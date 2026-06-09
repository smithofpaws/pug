class_name SyncKinto extends Node
## Cliente de sincronizacao dos planejamentos com um servidor [url=https://github.com/Kinto/kinto]Kinto[/url].
##
## Permite que cada coordenador envie ([method enviar]) e baixe ([method baixar]/[method listar]) o
## planejamento do seu curso de/para um servidor compartilhado, de forma assincrona. Cada curso e um
## [i]record[/i] no Kinto, identificado pelo codigo do curso ([code]<cod_curso>[/code], ex.:
## [code]alec[/code]) — nao pela grade/versao, pois um curso tem varios PPCs ativos e o planejamento
## cobre todos. Fica em [code]bucket "pug" / collection "planejamentos"[/code]. [br]
## [br]
## Autenticacao por [b]Basic Auth[/b] com [code]usuario:token[/code] (o token e a "senha" da conta
## Kinto, revogavel no servidor). So trafega o planejamento de oferta (nomes de professores), nunca
## dados de alunos. O transporte e protegido pela rede privada (Tailscale). [br]
## [br]
## Todos os metodos publicos sao [b]assincronos[/b] ([code]await[/code]) e retornam um [Dictionary]
## no formato [code]{ "ok": bool, "codigo": int, "dados": Variant, "erro": String }[/code]. Como o
## [HTTPRequest] atende uma requisicao por vez, evite chamadas concorrentes (ha guarda em
## [member _ocupado]).

# Caminhos canonicos no servidor Kinto (ver convencoes em AGENTS.md).
const _BUCKET := "pug"
const _COLLECTION := "planejamentos"

# Tempo maximo (segundos) de espera por uma resposta. Sem timeout, um servidor que nao responde
# (ex.: Tailscale fora do ar) deixaria o request_completed sem disparar e a guarda _ocupado presa
# em true para sempre, recusando toda sincronizacao seguinte ate reiniciar o programa.
const _TIMEOUT_SEGUNDOS := 15.0

# Configuracao injetada via configurar(); _url_base sem barra final (ex.: http://host:8888/v1).
var _url_base: String = ""
var _usuario: String = ""
var _token: String = ""

# Nó de requisicao criado sob demanda (precisa estar na arvore para processar).
var _http: HTTPRequest
# Guarda contra requisicoes concorrentes no mesmo HTTPRequest.
var _ocupado: bool = false


## Define o endereco do servidor e as credenciais. [param url] e a raiz da API (ex.:
## [code]http://100.110.55.51:8888/v1[/code]); barra final e ignorada.
func configurar(url: String, usuario: String, token: String) -> void:
	_url_base = url.strip_edges().trim_suffix("/")
	_usuario = usuario.strip_edges()
	# NAO usar strip_edges() no token: a senha/token pode legitimamente conter espaco no inicio/fim,
	# e precisa casar byte a byte com o que foi gravado no servidor. Url e usuario sao limpos (espaco
	# ali e sempre acidental e o Kinto nem aceita espaco no nome de conta).
	_token = token


## Retorna true quando url, usuario e token estao preenchidos.
func esta_configurado() -> bool:
	return not _url_base.is_empty() and not _usuario.is_empty() and not _token.is_empty()


## Envia (PUT) o [param planejamento] como o record do curso [param chave_curso], anexando quem
## enviou e quando. Substitui a versao existente no servidor (se houver permissao de escrita).
func enviar(chave_curso: String, planejamento: Dictionary) -> Dictionary:
	var corpo := {
		"planejamento": planejamento,
		"enviado_por": _usuario,
		"enviado_em": Time.get_datetime_string_from_system(),
	}
	return await _requisitar(HTTPClient.METHOD_PUT, _caminho_record(chave_curso), corpo)


## Baixa (GET) o record do curso [param chave_curso]. Em [code]dados.data[/code] vem o record com
## [code]planejamento[/code], [code]enviado_por[/code] e [code]enviado_em[/code].
func baixar(chave_curso: String) -> Dictionary:
	return await _requisitar(HTTPClient.METHOD_GET, _caminho_record(chave_curso), null)


## Lista (GET) os records disponiveis na collection. Em [code]dados.data[/code] vem um Array de
## records (cada um com [code]id[/code] = chave do curso, [code]enviado_por[/code], [code]enviado_em[/code]).
func listar() -> Dictionary:
	return await _requisitar(HTTPClient.METHOD_GET, _caminho_records(), null)


# Garante o HTTPRequest na arvore (criacao tardia evita depender da ordem de _ready).
func _garantir_http() -> void:
	if _http == null:
		_http = HTTPRequest.new()
		_http.timeout = _TIMEOUT_SEGUNDOS
		add_child(_http)


func _caminho_records() -> String:
	return "/buckets/%s/collections/%s/records" % [_BUCKET, _COLLECTION]


func _caminho_record(chave_curso: String) -> String:
	return _caminho_records() + "/" + chave_curso


# Executa a requisicao e devolve o resultado normalizado. [param corpo] (quando nao nulo) e
# encapsulado em {"data": corpo}, como o Kinto espera para records/contas/grupos. Quando
# [param encapsular_data] e false, o corpo e enviado como veio (ex.: {"permissions": {...}}, que vai
# no topo, nao sob "data"). Espera o sinal request_completed via await (cujos argumentos retornam num
# Array) — sem capturar locais em lambda (ver AGENTS.md).
func _requisitar(metodo: int, caminho: String, corpo: Variant, encapsular_data: bool = true) -> Dictionary:
	if not esta_configurado():
		return { "ok": false, "codigo": 0, "erro": "Sincronizacao nao configurada (servidor/usuario/token)." }
	if _ocupado:
		return { "ok": false, "codigo": 0, "erro": "Ja existe uma sincronizacao em andamento. Aguarde." }
	_garantir_http()
	_ocupado = true

	var headers := PackedStringArray([
		"Authorization: Basic " + Marshalls.utf8_to_base64(_usuario + ":" + _token),
		"Content-Type: application/json",
		"Accept: application/json",
	])
	var corpo_txt: String = ""
	if corpo != null:
		corpo_txt = JSON.stringify({ "data": corpo } if encapsular_data else corpo)

	var err: int = _http.request(_url_base + caminho, headers, metodo, corpo_txt)
	if err != OK:
		_ocupado = false
		return { "ok": false, "codigo": 0, "erro": "Falha ao iniciar a requisicao (erro %d)." % err }

	var resp: Array = await _http.request_completed
	_ocupado = false
	var resultado: int = resp[0]
	var codigo: int = resp[1]
	var corpo_bytes: PackedByteArray = resp[3]

	if resultado != HTTPRequest.RESULT_SUCCESS:
		return { "ok": false, "codigo": codigo, \
			"erro": "Sem conexao com o servidor. Verifique a rede/Tailscale (resultado %d)." % resultado }

	var texto: String = corpo_bytes.get_string_from_utf8()
	var dados: Variant = JSON.parse_string(texto) if not texto.is_empty() else {}

	if codigo < 200 or codigo >= 300:
		return { "ok": false, "codigo": codigo, "erro": _mensagem_erro(codigo, dados) }
	return { "ok": true, "codigo": codigo, "dados": dados }


# Traduz codigos HTTP/Kinto comuns para mensagens em portugues. Aproveita o campo "message" do
# corpo de erro do Kinto quando disponivel.
func _mensagem_erro(codigo: int, dados: Variant) -> String:
	var detalhe: String = ""
	if dados is Dictionary:
		detalhe = str(dados.get("message", ""))
	match codigo:
		401:
			return "Usuario ou token invalido (401). Verifique as credenciais em Configurar servidor."
		403:
			return "Sem permissao para este curso (403). Apenas o coordenador dono pode enviar; " + \
				"peca ao administrador para liberar o seu curso."
		404:
			return "Nao encontrado no servidor (404). Esse curso ainda nao foi enviado."
		_:
			return "Erro do servidor (HTTP %d)%s" % [codigo, (": " + detalhe) if not detalhe.is_empty() else "."]
