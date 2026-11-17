class_name ImportadorPreferencias extends RefCounted
## Pipeline de importação de um arquivo de preferências de horário de professor: [br]
## xlsx → csv (via [code]xlsx_to_csv.exe[/code] em [code]externo/bin/[/code]), reencodificação
## Windows-1252 → UTF-8 quando necessário (conversão nativa,
## [method FileHandling.convertto_utf8]) e cópia para o diretório de regras com o nome original.
## Sem UI: o módulo imprime o resultado no terminal.

var _file_handling: FileHandling
var _diretorio_regras: String
var _dir_temp: String

## Configura as referências do módulo-pai. [param dir_temp] é o diretório de arquivos temporários
## (intermediário xlsx→csv).
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

	# convertto_utf8 detecta o encoding: converte Windows-1252 ou copia o que ja e UTF-8.
	DirAccess.make_dir_recursive_absolute(_diretorio_regras)
	if not _file_handling.convertto_utf8(csv_para_importar.get_base_dir() + "/", \
			csv_para_importar.get_file(), _diretorio_regras + "/", nome_arquivo):
		_limpar_temp(temp_xlsx)
		return {"ok": false, "mensagem": "Erro ao salvar arquivo em " + _diretorio_regras}
	var destino_final: String = _diretorio_regras + "/" + nome_arquivo

	_limpar_temp(temp_xlsx)
	return {"ok": true, "mensagem": "Importado: " + destino_final}

# Remove o csv intermediário da conversão xlsx, se houver.
func _limpar_temp(temp_xlsx: String) -> void:
	if not temp_xlsx.is_empty():
		DirAccess.remove_absolute(temp_xlsx)
