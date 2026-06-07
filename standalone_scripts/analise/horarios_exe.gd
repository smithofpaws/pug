class_name HorariosExe extends Resource
## Função de suporte para interações com arquivos do programa de horários utilizado na Unipampa 
## Alegrete.
##
## Trabalha com a leitura dos arquivos e conversões possíveis. É separada pois visa ser obsoletada 
## em futura substituição completa do Horarios.exe.
## Os principais parâmetros empregados nesta classe e suas devidas formatações são: [br]
## Formato de [param horarios_ini] é conforme o arquivo [code]horarios.ini[/code], ou seja,
## mantém a lógica de um arquivo ini mas em forma de dicionário. Inclui letras maiúsculas e 
## minúsculas. [br]
## Formato de [param horarios_txt] é uma matriz contendo dicionários que representam cada 
## linha e item do arquivo lido, porém buscando o aprimoramento com o uso de chaves de 
## dicionários. Assim, o resultado é: [br]
## [ [br]
## { "linha": "145", "professor": "maria da silva souza", "sala": "sem sala", ...}, [br]
## { "linha": "146", "professor": "joao pereira lima", "sala": "sem sala", ...} [br]
## ] [br]
## Formato de [param horariosexe_txt] é o formato do arquivo [code]horarios.txt[/code], 
## contido em matrizes de matrizes, visando preparar para exportação e uso em horarios.exe. [br]
## [ [br]
##  [1,maria da silva souza,Salas,ec01,13:30,Quarta,Algoritmos e Programação (al0005),Teorica,T20,Vagas,1,1,1] [br]
##  [1,joao pereira lima,Salas,ec01,13:30,Quarta,Introdução à Engenharia Civil (al0362),Teorica,T20,Vagas,1,1,1] [br]
## ] [br]

# Classes instanciadas
var general_functions := GeneralFunctions.new()
var analise_historico := AnaliseHistorico.new()
var analise_grades := AnaliseGrades.new()

## Carrega o arquivo de horários ini localizado em [code]/dados/saida/horarios.ini[/code], sendo 
## o arquivo em questão obtido no programa de horários do campus. [br]
## Este arquivo não é um ini padrão, então a classe de ajuda de leitura ini do Godot não pode ser empregado. 
## A leitura não é realizada de forma integral, então algumas chaves são ignoradas. [br]
## Formato de [param diretorio] deve ser como [code]c:/local_exemplo/[/code]. [br]
## Formato de [param arquivo] deve ser como [code]horarios.ini[/code]. [br]
func carregar_horarios_ini(diretorio: String, arquivo: String) -> Dictionary:
	print_debug("Carregando horarios INI...")
	var horarios_ini: Dictionary
	var f: FileAccess = FileAccess.open(diretorio + arquivo, FileAccess.READ)
	if f == null:
		print_debug("CRITICO: Erro ao abrir arquivo ", diretorio + arquivo, "!")
		return {}
	var section: String = ""
	while not f.eof_reached():
		var line: String = f.get_line()
		if line.to_lower().begins_with("["):
			line = line.trim_prefix("[")
			line = line.trim_suffix("]")
			section = line
			horarios_ini[section] = {}
		else:
			if section != "Config" and section != "Vagas":
				var line_arr: Array[String] = general_functions.split(line, "=", true, false)
				if line_arr.size() > 1:
					line_arr[1] = line_arr[1].replace("\"","")
					line_arr[1] = line_arr[1].replace(";-","")
					line_arr[1] = line_arr[1].replace(";0","")
					horarios_ini[section][line_arr[0]] = line_arr[1]
			else:
				horarios_ini[section]["Secao_nao_lida"] = ""
	print_debug("Horarios INI carregado.")
	return horarios_ini

## Carrega o arquivo de horários txt localizado em [code]/dados/saida/horarios.txt[/code], sendo 
## o arquivo em questão obtido no programa de horários do campus. [br]
## Formato de [param diretorio] deve ser como [code]c:/local_exemplo/[/code]. [br]
## Formato de [param arquivo] deve ser como [code]horarios.txt[/code]. [br]
## Formato de [param posicoes_horarios_txt] deve ser conforme vem do arquivo [code]base_config.json[/code]. [br]
func carregar_horarios_txt(diretorio: String, arquivo: String, posicoes_horarios_txt: Dictionary) -> Array:
	print_debug("Carregando Horarios TXT...")
	var horarios_txt: Array[Dictionary]
	var f: FileAccess = FileAccess.open(diretorio + arquivo, FileAccess.READ)
	if f == null:
		print_debug("CRITICO: Erro ao abrir arquivo ", diretorio + arquivo, "!")
		return []
	var section: String = ""
	# Numero da linha fisica no arquivo (1-based) e contagem de linhas problematicas, para o
	# diagnostico apontar exatamente onde esta o problema (toda linha deveria ter disciplina + codigo).
	var num_linha: int = 0
	var problemas: int = 0
	# Padrao de codigo de disciplina (e.g. "al0496"), aceito tanto entre parenteses "(al0496)" quanto
	# anexado ao nome "Calculo I Al0496". Compilado uma vez para o diagnostico de cada linha.
	var re_codigo := RegEx.new()
	re_codigo.compile("(?i)al\\d+")
	while not f.eof_reached():
		var line: String = f.get_line()
		num_linha += 1
		var split_arr: PackedStringArray = line.split(",")
		var line_arr: Array[String] = []
		# Aqui, para a linha em análise, é necessário verificar se existem aspas no texto. Um exemplo 
		# dessa situação é tanto nomes de professores "Diego Arthur Hartmann" que possuem aspas devido
		# aos espaços no texto, quanto ao nome de disciplinas "Mecânica dos Solos". Estas aspas devem
		# ser removidos.
		# Um caso específico é textos entre aspas que contenham vírgulas. Um exemplo é 
		# "Legislação, Ética e Exercício Profissional de Engenharia (al0142)". Como tem uma vírgula
		# o nome acaba sendo cortado ao meio, virando 
		# ["Legislação",Ética e Exercício Profissional de Engenharia (al0142)""]. Isto é corrigido aqui.
		var a: int = 0
		while a < split_arr.size():
			var pos_start: int = split_arr[a].find("\"")
			# Verifica se encontrou aspas no inicio da String
			if pos_start != -1:
				var pos_end: int = split_arr[a].find("\"", 1)
				# Verifica se não encontrou aspas depois do inicio da String
				if pos_end != -1:
					# Caso encontre, significa que é uma String longa com espaços, mas sem vírgula
					split_arr[a] = split_arr[a].replacen("\"","")
					line_arr.append(split_arr[a].to_lower())
				else:
					# Caso não encontre, significa que a String foi dividida por uma vírgula
					var concatenated: String = split_arr[a].replacen("\"","")
					for b in range(a+1,split_arr.size(),1):
						# Procura a próxima ocorrencia de aspas, indicando o fim da String com vírgula
						if split_arr[b].find("\"") != -1:
							# Caso encontre, chegou ao fim da string, então finaliza a string
							concatenated = concatenated + "," + split_arr[b].replacen("\"","")
							line_arr.append(concatenated.to_lower())
							a = b
							break
						else:
							# Caso não encontre, concatena e prossegue a procura
							concatenated = concatenated + "," + split_arr[b]
			else:
				line_arr.append(split_arr[a].to_lower())
			a = a + 1
		
		var temp_dict: Dictionary = {}
		for key in posicoes_horarios_txt.keys():
			if posicoes_horarios_txt[key] < line_arr.size():
				temp_dict[key] = line_arr[posicoes_horarios_txt[key]]
		if line_arr.size() > 1:
			horarios_txt.append(temp_dict)
			if _diagnosticar_linha_horarios(num_linha, line, line_arr, temp_dict, posicoes_horarios_txt, re_codigo):
				problemas += 1

	if problemas > 0:
		print_debug("Horarios TXT: ", problemas, " linha(s) com disciplina/codigo ausente. Veja os avisos acima.")
	print_debug("Horarios TXT carregado.")
	return horarios_txt

# Verifica uma linha ja carregada do horarios.txt e, se houver problema, emite um aviso claro com
# numero da linha, conteudo bruto e motivo. Em principio toda linha deveria ter a coluna disciplina
# com um codigo de disciplina (e.g. "Algoritmos (al0005)" ou "Algoritmos Al0005"). Retorna true se
# detectou problema.
func _diagnosticar_linha_horarios(num_linha: int, linha_bruta: String, line_arr: Array, \
	temp_dict: Dictionary, posicoes: Dictionary, re_codigo: RegEx) -> bool:
	var bruta: String = linha_bruta.strip_edges()
	if not temp_dict.has("disciplina"):
		var pos_disc: int = int(posicoes.get("disciplina", -1))
		print_debug("AVISO horarios.txt linha ", num_linha, ": sem coluna de disciplina (", \
			line_arr.size(), " campos; esperado indice ", pos_disc, "). Conteudo: ", bruta)
		return true
	var disc: String = str(temp_dict["disciplina"])
	if re_codigo.search(disc) == null:
		print_debug("AVISO horarios.txt linha ", num_linha, \
			": disciplina sem codigo identificavel (esperado algo como 'al0123'): '", disc, \
			"'. Conteudo: ", bruta)
		return true
	return false

## Extrai do nome da disciplina no arquivo [code]horarios.txt[/code] o código da disciplina (e.g. para o
## nome "Projeto Integrado (al0164)", extrai apenas "al0164". [br]
## Formato de [param texto] deve ser como "Projeto Integrado (al0164)". [br]
## Retorna o código da disciplina (e.g "al0164").
func extrair_cod_horarios_txt(texto: String) -> String:
	if "(" in texto:
		var ultimo_slice: int = texto.get_slice_count("(")
		texto = texto.get_slice("(", ultimo_slice-1)
		texto = texto.trim_suffix(")")
	else:
		var idx_al: int = texto.to_lower().rfind("al")
		texto = texto.substr(idx_al) if idx_al >= 0 else ""
	return texto

## Extrai o nome da disciplina de uma linha do [code]horarios.txt[/code], descartando o código entre
## parênteses (e.g. para "Projeto Integrado (al0164)", retorna "Projeto Integrado"). [br]
## Sem parênteses, retorna o texto inteiro (apenas com as bordas aparadas).
func extrair_nome_horarios_txt(texto: String) -> String:
	if "(" in texto:
		return texto.substr(0, texto.rfind("(")).strip_edges()
	return texto.strip_edges()

## A partir do dicionário fornecido, retorna a chave com a formatação adequado ao uso no arquivo 
## [code]horarios.txt[/code] e emprego no programa horarios.exe. [br]
## Formato de [param dicionario] deve ser de forma que as chaves se enquadrem nas chaves do 
## arquivo [code]base_config.json[/code] na chave horarios_txt.
func info_formatada(dicionario: Dictionary, key: String) -> String:
	var info: String
	match key:
		"linha":
			info = dicionario.get(key,"ERRO: SEM LINHA")
		"professor":
			info = dicionario.get(key,"ERRO: SEM PROFESSOR")
			if info.begins_with("\""):
				info = info.replace("\"", "").capitalize()
				info = "\"" + info + "\""
			else:
				info = info.capitalize()
		"sala":
			if dicionario.keys().size() == 0:
				info = "Sem Sala"
			else:
				info = dicionario.get(key,"ERRO: SEM SALA").capitalize()
		"semestre":
			info = dicionario.get(key, "ERRO: SEM SEMESTRE").to_upper()
			if "EXTRA" in info:
				info = info.replace("EXTRA", "Extra")
		"horario":
			if dicionario.keys().size() == 0:
				info = "13:30"
			else:
				info = dicionario.get(key, "ERRO: SEM HORARIO")
		"dia":
			if dicionario.keys().size() == 0:
				info = "Sábado"
			else:
				info = dicionario.get(key, "ERRO: SEM DIA").capitalize()
		"disciplina":
			info = dicionario.get(key, "ERRO: SEM DISCIPLINA")
			# A sequência abaixo adequa o nome das disciplinas conforme necessário para o programa de horários
			# O diagnostico de linhas sem disciplina/codigo e feito no carregamento
			# (ver [method _diagnosticar_linha_horarios]); aqui apenas formatamos o nome.
			var begin: int = info.find("(")
			var end: int = info.find(")")
			if begin != -1 and end != -1:
				var codigo: String = info.substr(begin+1, end-begin-1).to_pascal_case()
				info = info.erase(begin+1, end-begin-1)
				info = info.replace("()", codigo)
		"tipo":
			if dicionario.keys().size() == 0:
				info = "Teorica"
			else:
				info = dicionario.get(key, "ERRO: SEM TIPO").capitalize()
		"turma":
			if dicionario.keys().size() == 0:
				info = "T20"
			else:
				info = dicionario.get(key, "ERRO: SEM TURMA")
		"vagas":
			if dicionario.keys().size() == 0:
				info = "Vagas"
			else:
				info = dicionario.get(key, "ERRO: SE VAGAS")
		"p":
			if dicionario.keys().size() == 0:
				info = "1"
			else:
				info = dicionario.get(key, "ERRO: SEM P")
		"s":
			if dicionario.keys().size() == 0:
				info = "1"
			else:
				info = dicionario.get(key, "ERRO: SEM S")
		"t":
			if dicionario.keys().size() == 0:
				info = "1"
			else:
				info = dicionario.get(key, "ERRO: SEM T")
	# Adiciona aspas para nomes com espaços
	if " " in info and not info.begins_with("\""):
		info = "\"" + info + "\""
	return info

## Exporta o [param planejamento_csv] para o formato de [param horariosexe_txt]. [br]
## Formato de [param planejamento_csv] deve ser de forma [method FileHandling.carregar_planejamento]. [br]
## Formato de [param grades_disciplinas_curriculos] deve ser o mesmo fornecido por main 
## em sua criação e vem da pasta de grades. [br]
## Quando [param numero_linha] é adicionado, a primeira linha começa com o número definido. [br]
## Quando [param adicionar_aspas] é verdadeiro, adiciona aspas em frases com espaço. [br]
## @deprecated
func exportar_planejamento(planejamento_csv: Dictionary, grades_disciplinas_curriculos: Dictionary, numero_linha: int = 0, adicionar_aspas: bool = true) -> Array:
	var linhas: int = 0
	var horariosexe_txt: Array[Array] = []
	for key in planejamento_csv.keys():
		for b in planejamento_csv[key]["professor"].size():
			for c in int(planejamento_csv[key]["ch"][b]):
				# Obtem os dados do dicionário da extração de dados da planilha de planejamento
				horariosexe_txt.append([])
				horariosexe_txt[linhas].append(str(numero_linha))
				horariosexe_txt[linhas].append(info_formatada({"professor":planejamento_csv[key]["professor"][b]},"professor"))
				horariosexe_txt[linhas].append(info_formatada({}, "sala"))
				horariosexe_txt[linhas].append(info_formatada({"semestre":planejamento_csv[key]["semestre"]},"semestre"))
				horariosexe_txt[linhas].append(info_formatada({}, "horario"))
				horariosexe_txt[linhas].append(info_formatada({}, "dia"))
				# Determina o nome da disciplina a partir do código e do arquivo de grades
				var codigo: String = planejamento_csv[key].get("codigo", key)
				var nome: String = analise_grades.info_grade(grades_disciplinas_curriculos, codigo, "nome", "", true)
				var disciplina: String = nome + " (" + codigo + ")"
				horariosexe_txt[linhas].append(info_formatada({"disciplina": disciplina}, "disciplina"))
				horariosexe_txt[linhas].append(info_formatada({}, "tipo"))
				horariosexe_txt[linhas].append(info_formatada({}, "turma"))
				horariosexe_txt[linhas].append(info_formatada({}, "vagas"))
				horariosexe_txt[linhas].append(info_formatada({},"p"))
				horariosexe_txt[linhas].append(info_formatada({},"s"))
				horariosexe_txt[linhas].append(info_formatada({},"t"))
				linhas+=1
				numero_linha+=1
	return horariosexe_txt

## Exporta os horários que estão no formato [param horarios_txt] para o formato [param horariosexe_txt].
func exportar_horariostxt(horarios_txt: Array) -> Array:
	var horariosexe_txt: Array[Array] = []
	for a in horarios_txt.size():
		horariosexe_txt.append([])
		var temp_dic: Dictionary = horarios_txt[a]
		horariosexe_txt[a].append(info_formatada(temp_dic,"linha"))
		horariosexe_txt[a].append(info_formatada(temp_dic,"professor"))
		horariosexe_txt[a].append(info_formatada(temp_dic,"sala"))
		horariosexe_txt[a].append(info_formatada(temp_dic,"semestre"))
		horariosexe_txt[a].append(info_formatada(temp_dic,"horario"))
		horariosexe_txt[a].append(info_formatada(temp_dic,"dia"))
		horariosexe_txt[a].append(info_formatada(temp_dic,"disciplina"))
		horariosexe_txt[a].append(info_formatada(temp_dic,"tipo"))
		horariosexe_txt[a].append(info_formatada(temp_dic,"turma"))
		horariosexe_txt[a].append(info_formatada(temp_dic,"vagas"))
		horariosexe_txt[a].append(info_formatada(temp_dic,"p"))
		horariosexe_txt[a].append(info_formatada(temp_dic,"s"))
		horariosexe_txt[a].append(info_formatada(temp_dic,"t"))
	return horariosexe_txt

## Exporta as alocações no formato [code]horarios_ref.txt[/code] (13 campos, CP1252) compatível
## com o programa de horários da universidade.
## [param alocacoes] deve ser um dicionário chave "linha_coluna" → dados da célula alocada.
## [param planejamento_csv] deve vir de [method FileHandling.carregar_planejamento] (fallback).
## [param horarios_ini] deve vir de [method carregar_horarios_ini] (fonte canônica de nomes).
## [param grades] deve ser o dicionário de grades curriculares (fallback para nome de disciplina).
## [param dias] array com os nomes dos dias da semana, na ordem das colunas da grade.
## [param horas] array com os horários de aula, na ordem das linhas da grade.
func exportar_horarios_ref(alocacoes: Dictionary, planejamento_csv: Dictionary, horarios_ini: Dictionary, grades: Dictionary, dias: Array, horas: Array) -> Array[String]:
	var linhas: Array[String] = []
	linhas.append('1," "," "," "," "," "," "," "," "," ",1,1,1')
	var celulas_ordenadas: Array[String] = []
	celulas_ordenadas.assign(alocacoes.keys())
	celulas_ordenadas.sort()
	var _id: int = 0
	for chave_celula in celulas_ordenadas:
		var partes: PackedStringArray = chave_celula.split("_")
		if partes.size() != 2:
			continue
		var lin: int = int(partes[0])
		var col: int = int(partes[1])
		if lin < 1 or col < 1:
			continue
		var arr: Array = alocacoes[chave_celula]
		for a_dict in arr:
			var aloc: Dictionary = a_dict
			var chave: String = aloc.get("chave", "")
			var dados_csv: Dictionary = planejamento_csv.get(chave, {})
			var codigo: String = dados_csv.get("codigo", aloc.get("codigo", ""))
			# Professor — fonte canônica: horarios.ini [Professores]
			var profs: Array = dados_csv.get("professor", [])
			var prof_nome: String = str(profs[0]) if profs.size() > 0 else aloc.get("professor", "")
			var prof_str: String = _buscar_professor_ini(prof_nome, horarios_ini)
			# Sala — usa default "Sem Sala" se vazio
			var sala_str: String = aloc.get("sala", "")
			if sala_str.is_empty():
				sala_str = "Sem Sala"
			# Semestre — normaliza para uppercase (ex: ec05 → EC05, ecextra → ECExtra)
			var sem_str: String = dados_csv.get("semestre", aloc.get("semestre", ""))
			if not sem_str.is_empty():
				sem_str = sem_str.to_upper()
				if sem_str.ends_with("EXTRA"):
					sem_str = sem_str.substr(0, sem_str.length() - 5) + "Extra"
			# Horário
			var hor_str: String = ""
			if lin - 1 < horas.size():
				hor_str = str(horas[lin - 1])
			# Dia
			var dia_str: String = ""
			if col - 1 < dias.size():
				dia_str = str(dias[col - 1])
			# Disciplina — fonte canônica: horarios.ini [Disciplinas]
			var disc_str: String = _buscar_disciplina_ini(codigo, horarios_ini)
			if disc_str.is_empty():
				var nome: String = analise_grades.info_grade(grades, codigo, "nome", "", true)
				if nome.begins_with("Codigo"):
					nome = codigo
				disc_str = nome + " " + codigo.to_upper()
			# Tipo, Turma, Vagas, P, S, T — usam defaults se vazios
			var tipo_str: String = aloc.get("tipo", "")
			if tipo_str.is_empty():
				tipo_str = "Teorica"
			var turma_str: String = aloc.get("turma", "")
			if turma_str.is_empty():
				turma_str = "T20"
			var vagas_str: String = aloc.get("vagas", "Vagas")
			if vagas_str.is_empty():
				vagas_str = "Vagas"
			var p_str: String = aloc.get("p", "1")
			var s_str: String = aloc.get("s", "1")
			var t_str: String = aloc.get("t", "1")
			_id += 1
			var linha: String = str(_id) + ","
			linha += _formatar_campo_cp1252(prof_str) + ","
			linha += _formatar_campo_cp1252(sala_str) + ","
			linha += sem_str + ","
			linha += hor_str + ","
			linha += dia_str + ","
			linha += _formatar_campo_cp1252(disc_str) + ","
			linha += _formatar_campo_cp1252(tipo_str) + ","
			linha += _formatar_campo_cp1252(turma_str) + ","
			linha += vagas_str + ","
			linha += p_str + ","
			linha += s_str + ","
			linha += t_str
			linhas.append(linha)
	return linhas

# Busca o nome canônico do professor no [code]horarios.ini[/code].
# Se não encontrado, retorna o nome original do CSV.
func _buscar_professor_ini(nome_csv: String, horarios_ini: Dictionary) -> String:
	if nome_csv.is_empty():
		return " "
	if not horarios_ini.has("Professores"):
		return nome_csv
	var nome_min: String = nome_csv.to_lower().replace(" ", "")
	for prof in horarios_ini["Professores"].values():
		if str(prof).to_lower().replace(" ", "") == nome_min:
			return str(prof)
	return nome_csv

# Busca o nome canônico da disciplina no [code]horarios.ini[/code] pelo código ALXXXX.
# Retorna o texto completo (ex.: "Ciencia dos Materiais Al5071") ou string vazia se não encontrado.
func _buscar_disciplina_ini(codigo: String, horarios_ini: Dictionary) -> String:
	if codigo.is_empty() or not horarios_ini.has("Disciplinas"):
		return ""
	var cod_lower: String = codigo.to_lower()
	for disc in horarios_ini["Disciplinas"].values():
		var disc_str: String = str(disc)
		if disc_str.to_lower().ends_with(cod_lower) or (" " + cod_lower) in disc_str.to_lower():
			return disc_str
	return ""

# Formata um campo para o arquivo horarios_ref.txt.
# Valores com espaço são quotados com aspas duplas.
func _formatar_campo_cp1252(valor: String) -> String:
	if " " in valor or valor.is_empty():
		return '"' + valor + '"'
	return valor

# Converte uma string UTF-8 para bytes CP1252 (Windows-1252).
func _para_cp1252(texto: String) -> PackedByteArray:
	var bytes: PackedByteArray = PackedByteArray()
	for c in texto:
		var cp: int = c.unicode_at(0)
		if cp <= 0x7F:
			bytes.append(cp)
		elif cp >= 0xA0 and cp <= 0xFF:
			bytes.append(cp)
		else:
			bytes.append(_unicode_para_cp1252(cp))
	return bytes

# Mapeia caracteres Unicode para CP1252.
func _unicode_para_cp1252(cp: int) -> int:
	match cp:
		0x20AC: return 0x80   # €
		0x201A: return 0x82   # ‚
		0x0192: return 0x83   # ƒ
		0x201E: return 0x84   # „
		0x2026: return 0x85   # …
		0x2020: return 0x86   # †
		0x2021: return 0x87   # ‡
		0x02C6: return 0x88   # ˆ
		0x2030: return 0x89   # ‰
		0x0160: return 0x8A   # Š
		0x2039: return 0x8B   # ‹
		0x0152: return 0x8C   # Œ
		0x017D: return 0x8E   # Ž
		0x2018: return 0x91   # '
		0x2019: return 0x92   # '
		0x201C: return 0x93   # "
		0x201D: return 0x94   # "
		0x2022: return 0x95   # •
		0x2013: return 0x96   # –
		0x2014: return 0x97   # —
		0x02DC: return 0x98   # ˜
		0x2122: return 0x99   # ™
		0x0161: return 0x9A   # š
		0x203A: return 0x9B   # ›
		0x0153: return 0x9C   # œ
		0x017E: return 0x9E   # ž
		0x0178: return 0x9F   # Ÿ
		_:  return 0x3F       # ?
