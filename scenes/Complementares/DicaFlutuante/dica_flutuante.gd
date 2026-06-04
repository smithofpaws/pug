class_name DicaFlutuante extends PanelContainer
## Dica flutuante reutilizavel, exibida ao passar o mouse sobre qualquer [Control].
## [br]
## Suporta texto com BBCode. Uso tipico: [codeblock]
## DicaFlutuante.vincular(meu_botao, "[b]Salvar[/b]\nGrava o planejamento em disco.")
## [/codeblock]
## A dica e posicionada junto ao cursor. Para renderizar acima de qualquer popup
## (AcceptDialog, ConfirmationDialog) em GL Compatibility, ela e criada como uma
## sub-window filha da [b]janela do controle de origem[/b] -- a mesma estrategia do
## tooltip nativo da engine ([code]Viewport::_gui_show_tooltip[/code]). Sub-windows
## embutidas renderizam acima do conteudo (canvas) da janela que as contem, entao
## uma dica dentro da arvore do dialogo aparece acima do conteudo dele.

# Atraso (s) entre o mouse entrar no controle e a dica aparecer.
const _ATRASO_SEGUNDOS := 0.4

# Deslocamento da dica em relacao ao cursor.
const _MARGEM_CURSOR := Vector2(14, 18)

# Largura maxima antes de quebrar linha.
const _LARGURA_MAXIMA := 480.0

# --- Estado persistente -----------------------------------------------------
# Vive na root (nunca dentro de um dialogo), para nao ser liberado quando um
# dialogo fechar. O Timer agenda a exibicao; o popup e efemero (recriado a cada
# exibicao e liberado ao esconder).
static var _timer: Timer
static var _texto_pendente: String = ""
static var _control_origem: Control
static var _popup: Window

# --- Membros de instancia (cada painel e recriado a cada exibicao) ----------
var _rotulo: RichTextLabel


## Vincula uma dica (com BBCode) a [param control], exibida ao passar o mouse. [br]
## Texto vazio remove a dica. Revincular com texto novo apenas atualiza o conteudo.
static func vincular(control: Control, texto_bbcode: String) -> void:
	if not is_instance_valid(control):
		return
	if texto_bbcode.strip_edges().is_empty():
		if control.has_meta("dica_texto"):
			control.remove_meta("dica_texto")
		return
	control.set_meta("dica_texto", texto_bbcode)
	if control.has_meta("dica_vinculada"):
		return
	control.set_meta("dica_vinculada", true)
	control.mouse_filter = Control.MOUSE_FILTER_PASS
	control.mouse_entered.connect(_ao_entrar.bind(control))
	control.mouse_exited.connect(_ao_sair)
	control.tree_exiting.connect(_ao_sair)


## Exibe a dica flutuante na posicao atual do mouse apos o atraso padrao, sem vinculo
## com um [Control] especifico. Util para tooltips em texto BBCode via [url] em RichTextLabel.
## Para esconder antes do atraso, chame [method esconder].
static func mostrar_em(texto_bbcode: String) -> void:
	_garantir_timer()
	if not is_instance_valid(_timer):
		return
	_timer.stop()
	_texto_pendente = texto_bbcode
	_control_origem = null
	_timer.start(_ATRASO_SEGUNDOS)


## Esconde a dica flutuante se estiver visivel. Seguro chamar mesmo quando ja oculta.
static func esconder() -> void:
	_ao_sair()


# --- Internos ---------------------------------------------------------------

static func _ao_entrar(control: Control) -> void:
	_garantir_timer()
	if not is_instance_valid(_timer):
		return
	_timer.stop()
	_texto_pendente = str(control.get_meta("dica_texto", ""))
	_control_origem = control
	_timer.start(_ATRASO_SEGUNDOS)


static func _ao_sair() -> void:
	if is_instance_valid(_timer):
		_timer.stop()
	if is_instance_valid(_popup):
		_popup.queue_free()
	_popup = null


# Garante o Timer compartilhado, criado uma vez como filho da root.
static func _garantir_timer() -> void:
	if is_instance_valid(_timer):
		return
	var loop := Engine.get_main_loop()
	if not loop is SceneTree:
		return
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_mostrar)
	(loop as SceneTree).root.add_child(_timer)


# Cria a sub-window da dica como filha da janela de origem e a exibe.
static func _mostrar() -> void:
	if _texto_pendente.strip_edges().is_empty():
		return
	if is_instance_valid(_popup):
		_popup.queue_free()
		_popup = null

	var alvo := _janela_destino()
	if not is_instance_valid(alvo):
		return

	var painel := DicaFlutuante.new()

	var janela := Window.new()
	janela.visible = false
	janela.borderless = true
	janela.unresizable = true
	janela.transparent = true
	janela.transparent_bg = true
	# Sem foco e transparente ao mouse: nao rouba o mouse-over do controle de
	# origem (logo nao dispara seu mouse_exited) nem o foco de teclado.
	janela.set_flag(Window.FLAG_NO_FOCUS, true)
	janela.set_flag(Window.FLAG_MOUSE_PASSTHROUGH, true)
	# FLAG_POPUP desligado: nao queremos auto-fechar ao perder foco nem captura
	# global de input -- a visibilidade e gerida manualmente em _ao_sair.
	janela.set_flag(Window.FLAG_POPUP, false)
	janela.add_child(painel)

	_popup = janela
	# Ao entrar na arvore, _ready do painel monta a UI; depois exibimos.
	alvo.add_child(janela)
	painel._exibir(_texto_pendente)


# Janela onde a dica deve ser criada: a do controle de origem (se houver) ou a
# sub-window sob o mouse (para mostrar_em, que nao tem controle).
static func _janela_destino() -> Window:
	if is_instance_valid(_control_origem) and _control_origem.is_inside_tree():
		return _control_origem.get_window()
	return _janela_sob_mouse()


static func _janela_sob_mouse() -> Window:
	var loop := Engine.get_main_loop()
	if not loop is SceneTree:
		return null
	var raiz: Window = (loop as SceneTree).root
	var alvo: Window = raiz
	var mouse: Vector2 = raiz.get_mouse_position()
	# Sub-windows embutidas posicionam-se no espaco da root; a ultima visivel que
	# contem o mouse e a mais ao topo.
	for filho in raiz.get_children():
		var w := filho as Window
		if w != null and w.visible and Rect2(Vector2(w.position), Vector2(w.size)).has_point(mouse):
			alvo = w
	return alvo


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_rotulo = RichTextLabel.new()
	_rotulo.bbcode_enabled = true
	_rotulo.fit_content = true
	_rotulo.scroll_active = false
	_rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rotulo.custom_minimum_size = Vector2(_LARGURA_MAXIMA, 0)
	_rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rotulo)

	_aplicar_tema()


func _aplicar_tema() -> void:
	var fundo: Color = PaletaSemantica.fundo()
	fundo.a = 0.97
	var texto: Color = PaletaSemantica.cor("padrao")
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = fundo
	estilo.border_color = PaletaSemantica.fundo().lerp(texto, 0.35)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(4)
	estilo.set_content_margin_all(8)
	add_theme_stylebox_override("panel", estilo)
	if _rotulo:
		_rotulo.add_theme_color_override("default_color", texto)


# Preenche, dimensiona e exibe a dica. Reaplica tamanho/posicao apos um frame,
# pois o fit_content do RichTextLabel pode so resolver a altura no proximo layout.
func _exibir(texto: String) -> void:
	_rotulo.text = texto
	reset_size()
	var janela := get_parent() as Window
	if not is_instance_valid(janela):
		return
	janela.size = Vector2i(size)
	_reposicionar()
	janela.show()
	# Reaplica tamanho/posicao no proximo frame via conexao one-shot (e nao [code]await[/code]):
	# se este painel for liberado nesse meio tempo — ex.: a dica e escondida ao alternar paineis,
	# que chama [method _ao_sair] -> [code]queue_free[/code] —, a conexao some junto com o objeto e
	# o callback nao roda. Um [code]await[/code] aqui retomaria sobre um objeto ja deletado, gerando
	# repetidamente o erro "Object was deleted while awaiting a callback".
	get_tree().process_frame.connect(_reajustar, CONNECT_ONE_SHOT)


# Segundo passe de layout: so executa se o painel (self) e a janela ainda forem validos.
func _reajustar() -> void:
	var janela := get_parent() as Window
	if not is_instance_valid(janela) or not janela.visible:
		return
	reset_size()
	janela.size = Vector2i(size)
	_reposicionar()


func _reposicionar() -> void:
	var janela := get_parent() as Window
	if not is_instance_valid(janela):
		return
	# A position da sub-window e relativa a quem a embute, e a root embute todas
	# as sub-windows (dialogos inclusive): um AcceptDialog nao embute as proprias.
	# Por isso lemos mouse e limites no espaco da root, e nao da janela-alvo da
	# arvore -- senao a dica nasceria deslocada pelo offset do dialogo.
	var ref: Window = get_tree().root
	var mouse: Vector2 = ref.get_mouse_position()
	var area: Vector2 = Vector2(ref.size)
	var tam: Vector2 = Vector2(janela.size)
	var pos: Vector2 = mouse + _MARGEM_CURSOR
	if pos.x + tam.x > area.x:
		pos.x = mouse.x - tam.x - _MARGEM_CURSOR.x
	if pos.y + tam.y > area.y:
		pos.y = mouse.y - tam.y - _MARGEM_CURSOR.y
	pos.x = maxf(0.0, pos.x)
	pos.y = maxf(0.0, pos.y)
	janela.position = Vector2i(pos)
