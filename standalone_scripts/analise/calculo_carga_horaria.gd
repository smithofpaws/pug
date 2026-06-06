class_name CalculoCargaHoraria extends Resource
## Funções de cálculo de carga horária: CH vencida por núcleo, percentual de conclusão e créditos por disciplina.
##
## Extraído de [code]analise_historico.gd[/code] como parte da divisão em responsabilidades únicas.

var analise_grades := AnaliseGrades.new()

## Determina a % de disciplinas já finalizadas no total, considerando todos os nucleos
## Formato de [param ch_exigida] deve ser a lista de condições nos arquivos em [code]/arquivos/cargaexigida[/code]. [br]
## Formato de [param ch_vencida] deve ser a saída de [method ch_vencida]  [br]
## Esta função NÃO está finalizada! # TODO
func percentagem_curso(ch_exigida: Dictionary, ch_vencida: Dictionary) -> float:
	var soma_chexigida: float = 0
	var soma_chvencida: float = 0
	for nucleo in ch_exigida.keys():
		soma_chexigida += int(ch_exigida[nucleo])
	for nucleo in ch_vencida.keys():
		soma_chvencida += int(ch_vencida[nucleo])
	# Sem carga exigida cadastrada (soma zero) nao ha denominador: retorna 0 em vez de NaN/inf.
	if soma_chexigida == 0:
		return 0.0
	var percentagem: float = soma_chvencida/soma_chexigida * 100.0
	return percentagem

## Determina a quantidade de horas cursadas separadas por nucleo (e.g. basico, profissionalizante, cccg, extensão, etc). [br]
## Retorna {"ch": {nucleo: horas}, "divergencias": [{codigo, ch_historico, ch_grade}]}. [br]
## Seta [param ch_do_historico] para false usa valores da grade json (default: true usa hist.csv).
func ch_vencida(matricula: String, grade_disciplinas: Dictionary, historico: Dictionary, \
ignorar_matriculada: int = -1, ch_do_historico: bool = true) -> Dictionary:
	var ch_nucleos_historico: Dictionary = {}
	var ch_nucleos_grade: Dictionary = {}
	var divergencias: Array[Dictionary] = []
	for cod_disc in grade_disciplinas.keys():
		for b in historico[matricula]["dados"].size():
			if not (historico[matricula]["dados"][b]["situacao"].begins_with("matr") and ignorar_matriculada == -1)\
			and not (not historico[matricula]["dados"][b]["situacao"].begins_with("matr") and ignorar_matriculada == 1):
				if historico[matricula]["dados"][b]["codigocurriculo"] == cod_disc:
					var ch_hist: int = int(historico[matricula]["dados"][b].get("cargahoraria","0"))
					var ch_grd: int = int(grade_disciplinas[cod_disc].get("ch","0"))
					if ch_hist != ch_grd and ch_hist > 0 and ch_grd > 0:
						divergencias.append({"codigo": cod_disc, "ch_historico": ch_hist, "ch_grade": ch_grd})
					if ch_do_historico:
						var nucleo: String = historico[matricula]["dados"][b].get("estcurricular","")
						ch_nucleos_historico[nucleo] = ch_nucleos_historico.get(nucleo, 0) + ch_hist
					else:
						var nucleo: String = grade_disciplinas[cod_disc].get("nucleo","")
						ch_nucleos_grade[nucleo] = ch_nucleos_grade.get(nucleo, 0) + ch_grd
					break
	var resultado: Dictionary = {"ch": ch_nucleos_historico if ch_do_historico else ch_nucleos_grade}
	if divergencias.size() > 0:
		resultado["divergencias"] = divergencias
	return resultado

## Calcula o numero de creditos para disciplinas de uma determinada matricula. Quando a disciplina 
## estiver contida no [param historico], obtem os créditos por lá. Quando for uma disciplina futura (e.g. 
## "matriculavel"), obtem na grade.
## Formato de [param disc_cursaveis] deve ser um dicionário com as chaves de condições 
## que vem do arquivo [code]base_config.json[/code]. [br]
## Retorna um dicionário contendo chaves que são códigos de disciplinas e para cada chave o respectivo credito.
func creditos_disciplinas(matricula: String, historico: Dictionary, disc_cursaveis: Dictionary, grade_disciplinas: Dictionary) -> Dictionary:
	var creditos: Dictionary = {}
	# Para as disciplinas cursadas, aproveitadas e matriculadas, obtem a ch direto do historico
	for a in historico[matricula]["dados"].size():
		creditos[historico[matricula]["dados"][a]["codigocurriculo"]] = int(historico[matricula]["dados"][a]["cargahoraria"])/15
	# Para as disciplinas em outros estados (matriculavel, seaprovado, etc), pesquisa na grade
	# apenas se o codigo nao veio do historico (evita sobrescrever CH real com CH do json)
	for condicao in disc_cursaveis.keys():
		if condicao != "matriculado_agora" and condicao != "matriculado_agora_aproveitamento":
			for a in disc_cursaveis[condicao].size():
				var cod: String = disc_cursaveis[condicao][a]
				if not creditos.has(cod):
					creditos[cod] = int(analise_grades.info_grade(grade_disciplinas, cod, "ch"))/15
	return creditos
