class_name JsonValidator extends Resource
## Validacao de arquivos JSON carregados pelo programa.
##
## Fornece schemas e validacao para base_config.json, grades, equivalencias e carga exigida.

const STR: String = "String"
const FLT: String = "float"
const INT: String = "int"
const BOOL: String = "bool"
const DICT: String = "Dictionary"
const ARR: String = "Array"

const PREFIXO: String = "VALIDACAO JSON"

## Valida o [code]base_config.json[/code] contra o schema interno.
static func validar_base_config(data: Dictionary) -> bool:
	return _validar(data, _schema_base_config(), "base_config.json")

## Valida um arquivo de grade curricular contra o schema interno.
static func validar_grade(data: Dictionary) -> bool:
	return _validar(data, _schema_grade(), "grade")

## Valida um arquivo de equivalencia contra o schema interno.
static func validar_equivalencia(data: Dictionary) -> bool:
	return _validar(data, _schema_equivalencia(), "equivalencia")

## Valida um arquivo de carga exigida contra o schema interno.
static func validar_carga_exigida(data: Dictionary) -> bool:
	return _validar(data, _schema_carga_exigida(), "carga_exigida")

static func _schema_base_config() -> Dictionary:
	return {
		"diretorios": {"dados": STR},
		"interface": {"escala": FLT, "?escala_min": FLT, "?escala_max": FLT, "?escala_passo": FLT, "?tamanho_fonte": FLT, "?tamanho_fonte_min": FLT, "?tamanho_fonte_max": FLT, "?tamanho_fonte_passo": FLT, "?tamanho_fonte_grade_offset": FLT, "?tamanho_fonte_grade_min": FLT, "?tamanho_fonte_grade_max": FLT, "?tema": STR, "?tamanho_janela": {"largura": INT, "altura": INT}},
		"modulos": {
			"*": {
				"nome": STR,
				"arquivos": ARR,
				"?diretorios": ARR,
				"?enabled": BOOL,
				"?limites": DICT
			}
		},
		"histfile": {"*": FLT},
		"mailfile": {"*": FLT},
		"horarios_txt": {"*": FLT},
		"condicoes": ARR,
		"delimitadores": {"*": ARR},
		"grupos_complementares": {"*": STR},
		"efeitos": {"*": STR},
		"formatos_grade": {"rotulos": ARR, "valores": ARR},
		"cursos": {
			"*": {
				"nome": STR,
				"prefixos_semestre": ARR,
				"turmas": ARR,
				"grades": ARR
			}
		}
	}


static func _schema_grade() -> Dictionary:
	return {
		"*": {
			"nome": STR,
			"semestre": STR,
			"ch": STR
		}
	}


static func _schema_equivalencia() -> Dictionary:
	return {
		"*": [STR, ARR]
	}


static func _schema_carga_exigida() -> Dictionary:
	return {
		"*": STR
	}


static func _validar(data: Variant, schema: Variant, nome_arquivo: String, caminho: String = "") -> bool:
	if not _checar_tipo(data, schema, nome_arquivo, caminho):
		return false

	if schema is Dictionary and data is Dictionary:
		var valido := true
		for chave: Variant in schema.keys():
			var caminho_campo: String = caminho + "." + chave if caminho != "" else chave

			if chave == "*":
				var sub_schema: Variant = schema["*"]
				for chave_dado: Variant in data.keys():
					var caminho_coringa: String = caminho + "[\"" + str(chave_dado) + "\"]" if caminho != "" else str(chave_dado)
					if not _validar(data[chave_dado], sub_schema, nome_arquivo, caminho_coringa):
						valido = false
			elif chave.begins_with("?"):
				var chave_real: String = chave.substr(1)
				if data.has(chave_real):
					if not _validar(data[chave_real], schema[chave], nome_arquivo, caminho_campo.replace("?", "")):
						valido = false
			else:
				if not data.has(chave):
					push_warning(PREFIXO + ": Campo obrigatorio '" + chave + "' ausente em " + nome_arquivo + " -> " + caminho)
					valido = false
				else:
					if not _validar(data[chave], schema[chave], nome_arquivo, caminho_campo):
						valido = false
		return valido

	return true


static func _checar_tipo(value: Variant, expected: Variant, nome_arquivo: String, caminho: String) -> bool:
	if expected is Array:
		for e in expected:
			if _checar_tipo(value, e, nome_arquivo, caminho):
				return true
		var tipos_str: String = ""
		for e in expected:
			tipos_str += str(e) + " | "
		tipos_str = tipos_str.trim_suffix(" | ")
		push_warning(PREFIXO + ": Tipo esperado " + tipos_str + " em " + nome_arquivo + " -> " + caminho + ", obtido " + type_string(typeof(value)))
		return false
	if not expected is String:
		if expected is Dictionary and typeof(value) != TYPE_DICTIONARY:
			push_warning(PREFIXO + ": Tipo esperado Dictionary em " + nome_arquivo + " -> " + caminho + ", obtido " + type_string(typeof(value)))
			return false
		return true

	match expected:
		STR:
			if typeof(value) != TYPE_STRING:
				push_warning(PREFIXO + ": Tipo esperado String em " + nome_arquivo + " -> " + caminho + ", obtido " + type_string(typeof(value)))
				return false
		FLT:
			if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
				push_warning(PREFIXO + ": Tipo esperado float em " + nome_arquivo + " -> " + caminho + ", obtido " + type_string(typeof(value)))
				return false
		INT:
			if typeof(value) != TYPE_INT:
				push_warning(PREFIXO + ": Tipo esperado int em " + nome_arquivo + " -> " + caminho + ", obtido " + type_string(typeof(value)))
				return false
		BOOL:
			if typeof(value) != TYPE_BOOL:
				push_warning(PREFIXO + ": Tipo esperado bool em " + nome_arquivo + " -> " + caminho + ", obtido " + type_string(typeof(value)))
				return false
		DICT:
			if typeof(value) != TYPE_DICTIONARY:
				push_warning(PREFIXO + ": Tipo esperado Dictionary em " + nome_arquivo + " -> " + caminho + ", obtido " + type_string(typeof(value)))
				return false
		ARR:
			if typeof(value) != TYPE_ARRAY:
				push_warning(PREFIXO + ": Tipo esperado Array em " + nome_arquivo + " -> " + caminho + ", obtido " + type_string(typeof(value)))
				return false
	return true
