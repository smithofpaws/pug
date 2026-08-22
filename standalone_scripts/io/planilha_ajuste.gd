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
# 3-4 digitos. Exclui o codigo de turma/curso tipo "T20" (1 letra + 2 digitos). O \b inicial exige
# fronteira de palavra antes das letras -- sem ele, a cauda de texto livre comum em resposta de
# Forms ("Sala 302", "Turma 101", "predio 1102") casava um falso segundo codigo em pleno meio de
# palavra ("ala302", "rma101", "dio1102"), fazendo _mesclar_lado tratar uma unica mencao valida como
# duas e gerando alerta de "problema" falso no modulo (Cards/0002, finding de review). Residual
# aceito: um token curto isolado seguido de numero ("Lab 101", "em 2026") ainda satisfaz o \b e
# ainda casa como candidato -- distinguir isso de um segundo codigo real exige a grade do aluno,
# que este parser nao tem (validacao e non-goal do card, fica no modulo).
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
## devolve, por matrícula, a [b]mesclagem[/b] de todas as respostas do aluno: quando o mesmo aluno
## responde mais de uma vez, incluir/excluir viram a união das menções, e um conflito por disciplina
## (mesmo código nos dois lados em respostas [i]diferentes[/i]) é resolvido pela menção mais recente
## — as linhas do CSV estão em ordem cronológica do Forms. Um conflito dentro da [i]mesma[/i] resposta
## (sem "mais recente" possível) é resolvido a favor da exclusão. Retorna
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

	# Mescla todas as respostas por matricula (linhas em ordem cronologica do Forms): o estado por
	# matricula acumula, por codigo de disciplina, a mencao mais recente (ver _mesclar_lado).
	var por_matricula: Dictionary = {}
	for i in range(1, linhas.size()):
		var linha: Array = linhas[i]
		var matricula: String = _celula(linha, col_matricula).strip_edges()
		if matricula.is_empty():
			continue
		if not por_matricula.has(matricula):
			por_matricula[matricula] = {
				"matricula": matricula,
				"decisoes": {},
				"problemas_incluir": {},
				"problemas_excluir": {},
			}
		var estado: Dictionary = por_matricula[matricula]
		# Incluir antes de excluir: desempate de conflito na mesma linha (ver _mesclar_lado).
		_mesclar_lado(estado, _separar_entradas(_celula(linha, col_incluir)), "incluir", i)
		_mesclar_lado(estado, _separar_entradas(_celula(linha, col_excluir)), "excluir", i)

	var respostas: Array = []
	for matricula: String in por_matricula:
		respostas.append(_montar_resposta(por_matricula[matricula]))
	return { "ok": true, "respostas": respostas, "erro": "" }


## Extrai os códigos de disciplina candidatos de uma [param entrada] de texto livre (ex.:
## [code]"AL0400 - Fundacoes - T20 - Maria"[/code] → [code]["al0400"][/code]). Normaliza para
## minúsculas e sem espaço. Exige que o código comece numa fronteira de palavra, então cauda de
## texto livre como [code]"Sala 302"[/code] ou [code]"Turma 101"[/code] não vira candidato (o
## trecho numérico está em pleno meio da palavra anterior). Pode retornar 0, 1 ou mais candidatos;
## a validação contra a grade fica no módulo.
func extrair_codigos(entrada: String) -> Array[String]:
	if _regex_codigo == null:
		_regex_codigo = RegEx.new()
		_regex_codigo.compile("\\b[A-Za-z]{2,3}\\s?\\d{3,4}")
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


# Mescla, no [param estado] da matricula, as [param entradas] de um [param lado] ("incluir" ou
# "excluir") da linha [param ordem]. Entrada sem codigo extraivel vira "problema" desse lado
# (dedupado por texto normalizado, primeira ocorrencia define o texto exibido); entrada com
# codigo(s) concorre pela decisao de estado.decisoes[codigo], vencida pela mencao de maior ordem —
# em ordem igual (mesma linha), "excluir" vence "incluir". Dentro da mesma linha e mesmo lado, a
# primeira mencao de um codigo repetido e mantida (nao ha "mais recente" possivel).
func _mesclar_lado(estado: Dictionary, entradas: Array[String], lado: String, ordem: int) -> void:
	var problemas: Dictionary = estado["problemas_incluir"] if lado == "incluir" else estado["problemas_excluir"]
	var decisoes: Dictionary = estado["decisoes"]
	for entrada: String in entradas:
		var codigos: Array[String] = extrair_codigos(entrada)
		if codigos.is_empty():
			var chave: String = _sem_acento(entrada)
			if not problemas.has(chave):
				problemas[chave] = entrada
			continue
		for codigo: String in codigos:
			# Mencao multi-codigo emite o proprio codigo (nao a entrada inteira) — reusar o texto
			# faria o modulo re-extrair sempre o mesmo primeiro candidato para todos os codigos.
			# Cuidado: NAO trocar para "sempre entrada" achando que resolve ruido de regex sem
			# tocar aqui (foi essa a correcao proposta e descartada no finding de review do
			# Cards/0002) — duas copias identicas da entrada fariam _classificar_codigos escolher
			# sempre o MESMO primeiro candidato valido nas duas, perdendo silenciosamente o segundo
			# codigo real em mencoes genuinamente multiplas (test_mencao_multi_codigo_decide_por_codigo).
			# O ruido de regex foi tratado na raiz, no \b de extrair_codigos.
			var texto: String = entrada if codigos.size() == 1 else codigo
			var substitui: bool = true
			if decisoes.has(codigo):
				var atual: Dictionary = decisoes[codigo]
				substitui = ordem > int(atual["ordem"]) \
					or (ordem == int(atual["ordem"]) and lado == "excluir")
			if substitui:
				decisoes[codigo] = { "lado": lado, "texto": texto, "ordem": ordem }


# Reconstroi a resposta final de uma matricula a partir do [param estado] mesclado: os codigos
# decididos (na ordem de primeira mencao — Dictionary preserva insercao mesmo em overwrite) seguidos
# dos problemas (entradas sem codigo extraivel) de cada lado.
func _montar_resposta(estado: Dictionary) -> Dictionary:
	var incluir: Array[String] = []
	var excluir: Array[String] = []
	var decisoes: Dictionary = estado["decisoes"]
	for codigo: String in decisoes:
		var decisao: Dictionary = decisoes[codigo]
		if decisao["lado"] == "incluir":
			incluir.append(decisao["texto"])
		else:
			excluir.append(decisao["texto"])
	for problema: String in estado["problemas_incluir"].values():
		incluir.append(problema)
	for problema: String in estado["problemas_excluir"].values():
		excluir.append(problema)
	return { "matricula": estado["matricula"], "incluir": incluir, "excluir": excluir }


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
