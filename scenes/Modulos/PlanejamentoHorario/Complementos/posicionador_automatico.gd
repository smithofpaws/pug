class_name PosicionadorAutomatico extends RefCounted
## Posiciona automaticamente as disciplinas pendentes na grade de horários. [br]
##
## Núcleo puro (sem UI): recebe o estado atual via [method configurar] e devolve um plano de
## alocações via [method gerar_plano], sem tocar na grade nem nos cards. Quem aplica o plano é o
## módulo [PlanejamentoHorario] (espelhando o par [code]preparar_alocacoes_do_txt[/code] →
## [code]_popular_grade_do_txt[/code]). [br]
##
## Estratégia: guloso com pontuação e restrições duras. Para cada disciplina incompleta, gera
## candidatos de posicionamento (blocos de aula em dias distintos, no mesmo horário — regra 6),
## pontua cada um e fixa o de menor custo. As regras pedidas mapeiam para: [br]
## - R1 (paridade manhã/tarde): período-alvo por paridade do semestre + peso [code]fora_periodo[/code]; [br]
## - R2 (preferências): slots sem preferência são proibidos; os demais custam o valor 1..5 numa
##   escala não-linear ([code]pow(v-1, preferencia_expoente) * preferencia[/code]), em que o verde
##   (1) custa 0 e o vermelho (5) é fortemente penalizado; [br]
## - R3 (mesmo semestre): restrição dura ao gerar candidatos; [br]
## - R4 (menor choque): pesos de choque de professor e de alunos no custo; [br]
## - R5 (2+2): créditos→aulas com arredondamento de ímpar ≥3, em blocos de [code]tamanho_bloco[/code]; [br]
## - R6 (mesmo horário em dias diferentes): candidatos primários compartilham a linha-início.

# Dimensões e cabeçalhos da grade (linhas/colunas incluem a faixa de cabeçalho no índice 0).
var _linhas: int = 0
var _colunas: int = 0
var _horas: Array[String] = []
var _dias: Array[String] = []

# Estado injetado.
var _cards: Dictionary = {}
var _alocacoes: Dictionary = {}
var _planejamento_csv: Dictionary = {}
# nome_professor (minúsculo) → { "linha_coluna": int(1..5) }. Professor ausente = sem restrição.
var _preferencias: Dictionary = {}
var _config: Dictionary = {}
# Callable(cod_a, cod_b) -> int (nº de alunos em comum). Inválido = choque de alunos desconsiderado.
var _peso_alunos_fn: Callable = Callable()

# Config derivada em _preparar_config().
var _inicio_manha: bool = true               # true = semestre de rank 0 (EC01/EC02) começa de manhã
var _permitir_sabado: bool = false           # true = sábado liberado (somente de manhã)
var _choque_professor_rigido: bool = true    # true = choque de professor é proibição (não peso)
var _tamanho_bloco: int = 2
var _pesos: Dictionary = {}
var _linhas_emergencia: Dictionary = {}      # linha(int) → true
var _periodo_linhas: Dictionary = {}         # "manha"/"tarde"/"noite" → Array[int] de linhas
var _linhas_validas: Dictionary = {}         # linha(int) → true (em algum período ou emergência)
var _linhas_manha: Dictionary = {}           # linha(int) → true (período da manhã)
var _coluna_sabado: int = -1                 # coluna do sábado em _dias (-1 = ausente)
# "linha_coluna" → true. Slots liberados pelo usuário na grade de Configurações. Quando não-vazio,
# restringe (interseção) os slots viáveis às células marcadas. Vazio = sem restrição extra.
var _slots_liberados: Dictionary = {}

# Estado interno mutável durante a geração.
var _ocup: Dictionary = {}                   # "linha_coluna" → Array de { codigo, semestre, profs }
var _cache_alunos: Dictionary = {}           # "cod_a|cod_b" (ordenado) → int
var _paridade_oferta: int = 1                # 1 = oferta ímpar, 2 = oferta par (maioria das pendentes)

## Configura as referências e dados necessários. [br]
## [param dims] = [linhas, colunas] totais da grade (com cabeçalho). [param peso_alunos_fn] é um
## [Callable] que recebe dois códigos e devolve quantos discentes cursariam ambas (0 quando não há
## dados); o cache de pares é interno.
func configurar(dims: Array, horas: Array[String], dias: Array[String], cards_disciplinas: Dictionary, \
		alocacoes: Dictionary, planejamento_csv: Dictionary, preferencias: Dictionary, \
		config: Dictionary, peso_alunos_fn: Callable) -> void:
	_linhas = int(dims[0])
	_colunas = int(dims[1])
	_horas = horas
	_dias = dias
	_cards = cards_disciplinas
	_alocacoes = alocacoes
	_planejamento_csv = planejamento_csv
	_preferencias = preferencias
	_config = config
	_peso_alunos_fn = peso_alunos_fn

## Gera o plano de alocações sem alterar grade/cards/alocações. Retorna [br]
## [code]{ "alocacoes": Array, "nao_alocadas": Array[String], "custo": float }[/code], onde cada
## item de [param alocacoes] é [code]{ chave, codigo, linha, coluna, aloc }[/code].
func gerar_plano() -> Dictionary:
	_preparar_config()
	_inicializar_ocupacao()
	_cache_alunos.clear()
	_paridade_oferta = _calcular_paridade_oferta()
	var pendentes: Array = _coletar_pendentes()
	var plano_alocacoes: Array = []
	var nao_alocadas: Array[String] = []
	var custo_total: float = 0.0
	for chave in pendentes:
		var card: CardDisciplina = _cards[chave]
		var codigo: String = card.codigo
		var profs: Array = _profs_de(chave)
		var semestre: String = _semestre_de(chave)
		var periodo_alvo: String = _periodo_de_semestre(_num_semestre(semestre))
		var slots_proibidos: Dictionary = _slots_proibidos(profs)
		var aulas: int = _aulas_faltantes(card)
		if aulas <= 0:
			continue
		var blocos_tam: Array[int] = _dividir_blocos(aulas)
		var resultado: Dictionary = {}
		if _tamanhos_uniformes(blocos_tam):
			resultado = _candidato_primario(codigo, profs, semestre, periodo_alvo, slots_proibidos, blocos_tam.size(), blocos_tam[0])
		if resultado.is_empty():
			resultado = _candidato_fallback(codigo, profs, semestre, periodo_alvo, slots_proibidos, blocos_tam)
		var blocos: Array = resultado.get("blocos", [])
		if blocos.is_empty():
			nao_alocadas.append("%s (%s): nenhum horário viável." % [codigo.to_upper(), semestre.to_upper()])
			continue
		var aplicados: int = 0
		for i in blocos.size():
			var linha_inicio: int = int(blocos[i][0])
			var dia: int = int(blocos[i][1])
			var t: int = blocos_tam[i] if i < blocos_tam.size() else _tamanho_bloco
			for off in t:
				var linha: int = linha_inicio + off
				_ocup_adicionar("%d_%d" % [linha, dia], codigo, semestre, profs)
				plano_alocacoes.append({
					"chave": chave,
					"codigo": codigo,
					"linha": linha,
					"coluna": dia,
					"aloc": _montar_aloc(chave, codigo, semestre),
				})
				aplicados += 1
		custo_total += float(resultado.get("custo", 0.0))
		if aplicados < aulas:
			nao_alocadas.append("%s (%s): %d de %d aulas alocadas." % [codigo.to_upper(), semestre.to_upper(), aplicados, aulas])
	return {"alocacoes": plano_alocacoes, "nao_alocadas": nao_alocadas, "custo": custo_total}

#region Preparação
# Extrai a configuração crua (períodos, pesos, turno inicial, sábado, emergência) para estruturas
# eficientes. As linhas válidas (em algum período ou emergência) delimitam onde se pode alocar:
# horários fora delas (ex.: 12:30) ficam proibidos.
func _preparar_config() -> void:
	_inicio_manha = bool(_config.get("inicio_manha", true))
	_permitir_sabado = bool(_config.get("permitir_sabado", false))
	_choque_professor_rigido = bool(_config.get("choque_professor_rigido", true))
	_tamanho_bloco = maxi(1, int(_config.get("tamanho_bloco", 2)))
	_pesos = _config.get("pesos", {})
	_periodo_linhas = {}
	_linhas_validas = {}
	var periodos: Dictionary = _config.get("periodos", {})
	for nome in periodos:
		var faixa: Array = periodos[nome]
		if faixa.size() < 2:
			continue
		var linha_ini: int = _horas.find(str(faixa[0])) + 1
		var linha_fim: int = _horas.find(str(faixa[1])) + 1
		if linha_ini <= 0 or linha_fim <= 0:
			continue
		var lista: Array[int] = []
		for l in range(linha_ini, linha_fim + 1):
			lista.append(l)
			_linhas_validas[l] = true
		_periodo_linhas[nome] = lista
	_linhas_manha = {}
	for l in _periodo_linhas.get("manha", []):
		_linhas_manha[l] = true
	_linhas_emergencia = {}
	for h in _config.get("horarios_emergencia", []):
		var idx: int = _horas.find(str(h))
		if idx >= 0:
			_linhas_emergencia[idx + 1] = true
			_linhas_validas[idx + 1] = true
	_coluna_sabado = -1
	for i in _dias.size():
		var d: String = _dias[i].to_lower()
		if d == "sábado" or d == "sabado":
			_coluna_sabado = i + 1
			break
	# Slots liberados pelo usuário (matriz booleana horas × dias). Índice i/j (0-based) vira a
	# linha/coluna i+1/j+1 da grade (linha/coluna 0 são cabeçalhos).
	_slots_liberados = {}
	var liberados: Array = _config.get("horarios_liberados", [])
	for i in liberados.size():
		var linha_arr = liberados[i]
		if not linha_arr is Array:
			continue
		for j in linha_arr.size():
			if bool(linha_arr[j]):
				_slots_liberados["%d_%d" % [i + 1, j + 1]] = true

# Copia as alocações já existentes para a tabela de ocupação (preservadas como restrição).
func _inicializar_ocupacao() -> void:
	_ocup = {}
	for chave_celula in _alocacoes:
		for aloc in _alocacoes[chave_celula]:
			var chave: String = aloc.get("chave", "")
			# Prefere o semestre que a própria alocação carrega: para disciplinas compartilhadas
			# (chave combinada "al0400_ec02;em02"), _semestre_de não resolve e retornaria "", o que
			# faria a R3 ser pulada. Só recai em _semestre_de quando a alocação não traz o rótulo.
			var sem: String = str(aloc.get("semestre", ""))
			if sem.is_empty():
				sem = _semestre_de(chave)
			_ocup_adicionar(chave_celula, aloc.get("codigo", ""), sem, _profs_de(chave))

# Infere a paridade da oferta (1 = ímpar, 2 = par) pela maioria das pendentes com número de
# semestre. Disciplinas da paridade oposta serão tratadas como Extra (sem período-alvo). Empate → ímpar.
func _calcular_paridade_oferta() -> int:
	var impares: int = 0
	var pares: int = 0
	for chave in _cards:
		var card: CardDisciplina = _cards[chave]
		if card.ch_total <= 0 or card.ch_alocada >= card.ch_total:
			continue
		var n: int = _num_semestre(_semestre_de(chave))
		if n <= 0:
			continue
		if n % 2 == 1:
			impares += 1
		else:
			pares += 1
	return 2 if pares > impares else 1

# Disciplinas com carga ainda incompleta, ordenadas das mais restritas para as menos.
func _coletar_pendentes() -> Array:
	var grupos: Dictionary = {}
	for chave in _cards:
		var card: CardDisciplina = _cards[chave]
		if card.ch_total <= 0:
			continue
		var cod: String = card.codigo.to_lower()
		if not grupos.has(cod):
			grupos[cod] = {"chaves": [], "max_alocada": -1, "melhor": ""}
		grupos[cod]["chaves"].append(chave)
		if card.ch_alocada > grupos[cod]["max_alocada"]:
			grupos[cod]["max_alocada"] = card.ch_alocada
			grupos[cod]["melhor"] = chave
	var lista: Array = []
	for cod in grupos:
		var g: Dictionary = grupos[cod]
		var melhor_card: CardDisciplina = _cards[g["melhor"]]
		if melhor_card.ch_alocada >= melhor_card.ch_total:
			continue
		lista.append(g["melhor"])
	lista.sort_custom(_comparar_restricao)
	return lista

# Mais restrito primeiro: menos slots livres no período-alvo; desempate por mais créditos.
func _comparar_restricao(chave_a: String, chave_b: String) -> bool:
	var ra: int = _grau_restricao(chave_a)
	var rb: int = _grau_restricao(chave_b)
	if ra != rb:
		return ra < rb
	return _cards[chave_a].ch_total > _cards[chave_b].ch_total

# Quantidade de slots permitidos (não proibidos pelas preferências) no período-alvo da disciplina.
func _grau_restricao(chave: String) -> int:
	var profs: Array = _profs_de(chave)
	var proibidos: Dictionary = _slots_proibidos(profs)
	var periodo: String = _periodo_de_semestre(_num_semestre(_semestre_de(chave)))
	var linhas_alvo: Array = _periodo_linhas.get(periodo, []) if not periodo.is_empty() else _todas_linhas_uteis()
	var livres: int = 0
	for linha in linhas_alvo:
		for dia in range(1, _colunas):
			if not proibidos.has("%d_%d" % [linha, dia]):
				livres += 1
	return livres
#endregion

#region Geração de candidatos
# Candidato primário (regra 6): todos os blocos na mesma linha-início, em N dias distintos.
# Retorna { custo, blocos: [[linha, dia], ...] } ou {} se não houver L com N dias viáveis.
func _candidato_primario(codigo: String, profs: Array, semestre: String, periodo_alvo: String, \
		slots_proibidos: Dictionary, n_blocos: int, t: int) -> Dictionary:
	var melhor: Dictionary = {}
	for linha_inicio in range(1, _linhas - t + 1):
		var dias_viaveis: Array = []
		for dia in range(1, _colunas):
			if not _bloco_viavel(linha_inicio, dia, semestre, profs, slots_proibidos, t):
				continue
			dias_viaveis.append([_custo_bloco(codigo, profs, linha_inicio, dia, periodo_alvo, t), dia])
		if dias_viaveis.size() < n_blocos:
			continue
		dias_viaveis.sort_custom(func(x, y): return x[0] < y[0])
		var custo_total: float = 0.0
		var blocos: Array = []
		for k in n_blocos:
			custo_total += float(dias_viaveis[k][0])
			blocos.append([linha_inicio, dias_viaveis[k][1]])
		custo_total -= float(_pesos.get("bonus_mesmo_horario", 0.0))
		if melhor.is_empty() or custo_total < float(melhor["custo"]):
			melhor = {"custo": custo_total, "blocos": blocos}
	return melhor

# Fallback: escolhe cada bloco independentemente (em dias distintos), sem exigir o mesmo horário.
# Usado quando o primário não é viável ou os blocos têm tamanhos diferentes. Pode devolver blocos
# parciais (campo [param blocos] menor que [param blocos_tam]) quando algum bloco não couber.
func _candidato_fallback(codigo: String, profs: Array, semestre: String, periodo_alvo: String, \
		slots_proibidos: Dictionary, blocos_tam: Array[int]) -> Dictionary:
	var blocos: Array = []
	var dias_usados: Dictionary = {}
	var custo_total: float = 0.0
	for t in blocos_tam:
		var melhor_local: Dictionary = {}
		for linha_inicio in range(1, _linhas - t + 1):
			for dia in range(1, _colunas):
				if dias_usados.has(dia):
					continue
				if not _bloco_viavel(linha_inicio, dia, semestre, profs, slots_proibidos, t):
					continue
				var c: float = _custo_bloco(codigo, profs, linha_inicio, dia, periodo_alvo, t)
				if melhor_local.is_empty() or c < float(melhor_local["custo"]):
					melhor_local = {"custo": c, "linha": linha_inicio, "dia": dia}
		if melhor_local.is_empty():
			break
		dias_usados[int(melhor_local["dia"])] = true
		blocos.append([int(melhor_local["linha"]), int(melhor_local["dia"])])
		custo_total += float(melhor_local["custo"])
	return {"custo": custo_total, "blocos": blocos}

# Restrições duras de um bloco (dia [param dia], linhas [linha_inicio, +t)): cabe na grade; toda
# linha está num período válido (proíbe 12:30 e horários fora dos períodos); respeita o sábado
# (proibido, ou só de manhã); nenhum slot proibido por preferência (R2); nenhum slot ocupado por
# disciplina do mesmo semestre (R3); e, com [member _choque_professor_rigido], nenhum slot onde um
# professor da disciplina já dá aula (proibição em vez de peso).
func _bloco_viavel(linha_inicio: int, dia: int, semestre: String, profs: Array, slots_proibidos: Dictionary, t: int) -> bool:
	if linha_inicio < 1 or linha_inicio + t > _linhas:
		return false
	if dia == _coluna_sabado and not _permitir_sabado:
		return false
	var sem_lower: String = semestre.to_lower()
	var num_sem_novo: int = _num_semestre(semestre)
	for off in t:
		var linha: int = linha_inicio + off
		if not _linhas_validas.has(linha):
			return false
		# Interseção com a liberação do usuário: se há grade configurada, só vale o que está marcado.
		if not _slots_liberados.is_empty() and not _slots_liberados.has("%d_%d" % [linha, dia]):
			return false
		if dia == _coluna_sabado and not _linhas_manha.has(linha):
			return false
		var k: String = "%d_%d" % [linha, dia]
		if slots_proibidos.has(k):
			return false
		for ocup in _ocup.get(k, []):
			if num_sem_novo > 0:
				var ocup_sem: String = str(ocup.get("semestre", ""))
				if not ocup_sem.is_empty() and _num_semestre(ocup_sem) == num_sem_novo:
					return false
			if _choque_professor_rigido:
				for prof in profs:
					if _prof_em(prof, ocup.get("profs", [])):
						return false
	return true

# Custo de um bloco (menor = melhor): preferências dos professores + emergência (07:30) +
# choque de professor + choque de alunos com os ocupantes + penalidade por estar fora do período.
func _custo_bloco(codigo: String, profs: Array, linha_inicio: int, dia: int, periodo_alvo: String, t: int) -> float:
	var custo: float = 0.0
	var peso_pref: float = float(_pesos.get("preferencia", 1.0))
	var pref_exp: float = float(_pesos.get("preferencia_expoente", 2.0))
	var peso_emerg: float = float(_pesos.get("emergencia", 20.0))
	var peso_cprof: float = float(_pesos.get("choque_professor", 50.0))
	var peso_caluno: float = float(_pesos.get("choque_aluno", 2.0))
	var cod_lower: String = codigo.to_lower()
	for off in t:
		var linha: int = linha_inicio + off
		var k: String = "%d_%d" % [linha, dia]
		for prof in profs:
			var pl: String = str(prof).to_lower()
			if _preferencias.has(pl):
				# Escala não-linear: o valor 1 (verde/preferido) custa 0 e o 5 (vermelho/evitado)
				# custa muito mais que a faixa linear, para que a preferência domine critérios
				# secundários (fora_periodo, bônus de mesmo horário). pow((v-1), exp): 1→0, 2→1,
				# 3→4, 4→9, 5→16 com exp=2.
				var v: int = int(_preferencias[pl].get(k, 0))
				if v >= 1:
					custo += pow(float(v - 1), pref_exp) * peso_pref
		if _linhas_emergencia.has(linha):
			custo += peso_emerg
		for ocup in _ocup.get(k, []):
			# Quando rígido, o choque de professor já é barrado em _bloco_viavel (não vira custo).
			if not _choque_professor_rigido:
				for prof in profs:
					if _prof_em(prof, ocup.get("profs", [])):
						custo += peso_cprof
						break
			var cod_ocup: String = str(ocup.get("codigo", "")).to_lower()
			if not cod_ocup.is_empty() and cod_ocup != cod_lower:
				custo += peso_caluno * float(_peso_alunos_par(cod_lower, cod_ocup))
	if not periodo_alvo.is_empty() and not _bloco_no_periodo(linha_inicio, periodo_alvo, t):
		custo += float(_pesos.get("fora_periodo", 8.0))
	return custo
#endregion

#region Auxiliares
# Período-alvo (manhã/tarde) por alternância progressiva dos semestres da oferta: o turno alterna
# conforme [code]rank = (num_sem - 1) / 2[/code] (EC01→0, EC03→1, EC05→2, …), e [member _inicio_manha]
# define o turno do rank 0 (EC01/EC02). Retorna "" (sem alvo, posicionado só por menor choque) para:
# sem número de semestre (complementares); e disciplinas da paridade oposta à oferta (Extra).
func _periodo_de_semestre(num_sem: int) -> String:
	if num_sem <= 0:
		return ""
	if (num_sem % 2) != (_paridade_oferta % 2):
		return ""
	var rank: int = (num_sem - 1) / 2
	var turno_inicial: bool = (rank % 2) == 0  # rank par segue o turno escolhido; ímpar inverte
	if not _inicio_manha:
		turno_inicial = not turno_inicial
	return "manha" if turno_inicial else "tarde"

# Verdadeiro se todas as linhas do bloco pertencem ao período informado.
func _bloco_no_periodo(linha_inicio: int, periodo: String, t: int) -> bool:
	var linhas_p: Array = _periodo_linhas.get(periodo, [])
	for off in t:
		if not (linha_inicio + off) in linhas_p:
			return false
	return true

# Conjunto de slots proibidos pela união dos professores que possuem arquivo de preferências:
# um slot é proibido quando algum desses professores não o marcou (= "não darei aula").
func _slots_proibidos(profs: Array) -> Dictionary:
	var proibidos: Dictionary = {}
	for prof in profs:
		var pl: String = str(prof).to_lower()
		if not _preferencias.has(pl):
			continue
		var pref: Dictionary = _preferencias[pl]
		for linha in range(1, _linhas):
			for dia in range(1, _colunas):
				var k: String = "%d_%d" % [linha, dia]
				if not pref.has(k):
					proibidos[k] = true
	return proibidos

# Número de aulas (slots) a alocar: créditos do card arredondados (ímpar ≥3 → par seguinte),
# descontando o que já estiver alocado. Disciplinas de 45h/60h (3/4 créditos) resultam em 4 aulas.
func _aulas_faltantes(card: CardDisciplina) -> int:
	var aulas: int = card.ch_total
	if aulas >= 3 and (aulas % 2) == 1:
		aulas += 1
	return maxi(aulas - card.ch_alocada, 0)

# Divide [param aulas] em blocos de [member _tamanho_bloco]; o último pode ser menor (ex.: 1 aula).
func _dividir_blocos(aulas: int) -> Array[int]:
	var blocos: Array[int] = []
	var restante: int = aulas
	while restante >= _tamanho_bloco:
		blocos.append(_tamanho_bloco)
		restante -= _tamanho_bloco
	if restante > 0:
		blocos.append(restante)
	return blocos

# Verdadeiro quando todos os blocos têm o mesmo tamanho (condição da estratégia primária).
func _tamanhos_uniformes(blocos_tam: Array[int]) -> bool:
	for t in blocos_tam:
		if t != blocos_tam[0]:
			return false
	return not blocos_tam.is_empty()

# Linhas válidas (em algum período ou emergência), usadas como alvo quando não há período definido
# (disciplinas Extra/complementares). Exclui horários proibidos como o 12:30.
func _todas_linhas_uteis() -> Array:
	return _linhas_validas.keys()

# Peso de choque de alunos entre dois códigos (nº de discentes em comum), com cache de pares.
func _peso_alunos_par(cod_a: String, cod_b: String) -> int:
	if cod_a == cod_b or not _peso_alunos_fn.is_valid():
		return 0
	var k: String = (cod_a + "|" + cod_b) if cod_a < cod_b else (cod_b + "|" + cod_a)
	if _cache_alunos.has(k):
		return _cache_alunos[k]
	var v: int = int(_peso_alunos_fn.call(cod_a, cod_b))
	_cache_alunos[k] = v
	return v

# Verdadeiro se [param prof] consta (sem diferenciar caixa) na [param lista] de professores.
func _prof_em(prof: String, lista: Array) -> bool:
	var pl: String = prof.to_lower()
	for p in lista:
		if str(p).to_lower() == pl:
			return true
	return false

# Adiciona um ocupante (codigo/semestre/profs) à tabela de ocupação do slot.
func _ocup_adicionar(chave_slot: String, codigo: String, semestre: String, profs: Array) -> void:
	if not _ocup.has(chave_slot):
		_ocup[chave_slot] = []
	_ocup[chave_slot].append({"codigo": codigo, "semestre": semestre, "profs": profs})

# Semestre da disciplina, do planejamento.csv com fallback para o card.
func _semestre_de(chave: String) -> String:
	var sem: String = _planejamento_csv.get(chave, {}).get("semestre", "")
	if sem.is_empty():
		var card: CardDisciplina = _cards.get(chave)
		if card:
			sem = card.semestre
	return sem

# Professores da disciplina, do planejamento.csv com fallback para o card.
func _profs_de(chave: String) -> Array:
	var profs: Array = _planejamento_csv.get(chave, {}).get("professor", [])
	if profs.is_empty():
		var card: CardDisciplina = _cards.get(chave)
		if card:
			return card.professores
	return profs

# Extrai o número do semestre dos dígitos do rótulo (ex.: "EC01" → 1, "CC02" → 2; sem dígito → 0).
# Rótulos de disciplinas compartilhadas ("EC02;EM02", "EC04/EE04") têm o mesmo número nos dois lados:
# consideramos só o primeiro curso, evitando concatenar dígitos dos dois (que daria 202 em "EC02;EM02").
func _num_semestre(sem: String) -> int:
	var token: String = sem
	for sep in [";", "/", "-", ","]:
		var idx: int = token.find(sep)
		if idx >= 0:
			token = token.substr(0, idx)
	var num: int = 0
	for c in token:
		if c.is_valid_int():
			num = num * 10 + int(c)
	return num

# Monta o dicionário de alocação no mesmo formato do drop manual (ver _on_grade_drop_realizado).
func _montar_aloc(chave: String, codigo: String, semestre: String) -> Dictionary:
	return {
		"chave": chave,
		"codigo": codigo,
		"semestre": semestre,
		"sala": "Sem Sala",
		"tipo": "Teorica",
		"turma": "T20",
		"vagas": "Vagas",
		"p": "1",
		"s": "1",
		"t": "1",
	}
#endregion
