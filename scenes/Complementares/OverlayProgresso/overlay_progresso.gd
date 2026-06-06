# Auxiliar Coordenacao
# Copyright (C) 2026 DIEGO ARTHUR HARTMANN
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

class_name OverlayProgresso extends CanvasLayer
## Sobreposicao modal de progresso, mostrada durante calculos demorados (ex.: condicoes_discentes
## sobre um hist.csv grande). Fica acima de toda a interface e comunica que o programa esta
## processando, em vez de parecer travado. [br]
## [br]
## Uso tipico (em main.gd): [method mostrar] antes do laco, [method definir_progresso] a cada
## bloco de itens (com [code]await get_tree().process_frame[/code] para repintar), [method ocultar]
## ao terminar. Construido por codigo (sem .tscn) para nao depender de edicao de cena.

# Veu semitransparente que escurece a interface por tras do painel.
var _scrim: ColorRect
# Texto descritivo do que esta sendo calculado.
var _label: Label
# Barra de progresso (0..100).
var _barra: ProgressBar

func _ready() -> void:
	# Camada bem acima do conteudo normal para cobrir tudo.
	layer = 128
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	_scrim = ColorRect.new()
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	var cor_scrim := Color(0, 0, 0, 0.45)
	_scrim.color = cor_scrim
	# Bloqueia cliques na interface por tras enquanto o calculo roda.
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_scrim)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centro)

	var painel := PanelContainer.new()
	centro.add_child(painel)

	var margem := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 16)
	painel.add_child(margem)

	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 12)
	caixa.custom_minimum_size = Vector2(320, 0)
	margem.add_child(caixa)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caixa.add_child(_label)

	_barra = ProgressBar.new()
	_barra.min_value = 0
	_barra.max_value = 100
	_barra.value = 0
	_barra.custom_minimum_size = Vector2(0, 22)
	caixa.add_child(_barra)

## Exibe a sobreposicao com o [param texto] descritivo e zera a barra.
func mostrar(texto: String) -> void:
	_label.text = texto
	_barra.value = 0
	_barra.show_percentage = true
	visible = true

## Atualiza a barra para [param fracao] (0.0 a 1.0). Se [param texto] for informado, troca o rotulo.
func definir_progresso(fracao: float, texto: String = "") -> void:
	_barra.value = clampf(fracao, 0.0, 1.0) * 100.0
	if not texto.is_empty():
		_label.text = texto

## Oculta a sobreposicao.
func ocultar() -> void:
	visible = false
