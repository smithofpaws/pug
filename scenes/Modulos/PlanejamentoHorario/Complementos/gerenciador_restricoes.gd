class_name GerenciadorRestricoes extends RefCounted
## Gerencia as restrições de alocação da grade de horários. [br]
## Centraliza o CRUD de [member restricoes], as consultas de escopo e a (de)serialização para o
## planejamento.json. A política de interface (undo, repintura, filtro ativo) fica no módulo
## Planejamento de Horário.

## Dicionário de restrições. Chave: [code]"linha_coluna"[/code] → Array de dicionários
## [code]{ "tipo": "professor"|"semestre", "valor": String }[/code].
var restricoes: Dictionary = {}

## Verdadeiro se a célula já tem uma restrição com o mesmo tipo+valor de [param escopo].
func celula_tem(chave_celula: String, escopo: Dictionary) -> bool:
	for r in restricoes.get(chave_celula, []):
		if mesma(r as Dictionary, escopo):
			return true
	return false

## Compara duas restrições por tipo + valor (valor case-insensitive).
func mesma(a: Dictionary, b: Dictionary) -> bool:
	return a.get("tipo", "") == b.get("tipo", "") \
		and str(a.get("valor", "")).to_lower() == str(b.get("valor", "")).to_lower()

## Adiciona a restrição de [param escopo] à célula. Retorna falso (sem mudar nada) com
## parâmetros inválidos ou quando uma restrição idêntica já existe.
func aplicar(linha: int, coluna: int, escopo: Dictionary) -> bool:
	if linha <= 0 or coluna <= 0 or escopo.is_empty():
		return false
	var chave_celula := "%d_%d" % [linha, coluna]
	if celula_tem(chave_celula, escopo):
		return false
	if not restricoes.has(chave_celula):
		restricoes[chave_celula] = []
	restricoes[chave_celula].append({"tipo": escopo.get("tipo", ""), "valor": str(escopo.get("valor", ""))})
	return true

## Remove a restrição de mesmo escopo da célula. Retorna verdadeiro se algo foi removido;
## a célula que fica sem restrições sai do dicionário.
func remover(linha: int, coluna: int, escopo: Dictionary) -> bool:
	if linha <= 0 or coluna <= 0 or escopo.is_empty():
		return false
	var chave_celula := "%d_%d" % [linha, coluna]
	var arr: Array = restricoes.get(chave_celula, [])
	var removeu: bool = false
	for i in range(arr.size() - 1, -1, -1):
		if mesma(arr[i] as Dictionary, escopo):
			arr.remove_at(i)
			removeu = true
	if removeu and arr.is_empty():
		restricoes.erase(chave_celula)
	return removeu

## Verdadeiro se a célula tem alguma restrição cujo escopo casa com o filtro ativo: restrição de
## professor aparece sob o filtro daquele professor; de semestre, quando aquele semestre está filtrado.
func visivel(chave_celula: String, filtro_professor: String, filtro_semestre: Array) -> bool:
	var pf: String = filtro_professor.to_lower()
	for r in restricoes.get(chave_celula, []):
		var tipo: String = (r as Dictionary).get("tipo", "")
		var valor: String = str((r as Dictionary).get("valor", ""))
		if tipo == "professor" and not pf.is_empty() and valor.to_lower() == pf:
			return true
		if tipo == "semestre" and valor in filtro_semestre:
			return true
	return false

## Células restritas cujo escopo casa com algum professor de [param profs] (chaves minúsculas)
## ou com [param semestre] (minúsculo). Independe do filtro ativo — alimenta o alerta
## vermelho+hachura durante o arraste de uma disciplina.
func celulas_com_escopo(profs: Dictionary, semestre: String) -> Dictionary:
	var resultado: Dictionary = {}
	for chave_celula in restricoes:
		for r in restricoes[chave_celula]:
			var tipo: String = (r as Dictionary).get("tipo", "")
			var valor: String = str((r as Dictionary).get("valor", "")).to_lower()
			if (tipo == "professor" and profs.has(valor)) or (tipo == "semestre" and valor == semestre):
				resultado[chave_celula] = true
				break
	return resultado

## Rótulo legível de um escopo de restrição, para o texto do item de menu.
func rotulo_escopo(escopo: Dictionary) -> String:
	if escopo.get("tipo", "") == "professor":
		return "professor " + str(escopo.get("valor", "")).capitalize()
	return "semestre " + str(escopo.get("valor", ""))

## Converte [member restricoes] ("linha_coluna" → restrições) para a lista do planejamento.json,
## gravando por dia/horário (robusto a mudanças de layout, como as alocações). Células fora do
## layout são puladas.
func para_json(dias: Array[String], horas: Array[String]) -> Array:
	var saida: Array = []
	for chave_celula in restricoes:
		var partes: PackedStringArray = chave_celula.split("_")
		if partes.size() != 2:
			continue
		var linha: int = int(partes[0])
		var coluna: int = int(partes[1])
		if linha <= 0 or linha > horas.size() or coluna <= 0 or coluna > dias.size():
			continue
		for r in restricoes[chave_celula]:
			saida.append({
				"dia": dias[coluna - 1],
				"horario": horas[linha - 1],
				"tipo": (r as Dictionary).get("tipo", ""),
				"valor": str((r as Dictionary).get("valor", "")),
			})
	return saida

## Preenche [member restricoes] a partir do planejamento.json carregado, convertendo dia/horário de
## volta para "linha_coluna" (mesmo mapeamento das alocações). Limpa o estado anterior; ignora itens
## fora do layout.
func carregar_do_json(dados: Dictionary, dias: Array[String], horas: Array[String]) -> void:
	restricoes.clear()
	for item in dados.get("restricoes", []):
		if not item is Dictionary:
			continue
		var tipo: String = str((item as Dictionary).get("tipo", ""))
		var valor: String = str((item as Dictionary).get("valor", ""))
		if tipo.is_empty() or valor.is_empty():
			continue
		var col_idx: int = dias.find(str((item as Dictionary).get("dia", ""))) + 1
		var row_idx: int = horas.find(str((item as Dictionary).get("horario", ""))) + 1
		if col_idx <= 0 or row_idx <= 0:
			continue
		var chave_celula := "%d_%d" % [row_idx, col_idx]
		if not restricoes.has(chave_celula):
			restricoes[chave_celula] = []
		# Evita duplicatas iguais (mesmo tipo+valor) ao recarregar.
		if not celula_tem(chave_celula, {"tipo": tipo, "valor": valor}):
			restricoes[chave_celula].append({"tipo": tipo, "valor": valor})
