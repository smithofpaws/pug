class_name BuscaTerminal extends RefCounted
## Busca no texto visivel do Terminal. Estatico e puro (nao le arquivos nem toca em nos): recebe o
## buffer de entradas do Terminal e devolve ocorrencias e BBCode realcado; quem chama injeta as cores. [br]
## [br]
## O tokenizador imita o [RichTextLabel] do Godot 4.7: so tags conhecidas somem; o resto e literal. [br]
## [b]Limitacoes aceitas:[/b] (1) um [code][[/code] sem [code]]][/code] dentro da entrada, seguido de
## nome de tag conhecido, e literal aqui mas o motor o junta ao [code][/color][/code] do envelope
## (defeito de renderizacao ja existente); (2) tags com glifo proprio ([code]img[/code], [code]ul[/code],
## [code]table[/code], [code]hr[/code], [code]char[/code], [code]dropcap[/code]) nao somam o caractere
## extra ao texto visivel, entao a rolagem pode ficar deslocada; (3) um fechamento solto que so
## fecharia o envelope e literal; (4) acento em forma decomposta (NFD) nao e normalizado.

# Nomes de tag que o RichTextLabel 4.7 reconhece. Completa de proposito: uma tag que o motor
# esconde e esta lista nao conhece seria reemitida com [lb] e apareceria na tela.
const _TAGS_CONHECIDAS: Array[String] = [
	"b", "i", "u", "s", "code", "char", "p", "center", "left", "right", "fill", "indent", "url",
	"hint", "dropcap", "color", "bgcolor", "fgcolor", "outline_size", "outline_color", "font",
	"font_size", "opentype_features", "otf", "lang", "table", "cell", "ul", "ol", "img", "wave",
	"tornado", "shake", "fade", "rainbow", "pulse", "lrm", "rlm", "lre", "rle", "lro", "rlo",
	"pdf", "alm", "zwj", "zwnj", "wj", "shy", "hr",
]
const _ESCAPES: Dictionary = {"lb": "[", "rb": "]", "br": "\r"}


## Monta o indice do [param buffer] do Terminal (entradas com [code]texto[/code] e [code]nl[/code]). [br]
## Retorna [code]{ visivel, normalizado, entradas }[/code]; cada entrada traz [code]texto[/code],
## [code]inicio[/code]/[code]fim[/code] (posicoes em [code]visivel[/code]) e [code]tokens[/code].
## [code]normalizado[/code] tem sempre o mesmo comprimento de [code]visivel[/code].
static func indexar(buffer: Array[Dictionary]) -> Dictionary:
	var visivel: String = ""
	var entradas: Array[Dictionary] = []
	for entrada in buffer:
		var texto: String = str(entrada.get("texto", ""))
		if bool(entrada.get("nl", false)):
			visivel += "\n"
		var inicio: int = visivel.length()
		var tokens: Array[Dictionary] = _tokenizar(texto)
		for token in tokens:
			visivel += str(token["visivel"])
		entradas.append({"texto": texto, "inicio": inicio, "fim": visivel.length(), "tokens": tokens})
	var normalizado: String = GeneralFunctions.remover_acentos(visivel)
	if normalizado.length() != visivel.length():
		normalizado = visivel.to_lower()
	return {"visivel": visivel, "normalizado": normalizado, "entradas": entradas}


## Acha as ocorrencias de [param termo] no [param indice], sem diferenciar caixa nem acento.
## Retorna [code]Vector2i(inicio, fim)[/code] (fim exclusivo) em posicoes de [code]visivel[/code],
## em ordem e sem sobreposicao. Termo vazio ou so de espacos retorna vazio.
static func buscar(indice: Dictionary, termo: String) -> Array[Vector2i]:
	var resultado: Array[Vector2i] = []
	if termo.strip_edges().is_empty() or not indice.has("normalizado"):
		return resultado
	var alvo: String = GeneralFunctions.remover_acentos(termo)
	var normalizado: String = str(indice["normalizado"])
	var pos: int = normalizado.find(alvo)
	while pos != -1:
		resultado.append(Vector2i(pos, pos + alvo.length()))
		pos = normalizado.find(alvo, pos + alvo.length())
	return resultado


## Devolve o texto interno (BBCode) de cada entrada do [param indice] com as [param ocorrencias]
## envolvidas em [code][bgcolor][/code]: [param cor_atual] na de indice [param atual], [param cor_todas]
## nas demais. Nenhum [code][bgcolor][/code] contem tag; entradas sem ocorrencia saem identicas.
static func realcar(indice: Dictionary, ocorrencias: Array[Vector2i], atual: int, cor_todas: String, cor_atual: String) -> Array[String]:
	var resultado: Array[String] = []
	var entradas: Array = indice.get("entradas", [])
	var k: int = 0
	var total: int = ocorrencias.size()
	for entrada in entradas:
		var inicio: int = int(entrada["inicio"])
		var fim: int = int(entrada["fim"])
		while k < total and ocorrencias[k].y <= inicio:
			k += 1
		if fim <= inicio or k >= total or ocorrencias[k].x >= fim:
			resultado.append(str(entrada["texto"]))
			continue
		var saida: String = ""
		var p: int = inicio
		for token in entrada["tokens"]:
			var tipo: String = str(token["tipo"])
			if tipo == "tag":
				saida += str(token["fonte"])
				continue
			var tamanho: int = str(token["visivel"]).length()
			if tipo == "escape":
				while k < total and ocorrencias[k].y <= p:
					k += 1
				if k < total and ocorrencias[k].x <= p:
					saida += _envolver(str(token["fonte"]), k, atual, cor_todas, cor_atual)
				else:
					saida += str(token["fonte"])
				p += tamanho
				continue
			var texto: String = str(token["visivel"])
			var q: int = p
			var limite: int = p + tamanho
			while q < limite:
				while k < total and ocorrencias[k].y <= q:
					k += 1
				var parada: int = limite
				var dentro: bool = k < total and ocorrencias[k].x <= q
				if dentro:
					parada = mini(ocorrencias[k].y, limite)
				if not dentro and k < total:
					parada = mini(ocorrencias[k].x, limite)
				var pedaco: String = texto.substr(q - p, parada - q).replace("[", "[lb]")
				saida += _envolver(pedaco, k, atual, cor_todas, cor_atual) if dentro else pedaco
				q = parada
			p = limite
		resultado.append(saida)
	return resultado


## Proximo indice da navegacao circular ([code]-1[/code] quando nao ha ocorrencias).
static func proxima(atual: int, total: int) -> int:
	if total <= 0:
		return -1
	return (atual + 1) % total


## Indice anterior da navegacao circular ([code]-1[/code] quando nao ha ocorrencias).
static func anterior(atual: int, total: int) -> int:
	if total <= 0:
		return -1
	if atual < 0:
		return total - 1
	return (atual - 1 + total) % total


## Texto que o [RichTextLabel] mostra para [param texto_bbcode] (concatena o visivel dos tokens).
static func texto_visivel(texto_bbcode: String) -> String:
	var resultado: String = ""
	for token in _tokenizar(texto_bbcode):
		resultado += str(token["visivel"])
	return resultado


# Envolve [param trecho] no fundo da ocorrencia [param k] (forte so para a atual).
static func _envolver(trecho: String, k: int, atual: int, cor_todas: String, cor_atual: String) -> String:
	var cor: String = cor_atual if k == atual else cor_todas
	return "[bgcolor=" + cor + "]" + trecho + "[/bgcolor]"


# Quebra o BBCode em tokens { tipo: texto|tag|escape, fonte, visivel }, na mesma regra do motor.
static func _tokenizar(texto: String) -> Array[Dictionary]:
	var tokens: Array[Dictionary] = []
	var pilha: Array[String] = []
	var literal: String = ""
	var pos: int = 0
	while pos < texto.length():
		var abre: int = texto.find("[", pos)
		if abre == -1:
			literal += texto.substr(pos)
			break
		var fecha: int = texto.find("]", abre)
		if fecha == -1:
			literal += texto.substr(pos)
			break
		literal += texto.substr(pos, abre - pos)
		var tag: String = texto.substr(abre + 1, fecha - abre - 1)
		var fonte: String = texto.substr(abre, fecha - abre + 1)
		if _ESCAPES.has(tag):
			_descarregar_literal(tokens, literal)
			literal = ""
			tokens.append({"tipo": "escape", "fonte": fonte, "visivel": _ESCAPES[tag]})
			pos = fecha + 1
			continue
		if tag.begins_with("/"):
			if not pilha.is_empty() and pilha[pilha.size() - 1] == tag.substr(1):
				pilha.pop_back()
				_descarregar_literal(tokens, literal)
				literal = ""
				tokens.append({"tipo": "tag", "fonte": fonte, "visivel": ""})
				pos = fecha + 1
				continue
		else:
			var corte: int = mini(
				tag.find(" ") if tag.contains(" ") else tag.length(),
				tag.find("=") if tag.contains("=") else tag.length()
			)
			var nome: String = tag.substr(0, corte)
			if _TAGS_CONHECIDAS.has(nome):
				pilha.append(nome)
				_descarregar_literal(tokens, literal)
				literal = ""
				tokens.append({"tipo": "tag", "fonte": fonte, "visivel": ""})
				pos = fecha + 1
				continue
		# Nao e tag: o "[" e um caractere literal e a varredura recomeca logo depois dele.
		literal += "["
		pos = abre + 1
	_descarregar_literal(tokens, literal)
	return tokens


static func _descarregar_literal(tokens: Array[Dictionary], literal: String) -> void:
	if not literal.is_empty():
		tokens.append({"tipo": "texto", "fonte": literal, "visivel": literal})
