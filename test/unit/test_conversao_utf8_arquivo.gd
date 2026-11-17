extends GutTest
## Testes de I/O da conversao Windows-1252 -> UTF-8 ([method FileHandling.convertto_utf8]) e dos
## chamadores que a usam. Fixtures ficticias, geradas em memoria e gravadas em user://.

const RAIZ: String = "user://teste_0010/"
const ORACULO_80_9F: Dictionary = {
	0x20AC: 0x80, 0x201A: 0x82, 0x0192: 0x83, 0x201E: 0x84, 0x2026: 0x85, 0x2020: 0x86,
	0x2021: 0x87, 0x02C6: 0x88, 0x2030: 0x89, 0x0160: 0x8A, 0x2039: 0x8B, 0x0152: 0x8C,
	0x017D: 0x8E, 0x2018: 0x91, 0x2019: 0x92, 0x201C: 0x93, 0x201D: 0x94, 0x2022: 0x95,
	0x2013: 0x96, 0x2014: 0x97, 0x02DC: 0x98, 0x2122: 0x99, 0x0161: 0x9A, 0x203A: 0x9B,
	0x0153: 0x9C, 0x017E: 0x9E, 0x0178: 0x9F,
}
const POSICOES: Dictionary = {
	"linha": 0.0, "professor": 1.0, "sala": 2.0, "semestre": 3.0, "horario": 4.0, "dia": 5.0,
	"disciplina": 6.0, "tipo": 7.0, "turma": 8.0, "vagas": 9.0, "p": 10.0, "s": 11.0, "t": 12.0,
}
const SUBPASTAS: Array[String] = ["origem/", "destino/", "regras/", "temp/"]

class CapturaLog extends Logger:
	var mensagens: Array[String] = []
	var _mutex: Mutex = Mutex.new()

	func _log_message(message: String, _error: bool) -> void:
		_mutex.lock()
		mensagens.append(message)
		_mutex.unlock()

var _captura: CapturaLog
var _f: FileHandling

func before_each() -> void:
	_limpar_raiz()
	for s in SUBPASTAS:
		DirAccess.make_dir_recursive_absolute(RAIZ + s)
	_captura = CapturaLog.new()
	OS.add_logger(_captura)
	_f = FileHandling.new()

func after_each() -> void:
	OS.remove_logger(_captura)
	_limpar_raiz()

func test_converte_cp1252_mantendo_texto_e_crlf() -> void:
	var t: String = "Maria da Silva Souza;Terça;Sábado;Ação – “x” €\r\nLinha 2;Mecânica\r\n"
	var origem: PackedByteArray = _cp1252(t)
	assert_false(CodificacaoTexto.eh_utf8_valido(origem))
	_gravar(RAIZ + "origem/entrada.txt", origem)
	assert_true(_converter())
	assert_eq(_ler(RAIZ + "destino/saida.txt"), t.to_utf8_buffer())
	assert_eq(_erros_unicode(), 0)

func test_origem_utf8_e_copiada_byte_a_byte() -> void:
	var origem: PackedByteArray = "Sábado – ação\r\n".to_utf8_buffer()
	_gravar(RAIZ + "origem/entrada.txt", origem)
	assert_true(_converter())
	var destino: PackedByteArray = _ler(RAIZ + "destino/saida.txt")
	assert_eq(destino, origem)
	assert_eq(destino.hex_encode().find("c383c2a1"), -1)
	assert_eq(_erros_unicode(), 0)

func test_origem_utf8_com_bom_mantem_bom() -> void:
	var origem: PackedByteArray = PackedByteArray([0xEF, 0xBB, 0xBF])
	origem.append_array("Sábado\r\n".to_utf8_buffer())
	_gravar(RAIZ + "origem/entrada.txt", origem)
	assert_true(_converter())
	var destino: PackedByteArray = _ler(RAIZ + "destino/saida.txt")
	assert_eq(destino, origem)
	assert_eq(destino.slice(0, 3), PackedByteArray([0xEF, 0xBB, 0xBF]))

func test_origem_inexistente_falha_sem_criar_destino() -> void:
	assert_false(_converter("nao_existe.txt"))
	assert_push_error("nao_existe.txt")
	assert_false(FileAccess.file_exists(RAIZ + "destino/saida.txt"))

func test_origem_igual_ao_destino_nao_toca_no_arquivo() -> void:
	var a: PackedByteArray = _cp1252("Terça\r\n")
	_gravar(RAIZ + "origem/a.txt", a)
	assert_false(_f.convertto_utf8(RAIZ + "origem/", "a.txt", RAIZ + "origem/", "a.txt"))
	assert_push_error("a.txt")
	assert_eq(_ler(RAIZ + "origem/a.txt"), a)
	var b: PackedByteArray = "Terça\r\n".to_utf8_buffer()
	_gravar(RAIZ + "origem/b.txt", b)
	assert_true(_f.convertto_utf8(RAIZ + "origem/", "b.txt", RAIZ + "origem/", "b.txt"))
	assert_eq(_ler(RAIZ + "origem/b.txt"), b)

func test_horarios_txt_formato_novo_cp1252_carrega_dias_e_codigo() -> void:
	var linha1: String = ',"Maria da Silva Souza",EaD,ec03,13:30,Terça,"Mecânica dos Sólidos (al0171)",EaD,T100,Vagas,1,1,1'
	var linha2: String = linha1.replace("13:30,Terça", "08:30,Sábado")
	var origem: PackedByteArray = _cp1252(linha1 + "\r\n" + linha2 + "\r\n")
	assert_false(CodificacaoTexto.eh_utf8_valido(origem))
	_gravar(RAIZ + "origem/entrada.txt", origem)
	assert_true(_converter("entrada.txt", "horarios.txt"))
	var exe := HorariosExe.new()
	var r: Array = exe.carregar_horarios_txt(RAIZ + "destino/", "horarios.txt", POSICOES)
	assert_eq(r.size(), 2)
	assert_eq(r[0]["linha"], "")
	assert_eq(r[0]["dia"], "terça")
	assert_eq(r[1]["dia"], "sábado")
	assert_eq(r[0]["sala"], "ead")
	assert_eq(r[0]["tipo"], "ead")
	assert_eq(r[0]["turma"], "t100")
	assert_eq(exe.extrair_cod_horarios_txt(r[0]["disciplina"]), "al0171")
	assert_eq(_erros_unicode(), 0)

func test_converte_5mib_cp1252_em_menos_de_3s() -> void:
	var texto: String = "Maria da Silva Souza;Terça;Sábado;Ação – “x” €;Mecânica\r\n"
	var par: Array = _bloco_repetido(_cp1252(texto))
	_gravar(RAIZ + "origem/entrada.txt", par[0])
	var inicio: int = Time.get_ticks_msec()
	var ok: bool = _converter()
	var tempo: int = Time.get_ticks_msec() - inicio
	gut.p("5 MiB CP1252 convertidos em %d ms" % tempo)
	assert_true(ok)
	assert_lt(tempo, 3000)
	var esperado: PackedByteArray = PackedByteArray()
	var linha_utf8: PackedByteArray = texto.to_utf8_buffer()
	for i in par[1]:
		esperado.append_array(linha_utf8)
	assert_eq(_ler(RAIZ + "destino/saida.txt"), esperado)

func test_valida_e_copia_5mib_utf8_em_menos_de_3s() -> void:
	var par: Array = _bloco_repetido("Maria da Silva Souza;Terça;Sábado;Mecânica\r\n".to_utf8_buffer())
	_gravar(RAIZ + "origem/entrada.txt", par[0])
	var inicio: int = Time.get_ticks_msec()
	var ok: bool = _converter()
	var tempo: int = Time.get_ticks_msec() - inicio
	gut.p("5 MiB UTF-8 validados e copiados em %d ms" % tempo)
	assert_true(ok)
	assert_lt(tempo, 3000)
	assert_eq(_ler(RAIZ + "destino/saida.txt"), par[0])

func test_origem_vazia_gera_destino_vazio() -> void:
	_gravar(RAIZ + "origem/entrada.txt", PackedByteArray())
	assert_true(_converter())
	assert_true(FileAccess.file_exists(RAIZ + "destino/saida.txt"))
	assert_eq(_ler(RAIZ + "destino/saida.txt").size(), 0)

func test_destino_existente_e_sobrescrito() -> void:
	_gravar(RAIZ + "destino/saida.txt", "conteudo antigo bem maior que o novo\r\n".to_utf8_buffer())
	_gravar(RAIZ + "origem/entrada.txt", _cp1252("Terça\r\n"))
	assert_true(_converter())
	assert_eq(_ler(RAIZ + "destino/saida.txt"), "Terça\r\n".to_utf8_buffer())

func test_origem_so_com_lf_continua_lf() -> void:
	_gravar(RAIZ + "origem/entrada.txt", _cp1252("Terça\nSábado\n"))
	assert_true(_converter())
	assert_eq(_ler(RAIZ + "destino/saida.txt"), "Terça\nSábado\n".to_utf8_buffer())

func test_heuristicas_antigas_foram_removidas() -> void:
	assert_false(FileHandling.new().has_method("_precisa_conversao_utf8"))
	assert_false(ArquivosPlanejamento.new().has_method("_verifica_se_windows1252"))

func test_importador_preferencias_converte_cp1252() -> void:
	var t: String = "Não colocar aula na sexta, à tarde,,,,\r\n"
	_gravar(RAIZ + "origem/prefs_ficticio.csv", _cp1252(t))
	var r: Dictionary = _importador().importar(RAIZ + "origem/prefs_ficticio.csv")
	assert_true(r["ok"])
	assert_eq(_ler(RAIZ + "regras/prefs_ficticio.csv"), t.to_utf8_buffer())
	assert_eq(_erros_unicode(), 0)

func test_importador_preferencias_copia_utf8_sem_alterar() -> void:
	var origem: PackedByteArray = "Não colocar aula na sexta, à tarde,,,,\r\n".to_utf8_buffer()
	_gravar(RAIZ + "origem/prefs_ficticio.csv", origem)
	var r: Dictionary = _importador().importar(RAIZ + "origem/prefs_ficticio.csv")
	assert_true(r["ok"])
	assert_eq(_ler(RAIZ + "regras/prefs_ficticio.csv"), origem)
	assert_eq(_erros_unicode(), 0)

func test_ler_comentarios_professor_em_cp1252() -> void:
	var t: String = _csv_comentarios()
	_gravar(RAIZ + "regras/prefs.csv", _cp1252(t))
	assert_eq(_planejamento().ler_comentarios_professor("prefs.csv"), \
		["Não colocar aula na sexta, à tarde"] as Array[String])
	_gravar(RAIZ + "regras/prefs.csv", t.to_utf8_buffer())
	assert_eq(_planejamento().ler_comentarios_professor("prefs.csv"), \
		["Não colocar aula na sexta, à tarde"] as Array[String])
	assert_eq(_erros_unicode(), 0)

func _limpar_raiz() -> void:
	for s in SUBPASTAS:
		var dir := DirAccess.open(RAIZ + s)
		if dir == null:
			continue
		for nome in dir.get_files():
			DirAccess.remove_absolute(RAIZ + s + nome)
		DirAccess.remove_absolute(RAIZ + s)
	if DirAccess.dir_exists_absolute(RAIZ):
		DirAccess.remove_absolute(RAIZ)

func _erros_unicode() -> int:
	var total: int = 0
	for m in _captura.mensagens:
		if "Unicode parsing error" in m:
			total += 1
	return total

# Oraculo independente: Latin-1 mais os 27 da tabela. Nao usa CodificacaoTexto.
func _cp1252(texto: String) -> PackedByteArray:
	var saida: PackedByteArray = PackedByteArray()
	for i in texto.length():
		var cp: int = texto.unicode_at(i)
		if cp <= 0xFF:
			saida.append(cp)
		else:
			saida.append(ORACULO_80_9F[cp])
	return saida

func _gravar(caminho: String, bytes: PackedByteArray) -> void:
	var arq := FileAccess.open(caminho, FileAccess.WRITE)
	arq.store_buffer(bytes)
	arq.close()

func _ler(caminho: String) -> PackedByteArray:
	var arq := FileAccess.open(caminho, FileAccess.READ)
	if arq == null:
		return PackedByteArray()
	var bytes: PackedByteArray = arq.get_buffer(arq.get_length())
	arq.close()
	return bytes

func _converter(nome_origem: String = "entrada.txt", nome_destino: String = "saida.txt") -> bool:
	return _f.convertto_utf8(RAIZ + "origem/", nome_origem, RAIZ + "destino/", nome_destino)

func _bloco_repetido(linha: PackedByteArray) -> Array:
	var vezes: int = (5 * 1024 * 1024) / linha.size() + 1
	var entrada: PackedByteArray = PackedByteArray()
	for i in vezes:
		entrada.append_array(linha)
	return [entrada, vezes]

func _importador() -> ImportadorPreferencias:
	var imp := ImportadorPreferencias.new()
	imp.configurar(_f, RAIZ + "regras", RAIZ + "temp/")
	return imp

func _csv_comentarios() -> String:
	var linhas: Array[String] = []
	for i in 28:
		linhas.append(",,,,")
	linhas[23] = "Condições adicionais,,,,"
	linhas[24] = '"Não colocar aula na sexta, à tarde",,,,'
	return "\r\n".join(linhas) + "\r\n"

func _planejamento() -> ArquivosPlanejamento:
	var ap := ArquivosPlanejamento.new()
	ap.configurar(_f, AnaliseHorarios.new(), AnaliseGrades.new(), HorariosExe.new(), {}, {}, \
		RAIZ + "regras", {})
	return ap
