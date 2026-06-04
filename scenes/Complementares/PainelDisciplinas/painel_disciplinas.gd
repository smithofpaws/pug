class_name PainelDisciplinas extends VBoxContainer
## Painel reutilizável de disciplinas com filtros cascata e cards arrastáveis.
## [br]
## Emite [signal card_interagido] quando um card é clicado ou arrastado, e
## [signal filtro_alterado] quando qualquer filtro muda (curso, semestre, professor).
## [br]
## A lógica de cascade (mudar curso reseta semestre/professor, etc.) é gerida internamente.
## A lógica específica de grade (colorir células) e status bar permanece no módulo consumidor.

signal card_interagido(card: CardDisciplina)
signal filtro_alterado(filtros: Dictionary)
signal filtro_limpo()
signal semestre_edicao_alterado(semestre: String)
signal card_removido(chave: String)

# Pré-carrega a cena do CardDisciplina para instanciação rápida
const _card_disciplina_scene := preload("res://scenes/Complementares/CardDisciplina/CardDisciplina.tscn")

var _analise_grades := AnaliseGrades.new()
var _grades_disciplinas_curriculos: Dictionary = {}
var _cores_terminal: Dictionary = {}
var _planejamento_csv: Dictionary = {}

# Metadados de cursos, formato [code]base_config.json:cursos[/code]. Quando vazio, o painel
# faz fallback para comparação por prefixo cru (mantém compatibilidade com chamadores antigos).
var _cursos: Dictionary = {}

# Quando falso, os cards criados ocultam o botão de hora extra (ex.: Planejamento de Oferta).
var _habilita_hora_extra: bool = true

# Quando verdadeiro, os cards criados exibem o botão remover.
var _habilita_remover: bool = false

# Unidade de carga horária propagada aos cards instanciados (default [code]"h"[/code];
# [code]"cr"[/code] no Planejamento de Oferta, onde a CH é em créditos).
var _unidade_ch: String = "h"

## Cards de disciplina instanciados no painel, indexados pela chave composta.
var cards_disciplinas: Dictionary = {}

## Filtros do painel de disciplinas (vazio = "Todos").
var filtro_curso: String = ""

## Filtro de semestre ativo.
var filtro_semestre: Array[String] = []

## Filtro de professor ativo.
var filtro_professor: String = ""

## Contexto de edição de semestre ("" = Todos, "1" = 1° semestre, "2" = 2° semestre).
var _semestre_edicao: String = ""

## Retorna [code]true[/code] se algum filtro (curso, semestre ou professor) estiver ativo.
func filtro_ativo() -> bool:
	return not filtro_curso.is_empty() or filtro_semestre.size() > 0 or not filtro_professor.is_empty()


## Programa o filtro de curso. [param cod_curso] e o codigo interno de curso (ex.: [code]"alec"[/code])
## ou [code]""[/code] para "Todos". Dispara os mesmos efeitos colaterais da selecao manual.
func selecionar_filtro_curso(cod_curso: String) -> void:
	_on_filtro_curso_opcao_selecionada("", [cod_curso])


func _ready() -> void:
	$"%FiltroCurso".opcao_selecionada.connect(_on_filtro_curso_opcao_selecionada)
	$"%FiltroSemestre".opcao_selecionada.connect(_on_filtro_semestre_opcao_selecionada)
	$"%FiltroProfessor".opcao_selecionada.connect(_on_filtro_professor_opcao_selecionada)
	$"%FiltroCurso".get_node("MenuButton").gui_input.connect(_on_filtro_gui_input.bind("curso"))
	$"%FiltroSemestre".get_node("MenuButton").gui_input.connect(_on_filtro_gui_input.bind("semestre"))
	$"%FiltroProfessor".get_node("MenuButton").gui_input.connect(_on_filtro_gui_input.bind("professor"))


## Define o semestre de edição externamente (chamado pelo módulo pai quando o
## [FiltroSemestreEdicao] — agora no topo do módulo — é alterado).
func definir_semestre_edicao(semestre: String) -> void:
	_semestre_edicao = semestre
	_atualizar_indicadores()
	semestre_edicao_alterado.emit(_semestre_edicao)


func _on_filtro_curso_opcao_selecionada(_retorno: String, lista_selecionada: Array[String]) -> void:
	filtro_curso = lista_selecionada[0] if lista_selecionada.size() > 0 else ""
	$"%FiltroCurso".texto_padrao = _nome_curso(filtro_curso) if not filtro_curso.is_empty() else "Curso"
	filtro_semestre = []
	$"%FiltroSemestre".limpar_selecao()
	$"%FiltroSemestre".texto_padrao = "Semestre"
	filtro_professor = ""
	$"%FiltroProfessor".texto_padrao = "Professor"
	$"%FiltroSemestre".lista_itens = popular_filtro_semestre()
	$"%FiltroProfessor".lista_itens = popular_filtro_professor()
	aplicar_filtro()
	filtro_alterado.emit({"curso": filtro_curso, "semestre": filtro_semestre, "professor": filtro_professor})


func _on_filtro_semestre_opcao_selecionada(_retorno: String, lista_selecionada: Array[String]) -> void:
	var popup: PopupMenu = $"%FiltroSemestre".get_node("MenuButton").get_popup()
	var idx_todos: int = -1
	for i in popup.item_count:
		if popup.is_item_checkable(i) and popup.get_item_text(i) == "Todos":
			idx_todos = i
			break

	if Input.is_key_pressed(KEY_SHIFT) and not filtro_curso.is_empty() and not _retorno.is_empty() and _retorno != "Todos":
		var chave_busca: String = _extrair_chave_semestre(_retorno, filtro_curso)
		var idx_clicado: int = -1
		for j in popup.item_count:
			if popup.is_item_checkable(j) and popup.get_item_text(j) == _retorno:
				idx_clicado = j
				break
		var selecionar: bool = idx_clicado >= 0 and popup.is_item_checked(idx_clicado)
		for i in popup.item_count:
			if popup.is_item_checkable(i) and popup.get_item_text(i).to_upper().contains(chave_busca.to_upper()):
				popup.set_item_checked(i, selecionar)
		if idx_todos >= 0 and popup.is_item_checked(idx_todos):
			popup.set_item_checked(idx_todos, false)
		lista_selecionada.clear()
		for i in popup.item_count:
			if popup.is_item_checkable(i) and popup.is_item_checked(i):
				lista_selecionada.append(popup.get_item_text(i))

	if _retorno == "Todos":
		if idx_todos >= 0 and popup.is_item_checked(idx_todos):
			for i in popup.item_count:
				if popup.is_item_checkable(i) and i != idx_todos:
					popup.set_item_checked(i, false)
			lista_selecionada.clear()
			lista_selecionada.append("Todos")
	else:
		if idx_todos >= 0 and popup.is_item_checked(idx_todos):
			popup.set_item_checked(idx_todos, false)
		var lista_idx_todos: int = lista_selecionada.find("Todos")
		if lista_idx_todos >= 0:
			lista_selecionada.remove_at(lista_idx_todos)

	var nova: Array[String] = []
	for s in lista_selecionada:
		if s != "" and s != "Todos":
			nova.append(s)
	filtro_semestre = nova
	if nova.size() == 1:
		$"%FiltroSemestre".texto_padrao = nova[0]
	else:
		$"%FiltroSemestre".texto_padrao = "Semestre"
	filtro_professor = ""
	$"%FiltroProfessor".texto_padrao = "Professor"
	$"%FiltroProfessor".lista_itens = popular_filtro_professor()
	aplicar_filtro()
	filtro_alterado.emit({"curso": filtro_curso, "semestre": filtro_semestre, "professor": filtro_professor})


func _extrair_chave_semestre(semestre: String, cod_curso: String) -> String:
	if _cursos.is_empty() or not _cursos.has(cod_curso):
		return semestre
	var prefixos: Array = _cursos[cod_curso].get("prefixos_semestre", [])
	if prefixos.is_empty():
		return semestre
	var sem_upper: String = semestre.to_upper()
	for parte in sem_upper.split(";"):
		var p: String = parte.strip_edges()
		for prefixo in prefixos:
			if p.begins_with(str(prefixo).to_upper()):
				return p
	return semestre


func _on_filtro_professor_opcao_selecionada(_retorno: String, lista_selecionada: Array[String]) -> void:
	filtro_professor = lista_selecionada[0] if lista_selecionada.size() > 0 else ""
	$"%FiltroProfessor".texto_padrao = filtro_professor if not filtro_professor.is_empty() else "Professor"
	aplicar_filtro()
	filtro_alterado.emit({"curso": filtro_curso, "semestre": filtro_semestre, "professor": filtro_professor})


func _on_filtro_gui_input(event: InputEvent, tipo_filtro: String) -> void:
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_MIDDLE or not event.pressed:
		return
	match tipo_filtro:
		"curso":
			filtro_curso = ""
			$"%FiltroCurso".texto_padrao = "Curso"
			$"%FiltroCurso".limpar_selecao()
			$"%FiltroSemestre".lista_itens = popular_filtro_semestre()
			$"%FiltroProfessor".lista_itens = popular_filtro_professor()
		"semestre":
			filtro_semestre = []
			$"%FiltroSemestre".texto_padrao = "Semestre"
			$"%FiltroSemestre".limpar_selecao()
			$"%FiltroSemestre".limpar_selecao()
			$"%FiltroProfessor".lista_itens = popular_filtro_professor()
		"professor":
			filtro_professor = ""
			$"%FiltroProfessor".texto_padrao = "Professor"
			$"%FiltroProfessor".limpar_selecao()
	aplicar_filtro()
	filtro_alterado.emit({"curso": filtro_curso, "semestre": filtro_semestre, "professor": filtro_professor})


# Obtém informações de complementaridade e prefixo do curso para uma disciplina. [br]
# Usa a última grade do curso (mais recente) para determinar se é complementar.
func _obter_info_disciplina(codigo: String, semestre: String) -> Dictionary:
	var complementar: bool = false
	var prefixo: String = semestre.substr(0, 2).to_upper()
	var grade_nome: String = ""

	var cod_curso: String = _identificar_cod_curso_por_semestre(semestre)
	if not cod_curso.is_empty() and _cursos.has(cod_curso):
		var prefixos: Array = _cursos[cod_curso].get("prefixos_semestre", [])
		if not prefixos.is_empty():
			prefixo = str(prefixos[0]).to_upper()
		var grades_list: Array = _cursos[cod_curso].get("grades", [])
		if not grades_list.is_empty():
			grade_nome = str(grades_list[-1])

	if not grade_nome.is_empty():
		var sem: String = _analise_grades.info_grade(_grades_disciplinas_curriculos, codigo, "semestre", grade_nome)
		complementar = (sem == "0")

	return {"complementar": complementar, "prefixo": prefixo}


## Reavalia os indicadores (CG / Extra / semestre) de todos os cards com base
## no contexto de edição atual ([member _semestre_edicao]).
func _atualizar_indicadores() -> void:
	for chave in cards_disciplinas:
		var card: CardDisciplina = cards_disciplinas[chave]
		if card.complementar:
			card.extra = false
		elif card.semestre.to_lower().ends_with("extra"):
			# Disciplinas rotuladas "<prefixo>Extra" no planejamento são sempre extra.
			card.extra = true
		elif _semestre_edicao.is_empty():
			card.extra = false
		else:
			var num_sem: int = 0
			for c in card.semestre:
				if c.is_valid_int():
					num_sem = num_sem * 10 + int(c)
			var edicao_int: int = int(_semestre_edicao) if _semestre_edicao.is_valid_int() else 0
			# Paridade: 1° academico = curriculares impares; 2° academico = pares.
			card.extra = num_sem > 0 and edicao_int > 0 and (num_sem % 2) != (edicao_int % 2)
		card._atualizar_visual()


## Configura as referências injetadas e dados necessários para popular cards e filtros. [br]
## [param habilita_hora_extra] controla se os cards exibem o botão de hora extra; passe
## [code]false[/code] em módulos sem grade de horários (ex.: Planejamento de Oferta). [br]
## [param cursos] é o dicionário [code]base_config.json:cursos[/code]; usado para mapear
## prefixos de semestre em [code]cod_curso[/code] e para nome bonito na UI. [br]
## [param permite_remover] controla se os cards exibem o botão remover. [br]
## [param unidade_ch] é o rótulo da unidade de CH usado nos cards (default [code]"h"[/code];
## o Planejamento de Oferta passa [code]"cr"[/code] porque opera em créditos).
func configurar(analise_grades: AnaliseGrades, grades_disciplinas_curriculos: Dictionary, cores_terminal: Dictionary, habilita_hora_extra: bool = true, cursos: Dictionary = {}, permite_remover: bool = false, unidade_ch: String = "h") -> void:
	_analise_grades = analise_grades
	_grades_disciplinas_curriculos = grades_disciplinas_curriculos
	_cores_terminal = cores_terminal
	_habilita_hora_extra = habilita_hora_extra
	_habilita_remover = permite_remover
	_cursos = cursos
	_unidade_ch = unidade_ch


## Retorna [code]true[/code] se [param sem] pertence ao curso [param cod_curso], comparando
## com os [code]prefixos_semestre[/code] da metadata [code]cursos[/code] injetada via [method configurar]. [br]
## Quando [param cod_curso] não está em [code]cursos[/code], faz fallback de prefixo cru
## (mantém compatibilidade com chamadores que ainda passam o prefixo do semestre).
func semestre_pertence_ao_curso(sem: String, cod_curso: String) -> bool:
	if sem.is_empty() or cod_curso.is_empty():
		return false
	var sem_upper: String = sem.to_upper().strip_edges()
	if _cursos.has(cod_curso):
		var prefixos: Array = _cursos[cod_curso].get("prefixos_semestre", [])
		for prefixo in prefixos:
			if sem_upper.begins_with(str(prefixo).to_upper()):
				return true
		return false
	# Fallback: trata [param cod_curso] como prefixo literal (comportamento antigo).
	return sem_upper.begins_with(cod_curso.to_upper())


## Popula o painel com cards a partir do planejamento.csv importado e retorna os dados dos filtros. [br]
## Quando [param limpar_antes] é [code]true[/code] (padrão), descarta toda a lista antes de popular. [br]
## Quando [code]false[/code], faz merge: remove apenas os cards cujo código está no novo planejamento
## (serão recriados atualizados) e preserva os demais (ex.: adicionados via grade), evitando duplicação.
func popular(planejamento_csv: Dictionary, terminal: Node, limpar_antes: bool = true) -> Dictionary:
	if limpar_antes:
		limpar()
	else:
		var novos_codigos: Dictionary = {}
		for chave in planejamento_csv:
			novos_codigos[str(planejamento_csv[chave].get("codigo", "")).to_lower()] = true
		for chave in cards_disciplinas.keys():
			if novos_codigos.has(cards_disciplinas[chave].codigo.to_lower()):
				cards_disciplinas[chave].queue_free()
				cards_disciplinas.erase(chave)
	_planejamento_csv = planejamento_csv
	var chaves_ordenadas: Array[String] = []
	chaves_ordenadas.assign(_planejamento_csv.keys())
	chaves_ordenadas.sort()
	for chave in chaves_ordenadas:
		var dados: Dictionary = _planejamento_csv[chave]
		var codigo: String = dados.get("codigo", "")
		var semestre: String = dados.get("semestre", "")
		var profs: Array[String] = []
		profs.assign(dados.get("professor", []))
		var chs: Array = dados.get("ch", [])
		if chs.size() == 0:
			var ch_disc: String = dados.get("ch_disciplina", "0")
			if int(ch_disc) > 0:
				chs = [ch_disc]
		var nome: String = _analise_grades.info_grade(_grades_disciplinas_curriculos, codigo, "nome")
		if nome.begins_with("Codigo"):
			nome = codigo
		var card: CardDisciplina = _card_disciplina_scene.instantiate()
		card.habilita_hora_extra = _habilita_hora_extra
		card.habilita_remover = _habilita_remover
		card.unidade_ch = _unidade_ch
		var info: Dictionary = _obter_info_disciplina(codigo, semestre)
		card.configurar(codigo, nome, profs, chs, semestre, chave, info["complementar"], info["prefixo"], dados.get("oferta", ""))
		card.card_interagido.connect(_on_card_interagido)
		card.remover_solicitado.connect(_on_card_remover_solicitado.bind(chave))
		$"%ListaDisciplinas".add_child(card)
		cards_disciplinas[chave] = card
	_atualizar_indicadores()
	terminal.text_edit("Painel populado com " + str(chaves_ordenadas.size()) + " disciplinas.", \
		_cores_terminal.get("sucesso", "green"), true, false)
	var filtros := popular_filtros()
	$"%FiltroCurso".lista_itens = filtros["cursos"]
	$"%FiltroSemestre".lista_itens = filtros["semestres"]
	$"%FiltroProfessor".lista_itens = filtros["professores"]
	aplicar_filtro()
	return filtros


## Retorna [code]true[/code] se já existe um card com o [param codigo] informado (qualquer
## chave/semestre/origem). Usado para evitar duplicação ao inserir disciplinas de fontes distintas.
func tem_codigo(codigo: String) -> bool:
	for chave in cards_disciplinas:
		if cards_disciplinas[chave].codigo.to_lower() == codigo.to_lower():
			return true
	return false


## Retorna a lista (em minúsculas) dos códigos de todos os cards presentes no painel.
func codigos_presentes() -> Array[String]:
	var codigos: Array[String] = []
	for chave in cards_disciplinas:
		codigos.append(cards_disciplinas[chave].codigo.to_lower())
	return codigos


## Cria um card extra para disciplina não presente no planejamento.csv. [br]
## [param complementar] indica se a disciplina é complementar (grade semestre = 0). [br]
## [param prefixo] é o prefixo do curso para badges (ex.: "EC").
func popular_card_extra(codigo: String, nome: String, profs: Array[String], chs: Array, sem: String, chave: String, complementar: bool = false, prefixo: String = "") -> CardDisciplina:
	if cards_disciplinas.has(chave):
		cards_disciplinas[chave].queue_free()
		cards_disciplinas.erase(chave)
	var card: CardDisciplina = _card_disciplina_scene.instantiate()
	card.habilita_hora_extra = _habilita_hora_extra
	card.habilita_remover = _habilita_remover
	card.unidade_ch = _unidade_ch
	card.configurar(codigo, nome, profs, chs, sem, chave, complementar, prefixo, "")
	card.card_interagido.connect(_on_card_interagido)
	card.remover_solicitado.connect(_on_card_remover_solicitado.bind(chave))
	$"%ListaDisciplinas".add_child(card)
	cards_disciplinas[chave] = card
	_atualizar_indicadores()
	atualizar_filtros()
	return card


## Reconstroi as listas dos tres filtros (curso/semestre/professor) a partir do estado atual
## de [member cards_disciplinas]. Chamado internamente apos [method popular_card_extra] e
## exposto para o modulo chamar apos mutacoes externas (ex.: atribuicao de professor).
func atualizar_filtros() -> void:
	var filtros := popular_filtros()
	$"%FiltroCurso".lista_itens = filtros["cursos"]
	$"%FiltroSemestre".lista_itens = filtros["semestres"]
	$"%FiltroProfessor".lista_itens = filtros["professores"]


## Remove todos os cards do painel e reseta os filtros.
func limpar() -> void:
	for child in $"%ListaDisciplinas".get_children():
		child.queue_free()
	cards_disciplinas.clear()
	filtro_curso = ""
	filtro_semestre = []
	filtro_professor = ""


## Popula os três filtros com base nos cards atualmente instanciados e retorna o dicionário. [br]
## A iteracao usa [member cards_disciplinas] (e nao mais [code]_planejamento_csv[/code]) para que
## qualquer disciplina adicionada via [method popular_card_extra] (grade, txt, etc.) e qualquer
## atribuicao de professor feita em runtime aparecam nos filtros. [br]
## A lista de cursos exibe nomes bonitos (de [code]cursos[cod].nome[/code]) mas retorna
## o [code]cod_curso[/code] interno (lowercase).
func popular_filtros() -> Dictionary:
	var cursos_display: Array[String] = ["Todos"]
	var cursos_retorno: Array[String] = [""]
	var semestres: Array[String] = ["Todos"]
	var professores: Array[String] = ["Todos"]
	var professores_retorno: Array[String] = [""]
	for chave in cards_disciplinas:
		var card: CardDisciplina = cards_disciplinas[chave]
		var sem: String = card.semestre.to_upper()
		if not sem.is_empty():
			var cod_curso: String = _identificar_cod_curso_por_semestre(sem)
			if cod_curso.is_empty():
				cod_curso = sem.substr(0, 2).to_lower()
			if not cod_curso in cursos_retorno:
				cursos_display.append(_nome_curso(cod_curso))
				cursos_retorno.append(cod_curso)
			if not sem in semestres:
				semestres.append(sem)
		for prof in card.professores:
			var pn: String = str(prof)
			if not pn.is_empty():
				var pn_lower: String = pn.to_lower()
				var ja_existe: bool = false
				for p in professores_retorno:
					if p.to_lower() == pn_lower:
						ja_existe = true
						break
				if not ja_existe:
					professores.append(AnaliseAfinidade.normalizar_nome(pn))
					professores_retorno.append(pn)
	# Ordena cursos por nome de exibição mantendo o pareamento display ↔ cod_curso.
	var cursos_pares: Array = []
	for i in range(1, cursos_display.size()):
		cursos_pares.append([cursos_display[i], cursos_retorno[i]])
	cursos_pares.sort_custom(func(a, b): return a[0] < b[0])
	cursos_display = ["Todos"]
	cursos_retorno = [""]
	for par in cursos_pares:
		cursos_display.append(par[0])
		cursos_retorno.append(par[1])
	semestres.erase("Todos")
	semestres.sort()
	semestres.insert(0, "Todos")
	var prof_pares: Array = []
	for i in range(1, professores.size()):
		prof_pares.append([professores[i], professores_retorno[i]])
	prof_pares.sort_custom(func(a, b): return a[0] < b[0])
	professores = ["Todos"]
	professores_retorno = [""]
	for par in prof_pares:
		professores.append(par[0])
		professores_retorno.append(par[1])
	return {
		"cursos": {"_Curso*": cursos_display, "_Curso_retorno": cursos_retorno},
		"semestres": {"_Semestre_": semestres, "_Semestre_retorno": semestres},
		"professores": {"_Professor*": professores, "_Professor_retorno": professores_retorno},
	}


# Tenta identificar o [code]cod_curso[/code] de um semestre consultando os prefixos em [code]_cursos[/code].
# Retorna string vazia quando nenhum curso casa ou quando [code]_cursos[/code] não foi configurado.
func _identificar_cod_curso_por_semestre(sem: String) -> String:
	if sem.is_empty() or _cursos.is_empty():
		return ""
	var sem_upper: String = sem.to_upper().strip_edges()
	for cod_curso in _cursos.keys():
		var prefixos: Array = _cursos[cod_curso].get("prefixos_semestre", [])
		for prefixo in prefixos:
			if sem_upper.begins_with(str(prefixo).to_upper()):
				return cod_curso
	return ""


# Retorna o nome bonito de um curso (de [code]cursos[cod].nome[/code]) ou o próprio
# [param cod_curso] em caixa alta quando não há metadata disponível.
func _nome_curso(cod_curso: String) -> String:
	if _cursos.has(cod_curso):
		return str(_cursos[cod_curso].get("nome", cod_curso))
	return cod_curso.to_upper()


## Popula o filtro de semestre com base no filtro de curso ativo e retorna o dicionário.
## Inclui semestres das grades curriculares (disciplinas ainda sem card) e o sufixo
## [code]CG[/code] para disciplinas complementares (ex.: [code]"ECCG"[/code]).
func popular_filtro_semestre() -> Dictionary:
	var semestres: Array[String] = ["Todos"]
	var set_inseridos: Dictionary = {"todos": true}
	for chave in cards_disciplinas:
		var card: CardDisciplina = cards_disciplinas[chave]
		var sem_display: String = card.semestre.to_upper()
		if sem_display.is_empty():
			continue
		var dedup_key: String = sem_display.to_lower()
		if not set_inseridos.has(dedup_key):
			if filtro_curso.is_empty() or semestre_pertence_ao_curso(sem_display, filtro_curso):
				semestres.append(sem_display)
				set_inseridos[dedup_key] = true
		# Também exibe a oferta combinada (ex.: "EM02;ECExtra") como opção de filtro.
		var oferta_card: String = card.oferta
		if not oferta_card.is_empty() and oferta_card.to_lower() != dedup_key:
			var oferta_display: String = oferta_card.to_upper()
			var oferta_dedup: String = oferta_display.to_lower()
			if not set_inseridos.has(oferta_dedup):
				if filtro_curso.is_empty() or semestre_pertence_ao_curso(sem_display, filtro_curso):
					semestres.append(oferta_display)
					set_inseridos[oferta_dedup] = true
	# Semestres das grades curriculares (abrange disciplinas ainda nao importadas).
	if not filtro_curso.is_empty() and _cursos.has(filtro_curso):
		var grades_curso: Array = _cursos[filtro_curso].get("grades", [])
		for grade_nome in grades_curso:
			var grade: Dictionary = _grades_disciplinas_curriculos.get(grade_nome, {})
			for codigo in grade:
				var sem: String = str(grade[codigo].get("semestre", ""))
				if sem.is_empty():
					continue
				if sem == "0":
					var sem_cg: String = _semestre_prefixed(grade_nome, sem) + "CG"
					var cg_dedup: String = sem_cg.to_lower()
					if not set_inseridos.has(cg_dedup):
						semestres.append(sem_cg)
						set_inseridos[cg_dedup] = true
					continue
				var sem_prefixed: String = _semestre_prefixed(grade_nome, sem)
				var grade_dedup: String = sem_prefixed.to_lower()
				if set_inseridos.has(grade_dedup):
					continue
				semestres.append(sem_prefixed)
				set_inseridos[grade_dedup] = true
	semestres.erase("Todos")
	semestres.sort()
	semestres.insert(0, "Todos")
	return {"_Semestre_": semestres, "_Semestre_retorno": semestres}


# Converte o semestre numerico de uma grade (ex.: "1") para o formato prefixado
# usado nos filtros (ex.: "EC01"). Para semestre "0" retorna apenas o prefixo ("EC").
func _semestre_prefixed(grade_nome: String, sem: String) -> String:
	var cod_curso: String = ""
	for cod in _cursos:
		for g in _cursos[cod].get("grades", []):
			if str(g) == grade_nome:
				cod_curso = cod
				break
		if not cod_curso.is_empty():
			break
	if cod_curso.is_empty():
		return sem
	var prefixos: Array = _cursos[cod_curso].get("prefixos_semestre", [])
	if prefixos.is_empty():
		return sem
	var prefixo: String = str(prefixos[0]).to_upper()
	var sem_int: int = int(sem)
	if sem_int > 0:
		return "%s%02d" % [prefixo, sem_int]
	return prefixo


## Popula o filtro de professor com base nos filtros de curso e semestre ativos e retorna o dicionário.
func popular_filtro_professor() -> Dictionary:
	var professores: Array[String] = ["Todos"]
	var professores_retorno: Array[String] = [""]
	for chave in cards_disciplinas:
		var card: CardDisciplina = cards_disciplinas[chave]
		var sem: String = card.semestre
		if not filtro_curso.is_empty() and not semestre_pertence_ao_curso(sem, filtro_curso):
			continue
		if filtro_semestre.size() > 0:
			var sem_lower: String = sem.to_lower()
			var bateu: bool = false
			for fs in filtro_semestre:
				if sem_lower == fs.to_lower():
					bateu = true
					break
			if not bateu:
				continue
		for prof in card.professores:
			var pn: String = str(prof)
			if not pn.is_empty():
				var pn_lower: String = pn.to_lower()
				var ja_existe: bool = false
				for p in professores_retorno:
					if p.to_lower() == pn_lower:
						ja_existe = true
						break
				if not ja_existe:
					professores.append(AnaliseAfinidade.normalizar_nome(pn))
					professores_retorno.append(pn)
	var prof_pares: Array = []
	for i in range(1, professores.size()):
		prof_pares.append([professores[i], professores_retorno[i]])
	prof_pares.sort_custom(func(a, b): return a[0] < b[0])
	professores = ["Todos"]
	professores_retorno = [""]
	for par in prof_pares:
		professores.append(par[0])
		professores_retorno.append(par[1])
	return {"_Professor*": professores, "_Professor_retorno": professores_retorno}


## Aplica os filtros ativos na visibilidade dos cards.
func aplicar_filtro() -> void:
	for chave in cards_disciplinas:
		var card: CardDisciplina = cards_disciplinas[chave]
		var visivel: bool = true
		if not filtro_curso.is_empty() and not semestre_pertence_ao_curso(card.semestre, filtro_curso):
			visivel = false
		if visivel and filtro_semestre.size() > 0:
			var card_sem_lower: String = card.semestre.to_lower()
			var card_oferta_lower: String = card.oferta.to_lower()
			var bateu: bool = false
			for fs in filtro_semestre:
				var fs_lower: String = fs.to_lower()
				if card_sem_lower == fs_lower or card_oferta_lower == fs_lower:
					bateu = true
					break
			if not bateu:
				visivel = false
		if visivel and not filtro_professor.is_empty():
			var tem_prof: bool = false
			for p in card.professores:
				if p == filtro_professor:
					tem_prof = true
					break
			if not tem_prof:
				visivel = false
		card.visible = visivel


## Atualiza os labels de status com contagem de pendentes, completas e choques. [br]
## [param label_choques_alunos] e [param total_choques_alunos] são opcionais: quando o label é
## fornecido, exibe o total de alunos em choque entre disciplinas sobrepostas.
## Conta as disciplinas pendentes e completas a partir dos cards atuais. Retorna
## [code]{ "pendentes": int, "completas": int }[/code]. A apresentação fica a cargo do consumidor
## (ver [StatusBar] no módulo Planejamento de Horário).
func contar_status_cards() -> Dictionary:
	var pendentes: int = 0
	var completas: int = 0
	for chave in cards_disciplinas:
		var card: CardDisciplina = cards_disciplinas[chave]
		if card.ch_total > 0:
			if card.ch_alocada >= card.ch_total:
				completas += 1
			else:
				pendentes += 1
	return {"pendentes": pendentes, "completas": completas}


#region Sinais
func _on_card_interagido(card: CardDisciplina) -> void:
	card_interagido.emit(card)


func _on_card_remover_solicitado(_card: CardDisciplina, chave: String) -> void:
	_remover_card(chave)


func _remover_card(chave: String) -> void:
	if not cards_disciplinas.has(chave):
		return
	var card: CardDisciplina = cards_disciplinas[chave]
	card.queue_free()
	cards_disciplinas.erase(chave)
	card_removido.emit(chave)
#endregion
