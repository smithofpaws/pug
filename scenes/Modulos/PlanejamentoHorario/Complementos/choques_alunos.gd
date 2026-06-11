class_name ChoquesAlunos extends RefCounted
## Análise e relato dos choques de horário entre ALUNOS no Planejamento de Horário. [br]
## Conta e imprime, para pares de disciplinas co-alocadas, quantos discentes estão em ambas
## (nas condições de matrícula selecionadas). A política de indicadores (quando contar/relatar/
## detalhar) fica no módulo; esta classe só computa e imprime no terminal injetado.

var _ger_alocacoes: GerenciadorAlocacoes
var _analise_historico: AnaliseHistorico
var _terminal: Node

# Dados discentes e condições selecionadas, sincronizados pelo módulo via definir_dados sempre
# que mudam (o seletor de condições REATRIBUI o array — uma referência fixa ficaria obsoleta).
var _condicoes_discentes: Dictionary = {}
var _condicoes_selecionadas: Array[String] = []
var _historico: Dictionary = {}

## Configura as referências do módulo-pai.
func configurar(ger_alocacoes: GerenciadorAlocacoes, analise_historico: AnaliseHistorico, \
		terminal: Node) -> void:
	_ger_alocacoes = ger_alocacoes
	_analise_historico = analise_historico
	_terminal = terminal

## Atualiza os dados de discentes e as condições de choque consideradas. Chamar sempre que o
## módulo (re)carregar os dados ou o usuário alterar a seleção de condições.
func definir_dados(condicoes_discentes: Dictionary, condicoes_selecionadas: Array[String], \
		historico: Dictionary) -> void:
	_condicoes_discentes = condicoes_discentes
	_condicoes_selecionadas = condicoes_selecionadas
	_historico = historico

## Soma, sobre TODA a grade, quantos discentes estão em ambas as disciplinas de cada par de códigos
## distintos co-alocados (nas condições selecionadas). Silencioso — alimenta apenas a barra de status.
func contar() -> int:
	if _condicoes_discentes.is_empty() or _condicoes_selecionadas.is_empty():
		return 0
	var pares: Dictionary = {}
	for chave_celula in _ger_alocacoes.alocacoes:
		var arr: Array = _ger_alocacoes.alocacoes[chave_celula]
		for i in arr.size():
			var cod_i: String = (arr[i] as Dictionary).get("codigo", "").to_lower()
			for j in range(i + 1, arr.size()):
				var cod_j: String = (arr[j] as Dictionary).get("codigo", "").to_lower()
				if cod_i.is_empty() or cod_j.is_empty() or cod_i == cod_j:
					continue
				var a: String = cod_i if cod_i < cod_j else cod_j
				var b: String = cod_j if cod_i < cod_j else cod_i
				pares["%s|%s" % [a, b]] = true
	var total: int = 0
	for k in pares:
		var partes: PackedStringArray = str(k).split("|")
		var discentes: Dictionary = _analise_historico.comparar_discentes_disciplina(\
			partes[0], partes[1], _condicoes_discentes, _condicoes_selecionadas)
		total += discentes.size()
	return total

## Imprime no terminal os choques de alunos entre disciplinas sobrepostas nas células dadas (cada
## item de [param celulas] é [code][linha, coluna][/code]). Deduplica pares repetidos entre as
## células. [param detalhar] lista os alunos de cada par. [br]
## [param eh_ancora]: quando válido, só reporta um par se ao menos uma das disciplinas for âncora
## (eh_ancora.call(aloc) == true). Usado para focar o relato: ao soltar, âncora = a disciplina
## movida (só seus choques); ao clicar com filtro, âncora = as disciplinas que passam o filtro.
## Inválido = reporta todos os pares (ex.: clique sem filtro mostra todos os choques do dia).
func reportar_celulas(celulas: Array, detalhar: bool, eh_ancora: Callable = Callable()) -> void:
	if _condicoes_discentes.is_empty() or _condicoes_selecionadas.is_empty():
		return
	var vistos: Dictionary = {}
	for cel in celulas:
		var arr: Array = _ger_alocacoes.obter_alocacoes("%d_%d" % [cel[0], cel[1]])
		for i in arr.size():
			for j in range(i + 1, arr.size()):
				var aloc_a: Dictionary = arr[i]
				var aloc_b: Dictionary = arr[j]
				var cod_a: String = aloc_a.get("codigo", "").to_lower()
				var cod_b: String = aloc_b.get("codigo", "").to_lower()
				if cod_a.is_empty() or cod_b.is_empty() or cod_a == cod_b:
					continue
				# Foco: ao menos um lado do par precisa ser âncora (quando há predicado).
				if eh_ancora.is_valid() and not (eh_ancora.call(aloc_a) or eh_ancora.call(aloc_b)):
					continue
				var k: String = (cod_a + "|" + cod_b) if cod_a < cod_b else (cod_b + "|" + cod_a)
				if vistos.has(k):
					continue
				vistos[k] = true
				_imprimir_choque_par(aloc_a, aloc_b, detalhar)

## Lista [code][linha, coluna][/code] de todas as células ocupadas no dia (coluna) informado.
## "Dia" é a coluna da grade (as horas de uma disciplina empilham na mesma coluna).
func celulas_do_dia(coluna: int) -> Array:
	var celulas: Array = []
	for chave_celula in _ger_alocacoes.alocacoes:
		var partes: PackedStringArray = chave_celula.split("_")
		if partes.size() == 2 and int(partes[1]) == coluna:
			celulas.append([int(partes[0]), coluna])
	# Ordena por horário (linha) para o relato sair de cima para baixo no terminal.
	celulas.sort_custom(func(a, b): return a[0] < b[0])
	return celulas

# Imprime no terminal a contagem de alunos em choque entre duas disciplinas e, se [param detalhar],
# a lista de alunos com a situação em cada uma. O rótulo segue o modo de visualização.
func _imprimir_choque_par(aloc_a: Dictionary, aloc_b: Dictionary, detalhar: bool) -> void:
	var cod_a: String = aloc_a.get("codigo", "").to_lower()
	var cod_b: String = aloc_b.get("codigo", "").to_lower()
	var discentes: Dictionary = _analise_historico.comparar_discentes_disciplina(\
		cod_a, cod_b, _condicoes_discentes, _condicoes_selecionadas)
	var n: int = discentes.size()
	var rot_a: String = _ger_alocacoes.rotulo_alocacao(aloc_a)
	var rot_b: String = _ger_alocacoes.rotulo_alocacao(aloc_b)
	_terminal.linha("Choque de alunos: %s × %s → %d aluno(s) em ambas." % \
		[rot_a, rot_b, n], "aviso")
	if n > 0 and detalhar:
		_listar_alunos_em_choque(discentes, rot_a, rot_b)

# Imprime, para um par de disciplinas, o nome de cada discente em choque e a situação em que se
# enquadra em cada uma. Útil para distinguir choques certos de choques condicionais (ex.: o aluno
# é "matriculável" em uma e "seaprovado" em outra — só haverá choque se for aprovado primeiro). [br]
# A lista é ordenada por prioridade da situação: já matriculados primeiro, depois matriculáveis,
# por último os seaprovado (ver [method _prioridade_condicao]).
func _listar_alunos_em_choque(discentes: Dictionary, rot_a: String, rot_b: String) -> void:
	var entradas: Array = []
	for matr in discentes.keys():
		var nome: String = _historico.get(matr, {}).get("nomedoaluno", str(matr))
		# Deduplica pares de condições repetidos para o mesmo aluno e guarda a prioridade de cada par.
		var vistos: Dictionary = {}
		var pares_prio: Array = []  # cada item: [prio_min, prio_max, texto]
		for par_cond in discentes[matr]:
			var cond_a: String = str(par_cond[0])
			var cond_b: String = str(par_cond[1])
			var chave_par: String = cond_a + "|" + cond_b
			if vistos.has(chave_par):
				continue
			vistos[chave_par] = true
			var pa: int = _prioridade_condicao(cond_a)
			var pb: int = _prioridade_condicao(cond_b)
			# Cada lado leva a cor (BBCode) da sua condição — a mesma paleta das situações curriculares
			# (ex.: matriculado_agora = verde; matriculavel = neutro). Facilita distinguir o tipo de choque.
			var texto: String = "[color=%s]%s: %s[/color] / [color=%s]%s: %s[/color]" % \
				[PaletaSemantica.cor_hex(cond_a), rot_a, cond_a.replacen("_", " ").capitalize(), \
				PaletaSemantica.cor_hex(cond_b), rot_b, cond_b.replacen("_", " ").capitalize()]
			pares_prio.append([min(pa, pb), max(pa, pb), texto])
		# Ordena as situações do próprio aluno (mais "matriculado" primeiro).
		pares_prio.sort_custom(func(x, y): return x[0] < y[0] if x[0] != y[0] else x[1] < y[1])
		var situacoes: Array[String] = []
		for pp in pares_prio:
			situacoes.append(pp[2])
		# Chave de ordenação do aluno: o melhor (menor) par de prioridades que ele possui.
		var kmin: int = pares_prio[0][0] if pares_prio.size() > 0 else 9
		var kmax: int = pares_prio[0][1] if pares_prio.size() > 0 else 9
		entradas.append({"nome": nome, "kmin": kmin, "kmax": kmax, "situacoes": situacoes})
	# Ordena os alunos por prioridade de situação e, em empate, por nome.
	entradas.sort_custom(func(x, y):
		if x["kmin"] != y["kmin"]:
			return x["kmin"] < y["kmin"]
		if x["kmax"] != y["kmax"]:
			return x["kmax"] < y["kmax"]
		return str(x["nome"]) < str(y["nome"]))
	for e in entradas:
		_terminal.item("%s — %s" % [str(e["nome"]).capitalize(), " ; ".join(e["situacoes"])])

# Prioridade de uma condição de matrícula para ordenar a apresentação dos choques: [br]
# 1 = já matriculado (normal, por aproveitamento ou irregular); 2 = matriculável (inclui
# corequisito e aproveitamento); 3 = seaprovado (inclui corequisito e aproveitamento). Menor = antes.
func _prioridade_condicao(cond: String) -> int:
	if cond.contains("matriculado") or cond.contains("matricula_irregular"):
		return 1
	if cond.contains("matriculavel"):
		return 2
	if cond.contains("seaprovado"):
		return 3
	return 4
