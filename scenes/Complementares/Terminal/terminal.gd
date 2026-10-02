class_name Terminal extends ReferenceRect
## Terminal de saída dos módulos. Renderiza BBCode (cores/efeitos) num RichTextLabel. [br]
## [br]
## [b]Apresentação padronizada (markdown + tokens):[/b] o conteúdo textual usa markdown
## ([code]#[/code]/[code]##[/code] para títulos, [code]- [/code] para listas, [code]---[/code]
## para separador) e a cor vem do token semântico. Como o clipboard de um RichTextLabel recebe
## só o texto visível (sem as tags de cor), copiar a saída resulta em markdown válido, enquanto
## a cor cumpre o papel semântico apenas na tela. Preferir os helpers [method titulo],
## [method secao], [method item], [method linha], [method separador] e [method espaco] em vez de
## montar a formatação à mão; usar [method text_edit] direto só para linhas compostas multi-cor. [br]
## [br]
## Com o foco no texto, Ctrl+F abre uma faixa de busca (lógica em [BuscaTerminal]).

const _ALPHA_REALCE_TODAS: float = 0.25
const _ALPHA_REALCE_ATUAL: float = 0.6
const _LINHAS_CONTEXTO: int = 3

# Histórico do que foi escrito, para re-renderizar com a paleta correta ao trocar de tema.
# Cada entrada: { "texto": String, "token": String, "efeito": String, "nl": bool, "bg": String }.
var _buffer: Array[Dictionary] = []

# Tooltips registrados para meta hover via [url] BBCode: { chave → texto_bbcode }.
var _meta_tooltips: Dictionary = {}

# Estado da busca (Ctrl+F). O índice é um retrato do buffer tirado ao abrir; qualquer escrita fecha a busca.
var _busca_aberta: bool = false
var _indice_busca: Dictionary = {}
var _ocorrencias: Array[Vector2i] = []
var _atual: int = -1
# Invalida rolagens adiadas (await) quando a busca muda ou fecha antes de o layout ficar pronto.
var _geracao_rolagem: int = 0

func _ready() -> void:
	_atualizar_fundo()
	$"%TextEdit".meta_hover_started.connect(_on_meta_hover_started)
	$"%TextEdit".meta_hover_ended.connect(_on_meta_hover_ended)
	$"%TextEdit".gui_input.connect(_on_text_edit_gui_input)
	$"%CampoBusca".gui_input.connect(_on_campo_busca_gui_input)
	$"%CampoBusca".text_changed.connect(_on_campo_busca_text_changed)
	$"%TimerBusca".timeout.connect(_on_timer_busca_timeout)
	$"%BotaoAnterior".pressed.connect(_navegar.bind(false))
	$"%BotaoProxima".pressed.connect(_navegar.bind(true))
	$"%BotaoFechar".pressed.connect(_fechar_busca.bind(true))
	DicaFlutuante.vincular($"%BotaoAnterior", "Ocorrência anterior (Shift+Enter)")
	DicaFlutuante.vincular($"%BotaoProxima", "Próxima ocorrência (Enter)")
	DicaFlutuante.vincular($"%BotaoFechar", "Fechar a busca (Esc)")

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_atualizar_fundo()
		# Reaplica as cores de todo o histórico ao novo tema, sem envolver os módulos.
		_renderizar()


## Registra um tooltip para exibicao ao passar o mouse sobre um marcador [url=chave] no texto.
## [param chave] e o identificador unico usado no BBCode [code][url=chave][/code].
## [param texto_bbcode] e o conteudo do tooltip com suporte a BBCode.
func registrar_meta(chave: String, texto_bbcode: String) -> void:
	_meta_tooltips[chave] = texto_bbcode


## Escreve [param text] no terminal com a cor do token [param color] (chave semântica, nome de cor ou
## hex). O Terminal resolve e adapta a cor ao tema atual; o módulo só informa o token. [br]
## [param newline] insere quebra de linha antes do texto; [param clear] limpa o histórico antes de
## escrever; [param effect] aplica um efeito (ex.: [code]"shake"[/code]).
## [param bg] (opcional): cor de fundo em hex (ex.: [code]"#2e7d3280"[/code], aceita alpha) aplicada
## via [code][bgcolor][/code]. Diferente de [param color], não é um token semântico nem passa por
## adaptação de tema — é emitida literal (usar hex com alpha para legibilidade).
func text_edit(text: String, color: String = "padrao", newline: bool = true, clear: bool = false, effect: String = "", bg: String = "") -> void:
	if _busca_aberta:
		_fechar_busca(false)
	if clear:
		_buffer.clear()
		_meta_tooltips.clear()
		$"%TextEdit".set_text("")
	var entrada: Dictionary = {"texto": text, "token": color, "efeito": effect, "nl": newline and not clear, "bg": bg}
	_buffer.append(entrada)
	# Acrescimo incremental (mesmo custo de antes); a re-renderização total só ocorre na troca de tema.
	$"%TextEdit".set_text($"%TextEdit".get_text() + _segmento_bbcode(entrada, text))


## Título de relatório/análise em markdown ([code]# texto[/code]), token [code]alerta[/code].
## [param limpar] reinicia o terminal antes de escrever (início de um novo relatório).
func titulo(texto: String, limpar: bool = false) -> void:
	text_edit("# " + texto, "alerta", true, limpar)


## Cabeçalho de seção em markdown ([code]## texto[/code]), token [code]alerta[/code].
func secao(texto: String) -> void:
	text_edit("## " + texto, "alerta")


## Cabeçalho de subseção em markdown ([code]### texto[/code]), token [code]alerta[/code].
func subsecao(texto: String) -> void:
	text_edit("### " + texto, "alerta")


## Item de lista em markdown ([code]- texto[/code]). [param nivel] indenta com 2 espaços por
## nível; [param token] colore a linha (padrão neutro); [param bg] (hex, opcional) aplica cor de
## fundo na linha (ver [method text_edit]).
func item(texto: String, nivel: int = 0, token: String = "padrao", bg: String = "") -> void:
	text_edit("  ".repeat(nivel) + "- " + texto, token, true, false, "", bg)


## Linha simples (corpo ou status), colorida pelo [param token].
func linha(texto: String, token: String = "padrao") -> void:
	text_edit(texto, token)


## Linha em branco para separar blocos.
func espaco() -> void:
	text_edit("")


## Separador horizontal markdown ([code]---[/code]), precedido de linha em branco para não ser
## interpretado como sublinhado de título (setext) da linha anterior.
func separador() -> void:
	text_edit("")
	text_edit("---")

# Acompanha o fundo do tema no ColorRect de fundo do terminal, aplicando a translucidez dos painéis
# (alpha_painel): empilhada sobre o backdrop, deixa o terminal mais opaco que o fundo geral.
func _atualizar_fundo() -> void:
	var style := get_theme_stylebox("panel", "PanelContainer")
	if style is StyleBoxFlat:
		var c: Color = style.bg_color
		c.a = PaletaSemantica.alpha_painel()
		$ColorRect.color = c

# Reconstrói todo o texto a partir do buffer, resolvendo as cores no tema atual e aplicando o
# realce da busca (se aberta). Preserva a rolagem: o realce não muda as métricas do texto.
func _renderizar() -> void:
	var textos: Array[String] = []
	if _busca_aberta and not _ocorrencias.is_empty():
		var cores: PackedStringArray = _cores_realce()
		textos = BuscaTerminal.realcar(_indice_busca, _ocorrencias, _atual, cores[0], cores[1])
		if textos.size() != _buffer.size():
			textos = []
	var partes := PackedStringArray()
	for i in range(_buffer.size()):
		var texto: String = textos[i] if not textos.is_empty() else str(_buffer[i]["texto"])
		partes.append(_segmento_bbcode(_buffer[i], texto))
	var barra: VScrollBar = $"%TextEdit".get_v_scroll_bar()
	var rolagem: float = barra.value
	$"%TextEdit".set_text("".join(partes))
	barra.value = rolagem

# Monta o trecho de BBCode de uma entrada com o [texto] dado, com a cor já adaptada ao contraste do tema.
func _segmento_bbcode(entrada: Dictionary, texto: String) -> String:
	var cor_hex: String = PaletaSemantica.cor_hex(entrada["token"])
	var efeito_ini: String = ""
	var efeito_fim: String = ""
	if entrada["efeito"] == "shake":
		efeito_ini = "[shake rate=20.0 level=10]"
		efeito_fim = "[/shake]"
	# Fundo opcional (hex literal): envolve o texto por dentro da tag de cor.
	var bg: String = entrada.get("bg", "")
	var bg_ini: String = "[bgcolor=" + bg + "]" if not bg.is_empty() else ""
	var bg_fim: String = "[/bgcolor]" if not bg.is_empty() else ""
	var prefixo: String = "\n" if entrada["nl"] else ""
	return prefixo + "[color=" + cor_hex + "]" + bg_ini + efeito_ini + texto + efeito_fim + bg_fim + "[/color]"

# Abre a faixa de busca (ou volta ao campo e seleciona o termo, se já aberta).
func _abrir_busca() -> void:
	if not _busca_aberta:
		_busca_aberta = true
		_indice_busca = BuscaTerminal.indexar(_buffer)
		$"%FaixaBusca".visible = true
		if not $"%CampoBusca".text.is_empty():
			_executar_busca()
	$"%CampoBusca".grab_focus()
	$"%CampoBusca".select_all()

# Fecha a faixa e remove o realce. Esc e botão devolvem o foco ao texto; mudança de conteúdo não,
# para não roubar o foco de quem trocou o aluno num seletor.
func _fechar_busca(devolver_foco: bool) -> void:
	if not _busca_aberta:
		return
	_busca_aberta = false
	$"%TimerBusca".stop()
	_geracao_rolagem += 1
	var havia_realce: bool = not _ocorrencias.is_empty()
	_ocorrencias = []
	_atual = -1
	_indice_busca = {}
	if devolver_foco:
		$"%TextEdit".grab_focus()
	$"%FaixaBusca".visible = false
	if havia_realce:
		_renderizar()

func _executar_busca() -> void:
	var havia_realce: bool = not _ocorrencias.is_empty()
	_ocorrencias = BuscaTerminal.buscar(_indice_busca, $"%CampoBusca".text)
	_atual = 0 if not _ocorrencias.is_empty() else -1
	if havia_realce or not _ocorrencias.is_empty():
		_renderizar()
	_atualizar_contador()
	if _atual >= 0:
		_rolar_para_atual()

# Enter logo depois de digitar vale sobre o termo novo: executa a busca pendente antes de navegar.
func _descarregar_busca_pendente() -> void:
	if not $"%TimerBusca".is_stopped():
		$"%TimerBusca".stop()
		_executar_busca()

func _navegar(para_frente: bool) -> void:
	_descarregar_busca_pendente()
	if _ocorrencias.is_empty():
		return
	var total: int = _ocorrencias.size()
	_atual = BuscaTerminal.proxima(_atual, total) if para_frente else BuscaTerminal.anterior(_atual, total)
	_renderizar()
	_atualizar_contador()
	_rolar_para_atual()

# Realce de "todas" e da "atual": o mesmo token de seleção do tema, só muda a intensidade.
func _cores_realce() -> PackedStringArray:
	var base: Color = PaletaSemantica.cor("selecao")
	var todas: Color = base
	todas.a = _ALPHA_REALCE_TODAS
	var atual: Color = base
	atual.a = _ALPHA_REALCE_ATUAL
	return PackedStringArray(["#" + todas.to_html(true), "#" + atual.to_html(true)])

func _atualizar_contador() -> void:
	var contador: Label = $"%ContadorBusca"
	if $"%CampoBusca".text.strip_edges().is_empty():
		contador.text = ""
	elif _ocorrencias.is_empty():
		contador.text = "0 de 0"
	else:
		contador.text = "%d de %d" % [_atual + 1, _ocorrencias.size()]

# Rola até a ocorrência atual só se a linha dela estiver fora da vista (sem pulo desnecessário).
func _rolar_para_atual() -> void:
	_geracao_rolagem += 1
	var geracao: int = _geracao_rolagem
	var rtl: RichTextLabel = $"%TextEdit"
	var posicao: int = _ocorrencias[_atual].x
	var linha_alvo: int = rtl.get_character_line(posicao)
	if linha_alvo < 0:
		await get_tree().process_frame
		if geracao != _geracao_rolagem or not _busca_aberta:
			return
		linha_alvo = rtl.get_character_line(posicao)
		if linha_alvo < 0:
			return
	var barra: VScrollBar = rtl.get_v_scroll_bar()
	var topo: float = rtl.get_line_offset(linha_alvo)
	var altura: float = rtl.get_line_height(linha_alvo)
	if topo < barra.value or topo + altura > barra.value + barra.page:
		rtl.scroll_to_line(maxi(linha_alvo - _LINHAS_CONTEXTO, 0))

#region Sinais
func _on_meta_hover_started(meta: Variant) -> void:
	var chave: String = str(meta)
	if _meta_tooltips.has(chave):
		DicaFlutuante.mostrar_em(_meta_tooltips[chave])


func _on_meta_hover_ended(_meta: Variant) -> void:
	DicaFlutuante.esconder()


# Ctrl+F abre a busca só com o foco no texto; Esc fecha. O resto (Ctrl+C, Ctrl+A, rolagem) segue igual.
func _on_text_edit_gui_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var tecla := event as InputEventKey
	if not tecla.pressed or tecla.echo:
		return
	if tecla.keycode == KEY_F and tecla.ctrl_pressed and not tecla.shift_pressed and not tecla.alt_pressed and not tecla.meta_pressed:
		$"%TextEdit".accept_event()
		_abrir_busca()
	elif tecla.keycode == KEY_ESCAPE and _busca_aberta:
		$"%TextEdit".accept_event()
		_fechar_busca(true)


func _on_campo_busca_gui_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var tecla := event as InputEventKey
	if not tecla.pressed:
		return
	if tecla.keycode == KEY_ENTER or tecla.keycode == KEY_KP_ENTER:
		$"%CampoBusca".accept_event()
		_navegar(not tecla.shift_pressed)
	elif tecla.echo:
		return
	elif tecla.keycode == KEY_ESCAPE:
		$"%CampoBusca".accept_event()
		_fechar_busca(true)
	elif tecla.keycode == KEY_F and tecla.ctrl_pressed:
		$"%CampoBusca".accept_event()
		$"%CampoBusca".select_all()


func _on_campo_busca_text_changed(_texto: String) -> void:
	$"%TimerBusca".start()


func _on_timer_busca_timeout() -> void:
	_executar_busca()
#endregion
