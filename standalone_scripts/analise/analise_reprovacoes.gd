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
