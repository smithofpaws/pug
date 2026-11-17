extends GutTest
## Testes do nucleo puro [CodificacaoTexto] e da fixacao de [HorariosExe]. Fixtures ficticias,
## geradas em memoria.

const ORACULO_80_9F: Dictionary = {
	0x80: 0x20AC, 0x82: 0x201A, 0x83: 0x0192, 0x84: 0x201E, 0x85: 0x2026, 0x86: 0x2020,
	0x87: 0x2021, 0x88: 0x02C6, 0x89: 0x2030, 0x8A: 0x0160, 0x8B: 0x2039, 0x8C: 0x0152,
	0x8E: 0x017D, 0x91: 0x2018, 0x92: 0x2019, 0x93: 0x201C, 0x94: 0x201D, 0x95: 0x2022,
	0x96: 0x2013, 0x97: 0x2014, 0x98: 0x02DC, 0x99: 0x2122, 0x9A: 0x0161, 0x9B: 0x203A,
	0x9C: 0x0153, 0x9E: 0x017E, 0x9F: 0x0178,
}
const INDEFINIDOS: Array[int] = [0x81, 0x8D, 0x8F, 0x90, 0x9D]

class CapturaLog extends Logger:
	var mensagens: Array[String] = []
	var _mutex: Mutex = Mutex.new()

	func _log_message(message: String, _error: bool) -> void:
		_mutex.lock()
		mensagens.append(message)
		_mutex.unlock()

var _captura: CapturaLog

func before_each() -> void:
	_captura = CapturaLog.new()
	OS.add_logger(_captura)

func after_each() -> void:
	OS.remove_logger(_captura)

func test_para_cp1252_do_horarios_exe_mantem_bytes() -> void:
	var esperado: PackedByteArray = _bytes([0x41, 0xE7, 0xE3, 0x6F, 0x20, 0x96, 0x20, 0x93, 0x43, \
		0xE1, 0x6C, 0x63, 0x75, 0x6C, 0x6F, 0x94, 0x20, 0x80, 0x20, 0x3F, 0x0D, 0x0A])
	assert_eq(HorariosExe.new()._para_cp1252("Ação – “Cálculo” € ✓\r\n"), esperado)

func test_ascii_passa_intacto() -> void:
	var b: PackedByteArray = PackedByteArray()
	for i in 128:
		b.append(i)
	assert_eq(CodificacaoTexto.cp1252_para_utf8(b), b)

func test_faixa_a0_ff_vira_latin1() -> void:
	for b in range(0xA0, 0x100):
		assert_eq(CodificacaoTexto.cp1252_para_utf8(_bytes([b])), String.chr(b).to_utf8_buffer())
	assert_eq(CodificacaoTexto.cp1252_para_utf8(_bytes([0xE7, 0xE3, 0x6F])), \
		"ção".to_utf8_buffer())

func test_faixa_80_9f_definidos_viram_seus_caracteres() -> void:
	for b in ORACULO_80_9F:
		assert_eq(CodificacaoTexto.cp1252_para_utf8(_bytes([b])), \
			String.chr(ORACULO_80_9F[b]).to_utf8_buffer())
	assert_eq(CodificacaoTexto.cp1252_para_utf8(_bytes([0x80])), "€".to_utf8_buffer())
	assert_eq(CodificacaoTexto.cp1252_para_utf8(_bytes([0x96])), "–".to_utf8_buffer())
	assert_eq(CodificacaoTexto.cp1252_para_utf8(_bytes([0x93, 0x94])), "“”".to_utf8_buffer())

func test_bytes_indefinidos_viram_fffd_sem_interromper() -> void:
	var entrada: PackedByteArray = _bytes([0x41, 0x81, 0x42, 0x8D, 0x8F, 0x90, 0x9D, 0xE7])
	assert_eq(CodificacaoTexto.cp1252_para_utf8(entrada), \
		"A�B����ç".to_utf8_buffer())

func test_detecao_reconhece_utf8_e_cp1252() -> void:
	assert_true(CodificacaoTexto.eh_utf8_valido("Maria da Silva Souza".to_utf8_buffer()))
	assert_true(CodificacaoTexto.eh_utf8_valido(PackedByteArray()))
	assert_true(CodificacaoTexto.eh_utf8_valido("Terça e Sábado".to_utf8_buffer()))
	var com_bom: PackedByteArray = _bytes([0xEF, 0xBB, 0xBF])
	com_bom.append_array("ação".to_utf8_buffer())
	assert_true(CodificacaoTexto.eh_utf8_valido(com_bom))
	assert_false(CodificacaoTexto.eh_utf8_valido(_bytes([0x54, 0x65, 0x72, 0xE7, 0x61])))

func test_detecao_nao_registra_unicode_parsing_error() -> void:
	var bloco: PackedByteArray = PackedByteArray()
	for i in 65536:
		bloco.append(0xE7 if i % 2 == 0 else 0x61)
	var entradas: Array[PackedByteArray] = [
		"Maria da Silva Souza".to_utf8_buffer(), PackedByteArray(),
		"Terça e Sábado".to_utf8_buffer(), _bytes([0xEF, 0xBB, 0xBF, 0x41]),
		_bytes([0x54, 0x65, 0x72, 0xE7, 0x61]), bloco,
	]
	for e in entradas:
		CodificacaoTexto.eh_utf8_valido(e)
	assert_eq(_erros_unicode(), 0)

func test_detecao_concorda_com_parser_do_godot() -> void:
	var corpus: Array[PackedByteArray] = [
		PackedByteArray(), _bytes([0x41, 0x42]), _bytes([0xEF, 0xBB, 0xBF, 0x41]),
		_bytes([0xEF, 0xBB, 0xBF]), _bytes([0xC3, 0xA7]), _bytes([0xF0, 0x9F, 0x98, 0x80]),
		_bytes([0xC0, 0x80]), _bytes([0xC1, 0xBF]), _bytes([0xE0, 0x80, 0x80]),
		_bytes([0xED, 0xA0, 0x80]), _bytes([0xF4, 0x90, 0x80, 0x80]), _bytes([0xF5]),
		_bytes([0x80]), _bytes([0x41, 0xC3]), _bytes([0xE2, 0x82]), _bytes([0xE7, 0xE3, 0x6F]),
		_bytes([0x93, 0x41, 0x94]), _bytes([0xFF]), _bytes([0x41, 0x00, 0xC3, 0xA7]),
		_bytes([0xEF, 0xBF, 0xBD]), _bytes([0xEF, 0xBF, 0xBE]),
	]
	for b in corpus:
		var antes: int = _erros_unicode()
		b.get_string_from_utf8()
		var motor_ok: bool = _erros_unicode() == antes
		assert_eq(CodificacaoTexto.eh_utf8_valido(b), motor_ok, "caso %s" % [b])

func test_saida_e_sempre_utf8_valido() -> void:
	var b: PackedByteArray = PackedByteArray()
	for i in 256:
		b.append(i)
	assert_true(CodificacaoTexto.eh_utf8_valido(CodificacaoTexto.cp1252_para_utf8(b)))

func test_ida_e_volta_para_todos_os_bytes_definidos() -> void:
	for b in range(1, 256):
		if b in INDEFINIDOS:
			continue
		var texto: String = CodificacaoTexto.cp1252_para_utf8(_bytes([b])).get_string_from_utf8()
		assert_eq(CodificacaoTexto.texto_para_cp1252(texto), _bytes([b]), "byte %d" % b)

func test_texto_para_cp1252_sem_mapa_vira_interrogacao() -> void:
	for t in ["✓", "�", String.chr(0x81), "あ"]:
		assert_eq(CodificacaoTexto.texto_para_cp1252(t), _bytes([0x3F]))

func _erros_unicode() -> int:
	var total: int = 0
	for m in _captura.mensagens:
		if "Unicode parsing error" in m:
			total += 1
	return total

func _bytes(valores: Array) -> PackedByteArray:
	return PackedByteArray(valores)
