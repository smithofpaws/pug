class_name DetectorDeChoques extends RefCounted
## Detecta choques de horário na grade de alocações. [br]
## Tipos de choque: professor, sala e semestre no mesmo dia+horário, [br]
## além de carga horária excedida por disciplina. [br]
##
## É puro de detecção: conta os choques e devolve, por célula, quais categorias de problema a
## afetam. NÃO pinta a grade nem escreve no terminal — a pintura fica a cargo do
## [AplicadorVisualGrade] e o relato a cargo do [RelatoriosHorario].

# Referências compartilhadas com o módulo principal.
var _alocacoes: Dictionary
var _planejamento_csv: Dictionary
var _cards_disciplinas: Dictionary

## Contagem total de choques (professor + sala + semestre + CH excedida).
var total_choques: int = 0

## Configura as referências necessárias para detecção.
func configurar(alocacoes: Dictionary, planejamento_csv: Dictionary, cards_disciplinas: Dictionary) -> void:
	_alocacoes = alocacoes
	_planejamento_csv = planejamento_csv
	_cards_disciplinas = cards_disciplinas

## Varre as alocações e detecta choques de professor, sala e semestre, além de CH excedida. [br]
## Se [param celulas_afetadas] for não-vazio, limita a verificação a essas células. [br]
## Retorna um dicionário com as contagens, um [param resumo] (Array[String]) quando há problemas,
## e dois mapas por célula: [br]
## [code]celulas_choque: { "linha_coluna": { "prof":bool, "sala":bool, "sem":bool } }[/code] e
## [code]celulas_ch_excedida: { "linha_coluna": true }[/code].
func detectar(celulas_afetadas: Array[String] = []) -> Dictionary:
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
			# Alocacao de outro curso sobreposta como referencia (somente-leitura). Choque de
			# professor/sala CONTINUA valendo (conflito de recurso entre cursos e justamente o que
			# interessa co-planejar). Ja choque de semestre (interno de um curso) nao e contado para
			# a referencia — nao e responsabilidade deste coordenador.
			var eh_ref: bool = aloc.get("referencia", false) or dados_csv.get("referencia", false)
			# Acumula UMA ocorrência por alocação (sem deduplicar a célula): é a contagem de
			# ocorrências por célula que revela o choque em _contar_choques (n > 1). Deduplicar
			# aqui zeraria a detecção de sobreposição na mesma célula.
			for prof in profs:
				var pn: String = str(prof)
				if not prof_por_celula.has(pn):
					prof_por_celula[pn] = []
				prof_por_celula[pn].append(chave_celula)
			if not sala.is_empty():
				if not sala_por_celula.has(sala):
					sala_por_celula[sala] = []
				sala_por_celula[sala].append(chave_celula)
			if not sem.is_empty() and not eh_ref:
				if not sem_por_celula.has(sem):
					sem_por_celula[sem] = []
				sem_por_celula[sem].append(chave_celula)
	# Mapa por célula das categorias de choque (alimenta o aplicador visual e o tooltip).
	var celulas_choque: Dictionary = {}
	var choques_prof: int = _contar_choques(prof_por_celula, "prof", celulas_choque)
	var choques_sala: int = _contar_choques(sala_por_celula, "sala", celulas_choque)
	var choques_sem: int = _contar_choques(sem_por_celula, "sem", celulas_choque)

	# CH excedida é por disciplina (card); as células afetadas são todas as que a contêm.
	var extras_por_chave: Dictionary = {}
	for chave_celula in _alocacoes:
		for a_dict in _alocacoes[chave_celula]:
			var aloc: Dictionary = a_dict
			if aloc.get("is_extra", false):
				var chave: String = aloc.get("chave", "")
				extras_por_chave[chave] = extras_por_chave.get(chave, 0) + 1
	var chaves_excedidas: Dictionary = {}
	for chave in _cards_disciplinas:
		# CH excedida de disciplina de outro curso (referencia) nao e responsabilidade deste usuario.
		if _planejamento_csv.get(chave, {}).get("referencia", false):
			continue
		var card: CardDisciplina = _cards_disciplinas[chave]
		var extras: int = extras_por_chave.get(chave, 0)
		if card.ch_alocada - extras > card.ch_total:
			chaves_excedidas[chave] = true
	var celulas_ch_excedida: Dictionary = {}
	var ch_excedida: int = chaves_excedidas.size()
	if ch_excedida > 0:
		for chave_celula in _alocacoes:
			for a_dict in _alocacoes[chave_celula]:
				if chaves_excedidas.has((a_dict as Dictionary).get("chave", "")):
					celulas_ch_excedida[chave_celula] = true
					break

	total_choques = choques_prof + choques_sala + choques_sem + ch_excedida
	var resultado: Dictionary = {
		"choques_prof": choques_prof,
		"choques_sala": choques_sala,
		"choques_sem": choques_sem,
		"ch_excedida": ch_excedida,
		"total": total_choques,
		"celulas_choque": celulas_choque,
		"celulas_ch_excedida": celulas_ch_excedida,
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
	return resultado

# Conta os choques de um índice {valor: [chave_celula, ...]} e registra em [param celulas_out] as
# células em conflito sob a chave [param tipo] ("prof"/"sala"/"sem"). Há choque quando o mesmo valor
# aparece mais de uma vez na mesma célula; conta os pares por célula (C(n,2)).
func _contar_choques(indice: Dictionary, tipo: String, celulas_out: Dictionary) -> int:
	var total: int = 0
	for valor in indice:
		var contagem_por_celula: Dictionary = {}
		for chave_celula in indice[valor]:
			contagem_por_celula[chave_celula] = contagem_por_celula.get(chave_celula, 0) + 1
		for chave_celula in contagem_por_celula:
			var n: int = contagem_por_celula[chave_celula]
			if n > 1:
				total += n * (n - 1) / 2
				if not celulas_out.has(chave_celula):
					celulas_out[chave_celula] = {}
				celulas_out[chave_celula][tipo] = true
	return total
