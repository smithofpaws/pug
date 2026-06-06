class_name AnaliseAfinidade extends RefCounted
## Motor de calculo de afinidade entre professores e disciplinas. [br]
## Constroi um indice reverso a partir do [code]historico_professores.json[/code] e responde
## consultas de afinidade por disciplina (considerando equivalencias e bonus de curso). [br]
## E logica pura, sem dependencias de UI — os dados sao injetados uma unica vez por
## [method configurar] e o indice/caches sao reconstruidos a partir deles.

# Dados injetados via [method configurar].
var _historico_professores: Dictionary = {}
var _cursos: Dictionary = {}
var _equivalencias: Dictionary = {}
var _janela: int = 15

# Turmas globais (oferecidas a todos os cursos, ex.: T90), de base_config.json:turmas_globais.
# Set para lookup O(1): { turma_int: true }.
var _turmas_globais: Dictionary = {}

# Indice reverso de afinidade: { codigo → [{ nome, score, entradas:[{ano, semestre, peso, turmas}] }] }.
# O score e o somatorio dos pesos da janela deslizante (antes do bonus de curso). As entradas
# armazenam dados brutos para calculo do bonus de turma sob demanda.
var _index: Dictionary = {}

# Cache de codigos equivalentes: { codigo → Array[String] } (inclui o proprio, em minusculas).
# Evita varrer todos os arquivos de equivalencia a cada consulta.
var _equiv_cache: Dictionary = {}

# Indice reverso por professor (construido sob demanda): { nome → [{ codigo, score }] }.
var _por_prof_cache: Dictionary = {}
var _por_prof_construido: bool = false

# Cache de professores por curso (construido sob demanda): { cod_curso → { nome_normalizado: true } }.
var _prof_curso_cache: Dictionary = {}


## Injeta os dados e (re)constroi o indice e os caches. [param janela] e o tamanho da janela
## de afinidade (de [code]base_config.json:planejamento_oferta.janela_afinidade[/code]).
## [param turmas_globais] e a lista [code]base_config.json:turmas_globais[/code] (turmas
## oferecidas a todos os cursos, ex.: T90); vem como float do JSON e e convertida para int.
func configurar(historico: Dictionary, cursos: Dictionary, equivalencias: Dictionary, janela: int, turmas_globais: Array = []) -> void:
	_historico_professores = historico
	_cursos = cursos
	_equivalencias = equivalencias
	_janela = janela
	_turmas_globais.clear()
	for t in turmas_globais:
		_turmas_globais[int(t)] = true
	_equiv_cache.clear()
	_por_prof_cache.clear()
	_por_prof_construido = false
	_prof_curso_cache.clear()
	construir_index()


## Indica se o indice de afinidade esta vazio (sem historico carregado).
func index_vazio() -> bool:
	return _index.is_empty()


# Constroi o indice reverso de afinidade a partir do historico de professores.
# Usa janela deslizante: o ano mais recente vale o tamanho da janela em pontos e decai
# 1 ponto por ano ate o minimo de 1. Anos mais distantes que a janela tambem valem 1.
# O score e a soma dos pesos de cada ano/semestre. Alem disso, armazena os dados brutos
# de cada ocorrencia (ano, semestre, peso, turmas) para que [method obter_afinidade] possa
# aplicar bonus de curso. [br]
# Nota: chaves como "2010", "2023" no [code]historico_professores.json[/code] sao anos de
# oferta (nao versoes de grade) e por isso nao seguem a convencao [code]<cod_curso>_<versao>[/code].
func construir_index() -> void:
	_index.clear()
	if _historico_professores.is_empty():
		return
	var janela: int = _janela
	# Encontra o ano mais recente do historico.
	var ano_maximo: int = 0
	for prof_nome in _historico_professores:
		for codigo in _historico_professores[prof_nome]:
			for ano_str in _historico_professores[prof_nome][codigo]:
				var ano: int = int(ano_str)
				if ano > ano_maximo:
					ano_maximo = ano
	if ano_maximo <= 0:
		return
	for prof_nome in _historico_professores:
		var nome_normalizado := normalizar_nome(prof_nome)
		var disciplinas: Dictionary = _historico_professores[prof_nome]
		for codigo in disciplinas:
			var dados: Dictionary = disciplinas[codigo]
			var score: int = 0
			var entradas: Array = []
			for ano_str in dados:
				if not (dados[ano_str] is Dictionary):
					continue
				var ano: int = int(ano_str)
				var distancia: int = ano_maximo - ano
				var peso: int = janela - distancia
				if peso < 1:
					peso = 1
				var semestres_dict: Dictionary = dados[ano_str]
				for sem_str in semestres_dict:
					var entrada_sem: Array = semestres_dict[sem_str]
					if not (entrada_sem is Array):
						continue
					var turmas: Array = _extrair_turmas(entrada_sem)
					score += peso
					entradas.append({
						"ano": ano,
						"semestre": sem_str,
						"peso": peso,
						"turmas": turmas,
					})
			# Mescla com entrada existente (mesmo professor, mesmo codigo).
			var ja_existe: bool = false
			if _index.has(codigo):
				for entrada in _index[codigo]:
					if entrada["nome"] == nome_normalizado:
						entrada["score"] = entrada.get("score", 0) + score
						for e in entradas:
							(entrada["entradas"] as Array).append(e)
						ja_existe = true
						break
			if not ja_existe:
				if not _index.has(codigo):
					_index[codigo] = []
				_index[codigo].append({
					"nome": nome_normalizado,
					"score": score,
					"entradas": entradas,
				})
	# Ordena cada lista por score (descendente).
	for codigo in _index:
		var lista: Array = _index[codigo]
		lista.sort_custom(func(a, b): return a["score"] > b["score"])
		_index[codigo] = lista


# Retorna os codigos equivalentes a um codigo (incluindo ele proprio), em minusculas.
# Memoiza o resultado por codigo: a primeira consulta varre os arquivos de equivalencia,
# as seguintes (mesmo codigo) sao O(1).
func codigos_equivalentes(codigo: String) -> Array[String]:
	if _equiv_cache.has(codigo):
		return _equiv_cache[codigo]
	var codigos: Array[String] = [codigo.to_lower()]
	for nome_arquivo in _equivalencias:
		var dict_equiv: Dictionary = _equivalencias[nome_arquivo]
		if dict_equiv.has(codigo):
			var valor = dict_equiv[codigo]
			if valor is String:
				codigos.append(valor.to_lower())
			elif valor is Array:
				for v in valor:
					codigos.append(str(v).to_lower())
	# Remove duplicatas preservando a ordem (o codigo clicado fica em primeiro).
	var unicos: Array[String] = []
	for c in codigos:
		if not c in unicos:
			unicos.append(c)
	_equiv_cache[codigo] = unicos
	return unicos


## Obtem a afinidade para um codigo, considerando tambem codigos equivalentes. [br]
## Aplica bonus de curso quando as turmas da ocorrencia batem com as turmas esperadas para
## o curso da disciplina, definidas em [code]base_config.json:cursos[/code].
func obter_afinidade(codigo: String, semestre: String = "") -> Array[Dictionary]:
	var codigos: Array[String] = codigos_equivalentes(codigo)
	# Determina o curso-alvo a partir do prefixo do semestre.
	var curso_alvo: String = prefixo_para_curso(semestre)
	# Busca cada codigo e mescla os resultados (somando scores + bonus).
	var resultado: Dictionary = {}
	for c in codigos:
		if _index.has(c):
			for entrada in _index[c]:
				var nome: String = entrada["nome"]
				var score_base: int = entrada["score"]
				var score_bonus: int = 0
				if not curso_alvo.is_empty():
					for e in entrada.get("entradas", []):
						var turmas: Array = e.get("turmas", [])
						for t in turmas:
							if turma_e_global(t) or turma_para_curso(t) == curso_alvo:
								score_bonus += int(e.get("peso", 0))
								break
				var score_total: int = score_base + score_bonus
				if resultado.has(nome):
					resultado[nome] += score_total
				else:
					resultado[nome] = score_total
	var lista: Array[Dictionary] = []
	for nome in resultado:
		lista.append({"nome": nome, "score": int(resultado[nome])})
	lista.sort_custom(func(a, b): return a["score"] > b["score"])
	return lista


## Indice reverso por professor: { nome → [{ codigo, score }] } ordenado por score (desc).
## Construido sob demanda e cacheado (o indice base e imutavel apos [method construir_index]).
func afinidade_por_prof() -> Dictionary:
	if _por_prof_construido:
		return _por_prof_cache
	_por_prof_cache.clear()
	for codigo in _index:
		for entrada in _index[codigo]:
			var nome: String = entrada["nome"]
			if not _por_prof_cache.has(nome):
				_por_prof_cache[nome] = []
			_por_prof_cache[nome].append({"codigo": codigo, "score": entrada["score"]})
	for nome in _por_prof_cache:
		(_por_prof_cache[nome] as Array).sort_custom(func(a, b): return a["score"] > b["score"])
	_por_prof_construido = true
	return _por_prof_cache


## Monta, por professor, o texto de historico (anos e semestres) em que lecionou o codigo
## informado ou seus equivalentes. Retorna [code]{ nome_prof: "2023 (1, 2) | 2021 (2)" }[/code].
func detalhes_historico(codigo: String) -> Dictionary:
	var detalhes: Dictionary = {}
	if _historico_professores.is_empty():
		return detalhes
	var codigos: Array[String] = codigos_equivalentes(codigo)
	for prof_name in _historico_professores:
		var nome_normalizado := normalizar_nome(prof_name)
		var disciplinas: Dictionary = _historico_professores[prof_name]
		var partes: PackedStringArray = []
		for cod in codigos:
			if not disciplinas.has(cod):
				continue
			var dados_disc: Dictionary = disciplinas[cod]
			for ano in dados_disc:
				var sems: String = ""
				for sem in dados_disc[ano]:
					if not sems.is_empty():
						sems += ", "
					sems += sem
				partes.append(ano + " (" + sems + ")")
		if partes.size() > 0:
			detalhes[nome_normalizado] = " | ".join(partes)
	return detalhes


## Retorna o [code]cod_curso[/code] cujo [code]prefixos_semestre[/code] bate com o inicio de
## [param semestre] (case-insensitive). Retorna string vazia quando nenhum curso casa.
func prefixo_para_curso(semestre: String) -> String:
	if semestre.is_empty():
		return ""
	var sem_upper: String = semestre.to_upper().strip_edges()
	for cod_curso in _cursos.keys():
		var prefixos: Array = _cursos[cod_curso].get("prefixos_semestre", [])
		for prefixo in prefixos:
			if sem_upper.begins_with(str(prefixo).to_upper()):
				return cod_curso
	return ""


## Retorna o [code]cod_curso[/code] que contem [param turma] em sua lista [code]turmas[/code].
## Retorna string vazia quando nenhum curso casa. A comparacao e numerica: as turmas vem do
## JSON como float (ex.: [code]20.0[/code]) e do historico como int (ex.: [code]20[/code]), logo
## [code]str()[/code] direto ("20.0" vs "20") nunca casaria.
func turma_para_curso(turma: Variant) -> String:
	var turma_int: int = int(turma)
	for cod_curso in _cursos.keys():
		var turmas: Array = _cursos[cod_curso].get("turmas", [])
		for t in turmas:
			if int(t) == turma_int:
				return cod_curso
	return ""


## Indica se [param turma] e uma turma global (oferecida a todos os cursos), definida em
## [code]base_config.json:turmas_globais[/code] (ex.: T90). Comparacao numerica via [code]int()[/code].
func turma_e_global(turma: Variant) -> bool:
	return _turmas_globais.has(int(turma))


## Conjunto de professores (nomes normalizados) que ja lecionaram ao curso [param cod_curso],
## detectados pelo codigo de turma do historico (via [method turma_para_curso]). Formato:
## [code]{ nome_normalizado: true }[/code]. Retorna dict vazio quando [param cod_curso] e vazio
## ou nao ha historico. Cacheado por curso (o historico e imutavel apos [method configurar]).
func professores_do_curso(cod_curso: String) -> Dictionary:
	if cod_curso.is_empty():
		return {}
	if _prof_curso_cache.has(cod_curso):
		return _prof_curso_cache[cod_curso]
	var resultado: Dictionary = {}
	for prof_nome in _historico_professores:
		if _prof_leciona_curso(_historico_professores[prof_nome], cod_curso):
			resultado[normalizar_nome(prof_nome)] = true
	_prof_curso_cache[cod_curso] = resultado
	return resultado


# Varre as disciplinas/anos/semestres de um professor procurando uma turma do curso.
func _prof_leciona_curso(disciplinas: Dictionary, cod_curso: String) -> bool:
	for codigo in disciplinas:
		var dados: Dictionary = disciplinas[codigo]
		for ano_str in dados:
			if not (dados[ano_str] is Dictionary):
				continue
			for sem_str in dados[ano_str]:
				var entrada_sem = dados[ano_str][sem_str]
				if not (entrada_sem is Array):
					continue
				for t in _extrair_turmas(entrada_sem):
					if turma_e_global(t) or turma_para_curso(t) == cod_curso:
						return true
	return false


## Converte um score de afinidade em estrelas (faixas fixas).
static func estrelas_afinidade(score: int) -> String:
	if score >= 46:
		return "⭐⭐⭐⭐⭐"
	elif score >= 31:
		return "⭐⭐⭐⭐"
	elif score >= 18:
		return "⭐⭐⭐"
	elif score >= 9:
		return "⭐⭐"
	elif score >= 3:
		return "⭐"
	return ""


## Normaliza nomes de professor para um formato consistente: substitui underscores por
## espacos e capitaliza cada palavra.
static func normalizar_nome(nome: String) -> String:
	if nome.is_empty():
		return nome
	var palavras: PackedStringArray = nome.replace("_", " ").split(" ")
	var resultado: PackedStringArray = []
	for p in palavras:
		if not p.is_empty():
			resultado.append(p[0].to_upper() + p.substr(1))
	return " ".join(resultado)


# Extrai as turmas de uma entrada de semestre do historico (array de horarios). Procura
# pelo elemento com chave "turma"; se ausente, retorna array vazio.
func _extrair_turmas(entrada_semestre: Array) -> Array:
	for item in entrada_semestre:
		if item is Dictionary and item.has("turma"):
			var turmas: Array = item["turma"]
			var resultado: Array[int] = []
			for t in turmas:
				resultado.append(int(t))
			return resultado
	return []
