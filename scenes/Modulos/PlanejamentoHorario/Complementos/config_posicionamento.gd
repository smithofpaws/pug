class_name ConfigPosicionamento extends RefCounted
## Diálogo modal de configuração do posicionamento automático de horários. [br]
##
## Pergunta ao usuário em qual turno o primeiro semestre da oferta começa (a alternância
## manhã↔tarde dos demais decorre disso — regra 1) e se há aula aos sábados. Emite
## [signal configuracao_definida] ao confirmar. Segue o padrão dos demais auxiliares construídos em
## runtime (ex.: [SeletorCursos]): um [RefCounted] que monta e gerencia o próprio
## [ConfirmationDialog], comunicando o resultado por sinal.

## Emitido ao confirmar, com [code]{ "inicio_manha": bool, "permitir_sabado": bool }[/code]
## ([code]inicio_manha[/code] = o semestre de menor número, ex.: EC01, começa pela manhã).
signal configuracao_definida(cfg: Dictionary)

# Nó onde o diálogo é adicionado (geralmente o módulo).
var _raiz: Node

func _init(raiz: Node) -> void:
	_raiz = raiz

## Abre o diálogo. [param inicio_manha_inicial] e [param permitir_sabado_inicial] são as últimas
## escolhas do usuário, reapresentadas como pré-seleção. [param nome_curso_filtro] (quando não vazio)
## é o nome do curso ativo no filtro, exibido para deixar explícito que só ele será posicionado. [br]
## [param diagnostico] lista os pré-requisitos a exibir, cada item
## [code]{ "texto": String, "token": String, "bloqueia": bool }[/code]: [code]token[/code] é a cor
## semântica ("erro"/"alerta"/"aviso"/"sucesso") e [code]bloqueia[/code] desabilita o botão Posicionar.
func abrir(inicio_manha_inicial: bool = true, permitir_sabado_inicial: bool = false, \
		nome_curso_filtro: String = "", diagnostico: Array = []) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Posicionar automaticamente"
	# wrap_controls ajusta a altura do diálogo ao conteúdo (ver SeletorCursos).
	dialog.wrap_controls = true
	dialog.exclusive = false
	dialog.get_ok_button().text = "Posicionar"
	dialog.get_cancel_button().text = "Cancelar"

	var vbox := VBoxContainer.new()
	dialog.add_child(vbox)

	var escopo: String = ""
	if nome_curso_filtro.is_empty():
		escopo = "Serão posicionadas as disciplinas pendentes de todos os cursos (nenhum filtro de curso ativo)."
	else:
		escopo = "Será respeitado o filtro de curso ativo: somente as disciplinas pendentes de %s serão posicionadas." % nome_curso_filtro
	var lbl_escopo := Label.new()
	lbl_escopo.text = escopo
	lbl_escopo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_escopo.custom_minimum_size = Vector2(460, 0)
	vbox.add_child(lbl_escopo)

	# Seção de pré-requisitos: cada item é colorido pela sua severidade (token semântico). Se algum
	# item bloquear (obrigatório ausente), o botão Posicionar é desabilitado mais abaixo.
	var bloqueado: bool = false
	if not diagnostico.is_empty():
		vbox.add_child(HSeparator.new())
		var titulo := Label.new()
		titulo.text = "Pré-requisitos:"
		vbox.add_child(titulo)
		for item in diagnostico:
			var linha := Label.new()
			linha.text = "• " + str(item.get("texto", ""))
			linha.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			linha.custom_minimum_size = Vector2(460, 0)
			linha.add_theme_color_override("font_color", PaletaSemantica.cor(str(item.get("token", "padrao"))))
			vbox.add_child(linha)
			if bool(item.get("bloqueia", false)):
				bloqueado = true
		if bloqueado:
			var nota := Label.new()
			nota.text = "Resolva os itens em vermelho para liberar o posicionamento."
			nota.add_theme_color_override("font_color", PaletaSemantica.cor("erro"))
			vbox.add_child(nota)

	vbox.add_child(HSeparator.new())
	var instr := Label.new()
	instr.text = "Escolha em qual turno o primeiro semestre da oferta começa (os seguintes alternam manhã/tarde):"
	instr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instr.custom_minimum_size = Vector2(460, 0)
	vbox.add_child(instr)

	# CheckBoxes num mesmo ButtonGroup funcionam como radiobuttons (escolha única).
	var grupo := ButtonGroup.new()
	var cb_manha := CheckBox.new()
	cb_manha.text = "Primeiro semestre de manhã (EC01 manhã, EC03 tarde, EC05 manhã…)"
	cb_manha.button_group = grupo
	cb_manha.set_meta("inicio_manha", true)
	vbox.add_child(cb_manha)

	var cb_tarde := CheckBox.new()
	cb_tarde.text = "Primeiro semestre à tarde (EC01 tarde, EC03 manhã, EC05 tarde…)"
	cb_tarde.button_group = grupo
	cb_tarde.set_meta("inicio_manha", false)
	vbox.add_child(cb_tarde)

	if inicio_manha_inicial:
		cb_manha.button_pressed = true
	else:
		cb_tarde.button_pressed = true

	vbox.add_child(HSeparator.new())
	var cb_sabado := CheckBox.new()
	cb_sabado.text = "Permitir aula aos sábados (somente de manhã)"
	cb_sabado.button_pressed = permitir_sabado_inicial
	vbox.add_child(cb_sabado)

	dialog.confirmed.connect(_on_confirmar.bind(grupo, cb_sabado))
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	_raiz.add_child(dialog)
	# Item obrigatório ausente impede o posicionamento: o usuário ainda pode fechar/cancelar.
	dialog.get_ok_button().disabled = bloqueado
	dialog.popup_centered()

# Lê o turno inicial marcado e a opção de sábado, e emite o sinal de configuração.
func _on_confirmar(grupo: ButtonGroup, cb_sabado: CheckBox) -> void:
	var pressed: BaseButton = grupo.get_pressed_button()
	var inicio_manha: bool = bool(pressed.get_meta("inicio_manha", true)) if pressed else true
	configuracao_definida.emit({"inicio_manha": inicio_manha, "permitir_sabado": cb_sabado.button_pressed})
