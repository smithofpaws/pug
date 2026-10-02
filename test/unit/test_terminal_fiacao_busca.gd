extends GutTest
## Testes de fiacao da busca no Terminal real (cena [code]Terminal.tscn[/code]). Provam que o Terminal
## consome o nucleo [BuscaTerminal] e cobrem o estado por tras dos ACs manuais. Fixtures ficticias.

const _CENA: PackedScene = preload("res://scenes/Complementares/Terminal/Terminal.tscn")


func test_texto_visivel_do_indice_igual_ao_do_terminal() -> void:
	var t: Terminal = await _terminal()
	var espelho: Array[Dictionary] = [{"texto": "# Relatório fictício", "nl": false}]
	for texto in _textos_fixture():
		espelho.append({"texto": texto, "nl": true})
	assert_eq(BuscaTerminal.indexar(espelho)["visivel"], t.get_node("%TextEdit").get_parsed_text())


func test_ctrl_f_com_foco_no_terminal_abre_faixa_e_foca_campo() -> void:
	var t: Terminal = await _terminal()
	var antes: float = t.get_node("%TextEdit").global_position.y
	t.get_node("%TextEdit").grab_focus()
	get_viewport().push_input(_tecla(KEY_F, true))
	await wait_process_frames(2)
	assert_true(t.get_node("%FaixaBusca").visible)
	assert_true(t.get_node("%CampoBusca").has_focus())
	assert_gt(t.get_node("%TextEdit").global_position.y, antes)


func test_ctrl_f_com_foco_fora_nao_abre() -> void:
	var t: Terminal = await _terminal()
	var fora: LineEdit = LineEdit.new()
	add_child_autofree(fora)
	fora.grab_focus()
	get_viewport().push_input(_tecla(KEY_F, true))
	await wait_process_frames(1)
	assert_false(t.get_node("%FaixaBusca").visible)


func test_digitar_realca_e_contador_mostra_1_de_n() -> void:
	var t: Terminal = await _terminal()
	await _abrir(t)
	_digitar(t, "calculo")
	assert_true(_tem_realce(t))
	assert_eq(t.get_node("%ContadorBusca").text, "1 de 3")


func test_sem_ocorrencias_contador_zero_e_enter_nao_faz_nada() -> void:
	var t: Terminal = await _terminal()
	await _abrir(t)
	_digitar(t, "zzzz")
	var texto: String = t.get_node("%TextEdit").text
	assert_eq(t.get_node("%ContadorBusca").text, "0 de 0")
	get_viewport().push_input(_tecla(KEY_ENTER))
	await wait_process_frames(1)
	assert_eq(t.get_node("%ContadorBusca").text, "0 de 0")
	assert_false(_tem_realce(t))
	assert_eq(t.get_node("%TextEdit").text, texto)
	assert_true(t.get_node("%CampoBusca").has_focus())


func test_enter_shift_enter_e_botoes_navegam_em_ciclo() -> void:
	var t: Terminal = await _terminal()
	await _abrir(t)
	_digitar(t, "calculo")
	var lido: Array[String] = []
	for ev in [_tecla(KEY_ENTER), _tecla(KEY_ENTER), _tecla(KEY_ENTER), _tecla(KEY_ENTER, false, true), _tecla(KEY_ENTER, false, true)]:
		get_viewport().push_input(ev)
		await wait_process_frames(1)
		lido.append(t.get_node("%ContadorBusca").text)
	t.get_node("%BotaoAnterior").pressed.emit()
	lido.append(t.get_node("%ContadorBusca").text)
	t.get_node("%BotaoProxima").pressed.emit()
	lido.append(t.get_node("%ContadorBusca").text)
	assert_eq(lido, ["2 de 3", "3 de 3", "1 de 3", "3 de 3", "2 de 3", "1 de 3", "2 de 3"])
	assert_true(t.get_node("%CampoBusca").has_focus())


func test_esc_e_fechar_removem_realce_devolvem_foco_e_preservam_rolagem() -> void:
	var t: Terminal = await _terminal()
	var texto_sem_realce: String = t.get_node("%TextEdit").text
	for via_esc in [true, false]:
		await _abrir(t)
		_digitar(t, "calculo iii")
		await wait_process_frames(2)
		var rolagem: float = t.get_node("%TextEdit").get_v_scroll_bar().value
		assert_gt(rolagem, 0.0)
		if via_esc:
			get_viewport().push_input(_tecla(KEY_ESCAPE))
		else:
			t.get_node("%BotaoFechar").pressed.emit()
		await wait_process_frames(2)
		assert_false(t.get_node("%FaixaBusca").visible)
		assert_eq(t.get_node("%TextEdit").text, texto_sem_realce)
		assert_true(t.get_node("%TextEdit").has_focus())
		assert_eq(t.get_node("%TextEdit").get_v_scroll_bar().value, rolagem)


func test_mudanca_de_conteudo_fecha_busca() -> void:
	var t: Terminal = await _terminal()
	await _abrir(t)
	_digitar(t, "calculo")
	t.linha("Linha nova escrita depois")
	assert_false(t.get_node("%FaixaBusca").visible)
	assert_false(_tem_realce(t))
	assert_true(t.get_node("%TextEdit").get_parsed_text().ends_with("Linha nova escrita depois"))


func test_troca_de_tema_mantem_busca_e_realce() -> void:
	var t: Terminal = await _terminal()
	await _abrir(t)
	_digitar(t, "calculo")
	t.notification(Control.NOTIFICATION_THEME_CHANGED)
	assert_true(t.get_node("%FaixaBusca").visible)
	assert_true(_tem_realce(t))
	assert_eq(t.get_node("%ContadorBusca").text, "1 de 3")


func test_copia_com_realce_igual_sem_realce() -> void:
	var t: Terminal = await _terminal()
	var rtl: RichTextLabel = t.get_node("%TextEdit")
	rtl.select_all()
	var sem: String = rtl.get_selected_text()
	await _abrir(t)
	_digitar(t, "calculo")
	rtl.select_all()
	var com: String = rtl.get_selected_text()
	assert_true(_tem_realce(t))
	assert_eq(com, sem)
	assert_eq(com, rtl.get_parsed_text())


func test_botoes_tem_dica_com_atalho() -> void:
	var t: Terminal = await _terminal()
	assert_true(str(t.get_node("%BotaoAnterior").get_meta("dica_texto")).contains("Shift+Enter"))
	var proxima: String = str(t.get_node("%BotaoProxima").get_meta("dica_texto"))
	assert_true(proxima.contains("Enter"))
	assert_false(proxima.contains("Shift"))
	assert_true(str(t.get_node("%BotaoFechar").get_meta("dica_texto")).contains("Esc"))


func test_reabrir_traz_ultimo_termo_selecionado() -> void:
	var t: Terminal = await _terminal()
	await _abrir(t)
	_digitar(t, "calculo")
	get_viewport().push_input(_tecla(KEY_ESCAPE))
	await wait_process_frames(1)
	t.get_node("%TextEdit").grab_focus()
	get_viewport().push_input(_tecla(KEY_F, true))
	await wait_process_frames(2)
	var campo: LineEdit = t.get_node("%CampoBusca")
	assert_eq(campo.text, "calculo")
	assert_eq(campo.get_selected_text(), "calculo")
	assert_true(_tem_realce(t))
	assert_eq(t.get_node("%ContadorBusca").text, "1 de 3")
	campo.deselect()
	get_viewport().push_input(_tecla(KEY_F, true))
	await wait_process_frames(1)
	assert_eq(campo.text, "calculo")
	assert_eq(campo.get_selected_text(), "calculo")
	assert_true(_tem_realce(t))


func _textos_fixture() -> Array[String]:
	var textos: Array[String] = ["- Cálculo Numérico — Maria da Silva Souza", "- Ação Extensionista", "- CÁLCULO I"]
	for i in range(60):
		textos.append("linha de enchimento %d" % i)
	textos.append("- Cálculo III")
	for i in range(60):
		textos.append("linha de enchimento %d" % (60 + i))
	return textos


func _terminal() -> Terminal:
	var t: Terminal = _CENA.instantiate()
	add_child_autofree(t)
	await wait_process_frames(2)
	t.titulo("Relatório fictício", true)
	t.item("Cálculo Numérico — Maria da Silva Souza")
	t.item("Ação Extensionista")
	t.item("CÁLCULO I")
	for i in range(60):
		t.linha("linha de enchimento %d" % i)
	t.item("Cálculo III")
	for i in range(60):
		t.linha("linha de enchimento %d" % (60 + i))
	await wait_process_frames(2)
	return t


func _abrir(t: Terminal) -> void:
	t.get_node("%TextEdit").grab_focus()
	get_viewport().push_input(_tecla(KEY_F, true))
	await wait_process_frames(2)


func _digitar(t: Terminal, termo: String) -> void:
	var campo: LineEdit = t.get_node("%CampoBusca")
	campo.text = termo
	campo.text_changed.emit(termo)
	t.get_node("%TimerBusca").stop()
	t.get_node("%TimerBusca").timeout.emit()


func _tem_realce(t: Terminal) -> bool:
	return str(t.get_node("%TextEdit").text).contains("[bgcolor=")


func _tecla(codigo: Key, ctrl: bool = false, shift: bool = false) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = codigo
	ev.physical_keycode = codigo
	ev.pressed = true
	ev.ctrl_pressed = ctrl
	ev.shift_pressed = shift
	return ev
