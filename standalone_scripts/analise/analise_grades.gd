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

class_name AnaliseGrades extends Resource
## Funções específicas a análise de grades curriculares.
##
## Retornam informações ligadas somente a arquivos contídos em [code]/arquivos/grades[/code]. [br]
## [br]
## Os principais parâmetros empregados nesta classe e suas devidas formatações são: [br]
## Formato de [param grades_disciplinas_curriculos] deve ser uma chave de dicionário para cada arquivo em 
## [code]/arquivos/grades[/code] e em cada chave o conteudo do arquivo em questão. [br]
## Formato de [param equivalencias] deve ser uma chave de dicionário para cada arquivo em 
## [code]/arquivos/equivalencias[/code] e em cada chave o conteudo do arquivo em questão. [br]
## Formato de [param versao_grade] deve ser a chave composta da grade no padrão
## [code]<cod_curso>_<versao>[/code] (e.g. [code]alec_2023[/code]).

var general_functions := GeneralFunctions.new() 

## Retorna informação de diversas grades.
## Formato de [param codigo_pesquisa] deve o código da disciplina (e.g. "al0001"). [br]
## Formato de [param informacao_desejada] deve ser o nome da informação em [code]/arquivos/grades[/code] (e.g. "nome"). [br]
## Quando [param silencioso] é verdadeiro, não loga o "ERRO: Não foi encontrado código" caso o
## código não exista em nenhuma grade — usado pelos chamadores do fluxo de planejamento/oferta,
## onde códigos sem grade são esperados e tratados (o ruído é reportado de forma agregada).
func info_grade(grades_disciplinas_curriculos: Dictionary, codigo_pesquisa: String, informacao_desejada: String, grade_nome: String = "", silencioso: bool = false) -> String:
	if not grade_nome.is_empty():
		var grade: Dictionary = grades_disciplinas_curriculos.get(grade_nome, {})
		if grade.has(codigo_pesquisa):
			return str(grade[codigo_pesquisa].get(informacao_desejada, "Informação não encontrada ("+informacao_desejada+")"))
		if not silencioso:
			print_debug("ERRO: Não foi encontrado código ", codigo_pesquisa, "!")
		return "Codigo não encontrado"
	for grade in grades_disciplinas_curriculos.keys():
		for codigo in grades_disciplinas_curriculos[grade].keys():
			if codigo == codigo_pesquisa:
				return grades_disciplinas_curriculos[grade][codigo].get(informacao_desejada, "Informação não encontrada ("+informacao_desejada+")")
	if not silencioso:
		print_debug("ERRO: Não foi encontrado código ", codigo_pesquisa, "!")
	return "Codigo não encontrado"

## Retorna se [param codigo] existe em alguma grade de [param grades_disciplinas_curriculos], sem
## logar nada. Útil para verificações em massa (e.g. quais códigos do planejamento não têm grade).
func existe_codigo(grades_disciplinas_curriculos: Dictionary, codigo: String) -> bool:
	for grade in grades_disciplinas_curriculos.keys():
		if grades_disciplinas_curriculos[grade].has(codigo):
			return true
	return false

## Dada uma lista de [param codigos], retorna os que NÃO existem em nenhuma grade, sem duplicatas e
## preservando a ordem de aparição. Base do aviso agregado de "disciplinas sem grade".
func codigos_ausentes(grades_disciplinas_curriculos: Dictionary, codigos: Array) -> Array[String]:
	var ausentes: Array[String] = []
	for codigo in codigos:
		var cod: String = str(codigo)
		if cod == "" or ausentes.has(cod):
			continue
		if not existe_codigo(grades_disciplinas_curriculos, cod):
			ausentes.append(cod)
	return ausentes

## Monta a matriz da grade curricular de um discente para apresentação no componente [GradeCurricular]/[Grade]. [br]
## Posiciona cada disciplina obrigatória conforme sua chave [code]posicao_grade[/code] ([linha, coluna]) e
## define a cor da letra da célula conforme a situação do discente. [br]
## Formato de [param grade] deve ser um único arquivo de [code]/arquivos/grades[/code]
## (e.g. [code]grades_disciplinas_curriculos["alec_2023"][/code]). [br]
## Formato de [param disc_cursaveis] segue a saída de [method AnaliseHistorico.condicoes_discentes] para um
## discente: uma chave para cada condição e em cada chave a lista de códigos. [br]
## Formato de [param cursadas] deve ser a lista de códigos já concluídos (saída de
## [method AnaliseHistorico.disciplinas_concluidas]). [br]
## Formato de [param lista_cores] deve ser o dicionário [code]lista_cores[/code] de [code]base_config.json[/code]. [br]
## Formato de [param forma_apresentacao] define como o texto da célula é formatado: [br]
## - [code]"somente_codigo"[/code]: apenas o código (ex.: AL0001); [br]
## - [code]"nome_completo"[/code]: apenas o nome da disciplina; [br]
## - [code]"nome_reduzido"[/code]: nome abreviado via [method GeneralFunctions.encurtar_texto]; [br]
## - [code]"codigo_e_nome"[/code] (padrão): código + nome em duas linhas; [br]
## - [code]"codigo_e_nome_reduzido"[/code]: código + nome abreviado em duas linhas. [br]
## Formato de [param codigos_destacar] deve ser uma lista de códigos cujas células receberão
## destaque visual ([param cor_barra_superior] = [code]YELLOW[/code]). [br]
## Formato de [param codigos_destacar_secundario] deve ser um [Dictionary] [code]{codigo: cor}[/code]
## com os códigos a destacar e suas respectivas cores (saída de [method obter_bloqueadas_transitivas]). [br]
## Retorna uma matriz bidimensional ([code]Array[Array][/code]) no formato esperado por [Grade]: células
## preenchidas são Dictionary com [param texto_central], [param codigo], [param cor_central]
## (cor da situação) e [param apenas_central]; células sem disciplina são String vazia. [br]
## Disciplinas sem [code]posicao_grade[/code] (e.g. eletivas, CCCGs) são ignoradas. [br]
## [br]
## Parâmetros opcionais usados pelo Planejamento de Oferta (ignorados quando vazios): [br]
## Formato de [param contagens_por_codigo] deve ser [code]{codigo_lower: {situacao: quantidade}}[/code]
## (a quantidade de discentes em cada situação para cada disciplina). [br]
## Formato de [param situacoes_rodape] deve ser a lista de situações (na ordem) a exibir no rodapé da
## célula como números coloridos; cada número usa a cor da situação via [code]lista_cores[/code]
## (com fallback para o próprio token). Quando vazio, nenhum rodapé é montado. [br]
## Formato de [param codigos_inseridos] deve ser a lista de códigos (minúsculos) já presentes em outro
## painel (ex.: cards no PainelDisciplinas), cujas células recebem contorno [param cor_inseridas]. [br]
## Formato de [param cor_inseridas] é a [Color] do contorno das disciplinas já inseridas; quando
## transparente (padrão) nenhum contorno é aplicado. [br]
## Formato de [param codigos_hachurar] deve ser a lista de códigos (minúsculos) cujas células recebem
## hachura leve — na Situação dos Alunos, as disciplinas ainda distantes de serem cursáveis (saída de
## [method disciplinas_distantes]). Vazio (padrão) não hachura nada.
func montar_grade_curricular(grade: Dictionary, disc_cursaveis: Dictionary, cursadas: Array[String], lista_cores: Dictionary, forma_apresentacao: String = "codigo_e_nome", codigos_destacar: Array[String] = [], codigos_destacar_secundario: Dictionary = {}, contagens_por_codigo: Dictionary = {}, situacoes_rodape: Array = [], codigos_inseridos: Array[String] = [], cor_inseridas: Color = Color.TRANSPARENT, codigos_hachurar: Array[String] = []) -> Array[Array]:
	# Mapeia cada código de disciplina para o nome da cor de sua situação.
	var cor_por_codigo: Dictionary = {}
	for condicao in disc_cursaveis.keys():
		for codigo in disc_cursaveis[condicao]:
			cor_por_codigo[str(codigo).to_lower()] = lista_cores.get(condicao, "")
	# Disciplinas concluídas têm precedência, pois representam situação definitiva.
	for codigo in cursadas:
		cor_por_codigo[str(codigo).to_lower()] = lista_cores.get("cursada", "")
	# Determina as dimensões da matriz a partir das posições informadas na grade.
	var max_linha: int = 0
	var max_coluna: int = 0
	for codigo in grade.keys():
		if grade[codigo].has("posicao_grade"):
			var pos: Array = grade[codigo]["posicao_grade"]
			max_linha = max(max_linha, int(pos[0]))
			max_coluna = max(max_coluna, int(pos[1]))
	if max_linha == 0:
		return []
	# Calha de semestre: a coluna 0 é sempre reservada ao número do semestre. Como cada grade usa uma
	# convenção própria (alec_2023 começa na coluna 1; alec_2010 usa a coluna 0 para disciplinas),
	# desloca-se todas as disciplinas para que a menor coluna vire 1, mantendo a coluna 0 livre.
	var offset: int = _offset_coluna(grade)
	# Cria a matriz vazia. As linhas em posicao_grade iniciam em 1, logo são deslocadas para o índice 0.
	var matriz: Array[Array] = []
	for _l in max_linha:
		var linha_atual: Array = []
		for _c in max_coluna + offset + 1:
			linha_atual.append("")
		matriz.append(linha_atual)
	# Posiciona cada disciplina obrigatória na matriz, colorindo conforme a situação.
	for codigo in grade.keys():
		if not grade[codigo].has("posicao_grade"):
			continue
		var pos: Array = grade[codigo]["posicao_grade"]
		var linha: int = int(pos[0]) - 1
		var coluna: int = int(pos[1]) + offset
		var nome_disciplina: String = str(grade[codigo].get("nome", ""))
		var texto_celula: String
		match forma_apresentacao:
			"somente_codigo":
				texto_celula = codigo.to_upper()
			"nome_completo":
				texto_celula = nome_disciplina
			"nome_reduzido":
				texto_celula = general_functions.encurtar_texto(nome_disciplina, 3)
			"codigo_e_nome":
				texto_celula = codigo.to_upper() + "\n" + nome_disciplina
			"codigo_e_nome_reduzido":
				texto_celula = codigo.to_upper() + "\n" + general_functions.encurtar_texto(nome_disciplina, 3)
			_:
				texto_celula = codigo.to_upper() + "\n" + nome_disciplina
		var celula: Dictionary = {
			"codigo": codigo.to_lower(),
			"texto_central": texto_celula,
			"faixa_alternada": (linha % 2 == 1),
		}
		# Código e carga horária nos cantos superiores apenas nos modos cujo centro não é o código.
		if forma_apresentacao == "nome_completo" or forma_apresentacao == "nome_reduzido":
			celula["texto_canto_superior_esquerdo"] = codigo.to_upper()
			var ch: String = str(grade[codigo].get("ch", ""))
			if ch != "":
				celula["texto_canto_superior_direito"] = ch + "h"
		else:
			celula["apenas_central"] = true
		# A situação é indicada pela cor da letra, mantendo o fundo padrão.
		var nome_cor: String = cor_por_codigo.get(codigo.to_lower(), "")
		if nome_cor != "":
			celula["cor_central"] = nome_cor
		# Destaca células cujo código está na lista de pré-requisitos selecionados.
		if codigos_destacar.has(codigo.to_lower()):
			celula["cor_barra_superior"] = "YELLOW"
		# Destaca em laranja as disciplinas bloqueadas pela selecionada (botão direito).
		if codigos_destacar_secundario.has(codigo.to_lower()):
			celula["cor_barra_superior"] = codigos_destacar_secundario[codigo.to_lower()]
		# Rodapé com contagens por situação (Planejamento de Oferta): "20 | 30 | 15", cada número na cor
		# da respectiva situação. Só é montado quando há ao menos um discente em alguma das situações.
		if not situacoes_rodape.is_empty():
			var counts: Dictionary = contagens_por_codigo.get(codigo.to_lower(), {})
			var total: int = 0
			var partes: Array[String] = []
			for sit in situacoes_rodape:
				var n: int = int(counts.get(sit, 0))
				total += n
				partes.append("[color=%s]%d[/color]" % [str(lista_cores.get(sit, sit)), n])
			if total > 0:
				celula["texto_rodape"] = " | ".join(partes)
		# Contorno nas disciplinas já inseridas em outro painel (ex.: cards do PainelDisciplinas).
		if cor_inseridas != Color.TRANSPARENT and codigos_inseridos.has(codigo.to_lower()):
			celula["cor_barra_superior"] = cor_inseridas
		# Hachura leve nas disciplinas ainda distantes de serem cursáveis.
		if codigos_hachurar.has(codigo.to_lower()):
			celula["hachurado"] = true
			celula["hachura_leve"] = true
		matriz[linha][coluna] = celula
	# Preenche a coluna 0 (sempre reservada pela calha) com o número do semestre de cada linha.
	for l in matriz.size():
		matriz[l][0] = {
			"texto_central": str(l + 1),
			"apenas_central": true,
			"faixa_alternada": (l % 2 == 1),
		}
	return matriz

## Códigos da [param grade] que estão [b]distantes[/b] para o discente: não se enquadram em nenhuma
## condição de [param disc_cursaveis] (nem matriculável, nem "se aprovado", nem matriculado) e também
## não foram concluídos. São as disciplinas que dependem de aprovação em algo que, por sua vez, ainda
## depende de outra aprovação — duas ou mais etapas à frente. [br]
## [br]
## Exemplo: matriculada em Mecânica dos Solos II, o discente cursará Obras de Terra se aprovado
## ([code]seaprovado[/code]); Fundações, que exige Obras de Terra, não entra em condição alguma e é
## justamente o que esta função retorna. [br]
## [br]
## A conclusão é avaliada [b]com aproveitamento[/b]: uma disciplina cursada sob o código de outra
## grade conta como concluída aqui, senão apareceria como distante mesmo já tendo sido aprovada
## (a regra de disciplina dividida vale, via [method alvo_completo]). [br]
## [param codigos_historico] deve ser [code]{codigo_lower: true}[/code] com TODOS os códigos que o
## discente tem no histórico, usado por essa regra. [br]
## Disciplinas sem [code]posicao_grade[/code] (eletivas, CCCGs) são ignoradas, pois não têm célula.
func disciplinas_distantes(grade: Dictionary, disc_cursaveis: Dictionary, cursadas: Array[String], \
equivalencias: Dictionary, versao_grade: String, codigos_historico: Dictionary) -> Array[String]:
	# Tudo que já tem situação definida: qualquer condição do discente ou disciplina concluída.
	var definidas: Dictionary = {}
	for condicao in disc_cursaveis.keys():
		for codigo in disc_cursaveis[condicao]:
			definidas[str(codigo).to_lower()] = true
	for codigo in cursadas:
		var cl: String = str(codigo).to_lower()
		definidas[cl] = true
		# Concluída sob o código de outra grade: marca também o alvo equivalente nesta grade.
		for alvo in para_o_codigo_qual_a_equivalencia(cl, equivalencias, versao_grade):
			if alvo_completo(alvo, equivalencias, versao_grade, codigos_historico):
				definidas[str(alvo).to_lower()] = true
	var distantes: Array[String] = []
	for codigo in grade.keys():
		if not grade[codigo].has("posicao_grade"):
			continue
		if not definidas.has(str(codigo).to_lower()):
			distantes.append(str(codigo).to_lower())
	return distantes

## Deslocamento de coluna aplicado às disciplinas para liberar a coluna 0 como calha de semestre. [br]
## Vale [code]1 - menor_coluna[/code]: assim a menor coluna usada pela grade passa a ser 1, qualquer que
## seja a convenção do arquivo (alec_2023 começa em 1 → offset 0; alec_2010 começa em 0 → offset 1).
func _offset_coluna(grade: Dictionary) -> int:
	var min_coluna: int = -1
	for codigo in grade.keys():
		if grade[codigo].has("posicao_grade"):
			var c: int = int(grade[codigo]["posicao_grade"][1])
			if min_coluna == -1 or c < min_coluna:
				min_coluna = c
	if min_coluna == -1:
		return 1
	return 1 - min_coluna

## Linhas de conexão da cadeia de PRÉ-REQUISITOS de [param codigo] (a montante, "para cima"). [br]
## Propaga em dominó: cada aresta liga um pré-requisito direto ao seu dependente imediato, e não a
## disciplina clicada a todos os ancestrais. Todas as linhas usam a cor [code]YELLOW[/code]. [br]
## Retorna lista no formato esperado por [member Grade.conexoes].
func conexoes_prerequisitos(codigo: String, grade: Dictionary) -> Array:
	return _arestas_para_conexoes(_percorrer_cascata(codigo, grade, false), grade, false)

## Linhas de conexão da cadeia de DEPENDENTES de [param codigo] (a jusante, "para baixo"). [br]
## Propaga em dominó: cada aresta liga uma disciplina ao seu dependente imediato. A cor de cada aresta
## reflete a profundidade na cadeia (ver [method _cor_por_profundidade]). [br]
## Retorna lista no formato esperado por [member Grade.conexoes].
func conexoes_bloqueios(codigo: String, grade: Dictionary) -> Array:
	return _arestas_para_conexoes(_percorrer_cascata(codigo, grade, true), grade, true)

## Retorna todos os pré-requisitos transitivos (a montante) de [param codigo], para destaque de bordas.
func prerequisitos_transitivos(codigo: String, grade: Dictionary) -> Array[String]:
	var lista: Array[String] = []
	for aresta in _percorrer_cascata(codigo, grade, false):
		# aresta = [cod_prerequisito, cod_dependente, profundidade]; o ancestral é sempre o pré-requisito.
		if not aresta[0] in lista:
			lista.append(aresta[0])
	return lista

# Percorre o grafo de pré-requisitos a partir de [param codigo] em largura (BFS).
# [param dependentes]=true segue quem depende de codigo (para baixo); false segue os pré-requisitos
# de codigo (para cima). As arestas são sempre orientadas (pré-requisito -> dependente).
# Retorna uma lista de arestas [cod_prerequisito, cod_dependente, profundidade].
func _percorrer_cascata(codigo: String, grade: Dictionary, dependentes: bool) -> Array:
	var arestas: Array = []
	var inicial: String = codigo.to_lower()
	var visitados: Array[String] = [inicial]
	var fila: Array[Array] = [[inicial, 0]]
	var idx: int = 0
	while idx < fila.size():
		var cod_atual: String = fila[idx][0]
		var prof: int = fila[idx][1]
		idx += 1
		if dependentes:
			# Disciplinas que têm cod_atual como pré-requisito.
			for cod_disc in grade.keys():
				var dl: String = str(cod_disc).to_lower()
				var i: int = 0
				while grade[cod_disc].has("prerequisito" + str(i)):
					if str(grade[cod_disc]["prerequisito" + str(i)]).to_lower() == cod_atual:
						arestas.append([cod_atual, dl, prof + 1])
						if not dl in visitados:
							visitados.append(dl)
							fila.append([dl, prof + 1])
						break
					i += 1
		else:
			# Pré-requisitos diretos de cod_atual.
			if grade.has(cod_atual):
				var i: int = 0
				while grade[cod_atual].has("prerequisito" + str(i)):
					var pr: String = str(grade[cod_atual]["prerequisito" + str(i)]).to_lower()
					arestas.append([pr, cod_atual, prof + 1])
					if not pr in visitados:
						visitados.append(pr)
						fila.append([pr, prof + 1])
					i += 1
	return arestas

# Converte arestas [cod_prereq, cod_dep, prof] em conexões posicionais para [member Grade.conexoes],
# aplicando o mesmo offset de coluna da grade. [param usar_profundidade] escolhe a cor: profundidade
# (dependentes) ou [code]YELLOW[/code] fixo (pré-requisitos).
func _arestas_para_conexoes(arestas: Array, grade: Dictionary, usar_profundidade: bool) -> Array:
	var conexoes: Array = []
	var offset: int = _offset_coluna(grade)
	for aresta in arestas:
		var prereq: String = aresta[0]
		var dep: String = aresta[1]
		var prof: int = aresta[2]
		if not grade.has(prereq) or not grade[prereq].has("posicao_grade"):
			continue
		if not grade.has(dep) or not grade[dep].has("posicao_grade"):
			continue
		var pos_p: Array = grade[prereq]["posicao_grade"]
		var pos_d: Array = grade[dep]["posicao_grade"]
		var cor = _cor_por_profundidade(prof) if usar_profundidade else "YELLOW"
		conexoes.append({
			"origem": [int(pos_p[0]) - 1, int(pos_p[1]) + offset],
			"destino": [int(pos_d[0]) - 1, int(pos_d[1]) + offset],
			"cor": cor,
		})
	return conexoes

## Retorna os códigos de todos os pré-requisitos de uma disciplina em [param grade]. [br]
## Itera as chaves [code]prerequisito0[/code], [code]prerequisito1[/code], etc. [br]
## Retorna Array vazia se a disciplina não tiver pré-requisitos ou não estiver na grade.
func obter_prerequisitos(codigo: String, grade: Dictionary) -> Array[String]:
	var prerequisitos: Array[String] = []
	if not grade.has(codigo):
		return prerequisitos
	var i: int = 0
	while grade[codigo].has("prerequisito" + str(i)):
		prerequisitos.append(str(grade[codigo]["prerequisito" + str(i)]).to_lower())
		i += 1
	return prerequisitos

## Calcula o caminho crítico de formatura: a maior cadeia de pré-requisitos OBRIGATÓRIOS ainda
## pendente, que determina o prazo mínimo até a formatura. [br]
## Considera apenas disciplinas obrigatórias (as que têm [code]posicao_grade[/code] em [param grade]);
## eletivas/CCCGs são ignoradas. [br]
## Formato de [param cursadas] e [param em_curso] devem ser listas de códigos em minúsculas (saída de
## [method AnaliseHistorico.disciplinas_concluidas] e dos códigos com situação [code]matr[/code]). [br]
## Para cada obrigatória, o "offset de conclusão" (em períodos, a partir do período atual) é: [br]
## - já concluída: [code]-1[/code] (não estende a cadeia); [br]
## - em curso: [code]0[/code] (conclui no período atual); [br]
## - pendente: [code]max(1, max(offset dos pré-requisitos) + 1)[/code] (piso de 1 período, pois a
## matrícula do período atual já está fechada). [br]
## Retorna [code]{ "offset": int, "cadeia": Array[Dictionary] }[/code], onde [code]offset[/code] é o
## maior offset entre as obrigatórias pendentes/em curso ([code]-1[/code] se nenhuma restar) e
## [code]cadeia[/code] é a sequência determinante (do início ao fim), cada item
## [code]{ "codigo": String, "nome": String }[/code].
func caminho_critico_formatura(grade: Dictionary, cursadas: Array, em_curso: Array) -> Dictionary:
	# Conjuntos de consulta rápida (códigos em minúsculas).
	var concluidas: Dictionary = {}
	for c in cursadas:
		concluidas[str(c).to_lower()] = true
	var matriculadas: Dictionary = {}
	for c in em_curso:
		matriculadas[str(c).to_lower()] = true
	# Memoização do offset de conclusão e do pré-requisito escolhido (para reconstruir a cadeia).
	var offsets: Dictionary = {}
	var escolhido: Dictionary = {}  # codigo -> codigo do pré-requisito que gerou o offset, ou ""
	for codigo in grade.keys():
		var cod: String = str(codigo).to_lower()
		if grade[codigo].has("posicao_grade"):
			_offset_conclusao(cod, grade, concluidas, matriculadas, offsets, escolhido)
	# Disciplina obrigatória pendente/em curso de maior offset (o gargalo).
	var offset_max: int = -1
	var alvo: String = ""
	for cod in offsets.keys():
		if offsets[cod] > offset_max:
			offset_max = offsets[cod]
			alvo = cod
	# Reconstrói a cadeia retrocedendo pelo pré-requisito escolhido a cada nó.
	var cadeia: Array[Dictionary] = []
	if offset_max >= 0:
		var caminho: Array[String] = []
		var atual: String = alvo
		while atual != "":
			caminho.append(atual)
			atual = escolhido.get(atual, "")
		caminho.reverse()
		for cod in caminho:
			cadeia.append({
				"codigo": cod,
				"nome": str(grade.get(cod, {}).get("nome", cod.to_upper())),
			})
	return { "offset": offset_max, "cadeia": cadeia }

# Offset de conclusão de [param cod] (memoizado em [param offsets]), registrando em [param escolhido]
# o pré-requisito que determinou o offset. Disciplinas concluídas retornam -1; em curso, 0; pendentes,
# max(1, melhor pré-requisito + 1). Só pré-requisitos OBRIGATÓRIOS (presentes na grade) contam.
func _offset_conclusao(cod: String, grade: Dictionary, concluidas: Dictionary, matriculadas: Dictionary, \
offsets: Dictionary, escolhido: Dictionary) -> int:
	if offsets.has(cod):
		return offsets[cod]
	if concluidas.has(cod):
		return -1  # Concluída: não memoiza no mapa de pendentes (não conta para o offset máximo).
	# Marca em andamento (evita laço em grades eventualmente cíclicas) antes de recorrer.
	offsets[cod] = 0
	escolhido[cod] = ""
	if matriculadas.has(cod):
		return 0
	var melhor: int = -1
	var melhor_pre: String = ""
	for pre in obter_prerequisitos(cod, grade):
		if not grade.has(pre):
			continue
		var off_pre: int = _offset_conclusao(pre, grade, concluidas, matriculadas, offsets, escolhido)
		if off_pre > melhor:
			melhor = off_pre
			melhor_pre = pre
	var resultado: int = max(1, melhor + 1)
	offsets[cod] = resultado
	# Só encadeia o pré-requisito se ele próprio ainda for pendente/em curso (offset >= 0).
	escolhido[cod] = melhor_pre if melhor >= 0 else ""
	return resultado

## Retorna os códigos das disciplinas que têm [param codigo] como pré-requisito em [param grade]. [br]
## Itera todas as disciplinas verificando suas chaves [code]prerequisito{N}[/code]. [br]
## Retorna Array vazia se nenhuma disciplina depender de [param codigo].
func obter_disciplinas_bloqueadas(codigo: String, grade: Dictionary) -> Array[String]:
	var bloqueadas: Array[String] = []
	var codigo_lower: String = codigo.to_lower()
	for cod_disc in grade.keys():
		var i: int = 0
		while grade[cod_disc].has("prerequisito" + str(i)):
			if str(grade[cod_disc]["prerequisito" + str(i)]).to_lower() == codigo_lower:
				bloqueadas.append(str(cod_disc).to_lower())
				break
			i += 1
	return bloqueadas

## Retorna o encadeamento transitivo de disciplinas bloqueadas por [param codigo]. [br]
## Percorre em largura (BFS): primeiro as que dependem diretamente de [param codigo], depois as que
## dependem destas, e assim por diante. [br]
## Retorna um [Dictionary] [code]{codigo: nome_da_cor}[/code] onde a cor indica a profundidade: [br]
## - Profundidade 1: [code]RED[/code]; [br]
## - Profundidade 2: [code]ORANGE[/code]; [br]
## - Profundidade 3: [code]YELLOW[/code]; [br]
## - Profundidade 4: [code]GREEN[/code]; [br]
## - Profundidade 5: [code]DARK_GREEN[/code]; [br]
## - Profundidade 6+: [code]LIGHT_GREEN[/code].
func obter_bloqueadas_transitivas(codigo: String, grade: Dictionary) -> Dictionary:
	var cores: Dictionary = {}
	var codigo_lower: String = codigo.to_lower()
	var visitados: Array[String] = [codigo_lower]
	var fila: Array[Array] = [[codigo_lower, 0]]  # [código, profundidade]
	var idx: int = 0
	while idx < fila.size():
		var atual: Array = fila[idx]
		var cod_atual: String = atual[0]
		var prof: int = atual[1]
		idx += 1
		for cod_disc in grade.keys():
			var disc_lower: String = str(cod_disc).to_lower()
			if disc_lower in visitados:
				continue
			var i: int = 0
			while grade[cod_disc].has("prerequisito" + str(i)):
				if str(grade[cod_disc]["prerequisito" + str(i)]).to_lower() == cod_atual:
					var nova_prof: int = prof + 1
					cores[disc_lower] = _cor_por_profundidade(nova_prof)
					visitados.append(disc_lower)
					fila.append([disc_lower, nova_prof])
					break
				i += 1
	return cores

## Retorna o nome da cor correspondente a uma [param profundidade] na cadeia de pré-requisitos.
func _cor_por_profundidade(profundidade: int) -> String:
	match profundidade:
		1: return "RED"
		2: return "ORANGE"
		3: return "YELLOW"
		4: return "GREEN"
		5: return "DARK_GREEN"
		_: return "LIGHT_GREEN"

## Pega a lista de json de equivalências e verifica quais são utilizáveis para a grade atual. [br]
## Compara estritamente o destino (sufixo após [code]-[/code]) com [param versao_grade] para evitar
## falsos positivos entre cursos com mesma versão (e.g. [code]alea_2023[/code] vs [code]alec_2023[/code]).
func determinar_aproveitaveis(equivalencias: Dictionary, versao_grade: String) -> Array[String]:
	# Função de pouca utilidade agora, mas pode ser útil quando houverem multiplas equivalencias para a mesma grade
	# Exemplo: alec_2010-alec_2023, alec_2025-alec_2023, etc. Isto é, alunos versão alec_2023 podem cursar
	# quais disciplinas de alec_2010 ou alec_2025 e aproveitar?
	var lista: Array[String] = []
	for key in equivalencias.keys():
		# Verifica se o destino bate exatamente com [param versao_grade].
		var partes: PackedStringArray = key.split("-")
		if partes.size() == 2 and partes[1] == versao_grade:
			lista.append(key)
	return lista

## Verifica se existem equivalências para as disciplinas. [br]
## Formato de [param cursaveis] deve ser uma chave para cada [param condicoes] e em cada chave a lista 
## de disciplinas que se enquadram na condição. [br]
## Formato de [param condicoes] deve ser a lista de condições no arquivo [code]base_config.json[/code]. [br]
func obter_equivalencias(cursaveis: Dictionary, equivalencias: Dictionary, versao_grade: String, condicoes: Array) -> Dictionary:
	# Com a lista de disciplinas cursaveis (matriculado_agora, matriculáveis, seaprovado, etc), verifica se existem equivalências para estas
	# Caso exista, adiciona em uma nova chave com "_aproveitamento" ao final. Exemplo: cursa química do curriculo alec_2023
	#  e coloca al0366 na lista de "matriculado_agora_aproveitamento" dentro de cursaveis.
	var lista_disciplinas_equivalentes: Array[String] = []
	for cond in range(0,condicoes.size(),1):
		lista_disciplinas_equivalentes = []
		var condicao_atual: String = condicoes[cond]
		# Pula ambas as formas de matrícula: "matriculado_agora" e "matriculado_agora_aproveitamento"
		# já vêm completas do pós-processamento de disciplinas_cursaveis (com os códigos da grade ATUAL,
		# necessários para colorir a célula na Grade Curricular e casar em matriculada_com_turma).
		# Reprocessá-las aqui converteria esses códigos-alvo de volta para os códigos-fonte de outra
		# grade (via codigos_origem_equivalencia), que não existem na grade atual e somem da indicação.
		if condicao_atual != "matriculado_agora" and condicao_atual != "matriculado_agora_aproveitamento":
			for b in cursaveis[condicao_atual].size():
				lista_disciplinas_equivalentes.append_array(
					codigos_origem_equivalencia(cursaveis[condicao_atual][b], equivalencias, versao_grade)
				)
			if lista_disciplinas_equivalentes.size() > 0:
				if condicao_atual.ends_with("_aproveitamento"):
					cursaveis[condicao_atual] = []
				else:
					cursaveis[condicao_atual+"_aproveitamento"] = []
			for a in lista_disciplinas_equivalentes.size():
				if condicao_atual.ends_with("_aproveitamento"):
					cursaveis[condicao_atual].append(lista_disciplinas_equivalentes[a])
				else:
					cursaveis[condicao_atual+"_aproveitamento"].append(lista_disciplinas_equivalentes[a])
	return cursaveis

## Dado um codigo alvo (na grade atual), retorna os codigos fonte das equivalencias [br]
## que mapeiam para ele. Suporta equivalencias 1:N (Array de Strings no JSON). [br]
## Exemplo: se "alcc_0000-alec_2023" contem "al0493": "al0005", [br]
## entao codigos_origem_equivalencia("al0005", equivalencias, "alec_2023") retorna ["al0493"].
func codigos_origem_equivalencia(codigo_alvo: String, equivalencias: Dictionary, versao_grade: String) -> Array[String]:
	var codigos_origem: Array[String] = []
	var equiv_para_versao: Array[String] = determinar_aproveitaveis(equivalencias, versao_grade)
	for equiv_key in equiv_para_versao:
		for src_codigo in equivalencias[equiv_key].keys():
			var valor = equivalencias[equiv_key][src_codigo]
			var encontrado: bool = false
			if valor is String and valor.to_lower() == codigo_alvo.to_lower():
				encontrado = true
			elif valor is Array and codigo_alvo.to_lower() in valor:
				encontrado = true
			if encontrado:
				codigos_origem.append(src_codigo)
	return codigos_origem

## Soma as reprovações (por nota e por falta) de [param codigo] na grade [param versao_grade] com as
## de seus códigos equivalentes de outras grades — aproveitamento de reprovações. Ex.: o aluno reprovou
## várias vezes na disciplina da grade antiga e, após migrar de PPC, cursa a equivalente na grade nova;
## as reprovações da versão antiga são contadas junto. [br]
## [param reprov_matr] é a entrada de UMA matrícula em [method AnaliseReprovacoes.analise_reprovacoes]:
## [code]{ "reprovado com nota": {cod: n}, "reprovado por frequência": {cod: n} }[/code] (códigos em
## minúsculas). Retorna [code]{ "nota": int, "falta": int }[/code].
func reprovacoes_aproveitadas(reprov_matr: Dictionary, codigo: String, equivalencias: Dictionary, versao_grade: String) -> Dictionary:
	var rn: Dictionary = reprov_matr.get("reprovado com nota", {})
	var rf: Dictionary = reprov_matr.get("reprovado por frequência", {})
	var cl: String = codigo.to_lower()
	var nota: int = int(rn.get(cl, 0))
	var falta: int = int(rf.get(cl, 0))
	for cod_origem in codigos_origem_equivalencia(codigo, equivalencias, versao_grade):
		var ol: String = str(cod_origem).to_lower()
		if ol == cl:
			continue
		nota += int(rn.get(ol, 0))
		falta += int(rf.get(ol, 0))
	return { "nota": nota, "falta": falta }

## Retorna true se [param cod_alvo] é "completo" para o aluno: existe ao menos um grupo de
## equivalência (mesma grade-fonte, i.e. mesma chave em [member equivalencias]) cujas TODAS as fontes
## que mapeiam para [param cod_alvo] estão em [param codigos_presentes] ([code]{ cod_lower: true }[/code]).
## [br]
## Trata o caso de "disciplina dividida": quando a grade nova quebra uma disciplina antiga em duas
## (ex.: Saneamento Básico → I + II), o aluno só aproveita a antiga cursando ambas as partes.
## Para alvos 1:1 (fonte única) basta a fonte. Agrupar por grade-fonte preserva rotas alternativas
## (OR entre grupos, AND dentro do grupo). Sem nenhuma fonte mapeando para o alvo, retorna true (não
## bloqueia — caso normal sem equivalência).
func alvo_completo(cod_alvo: String, equivalencias: Dictionary, versao_grade: String, codigos_presentes: Dictionary) -> bool:
	var equiv_keys: Array[String] = determinar_aproveitaveis(equivalencias, versao_grade)
	var houve_grupo: bool = false
	for key in equiv_keys:
		var fontes: Array[String] = []
		for src_codigo in equivalencias[key].keys():
			var valor = equivalencias[key][src_codigo]
			var bate: bool = false
			if valor is String and valor.to_lower() == cod_alvo.to_lower():
				bate = true
			elif valor is Array:
				for v in valor:
					if str(v).to_lower() == cod_alvo.to_lower():
						bate = true
						break
			if bate:
				fontes.append(str(src_codigo).to_lower())
		if fontes.is_empty():
			continue
		houve_grupo = true
		var todas: bool = true
		for f in fontes:
			if not codigos_presentes.has(f):
				todas = false
				break
		if todas:
			return true
	return not houve_grupo

## Pega cada código de disciplina contido em ~equivalencias_para_versao e obtem a equivalencia para a [param versao_grade]. [br]
## Formato de [param cod_disciplina] deve ser o código da disciplina em String (e.g. "al0001").
func para_o_codigo_qual_a_equivalencia(cod_disciplina: String, equivalencias: Dictionary, versao_grade: String) -> Array[String]:
	# O formato gerado de ~disciplinas_a_serem_aproveitadas são arrays dentro da array
	# Exemplo: [[AL0001],[AL0004, AL0003]]
	var lista_disciplinas_equivalentes: Array[String] = []
	var equivalencias_para_versao: Array[String] = determinar_aproveitaveis(equivalencias, versao_grade)
	for a in equivalencias_para_versao.size():
		# Itera apenas sobre as chaves já filtradas por [method determinar_aproveitaveis], que faz
		# a comparação estrita do destino (sufixo após [code]-[/code]).
		var key: String = equivalencias_para_versao[a]
		for key2 in equivalencias[key].keys():
			if cod_disciplina == key2:
				var valor = equivalencias[key][key2]
				if valor is String:
					lista_disciplinas_equivalentes.append(valor)
				elif valor is Array:
					lista_disciplinas_equivalentes.append_array(valor)
	return lista_disciplinas_equivalentes

## Remove da carga horária exigida para formação as horas referentes a disciplinas marcadas para ignorar no json. 
## Usado para o cálculo da % de liberação do TCC, que não inclui algumas disciplinas. Verificar "ignorahora" no 
## arquivo json na pasta "cargaexigida". [br]
## Formato de [param ch_exigida] deve ser a lista de condições nos arquivos em [code]/arquivos/cargaexigida[/code]. [br]
## Formato de [param grade_disciplina] deve ser de um arquivo de [code]/arquivos/grades[/code], não da combinação. [br]
func ajustarch_tccestagio(grade_disciplina: Dictionary, ch_exigida: Dictionary) -> Dictionary:
	var ch_ajustada: Dictionary = ch_exigida
	for cod_disc in grade_disciplina.keys():
		var nucleo: String = grade_disciplina[cod_disc].get("nucleo", "")
		if nucleo != "" and ch_exigida.has(nucleo):
			var ch: int = int(grade_disciplina[cod_disc].get("ch", "-1"))
			if ch == -1:
					print_debug("ERRO: Disciplina ", cod_disc, " sem carga horária informada!")
			else:
				if grade_disciplina[cod_disc].get("ignorahora", "false") == "true":
					ch_ajustada[nucleo] = str(int(ch_exigida[nucleo]) - ch)
				else:
					ch_ajustada[nucleo] = ch_exigida[nucleo]
	return ch_ajustada


## Valida as disciplinas das grades curriculares contra o cadastro oficial
## (relatório 5104 - Cadastro de disciplinas por campus).
##
## Parâmetros:
## - [param grades_disciplinas_curriculos]: dicionário de grades
##   (chave = grade_key ex: "alec_2023", valor = Dict de disciplinas)
## - [param dir_cadastro]: diretório do CSV do relatório 5104
## - [param arquivo_cadastro]: nome do arquivo CSV
##
## Retorna Dictionary com:
## - grade_sem_cadastro (Array): disciplinas na grade que não existem no cadastro
## - inativas_no_cadastro (Array): disciplinas da grade com situação inativa
## - ch_divergente (Array): carga horária diferente entre grade e cadastro
## - nome_divergente (Array): nome diferente entre grade e cadastro (ignora acentos, maiúsculas e espaços)
## - cadastro_sem_grade (Array): disciplinas ativas no cadastro não usadas em grade alguma
func validar_contra_cadastro(grades_disciplinas_curriculos: Dictionary, \
		dir_cadastro: String, arquivo_cadastro: String) -> Dictionary:
	var fh := FileHandling.new()
	var temp_dir: String = dir_cadastro
	var temp_file: String = "out_5104.csv"

	fh.convertto_utf8(dir_cadastro, arquivo_cadastro, temp_dir, temp_file)

	var linhas: Array[Array] = fh.read_csvfile(temp_dir, temp_file, \
		[2, 3, 5, 6, 8], [-1], [";", ","])

	# Remove o CSV temporário convertido — não é mais necessário após a leitura.
	fh.remove_file(temp_dir, temp_file)

	if linhas.is_empty():
		push_error("Falha ao ler o CSV do cadastro 5104.")
		return {}

	var cadastro: Dictionary = {}
	for linha in linhas:
		if linha.size() < 5:
			continue
		var cod: String = linha[0]
		if not cod.begins_with("al"):
			continue
		cadastro[cod] = {
			"nome": linha[1],
			"cursos": linha[2],
			"ch": linha[3],
			"situacao": linha[4]
		}

	var resultado: Dictionary = {
		"grade_sem_cadastro": [],
		"inativas_no_cadastro": [],
		"ch_divergente": [],
		"nome_divergente": [],
		"cadastro_sem_grade": []
	}

	for grade_key in grades_disciplinas_curriculos:
		var grade: Dictionary = grades_disciplinas_curriculos[grade_key]
		for codigo in grade.keys():
			var cod_lower: String = codigo.to_lower()
			var nome: String = str(grade[codigo].get("nome", ""))
			var ch_grade: String = str(grade[codigo].get("ch", ""))

			if not cadastro.has(cod_lower):
				resultado["grade_sem_cadastro"].append({
					"grade": grade_key,
					"codigo": cod_lower,
					"nome": nome,
					"ch": ch_grade
				})
				continue

			var info: Dictionary = cadastro[cod_lower]

			if info["situacao"] != "ativa":
				resultado["inativas_no_cadastro"].append({
					"grade": grade_key,
					"codigo": cod_lower,
					"nome": nome
				})

			if ch_grade != "" and info["ch"] != "" and ch_grade != info["ch"]:
				resultado["ch_divergente"].append({
					"grade": grade_key,
					"codigo": cod_lower,
					"nome": nome,
					"ch_grade": ch_grade,
					"ch_cadastro": info["ch"]
				})

			var nome_grade_norm: String = general_functions.remover_acentos(nome).replace(" ", "")
			var nome_cadastro_norm: String = general_functions.remover_acentos(info["nome"]).replace(" ", "")
			if nome_grade_norm != nome_cadastro_norm:
				resultado["nome_divergente"].append({
					"grade": grade_key,
					"codigo": cod_lower,
					"nome_grade": nome,
					"nome_cadastro": info["nome"]
				})

	var codigos_nas_grades: Dictionary = {}
	for grade_key in grades_disciplinas_curriculos:
		var grade: Dictionary = grades_disciplinas_curriculos[grade_key]
		for codigo in grade.keys():
			codigos_nas_grades[codigo.to_lower()] = true

	for codigo in cadastro.keys():
		var info: Dictionary = cadastro[codigo]
		if info["situacao"] == "ativa" and not codigos_nas_grades.has(codigo):
			resultado["cadastro_sem_grade"].append({
				"codigo": codigo,
				"nome": info["nome"],
				"cursos": info["cursos"]
			})

	return resultado
