class_name Atualizador extends Node
## Atualizacao do programa a partir das [i]releases[/i] do repositorio no GitHub.
##
## Consulta a release mais recente, compara com a versao instalada
## ([code]application/config/version[/code] em [code]project.godot[/code]), baixa o pacote nomeado em
## [code]base_config.json:atualizacao.asset[/code] — que depende da arquitetura desta instalacao
## ([code]PUG_WIN_X64.zip[/code] ou [code]PUG_WIN_ARM64.zip[/code]), pois cada pacote traz o seu
## proprio [code]base_config.json[/code] —, confere a integridade pelo SHA-256 publicado junto e extrai tudo
## numa area de trabalho em [code]user://[/code]. So depois de o pacote estar inteiro e conferido e
## que a troca acontece — uma copia pela metade deixaria a instalacao inutilizada. [br]
## [br]
## A troca em si nao pode ser feita pelo proprio programa: no Windows o executavel em uso fica
## travado. Por isso [method aplicar] grava um script PowerShell auxiliar, dispara-o com
## [method OS.create_process] e o programa se encerra; o script espera o processo morrer, copia os
## arquivos por cima da instalacao e relanca o executavel. [br]
## [br]
## A copia e sempre [b]aditiva[/b] (robocopy [code]/E[/code] sem [code]/PURGE[/code]): grades que o
## coordenador tenha acrescentado em [code]arquivos/[/code], o [code]config_usuario.json[/code],
## [code]dados/[/code] e [code]exportacoes/[/code] nunca sao apagados. [br]
## [br]
## Todos os metodos de rede sao [b]assincronos[/b] ([code]await[/code]) e retornam um [Dictionary]
## no formato [code]{ "ok": bool, "erro": String, ... }[/code], como [SyncKinto]. O I/O e disparado
## pelo [code]main.gd[/code], que injeta a configuracao (ver AGENTS.md).

## Emitido durante download e extracao, para alimentar a barra de progresso do [code]main.gd[/code].
signal progresso(fracao: float, texto: String)

# Endpoint da release mais recente. O GitHub recusa requisicoes sem User-Agent (403), por isso ele e
# sempre explicito. O repositorio e publico: nao ha token nem credencial envolvidos.
const _URL_API := "https://api.github.com/repos/%s/releases/latest"
const _CABECALHOS := ["User-Agent: PUG-Atualizador", "Accept: application/vnd.github+json"]

# Timeouts: sem eles, um servidor mudo deixaria request_completed sem disparar e a guarda _ocupado
# presa em true (mesmo motivo documentado em sincronizacao.gd). O download tolera bem mais tempo.
const _TIMEOUT_API := 20.0
const _TIMEOUT_DOWNLOAD := 600.0

# Area de trabalho em user:// (mapeia para %APPDATA%, FORA do OneDrive — nada aqui deve ser
# sincronizado entre as 3 maquinas, pois e especifico do PC que esta se atualizando).
const DIR_TRABALHO := "user://atualizacao/"
const _ARQ_SCRIPT := "aplicar_atualizacao.ps1"
const _ARQ_LOG := "log.txt"
const DIR_STAGING := DIR_TRABALHO + "staging/"

var _repositorio: String = ""
var _nome_asset: String = ""

# No de requisicao criado sob demanda (precisa estar na arvore para processar).
var _http: HTTPRequest
# Guarda contra requisicoes concorrentes no mesmo HTTPRequest.
var _ocupado: bool = false
# Ativa a emissao de progresso em _process durante o download.
var _baixando: bool = false


func _ready() -> void:
	set_process(false)


## Define de onde baixar. [param repositorio] no formato [code]usuario/repo[/code];
## [param nome_asset] e o nome exato do arquivo anexado a release (ex.: [code]PUG_WIN_X64.zip[/code]).
func configurar(repositorio: String, nome_asset: String) -> void:
	_repositorio = repositorio.strip_edges().trim_prefix("/").trim_suffix("/")
	_nome_asset = nome_asset.strip_edges()


## Retorna true quando repositorio e asset estao preenchidos.
func esta_configurado() -> bool:
	return not _repositorio.is_empty() and not _nome_asset.is_empty()


## Versao deste executavel, lida de [code]application/config/version[/code]. E intrinseca ao binario
## (vai embutida no PCK), e nao do [code]base_config.json[/code] — que e um arquivo solto, substituido
## pela propria atualizacao e ainda sobreposto pelo [code]config_usuario.json[/code].
func versao_instalada() -> String:
	var v: String = str(ProjectSettings.get_setting("application/config/version", ""))
	return v if not v.is_empty() else "0.0.0"


## Compara duas versoes no formato [code]X.Y.Z[/code] (o [code]v[/code] inicial e ignorado).
## Retorna -1 se [param a] < [param b], 0 se iguais, 1 se [param a] > [param b]. [br]
## A comparacao e numerica por componente: como texto, "1.10.0" ficaria [i]abaixo[/i] de "1.9.0".
static func comparar_versoes(a: String, b: String) -> int:
	var pa: Array[int] = _componentes(a)
	var pb: Array[int] = _componentes(b)
	for i in maxi(pa.size(), pb.size()):
		var va: int = pa[i] if i < pa.size() else 0
		var vb: int = pb[i] if i < pb.size() else 0
		if va != vb:
			return -1 if va < vb else 1
	return 0


# Quebra "v1.2.3" em [1, 2, 3]. Sufixos nao numericos ("1.2.3-beta") degradam para o numero lido.
static func _componentes(versao: String) -> Array[int]:
	var limpa: String = versao.strip_edges().lstrip("vV")
	var saida: Array[int] = []
	for parte in limpa.split("."):
		saida.append(int(parte))
	return saida


## Consulta a release mais recente. Retorna [code]{ ok, versao, versao_instalada, ha_atualizacao,
## notas, url_zip, url_hash, tamanho, erro }[/code]. Nao baixa nada.
func verificar() -> Dictionary:
	if not esta_configurado():
		return { "ok": false, "erro": "Atualizacao nao configurada (repositorio/arquivo)." }
	var resposta: Dictionary = await _requisitar_texto(_URL_API % _repositorio, _TIMEOUT_API)
	if not resposta["ok"]:
		return resposta

	var dados: Variant = JSON.parse_string(resposta["texto"])
	if not dados is Dictionary:
		return { "ok": false, "erro": "Resposta inesperada do GitHub." }

	var tag: String = str(dados.get("tag_name", ""))
	if tag.is_empty():
		return { "ok": false, "erro": "A release mais recente nao tem numero de versao (tag)." }

	var url_zip: String = ""
	var url_hash: String = ""
	var tamanho: int = 0
	for anexo: Variant in dados.get("assets", []):
		var nome: String = str(anexo.get("name", ""))
		if nome == _nome_asset:
			url_zip = str(anexo.get("browser_download_url", ""))
			tamanho = int(anexo.get("size", 0))
		elif nome == _nome_asset + ".sha256":
			url_hash = str(anexo.get("browser_download_url", ""))
	if url_zip.is_empty():
		return { "ok": false, \
			"erro": "A release %s nao traz o arquivo %s." % [tag, _nome_asset] }

	var instalada: String = versao_instalada()
	return {
		"ok": true,
		"versao": tag,
		"versao_instalada": instalada,
		"ha_atualizacao": comparar_versoes(tag, instalada) > 0,
		"notas": str(dados.get("body", "")),
		"url_zip": url_zip,
		"url_hash": url_hash,
		"tamanho": tamanho,
	}


## Baixa o pacote da release, confere o SHA-256 e extrai para [constant DIR_STAGING], emitindo
## [signal progresso] durante todo o percurso. Nada e aplicado aqui: ao final o pacote esta apenas
## preparado em disco. Retorna [code]{ ok, erro, staging }[/code].
func baixar_e_preparar(info: Dictionary) -> Dictionary:
	_limpar_trabalho()
	DirAccess.make_dir_recursive_absolute(DIR_TRABALHO)
	var caminho_zip: String = DIR_TRABALHO + _nome_asset

	# O hash e opcional (releases antigas podem nao te-lo), mas quando existe e obrigatorio conferir.
	var sha_esperado: String = ""
	if not str(info.get("url_hash", "")).is_empty():
		progresso.emit(0.0, "Obtendo a soma de verificação…")
		var resp_hash: Dictionary = await _requisitar_texto(str(info["url_hash"]), _TIMEOUT_API)
		if resp_hash["ok"]:
			# O arquivo pode vir como "<hash>" ou "<hash>  <nome>"; interessa so o primeiro campo.
			sha_esperado = str(resp_hash["texto"]).strip_edges().split(" ")[0].strip_edges()

	progresso.emit(0.0, "Baixando a atualização…")
	var resp_zip: Dictionary = await _baixar_arquivo(str(info["url_zip"]), caminho_zip)
	if not resp_zip["ok"]:
		return resp_zip

	progresso.emit(1.0, "Conferindo o pacote…")
	var conferencia: Dictionary = validar(caminho_zip, sha_esperado)
	if not conferencia["ok"]:
		return conferencia

	var extracao: Dictionary = await extrair(caminho_zip, DIR_STAGING)
	if not extracao["ok"]:
		return extracao
	return { "ok": true, "staging": DIR_STAGING }


## Confere o pacote baixado: SHA-256 (quando [param sha_esperado] nao e vazio) e o layout interno —
## a raiz do ZIP tem de ser a raiz da instalacao. Um ZIP com pasta de topo passaria pelo download sem
## erro e produziria uma atualizacao morta, sem sintoma; por isso a conferencia de layout.
func validar(caminho_zip: String, sha_esperado: String) -> Dictionary:
	if not FileAccess.file_exists(caminho_zip):
		return { "ok": false, "erro": "O arquivo baixado nao foi encontrado." }

	if not sha_esperado.is_empty():
		var sha_real: String = FileAccess.get_sha256(caminho_zip)
		if sha_real.to_lower() != sha_esperado.to_lower():
			return { "ok": false, "erro": "A conferencia de integridade falhou: o arquivo baixado " + \
				"nao corresponde ao publicado. A atualizacao foi cancelada." }

	var zip := ZIPReader.new()
	if zip.open(caminho_zip) != OK:
		return { "ok": false, "erro": "O arquivo baixado nao e um ZIP valido." }
	var entradas: PackedStringArray = zip.get_files()
	zip.close()

	var tem_config: bool = false
	var tem_executavel: bool = false
	var tem_arquivos: bool = false
	for entrada: String in entradas:
		if entrada == "base_config.json":
			tem_config = true
		elif not entrada.contains("/") and entrada.to_lower().ends_with(".exe"):
			tem_executavel = true
		elif entrada.begins_with("arquivos/"):
			tem_arquivos = true
	if not (tem_config and tem_executavel and tem_arquivos):
		return { "ok": false, "erro": "O pacote nao tem o formato esperado (executavel, " + \
			"base_config.json e arquivos/ na raiz do ZIP). Provavel erro na publicacao da release." }
	return { "ok": true }


## Extrai [param caminho_zip] em [param dir_destino], recriando a arvore de pastas. Cede um frame a
## cada bloco para a barra de progresso repintar.
func extrair(caminho_zip: String, dir_destino: String) -> Dictionary:
	var zip := ZIPReader.new()
	if zip.open(caminho_zip) != OK:
		return { "ok": false, "erro": "Nao foi possivel abrir o pacote baixado." }
	var entradas: PackedStringArray = zip.get_files()
	DirAccess.make_dir_recursive_absolute(dir_destino)

	var total: int = entradas.size()
	for i in total:
		var entrada: String = entradas[i]
		var caminho: String = dir_destino + entrada
		if entrada.ends_with("/"):
			DirAccess.make_dir_recursive_absolute(caminho)
			continue
		DirAccess.make_dir_recursive_absolute(caminho.get_base_dir())
		var arquivo := FileAccess.open(caminho, FileAccess.WRITE)
		if arquivo == null:
			zip.close()
			return { "ok": false, "erro": "Nao foi possivel gravar '%s' na pasta temporaria." % entrada }
		arquivo.store_buffer(zip.read_file(entrada))
		arquivo.close()
		if i % 20 == 0 or i == total - 1:
			progresso.emit(float(i + 1) / float(maxi(total, 1)), \
				"Preparando arquivos (%d de %d)…" % [i + 1, total])
			await get_tree().process_frame
	zip.close()
	return { "ok": true }


## Grava o script auxiliar e o dispara. Depois desta chamada o programa deve encerrar-se
## imediatamente ([code]get_tree().quit()[/code]): e o script quem copia os arquivos por cima de
## [param dir_instalacao] e relanca o executavel. [br]
## Nenhum caminho e interpolado no corpo do script — todos entram como parametros nomeados. Caminhos
## com espaco (o projeto vive em "Auxiliar de Coordenacao GD4") ou acento embutidos no corpo de um
## .bat/.ps1 sao a quebra classica no Windows.
func aplicar(dir_staging: String, dir_instalacao: String, versao: String) -> Dictionary:
	var caminho_script: String = DIR_TRABALHO + _ARQ_SCRIPT
	var arquivo := FileAccess.open(caminho_script, FileAccess.WRITE)
	if arquivo == null:
		return { "ok": false, "erro": "Nao foi possivel gravar o aplicador da atualizacao." }
	arquivo.store_string(_SCRIPT_APLICADOR)
	arquivo.close()

	var argumentos := PackedStringArray([
		"-NoProfile", "-ExecutionPolicy", "Bypass",
		"-File", _caminho_windows(caminho_script),
		"-PidPai", str(OS.get_process_id()),
		"-Origem", _caminho_windows(dir_staging),
		"-Destino", _caminho_windows(dir_instalacao),
		"-Exe", _caminho_windows(OS.get_executable_path()),
		"-Log", _caminho_windows(DIR_TRABALHO + _ARQ_LOG),
		"-Versao", versao,
	])
	# create_process (e nao execute): o aplicador tem de continuar rodando DEPOIS que este processo
	# morrer. O OS.execute usado no resto do projeto e bloqueante e nao serviria aqui.
	var pid: int = OS.create_process("powershell.exe", argumentos)
	if pid <= 0:
		return { "ok": false, "erro": "Nao foi possivel iniciar o aplicador da atualizacao." }
	return { "ok": true, "pid": pid }


## Caminho do log deixado pelo script aplicador (para mostrar ao usuario quando algo falha).
func caminho_log() -> String:
	return _caminho_windows(DIR_TRABALHO + _ARQ_LOG)


# Converte um caminho do Godot (inclusive URIs user://) para caminho absoluto do Windows com
# contrabarras. O PowerShell nao entende "user://", e o robocopy e sensivel a barra final.
func _caminho_windows(caminho: String) -> String:
	var absoluto: String = ProjectSettings.globalize_path(caminho) if caminho.begins_with("user://") \
		or caminho.begins_with("res://") else caminho
	return absoluto.replace("/", "\\").trim_suffix("\\")


# Garante o HTTPRequest na arvore (criacao tardia evita depender da ordem de _ready), ajustando o
# timeout ao tipo de requisicao (consulta rapida x download longo).
func _garantir_http(tempo_limite: float) -> void:
	if _http == null:
		_http = HTTPRequest.new()
		add_child(_http)
	_http.timeout = tempo_limite


# Requisicao GET que devolve texto. Espera o sinal request_completed via await (cujos argumentos
# retornam num Array) — sem capturar locais em lambda (ver AGENTS.md).
func _requisitar_texto(url: String, tempo_limite: float) -> Dictionary:
	if _ocupado:
		return { "ok": false, "erro": "Ja existe uma verificacao em andamento. Aguarde." }
	_garantir_http(tempo_limite)
	_http.download_file = ""
	_ocupado = true

	var err: int = _http.request(url, PackedStringArray(_CABECALHOS))
	if err != OK:
		_ocupado = false
		return { "ok": false, "erro": "Falha ao iniciar a requisicao (erro %d)." % err }

	var resposta: Array = await _http.request_completed
	_ocupado = false
	var resultado: int = resposta[0]
	var codigo: int = resposta[1]
	if resultado != HTTPRequest.RESULT_SUCCESS:
		return { "ok": false, "erro": _erro_rede(resultado) }
	if codigo < 200 or codigo >= 300:
		return { "ok": false, "erro": _erro_http(codigo) }
	return { "ok": true, "texto": (resposta[3] as PackedByteArray).get_string_from_utf8() }


# Download de arquivo direto para o disco (download_file), com threads para nao travar a interface.
# O progresso e emitido em _process, que le get_downloaded_bytes()/get_body_size().
func _baixar_arquivo(url: String, destino: String) -> Dictionary:
	if _ocupado:
		return { "ok": false, "erro": "Ja existe um download em andamento. Aguarde." }
	_garantir_http(_TIMEOUT_DOWNLOAD)
	_http.use_threads = true
	_http.download_file = destino
	_ocupado = true

	var err: int = _http.request(url, PackedStringArray(_CABECALHOS))
	if err != OK:
		_ocupado = false
		_http.download_file = ""
		return { "ok": false, "erro": "Falha ao iniciar o download (erro %d)." % err }

	_baixando = true
	set_process(true)
	var resposta: Array = await _http.request_completed
	_baixando = false
	set_process(false)
	_ocupado = false
	_http.download_file = ""
	# Devolve o no ao estado padrao: o mesmo _http atende as consultas de texto depois daqui, e
	# use_threads ligado seria um efeito colateral carregado do download.
	_http.use_threads = false

	var resultado: int = resposta[0]
	var codigo: int = resposta[1]
	if resultado != HTTPRequest.RESULT_SUCCESS:
		return { "ok": false, "erro": _erro_rede(resultado) }
	if codigo < 200 or codigo >= 300:
		return { "ok": false, "erro": _erro_http(codigo) }
	return { "ok": true }


func _process(_delta: float) -> void:
	if not _baixando or _http == null:
		return
	var total: int = _http.get_body_size()
	var recebido: int = _http.get_downloaded_bytes()
	var mb_recebido: float = float(recebido) / 1048576.0
	if total > 0:
		progresso.emit(float(recebido) / float(total), \
			"Baixando a atualização (%.1f de %.1f MB)…" % [mb_recebido, float(total) / 1048576.0])
	else:
		progresso.emit(0.0, "Baixando a atualização (%.1f MB)…" % mb_recebido)


# Apaga a area de trabalho de uma tentativa anterior, para nao misturar pacotes de versoes diferentes.
func _limpar_trabalho() -> void:
	_remover_recursivo(DIR_TRABALHO)


func _remover_recursivo(caminho: String) -> void:
	var dir := DirAccess.open(caminho)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_remover_recursivo(caminho.path_join(sub))
	for arq: String in dir.get_files():
		DirAccess.remove_absolute(caminho.path_join(arq))
	DirAccess.remove_absolute(caminho)


func _erro_rede(resultado: int) -> String:
	return "Sem conexao com o GitHub. Verifique a internet (resultado %d)." % resultado


func _erro_http(codigo: int) -> String:
	match codigo:
		404:
			return "Nenhuma versao publicada foi encontrada no repositorio (404)."
		403:
			return "O GitHub recusou a consulta (403). Pode ser limite de requisicoes; tente mais tarde."
		_:
			return "Erro ao consultar o GitHub (HTTP %d)." % codigo


# Script auxiliar que faz a troca depois que o programa fecha. Mantido em ASCII puro de proposito: o
# PowerShell 5.1 le arquivos .ps1 sem BOM usando a codepage ANSI, e acentos aqui viravam lixo.
# Todos os caminhos chegam como parametros — nada e interpolado neste corpo.
const _SCRIPT_APLICADOR := """param(
    [int]$PidPai,
    [string]$Origem,
    [string]$Destino,
    [string]$Exe,
    [string]$Log,
    [string]$Versao
)

$ErrorActionPreference = "Stop"
$backup = ""

function Registrar($mensagem) {
    $linha = "[" + (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + "] " + $mensagem
    Add-Content -LiteralPath $Log -Value $linha
}

try {
    Registrar "Aplicando a versao $Versao"
    Registrar "Origem:  $Origem"
    Registrar "Destino: $Destino"

    # Espera o PID real do programa, em vez de dormir e torcer.
    try {
        Wait-Process -Id $PidPai -Timeout 60
        Registrar "Programa encerrado."
    } catch {
        Registrar ("Espera pelo processo: " + $_.Exception.Message)
    }
    Start-Sleep -Milliseconds 500

    # Copia de seguranca do executavel EM USO (nao dos quatro): cada um passa de 100 MB e a pasta e
    # replicada pelo OneDrive. Guardar so o que o usuario de fato abre mantem o rollback possivel
    # sem encher o disco. Backups de atualizacoes anteriores sao descartados pelo mesmo motivo.
    $raizBackup = Join-Path $Destino ".backup"
    if (Test-Path -LiteralPath $raizBackup) {
        Get-ChildItem -LiteralPath $raizBackup -Directory -Filter "pre_atualizacao_*" |
            ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force }
    }
    $backup = Join-Path $raizBackup ("pre_atualizacao_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
    New-Item -ItemType Directory -Force -Path $backup | Out-Null
    if (Test-Path -LiteralPath $Exe) {
        Copy-Item -LiteralPath $Exe -Destination $backup -Force
    }
    Registrar "Executavel em uso copiado para $backup"

    # /E sem /PURGE: copia aditiva. NUNCA espelhar — grades acrescentadas pelo coordenador em
    # arquivos/, o config_usuario.json, dados/ e exportacoes/ tem de sobreviver a atualizacao.
    & robocopy $Origem $Destino /E /R:3 /W:2 /NFL /NDL /NJH /NJS | Out-Null
    $codigo = $LASTEXITCODE
    Registrar "robocopy terminou com codigo $codigo"
    if ($codigo -ge 8) { throw "robocopy falhou (codigo $codigo)" }

    Registrar "Relancando $Exe"
    Start-Process -FilePath $Exe -WorkingDirectory $Destino
    Registrar "Concluido."
} catch {
    Registrar ("ERRO: " + $_.Exception.Message)
    if ($backup -ne "" -and (Test-Path -LiteralPath $backup)) {
        Registrar "Restaurando o executavel anterior."
        try {
            Get-ChildItem -LiteralPath $backup -Filter *.exe -File | ForEach-Object {
                Copy-Item -LiteralPath $_.FullName -Destination $Destino -Force
            }
        } catch {
            Registrar ("Falha ao restaurar: " + $_.Exception.Message)
        }
    }
    try { Start-Process -FilePath $Exe -WorkingDirectory $Destino } catch { }
}
"""
