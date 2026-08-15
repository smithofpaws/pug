class_name PlanilhaAjuste extends Node
## Baixa e interpreta as respostas do formulário de [b]ajuste de matrícula[/b] a partir de uma planilha
## do Google publicada em CSV (Modo Ajuste do módulo [SituacaoAlunos]).
##
## Responsabilidade restrita a [b]baixar[/b] ([method baixar]) e [b]parsear[/b] ([method parse]) — não
## valida códigos contra as grades nem casa matrículas com alunos (isso fica no módulo, que tem os
## dados). É um [Node] (e não [RefCounted]) porque precisa de um [HTTPRequest] filho na árvore, no
## mesmo padrão de [SyncKinto]; o módulo o adiciona como filho e ambos são liberados ao trocar de
## módulo. [br]
## [br]
## O formulário (Google Forms) acrescenta colunas próprias (carimbo de data/hora, etc.), então as
## colunas de interesse são localizadas pelas [b]palavras-chave[/b] no cabeçalho: [code]matricula[/code],
## [code]incluir[/code] e [code]excluir[/code] (comparação sem acento e sem caixa). Quando o discente
## escolhe várias disciplinas, o Forms agrupa tudo numa única célula entre aspas, separadas por
## vírgula; cada entrada é texto livre do qual se extrai ao menos o código da disciplina.

# Tempo maximo (segundos) de espera por uma resposta, evitando travar o guard _ocupado para sempre.
const _TIMEOUT_SEGUNDOS := 15.0

# Nó de requisicao criado sob demanda (precisa estar na arvore para processar).
var _http: HTTPRequest
# Guarda contra requisicoes concorrentes no mesmo HTTPRequest.
var _ocupado: bool = false
# Regex de codigo de disciplina (ex.: "al0162", "AL0400", "Al 0015"): 2-3 letras + opcional espaco +
# 3-4 digitos. Exclui o codigo de turma/curso tipo "T20" (1 letra + 2 digitos).
var _regex_codigo: RegEx = null


## Baixa o CSV de [param url] (URL de planilha publicada). Segue redirecionamentos [b]manualmente[/b]
## (o HTTPRequest do Godot não segue 307/308, e o "Publicar na web › CSV" do Google responde 307
## apontando para [code]googleusercontent.com[/code]). Retorna
## [code]{ "ok": bool, "csv": String, "erro": String }[/code].
func baixar(url: String) -> Dictionary:
	var alvo: String = url.strip_edges()
	if alvo.is_empty():
		return { "ok": false, "csv": "", "erro": "Endereço da planilha não configurado." }
	if _ocupado:
		return { "ok": false, "csv": "", "erro": "Já existe uma verificação em andamento. Aguarde." }
	_garantir_http()
	_ocupado = true
	# Segue até 5 redirecionamentos lendo o cabeçalho Location de respostas 3xx.
	for _salto in 6:
		var err: int = _http.request(alvo, PackedStringArray(), HTTPClient.METHOD_GET)
		if err != OK:
			_ocupado = false
			return { "ok": false, "csv": "", "erro": "Falha ao iniciar o download (erro %d)." % err }
		var resp: Array = await _http.request_completed
		var resultado: int = resp[0]
		var codigo: int = resp[1]
		var headers: PackedStringArray = resp[2]
		var corpo_bytes: PackedByteArray = resp[3]
		if resultado != HTTPRequest.RESULT_SUCCESS:
			_ocupado = false
			return { "ok": false, "csv": "", \
				"erro": "Não foi possível acessar a planilha (resultado %d). Verifique a URL e a conexão." % resultado }
		if codigo in [301, 302, 303, 307, 308]:
			var destino: String = _cabecalho_location(headers)
			if not destino.is_empty():
				# Resolve Location relativo contra a URL atual (o Google manda absoluto, mas é seguro).
				alvo = destino if destino.begins_with("http") else alvo.get_base_dir() + "/" + destino
				continue
		_ocupado = false
		if codigo < 200 or codigo >= 300:
			return { "ok": false, "csv": "", \
				"erro": "A planilha respondeu com código HTTP %d. Confirme que está publicada em CSV." % codigo }
		return { "ok": true, "csv": corpo_bytes.get_string_from_utf8(), "erro": "" }
	_ocupado = false
	return { "ok": false, "csv": "", "erro": "Excesso de redirecionamentos ao acessar a planilha." }


## Interpreta o [param csv] das respostas. Localiza as colunas pelas palavras-chave do cabeçalho e
## devolve, por matrícula (mantendo a [b]resposta mais recente[/b] — última linha do arquivo),
## as entradas de texto a incluir/excluir. Retorna
## [code]{ "ok": bool, "respostas": Array, "erro": String }[/code], onde cada item de
## [code]respostas[/code] é [code]{ "matricula": String, "incluir": Array[String], "excluir": Array[String] }[/code].
func parse(csv: String) -> Dictionary:
	var linhas: Array = _parse_csv(csv)
	if linhas.size() < 2:
		return { "ok": false, "respostas": [], "erro": "A planilha não tem respostas (apenas cabeçalho ou vazia)." }
	var cabecalho: Array = linhas[0]
	var col_matricula: int = _coluna_por_palavra(cabecalho, "matricula")
	var col_incluir: int = _coluna_por_palavra(cabecalho, "incluir")
	var col_excluir: int = _coluna_por_palavra(cabecalho, "excluir")
	var faltando: Array[String] = []
	if col_matricula < 0:
		faltando.append("matricula")
	if col_incluir < 0:
		faltando.append("incluir")
	if col_excluir < 0:
		faltando.append("excluir")
	if not faltando.is_empty():
		return { "ok": false, "respostas": [], \
			"erro": "Cabeçalho sem a(s) coluna(s): " + ", ".join(faltando) + ". Confira o formulário." }

	# Mantem a resposta mais recente por matricula (linhas em ordem cronologica do Forms; last-wins).
	var por_matricula: Dictionary = {}
	for i in range(1, linhas.size()):
		var linha: Array = linhas[i]
		var matricula: String = _celula(linha, col_matricula).strip_edges()
		if matricula.is_empty():
			continue
		por_matricula[matricula] = {
			"matricula": matricula,
			"incluir": _separar_entradas(_celula(linha, col_incluir)),
			"excluir": _separar_entradas(_celula(linha, col_excluir)),
		}
	return { "ok": true, "respostas": por_matricula.values(), "erro": "" }


## Extrai os códigos de disciplina candidatos de uma [param entrada] de texto livre (ex.:
## [code]"AL0400 - Fundacoes - T20 - Maria"[/code] → [code]["al0400"][/code]). Normaliza para
## minúsculas e sem espaço. Pode retornar 0, 1 ou mais candidatos; a validação contra a grade fica
## no módulo.
func extrair_codigos(entrada: String) -> Array[String]:
	if _regex_codigo == null:
		_regex_codigo = RegEx.new()
		_regex_codigo.compile("[A-Za-z]{2,3}\\s?\\d{3,4}")
	var codigos: Array[String] = []
	for ocorrencia in _regex_codigo.search_all(entrada):
		var cod: String = ocorrencia.get_string().replace(" ", "").to_lower()
		if not cod in codigos:
			codigos.append(cod)
	return codigos


# Retorna o valor do cabecalho Location (case-insensitive) de uma resposta, ou "" se ausente.
func _cabecalho_location(headers: PackedStringArray) -> String:
	for h in headers:
		var sep: int = h.find(":")
		if sep > 0 and h.substr(0, sep).strip_edges().to_lower() == "location":
			return h.substr(sep + 1).strip_edges()
	return ""


# Garante o HTTPRequest na arvore (criacao tardia evita depender da ordem de _ready).
func _garantir_http() -> void:
	if _http == null:
		_http = HTTPRequest.new()
		_http.timeout = _TIMEOUT_SEGUNDOS
		add_child(_http)


# Divide o conteudo de uma celula de disciplinas (varias separadas por virgula) em entradas limpas,
# descartando as vazias.
func _separar_entradas(celula: String) -> Array[String]:
	var entradas: Array[String] = []
	for parte in celula.split(","):
		var limpa: String = parte.strip_edges()
		if not limpa.is_empty():
			entradas.append(limpa)
	return entradas


# Retorna o indice da primeira coluna cujo cabecalho (sem acento, minusculo) contem [param palavra].
# -1 se nenhuma.
func _coluna_por_palavra(cabecalho: Array, palavra: String) -> int:
	for i in cabecalho.size():
		if _sem_acento(str(cabecalho[i])).contains(palavra):
			return i
	return -1


# Acesso seguro a uma celula da linha (linhas curtas no CSV viram celula vazia).
func _celula(linha: Array, indice: int) -> String:
	if indice < 0 or indice >= linha.size():
		return ""
	return str(linha[indice])


# Normaliza para comparacao de cabecalho: minusculo e sem acentos comuns do portugues.
func _sem_acento(texto: String) -> String:
	var t: String = texto.to_lower()
	var de: String = "áàâãäéèêëíìîïóòôõöúùûüç"
	var para: String = "aaaaaeeeeiiiiooooouuuuc"
	var resultado: String = ""
	for ch in t:
		var pos: int = de.find(ch)
		resultado += para[pos] if pos >= 0 else ch
	return resultado


# Parser CSV char-a-char (RFC4180): trata aspas duplas, "" como aspa escapada, e virgulas/quebras de
# linha dentro de celulas entre aspas (respostas multilinha do Forms). Retorna Array de linhas, cada
# uma um Array[String] de celulas.
func _parse_csv(texto: String) -> Array:
	var linhas: Array = []
	var linha: Array[String] = []
	var campo: String = ""
	var em_aspas: bool = false
	var i: int = 0
	var n: int = texto.length()
	while i < n:
		var c: String = texto[i]
		if em_aspas:
			if c == "\"":
				# Aspa dupla escapada ("") vira uma aspa literal; senao fecha o trecho citado.
				if i + 1 < n and texto[i + 1] == "\"":
					campo += "\""
					i += 1
				else:
					em_aspas = false
			else:
				campo += c
		else:
			if c == "\"":
				em_aspas = true
			elif c == ",":
				linha.append(campo)
				campo = ""
			elif c == "\n":
				linha.append(campo)
				linhas.append(linha)
				linha = []
				campo = ""
			elif c == "\r":
				pass  # Ignora CR; o LF fecha a linha (trata CRLF e LF).
			else:
				campo += c
		i += 1
	# Descarrega a ultima celula/linha se o arquivo nao terminou em quebra de linha.
	if not campo.is_empty() or not linha.is_empty():
		linha.append(campo)
		linhas.append(linha)
	return linhas
