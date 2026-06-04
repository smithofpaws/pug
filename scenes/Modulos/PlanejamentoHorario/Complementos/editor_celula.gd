class_name EditorCelula extends RefCounted
## Diálogo de edição de célula da grade de horários. [br]
## Permite editar sala, tipo, turma e vagas de uma alocação existente. [br]
## Emite [signal edicao_confirmada] quando o usuário salva as alterações.

signal edicao_confirmada(linha: int, coluna: int, dados: Dictionary)

# Diálogo editor de célula (criado sob demanda).
var _dialogo: PopupPanel
var _campo_sala: LineEdit
var _campo_tipo: OptionButton
var _campo_turma: LineEdit
var _campo_vagas: LineEdit
var _linha: int = -1
var _coluna: int = -1
var _raiz: Node

func _init(raiz: Node) -> void:
	_raiz = raiz

## Abre o diálogo de edição para a célula na posição [param linha], [param coluna], com os dados de [param aloc].
func abrir(linha: int, coluna: int, aloc: Dictionary) -> void:
	if not _dialogo:
		_criar_dialogo()
	_linha = linha
	_coluna = coluna
	_dialogo.title = "Editar: " + aloc.get("codigo", "").to_upper()
	_campo_sala.text = aloc.get("sala", "")
	_campo_tipo.select(1 if aloc.get("tipo", "") == "Pratica" else 0)
	_campo_turma.text = aloc.get("turma", "")
	_campo_vagas.text = aloc.get("vagas", "Vagas")
	_dialogo.popup_centered_ratio(0.35)

## Fecha o diálogo sem salvar.
func fechar() -> void:
	if _dialogo:
		_dialogo.hide()
	_linha = -1
	_coluna = -1

# Cria os controles do diálogo na primeira vez que é aberto.
func _criar_dialogo() -> void:
	_dialogo = PopupPanel.new()
	_dialogo.exclusive = true
	_raiz.add_child(_dialogo)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	var margem := MarginContainer.new()
	margem.add_theme_constant_override("margin_left", 12)
	margem.add_theme_constant_override("margin_top", 12)
	margem.add_theme_constant_override("margin_right", 12)
	margem.add_theme_constant_override("margin_bottom", 12)
	margem.add_child(vbox)
	_dialogo.add_child(margem)

	_campo_sala = _adicionar_campo(vbox, "Sala:")
	_campo_tipo = OptionButton.new()
	_campo_tipo.add_item("Teorica")
	_campo_tipo.add_item("Pratica")
	_criar_linha(vbox, "Tipo:", _campo_tipo)
	_campo_turma = _adicionar_campo(vbox, "Turma:")
	_campo_vagas = _adicionar_campo(vbox, "Vagas:")

	var separador := HSeparator.new()
	vbox.add_child(separador)

	var botoes := HBoxContainer.new()
	botoes.alignment = BoxContainer.ALIGNMENT_END
	var btn_cancelar := Button.new()
	btn_cancelar.text = "Cancelar"
	btn_cancelar.pressed.connect(_on_cancelar)
	botoes.add_child(btn_cancelar)
	var btn_salvar := Button.new()
	btn_salvar.text = "Salvar"
	btn_salvar.pressed.connect(_on_confirmar)
	botoes.add_child(btn_salvar)
	vbox.add_child(botoes)

# Adiciona um campo [LineEdit] com rótulo ao diálogo.
func _adicionar_campo(pai: VBoxContainer, rotulo: String) -> LineEdit:
	var campo := LineEdit.new()
	_criar_linha(pai, rotulo, campo)
	return campo

# Adiciona uma linha com rótulo e campo ao diálogo.
func _criar_linha(pai: VBoxContainer, rotulo: String, campo: Control) -> void:
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 6)
	var lbl := Label.new()
	lbl.text = rotulo
	lbl.custom_minimum_size = Vector2(50, 0)
	linha.add_child(lbl)
	campo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(campo)
	pai.add_child(linha)

#region Sinais
func _on_confirmar() -> void:
	if _linha < 0 or _coluna < 0:
		return
	var dados: Dictionary = {
		"sala": _campo_sala.text,
		"tipo": _campo_tipo.get_item_text(_campo_tipo.selected),
		"turma": _campo_turma.text,
		"vagas": _campo_vagas.text,
	}
	edicao_confirmada.emit(_linha, _coluna, dados)
	fechar()

func _on_cancelar() -> void:
	fechar()
#endregion