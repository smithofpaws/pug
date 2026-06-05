class_name VerificadorCarga extends RefCounted
## Verifica a carga horária dos professores na grade de alocações. [br]
## Detecta dois problemas: carga ≥6h no mesmo dia e aula noturna seguida de manhã cedo [br]
## no dia seguinte. [br]
##
## É puro de detecção: devolve as mensagens e, por célula, quais estão em sobrecarga. NÃO pinta a
## grade — a pintura fica a cargo do [AplicadorVisualGrade].

# Referências compartilhadas com o módulo principal.
var _alocacoes: Dictionary
var _planejamento_csv: Dictionary

## Configura as referências necessárias para verificação.
func configurar(alocacoes: Dictionary, planejamento_csv: Dictionary) -> void:
	_alocacoes = alocacoes
	_planejamento_csv = planejamento_csv

## Verifica a carga dos professores conforme [param horas] (horas das aulas em ordem). [br]
## Retorna [code]{ "avisos": Array[String], "info": String, "celulas_carga": Dictionary,
## "celulas_noturna": Dictionary }[/code], onde os mapas são conjuntos [code]{ "linha_coluna":
## true }[/code] das células afetadas por cada problema.
func verificar(horas: Array[String], prof_filtro: String = "") -> Dictionary:
	if horas.is_empty():
		return {"avisos": [], "info": "", "celulas_carga": {}, "celulas_noturna": {}}
	var prof_dias: Dictionary = _mapear_professores_por_dia(horas)
	# Com filtro de professor, restringe a verificação a ele: carga/noturna são por professor, e numa
	# célula compartilhada o aviso de OUTRO professor não deve aparecer na disciplina do filtrado.
	if not prof_filtro.is_empty():
		var pfl: String = prof_filtro.to_lower()
		var so_filtrado: Dictionary = {}
		for pn in prof_dias:
			if pn.to_lower() == pfl:
				so_filtrado[pn] = prof_dias[pn]
		prof_dias = so_filtrado
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
			# Marca SOMENTE as aulas efetivamente noturnas (dia 1) e matinais (dia 2) que causam o
			# problema — não o dia inteiro. Assim uma aula de tarde no meio não fica sinalizada.
			var linhas_noturnas: Array = _linhas_no_periodo(dia_map[dia1], horas, true)
			if linhas_noturnas.is_empty():
				continue
			var linhas_matinais: Array = _linhas_no_periodo(dia_map[dia2], horas, false)
			if linhas_matinais.is_empty():
				continue
			avisos.append("%s: aula noturna (col %d) seguida de manhã cedo (col %d)." % [pn.capitalize(), dia1, dia2])
			for l in linhas_noturnas:
				celulas_noturna["%d_%d" % [l, dia1]] = true
			for l in linhas_matinais:
				celulas_noturna["%d_%d" % [l, dia2]] = true
	var info: String = ""
	if prof_dias.is_empty():
		info = "(Verif. carga: nenhum professor encontrado)"
	elif avisos.is_empty():
		info = "(Verif. carga: OK — %d professor(es))" % prof_dias.size()
	return {"avisos": avisos, "info": info, "celulas_carga": celulas_carga, "celulas_noturna": celulas_noturna}

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

# Linhas (índices 1-based) de [param linhas] que caem no período noturno (≥18h) ou, quando
# [param noite] é false, no matutino (≤12h).
func _linhas_no_periodo(linhas: Array, horas: Array[String], noite: bool) -> Array:
	var resultado: Array = []
	for l in linhas:
		if l > horas.size():
			continue
		var hora_inicio: int = int(horas[l - 1].substr(0, 2))
		if noite and hora_inicio >= 18:
			resultado.append(l)
		elif not noite and hora_inicio <= 12:
			resultado.append(l)
	return resultado
