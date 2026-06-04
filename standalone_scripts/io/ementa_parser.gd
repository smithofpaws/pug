class_name EmentaParser extends Resource
## Converte um arquivo de ementa (.txt) em um dicionário estruturado. [br]
## [br]
## O arquivo .txt usa placeholders [code][[campo]][/code] seguidos pelo valor na linha seguinte. [br]
## Campos de valor único: [param cod_componente], [param ch_tot], [param texto_ementa], etc. [br]
## Campos multivalorados: [param objetivos_especificos], [param ref_basica], [param ref_complementar] —
##   coletam linhas até o próximo placeholder. [br]
## [param obj_esp_geral] é um campo de valor único (objetivo geral específico).

const CAMPOS_VALOR_UNICO: Array[String] = [
	"cod_componente", "nome_componente", "cod_prerequisito",
	"ch_tot", "ch_pres_t", "ch_pres_p", "ch_ead_t", "ch_ead_p", "ch_ext",
	"texto_ementa", "texto_obj_geral"
]

const CAMPOS_MULTIVALOR: Array[String] = [
	"objetivos_especificos", "ref_basica", "ref_complementar"
]

const ESPECIAL_UNICO: String = "obj_esp_geral"


## Converte um array de linhas da ementa em um [Dictionary] estruturado. [br]
## Formato de [param ementa] é o retorno de [method FileHandling.read_txt_file] — [param Array[String]]. [br]
## Retorna: [br]
## { [br]
##   "cod_componente": "AL0001", [br]
##   "nome_componente": "Fundações", [br]
##   "ch_tot": "60", [br]
##   "texto_ementa": "...", [br]
##   "texto_obj_geral": "...", [br]
##   "obj_esp_geral": "...", [br]
##   "objetivos_especificos": ["item1", "item2"], [br]
##   "ref_basica": ["ref1", "ref2"], [br]
##   "ref_complementar": ["ref1"] [br]
## }
func parse(ementa: Array[String]) -> Dictionary:
	var resultado: Dictionary = {}
	for campo in CAMPOS_VALOR_UNICO:
		resultado[campo] = ""
	resultado[ESPECIAL_UNICO] = ""
	for campo in CAMPOS_MULTIVALOR:
		resultado[campo] = []

	var i: int = 0
	while i < ementa.size():
		var linha: String = ementa[i].strip_edges()

		if _eh_placeholder(linha):
			var nome_campo: String = _extrair_nome_campo(linha)
			i += 1

			# Pula linhas vazias após o placeholder
			while i < ementa.size() and ementa[i].strip_edges() == "":
				i += 1

			if CAMPOS_VALOR_UNICO.has(nome_campo) or nome_campo == ESPECIAL_UNICO:
				if i < ementa.size():
					resultado[nome_campo] = ementa[i].strip_edges()
				i += 1
			elif CAMPOS_MULTIVALOR.has(nome_campo):
				while i < ementa.size():
					var sub_linha: String = ementa[i].strip_edges()
					if _eh_placeholder(sub_linha):
						break
					if sub_linha != "":
						resultado[nome_campo].append(sub_linha)
					i += 1
			else:
				i += 1
		else:
			i += 1

	return resultado

static func _eh_placeholder(linha: String) -> bool:
	return linha.begins_with("[[") and linha.ends_with("]]")

static func _extrair_nome_campo(linha: String) -> String:
	return linha.trim_prefix("[[").trim_suffix("]]")
