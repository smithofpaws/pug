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

class_name AnaliseHorarios extends Resource
## Funções para análises gerais relacionadas a horários.
##
## Retornam informações ligadas somente a arquivos contídos em [code]/dados/saida/[/code], como
## [code]horarios.txt[/code] e [code]horarios.ini[/code]. [br]
## [br]
## Os principais parâmetros empregados nesta classe e suas devidas formatações são: [br]
## Formato de [param horarios_ini] deve ser conforme [method horarios_exe.carregar_horarios_ini]. [br]
## Formato de [param horarios_txt] deve ser conforme [method horarios_exe.carregar_horarios_txt]. [br]
## Formato de [param condicoes] deve ser a lista de condições no arquivo [code]base_config.json[/code]. [br]

## Condições sintéticas do Modo Ajuste, em ordem de prioridade. Não existem em
## [code]base_config.json:condicoes[/code] — são criadas em memória pelo chamador (hoje
## [code]situacao_alunos.gd[/code]) e nunca persistidas.
const CONDICOES_AJUSTE: Array[String] = ["ajuste_incluir", "ajuste_excluir"]

var analise_historico := AnaliseHistorico.new()
var general_functions := GeneralFunctions.new()
var horariosexe := HorariosExe.new()

## Obtem lista de dias da semana. [br]
## Retorna uma matriz com a listagem dos dias da semana conforme [code]horarios.ini[/code].
## Obtem lista de dias da semana. Valores universais da instituição, definidos em base_config.json.
func dias_da_semana(_horarios_ini: Dictionary = {}) -> Array[String]:
	var arr: Array[String] = []
	arr.assign(GV.configuracao_base.get("dias_semana", []))
	return arr

## Obtem lista de horas das aulas. Valores universais da instituição, definidos em base_config.json.
func horas_das_aulas(_horarios_ini: Dictionary = {}) -> Array[String]:
	var arr: Array[String] = []
	arr.assign(GV.configuracao_base.get("horarios_aula", []))
	return arr

## Ordena [param condicoes] na ordem canônica de prioridade da grade de horários: primeiro as de
## [constant CONDICOES_AJUSTE] (na ordem da constante), depois as presentes em [param condicoes_base]
## (na ordem dela), por fim as desconhecidas, preservando a ordem relativa de entrada entre si. [br]
## Retorna um array novo; não muta [param condicoes]. Duplicatas na entrada são preservadas.
static func ordenar_condicoes(condicoes: Array, condicoes_base: Array) -> Array[String]:
	var decoradas: Array[Array] = []
	for indice in condicoes.size():
		var item: String = condicoes[indice]
		decoradas.append([_prioridade_condicao(item, condicoes_base), indice, item])
	# sort_custom nao e estavel; o indice original no par de comparacao garante desempate
	# deterministico entre itens de mesma prioridade (ex.: duas condicoes desconhecidas).
	decoradas.sort_custom(func(a: Array, b: Array) -> bool:
		if a[0] != b[0]:
			return a[0] < b[0]
		return a[1] < b[1])
	var resultado: Array[String] = []
	for decorada in decoradas:
		resultado.append(decorada[2])
	return resultado

## Obtem, para uma matrícula, as disciplinas sendo cursadas e seus horarios. [br]
## Formato de [param disc_cursaveis] deve ser um dicionário com as chaves que vem do arquivo [code]base_config.json[/code], como
## "matriculavel", "seaprovado", etc. [br]
## Cada chave possui uma matriz com os códigos das disciplinas na condição. [br]
## Formato de [param historico_matricula] deve ser um extrato do [param historico] porém apenas de uma matrícula
## (e.g. {"nomedoaluno": "adriane arruda", "dados": [matriz_do_historico]}). [br]
## Retorna uma matriz bidimensional contendo os horarios, onde o primeiro item é a matriz da primeira linha, 
## contendo a sequencia de dias da semana, e as linhas subsequentes tem o primeiro item como o horário da aula. 
## Exemplo: [br]
## ["", "segunda", "terça", ... ] [br]
## [ "07:30", ... ]
## [ "08:30", ... ]
## [param codigos_incluir]/[param codigos_excluir] (Modo Ajuste, em minúsculas) marcam as disciplinas
## solicitadas no formulário de ajuste: as de incluir saem com fundo verde
## ([code]PaletaSemantica.FUNDO_AJUSTE_INCLUIR[/code]) e as de excluir com fundo vermelho
## ([code]FUNDO_AJUSTE_EXCLUIR[/code]). Vazios (padrão) não alteram nada. [br]
## [param condicoes] é reordenado pela ordem canônica de prioridade antes de montar a matriz
## (ver [method ordenar_condicoes]), independentemente da ordem recebida; o array do chamador
## não é mutado.
func determinar_horarios(horarios_ini: Dictionary, horarios_txt: Array, disc_cursaveis: Dictionary,\
historico_matricula: Dictionary, condicoes: Array = ["matriculado_agora"], \
lista_cores: Dictionary = {"matriculado_agora": "GREEN"}, forma_apresentacao: String = "somente_codigo", \
codigos_incluir: Array = [], codigos_excluir: Array = []) -> Array:
	var dias: Array[String] = dias_da_semana(horarios_ini)
	var horas: Array[String] = horas_das_aulas(horarios_ini)
	var condicoes_ordenadas: Array[String] = AnaliseHorarios.ordenar_condicoes(condicoes, \
	GV.configuracao_base.get("condicoes", []))
	var matriculada_com_turma: Dictionary = analise_historico.matriculada_com_turma(disc_cursaveis, historico_matricula)
	var horarios_txt_condicao: Dictionary = extrair_horarios_txt(horarios_txt, matriculada_com_turma, disc_cursaveis)
	var matriz_grade: Array[Array] = _preparar_horarios(dias, horas, horarios_txt_condicao, condicoes_ordenadas, \
	lista_cores, forma_apresentacao, codigos_incluir, codigos_excluir)
	return matriz_grade

## Calcula a taxa de presenca possivel para uma disciplina alvo considerando [br]
## choques de horario com as ja matriculadas do discente. [br]
## [param codigo_disc] e o codigo da disciplina (e.g. "al0001"). [br]
## [param horarios_txt] e o array completo de horarios do semestre. [br]
## [param slots_matriculadas] sao as entradas de horarios_txt das disciplinas ja [br]
## matriculadas (matriculado_agora, matricula_irregular, etc.). [br]
## Retorna {"exclusivos": int, "slots_conflito": int, "slots_total": int, [br]
##          "conflitos": {codigo: slots_conflito}}.
func calcular_choque_disciplina(codigo_disc: String, horarios_txt: Array, \
slots_matriculadas: Array[Dictionary]) -> Dictionary:
	var slots_disc: Array[Dictionary] = []
	for entry in horarios_txt:
		var cod_entry: String = horariosexe.extrair_cod_horarios_txt(entry.get("disciplina", ""))
		if cod_entry.to_lower() == codigo_disc.to_lower():
			slots_disc.append(entry)
	var slots_conflito: int = 0
	var conflitos_por_disc: Dictionary = {}
	for sd in slots_disc:
		for sm in slots_matriculadas:
			if sd["dia"] == sm["dia"] and sd["horario"] == sm["horario"]:
				slots_conflito += 1
				var cod_m: String = horariosexe.extrair_cod_horarios_txt(sm.get("disciplina", ""))
				conflitos_por_disc[cod_m] = conflitos_por_disc.get(cod_m, 0) + 1
				break
	var exclusivos: int = slots_disc.size() - slots_conflito
	return {
		"exclusivos": exclusivos,
		"slots_conflito": slots_conflito,
		"slots_total": slots_disc.size(),
		"conflitos": conflitos_por_disc
	}

## A partir de duas matrizes de horarios, une-as em umas só. [param matriz_grade1] e [param matriz_grade2] 
## seguem o padrão de saída de [method determinar_horarios]
func concatenar_horarios(matriz_grade1: Array, matriz_grade2: Array) -> Array:
	# Concatena duas matrizes de horarios em apenas uma
	var matriz_concatenada: Array[Array]
	# Verifica se uma das matrizes é vazia
	if matriz_grade1.size() == 0:
		return matriz_grade2
	if matriz_grade2.size() == 0:
		return matriz_grade1
	# Verifica se as matrizes tem a mesma dimensão.
	if matriz_grade1.size() != matriz_grade2.size() or (matriz_grade1.size() > 0 and matriz_grade2.size() > 0 and matriz_grade1[0].size() != matriz_grade2[0].size()):
		print_debug("ERRO: Matrizes de horários com dimensões diferentes. Não é possível concatenar. Matriz1: ", matriz_grade1.size(), "x", matriz_grade1[0].size() if matriz_grade1.size() > 0 else 0, " Matriz2: ", matriz_grade2.size(), "x", matriz_grade2[0].size() if matriz_grade2.size() > 0 else 0)
		return matriz_grade1
	# Prepara a matriz concatenada.
	matriz_concatenada.resize(matriz_grade1.size())
	for a in matriz_grade1.size():
		matriz_concatenada[a] = []
		matriz_concatenada[a].resize(matriz_grade1[a].size())
		matriz_concatenada[a].fill("")
	# Concatena as matrizes.
	for a in matriz_grade1.size():
		for b in matriz_grade1[a].size():
			if a == 0 or b == 0:
				matriz_concatenada[a][b] = matriz_grade1[a][b]
			else:
				matriz_concatenada[a][b] = matriz_grade1[a][b] + matriz_grade2[a][b]
	return matriz_concatenada

## Detecta choques de horário entre condições. [br]
## [param horarios_txt_condicao] deve ser conforme [method extrair_horarios_txt] — dicionario onde
## cada chave é uma condição e o valor é um array de entradas de horario ([param dia], [param horario], etc.). [br]
## [param regras] é um array de pares de condicoes a comparar (e.g. [code][["matriculavel", "matriculado_agora"]][/code]). [br]
## Retorna um dicionario onde cada chave é [code]"cond_A x cond_B"[/code] e o valor é um array de dicionarios
## com os choques encontrados, cada um contendo [param dia], [param horario], [param disc_a],
## [param turma_a], [param disc_b], [param turma_b].
func detectar_choques(horarios_txt_condicao: Dictionary, regras: Array[Array] = [["matriculavel", "matriculado_agora"]]) -> Dictionary:
	var resultado: Dictionary = {}

	for regra in regras:
		var cond_a: String = regra[0]
		var cond_b: String = regra[1]
		var chave_regra: String = cond_a + " x " + cond_b

		if not horarios_txt_condicao.has(cond_a) or not horarios_txt_condicao.has(cond_b):
			continue

		var lista_choques: Array[Dictionary] = []
		var entradas_a: Array = horarios_txt_condicao[cond_a]
		var entradas_b: Array = horarios_txt_condicao[cond_b]
		var mesma_condicao: bool = cond_a == cond_b

		for i in entradas_a.size():
			var cod_a: String = horariosexe.extrair_cod_horarios_txt(entradas_a[i].get("disciplina", ""))
			var dia_a: String = entradas_a[i].get("dia", "")
			var hora_a: String = entradas_a[i].get("horario", "")

			var inicio_j: int = i + 1 if mesma_condicao else 0
			for j in range(inicio_j, entradas_b.size()):
				var cod_b: String = horariosexe.extrair_cod_horarios_txt(entradas_b[j].get("disciplina", ""))
				if cod_a == cod_b:
					continue
				if dia_a == entradas_b[j].get("dia", "") and hora_a == entradas_b[j].get("horario", ""):
					lista_choques.append({
						"dia": dia_a,
						"horario": hora_a,
						"disc_a": cod_a,
						"turma_a": entradas_a[i].get("turma", ""),
						"disc_b": cod_b,
						"turma_b": entradas_b[j].get("turma", ""),
					})

		resultado[chave_regra] = lista_choques

	return resultado

## Extrai de [param horarios_txt] apenas as linhas que coincidam com os códigos de disciplinas e de turmas
## encontrados em [param matriculada_com_turma]. [br]
## Formato de [param matriculada_com_turma] deve ser conforme [method AnaliseHistorico.matriculada_com_turma], e contém
## a lista de códigos das disciplinas matriculadas e respectivas turmas. [br]
## Formato de [param disc_cursaveis] deve ser um dicionário com as chaves que vem do arquivo [code]base_config.json[/code], como
## "matriculavel", "seaprovado", etc. [br]
## Retorna um dicionário de matrizes no estilo de [param horarios_txt] mas sem as linhas que o
## discente não tenha situação envolvida. As chaves do dicionário são relacionadas as condições. Exemplo: [br]
## { [br]
## "matriculado_agora": { [br]
## { "linha": "23", "professor": "Maria da Silva Souza", "sala": "A1-304 (Sala de Aula)", ... } [br]
## { "linha": "18", "professor": "João Pereira Lima", "sala": "A1-303 (Sala de Aula)" ... } [br]
## } [br]
## }
func extrair_horarios_txt(horarios_txt: Array, matriculada_com_turma: Dictionary, disc_cursaveis: Dictionary) -> Dictionary:
	var horarios_txt_condicao: Dictionary = {}
	for key in disc_cursaveis.keys():
		horarios_txt_condicao[key] = []
	for a in horarios_txt.size():
		for key in matriculada_com_turma.keys():
			for b in matriculada_com_turma[key].size():
				if matriculada_com_turma[key][b][0] == horariosexe.extrair_cod_horarios_txt(horarios_txt[a].get("disciplina")):
					var turmas_txt: Array[String] = _obter_turmas(horarios_txt[a].get("turma"))
					var turmas_aluno: Array[String] = _obter_turmas(matriculada_com_turma[key][b][1])
					
					var tem_turma_em_comum: bool = false
					for c in turmas_txt.size():
						for d in turmas_aluno.size():
							if AnaliseHorarios._comparar_turmas(turmas_txt[c], turmas_aluno[d]):
								tem_turma_em_comum = true
								break
						if tem_turma_em_comum:
							break
					
					# Se houver correspondencia, adiciona a aula ao discente
					if tem_turma_em_comum:
						horarios_txt_condicao[key].append(horarios_txt[a])
					else:
						# Se for a mesma disciplina mas a turma não bater, joga para "matriculavel"
						# para que o discente veja as outras opções de horários em branco
						if horarios_txt_condicao.has("matriculavel"):
							horarios_txt_condicao["matriculavel"].append(horarios_txt[a])
		# Depois verifica as disciplinas em outras situações, como matriculáveis, matriculáveis com corequisito, etc
		for key in disc_cursaveis.keys():
			if key != "matriculado_agora" and key != "matriculado_agora_aproveitamento":
				for b in disc_cursaveis[key].size():
					if disc_cursaveis[key][b] == horariosexe.extrair_cod_horarios_txt(horarios_txt[a].get("disciplina")):
						horarios_txt_condicao[key].append(horarios_txt[a])
	return horarios_txt_condicao

# Determina qual a(s) turma(s) a partir do texto informado. [br]
# Formato de [param turma] pode ser o da turma do [method horarios_exe.carregar_horarios_txt] (e.g. "T10/70", 
# "T20/30/60A"), ou do [method FileHandling.ler_dados] (e.g "20/30"). [br]
# Compara dois identificadores de turma. [br]
# Retorna [code]true[/code] se forem equivalentes.
static func _comparar_turmas(turma_a: String, turma_b: String) -> bool:
	return turma_a.to_lower().replacen("t", "") == turma_b.to_lower().replacen("t", "")

# Retorna uma matriz contendo os números das turmas.
func _obter_turmas(turma: String) -> Array:
	turma = turma.to_lower().replacen("t", "")
	# Padroniza os separadores transformando o ; do txt em /
	turma = turma.replace(";", "/") 
	
	# Usando Array() para garantir a compatibilidade do tipo
	var lista_turmas: Array[String] = []
	lista_turmas.assign(turma.split("/"))
	
	# Propaga a letra final. Ex: "40/80b" -> "40b" e "80b"
	if lista_turmas.size() > 1:
		var ultima_turma = lista_turmas[-1]
		# Se a última turma contiver uma letra (ou seja, não for apenas número)
		if ultima_turma != "" and not ultima_turma.is_valid_int():
			var letra_final: String = ""
			var num_str: String = ""
			for ch in ultima_turma:
				if ch.is_valid_int():
					num_str += ch
				else:
					letra_final += ch
			# Aplica a letra nas turmas anteriores que forem puramente numéricas
			for i in range(lista_turmas.size() - 1):
				if lista_turmas[i].is_valid_int():
					lista_turmas[i] = lista_turmas[i] + letra_final
					
	return lista_turmas

# Prioridade de ordenacao de uma condicao: 0/1 para o tier ajuste (indice em CONDICOES_AJUSTE),
# 2+indice para o tier base (indice em condicoes_base), ou 2+condicoes_base.size() para desconhecida.
static func _prioridade_condicao(condicao: String, condicoes_base: Array) -> int:
	var indice_ajuste: int = AnaliseHorarios.CONDICOES_AJUSTE.find(condicao)
	if indice_ajuste != -1:
		return indice_ajuste
	var indice_base: int = condicoes_base.find(condicao)
	if indice_base != -1:
		return AnaliseHorarios.CONDICOES_AJUSTE.size() + indice_base
	return AnaliseHorarios.CONDICOES_AJUSTE.size() + condicoes_base.size()

# Cria a matriz de horarios contendo dias da semana vs hora.
# Formato de [param dias_da_semana] deve ser uma matriz sequencial com os dias da semana.
# Formato de [param horas_das_aulas] deve ser uma matriz sequencial com as horas de aula possiveis.
# Formato de [param horarios_txt_condicao] deve ser de acordo com [method extrair_horarios_txt].
# Formato de [param condicoes] deve ser uma lista de condicoes que se deseja apresentar.
# Formato de [param lista_cores] deve ser um dicionario de cores conforme [code]base_config.json[/code].
# Formato de [param forma_apresentacao] e um texto que indica como serao apresentados os dados na matriz de horarios.
# Retorna uma matriz bidimensional de dias da semana versus horarios das aulas.
func _preparar_horarios(dias_da_semana: Array, horas_das_aulas: Array, horarios_txt_condicao: Dictionary, \
condicoes: Array = ["matriculado_agora"], lista_cores: Dictionary = {"matriculado_agora": "GREEN"}, \
forma_apresentacao: String = "somente_codigo", codigos_incluir: Array = [], codigos_excluir: Array = []) -> Array:
	var matriz_grade: Array[Array] = []
	# Remove situações em [param condicoes] que não sejam validas para [param horarios_txt_condicao]
	var counter: int = 0
	while counter < condicoes.size():
		var encontrada: bool = false
		for key in horarios_txt_condicao.keys():
			if condicoes[counter] == key:
				encontrada = true
				break
		if not encontrada:
			condicoes.remove_at(counter)
		else:
			counter += 1
	
	# Prepara a matriz apenas com dias da semana e horário das aulas
	if dias_da_semana.size() > 0 and horas_das_aulas.size() > 0:
		matriz_grade.append([""])
		for a in dias_da_semana.size():
			matriz_grade[0].append(dias_da_semana[a])
		for a in horas_das_aulas.size():
			matriz_grade.append([horas_das_aulas[a]])
			for b in dias_da_semana.size():
				matriz_grade[a+1].append("")
	# Popula a matriz com as informações
	for a in condicoes.size():
		for b in horarios_txt_condicao.get(condicoes[a]).size():
			# Determina hora e dia da semana da aula
			var hora: String = horarios_txt_condicao[condicoes[a]][b].get("horario")
			var dia_da_semana: String = horarios_txt_condicao[condicoes[a]][b].get("dia")
			# Procura posição na matriz do horario e dia da semana
			var linha: int = 0
			for pesquisa_linha in matriz_grade.size():
				if hora == matriz_grade[pesquisa_linha][0]:
					linha = pesquisa_linha
					break
			if linha == 0:
				print_debug("ERRO: Linha não encontrada!")
				continue
			var coluna: int = 0
			for pesquisa_coluna in matriz_grade[0].size():
				if dia_da_semana == matriz_grade[0][pesquisa_coluna].to_lower():
					coluna = pesquisa_coluna
					break
			if coluna == 0:
				print_debug("ERRO: Coluna não encontrada!")
				continue
			
			# Contém o texto que será enviado diretamente a matriz de horarios, já concatenado
			var texto_para_matriz: String
			# Emite o token da condicao no BBCode; a Celula o traduz e adapta ao tema na hora de pintar.
			var color: String = condicoes[a]
			# Duas variáveis de controle para o BBcode que controla a cor
			var prefixo: String = "[color="+color+"]"
			var sufixo: String = "[/color]"
			if not lista_cores.has(condicoes[a]):
				prefixo = prefixo + "[shake rate=20.0 level=10]"
				sufixo = "[/shake]" + sufixo
			var disciplina: String = horarios_txt_condicao[condicoes[a]][b].get("disciplina", "")
			var codigo: String = horariosexe.extrair_cod_horarios_txt(disciplina).to_upper()
			var nome: String = horariosexe.extrair_nome_horarios_txt(disciplina)
			match forma_apresentacao:
				"somente_codigo":
					texto_para_matriz = codigo
				"nome_completo":
					texto_para_matriz = nome
				"nome_reduzido":
					texto_para_matriz = general_functions.encurtar_texto(nome, 3)
				"codigo_nome_reduzido":
					var nr: String = general_functions.encurtar_texto(nome, 3)
					texto_para_matriz = codigo + (" - " + nr if not nr.is_empty() else "")
				"completo":
					var partes: Array[String] = [codigo]
					var turma: String = horarios_txt_condicao[condicoes[a]][b].get("turma", "").to_upper()
					if not turma.is_empty():
						partes.append(turma)
					var nrc: String = general_functions.encurtar_texto(nome, 3)
					if not nrc.is_empty():
						partes.append(nrc)
					texto_para_matriz = " - ".join(partes)
				"esferas":
					texto_para_matriz = "●"
				_:
					texto_para_matriz = "forma de apresentação inválida"
			
			# Modo Ajuste: fundo verde p/ a disciplina que o discente quer incluir e vermelho p/ a que
			# quer excluir (substitui o antigo [u]/[s], fraco demais). O hex literal do [bgcolor]
			# atravessa a tradução de tokens da Celula intacto.
			var cod_lower: String = codigo.to_lower()
			if cod_lower in codigos_incluir:
				texto_para_matriz = "[bgcolor=" + PaletaSemantica.FUNDO_AJUSTE_INCLUIR + "]" + texto_para_matriz + "[/bgcolor]"
			elif cod_lower in codigos_excluir:
				texto_para_matriz = "[bgcolor=" + PaletaSemantica.FUNDO_AJUSTE_EXCLUIR + "]" + texto_para_matriz + "[/bgcolor]"

			var virgula: String = "[color=orange], [/color]"
			if forma_apresentacao == "esferas" or matriz_grade[linha][coluna].length() == 0:
				virgula = ""
			matriz_grade[linha][coluna] = matriz_grade[linha][coluna] + virgula + prefixo + texto_para_matriz + sufixo
	return matriz_grade
