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

class_name AnaliseHistorico extends Resource
## Funções específicas ligadas ao histórico dos discentes.
##
## Retornam dados ligados ao arquivo [code]/dados/saida/hist.csv[/code] e seu correspondente na memória, [param historico].
## Podem cruzar dados com as grades curriculares de [code]/arquivos/grades[/code] entre outros dados. [br]
## [br]
## Os principais parâmetros empregados nesta classe e suas devidas formatações são: [br]
## Formato de [param matricula] deve ser apenas a sequencia numérica da matrícula em formato String. [br]
## Formato de [param historico] deve ser o padrão do historico. [br]
## Formato de [param condicoes] deve ser a lista de condições no arquivo [code]base_config.json[/code]. [br]
## Formato de [param grade_disciplinas] deve ser o dos arquivos em [code]/arquivos/grades[/code]. [br]
## Formato de [param grades_disciplinas_curriculos] deve conter chaves para cada arquivo em [code]/arquivos/grades[/code] 
## e dentro de cada chave o conteúdo destes arquivos. [br]
## Formato de [param equivalencias] deve ser o dos arquivos em [code]/arquivos/equivalencias[/code]. [br]
## [br]
## [b]Nota:[/b] Esta classe agora delega a maior parte da lógica para classes especializadas:
## [AnaliseCurricular], [AnaliseReprovacoes] e [CalculoCargaHoraria].

# Classes instanciadas (delegação).
var analise_curricular := AnaliseCurricular.new()
var analise_reprovacoes := AnaliseReprovacoes.new()
var calculo_carga_horaria := CalculoCargaHoraria.new()

## Cria uma lista de alunos a partir do historico, retornando uma Array de [matricula, nome]. [br]
## Formato de [param historico] deve ser o padrao do historico.
func criar_lista_alunos(historico: Dictionary) -> Array[Array]:
	var lista: Array[Array] = []
	for key in historico.keys():
		lista.append([key, historico[key]["nomedoaluno"]])
	return lista

## Retorna os códigos das disciplinas já concluídas (aprovadas ou dispensadas) de uma [param matricula]. [br]
## Formato de [param matricula] deve ser apenas a sequencia numérica da matrícula em formato String. [br]
## Formato de [param historico] deve ser o padrão do histórico. [br]
## Disciplinas em situação de matrícula ("matr") não são consideradas concluídas.
func disciplinas_concluidas(matricula: String, historico: Dictionary) -> Array[String]:
	var concluidas: Array[String] = []
	for dado in historico.get(matricula, {}).get("dados", []):
		var situacao: String = str(dado.get("situacao", "")).to_lower()
		if situacao.begins_with("aprovado") or situacao.begins_with("dispensado"):
			var codigo: String = str(dado.get("codigocurriculo", "")).to_lower()
			if codigo != "" and not concluidas.has(codigo):
				concluidas.append(codigo)
	return concluidas

## Função fundamental da previsão de disciplinas cursáveis. Retorna, para uma dada matrícula, quais disciplinas
## são cursáveis para esta matrícula. [br]
## Formato de [param versao_grade] deve ser a chave composta da grade no padrão
## [code]<cod_curso>_<versao>[/code] (e.g. [code]alec_2023[/code]).
## Não é obrigatório, sendo automaticamente determinado durante a execução da função.
func disciplinas_cursaveis(matricula: String, grades_disciplinas_curriculos: Dictionary, historico: Dictionary, condicoes: Array[String], equivalencias: Dictionary, versao_grade: String = "") -> Dictionary:
	return analise_curricular.disciplinas_cursaveis(matricula, grades_disciplinas_curriculos, historico, condicoes, equivalencias, versao_grade)

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
func condicoes_discentes(lista_alunos: Array[Array], historico: Dictionary, condicoes: Array, grades_disciplinas_curriculos: Dictionary, equivalencias: Dictionary, versao_grade: String = "") -> Dictionary:
	return analise_curricular.condicoes_discentes(lista_alunos, historico, condicoes, grades_disciplinas_curriculos, equivalencias, versao_grade)

## Verifica, para uma disciplina, a lista de discentes que tem [param condição] com a mesma. [br]
## Formato de [param cod_disciplina] é só o código por extenso (e.g. "al0001"). [br]
## Formato de [param condicoes_discentes] segue o formato de saída de [method AnaliseHistorico.condicoes_discentes]. [br]
## [param matriculas_reais] (opcional): ver [method AnaliseCurricular.discentes_disciplina].
func discentes_disciplina(cod_disciplina: String, condicoes_discentes: Dictionary, condicoes: Array, matriculas_reais: Dictionary = {}) -> Dictionary:
	return analise_curricular.discentes_disciplina(cod_disciplina, condicoes_discentes, condicoes, matriculas_reais)

## Verifica que discentes encontram-se matriculados em ambas disciplinas informadas. [br]
## Formato de [param cod_disciplina1] é só o código por extenso (e.g. "al0001"). [br]
## Formato de [param cod_disciplina2] é só o código por extenso (e.g. "al0363"). [br]
## Formato de [param condicoes_discentes] segue o formato de saída de [method AnaliseHistorico.condicoes_discentes]. [br]
## [param matriculas_reais] (opcional): ver [method AnaliseCurricular.discentes_disciplina].
func comparar_discentes_disciplina(cod_disciplina1: String, cod_disciplina2: String, condicoes_discentes: Dictionary, condicoes: Array, matriculas_reais: Dictionary = {}) -> Dictionary:
	return analise_curricular.comparar_discentes_disciplina(cod_disciplina1, cod_disciplina2, condicoes_discentes, condicoes, matriculas_reais)

## Índice das matrículas atuais por código REAL do histórico: [code]{cod_lower: [matricula, ...]}[/code].
## Ver [method AnaliseCurricular.indice_matriculas_reais].
func indice_matriculas_reais(historico: Dictionary) -> Dictionary:
	return analise_curricular.indice_matriculas_reais(historico)

## Esta função detecta a chave da grade curricular da matrícula desejada no formato
## [code]<cod_curso>_<versao>[/code]. [br]
## Combina [code]cod_curso[/code] e [code]versao[/code] de cada linha do histórico do aluno.
## Caso sejam detectadas múltiplas chaves, retorna a mais recente. [br]
## [param cursos] (opcional) é o dicionário [code]base_config.json:cursos[/code] usado para
## fallback quando [code]cod_curso[/code] vier vazio na linha do histórico.
func detectar_versao_grade(matricula: String, historico: Dictionary, cursos: Dictionary = {}) -> String:
	return analise_curricular.detectar_versao_grade(matricula, historico, cursos)

## Retorna o [code]cod_curso[/code] dono da [param grade_nome] (chave [code]<cod_curso>_<versao>[/code]),
## conforme [code]cursos.<cod>.grades[/code] em [param cursos]. Vazio se a grade nao estiver cadastrada.
func curso_da_grade(grade_nome: String, cursos: Dictionary) -> String:
	return analise_curricular.curso_da_grade(grade_nome, cursos)

## Verifica algumas questões do histórico: [br]
##  - Se existem disciplinas no histórico que não estão nas grades; [br]
##  - Se alguma disciplina de outro semestre encontra-se em aberto. [br]
## Formato de [param grades_disciplinas_curriculos] deve conter múltiplas grades, com chave no padrão
## [code]<cod_curso>_<versao>[/code]. Exemplo: [br]
## { [br]
## "alec_2010": Dicionário copia de [code]/arquivos/grades/alec_2010.json[/code], [br]
## "alec_2023": Dicionário copia de [code]/arquivos/grades/alec_2023.json[/code] [br]
## }
## Retorna uma matriz [codigo, nome_da_disciplina] das disciplinas que não foram encontradas nas grades.
func revisar_historico(historico: Dictionary, grades_disciplinas_curriculos: Dictionary, matricula: String = "", print: bool = true) -> Array[Array]:
# TODO Revisado por LLM. Saída alterada de Array[String] para Array[Array] ([codigo, nome]).
	var contador_verificacao: int = 0
	for key in grades_disciplinas_curriculos.keys():
		# Aqui é verificado se foi fornecido o formato correto de variável para a função.
		# Caso detecte vários "al" significa que [param grades_disciplinas_curriculos] está direto com a grade.
		if key.left(2) == "al":
			contador_verificacao += 1
		if contador_verificacao > 5:
			break
	if contador_verificacao > 5:
		print_debug("CRÍTICO: Foi fornecido o formato errado para ~grades_disciplinas_curriculos a função!")
		push_warning("CRÍTICO: Foi fornecido o formato errado para ~grades_disciplinas_curriculos a função!")
		return []
	if matricula == "":
		print_debug("Revisando histórico...")
	else:
		print_debug("Revisando histórico para matrícula ", matricula, "...")
	# Indice de todos os codigos de disciplina validos (em minusculas) presentes em qualquer grade,
	# construido uma unica vez para tornar a verificacao por disciplina O(1) em vez do laco aninhado.
	var disciplinas_validas: Dictionary = {}
	for key_b in grades_disciplinas_curriculos.keys():
		for key_c in grades_disciplinas_curriculos[key_b].keys():
			disciplinas_validas[key_c.to_lower()] = true
	# Grupos genericos que nao representam disciplinas reais e nao devem ser listados.
	var grupos_ignorados := {"grupo i": true, "grupo ii": true, "grupo iii": true, "grupo iv": true}
	var lista_disc: Array[Array]
	# Codigos ja adicionados a lista_disc, para evitar duplicatas sem busca linear.
	var ja_listadas: Dictionary = {}
	for key in historico.keys():
		if matricula == "" or matricula == key:
			for a in historico[key]["dados"].size():
				var cod: String = historico[key]["dados"][a]["codigocurriculo"]
				var cod_lower := cod.to_lower()
				if disciplinas_validas.has(cod_lower) or ja_listadas.has(cod_lower) \
				or grupos_ignorados.has(cod_lower):
					continue
				ja_listadas[cod_lower] = true
				lista_disc.append([cod, historico[key]["dados"][a]["nomeativcurricular"]])
	if lista_disc.size() > 0 and print:
		print_debug("Alguns alunos cursaram disciplinas não incluídas na(s) seguinte(s) grade(s) curricular(es):\n\n"\
		+ str(grades_disciplinas_curriculos.keys()) + "\n" + "As disciplinas faltantes são: ")
		for a in lista_disc.size():
			print(lista_disc[a][0] + " " + lista_disc[a][1])
	elif matricula == "":
		print_debug("Todas disciplinas foram encontradas nas grades curriculares!")
	# Verifica disciplinas em aberto (não finalizadas por docentes).
	var contador_erro: int = 0
	if matricula == "":
		var time: Dictionary = Time.get_date_dict_from_system()
		var semestre: String = GeneralFunctions.semestre_atual()
		for matr in historico.keys():
			for a in historico.get(matr, {}).get("dados",[]).size():
				if (int(historico[matr]["dados"][a].get("ano","")) == time["year"]\
				and int(historico[matr]["dados"][a].get("semestre","")) != int(semestre))\
				or int(historico[matr]["dados"][a].get("ano","")) < time["year"]:
					if historico[matr]["dados"][a].get("situacao","").begins_with("matr"):
						print_debug("AVISO: Revisar matricula da disciplina ", historico[matr]["dados"][a].get("nomeativcurricular",""), \
						" para o discente ", historico[matr]["nomedoaluno"], " com professor ",\
						historico[matr]["dados"][a].get("professor",""), ". Parece estar em aberto e ser de semestre anterior.")
						contador_erro += 1
			if contador_erro > 40:
				print_debug("Possivel troca de semestre detectada. Aguardar aprovação para realizar a verificação novamente.")
				break
	return lista_disc

## Remove do [param historico] as disciplinas que não se enquadrem na [param regra]. Exemplo: [br]
## Caso se queira manter apenas as disciplinas aprovadas, dispensadas e em matricula, definir 
## [param chave] como "situação" e [param regra] como ["aprovado", "dispensado", "matr"] 
## (apenas "matr" pois a busca é feita pelo inicio, evitando acento"). 
## Assim, obtém-se o seguinte: [br]
##  - Aprovado -> é mantido [br]
##  - Dispensado sem nota -> é mantido [br]
##  - Matricula -> é mantido [br]
##  - SOD -> é removido [br]
##  - Trancamento Total -> é removido [br]
##  - Trancamento Parcial -> é removido [br]
##  - Disciplina Não Concluida -> é removido [br]
## [code]Atenção:[/code] Esta função altera o [param historico] original (mutação in-place).
func simplificar_historico(historico: Dictionary, chave: String, regra: Array[String]) -> void:
	var temp_regra: String = ""
	temp_regra = regra[0]
	for a in range(1,regra.size(),1):
		temp_regra = temp_regra + ", " + regra[a]
	print_debug("Simplificando histórico, mantendo apenas ", temp_regra, ".")
	var counter: int = 0
	for key in historico.keys():
		var a = 0
		while a < historico[key]["dados"].size():
			var regra_verificada: bool = false
			for reg in regra.size():
				if historico[key]["dados"][a][chave].begins_with(regra[reg]):
					regra_verificada = true
					break
			if not regra_verificada:
				historico[key]["dados"].remove_at(a)
				counter += 1
				a -= 1
			a += 1
	print_debug("Histórico simplificado. Foram removidas ", counter, " linhas.")

## Cria uma lista de disciplinas que se enquadram em determinadas [param situacao]. Exemplo: [br]
## Se [param situacao] é ["reprovado com nota", "Reprovado por Frequência"], serão retornadas as disciplinas 
## reprovadas por nota e por frequência. [br]
## Retorna o [param lista_situacoes] no seguinte formato: [br]
## { [br]
## "2410102467": { [br]
## "reprovado com nota": ["al0005", "al0010", "al0015", "al0044", "al0170", "al0044", "al0126"] [br]
## }, [br]
## "2010100557": { [br]
## "reprovado com nota": ["al0005", "al0015", "al0010"] [br]
## } [br]
## }
func listar_situacao(historico: Dictionary, situacao: Array[String]) -> Dictionary:
	return analise_reprovacoes.listar_situacao(historico, situacao)

## Conta as reprovações por disciplina para cada matrícula. [br]
## Formato de [param lista_situacoes] deve ser a saída de [method listar_situacao]. [br]
## Retorna um dicionário com a contagem de reprovações por matrícula, situação e disciplina.
func processar_reprovacoes(lista_situacoes: Dictionary) -> Dictionary:
	return analise_reprovacoes.analise_reprovacoes(lista_situacoes)

## Calcula o índice de aprovação semestre a semestre de cada matrícula do [param historico]
## (percentual de disciplinas aprovadas dentre as cursadas em cada período). [br]
## Exige o histórico COMPLETO, antes de [method simplificar_historico] — ver
## [method AnaliseReprovacoes.indice_aprovacao].
func indice_aprovacao_todos(historico: Dictionary, limite_reprovacao_estagio: float = 0.6) -> Dictionary:
	return analise_reprovacoes.indice_aprovacao_todos(historico, limite_reprovacao_estagio)

## Aprova todos discentes em todas disciplinas em situação de matrícula. [br]
## [code]Atenção:[/code] Esta função altera o [param historico] original (mutação in-place).
func aprovar_matriculados(historico: Dictionary) -> void:
	analise_reprovacoes.aprovar_matriculados(historico)

## Determina a % de disciplinas já finalizadas no total, considerando todos os nucleos
## Formato de [param ch_exigida] deve ser a lista de condições nos arquivos em [code]/arquivos/cargaexigida[/code]. [br]
## Formato de [param ch_vencida] deve ser a saída de [method AnaliseHistorico.ch_vencida]  [br]
## Esta função NÃO está finalizada! # TODO
func percentagem_curso(ch_exigida: Dictionary, ch_vencida: Dictionary) -> float:
	return calculo_carga_horaria.percentagem_curso(ch_exigida, ch_vencida)

## Determina a quantidade de horas cursadas separadas por nucleo (e.g. basico, profissionalizante, cccg, extensão, etc). [br]
## Retorna {"ch": {nucleo: horas}, "divergencias": [{codigo, ch_historico, ch_grade}]}. [br]
## Seta [param ch_do_historico] para false usa valores da grade json (default: true usa hist.csv).
func ch_vencida(matricula: String, grade_disciplinas: Dictionary, historico: Dictionary, ignorar_matriculada: int = -1, ch_do_historico: bool = true) -> Dictionary:
	return calculo_carga_horaria.ch_vencida(matricula, grade_disciplinas, historico, ignorar_matriculada, ch_do_historico)

## Calcula o numero de creditos para disciplinas de uma determinada matricula. Quando a disciplina 
## estiver contida no [param historico], obtem os créditos por lá. Quando for uma disciplina futura (e.g. 
## "matriculavel"), obtem na grade.
## Formato de [param disc_cursaveis] deve ser um dicionário com as chaves de condições 
## que vem do arquivo [code]base_config.json[/code]. [br]
## Retorna um dicionário contendo chaves que são códigos de disciplinas e para cada chave o respectivo credito.
func creditos_disciplinas(matricula: String, historico: Dictionary, disc_cursaveis: Dictionary, grade_disciplinas: Dictionary) -> Dictionary:
	return calculo_carga_horaria.creditos_disciplinas(matricula, historico, disc_cursaveis, grade_disciplinas)

## Obtem, para uma matricula, a relação de disciplinas com código da turma. [br]
## Formato de [param disc_cursaveis] deve ser um dicionário com as chaves de condições 
## que vem do arquivo [code]base_config.json[/code]. [br]
## Formato de [param historico_matricula] deve ser um extrato do [param historico] porém apenas de uma matrícula 
## (e.g. {"nomedoaluno": "adriane arruda", "dados": [matriz_do_historico]}). [br]
## Retorna um dicionário separado nas chaves "matriculado_agora" e "matriculado_agora_aproveitamento", 
## cada chave contendo matrizes, como [[cod_disciplina1, turma1], [cod_disciplina2, turma2]].
func matriculada_com_turma(disc_cursaveis: Dictionary, historico_matricula: Dictionary) -> Dictionary:
	return analise_curricular.matriculada_com_turma(disc_cursaveis, historico_matricula)
