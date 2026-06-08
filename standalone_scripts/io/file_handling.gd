# Auxiliar Coordenacao
# Copyright (C) 2026 DIEGO ARTHUR HARTMANN
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

class_name FileHandling extends Resource
## Controla qualquer tipo de leitura e gravação de arquivos.
##
## Separadas em dois tipos de funções: gerais e específicas. As funções gerais 
## servem para qualquer programa em GDScript, já as específicas são apenas para 
## uso neste programa. 

# Classes instanciadas
var general_functions := GeneralFunctions.new()
var analise_historico := AnaliseHistorico.new()

## Avisos gerados durante a leitura de arquivos (ex.: divergência de cabeçalho).
var avisos_leitura: Array[String] = []

#region Funções específicas
## Verdadeiro quando a [param celula] de semestre (ex.: [code]"EC04"[/code], [code]"EM02;ECExtra"[/code])
## casa com algum dos [param prefixos] (case-insensitive). A célula é quebrada nos [param delimitadores]
## (default [code][";", "/", "-"][/code]) ANTES do teste, para que ofertas combinadas como
## [code]"EM02;ECExtra"[/code] casem com o prefixo [code]"EC"[/code] mesmo não sendo o primeiro da lista.
## Usado tanto na leitura ([method carregar_planejamento]) quanto no filtro de envio por curso
## ([method ArquivosPlanejamento.exportar_planejamento_json]).
static func semestre_casa_prefixos(celula: String, prefixos: Array, delimitadores: Array = []) -> bool:
	for parte in dividir_semestres(celula, delimitadores):
		var parte_lower: String = parte.strip_edges().to_lower()
		for prefixo in prefixos:
			var pref_lower: String = str(prefixo).strip_edges().to_lower()
			if not pref_lower.is_empty() and parte_lower.begins_with(pref_lower):
				return true
	return false

## Quebra a [param celula] de semestre em partes pelos [param delimitadores] (default
## [code][";", "/", "-"][/code]). Usado para ofertas combinadas (ex.: [code]"EM02;ECExtra"[/code]).
## Retorna [code][celula][/code] quando nenhum delimitador aparece.
static func dividir_semestres(celula: String, delimitadores: Array = []) -> PackedStringArray:
	var delims: Array = delimitadores if delimitadores.size() > 0 else [";", "/", "-"]
	for delim in delims:
		if celula.contains(delim):
			return celula.split(delim)
	return PackedStringArray([celula])

## Carrega o arquivo de planejamento csv localizado em [code]/dados/saida/planejamento.csv[/code], sendo
## o arquivo em questão baixado da planilha de planejamento da coordenação acadêmica, mas em formato csv. [br]
## Formato de [param diretorio] deve ser como [code]c:/local_exemplo/[/code]. [br]
## Formato de [param arquivo] deve ser como [code]planejamento.csv[/code]. [br]
## [param prefixos_semestre] é a lista (case-insensitive) de prefixos do código de semestre a aceitar, ex.
## [code]["EC", "EA"][/code]. Linhas cujo semestre não começar com nenhum desses prefixos são ignoradas.
## Quando a lista vier vazia, nada é lido e o dicionário retornado é vazio. [br]
## Retorna um dicionário chaveado por [code]<cod_disciplina>_<semestre>[/code] (com sufixo [code]_N[/code] se
## houver ofertas duplicadas). [br]
## { [br]
##  "al0001_ec01": { [br]
## "semestre": "EC01", [br]
## "professor": ["professor1", "professor2"], [br]
## "ch": ["ch_prof1", "ch_prof2"], [br]
## "oferta": "EC01", [br]
## "ch_disciplina": "4", [br]
## "codigo": "al0001", [br]
## }, [br]
## ... [br]
## } [br]
## [param posicoes] dicionario com as posicoes das colunas no CSV (chaves: [code]semestre[/code],
## [code]codigo[/code], [code]ch_total[/code], [code]cabecalho_profs[/code]). [br]
## Se omitido ou vazio, usa defaults (1, 2, 3, "matr"). [br]
## Nota: celulas de semestre como [code]"EC04;EE04"[/code] geram entradas separadas para cada curso.
func carregar_planejamento(diretorio: String, arquivo: String, prefixos_semestre: Array, delimitadores: Array = [], posicoes: Dictionary = {}) -> Dictionary:
	print_debug("Carregando planejamento...")
	if prefixos_semestre.is_empty():
		print_debug("AVISO: carregar_planejamento chamado sem prefixos de semestre. Nenhum curso sera lido.")
		return {}
	# Normaliza os prefixos para minúsculas (a comparação no laço também é em minúsculas).
	var prefixos_lower: Array[String] = []
	for p in prefixos_semestre:
		var s: String = str(p).strip_edges().to_lower()
		if not s.is_empty():
			prefixos_lower.append(s)
	if prefixos_lower.is_empty():
		print_debug("AVISO: prefixos_semestre informados sao todos vazios.")
		return {}
	# Extrai posicoes das colunas do dicionario (com defaults retrocompativeis)
	var col_semestre := int(posicoes.get("semestre", 1))
	var col_codigo := int(posicoes.get("codigo", 2))
	var col_ch_total := int(posicoes.get("ch_total", 3))
	var cabecalho_profs := str(posicoes.get("cabecalho_profs", "matr"))
	# [param temp] contém o arquivo de planejamento de forma mais bruta.
	var temp: Array[Array] = read_csvfile(diretorio, arquivo, [], [], [",", ";"])
	if temp.size() < 2:
		print_debug("ERRO: Arquivo de planejamento vazio ou ausente em ", diretorio + arquivo, ".")
		return {}
	# [param planejamento] contém uma sequencia de chaves compostas (código_semestre), as quais contém
	# os profs, os créditos alocados a estes, e o semestre. Exemplo com dois professores em uma disciplina,
	# um professor com 2 créditos e outro com 1:
	#     "al0001_ec01": {
	#       "codigo": "al0001",
	#       "professor": ["fulano", "ciclano"],
	#       "semestre": "EC01",
	#       "ch": ["2", "1"],
	#       "oferta": "EC01",
	#       "ch_disciplina": "4"
	#     }
	var planejamento: Dictionary
	# [param divisor_lista_prof] é o índice da matriz linha que contém o nome do primeiro professor.
	var dividor_lista_prof: int

	for a in temp[0].size():
		if temp[0][a].to_lower().begins_with(cabecalho_profs):
			dividor_lista_prof = a + 1
			break
	if dividor_lista_prof == 0:
		print_debug("AVISO: Coluna '" + cabecalho_profs + "' nao encontrada no cabecalho. Dados de professores nao serao extraidos.")
		dividor_lista_prof = temp[0].size()

	# Varre todas as linhas: cada bloco de curso (separado por linhas em branco) é tratado igual.
	# Linhas em branco são naturalmente descartadas porque seu temp[lines][col_semestre] não casa com nenhum prefixo.
	for lines in temp.size():
		# Linhas em branco e de outros cursos são descartadas: seu semestre não casa com nenhum prefixo.
		var celula_semestre: String = temp[lines][col_semestre]
		if not semestre_casa_prefixos(celula_semestre, prefixos_lower, delimitadores):
			continue
		# Partes da oferta combinada (ex.: "EM02;ECExtra"): cada parte que casa vira uma entrada.
		var semestres: PackedStringArray = dividir_semestres(celula_semestre, delimitadores)
		# Determina o código da disciplina
		var cod_pos: int = col_codigo
		if not temp[lines][col_codigo].to_lower().begins_with("al"):
			for a in range(cod_pos + 1, temp[lines].size()):
				var temp_str: String = temp[lines][a]
				if temp_str.to_lower().begins_with("al"):
					cod_pos = a
					break
				if a == temp[lines].size() - 1:
					print_debug("ERRO: Não foi encontrado o código para a disciplina. Possivelmente uma ficará em falta. " \
					+ "Linha problemática: " + str(temp[lines]))
		var temp_string: String = temp[lines][cod_pos]
		var cod_disciplina: String = general_functions.split(temp_string, " ")[0]
		# A coluna do codigo no planejamento.csv costuma trazer "CODIGO NOME" (ex.: "AL0490 DESENHO
		# DIGITAL"). Preserva o nome embutido (o que vier depois do codigo) para uso em avisos/exibicao.
		var nome_disciplina: String = ""
		var idx_espaco: int = temp_string.find(" ")
		if idx_espaco != -1:
			nome_disciplina = temp_string.substr(idx_espaco + 1).strip_edges()
		if cod_disciplina.to_lower().begins_with("al"):
			for semestre in semestres:
				semestre = semestre.strip_edges()
				# Só cria entrada para pedaços cujo prefixo bata com os prefixos
				# selecionados. Evita que um pedaço "EM02" vaze na importação feita
				# com prefixo ["ec"], poluindo os filtros de curso/semestre.
				var sem_lower: String = semestre.to_lower()
				var parte_casa: bool = false
				for prefixo in prefixos_lower:
					if sem_lower.begins_with(prefixo):
						parte_casa = true
						break
				if not parte_casa:
					continue
				var chave_base: String = cod_disciplina + "_" + semestre.to_lower()
				var oferta_seq: int = 1
				var chave: String = chave_base
				while planejamento.has(chave):
					oferta_seq += 1
					chave = chave_base + "_" + str(oferta_seq)
				planejamento[chave] = {}
				planejamento[chave]["codigo"] = cod_disciplina
				planejamento[chave]["semestre"] = semestre
				planejamento[chave]["professor"] = []
				planejamento[chave]["ch"] = []
				planejamento[chave]["oferta"] = celula_semestre
				planejamento[chave]["ch_disciplina"] = str(temp[lines][col_ch_total])
				planejamento[chave]["nome_csv"] = nome_disciplina
				for a in range(dividor_lista_prof, temp[lines].size()):
					if int(temp[lines][a]) > 0:
						planejamento[chave]["professor"].append(temp[0][a])
						planejamento[chave]["ch"].append(temp[lines][a])
		else:
			print_debug("ERRO: Leitura do código da disciplina resultou em código invalido: ", cod_disciplina, ".")
	print_debug("Planejamento carregado (", planejamento.size(), " disciplinas, prefixos: ", prefixos_lower, ").")
	return planejamento

## Lê o arquivo de dados dos alunos em csv, podendo ser o historico ou o email apenas das colunas 
## interessantes para a análise em questão, definidas em [param regras_leitura]. [br]
## Formato de [param diretorio] deve ser como [code]c:/local_exemplo/[/code]. [br]
## Formato de [param arquivo] deve ser como [code]hist.csv[/code]. [br]
## Formato de [param regras_leitura] deve ser um dicionário cópia de histfile ou mailfile encontrados no 
## arquivo [code]base_config.json[/code]. Tem a função de indicar em qual coluna está qual dado. [br]
## Retorna um dicionário especialmente usado para armazenar o [param historico] e [param email]. O formato 
## de saída segue a seguinte lógica de exemplo: [br]
## { [br]
## "2410102767": { [br]
## "nomedoaluno": "aaron krignl trindade", [br]
## "dados": [sequencia linha a linha do arquivo hist.csv ou email.csv contendo as chaves encontradas em 
## histfile e mailfile do arquivo [code]base_config.json[/code]] [br]
## } [br]
## } [br]
func ler_dados(diretorio: String, arquivo: String, regras_leitura: Dictionary, ignorar_verificacao: bool = false, grades: Dictionary = {}) -> Dictionary:
	var dados: Dictionary = {}
	print_debug("Lendo arquivo ", arquivo, " ...")
	var f := FileAccess.open(diretorio + arquivo, FileAccess.READ)
	if f == null:
		print_debug("CRITICO: Erro ao abrir arquivo ", diretorio + arquivo, "!")
		return {}
	var linecount: int = 0
	var matricula: String = ""
	var _delimitador: String = ";"
	while not f.eof_reached():
		var line: Array[String] = general_functions.split(f.get_line().to_lower(), _delimitador)
		if linecount == 0:
			_validar_cabecalho(line, regras_leitura, arquivo)
		if linecount > 0:
			if line.size() > 1:
				if line[0] != matricula:
					matricula = line[int(regras_leitura["matricula"])]
					dados[matricula] = {}
					dados[matricula]["nomedoaluno"] = line[int(regras_leitura.get("nomedoaluno", 0))]
					dados[matricula]["dados"] = []
				var temp_dados: Dictionary
				for key in regras_leitura.keys():
					if key != "matricula" and key != "nomedoaluno": # Já extraídos acima como chaves estruturais; não duplicar nas linhas de dados.
						temp_dados[key] = line[int(regras_leitura[key])]
				dados[matricula]["dados"].append(temp_dados)
		linecount += 1
	print_debug("Arquivo ", arquivo, " lido.")
	if not ignorar_verificacao: analise_historico.revisar_historico(dados, grades)
	return dados

# Valida o cabeçalho de um arquivo CSV comparando com as posições esperadas em [param regras_leitura]. [br]
# Detecta: número insuficiente de colunas e possíveis divergências nos nomes das colunas. [br]
# Os avisos são armazenados em [member avisos_leitura].
func _validar_cabecalho(header: Array[String], regras_leitura: Dictionary, arquivo: String) -> void:
	avisos_leitura.clear()
	# Índice máximo esperado
	var max_index: int = -1
	for key in regras_leitura.keys():
		max_index = max(max_index, int(regras_leitura[key]))
	# Colunas insuficientes
	if header.size() <= max_index:
		avisos_leitura.append("Cabeçalho de " + arquivo + " tem " + str(header.size()) + " colunas, mas esperado ao menos " + str(max_index + 1) + ". Planilha pode ter colunas removidas ou deslocadas.")
		return
	# Para cada campo crítico, verifica se o cabeçalho contém palavra-chave esperada
	var _criticos: Dictionary = {
		"matricula": ["matrícula", "matricula"],
		"nomedoaluno": ["nome", "aluno"],
		"cod_curso": ["cod_curso"],
		"codigocurriculo": ["código", "currículo", "codigo"],
		"situacao": ["situação", "situacao", "status"],
		"ano": ["ano"],
		"semestre": ["semestre"],
	}
	for campo in _criticos.keys():
		if not regras_leitura.has(campo):
			continue
		var col: int = int(regras_leitura[campo])
		if col >= header.size():
			continue
		var valor: String = header[col].strip_edges()
		if valor == "":
			avisos_leitura.append("Cabeçalho de " + arquivo + ": coluna " + str(col) + " ('" + campo + "') está vazia.")
			continue
		var encontrado: bool = false
		for esperado in _criticos[campo]:
			if esperado in valor:
				encontrado = true
				break
		if not encontrado:
			avisos_leitura.append("Possível divergência em " + arquivo + ": coluna " + str(col) + " ('" + campo + "') contém '" + valor + "'. A planilha pode estar com colunas em ordem diferente da esperada.")
	return

## Define o diretório base de todos os arquivos do programa, armazenando-o em valore global.
func configurar_diretoriobase() -> void:
	if general_functions.is_exported():
		GV.dir_principal = OS.get_executable_path()
		GV.dir_principal = GV.dir_principal.trim_suffix(GV.dir_principal.get_file())
	else:
		GV.dir_principal = "res://"

## Configura o diretório de dados, definindo seu caminho e criando diretórios necessários para o 
## funcionamento do programa.
func configurar_dirdados() -> void:
	# Define o diretório dos arquivos de entrada e saída do usuário
	GV.dir_dados = GV.dir_principal + GV.configuracao_base.get("diretorios",{}).get("dados","")
	# Cria os diretórios de entrada e saída
	var dir_list: Array[String] = ["saida", "temp"]
	check_create_dir(GV.dir_dados)
	var dir = DirAccess.open(GV.dir_dados)
	if dir == null:
		DirAccess.make_dir_recursive_absolute(GV.dir_dados)
		dir = DirAccess.open(GV.dir_dados)
	if dir == null:
		print_debug("CRITICO: Nao foi possivel criar ou acessar o diretorio de dados ", GV.dir_dados, "!")
		return
	for a in dir_list.size():
		if not dir.dir_exists(dir_list[a]):
			dir.make_dir(dir_list[a])
			print_debug("Dir created: ", dir_list[a])
	# Define os diretórios
	GV.dir_saida = GV.dir_dados + "/" + dir_list[0] + "/"
	GV.dir_temp = GV.dir_dados + "/" + dir_list[1] + "/"
	if not general_functions.is_exported():
		GV.dir_saida = ProjectSettings.globalize_path(GV.dir_saida)
		GV.dir_temp = ProjectSettings.globalize_path(GV.dir_temp)
	print_debug("Diretorio de saida definido em ", GV.dir_saida, ".")
	print_debug("Diretorio temporario definido em ", GV.dir_temp, ".")
	var nome_exportacoes: String = GV.configuracao_base.get("diretorios", {}).get("exportacoes", "exportacoes")
	GV.dir_exportacoes = GV.dir_principal + nome_exportacoes + "/"
	if not general_functions.is_exported():
		GV.dir_exportacoes = ProjectSettings.globalize_path(GV.dir_exportacoes)
	check_create_dir(GV.dir_exportacoes)
	print_debug("Diretorio de exportacoes definido em ", GV.dir_exportacoes, ".")

## Exports to pdf using typst. [br]
## [param directory] format must be like [code]c:/example_folder/[/code]. [br]
## [param filename] format must be like [code]filename.csv[/code]. [br]
## [param data] format will depend on [param format]. [br]
## [param format] is a string that can be "text" or "table". [br]
## [param titulo] optional title for table format. When not empty, adds page setup and centered bold title.
func typst_export(directory: String, filename: String, data: Array, format: String, titulo: String = "") -> void:
	# Lambda functions for different situations
	# Table function to export 2D table
	# [param table_data] must be a 2D Array (e.g. [[a,b],[c,d],...])
	var table_lambda: Callable = func (table_data: Array[Array]) -> Array[String]:
		var output_table: Array[String] = []
		if titulo != "":
			output_table = [
				"#set page(",
				"  paper: \"a4\",",
				"  margin: (x: 1.8cm, y: 1.5cm),",
				")",
				"#set text(",
				"  font: \"Arial\",",
				"  size: 12pt",
				")",
				"",
				"#align(center)[= " + titulo + "]",
				"",
			]
		var column_sizing: String = ""
		for a in table_data[0].size():
			#column_sizing += "1fr"
			column_sizing += "auto"
			if a < table_data[0].size() - 1:
				column_sizing += ", "
		output_table.append_array([
			"#table(",
			# Creates the table header, making the number of culumns equal to this amount
			"  columns: (" + column_sizing + "),",
			"  inset: 10pt,",
			"  align: horizon,",
			"  table.header(",
		])
		var line_temp: String = "    "
		for a in table_data[0].size():
			line_temp = line_temp + "[" + table_data[0][a] + "],"
		output_table.append(line_temp)
		output_table.append("),")
		for a in range(1, table_data.size()):
			for b in table_data[a].size():
				output_table.append("["+ table_data[a][b]+"]"+",")
		output_table.append(")")
		return output_table
	
	var text_lambda: Callable = func (text_data: Array[String]) -> Array[String]:
		var text: Array[String] = []
		# Setups the header containing formatting options
		var header: Array[String] = [
			"#set page(",
			"  paper: \"a4\",",
			"  margin: (x: 1.8cm, y: 1.5cm),",
			")",
			"#set text(",
			"  font: \"Arial\",",
			"  size: 12pt",
			")"
		]
		text = header.duplicate()
		for a in data.size():
			text.append(data[a])
		return text
	
	var output: Array[String] = []
	
	match format:
		"text":
			output = text_lambda.call(data)
		
		"table":
			# Table test
			output = table_lambda.call(data)
		
		"ementa":
			output = data
			
		
		_:
			output = ["wrong format"]
	
	# Saves to storage and converts to pdf using typst
	save_text_file(directory, filename, output)
	if typst_disponivel():
		var typ_path = ProjectSettings.globalize_path(directory + filename)
		os_execute(GV.dir_principal + "externo/bin/", "typst.exe", ["compile", typ_path])
		print_debug("Arquivo pdf salvo em ", directory)
	else:
		print_debug("AVISO: typst.exe nao encontrado. Arquivo .typ salvo, mas PDF nao foi gerado.")


## Verifica se o executavel typst.exe esta presente no diretorio externo/bin.
func typst_disponivel() -> bool:
	return FileAccess.file_exists(GV.dir_principal + "externo/bin/typst.exe")

#endregion

#region Funções gerais
## Verifica se o diretorio existe. Se nao, cria-o. [br]
## [param directory] e o caminho completo do diretorio. Ex.: "c:/temp/directory"
func check_create_dir(directory: String) -> void:
	if not check_directory(directory, "", true):
		print_debug("Diretório ", directory, " não foi encontrado! O diretório será criado...")
		var folder_name: String = directory.trim_suffix("/").get_file()
		create_directory(GV.dir_saida, folder_name)

## Carrega um arquivo json. [param filename] precisa conter a extensao (i.e. ".json").
## [param directory] formato deve ser como [code]c:/example_folder/[/code]. [br]
## [param filename] formato deve ser como [code]base_config.json[/code]. [br]
## A função retorna um dicionário com os dados do arquivo JSON.
func load_json(directory: String, filename: String) -> Dictionary:
	if not check_directory(directory, filename):
		print_debug("ERROR: File ", filename, "not found in directory ", directory, "!")
		return {}
	var f := FileAccess.open(directory + filename, FileAccess.READ)
	if f == null:
		print_debug("CRITICO: Erro ao abrir arquivo JSON ", directory + filename, "!")
		return {}
	var text: String = f.get_as_text()
	var out: Variant = JSON.parse_string(text)
	if out == null:
		print_debug("CRITICO: Erro ao fazer parse do JSON ", filename, "! O arquivo pode estar mal formatado.")
		return {}
	if typeof(out) != TYPE_DICTIONARY:
		print_debug("CRITICO: JSON ", filename, " nao eh um dicionario! Tipo obtido: ", type_string(typeof(out)))
		return {}
	return out

## Salva um dicionario em JSON no disco.
## [param directory] formato deve ser como [code]c:/example_folder/[/code]. [br]
## [param filename] formato deve ser como [code]base_config.json[/code]. [br]
func save_json(directory: String, filename: String, data: Dictionary) -> void:
	if not check_directory(directory, "", true):
		if not DirAccess.dir_exists_absolute(directory):
			print_debug("CRITICO: Diretorio ", directory, " nao existe!")
			return
	var f := FileAccess.open(directory + filename, FileAccess.WRITE)
	if f == null:
		print_debug("CRITICO: Erro ao abrir arquivo JSON para escrita ", directory + filename, "!")
		return
	f.store_line(JSON.stringify(data, "\t", false))

## Verifica se um dado diretorio e arquivo existem. [param filename] e opcional. [br]
## [param directory] formato deve ser como [code]c:/example_folder/[/code]. [br]
## [param filename] formato deve ser como [code]filename.txt[/code]. [br]
## Retorna true se o diretorio e o arquivo existirem.
func check_directory(directory: String, filename: String = "", disable_msg: bool = false) -> bool:
	var dir = DirAccess.open(directory)
	
	if dir == null:
		if not disable_msg: print_debug("\nCRITICO: Diretorio ", directory, " nao existe!\n")
		return false
	if filename != "" and not dir.file_exists(directory+filename):
		if not disable_msg: print_debug("\nCRITICO: Arquivo ", directory+filename, " nao existe!\n")
		return false
	return true

## Copia um arquivo para outro diretorio. [br]
## [param directory] formato deve ser como [code]c:/example_folder/[/code]. [br]
## [param filename] formato deve ser como [code]filename.txt[/code]. [br]
## [param directory_out] formato deve ser como [code]c:/example_folder/[/code]. [br]
## [param filename_out] formato deve ser como [code]filename.txt[/code], mas nao e obrigatorio. 
## Se nenhum [param filename_out] for informado, [param filename] sera usado.
func copy_file(directory: String, filename: String, directory_out: String, filename_out: String = "") -> void:
	if filename_out == "":
		filename_out = filename
	if not check_directory(directory, filename):
		return
	if not check_directory(directory_out):
		return
	var dir = DirAccess.open(directory)
	var error = dir.copy(directory + filename, directory_out + filename_out)
	if error != OK:
		print_debug("Erro ao copiar o arquivo: %s" % error_string(error))
		return

## Remove um arquivo. [br]
## [param directory] formato deve ser como [code]c:/example_folder/[/code]. [br]
## [param filename] formato deve ser como [code]filename.txt[/code]. [br]
func remove_file(directory: String, filename: String) -> void:
	if not check_directory(directory, filename):
		return
	var dir = DirAccess.open(directory)
	var error = dir.remove(directory + filename)
	if error != OK:
		print_debug("Erro ao remover o arquivo: %s" % error_string(error))
		return

## Recebe uma string e remove todos os caracteres que a tornariam um nome de arquivo invalido. [br]
## [param string] pode ser qualquer String. [br]
## [param optional_charset] pode ser uma lista de caracteres para verificar e remover se encontrados. [br]
## Retorna a nova string sem os caracteres removidos.
func string_to_validfilename(string: String, optional_charset: Array[String] = []) -> String:
	var valid_filename: String = ""
	valid_filename = string
	var counter: int = 0
	var char_set: Array[String] = [":", "/", "\\", "?", "*", "\"", "|", "%", "<", ">"]
	if optional_charset.size() > 0:
		char_set = optional_charset
	while not valid_filename.is_valid_filename():
		for a in char_set.size():
			if valid_filename.find(char_set[a]) > -1:
				valid_filename = valid_filename.replace(char_set[a], "")
		counter += 1
		if counter > 10:
			# Used only if is_valid_filename() return false and the invalid char is not contained in
			#  [param char_set], so invalid char cannot be removed
			print_debug("Nome de arquivo/pasta invalido e irresolvivel: ", valid_filename)
			break
	return valid_filename

## Converte um arquivo para utf8 e salva em um novo arquivo chamado out.csv. [br]
## [param directory] formato deve ser como [code]c:/example_folder/[/code]. [br]
## [param filename] formato deve ser como [code]filename.txt[/code].
func convertto_utf8(directory: String, filename: String, \
  output_directory: String = GV.dir_saida, output_filename: String = "out.csv") -> void:
	var output: Array[String] = []
#	OS.execute("powershell.exe", \
#	  ["-Command", "& {set-location '"+directory+"'; Get-Content '"+filename+"' -Encoding Oem | Out-File '"+\
#	  output_directory+"//"+output_filename+"' -Encoding utf8;}"], \
#	  output, true, false)
	#OS.execute("powershell.exe", \
	  #["-Command", "& {set-location '"+directory+"'; Get-Content '"+filename+"' | Out-File '"+\
	  #output_directory+"//"+output_filename+"' -Encoding utf8;}"], \
	  #output, true, false)
	#  Employs an external executable compiled from a python code to do the conversion.
	var external_script: String = GV.dir_principal + "externo/bin/ansi_to_utf8.exe"
	external_script = ProjectSettings.globalize_path(external_script)
	OS.execute(external_script, \
		[directory+filename, output_directory+output_filename], \
		output, true, false)
	print_debug("utf8 conversion output: ", output)

## Converte um arquivo XLSX para CSV utilizando o executavel externo
## [code]externo/bin/xlsx_to_csv.exe[/code]. Retorna [code]true[/code] se a
## conversao foi bem-sucedida e o arquivo de saida existe.
func converter_xlsx_para_csv(caminho_xlsx: String, saida_csv: String) -> bool:
	var exe: String = GV.dir_principal + "externo/bin/xlsx_to_csv.exe"
	exe = ProjectSettings.globalize_path(exe)
	if not FileAccess.file_exists(exe):
		return false
	var output: Array[String] = []
	OS.execute(exe, [caminho_xlsx, saida_csv], output, true, false)
	return FileAccess.file_exists(saida_csv)

## Executa um processo usando uma chamada do SO.
## [param directory] formato deve ser como [code]c:/example_folder/[/code]. [br]
## [param filename] formato deve ser como [code]filename.txt[/code].
func os_execute(directory: String, filename: String, arguments: PackedStringArray) -> void:
	var path: String = ProjectSettings.globalize_path(directory + filename)
	var output: Array[String] = []
	OS.execute(path, arguments, output, true, false)

## Compacta arquivos (zip). [br]
## [param directory] formato deve ser como [code]c:/example_folder/[/code]. [br]
## [param zip_name] e o nome do arquivo zip de saida. [br]
## [param files] e uma lista de nomes de arquivos para compactar.
func zip_files(directory: String, zip_name: String, files: Array[String]) -> void:
	var filestring: String
	for a in files.size():
		filestring = filestring + " " + files[a]
	var output: Array[String] = []
	OS.execute("powershell.exe", ["-Command", "& {set-location '"+directory+ \
	  "'; tar.exe -a -c -f '"+zip_name+".zip' "+filestring+";}"], output, false, false)
	print_debug("powershell file zip output: ", output)

## Exclui todos os arquivos em um determinado diretorio. [br]
## [param directory] formato deve ser como [code]c:/example_folder/[/code]. [br]
## Se [param include_folders] for true, os diretorios tambem serao excluidos.
func clear_directory(directory: String, include_folders: bool = false) -> int:
	var dir = DirAccess.open(directory)
	var files: PackedStringArray = dir.get_files()
	var directories: PackedStringArray = dir.get_directories()
	var errors: int = 0
	for a in files.size():
		var error_code: int = OS.move_to_trash(directory+files[a])
		if error_code > 0:
			print_debug("ERRO: Erro ao apagar arquivo ", directory+files[a], "! O código do erro é: ", error_code, ".")
			errors += 1
	if include_folders:
		for a in directories.size():
			var error_code: int = OS.move_to_trash(directory+directories[a])
			if error_code > 0:
				print_debug("ERRO: Erro ao apagar arquivo ", directory+files[a], "! O código do erro é: ", error_code, ".")
				errors += 1
	return errors

## Cria um diretorio. [br]
## [param where_to] formato deve ser como [code]c:/example_folder/[/code]. [br]
## [param directory] e o nome da pasta a ser criada dentro de [param where_to].
func create_directory(where_to: String, directory: String) -> void:
	var dir = DirAccess.open(where_to)
	if not dir.dir_exists(directory):
		dir.make_dir(directory)
	else:
		print_debug("Directory ", directory, " already exists in ", where_to, "!")

## Le [param columns] e [param lines] especificos de um arquivo no estilo csv. [br]
## [param directory] formato deve ser como [code]c:/example_folder/[/code]. [br]
## [param filename] formato deve ser como [code]filename.csv[/code]. [br]
## [param columns] e [param lines] sao usados para controlar quais colunas/linhas ler/ignorar. 
## Linhas e colunas comecam na posicao de indice 1, ou seja, para apagar a primeira linha use -1, nao -0. 
## Use valores positivos para incluir colunas/linhas e valores negativos para remover colunas/linhas. 
## Ex.: [-1, -4] remove as colunas 1 e 4 e salva o resto, enquanto [1, 4] salva apenas as colunas 1 e 4. [br]
## [param splitter] e o caractere usado para dividir o arquivo csv. [br]
## Retorna um array que contem arrays de linhas do arquivo. Essencialmente e um array 2D de colunas e linhas.
func read_csvfile(directory: String, filename: String, columns: Array[int] = [], lines: Array[int] = [], splitter = ";") -> Array[Array]:
	columns.sort()
	lines.sort()
	var nof_columns: int = 0
	var temp_arr: Array[Array] = []

	# If multiple [param splitter] informed, check which to use
	var f := FileAccess.open(directory + filename, FileAccess.READ)
	if f == null:
		print_debug("CRITICO: Erro ao abrir arquivo ", directory + filename, "!")
		return []
	if splitter is Array:
		print_debug("Foram informados múltiplos splitter. O arquivo será testado com os múltiplos splitter e será usado " \
		+ "o que resultar em multiplos dados na primeira linha.")
		var splitter_determined: bool = false
		for a in splitter.size():
			var line: Array[String] = general_functions.split(f.get_line().to_lower(), splitter[a])
			print_debug("Testando splitter ", splitter[a])
			if line.size() > 1:
				splitter = splitter[a]
				splitter_determined = true
				print_debug("splitter ", splitter," resultou em uma matriz com multiplos dados e será usado.")
				break
		if not splitter_determined:
			print_debug("ERRO: Nenhum splitter definido na Array foi empregado. Leitura cancelada.")
			return []
		# Volta ao inicio para a leitura efetiva (o handle avancou durante a deteccao do splitter).
		f.seek(0)

	# Read file
	var linecount: int = 0
	while not f.eof_reached():
		var skip_line: bool = false
		if lines.size() != 0:
			for b in lines.size():
				if lines[0] > 0:
					if lines[b]-1 == linecount:
						skip_line = false
						break
					else:
						skip_line = true
				else:
					if abs(lines[b])-1 == linecount:
						skip_line = true
		var line: Array[String] = general_functions.split(f.get_line().to_lower(), splitter)
		if nof_columns == 0: # used to avoid reading last empty line
			nof_columns = line.size()
		if skip_line == false and nof_columns <= line.size():
			if columns.size() == 0:
				temp_arr.append(line)
			else:
				if columns[0] > 0:
					var needed_line: Array[String] = []
					for b in columns.size():
						needed_line.append(line[columns[b]-1])
					temp_arr.append(needed_line)
				else:
					for b in columns.size():
						line.remove_at(abs(columns[b]-1))
					temp_arr.append(line)
		linecount = linecount + 1
		if lines.size() != 0:
			if linecount == lines[lines.size()-1] and lines[0] > 0:
				break;
	return temp_arr

## Le um arquivo de texto, linha por linha, e cria um array contendo os dados do texto. [br]
## [param directory] formato deve ser como [code]c:/example_folder/[/code]. [br]
## [param filename] formato deve ser como [code]filename.csv[/code]. [br]
func read_txt_file(directory: String, filename: String) -> Array[String]:
	var f := FileAccess.open(directory + filename, FileAccess.READ)
	if f == null:
		print_debug("CRITICO: Erro ao abrir arquivo ", directory + filename, "!")
		return []
	var out: Array[String] = []
	while not f.eof_reached():
		out.append(f.get_line())
	return out

## Salva um array de linhas em um arquivo. [br]
## [param directory] formato deve ser como [code]c:/example_folder/[/code]. [br]
## [param filename] formato deve ser como [code]filename.csv[/code]. [br]
## [param data] formato deve ser um array onde cada elemento e uma linha. [br]
func save_text_file(directory: String, filename: String, data: Array[String]) -> void:
	var file_path: String = directory + filename
	var f := FileAccess.open(file_path, FileAccess.WRITE)
	if f == null:
		print_debug("CRITICO: Erro ao abrir arquivo ", file_path, "!")
		return
	for a in data.size():
		f.store_string(data[a])
		f.store_string("\n")
	print_debug("Arquivo texto salvo em:", file_path)

#endregion
