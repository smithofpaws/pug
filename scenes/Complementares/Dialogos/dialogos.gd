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
	# No frame seguinte ao layout, limita o diálogo ao viewport e centraliza os botões (ver
	# _pos_layout_confirmar). Mensagens longas que antes esticavam o diálogo passam a ser contidas.
	pai.get_tree().process_frame.connect(func(): _pos_layout_confirmar(dialogo), CONNECT_ONE_SHOT)

# Pós-layout do confirmar: primeiro limita o diálogo ao viewport (encolhe se a mensagem o fez
# ultrapassar a tela), depois — no frame seguinte, já com o tamanho final refletido nas medidas do
# label — centraliza o HBox dos botões. A espera de um frame extra é necessária porque o reflow do
# clamp só atualiza o minimum_size do label (autowrap) no próximo ciclo de layout.
static func _pos_layout_confirmar(dialogo: ConfirmationDialog) -> void:
	_aplicar_limite_tela(dialogo, 80)
	var tree := dialogo.get_tree()
	if tree:
		tree.process_frame.connect(func(): _centrar_botoes(dialogo), CONNECT_ONE_SHOT)

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

## Exibe um aviso de [b]botão único[/b] (sem escolha), para relatar um desfecho ao usuário — um erro
## de rede, um "já está na versão mais recente". Complementa [method confirmar], que sempre oferece o
## par confirmar/cancelar e portanto sugere uma decisão onde não há nenhuma. [br]
## [param largura_max] (> 0) fixa a largura e ativa a quebra automática, como em [method confirmar].
## O nó é liberado da memória ao fechar por qualquer caminho.
## [codeblock]
## Dialogos.avisar(self, "Atualização", "O programa já está na versão mais recente.")
## [/codeblock]
static func avisar(pai: Node, titulo: String, texto: String, texto_ok: String = "OK", \
		largura_max: int = 420) -> void:
	var dialogo := AcceptDialog.new()
	dialogo.title = titulo
	dialogo.dialog_text = texto
	if largura_max > 0:
		var label := dialogo.get_label()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(largura_max, 0)
	dialogo.get_ok_button().text = texto_ok
	dialogo.visibility_changed.connect(func():
		if not dialogo.visible:
			dialogo.queue_free())
	pai.add_child(dialogo)
	dialogo.popup_centered()
	limitar_a_tela(dialogo)

## Exibe um diálogo com um [param cabecalho], uma lista [b]rolável[/b] de [param itens] (que não estica
## a janela) e um [param rodape] opcional, oferecendo uma ou mais [param acoes] (botões). Para
## avisos/escolhas que mostram uma lista potencialmente longa (ex.: muitas disciplinas), garantindo
## que o diálogo não ultrapasse a tela e os botões fiquem sempre visíveis — substitui o antigo padrão
## de concatenar a lista no [code]dialog_text[/code], que crescia sem limite. [br]
## [param itens] são as linhas exibidas (texto puro, uma por linha). [param acoes] é um Array de
## [code]{ "texto": String, "ao_acionar": Callable }[/code]: a primeira ação é o botão de confirmação
## (à direita); as demais viram botões extras. [param texto_cancelar] (quando não vazio) adiciona um
## botão que apenas fecha. [param largura] fixa a largura do conteúdo (o texto quebra nela). O nó é
## liberado da memória em qualquer caminho de fechamento.
## [codeblock]
## Dialogos.escolha_lista(self, "Título", "Cabeçalho:", ["• item 1", "• item 2"], "E aí?",
##     [{ "texto": "Fazer A", "ao_acionar": _fazer_a }, { "texto": "Fazer B", "ao_acionar": _fazer_b }])
## [/codeblock]
static func escolha_lista(pai: Node, titulo: String, cabecalho: String, itens: Array, rodape: String, \
		acoes: Array, texto_cancelar: String = "Cancelar", largura: int = 520) -> void:
	var dialogo := ConfirmationDialog.new()
	dialogo.title = titulo
	dialogo.dialog_text = ""
	# wrap_controls ajusta a altura ao conteúdo; min_size dá a largura e um piso de altura (com y=0 o
	# Godot colapsa a altura — ver confirmar). O ScrollContainer abaixo é que evita o crescimento.
	dialogo.wrap_controls = true
	dialogo.exclusive = false
	dialogo.min_size = Vector2i(largura + 48, 360)

	var vbox := VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialogo.add_child(vbox)

	if not cabecalho.is_empty():
		var lbl_cab := Label.new()
		lbl_cab.text = cabecalho
		lbl_cab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl_cab.custom_minimum_size = Vector2(largura, 0)
		vbox.add_child(lbl_cab)

	# Lista rolável: ScrollContainer com altura fixa (não cresce com o nº de itens) dentro de um VBox
	# que expande — o conteúdo rola em vez de esticar a janela (padrão de SeletorCursos).
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(largura, 220)
	vbox.add_child(scroll)
	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lista)
	for item in itens:
		var linha := Label.new()
		linha.text = str(item)
		linha.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# -20 reserva espaço para a barra de rolagem vertical, evitando rolagem horizontal espúria.
		linha.custom_minimum_size = Vector2(largura - 20, 0)
		lista.add_child(linha)

	if not rodape.is_empty():
		var lbl_rod := Label.new()
		lbl_rod.text = rodape
		lbl_rod.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl_rod.custom_minimum_size = Vector2(largura, 0)
		vbox.add_child(lbl_rod)

	# A 1ª ação é o botão OK (confirmação); as demais viram botões extras despachados por custom_action
	# (indexados por "extra_<i>"). O ConfirmationDialog fecha sozinho no OK; nos extras, fechamos à mão.
	var extras: Dictionary = {}
	if acoes.size() > 0:
		var ok_acao: Dictionary = acoes[0]
		dialogo.get_ok_button().text = str(ok_acao.get("texto", "OK"))
		var ok_cb: Callable = ok_acao.get("ao_acionar", Callable())
		if ok_cb.is_valid():
			dialogo.confirmed.connect(ok_cb)
	for i in range(1, acoes.size()):
		var acao: Dictionary = acoes[i]
		var nome := "extra_%d" % i
		extras[nome] = acao.get("ao_acionar", Callable())
		dialogo.add_button(str(acao.get("texto", "")), true, nome)
	if texto_cancelar.is_empty():
		dialogo.get_cancel_button().hide()
	else:
		dialogo.get_cancel_button().text = texto_cancelar

	dialogo.custom_action.connect(func(acao: StringName):
		var cb: Callable = extras.get(String(acao), Callable())
		dialogo.hide()
		if cb.is_valid():
			cb.call())
	# Libera o nó em qualquer caminho de fechamento (OK/extra/Cancelar/Esc/X), sem risco de free duplo.
	dialogo.visibility_changed.connect(func():
		if not dialogo.visible:
			dialogo.queue_free())
	pai.add_child(dialogo)
	dialogo.popup_centered()
	limitar_a_tela(dialogo)

## Garante que [param janela] (qualquer diálogo/popup construído em runtime) não ultrapasse a área
## visível do app: no frame seguinte ao layout, encolhe-a para caber (menos [param margem] no total de
## cada eixo) e a re-centraliza, sem deixá-la sair pela borda. Chamar logo após [code]popup_centered()[/code].
## Para diálogos com conteúdo rolável ([ScrollContainer] com [code]SIZE_EXPAND_FILL[/code]), o conteúdo
## passa a rolar quando a janela encolhe; nos demais, garante ao menos que os botões fiquem visíveis.
## Generaliza o padrão de [code]seletor_horarios_liberados.gd[/code]. Só encolhe se a janela exceder —
## diálogos que já cabem ficam intactos.
static func limitar_a_tela(janela: Window, margem: int = 80) -> void:
	if not is_instance_valid(janela):
		return
	var tree := janela.get_tree()
	if tree == null:
		return
	tree.process_frame.connect(func(): _aplicar_limite_tela(janela, margem), CONNECT_ONE_SHOT)

# Aplica o clamp de tamanho/posição assumindo que o layout já ocorreu (chamado um frame após o popup,
# ou diretamente por quem já está em pós-layout). Usa o tamanho do viewport raiz — coordenadas em que
# os subwindows embutidos posicionam size/position (mesma referência de seletor_horarios_liberados).
static func _aplicar_limite_tela(janela: Window, margem: int) -> void:
	if not is_instance_valid(janela) or not janela.visible:
		return
	var tree := janela.get_tree()
	if tree == null:
		return
	var disp: Vector2i = Vector2i(tree.root.get_visible_rect().size)
	var maxw: int = maxi(240, disp.x - margem)
	var maxh: int = maxi(160, disp.y - margem)
	# O min_size é um piso rígido: se ele próprio exceder o disponível, reduzi-lo antes — senão o
	# Window ignora qualquer size menor (diálogos com min_size alto não encolheriam em telas baixas).
	if janela.min_size.x > maxw or janela.min_size.y > maxh:
		janela.min_size = Vector2i(mini(janela.min_size.x, maxw), mini(janela.min_size.y, maxh))
	var nova := Vector2i(mini(janela.size.x, maxw), mini(janela.size.y, maxh))
	var encolheu: bool = nova != janela.size
	if encolheu:
		janela.size = nova
	# Reposiciona só se encolheu ou se a janela está saindo da área visível — diálogos que já cabem e
	# estão bem centralizados (a maioria) não sofrem nenhum "salto" de posição.
	var pos := janela.position
	var fora: bool = pos.x < 0 or pos.y < 0 \
		or pos.x + janela.size.x > disp.x or pos.y + janela.size.y > disp.y
	if encolheu or fora:
		var folga: int = margem / 2
		var alvo := Vector2i((disp.x - janela.size.x) / 2, (disp.y - janela.size.y) / 2)
		janela.position = Vector2i(maxi(alvo.x, folga), maxi(alvo.y, folga))
