class_name SeletorAvancado extends ReferenceRect
## Automatiza a criação de uma lista de items a serem selecionados e o processo de seleção destes itens.
##
## Pode ser empregado na criação de uma lista de itens que o usuário pode selecionar. Funciona tanto como 
## lista de seleção de apenas um item como de múltiplos intems.

signal opcao_selecionada

@export var texto_padrao: String : set = _set_textopadrao

## Lista de itens a serem apresentados. O funcionamento é o seguinte: [br]
## - Cada chave do dicionário gera um separador; [br]
## - Em cada chave é armazenada uma Array de Strings, a qual contém a lista; [br]
## - Um separador pode ser suprimido ao nomear a chave iniciando com "_"; [br]
## - Uma chave terminando com "_" indica que a lista será de marcar; [br]
## - Uma chave terminando com "*" indica que a lista será de marcar limitada a um item 
## marcado por vez; [br]
## - Uma chave terminando em "_retorno" indica que a Array irá conter as informações a 
## serem retornadas após clicado. Exemplo: Deseja se deixar a interface organizada, então 
## busca-se apresentar na tela "Matriculado Agora", porém quando esta opção for selecionada 
## deve-se informar "matriculado_agora", que é a forma padrão do programa. [br]
## Exemplo: [br]
## { [br]
## "alunos": ["pedro", "paulo", "marcos"], [br]
## "disciplinas": ["Obras de Terra", "Mecânica dos Solos"], [br]
## "disciplinas_retorno": ["obras", "solos"], [br]
## "_separadoroculto": ["item sem separador"] [br] 
## } [br]
## Gera uma lista como: [br]
## -----alunos------ [br]
## pedro [br]
## paulo [br]
## marcos [br]
## -----disciplinas------ [br]
## Obras de Terra [br]
## Mecânica dos Solos [br]
## item sem separador [br]
var lista_itens: Dictionary : set = _set_lista_itens

## Quando verdadeiro atualiza [param texto_padrao] sempre que um item for selecionado, inserindo
## o texto do item selecionado no texto padrao
var atualizar_texto_padrao: bool = false

# Array que contém os dados a serem retornados pelo signal de seleção.
var _retorno: Array[String] = []

# Contém uma lista de matrizes que separa os itens por grupos e suas definições. Empregado em
# definições mais complexas do comportamento dos grupos, como grupos que só podem ter um item
# marcado por vez, por exemplo.
var _selecao_unica: Array[Array] = []

# Índice do último item escolhido. Como a seleção única ("*") agora usa itens sem checkbox (não
# marcáveis), o scroll do mouse não consegue achar o "atual" via is_item_checked — este membro
# preserva a posição para a navegação por scroll continuar funcionando.
var _indice_atual: int = -1

# Dicas por item do dropdown (índice do PopupMenu → texto BBCode), exibidas via DicaFlutuante ao
# passar o mouse / focar o item. Itens de PopupMenu não são Controls (DicaFlutuante.vincular exige um
# Control), por isso usamos o sinal id_focused do popup. Assume id == índice — válido enquanto os
# itens forem criados por add_item/add_check_item sem id explícito (caso desta cena).
var _dicas_itens: Dictionary = {}

## Vincula uma DicaFlutuante ao item de índice [param index] do dropdown, exibida ao passar o mouse.
## Chame [b]após[/b] definir [member lista_itens] (reconstruir a lista não preserva as dicas). Texto
## vazio remove a dica do item.
func definir_dica_item(index: int, texto_bbcode: String) -> void:
	if texto_bbcode.strip_edges().is_empty():
		_dicas_itens.erase(index)
	else:
		_dicas_itens[index] = texto_bbcode

## Define (ou remove, com [param textura] nula) o ícone do item cujo valor de retorno é
## [param valor_retorno], sem reconstruir a lista — preserva a seleção atual. Útil para marcar itens
## em runtime (ex.: ícone verde para alunos que preencheram o formulário de ajuste). Como o índice em
## [member _retorno] coincide com o índice do item no PopupMenu, basta localizá-lo ali.
func definir_icone_item(valor_retorno: String, textura: Texture2D) -> void:
	var idx: int = _retorno.find(valor_retorno)
	if idx < 0:
		return
	$MenuButton.get_popup().set_item_icon(idx, textura)


func selecionar_item(index: int) -> void:
	if index >= _selecao_unica.size():
		print_debug("Indice do item ultrapassa numero de itens.")
		return
	_on_popupmenu_option_chosen(index)


## Define o texto do botão como [param texto] se ele couber na largura atual; caso contrário usa
## [param fallback]. Útil para listas de itens marcados (ex.: vários semestres) cujo texto pode
## exceder o botão.
func definir_texto_ou_fallback(texto: String, fallback: String) -> void:
	var btn: MenuButton = $MenuButton
	var fonte: Font = btn.get_theme_font("font")
	if fonte == null:
		texto_padrao = texto
		return
	var tam_fonte: int = btn.get_theme_font_size("font_size")
	var largura_texto: float = fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam_fonte).x
	# Desconta uma folga para o padding interno do botão.
	texto_padrao = texto if largura_texto <= btn.size.x - 16.0 else fallback


## Desmarca todos os itens checkable do PopupMenu, sem alterar [member lista_itens].
## Util para limpar visualmente a selecao ao resetar o filtro via middle-click.
func limpar_selecao() -> void:
	var popup: PopupMenu = $MenuButton.get_popup()
	for i in popup.item_count:
		if popup.is_item_checkable(i) and popup.is_item_checked(i):
			popup.set_item_checked(i, false)

func _ready() -> void:
	var popup: PopupMenu = $MenuButton.get_popup()
	popup.index_pressed.connect(_on_popupmenu_option_chosen)
	popup.set_hide_on_checkable_item_selection(false)
	# Dicas por item (ver _dicas_itens): id_focused dispara ao focar/passar o mouse; ao fechar o popup
	# escondemos a dica pendente.
	popup.id_focused.connect(_on_item_focado)
	popup.popup_hide.connect(func(): DicaFlutuante.esconder())
	$MenuButton.clip_text = true
	$MenuButton.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	aplicar_contorno_popup()
	_set_textopadrao(texto_padrao)
	gui_input.connect(_on_gui_input)

# Exibe (ou esconde) a DicaFlutuante do item sob o foco/mouse. Sem dica para o id, esconde a anterior.
func _on_item_focado(id: int) -> void:
	if _dicas_itens.has(id):
		DicaFlutuante.mostrar_em(_dicas_itens[id])
	else:
		DicaFlutuante.esconder()

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		if is_node_ready():
			aplicar_contorno_popup()

## Adiciona um contorno ao dropdown para diferencia-lo do fundo do programa, cuja cor
## e identica a do popup. A borda usa a cor de texto do tema para garantir contraste. [br]
## Publico porque o startup do programa atribui o tema da janela [b]depois[/b] do [code]_ready()[/code]
## desta cena: para a instancia que vive na [code]BarraPrincipal[/code], [code]main.gd[/code] chama
## explicitamente apos assinar o tema, garantindo que [code]get_theme_stylebox("panel")[/code] devolva
## o painel do tema correto em vez do default do engine.
func aplicar_contorno_popup() -> void:
	var popup: PopupMenu = $MenuButton.get_popup()
	popup.remove_theme_stylebox_override("panel")
	var base: StyleBox = popup.get_theme_stylebox("panel")
	var estilo: StyleBoxFlat
	if base is StyleBoxFlat:
		estilo = base.duplicate()
	else:
		estilo = StyleBoxFlat.new()
		estilo.bg_color = Color(0.12, 0.13, 0.14)
		estilo.set_content_margin_all(4)
	estilo.set_border_width_all(1)
	var cor_texto: Color = PaletaSemantica.cor("padrao")
	estilo.border_color = cor_texto
	popup.add_theme_stylebox_override("panel", estilo)
	popup.add_theme_color_override("font_separator_color", cor_texto)

func _criar_lista() -> void: 
	# Parâmetro que indica se a lista a ser criada é de marcar.
	var multipla_selecao: bool = true
	# Identificador numérico para cada chave.
	var grupo: int = 0
	# Limpa informações existentes para iniciar a criação de nova lista.
	$MenuButton.get_popup().clear(true)
	_selecao_unica.clear()
	_retorno.clear()
	# Itera entre itens da lista para criar a lista de seleção.
	for key in lista_itens.keys():
		if not key.ends_with("_retorno") and not key.ends_with("_disabled") and not key.ends_with("_icones"):
			if not key.begins_with("_"):
				$MenuButton.get_popup().add_separator(key.trim_suffix("_"))
				_retorno.append(key)
				_selecao_unica.append([grupo, false])
			# Caixa de marcar (checkbox) só em seleção MÚLTIPLA ("_", marca vários). Seleção única ("*")
			# e itens simples viram um dropdown limpo (add_item, sem caixa) — a escolha aparece no texto
			# do botão. Assim o checkbox fica só onde é pertinente.
			if key.ends_with("_"):
				multipla_selecao = true
			else:
				multipla_selecao = false
			var item_start: int = $MenuButton.get_popup().item_count
			var key_base: String = key.trim_suffix("_").trim_suffix("*")
			for a in lista_itens[key].size():
				if multipla_selecao:
					$MenuButton.get_popup().add_check_item(lista_itens[key][a])
				else:
					$MenuButton.get_popup().add_item(lista_itens[key][a])
				if lista_itens.has(key_base + "_retorno"):
					_retorno.append(lista_itens[key_base + "_retorno"][a])
				else:
					_retorno.append(lista_itens[key][a])
				if key.ends_with("*"):
					_selecao_unica.append([grupo, true])
				else:
					_selecao_unica.append([grupo, false])
				# Aplica estado desabilitado se houver array paralela _disabled.
				if lista_itens.has(key_base + "_disabled"):
					var disabled_arr: Array = lista_itens[key_base + "_disabled"]
					if a < disabled_arr.size() and disabled_arr[a]:
						$MenuButton.get_popup().set_item_disabled(item_start + a, true)
				# Aplica icone se houver array paralela _icones (ex.: marca quem preencheu o ajuste).
				if lista_itens.has(key_base + "_icones"):
					var icones_arr: Array = lista_itens[key_base + "_icones"]
					if a < icones_arr.size() and icones_arr[a] != null:
						$MenuButton.get_popup().set_item_icon(item_start + a, icones_arr[a])
		grupo += 1
	pass

#region Setgets
func _set_lista_itens(new_value: Dictionary) -> void:
	lista_itens = new_value
	_criar_lista()

func _set_textopadrao(new_value: String) -> void:
	texto_padrao = new_value
	$MenuButton.set_text(texto_padrao)
#endregion

#region Sinais
# Permite trocar o item selecionado com o scroll do mouse quando o cursor
# esta sobre o seletor, sem precisar abrir o dropdown.
func _on_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	var delta: int = 0
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		delta = -1
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		delta = 1
	else:
		return
	var popup: PopupMenu = $MenuButton.get_popup()
	var atual: int = -1
	for i in popup.item_count:
		if popup.is_item_checked(i):
			atual = i
			break
	# Seleção única não tem item marcado (sem checkbox): usa o último índice escolhido como referência.
	if atual < 0:
		atual = _indice_atual
	# Se o item pertence a um grupo de multipla selecao (_ sem *), desmarca
	# todos do grupo antes de avancar (scroll = single, clique = multi).
	if atual >= 0 and popup.is_item_checkable(atual) and not _selecao_unica[atual][1]:
		var grupo: int = _selecao_unica[atual][0]
		for i in popup.item_count:
			if popup.is_item_checkable(i) and _selecao_unica[i][0] == grupo and popup.is_item_checked(i):
				popup.set_item_checked(i, false)
	var total: int = popup.item_count
	for _t in total:
		atual = (atual + delta + total) % total
		if not popup.is_item_separator(atual) and not popup.is_item_disabled(atual):
			_on_popupmenu_option_chosen(atual)
			accept_event()
			return
	accept_event()

# [param index] é o número da linha selecionada, incluindo separadores.
func _on_popupmenu_option_chosen(index: int) -> void:
	if _selecao_unica[index][1]:
		# Marca apenas o selecionado e desmarca todos outros pertencentes ao grupo.
		for a in _selecao_unica.size():
			if _selecao_unica[a][0] == _selecao_unica[index][0]:
				if $MenuButton.get_popup().is_item_checkable(a):
					if a == index and $MenuButton.get_popup().is_item_checked(index):
						$MenuButton.get_popup().set_item_checked(index,false)
					elif a == index and not $MenuButton.get_popup().is_item_checked(index):
						$MenuButton.get_popup().set_item_checked(index,true)
					else:
						$MenuButton.get_popup().set_item_checked(a,false)
		$MenuButton.get_popup().hide()
	else:
		# Marca ou desmarca caso for um item com checkbox de um grupo que permite
		# multiplos marcadores.
		if $MenuButton.get_popup().is_item_checked(index):
			$MenuButton.get_popup().set_item_checked(index,false)
		else:
			$MenuButton.get_popup().set_item_checked(index,true)
	# Cria a lista de itens marcados
	var lista_selecionada: Array[String] = []
	for a in $MenuButton.get_popup().get_item_count():
		if $MenuButton.get_popup().is_item_checkable(a):
			if $MenuButton.get_popup().is_item_checked(a):
				lista_selecionada.append(_retorno[a])
	
	if atualizar_texto_padrao:
		_set_textopadrao($MenuButton.get_popup().get_item_text(index))

	# Guarda a posição para a navegação por scroll (a seleção única não fica marcada para consultar).
	_indice_atual = index
	emit_signal("opcao_selecionada", _retorno[index], lista_selecionada)
#endregion
