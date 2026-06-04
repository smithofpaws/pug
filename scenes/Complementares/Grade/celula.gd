class_name Celula extends ReferenceRect
## Celula ligada ao componente [GradeVisual].
##
## Verificar [method Grade], para mais detalhes sobre a aplicação.

signal clicado
signal clicado_direito
signal clicado_meio
signal celula_dropada(linha: int, coluna: int, dados: Dictionary)
signal arraste_iniciado(linha: int, coluna: int)

## String do texto do centro.
var texto_central: String : set = _set_texto_central

## Cor do texto central.
var cor_central: String = "white" : set = _set_cor_central

## Cor do fundo
var cor_fundo: Color = Color(0.173, 0.173, 0.173, 1): set = _set_cor_fundo

## Quando não-transparente, substitui o processamento de [method cor_adaptada] e usa esta cor literal para o texto.
var cor_texto_override: Color = Color.TRANSPARENT : set = _set_cor_texto_override

## Cor barra superior (atalho que define as quatro bordas de uma vez).
var cor_barra_superior: set = _set_cor_barra_superior

## Cor barra cima
var cor_barra_cima = Color(0, 0, 0, 0): set = _set_cor_barra_cima

## Cor barra baixo
var cor_barra_baixo = Color(0, 0, 0, 0): set = _set_cor_barra_baixo

## Cor barra esquerda
var cor_barra_esquerda = Color(0, 0, 0, 0): set = _set_cor_barra_esquerda

## Cor barra direita
var cor_barra_direita = Color(0, 0, 0, 0): set = _set_cor_barra_direita

var _barras: Dictionary = {}

## Quando true oculta todos os textos, deixando apenas o central.
## Labels de canto com texto não vazio permanecem visíveis (ver [method _set_apenas_central]).
var apenas_central: bool : set = _set_apenas_central

## Texto exibido no canto superior esquerdo (ex.: código da disciplina na grade curricular).
var texto_canto_superior_esquerdo: String : set = _set_texto_canto_se

## Texto exibido no canto superior direito (ex.: carga horária na grade curricular).
var texto_canto_superior_direito: String : set = _set_texto_canto_sd

## Texto BBCode exibido no rodapé da célula (ex.: contagens por situação no Planejamento de Oferta).
## Aceita tokens [code][color=<token>][/code] resolvidos por [method _traduzir_cores] conforme o tema.
## Vazio oculta o rodapé.
var texto_rodape: String : set = _set_texto_rodape

## Quando true, aplica leve clareamento/escurecimento ao fundo para criar faixas alternadas por linha.
var faixa_alternada: bool : set = _set_faixa_alternada

## Índice da coluna da célula na grade. Preenchido externamente pelo [Grade].
var xpos: int

## Índice da linha da célula na grade. Preenchido externamente pelo [Grade].
var ypos: int

## Chave da alocação nesta célula ("linha_coluna"). Preenchida externamente pelo PlanejamentoHorario.
var alocacao_chave: String = ""

var _drag_hovering: bool = false
var _arrastando: bool = false
var _cor_barra_cima_salva: Color = Color(0, 0, 0, 0)
var _cor_barra_baixo_salva: Color = Color(0, 0, 0, 0)
var _cor_barra_esquerda_salva: Color = Color(0, 0, 0, 0)
var _cor_barra_direita_salva: Color = Color(0, 0, 0, 0)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if alocacao_chave.is_empty() or ypos == 0 or xpos == 0:
		return null
	_arrastando = true
	arraste_iniciado.emit(ypos, xpos)
	var preview := Label.new()
	preview.text = texto_central
	preview.add_theme_color_override("font_color", Color.WHITE)
	set_drag_preview(preview)
	return {
		"codigo": texto_central.to_lower(),
		"chave": alocacao_chave,
		"origem": "celula",
		"linha_origem": ypos,
		"coluna_origem": xpos,
	}

func _can_drop_data(_position: Vector2, data) -> bool:
	if data is Dictionary and data.has("codigo") and data.has("chave"):
		var grade := get_parent().get_parent()
		if grade is GradeVisual:
			grade._limpar_highlight_todas_celulas()
		if not _drag_hovering:
			_cor_barra_cima_salva = cor_barra_cima
			_cor_barra_baixo_salva = cor_barra_baixo
			_cor_barra_esquerda_salva = cor_barra_esquerda
			_cor_barra_direita_salva = cor_barra_direita
		_drag_hovering = true
		cor_barra_superior = PaletaSemantica.cor("selecao")
		return true
	return false

func _drop_data(_position: Vector2, data) -> void:
	_restaurar_cores_originais()
	_drag_hovering = false
	celula_dropada.emit(ypos, xpos, data)

func limpar_highlight_drag() -> void:
	if _drag_hovering:
		_drag_hovering = false
		_restaurar_cores_originais()

func _restaurar_cores_originais() -> void:
	cor_barra_cima = _cor_barra_cima_salva
	cor_barra_baixo = _cor_barra_baixo_salva
	cor_barra_esquerda = _cor_barra_esquerda_salva
	cor_barra_direita = _cor_barra_direita_salva

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_arrastando = false
		if _drag_hovering:
			_drag_hovering = false
			_restaurar_cores_originais()
	elif what == NOTIFICATION_THEME_CHANGED:
		# Reaplica a cor do texto adaptada ao novo fundo do tema.
		_update_button()

func _ready() -> void:
	# Código de arraste desabilitado — evita processamento ocioso por frame em cada célula.
	set_process(false)
	_criar_barras_borda()

# Cria as quatro barras de borda (ColorRect) que permitem marcação independente de cada lado.
func _criar_barras_borda() -> void:
	var configs := {
		"cima":     {"anc_l": 0.0, "anc_t": 0.0, "anc_r": 1.0, "anc_b": 0.0, "off_l": 0.0, "off_t": 0.0, "off_r": 0.0, "off_b": 4.0},
		"baixo":    {"anc_l": 0.0, "anc_t": 1.0, "anc_r": 1.0, "anc_b": 1.0, "off_l": 0.0, "off_t": -4.0, "off_r": 0.0, "off_b": 0.0},
		"esquerda": {"anc_l": 0.0, "anc_t": 0.0, "anc_r": 0.0, "anc_b": 1.0, "off_l": 0.0, "off_t": 0.0, "off_r": 4.0, "off_b": 0.0},
		"direita":  {"anc_l": 1.0, "anc_t": 0.0, "anc_r": 1.0, "anc_b": 1.0, "off_l": -4.0, "off_t": 0.0, "off_r": 0.0, "off_b": 0.0},
	}
	for lado in configs:
		var rect := ColorRect.new()
		rect.name = "Barra_" + lado.capitalize()
		rect.mouse_filter = MOUSE_FILTER_IGNORE
		rect.color = get("cor_barra_" + lado)
		var c = configs[lado]
		rect.anchor_left = c["anc_l"]
		rect.anchor_top = c["anc_t"]
		rect.anchor_right = c["anc_r"]
		rect.anchor_bottom = c["anc_b"]
		rect.offset_left = c["off_l"]
		rect.offset_top = c["off_t"]
		rect.offset_right = c["off_r"]
		rect.offset_bottom = c["off_b"]
		add_child(rect)
		_barras[lado] = rect

# Atualiza o botão.
func _update_button() -> void:
	# Se o fundo ainda é o padrão escuro de fábrica, usa a cor do painel do tema.
	var fundo := cor_fundo
	if fundo == Color(0.173, 0.173, 0.173, 1):
		var style_panel := get_theme_stylebox("panel", "PanelContainer")
		if style_panel is StyleBoxFlat:
			fundo = style_panel.bg_color
	# Faixa alternada: leve variação de luminância para distinguir linhas adjacentes.
	if faixa_alternada:
		fundo = fundo.lightened(0.03) if fundo.get_luminance() < 0.5 else fundo.darkened(0.03)
	# Texto central com cor adaptada ao contraste deste fundo (lido na hora, imune a cache de tema).
	var cor_texto := get_theme_color("font_color", "Label")
	# Traduz eventuais tokens de cor embutidos no texto (ex.: grade de horarios) para o tema atual.
	$ScrollContainer/VBoxContainer/RichTextLabel.set_text(_traduzir_cores(texto_central, fundo, cor_texto))
	if cor_texto_override != Color.TRANSPARENT:
		$ScrollContainer/VBoxContainer/RichTextLabel.add_theme_color_override("default_color", cor_texto_override)
	else:
		$ScrollContainer/VBoxContainer/RichTextLabel.add_theme_color_override("default_color", PaletaSemantica.cor_adaptada(cor_central, fundo, cor_texto))
	# Rodapé opcional (ex.: contagens por situação na grade de oferta), com cores resolvidas ao fundo.
	var rt_rodape: RichTextLabel = get_node_or_null("RodapeRich")
	if rt_rodape:
		if texto_rodape.is_empty():
			rt_rodape.visible = false
		else:
			rt_rodape.visible = true
			rt_rodape.text = _traduzir_cores(texto_rodape, fundo, cor_texto)
			rt_rodape.add_theme_color_override("default_color", cor_texto)
	# Cria StyleBoxFlat próprio para o fundo da célula, sem depender do tema.
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = fundo
	style_normal.border_width_left = 1
	style_normal.border_width_right = 1
	style_normal.border_width_top = 1
	style_normal.border_width_bottom = 1
	# Borda visível em qualquer tema: clareia sobre fundo escuro, escurece sobre fundo claro.
	style_normal.border_color = fundo.lightened(0.4) if fundo.get_luminance() < 0.5 else fundo.darkened(0.4)
	# Cantos arredondados dão aparência de cartão, aproximando do visual das imagens de referência.
	style_normal.corner_radius_top_left = 4
	style_normal.corner_radius_top_right = 4
	style_normal.corner_radius_bottom_left = 4
	style_normal.corner_radius_bottom_right = 4
	$Button.add_theme_stylebox_override("normal", style_normal)
	var style_hover := style_normal.duplicate()
	style_hover.bg_color = fundo.lightened(0.1)
	$Button.add_theme_stylebox_override("hover", style_hover)
	var style_pressed := style_normal.duplicate()
	style_pressed.bg_color = fundo.darkened(0.1)
	$Button.add_theme_stylebox_override("pressed", style_pressed)

# RegEx compilada uma unica vez para localizar tags [color=...] no texto da celula.
static var _regex_cor: RegEx = null

# Substitui cada [color=<token>] por [color=#rrggbb] resolvido e adaptado ao [param fundo].
# Texto sem tags de cor (ex.: grade curricular) e devolvido sem alteracao.
func _traduzir_cores(texto: String, fundo: Color, cor_texto: Color) -> String:
	if not texto.contains("[color="):
		return texto
	if _regex_cor == null:
		_regex_cor = RegEx.new()
		_regex_cor.compile("\\[color=([^\\]]+)\\]")
	var resultado: String = ""
	var pos: int = 0
	for ocorrencia in _regex_cor.search_all(texto):
		resultado += texto.substr(pos, ocorrencia.get_start() - pos)
		var token: String = ocorrencia.get_string(1)
		resultado += "[color=#" + PaletaSemantica.cor_adaptada(token, fundo, cor_texto).to_html(false) + "]"
		pos = ocorrencia.get_end()
	resultado += texto.substr(pos)
	return resultado

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			$ScrollContainer.scroll_vertical -= 20
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			$ScrollContainer.scroll_vertical += 20
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_arrastando = false
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if not _arrastando:
				clicado.emit()
			_arrastando = false
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			clicado_direito.emit()
		elif event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
			clicado_meio.emit()


#region Setgets
func _set_texto_central(new_value: String) -> void:
	texto_central = new_value
	_update_button()

func _set_cor_central(new_value: String) -> void:
	cor_central = new_value
	_update_button()

func _set_cor_fundo(valor) -> void:
	cor_fundo = _para_cor(valor)
	_update_button()

func _set_cor_texto_override(valor: Color) -> void:
	cor_texto_override = valor
	_update_button()

func _set_apenas_central(new_value: bool) -> void:
	apenas_central = new_value
	if apenas_central:
		for child in self.get_children():
			if child != $ScrollContainer and child != $Button and child != $Area2D:
				# Não oculta as barras de borda
				if child in _barras.values():
					continue
				# Mantém visíveis os labels de canto que tenham texto (ex.: código/CH).
				if child is Label and child.text != "":
					continue
				# O rodapé tem sua visibilidade controlada por [method _update_button].
				if child.name == "RodapeRich":
					continue
				child.hide()
	_update_button()

func _set_texto_canto_se(new_value: String) -> void:
	texto_canto_superior_esquerdo = new_value
	$TopoEsquerda.text = new_value
	$TopoEsquerda.visible = new_value != ""

func _set_texto_canto_sd(new_value: String) -> void:
	texto_canto_superior_direito = new_value
	$TopoDireita.text = new_value
	$TopoDireita.visible = new_value != ""

func _set_texto_rodape(new_value: String) -> void:
	texto_rodape = new_value
	_update_button()

func _set_faixa_alternada(new_value: bool) -> void:
	faixa_alternada = new_value
	_update_button()

func _para_cor(valor) -> Color:
	if valor is Color:
		return valor
	if valor is String:
		return Color(valor)
	return Color(0, 0, 0, 0)

func _set_cor_barra_superior(valor) -> void:
	var c := _para_cor(valor)
	_set_cor_barra_cima(c)
	_set_cor_barra_baixo(c)
	_set_cor_barra_esquerda(c)
	_set_cor_barra_direita(c)

func _set_cor_barra_cima(valor) -> void:
	cor_barra_cima = _para_cor(valor)
	if _barras.has("cima"):
		_barras["cima"].color = cor_barra_cima

func _set_cor_barra_baixo(valor) -> void:
	cor_barra_baixo = _para_cor(valor)
	if _barras.has("baixo"):
		_barras["baixo"].color = cor_barra_baixo

func _set_cor_barra_esquerda(valor) -> void:
	cor_barra_esquerda = _para_cor(valor)
	if _barras.has("esquerda"):
		_barras["esquerda"].color = cor_barra_esquerda

func _set_cor_barra_direita(valor) -> void:
	cor_barra_direita = _para_cor(valor)
	if _barras.has("direita"):
		_barras["direita"].color = cor_barra_direita
#endregion
