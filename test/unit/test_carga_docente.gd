extends GutTest
## Prova a regra de quem entra no relatorio de carga horaria (Cards/0008-carga-horaria-lista-oficial-professores).
## Fixtures inline e ficticias: cursos zz/yy/xa+xb, inexistentes; nada de arquivos/oferta/.

const CONFIG: Dictionary = {"ch_minimo": 8.0, "ch_ideal": 12.0, "ch_maximo": 20.0}
const CURSOS: Dictionary = {
	"alzz": {"nome": "Curso Ficticio Zeta", "prefixos_semestre": ["zz"], "turmas": [20.0]},
	"alyy": {"nome": "Curso Ficticio Ipsilon", "prefixos_semestre": ["yy"], "turmas": [30.0]},
	"alxx": {"nome": "Curso Ficticio Xis", "prefixos_semestre": ["xa", "xb"], "turmas": [50.0]},
}
const ANA: String = "Ana Ficticia Costa"
const BRUNO: String = "Bruno Ficticio Alves"
const CARLA: String = "Carla Ficticia Dias"
const DAVI: String = "Davi Ficticio Lopes"
const BEATRIZ: String = "Beatriz Ficticia Melo"
const EDU: String = "Edu Ficticio Neves"


func test_lista_oficial_sem_carga_entra_com_zero_abaixo_do_minimo() -> void:
	var res := _v({CARLA: 10}, "alzz", {CARLA: true}, {ANA: true})
	assert_eq(Array(res), [{"nome": CARLA, "ch": 10, "status": "ok"}, {"nome": ANA, "ch": 0, "status": "abaixo_minimo"}])


func test_lista_oficial_com_carga_que_nunca_lecionou_entra_com_carga_real() -> void:
	var hist := {CARLA: true}
	assert_false(hist.has(ANA))
	var res := _v({ANA: 10, CARLA: 14}, "alzz", hist, {ANA: true})
	assert_eq(Array(res), [{"nome": CARLA, "ch": 14, "status": "acima_ideal"}, {"nome": ANA, "ch": 10, "status": "ok"}])


func test_professor_do_historico_fora_da_lista_continua_entrando() -> void:
	var oficiais := {ANA: true}
	assert_false(oficiais.is_empty())
	assert_false(oficiais.has(CARLA))
	var res := _v({CARLA: 10}, "alzz", {CARLA: true}, oficiais)
	var achados: Array[Dictionary] = res.filter(func(i: Dictionary) -> bool: return i["nome"] == CARLA)
	assert_eq(achados.size(), 1)
	assert_eq(achados[0]["ch"], 10)


func test_professor_sem_historico_e_fora_da_lista_continua_fora() -> void:
	var carga := {EDU: 6, CARLA: 10}
	assert_eq(_nomes(_v(carga, "alzz", {CARLA: true}, {ANA: true})), [CARLA, ANA])
	assert_eq(_nomes(_v(carga, "alzz", {CARLA: true}, {})), [CARLA])


func test_sem_filtro_lista_oficial_nao_acrescenta_ninguem() -> void:
	var carga := {EDU: 6, CARLA: 10}
	var esperado := [{"nome": CARLA, "ch": 10, "status": "ok"}, {"nome": EDU, "ch": 6, "status": "abaixo_minimo"}]
	assert_eq(Array(_v(carga, "", {}, {ANA: true})), esperado)
	assert_eq(Array(_v(carga, "", {CARLA: true}, {ANA: true})), esperado)


func test_nome_da_lista_com_sublinhado_casa_com_o_plano_uma_vez() -> void:
	var oficiais := _oficiais({"zz": ["Maria_da_Silva_Souza"]}, "alzz")
	assert_eq(oficiais, {"Maria Da Silva Souza": true})
	var res := _v({"Maria Da Silva Souza": 10}, "alzz", {}, oficiais)
	assert_eq(Array(res), [{"nome": "Maria Da Silva Souza", "ch": 10, "status": "ok"}])


func test_so_entra_a_lista_dos_prefixos_do_curso_filtrado() -> void:
	var lista := {"ZZ": ["Ana_Ficticia_Costa"], "yy": ["Bruno_Ficticio_Alves"],
		"xa": ["Davi_Ficticio_Lopes"], "xb": ["Beatriz_Ficticia_Melo"]}
	var carga := {CARLA: 10}
	assert_eq(_nomes(_v(carga, "alzz", {CARLA: true}, _oficiais(lista, "alzz"))), [CARLA, ANA])
	assert_eq(_nomes(_v(carga, "alyy", {}, _oficiais(lista, "alyy"))), [BRUNO])
	assert_eq(_nomes(_v(carga, "alxx", {}, _oficiais(lista, "alxx"))), [BEATRIZ, DAVI])


func test_lista_vazia_ou_ausente_mantem_resultado_de_hoje() -> void:
	var carga := {CARLA: 10, EDU: 6}
	var esperado := [{"nome": CARLA, "ch": 10, "status": "ok"}]
	var listas: Array[Dictionary] = [{}, {"zz": []}, {"zz": "texto"}, {"yy": ["Bruno_Ficticio_Alves"]}]
	for lista: Dictionary in listas:
		var res := _v(carga, "alzz", {CARLA: true}, _oficiais(lista, "alzz"))
		assert_eq(Array(res), esperado, "lista %s" % str(lista))


func test_status_carga_nas_fronteiras_dos_limites() -> void:
	var esperado := ["abaixo_minimo", "abaixo_minimo", "ok", "ok", "acima_ideal", "acima_ideal", "acima_maximo"]
	var cargas := [0, 7, 8, 12, 13, 20, 21]
	var obtido: Array = []
	var carga_plano: Dictionary = {}
	for i in cargas.size():
		obtido.append(CargaDocente.status_carga(cargas[i], CONFIG))
		carga_plano["Prof %d" % i] = cargas[i]
	assert_eq(obtido, esperado)
	var status_itens: Array = []
	for item: Dictionary in _v(carga_plano, "", {}, {}):
		status_itens.append(item["status"])
	status_itens.reverse()
	assert_eq(status_itens, esperado.duplicate())


func test_status_carga_usa_defaults_sem_config() -> void:
	var esperado := ["abaixo_minimo", "abaixo_minimo", "ok", "ok", "acima_ideal", "acima_ideal", "acima_maximo"]
	var obtido: Array = []
	for ch in [0, 7, 8, 12, 13, 20, 21]:
		obtido.append(CargaDocente.status_carga(ch, {}))
	assert_eq(obtido, esperado)


func test_ordena_por_carga_decrescente_e_nome_no_empate() -> void:
	var carga := {BRUNO: 10, ANA: 10, CARLA: 15}
	var hist := {BRUNO: true, ANA: true, CARLA: true}
	var oficiais := {DAVI: true, BEATRIZ: true}
	assert_eq(_nomes(_v(carga, "alzz", hist, oficiais)), [CARLA, ANA, BRUNO, BEATRIZ, DAVI])
	assert_eq(_nomes(_v({BRUNO: 10, ANA: 10}, "", {}, {})), [ANA, BRUNO])


func test_plano_sem_alocacao_nao_lista_ninguem_mesmo_com_filtro_e_lista() -> void:
	assert_eq(_v({}, "alzz", {CARLA: true}, {ANA: true}), [] as Array[Dictionary])
	assert_eq(_v({}, "", {}, {ANA: true}), [] as Array[Dictionary])


func test_indexar_lista_oficial_normaliza_e_ignora_entrada_invalida() -> void:
	var idx := CargaDocente.indexar_lista_oficial({"EC": ["Maria_da_Silva_Souza", ""], "zz": "texto", "yy": 7})
	assert_eq(idx, {"ec": {"Maria Da Silva Souza": true}})


func test_lista_oficial_do_curso_vazia_sem_filtro_ou_curso_desconhecido() -> void:
	var idx := CargaDocente.indexar_lista_oficial({"zz": ["Ana_Ficticia_Costa"]})
	assert_eq(CargaDocente.lista_oficial_do_curso(idx, CURSOS, ""), {})
	assert_eq(CargaDocente.lista_oficial_do_curso(idx, CURSOS, "alww"), {})
	assert_false(CargaDocente.lista_oficial_do_curso(idx, CURSOS, "alzz").is_empty())


func test_nao_muta_entradas() -> void:
	var carga := {CARLA: 10, EDU: 6}
	var hist := {CARLA: true}
	var oficiais := {ANA: true}
	var lista_crua := {"zz": ["Ana_Ficticia_Costa"]}
	var indice := CargaDocente.indexar_lista_oficial(lista_crua)
	var copias := [carga.duplicate(true), hist.duplicate(true), oficiais.duplicate(true),
		lista_crua.duplicate(true), indice.duplicate(true)]
	_v(carga, "alzz", hist, oficiais)
	var uniao := CargaDocente.lista_oficial_do_curso(indice, CURSOS, "alzz")
	uniao["intruso"] = true
	assert_eq([carga, hist, oficiais, lista_crua, indice], copias)


func test_item_tem_exatamente_nome_ch_status() -> void:
	var res := _v({CARLA: 10}, "alzz", {CARLA: true}, {ANA: true})
	assert_false(res.is_empty())
	for item: Dictionary in res:
		var chaves := item.keys()
		chaves.sort()
		assert_eq(chaves, ["ch", "nome", "status"])
		assert_eq(typeof(item["ch"]), TYPE_INT)


func _v(carga: Dictionary, cod: String, hist: Dictionary, oficiais: Dictionary) -> Array[Dictionary]:
	return CargaDocente.verificacao_carga(carga, cod, hist, oficiais, CONFIG)


func _nomes(itens: Array[Dictionary]) -> Array:
	var nomes: Array = []
	for item: Dictionary in itens:
		nomes.append(item["nome"])
	return nomes


func _oficiais(lista_crua: Dictionary, cod: String) -> Dictionary:
	var indexada: Dictionary = CargaDocente.indexar_lista_oficial(lista_crua)
	return CargaDocente.lista_oficial_do_curso(indexada, CURSOS, cod)
