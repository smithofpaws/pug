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

class_name CargaDocente extends Resource
## Decide quem entra no relatorio de carga horaria do Planejamento de Oferta, com qual carga e
## qual status, e monta o conjunto da lista oficial de professores por curso. [br]
## Funcoes puras: recebem tudo por parametro e nao mutam os argumentos.

## Indexa a lista oficial crua: devolve [code]{ chave_minuscula: { nome_normalizado: true } }[/code].
static func indexar_lista_oficial(lista_professores: Dictionary) -> Dictionary:
	var indexada: Dictionary = {}
	for chave: Variant in lista_professores:
		var lista: Variant = lista_professores[chave]
		if not lista is Array:
			continue
		var nomes_normalizados: Dictionary = {}
		for nome: Variant in lista:
			var normalizado: String = AnaliseAfinidade.normalizar_nome(str(nome))
			if not normalizado.is_empty():
				nomes_normalizados[normalizado] = true
		indexada[str(chave).to_lower()] = nomes_normalizados
	return indexada


## Une as listas indexadas cujas chaves sao os [code]prefixos_semestre[/code] de [param cod_curso].
## Devolve sempre um [Dictionary] novo, vazio quando nao ha filtro ou o curso nao e conhecido.
static func lista_oficial_do_curso(lista_indexada: Dictionary, cursos: Dictionary, cod_curso: String) -> Dictionary:
	var resultado: Dictionary = {}
	if cod_curso.is_empty():
		return resultado
	var prefixos: Array = cursos.get(cod_curso, {}).get("prefixos_semestre", [])
	for prefixo: Variant in prefixos:
		var chave: String = str(prefixo).to_lower()
		if lista_indexada.has(chave):
			for nome: Variant in lista_indexada[chave]:
				resultado[nome] = true
	return resultado


## Token de status da carga [param ch] frente aos limites de [param config_oferta]:
## [code]acima_maximo[/code], [code]acima_ideal[/code], [code]abaixo_minimo[/code] ou [code]ok[/code].
static func status_carga(ch: int, config_oferta: Dictionary) -> String:
	if ch > int(config_oferta.get("ch_maximo", 20)):
		return "acima_maximo"
	if ch > int(config_oferta.get("ch_ideal", 12)):
		return "acima_ideal"
	if ch < int(config_oferta.get("ch_minimo", 8)):
		return "abaixo_minimo"
	return "ok"


## Professores do relatorio de carga, em [code]{nome, ch, status}[/code], por carga decrescente e
## nome crescente. Sem [param cod_curso], todos com carga no plano. Com curso, quem tem carga e
## lecionou ao curso ou esta na lista oficial, mais toda a lista oficial (com 0 cr se fora do plano).
static func verificacao_carga(carga_por_prof: Dictionary, cod_curso: String, profs_historico_curso: Dictionary, profs_oficiais_curso: Dictionary, config_oferta: Dictionary) -> Array[Dictionary]:
	var linhas: Array[Dictionary] = []
	if carga_por_prof.is_empty():
		return linhas
	var nomes: Dictionary = {}
	if cod_curso.is_empty():
		for nome: Variant in carga_por_prof:
			nomes[nome] = true
	else:
		for nome: Variant in carga_por_prof:
			if profs_historico_curso.has(nome) or profs_oficiais_curso.has(nome):
				nomes[nome] = true
		for nome: Variant in profs_oficiais_curso:
			nomes[nome] = true
	for nome: Variant in nomes:
		var ch: int = int(carga_por_prof.get(nome, 0))
		linhas.append({"nome": str(nome), "ch": ch, "status": status_carga(ch, config_oferta)})
	linhas.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["ch"] != b["ch"]:
			return a["ch"] > b["ch"]
		return a["nome"] < b["nome"])
	return linhas
