extends ReferenceRect

var file_handling := FileHandling.new()
var general_functions := GeneralFunctions.new()

# ~historico contem os dados do historico, de todos os alunos, que importam para esta análise
var historico: Dictionary
var emails: Dictionary

# ~posicoes_histcsv, ~posicoes_mailfile e ~diretorio_surveys são recebidos pelo main em sua criação e vem do arquivo base_config.json
var posicoes_histcsv: Dictionary
var posicoes_mailfile: Dictionary
var diretorio_surveys: String

## Configuracoes globais de interface, de [code]base_config.json[/code].
var config_interface: Dictionary = {}

func _ready() -> void:
	# Lê e simplifica o historico para conter apenas as linhas aprovadas
	historico = file_handling.ler_dados(GV.dir_saida, "hist.csv", posicoes_histcsv, true)
	emails = file_handling.ler_dados(GV.dir_saida, "email.csv", posicoes_mailfile, true)
	# Define algumas configurações do administrador
	var time: Dictionary = Time.get_date_dict_from_system()
	var semestre: String = GeneralFunctions.semestre_atual()
	var mes = general_functions.int_string_fill(time["month"], 2)
	var dia = general_functions.int_string_fill(time["day"], 2)
	$"%LEDataInicio".set_text(str(time["year"])+"-"+mes+"-"+dia+" 00:00:00")
	$"%LEDataExpiracao".set_text($"%LEDataInicio".get_text())
	$"%LESemestre".set_text(str(time["year"])+"/"+semestre)
	# Realce inicial dos botoes OnOff conforme a visibilidade dos paineis.
	TogglePaineis.sincronizar_botoes(_mapa_toggles())


func _lista_disciplinas(historico: Dictionary) -> Array:
	# Retorna a lista de combinacoes disciplina-professor, sem duplicatas.
	# Uma classe eh identificada por (codigocurriculo, codturma, semestre).
	var codigos_disciplinas: Array[Dictionary] = []
	# ~lambda_prof eh usada para obter a lista de professores em disciplinas
	# A entrada pode vir como um professor (e.g "NOME DO PROFESSOR")
	#  ou mais (e.g "NOME DO PRIMEIRO PROF / NOME DO SEGUNDO PROF")
	var lambda_prof = func(prof_nomes: String):
		var professores: Array[String] = []
		if prof_nomes.contains("/"):
			professores = general_functions.split(prof_nomes, "/")
			for i in professores.size():
				professores[i] = professores[i].strip_edges()
		else:
			professores.append(prof_nomes)
		return professores

	for matr in historico.keys():
		for a in historico[matr]["dados"].size():
			if not historico[matr]["dados"][a]["situacao"].begins_with("matr"):
				continue
			var dados: Dictionary = historico[matr]["dados"][a]
			var lista_professores: Array[String] = lambda_prof.call(dados.get("professor"))
			var lista_novos_profs: Array[String] = []

			# Verifica se a classe (codigo+turma+semestre) ja esta na lista
			var newclass: bool = true
			for b in codigos_disciplinas:
				if dados["codigocurriculo"] == b["codigocurriculo"] \
				and dados["codturma"] == b["codturma"] \
				and dados["semestre"] == b["semestre"]:
					newclass = false
					break

			if newclass:
				lista_novos_profs = lista_professores
			else:
				for prof in lista_professores:
					var prof_existe: bool = false
					for b in codigos_disciplinas:
						if dados["codigocurriculo"] == b["codigocurriculo"] \
						and dados["codturma"] == b["codturma"] \
						and dados["semestre"] == b["semestre"] \
						and prof == b["professor"]:
							prof_existe = true
							break
					if not prof_existe:
						lista_novos_profs.append(prof)

			for prof in lista_novos_profs:
				codigos_disciplinas.append({
					"codigocurriculo": dados["codigocurriculo"],
					"professor": prof,
					"nomeativcurricular": dados["nomeativcurricular"],
					"semestre": dados["semestre"],
					"codturma": dados["codturma"]
				})
	return codigos_disciplinas

func _lss_out(caminho_arquivoentrada: String, caminho_saida: String, disciplina: String, professor: String) -> void:
	# Lê o arquivo .lss base, injeta os dados e salva um novo .lss
	var lss_output := FileAccess.open(caminho_saida + "survey.lss", FileAccess.WRITE)
	var f := FileAccess.open(caminho_arquivoentrada, FileAccess.READ)
	if lss_output == null or f == null:
		return
	while not f.eof_reached():
		var line = f.get_line()
		
		if "<admin><![CDATA[administrator]]></admin>" in line:
			line = line.replace("administrator", $"%LEAdministrador".get_text())
		if "<expires><![CDATA[AAAA-MM-DD HH:MM:SS]]></expires>" in line:
			line = line.replace("AAAA-MM-DD HH:MM:SS", $"%LEDataExpiracao".get_text())
		if "<startdate><![CDATA[AAAA-MM-DD HH:MM:SS]]></startdate>" in line:
			line = line.replace("AAAA-MM-DD HH:MM:SS", $"%LEDataInicio".get_text())
		if "<adminemail><![CDATA[administrator@unipampa.edu.br]]></adminemail>" in line:
			line = line.replace("administrator@unipampa.edu.br", $"%LEEmailAdmin".get_text())
		if "<bounce_email><![CDATA[administrator@unipampa.edu.br]]></bounce_email>" in line:
			line = line.replace("administrator@unipampa.edu.br", $"%LEEmailBounce".get_text())
		if "[[XXXX/X]]" in line:
			line = line.replace("[[XXXX/X]]", $"%LESemestre".get_text())
		if "[[CLASSNAME]]" in line:
			line = line.replace("[[CLASSNAME]]", disciplina+" ("+professor+")")
		
		lss_output.store_string(line + "\n")

func _lst_out(caminho_arquivoentrada: String, caminho_saida: String, user_data: Array[Dictionary]) -> void:
	# Lê o arquivo .lst base, injeta os dados e salva um novo lst. [br]
	# [param user_data] deve ser Array[Dictionary] com chaves "nome" e "email".
	var lst_output := FileAccess.open(caminho_saida + "survey_tokens.lst", FileAccess.WRITE)
	var f := FileAccess.open(caminho_arquivoentrada, FileAccess.READ)
	if lst_output == null or f == null:
		return

	var reached_userdata: bool = false
	var row_over: bool = false
	var row_info: Array[String] = []

	while not f.eof_reached():
		var line = f.get_line()
		
		if reached_userdata == false or row_over == true:
			lst_output.store_string(line + "\n")
		if reached_userdata == true and row_over == false:
			row_info.append(line)
		
		if "<rows>" in line:
			reached_userdata = true
		if "</row>" in line:
			row_over = true
			var counter := 1
			for entry in user_data:
				for j in row_info.size():
					var templine: String = row_info[j]
					if "<tid><![CDATA[[[COUNTER]]]]></tid>" in row_info[j]:
						templine = row_info[j].replace("[[COUNTER]]", str(counter))
						counter += 1
					if "<firstname><![CDATA[[[STUDENTNAME]]]]></firstname>" in row_info[j]:
						templine = row_info[j].replace("[[STUDENTNAME]]", entry["nome"])
					if "<email><![CDATA[[[STUDENTEMAIL]]]]></email>" in row_info[j]:
						templine = row_info[j].replace("[[STUDENTEMAIL]]", entry["email"])
					lst_output.store_string(templine + "\n")

func _lsa_out(nome_survey: String) -> void:
	# Lê o arquivo .lst base, injeta os dados e salva um novo lst
	var diretorio: String = diretorio_surveys
	file_handling.zip_files(diretorio, nome_survey, ["survey.lss","survey_tokens.lst"])
	var dir = DirAccess.open(diretorio)
	dir.rename(diretorio+nome_survey+".zip", diretorio+nome_survey+".lsa")
	dir.remove(diretorio+"survey.lss")
	dir.remove(diretorio+"survey_tokens.lst")


func _on_gerar_lime_survey_button_up() -> void:
	print_debug("Iniciando processo de geração LimeSurvey...")
	var lista_disciplinas: Array[Dictionary] = _lista_disciplinas(historico)
	var dir = DirAccess.open(GV.dir_saida)
	print_debug("Limpando diretório ", diretorio_surveys, ". Este processo pode demorar um pouco.")
	file_handling.clear_directory(diretorio_surveys, true)
	print_debug("Criando surveys para as disciplinas. Total a ser criado: ", lista_disciplinas.size(), ".")
	print_debug("Criando surveys na pasta '", diretorio_surveys, "'", ".")
	for a in lista_disciplinas.size():
		# Cada iteiração neste loop cria uma pasta para uma combinação disciplina-professor
		var nome_survey: String = lista_disciplinas[a]["professor"] + "-" \
		+ lista_disciplinas[a]["nomeativcurricular"] + "-" \
		+ lista_disciplinas[a]["codturma"] + "-" \
		+ lista_disciplinas[a]["semestre"]
		nome_survey = file_handling.string_to_validfilename(nome_survey)
		print_debug("Survey ", nome_survey, ".")
		dir = DirAccess.open(GV.dir_saida)
		# Criar o arquivo .lss
		_lss_out(GV.dir_principal + "arquivos/limesurvey/survey.lss", diretorio_surveys, \
		lista_disciplinas[a]["nomeativcurricular"], lista_disciplinas[a]["professor"])
		# Criar lista de alunos e e-mails e, na sequência, criar arquivo .lst
		var exp_arr: Array[Dictionary] = []
		for matricula_aluno in historico.keys():
			for b in historico[matricula_aluno]["dados"].size():
				if historico[matricula_aluno]["dados"][b]["codigocurriculo"].to_lower() \
				== lista_disciplinas[a]["codigocurriculo"].to_lower()\
				and historico[matricula_aluno]["dados"][b]["situacao"].begins_with("matr"):
					# Se é igual, o aluno cursa a disciplina que está sendo criado o survey no momento
					var err: bool = false
					if not emails.has(matricula_aluno):
						print_debug("ERRO: Matricula nao encontrada no arquivo de emails. O arquivo esta atualizado?")
						err = true
						if not historico.has(matricula_aluno):
							print_debug("ERRO: Matricula nao encontrada no arquivo de historico. O arquivo esta atualizado?")
							err = true
					if not err:
						exp_arr.append({
							"nome": historico[matricula_aluno]["nomedoaluno"],
							"email": emails[matricula_aluno]["dados"][0]["emailinst"]
						})
		_lst_out(GV.dir_principal + "arquivos/limesurvey/survey_tokens.lst", diretorio_surveys, exp_arr)
		# Compacta o arquivo e cria o lsa
		_lsa_out(nome_survey)
		if a == 1:
			pass


# Mapa botao OnOff -> painel que ele controla. Base unica para alternar (Shift+clique isola/restaura)
# e para o realce: o botao fica "afundado" (toggle_mode) quando seu painel esta visivel.
func _mapa_toggles() -> Dictionary:
	return {$"%OnOffTerminal": $"%Terminal", $"%OnOffAdmin": $"%JanelaAdmin"}

func _toggle(alvo: Control) -> void:
	var mapa := _mapa_toggles()
	TogglePaineis.aplicar(mapa.values(), alvo, Input.is_key_pressed(KEY_SHIFT))
	TogglePaineis.sincronizar_botoes(mapa)

func _on_on_off_terminal_button_up() -> void:
	_toggle($"%Terminal")


func _on_on_off_admin_button_up() -> void:
	_toggle($"%JanelaAdmin")
