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
