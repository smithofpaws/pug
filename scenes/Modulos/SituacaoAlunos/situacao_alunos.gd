class_name SituacaoAlunos extends ReferenceRect
## Relacionado a ilustração da situação dos discentes em disciplinas. Especialmente interessante 
## na realização dos ajustes de matrícula. [br]
##
## Os principais empregos são: [br]
## - Apresentar as disciplinas que os discentes estão matriculados e que podem se matricular; [br]
## - Apresentar os horários que cada discente tem aula e os horários das disciplinas em que 
## podem se matricular; [br]
## - Apresentar a grade curricular indicando visualmente quais disciplinas foram cursadas e quais
## podem ser cursadas.

# Classes instanciadas.
var file_handling := FileHandling.new()
var analise_historico := AnaliseHistorico.new()
var analise_grades := AnaliseGrades.new()
var analise_horarios := AnaliseHorarios.new()
var horarios_exe := HorariosExe.new()

## Recebido pelo main em sua criação e vem do arquivo [code]base_config.json[/code].
var condicoes: Array[String]

## Recebido pelo main em sua criação e vem do arquivo [code]base_config.json[/code].
var posicoes_histcsv: Dictionary

## Recebido pelo main em sua criação e vem do arquivo [code]base_config.json[/code].
var posicoes_horarios_txt: Dictionary

## Recebido pelo main em sua criação e vem da pasta de equivalencias.
var equivalencias: Dictionary = {}

## Recebido pelo main em sua criação e vem da pasta de grades. [br]
## Formato de [param grades_disciplinas_curriculos] deve conter múltiplas grades, com chave no padrão
## [code]<cod_curso>_<versao>[/code]. Exemplo: [br]
## { [br]
## "alec_2010": Dicionário copia de [code]/arquivos/grades/alec_2010.json[/code], [br]
## "alec_2023": Dicionário copia de [code]/arquivos/grades/alec_2023.json[/code] [br]
## }
var grades_disciplinas_curriculos: Dictionary = {}

## Recebido pelo main em sua criação e vem da pasta de cargas exigidas.
var cargas_exigidas: Dictionary = {}

## Recebido pelo main em sua criação e vem do arquivo base_config.json.
var lista_cores: Dictionary = {}

## Recebido pelo main, contem as cores padrao do terminal.
var cores_terminal: Dictionary = {}

## Recebido pelo main, contem os efeitos de texto do terminal.
var efeitos: Dictionary = {}

## Recebido pelo main, diretorio onde os arquivos exportados sao salvos
## (e.g. [code]<raiz>/exportacoes[/code]). Sem barra final.
var diretorio_exportacao: String = ""

## Configuracoes globais de interface, de [code]base_config.json[/code].
var config_interface: Dictionary = {}

## Modos de exibição das células da grade (lista canônica), de [code]base_config.json:formatos_grade[/code].
var formatos_grade: Dictionary = {}

# Contém os dados do historico, de todos os alunos, que importam para esta análise.
var _historico: Dictionary

# Contém as disciplinas que todos alunos se enquadram dentro de [param condicoes].
var _condicoes_discentes: Dictionary

# Contém os dados do arquivo ini, organizados em forma de um dicionário.
var _horarios_ini: Dictionary

# Contém os dados do arquivo txt, organizados em forma de um dicionário.
var _horarios_txt: Array

# É uma array contendo em cada elemento a combinação do nome do aluno e sua matrícula.
var _lista_alunos: Array[Array]

# É uma array contendo as informações de reprovação de todas matrículas.
var _analisado_reprov: Dictionary

# Carga horária exigida para a grade do discente atualmente selecionado (já ajustada por TCC/estágio).
var _ch_exigida: Dictionary = {}

# É uma string no padrão [code]<cod_curso>_<versao>[/code] que define a grade a ser usada
# (e.g. [code]alec_2023[/code]).
var _grade_ativa: String = ""

# Vem de [method AnaliseHorarios._preparar_horarios], e remete a forma de apresentação 
# dos horários na grade de horários.
var _forma_de_apresentacao: String = "somente_codigo"

# Vem do SeletorOpcoes da GradeCurricular e define como as disciplinas são exibidas nas células.
var _forma_apresentacao_grade: String = "nome_reduzido"

# Matrícula do discente atualmente selecionado.
var _matricula_atual: String = ""

# Código da disciplina selecionada na GradeCurricular (para destacar pré-requisitos).
var _codigo_selecionado: String = ""

# Códigos das disciplinas que devem ser destacadas visualmente (pré-requisitos da selecionada).
var _codigos_destacar: Array[String] = []

# Código da disciplina selecionada com botão direito (para destacar disciplinas bloqueadas).
var _codigo_selecionado_direito: String = ""

# Códigos das disciplinas bloqueadas pela selecionada (botão direito), com cor por profundidade.
var _codigos_destacar_secundario: Dictionary = {}

# Código da disciplina realçada na GradeHorarios (toggle ao clicar na célula).
var _codigo_realcado: String = ""

## Impede que os signals de inicialização disparem [_rodar_análise] múltiplas vezes.
var _pronto := false

func _ready() -> void:
	$"%Horarios".formatos_grade = formatos_grade
	$"%Horarios".condicoes = condicoes
	# Lê o historico
	_historico = file_handling.ler_dados(GV.dir_saida, "hist.csv", posicoes_histcsv, false, grades_disciplinas_curriculos)
	# Exibe avisos de validação do cabeçalho, se houver.
	for aviso in file_handling.avisos_leitura:
		$"%Terminal".text_edit(aviso, cores_terminal["aviso"], true, true)
	# Analisa as reprovações de cada discente
	var _lista_situacoes = analise_historico.listar_situacao(_historico, ["reprovado com nota", "Reprovado por Frequência"])
	_analisado_reprov = analise_historico.processar_reprovacoes(_lista_situacoes)
	# Simplifica para conter apenas as linhas aprovadas.
	analise_historico.simplificar_historico(_historico, "situacao", ["aprovado","dispensado","matr"])
	# Lê os horários.
	_horarios_ini = horarios_exe.carregar_horarios_ini(GV.dir_saida,"horarios.ini")
	_horarios_txt = horarios_exe.carregar_horarios_txt(GV.dir_saida,"horarios.txt", posicoes_horarios_txt)
	# Prepara a lista de alunos.
	_lista_alunos = analise_historico.criar_lista_alunos(_historico)
	var alunos_itens: Array[String] = []
	var alunos_retorno: Array[String] = []
	for a in _lista_alunos.size():
		alunos_itens.append(_lista_alunos[a][1].capitalize())
		alunos_retorno.append(_lista_alunos[a][0])
	$"%SeletorListaAlunos".lista_itens = {
		"_alunos*": alunos_itens,
		"_alunos_retorno": alunos_retorno
	}
	$"%SeletorListaAlunos".atualizar_texto_padrao = true
	if _lista_alunos.size() > 0:
		_matricula_atual = _lista_alunos[0][0]
		$"%SeletorListaAlunos".selecionar_item(0)

	var largura_seletor: int = int(config_interface.get("largura_padrao_seletor", 180))
	$"%SeletorListaAlunos".custom_minimum_size = Vector2(largura_seletor, 30)

	# Verificar, para todos alunos, as disciplinas matriculadas, matriculáveis, etc (conforme [param condicoes]).
	_condicoes_discentes = analise_historico.condicoes_discentes(_lista_alunos, _historico, condicoes, \
	grades_disciplinas_curriculos, equivalencias)
	# Seleciona primeira condicao e opcao do visualizador (dispara signals).
	$"%Horarios".selecionar_condicao(0)
	$"%Horarios".selecionar_condicao(1)
	$"%Horarios".selecionar_opcao_por_valor("nome_completo")
	# Executa a análise uma única vez após toda a configuração inicial.
	_pronto = true
	_rodar_análise()
	var btn_exportar := $"Topo/HBoxContainer/Exportar"
	if not btn_exportar.pressed.is_connected(_on_exportar_button_up):
		btn_exportar.pressed.connect(_on_exportar_button_up)
	$"%GradeCurricular".celula_selecionada.connect(_on_grade_celula_selecionada)
	$"%GradeCurricular".celula_selecionada_direita.connect(_on_grade_celula_selecionada_direita)
	var grade_horarios = $"%Horarios".get_node("GradeHorarios")
	if grade_horarios:
		grade_horarios.celula_clicada.connect(_on_horarios_celula_clicada)
	# Realce inicial dos botoes OnOff conforme a visibilidade dos paineis.
	TogglePaineis.sincronizar_botoes(_mapa_toggles())


# Roda a análise para a seleção atual.
func _rodar_análise() -> void:
	_codigo_selecionado = ""
	_codigos_destacar = []
	_codigo_selecionado_direito = ""
	_codigos_destacar_secundario = {}
	_limpar_realces_horarios()
	_grade_ativa = analise_historico.detectar_versao_grade(_matricula_atual, _historico)
	if not _validar_grade_ativa():
		return
	_ch_exigida = cargas_exigidas[_grade_ativa]
	_ch_exigida = analise_grades.ajustarch_tccestagio(grades_disciplinas_curriculos[_grade_ativa], _ch_exigida)
	_analisar_matricula(_matricula_atual)

# Verifica se [_grade_ativa] e chave valida nos dicionarios de grade e carga. [br]
# Retorna true se valido; caso contrario loga erro e retorna false.
func _validar_grade_ativa() -> bool:
	if not grades_disciplinas_curriculos.has(_grade_ativa):
		print_debug("ERRO: Grade '" + _grade_ativa + "' nao encontrada em grades_disciplinas_curriculos.")
		return false
	if not cargas_exigidas.has(_grade_ativa):
		print_debug("ERRO: Grade '" + _grade_ativa + "' nao encontrada em cargas_exigidas.")
		return false
	return true

# Faz a análise da integralização e horários para uma [param matricula]. [br]
# Formato de [param matricula] deve ser apenas a sequencia numérica da matrícula em formato String. [br]
# Quando [param impressao] é verdadeiro são impressos os dados no terminal visual. [br]
# Quando [param revisao] é verdadeiro são verificados e apresentados alguns problemas na matrícula. [br]
func _analisar_matricula(matricula: String, impressao: bool = true, revisao: bool = true) -> void:
	# Determina quantas horas foram cursadas e o percentual de curso ignorando tccs e estágio.
	var ch_data: Dictionary = analise_historico.ch_vencida(matricula, \
		grades_disciplinas_curriculos[_grade_ativa], _historico)
	var ch_vencida: Dictionary = ch_data["ch"]
	var percentual_tcc: float = analise_historico.percentagem_curso(_ch_exigida, ch_vencida)
	# Exibe divergencias entre CH do historico e da grade
	if ch_data.has("divergencias"):
		for div in ch_data["divergencias"]:
			$"%Terminal".item(div["codigo"] + ": hist.csv=" + str(div["ch_historico"]) \
			+ "h, grade=" + str(div["ch_grade"]) + "h", 0, cores_terminal["aviso"])
	# Obtem a lista de disciplinas que o aluno cursou mas não estão descritas na grade curricular escolhida.
	var disc_semgrade: Array[Array]
	if revisao:
		disc_semgrade = analise_historico.revisar_historico(_historico,grades_disciplinas_curriculos, matricula, false)
	# Obtem, para a matrícula em questão, as disciplinas que se enquadrem nas [param condicoes].
	var disc_cursaveis: Dictionary = _condicoes_discentes.get(matricula, {})
	# Determina o numero de créditos matriculado nas condições "matriculado_agora" e "matriculado_agora_aproveitamento".
	var creditos_disciplinas: Dictionary
	creditos_disciplinas = analise_historico.creditos_disciplinas(matricula, _historico, disc_cursaveis, grades_disciplinas_curriculos)
	# Envia para a grade de horarios os horarios a listagem de disciplinas.
	$"%Horarios".dados = analise_horarios.determinar_horarios(_horarios_ini, _horarios_txt, disc_cursaveis, \
	_historico.get(matricula), $"%Horarios".lista_condicoes_verdadeiras, lista_cores, _forma_de_apresentacao)
	# Monta e envia a grade curricular do discente, colorindo conforme a situacao.
	var cursadas: Array[String] = analise_historico.disciplinas_concluidas(matricula, _historico)
	$"%GradeCurricular".dados = analise_grades.montar_grade_curricular(grades_disciplinas_curriculos[_grade_ativa], \
	disc_cursaveis, cursadas, lista_cores, _forma_apresentacao_grade)
	# Nova análise zera a seleção de pré-requisitos e remove as linhas de conexão.
	_codigo_selecionado = ""
	_codigo_selecionado_direito = ""
	_codigos_destacar = []
	_codigos_destacar_secundario = {}
	$"%GradeCurricular".conexoes = []
	# Imprime o resultado da análise
	if impressao:
		_imprimir_analise(matricula, disc_cursaveis, disc_semgrade, ch_vencida, \
		creditos_disciplinas, _analisado_reprov.get(matricula, {}))

# Organiza os dados da análise em seções estruturadas. Retorna um Array de Dictionary.
# Cada dicionário possui a chave "tipo" indicando o tipo de seção (versao, ch, sem_grade, condicao, etc).
# Esta é a única fonte de verdade dos dados exibidos. As funções de saída consomem este Array.
func _formatar_analise(matricula: String, disc_cursaveis: Dictionary, disc_semgrade: Array, ch_vencida: Dictionary, \
creditos_disciplinas: Dictionary, analisado_reprov: Dictionary) -> Array[Dictionary]:
	var secoes: Array[Dictionary] = []
	var sem_grade: bool = disc_semgrade.size() > 0

	# Versão do currículo
	secoes.append({"tipo": "versao", "texto": _grade_ativa, "sem_grade": sem_grade})

	# Matrícula
	secoes.append({"tipo": "matricula", "texto": matricula})

	# Carga horária vencida
	var ch_itens: Array[Array] = []
	var ch_total: int = 0
	for key in ch_vencida.keys():
		ch_itens.append([key.capitalize(), str(ch_vencida.get(key, 0))])
		ch_total += ch_vencida.get(key, 0)
	var ch_secao: Dictionary = {"tipo": "ch", "itens": ch_itens, "total": ch_total}
	# TODO Mover esta regra específica (exigência de 2550h para TCC) para [code]base_config.json:cursos[/code].
	if _grade_ativa.ends_with("_2010"):
		ch_secao["para_tcc"] = {"horas": "2550", "total_aluno": ch_total}
	secoes.append(ch_secao)

	# Disciplinas sem grade - separadas por matriculadas (situacao "matr*") e nao matriculadas
	var sem_grade_matriculadas: Array[Array] = []
	var sem_grade_nao_matriculadas: Array[Array] = []
	var dados_aluno: Array = _historico.get(matricula, {}).get("dados", [])
	for item in disc_semgrade:
		var codigo_lower: String = item[0].to_lower()
		var matriculada: bool = false
		for entry in dados_aluno:
			if entry.get("codigocurriculo", "").to_lower() == codigo_lower \
			and entry.get("situacao", "").begins_with("matr"):
				matriculada = true
				break
		if matriculada:
			sem_grade_matriculadas.append(item)
		else:
			sem_grade_nao_matriculadas.append(item)
	if sem_grade_matriculadas.size() > 0:
		secoes.append({"tipo": "sem_grade_matriculadas", "itens": sem_grade_matriculadas})
	if sem_grade_nao_matriculadas.size() > 0:
		secoes.append({"tipo": "sem_grade_nao_matriculadas", "itens": sem_grade_nao_matriculadas})

	# Aviso sobre reprovações
	secoes.append({"tipo": "aviso_reprovacoes"})

	# Disciplinas nas condições
	var limiar_presenca: float = GV.configuracao_base.get("choque", {}).get("limiar_presenca", 0.75)
	# Constroi slots das disciplinas ja matriculadas (para calculo de choque de horario)
	var codigos_matriculados: Array[String] = []
	for cond_matr in ["matriculado_agora", "matriculado_agora_aproveitamento", "matricula_irregular", "matricula_irregular_aproveitamento"]:
		if disc_cursaveis.has(cond_matr):
			for cod in disc_cursaveis[cond_matr]:
				codigos_matriculados.append(cod.to_lower())
	var slots_matriculadas: Array[Dictionary] = []
	for entry in _horarios_txt:
		var cod_entry: String = horarios_exe.extrair_cod_horarios_txt(entry.get("disciplina", "")).to_lower()
		if cod_entry in codigos_matriculados:
			slots_matriculadas.append(entry)
	var condicoes_choque: Array[String] = ["matriculavel", "matriculavel_aproveitamento", \
		"corequisito_matriculavel", "corequisito_matriculavel_aproveitamento"]
	var todas_cccgs: Dictionary = {}
	for condicao in disc_cursaveis.keys():
		if disc_cursaveis[condicao].size() > 0:
			var itens: Array[Dictionary] = []
			var lista_cccg: Array[Array] = []
			for a in disc_cursaveis[condicao].size():
				var codigo: String = disc_cursaveis[condicao][a]
				var nome_disc: String = str(analise_grades.info_grade(grades_disciplinas_curriculos, codigo, "nome"))
				var creditos: String = str(creditos_disciplinas.get(codigo, 0))
				var nucleo: String = str(analise_grades.info_grade(grades_disciplinas_curriculos, codigo, "nucleo"))
				var cod_lower: String = codigo.to_lower()
				var reprov_nota: int = analisado_reprov.get("reprovado com nota", {}).get(cod_lower, 0)
				var reprov_falta: int = analisado_reprov.get("reprovado por frequência", {}).get(cod_lower, 0)
				# Fallback: busca reprovacao nos codigos de origem por equivalencia
				if reprov_nota == 0 and reprov_falta == 0:
					var codigos_origem: Array[String] = analise_grades.codigos_origem_equivalencia(
						codigo, equivalencias, _grade_ativa
					)
					for cod_origem in codigos_origem:
						var orig_lower: String = cod_origem.to_lower()
						if reprov_nota == 0:
							reprov_nota = analisado_reprov.get("reprovado com nota", {}).get(orig_lower, 0)
						if reprov_falta == 0:
							reprov_falta = analisado_reprov.get("reprovado por frequência", {}).get(orig_lower, 0)
						if reprov_nota > 0 and reprov_falta > 0:
							break
				var reprovacoes: String = ""
				if reprov_falta != 0 or reprov_nota != 0:
					reprovacoes = "(" + str(reprov_nota) + " RN / " + str(reprov_falta) + " RF)"
				# Calcula choque de horario para disciplinas matriculaveis
				var info_choque: Dictionary = {}
				if condicao in condicoes_choque and slots_matriculadas.size() > 0:
					info_choque = analise_horarios.calcular_choque_disciplina(
						codigo, _horarios_txt, slots_matriculadas
					)
					if info_choque["slots_total"] > 0:
						var exclusivos: int = info_choque["exclusivos"]
						var total: int = info_choque["slots_total"]
						var conflito: int = info_choque["slots_conflito"]
						var necessario: int = max(0, int(ceil(limiar_presenca * total)) - exclusivos)
						info_choque["necessario"] = necessario
						# Presenca maxima possivel considerando alocacao otima dos slots
						if necessario <= conflito:
							info_choque["max_presenca"] = int(limiar_presenca * 100.0)
						else:
							info_choque["max_presenca"] = int(float(exclusivos + conflito) / float(total) * 100.0)
						# Resolve codigos conflitantes para nomes
						var nomes_conflito: Dictionary = {}
						for cod_conf in info_choque["conflitos"].keys():
							var nome = analise_grades.info_grade(grades_disciplinas_curriculos, cod_conf, "nome")
							if nome.begins_with("Codigo") or nome.is_empty():
								nome = cod_conf
							nomes_conflito[cod_conf] = nome
						info_choque["nomes_conflito"] = nomes_conflito
				if nucleo == "cccg":
					lista_cccg.append([codigo, nome_disc, creditos])
				else:
					itens.append({"codigo": codigo, "nome_disc": nome_disc, \
						"creditos": creditos, "reprovacoes": reprovacoes, "nucleo": nucleo, \
						"info_choque": info_choque})
			if lista_cccg.size() > 0:
				todas_cccgs[condicao] = lista_cccg
			secoes.append({"tipo": "condicao", "nome": condicao, "itens": itens})

	# CCCGs ao final
	for condicao in todas_cccgs.keys():
		var itens_cccg: Array[Dictionary] = []
		for a in todas_cccgs[condicao].size():
			itens_cccg.append({"codigo": todas_cccgs[condicao][a][0], \
				"nome_disc": todas_cccgs[condicao][a][1], "creditos": todas_cccgs[condicao][a][2]})
		secoes.append({"tipo": "condicao_cccg", "nome": condicao, "itens": itens_cccg})

	return secoes


# Organiza e imprime os dados no terminal.
func _imprimir_analise(matricula: String, disc_cursaveis: Dictionary, disc_semgrade: Array, ch_vencida: Dictionary, \
creditos_disciplinas: Dictionary, analisado_reprov: Dictionary) -> void:
	var secoes: Array[Dictionary] = _formatar_analise(matricula, disc_cursaveis, disc_semgrade, \
		ch_vencida, creditos_disciplinas, analisado_reprov)
	var primeiro: bool = true
	for secao in secoes:
		match secao["tipo"]:
			"versao":
				var texto: String = "Versão do currículo: " + secao["texto"]
				if secao["sem_grade"]:
					texto += " (disciplinas sem grade detectadas)"
				if primeiro:
					$"%Terminal".titulo(texto, true)
					primeiro = false
				else:
					$"%Terminal".secao(texto)
			"matricula":
				$"%Terminal".linha("Matrícula: " + secao["texto"], cores_terminal["alerta"])
				$"%Terminal".espaco()
			"ch":
				$"%Terminal".secao("Carga horária vencida")
				if secao["itens"].size() == 0:
					$"%Terminal".item("Discente não concluiu nenhuma disciplina!", 0, cores_terminal["alerta"])
				for item in secao["itens"]:
					$"%Terminal".item(item[0] + ": " + item[1])
				if secao.has("para_tcc"):
					$"%Terminal".linha("Para TCC são necessárias " + secao["para_tcc"]["horas"] + \
						" horas. O discente tem " + str(secao["para_tcc"]["total_aluno"]) + ".")
				$"%Terminal".espaco()
			"sem_grade_matriculadas":
				$"%Terminal".secao("Disciplinas sem grade (matriculadas atualmente)")
				for item in secao["itens"]:
					$"%Terminal".item(item[0] + " " + item[1], 0, cores_terminal["alerta"])
				$"%Terminal".espaco()
			"sem_grade_nao_matriculadas":
				$"%Terminal".secao("Disciplinas sem grade (nao matriculadas)")
				for item in secao["itens"]:
					$"%Terminal".item(item[0] + " " + item[1], 0, cores_terminal["alerta"])
				$"%Terminal".espaco()
			"aviso_reprovacoes":
				$"%Terminal".linha("Valores em parênteses indicam reprovações por nota e por faltas.")
				$"%Terminal".espaco()
			"condicao":
				$"%Terminal".secao(secao["nome"].replacen("_", " ").capitalize())
				for disc in secao["itens"]:
					var linha: String = disc["codigo"] + ": " + disc["nome_disc"] + " (" + \
						disc["creditos"] + " Créditos) " + disc["reprovacoes"]
					# Adiciona info de choque de horario
					if disc.has("info_choque") and not disc["info_choque"].is_empty() \
					and disc["info_choque"]["slots_conflito"] > 0:
						var necessario: int = disc["info_choque"].get("necessario", 0)
						if necessario <= 0:
							continue
						var max_pct: int = disc["info_choque"].get("max_presenca", 0)
						var nomes: Dictionary = disc["info_choque"].get("nomes_conflito", {})
						var nomes_lista: Array[String] = []
						for _cod in nomes:
							nomes_lista.append(nomes[_cod])
						var choque_str: String = " | Conflito com " \
							+ ", ".join(nomes_lista) + " (" \
							+ str(max_pct) + "% presenca maxima)"
						linha += choque_str
					$"%Terminal".item(linha, 0, lista_cores[secao["nome"]])
				$"%Terminal".espaco()
			"condicao_cccg":
				$"%Terminal".secao(secao["nome"].replacen("_", " ").capitalize() + " (CCCGs)")
				for disc in secao["itens"]:
					$"%Terminal".item(disc["codigo"] + ": " + disc["nome_disc"] + " (" + \
						disc["creditos"] + " Créditos)", 0, lista_cores[secao["nome"]])
				$"%Terminal".espaco()


# Formata os dados de um aluno em linhas markdown.
func _formatar_analise_markdown(matricula: String, nome: String, disc_cursaveis: Dictionary, disc_semgrade: Array, \
ch_vencida: Dictionary, creditos_disciplinas: Dictionary, analisado_reprov: Dictionary) -> Array[String]:
	var secoes: Array[Dictionary] = _formatar_analise(matricula, disc_cursaveis, disc_semgrade, \
		ch_vencida, creditos_disciplinas, analisado_reprov)
	var md: Array[String] = []

	md.append("## " + nome + " (Matricula: " + matricula + ")")
	md.append("")

	for secao in secoes:
		match secao["tipo"]:
			"versao":
				var extra: String = ""
				if secao["sem_grade"]:
					extra = " *(disciplinas sem grade detectadas)*"
				md.append("**Versao do curriculo:** " + secao["texto"] + extra)
			"matricula":
				pass  # Já incluída no cabeçalho
			"ch":
				md.append("### Carga horaria vencida")
				if secao["itens"].size() == 0:
					md.append("- *Discente nao concluiu nenhuma disciplina!*")
				for item in secao["itens"]:
					md.append("- " + item[0] + ": " + item[1])
				if secao.has("para_tcc"):
					md.append("*Para TCC sao necessarias " + secao["para_tcc"]["horas"] + \
						" horas. O discente tem " + str(secao["para_tcc"]["total_aluno"]) + ".*")
				md.append("**Total:** " + str(secao["total"]) + " horas")
			"sem_grade_matriculadas":
				md.append("### Disciplinas sem grade (matriculadas)")
				for item in secao["itens"]:
					md.append("- " + item[0] + " " + item[1])
			"sem_grade_nao_matriculadas":
				md.append("### Disciplinas sem grade (nao matriculadas)")
				for item in secao["itens"]:
					md.append("- " + item[0] + " " + item[1])
			"aviso_reprovacoes":
				md.append("*Valores entre parenteses indicam reprovacoes por nota e por faltas.*")
			"condicao":
				md.append("### " + secao["nome"].replacen("_", " ").capitalize())
				for disc in secao["itens"]:
					var linha_md: String = "- " + disc["codigo"] + ": " + disc["nome_disc"] + " (" + \
						disc["creditos"] + " Creditos)" + disc["reprovacoes"]
					if disc.has("info_choque") and not disc["info_choque"].is_empty() \
					and disc["info_choque"]["slots_conflito"] > 0:
						var necessario: int = disc["info_choque"].get("necessario", 0)
						if necessario <= 0:
							continue
						var max_pct: int = disc["info_choque"].get("max_presenca", 0)
						var nomes: Dictionary = disc["info_choque"].get("nomes_conflito", {})
						var nomes_lista: Array[String] = []
						for _cod in nomes:
							nomes_lista.append(nomes[_cod])
						linha_md += " | Conflito com " \
							+ ", ".join(nomes_lista) + " (" \
							+ str(max_pct) + "% presenca maxima)"
					md.append(linha_md)
			"condicao_cccg":
				md.append("### " + secao["nome"].replacen("_", " ").capitalize() + " (CCCGs)")
				for disc in secao["itens"]:
					md.append("- " + disc["codigo"] + ": " + disc["nome_disc"] + " (" + \
						disc["creditos"] + " Creditos)")
		md.append("")

	md.append("")
	return md


#region Sinais
# Mapa botao OnOff -> painel que ele controla. Base unica para alternar (Shift+clique isola/restaura)
# e para o realce: o botao fica "afundado" (toggle_mode) quando seu painel esta visivel.
func _mapa_toggles() -> Dictionary:
	return {
		$"%OnOffTerminal": $"%Terminal",
		$"%OnOffHorarios": $"%Horarios",
		$"%OnOffGrade": $"%GradeCurricular",
	}

func _toggle(alvo: Control) -> void:
	var mapa := _mapa_toggles()
	TogglePaineis.aplicar(mapa.values(), alvo, Input.is_key_pressed(KEY_SHIFT))
	TogglePaineis.sincronizar_botoes(mapa)

func _on_on_off_terminal_button_up() -> void:
	_toggle($"%Terminal")

func _on_on_off_horarios_button_up() -> void:
	_toggle($"%Horarios")

func _on_on_off_grade_button_up() -> void:
	_toggle($"%GradeCurricular")

func _on_seletor_lista_alunos_opcao_selecionada(retorno: String, _lista_selecionada: Array) -> void:
	_matricula_atual = retorno
	if _pronto:
		_rodar_análise()

func _on_horarios_listacondicoes_alterada() -> void:
	if not _pronto:
		return
	_rodar_análise()

func _on_horarios_listaopcoes_alterada(opcao: String) -> void:
	_forma_de_apresentacao = opcao
	if not _pronto:
		return
	_rodar_análise()

func _on_grade_curricular_listaopcoes_alterada(opcao: String) -> void:
	_forma_apresentacao_grade = opcao
	_rodar_análise()

func _on_grade_celula_selecionada(codigo: String) -> void:
	# Toggle: clicar novamente na mesma disciplina limpa o destaque.
	if _codigo_selecionado == codigo:
		_codigo_selecionado = ""
		_codigos_destacar = []
	else:
		_codigo_selecionado = codigo
		_codigos_destacar = analise_grades.prerequisitos_transitivos(codigo, grades_disciplinas_curriculos[_grade_ativa])
	_atualizar_grade_curricular()

## Trata clique direito: destaca transitivamente disciplinas que têm [param codigo]
## como pré-requisito (bloqueadas), com cor decrescente por profundidade.
func _on_grade_celula_selecionada_direita(codigo: String) -> void:
	if _codigo_selecionado_direito == codigo:
		_codigo_selecionado_direito = ""
		_codigos_destacar_secundario = {}
	else:
		_codigo_selecionado_direito = codigo
		_codigos_destacar_secundario = analise_grades.obter_bloqueadas_transitivas(codigo, grades_disciplinas_curriculos[_grade_ativa])
	_atualizar_grade_curricular()

## Regera apenas a grade curricular (sem reprocessar horários ou percentuais),
## aplicando os destaques de pré-requisitos conforme [_codigos_destacar].
func _atualizar_grade_curricular() -> void:
	var cursadas: Array[String] = analise_historico.disciplinas_concluidas(_matricula_atual, _historico)
	var disc_cursaveis: Dictionary = _condicoes_discentes.get(_matricula_atual, {})
	var grade_ativa: Dictionary = grades_disciplinas_curriculos[_grade_ativa]
	$"%GradeCurricular".dados = analise_grades.montar_grade_curricular(
		grade_ativa,
		disc_cursaveis,
		cursadas,
		lista_cores,
		_forma_apresentacao_grade,
		_codigos_destacar,
		_codigos_destacar_secundario
	)
	# Monta as linhas de conexão em dominó: cadeia de pré-requisitos (esquerdo) e de dependentes
	# (direito). Sem seleção, a lista fica vazia e nenhuma linha é desenhada.
	var conexoes: Array = []
	if _codigo_selecionado != "":
		conexoes.append_array(analise_grades.conexoes_prerequisitos(_codigo_selecionado, grade_ativa))
	if _codigo_selecionado_direito != "":
		conexoes.append_array(analise_grades.conexoes_bloqueios(_codigo_selecionado_direito, grade_ativa))
	$"%GradeCurricular".conexoes = conexoes

# Limpa os realces de horarios e reseta [_codigo_realcado].
func _limpar_realces_horarios() -> void:
	_codigo_realcado = ""
	var grade_horarios = $"%Horarios".get_node("GradeHorarios")
	if not grade_horarios:
		return
	var dias: Array = GV.configuracao_base.get("dias_semana", [])
	var horas: Array = GV.configuracao_base.get("horarios_aula", [])
	for lin in horas.size() + 1:
		for col in dias.size() + 1:
			var cel: Celula = grade_horarios.get_celula(lin, col)
			if cel:
				cel.cor_fundo = Color(0.173, 0.173, 0.173, 1)

## Realca na GradeHorarios todas as celulas do codigo informado (toggle).
func _realcar_por_codigo(codigo: String) -> void:
	if _codigo_realcado == codigo:
		_limpar_realces_horarios()
		return
	_limpar_realces_horarios()
	_codigo_realcado = codigo
	var cod_lower: String = codigo.to_lower()
	var grade_horarios = $"%Horarios".get_node("GradeHorarios")
	if not grade_horarios:
		return
	var dias: Array = GV.configuracao_base.get("dias_semana", [])
	var horas: Array = GV.configuracao_base.get("horarios_aula", [])
	for lin in horas.size() + 1:
		for col in dias.size() + 1:
			var cel: Celula = grade_horarios.get_celula(lin, col)
			if not cel:
				continue
			var txt: String = cel.texto_central
			txt = txt.replace("[/color]", "")
			while txt.contains("[color="):
				var ini: int = txt.find("[color=")
				var fim: int = txt.find("]", ini)
				if fim >= 0:
					txt = txt.erase(ini, fim - ini + 1)
				else:
					break
			# Verifica se algum codigo na celula corresponde ao alvo
			var partes_txt: PackedStringArray = txt.split(",")
			var encontrou: bool = false
			for parte_txt in partes_txt:
				if horarios_exe.extrair_cod_horarios_txt(parte_txt.strip_edges()).to_lower() == cod_lower:
					encontrou = true
					break
			if encontrou:
				cel.cor_fundo = Color(0.3, 0.6, 0.3, 0.3)

## Abre um AcceptDialog com botoes para cada disciplina na celula.
func _mostrar_selecao_disciplinas(partes: PackedStringArray, codigos: Array[String]) -> void:
	var dialogo := AcceptDialog.new()
	dialogo.title = "Selecione a disciplina"
	dialogo.ok_button_text = "Cancelar"
	dialogo.min_size = Vector2(400, 0)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in codigos.size():
		var nome: String = horarios_exe.extrair_nome_horarios_txt(partes[i]).strip_edges()
		var btn := Button.new()
		btn.text = nome + " (" + codigos[i].to_upper() + ")"
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_realcar_por_codigo.bind(codigos[i]))
		btn.pressed.connect(dialogo.queue_free)
		vbox.add_child(btn)
	dialogo.add_child(vbox)
	add_child(dialogo)
	dialogo.popup_centered()

## Realca na GradeHorarios todas as celulas da disciplina clicada (toggle).
## Se a celula tiver multiplas disciplinas, abre popup de selecao.
func _on_horarios_celula_clicada(linha: int, coluna: int) -> void:
	var grade_horarios = $"%Horarios".get_node("GradeHorarios")
	if not grade_horarios:
		return
	var celula: Celula = grade_horarios.get_celula(linha, coluna)
	if not celula or celula.texto_central.is_empty():
		_limpar_realces_horarios()
		return
	# Extrai todos os codigos da celula (separados por virgula no texto BBCode)
	var texto_limpo: String = celula.texto_central
	texto_limpo = texto_limpo.replace("[/color]", "")
	while texto_limpo.contains("[color="):
		var ini: int = texto_limpo.find("[color=")
		var fim_col: int = texto_limpo.find("]", ini)
		if fim_col >= 0:
			texto_limpo = texto_limpo.erase(ini, fim_col - ini + 1)
		else:
			break
	var codigos: Array[String] = []
	var partes: PackedStringArray = texto_limpo.split(",")
	for parte in partes:
		var parte_limpa: String = parte.strip_edges()
		var cod: String = horarios_exe.extrair_cod_horarios_txt(parte_limpa)
		if not cod.is_empty():
			codigos.append(cod.to_lower())
	if codigos.is_empty():
		_limpar_realces_horarios()
		return
	if codigos.size() == 1:
		_realcar_por_codigo(codigos[0])
	else:
		_mostrar_selecao_disciplinas(partes, codigos)

## Abre um diálogo de confirmação antes de exportar a situação de todos os alunos.
func _on_exportar_button_up() -> void:
	Dialogos.confirmar(self, "Exportar Situação dos Alunos", \
		"Deseja exportar a situação de todos os alunos (%d) para um arquivo?" % _lista_alunos.size(), \
		_exportar, "Exportar")

func _exportar() -> void:
	var time: Dictionary = Time.get_date_dict_from_system()
	var time_hora: Dictionary = Time.get_time_dict_from_system()
	var data_hora: String = "%02d/%02d/%04d %02d:%02d" % [time["day"], time["month"], time["year"], time_hora["hour"], time_hora["minute"]]
	var data_arquivo: String = str(time["year"]) + "_" + "%02d" % time["month"] + "_" + "%02d" % time["day"]
	var linhas: Array[String] = []

	# Cabeçalho do documento
	linhas.append("# Situacao dos Alunos")
	linhas.append("")
	linhas.append("**Exportado em:** " + data_hora)
	linhas.append("**Total de alunos:** " + str(_lista_alunos.size()))
	linhas.append("")

	for aluno in _lista_alunos:
		var matricula: String = aluno[0]
		var nome: String = aluno[1].capitalize()

		# Detecta grade e CH exigida para o aluno
		_grade_ativa = analise_historico.detectar_versao_grade(matricula, _historico)
		if not _validar_grade_ativa():
			continue
		_ch_exigida = cargas_exigidas[_grade_ativa]
		_ch_exigida = analise_grades.ajustarch_tccestagio(grades_disciplinas_curriculos[_grade_ativa], _ch_exigida)

		# Computa os dados
		var ch_data: Dictionary = analise_historico.ch_vencida(matricula, \
			grades_disciplinas_curriculos[_grade_ativa], _historico)
		var ch_vencida: Dictionary = ch_data["ch"]
		var disc_semgrade: Array[Array] = analise_historico.revisar_historico(_historico, \
			grades_disciplinas_curriculos, matricula, false)
		var disc_cursaveis: Dictionary = _condicoes_discentes.get(matricula, {})
		var creditos_disciplinas: Dictionary = analise_historico.creditos_disciplinas(matricula, \
			_historico, disc_cursaveis, grades_disciplinas_curriculos)
		var analisado_reprov: Dictionary = _analisado_reprov.get(matricula, {})

		# Formata o aluno em markdown
		linhas.append("---")
		linhas.append("")
		linhas.append_array(_formatar_analise_markdown(matricula, nome, disc_cursaveis, disc_semgrade, \
			ch_vencida, creditos_disciplinas, analisado_reprov))

	# Salva o arquivo
	var nome_arquivo: String = "situacao_alunos_" + data_arquivo + ".md"
	file_handling.check_create_dir(diretorio_exportacao)
	file_handling.save_text_file(diretorio_exportacao, nome_arquivo, linhas)
	$"%Terminal".text_edit("Arquivo exportado: " + diretorio_exportacao + nome_arquivo, \
		cores_terminal["sucesso"], true, true)

#endregion
