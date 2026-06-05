class_name Dialogos extends RefCounted
## Helper program-wide para diálogos padrão da aplicação.
##
## Centraliza a criação de diálogos para garantir aparência e comportamento consistentes e evitar
## boilerplate duplicado nos módulos (no mesmo espírito de [DicaFlutuante] para tooltips). [br]
## Use sempre estes métodos em vez de instanciar [ConfirmationDialog]/[AcceptDialog] ad-hoc.

## Exibe um diálogo de confirmação (sim/não) e chama [param ao_confirmar] caso o usuário confirme. [br]
## O diálogo é criado sob demanda, adicionado como filho de [param pai] e liberado da memória ao fechar
## por qualquer caminho (confirmar, cancelar, Esc ou X) — não há como vazar o nó. [br]
## Formato de [param ao_confirmar] deve ser um [Callable] sem argumentos (executado só na confirmação). [br]
## [param texto_ok]/[param texto_cancelar] personalizam os rótulos dos botões. [br]
## [param largura_max] (> 0) fixa a largura do diálogo (em píxeis) pela largura mínima do label e
## ativa a quebra automática do texto — útil para mensagens longas, que de outro modo esticariam o
## diálogo horizontalmente. Com 0 (padrão), o diálogo dimensiona à linha mais longa, como antes.
## [codeblock]
## Dialogos.confirmar(self, "Exportar", "Deseja exportar?", _exportar, "Exportar")
## [/codeblock]
static func confirmar(pai: Node, titulo: String, texto: String, ao_confirmar: Callable, \
		texto_ok: String = "Sim", texto_cancelar: String = "Cancelar", largura_max: int = 0) -> void:
	var dialogo := ConfirmationDialog.new()
	dialogo.title = titulo
	dialogo.dialog_text = texto
	if largura_max > 0:
		# Define a largura pela largura mínima do label (com autowrap), e não por min_size/max_size do
		# Window: estes, com y = 0, faziam o Godot colapsar a altura (sobrava só a barra de título).
		# Com custom_minimum_size.x o texto quebra nessa largura e o diálogo cresce em altura sozinho.
		var label := dialogo.get_label()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(largura_max, 0)
	dialogo.get_ok_button().text = texto_ok
	dialogo.get_cancel_button().text = texto_cancelar
	dialogo.confirmed.connect(ao_confirmar)
	# Libera o nó em qualquer caminho de fechamento (confirmar/cancelar/Esc/X), sem risco de free duplo.
	dialogo.visibility_changed.connect(func():
		if not dialogo.visible:
			dialogo.queue_free())
	pai.add_child(dialogo)
	# Margem inferior mínima para o layout inicial (evita botões na borda antes do ajuste dinâmico).
	var panel_original := dialogo.get_theme_stylebox("panel")
	if panel_original:
		var panel := panel_original.duplicate() as StyleBox
		if panel:
			panel.content_margin_bottom = 12.0
			dialogo.add_theme_stylebox_override("panel", panel)
	dialogo.popup_centered()
	# No frame seguinte ao layout, reposiciona o HBox para centralizar os botões entre o final do
	# texto e a borda inferior — necessário porque o Label tem anchor_bottom=1 e se expande além
	# do conteúdo de texto, tornando a centralização estática ineficaz.
	pai.get_tree().process_frame.connect(func(): _centrar_botoes(dialogo), CONNECT_ONE_SHOT)

## Reposiciona o HBox interno para centrar os botões entre o texto visível e a borda inferior.
static func _centrar_botoes(dialogo: ConfirmationDialog) -> void:
	if not is_instance_valid(dialogo) or not dialogo.visible:
		return
	var label := dialogo.get_label()
	var hbox: HBoxContainer
	for i in dialogo.get_child_count(true):
		var c := dialogo.get_child(i, true)
		if c is HBoxContainer:
			hbox = c
			break
	if not label or not hbox or dialogo.size.y == 0 or hbox.size.y == 0:
		return
	var texto_bottom := label.position.y + label.get_minimum_size().y
	var espaco := float(dialogo.size.y) - texto_bottom - hbox.size.y
	if espaco < 8.0:
		return
	var margem := espaco / 2.0
	hbox.set_offset(SIDE_TOP, texto_bottom + margem)
	hbox.set_offset(SIDE_BOTTOM, texto_bottom + margem + hbox.size.y)
