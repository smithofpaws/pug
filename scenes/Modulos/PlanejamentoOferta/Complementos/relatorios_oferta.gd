class_name RelatoriosOferta extends RefCounted
## Gera os relatorios das "Acoes" do Planejamento de Oferta, escrevendo no terminal. [br]
## E puro de saida: recebe os dados (alocacoes, carga, demanda) por parametro e nao muta
## o estado do modulo nem a status bar — essa coordenacao fica a cargo do modulo. [br]
## Os colaboradores estaveis (terminal, motor de afinidade, analise de historico, grades,
## condicoes e config) sao injetados uma unica vez por [method configurar].

# Colaboradores e dados estaveis, injetados via [method configurar].
var _terminal: Node
var _afinidade: AnaliseAfinidade
var _analise_historico: AnaliseHistorico
var _grades: Dictionary = {}
var _condicoes: Array[String] = []
var _config_oferta: Dictionary = {}
var _cursos: Dictionary = {}
var _equivalencias: Dictionary = {}
var _analise_grades_ref: AnaliseGrades

# Limite maximo de alunos exibidos no tooltip por disciplina.
const MAX_ALUNOS_TOOLTIP = 15


## Injeta os colaboradores estaveis usados por todos os relatorios.
func configurar(terminal: Node, afinidade: AnaliseAfinidade, analise_historico: AnaliseHistorico, \
		grades: Dictionary, condicoes: Array[String], config_oferta: Dictionary, cursos: Dictionary = {}, \
		equivalencias: Dictionary = {}) -> void:
	_terminal = terminal
	_afinidade = afinidade
	_analise_historico = analise_historico
	_grades = grades
	_condicoes = condicoes
	_config_oferta = config_oferta
	_cursos = cursos
	_equivalencias = equivalencias
	_analise_grades_ref = AnaliseGrades.new()


# Escreve uma linha no terminal com o token de cor informado.
func _log(texto: String, token: String = "padrao", nl: bool = true, limpar: bool = false) -> void:
	_terminal.text_edit(texto, token, nl, limpar)


## Lista, por grade, a demanda de cada disciplina conforme as condicoes de matricula dos
## discentes. [param condicoes_discentes] deve ter sido carregado previamente pelo modulo.
## [param cod_curso] filtra apenas grades do curso selecionado; [param filtro_semestre]
## filta apenas o semestre especifico (formato prefixado, ex.: "EC04").
func determinar_demanda(condicoes_discentes: Dictionary, cod_curso: String = "", filtro_semestre: Array = [], edicao_semestre: String = "", codigos_na_oferta: Array[String] = [], historico_discentes: Dictionary = {}) -> void:
	_terminal.titulo("Determinacao de demanda", true)
	if not cod_curso.is_empty():
		_terminal.linha("Filtro curso: %s" % _cursos.get(cod_curso, {}).get("nome", cod_curso), "aviso")
	if filtro_semestre.size() > 0:
		var sem_str: String = filtro_semestre[0]
		_terminal.linha("Filtro semestre: %s" % sem_str, "aviso")

	var grades_ordenadas: Array = _grades.keys()
	grades_ordenadas.sort()
	grades_ordenadas.reverse()
	for grade_nome in grades_ordenadas:
		if not cod_curso.is_empty():
			var grades_do_curso: Array = _cursos.get(cod_curso, {}).get("grades", [])
			if not grade_nome in grades_do_curso:
				continue
		var grade: Dictionary = _grades[grade_nome]
		var linhas: Array = []
		for codigo in grade:
			var sem: String = str(grade[codigo].get("semestre", ""))
			if sem.is_empty():
				continue
			if not codigos_na_oferta.is_empty() and codigos_na_oferta.has(codigo.to_lower()):
				continue
			if filtro_semestre.size() > 0 and _semestre_prefixed(grade_nome, sem) != filtro_semestre[0]:
				continue
			var badge: String = _calcular_badge(grade_nome, sem, edicao_semestre)
			var tipo: int = _tipo_disciplina(sem, edicao_semestre)
			var nome_exibicao: String = "%s - %s" % [str(codigo).to_upper(), str(grade[codigo].get("nome", codigo))]
			if not badge.is_empty():
				nome_exibicao += " (%s)" % badge
			var disc_cond: Dictionary = _analise_historico.discentes_disciplina(codigo, condicoes_discentes, _condicoes)
			var contagens: Dictionary = {}
			var total_matriculaveis: int = 0
			for cond in _condicoes:
				contagens[cond] = (disc_cond.get(cond, []) as Array).size()
				if cond.contains("matriculavel"):
					total_matriculaveis += contagens[cond]
			linhas.append({
				"codigo": codigo,
				"nome": nome_exibicao,
				"matriculaveis": total_matriculaveis,
				"contagens": contagens,
				"tipo": tipo,
			})
		linhas.sort_custom(func(x, y):
			if x["tipo"] != y["tipo"]:
				return x["tipo"] < y["tipo"]
			return x["matriculaveis"] > y["matriculaveis"] if x["matriculaveis"] != y["matriculaveis"] \
				else x["codigo"] < y["codigo"])
		_terminal.espaco()
		_terminal.secao("Grade %s" % grade_nome)
		for linha in linhas:
			var nome_exibicao: String = linha["nome"]
			var alunos_bbcode: String = _lista_alunos_bbcode(linha["codigo"], condicoes_discentes, historico_discentes)
			if not alunos_bbcode.is_empty():
				var meta_chave: String = "demanda_%s" % linha["codigo"]
				_terminal.registrar_meta(meta_chave, "[b]%s[/b]%s" % [linha["nome"], alunos_bbcode])
				nome_exibicao = "[url=%s]%s[/url]" % [meta_chave, linha["nome"]]
			_terminal.item(nome_exibicao)
			var algum: bool = false
			for cond in _condicoes:
				var n: int = linha["contagens"][cond]
				if n <= 0:
					continue
				# Sub-linha de contagens (item aninhado), montada com cores por condicao.
				if not algum:
					_log("  - ", "padrao", true, false)
				else:
					_log(" | ", "padrao", false, false)
				_log("%s: %d" % [cond.replacen("_", " ").capitalize(), n], cond, false, false)
				algum = true
			if not algum:
				_terminal.item("sem demanda", 1)


# Constroi o fragmento BBCode com a lista de alunos demandantes de uma disciplina.
# Retorna "" se nao houver alunos ou [param historico_discentes] estiver vazio.
func _lista_alunos_bbcode(codigo: String, condicoes_discentes: Dictionary, historico_discentes: Dictionary) -> String:
	if historico_discentes.is_empty():
		return ""
	var disc_cond: Dictionary = _analise_historico.discentes_disciplina(codigo, condicoes_discentes, _condicoes)
	var alunos_info: Dictionary = {}
	for cond in _condicoes:
		if cond in ["matriculado_agora", "matriculado_agora_aproveitamento", \
				"matricula_irregular", "matricula_irregular_aproveitamento"]:
			continue
		for mat in (disc_cond.get(cond, []) as Array):
			if not alunos_info.has(mat):
				alunos_info[mat] = cond
	if alunos_info.is_empty():
		return ""
	var linhas_alunos: Array[String] = []
	var total: int = alunos_info.size()
	for mat in alunos_info.keys():
		if linhas_alunos.size() >= MAX_ALUNOS_TOOLTIP:
			break
		if not historico_discentes.has(mat):
			continue
		var cond_aluno: String = alunos_info[mat]
		var cor_aluno: String = PaletaSemantica.cor_hex(cond_aluno)
		var nome_aluno: String = str(historico_discentes[mat].get("nomedoaluno", "")).capitalize()
		var ppc: String = _analise_historico.detectar_versao_grade(mat, historico_discentes, _cursos)
		var rotulo: String = "[color=%s]%s[/color]" % [cor_aluno, nome_aluno]
		if not ppc.is_empty():
			var partes: PackedStringArray = ppc.split("_")
			var grade: Dictionary = _grades.get(ppc, {})
			var eh_complementar: bool = grade.has(codigo) and str(grade[codigo].get("semestre", "")) == "0"
			rotulo += " (PPC " + (partes[-1] if partes.size() > 1 else ppc)
			if eh_complementar:
				var curso_cod: String = partes[0] if partes.size() > 1 else ""
				var sigla_cg: String = "CG"
				if not curso_cod.is_empty() and _cursos.has(curso_cod):
					var prefixos: Array = _cursos[curso_cod].get("prefixos_semestre", [])
					if prefixos.size() > 0:
						sigla_cg = str(prefixos[0]).to_upper() + "CG"
				rotulo += " - " + sigla_cg
			rotulo += ")"
		linhas_alunos.append(rotulo)
	if total > MAX_ALUNOS_TOOLTIP:
		linhas_alunos.append("[color=#888888]... e mais %d aluno(s)[/color]" % [total - MAX_ALUNOS_TOOLTIP])
	return "\n[b]Alunos:[/b]\n" + "\n".join(linhas_alunos)


# Retorna o cod_curso ao qual uma grade pertence, varrendo _cursos.
func _curso_da_grade(grade_nome: String) -> String:
	for cod in _cursos:
		for g in _cursos[cod].get("grades", []):
			if str(g) == grade_nome:
				return cod
	return ""


func _calcular_badge(grade_nome: String, sem: String, edicao_semestre: String) -> String:
	var cod_curso: String = _curso_da_grade(grade_nome)
	if cod_curso.is_empty():
		return ""
	var prefixos: Array = _cursos.get(cod_curso, {}).get("prefixos_semestre", [])
	if prefixos.is_empty():
		return ""
	var prefixo: String = str(prefixos[0]).to_upper()
	if sem == "0":
		return "%sCG" % prefixo
	var sem_int: int = int(sem)
	if sem_int > 0:
		var edicao_int: int = int(edicao_semestre)
		if edicao_int > 0 and (sem_int % 2) != (edicao_int % 2):
			return "%sExtra" % prefixo
		return "%s%02d" % [prefixo, sem_int]
	return ""


func _tipo_disciplina(sem: String, edicao_semestre: String) -> int:
	if sem == "0":
		return 2
	var sem_int: int = int(sem)
	var edicao_int: int = int(edicao_semestre)
	if sem_int > 0 and edicao_int > 0 and (sem_int % 2) != (edicao_int % 2):
		return 1
	return 0


# Converte o semestre numerico de uma grade (ex.: "1") para o formato prefixado
# usado nos filtros (ex.: "EC01"), para permitir comparacao com filtro_semestre.
func _semestre_prefixed(grade_nome: String, sem: String) -> String:
	var cod_curso: String = _curso_da_grade(grade_nome)
	if cod_curso.is_empty():
		return sem
	var prefixos: Array = _cursos.get(cod_curso, {}).get("prefixos_semestre", [])
	if prefixos.is_empty():
		return sem
	var prefixo: String = str(prefixos[0]).to_upper()
	var sem_int: int = int(sem)
	if sem_int > 0:
		return "%s%02d" % [prefixo, sem_int]
	if sem == "0":
		return "%sCG" % prefixo
	return prefixo


## Lista a carga horaria alocada por professor (recebida em [param carga_por_prof]) e seu
## status frente aos limites min/ideal/max de [code]base_config.json[/code]. [br]
## Quando [param cod_curso] nao e vazio, considera apenas professores que ja lecionaram ao curso
## (via [method AnaliseAfinidade.professores_do_curso]).
func verificar_carga_horaria(carga_por_prof: Dictionary, cod_curso: String = "") -> void:
	var ch_min: int = int(_config_oferta.get("ch_minimo", 8))
	var ch_ideal: int = int(_config_oferta.get("ch_ideal", 12))
	var ch_max: int = int(_config_oferta.get("ch_maximo", 20))
	_terminal.titulo("Verificacao de carga horaria", true)
	if not cod_curso.is_empty():
		_terminal.linha("Filtro curso: %s" % _cursos.get(cod_curso, {}).get("nome", cod_curso), "aviso")
	if carga_por_prof.is_empty():
		_terminal.linha("Nenhum professor alocado.")
		return
	var nomes: Array = carga_por_prof.keys()
	if not cod_curso.is_empty():
		var do_curso: Dictionary = _afinidade.professores_do_curso(cod_curso)
		nomes = nomes.filter(func(n): return do_curso.has(n))
		if nomes.is_empty():
			_terminal.linha("Nenhum professor alocado que tenha lecionado para o curso.")
			return
	nomes.sort_custom(func(a, b): return carga_por_prof[a] > carga_por_prof[b])
	for nome in nomes:
		var ch: int = int(carga_por_prof[nome])
		var status: String
		var cor: String = "sucesso"
		if ch > ch_max:
			status = "ACIMA DO MAXIMO (%d cr)" % ch_max
			cor = "erro"
		elif ch > ch_ideal:
			status = "acima do ideal (%d cr)" % ch_ideal
			cor = "aviso"
		elif ch < ch_min:
			status = "abaixo do minimo (%d cr)" % ch_min
			cor = "aviso"
		else:
			status = "OK"
		_terminal.item("%s: %d cr — %s" % [nome.capitalize(), ch, status], 0, cor)
	_terminal.espaco()
	_terminal.linha("Minimo: %d cr | Ideal: ate %d cr | Maximo absoluto: %d cr" % [ch_min, ch_ideal, ch_max])


## Aponta alocacoes cujo professor tem afinidade baixa (score < 9) com a disciplina. [br]
## Quando [param cod_curso] nao e vazio, considera apenas professores que ja lecionaram ao curso
## (via [method AnaliseAfinidade.professores_do_curso]).
func verificar_erro_afinidade(alocacoes: Dictionary, cod_curso: String = "") -> void:
	_terminal.titulo("Verificacao de erros de afinidade", true)
	if not cod_curso.is_empty():
		_terminal.linha("Filtro curso: %s" % _cursos.get(cod_curso, {}).get("nome", cod_curso), "aviso")
	if alocacoes.is_empty():
		_terminal.linha("Nenhuma disciplina no planejamento.", "erro")
		return
	if _afinidade.index_vazio():
		_terminal.linha("Indice de afinidade vazio. Verifique se historico_professores.json foi carregado.", "aviso")
		return

	var profs_curso: Dictionary = _afinidade.professores_do_curso(cod_curso)
	var erros: Array = []
	for chave in alocacoes:
		var dados: Dictionary = alocacoes[chave]
		var codigo: String = dados.get("codigo", "")
		var semestre: String = dados.get("semestre", "")
		var nome_disc: String = dados.get("nome", codigo)
		var profs: Dictionary = dados.get("professores", {})
		if profs.is_empty():
			continue
		var afinidade: Array[Dictionary] = _afinidade.obter_afinidade(codigo, semestre)
		var score_por_prof: Dictionary = {}
		for entry in afinidade:
			score_por_prof[entry["nome"]] = entry["score"]
		for prof_nome in profs:
			if not cod_curso.is_empty() and not profs_curso.has(prof_nome):
				continue
			var score: int = score_por_prof.get(prof_nome, 0)
			if score < 9:
				erros.append({
					"prof": prof_nome,
					"codigo": codigo,
					"nome_disc": nome_disc,
					"score": score,
					"ch": profs[prof_nome],
				})

	if erros.is_empty():
		_terminal.linha("Nenhum erro de afinidade encontrado.", "sucesso")
		return

	erros.sort_custom(func(a, b): return a["score"] < b["score"])

	for err in erros:
		var nome: String = err["prof"]
		var cod: String = err["codigo"]
		var nome_disc: String = err["nome_disc"]
		var score: int = err["score"]
		var estrelas: String = AnaliseAfinidade.estrelas_afinidade(score)
		_terminal.item("%s — %s — %s  (%d pts) %s" % [nome.capitalize(), cod.to_upper(), nome_disc, score, estrelas])

	_terminal.espaco()
	_terminal.linha("Total de alocacoes com afinidade baixa: %d" % erros.size())


## Sugere disciplinas para professores abaixo do minimo de carga, ordenadas por afinidade.
## Quando [param tem_demanda] e true, anexa as contagens de demanda.
## Quando [param cod_curso] nao e vazio, filtra apenas disciplinas das grades do curso.
func sugerir_oferta(alocacoes: Dictionary, todos_professores: Array[String], carga_por_prof: Dictionary, \
		condicoes_discentes: Dictionary, tem_demanda: bool, cod_curso: String = "", historico_discentes: Dictionary = {}, \
		profs_oficiais_curso: Dictionary = {}) -> void:
	var ch_min: int = int(_config_oferta.get("ch_minimo", 8))
	_terminal.titulo("Sugestao de oferta", true)
	if not cod_curso.is_empty():
		_terminal.linha("Filtro curso: %s" % _cursos.get(cod_curso, {}).get("nome", cod_curso), "aviso")
	if alocacoes.is_empty():
		_terminal.linha("Nenhuma disciplina no planejamento. Importe um planejamento.csv primeiro.", "erro")
		return
	if _afinidade.index_vazio():
		_terminal.linha("Indice de afinidade vazio. Verifique se historico_professores.json foi carregado.", "aviso")
		return

	# Cache de contagens de demanda por codigo.
	var cache_demanda: Dictionary = {}

	# Conjunto de codigos das grades do curso filtrado, para restringir as sugestoes.
	var codigos_do_curso: Dictionary = {}
	if not cod_curso.is_empty():
		var grades_do_curso: Array = _cursos.get(cod_curso, {}).get("grades", [])
		for grade_nome in grades_do_curso:
			var grade: Dictionary = _grades.get(grade_nome, {})
			for cod in grade:
				codigos_do_curso[cod] = true

	# Indice reverso de afinidade: {nome_professor → [{codigo, score}]}.
	var afinidade_por_prof: Dictionary = _afinidade.afinidade_por_prof()

	# Conjunto de codigos no planejamento e mapa codigo → {prof: true}
	# (para checagem O(1) de "ja alocado").
	var codigos_planejamento: Dictionary = {}
	var info_disciplina: Dictionary = {}
	var alocado_por_codigo: Dictionary = {}
	for chave in alocacoes:
		var cod: String = alocacoes[chave].get("codigo", "")
		codigos_planejamento[cod] = true
		if not info_disciplina.has(cod):
			info_disciplina[cod] = {
				"nome": alocacoes[chave].get("nome", cod),
				"semestre": alocacoes[chave].get("semestre", ""),
			}
		if not alocado_por_codigo.has(cod):
			alocado_por_codigo[cod] = {}
		for pnome in alocacoes[chave].get("professores", {}):
			alocado_por_codigo[cod][pnome] = true
	# Complementa informacoes de disciplinas nao-planejadas com dados das grades.
	for grade_nome in _grades:
		var grade: Dictionary = _grades[grade_nome]
		for codigo in grade:
			if not info_disciplina.has(codigo):
				var disc: Dictionary = grade[codigo]
				info_disciplina[codigo] = {
					"nome": disc.get("nome", codigo.to_upper()),
					"semestre": disc.get("semestre", ""),
				}

	# Base de pertencimento ao curso filtrado. Preferencia: lista oficial do curso
	# (profs_oficiais_curso, de lista_professores.json) — assim professores do curso que
	# nao estao no plano importado ainda sao sugeridos como "nao alocados". Fallback para o
	# historico de turmas (professores_do_curso) quando a lista oficial nao cobre o curso.
	var profs_curso: Dictionary = profs_oficiais_curso
	if profs_curso.is_empty():
		profs_curso = _afinidade.professores_do_curso(cod_curso)

	# Universo de candidatos: professores do plano importado unidos aos da lista oficial do
	# curso (estes entram com carga 0 = "nao alocado"). Sem isto, quem nao esta no plano some.
	var universo: Dictionary = {}
	for nome in todos_professores:
		universo[nome] = true
	for nome in profs_oficiais_curso:
		universo[nome] = true

	# Professores abaixo do minimo (incluindo nao alocados).
	var profs_abaixo: Array = []
	for nome in universo:
		if not cod_curso.is_empty() and not profs_curso.has(nome):
			continue
		var ch: int = int(carga_por_prof.get(nome, 0))
		if ch < ch_min:
			profs_abaixo.append({"nome": nome, "ch": ch})
	profs_abaixo.sort_custom(func(a, b): return a["ch"] < b["ch"])
	if profs_abaixo.is_empty():
		_terminal.linha("Todos os professores estao com carga >= %d cr." % ch_min, "sucesso")
		return

	# Cache de detalhes do historico (anos/semestres) por codigo de disciplina, para
	# evitar escanear todo o historico a cada sugestao.
	var cache_detalhes: Dictionary = {}

	var total_mostradas: int = 0
	for item in profs_abaixo:
		var nome: String = item["nome"]
		var ch: int = int(item["ch"])
		_terminal.espaco()
		if ch > 0:
			_terminal.secao("%s — %d cr" % [nome.capitalize(), ch])
		else:
			_terminal.secao("%s — nao alocado" % nome.capitalize())
		var afinidades: Array = afinidade_por_prof.get(nome, [])
		var mostradas: int = 0
		for aff in afinidades:
			if mostradas >= 10:
				break
			var codigo: String = aff["codigo"]
			var score: int = aff["score"]
			if not cod_curso.is_empty() and not codigos_do_curso.has(codigo):
				continue
			var info: Dictionary = info_disciplina.get(codigo, {"nome": codigo.to_upper(), "semestre": ""})
			var nome_disc: String = str(info.get("nome", codigo.to_upper()))

			# Tooltip com anos/semestres e alunos demandantes.
			if not cache_detalhes.has(codigo):
				cache_detalhes[codigo] = _afinidade.detalhes_historico(codigo)
			var texto_tooltip: String = (cache_detalhes[codigo] as Dictionary).get(nome, "")
			var meta_chave: String = "sugerir_%s_%s" % [codigo, nome]
			var texto_bbcode: String = "[b]%s[/b]" % nome.capitalize()
			if not texto_tooltip.is_empty():
				texto_bbcode += "\n" + texto_tooltip

			# Alunos matriculaveis na disciplina, com nome, PPC e tipo.
			if tem_demanda and not historico_discentes.is_empty():
				texto_bbcode += _lista_alunos_bbcode(codigo, condicoes_discentes, historico_discentes)

			if texto_bbcode != "[b]%s[/b]" % nome.capitalize():
				_terminal.registrar_meta(meta_chave, texto_bbcode)
				nome_disc = "[url=%s]%s[/url]" % [meta_chave, nome_disc]

			# Ja alocado e indicado pela cor (token sucesso), sem simbolo decorativo.
			var ja_alocado: bool = (alocado_por_codigo.get(codigo, {}) as Dictionary).has(nome)
			var estrelas: String = AnaliseAfinidade.estrelas_afinidade(score)
			var token_inicio: String = "sucesso" if ja_alocado else "padrao"
			# Item de lista markdown; comeca com "- " para sobreviver ao copiar.
			var linha_inicio: String = "- " + codigo.to_upper() + " — " + nome_disc

			if tem_demanda:
				# Obtem contagens de demanda (cacheada por codigo).
				var contagens: Dictionary = cache_demanda.get(codigo, {})
				if contagens.is_empty():
					var disc_cond: Dictionary = _analise_historico.discentes_disciplina(codigo, condicoes_discentes, _condicoes)
					for cond in _condicoes:
						if cond == "matriculado_agora" or cond == "matriculado_agora_aproveitamento" or cond == "matricula_irregular" or cond == "matricula_irregular_aproveitamento":
							continue
						var n: int = (disc_cond.get(cond, []) as Array).size()
						if n > 0:
							contagens[cond] = n
					cache_demanda[codigo] = contagens

				if not contagens.is_empty():
					_log(linha_inicio + " (", token_inicio, true)
					var primeiro: bool = true
					for cond in _condicoes:
						var n: int = contagens.get(cond, 0)
						if n <= 0:
							continue
						if primeiro:
							_log(str(n), cond, false)
							primeiro = false
						else:
							_log("+", "padrao", false)
							_log(str(n), cond, false)
					_log(" alunos) " + estrelas, "padrao", false)
				else:
					_log(linha_inicio + "  " + estrelas, token_inicio, true)
			else:
				_log(linha_inicio + "  " + estrelas, token_inicio, true)

			mostradas += 1
			total_mostradas += 1
		if mostradas == 0:
			_terminal.item("sem disciplinas com afinidade.")
	_terminal.espaco()
	_terminal.linha("Minimo de carga horaria: %d cr" % ch_min)
	_terminal.linha("Exibidas ate 10 sugestoes por professor (%d sugestoes no total)." % total_mostradas)


## Detecta dois tipos de problemas na oferta planejada: [br]
## 1. Disciplinas obrigatorias de grades do curso selecionado que nao constam nos cards
##    (considerando equivalencias). [br]
## 2. Disciplinas ofertadas cujo semestre do card difere do semestre na grade curricular.
func detectar_problema_oferta(cards_disciplinas: Dictionary, filtro_curso: String, edicao_semestre: String) -> void:
	_terminal.titulo("Deteccao de problemas na oferta", true)
	if cards_disciplinas.is_empty():
		_terminal.linha("Nenhuma disciplina na oferta.", "erro")
		return
	if filtro_curso.is_empty():
		_terminal.linha("Selecione um curso no filtro para verificar.", "erro")
		return
	_terminal.linha("Curso: %s" % _cursos.get(filtro_curso, {}).get("nome", filtro_curso), "aviso")

	var grades_do_curso: Array = _cursos.get(filtro_curso, {}).get("grades", [])
	if grades_do_curso.is_empty():
		_terminal.linha("Nenhuma grade cadastrada para o curso %s." % filtro_curso, "erro")
		return

	var codigos_oferta: Array[String] = []
	for chave in cards_disciplinas:
		codigos_oferta.append(cards_disciplinas[chave].codigo.to_lower())

	var edicao_int: int = int(edicao_semestre)

	# --- Check 1: Disciplinas obrigatorias ausentes ---
	var ausentes: Array = []
	var equivalencias_consideradas: Array = []
	for grade_nome in grades_do_curso:
		var grade: Dictionary = _grades.get(grade_nome, {})
		if grade.is_empty():
			continue
		for codigo in grade:
			var disc: Dictionary = grade[codigo]
			var sem_grade: String = str(disc.get("semestre", ""))
			if sem_grade == "0" or sem_grade.is_empty():
				continue
			var sem_grade_int: int = int(sem_grade)
			if edicao_int > 0 and (sem_grade_int % 2) != (edicao_int % 2):
				continue
			if codigos_oferta.has(codigo.to_lower()):
				continue
			var coberto: bool = false
			if _equivalencias.size() > 0:
				var origens: Array[String] = _analise_grades_ref.codigos_origem_equivalencia(
					str(codigo), _equivalencias, grade_nome)
				for origem in origens:
					if codigos_oferta.has(origem.to_lower()):
						coberto = true
						equivalencias_consideradas.append({
							"codigo_equivalente": origem,
							"codigo_alvo": codigo,
							"grade_alvo": grade_nome,
							"nome_equivalente": _nome_disciplina(origem),
							"nome_alvo": str(disc.get("nome", codigo)),
						})
						break
			if not coberto:
				ausentes.append({
					"codigo": codigo,
					"nome": str(disc.get("nome", codigo)),
					"grade": grade_nome,
					"semestre_grade": sem_grade,
				})

	_terminal.espaco()
	_terminal.secao("Disciplinas obrigatorias ausentes")
	if ausentes.is_empty():
		_terminal.item("Nenhuma.", 0, "sucesso")
	else:
		ausentes.sort_custom(func(a, b):
			var ga: String = a["grade"]
			var gb: String = b["grade"]
			if ga != gb:
				return ga < gb
			return int(a["semestre_grade"]) < int(b["semestre_grade"]))
		var grade_atual: String = ""
		for item in ausentes:
			if item["grade"] != grade_atual:
				grade_atual = item["grade"]
				_terminal.subsecao(grade_atual)
			_terminal.item("%s - %s (semestre %s)" % [
				str(item["codigo"]).to_upper(), item["nome"],
				item["semestre_grade"]])
		_terminal.espaco()
		_terminal.linha("Total de ausentes: %d" % ausentes.size(), "aviso")

	# --- Check 2: Semestre incorreto ---
	var semestre_errado: Array = []
	for grade_nome in grades_do_curso:
		var grade: Dictionary = _grades.get(grade_nome, {})
		if grade.is_empty():
			continue
		for chave in cards_disciplinas:
			var card: CardDisciplina = cards_disciplinas[chave]
			var codigo_card: String = card.codigo.to_lower()
			if not grade.has(codigo_card):
				continue
			var disc: Dictionary = grade[codigo_card]
			var sem_grade: String = str(disc.get("semestre", ""))
			if sem_grade == "0" or sem_grade.is_empty():
				continue
			var sem_esperado: String = _semestre_prefixed(grade_nome, sem_grade)
			if card.semestre.to_lower() != sem_esperado.to_lower():
				semestre_errado.append({
					"codigo": codigo_card,
					"nome": str(disc.get("nome", codigo_card)),
					"grade": grade_nome,
					"sem_atual": card.semestre,
					"sem_esperado": sem_esperado,
				})

	_terminal.espaco()
	_terminal.secao("Semestre incorreto na oferta")
	if semestre_errado.is_empty():
		_terminal.item("Nenhum.", 0, "sucesso")
	else:
		var grade_atual: String = ""
		for item in semestre_errado:
			if item["grade"] != grade_atual:
				grade_atual = item["grade"]
				_terminal.subsecao(grade_atual)
			_terminal.item("%s - %s: ofertado %s, esperado %s" % [
				str(item["codigo"]).to_upper(), item["nome"],
				item["sem_atual"], item["sem_esperado"]])
		_terminal.espaco()
		_terminal.linha("Total com semestre incorreto: %d" % semestre_errado.size(), "aviso")

	# --- Equivalencias consideradas ---
	if equivalencias_consideradas.size() > 0:
		_terminal.espaco()
		_terminal.secao("Equivalencias consideradas")
		for item in equivalencias_consideradas:
			_terminal.item("%s (%s) cobre %s - %s (grade %s)" % [
				str(item["codigo_equivalente"]).to_upper(), item["nome_equivalente"],
				str(item["codigo_alvo"]).to_upper(), item["nome_alvo"],
				item["grade_alvo"]])


func _nome_disciplina(codigo: String) -> String:
	for grade_nome in _grades:
		var grade: Dictionary = _grades[grade_nome]
		if grade.has(codigo):
			return str(grade[codigo].get("nome", codigo))
	return str(codigo).to_upper()
