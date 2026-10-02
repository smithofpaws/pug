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

class_name ValidacaoCurricular extends Resource
## Confere a coerência [b]entre[/b] grades, equivalências e cargas exigidas já carregadas
## (o [JsonValidator] cuida só dos tipos, um arquivo por vez). [br]
## Nada é corrigido nem bloqueado: cada inconsistência vira um achado, e [method validar] o emite
## como [code]push_warning[/code]. [br]
## [br]
## Os três parâmetros seguem o formato de [code]GV.grades[/code], [code]GV.equivalencias[/code] e
## [code]GV.ch_exigida[/code]: uma chave por arquivo, igual ao nome sem [code].json[/code].
## Dicionário vazio vale como arquivo ausente (é como um parse falho chega).

## Prefixo de todo aviso emitido.
const PREFIXO: String = "VALIDACAO COERENCIA"

const _FAMILIAS: Array[String] = ["prerequisito", "corequisito"]

## Devolve os achados de inconsistência, em ordem determinística (grades, equivalências, cargas). [br]
## Cada achado é um [Dictionary] com valores [String]: [code]regra[/code], [code]chave[/code],
## [code]codigo[/code] e as chaves específicas da regra. Função pura: não emite aviso nem muta os
## argumentos.
static func inconsistencias(grades: Dictionary, equivalencias: Dictionary, cargas_exigidas: Dictionary) -> Array[Dictionary]:
	var achados: Array[Dictionary] = []
	for chave: Variant in grades:
		var grade: Variant = grades[chave]
		if grade is Dictionary and not grade.is_empty():
			achados.append_array(_inconsistencias_grade(str(chave), grade))
	for chave: Variant in equivalencias:
		var mapa: Variant = equivalencias[chave]
		if mapa is Dictionary and not mapa.is_empty():
			achados.append_array(_inconsistencias_equivalencia(str(chave), mapa, grades))
	for chave: Variant in cargas_exigidas:
		var carga: Variant = cargas_exigidas[chave]
		var grade: Variant = grades.get(chave)
		if carga is Dictionary and not carga.is_empty() and grade is Dictionary and not grade.is_empty():
			achados.append_array(_inconsistencias_carga(str(chave), grade, carga))
	return achados

## Converte um achado na mensagem de aviso, citando o arquivo, a disciplina e o código. [br]
## Regra desconhecida não quebra: sai o dicionário bruto.
static func formatar(achado: Dictionary) -> String:
	var chave: String = achado.get("chave", "")
	var codigo: String = achado.get("codigo", "")
	var nome: String = achado.get("nome", "")
	var valor: String = achado.get("valor", "")
	var campo: String = achado.get("campo", "")
	var alvo: String = codigo if nome.is_empty() else "%s (%s)" % [codigo, nome]
	var grade: String = "grades/" + chave + ".json"
	var cabecalho: String = PREFIXO + ": "
	match achado.get("regra", ""):
		"requisito_inexistente":
			return cabecalho + "%s -> %s: %s aponta para '%s', que nao existe nesta grade" % [grade, alvo, campo, valor]
		"requisito_numeracao":
			var ausente: String = achado.get("indice_ausente", "")
			return cabecalho + "%s -> %s: numeracao de %s pula o indice %s; os seguintes nao sao lidos pelo programa" % [grade, alvo, campo, ausente]
		"requisito_fora_de_ordem":
			var dados: Array = [grade, alvo, campo, valor, achado.get("semestre_requisito", ""), achado.get("semestre", "")]
			return cabecalho + "%s -> %s: %s = %s e do semestre %s, igual ou posterior ao da disciplina (%s)" % dados
		"semestre_posicao_divergente":
			var dados: Array = [grade, alvo, achado.get("semestre", ""), achado.get("posicao_grade", "")]
			return cabecalho + "%s -> %s: semestre %s difere de posicao_grade[0] = %s" % dados
		"equivalencia_inexistente":
			var dados: Array = [chave, codigo, valor, campo, achado.get("grade", "")]
			return cabecalho + "equivalencias/%s.json -> %s: codigo '%s' (%s) nao existe na grade %s" % dados
		"nucleo_sem_carga":
			var dados: Array = [chave, codigo, achado.get("disciplinas", ""), grade]
			return cabecalho + "cargaexigida/%s.json nao tem a chave '%s', nucleo usado por %s disciplina(s) de %s" % dados
	return cabecalho + str(achado)

## Emite um [code]push_warning[/code] por achado de [method inconsistencias] e devolve quantos
## emitiu. Sem achado, não emite nada.
static func validar(grades: Dictionary, equivalencias: Dictionary, cargas_exigidas: Dictionary) -> int:
	var achados: Array[Dictionary] = inconsistencias(grades, equivalencias, cargas_exigidas)
	for achado in achados:
		push_warning(formatar(achado))
	return achados.size()

# Regras de requisito, numeracao e semestre de uma grade.
static func _inconsistencias_grade(chave: String, grade: Dictionary) -> Array[Dictionary]:
	var achados: Array[Dictionary] = []
	for codigo: Variant in grade:
		var disc: Variant = grade[codigo]
		if not disc is Dictionary:
			continue
		var nome: String = str(disc.get("nome", ""))
		var base: Dictionary = {"chave": chave, "codigo": str(codigo), "nome": nome}
		for familia in _FAMILIAS:
			var indices: Array[int] = _indices_da_familia(disc, familia)
			for indice in indices:
				var campo: String = familia + str(indice)
				var valor: String = str(disc[campo])
				if not grade.has(valor):
					achados.append(_achado("requisito_inexistente", base, {"campo": campo, "valor": valor}))
			var ausente: int = _primeiro_indice_ausente(indices)
			if not indices.is_empty() and indices.max() > ausente:
				achados.append(_achado("requisito_numeracao", base, {"campo": familia, "indice_ausente": str(ausente)}))
		achados.append_array(_inconsistencias_semestre(grade, disc, base))
	return achados

# Ordem dos pre-requisitos e coerencia de semestre com posicao_grade.
static func _inconsistencias_semestre(grade: Dictionary, disc: Dictionary, base: Dictionary) -> Array[Dictionary]:
	var achados: Array[Dictionary] = []
	var semestre: int = _semestre(disc)
	if disc.has("posicao_grade"):
		var posicao: Variant = disc["posicao_grade"]
		var semestre_posicao: int = -1
		var posicao_texto: String = str(posicao)
		if posicao is Array and not posicao.is_empty() and (posicao[0] is float or posicao[0] is int):
			semestre_posicao = int(posicao[0])
			posicao_texto = str(semestre_posicao)
		if semestre != semestre_posicao:
			achados.append(_achado("semestre_posicao_divergente", base, {"semestre": str(semestre), "posicao_grade": posicao_texto}))
	if not _participa_da_ordem(disc):
		return achados
	var corequisitos: Array[String] = []
	for indice in _indices_da_familia(disc, "corequisito"):
		corequisitos.append(str(disc["corequisito" + str(indice)]))
	for indice in _indices_da_familia(disc, "prerequisito"):
		var campo: String = "prerequisito" + str(indice)
		var valor: String = str(disc[campo])
		var requisito: Variant = grade.get(valor)
		if not requisito is Dictionary or not _participa_da_ordem(requisito) or valor in corequisitos:
			continue
		var semestre_requisito: int = _semestre(requisito)
		if semestre_requisito >= semestre:
			achados.append(_achado("requisito_fora_de_ordem", base, {"campo": campo, "valor": valor, "semestre": str(semestre), "semestre_requisito": str(semestre_requisito)}))
	return achados

# Equivalencia <origem>-<destino>: codigos precisam existir nas grades carregadas (menos placeholder).
static func _inconsistencias_equivalencia(chave: String, mapa: Dictionary, grades: Dictionary) -> Array[Dictionary]:
	var achados: Array[Dictionary] = []
	var partes: PackedStringArray = chave.split("-")
	if partes.size() != 2:
		return achados
	var origem: String = partes[0]
	var destino: String = partes[1]
	for fonte: Variant in mapa:
		var codigo: String = str(fonte)
		if codigo.begins_with("//"):
			continue
		var base: Dictionary = {"chave": chave, "codigo": codigo}
		if _grade_conferivel(origem, grades) and not grades[origem].has(codigo):
			achados.append(_achado("equivalencia_inexistente", base, {"campo": "origem", "valor": codigo, "grade": origem}))
		var alvos: Variant = mapa[fonte]
		var lista: Array = alvos if alvos is Array else [alvos]
		if not (alvos is String or alvos is Array) or not _grade_conferivel(destino, grades):
			continue
		for alvo: Variant in lista:
			if alvo is String and not grades[destino].has(alvo):
				achados.append(_achado("equivalencia_inexistente", base, {"campo": "destino", "valor": alvo, "grade": destino}))
	return achados

# Cada nucleo usado na grade precisa ter chave na carga exigida. Um achado por nucleo.
static func _inconsistencias_carga(chave: String, grade: Dictionary, carga: Dictionary) -> Array[Dictionary]:
	var usos: Dictionary = {}
	for codigo: Variant in grade:
		var disc: Variant = grade[codigo]
		if not disc is Dictionary:
			continue
		var nucleo: String = str(disc.get("nucleo", ""))
		if not nucleo.is_empty():
			usos[nucleo] = int(usos.get(nucleo, 0)) + 1
	var achados: Array[Dictionary] = []
	for nucleo: Variant in usos:
		if not carga.has(nucleo):
			achados.append({"regra": "nucleo_sem_carga", "chave": chave, "codigo": str(nucleo), "disciplinas": str(usos[nucleo])})
	return achados

# Monta o achado: regra + campos comuns (chave, codigo, nome) + campos da regra.
static func _achado(regra: String, base: Dictionary, extras: Dictionary) -> Dictionary:
	var achado: Dictionary = {"regra": regra}
	achado.merge(base)
	achado.merge(extras)
	return achado

# Grade de placeholder (_0000), ausente ou vazia nao e conferida.
static func _grade_conferivel(chave: String, grades: Dictionary) -> bool:
	var grade: Variant = grades.get(chave)
	return not chave.ends_with("_0000") and grade is Dictionary and not grade.is_empty()

# Indices K, em ordem crescente, das chaves "<prefixo>K" da disciplina (K inteiro).
static func _indices_da_familia(disc: Dictionary, prefixo: String) -> Array[int]:
	var indices: Array[int] = []
	for campo: Variant in disc:
		var texto: String = str(campo)
		if texto.begins_with(prefixo) and texto.substr(prefixo.length()).is_valid_int():
			indices.append(int(texto.substr(prefixo.length())))
	indices.sort()
	return indices

# Primeiro indice que a leitura sequencial do programa (0, 1, 2...) nao encontra.
static func _primeiro_indice_ausente(indices: Array[int]) -> int:
	var proximo: int = 0
	while proximo in indices:
		proximo += 1
	return proximo

# Semestre como inteiro; nao numerico conta como 0.
static func _semestre(disc: Dictionary) -> int:
	var valor: Variant = disc.get("semestre", 0)
	if valor is String:
		return int(valor) if valor.is_valid_int() else 0
	if valor is float or valor is int:
		return int(valor)
	return 0

# Participa da ordem quem tem posicao_grade e semestre > 0 (exclui complementar e placeholder).
static func _participa_da_ordem(disc: Dictionary) -> bool:
	return disc.has("posicao_grade") and _semestre(disc) > 0
