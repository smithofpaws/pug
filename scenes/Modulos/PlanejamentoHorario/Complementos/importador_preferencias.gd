class_name ImportadorPreferencias extends RefCounted
## Pipeline de importação de um arquivo de preferências de horário de professor: [br]
## xlsx → csv (via [code]xlsx_to_csv.exe[/code] em [code]externo/bin/[/code]), reencodificação
## Windows-1252 → UTF-8 quando necessário (via [code]ansi_to_utf8.exe[/code]) e cópia para o
## diretório de regras com o nome original. Sem UI: o módulo imprime o resultado no terminal.

var _file_handling: FileHandling
var _diretorio_regras: String
var _dir_temp: String

## Configura as referências do módulo-pai. [param dir_temp] é o diretório de arquivos temporários
## (intermediários xlsx→csv e de reencodificação).
func configurar(file_handling: FileHandling, diretorio_regras: String, dir_temp: String) -> void:
	_file_handling = file_handling
	_diretorio_regras = diretorio_regras
	_dir_temp = dir_temp

## Importa o arquivo de preferências em [param caminho] para o diretório de regras, convertendo
## encoding e formato conforme necessário. Retorna [code]{"ok": bool, "mensagem": String}[/code]
## para o módulo exibir no terminal.
func importar(caminho: String) -> Dictionary:
	var ext: String = caminho.get_extension().to_lower()
	var nome_base: String = caminho.get_file().trim_suffix("." + ext)
	var nome_arquivo: String = nome_base + ".csv"

	var csv_para_importar: String = caminho
	var temp_xlsx: String = ""
	if ext == "xlsx":
		DirAccess.make_dir_recursive_absolute(_dir_temp)
		temp_xlsx = _dir_temp + nome_arquivo
		if not _file_handling.converter_xlsx_para_csv(caminho, temp_xlsx):
			return {"ok": false, "mensagem": "Conversor .xlsx nao encontrado. " + \
				"Coloque xlsx_to_csv.exe em externo/bin/ para importar arquivos Excel."}
		csv_para_importar = temp_xlsx

	# Detecta encoding não-UTF-8 pelo caractere de substituição na decodificação de teste.
	var precisa_conversao: bool = false
	var f := FileAccess.open(csv_para_importar, FileAccess.READ)
	if f != null:
		var raw: PackedByteArray = f.get_buffer(f.get_length())
		f.close()
		var teste_utf8: String = raw.get_string_from_utf8()
		precisa_conversao = "�" in teste_utf8

	var destino_final: String
	if precisa_conversao:
		DirAccess.make_dir_recursive_absolute(_dir_temp)
		var temp_nome: String = nome_arquivo
		_file_handling.convertto_utf8(csv_para_importar.get_base_dir() + "/", nome_arquivo, _dir_temp, temp_nome)
		var temp_path: String = _dir_temp + temp_nome
		var utf8_file := FileAccess.open(temp_path, FileAccess.READ)
		if utf8_file == null:
			_limpar_temp(temp_xlsx)
			return {"ok": false, "mensagem": "Erro ao ler arquivo convertido: " + temp_path}
		var utf8_bytes: PackedByteArray = utf8_file.get_buffer(utf8_file.get_length())
		utf8_file.close()
		DirAccess.make_dir_recursive_absolute(_diretorio_regras)
		var destino := FileAccess.open(_diretorio_regras + "/" + nome_arquivo, FileAccess.WRITE)
		if destino == null:
			DirAccess.remove_absolute(temp_path)
			_limpar_temp(temp_xlsx)
			return {"ok": false, "mensagem": "Erro ao salvar arquivo em " + _diretorio_regras}
		destino.store_buffer(utf8_bytes)
		destino.close()
		DirAccess.remove_absolute(temp_path)
		destino_final = _diretorio_regras + "/" + nome_arquivo
	else:
		DirAccess.make_dir_recursive_absolute(_diretorio_regras)
		var err := DirAccess.copy_absolute(csv_para_importar, _diretorio_regras + "/" + nome_arquivo)
		if err != OK:
			_limpar_temp(temp_xlsx)
			return {"ok": false, "mensagem": "Erro ao copiar arquivo para " + _diretorio_regras}
		destino_final = _diretorio_regras + "/" + nome_arquivo

	_limpar_temp(temp_xlsx)
	return {"ok": true, "mensagem": "Importado: " + destino_final}

# Remove o csv intermediário da conversão xlsx, se houver.
func _limpar_temp(temp_xlsx: String) -> void:
	if not temp_xlsx.is_empty():
		DirAccess.remove_absolute(temp_xlsx)
