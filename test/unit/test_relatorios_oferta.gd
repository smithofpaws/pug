extends GutTest
## Prova a fiacao de [method RelatoriosOferta.verificar_carga_horaria] com [CargaDocente]
## (Cards/0008-carga-horaria-lista-oficial-professores). Terminal falso e dados ficticios (curso zz).

const CONFIG: Dictionary = {"ch_minimo": 8.0, "ch_ideal": 12.0, "ch_maximo": 20.0}
const CURSOS: Dictionary = {
	"alzz": {"nome": "Curso Ficticio Zeta", "prefixos_semestre": ["zz"], "turmas": [20.0]},
}
const HISTORICO: Dictionary = {
	"Carla_Ficticia_Dias": {"zz0001": {"2025": {"1": [{"turma": [20.0]}]}}},
}
const RODAPE: String = "Minimo: 8 cr | Ideal: ate 12 cr | Maximo absoluto: 20 cr"


class TerminalFalso extends Node:
	var registros: Array[Dictionary] = []

	func titulo(texto: String, _limpar: bool = false) -> void:
		registros.append({"texto": "# " + texto, "token": "alerta"})

	func secao(texto: String) -> void:
		registros.append({"texto": "## " + texto, "token": "alerta"})

	func item(texto: String, nivel: int = 0, token: String = "padrao", _bg: String = "") -> void:
		registros.append({"texto": "  ".repeat(nivel) + "- " + texto, "token": token})

	func linha(texto: String, token: String = "padrao") -> void:
		registros.append({"texto": texto, "token": token})

	func espaco() -> void:
		registros.append({"texto": "", "token": "padrao"})

	func text_edit(texto: String, token: String = "padrao", _nl: bool = true, _limpar: bool = false) -> void:
		registros.append({"texto": texto, "token": token})

	func registrar_meta(_chave: String, _texto_bbcode: String) -> void:
		pass


func test_verificar_carga_horaria_imprime_lista_oficial_com_zero_cr() -> void:
	var m := _montar()
	assert_eq(m[2].professores_do_curso("alzz"), {"Carla Ficticia Dias": true})
	m[0].verificar_carga_horaria({"Carla Ficticia Dias": 10}, "alzz", {"Ana Ficticia Costa": true})
	var itens := _itens(m[1])
	assert_eq(itens.size(), 2)
	assert_eq(itens[0], {"texto": "- Carla Ficticia Dias: 10 cr — OK", "token": "sucesso"})
	assert_eq(itens[1], {"texto": "- Ana Ficticia Costa: 0 cr — abaixo do minimo (8 cr)", "token": "aviso"})
	assert_true(_tem_texto(m[1], RODAPE))


func test_verificar_carga_horaria_plano_vazio_mostra_nenhum_professor_alocado() -> void:
	var m := _montar()
	m[0].verificar_carga_horaria({}, "alzz", {"Ana Ficticia Costa": true})
	assert_true(_tem_texto(m[1], "Nenhum professor alocado."))
	assert_eq(_itens(m[1]).size(), 0)
	for reg in m[1].registros:
		assert_false((reg["texto"] as String).contains("Ana Ficticia Costa"))


func test_verificar_carga_horaria_sem_ninguem_do_curso_mantem_mensagem() -> void:
	var m := _montar()
	m[0].verificar_carga_horaria({"Edu Ficticio Neves": 6}, "alzz", {})
	assert_true(_tem_texto(m[1], "Nenhum professor alocado que tenha lecionado para o curso."))
	assert_eq(_itens(m[1]).size(), 0)


func test_verificar_carga_horaria_sem_filtro_ignora_lista() -> void:
	var m := _montar()
	m[0].verificar_carga_horaria({"Edu Ficticio Neves": 6}, "", {"Ana Ficticia Costa": true})
	var itens := _itens(m[1])
	assert_eq(itens.size(), 1)
	assert_eq(itens[0]["texto"], "- Edu Ficticio Neves: 6 cr — abaixo do minimo (8 cr)")
	for reg in m[1].registros:
		assert_false((reg["texto"] as String).begins_with("Filtro curso"))


func test_verificar_carga_horaria_mantem_rotulos_de_status() -> void:
	var m := _montar()
	m[0].verificar_carga_horaria({"Ana Ficticia Costa": 21, "Bruno Ficticio Alves": 13,
		"Carla Ficticia Dias": 10, "Davi Ficticio Lopes": 7})
	var itens := _itens(m[1])
	assert_eq(itens.size(), 4)
	assert_eq(itens[0], {"texto": "- Ana Ficticia Costa: 21 cr — ACIMA DO MAXIMO (20 cr)", "token": "erro"})
	assert_eq(itens[1], {"texto": "- Bruno Ficticio Alves: 13 cr — acima do ideal (12 cr)", "token": "aviso"})
	assert_eq(itens[2], {"texto": "- Carla Ficticia Dias: 10 cr — OK", "token": "sucesso"})
	assert_eq(itens[3], {"texto": "- Davi Ficticio Lopes: 7 cr — abaixo do minimo (8 cr)", "token": "aviso"})


func _montar() -> Array:
	var terminal := TerminalFalso.new()
	autofree(terminal)
	var afinidade := AnaliseAfinidade.new()
	afinidade.configurar(HISTORICO, CURSOS, {}, 15, [])
	var relatorio := RelatoriosOferta.new()
	relatorio.configurar(terminal, afinidade, AnaliseHistorico.new(), {}, [] as Array[String], CONFIG, CURSOS)
	return [relatorio, terminal, afinidade]


func _itens(terminal: TerminalFalso) -> Array[Dictionary]:
	var itens: Array[Dictionary] = []
	for reg in terminal.registros:
		if (reg["texto"] as String).begins_with("- "):
			itens.append(reg)
	return itens


func _tem_texto(terminal: TerminalFalso, texto: String) -> bool:
	for reg in terminal.registros:
		if reg["texto"] == texto:
			return true
	return false
