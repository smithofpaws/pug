<#
.SYNOPSIS
    Monta os pacotes portateis do PUG (x64 e ARM64) e publica-os como release no GitHub.

.DESCRIPTION
    Este script e o outro lado do atualizador automatico (standalone_scripts/io/atualizador.gd).
    Ele garante o contrato do ZIP: a raiz do pacote e a raiz da instalacao, sem pasta de topo. Um
    desencontro aqui produz uma atualizacao morta, sem sintoma nenhum para o usuario.

    Por padrao apenas PREPARA os pacotes (versao, exportacao, zip, soma de verificacao, conferencia)
    e deixa o resultado na Area de Trabalho. Passe -Publicar para tambem commitar a versao, criar a
    tag anotada, enviar ao GitHub e criar a release.

    Sao dois pacotes, um por arquitetura: PUG_WIN_X64.zip e PUG_WIN_ARM64.zip. Cada um leva o seu
    proprio base_config.json, com atualizacao.asset apontando para o proprio nome - assim uma
    instalacao ARM continua se atualizando com pacotes ARM.

    Observacao sobre acentos: o corpo deste script e ASCII puro de proposito. O PowerShell 5.1 le
    arquivos .ps1 sem BOM usando a codepage ANSI, e acentos aqui apareceriam corrompidos.

.PARAMETER Versao
    Numero da versao no formato X.Y.Z (ex.: 1.1.0). Vira a tag vX.Y.Z.

.PARAMETER Notas
    Caminho de um arquivo com as notas da release. Sem ele, o GitHub gera as notas automaticamente.

.PARAMETER SemArm
    Gera somente o pacote x64. Valvula de escape para quando os modelos de exportacao ARM64 nao
    estiverem instalados e for preciso publicar assim mesmo.

.PARAMETER Publicar
    Alem de preparar, commita a versao, cria a tag, faz push e publica a release no GitHub.

.PARAMETER Info
    So mostra a versao atual, a ultima tag publicada e sugestoes de numeracao. Nao exporta nada.

.EXAMPLE
    .\ferramentas\publicar_release.ps1 -Info
    .\ferramentas\publicar_release.ps1 -Versao 1.1.0
    .\ferramentas\publicar_release.ps1 -Versao 1.1.0 -Publicar
#>
[CmdletBinding(DefaultParameterSetName = "Publicacao")]
param(
    [Parameter(Mandatory = $true, ParameterSetName = "Publicacao", Position = 0)][string]$Versao,
    [Parameter(ParameterSetName = "Publicacao")][string]$Notas = "",
    [Parameter(ParameterSetName = "Publicacao")][switch]$SemArm,
    [Parameter(ParameterSetName = "Publicacao")][switch]$Publicar,
    [Parameter(Mandatory = $true, ParameterSetName = "Info")][switch]$Info,
    [string]$Godot = "C:\Program Files\Godot\Godot_console.exe"
)

$ErrorActionPreference = "Stop"

$Raiz = Split-Path -Parent $PSScriptRoot
$Git  = "C:\Program Files\Git\cmd\git.exe"
$Tag  = "v$Versao"
$Temp = Join-Path $env:TEMP "pug_release_$Versao"

# Uma entrada por arquitetura publicada. O nome do preset tem de bater com export_presets.cfg, e o
# nome do asset com o que o atualizador procura na release (base_config.json:atualizacao.asset).
# Templates = os modelos de exportacao que o Godot exige para aquela arquitetura; sao conferidos
# ANTES de exportar, porque descobrir o modelo faltando depois de uma exportacao de varios minutos
# e puro desperdicio.
$Arquiteturas = @(
    @{ Nome = "x64";   Preset = "PUG";       Asset = "PUG_WIN_X64.zip";
       Templates = @("windows_release_x86_64.exe", "windows_debug_x86_64.exe") },
    @{ Nome = "arm64"; Preset = "PUG_ARM64"; Asset = "PUG_WIN_ARM64.zip";
       Templates = @("windows_release_arm64.exe", "windows_debug_arm64.exe") }
)

# Grava texto em UTF-8 SEM BOM. O Set-Content -Encoding UTF8 do PowerShell 5.1 adiciona BOM, que nao
# tem lugar no project.godot nem no export_presets.cfg.
function Escrever-Texto($caminho, $conteudo) {
    $utf8SemBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($caminho, $conteudo, $utf8SemBom)
}

function Passo($mensagem) {
    Write-Host ""
    Write-Host ">> $mensagem" -ForegroundColor Cyan
}

# Versao gravada em project.godot (a mesma que vai embutida no binario e que o atualizador compara).
function Ler-VersaoProjeto {
    $arq = Join-Path $Raiz "project.godot"
    if (-not (Test-Path -LiteralPath $arq)) { return "" }
    $m = [regex]::Match([System.IO.File]::ReadAllText($arq), '(?m)^config/version="(.*)"$')
    if ($m.Success) { return $m.Groups[1].Value }
    return ""
}

# Ultima tag de versao, pela ordem de VERSAO (--sort=-v:refname), nao alfabetica.
#
# Sao as tags LOCAIS: nao ha fetch aqui, e o projeto vive em 3 PCs. Numa maquina que nao deu pull
# desde a ultima release, a tag mostrada estaria atrasada - por isso a linha se chama "tag local" e
# nao "tag publicada". O erro so apareceria la no push, depois de exportar tudo.
function Ler-UltimaTag {
    if (-not (Test-Path -LiteralPath $Git)) { return "" }
    try {
        $tags = @(& $Git -C $Raiz tag --list "v*" --sort=-v:refname)
        if ($tags.Count -gt 0) { return $tags[0] }
    } catch { }
    return ""
}

# Painel de numeracao mostrado antes de perguntar a versao (o .bat chama com -Info).
#
# Mostra as DUAS fontes de proposito. O project.godot pode estar ADIANTE da ultima tag: o modo
# preparacao grava a versao no arquivo e nao a commita, entao um ensaio abandonado deixa um numero
# ali que nunca virou release. A tag e o que de fato existe publicado; a divergencia entre as duas
# linhas e justamente o que precisa saltar aos olhos.
function Mostrar-Info {
    $atual = Ler-VersaoProjeto
    $tag   = Ler-UltimaTag
    Write-Host ""
    if ($atual -eq "") {
        Write-Host "Versao em project.godot: (nao consegui ler)" -ForegroundColor Yellow
    } else {
        Write-Host "Versao em project.godot: $atual" -ForegroundColor White
    }
    if ($tag -eq "") {
        Write-Host "Ultima tag local:        (nenhuma)" -ForegroundColor White
    } else {
        Write-Host "Ultima tag local:        $tag   (rode 'git pull' se acabou de trocar de PC)" -ForegroundColor White
    }
    $m = [regex]::Match($atual, '^(\d+)\.(\d+)\.(\d+)$')
    if ($m.Success) {
        $a = [int]$m.Groups[1].Value
        $b = [int]$m.Groups[2].Value
        $c = [int]$m.Groups[3].Value
        Write-Host ""
        Write-Host "Sugestoes a partir de ${atual}:"
        Write-Host ("   {0}.{1}.{2}   correcao de erro" -f $a, $b, ($c + 1))
        Write-Host ("   {0}.{1}.0   funcionalidade nova" -f $a, ($b + 1))
        Write-Host ("   {0}.0.0   mudanca grande / incompativel" -f ($a + 1))
    }
    if ($atual -ne "" -and $tag -ne "" -and $tag -ne ("v" + $atual)) {
        Write-Host ""
        Write-Host ("Atencao: o project.godot ($atual) nao corresponde a ultima tag local ($tag). " +
                    "Provavelmente sobrou de uma preparacao que nao virou release.") -ForegroundColor Yellow
    }
}

if ($Info) {
    Mostrar-Info
    exit 0
}

# Pasta de modelos de exportacao desta instalacao do Godot (ex.: %APPDATA%\Godot\export_templates\
# 4.7.stable). Retorna "" quando nao da para determinar - o chamador entao apenas avisa, porque um
# palpite errado sobre o caminho nao pode barrar uma publicacao legitima.
function Pasta-Templates {
    try {
        $saida = @(& $Godot --version)
    } catch {
        return ""
    }
    foreach ($linha in $saida) {
        $m = [regex]::Match([string]$linha, '^(\d+\.\d+(?:\.\d+)?\.[A-Za-z]+)')
        if ($m.Success) {
            return (Join-Path $env:APPDATA ("Godot\export_templates\" + $m.Groups[1].Value))
        }
    }
    return ""
}

# Confere os modelos de exportacao ANTES de comecar. Sem esta guarda, a falta do modelo ARM64 so
# apareceria depois da exportacao x64 inteira - varios minutos jogados fora.
function Conferir-Templates($arqs) {
    $pasta = Pasta-Templates
    if ($pasta -eq "" -or -not (Test-Path -LiteralPath $pasta)) {
        Write-Host "   nao consegui localizar a pasta de modelos; a propria exportacao dira se falta algum." -ForegroundColor Yellow
        return
    }
    $faltando = @()
    foreach ($arq in $arqs) {
        foreach ($modelo in $arq.Templates) {
            if (-not (Test-Path -LiteralPath (Join-Path $pasta $modelo))) {
                $faltando += ($arq.Nome + ": " + $modelo)
            }
        }
    }
    if ($faltando.Count -gt 0) {
        Write-Host ($faltando -join "`n") -ForegroundColor Red
        throw ("Faltam modelos de exportacao em '" + $pasta + "'. Instale-os pelo editor do Godot " +
               "(Editor > Gerenciar modelos de exportacao > Baixar e instalar) ou, para publicar " +
               "somente a versao x64 agora, escolha 'X' no menu do .bat (ou rode com -SemArm).")
    }
    Write-Host ("   modelos conferidos em " + $pasta)
}

# Confere o que o Godot embutiu no PCK, lendo o log da exportacao ($log) da variante $variante.
#
# A conferencia do ZIP, mais abaixo, olha o LAYOUT do pacote e nao enxerga o interior dos
# executaveis. Mas export_filter="all_resources" leva para dentro do PCK todo arquivo solto na raiz
# do projeto, gitignorado ou nao: foi assim que o config_usuario.json - com usuario e token do Kinto
# - entrou nos binarios da 1.0.0, publicada. O exclude_filter dos presets fecha o buraco; esta
# guarda existe para que a regressao apareca aqui, e nao numa release publica.
#
# Le o LOG, e nao o .exe: no binario pronto o caminho "res://..." nao aparece como texto (so o
# conteudo do arquivo aparece), e procurar pelo nome solto acusa qualquer mencao no codigo - o
# main.gd le "config_usuario.json" pelo nome, entao o falso positivo seria garantido. O log traz uma
# linha "Storing File: res://<caminho>" por arquivo empacotado, que e exatamente a pergunta certa.
function Conferir-Pck($log, $variante) {
    $proibidos = @("res://config_usuario.json", "res://arquivos/limesurvey/survey_tokens.lst")
    $linhas = @(Select-String -Path $log -SimpleMatch "Storing File: res://" -ErrorAction SilentlyContinue)
    # Nenhuma linha significa que o formato do log mudou e a guarda deixou de enxergar o PCK.
    # Silenciosamente aprovar seria pior que falhar: o ponto cego voltaria sem aviso nenhum.
    if ($linhas.Count -eq 0) {
        throw ("Nao consegui conferir o conteudo do PCK ($variante): o log da exportacao nao tem " +
               "nenhuma linha 'Storing File:'. Confira o formato do log do Godot antes de publicar.")
    }
    foreach ($proibido in $proibidos) {
        foreach ($linha in $linhas) {
            if ($linha.Line.Contains("Storing File: " + $proibido)) {
                throw ("'" + $proibido + "' foi embutido no PCK ($variante). Confira o " +
                       "exclude_filter em export_presets.cfg. NAO publique este build.")
            }
        }
    }
    Write-Host ("   PCK conferido: " + $linhas.Count + " arquivos, nenhum proibido.")
}

# Exporta, monta, compacta e CONFERE o pacote de uma arquitetura. Devolve
# @{ Asset; Zip; Hash; ArqHash; TamanhoMB }.
#
# Todas as guardas vivem aqui dentro de proposito: elas sao por PACOTE. Deixar qualquer uma no
# caminho de uma arquitetura so significaria que a outra sai sem conferencia nenhuma - e um pacote
# nao conferido e exatamente o que ja vazou credencial uma vez.
function Empacotar-Arquitetura($arq, $rastreados) {
    $nome  = $arq.Nome
    $asset = $arq.Asset

    $base       = Join-Path $Temp $nome
    $dirRelease = Join-Path $base "release"
    $dirDebug   = Join-Path $base "debug"
    $staging    = Join-Path $base "staging"
    New-Item -ItemType Directory -Force -Path $dirRelease, $dirDebug, $staging | Out-Null

    # Duas passadas em pastas separadas: release e debug produzem os MESMOS nomes de arquivo e
    # colidiriam na mesma pasta. O console wrapper sai junto de cada uma (export_console_wrapper=2).
    # A saida de cada exportacao e guardada: e nela que o Godot lista, linha a linha, TUDO que entrou
    # no PCK ("Storing File: res://..."). E a unica leitura confiavel do conteudo do pacote embutido
    # - no binario pronto o caminho nao aparece como texto, so o conteudo do arquivo. Ver
    # Conferir-Pck acima.
    $logRelease = Join-Path $base "export_release.log"
    $logDebug   = Join-Path $base "export_debug.log"

    Passo "Exportando $nome (release)"
    # Tee-Object devolveria a saida do Godot como valor de retorno da funcao; Out-Host a manda para o
    # console e deixa o retorno limpo.
    & $Godot --headless --path $Raiz --export-release $arq.Preset (Join-Path $dirRelease "Auxiliar.exe") |
        Tee-Object -FilePath $logRelease | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "A exportacao release ($nome) falhou (codigo $LASTEXITCODE)." }
    Conferir-Pck $logRelease "$nome release"

    Passo "Exportando $nome (debug)"
    & $Godot --headless --path $Raiz --export-debug $arq.Preset (Join-Path $dirDebug "Auxiliar.exe") |
        Tee-Object -FilePath $logDebug | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "A exportacao debug ($nome) falhou (codigo $LASTEXITCODE)." }
    Conferir-Pck $logDebug "$nome debug"

    # ---------------------------------------------------------------- montagem do pacote
    Passo "Montando o pacote $nome"
    $variantes = @(
        @{ Origem = (Join-Path $dirRelease "Auxiliar.exe");         Nome = "Auxiliar.exe" },
        @{ Origem = (Join-Path $dirRelease "Auxiliar.console.exe"); Nome = "Auxiliar.console.exe" },
        @{ Origem = (Join-Path $dirDebug   "Auxiliar.exe");         Nome = "Auxiliar_debug.exe" },
        @{ Origem = (Join-Path $dirDebug   "Auxiliar.console.exe"); Nome = "Auxiliar_debug.console.exe" }
    )
    foreach ($v in $variantes) {
        if (-not (Test-Path -LiteralPath $v.Origem)) {
            throw ("Executavel esperado nao foi gerado: " + $v.Origem)
        }
        Copy-Item -LiteralPath $v.Origem -Destination (Join-Path $staging $v.Nome) -Force
    }

    Copy-Item -LiteralPath (Join-Path $Raiz "base_config.json") -Destination $staging -Force
    Copy-Item -LiteralPath (Join-Path $Raiz "MANUAL.md")        -Destination $staging -Force

    # Cada pacote se atualiza com pacotes da PROPRIA arquitetura. Sem isto, um PC ARM baixaria o
    # PUG_WIN_X64.zip na primeira atualizacao e trocaria os binarios nativos por binarios emulados,
    # em silencio e sem volta automatica. So a chave "asset" muda; o resto do base_config.json e o
    # mesmo arquivo versionado.
    $arqConfig = Join-Path $staging "base_config.json"
    $txtConfig = [System.IO.File]::ReadAllText($arqConfig)
    if ($txtConfig -notmatch '"asset"\s*:\s*"[^"]*"') {
        throw "Nao encontrei a chave 'asset' em base_config.json (secao atualizacao)."
    }
    $txtConfig = $txtConfig -replace '("asset"\s*:\s*")[^"]*(")', ('${1}' + $asset + '${2}')
    Escrever-Texto $arqConfig $txtConfig
    Write-Host "   base_config.json aponta para $asset."

    # arquivos/ e externo/bin/ entram pelo que o GIT rastreia, nao por copia cega da pasta. Assim
    # nada gitignorado escapa para um pacote publico - em especial
    # arquivos/limesurvey/survey_tokens.lst, que sao tokens vinculados a alunos (LGPD).
    foreach ($rel in $rastreados) {
        $origem  = Join-Path $Raiz $rel
        $destino = Join-Path $staging $rel
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destino) | Out-Null
        Copy-Item -LiteralPath $origem -Destination $destino -Force
    }
    Write-Host ("   " + $rastreados.Count + " arquivos versionados de arquivos/ e externo/bin/.")

    # ---------------------------------------------------------------- zip
    Passo "Compactando $nome"
    $zipFinal = Join-Path $Temp $asset
    # As entradas sao criadas UMA A UMA com o caminho relativo montado a mao, e nao por
    # CreateFromDirectory/Compress-Archive: no .NET Framework do PowerShell 5.1 ambos gravam os
    # separadores com CONTRABARRA ("arquivos\dicas.json"). O ZIPReader do Godot leria isso como um
    # nome de arquivo unico e a atualizacao quebraria - sem erro visivel no empacotamento.
    $arquivo = [System.IO.Compression.ZipFile]::Open($zipFinal, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($item in (Get-ChildItem -LiteralPath $staging -Recurse -File)) {
            $rel = $item.FullName.Substring($staging.Length + 1).Replace('\', '/')
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $arquivo, $item.FullName, $rel,
                [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
        }
    }
    finally { $arquivo.Dispose() }

    # ---------------------------------------------------------------- conferencia do pacote
    Passo "Conferindo o conteudo do pacote $nome"
    $zip = [System.IO.Compression.ZipFile]::OpenRead($zipFinal)
    $nomes = @($zip.Entries | ForEach-Object { $_.FullName })
    $zip.Dispose()

    # O separador tem de ser barra. Se alguma entrada vier com contrabarra, o ZIPReader do Godot a
    # trataria como um nome de arquivo unico e a atualizacao quebraria em silencio.
    $tortas = @($nomes | Where-Object { $_ -like "*\*" })
    if ($tortas.Count -gt 0) {
        Write-Host ($tortas -join "`n") -ForegroundColor Red
        throw "ABORTADO: ha entradas com contrabarra no ZIP ($nome)."
    }

    # Vazamento so aparece DEPOIS de publicado, e uma release publica e permanente mesmo se apagada.
    # Por isso a checagem e automatica, e nao conferencia a olho.
    $proibidos = @("survey_tokens", "config_usuario.json", "dados/", "exportacoes/", ".backup",
                   "historico_professores", "lista_professores", "arquivos/oferta/")
    foreach ($p in $proibidos) {
        $achados = @($nomes | Where-Object { $_ -like "*$p*" })
        if ($achados.Count -gt 0) {
            Write-Host ($achados -join "`n") -ForegroundColor Red
            throw "ABORTADO: o pacote $nome contem arquivo proibido ('$p'). Nada foi publicado."
        }
    }
    if ($nomes -notcontains "base_config.json") { throw "O pacote $nome nao tem base_config.json na raiz." }
    if (@($nomes | Where-Object { $_ -match '^[^/]+\.exe$' }).Count -eq 0) {
        throw "O pacote $nome nao tem nenhum executavel na raiz (pasta de topo indevida?)."
    }
    if (@($nomes | Where-Object { $_ -like "arquivos/*" }).Count -eq 0) {
        throw "O pacote $nome nao tem a pasta arquivos/."
    }
    Write-Host ("   " + $nomes.Count + " entradas, layout conferido.")

    # ---------------------------------------------------------------- soma de verificacao
    Passo "Gerando a soma de verificacao de $nome"
    # Somente a string do hash: o Get-FileHash devolve um objeto, e serializa-lo inteiro faria a
    # comparacao do atualizador nunca casar.
    $hash = (Get-FileHash -LiteralPath $zipFinal -Algorithm SHA256).Hash.ToLower()
    $arqHash = "$zipFinal.sha256"
    Escrever-Texto $arqHash $hash
    Write-Host "   $hash"

    return @{
        Asset     = $asset
        Zip       = $zipFinal
        ArqHash   = $arqHash
        TamanhoMB = [math]::Round((Get-Item -LiteralPath $zipFinal).Length / 1MB, 1)
    }
}

try {
    # ---------------------------------------------------------------- pre-condicoes
    if ($Versao -notmatch '^\d+\.\d+\.\d+$') {
        throw "Versao deve estar no formato X.Y.Z (ex.: 1.1.0). Recebido: '$Versao'."
    }
    if (-not (Test-Path -LiteralPath $Godot)) {
        throw "Godot nao encontrado em '$Godot'. Informe o caminho com -Godot."
    }
    if ($SemArm) { $Arquiteturas = @($Arquiteturas[0]) }

    # Os dois assemblies: ZipArchiveMode vive em System.IO.Compression, o resto em .FileSystem.
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    # A exportacao le do DISCO, nao do git. Com a arvore suja, o pacote publicado conteria alteracoes
    # que nao estao em commit nenhum e ninguem conseguiria reproduzir aquele build depois.
    Passo "Conferindo a arvore de trabalho"
    $sujo = & $Git -C $Raiz status --porcelain
    if ($sujo) {
        Write-Host $sujo
        throw "Ha alteracoes nao commitadas. Commite (ou descarte) antes de publicar uma release."
    }
    $tagExistente = & $Git -C $Raiz tag --list $Tag
    if ($tagExistente) { throw "A tag $Tag ja existe. Escolha outra versao." }
    Write-Host "   arvore limpa, tag $Tag livre."

    Passo "Conferindo os modelos de exportacao"
    Write-Host ("   arquiteturas: " + (($Arquiteturas | ForEach-Object { $_.Nome }) -join ", "))
    Conferir-Templates $Arquiteturas

    # ---------------------------------------------------------------- versao
    Passo "Gravando a versao $Versao"
    $arqProjeto = Join-Path $Raiz "project.godot"
    $txtProjeto = [System.IO.File]::ReadAllText($arqProjeto)
    if ($txtProjeto -notmatch '(?m)^config/version=".*"$') {
        throw "Nao encontrei 'config/version' em project.godot."
    }
    $txtProjeto = $txtProjeto -replace '(?m)^config/version=".*"$', ('config/version="' + $Versao + '"')
    Escrever-Texto $arqProjeto $txtProjeto

    # O Windows espera quatro componentes nos metadados do executavel. A substituicao e global: pega
    # de uma vez os presets de TODAS as arquiteturas (PUG e PUG_ARM64).
    $versao4 = "$Versao.0"
    $arqPresets = Join-Path $Raiz "export_presets.cfg"
    $txtPresets = [System.IO.File]::ReadAllText($arqPresets)
    $txtPresets = $txtPresets -replace '(?m)^application/file_version=".*"$',    ('application/file_version="' + $versao4 + '"')
    $txtPresets = $txtPresets -replace '(?m)^application/product_version=".*"$', ('application/product_version="' + $versao4 + '"')
    Escrever-Texto $arqPresets $txtPresets
    Write-Host "   project.godot e export_presets.cfg atualizados."

    # ---------------------------------------------------------------- pacotes
    if (Test-Path -LiteralPath $Temp) { Remove-Item -Recurse -Force -LiteralPath $Temp }
    New-Item -ItemType Directory -Force -Path $Temp | Out-Null

    # A lista do git e a mesma para todas as arquiteturas; lida uma vez so.
    $rastreados = & $Git -C $Raiz ls-files arquivos externo/bin
    # arquivos/oferta/ fica de fora do pacote: os dados de docentes vem da sincronizacao com o repo
    # privado do curso, em cada maquina, e o unico arquivo versionado ali (.gdignore) so serve ao
    # editor do Godot. Sem esta exclusao, a guarda de arquivo proibido abaixo barraria o proprio
    # .gdignore e a publicacao nunca passaria.
    $rastreados = @($rastreados | Where-Object { -not $_.StartsWith("arquivos/oferta/") })

    $pacotes = @()
    foreach ($arq in $Arquiteturas) {
        $pacotes += (Empacotar-Arquitetura $arq $rastreados)
    }

    # ---------------------------------------------------------------- entrega
    $desktop = [Environment]::GetFolderPath("Desktop")
    Write-Host ""
    foreach ($p in $pacotes) {
        Copy-Item -LiteralPath $p.Zip     -Destination $desktop -Force
        Copy-Item -LiteralPath $p.ArqHash -Destination $desktop -Force
        Write-Host ("Pacote pronto: $desktop\" + $p.Asset + " (" + $p.TamanhoMB + " MB)") -ForegroundColor Green
    }
    if ($SemArm) {
        Write-Host "Sem o pacote ARM64 (-SemArm)." -ForegroundColor Yellow
    }

    if (-not $Publicar) {
        Write-Host ""
        Write-Host "Nada foi enviado ao GitHub (modo preparacao)." -ForegroundColor Yellow
        Write-Host "Para publicar de fato, rode de novo com -Publicar."
        Write-Host "As alteracoes de versao ficaram no working tree; para desfazer:"
        Write-Host "   git checkout -- project.godot export_presets.cfg"
        exit 0
    }

    # ---------------------------------------------------------------- publicacao
    Passo "Commitando a versao e criando a tag"
    & $Git -C $Raiz add project.godot export_presets.cfg
    # A versao pedida pode ja estar commitada (ex.: a primeira release, cuja versao entrou junto com
    # o codigo). Nesse caso nao ha o que commitar, e um "git commit" vazio falharia sem motivo.
    $pendente = & $Git -C $Raiz diff --cached --name-only
    if ($pendente) {
        & $Git -C $Raiz commit -m "Versao $Versao"
        if ($LASTEXITCODE -ne 0) { throw "Falha ao commitar a versao." }
    }
    else {
        Write-Host "   a versao ja estava commitada; nada a commitar."
    }
    # Tag ANOTADA: o --follow-tags do push so envia tags anotadas.
    & $Git -C $Raiz tag -a $Tag -m "PUG $Versao"
    if ($LASTEXITCODE -ne 0) { throw "Falha ao criar a tag $Tag." }

    Passo "Enviando ao GitHub"
    # A tag precisa existir no remoto ANTES do gh release create. Sem isso o gh cria a tag no
    # servidor apontando para o HEAD do branch padrao remoto - que pode nao ser a arvore exportada.
    & $Git -C $Raiz push origin HEAD --follow-tags
    if ($LASTEXITCODE -ne 0) { throw "Falha no push. A tag existe localmente; nada foi publicado." }

    Passo "Criando a release"
    $argsGh = @("release", "create", $Tag)
    foreach ($p in $pacotes) { $argsGh += @($p.Zip, $p.ArqHash) }
    $argsGh += @("--title", "PUG $Versao")
    if ($Notas -ne "") { $argsGh += @("--notes-file", $Notas) } else { $argsGh += @("--generate-notes") }
    & gh @argsGh
    if ($LASTEXITCODE -ne 0) { throw "Falha ao criar a release no GitHub." }

    Write-Host ""
    Write-Host "Release $Tag publicada." -ForegroundColor Green
}
catch {
    Write-Host ""
    Write-Host ("ERRO: " + $_.Exception.Message) -ForegroundColor Red
    Write-Host "Se a versao ja tinha sido gravada nos arquivos, desfaca com:"
    Write-Host "   git checkout -- project.godot export_presets.cfg"
    exit 1
}
finally {
    # O AGENTS.md exige limpar os temporarios da exportacao. As copias na Area de Trabalho ficam.
    if (Test-Path -LiteralPath $Temp) {
        Remove-Item -Recurse -Force -LiteralPath $Temp -ErrorAction SilentlyContinue
    }
}
