class_name SeletorCursos extends RefCounted
## Diálogo modal de seleção de cursos para importação do planejamento. [br]
## Lista um [CheckBox] por [code]cod_curso[/code] presente em [code]base_config.json:cursos[/code],
## permitindo selecionar um ou vários ao mesmo tempo. Emite [signal cursos_selecionados] ao
## confirmar com a lista de [code]cod_curso[/code] marcados (ordem do dicionário). [br]
## Segue o padrão dos demais auxiliares construídos em runtime (ex.: [SeletorDisciplinasGrade]):
## um [RefCounted] que constrói e gerencia seu próprio diálogo, comunicando o resultado por sinal.

signal cursos_selecionados(cods: Array[String])

# Nó onde o diálogo é adicionado (geralmente o módulo).
var _raiz: Node

func _init(raiz: Node) -> void:
	_raiz = raiz

## Abre o diálogo listando os cursos de [param cursos] (dicionário [code]cod_curso → metadados[/code],
## tipicamente [code]base_config.json:cursos[/code]). [param pre_marcados] são os [code]cod_curso[/code]
## que devem aparecer já marcados (por exemplo, a última seleção do usuário).
func abrir(cursos: Dictionary, pre_marcados: Array = []) -> void:
	if cursos.is_empty():
		push_warning("SeletorCursos.abrir chamado com dicionario de cursos vazio.")
		return
	var pre: Dictionary = {}
	for c in pre_marcados:
		pre[str(c).to_lower()] = true

	var dialog := AcceptDialog.new()
	dialog.title = "Selecionar cursos"
	# Tamanho minimo fixo + conteudo com SIZE_EXPAND_FILL: o ScrollContainer cresce com o
	# dialogo ao redimensionar (mesmo padrao de SeletorDisciplinasGrade), em vez de manter
	# uma area de listagem fixa que sempre exige rolagem.
	dialog.min_size = Vector2i(380, 320)
	# Nao-exclusivo: o usuario consegue fechar a janela principal (X do topo) sem
	# precisar fechar o dialogo antes.
	dialog.exclusive = false
	dialog.get_ok_button().text = "Importar selecionados"

	var vbox := VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialog.add_child(vbox)

	var info := Label.new()
	info.text = "Selecione os cursos a importar do planejamento.csv:"
	vbox.add_child(info)

	# Atalho para marcar todos os cursos de uma vez. Conectado apos a criacao dos
	# checkboxes (ver abaixo), quando a lista [code]checkboxes[/code] ja esta populada.
	var btn_todos := Button.new()
	btn_todos.text = "Selecionar todos"
	btn_todos.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	vbox.add_child(btn_todos)

	# Lista rolável de checkboxes, ordenada por cod_curso para previsibilidade.
	# [code]custom_minimum_size[/code] define o piso de altura; acima disso o
	# [code]SIZE_EXPAND_FILL[/code] faz a lista acompanhar o redimensionamento do dialogo.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(360, 200)
	vbox.add_child(scroll)
	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lista)

	var cods: Array = cursos.keys()
	cods.sort()
	var checkboxes: Array = []
	for cod in cods:
		var meta: Dictionary = cursos[cod]
		var nome: String = str(meta.get("nome", cod))
		var cb := CheckBox.new()
		cb.text = "%s — %s" % [str(cod).to_upper(), nome]
		cb.set_meta("cod_curso", str(cod))
		if pre.has(str(cod).to_lower()):
			cb.button_pressed = true
		lista.add_child(cb)
		checkboxes.append(cb)

	btn_todos.pressed.connect(func():
		for cb in checkboxes:
			cb.button_pressed = true)

	dialog.confirmed.connect(_on_confirmar.bind(checkboxes))
	dialog.confirmed.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	_raiz.add_child(dialog)
	dialog.popup_centered()
	Dialogos.limitar_a_tela(dialog)

# Coleta os cod_curso marcados e emite o sinal.
func _on_confirmar(checkboxes: Array) -> void:
	var selecionados: Array[String] = []
	for cb in checkboxes:
		if cb.button_pressed:
			selecionados.append(str(cb.get_meta("cod_curso")))
	cursos_selecionados.emit(selecionados)
