class_name MarkdownHtml extends RefCounted
## Conversor Markdown -> HTML para o subconjunto usado no [code]MANUAL.md[/code].
##
## Estatico e puro (nao le arquivos nem toca em nos), para ser testavel isoladamente. Cobre titulos,
## paragrafos, regua, listas (com um nivel de aninhamento) ordenadas/nao ordenadas, tabelas GFM e
## formatacao inline (negrito, italico, codigo, links). A folha de estilo e injetada por quem chama
## (ex.: a barra principal monta o CSS a partir do tema atual).

## Monta o documento HTML5 completo com [param titulo] e a folha de estilo [param css] no head, e o
## corpo convertido de [param md].
static func documento(md: String, titulo: String, css: String) -> String:
	var corpo: String = converter(md)
	var partes: Array[String] = [
		"<!DOCTYPE html>",
		"<html lang=\"pt-BR\">",
		"<head>",
		"<meta charset=\"utf-8\">",
		"<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">",
		"<title>" + _escapar(titulo) + "</title>",
		"<style>",
		css,
		"</style>",
		"</head>",
		"<body>",
		"<main class=\"conteudo\">",
		corpo,
		"</main>",
		"</body>",
		"</html>",
	]
	return "\n".join(partes)


## Converte [param md] no corpo HTML (sem head/body). Processa linha a linha, agrupando blocos
## (listas, tabelas, paragrafos) conforme necessario.
static func converter(md: String) -> String:
	var linhas: PackedStringArray = md.replace("\r\n", "\n").replace("\r", "\n").split("\n")
	var saida: Array[String] = []
	var i: int = 0
	while i < linhas.size():
		var linha: String = linhas[i]
		var sem_espaco: String = linha.strip_edges()

		# Linha em branco: separa blocos, nada a emitir.
		if sem_espaco.is_empty():
			i += 1
			continue

		# Regua horizontal.
		if sem_espaco == "---" or sem_espaco == "***" or sem_espaco == "___":
			saida.append("<hr>")
			i += 1
			continue

		# Titulos (#..####).
		var nivel: int = _nivel_titulo(sem_espaco)
		if nivel > 0:
			var texto: String = sem_espaco.substr(nivel).strip_edges()
			var id_slug: String = _slug(texto)
			saida.append("<h%d id=\"%s\">%s</h%d>" % [nivel, id_slug, _inline(texto), nivel])
			i += 1
			continue

		# Tabela GFM: linha atual com '|' seguida de linha separadora '|---|'.
		if sem_espaco.begins_with("|") and i + 1 < linhas.size() and _eh_separador_tabela(linhas[i + 1]):
			var bloco: Array[String] = []
			while i < linhas.size() and linhas[i].strip_edges().begins_with("|"):
				bloco.append(linhas[i])
				i += 1
			saida.append(_tabela(bloco))
			continue

		# Listas (nao ordenadas '- ' ou ordenadas '1.'), agrupando linhas consecutivas de lista.
		if _eh_item_lista(linha):
			var bloco_lista: Array[String] = []
			while i < linhas.size() and _eh_item_lista(linhas[i]):
				bloco_lista.append(linhas[i])
				i += 1
			saida.append(_lista(bloco_lista))
			continue

		# Blockquote (linhas iniciadas por '>'), incluindo callouts GFM '> [!TIPO]'.
		if _eh_blockquote(linha):
			var bloco_bq: Array[String] = []
			while i < linhas.size() and _eh_blockquote(linhas[i]):
				bloco_bq.append(linhas[i])
				i += 1
			saida.append(_blockquote(bloco_bq))
			continue

		# Paragrafo: agrupa linhas consecutivas que nao iniciam outro bloco.
		var paragrafo: Array[String] = []
		while i < linhas.size():
			var l: String = linhas[i]
			var ls: String = l.strip_edges()
			if ls.is_empty() or _nivel_titulo(ls) > 0 or ls == "---" or _eh_item_lista(l) \
					or _eh_blockquote(l) \
					or (ls.begins_with("|") and i + 1 < linhas.size() and _eh_separador_tabela(linhas[i + 1])):
				break
			paragrafo.append(ls)
			i += 1
		saida.append("<p>" + _inline(" ".join(paragrafo)) + "</p>")
	return "\n".join(saida)


# Retorna o nivel do titulo (1..6) se [param linha] comeca com '# '..'###### '; senao 0.
static func _nivel_titulo(linha: String) -> int:
	var n: int = 0
	while n < linha.length() and linha[n] == "#":
		n += 1
	if n >= 1 and n <= 6 and n < linha.length() and linha[n] == " ":
		return n
	return 0


# Verdadeiro se [param linha] e um item de lista nao ordenada ('- ') ou ordenada ('1. ').
static func _eh_item_lista(linha: String) -> bool:
	var s: String = linha.strip_edges()
	if s.begins_with("- "):
		return true
	# Ordenada: digitos seguidos de '. '.
	var ponto: int = s.find(". ")
	if ponto > 0 and s.substr(0, ponto).is_valid_int():
		return true
	return false


# Conta os espacos de indentacao no inicio da linha (para detectar aninhamento de lista).
static func _indentacao(linha: String) -> int:
	var n: int = 0
	while n < linha.length() and linha[n] == " ":
		n += 1
	return n


# Converte um bloco de itens de lista em <ul>/<ol> com ate um nivel de aninhamento (por indentacao).
static func _lista(bloco: Array[String]) -> String:
	var ordenada: bool = not bloco[0].strip_edges().begins_with("- ")
	var tag: String = "ol" if ordenada else "ul"
	var html: Array[String] = ["<" + tag + ">"]
	var i: int = 0
	while i < bloco.size():
		var conteudo: String = _texto_item(bloco[i])
		var base_indent: int = _indentacao(bloco[i])
		# Coleta filhos mais indentados como sublista.
		var filhos: Array[String] = []
		while i + 1 < bloco.size() and _indentacao(bloco[i + 1]) > base_indent:
			filhos.append(bloco[i + 1])
			i += 1
		if filhos.is_empty():
			html.append("<li>" + _inline(conteudo) + "</li>")
		else:
			html.append("<li>" + _inline(conteudo) + _lista(filhos) + "</li>")
		i += 1
	html.append("</" + tag + ">")
	return "\n".join(html)


# Extrai o texto de um item de lista, removendo o marcador ('- ' ou 'N. ').
static func _texto_item(linha: String) -> String:
	var s: String = linha.strip_edges()
	if s.begins_with("- "):
		return s.substr(2)
	var ponto: int = s.find(". ")
	if ponto > 0 and s.substr(0, ponto).is_valid_int():
		return s.substr(ponto + 2)
	return s


# Verdadeiro se [param linha] inicia um blockquote ('>' no comeco, apos espacos de indentacao).
static func _eh_blockquote(linha: String) -> bool:
	return linha.strip_edges().begins_with(">")


# Converte um bloco de linhas '>' em <blockquote> ou, se a 1a linha for '[!TIPO]', num callout
# GFM (<div class="callout callout-tipo">). O conteudo vira um ou mais <p> (linha '>' vazia separa).
static func _blockquote(bloco: Array[String]) -> String:
	# Remove o prefixo '>' (e um espaco opcional) de cada linha.
	var conteudo: Array[String] = []
	for linha in bloco:
		var s: String = linha.strip_edges().substr(1)  # tira o '>'
		if s.begins_with(" "):
			s = s.substr(1)
		conteudo.append(s)

	# Callout GFM: 1a linha no formato '[!TIPO]'.
	var tipo: String = ""
	if not conteudo.is_empty():
		var primeira: String = conteudo[0].strip_edges()
		if primeira.begins_with("[!") and primeira.ends_with("]"):
			tipo = primeira.substr(2, primeira.length() - 3).strip_edges()
			conteudo.remove_at(0)

	var corpo: String = _paragrafos(conteudo)
	if tipo.is_empty():
		return "<blockquote>\n" + corpo + "\n</blockquote>"
	return "<div class=\"callout callout-%s\">\n<p class=\"callout-titulo\">%s</p>\n%s\n</div>" \
		% [_slug(tipo), _escapar(_titulo_callout(tipo)), corpo]


# Agrupa linhas em um ou mais <p>; uma linha em branco separa paragrafos. Reusa _inline em cada um.
static func _paragrafos(linhas: Array[String]) -> String:
	var paragrafos: Array[String] = []
	var atual: Array[String] = []
	for linha in linhas:
		if linha.strip_edges().is_empty():
			if not atual.is_empty():
				paragrafos.append("<p>" + _inline(" ".join(atual)) + "</p>")
				atual = []
		else:
			atual.append(linha.strip_edges())
	if not atual.is_empty():
		paragrafos.append("<p>" + _inline(" ".join(atual)) + "</p>")
	return "\n".join(paragrafos)


# Titulo legivel do callout: capitaliza so a 1a letra (ex.: 'ATENCAO' -> 'Atencao', 'NOTA' -> 'Nota').
static func _titulo_callout(tipo: String) -> String:
	var t: String = tipo.strip_edges().to_lower()
	if t.is_empty():
		return ""
	return t.substr(0, 1).to_upper() + t.substr(1)


# Verdadeiro se a linha e a separadora de cabecalho de tabela GFM (ex.: '|---|---|').
static func _eh_separador_tabela(linha: String) -> bool:
	var s: String = linha.strip_edges()
	if not s.begins_with("|"):
		return false
	for c in s:
		if c != "|" and c != "-" and c != ":" and c != " ":
			return false
	return s.contains("-")


# Converte um bloco de linhas de tabela GFM em <table> (primeira linha = cabecalho).
static func _tabela(bloco: Array[String]) -> String:
	var html: Array[String] = ["<table>"]
	# bloco[0] = cabecalho; bloco[1] = separador; bloco[2..] = corpo.
	html.append("<thead><tr>")
	for celula in _celulas_linha(bloco[0]):
		html.append("<th>" + _inline(celula) + "</th>")
	html.append("</tr></thead>")
	html.append("<tbody>")
	for j in range(2, bloco.size()):
		html.append("<tr>")
		for celula in _celulas_linha(bloco[j]):
			html.append("<td>" + _inline(celula) + "</td>")
		html.append("</tr>")
	html.append("</tbody></table>")
	return "\n".join(html)


# Quebra uma linha de tabela '| a | b |' nas celulas ['a', 'b'].
static func _celulas_linha(linha: String) -> Array[String]:
	var s: String = linha.strip_edges()
	if s.begins_with("|"):
		s = s.substr(1)
	if s.ends_with("|"):
		s = s.substr(0, s.length() - 1)
	var celulas: Array[String] = []
	for parte in s.split("|"):
		celulas.append(parte.strip_edges())
	return celulas


# Aplica formatacao inline: escapa HTML, protege code spans, depois links/negrito/italico.
static func _inline(texto: String) -> String:
	# Backtick montado via codigo do caractere para nao colocar o literal dentro da string da regex.
	var bt: String = String.chr(96)
	# 1. Code spans primeiro: extrai o conteudo cru e o protege com marcadores de controle, para nao
	#    sofrer interpretacao de negrito/italico no meio do codigo.
	var placeholders: Array[String] = []
	var re_code := RegEx.new()
	re_code.compile(bt + "([^" + bt + "]+)" + bt)
	var resultado: String = ""
	var pos: int = 0
	for m in re_code.search_all(texto):
		resultado += _escapar(texto.substr(pos, m.get_start() - pos))
		resultado += String.chr(1) + str(placeholders.size()) + String.chr(2)
		placeholders.append("<code>" + _escapar(m.get_string(1)) + "</code>")
		pos = m.get_end()
	resultado += _escapar(texto.substr(pos))

	# 2. Links [texto](destino).
	var re_link := RegEx.new()
	re_link.compile("\\[([^\\]]+)\\]\\(([^)]+)\\)")
	resultado = re_link.sub(resultado, "<a href=\"$2\">$1</a>", true)

	# 3. Negrito (**...**) antes de italico (*...*) para nao consumir os asteriscos duplos.
	var re_bold := RegEx.new()
	re_bold.compile("\\*\\*([^*]+)\\*\\*")
	resultado = re_bold.sub(resultado, "<strong>$1</strong>", true)
	var re_ital := RegEx.new()
	re_ital.compile("\\*([^*]+)\\*")
	resultado = re_ital.sub(resultado, "<em>$1</em>", true)

	# 4. Restaura os code spans protegidos.
	for k in placeholders.size():
		resultado = resultado.replace(String.chr(1) + str(k) + String.chr(2), placeholders[k])
	return resultado


# Escapa os caracteres especiais de HTML.
static func _escapar(texto: String) -> String:
	return texto.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


# Gera um identificador no estilo GitHub: minusculas, sem pontuacao (preserva letras acentuadas e
# digitos), espacos viram hifen. Casa com as ancoras escritas no sumario do manual.
static func _slug(texto: String) -> String:
	var s: String = texto.to_lower()
	var re := RegEx.new()
	re.compile("[^\\p{L}\\p{N}\\s-]")
	s = re.sub(s, "", true)
	s = s.strip_edges().replace(" ", "-")
	return s
