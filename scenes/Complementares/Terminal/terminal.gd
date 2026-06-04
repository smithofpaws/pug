class_name Terminal extends ReferenceRect
## Terminal de saída dos módulos. Renderiza BBCode (cores/efeitos) num RichTextLabel. [br]
## [br]
## [b]Apresentação padronizada (markdown + tokens):[/b] o conteúdo textual usa markdown
## ([code]#[/code]/[code]##[/code] para títulos, [code]- [/code] para listas, [code]---[/code]
## para separador) e a cor vem do token semântico. Como o clipboard de um RichTextLabel recebe
## só o texto visível (sem as tags de cor), copiar a saída resulta em markdown válido, enquanto
## a cor cumpre o papel semântico apenas na tela. Preferir os helpers [method titulo],
## [method secao], [method item], [method linha], [method separador] e [method espaco] em vez de
## montar a formatação à mão; usar [method text_edit] direto só para linhas compostas multi-cor.

# Histórico do que foi escrito, para re-renderizar com a paleta correta ao trocar de tema.
# Cada entrada: { "texto": String, "token": String, "efeito": String, "nl": bool }.
var _buffer: Array[Dictionary] = []

# Tooltips registrados para meta hover via [url] BBCode: { chave → texto_bbcode }.
var _meta_tooltips: Dictionary = {}

func _ready() -> void:
	_atualizar_fundo()
	$"%TextEdit".meta_hover_started.connect(_on_meta_hover_started)
	$"%TextEdit".meta_hover_ended.connect(_on_meta_hover_ended)


## Registra um tooltip para exibicao ao passar o mouse sobre um marcador [url=chave] no texto.
## [param chave] e o identificador unico usado no BBCode [code][url=chave][/code].
## [param texto_bbcode] e o conteudo do tooltip com suporte a BBCode.
func registrar_meta(chave: String, texto_bbcode: String) -> void:
	_meta_tooltips[chave] = texto_bbcode


func _on_meta_hover_started(meta: Variant) -> void:
	var chave: String = str(meta)
	if _meta_tooltips.has(chave):
		DicaFlutuante.mostrar_em(_meta_tooltips[chave])


func _on_meta_hover_ended(_meta: Variant) -> void:
	DicaFlutuante.esconder()

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_atualizar_fundo()
		# Reaplica as cores de todo o histórico ao novo tema, sem envolver os módulos.
		_renderizar()

# Acompanha o fundo do tema no ColorRect de fundo do terminal.
func _atualizar_fundo() -> void:
	var style := get_theme_stylebox("panel", "PanelContainer")
	if style is StyleBoxFlat:
		$ColorRect.color = style.bg_color

## Escreve [param text] no terminal com a cor do token [param color] (chave semântica, nome de cor ou
## hex). O Terminal resolve e adapta a cor ao tema atual; o módulo só informa o token. [br]
## [param newline] insere quebra de linha antes do texto; [param clear] limpa o histórico antes de
## escrever; [param effect] aplica um efeito (ex.: [code]"shake"[/code]).
func text_edit(text: String, color: String = "padrao", newline: bool = true, clear: bool = false, effect: String = "") -> void:
	if clear:
		_buffer.clear()
		_meta_tooltips.clear()
		$"%TextEdit".set_text("")
	var entrada: Dictionary = {"texto": text, "token": color, "efeito": effect, "nl": newline and not clear}
	_buffer.append(entrada)
	# Acrescimo incremental (mesmo custo de antes); a re-renderização total só ocorre na troca de tema.
	$"%TextEdit".set_text($"%TextEdit".get_text() + _segmento_bbcode(entrada))


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
## nível; [param token] colore a linha (padrão neutro).
func item(texto: String, nivel: int = 0, token: String = "padrao") -> void:
	text_edit("  ".repeat(nivel) + "- " + texto, token)


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

# Reconstrói todo o texto a partir do buffer, resolvendo as cores no tema atual.
func _renderizar() -> void:
	var texto_completo: String = ""
	for entrada in _buffer:
		texto_completo += _segmento_bbcode(entrada)
	$"%TextEdit".set_text(texto_completo)

# Monta o trecho de BBCode de uma entrada, com a cor já adaptada ao contraste do tema.
func _segmento_bbcode(entrada: Dictionary) -> String:
	var cor_hex: String = PaletaSemantica.cor_hex(entrada["token"])
	var efeito_ini: String = ""
	var efeito_fim: String = ""
	if entrada["efeito"] == "shake":
		efeito_ini = "[shake rate=20.0 level=10]"
		efeito_fim = "[/shake]"
	var prefixo: String = "\n" if entrada["nl"] else ""
	return prefixo + "[color=" + cor_hex + "]" + efeito_ini + entrada["texto"] + efeito_fim + "[/color]"
