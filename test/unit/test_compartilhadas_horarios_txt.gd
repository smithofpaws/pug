extends GutTest
## Prova que a disciplina compartilhada do horarios.txt (semestre "EC03;EMExtra", "EE03;EC03"...)
## casa com o card que o planejamento.csv criou para ela
## (Cards/0011-compartilhadas-horarios-txt). Cada teste de AC passa pela funcao publica de ponta a
## ponta; o planejamento vem do leitor real do CSV, para provar a paridade das chaves entre os dois
## arquivos. Fixtures ficticias, geradas em memoria e gravadas em user://.

const RAIZ: String = "user://teste_0011/"
const DIAS: Array[String] = ["Segunda", "Terca", "Quarta", "Quinta", "Sexta"]
const HORAS: Array[String] = ["07:30", "08:30", "09:30", "10:30", "13:30", "14:30"]
const CABECALHO_CSV: String = "n,semestre,codigo,ch,matricula,Maria da Silva Souza,Carlos Ficticio Lima"
const CABECALHO_TXT: String = "1,\" \",\" \",\" \",\" \",\" \",\" \",\" \",\" \",\" \",1,1,1"

var _configuracao_base_original: Dictionary

func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(RAIZ)
	_configuracao_base_original = GV.configuracao_base
	GV.configuracao_base = {"dias_semana": DIAS, "horarios_aula": HORAS}

func after_each() -> void:
	GV.configuracao_base = _configuracao_base_original
	_limpar_raiz()

# --- Nao regressao: comportamento que ja vale hoje ---

func test_linha_sem_parte_do_curso_continua_descartada() -> void:
	var ap: ArquivosPlanejamento = _ap()
	_gravar_txt([
		_linha_txt("Maria da Silva Souza", "Sala 101", "EE01;EM01", "07:30", "Segunda", "AL0101"),
		_linha_txt("Maria da Silva Souza", "Sala 101", "EE01;EM01", "08:30", "Segunda", "AL0101"),
		_linha_txt("Maria da Silva Souza", "Sala 102", "EC07", "09:30", "Terca", "AL0395"),
		_linha_txt("Maria da Silva Souza", "Sala 102", "EC07", "10:30", "Terca", "AL0395"),
	])
	var prefixos: Array[String] = ["ec"]
	var plano: Dictionary = _preparar(ap, prefixos)
	assert_true(plano["valido"])
	assert_eq(_alocacoes_do_codigo(plano, "al0101").size(), 0, "linha fora do curso nao vira alocacao")
	assert_eq(_cards_do_codigo(plano, "al0101").size(), 0, "linha fora do curso nao vira card")
	assert_eq(plano["ignoradas"], 0)

func test_linha_nao_compartilhada_mantem_a_chave() -> void:
	var prefixos: Array[String] = ["ec"]
	# Com card no planejamento.
	var ap_csv: ArquivosPlanejamento = _ap()
	_gravar_csv(["1,EC07,AL0395 DISCIPLINA FICTICIA C,2,,2,"])
	assert_true(ap_csv.carregar_planejamento(RAIZ, prefixos))
	_gravar_txt([
		_linha_txt("Maria da Silva Souza", "Sala 101", "EC07", "07:30", "Segunda", "AL0395"),
		_linha_txt("Maria da Silva Souza", "Sala 101", "EC07", "08:30", "Segunda", "AL0395"),
	])
	var plano_csv: Dictionary = _preparar(ap_csv, prefixos)
	assert_eq(plano_csv["alocacoes"].size(), 2)
	for item in plano_csv["alocacoes"]:
		assert_eq(item["chave"], "al0395_ec07")
		assert_eq(item["aloc"]["chave"], "al0395_ec07")
		assert_eq(item["aloc"]["semestre"], "EC07")
	assert_eq(plano_csv["cards_novos"].size(), 0)
	# Sem card no planejamento: o card nasce com o campo do txt.
	var plano_sem: Dictionary = _preparar(_ap(), prefixos)
	assert_eq(plano_sem["alocacoes"].size(), 2)
	for item in plano_sem["alocacoes"]:
		assert_eq(item["chave"], "al0395_ec07")
		assert_eq(item["aloc"]["semestre"], "EC07")
	assert_eq(plano_sem["cards_novos"].size(), 1)
	assert_eq(plano_sem["cards_novos"][0]["chave"], "al0395_ec07")
	assert_eq(plano_sem["cards_novos"][0]["sem"], "EC07")
	assert_eq(plano_sem["cards_novos"][0]["oferta"], "EC07")

func test_import_de_referencia_mantem_o_campo_inteiro() -> void:
	var ap: ArquivosPlanejamento = _ap()
	var prefixos: Array[String] = ["ec"]
	_gravar_csv(["1,EC03;EE03;ET03;EM03,AL0019 DISCIPLINA FICTICIA D,4,,4,"])
	assert_true(ap.carregar_planejamento(RAIZ, prefixos))
	assert_true(ap._planejamento_csv.has("al0019_ec03"), "sanidade: o card proprio existe")
	_gravar_txt([
		_linha_txt("Carlos Ficticio Lima", "Sala 201", "EC03;EE03;ET03;EM03", "07:30", "Segunda", "AL0019"),
		_linha_txt("Carlos Ficticio Lima", "Sala 201", "EC03;EE03;ET03;EM03", "08:30", "Segunda", "AL0019"),
	])
	var sem_filtro: Array[String] = []
	var plano: Dictionary = _preparar(ap, sem_filtro)
	var chave_campo: String = "al0019_ec03;ee03;et03;em03"
	assert_eq(plano["alocacoes"].size(), 2)
	for item in plano["alocacoes"]:
		assert_ne(item["chave"], "al0019_ec03", "nao se anexa ao card proprio")
		assert_eq(item["chave"], chave_campo)
	assert_eq(plano["cards_novos"].size(), 1)
	assert_eq(plano["cards_novos"][0]["chave"], chave_campo)
	assert_eq(plano["cards_novos"][0]["sem"], "EC03;EE03;ET03;EM03")
	assert_eq(plano["cards_novos"][0]["oferta"], "EC03;EE03;ET03;EM03")
	assert_false(ap._planejamento_csv.has(chave_campo), "a referencia entra como disciplina nova")

# --- Nucleo puro (apoio) ---

func test_parte_receptora_respeita_ordem_filtro_e_caixa() -> void:
	var delim: Array = [";", "/"]
	var duas: Dictionary = {"al0022_ee03": "", "al0022_ec03": ""}
	var prefixos_ec_ee: Array = ["ec", "ee"]
	var prefixos_ec: Array = ["ec"]
	var prefixos_vazios: Array = []
	# A ordem do campo decide quando mais de uma parte passa no filtro e tem card.
	assert_eq(ArquivosPlanejamento.parte_receptora_txt("AL0022", "EE03;EC03", duas, prefixos_ec_ee, delim), {"chave": "al0022_ee03", "semestre": "EE03"})
	assert_eq(ArquivosPlanejamento.parte_receptora_txt("AL0022", "EC03;EE03", duas, prefixos_ec_ee, delim), {"chave": "al0022_ec03", "semestre": "EC03"})
	# O filtro tira as partes de outros cursos, mesmo que elas tenham card.
	assert_eq(ArquivosPlanejamento.parte_receptora_txt("AL0022", "EE03;EC03", duas, prefixos_ec, delim), {"chave": "al0022_ec03", "semestre": "EC03"})
	# Bordas aparadas e caixa mista: a chave sai minuscula, o semestre guarda a caixa do txt.
	assert_eq(ArquivosPlanejamento.parte_receptora_txt("AL0390", "EA09; ee09 ;EC07", {"al0390_ec07": ""}, prefixos_ec, delim), {"chave": "al0390_ec07", "semestre": "EC07"})
	# ECExtra casa com o prefixo ec, como o CSV o grava.
	assert_eq(ArquivosPlanejamento.parte_receptora_txt("AL0375", "EM03;ECExtra", {"al0375_ecextra": ""}, prefixos_ec, delim), {"chave": "al0375_ecextra", "semestre": "ECExtra"})
	# Sem card, vale a primeira parte que passa no filtro.
	assert_eq(ArquivosPlanejamento.parte_receptora_txt("AL0015", "EMExtra;EC03", {}, prefixos_ec, delim), {"chave": "al0015_ec03", "semestre": "EC03"})
	# Prefixos vazios: toda parte e candidata.
	assert_eq(ArquivosPlanejamento.parte_receptora_txt("AL0015", "EC03;EMExtra", {"al0015_emextra": ""}, prefixos_vazios, delim), {"chave": "al0015_emextra", "semestre": "EMExtra"})
	assert_eq(ArquivosPlanejamento.parte_receptora_txt("AL0015", "EC03;EMExtra", {}, prefixos_vazios, delim), {"chave": "al0015_ec03", "semestre": "EC03"})
	# Sem nenhuma parte candidata, a chave vem vazia.
	assert_eq(ArquivosPlanejamento.parte_receptora_txt("AL0015", "", {}, prefixos_vazios, delim)["chave"], "")
	assert_eq(ArquivosPlanejamento.parte_receptora_txt("AL0101", "EE01;EM01", {}, prefixos_ec, delim)["chave"], "")

func test_desempate_cai_na_base_sem_oferta_igual() -> void:
	var delim: Array = [";", "/"]
	# Base inexistente: e um card novo, devolve a base.
	assert_eq(ArquivosPlanejamento.desempatar_chave_duplicada("al0390_ec07", "EC07", {}, delim), "al0390_ec07")
	# Nenhuma oferta igual: devolve a base.
	var sem_igual: Dictionary = {"al0390_ec07": "ea09;ee09;ec07", "al0390_ec07_2": "ec07;et07"}
	assert_eq(ArquivosPlanejamento.desempatar_chave_duplicada("al0390_ec07", "EC07", sem_igual, delim), "al0390_ec07")
	# Oferta igual como conjunto: ordem, espacos e caixa nao contam.
	var variadas: Dictionary = {"al0390_ec07": "ea09; ee09; ec07", "al0390_ec07_2": "ec07"}
	assert_eq(ArquivosPlanejamento.desempatar_chave_duplicada("al0390_ec07", "EC07;EE09 ;eA09", variadas, delim), "al0390_ec07")
	assert_eq(ArquivosPlanejamento.desempatar_chave_duplicada("al0390_ec07", " ec07 ", variadas, delim), "al0390_ec07_2")
	# Duas duplicadas com a mesma oferta: a primeira do grupo.
	var repetidas: Dictionary = {"al0390_ec07": "ea09;ec07", "al0390_ec07_2": "ec07", "al0390_ec07_3": "ec07"}
	assert_eq(ArquivosPlanejamento.desempatar_chave_duplicada("al0390_ec07", "EC07", repetidas, delim), "al0390_ec07_2")
	# O grupo para na primeira lacuna, como o gerador de chaves do CSV.
	var com_lacuna: Dictionary = {"al0390_ec07": "ea09;ec07", "al0390_ec07_3": "ec07"}
	assert_eq(ArquivosPlanejamento.desempatar_chave_duplicada("al0390_ec07", "EC07", com_lacuna, delim), "al0390_ec07")

# --- Modo curso: a compartilhada usa a chave que o planejamento.csv gerou ---

func test_compartilhada_casa_com_card_do_planejamento_csv() -> void:
	var ap: ArquivosPlanejamento = _ap()
	var prefixos: Array[String] = ["ec"]
	_gravar_csv(["1,EC03;EMExtra,AL0015 DISCIPLINA FICTICIA A,4,,4,"])
	assert_true(ap.carregar_planejamento(RAIZ, prefixos))
	assert_true(ap._planejamento_csv.has("al0015_ec03"), "sanidade: o CSV gera uma chave por parte")
	_gravar_txt(_linhas_al0015("EC03;EMExtra"))
	var plano: Dictionary = _preparar(ap, prefixos)
	var alocacoes: Array = _alocacoes_do_codigo(plano, "al0015")
	assert_eq(alocacoes.size(), 4)
	for item in alocacoes:
		assert_eq(item["chave"], "al0015_ec03")
		assert_eq(item["aloc"]["chave"], "al0015_ec03")
		assert_eq(item["aloc"]["semestre"], "EC03")
	assert_eq(_cards_do_codigo(plano, "al0015").size(), 0, "o card do planejamento recebe; nao nasce card-fantasma")

func test_filtro_aceita_curso_fora_do_comeco_do_campo() -> void:
	var ap: ArquivosPlanejamento = _ap()
	var prefixos: Array[String] = ["ec"]
	_gravar_csv(["1,EE03;EC03,AL0022 DISCIPLINA FICTICIA E,2,,2,"])
	assert_true(ap.carregar_planejamento(RAIZ, prefixos))
	assert_true(ap._planejamento_csv.has("al0022_ec03"))
	_gravar_txt([
		_linha_txt("Maria da Silva Souza", "Sala 101", "EE03;EC03", "07:30", "Segunda", "AL0022"),
		_linha_txt("Maria da Silva Souza", "Sala 101", "EE03;EC03", "08:30", "Segunda", "AL0022"),
	])
	var plano: Dictionary = _preparar(ap, prefixos)
	assert_true(plano["valido"], "a linha nao pode ser descartada pelo filtro")
	var alocacoes: Array = _alocacoes_do_codigo(plano, "al0022")
	assert_eq(alocacoes.size(), 2)
	for item in alocacoes:
		assert_eq(item["chave"], "al0022_ec03")
	assert_eq(plano["cards_novos"].size(), 0)

func test_campo_com_espacos_e_caixa_mista_casa_com_card() -> void:
	var ap: ArquivosPlanejamento = _ap()
	var prefixos: Array[String] = ["ec"]
	_gravar_csv([
		"1,EA09; EE09; EC07,AL0390 DISCIPLINA FICTICIA F,2,,2,",
		"2,EC07,AL0390 DISCIPLINA FICTICIA F,2,,2,",
	])
	assert_true(ap.carregar_planejamento(RAIZ, prefixos))
	assert_eq(ap._planejamento_csv["al0390_ec07"]["oferta"], "ea09; ee09; ec07", "sanidade: o CSV guarda a celula inteira")
	assert_eq(ap._planejamento_csv["al0390_ec07_2"]["oferta"], "ec07")
	_gravar_txt([
		_linha_txt("Maria da Silva Souza", "Sala 101", "EA09; ee09 ;EC07", "07:30", "Segunda", "AL0390"),
		_linha_txt("Maria da Silva Souza", "Sala 101", "EA09; ee09 ;EC07", "08:30", "Segunda", "AL0390"),
	])
	var plano: Dictionary = _preparar(ap, prefixos)
	var alocacoes: Array = _alocacoes_do_codigo(plano, "al0390")
	assert_eq(alocacoes.size(), 2)
	for item in alocacoes:
		assert_eq(item["chave"], "al0390_ec07")
	assert_eq(plano["cards_novos"].size(), 0)

func test_varios_cursos_so_o_card_da_primeira_parte_recebe() -> void:
	var ap: ArquivosPlanejamento = _ap()
	var prefixos: Array[String] = ["ec", "ee"]
	_gravar_csv(["1,EE03;EC03,AL0022 DISCIPLINA FICTICIA E,2,,2,"])
	assert_true(ap.carregar_planejamento(RAIZ, prefixos))
	assert_true(ap._planejamento_csv.has("al0022_ee03"))
	assert_true(ap._planejamento_csv.has("al0022_ec03"))
	_gravar_txt([
		_linha_txt("Maria da Silva Souza", "Sala 101", "EE03;EC03", "07:30", "Segunda", "AL0022"),
		_linha_txt("Maria da Silva Souza", "Sala 101", "EE03;EC03", "08:30", "Segunda", "AL0022"),
	])
	var plano: Dictionary = _preparar(ap, prefixos)
	var alocacoes: Array = _alocacoes_do_codigo(plano, "al0022")
	assert_eq(alocacoes.size(), 2)
	for item in alocacoes:
		assert_eq(item["chave"], "al0022_ee03", "so o card da primeira parte recebe")
	assert_eq(plano["cards_novos"].size(), 0)

func test_chaves_duplicadas_desempatam_pela_oferta() -> void:
	var ap: ArquivosPlanejamento = _ap()
	var prefixos: Array[String] = ["ec"]
	_gravar_csv([
		"1,EA09;EE09;EC07,AL0390 DISCIPLINA FICTICIA F,2,,2,",
		"2,EC07,AL0390 DISCIPLINA FICTICIA F,2,,2,",
	])
	assert_true(ap.carregar_planejamento(RAIZ, prefixos))
	assert_eq(ap._planejamento_csv["al0390_ec07"]["oferta"], "ea09;ee09;ec07")
	assert_eq(ap._planejamento_csv["al0390_ec07_2"]["oferta"], "ec07")
	_gravar_txt([
		_linha_txt("Maria da Silva Souza", "Sala 101", "EA09;EE09;EC07", "07:30", "Segunda", "AL0390"),
		_linha_txt("Maria da Silva Souza", "Sala 101", "EA09;EE09;EC07", "08:30", "Segunda", "AL0390"),
		_linha_txt("Maria da Silva Souza", "Sala 102", "EC07", "07:30", "Terca", "AL0390"),
		_linha_txt("Maria da Silva Souza", "Sala 102", "EC07", "08:30", "Terca", "AL0390"),
	])
	var plano: Dictionary = _preparar(ap, prefixos)
	var por_celula: Dictionary = _chave_por_celula(plano)
	assert_eq(por_celula.size(), 4)
	assert_eq(por_celula["1_1"], "al0390_ec07")
	assert_eq(por_celula["2_1"], "al0390_ec07")
	assert_eq(por_celula["1_2"], "al0390_ec07_2")
	assert_eq(por_celula["2_2"], "al0390_ec07_2")
	assert_eq(plano["cards_novos"].size(), 0)

func test_sem_card_gera_um_card_novo_no_formato_do_csv() -> void:
	var ap: ArquivosPlanejamento = _ap()
	var prefixos: Array[String] = ["ec"]
	_gravar_txt(_linhas_al0015("EC03;EMExtra"))
	var plano: Dictionary = _preparar(ap, prefixos)
	assert_eq(plano["cards_novos"].size(), 1, "as quatro linhas somam num card so")
	var card: Dictionary = plano["cards_novos"][0]
	assert_eq(card["chave"], "al0015_ec03")
	assert_eq(card["sem"], "EC03")
	assert_eq(card["oferta"], "EC03;EMExtra")
	assert_eq(card["ch_total"], 4)
	var alocacoes: Array = _alocacoes_do_codigo(plano, "al0015")
	assert_eq(alocacoes.size(), 4)
	for item in alocacoes:
		assert_eq(item["chave"], "al0015_ec03")

func test_card_novo_leva_a_oferta_ao_planejamento() -> void:
	var ap: ArquivosPlanejamento = _ap()
	var prefixos: Array[String] = ["ec"]
	_gravar_txt(_linhas_al0015("EC03;EMExtra"))
	var plano: Dictionary = _preparar(ap, prefixos)
	ap.montar_planejamento_csv_do_txt(plano["cards_novos"])
	assert_true(ap._planejamento_csv.has("al0015_ec03"))
	assert_eq(ap._planejamento_csv["al0015_ec03"]["semestre"], "EC03")
	assert_eq(ap._planejamento_csv["al0015_ec03"]["oferta"], "EC03;EMExtra", "a oferta combinada nao pode ser rebaixada")

func test_variantes_do_campo_somam_no_mesmo_card_novo() -> void:
	var ap: ArquivosPlanejamento = _ap()
	var prefixos: Array[String] = ["ec"]
	_gravar_txt([
		_linha_txt("Maria da Silva Souza", "Sala 101", "EC03;EMExtra", "07:30", "Segunda", "AL0015"),
		_linha_txt("Maria da Silva Souza", "Sala 101", "EC03;EMExtra", "08:30", "Segunda", "AL0015"),
		_linha_txt("Maria da Silva Souza", "Sala 101", "EC03", "09:30", "Segunda", "AL0015"),
	])
	var plano: Dictionary = _preparar(ap, prefixos)
	assert_eq(plano["cards_novos"].size(), 1)
	assert_eq(plano["cards_novos"][0]["ch_total"], 3)
	assert_eq(plano["cards_novos"][0]["oferta"], "EC03;EMExtra", "vale a oferta da primeira linha")
	assert_eq(_alocacoes_do_codigo(plano, "al0015").size(), 3)

# --- Ida e volta pelo planejamento.json ---

func test_ida_e_volta_pelo_planejamento_json() -> void:
	var ap: ArquivosPlanejamento = _ap()
	var prefixos: Array[String] = ["ec"]
	_gravar_csv(["1,EC03;EMExtra,AL0015 DISCIPLINA FICTICIA A,4,,4,"])
	assert_true(ap.carregar_planejamento(RAIZ, prefixos))
	var linhas: Array[String] = _linhas_al0015("EC03;EMExtra")
	_gravar_txt(linhas)
	var plano: Dictionary = _preparar(ap, prefixos)
	# Mesma montagem que _popular_grade_do_txt faz: "linha_coluna" -> alocacoes da celula.
	var alocacoes: Dictionary = {}
	for item in plano["alocacoes"]:
		var celula: String = "%d_%d" % [item["linha"], item["coluna"]]
		if not alocacoes.has(celula):
			alocacoes[celula] = []
		alocacoes[celula].append(item["aloc"])
	var saida: Dictionary = ap.exportar_planejamento_json(alocacoes)
	var disciplina: Dictionary = {}
	for d in saida["disciplinas"]:
		if d["codigo"] == "al0015":
			disciplina = d
	assert_false(disciplina.is_empty(), "a al0015 tem de estar no planejamento exportado")
	assert_eq(disciplina["alocacoes"].size(), 4)
	var obtidas: Array[String] = []
	for a in disciplina["alocacoes"]:
		obtidas.append("%s|%s|%s" % [a["horario"], a["dia"], a["sala"]])
	obtidas.sort()
	var esperadas: Array[String] = ["07:30|Segunda|Sala 101", "08:30|Segunda|Sala 102", "07:30|Terca|Sala 103", "08:30|Terca|Sala 104"]
	esperadas.sort()
	assert_eq(obtidas, esperadas)
	assert_eq(disciplina["oferta"], "ec03;emextra", "a oferta combinada vem do CSV")

# --- Atualizar planejamento ---

func test_atualizar_planejamento_preserva_a_compartilhada() -> void:
	var ap: ArquivosPlanejamento = _ap()
	var prefixos: Array[String] = ["ec"]
	_gravar_csv([
		"1,EC03;EMExtra,AL0015 DISCIPLINA FICTICIA A,4,,4,",
		"2,EC07,AL0395 DISCIPLINA FICTICIA C,2,,2,",
	])
	assert_true(ap.carregar_planejamento(RAIZ, prefixos))
	var linhas: Array[String] = _linhas_al0015("EC03;EMExtra")
	linhas.append(_linha_txt("Maria da Silva Souza", "Sala 201", "EC07", "09:30", "Quarta", "AL0395"))
	linhas.append(_linha_txt("Maria da Silva Souza", "Sala 202", "EC07", "10:30", "Quarta", "AL0395"))
	_gravar_txt(linhas)
	var resultado: Dictionary = ap.mesclar_planejamento_com_horarios_txt(RAIZ + "horarios.txt")
	var da_al0015: Array[String] = _agenda_das_entries(resultado["entries"], "(AL0015)")
	da_al0015.sort()
	var esperadas: Array[String] = ["Sala 101|Segunda|07:30", "Sala 102|Segunda|08:30", "Sala 103|Terca|07:30", "Sala 104|Terca|08:30"]
	esperadas.sort()
	assert_eq(da_al0015, esperadas, "as quatro aulas mantem sala, dia e horario")
	assert_eq(_agenda_das_entries(resultado["entries"], "(AL0395)").size(), 2)
	var da_al0395: Array[String] = _agenda_das_entries(resultado["entries"], "(AL0395)")
	da_al0395.sort()
	assert_eq(da_al0395, ["Sala 201|Quarta|09:30", "Sala 202|Quarta|10:30"] as Array[String])
	for chave in resultado["removidas"]:
		assert_false(str(chave).begins_with("al0015"), "a compartilhada nao pode aparecer como removida")
	for entry in resultado["entries_removidas"]:
		assert_false(str(entry["disciplina"]).contains("(AL0015)"))

func test_atualizar_planejamento_ignora_entrada_de_referencia() -> void:
	var ap: ArquivosPlanejamento = _ap()
	var prefixos: Array[String] = ["ec"]
	_gravar_csv(["1,EE03;EC03,AL0022 DISCIPLINA FICTICIA E,2,,2,"])
	assert_true(ap.carregar_planejamento(RAIZ, prefixos))
	# Entrada de outro curso sobreposta como referencia, no formato que _aplicar_referencia grava
	# (vem do servidor, nao de um leitor de arquivo).
	ap._planejamento_csv["al0022_ee03"] = {
		"codigo": "al0022",
		"semestre": "EE03",
		"professor": ["carlos ficticio lima"],
		"ch": ["2"],
		"oferta": "EE03;EC03",
		"ch_disciplina": "2",
		"referencia": true,
		"curso_origem": "alee",
	}
	_gravar_txt([
		_linha_txt("Maria da Silva Souza", "Sala 301", "EE03;EC03", "07:30", "Sexta", "AL0022"),
		_linha_txt("Maria da Silva Souza", "Sala 302", "EE03;EC03", "08:30", "Sexta", "AL0022"),
	])
	var resultado: Dictionary = ap.mesclar_planejamento_com_horarios_txt(RAIZ + "horarios.txt")
	var do_proprio_curso: Array[String] = []
	for entry in resultado["entries"]:
		if str(entry["semestre"]).to_lower() == "ec03":
			do_proprio_curso.append("%s|%s|%s" % [entry["sala"], entry["dia"], entry["horario"]])
	do_proprio_curso.sort()
	assert_eq(do_proprio_curso, ["Sala 301|Sexta|07:30", "Sala 302|Sexta|08:30"] as Array[String], "a linha vai para o card proprio, nao para a referencia")
	for chave in resultado["removidas"]:
		assert_false(str(chave).begins_with("al0022"))

# --- Helpers ---

func _ap() -> ArquivosPlanejamento:
	var ap := ArquivosPlanejamento.new()
	ap.configurar(FileHandling.new(), AnaliseHorarios.new(), AnaliseGrades.new(), HorariosExe.new(), {}, {"planejamento": [";", "/"]}, RAIZ + "regras", {}, {})
	return ap

func _preparar(ap: ArquivosPlanejamento, prefixos: Array[String]) -> Dictionary:
	return ap.preparar_alocacoes_do_txt(RAIZ + "horarios.txt", DIAS, HORAS, HORAS.size() + 1, DIAS.size() + 1, ap._planejamento_csv.keys(), prefixos)

func _gravar_csv(linhas: Array[String]) -> void:
	_gravar_texto(RAIZ + "planejamento.csv", CABECALHO_CSV, linhas)

func _gravar_txt(linhas: Array[String]) -> void:
	_gravar_texto(RAIZ + "horarios.txt", CABECALHO_TXT, linhas)

func _gravar_texto(caminho: String, cabecalho: String, linhas: Array[String]) -> void:
	var arq := FileAccess.open(caminho, FileAccess.WRITE)
	arq.store_string(cabecalho + "\n")
	for linha in linhas:
		arq.store_string(linha + "\n")
	arq.close()

func _linha_txt(prof: String, sala: String, sem: String, hora: String, dia: String, codigo: String) -> String:
	return ",\"%s\",%s,%s,%s,%s,\"Disciplina Ficticia (%s)\",Teorica,T20,Vagas,1,1,1" % [prof, sala, sem, hora, dia, codigo]

func _alocacoes_do_codigo(plano: Dictionary, codigo: String) -> Array:
	var achadas: Array = []
	for item in plano["alocacoes"]:
		if item["aloc"]["codigo"] == codigo:
			achadas.append(item)
	return achadas

func _cards_do_codigo(plano: Dictionary, codigo: String) -> Array:
	var achados: Array = []
	for card in plano["cards_novos"]:
		if card["codigo"] == codigo:
			achados.append(card)
	return achados

# As quatro aulas da AL0015 em quatro celulas distintas da grade.
func _linhas_al0015(sem: String) -> Array[String]:
	return [
		_linha_txt("Maria da Silva Souza", "Sala 101", sem, "07:30", "Segunda", "AL0015"),
		_linha_txt("Maria da Silva Souza", "Sala 102", sem, "08:30", "Segunda", "AL0015"),
		_linha_txt("Maria da Silva Souza", "Sala 103", sem, "07:30", "Terca", "AL0015"),
		_linha_txt("Maria da Silva Souza", "Sala 104", sem, "08:30", "Terca", "AL0015"),
	]

# "sala|dia|horario" de cada entry cuja disciplina contem [param marca] (ex.: "(AL0015)").
func _agenda_das_entries(entries: Array, marca: String) -> Array[String]:
	var agenda: Array[String] = []
	for entry in entries:
		if str(entry["disciplina"]).contains(marca):
			agenda.append("%s|%s|%s" % [entry["sala"], entry["dia"], entry["horario"]])
	return agenda

# Mapa "linha_coluna" -> chave de cada alocacao do plano (uma por celula nos testes que o usam).
func _chave_por_celula(plano: Dictionary) -> Dictionary:
	var mapa: Dictionary = {}
	for item in plano["alocacoes"]:
		mapa["%d_%d" % [item["linha"], item["coluna"]]] = item["chave"]
	return mapa

func _limpar_raiz() -> void:
	var dir := DirAccess.open(RAIZ)
	if dir != null:
		for nome in dir.get_files():
			DirAccess.remove_absolute(RAIZ + nome)
	if DirAccess.dir_exists_absolute(RAIZ):
		DirAccess.remove_absolute(RAIZ)
