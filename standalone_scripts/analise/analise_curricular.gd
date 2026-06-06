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

class_name AnaliseCurricular extends Resource
## Funções de análise curricular: pré-requisitos, co-requisitos, equivalências e disciplinas cursáveis.
##
## Extraído de [code]analise_historico.gd[/code] como parte da divisão em responsabilidades únicas. [br]
## [br]
## Os principais parâmetros empregados nesta classe e suas devidas formatações são: [br]
## Formato de [param matricula] deve ser apenas a sequencia numérica da matrícula em formato String. [br]
## Formato de [param historico] deve ser o padrão do historico. [br]
## Formato de [param condicoes] deve ser a lista de condições no arquivo [code]base_config.json[/code]. [br]
## Formato de [param grade_disciplinas] deve ser o dos arquivos em [code]/arquivos/grades[/code]. [br]
## Formato de [param grades_disciplinas_curriculos] deve conter chaves para cada arquivo em [code]/arquivos/grades[/code] 
## e dentro de cada chave o conteúdo destes arquivos. [br]
## Formato de [param equivalencias] deve ser o dos arquivos em [code]/arquivos/equivalencias[/code].

var analise_grades := AnaliseGrades.new()

## Função fundamental da previsão de disciplinas cursáveis. Retorna, para uma dada matrícula, quais disciplinas
## são cursáveis para esta matrícula. [br]
## Formato de [param versao_grade] deve ser a chave composta da grade no padrão
## [code]<cod_curso>_<versao>[/code] (e.g. [code]alec_2023[/code]).
## Não é obrigatório, sendo automaticamente determinado durante a execução da função.
func disciplinas_cursaveis(matricula: String, grades_disciplinas_curriculos: Dictionary, historico: Dictionary, condicoes: Array, equivalencias: Dictionary, versao_grade: String = "") -> Dictionary:
	# FIXME Corrigir a questão de matriculavel com corequisito. Exemplo de fundações: Se só falta fundações e
	# integrado, aparece integrado como matriculável com corequisito. Porém, se a pessoa for matriculada em fundações
	# deixa de aparecer como matriculável com corequisito.

	# Cria uma cópia temporária do histórico para a análise, pois serão aproveitadas algumas disciplinas.
	var historico_da_matricula: Dictionary = historico.duplicate(true)

	# Obtem a lista de codigo de disciplinas que o discente não cursou mas está apto a cursar e
	#  as disciplinas que estará apto a cursar caso aprovado em uma disciplina em andamento.
	var cursaveis: Dictionary = {}
	if condicoes.size() == 0:
		print_debug("CRÍTICO: Não foram informadas as condições para análise. Revisar arquivo de configuração ou alimentação da função.")
	for a in condicoes.size():
		cursaveis[condicoes[a]] = []
	if versao_grade == "":
		versao_grade = detectar_versao_grade(matricula, historico_da_matricula)
	# Guard clause: se a chave detectada nao existe nas grades disponiveis, aborta cedo com
	# log de diagnostico em vez de crashar em [code]grades_disciplinas_curriculos[versao_grade][/code].
	if not grades_disciplinas_curriculos.has(versao_grade):
		print_debug("ERRO: Grade ", versao_grade, " nao encontrada em grades_disciplinas_curriculos ", \
			"para a matricula ", matricula, ". Chaves disponiveis: ", grades_disciplinas_curriculos.keys(), \
			". Retornando dicionario vazio de cursaveis.")
		return cursaveis

	# Calcula CH total concluída (aprovadas + dispensadas) para verificar cargarequisito.
	var ch_total_concluida: float = 0.0
	for dado in historico_da_matricula.get(matricula, {}).get("dados", []):
		if not dado.get("situacao", "").begins_with("matr"):
			ch_total_concluida += float(dado.get("cargahoraria", "0"))

	# Cria uma função lambda que verifica a situação para um determinado código de disciplina
	# e.g. Para AL0223, verifica se está matriculado, se pode se matricular, etc.
	var my_lambda: Callable = func(cod_disc: String, hist_temp: Dictionary) -> void:
		# Primeiro verifica se a disciplina já consta como aprovada/dispensada ou em matrícula.
		var situacao: String = ""
		for a in hist_temp[matricula]["dados"].size():
			if hist_temp[matricula]["dados"][a]["codigocurriculo"].to_lower() == cod_disc:
				if hist_temp[matricula]["dados"][a]["situacao"].begins_with("matr"):
					situacao = "matricula"
				else:
					situacao = "aprovado/dispensado"
				break
		# Depois compara todas disciplinas do curso para ver qual pode cursar agora ou se aprovado.
		if situacao != "aprovado/dispensado":
			var i: int = 0
			var lista_prerequisito: Array[String] = []
			var lista_corequisito: Array[String] = []
			# Obtem lista de prerequisitos
			while grades_disciplinas_curriculos[versao_grade][cod_disc].has("prerequisito"+str(i)):
				lista_prerequisito.append(grades_disciplinas_curriculos[versao_grade][cod_disc]["prerequisito"+str(i)])
				i += 1
			i = 0
			# Obtem lista de corequisitos.
			while grades_disciplinas_curriculos[versao_grade][cod_disc].has("corequisito"+str(i)):
				lista_corequisito.append(grades_disciplinas_curriculos[versao_grade][cod_disc]["corequisito"+str(i)])
				i += 1
			var matr_possivel: bool = false
			var matr_seaprv: bool = false
			var matr_poss_correq: bool = false
			var matr_seaprov_correq: bool = false
			var matriculado: bool = false
			var matr_prereq_do_correc: bool = false
			if lista_prerequisito.size() == 0:
				# Disciplina sem prerequisito é automáticamente matriculável.
				matr_possivel = true
			else:
				# Verifica quantos dos prerequisitos foram concluidos e se estão em matrícula.
				var lista_requisitos_aprov: Array[String] = []
				for a in lista_prerequisito.size():
					for b in hist_temp[matricula]["dados"].size():
						if hist_temp[matricula]["dados"][b]["codigocurriculo"].to_lower() == lista_prerequisito[a].to_lower():
							lista_requisitos_aprov.append(hist_temp[matricula]["dados"][b]["codigocurriculo"].to_lower())
							if hist_temp[matricula]["dados"][b]["situacao"].begins_with("matr"):
								matriculado = true
							break
				# Se não foi aprovado em todos prerequisitos, verifica se tem corequisitos e se este poderá 
				# ser cursado (deve ter o prerequisito do corequisito ou estar matriculado nele).
				# if lista_requisitos_aprov.size() != lista_prerequisito.size():
				if lista_requisitos_aprov.size() != lista_prerequisito.size() or matriculado: # TODO Revisado por LLM. Determinar se causou algum efeito na análise
					var lista_coreq_cursaveis: Array[String] = []
					for a in lista_corequisito.size():
						var j: int = 0
						while grades_disciplinas_curriculos[versao_grade][lista_corequisito[a]].has("prerequisito"+str(j)):
							var prereq_do_corequisito: String = grades_disciplinas_curriculos[versao_grade][lista_corequisito[a]]["prerequisito"+str(j)]
							for b in hist_temp[matricula]["dados"].size():
								if hist_temp[matricula]["dados"][b]["codigocurriculo"].to_lower() == prereq_do_corequisito.to_lower():
									lista_coreq_cursaveis.append(lista_corequisito[a])
									if hist_temp[matricula]["dados"][b]["situacao"].begins_with("matr"):
										matr_prereq_do_correc = true
							j += 1
					# Se existem correquisitos cursaveis, prossegue.
					if lista_coreq_cursaveis.size() > 0:
						# Verifica se os prerequisitos que não são corequisitos já foram concluidos.
						var lista_prereq_semcoreq: Array[String] = []
						for a in lista_prerequisito.size():
							lista_prereq_semcoreq.append(lista_prerequisito[a])
						for a in lista_corequisito.size():
							lista_prereq_semcoreq.erase(lista_corequisito[a])
						var prereq_semcorreq_aprov: int = 0
						for a in lista_prereq_semcoreq.size():
							for b in lista_requisitos_aprov.size():
								if lista_prereq_semcoreq[a] == lista_requisitos_aprov[b]:
									prereq_semcorreq_aprov+=1
						# Se o discente já concluiu todos prerequisitos que não possuem corequisitos, prossegue.
						if prereq_semcorreq_aprov >= lista_prereq_semcoreq.size():
							# Se o discente pode cursar as disciplinas corequisto, pode se matricular imediatamente.
							if lista_coreq_cursaveis.size() == lista_corequisito.size() \
							and lista_coreq_cursaveis.size() > 0 and matr_prereq_do_correc == false:
								matr_poss_correq = true
							# Se o discente está matriculado em uma disciplina que é requisito do corequisito para a que está sendo
							# analisada em [param cod_disc], ele só poderá se matricular em [param cod_disc] caso passe
							# no requisito do corequisito.
							if lista_coreq_cursaveis.size() == lista_corequisito.size() \
							and lista_coreq_cursaveis.size() > 0 and matr_prereq_do_correc:
								matr_seaprov_correq = true
				# Se o discente já concluiu as disciplinas prerequisto, pode se matricular imediatamente.
				if lista_requisitos_aprov.size() == lista_prerequisito.size() and matriculado == false:
					matr_possivel = true
				# Se o discente está matriculado em uma disciplina que é requisito para a que está sendo
				# analisada em [param cod_disc], ele só poderá se matricular em [param cod_disc] caso passe na disciplina.
				if lista_requisitos_aprov.size() == lista_prerequisito.size() and matriculado:
					matr_seaprv = true
			var ch_necessaria: String = grades_disciplinas_curriculos[versao_grade][cod_disc].get("cargarequisito", "")
			if ch_necessaria != "" and ch_necessaria != "0" and ch_total_concluida < float(ch_necessaria):
				matr_possivel = false
				matr_seaprv = false
				matr_poss_correq = false
				matr_seaprov_correq = false
			if situacao == "matricula":
				if matr_possivel:
					cursaveis["matriculado_agora"].append(cod_disc)
				else:
					cursaveis["matricula_irregular"].append(cod_disc)
			if matr_possivel and not situacao == "matricula":
				# Disciplina em aberto e matriculável pois já foi aprovado nos prerequisitos.
				cursaveis["matriculavel"].append(cod_disc)
			if matr_seaprv:
				# Disciplina em aberto e matriculável caso aprovado nos prerequisitos.
				cursaveis["seaprovado"].append(cod_disc)
			if matr_poss_correq:
				# Matrícula é possível desde que concomitantemente matriculado no seu corequisito.
				cursaveis["corequisito_matriculavel"].append(cod_disc)
			if matr_seaprov_correq:
				# Matrícula é possível desde que concomitantemente matriculado no seu corequisito 
				# o que só é possível se se aprovado em uma disciplina que é prerequisito para o corequisito.
				cursaveis["corequisito_seaprovado"].append(cod_disc)

	# Então verificam-se matriculadas que pertencem a outras versões de grades ou cursos.
	# [param disciplinas_outras_grades] contem as disciplinas de outras grades separadas em chaves: 
	# aprovadas/dispensadas e matricula.
	# [param disciplinas_a_serem_aproveitadas] é uma lista de códigos das disciplinas de 
	# outras grades a serem aproveitadas para a [param versao_grade].
	var disciplinas_outras_grades: Dictionary = _disciplinas_outras_grades(matricula, \
	historico_da_matricula, grades_disciplinas_curriculos, versao_grade)
	var disciplinas_a_serem_aproveitadas: Array[Dictionary]
	var codigos_equiv_matricula: Array[String] = []
	cursaveis["matriculado_agora_aproveitamento"] = []
	for key in disciplinas_outras_grades.keys():
		for a in disciplinas_outras_grades[key].size():
			if key == "matricula":
				print_debug("Realizando aproveitamento da disciplina ", disciplinas_outras_grades[key][a]["codigocurriculo"], \
				" - ", disciplinas_outras_grades[key][a]["nomeativcurricular"], " para ", historico[matricula]["nomedoaluno"], ".")
			if key == "aprovado/dispensado":
				# TODO Aqui só imprime que está sendo realizado o aproveitament. Era para fazer algo? Percebi só muito tempo
				# depois de ter feito este código.
				print_debug("Realizando aproveitamento da disciplina ", disciplinas_outras_grades[key][a]["codigocurriculo"], \
				" - ", disciplinas_outras_grades[key][a]["nomeativcurricular"], " para ", historico[matricula]["nomedoaluno"], \
				"(VERIFICAR O # TODO).")

			var disc_temp: Array[String] = analise_grades.para_o_codigo_qual_a_equivalencia(
				disciplinas_outras_grades[key][a]["codigocurriculo"],equivalencias, versao_grade
				)
			for b in disc_temp.size():
				var entry: Dictionary = disciplinas_outras_grades[key][a].duplicate()
				entry["codigocurriculo"] = disc_temp[b]
				disciplinas_a_serem_aproveitadas.append(entry)
				if key == "matricula":
					codigos_equiv_matricula.append(disc_temp[b])

	# Altera o histórico da matrícula, adicionando as disciplinas aproveitaveis.
	# TODO Revisado por LLM. A injeção no histórico é mantida para que a lambda avalie
	# corretamente os pré-requisitos. O pós-processamento abaixo remove os códigos
	# equivalentes das condições normais e os move para _aproveitamento, resolvendo
	# a duplicação conceitual (mesma matrícula aparecendo em duas seções).
	historico_da_matricula = _aproveitar_equivalencias(
		matricula, historico_da_matricula, equivalencias, disciplinas_a_serem_aproveitadas
		)

	# Chama a função lambda para cada código de uma grade curricular.
	for cod_disc in grades_disciplinas_curriculos[versao_grade].keys():
		my_lambda.call(cod_disc, historico_da_matricula)

	# Verifica disciplinas de outros cursos/versões com equivalência para esta grade.
	var equiv_para_versao: Array[String] = analise_grades.determinar_aproveitaveis(equivalencias, versao_grade)
	for chave_equiv in equiv_para_versao:
		var origem: String = chave_equiv.split("-")[0]
		if not grades_disciplinas_curriculos.has(origem):
			continue
		for cod_fonte in equivalencias[chave_equiv].keys():
			cod_fonte = cod_fonte.to_lower()
			# Já verificado pela lambda acima (disciplina na grade do aluno).
			if grades_disciplinas_curriculos[versao_grade].has(cod_fonte):
				continue
			var equivs: Array[String] = analise_grades.para_o_codigo_qual_a_equivalencia(
				cod_fonte, equivalencias, versao_grade)
			if equivs.is_empty():
				continue
			var cod_alvo: String = equivs[0].to_lower()
			# Se o alvo está cursável (pré-requisitos ok na grade do aluno),
			# adiciona o código fonte como alternativa na respectiva condição.
			for cond in condicoes:
				if cond.ends_with("_aproveitamento"):
					continue
				if cond == "matriculado_agora":
					# Matrícula-equivalente já é tratada pela injeção (_aproveitar_equivalencias) + o
					# pós-processamento abaixo, que produzem o código-ALVO (da grade atual) em
					# matriculado_agora_aproveitamento. Adicionar aqui o código-FONTE (de outra grade)
					# duplicaria a disciplina (caso aproveitamento) ou criaria entradas-fantasma (caso a
					# matrícula seja NORMAL, cursada direto na grade do aluno).
					continue
				if cursaveis.has(cond) and cod_alvo in cursaveis[cond]:
					var cond_aprov: String = cond + "_aproveitamento"
					if not cursaveis.has(cond_aprov):
						cursaveis[cond_aprov] = []
					if cod_fonte not in cursaveis[cond_aprov]:
						cursaveis[cond_aprov].append(cod_fonte)
					break

	# TODO Revisado por LLM. Pós-processamento: remove códigos equivalentes de matrícula
	# das condições normais (matriculado_agora, matricula_irregular, etc.) e os move para
	# as versões _aproveitamento, evitando que a mesma matrícula apareça em dobro.
	var processados: Array[String] = []
	for codigo in codigos_equiv_matricula:
		var cod_lower: String = codigo.to_lower()
		if cod_lower in processados:
			continue
		processados.append(cod_lower)
		var encontrado: bool = false
		for cond in condicoes:
			if cond.ends_with("_aproveitamento"):
				continue
			if not cursaveis.has(cond):
				continue
			var idx: int = 0
			while idx < cursaveis[cond].size():
				if str(cursaveis[cond][idx]).to_lower() == cod_lower:
					var valor: String = cursaveis[cond][idx]
					cursaveis[cond].erase(valor)
					var cond_aprov: String = cond + "_aproveitamento"
					if cursaveis.has(cond_aprov):
						cursaveis[cond_aprov].append(valor)
					encontrado = true
				else:
					idx += 1
		if not encontrado:
			cursaveis["matriculado_agora_aproveitamento"].append(codigo)

	# Realiza a análise de equivalências de disciplinas do curriculo, exceto matriculadas.
	cursaveis = analise_grades.obter_equivalencias(cursaveis, equivalencias, versao_grade, condicoes)

	return cursaveis

## Verifica, para uma lista de alunos, as disciplinas matriculadas, matriculáveis, etc. [br]
## Formato de [param lista_alunos] é [[matrícula1, nome1], [matricula2, nome2], [matriculan, nomen]]. [br]
## Retorna um dicionário organizado da seguinte forma: [br]
## O formato de saída é: [br]
## { "número matrícula": { [br]
## "matriculadas": [], [br]
## "seaprovado": [], [br]
## ... [br]
## } [br]
## }
func condicoes_discentes(lista_alunos: Array, historico: Dictionary, condicoes: Array, grades_disciplinas_curriculos: Dictionary, equivalencias: Dictionary, versao_grade: String = "") -> Dictionary:
	var condicoes_discentes: Dictionary
	for a in lista_alunos.size():
		var disc_cursaveis: Dictionary = disciplinas_cursaveis(lista_alunos[a][0], grades_disciplinas_curriculos, \
		historico, condicoes, equivalencias, versao_grade)
		condicoes_discentes[lista_alunos[a][0]] = disc_cursaveis
	return condicoes_discentes

## Verifica, para uma disciplina, a lista de discentes que tem [param condição] com a mesma. [br]
## Formato de [param cod_disciplina] é só o código por extenso (e.g. "al0001"). [br]
## Formato de [param condicoes_discentes] segue o formato de saída de [method condicoes_discentes].
func discentes_disciplina(cod_disciplina: String, condicoes_discentes: Dictionary, condicoes: Array) -> Dictionary:
	var condicoes_discentes_na_disciplina: Dictionary
	for a in condicoes.size():
		condicoes_discentes_na_disciplina[condicoes[a]] = []
	for matricula in condicoes_discentes.keys():
		var cond_disciplinas: Dictionary = condicoes_discentes[matricula]
		# Verifica se o aluno tem alguma condição com a disciplina envolvida (matriculado, matriculavel, etc).
		for a in condicoes.size():
			for b in cond_disciplinas[condicoes[a]].size():
				if cond_disciplinas[condicoes[a]][b] == cod_disciplina:
					condicoes_discentes_na_disciplina[condicoes[a]].append(matricula)
	return condicoes_discentes_na_disciplina

## Verifica que discentes encontram-se matriculados em ambas disciplinas informadas. [br]
## Formato de [param cod_disciplina1] é só o código por extenso (e.g. "al0001"). [br]
## Formato de [param cod_disciplina2] é só o código por extenso (e.g. "al0363"). [br]
## Formato de [param condicoes_discentes] segue o formato de saída de [method condicoes_discentes].
func comparar_discentes_disciplina(cod_disciplina1: String, cod_disciplina2: String, condicoes_discentes: Dictionary, condicoes: Array) -> Dictionary:
	# ~discentes_ambas tem o seguinte formato:
	# { matricula1:
	#     [condicao_disc_1, condicao_disc_2],
	#   matricula2:
	#     [condicao_disc_1, condicao_disc_2],
	# }
	var discentes_ambas: Dictionary
	var condicoes_discentes_na_disciplina1: Dictionary = discentes_disciplina(cod_disciplina1, condicoes_discentes, condicoes)
	var condicoes_discentes_na_disciplina2: Dictionary = discentes_disciplina(cod_disciplina2, condicoes_discentes, condicoes)
	for cond1 in condicoes_discentes_na_disciplina1.keys():
		for a in condicoes_discentes_na_disciplina1[cond1].size():
			for cond2 in condicoes_discentes_na_disciplina2.keys():
				for b in condicoes_discentes_na_disciplina2[cond2].size():
					if condicoes_discentes_na_disciplina1[cond1][a] == condicoes_discentes_na_disciplina2[cond2][b]:
						var temp_matricula: String = condicoes_discentes_na_disciplina1[cond1][a]
						if not discentes_ambas.has(temp_matricula):
							discentes_ambas[temp_matricula] = []
						discentes_ambas[temp_matricula].append([cond1, cond2])
	return discentes_ambas

## Esta função detecta a chave da grade curricular da matrícula desejada no formato
## [code]<cod_curso>_<versao>[/code] (e.g. [code]alec_2023[/code]). [br]
## Combina [code]cod_curso[/code] e [code]versao[/code] de cada linha do histórico do aluno.
## Caso sejam detectadas múltiplas chaves, retorna a mais recente e emite um aviso. [br]
## [param cursos] (opcional) é o dicionário [code]base_config.json:cursos[/code]; usado para
## fallback quando [code]cod_curso[/code] vier vazio (CSV legado): tenta inferir pelo prefixo
## do semestre ou, em último caso, devolve a última grade do primeiro curso configurado.
func detectar_versao_grade(matricula: String, historico: Dictionary, cursos: Dictionary = {}) -> String:
	# Fallback: callers internos (e.g. condicoes_discentes em batch) nao passam cursos;
	# puxa do autoload GV para manter robusto o caminho de inferencia por prefixo.
	if cursos.is_empty():
		cursos = GV.configuracao_base.get("cursos", {})
	var chaves_coletadas: Array[String] = []
	if historico[matricula]["dados"].size() > 0:
		for a in historico[matricula]["dados"].size():
			var linha: Dictionary = historico[matricula]["dados"][a]
			var cod_curso: String = linha.get("cod_curso", "").to_lower().strip_edges()
			var versao: String = linha.get("versao", "").strip_edges()
			# Fallback: tenta inferir cod_curso pelo prefixo do semestre quando ausente.
			if cod_curso == "" and not cursos.is_empty():
				cod_curso = _inferir_cod_curso_por_semestre(linha.get("semestre", ""), cursos)
			if cod_curso == "" or versao == "":
				continue
			var chave: String = cod_curso + "_" + versao
			if not chaves_coletadas.has(chave):
				chaves_coletadas.append(chave)
	if chaves_coletadas.size() > 1:
		chaves_coletadas.sort()
		print_debug("AVISO: Detectadas múltiplas grades para a matrícula ", matricula, \
			": ", ", ".join(chaves_coletadas), ". Adotada a mais recente: ", chaves_coletadas[-1], ".")
	if chaves_coletadas.size() == 0:
		# Último recurso: primeira grade do primeiro curso configurado.
		if not cursos.is_empty():
			var primeiro_cod: String = cursos.keys()[0]
			var grades_curso: Array = cursos[primeiro_cod].get("grades", [])
			if grades_curso.size() > 0:
				chaves_coletadas.append(grades_curso[-1])
		print_debug("ERRO: Não foi possível determinar versão do currículo para a matrícula ", matricula, \
			". Adotado fallback ", chaves_coletadas[-1] if chaves_coletadas.size() > 0 else "<vazio>", ".")
	return chaves_coletadas[-1] if chaves_coletadas.size() > 0 else ""

# Tenta inferir o cod_curso pelo prefixo do semestre (e.g. "EC01" -> "alec") consultando
# [code]cursos[cod].prefixos_semestre[/code]. Retorna string vazia se nada bater.
func _inferir_cod_curso_por_semestre(semestre: String, cursos: Dictionary) -> String:
	if semestre == "":
		return ""
	var sem_upper: String = semestre.to_upper().strip_edges()
	for cod_curso in cursos.keys():
		var prefixos: Array = cursos[cod_curso].get("prefixos_semestre", [])
		for prefixo in prefixos:
			if sem_upper.begins_with(str(prefixo).to_upper()):
				return cod_curso
	return ""

## Obtem, para uma matricula, a relação de disciplinas com código da turma. [br]
## Formato de [param disc_cursaveis] deve ser um dicionário com as chaves de condições 
## que vem do arquivo [code]base_config.json[/code]. [br]
## Formato de [param historico_matricula] deve ser um extrato do [param historico] porém apenas de uma matrícula 
## (e.g. {"nomedoaluno": "adriane arruda", "dados": [matriz_do_historico]}). [br]
## Retorna um dicionário separado nas chaves "matriculado_agora" e "matriculado_agora_aproveitamento", 
## cada chave contendo matrizes, como [[cod_disciplina1, turma1], [cod_disciplina2, turma2]].
func matriculada_com_turma(disc_cursaveis: Dictionary, historico_matricula: Dictionary) -> Dictionary:
	var matriculada_com_turma: Dictionary = {}
	var situacoes_locais: Array[String] = ["matriculado_agora", "matriculado_agora_aproveitamento"]
	for a in situacoes_locais.size():
		matriculada_com_turma[situacoes_locais[a]] = []
	for a in historico_matricula["dados"].size():
		for b in situacoes_locais.size():
			if disc_cursaveis.has(situacoes_locais[b]):
				for c in disc_cursaveis.get(situacoes_locais[b]).size():
					if historico_matricula["dados"][a]["situacao"].begins_with("matr"):
						if historico_matricula["dados"][a]["codigocurriculo"] == disc_cursaveis.get(situacoes_locais[b])[c]:
							var cod_disciplina = historico_matricula["dados"][a]["codigocurriculo"]
							var cod_turma = historico_matricula["dados"][a]["codturma"]
							matriculada_com_turma[situacoes_locais[b]].append([cod_disciplina,cod_turma])
	return matriculada_com_turma

# Aproveita as disciplinas encontradas em [param historico] que foram feitas em grade diferente da atual, usando equivalencias.
# Formato de [param lista_aproveitar] deve ser um Array de Dictionary, cada um com as chaves de uma
# entrada do histórico (codigocurriculo, nomeativcurricular, situacao, etc.). [br]
func _aproveitar_equivalencias(matricula: String, historico: Dictionary, equivalencias: Dictionary, lista_aproveitar: Array) -> Dictionary:
	for a in lista_aproveitar.size():
		var encontrado: bool = false
		for b in historico[matricula]["dados"].size():
			if historico[matricula]["dados"][b]["codigocurriculo"] == lista_aproveitar[a]["codigocurriculo"]:
				encontrado = true
				break
		if not encontrado:
			historico[matricula]["dados"].append(lista_aproveitar[a])
	return historico

# Verifica disciplinas no [param historico] da [param matricula] atual que pertencem a outras versões de grades ou cursos.
# Formato de [param versao_grade] deve ser a chave composta da grade no padrão
# [code]<cod_curso>_<versao>[/code] (e.g. [code]alec_2023[/code]).
func _disciplinas_outras_grades(matricula: String, historico: Dictionary, grade_disciplinas: Dictionary, versao_grade: String = "") -> Dictionary:
	# Retorna a informação separada em um dictionary com as seguintes chaves:
	#  -aprovado/dispensado
	#  -matricula
	# Dentro da chave está a referência completa de dados da disciplina cursada, não só o código.
	var lista_disciplinas: Dictionary = {"matricula": [], "aprovado/dispensado": []}
	# Guard clause: sem grade-alvo valida nao ha o que comparar.
	if not grade_disciplinas.has(versao_grade):
		return lista_disciplinas
	for a in historico[matricula]["dados"].size():
		var situacao: String = ""
		if historico[matricula]["dados"][a]["situacao"].begins_with("matr"):
			situacao = "matricula"
		else:
			situacao = "aprovado/dispensado"
		var dados: Dictionary = historico[matricula]["dados"][a]
		if dados.has("codigocurriculo"):
			if not grade_disciplinas[versao_grade].has(dados["codigocurriculo"]):
				for versao_outras_grades in grade_disciplinas.keys():
					if versao_outras_grades != versao_grade:
						if grade_disciplinas[versao_outras_grades].has(dados["codigocurriculo"]):
							lista_disciplinas[situacao].append(dados)
	return lista_disciplinas
