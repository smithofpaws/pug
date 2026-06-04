class_name VerificadorCarga extends RefCounted
## Verifica a carga horária dos professores na grade de alocações. [br]
## Detecta dois problemas: carga ≥6h no mesmo dia e aula noturna seguida de manhã cedo [br]
## no dia seguinte. Marca as células afetadas com a barra esquerda e devolve as mensagens.

# Grade visual onde as marcações são aplicadas.
var _grade: GradeVisual
# Referências compartilhadas com o módulo principal.
var _alocacoes: Dictionary
var _planejamento_csv: Dictionary

# Cor da barra esquerda usada para sinalizar carga excessiva ou noturna→manhã.
const COR_AVISO := Color(1, 0.5, 0, 1)

## Configura as referências necessárias para verificação e marcação visual.
func configurar(grade: GradeVisual, alocacoes: Dictionary, planejamento_csv: Dictionary) -> void:
	_grade = grade
	_alocacoes = alocacoes
	_planejamento_csv = planejamento_csv

## Verifica a carga dos professores conforme [param horas] (horas das aulas em ordem). [br]
## [param marcar_carga] e [param marcar_noturna] controlam se cada tipo pinta a barra esquerda. [br]
## Retorna [code]{ "avisos": Array[String], "info": String }[/code], onde [param avisos] são os [br]
## problemas encontrados e [param info] é a mensagem de status (vazia quando há avisos).
func verificar(horas: Array[String], marcar_carga: bool, marcar_noturna: bool) -> Dictionary:
	if not _grade or horas.is_empty():
		return {"avisos": [], "info": ""}
	_limpar_barras_esquerdas()
	var prof_dias: Dictionary = _mapear_professores_por_dia(horas)
	var celulas_carga: Dictionary = {}
	var celulas_noturna: Dictionary = {}
	var avisos: Array[String] = []
	for pn in prof_dias:
		var dia_map: Dictionary = prof_dias[pn]
		var dias_ordenados: Array = dia_map.keys()
		dias_ordenados.sort()
		for dia in dia_map:
			var linhas: Array = dia_map[dia]
			if linhas.size() >= 6:
				avisos.append("%s: %dh no mesmo dia (col %d)." % [pn.capitalize(), linhas.size(), dia])
				for l in linhas:
					celulas_carga["%d_%d" % [l, dia]] = true
		for i in range(dias_ordenados.size() - 1):
			var dia1: int = dias_ordenados[i]
			var dia2: int = dias_ordenados[i + 1]
			if dia2 != dia1 + 1:
				continue
			if not _tem_aula_no_periodo(dia_map[dia1], horas, true):
				continue
			if _tem_aula_no_periodo(dia_map[dia2], horas, false):
				avisos.append("%s: aula noturna (col %d) seguida de manhã cedo (col %d)." % [pn.capitalize(), dia1, dia2])
				for l in dia_map[dia1]:
					celulas_noturna["%d_%d" % [l, dia1]] = true
				for l in dia_map[dia2]:
					celulas_noturna["%d_%d" % [l, dia2]] = true
	if marcar_carga:
		_pintar_barra_esquerda(celulas_carga)
	if marcar_noturna:
		_pintar_barra_esquerda(celulas_noturna)
	var info: String = ""
	if prof_dias.is_empty():
		info = "(Verif. carga: nenhum professor encontrado)"
	elif avisos.is_empty():
		info = "(Verif. carga: OK — %d professor(es))" % prof_dias.size()
	return {"avisos": avisos, "info": info}

# Mapeia cada professor para as linhas que ocupa em cada coluna (dia): { prof -> { coluna -> [linhas] } }.
func _mapear_professores_por_dia(horas: Array[String]) -> Dictionary:
	var prof_dias: Dictionary = {}
	var visto: Dictionary = {}
	for chave_celula in _alocacoes:
		var partes: PackedStringArray = chave_celula.split("_")
		if partes.size() != 2:
			continue
		var linha: int = int(partes[0])
		var coluna: int = int(partes[1])
		if linha < 1 or coluna < 1 or linha > horas.size():
			continue
		for a_dict in _alocacoes[chave_celula]:
			var aloc: Dictionary = a_dict
			var dados_csv: Dictionary = _planejamento_csv.get(aloc.get("chave", ""), {})
			for prof in dados_csv.get("professor", []):
				var pn: String = str(prof)
				if not prof_dias.has(pn):
					prof_dias[pn] = {}
					visto[pn] = {}
				var dia_map: Dictionary = prof_dias[pn]
				if not dia_map.has(coluna):
					dia_map[coluna] = []
				var cl := "%d_%d" % [coluna, linha]
				var vp: Dictionary = visto[pn]
				if not vp.has(cl):
					vp[cl] = true
					dia_map[coluna].append(linha)
	return prof_dias

# Verifica se alguma das [param linhas] cai no período noturno (≥18h) ou matutino (≤12h, [param noite] = false).
func _tem_aula_no_periodo(linhas: Array, horas: Array[String], noite: bool) -> bool:
	for l in linhas:
		if l > horas.size():
			continue
		var hora_inicio: int = int(horas[l - 1].substr(0, 2))
		if noite and hora_inicio >= 18:
			return true
		if not noite and hora_inicio <= 12:
			return true
	return false

# Remove as barras esquerdas de todas as células alocadas.
func _limpar_barras_esquerdas() -> void:
	for chave_celula in _alocacoes:
		var partes: PackedStringArray = chave_celula.split("_")
		if partes.size() != 2:
			continue
		var linha: int = int(partes[0])
		var coluna: int = int(partes[1])
		if linha >= 1 and linha < _grade._linhas and coluna >= 1 and coluna < _grade._colunas:
			_grade.get_celula(linha, coluna).cor_barra_esquerda = Color(0, 0, 0, 0)

# Pinta a barra esquerda das [param celulas] (chaves "linha_coluna") com a cor de aviso.
func _pintar_barra_esquerda(celulas: Dictionary) -> void:
	for chave_celula in celulas:
		var partes: PackedStringArray = chave_celula.split("_")
		if partes.size() != 2:
			continue
		var linha: int = int(partes[0])
		var coluna: int = int(partes[1])
		if linha >= 1 and linha < _grade._linhas and coluna >= 1 and coluna < _grade._colunas:
			_grade.get_celula(linha, coluna).cor_barra_esquerda = COR_AVISO
