extends GutTest
## Prova a ordem canonica de prioridade das condicoes na grade de horarios
## (Cards/0001-ordem-prioridade-grade-horarios): tier Modo Ajuste, depois a
## ordem de base_config.json:condicoes, depois desconhecidas -- estavel e sem
## mutar a entrada do chamador.

const CONDICOES_BASE: Array[String] = [
	"matriculado_agora",
	"matriculado_agora_aproveitamento",
	"matricula_irregular",
	"matricula_irregular_aproveitamento",
	"matriculavel",
	"matriculavel_aproveitamento",
	"corequisito_matriculavel",
	"corequisito_matriculavel_aproveitamento",
	"seaprovado",
	"seaprovado_aproveitamento",
	"corequisito_seaprovado",
	"corequisito_seaprovado_aproveitamento",
]

var _analise := AnaliseHorarios.new()
var _configuracao_base_original: Dictionary


func before_each() -> void:
	_configuracao_base_original = GV.configuracao_base
	GV.configuracao_base = {
		"dias_semana": ["segunda"],
		"horarios_aula": ["07:30"],
		"condicoes": CONDICOES_BASE,
	}


func after_each() -> void:
	GV.configuracao_base = _configuracao_base_original


func test_ordenar_condicoes_poe_ajuste_primeiro() -> void:
	var condicoes: Array = ["seaprovado", "ajuste_excluir", "matriculavel", "ajuste_incluir", "matricula_irregular"]
	var resultado: Array[String] = AnaliseHorarios.ordenar_condicoes(condicoes, CONDICOES_BASE)
	assert_eq(resultado, ["ajuste_incluir", "ajuste_excluir", "matricula_irregular", "matriculavel", "seaprovado"])


func test_ordenar_condicoes_e_estavel_para_desconhecidas() -> void:
	var condicoes: Array = ["matriculavel", "zzz_desconhecida_b", "aaa_desconhecida_a"]
	var resultado: Array[String] = AnaliseHorarios.ordenar_condicoes(condicoes, CONDICOES_BASE)
	# As desconhecidas mantem a ordem relativa de entrada -- nao ordenam alfabeticamente.
	assert_eq(resultado, ["matriculavel", "zzz_desconhecida_b", "aaa_desconhecida_a"])


func test_ordenar_condicoes_nao_muta_entrada() -> void:
	var condicoes: Array = ["seaprovado", "ajuste_incluir"]
	AnaliseHorarios.ordenar_condicoes(condicoes, CONDICOES_BASE)
	assert_eq(condicoes, ["seaprovado", "ajuste_incluir"], "ordenar_condicoes nao pode mutar a entrada")


func test_ordenar_condicoes_com_base_vazia_nao_crasha() -> void:
	var condicoes: Array = ["ajuste_excluir", "matriculavel", "ajuste_incluir", "seaprovado"]
	var resultado: Array[String] = AnaliseHorarios.ordenar_condicoes(condicoes, [])
	# Sem base, so o tier ajuste e reordenado; o resto preserva a ordem de entrada.
	assert_eq(resultado, ["ajuste_incluir", "ajuste_excluir", "matriculavel", "seaprovado"])


func test_determinar_horarios_concatena_na_ordem_canonica() -> void:
	var horarios_txt: Array = [
		{"disciplina": "Disciplina Um (al0001)", "turma": "T10", "dia": "segunda", "horario": "07:30"},
		{"disciplina": "Disciplina Dois (al0002)", "turma": "T10", "dia": "segunda", "horario": "07:30"},
		{"disciplina": "Disciplina Tres (al0003)", "turma": "T10", "dia": "segunda", "horario": "07:30"},
		{"disciplina": "Disciplina Quatro (al0004)", "turma": "T10", "dia": "segunda", "horario": "07:30"},
		{"disciplina": "Disciplina Cinco (al0005)", "turma": "T10", "dia": "segunda", "horario": "07:30"},
		{"disciplina": "Disciplina Nove (al0009)", "turma": "T10", "dia": "segunda", "horario": "07:30"},
	]
	var disc_cursaveis: Dictionary = {
		"seaprovado": ["al0003"],
		"ajuste_excluir": ["al0005"],
		"condicao_futura": ["al0009"],
		"matriculavel": ["al0001"],
		"ajuste_incluir": ["al0004"],
		"matricula_irregular": ["al0002"],
	}
	var historico_matricula: Dictionary = {"nomedoaluno": "aluno ficticio", "dados": []}
	var lista_cores: Dictionary = {
		"seaprovado": "orange",
		"ajuste_excluir": "red",
		"matriculavel": "blue",
		"ajuste_incluir": "green",
		"matricula_irregular": "yellow",
	}
	var condicoes: Array = ["seaprovado", "ajuste_excluir", "condicao_futura", "matriculavel", "ajuste_incluir", "matricula_irregular"]

	var matriz: Array = _analise.determinar_horarios({}, horarios_txt, disc_cursaveis, historico_matricula, condicoes, lista_cores)
	var celula: String = matriz[1][1]

	var pos_incluir: int = celula.find("AL0004")
	var pos_excluir: int = celula.find("AL0005")
	var pos_irregular: int = celula.find("AL0002")
	var pos_matriculavel: int = celula.find("AL0001")
	var pos_seaprovado: int = celula.find("AL0003")
	var pos_futura: int = celula.find("AL0009")

	assert_ne(pos_incluir, -1, "AL0004 deve estar na celula")
	assert_true(pos_incluir < pos_excluir, "ajuste_incluir deve vir antes de ajuste_excluir")
	assert_true(pos_excluir < pos_irregular, "tier ajuste deve vir antes do tier matriculadas")
	assert_true(pos_irregular < pos_matriculavel, "matricula_irregular deve vir antes de matriculavel")
	assert_true(pos_matriculavel < pos_seaprovado, "matriculavel deve vir antes de seaprovado")
	assert_true(pos_seaprovado < pos_futura, "condicao desconhecida deve ficar no fim")


func test_condicao_desconhecida_fica_no_fim_com_shake() -> void:
	var horarios_txt: Array = [
		{"disciplina": "Disciplina Um (al0001)", "turma": "T10", "dia": "segunda", "horario": "07:30"},
		{"disciplina": "Disciplina Nove (al0009)", "turma": "T10", "dia": "segunda", "horario": "07:30"},
	]
	var disc_cursaveis: Dictionary = {
		"matriculavel": ["al0001"],
		"condicao_futura": ["al0009"],
	}
	var historico_matricula: Dictionary = {"nomedoaluno": "aluno ficticio", "dados": []}
	var lista_cores: Dictionary = {"matriculavel": "blue"}
	var condicoes: Array = ["condicao_futura", "matriculavel"]

	var matriz: Array = _analise.determinar_horarios({}, horarios_txt, disc_cursaveis, historico_matricula, condicoes, lista_cores)
	var celula: String = matriz[1][1]

	assert_true(celula.find("AL0001") < celula.find("AL0009"), "conhecida deve vir antes da desconhecida")
	assert_true(celula.contains("[shake rate=20.0 level=10]AL0009[/shake]"), "condicao sem cor mantem o destaque [shake]")


func test_determinar_horarios_nao_muta_condicoes_do_chamador() -> void:
	var horarios_txt: Array = [
		{"disciplina": "Disciplina Um (al0001)", "turma": "T10", "dia": "segunda", "horario": "07:30"},
	]
	var disc_cursaveis: Dictionary = {"matriculavel": ["al0001"]}
	var historico_matricula: Dictionary = {"nomedoaluno": "aluno ficticio", "dados": []}
	var lista_cores: Dictionary = {"matriculavel": "blue"}
	var condicoes: Array = ["matriculavel", "condicao_sem_entrada"]

	_analise.determinar_horarios({}, horarios_txt, disc_cursaveis, historico_matricula, condicoes, lista_cores)

	assert_eq(condicoes, ["matriculavel", "condicao_sem_entrada"], "determinar_horarios nao pode mutar o array condicoes do chamador")


func test_determinar_horarios_nao_poda_condicoes_entre_chamadas() -> void:
	# Regressao: antes desta mudanca, _preparar_horarios podava (remove_at) o array
	# condicoes do chamador in-place. Como situacao_alunos.gd passa
	# $"%Horarios".lista_condicoes_verdadeiras por referencia ao processar varios
	# alunos em sequencia, uma condicao ausente no primeiro aluno sumia da grade de
	# todos os alunos seguintes, mesmo que eles a tivessem.
	var condicoes: Array = ["matriculavel", "corequisito_seaprovado"]
	var lista_cores: Dictionary = {"matriculavel": "blue", "corequisito_seaprovado": "purple"}
	var historico_matricula: Dictionary = {"nomedoaluno": "aluno ficticio", "dados": []}

	# Primeira "matricula": disc_cursaveis nao tem corequisito_seaprovado -- a chave
	# nem existe em horarios_txt_condicao, o que aciona o filtro de _preparar_horarios.
	var horarios_txt_a: Array = [
		{"disciplina": "Disciplina Um (al0001)", "turma": "T10", "dia": "segunda", "horario": "07:30"},
	]
	var disc_cursaveis_a: Dictionary = {"matriculavel": ["al0001"]}
	_analise.determinar_horarios({}, horarios_txt_a, disc_cursaveis_a, historico_matricula, condicoes, lista_cores)

	# Segunda "matricula": reusa o MESMO array condicoes (por referencia) e tem
	# corequisito_seaprovado.
	var horarios_txt_b: Array = [
		{"disciplina": "Disciplina Sete (al0007)", "turma": "T10", "dia": "segunda", "horario": "07:30"},
	]
	var disc_cursaveis_b: Dictionary = {"corequisito_seaprovado": ["al0007"]}
	var matriz_b: Array = _analise.determinar_horarios({}, horarios_txt_b, disc_cursaveis_b, historico_matricula, condicoes, lista_cores)

	assert_true(matriz_b[1][1].contains("AL0007"), "corequisito_seaprovado da segunda matricula nao pode sumir por causa da primeira")


## Prova o casamento turma/subturma (Cards/0006-casamento-turma-subturma-horarios): a letra da
## turma identifica uma subturma, e letra ausente de qualquer um dos lados casa com qualquer letra.

func test_comparar_turmas_letra_de_um_lado_casa() -> void:
	assert_true(AnaliseHorarios._comparar_turmas("20", "20a"), "turma sem letra deve casar com a subturma")


func test_comparar_turmas_e_simetrica() -> void:
	assert_true(AnaliseHorarios._comparar_turmas("20a", "20"), "a regra deve valer nos dois sentidos")


func test_comparar_turmas_letras_distintas_nao_casam() -> void:
	assert_false(AnaliseHorarios._comparar_turmas("20a", "20b"), "grupos diferentes nao podem casar")


func test_comparar_turmas_identicas_casam() -> void:
	assert_true(AnaliseHorarios._comparar_turmas("20a", "20a"), "turmas identicas com letra devem casar")
	assert_true(AnaliseHorarios._comparar_turmas("20", "20"), "turmas identicas sem letra devem casar")


func test_comparar_turmas_numero_diferente_nao_casa() -> void:
	assert_false(AnaliseHorarios._comparar_turmas("20", "80"), "numero diferente nunca casa")
	assert_false(AnaliseHorarios._comparar_turmas("20a", "80a"), "numero manda mesmo com letras iguais")


func test_comparar_turmas_ignora_prefixo_t_e_caixa() -> void:
	assert_true(AnaliseHorarios._comparar_turmas("t20", "20A"), "prefixo T e caixa continuam irrelevantes")


func test_comparar_turmas_sem_numero_nao_casa_com_nada() -> void:
	assert_false(AnaliseHorarios._comparar_turmas("", ""), "duas turmas vazias nao podem casar entre si")
	assert_false(AnaliseHorarios._comparar_turmas(" ", " "), "turma so com espaco continua sem numero")
	assert_false(AnaliseHorarios._comparar_turmas("a", "a"), "letra sem numero nao pode casar")
	assert_false(AnaliseHorarios._comparar_turmas("", "20"), "turma vazia nao casa com turma valida")


func test_extrair_horarios_txt_teorica_sem_letra_casa_com_subturma() -> void:
	# Caso al0376 do card: o txt so tem a teorica (sem letra) e o historico grava a subturma.
	var horarios_txt: Array = [
		{"disciplina": "Nome Ficticio (al0376)", "turma": "T20"},
	]
	var matriculada_com_turma: Dictionary = {
		"matriculado_agora": [["al0376", "20A"]],
		"matriculado_agora_aproveitamento": [],
	}
	var disc_cursaveis: Dictionary = {"matriculado_agora": [], "matriculavel": []}

	var resultado: Dictionary = _analise.extrair_horarios_txt(horarios_txt, matriculada_com_turma, disc_cursaveis)

	assert_eq(resultado["matriculado_agora"].size(), 1, "a teorica sem letra deve casar com a subturma do historico")
	assert_true(resultado["matriculavel"].is_empty(), "a linha casada nao pode duplicar em matriculavel")


func test_extrair_horarios_txt_separa_subturma_do_grupo_errado() -> void:
	# Caso al0003 do card: teorica e a subturma do proprio grupo casam; a do outro grupo nao.
	var horarios_txt: Array = [
		{"disciplina": "Nome Ficticio (al0003)", "turma": "T20"},
		{"disciplina": "Nome Ficticio (al0003)", "turma": "T20A"},
		{"disciplina": "Nome Ficticio (al0003)", "turma": "T20B"},
	]
	var matriculada_com_turma: Dictionary = {
		"matriculado_agora": [["al0003", "20A"]],
		"matriculado_agora_aproveitamento": [],
	}
	var disc_cursaveis: Dictionary = {"matriculado_agora": [], "matriculavel": []}

	var resultado: Dictionary = _analise.extrair_horarios_txt(horarios_txt, matriculada_com_turma, disc_cursaveis)

	assert_eq(resultado["matriculado_agora"].size(), 2, "teorica e subturma do proprio grupo devem casar")
	assert_eq(resultado["matriculavel"].size(), 1, "subturma do outro grupo deve cair em matriculavel")


func test_extrair_horarios_txt_turma_composta_com_letra_propagada() -> void:
	# Turma composta com letra propagada (_obter_turmas): "30/60B" -> ["30b", "60b"].
	var horarios_txt: Array = [
		{"disciplina": "Nome Ficticio (al0055)", "turma": "T30;60"},
	]
	var matriculada_com_turma: Dictionary = {
		"matriculado_agora": [["al0055", "30/60B"]],
		"matriculado_agora_aproveitamento": [],
	}
	var disc_cursaveis: Dictionary = {"matriculado_agora": [], "matriculavel": []}

	var resultado: Dictionary = _analise.extrair_horarios_txt(horarios_txt, matriculada_com_turma, disc_cursaveis)

	assert_eq(resultado["matriculado_agora"].size(), 1, "a letra propagada deve casar com a turma sem letra do txt")
	assert_true(resultado["matriculavel"].is_empty(), "a linha casada nao pode duplicar em matriculavel")


func test_extrair_horarios_txt_turma_ausente_no_txt_continua_matriculavel() -> void:
	# Non-goal do card: turma do historico que nao existe no txt continua em matriculavel.
	var horarios_txt: Array = [
		{"disciplina": "Nome Ficticio (al0037)", "turma": "T80"},
	]
	var matriculada_com_turma: Dictionary = {
		"matriculado_agora": [["al0037", "20"]],
		"matriculado_agora_aproveitamento": [],
	}
	var disc_cursaveis: Dictionary = {"matriculado_agora": [], "matriculavel": []}

	var resultado: Dictionary = _analise.extrair_horarios_txt(horarios_txt, matriculada_com_turma, disc_cursaveis)

	assert_true(resultado["matriculado_agora"].is_empty(), "numero diferente nao pode casar")
	assert_eq(resultado["matriculavel"].size(), 1, "a linha sem casamento deve continuar em matriculavel")



func test_turmas_sem_correspondencia_turma_unica_divergente() -> void:
	var itens: Array[Dictionary] = _itens(_cenario_turma_unica())
	assert_eq(itens.size(), 1, "uma divergencia gera um item")
	assert_eq(itens[0], {"codigo": "al2126", "nome": "Nome Ficticio", "turma_historico": "20",
		"turmas_txt": ["T80"], "discentes": 1})


func test_turmas_sem_correspondencia_composta_lista_todas_as_turmas_do_txt() -> void:
	var itens: Array[Dictionary] = _itens(_cenario_composta())
	assert_eq(itens.size(), 1)
	assert_eq(itens[0]["turma_historico"], "20/80")
	assert_eq(itens[0]["turmas_txt"], ["T30;60", "T90"])
	assert_eq(itens[0]["discentes"], 2)


func test_turmas_sem_correspondencia_ignora_turma_que_casa_pela_regra_0006() -> void:
	var itens: Array[Dictionary] = _itens(_cenario_casam())
	assert_eq(itens.size(), 0, "20A x T20, 20 x T20A, 30/60 x T30;60 e 20/80 x T80 casam")


func test_turmas_sem_correspondencia_agrupa_discentes_da_mesma_turma() -> void:
	var itens: Array[Dictionary] = _itens(_cenario_dois_discentes())
	assert_eq(itens.size(), 1)
	assert_eq(itens[0]["discentes"], 2)


func test_turmas_sem_correspondencia_fan_out_nao_infla_contagem() -> void:
	var itens: Array[Dictionary] = _itens(_cenario_fan_out())
	assert_eq(itens.size(), 1)
	assert_eq(itens[0]["discentes"], 1)
	var repetido: Dictionary = {"matricula_ficticia_1": {
		"matriculado_agora": [["al2126", "20"], ["al2126", "20"]],
		"matriculado_agora_aproveitamento": [["al2126", "20"]],
	}}
	var direto: Array[Dictionary] = _analise.turmas_sem_correspondencia([_linha_txt("al2126", "T80")], repetido)
	assert_eq(direto.size(), 1)
	assert_eq(direto[0]["discentes"], 1)


func test_turmas_sem_correspondencia_turmas_distintas_geram_itens_distintos() -> void:
	var itens: Array[Dictionary] = _itens(_cenario_turmas_distintas())
	assert_eq(itens.size(), 2)
	assert_eq(itens[0]["turma_historico"], "20")
	assert_eq(itens[1]["turma_historico"], "40")


func test_turmas_sem_correspondencia_ignora_disciplina_sem_linha_no_txt() -> void:
	assert_eq(_itens(_cenario_sem_linha_no_txt()).size(), 0)


func test_turmas_sem_correspondencia_avalia_matricula_por_aproveitamento() -> void:
	var cenario: Dictionary = _cenario_aproveitamento()
	var por_discente: Dictionary = _analise.matriculadas_com_turma_por_discente( \
		cenario["historico"], cenario["condicoes_discentes"])
	assert_eq(por_discente["matricula_ficticia_1"]["matriculado_agora"].size(), 1, "pre-condicao")
	assert_eq(por_discente["matricula_ficticia_2"]["matriculado_agora_aproveitamento"].size(), 1, "pre-condicao")
	var itens: Array[Dictionary] = _analise.turmas_sem_correspondencia(cenario["horarios_txt"], por_discente)
	assert_eq(itens.size(), 1)
	assert_eq(itens[0]["discentes"], 2)


func test_turmas_sem_correspondencia_turma_vazia_gera_item() -> void:
	var itens: Array[Dictionary] = _itens(_cenario_turma_vazia())
	assert_eq(itens.size(), 1, "codturma vazio e ausente caem no mesmo item")
	assert_eq(itens[0]["turma_historico"], "")
	assert_eq(itens[0]["discentes"], 2)


func test_turmas_sem_correspondencia_entradas_vazias_devolvem_lista_vazia() -> void:
	var cenario: Dictionary = _cenario_turma_unica()
	var por_discente: Dictionary = _analise.matriculadas_com_turma_por_discente( \
		cenario["historico"], cenario["condicoes_discentes"])
	assert_eq(_analise.turmas_sem_correspondencia([], por_discente).size(), 0)
	assert_eq(_analise.turmas_sem_correspondencia(cenario["horarios_txt"], {}).size(), 0)
	var aprovado: Dictionary = {"matricula_ficticia_1": _aluno([_dado("al2126", "20", "aprovado")])}
	assert_eq(_analise.turmas_sem_correspondencia(cenario["horarios_txt"], \
		_analise.matriculadas_com_turma_por_discente(aprovado, {})).size(), 0)


func test_turmas_sem_correspondencia_ordena_por_codigo_e_turma() -> void:
	var itens: Array[Dictionary] = _itens(_cenario_ordem())
	var pares: Array = []
	for item in itens:
		pares.append([item["codigo"], item["turma_historico"]])
	assert_eq(pares, [["al0037", "20/80"], ["al0037", "40"], ["al2126", "20"], ["al2129", "20"]])


func test_turmas_sem_correspondencia_coerente_com_extrair_horarios_txt() -> void:
	var cenarios: Dictionary = {
		"turma_unica": _cenario_turma_unica(), "composta": _cenario_composta(), "casam": _cenario_casam(),
		"dois_discentes": _cenario_dois_discentes(), "fan_out": _cenario_fan_out(),
		"turmas_distintas": _cenario_turmas_distintas(), "sem_linha": _cenario_sem_linha_no_txt(),
		"aproveitamento": _cenario_aproveitamento(), "turma_vazia": _cenario_turma_vazia(),
		"ordem": _cenario_ordem(), "misto": _cenario_misto(),
	}
	for nome in cenarios.keys():
		var cenario: Dictionary = cenarios[nome]
		var por_discente: Dictionary = _analise.matriculadas_com_turma_por_discente( \
			cenario["historico"], cenario["condicoes_discentes"])
		var itens: Array[Dictionary] = _analise.turmas_sem_correspondencia(cenario["horarios_txt"], por_discente)
		var codigos_txt: Dictionary = {}
		for linha in cenario["horarios_txt"]:
			codigos_txt[_analise.horariosexe.extrair_cod_horarios_txt(linha["disciplina"])] = true
		var esperado: Dictionary = {}
		for matricula in por_discente.keys():
			var disc: Dictionary = {"matriculado_agora": [], "matriculado_agora_aproveitamento": [], "matriculavel": []}
			var resultado: Dictionary = _analise.extrair_horarios_txt(cenario["horarios_txt"], por_discente[matricula], disc)
			for condicao in por_discente[matricula].keys():
				for par in por_discente[matricula][condicao]:
					var sem_linha: bool = true
					for linha in resultado[condicao]:
						if _analise.horariosexe.extrair_cod_horarios_txt(linha["disciplina"]) == par[0]:
							sem_linha = false
					if codigos_txt.has(par[0]) and sem_linha:
						var chave: String = par[0] + "|" + str(par[1])
						if not esperado.has(chave):
							esperado[chave] = {}
						esperado[chave][matricula] = true
		assert_eq(itens.size(), esperado.size(), "cenario " + nome + ": quantidade de itens")
		for item in itens:
			var chave_item: String = item["codigo"] + "|" + item["turma_historico"]
			assert_true(esperado.has(chave_item), "cenario " + nome + ": item inesperado " + chave_item)
			if esperado.has(chave_item):
				assert_eq(item["discentes"], esperado[chave_item].size(), "cenario " + nome + ": contagem de " + chave_item)


func test_matriculadas_com_turma_por_discente_inclui_todo_o_historico() -> void:
	var historico: Dictionary = {
		"matricula_ficticia_1": _aluno([_dado("al2126", "20"), _dado("al0001", "10", "aprovado")]),
		"matricula_ficticia_2": _aluno([_dado("al0001", "10", "aprovado")]),
		"matricula_ficticia_3": _aluno([_dado("al0037", "30")]),
	}
	var condicoes: Dictionary = {"matricula_ficticia_1": {"matriculado_agora": ["al2126"]}}
	var resultado: Dictionary = _analise.matriculadas_com_turma_por_discente(historico, condicoes)
	assert_eq(resultado.size(), 3)
	assert_eq(resultado["matricula_ficticia_1"]["matriculado_agora"], [["al2126", "20"]])
	assert_eq(resultado["matricula_ficticia_1"]["matriculado_agora_aproveitamento"], [])
	assert_eq(resultado["matricula_ficticia_2"]["matriculado_agora"], [])
	assert_eq(resultado["matricula_ficticia_3"]["matriculado_agora_aproveitamento"], [["al0037", "30"]])


func test_turmas_sem_correspondencia_item_nao_carrega_dado_de_discente() -> void:
	for item in _itens(_cenario_ordem()):
		var chaves: Array = item.keys()
		chaves.sort()
		assert_eq(chaves, ["codigo", "discentes", "nome", "turma_historico", "turmas_txt"])


func test_turmas_sem_correspondencia_nao_muta_entradas() -> void:
	var cenario: Dictionary = _cenario_ordem()
	var copia: Dictionary = cenario.duplicate(true)
	var por_discente: Dictionary = _analise.matriculadas_com_turma_por_discente( \
		cenario["historico"], cenario["condicoes_discentes"])
	var por_discente_copia: Dictionary = por_discente.duplicate(true)
	_analise.turmas_sem_correspondencia(cenario["horarios_txt"], por_discente)
	assert_eq(cenario, copia)
	assert_eq(por_discente, por_discente_copia)


# Prova o aviso de turma sem correspondencia (Cards/0007-aviso-turma-sem-correspondencia-horarios).
func _linha_txt(codigo: String, turma: String, professor: String = "Maria da Silva Souza") -> Dictionary:
	return {"disciplina": "Nome Ficticio (" + codigo + ")", "turma": turma, "professor": professor}


func _dado(codigo: String, turma: String, situacao: String = "matriculado", professor: String = "") -> Dictionary:
	var dado: Dictionary = {"situacao": situacao, "codigocurriculo": codigo, "codturma": turma}
	if not professor.is_empty():
		dado["professor"] = professor
	return dado


func _aluno(dados: Array) -> Dictionary:
	return {"nomedoaluno": "aluno ficticio", "dados": dados}


func _itens(cenario: Dictionary) -> Array[Dictionary]:
	var por_discente: Dictionary = _analise.matriculadas_com_turma_por_discente( \
		cenario["historico"], cenario["condicoes_discentes"])
	return _analise.turmas_sem_correspondencia(cenario["horarios_txt"], por_discente)


func _cenario_turma_unica() -> Dictionary:
	return {
		"horarios_txt": [_linha_txt("al2126", "T80")],
		"historico": {"matricula_ficticia_1": _aluno([_dado("al2126", "20")])},
		"condicoes_discentes": {"matricula_ficticia_1": {"matriculado_agora": ["al2126"]}},
	}


func _cenario_composta() -> Dictionary:
	return {
		"horarios_txt": [_linha_txt("al0037", "T90"), _linha_txt("al0037", "T30;60")],
		"historico": {
			"matricula_ficticia_1": _aluno([_dado("al0037", "20/80")]),
			"matricula_ficticia_2": _aluno([_dado("al0037", "20/80")]),
		},
		"condicoes_discentes": {
			"matricula_ficticia_1": {"matriculado_agora": ["al0037"]},
			"matricula_ficticia_2": {"matriculado_agora": ["al0037"]},
		},
	}


func _cenario_casam() -> Dictionary:
	return {
		"horarios_txt": [_linha_txt("al0001", "T20"), _linha_txt("al0002", "T20A"), _linha_txt("al0003", "T30;60"), _linha_txt("al0004", "T80")],
		"historico": {"matricula_ficticia_1": _aluno([
			_dado("al0001", "20A"), _dado("al0002", "20"), _dado("al0003", "30/60"), _dado("al0004", "20/80"),
		])},
		"condicoes_discentes": {"matricula_ficticia_1": {"matriculado_agora": ["al0001", "al0002", "al0003", "al0004"]}},
	}


func _cenario_dois_discentes() -> Dictionary:
	return {
		"horarios_txt": [_linha_txt("al2126", "T80")],
		"historico": {
			"matricula_ficticia_1": _aluno([_dado("al2126", "20")]),
			"matricula_ficticia_2": _aluno([_dado("al2126", "20")]),
		},
		"condicoes_discentes": {
			"matricula_ficticia_1": {"matriculado_agora": ["al2126"]},
			"matricula_ficticia_2": {"matriculado_agora": ["al2126"]},
		},
	}


func _cenario_fan_out() -> Dictionary:
	return {
		"horarios_txt": [_linha_txt("al2126", "T80")],
		"historico": {"matricula_ficticia_1": _aluno([
			_dado("al2126", "20", "matriculado", "Maria da Silva Souza"),
			_dado("al2126", "20", "matriculado", "Joao Pereira Lima"),
		])},
		"condicoes_discentes": {"matricula_ficticia_1": {"matriculado_agora": ["al2126"]}},
	}


func _cenario_turmas_distintas() -> Dictionary:
	return {
		"horarios_txt": [_linha_txt("al2126", "T80")],
		"historico": {
			"matricula_ficticia_1": _aluno([_dado("al2126", "20")]),
			"matricula_ficticia_2": _aluno([_dado("al2126", "40")]),
		},
		"condicoes_discentes": {
			"matricula_ficticia_1": {"matriculado_agora": ["al2126"]},
			"matricula_ficticia_2": {"matriculado_agora": ["al2126"]},
		},
	}


func _cenario_sem_linha_no_txt() -> Dictionary:
	return {
		"horarios_txt": [_linha_txt("al0001", "T10")],
		"historico": {"matricula_ficticia_1": _aluno([_dado("al2126", "20")])},
		"condicoes_discentes": {"matricula_ficticia_1": {"matriculado_agora": ["al2126"]}},
	}


func _cenario_aproveitamento() -> Dictionary:
	return {
		"horarios_txt": [_linha_txt("al2126", "T80")],
		"historico": {
			"matricula_ficticia_1": _aluno([_dado("al2126", "20")]),
			"matricula_ficticia_2": _aluno([_dado("al2126", "20")]),
		},
		"condicoes_discentes": {
			"matricula_ficticia_1": {"matriculado_agora": ["al2126"]},
			"matricula_ficticia_2": {"matriculado_agora": []},
		},
	}


func _cenario_turma_vazia() -> Dictionary:
	return {
		"horarios_txt": [_linha_txt("al2126", "T80")],
		"historico": {
			"matricula_ficticia_1": _aluno([_dado("al2126", "")]),
			"matricula_ficticia_2": _aluno([{"situacao": "matriculado", "codigocurriculo": "al2126"}]),
		},
		"condicoes_discentes": {
			"matricula_ficticia_1": {"matriculado_agora": ["al2126"]},
			"matricula_ficticia_2": {"matriculado_agora": ["al2126"]},
		},
	}


func _cenario_ordem() -> Dictionary:
	return {
		"horarios_txt": [_linha_txt("al2129", "T80"), _linha_txt("al0037", "T90"), _linha_txt("al2126", "T80")],
		"historico": {
			"matricula_ficticia_1": _aluno([_dado("al2129", "20"), _dado("al0037", "40")]),
			"matricula_ficticia_2": _aluno([_dado("al2126", "20"), _dado("al0037", "20/80")]),
		},
		"condicoes_discentes": {
			"matricula_ficticia_1": {"matriculado_agora": ["al2129", "al0037"]},
			"matricula_ficticia_2": {"matriculado_agora": ["al2126", "al0037"]},
		},
	}


func _cenario_misto() -> Dictionary:
	return {
		"horarios_txt": [_linha_txt("al2126", "T80")],
		"historico": {
			"matricula_ficticia_1": _aluno([_dado("al2126", "80")]),
			"matricula_ficticia_2": _aluno([_dado("al2126", "20")]),
		},
		"condicoes_discentes": {
			"matricula_ficticia_1": {"matriculado_agora": ["al2126"]},
			"matricula_ficticia_2": {"matriculado_agora": ["al2126"]},
		},
	}
