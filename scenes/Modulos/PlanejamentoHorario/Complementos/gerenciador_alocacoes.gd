class_name GerenciadorAlocacoes extends RefCounted
## Gerencia as alocações de disciplinas na grade de horários. [br]
## Centraliza CRUD de [param alocacoes], renderização de células e modo de visualização. [br]
## Cada célula pode conter múltiplas alocações sobrepostas (ex.: disciplinas de semestres diferentes).

## Dicionário de alocações. Chave: [code]"linha_coluna"[/code] → Array de dicionários com chave, codigo, sala, tipo, turma, vagas, p, s, t.
var alocacoes: Dictionary = {}

## Modo de exibição do texto das células: [code]somente_codigo[/code], [code]completo[/code], [code]codigo_nome_reduzido[/code], [code]nome_completo[/code] ou [code]nome_reduzido[/code].
var modo_visualizacao: String = "nome_reduzido"

## Semestre destacado na grade. Quando definido, células com sobreposição de semestres exibem [br]
## somente as alocações deste semestre. Vazio = exibe todas as alocações da célula.
var semestre_filtro: String = ""

## Prefixos de semestre (maiúsculos, ex.: [code]["EC"][/code]) do curso filtrado no painel.
## Quando não-vazio, células com sobreposição exibem somente as alocações desse curso (oculta
## nomes de disciplinas de outros cursos). Compartilhadas casam pelo prefixo (ex.: "EC04;EM04"
## casa com "EC"). Vazio = sem filtro de curso.
var curso_filtro_prefixos: Array[String] = []

## Professor atualmente filtrado no painel de disciplinas. Quando definido, alocações
## que correspondem a este professor são exibidas primeiro na célula.
var _filtro_professor: String = ""

var _grade: GradeVisual
var _cards_disciplinas: Dictionary
var _planejamento_csv: Dictionary
var _analise_grades: AnaliseGrades
var _grades_disciplinas_curriculos: Dictionary
var _general_functions := GeneralFunctions.new()

## Configura as referências necessárias para renderização e consulta.
func configurar(grade: GradeVisual, cards_disciplinas: Dictionary, planejamento_csv: Dictionary, analise_grades: AnaliseGrades, grades_disciplinas_curriculos: Dictionary) -> void:
	_grade = grade
	_cards_disciplinas = cards_disciplinas
	_planejamento_csv = planejamento_csv
	_analise_grades = analise_grades
	_grades_disciplinas_curriculos = grades_disciplinas_curriculos

## Define o professor cujas alocações devem aparecer primeiro nas células.
func definir_filtro_professor(prof: String) -> void:
	_filtro_professor = prof

## Limpa todas as alocações armazenadas.
func limpar_alocacoes() -> void:
	alocacoes.clear()

## Aloca uma disciplina na posição [param chave_celula] com os [param dados] fornecidos. [br]
## Permite múltiplas alocações sobrepostas na mesma célula.
func alocar(chave_celula: String, dados: Dictionary) -> void:
	if not alocacoes.has(chave_celula):
		alocacoes[chave_celula] = []
	alocacoes[chave_celula].append(dados)

## Remove todas as alocações na posição [param chave_celula].
func remover(chave_celula: String) -> void:
	alocacoes.erase(chave_celula)

## Remove uma alocação específica pelo índice na posição [param chave_celula].
func remover_indice(chave_celula: String, indice: int) -> void:
	if not alocacoes.has(chave_celula):
		return
	var arr: Array = alocacoes[chave_celula]
	if indice >= 0 and indice < arr.size():
		arr.remove_at(indice)
	if arr.is_empty():
		alocacoes.erase(chave_celula)

## Retorna o Array de alocações na célula, ou array vazio se não houver.
func obter_alocacoes(chave_celula: String) -> Array:
	if not alocacoes.has(chave_celula):
		return []
	return alocacoes[chave_celula]

## Atualiza visualmente a célula na posição [param linha], [param coluna] conforme [param modo_visualizacao]. [br]
## Se houver múltiplas alocações, concatena os códigos separados por "/".
func atualizar_celula(linha: int, coluna: int) -> void:
	if not _grade:
		return
	if linha >= _grade._linhas or coluna >= _grade._colunas:
		return
	var chave_celula := "%d_%d" % [linha, coluna]
	var arr: Array = obter_alocacoes(chave_celula)
	if arr.is_empty():
		return
	var celula: Celula = _grade.get_celula(linha, coluna)
	celula.cor_texto_override = Color.TRANSPARENT
	# Com semestre_filtro ativo: se a célula contém alocações desse semestre, exibe somente
	# elas (oculta nomes de outros semestres em sobreposições). Senão, exibe todas.
	var arr_render: Array = arr
	if not semestre_filtro.is_empty():
		var do_semestre: Array = []
		for a_dict in arr:
			if _semestre_da_aloc(a_dict as Dictionary).to_lower() == semestre_filtro.to_lower():
				do_semestre.append(a_dict)
		if not do_semestre.is_empty():
			arr_render = do_semestre
	# Com curso_filtro_prefixos ativo: exibe somente as alocações do curso filtrado, ocultando os
	# nomes das disciplinas de outros cursos (ex.: só EC com Engenharia Civil). Diferente do
	# semestre_filtro (um destaque), o filtro de curso oculta: células exclusivamente de outros
	# cursos ficam com texto vazio (do_curso vazio → sem rótulo), sem depender de _aplicar_filtro_grade.
	# Compartilhadas casam pelo prefixo (ex.: "EC04;EM04" casa com "EC").
	if not curso_filtro_prefixos.is_empty():
		var do_curso: Array = []
		for a_dict in arr_render:
			var sem_upper: String = _semestre_da_aloc(a_dict as Dictionary).to_upper().strip_edges()
			for prefixo in curso_filtro_prefixos:
				if sem_upper.begins_with(prefixo):
					do_curso.append(a_dict)
					break
		arr_render = do_curso
	# Se houver filtro de professor ativo, reordena: alocações do professor primeiro.
	if not _filtro_professor.is_empty():
		var pf := _filtro_professor.to_lower()
		arr_render.sort_custom(func(a: Variant, b: Variant):
			var pa := _prof_bate(a as Dictionary, pf)
			var pb := _prof_bate(b as Dictionary, pf)
			return pa and not pb)
	var partes: Array[String] = []
	var tem_extra: bool = false
	for a_dict in arr_render:
		var aloc: Dictionary = a_dict
		if aloc.get("is_extra", false):
			tem_extra = true
		var rotulo: String = rotulo_alocacao(aloc)
		if not rotulo.is_empty():
			partes.append(rotulo)
	celula.texto_central = "\n".join(partes)
	celula.cor_central = "orange" if tem_extra else "white"
	celula.apenas_central = true
	celula.alocacao_chave = chave_celula

# Semestre de uma alocação: do planejamento.csv com fallback para o card. Usado pelos filtros
# de semestre e de curso ao decidir quais alocações exibir numa célula com sobreposição.
func _semestre_da_aloc(aloc: Dictionary) -> String:
	var ch: String = aloc.get("chave", "")
	var sem_aloc: String = _planejamento_csv.get(ch, {}).get("semestre", "")
	if sem_aloc.is_empty():
		var card: CardDisciplina = _cards_disciplinas.get(ch)
		if card:
			sem_aloc = card.semestre
	return sem_aloc


## Retorna o rótulo de UMA alocação conforme [member modo_visualizacao]. [br]
## Os modos de nome ([code]nome_completo[/code]/[code]nome_reduzido[/code]) exibem apenas o nome da
## disciplina, sem o código; [code]completo[/code] mostra código + turma + nome reduzido e
## [code]codigo_nome_reduzido[/code] mostra código + nome reduzido (partes separadas por " - "). [br]
## Reutilizado tanto na renderização das células quanto na apresentação de choques no terminal.
func rotulo_alocacao(aloc: Dictionary) -> String:
	var cod: String = aloc.get("codigo", "").to_upper()
	match modo_visualizacao:
		"codigo_nome_reduzido":
			var nr: String = _nome_reduzido(aloc)
			return cod + (" - " + nr if not nr.is_empty() else "")
		"completo":
			var partes: Array[String] = [cod]
			var turma: String = aloc.get("turma", "")
			if not turma.is_empty():
				partes.append(turma)
			var nrc: String = _nome_reduzido(aloc)
			if not nrc.is_empty():
				partes.append(nrc)
			return " - ".join(partes)
		"nome_completo", "nome_reduzido":
			var nome: String = _nome_disciplina(aloc)
			if nome.is_empty():
				return cod
			if modo_visualizacao == "nome_reduzido":
				return _general_functions.encurtar_texto(nome, 3)
			return nome
		"esferas":
			return "●"
		_:
			return cod

# Retorna o nome reduzido (abreviado) de uma alocação, ou "" se não houver nome.
func _nome_reduzido(aloc: Dictionary) -> String:
	var nome: String = _nome_disciplina(aloc)
	return _general_functions.encurtar_texto(nome, 3) if not nome.is_empty() else ""

# Resolve o nome da disciplina de uma alocação, via card e, em fallback, via grade curricular.
func _nome_disciplina(aloc: Dictionary) -> String:
	var chave: String = aloc.get("chave", "")
	var card: CardDisciplina = _cards_disciplinas.get(chave)
	var nome: String = card.nome if card else ""
	if nome.is_empty():
		var codigo: String = aloc.get("codigo", "")
		nome = _analise_grades.info_grade(_grades_disciplinas_curriculos, codigo, "nome")
		if nome.begins_with("Codigo"):
			nome = codigo
	return nome

# Verifica se o professor da alocação confere com [param pf] (lowercase).
func _prof_bate(aloc: Dictionary, pf: String) -> bool:
	var dados: Dictionary = _planejamento_csv.get(aloc.get("chave", ""), {})
	for p in dados.get("professor", []):
		if str(p).to_lower() == pf:
			return true
	return str(aloc.get("professor", "")).to_lower() == pf

## Limpa visualmente a célula na posição [param linha], [param coluna].
func limpar_celula(linha: int, coluna: int) -> void:
	if not _grade:
		return
	if linha >= _grade._linhas or coluna >= _grade._colunas:
		return
	var celula: Celula = _grade.get_celula(linha, coluna)
	celula.texto_central = ""
	celula.apenas_central = true
	celula.alocacao_chave = ""
	celula.cor_barra_cima = Color(0, 0, 0, 0)
	celula.cor_barra_baixo = Color(0, 0, 0, 0)
	celula.cor_barra_esquerda = Color(0, 0, 0, 0)
	celula.cor_barra_direita = Color(0, 0, 0, 0)
	celula.cor_fundo = Color(0.173, 0.173, 0.173, 1)
	celula.cor_texto_override = Color.TRANSPARENT

## Reaplica visualmente todas as alocações salvas nas células da grade. [br]
## Necessário após reconstrução da grade (ex.: troca de preferências de professor).
func reaplicar_todas() -> void:
	if not _grade:
		return
	for chave_celula in alocacoes:
		var partes: PackedStringArray = chave_celula.split("_")
		if partes.size() != 2:
			continue
		var linha: int = int(partes[0])
		var coluna: int = int(partes[1])
		if linha >= _grade._linhas or coluna >= _grade._colunas:
			continue
		atualizar_celula(linha, coluna)

## Marca em vermelho as células cujo professor está vazio. [br]
## Retorna a contagem de células com problema. Se [param indicar] for [code]false[/code], conta mas não altera cores.
func aplicar_indicador_problemas(indicar: bool) -> int:
	if alocacoes.size() == 0:
		return 0
	if not _grade:
		return 0
	var contador: int = 0
	for chave_celula in alocacoes:
		var arr: Array = alocacoes[chave_celula]
		var tem_problema: bool = false
		for a_dict in arr:
			var aloc: Dictionary = a_dict
			var chave: String = aloc.get("chave", "")
			var dados_csv: Dictionary = _planejamento_csv.get(chave, {})
			var profs: Array = dados_csv.get("professor", [])
			var prof_nome: String = str(profs[0]) if profs.size() > 0 else ""
			if prof_nome.is_empty():
				tem_problema = true
				break
		if tem_problema:
			var partes: PackedStringArray = chave_celula.split("_")
			if partes.size() == 2:
				var linha: int = int(partes[0])
				var coluna: int = int(partes[1])
				if linha >= 1 and coluna >= 1 and linha < _grade._linhas and coluna < _grade._colunas:
					# Só pinta quando indicar; senão apenas conta (não sobrescreve a cor
					# definida pelo filtro de semestre, que repinta as células logo antes).
					if indicar:
						_grade.get_celula(linha, coluna).cor_central = "red"
					contador += 1
	return contador
