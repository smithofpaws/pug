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

class_name AnaliseReprovacoes extends Resource
## Funções de análise de reprovações: listagem de situações e contagem de reprovações por disciplina.
##
## Extraído de [code]analise_historico.gd[/code] como parte da divisão em responsabilidades únicas.

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
	for b in situacao.size():
		situacao[b] = situacao[b].to_lower()
	var lista: Dictionary = {}
	var lista_situacoes: Dictionary = {}
	for matr in historico.keys():
		lista_situacoes[matr] = {}
		# Primeiro verifica para a matricula quais situações são verificadas para quais disciplinas
		for a in historico[matr]["dados"].size():
			for b in situacao.size():
				if historico[matr]["dados"][a].get("situacao", "").to_lower() == situacao[b]:
					if not lista.has(situacao[b]):
						lista[situacao[b]] = []
					lista[situacao[b]].append(historico[matr]["dados"][a].get("codigocurriculo","CODIGO NAO ENCONTRADO"))
		# Depois, para esta matricula, cria a lista de disciplinas em cada situação
		for b in situacao.size():
			if lista.has(situacao[b]):
				if lista[situacao[b]].size() > 0:
					lista_situacoes[matr][situacao[b]] = lista[situacao[b]].duplicate()
		lista.clear()
	return lista_situacoes

## Conta as reprovações por disciplina para cada matrícula. [br]
## Formato de [param lista_situacoes] deve ser a saída de [method listar_situacao]: [br]
## { "matricula": { "situacao": ["codigo1", "codigo2", ...] } } [br]
## Retorna um dicionário com a contagem: [br]
## { [br]
##   "matricula": { [br]
##     "situacao": { [br]
##       "codigo": quantidade_de_reprovacoes [br]
##     } [br]
##   } [br]
## } [br]
## Exemplo: se um aluno reprovou AL0005 duas vezes por nota e uma por falta: [br]
## { "2410102467": { "reprovado com nota": {"al0005": 2}, "reprovado por frequência": {"al0005": 1} } }
func analise_reprovacoes(lista_situacoes: Dictionary) -> Dictionary:
	var _analisado_reprov: Dictionary = {}
	for matr in lista_situacoes.keys():
		_analisado_reprov[matr] = {}
		for situacao in lista_situacoes[matr].keys():
			if not _analisado_reprov[matr].has(situacao):
				_analisado_reprov[matr][situacao] = {}
			for a in lista_situacoes[matr][situacao].size():
				var cod_disc: String = lista_situacoes[matr][situacao][a]
				if not _analisado_reprov[matr][situacao].has(cod_disc):
					_analisado_reprov[matr][situacao][cod_disc] = 1
				else:
					_analisado_reprov[matr][situacao][cod_disc] = _analisado_reprov[matr][situacao][cod_disc] + 1
	return _analisado_reprov

## Calcula o índice de aprovação semestre a semestre de uma [param matricula]: o percentual de
## disciplinas aprovadas dentre as cursadas em cada período letivo. [br]
## Só entram na conta as disciplinas com resultado ("aprovado*" ou "reprovado*"): matrículas em aberto,
## dispensas, trancamentos e aproveitamentos não são disciplinas efetivamente cursadas e avaliadas. [br]
## Períodos letivos especiais (verão/inverno) não têm número de semestre e são ignorados. [br]
## Retorna uma Array ordenada do período mais antigo ao mais recente, no formato: [br]
## [ { [br]
## "ano": 2023, [br]
## "semestre": 1, [br]
## "periodo": "2023/1", [br]
## "aprovadas": 5, [br]
## "cursadas": 7, [br]
## "percentual": 71.43, [br]
## "ch_cursada": 405.0, [br]
## "ch_reprovada": 120.0, [br]
## "ch_aprovada": 285.0, [br]
## "percentual_ch_aprovada": 70.37, [br]
## "apto_estagio": true [br]
## } ] [br]
## [param limite_reprovacao_estagio] (de [code]base_config.json:estagio.limite_reprovacao[/code]) rege
## [code]apto_estagio[/code]: o regulamento exige, para
## solicitar estágio, "não ter reprovado por frequência e por nota em mais de 60% da carga horária dos
## componentes curriculares em que estava matriculado no semestre regular imediatamente anterior".
## O critério é por CARGA HORÁRIA, então não acompanha o percentual de aprovação da mesma linha
## (que conta disciplinas): reprovar só nas disciplinas pesadas pesa mais aqui. [br]
## [code]Atenção:[/code] exige o histórico COMPLETO, antes de
## [method AnaliseCurricular.simplificar_historico] — a simplificação descarta as reprovações, que são
## justamente o denominador deste cálculo.
func indice_aprovacao(matricula: String, historico: Dictionary, \
limite_reprovacao_estagio: float = 0.6) -> Array[Dictionary]:
	# Cada disciplina conta uma única vez por período: a exportação do GURI repete a mesma matrícula em
	# linhas que diferem em colunas como turma e docente, e a deduplicação da leitura (que compara a
	# linha inteira) não as descarta. Na divergência entre as repetições, a aprovação prevalece.
	var periodos: Dictionary = {}
	for dado in historico.get(matricula, {}).get("dados", []):
		var situacao: String = str(dado.get("situacao", "")).to_lower()
		var aprovada: bool = situacao.begins_with("aprovado")
		if not aprovada and not situacao.begins_with("reprovado"):
			continue
		var ano: int = int(dado.get("ano", ""))
		var semestre: int = int(dado.get("semestre", ""))
		if ano <= 0 or semestre < 1 or semestre > 2:
			continue
		var chave: String = "%d/%d" % [ano, semestre]
		if not periodos.has(chave):
			periodos[chave] = {"ano": ano, "semestre": semestre, "disciplinas": {}}
		var codigo: String = str(dado.get("codigocurriculo", "")).to_lower()
		var disciplinas_periodo: Dictionary = periodos[chave]["disciplinas"]
		disciplinas_periodo[codigo] = {
			"aprovada": aprovada or disciplinas_periodo.get(codigo, {}).get("aprovada", false),
			"ch": float(dado.get("cargahoraria", "0")),
		}
	var chaves: Array = periodos.keys()
	chaves.sort_custom(func(a: String, b: String) -> bool:
		if periodos[a]["ano"] != periodos[b]["ano"]:
			return periodos[a]["ano"] < periodos[b]["ano"]
		return periodos[a]["semestre"] < periodos[b]["semestre"])
	var indice: Array[Dictionary] = []
	for chave in chaves:
		var disciplinas: Dictionary = periodos[chave]["disciplinas"]
		var aprovadas: int = 0
		var ch_cursada: float = 0.0
		var ch_reprovada: float = 0.0
		for cod in disciplinas.keys():
			ch_cursada += disciplinas[cod]["ch"]
			if disciplinas[cod]["aprovada"]:
				aprovadas += 1
			else:
				ch_reprovada += disciplinas[cod]["ch"]
		var cursadas: int = disciplinas.size()
		indice.append({
			"ano": periodos[chave]["ano"],
			"semestre": periodos[chave]["semestre"],
			"periodo": chave,
			"aprovadas": aprovadas,
			"cursadas": cursadas,
			"percentual": float(aprovadas) / float(cursadas) * 100.0,
			"ch_cursada": ch_cursada,
			"ch_reprovada": ch_reprovada,
			# Apresentada como APROVAÇÃO, para ler no mesmo sentido do percentual de disciplinas — o
			# regulamento fala em reprovação, que é o complemento (não reprovar em mais de 60% da carga
			# horária equivale a aprovar em pelo menos 40% dela).
			"ch_aprovada": ch_cursada - ch_reprovada,
			"percentual_ch_aprovada": ((ch_cursada - ch_reprovada) / ch_cursada * 100.0) \
				if ch_cursada > 0.0 else 0.0,
			# Comparação sem divisão: cobre o caso de CH ausente no histórico (ambas zeradas = apto).
			"apto_estagio": ch_reprovada <= limite_reprovacao_estagio * ch_cursada,
		})
	return indice

## Calcula o índice de aprovação de todas as matrículas do [param historico] de uma só vez, para que o
## [code]main.gd[/code] compute uma única vez (antes da simplificação) o que os módulos consomem. [br]
## Retorna [code]{ "<matricula>": <saída de [method indice_aprovacao]> }[/code].
func indice_aprovacao_todos(historico: Dictionary, limite_reprovacao_estagio: float = 0.6) -> Dictionary:
	var indices: Dictionary = {}
	for matricula in historico.keys():
		indices[matricula] = indice_aprovacao(matricula, historico, limite_reprovacao_estagio)
	return indices

## Aprova todos discentes em todas disciplinas em situação de matrícula. [br]
## [code]Atenção:[/code] Esta função altera o [param historico] original (mutação in-place).
func aprovar_matriculados(historico: Dictionary) -> void:
	print_debug("Aprovando todos discentes nas disciplinas matriculadas.")
	for key in historico.keys():
		if historico[key].has("dados"):
			for a in historico[key]["dados"].size():
				if historico[key]["dados"][a].has("situacao"):
					if historico[key]["dados"][a]["situacao"].begins_with("matr"):
						historico[key]["dados"][a]["situacao"] = "aprovado com nota"
