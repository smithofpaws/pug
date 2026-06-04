# Pacote de Utilidades para Graduação (PUG)
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

class_name CardDisciplina extends ReferenceRect
## Card arrastável representando uma disciplina no painel de planejamento de oferta.

## Emitido quando o card recebe clique do mouse ou inicia arrasto.
signal card_interagido(card: CardDisciplina)

## Emitido quando o botão remover do card é pressionado.
signal remover_solicitado(card: CardDisciplina)
##
## Exibe código, nome, professores e carga horária (alocada/total). [br]
## Funciona como fonte de arrasto (drag source) para a grade de horários. [br]
## Cores: cinza = sem horário (0%), amarelo = parcial, verde = completo (100%).

# As cores da barra de status e dos badges são resolvidas em runtime por [PaletaSemantica]
# (tokens [code]ch_*[/code]), adaptando-se ao contraste do tema atual.

## Código da disciplina (ex.: "al0493")
var codigo: String = ""

## Nome da disciplina
var nome: String = ""

## Lista de nomes dos professores
var professores: Array[String] = []

## Carga horária total da disciplina (soma das CHs de todos os professores)
var ch_total: int = 0

## Carga horária já alocada na grade de horários
var ch_alocada: int = 0:
	set(v):
		ch_alocada = v
		_atualizar_visual()

## Semestre/curso da disciplina (ex.: "CC01")
var semestre: String = ""

## Chave composta no dicionário _planejamento_csv
var chave_planejamento: String = ""

## Se verdadeiro, permite arrastar o card mesmo com CH completa (hora extra).
var permite_extra: bool = false

## Contador de horas extras já alocadas.
var ch_extra: int = 0

## Se falso, oculta o botão de hora extra mesmo com a CH completa. [br]
## Usado pelo Planejamento de Oferta, que não possui grade de horários.
var habilita_hora_extra: bool = true:
	set(v):
		habilita_hora_extra = v
		_atualizar_visual()

## Se verdadeiro, exibe o botão remover no card.
var habilita_remover: bool = false:
	set(v):
		habilita_remover = v
		_atualizar_visual()

## Se verdadeiro, indica que a disciplina é complementar/optativa (grade semestre = 0).
## Exibe badge [code]<prefixo>CG[/code] (ex.: "ECCG").
var complementar: bool = false

## Se verdadeiro, indica que a disciplina não pertence ao semestre sendo editado.
## Exibe badge [code]<prefixo>Extra[/code] (ex.: "ECExtra"). Mutuamente exclusivo com [member complementar].
var extra: bool = false

## Prefixo do curso para exibição nos badges (ex.: "EC" para Engenharia Civil).
var prefixo_curso: String = ""

## String original da oferta (célula de semestre do CSV), preservada para indicar
## compartilhamento entre cursos (ex.: "EM02;ECExtra" quando difere de [member semestre]).
var oferta: String = ""

## Unidade de carga horária exibida nos rótulos (ex.: [code]"h"[/code] no Planejamento de
## Horário, [code]"cr"[/code] no Planejamento de Oferta, onde a CH é em créditos).
var unidade_ch: String = "h"

func _ready() -> void:
	$"%BtnHoraExtra".pressed.connect(_on_btn_hora_extra_pressed)
	$"%BtnRemover".pressed.connect(_on_btn_remover_pressed)

## Configura o card com os dados da disciplina. [br]
## [param p_ch] deve ser uma Array de strings com as cargas horárias por professor. [br]
## [param p_complementar] indica se a disciplina é complementar (grade semestre = 0). [br]
## [param p_prefixo_curso] é o prefixo do curso para badges (ex.: "EC").
func configurar(p_codigo: String, p_nome: String, p_professores: Array[String], \
		p_ch: Array, p_semestre: String, p_chave: String, \
		p_complementar: bool = false, p_prefixo_curso: String = "", \
		p_oferta: String = "") -> void:
	codigo = p_codigo
	nome = p_nome
	professores = p_professores.duplicate()
	semestre = p_semestre
	chave_planejamento = p_chave
	complementar = p_complementar
	prefixo_curso = p_prefixo_curso
	oferta = p_oferta
	extra = false
	ch_total = 0
	for c in p_ch:
		ch_total += int(c)
	ch_alocada = 0
	_atualizar_visual()
	_vincular_dica_oferta()

func _get_drag_data(_at_position: Vector2) -> Variant:
	if ch_total == 0 or (ch_alocada >= ch_total and not permite_extra):
		return null
	card_interagido.emit(self)
	var preview := Label.new()
	preview.text = codigo.to_upper()
	preview.add_theme_color_override("font_color", Color.WHITE)
	set_drag_preview(preview)
	return {
		"codigo": codigo,
		"semestre": semestre,
		"chave": chave_planejamento,
		"professores": professores,
		"ch_restante": ch_total - ch_alocada,
		"shift_pressed": Input.is_key_pressed(KEY_SHIFT),
	}

func _notification(what: int) -> void:
	# Recolore a barra e os badges quando o tema muda (as cores vêm da PaletaSemantica).
	if what == NOTIFICATION_THEME_CHANGED and is_node_ready():
		_atualizar_visual()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		card_interagido.emit(self)

func _atualizar_visual() -> void:
	var cor_barra: Color
	var status_texto: String
	if permite_extra:
		cor_barra = PaletaSemantica.cor("ch_extra")
		status_texto = "Extra disponível"
	elif ch_total > 0 and ch_alocada > ch_total:
		cor_barra = PaletaSemantica.cor("ch_extra")
		status_texto = "Completo +" + str(ch_extra) + " " + unidade_ch + " extra"
	elif ch_total > 0 and ch_alocada >= ch_total:
		cor_barra = PaletaSemantica.cor("ch_completo")
		status_texto = "Completo"
	elif ch_alocada > 0:
		cor_barra = PaletaSemantica.cor("ch_parcial")
		status_texto = "Parcial " + str(ch_alocada) + "/" + str(ch_total) + " " + unidade_ch
	else:
		cor_barra = PaletaSemantica.cor("ch_pendente")
		status_texto = str(ch_total) + " " + unidade_ch + " pendente" if ch_total > 0 else "Sem CH definida"

	$"%BarraStatus".color = cor_barra
	$"%CodigoNome".text = codigo.to_upper() + "  " + nome

	# Atualiza badge de indicadores (CG / Extra / semestre) no canto superior direito
	if complementar:
		$"%Indicador".text = _texto_badge_oferta()
		$"%Indicador".add_theme_color_override("font_color", PaletaSemantica.cor("ch_complementar"))
	elif extra:
		$"%Indicador".text = _texto_badge_oferta()
		$"%Indicador".add_theme_color_override("font_color", PaletaSemantica.cor("ch_extra"))
	else:
		# Mostra o semestre numerico (ex.: "EC01") se existir
		var tem_numero: bool = false
		for c in semestre:
			if c.is_valid_int():
				tem_numero = true
				break
		if tem_numero:
			$"%Indicador".text = "%s" % _texto_badge_oferta()
			$"%Indicador".remove_theme_color_override("font_color")
		else:
			$"%Indicador".text = ""

	var profs_str: String = ""
	for i in professores.size():
		if i > 0:
			profs_str += ", "
		profs_str += professores[i].capitalize()
	$"%Professores".text = profs_str
	$"%CH".text = status_texto
	$"%BtnHoraExtra".visible = habilita_hora_extra and ch_total > 0 and ch_alocada >= ch_total and not permite_extra
	$"%BtnRemover".visible = habilita_remover

func _on_btn_hora_extra_pressed() -> void:
	permite_extra = true
	_atualizar_visual()
	$"%BtnHoraExtra".visible = habilita_hora_extra and ch_total > 0 and ch_alocada >= ch_total and not permite_extra

func _on_btn_remover_pressed() -> void:
	remover_solicitado.emit(self)


func _texto_badge_oferta() -> String:
	if oferta.is_empty() or oferta.to_lower() == semestre.to_lower():
		return "[%s]" % semestre.to_upper()
	var partes: PackedStringArray = _split_oferta()
	if partes.size() <= 1:
		return "[%s]" % semestre.to_upper()
	if partes.size() == 2:
		return "[%s]" % ";".join(partes).to_upper()
	return "[%s +%d]" % [semestre.to_upper(), partes.size() - 1]


func _split_oferta() -> PackedStringArray:
	var s: String = oferta.strip_edges()
	for delim in [";", "/", "-"]:
		if s.contains(delim):
			return s.split(delim)
	return PackedStringArray([s])


func _vincular_dica_oferta() -> void:
	if oferta.is_empty() or oferta.to_lower() == semestre.to_lower():
		return
	var partes: PackedStringArray = _split_oferta()
	if partes.size() <= 1:
		return
	var linhas: Array[String] = []
	linhas.append("[b]Ofertada para:[/b]")
	for p in partes:
		linhas.append("  %s" % p.strip_edges().to_upper())
	DicaFlutuante.vincular(self, "\n".join(linhas))
