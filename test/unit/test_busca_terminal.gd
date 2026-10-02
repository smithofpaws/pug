extends GutTest
## Testes do nucleo puro da busca do Terminal ([BuscaTerminal]). Fixtures ficticias.

const TODAS: String = "#00000140"
const ATUAL: String = "#00000280"

const CASOS: Array[String] = [
	"Movido: AL0001 → [5, 3].",
	"a [x b",
	"a[lb]b[rb]c",
	"a[br]b",
	"[b]neg[/b] [i]it[/i]",
	"a [/b] b",
	"x [ y ] z",
	"lista [\"al0001\", \"al0002\"]",
	"vazio []fim",
	"[color=#00ff00]Ana Ficticia: Matriculado agora[/color] / [color=#0000ff]Bruno Ficticio: Matriculavel[/color]",
	"[bgcolor=#2e7d3280]Cálculo[/bgcolor]",
	"a[unknown=1]b[/unknown]c",
	"a[B]b[/B]c",
	"a[ b]c",
	"a[url]u[/url]c",
	"[url=chave]Cálculo[/url] numérico",
	"a[[b]x[/b]c",
	"fim [",
	"]so[",
	"[shake rate=20.0 level=10]sh[/shake]",
	"[font_size=20]fs[/font_size] [hint=dica]h[/hint]",
	"a]b",
]


func test_ignora_maiusculas_e_acentos() -> void:
	var buf: Array[Dictionary] = [_e("Cálculo Numérico", false), _e("CÁLCULO I"), _e("calculo"), _e("Ação Extensionista")]
	assert_eq(_b(buf, "calculo").size(), 3)
	assert_eq(_b(buf, "CÁLCULO").size(), 3)
	assert_eq(_b(buf, "cálculo").size(), 3)
	assert_eq(_b(buf, "acao").size(), 1)
	assert_eq(_b(buf, "AÇÃO").size(), 1)
	var idx: Dictionary = _i(buf)
	var oc: Array[Vector2i] = BuscaTerminal.buscar(idx, "acao")
	assert_eq(str(idx["visivel"]).substr(oc[0].x, oc[0].y - oc[0].x), "Ação")


func test_ocorrencias_em_ordem_sem_sobreposicao() -> void:
	var buf: Array[Dictionary] = [_e("aaaa", false)]
	var esperado: Array[Vector2i] = [Vector2i(0, 2), Vector2i(2, 4)]
	assert_eq(_b(buf, "aa"), esperado)
	var buf2: Array[Dictionary] = [_e("Cálculo I", false), _e("Cálculo II"), _e("Cálculo III")]
	var oc: Array[Vector2i] = _b(buf2, "calculo")
	assert_eq(oc.size(), 3)
	for k in range(oc.size() - 1):
		assert_lt(oc[k].x, oc[k + 1].x)
		assert_true(oc[k].y <= oc[k + 1].x)


func test_termo_vazio_ou_so_espacos_nao_acha_nada() -> void:
	var buf: Array[Dictionary] = [_e("Cálculo I a b", false)]
	assert_eq(_b(buf, "").size(), 0)
	assert_eq(_b(buf, "   ").size(), 0)
	assert_eq(_b(buf, "\t").size(), 0)


func test_nao_casa_dentro_de_tags() -> void:
	var buf: Array[Dictionary] = [_e("[color=#ffcc00]Cor[/color] e [url=chave]Dica[/url] e [bgcolor=#2e7d3280]Fundo[/bgcolor]", false)]
	assert_eq(_i(buf)["visivel"], "Cor e Dica e Fundo")
	for termo in ["ffcc00", "color", "chave", "url", "bgcolor", "2e7d", "[b"]:
		assert_eq(_b(buf, termo).size(), 0, termo)
	assert_eq(_b(buf, "dica").size(), 1)
	assert_eq(_b(buf, "cor").size(), 1)
	assert_eq(_b(buf, "fundo").size(), 1)


func test_ocorrencia_atravessa_entradas_na_mesma_linha() -> void:
	var buf: Array[Dictionary] = [_e("- Disciplina par"), _e("cial", false), _e("cial")]
	var idx: Dictionary = _i(buf)
	var oc: Array[Vector2i] = BuscaTerminal.buscar(idx, "parcial")
	assert_eq(oc.size(), 1)
	var ent: Array = idx["entradas"]
	assert_lt(oc[0].x, int(ent[1]["inicio"]))
	assert_gt(oc[0].y, int(ent[1]["inicio"]))
	var r: Array[String] = BuscaTerminal.realcar(idx, oc, 0, TODAS, ATUAL)
	assert_true(r[0].ends_with("[bgcolor=#00000280]par[/bgcolor]"))
	assert_eq(r[1], "[bgcolor=#00000280]cial[/bgcolor]")
	assert_eq(r[2], "cial")


func test_ocorrencia_nao_atravessa_quebra_de_linha() -> void:
	var buf: Array[Dictionary] = [_e("par", false), _e("cial")]
	assert_eq(_b(buf, "parcial").size(), 0)


func test_realce_preserva_texto_visivel() -> void:
	var buf: Array[Dictionary] = [
		_e("[url=chave]Cálc[/url]ulo [b]Numé[/b]rico", false),
		_e("Movido: AL0001 → [5, 3]."),
		_e("[lb]x[rb] fim ["),
	]
	var idx: Dictionary = _i(buf)
	for termo in ["calculo numerico", "[5, 3]", "x] fim ["]:
		var oc: Array[Vector2i] = BuscaTerminal.buscar(idx, termo)
		assert_gt(oc.size(), 0, termo)
		var r: Array[String] = BuscaTerminal.realcar(idx, oc, 0, TODAS, ATUAL)
		for k in range(buf.size()):
			assert_eq(BuscaTerminal.texto_visivel(r[k]), BuscaTerminal.texto_visivel(str(buf[k]["texto"])), termo)
		if termo == "calculo numerico":
			assert_eq(r[0].count("[bgcolor="), 4)
			var p: int = r[0].find("[bgcolor=")
			while p != -1:
				var f: int = r[0].find("[/bgcolor]", p)
				var dentro: String = r[0].substr(p, f - p)
				for proibido in ["[url", "[/url]", "[b]", "[/b]"]:
					assert_false(dentro.contains(proibido))
				p = r[0].find("[bgcolor=", f)
		if termo == "[5, 3]":
			assert_false(r[1].contains("[5"))
			assert_true(r[1].contains("[lb]"))
			assert_eq(r[0], buf[0]["texto"])
		if termo == "x] fim [":
			assert_true(r[2].contains("[lb]"))
			assert_eq(r[1], buf[1]["texto"])


func test_realce_preserva_texto_visivel_no_motor() -> void:
	var rtl: RichTextLabel = autofree(RichTextLabel.new())
	rtl.bbcode_enabled = true
	for c in CASOS:
		var buf: Array[Dictionary] = [_e(c, false)]
		var tam: int = BuscaTerminal.texto_visivel(c).length()
		var oc: Array[Vector2i] = [Vector2i(0, tam / 3), Vector2i(tam / 2, tam)]
		var r: Array[String] = BuscaTerminal.realcar(_i(buf), oc, 0, TODAS, ATUAL)
		rtl.text = "[color=#ffffff]" + c + "[/color]"
		var sem: String = rtl.get_parsed_text()
		rtl.text = "[color=#ffffff]" + r[0] + "[/color]"
		assert_eq(rtl.get_parsed_text(), sem, c)


func test_atual_tem_realce_proprio_e_troca_so_move_o_forte() -> void:
	var buf: Array[Dictionary] = [_e("Cálculo e cálculo e CÁLCULO", false)]
	var idx: Dictionary = _i(buf)
	var oc: Array[Vector2i] = BuscaTerminal.buscar(idx, "calculo")
	assert_eq(oc.size(), 3)
	var a: String = BuscaTerminal.realcar(idx, oc, 0, TODAS, ATUAL)[0]
	var b: String = BuscaTerminal.realcar(idx, oc, 1, TODAS, ATUAL)[0]
	for s in [a, b]:
		assert_eq(s.count("[bgcolor=" + ATUAL + "]"), 1)
		assert_eq(s.count("[bgcolor=" + TODAS + "]"), 2)
	assert_ne(a, b)
	assert_eq(a.replace(ATUAL, TODAS), b.replace(ATUAL, TODAS))
	assert_lt(b.find(TODAS), b.find(ATUAL))


func test_navegacao_circular() -> void:
	assert_eq(BuscaTerminal.proxima(0, 3), 1)
	assert_eq(BuscaTerminal.proxima(2, 3), 0)
	assert_eq(BuscaTerminal.anterior(0, 3), 2)
	assert_eq(BuscaTerminal.anterior(2, 3), 1)
	assert_eq(BuscaTerminal.proxima(-1, 3), 0)
	assert_eq(BuscaTerminal.anterior(-1, 3), 2)
	assert_eq(BuscaTerminal.proxima(0, 1), 0)
	assert_eq(BuscaTerminal.anterior(0, 1), 0)


func test_sem_ocorrencias_nao_ha_atual() -> void:
	var buf: Array[Dictionary] = [_e("Cálculo", false)]
	assert_eq(_b(buf, "zzz").size(), 0)
	assert_eq(BuscaTerminal.proxima(-1, 0), -1)
	assert_eq(BuscaTerminal.anterior(-1, 0), -1)
	var vazio: Array[Vector2i] = []
	var esperado: Array[String] = ["Cálculo"]
	assert_eq(BuscaTerminal.realcar(_i(buf), vazio, -1, TODAS, ATUAL), esperado)


func test_normalizacao_preserva_comprimento() -> void:
	var s: String = "ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑáàâãäéèêëíìîïóòôõöúùûüçñ Aa"
	assert_eq(GeneralFunctions.remover_acentos(s).length(), s.length())
	var buf: Array[Dictionary] = [_e("Cálculo Numérico", false), _e("CÁLCULO I"), _e("calculo"), _e("Ação Extensionista")]
	var idx: Dictionary = _i(buf)
	assert_eq(str(idx["normalizado"]).length(), str(idx["visivel"]).length())


func test_texto_visivel_igual_ao_do_motor() -> void:
	var rtl: RichTextLabel = autofree(RichTextLabel.new())
	rtl.bbcode_enabled = true
	for c in CASOS:
		rtl.text = "[color=#ffffff]" + c + "[/color]"
		assert_eq(BuscaTerminal.texto_visivel(c), rtl.get_parsed_text(), c)


func test_indice_mapeia_entradas_e_quebras() -> void:
	var buf: Array[Dictionary] = [_e("ab", false), _e("[b]cd[/b]"), _e("ef", false)]
	var idx: Dictionary = _i(buf)
	assert_eq(idx["visivel"], "ab\ncdef")
	var ent: Array = idx["entradas"]
	assert_eq(ent.size(), 3)
	assert_eq([int(ent[0]["inicio"]), int(ent[0]["fim"])], [0, 2])
	assert_eq([int(ent[1]["inicio"]), int(ent[1]["fim"])], [3, 5])
	assert_eq([int(ent[2]["inicio"]), int(ent[2]["fim"])], [5, 7])


func test_colchete_literal_continua_igual_apos_realce() -> void:
	var buf: Array[Dictionary] = [_e("Movido: AL0001 → [5, 3].", false)]
	var idx: Dictionary = _i(buf)
	var oc: Array[Vector2i] = BuscaTerminal.buscar(idx, "5, 3")
	assert_eq(oc.size(), 1)
	var r: String = BuscaTerminal.realcar(idx, oc, 0, TODAS, ATUAL)[0]
	assert_true(r.contains("[lb]"))
	assert_false(r.contains("[5"))
	var rtl: RichTextLabel = autofree(RichTextLabel.new())
	rtl.bbcode_enabled = true
	rtl.text = "[color=#ffffff]" + r + "[/color]"
	assert_eq(rtl.get_parsed_text(), "Movido: AL0001 → [5, 3].")


func test_entrada_sem_ocorrencia_sai_identica() -> void:
	var buf: Array[Dictionary] = [_e("[b]um[/b] [lb]x", false), _e("[color=#fff]alvo[/color]"), _e("[i]tres[/i] [", false)]
	var idx: Dictionary = _i(buf)
	var oc: Array[Vector2i] = BuscaTerminal.buscar(idx, "alvo")
	assert_eq(oc.size(), 1)
	var r: Array[String] = BuscaTerminal.realcar(idx, oc, 0, TODAS, ATUAL)
	assert_eq(r[0], buf[0]["texto"])
	assert_eq(r[2], buf[2]["texto"])


func test_nao_muta_buffer() -> void:
	var buf: Array[Dictionary] = [_e("[b]Cálculo[/b] [", false), _e("calculo")]
	var copia: Array[Dictionary] = buf.duplicate(true)
	var idx: Dictionary = _i(buf)
	var oc: Array[Vector2i] = BuscaTerminal.buscar(idx, "calculo")
	BuscaTerminal.realcar(idx, oc, 0, TODAS, ATUAL)
	assert_eq(buf, copia)


func test_buffer_vazio() -> void:
	var vazio: Array[Dictionary] = []
	assert_eq(_i(vazio), {"visivel": "", "normalizado": "", "entradas": []})
	assert_eq(_b(vazio, "x").size(), 0)


func _e(texto: String, nl: bool = true) -> Dictionary:
	return {"texto": texto, "token": "padrao", "efeito": "", "nl": nl, "bg": ""}


func _i(buf: Array[Dictionary]) -> Dictionary:
	return BuscaTerminal.indexar(buf)


func _b(buf: Array[Dictionary], termo: String) -> Array[Vector2i]:
	return BuscaTerminal.buscar(_i(buf), termo)
