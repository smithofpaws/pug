class_name PaletaSemantica extends RefCounted
## Paleta de cores semânticas do programa, sob controle da camada de temas. [br]
## [br]
## O [b]significado[/b] de cada cor (a matiz) é definido uma única vez em [member PALETA]; o
## [b]contraste[/b] (a luminosidade) é calculado em tempo de execução contra o fundo do tema atual,
## via [method GeneralFunctions.ajustar_contraste]. Assim, adicionar um tema novo não exige autorar
## cor alguma: a paleta canônica é adaptada automaticamente ao fundo daquele tema. [br]
## [br]
## Para o raro caso em que o resultado automático não agrada num tema específico, use [member OVERRIDES]. [br]
## [br]
## O tema corrente é informado por [method atualizar_tema] (chamado pelo [code]main.gd[/code] e pela
## [code]barraprincipal.gd[/code]). Os consumidores resolvem cores via [method cor] (retorna [Color],
## para a [Celula]) ou [method cor_hex] (retorna [code]#rrggbb[/code], para BBCode do [code]Terminal[/code]
## e da grade de horários).

## Cores canônicas por significado. A matiz/saturação carregam o significado; a luminosidade é
## ajustada em runtime. Tokens neutros ([code]padrao[/code], [code]matriculavel[/code]) não estão aqui:
## resolvem para a cor de texto do tema.
const PALETA: Dictionary = {
	# Situações curriculares.
	"matriculavel_aproveitamento": Color.WEB_GRAY,
	"seaprovado": Color.CADET_BLUE,
	"seaprovado_aproveitamento": Color.DODGER_BLUE,
	"corequisito_matriculavel": Color.WEB_GRAY,
	"corequisito_matriculavel_aproveitamento": Color.DARK_SLATE_GRAY,
	"corequisito_seaprovado": Color.PALE_VIOLET_RED,
	"corequisito_seaprovado_aproveitamento": Color.MEDIUM_VIOLET_RED,
	"matriculado_agora": Color.GREEN,
	"matriculado_agora_aproveitamento": Color.DARK_GREEN,
	"matricula_irregular": Color.RED,
	"matricula_irregular_aproveitamento": Color.BROWN,
	"sem_grade": Color.GOLDENROD,
	"cursada": Color.GOLDENROD,
	# Indicadores de carga horária e alocação (cards de disciplina, painéis, barras de progresso).
	"ch_pendente": Color(0.4, 0.4, 0.4),
	"ch_parcial": Color(0.9, 0.7, 0.0),
	"ch_completo": Color(0.0, 0.65, 0.0),
	"ch_extra": Color(1.0, 0.55, 0.0),
	"ch_complementar": Color(0.2, 0.6, 0.8),
	"excedente": Color(0.9, 0.3, 0.0),
	# Chrome de interface (indicadores neutros e realce de seleção/arraste).
	"neutro": Color(0.5, 0.5, 0.5),
	"selecao": Color(0.3, 0.7, 1.0),
	# Disciplinas de outro curso sobrepostas como referência (somente-leitura).
	"referencia": Color(0.62, 0.52, 0.88),
	# Mensagens do terminal.
	"alerta": Color.GOLDENROD,
	"erro": Color.RED,
	"sucesso": Color.GREEN,
	"aviso": Color.YELLOW,
}

## Sobrescritas opcionais por tema: [code]{ nome_do_tema: { token: Color } }[/code]. Vazio por padrão.
const OVERRIDES: Dictionary = {}

# Tokens neutros: resolvem para a cor de texto do tema, sem adaptação adicional.
const _NEUTRO: Array[String] = ["padrao", "matriculavel", "white", "black"]

# Alvo de contraste padrão (WCAG) e alvo reduzido para variantes sutis (_aproveitamento),
# preservando a hierarquia visual "principal mais forte, aproveitamento mais discreto" em qualquer tema.
const _ALVO_PADRAO: float = 4.5
const _ALVO_SUTIL: float = 3.0

# Estado do tema corrente, alimentado por atualizar_tema().
static var _fundo: Color = Color.BLACK
static var _cor_texto: Color = Color.WHITE
static var _tema_atual: String = ""

# Transparência do fundo (0 = opaco, 1 = totalmente transparente), definida pelo main.gd a partir de
# interface.transparencia_fundo. Usada pelo terminal e pelas células para empilhar sua translucidez
# sobre o backdrop, deixando-os mais opacos que o fundo geral (ver alpha_painel).
static var _transparencia: float = 0.0

## Define a transparência atual do fundo (clamp em [0, 1]). Chamada pelo [code]main.gd[/code].
static func definir_transparencia(t: float) -> void:
	_transparencia = clampf(t, 0.0, 1.0)

## Alpha a aplicar ao fundo dos painéis (terminal, células). Igual ao do véu do backdrop ([code]1 −
## T[/code]): como o painel é desenhado sobre o backdrop, a imagem que o atravessa fica em [code]T²[/code],
## tornando-o mais opaco que o fundo geral. Em T = 0 retorna 1 (opaco, visual inalterado).
static func alpha_painel() -> float:
	return 1.0 - _transparencia

# Tema compartilhado pelas grades (GradeVisual). Define apenas o tamanho da fonte; cores e
# styleboxes continuam herdados do tema global da janela (a busca de tema sobe a arvore item-a-item).
# Por ser um unico recurso compartilhado, alterar seu default_font_size propaga
# NOTIFICATION_THEME_CHANGED a todas as grades/celulas ao vivo.
static var _tema_grades: Theme = null

## Atualiza o tema corrente a partir do recurso [param tema] carregado. Lê o fundo do painel
## ([code]PanelContainer[/code]) e a cor de texto padrão ([code]Label[/code]). [br]
## Deve ser chamado sempre que o tema da janela mudar.
static func atualizar_tema(tema: Theme, nome: String = "") -> void:
	_tema_atual = nome
	if tema == null:
		return
	if tema.has_stylebox("panel", "PanelContainer"):
		var estilo: StyleBox = tema.get_stylebox("panel", "PanelContainer")
		if estilo is StyleBoxFlat:
			_fundo = estilo.bg_color
	if tema.has_color("font_color", "Label"):
		_cor_texto = tema.get_color("font_color", "Label")

## Tema compartilhado das grades. Cada [GradeVisual] o atribui a si ([code]theme[/code]) para herdar
## o tamanho de fonte das grades, mantendo cores/styleboxes do tema global. Lazy-init.
static func tema_grades() -> Theme:
	if _tema_grades == null:
		_tema_grades = Theme.new()
	return _tema_grades

## Define o tamanho da fonte das grades. Por ser num recurso compartilhado, propaga a todas as
## grades e celulas ao vivo. Chamado pelo [code]main.gd[/code].
static func atualizar_fonte_grades(tamanho: int) -> void:
	tema_grades().default_font_size = tamanho

## Cor de fundo do tema corrente (fundo do [code]PanelContainer[/code]), sem adaptação de contraste.
## Útil para chrome que precisa combinar com o fundo em vez de contrastar com ele (ex.: a
## [DicaFlutuante]). Retorna preto até [method atualizar_tema] ser chamado.
static func fundo() -> Color:
	return _fundo

## Resolve [param token] (chave semântica, nome de cor do Godot ou hex) para uma [Color] já adaptada
## ao contraste do tema corrente (usa o fundo e a cor de texto em cache).
static func cor(token: String) -> Color:
	return cor_adaptada(token, _fundo, _cor_texto)

## Igual a [method cor], mas adapta contra um [param fundo] e uma [param cor_texto] informados, sem
## depender do cache do tema. Usar quando o consumidor conhece seu próprio fundo no momento de pintar
## (ex.: [Celula]), evitando dessincronia durante a troca de tema.
static func cor_adaptada(token: String, fundo: Color, cor_texto: Color) -> Color:
	var chave: String = token.strip_edges().to_lower()
	if chave in _NEUTRO:
		return cor_texto
	var base: Color
	var alvo: float = _ALVO_PADRAO
	if OVERRIDES.has(_tema_atual) and OVERRIDES[_tema_atual].has(chave):
		base = OVERRIDES[_tema_atual][chave]
	elif PALETA.has(chave):
		base = PALETA[chave]
		if chave.ends_with("_aproveitamento"):
			alvo = _ALVO_SUTIL
	else:
		# Aceita nomes de cor do Godot ("red") e hexadecimais ("#rrggbb"). Inválido cai na cor de texto.
		base = Color.from_string(token, Color.TRANSPARENT)
		if base == Color.TRANSPARENT:
			return cor_texto
	return GeneralFunctions.ajustar_contraste(base, fundo, alvo)

## Igual a [method cor], mas retorna a cor no formato [code]#rrggbb[/code] para uso em BBCode.
static func cor_hex(token: String) -> String:
	return "#" + cor(token).to_html(false)

## Tokens das mensagens de terminal, como dicionário identidade [code]{token: token}[/code]. Injetado
## nos módulos no lugar do antigo [code]cores_terminal[/code] de [code]base_config.json[/code].
static func tokens_terminal() -> Dictionary:
	return _identidade(["padrao", "alerta", "erro", "sucesso", "aviso"])

## Tokens das situações curriculares, como dicionário identidade. Injetado nos módulos no lugar do
## antigo [code]lista_cores[/code] de [code]base_config.json[/code].
static func tokens_lista() -> Dictionary:
	var chaves: Array = PALETA.keys()
	chaves.append("matriculavel")
	return _identidade(chaves)

# Monta um dicionário identidade {chave: chave} a partir de uma lista de chaves.
static func _identidade(chaves: Array) -> Dictionary:
	var dicionario: Dictionary = {}
	for chave in chaves:
		dicionario[chave] = chave
	return dicionario
