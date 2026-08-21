#!/usr/bin/env python3
"""Handlers dos hooks do Claude Code para o PUG.

Um script so, despachado pelo primeiro argumento, em vez de comandos inline no
settings.json: assim da para testar cada hook piping um JSON de exemplo, e a
logica fica sob o mesmo lint do resto do projeto.

    echo '{"tool_input":{"file_path":"dados/hist.csv"}}' \
        | python .tools/claude_hooks.py pre-tool-use

Contrato: le o JSON do evento no stdin e escreve um JSON de resposta no stdout.
Sempre sai com 0 — bloqueio se comunica pelo corpo da resposta, nao pelo exit
code, e um hook que estoura nao pode travar a sessao.
"""

import json
import os
import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
GUARDRAILS = REPO_ROOT / ".tools" / "guardrails.py"
CARDS_INDEX = REPO_ROOT / "Cards" / "README.md"
SETUP_SKILL = ".claude/skills/godot-session-setup/SKILL.md"

# Caminhos que nenhum agente deve escrever direto.
PROTECTED = [
	(re.compile(r"(^|/)dados/", re.I),
	 "dados/ contem dados pessoais importados pelo usuario (hist.csv, email.csv...). "
	 "Nao sao codigo, nao sao editaveis pelo assistente e NUNCA entram no git (LGPD). "
	 "Fixtures ficticias de teste moram em test/fixtures/."),
	(re.compile(r"(^|/)arquivos/oferta/", re.I),
	 "arquivos/oferta/ contem dados nominais de docentes e vem inteira do repositorio "
	 "privado do curso via ferramentas/sincronizar_dados_curso.ps1. Edicao local e "
	 "sobrescrita na proxima sincronizacao — edite no repositorio canonico."),
	(re.compile(r"(^|/)arquivos/limesurvey/survey_tokens\.lst$", re.I),
	 "survey_tokens.lst contem tokens vinculados a alunos. Gerado, gitignorado, "
	 "intocavel."),
	(re.compile(r"(^|/)exportacoes/", re.I),
	 "exportacoes/ e saida gerada pelo programa, regeneravel. Nao editar a mao."),
	(re.compile(r"(^|/)\.godot/", re.I),
	 ".godot/ e cache do editor, regenerado a cada import."),
	(re.compile(r"(^|/)\.claude/worktrees/", re.I),
	 ".claude/worktrees/ sao checkouts paralelos de agentes, nao o codigo do "
	 "projeto. Edite o arquivo correspondente na raiz do repo."),
	(re.compile(r"(^|/)addons/gut/", re.I),
	 "addons/gut/ e dependencia de terceiros (GUT). Mudanca local sumiria "
	 "no proximo update; escreva o teste em test/ em vez disso."),
]


def read_event():
	try:
		return json.loads(sys.stdin.read() or "{}")
	except (ValueError, OSError):
		return {}


def emit(payload):
	sys.stdout.write(json.dumps(payload))
	sys.stdout.flush()


def event_file_path(event):
	tool_input = event.get("tool_input") or {}
	response = event.get("tool_response") or {}
	return tool_input.get("file_path") or response.get("filePath") or ""


def normalize(path):
	return str(path).replace("\\", "/")


def run_guardrails(paths):
	"""Retorna (ok, saida) do guardrails para os caminhos dados."""
	if not paths:
		return True, ""
	command = [sys.executable, str(GUARDRAILS)] + [str(p) for p in paths]
	try:
		result = subprocess.run(
			command, cwd=str(REPO_ROOT), capture_output=True, text=True,
			encoding="utf-8", errors="replace", timeout=120)
	except (OSError, subprocess.SubprocessError):
		return True, ""  # ferramenta indisponivel nao pode travar a edicao
	return result.returncode == 0, (result.stdout or "") + (result.stderr or "")


def changed_gd_files():
	try:
		result = subprocess.run(
			["git", "diff", "--name-only", "HEAD"], cwd=str(REPO_ROOT),
			capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=30)
	except (OSError, subprocess.SubprocessError):
		return []
	names = [n.strip() for n in (result.stdout or "").splitlines() if n.strip().endswith(".gd")]
	return [n for n in names if (REPO_ROOT / n).exists()]


def relative_to_repo(path):
	"""Caminho relativo a REPO_ROOT quando esta dentro dela; senao, inalterado.

	As regras de PROTECTED sao escritas em caminho de projeto. Quando a sessao
	roda dentro de uma worktree, REPO_ROOT e a propria worktree e todo caminho
	absoluto carrega o prefixo .claude/worktrees/<nome>/ — o que faria a regra
	de worktree barrar o proprio trabalho da sessao. Relativizando antes, a
	regra volta a significar: nao mexa na worktree ALHEIA.
	"""
	if not path:
		return path
	try:
		return normalize(Path(path).resolve().relative_to(REPO_ROOT))
	except (ValueError, OSError):
		return path


def handle_pre_tool_use(event):
	path = relative_to_repo(normalize(event_file_path(event)))
	if not path:
		return emit({})
	for pattern, reason in PROTECTED:
		if pattern.search(path):
			return emit({
				"hookSpecificOutput": {
					"hookEventName": "PreToolUse",
					"permissionDecision": "deny",
					"permissionDecisionReason": reason,
				}
			})
	emit({})


def handle_post_tool_use(event):
	path = normalize(event_file_path(event))
	if not path.endswith(".gd"):
		return emit({})
	target = Path(path)
	if not target.is_absolute():
		target = REPO_ROOT / target
	if not target.exists():
		return emit({})
	ok, output = run_guardrails([target])
	if ok:
		return emit({"suppressOutput": True})
	emit({
		"decision": "block",
		"reason": (
			"guardrails do projeto reprovaram esta edicao. Corrija antes de seguir; "
			"as regras vem de FORMATACAO.md e AGENTS.md:\n\n" + output.strip()),
	})


def handle_session_start(_event):
	lines = [
		"Projeto PUG (Godot 4.7). O trabalho e organizado por cards.",
		"Para descrever uma feature nova ou retomar um card, leia " + SETUP_SKILL + ".",
		"Portoes: `python .tools/guardrails.py` (lint + regras do projeto), "
		"`python .tools/run_tests.py` (suite GUT headless) e o parser do Godot.",
	]
	if CARDS_INDEX.exists():
		try:
			index = CARDS_INDEX.read_text(encoding="utf-8")
		except OSError:
			index = ""
		open_rows = [
			row.strip() for row in index.splitlines()
			if row.strip().startswith("|") and ("`ready`" in row or "`in_progress`" in row)
		]
		if open_rows:
			lines.append("")
			lines.append("Cards abertos:")
			lines.extend(open_rows[:15])
	emit({
		"hookSpecificOutput": {
			"hookEventName": "SessionStart",
			"additionalContext": "\n".join(lines),
		}
	})


def handle_subagent_stop(_event):
	"""Avisa, nunca bloqueia.

	Bloquear aqui quebraria o agente de Gate do pipeline, cujo trabalho e
	justamente terminar com a arvore reprovada e reportar guardrails_clean=false —
	e esse relatorio e o sinal que faz o laco do workflow parar. O bloqueio real
	ja acontece no PostToolUse, no instante da edicao, e no pre-commit.
	"""
	files = changed_gd_files()
	if not files:
		return emit({"suppressOutput": True})
	ok, output = run_guardrails(files)
	if ok:
		return emit({"suppressOutput": True})
	first = (output.strip().splitlines() or [""])[0]
	emit({
		"systemMessage": "Subagente terminou com violacao de guardrail em .gd alterado: "
		                 + first,
		"suppressOutput": True,
	})


def handle_stop(_event):
	"""Lembrete barato de rodar a suite.

	Nao re-roda o guardrails: o PostToolUse ja garantiu que cada .gd editado passou
	no momento da edicao.
	"""
	files = changed_gd_files()
	if not files:
		return emit({"suppressOutput": True})
	emit({
		"systemMessage": "{} arquivo(s) .gd modificado(s). Rode `python .tools/run_tests.py` "
		                 "antes de commitar — o pre-commit vai exigir.".format(len(files)),
		"suppressOutput": True,
	})


HANDLERS = {
	"pre-tool-use": handle_pre_tool_use,
	"post-tool-use": handle_post_tool_use,
	"session-start": handle_session_start,
	"subagent-stop": handle_subagent_stop,
	"stop": handle_stop,
}


def main(argv):
	if not argv or argv[0] not in HANDLERS:
		sys.stderr.write("uso: claude_hooks.py {}\n".format("|".join(sorted(HANDLERS))))
		return 0
	event = read_event()
	try:
		HANDLERS[argv[0]](event)
	except Exception as error:  # um hook quebrado nao pode derrubar a sessao
		sys.stderr.write("claude_hooks: {}: {}\n".format(type(error).__name__, error))
		emit({})
	return 0


if __name__ == "__main__":
	os.chdir(str(REPO_ROOT))
	sys.exit(main(sys.argv[1:]))
