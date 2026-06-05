class_name HachuraOverlay extends Control
## Overlay que desenha hachura diagonal (linhas escuras) sobre uma célula da grade, indicando um
## estado temporário — ex.: horários a evitar ao mover uma disciplina (choque de semestre ou de
## professor). Não recebe eventos do mouse (o controle abaixo continua arrastável/clicável).

const _COR := Color(0, 0, 0, 0.55)
const _ESPACAMENTO := 7.0
const _ESPESSURA := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Recorta o desenho aos limites da célula: as linhas diagonais começam/terminam fora do
	# retângulo e, sem clip, vazariam para os lados.
	clip_contents = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


# Desenha linhas diagonais paralelas (de baixo-esquerda para cima-direita) cobrindo todo o retângulo.
func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var x: float = -h
	while x < w:
		draw_line(Vector2(x, h), Vector2(x + h, 0.0), _COR, _ESPESSURA, true)
		x += _ESPACAMENTO
