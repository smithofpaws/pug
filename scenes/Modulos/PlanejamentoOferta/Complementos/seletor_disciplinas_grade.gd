class_name SeletorDisciplinasGrade extends RefCounted
## Diálogo de seleção de disciplinas de uma grade curricular. [br]
## Lista as disciplinas da grade, permite buscar por código ou nome (ignora caixa e acentos),
## filtrar por semestre (período do currículo) e selecionar quais inserir. Emite
## [signal disciplinas_selecionadas] ao confirmar. [br]
## Disciplinas já presentes (informadas em [method abrir]) aparecem marcadas e desabilitadas. [br]
## Segue o padrão dos demais auxiliares em [code]Complementos/[/code] (ex.: [EditorCelula]): um
## [RefCounted] que constrói e gerencia seu próprio diálogo, comunicando o resultado por sinal.

signal disciplinas_selecionadas(grade_nome: String, codigos: Array)

# Nó onde o diálogo é adicionado (geralmente o módulo).
var _raiz: Node

# Estado dos filtros do diálogo aberto. Resetado a cada chamada de [method abrir].
var _texto_busca: String = ""
var _opt_sem_idx: int = 0

func _init(raiz: Node) -> void:
	_raiz = raiz

## Abre o diálogo para a [param grade] (dicionário código → dados) de nome [param grade_nome]. [br]
## [param codigos_existentes] são os códigos já presentes na lista (não podem ser reinseridos).
func abrir(grade_nome: String, grade: Dictionary, codigos_existentes: Array) -> void:
	if grade.is_empty():
		return
	var existentes: Dictionary = {}
	for c in codigos_existentes:
		existentes[str(c).to_lower()] = true

	# Reseta o estado para esta abertura (cada abrir cria um novo dialogo).
	_texto_busca = ""
	_opt_sem_idx = 0

	var dialog := AcceptDialog.new()
	dialog.title = "Inserir disciplinas — grade " + grade_nome
	dialog.min_size = Vector2i(440, 580)
	dialog.get_ok_button().text = "Inserir selecionadas"

	var vbox := VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialog.add_child(vbox)

	# Caixa de busca por codigo ou nome (case e acento-insensitive). Sempre acima do
	# filtro de semestre porque a expectativa de uso e procurar uma disciplina especifica.
	var linha_busca := HBoxContainer.new()
	var label_busca := Label.new()
	label_busca.text = "Buscar:"
	linha_busca.add_child(label_busca)
	var campo_busca := LineEdit.new()
	campo_busca.placeholder_text = "código ou nome"
	campo_busca.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	campo_busca.clear_button_enabled = true
	linha_busca.add_child(campo_busca)
	vbox.add_child(linha_busca)

	# Linha de filtro por semestre (período do currículo).
	var linha_filtro := HBoxContainer.new()
	var label := Label.new()
	label.text = "Semestre:"
	linha_filtro.add_child(label)
	var opt_sem := OptionButton.new()
	# Opções de grupo (selecionam varios semestres), seguidas de um separador e dos
	# semestres isolados.
	opt_sem.add_item("Todos")
	opt_sem.add_item("Pares")
	opt_sem.add_item("Ímpares")
	opt_sem.add_separator()
	var semestres: Array[int] = []
	for cod in grade:
		var s: int = int(str(grade[cod].get("semestre", "0")))
		if s > 0 and not s in semestres:
			semestres.append(s)
	semestres.sort()
	for s in semestres:
		opt_sem.add_item(str(s))
	linha_filtro.add_child(opt_sem)
	# Botão para marcar todas as disciplinas visíveis no filtro atual.
	var btn_todas := Button.new()
	btn_todas.text = "Selecionar todas visíveis"
	linha_filtro.add_child(btn_todas)
	vbox.add_child(linha_filtro)

	# Lista rolável de checkboxes, uma por disciplina (ordenada por semestre e código).
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(420, 440)
	vbox.add_child(scroll)
	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lista)

	# Ordena por semestre (período do currículo) crescente; disciplinas sem semestre (ou inválido)
	# vão para o final. Empate de semestre é desempatado pelo código.
	var codigos: Array = grade.keys()
	codigos.sort_custom(func(a, b):
		var sa: int = int(str(grade[a].get("semestre", "0")))
		var sb: int = int(str(grade[b].get("semestre", "0")))
		if sa <= 0:
			sa = 9999
		if sb <= 0:
			sb = 9999
		return sa < sb if sa != sb else a < b)
	var checkboxes: Array = []
	for cod in codigos:
		var disc: Dictionary = grade[cod]
		var sem: String = str(disc.get("semestre", ""))
		var nome: String = str(disc.get("nome", cod))
		var ch: String = str(disc.get("ch", "?"))
		var cb := CheckBox.new()
		cb.text = "%s - %s  (%sº sem · %sh)" % [str(cod).to_upper(), nome, sem, ch]
		cb.set_meta("codigo", cod)
		cb.set_meta("nome", nome)
		cb.set_meta("semestre", sem)
		# Pre-computa o "alvo" normalizado para busca (codigo + nome) para evitar
		# renormalizar a cada tecla digitada — a lista pode ter ~50 disciplinas.
		cb.set_meta("alvo_busca", GeneralFunctions.remover_acentos(str(cod) + " " + nome))
		# Já presente na lista (qualquer origem): marca e desabilita (não reinsere/duplica).
		if existentes.has(str(cod).to_lower()):
			cb.button_pressed = true
			cb.disabled = true
		lista.add_child(cb)
		checkboxes.append(cb)

	campo_busca.text_changed.connect(_on_busca_alterada.bind(opt_sem, checkboxes))
	opt_sem.item_selected.connect(_on_filtro_semestre.bind(opt_sem, checkboxes))
	btn_todas.pressed.connect(_on_selecionar_visiveis.bind(checkboxes))
	dialog.confirmed.connect(_on_confirmar.bind(grade_nome, checkboxes))
	dialog.confirmed.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	_raiz.add_child(dialog)
	dialog.popup_centered()
	Dialogos.limitar_a_tela(dialog)
	# Foco inicial no campo de busca: padrao de UI para listas com filtro.
	campo_busca.grab_focus()


# Atualiza o estado da busca e reaplica os dois filtros (busca + semestre).
func _on_busca_alterada(novo_texto: String, opt: OptionButton, checkboxes: Array) -> void:
	_texto_busca = novo_texto
	_aplicar_filtros(opt, checkboxes)


# Atualiza o estado do filtro de semestre e reaplica os dois filtros.
func _on_filtro_semestre(index: int, opt: OptionButton, checkboxes: Array) -> void:
	_opt_sem_idx = index
	_aplicar_filtros(opt, checkboxes)


# Recalcula a visibilidade de cada CheckBox combinando os dois filtros:
# semestre ("Todos"/"Pares"/"Ímpares"/N) AND substring da busca (no codigo+nome
# normalizado, sem acentos e em minusculas).
func _aplicar_filtros(opt: OptionButton, checkboxes: Array) -> void:
	var texto_sem: String = opt.get_item_text(_opt_sem_idx)
	var busca: String = GeneralFunctions.remover_acentos(_texto_busca).strip_edges()
	for cb in checkboxes:
		var sem_str: String = str(cb.get_meta("semestre"))
		var visivel: bool
		match texto_sem:
			"Todos":
				visivel = true
			"Pares":
				visivel = sem_str.is_valid_int() and (int(sem_str) % 2 == 0)
			"Ímpares":
				visivel = sem_str.is_valid_int() and (int(sem_str) % 2 == 1)
			_:
				visivel = sem_str == texto_sem
		if visivel and not busca.is_empty():
			var alvo: String = str(cb.get_meta("alvo_busca"))
			visivel = busca in alvo
		cb.visible = visivel


# Marca todas as disciplinas atualmente visíveis (e habilitadas) no filtro.
func _on_selecionar_visiveis(checkboxes: Array) -> void:
	for cb in checkboxes:
		if cb.visible and not cb.disabled:
			cb.button_pressed = true

# Coleta os códigos marcados (e habilitados) e emite o sinal de seleção.
func _on_confirmar(grade_nome: String, checkboxes: Array) -> void:
	var codigos: Array = []
	for cb in checkboxes:
		if cb.button_pressed and not cb.disabled:
			codigos.append(str(cb.get_meta("codigo")))
	disciplinas_selecionadas.emit(grade_nome, codigos)



