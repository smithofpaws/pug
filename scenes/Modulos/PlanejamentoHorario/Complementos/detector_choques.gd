class_name DetectorDeChoques extends RefCounted
## Detecta e marca choques de horário na grade de alocações. [br]
## Tipos de choque: professor, sala e semestre no mesmo dia+horário, [br]
## além de carga horária excedida por disciplina. [br]
## Emite [signal choques_detectados] quando o método [method detectar] encontra problemas.

signal choques_detectados(resumo: String, cor: String)

# Grade visual onde as marcações de choque são aplicadas.
var _grade: GradeVisual
# Referências compartilhadas com o módulo principal.
var _alocacoes: Dictionary
var _planejamento_csv: Dictionary
var _cards_disciplinas: Dictionary
var _cores_terminal: Dictionary

## Contagem total de choques (professor + sala + semestre + CH excedida).
var total_choques: int = 0

## Configura as referências necessárias para detecção e marcação visual.
func configurar(grade: GradeVisual, alocacoes: Dictionary, planejamento_csv: Dictionary, cards_disciplinas: Dictionary, cores_terminal: Dictionary) -> void:
	_grade = grade
	_alocacoes = alocacoes
	_planejamento_csv = planejamento_csv
	_cards_disciplinas = cards_disciplinas
	_cores_terminal = cores_terminal

## Varre todas as alocações e detecta choques de professor, sala e semestre. [br]
## Se [param marcar_choques] for [code]false[/code], apenas conta sem aplicar marcações visuais. [br]
## Se [param celulas_afetadas] for não-vazio, limita a verificação apenas às células especificadas. [br]
## Retorna um dicionário com as contagens e, se houver choques, um array [param resumo] com as mensagens.
func detectar(marcar_choques: bool = true, celulas_afetadas: Array[String] = []) -> Dictionary:
	limpar_marcacoes()
	var ch_excedida: int = 0
	var prof_por_celula: Dictionary = {}
	var sala_por_celula: Dictionary = {}
	var sem_por_celula: Dictionary = {}
	var apenas_afetadas: bool = not celulas_afetadas.is_empty()
	for chave_celula in _alocacoes:
		if apenas_afetadas and not celulas_afetadas.has(chave_celula):
			continue
		var arr: Array = _alocacoes[chave_celula]
		for a_dict in arr:
			var aloc: Dictionary = a_dict
			var chave: String = aloc.get("chave", "")
			var dados_csv: Dictionary = _planejamento_csv.get(chave, {})
			var profs: Array = dados_csv.get("professor", [])
			var sala: String = aloc.get("sala", "")
			var sem: String = dados_csv.get("semestre", "")
			for prof in profs:
				var pn: String = str(prof)
				if not prof_por_celula.has(pn):
					prof_por_celula[pn] = []
				if not prof_por_celula[pn].has(chave_celula):
					prof_por_celula[pn].append(chave_celula)
			if not sala.is_empty():
				if not sala_por_celula.has(sala):
					sala_por_celula[sala] = []
				if not sala_por_celula[sala].has(chave_celula):
					sala_por_celula[sala].append(chave_celula)
			if not sem.is_empty():
				if not sem_por_celula.has(sem):
					sem_por_celula[sem] = []
				if not sem_por_celula[sem].has(chave_celula):
					sem_por_celula[sem].append(chave_celula)
	var choques_prof: int = _contar_choques(prof_por_celula, "professor", marcar_choques)
	var choques_sala: int = _contar_choques(sala_por_celula, "sala", marcar_choques)
	var choques_sem: int = _contar_choques(sem_por_celula, "semestre", marcar_choques)
	var extras_por_chave: Dictionary = {}
	for chave_celula in _alocacoes:
		if apenas_afetadas and not celulas_afetadas.has(chave_celula):
			continue
		var arr: Array = _alocacoes[chave_celula]
		for a_dict in arr:
			var aloc: Dictionary = a_dict
			if aloc.get("is_extra", false):
				var chave: String = aloc.get("chave", "")
				extras_por_chave[chave] = extras_por_chave.get(chave, 0) + 1
	if apenas_afetadas:
		for chave in extras_por_chave:
			var card: CardDisciplina = _cards_disciplinas.get(chave)
			if card and card.ch_alocada - extras_por_chave.get(chave, 0) > card.ch_total:
				ch_excedida += 1
	else:
		for chave in _cards_disciplinas:
			var card: CardDisciplina = _cards_disciplinas[chave]
			var extras: int = extras_por_chave.get(chave, 0)
			if card.ch_alocada - extras > card.ch_total:
				ch_excedida += 1
	total_choques = choques_prof + choques_sala + choques_sem + ch_excedida
	var resultado: Dictionary = {
		"choques_prof": choques_prof,
		"choques_sala": choques_sala,
		"choques_sem": choques_sem,
		"ch_excedida": ch_excedida,
		"total": total_choques,
	}
	if choques_prof > 0 or choques_sala > 0 or choques_sem > 0 or ch_excedida > 0:
		var partes: Array[String] = []
		if choques_prof > 0:
			partes.append(str(choques_prof) + " choque(s) de professor")
		if choques_sala > 0:
			partes.append(str(choques_sala) + " choque(s) de sala")
		if choques_sem > 0:
			partes.append(str(choques_sem) + " choque(s) de semestre")
		if ch_excedida > 0:
			partes.append(str(ch_excedida) + " CH excedida")
		resultado["resumo"] = partes
		resultado["cor"] = _cores_terminal.get("erro", "red")
	return resultado

## Remove todas as marcações de choque das células da grade.
func limpar_marcacoes() -> void:
	if not _grade:
		return
	for chave_celula in _alocacoes:
		var partes: PackedStringArray = chave_celula.split("_")
		if partes.size() != 2:
			continue
		var linha: int = int(partes[0])
		var coluna: int = int(partes[1])
		if linha >= _grade._linhas or coluna >= _grade._colunas:
			continue
		var celula: Celula = _grade.get_celula(linha, coluna)
		celula.cor_barra_baixo = Color(0, 0, 0, 0)
		celula.cor_barra_direita = Color(0, 0, 0, 0)

## Marca visualmente uma célula como contendo choque do [param tipo] especificado.
func marcar_celula_choque(chave_celula: String, tipo: String) -> void:
	if not _grade:
		return
	var partes: PackedStringArray = chave_celula.split("_")
	if partes.size() != 2:
		return
	var linha: int = int(partes[0])
	var coluna: int = int(partes[1])
	if linha >= _grade._linhas or coluna >= _grade._colunas:
		return
	var celula: Celula = _grade.get_celula(linha, coluna)
	match tipo:
		"professor", "semestre":
			celula.cor_barra_baixo = Color(1, 0, 0, 1)
		"sala":
			celula.cor_barra_direita = Color(1, 0.5, 0, 1)

# Conta os choques de um indice {valor: [chave_celula, ...]} e, se [param marcar_choques], marca as
# celulas em conflito. Como cada chave_celula ("linha_coluna") ja identifica o dia+horario, ha choque
# quando o mesmo valor (professor, sala ou semestre) aparece mais de uma vez na mesma celula. Conta
# os pares em conflito por celula (C(n,2)), preservando a contagem do algoritmo par-a-par anterior.
func _contar_choques(indice: Dictionary, tipo: String, marcar_choques: bool) -> int:
	var total: int = 0
	for valor in indice:
		var contagem_por_celula: Dictionary = {}
		for chave_celula in indice[valor]:
			contagem_por_celula[chave_celula] = contagem_por_celula.get(chave_celula, 0) + 1
		for chave_celula in contagem_por_celula:
			var n: int = contagem_por_celula[chave_celula]
			if n > 1:
				total += n * (n - 1) / 2
				if marcar_choques:
					marcar_celula_choque(chave_celula, tipo)
	return total