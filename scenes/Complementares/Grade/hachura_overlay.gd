class_name HachuraOverlay extends Control
## Overlay que desenha hachura diagonal (linhas escuras) sobre uma célula da grade, indicando um
## estado temporário — ex.: horários a evitar ao mover uma disciplina (choque de semestre ou de
## professor). Não recebe eventos do mouse (o controle abaixo continua arrastável/clicável). [br]
## [br]
## A variante [member leve] serve a marcações permanentes, que convivem com a leitura normal da
## célula: escurece de leve em vez de riscar. Usada na grade de integralização para as disciplinas
## ainda distantes de serem cursáveis.

const _COR := Color(0, 0, 0, 0.55)
const _ESPACAMENTO := 7.0
const _ESPESSURA := 1.0

# Variante discreta: mesma trama, bem mais transparente e com traço mais largo, para o efeito ser de
# "célula levemente mais escura" e não de rabisco. Ajustar o alpha aqui muda a intensidade.
const _COR_LEVE := Color(0, 0, 0, 0.25)
const _ESPACAMENTO_LEVE := 5.0
const _ESPESSURA_LEVE := 2.0

## Quando true, desenha a variante discreta (ver [member _COR_LEVE]).
var leve: bool = false : set = _set_leve


func _set_leve(novo_valor: bool) -> void:
	leve = novo_valor
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Recorta o desenho aos limites da célula: as linhas diagonais começam/terminam fora do
	# retângulo e, sem clip, vazariam para os lados.
	clip_contents = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


# Desenha linhas diagonais paralelas (de baixo-esquerda para cima-direita) cobrindo todo o retângulo.
func _draw() -> void:
	var cor: Color = _COR_LEVE if leve else _COR
	var espacamento: float = _ESPACAMENTO_LEVE if leve else _ESPACAMENTO
	var espessura: float = _ESPESSURA_LEVE if leve else _ESPESSURA
	var w: float = size.x
	var h: float = size.y
	var x: float = -h
	while x < w:
		draw_line(Vector2(x, h), Vector2(x + h, 0.0), cor, espessura, true)
		x += espacamento
