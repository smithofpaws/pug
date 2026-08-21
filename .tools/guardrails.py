#!/usr/bin/env python3
"""Guardrails deterministicos do PUG (Pacote de Utilidades para Graduacao).

Ponto de entrada unico de checagem estatica de GDScript. Roda o gdlint (regras
genericas da linguagem, configuradas em gdlintrc) e soma regras que so fazem
sentido neste projeto e que nenhum linter generico conhece.

    python .tools/guardrails.py                     # repo inteiro
    python .tools/guardrails.py a.gd b.gd           # arquivos especificos
    python .tools/guardrails.py --no-lint           # so as regras do projeto
    python .tools/guardrails.py --update-baseline   # re-congela a divida atual

Sai com 0 quando limpo e 1 quando ha violacao, imprimindo uma linha
`arquivo:linha: [regra] mensagem` por ocorrencia. E esse exit code que os hooks
do Claude Code e o pre-commit do Lefthook consomem.

BASELINE (ratchet): o codigo anterior ao guardrail carrega violacoes historicas
(tipagem incompleta, espacos, `##` em privado). Elas estao CONGELADAS em
.tools/guardrails_baseline.json como contagem por arquivo+regra: o portao so
reprova quando um arquivo EXCEDE a propria contagem congelada — ou seja,
violacao nova e barrada, a divida antiga e tolerada e esta registrada. Reduzir
a divida e progresso: rode --update-baseline depois de limpar um arquivo para
apertar a catraca (nunca para afrouxa-la — o diff do JSON denuncia).

As regras de tipagem e ordem de secoes usam a arvore de parse do gdtoolkit em
vez de regex: assinatura multilinha, lambda e bind de `for`/`match` fazem busca
textual dar falso positivo. As demais sao textuais porque olham comentarios ou
tokens que a arvore descarta.
"""

import json
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
BASELINE_PATH = REPO_ROOT / ".tools" / "guardrails_baseline.json"

# Diretorios que nao sao codigo do projeto: cache do editor, dependencias de
# terceiros, backups, dados importados e checkouts paralelos de agentes.
EXCLUDED_DIRS = {
	".git", ".godot", ".claude", ".backup", "addons", "__pycache__",
	"dados", "exportacoes", "externo",
}

# Regra filesystem-boundary: arquivos autorizados a tocar o filesystem.
# - io/file_handling.gd e a classe autorizada por contrato (AGENTS.md);
# - scenes/main.gd concentra a leitura de arquivos e injeta nos modulos;
# - os demais sao CONGELAMENTO, nao endosso: ja tocavam disco quando o guardrail
#   nasceu (2026-08-21). Codigo novo nao entra aqui — le via main/file_handling.
#   Remover um arquivo desta lista quando ele for limpo e progresso.
FILESYSTEM_ALLOWED = {
	"standalone_scripts/io/file_handling.gd",
	"scenes/main.gd",
	# --- congelados (divida tecnica registrada) ---
	"scenes/barraprincipal.gd",
	"scenes/Modulos/Exportadores/exportadores.gd",
	"scenes/Modulos/LimeSurvey/limesurvey.gd",
	"scenes/Modulos/PlanejamentoHorario/Complementos/importador_preferencias.gd",
	"scenes/Modulos/PlanejamentoHorario/planejamentohorario.gd",
	"scenes/Modulos/PlanejamentoOferta/planejamentooferta.gd",
	"scenes/TelaPrincipal/VerificadorArquivos/verificador_arquivos.gd",
	"standalone_scripts/analise/horarios_exe.gd",
	"standalone_scripts/io/arquivos_planejamento.gd",
	"standalone_scripts/io/atualizador.gd",
}
FILESYSTEM_ALLOWED_PREFIXES = (".tools/", "test/")

# Regra tooltip-unico: tooltips passam SEMPRE por DicaFlutuante (AGENTS.md,
# "Regras de organizacao"). Nenhum modulo seta Control.tooltip_text direto.
TOOLTIP_ALLOWED = {"scenes/Complementares/DicaFlutuante/dica_flutuante.gd"}

_STRING_RE = re.compile(r'"(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\'')
_DECL_RE = re.compile(r"^\s*(?:@\w+(?:\([^)]*\))?\s+)*(var|const|func|signal)\s+([A-Za-z_]\w*)")

# `$` so resolve a partir de self, entao `outro_no.get_node("X")` nao tem
# substituto e nao e violacao. So a chamada nua (implicitamente em self) e.
_GET_NODE_RE = re.compile(r"(?<![.\w])get_node\s*\(")

# Callbacks do engine tem assinatura e posicao fixas: FORMATACAO.md §2 lhes da
# uma secao propria ("Ciclo de vida"), antes das demais funcoes. Nao entram na
# conta de publica-antes-de-privada.
LIFECYCLE_CALLBACKS = {
	"_init", "_ready", "_process", "_physics_process", "_enter_tree", "_exit_tree",
	"_input", "_unhandled_input", "_unhandled_key_input", "_shortcut_input",
	"_notification", "_draw", "_gui_input", "_to_string", "_get_configuration_warnings",
}

# Nos da arvore que representam declaracao sem tipo explicito.
UNTYPED_CLASS_VAR = {"class_var_empty", "class_var_assigned"}
UNTYPED_FUNC_VAR = {"func_var_empty", "func_var_assigned"}
UNTYPED_ARG = "func_arg_regular"


class Violation:
	def __init__(self, path, line, rule, message):
		self.path = path
		self.line = line
		self.rule = rule
		self.message = message

	def __str__(self):
		return "{}:{}: [{}] {}".format(self.path, self.line, self.rule, self.message)


def rel(path):
	"""Caminho relativo a raiz do repo, com barras normais nos dois SOs."""
	try:
		return path.resolve().relative_to(REPO_ROOT).as_posix()
	except ValueError:
		return path.as_posix()


def collect_files(args):
	"""Expande os argumentos em arquivos .gd, ignorando os diretorios excluidos."""
	roots = [Path(a) for a in args] if args else [REPO_ROOT]
	found = []
	for root in roots:
		if not root.is_absolute():
			root = REPO_ROOT / root
		if root.is_file():
			candidates = [root] if root.suffix == ".gd" else []
		else:
			candidates = sorted(root.rglob("*.gd"))
		for path in candidates:
			parts = set(path.relative_to(REPO_ROOT).parts) if _under_repo(path) else set()
			if parts & EXCLUDED_DIRS:
				continue
			found.append(path)
	seen = set()
	unique = []
	for path in found:
		key = path.resolve()
		if key not in seen:
			seen.add(key)
			unique.append(path)
	return unique


def _under_repo(path):
	try:
		path.resolve().relative_to(REPO_ROOT)
		return True
	except ValueError:
		return False


def strip_strings_and_comments(line):
	"""Remove literais e comentario de fim de linha para as regras textuais.

	Evita acusar `get_node(` citado dentro de uma docstring ou de uma mensagem
	de erro. Nao pretende ser um lexer: e uma aproximacao suficiente para as
	regras que a usam.
	"""
	stripped = _STRING_RE.sub('""', line)
	hash_at = stripped.find("#")
	return stripped if hash_at < 0 else stripped[:hash_at]


# --------------------------------------------------------------------------- #
# Regras sobre a arvore de parse
# --------------------------------------------------------------------------- #

def parse_tree(source):
	from gdtoolkit.parser import parser

	return parser.parse(source, gather_metadata=True)


def _node_line(node, default=0):
	return getattr(getattr(node, "meta", None), "line", default)


def _token_text(value):
	return str(value)


def check_tree_rules(path, source, violations):
	"""Regras de tipagem estatica e ordem de secoes (FORMATACAO.md §2 e §8)."""
	relpath = rel(path)
	try:
		tree = parse_tree(source)
	except Exception:
		return  # sintaxe invalida: o gdlint reporta com mensagem melhor

	class_members = []  # (linha, tipo, nome)
	for node in tree.children:
		if not hasattr(node, "data"):
			continue
		kind = str(node.data)
		if kind == "class_var_stmt":
			for child in node.children:
				if not hasattr(child, "data"):
					continue
				name = _token_text(child.children[0]) if child.children else "?"
				line = _node_line(child) or _node_line(node)
				class_members.append((line, "var", name))
				if str(child.data) in UNTYPED_CLASS_VAR:
					violations.append(Violation(
						relpath, line, "static-typing",
						"variavel de classe '{}' sem tipo explicito (FORMATACAO.md §8)".format(name)))
		elif kind in ("const_stmt", "signal_stmt"):
			class_members.append((_node_line(node), "var", kind))
		elif kind == "func_def":
			_check_func(node, relpath, class_members, violations)
		elif kind == "static_func_def":
			# `static func` vem embrulhado num no proprio; sem descer aqui, toda
			# funcao estatica escaparia das regras de tipagem e de ordem.
			for inner in node.children:
				if getattr(inner, "data", None) == "func_def":
					_check_func(inner, relpath, class_members, violations)

	_check_section_order(relpath, class_members, violations)


def _check_func(node, relpath, class_members, violations):
	header = next((c for c in node.children if getattr(c, "data", None) == "func_header"), None)
	if header is None:
		return
	line = _node_line(header) or _node_line(node)
	name = _token_text(header.children[0]) if header.children else "?"
	class_members.append((line, "func", name))

	# Tipo de retorno obrigatorio. O header traz [nome, func_args] e, quando
	# tipado, um terceiro filho com o tipo.
	args_index = next(
		(i for i, c in enumerate(header.children) if getattr(c, "data", None) == "func_args"), None)
	if args_index is not None and len(header.children) <= args_index + 1:
		violations.append(Violation(
			relpath, line, "static-typing",
			"funcao '{}' sem tipo de retorno (FORMATACAO.md §8)".format(name)))

	# Parametros tipados.
	if args_index is not None:
		for arg in header.children[args_index].children:
			if getattr(arg, "data", None) == UNTYPED_ARG:
				violations.append(Violation(
					relpath, line, "static-typing",
					"parametro '{}' de '{}' sem tipo (FORMATACAO.md §8)".format(
						_token_text(arg.children[0]) if arg.children else "?", name)))

	# Variaveis locais tipadas.
	for sub in node.iter_subtrees():
		if str(sub.data) in UNTYPED_FUNC_VAR:
			violations.append(Violation(
				relpath, _node_line(sub, line), "static-typing",
				"variavel local '{}' sem tipo; use ':=' ou anote o tipo (FORMATACAO.md §8)".format(
					_token_text(sub.children[0]) if sub.children else "?")))


def _check_section_order(relpath, members, violations):
	"""Ordem de secoes conforme FORMATACAO.md §2.

	Sao dois layouts. Modulo de cena (tem handlers `_on_*`) fecha com os sinais;
	script standalone poe funcoes publicas antes das privadas. O que vale nos
	dois e que declaracoes vem antes de funcoes.
	"""
	members = sorted(members, key=lambda m: m[0])
	funcs = [m for m in members if m[1] == "func"]
	first_func_line = funcs[0][0] if funcs else None

	if first_func_line is not None:
		for line, kind, name in members:
			if kind == "var" and line > first_func_line:
				violations.append(Violation(
					relpath, line, "section-order",
					"declaracao '{}' depois da primeira funcao; variaveis, constantes e sinais "
					"vem antes das funcoes (FORMATACAO.md §2)".format(name)))

	is_scene_module = any(name.startswith("_on_") for _, _, name in funcs)
	if is_scene_module:
		last_signal_handler = None
		for line, _, name in funcs:
			if name.startswith("_on_"):
				last_signal_handler = line
			elif last_signal_handler is not None:
				violations.append(Violation(
					relpath, line, "section-order",
					"funcao '{}' depois de um handler `_on_*`; os sinais ficam por ultimo, "
					"em #region Sinais (FORMATACAO.md §2)".format(name)))
				break
	else:
		first_private = None
		for line, _, name in funcs:
			if name in LIFECYCLE_CALLBACKS:
				continue
			if name.startswith("_"):
				if first_private is None:
					first_private = (line, name)
			elif first_private is not None:
				violations.append(Violation(
					relpath, line, "section-order",
					"funcao publica '{}' depois da privada '{}'; publicas vem antes das "
					"privadas (FORMATACAO.md §2)".format(name, first_private[1])))
				break


# --------------------------------------------------------------------------- #
# Regras textuais
# --------------------------------------------------------------------------- #

def check_text_rules(path, source, violations):
	relpath = rel(path)
	lines = source.splitlines()
	allowed_fs = relpath in FILESYSTEM_ALLOWED or relpath.startswith(FILESYSTEM_ALLOWED_PREFIXES)
	allowed_tooltip = relpath in TOOLTIP_ALLOWED

	for number, raw in enumerate(lines, start=1):
		code = strip_strings_and_comments(raw)

		# Indentacao com tabs, sempre (FORMATACAO.md §11).
		if raw.startswith(" ") and raw.strip():
			violations.append(Violation(
				relpath, number, "tabs-only",
				"indentacao com espacos; este projeto usa tabs (FORMATACAO.md §11)"))

		# Filesystem so pelo main e pelo FileHandling (AGENTS.md, "Leitura de
		# arquivos"). A lista congelada em FILESYSTEM_ALLOWED nao cresce.
		if not allowed_fs:
			match = re.search(r"\b(FileAccess|DirAccess|ResourceSaver)\b", code)
			if match:
				violations.append(Violation(
					relpath, number, "filesystem-boundary",
					"{} fora do main/FileHandling; modulos recebem dados injetados pelo "
					"main.gd, nunca leem arquivos diretamente (AGENTS.md)".format(match.group(1))))

		# Acesso a no sempre por $ (FORMATACAO.md §14).
		if _GET_NODE_RE.search(code):
			violations.append(Violation(
				relpath, number, "no-get-node",
				'use $"%UniqueName" ou $"Caminho/Completo" em vez de get_node() (FORMATACAO.md §14)'))

		# Instanciacao por ClassName.new() (FORMATACAO.md §3).
		if re.search(r"preload\s*\([^)]*\)\s*\.\s*new\s*\(", code):
			violations.append(Violation(
				relpath, number, "no-preload-new",
				"use ':= ClassName.new()' em vez de preload(...).new() (FORMATACAO.md §3)"))

		# Tooltips sempre por DicaFlutuante (AGENTS.md, "Regras de organizacao").
		if not allowed_tooltip and re.search(r"\btooltip_text\b", code):
			violations.append(Violation(
				relpath, number, "tooltip-unico",
				"tooltip_text direto; tooltips passam por DicaFlutuante para manter "
				"consistencia visual (AGENTS.md)"))

	_check_private_docstrings(relpath, lines, violations)


def _check_private_docstrings(relpath, lines, violations):
	"""`##` documenta membro publico; privado usa `#` (FORMATACAO.md §4 e §6)."""
	for number, raw in enumerate(lines, start=1):
		if not raw.strip().startswith("##"):
			continue
		if number > 1 and lines[number - 2].strip().startswith("##"):
			continue  # bloco continuado: so a primeira linha aponta o membro
		if _is_class_docstring(lines, number):
			continue  # docstring da classe, logo abaixo de class_name/extends
		for lookahead in lines[number:number + 12]:
			text = lookahead.strip()
			if not text or text.startswith("##"):
				continue
			match = _DECL_RE.match(lookahead)
			if match and match.group(2).startswith("_"):
				violations.append(Violation(
					relpath, number, "private-docstring",
					"'##' documenta membro publico; '{}' e privado e usa '#' "
					"(FORMATACAO.md §4)".format(match.group(2))))
			break


def _is_class_docstring(lines, number):
	"""O bloco `##` que segue class_name/extends documenta a classe, nao o membro."""
	for previous in reversed(lines[: number - 1]):
		text = previous.strip()
		if not text:
			continue
		return text.startswith("class_name") or text.startswith("extends")
	return False


# --------------------------------------------------------------------------- #
# gdlint
# --------------------------------------------------------------------------- #

def run_gdlint(files, violations):
	if not files:
		return
	command = [sys.executable, "-m", "gdtoolkit.linter"] + [str(f) for f in files]
	try:
		result = subprocess.run(
			command, cwd=str(REPO_ROOT), capture_output=True, text=True, encoding="utf-8",
			errors="replace")
	except FileNotFoundError:
		print("guardrails: gdtoolkit nao encontrado. Instale com: "
		      'python -m pip install --user "gdtoolkit==4.*"', file=sys.stderr)
		sys.exit(2)
	if result.returncode == 0:
		return
	pattern = re.compile(r"^(.*?):(\d+): Error: (.*)$")
	for line in (result.stdout + result.stderr).splitlines():
		match = pattern.match(line.strip())
		if match:
			message = match.group(3)
			rule = "gdlint"
			tail = re.search(r"\(([a-z-]+)\)$", message)
			if tail:
				rule = "gdlint:" + tail.group(1)
				message = message[: tail.start()].strip()
			# O gdlint devolve o caminho como foi passado (absoluto); a baseline
			# e os hooks trabalham com caminho relativo ao repo — normalizar.
			violations.append(Violation(
				rel(Path(match.group(1))), int(match.group(2)), rule, message))


def load_baseline():
	if not BASELINE_PATH.exists():
		return {}
	try:
		return json.loads(BASELINE_PATH.read_text(encoding="utf-8"))
	except (ValueError, OSError):
		return {}


def save_baseline(violations):
	counts = Counter("{}|{}".format(v.path, v.rule) for v in violations)
	payload = dict(sorted(counts.items()))
	BASELINE_PATH.write_text(
		json.dumps(payload, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
	print("guardrails: baseline re-congelada com {} entrada(s) em {}.".format(
		len(payload), rel(BASELINE_PATH)))


def apply_baseline(violations):
	"""Filtra as violacoes toleradas: por arquivo+regra, ate a contagem congelada.

	Quando um arquivo excede a contagem, TODAS as ocorrencias daquele par sao
	reportadas — sem numero de linha estavel nao ha como saber qual e a nova, e
	mostrar so o excedente esconderia contexto de quem vai corrigir.
	"""
	baseline = load_baseline()
	grouped = {}
	for violation in violations:
		grouped.setdefault("{}|{}".format(violation.path, violation.rule), []).append(violation)
	kept = []
	tolerated = 0
	for key, group in grouped.items():
		allowed = baseline.get(key, 0)
		if len(group) > allowed:
			kept.extend(group)
		else:
			tolerated += len(group)
	return kept, tolerated


def main(argv):
	args = [a for a in argv if not a.startswith("--")]
	skip_lint = "--no-lint" in argv
	update_baseline = "--update-baseline" in argv
	if update_baseline and args:
		sys.stderr.write(
			"guardrails: --update-baseline exige varredura completa; nao passe arquivos.\n")
		return 2
	files = collect_files(args)
	if not files:
		return 0

	violations = []
	if not skip_lint:
		run_gdlint(files, violations)
	for path in files:
		source = path.read_text(encoding="utf-8")
		check_text_rules(path, source, violations)
		check_tree_rules(path, source, violations)

	if update_baseline:
		save_baseline(violations)
		return 0

	violations, tolerated = apply_baseline(violations)
	if not violations:
		if tolerated:
			sys.stderr.write(
				"guardrails: limpo ({} violacao(oes) pre-existentes toleradas pela "
				"baseline).\n".format(tolerated))
		return 0
	violations.sort(key=lambda v: (v.path, v.line, v.rule))
	stdout = getattr(sys.stdout, "buffer", None)
	for violation in violations:
		text = str(violation)
		if stdout is not None:
			stdout.write(text.encode("utf-8", "replace") + b"\n")
		else:
			print(text)
	if stdout is not None:
		stdout.flush()
	sys.stderr.write(
		"\nguardrails: {} violacao(oes) em {} arquivo(s) acima da baseline. Corrija as "
		"novas; as linhas listadas incluem as pre-existentes do mesmo par arquivo+regra "
		"(sem linha estavel nao da para separar).\n".format(
			len(violations), len({v.path for v in violations})))
	return 1


if __name__ == "__main__":
	sys.exit(main(sys.argv[1:]))
