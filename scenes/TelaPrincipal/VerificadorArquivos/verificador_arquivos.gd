class_name VerificadorArquivos extends ReferenceRect
## Utilizado para carregar e verificar os arquivos adicionados pelo usuário e necessários para 
## funcionamento. [br]

# Classes instanciadas.
var file_handling := FileHandling.new()

## Recebido pelo main em sua criação e vem do arquivo [code]base_config.json[/code]. [br]
var modulos: Dictionary: set = _modulos_atualizado

# Calculado a partir de [param modulos] e contém uma lista de todos arquivos de usuário necessários
var _arquivos: Dictionary

# Calculado a partir de [param modulos] e contém uma lista de todos diretorios de usuário necessários
var _diretorios: Dictionary

# Relação de botões a serem criados para importar arquivos.
# Metadados de UI por arquivo/pasta. A lista de quais botões criar vem de base_config.json
# via _obter_lista("arquivos") e _obter_lista("diretorios"). Entradas com "opcional: true"
# são extras que não constam em modulos.*.arquivos (ex.: saída gerada pelo próprio programa).
var _ui_info: Dictionary = {
	"hist.csv": {
		"endereco": "https://guri.unipampa.edu.br/rpt/relatorios/gerar/1742/M",
		"texto": "Historico",
	},
	"horarios.txt": {
		"endereco": "Gerado pelo programa de horários ao salvar.",
		"texto": "Horarios TXT",
	},
	"horarios.ini": {
		"endereco": "https://drive.google.com/drive/folders/1-no7aQBSt_PJ5Hl2mbBOMm15uvTGC20A",
		"texto": "Horarios INI",
	},
	"email.csv": {
		"endereco": "https://guri.unipampa.edu.br/rpt/relatorios/gerar/1004/M",
		"texto": "Emails",
	},
	"surveys": {
		"texto": "Surveys",
	},
}

func _criar_botoes() -> void:
	for child in $VBoxContainer.get_children():
		child.queue_free()
	var itens: Array[String] = []
	itens.assign(_arquivos.keys() + _diretorios.keys())
	for key in _ui_info.keys():
		if _ui_info[key].get("opcional", false) and not key in itens:
			itens.append(key)
	for key in itens:
		var info: Dictionary = _ui_info.get(key, {})
		if info.is_empty():
			continue
		var selector = load("res://scenes/Complementares/FileSelector/FileSelector.tscn").instantiate()
		selector.id = key
		selector.button_text = info.get("texto", key)
		selector.site_link = info.get("endereco", "")
		# Diretorios e o historico abrem em multi-selecao (OPEN_FILES): o hist.csv pode ser
		# importado como varios arquivos de cursos distintos, concatenados num unico hist.csv.
		if _diretorios.has(key) or key == "hist.csv":
			selector.file_mode = FileDialog.FILE_MODE_OPEN_FILES
		else:
			selector.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		var formatos: Dictionary = GV.configuracao_base.get("formatos_arquivos", {})
		var filtro: String = formatos.get(key, "")
		if not filtro.is_empty():
			selector.filters = [filtro]
		selector.filepath_selected.connect(_on_selector_fileselected)
		selector.folderpath_selected.connect(_on_selector_folderselected)
		selector.multiplefiles_selected.connect(_on_selector_multiplefilesselected)
		$VBoxContainer.add_child(selector)


# Aqui é criada uma lista com o nome dos itens que o programa necessitará.
# A lista é criada baseada nas informações de necessidades de arquivos explicitada em
#  base_config.json. Por exemplo, se [param nome_lista] igual a "arquivos", será criada uma lista
#  com o nome dos arquivos explicitados nas chaves "arquivos" do arquivo .json, sendo
#  a saída algo como ["hist.csv"].
func _obter_lista(nome_lista: String) -> Dictionary:
	var temp_nomes: Array[String] = []
	var lista: Dictionary = {}
	for key in modulos.keys():
		var temp_lista: Array = modulos[key].get(nome_lista, [])
		for a in temp_lista.size():
			var onlist: bool = false
			for b in temp_nomes.size():
				if temp_lista[a] == temp_nomes[b]:
					onlist = true
					break
			if not onlist:
				temp_nomes.append(temp_lista[a])
	for a in temp_nomes.size():
		lista[temp_nomes[a]] = false
	return lista

# Retorna true se as extensões dos arquivos nas pastas estão como esperado
# e.g. Espera-se 2 arquivos .csv e 1 arquivo .html, se esta quantidade bater,
#  retorna true.
func _verificar_extensoes(diretorio: String) -> bool:
	var extension_list: Dictionary
	for key in _arquivos.keys():
		if extension_list.has(key.get_extension()):
			extension_list[key.get_extension()] += 1
		else:
			extension_list[key.get_extension()] = 1
	var dir = DirAccess.open(diretorio)
	var files: PackedStringArray = dir.get_files()
	for a in files.size():
		if extension_list.has(files[a].get_extension()):
			extension_list[files[a].get_extension()] -= 1
	for key in extension_list.keys():
		if extension_list[key] != 0:
			return false
	return true

# Apaga todos arquivos de um dado diretório.
func _limpar_diretorio(dir_name: String) -> void:
	print_debug("Verificando limpeza do diretório '", dir_name,"'...")
	var errors: int = file_handling.clear_directory(dir_name)
	if errors == 0:
		print_debug("Diretório limpo!")

# Chama o conversor de formatos.
func _converter_utf8(dir_in: String, dir_out: String, files: Array) -> void:
	for a in files.size():
		var arquivo_saida: String = files[a]
		print_debug("Convertendo arquivo de entrada ", files[a], " para formato utf-8...")
		file_handling.convertto_utf8(dir_in, files[a], dir_out, arquivo_saida)
		print_debug("Arquivo convertido!")

# Converte o nome dos arquivos para enquadrarem-se nos padrões usados pelo programa e move para a pasta de saida
func _renomear_mover() -> void:
	var dir_temp = DirAccess.open(GV.dir_temp)
	var files: PackedStringArray = dir_temp.get_files()
	for a in files.size():
		print_debug("Analisando arquivo ", files[a], " para renomear...")
		if files[a].get_extension() == "csv":
			print_debug("Arquivo csv encontrado. Verificando dados...")
			var colunas: Array[int] = [3]
			var linhas: Array[int] = [1]
			var temp: Array[Array] = file_handling.read_csvfile(GV.dir_temp, files[a], colunas, linhas, [";", ","])
			if temp[0][0].begins_with("cod"):
				print_debug("Arquivo é hist.csv. Renomeando e movendo para ", GV.dir_saida, ".")
				dir_temp.rename(files[a], GV.dir_saida+"hist.csv")
			elif temp[0][0].begins_with("email"):
				print_debug("Arquivo é email.csv. Renomeando e movendo para ", GV.dir_saida, ".")
				dir_temp.rename(files[a], GV.dir_saida+"email.csv")
			else:
				print_debug("AVISO: CSV nao reconhecido. O arquivo ", files[a], " nao corresponde a hist ou email e sera ignorado.")
		if files[a].get_extension() == "txt":
				print_debug("Arquivo txt encontrado. Verificando dados...")
				print_debug("Arquivo é horarios.txt. Renomeando e movendo para ", GV.dir_saida, ".")
				dir_temp.rename(files[a], GV.dir_saida+"horarios.txt")
		if files[a].get_extension() == "ini":
				print_debug("Arquivo ini encontrado. Verificando dados...")
				print_debug("Arquivo é horarios.ini. Renomeando e movendo para ", GV.dir_saida, ".")
				dir_temp.rename(files[a], GV.dir_saida+"horarios.ini")

# Atualiza a situação dos arquivos utilizando o sistema de cores cinza, verde e vermelha. [br]
# Arquivos opcionais ausentes ficam cinza (não bloqueiam); ausentes obrigatórios ficam vermelhos.
func _atualizar_mostradores() -> void:
	# Função lambda para obter data de criação de arquivo a partir do caminho absoluto.
	var obter_data = func(caminho: String) -> String:
		var file = FileAccess.get_modified_time(caminho)
		var unix_date: Dictionary = Time.get_date_dict_from_unix_time(file)
		var ano: String = str(unix_date["year"])
		var mes: String = str(unix_date["month"])
		var dia: String = str(unix_date["day"])
		return str(ano + "/" + mes + "/" + dia)
	# Define o diretório e obtem os arquivos
	var dir = DirAccess.open(GV.dir_saida)
	var files: PackedStringArray = dir.get_files()
	for key in _arquivos.keys():
		_arquivos[key] = false
	for a in files.size():
		if _arquivos.has(files[a]):
			_arquivos[files[a]] = true

	for child in $VBoxContainer.get_children():
		if "id" in child:
			var info: Dictionary = _ui_info.get(child.id, {})
			var opcional: bool = bool(info.get("opcional", false))
			var dir_base: String = _caminho_dir_base(info)
			var caminho: String = dir_base + child.id
			var existe: bool = FileAccess.file_exists(caminho) if dir_base != GV.dir_saida \
				else _arquivos.get(child.id, false) == true
			if existe:
				child.right_text = obter_data.call(caminho)
				child.status = "green"
			elif opcional:
				child.right_text = ""
				child.status = "gray"
			elif child.id != "surveys":
				child.right_text = obter_data.call(caminho)
				child.status = "red"


# Resolve o diretorio base de [param info] em [member _ui_info]. [param info.dir_base]
# aceita os nomes de propriedades de [GV] ([code]"dir_saida"[/code], [code]"dir_exportacoes"[/code]).
# Sempre retorna terminando com barra.
func _caminho_dir_base(info: Dictionary) -> String:
	var nome: String = info.get("dir_base", "dir_saida")
	var caminho: String
	match nome:
		"dir_exportacoes": caminho = GV.dir_exportacoes
		_: caminho = GV.dir_saida
	if not caminho.ends_with("/"):
		caminho += "/"
	return caminho

#region Setgets
# Obtém a lista de arquivos e diretórios necessários para o funcionamento. Cria novos diretórios se necessário.
func _modulos_atualizado(new_value: Dictionary) -> void:
	modulos = new_value
	_arquivos = _obter_lista("arquivos")
	_diretorios = _obter_lista("diretorios")
	for key in _diretorios.keys():
		file_handling.check_create_dir(GV.dir_saida + key)
	_criar_botoes()
#endregion

#region Sinais
# Chamado em um intervalo de tempo para fazer verificações em arquivos.
func _on_timer_timeout() -> void:
	# Verifica os arquivos na pasta de saida e mostra na tela os que estão corretos
	_atualizar_mostradores()

# Caso selecionado um único arquivo, trata-se do caso de seleção de arquivos como "hist.csv" e outros.
func _on_selector_fileselected(file_path: String, id: String) -> void:
	# Primeiro o diretório temp é limpado
	_limpar_diretorio(GV.dir_temp)
	# Os arquivos são então convertidos e salvos no diretório temp
	var file_name: String = file_path.get_file()
	var folder_path: String = file_path.get_base_dir() + "/"
	_converter_utf8(folder_path, GV.dir_temp, [file_name])
	# Após, verifica-se o nome dos arquivos e estes são renomeados e movidos para o diretório de saída
	_renomear_mover()
	_verificar_extensoes(GV.dir_saida)

# Ainda não há necessidade para uso desta função.
func _on_selector_folderselected(folder_path: String, id: String) -> void:
	print_debug("AVISO: Seleção de pasta não suportada")

# Caso selecionados múltiplos arquivos. Para "hist.csv" concatena os históricos num único arquivo;
# para os demais (ex.: surveys) mantém o comportamento de copiar cada arquivo para a subpasta.
func _on_selector_multiplefilesselected(multiple_file_paths: PackedStringArray, id: String) -> void:
	# Primeiro o diretório temp é limpado
	_limpar_diretorio(GV.dir_temp)
	if id == "hist.csv":
		_importar_hist_concatenado(multiple_file_paths)
	else:
		for a in multiple_file_paths.size():
			var file_name: String = multiple_file_paths[a].get_file()
			var folder_path: String = multiple_file_paths[a].get_base_dir() + "/"
			_converter_utf8(folder_path, GV.dir_saida + id + "/", [file_name])
	# Atualiza imediatamente os indicadores (verde/vermelho) em vez de aguardar o timer.
	_atualizar_mostradores()

# Concatena um ou mais arquivos de histórico num único [code]dados/saida/hist.csv[/code],
# substituindo qualquer hist.csv anterior. Cada arquivo é convertido para UTF-8; mantém-se apenas
# um cabeçalho (o do primeiro arquivo válido) e as linhas de dados são agrupadas por matrícula
# (ler_dados só agrupa matrículas consecutivas). Arquivos que não sejam histórico são ignorados.
func _importar_hist_concatenado(paths: PackedStringArray) -> void:
	var cabecalho: String = ""
	# Mapa matrícula -> linhas de dados, na ordem de primeira aparição (Dictionary preserva ordem).
	var por_matricula: Dictionary = {}
	var ignorados: Array[String] = []
	var convertidos: int = 0
	for i in paths.size():
		var nome_orig: String = paths[i].get_file()
		var pasta: String = paths[i].get_base_dir() + "/"
		var nome_temp: String = "hist_%d.csv" % i
		_converter_utf8(pasta, GV.dir_temp, [nome_orig])
		# convertto_utf8 mantém o nome do arquivo; renomeia para um nome único e estável no temp.
		var dir_temp = DirAccess.open(GV.dir_temp)
		if dir_temp and dir_temp.file_exists(nome_orig):
			dir_temp.rename(nome_orig, nome_temp)
		# Valida que é histórico (coluna 3, linha 1, começa com "cod"), igual a _renomear_mover.
		var det: Array[Array] = file_handling.read_csvfile(GV.dir_temp, nome_temp, [3], [1], [";", ","])
		if det.is_empty() or det[0].is_empty() or not str(det[0][0]).to_lower().begins_with("cod"):
			ignorados.append(nome_orig)
			continue
		var linhas: Array[String] = file_handling.read_txt_file(GV.dir_temp, nome_temp)
		if linhas.size() < 2:
			ignorados.append(nome_orig)
			continue
		if cabecalho == "":
			cabecalho = linhas[0]
		convertidos += 1
		# Linha 0 = cabeçalho (descartado); demais são dados, agrupados por matrícula (coluna 0).
		for j in range(1, linhas.size()):
			var linha: String = linhas[j]
			if linha.strip_edges() == "":
				continue
			var matricula: String = linha.split(";")[0]
			if not por_matricula.has(matricula):
				por_matricula[matricula] = []
			por_matricula[matricula].append(linha)
	if cabecalho == "":
		print_debug("AVISO: Nenhum arquivo de histórico válido foi selecionado. hist.csv não foi alterado.")
		_resumo_importacao_hist(0, 0, ignorados)
		return
	var saida: Array[String] = [cabecalho]
	for matricula in por_matricula:
		for linha in por_matricula[matricula]:
			saida.append(linha)
	file_handling.save_text_file(GV.dir_saida, "hist.csv", saida)
	_resumo_importacao_hist(convertidos, por_matricula.size(), ignorados)

# Exibe um diálogo de resumo da concatenação dos históricos (a tela principal não tem terminal).
func _resumo_importacao_hist(arquivos: int, alunos: int, ignorados: Array[String]) -> void:
	var texto: String
	if arquivos == 0:
		texto = "Nenhum arquivo de histórico válido foi importado."
	else:
		texto = "%d arquivo(s) de histórico concatenado(s) em hist.csv.\n%d aluno(s) no total." \
			% [arquivos, alunos]
	if ignorados.size() > 0:
		texto += "\n\nIgnorado(s) (não reconhecidos como histórico):\n- " + "\n- ".join(ignorados)
	var dialogo := AcceptDialog.new()
	dialogo.title = "Importação de histórico"
	dialogo.dialog_text = texto
	add_child(dialogo)
	dialogo.popup_centered()
	Dialogos.limitar_a_tela(dialogo)
	dialogo.confirmed.connect(dialogo.queue_free)
	dialogo.canceled.connect(dialogo.queue_free)
#endregion
