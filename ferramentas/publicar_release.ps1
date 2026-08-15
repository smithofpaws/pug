<#
.SYNOPSIS
    Monta o pacote portatil do PUG e publica-o como release no GitHub.

.DESCRIPTION
    Este script e o outro lado do atualizador automatico (standalone_scripts/io/atualizador.gd).
    Ele garante o contrato do ZIP: a raiz do pacote e a raiz da instalacao, sem pasta de topo. Um
    desencontro aqui produz uma atualizacao morta, sem sintoma nenhum para o usuario.

    Por padrao apenas PREPARA o pacote (versao, exportacao, zip, soma de verificacao, conferencia) e
    deixa o resultado na Area de Trabalho. Passe -Publicar para tambem commitar a versao, criar a
    tag anotada, enviar ao GitHub e criar a release.

    Observacao sobre acentos: o corpo deste script e ASCII puro de proposito. O PowerShell 5.1 le
    arquivos .ps1 sem BOM usando a codepage ANSI, e acentos aqui apareceriam corrompidos.

.PARAMETER Versao
    Numero da versao no formato X.Y.Z (ex.: 1.1.0). Vira a tag vX.Y.Z.

.PARAMETER Notas
    Caminho de um arquivo com as notas da release. Sem ele, o GitHub gera as notas automaticamente.

.PARAMETER Publicar
    Alem de preparar, commita a versao, cria a tag, faz push e publica a release no GitHub.

.EXAMPLE
    .\ferramentas\publicar_release.ps1 -Versao 1.1.0
    .\ferramentas\publicar_release.ps1 -Versao 1.1.0 -Publicar
#>
param(
    [Parameter(Mandatory = $true)][string]$Versao,
    [string]$Notas = "",
    [string]$Godot = "C:\Program Files\Godot\Godot_console.exe",
    [switch]$Publicar
)

$ErrorActionPreference = "Stop"

$Raiz  = Split-Path -Parent $PSScriptRoot
$Git   = "C:\Program Files\Git\cmd\git.exe"
$Asset = "PUG_WIN_X64.zip"
$Tag   = "v$Versao"
$Temp  = Join-Path $env:TEMP "pug_release_$Versao"

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

try {
    # ---------------------------------------------------------------- pre-condicoes
    if ($Versao -notmatch '^\d+\.\d+\.\d+$') {
        throw "Versao deve estar no formato X.Y.Z (ex.: 1.1.0). Recebido: '$Versao'."
    }
    if (-not (Test-Path -LiteralPath $Godot)) {
        throw "Godot nao encontrado em '$Godot'. Informe o caminho com -Godot."
    }

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

    # ---------------------------------------------------------------- versao
    Passo "Gravando a versao $Versao"
    $arqProjeto = Join-Path $Raiz "project.godot"
    $txtProjeto = [System.IO.File]::ReadAllText($arqProjeto)
    if ($txtProjeto -notmatch '(?m)^config/version=".*"$') {
        throw "Nao encontrei 'config/version' em project.godot."
    }
    $txtProjeto = $txtProjeto -replace '(?m)^config/version=".*"$', ('config/version="' + $Versao + '"')
    Escrever-Texto $arqProjeto $txtProjeto

    # O Windows espera quatro componentes nos metadados do executavel.
    $versao4 = "$Versao.0"
    $arqPresets = Join-Path $Raiz "export_presets.cfg"
    $txtPresets = [System.IO.File]::ReadAllText($arqPresets)
    $txtPresets = $txtPresets -replace '(?m)^application/file_version=".*"$',    ('application/file_version="' + $versao4 + '"')
    $txtPresets = $txtPresets -replace '(?m)^application/product_version=".*"$', ('application/product_version="' + $versao4 + '"')
    Escrever-Texto $arqPresets $txtPresets
    Write-Host "   project.godot e export_presets.cfg atualizados."

    # ---------------------------------------------------------------- exportacao
    if (Test-Path -LiteralPath $Temp) { Remove-Item -Recurse -Force -LiteralPath $Temp }
    $dirRelease = Join-Path $Temp "release"
    $dirDebug   = Join-Path $Temp "debug"
    $staging    = Join-Path $Temp "staging"
    New-Item -ItemType Directory -Force -Path $dirRelease, $dirDebug, $staging | Out-Null

    # Duas passadas em pastas separadas: release e debug produzem os MESMOS nomes de arquivo e
    # colidiriam na mesma pasta. O console wrapper sai junto de cada uma (export_console_wrapper=2).
    Passo "Exportando (release)"
    & $Godot --headless --path $Raiz --export-release "PUG" (Join-Path $dirRelease "Auxiliar.exe")
    if ($LASTEXITCODE -ne 0) { throw "A exportacao release falhou (codigo $LASTEXITCODE)." }

    Passo "Exportando (debug)"
    & $Godot --headless --path $Raiz --export-debug "PUG" (Join-Path $dirDebug "Auxiliar.exe")
    if ($LASTEXITCODE -ne 0) { throw "A exportacao debug falhou (codigo $LASTEXITCODE)." }

    # ---------------------------------------------------------------- guarda do PCK
    # A conferencia do ZIP mais abaixo olha o LAYOUT do pacote, e nao enxerga o que o Godot embutiu
    # DENTRO de cada executavel. Com export_filter="all_resources", qualquer arquivo solto na raiz do
    # projeto vai parar no PCK — foi assim que o config_usuario.json (com usuario e token do Kinto)
    # entrou nos binarios da 1.0.0, publicada. O exclude_filter dos presets fecha isso; esta guarda
    # existe para que a regressao apareca ANTES da publicacao, e nao numa release publica.
    # Procura o NOME do arquivo, nunca o segredo: o script nao deve ler credencial nenhuma.
    Passo "Conferindo os executaveis (nada gitignorado dentro do PCK)"
    $proibidosNoPck = @("config_usuario.json", "survey_tokens.lst")
    foreach ($exe in (Get-ChildItem -Path $dirRelease, $dirDebug -Filter *.exe -File)) {
        $conteudo = [System.Text.Encoding]::GetEncoding(28591).GetString(
            [System.IO.File]::ReadAllBytes($exe.FullName))
        foreach ($proibido in $proibidosNoPck) {
            if ($conteudo.Contains($proibido)) {
                throw ("'" + $proibido + "' foi embutido no PCK de " + $exe.Name + ". " +
                       "Confira o exclude_filter em export_presets.cfg. NAO publique este build.")
            }
        }
    }
    Write-Host "   nenhum arquivo proibido embutido nos executaveis."

    # ---------------------------------------------------------------- montagem do pacote
    Passo "Montando o pacote"
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

    # arquivos/ e externo/bin/ entram pelo que o GIT rastreia, nao por copia cega da pasta. Assim
    # nada gitignorado escapa para um pacote publico — em especial
    # arquivos/limesurvey/survey_tokens.lst, que sao tokens vinculados a alunos (LGPD).
    $rastreados = & $Git -C $Raiz ls-files arquivos externo/bin
    # arquivos/oferta/ fica de fora do pacote: os dados de docentes vem da sincronizacao com o repo
    # privado do curso, em cada maquina, e o unico arquivo versionado ali (.gdignore) so serve ao
    # editor do Godot. Sem esta exclusao, a guarda de arquivo proibido abaixo barraria o proprio
    # .gdignore e a publicacao nunca passaria.
    $rastreados = $rastreados | Where-Object { -not $_.StartsWith("arquivos/oferta/") }
    foreach ($rel in $rastreados) {
        $origem  = Join-Path $Raiz $rel
        $destino = Join-Path $staging $rel
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destino) | Out-Null
        Copy-Item -LiteralPath $origem -Destination $destino -Force
    }
    Write-Host ("   " + $rastreados.Count + " arquivos versionados de arquivos/ e externo/bin/.")

    # ---------------------------------------------------------------- zip
    Passo "Compactando"
    # Os dois assemblies: ZipArchiveMode vive em System.IO.Compression, o resto em .FileSystem.
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zipFinal = Join-Path $Temp $Asset
    # As entradas sao criadas UMA A UMA com o caminho relativo montado a mao, e nao por
    # CreateFromDirectory/Compress-Archive: no .NET Framework do PowerShell 5.1 ambos gravam os
    # separadores com CONTRABARRA ("arquivos\dicas.json"). O ZIPReader do Godot leria isso como um
    # nome de arquivo unico e a atualizacao quebraria — sem erro visivel no empacotamento.
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
    Passo "Conferindo o conteudo do pacote"
    $zip = [System.IO.Compression.ZipFile]::OpenRead($zipFinal)
    $nomes = @($zip.Entries | ForEach-Object { $_.FullName })
    $zip.Dispose()

    # O separador tem de ser barra. Se alguma entrada vier com contrabarra, o ZIPReader do Godot a
    # trataria como um nome de arquivo unico e a atualizacao quebraria em silencio.
    $tortas = @($nomes | Where-Object { $_ -like "*\*" })
    if ($tortas.Count -gt 0) {
        Write-Host ($tortas -join "`n") -ForegroundColor Red
        throw "ABORTADO: ha entradas com contrabarra no ZIP."
    }

    # Vazamento so aparece DEPOIS de publicado, e uma release publica e permanente mesmo se apagada.
    # Por isso a checagem e automatica, e nao conferencia a olho.
    $proibidos = @("survey_tokens", "config_usuario.json", "dados/", "exportacoes/", ".backup",
                   "historico_professores", "lista_professores", "arquivos/oferta/")
    foreach ($p in $proibidos) {
        $achados = @($nomes | Where-Object { $_ -like "*$p*" })
        if ($achados.Count -gt 0) {
            Write-Host ($achados -join "`n") -ForegroundColor Red
            throw "ABORTADO: o pacote contem arquivo proibido ('$p'). Nada foi publicado."
        }
    }
    if ($nomes -notcontains "base_config.json") { throw "O pacote nao tem base_config.json na raiz." }
    if (@($nomes | Where-Object { $_ -match '^[^/]+\.exe$' }).Count -eq 0) {
        throw "O pacote nao tem nenhum executavel na raiz (pasta de topo indevida?)."
    }
    if (@($nomes | Where-Object { $_ -like "arquivos/*" }).Count -eq 0) {
        throw "O pacote nao tem a pasta arquivos/."
    }
    Write-Host ("   " + $nomes.Count + " entradas, layout conferido.")

    # ---------------------------------------------------------------- soma de verificacao
    Passo "Gerando a soma de verificacao"
    # Somente a string do hash: o Get-FileHash devolve um objeto, e serializa-lo inteiro faria a
    # comparacao do atualizador nunca casar.
    $hash = (Get-FileHash -LiteralPath $zipFinal -Algorithm SHA256).Hash.ToLower()
    $arqHash = "$zipFinal.sha256"
    Escrever-Texto $arqHash $hash
    Write-Host "   $hash"

    # ---------------------------------------------------------------- entrega
    $desktop = [Environment]::GetFolderPath("Desktop")
    Copy-Item -LiteralPath $zipFinal -Destination $desktop -Force
    Copy-Item -LiteralPath $arqHash  -Destination $desktop -Force
    $tamanhoMB = [math]::Round((Get-Item -LiteralPath $zipFinal).Length / 1MB, 1)
    Write-Host ""
    Write-Host "Pacote pronto: $desktop\$Asset ($tamanhoMB MB)" -ForegroundColor Green

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
    # servidor apontando para o HEAD do branch padrao remoto — que pode nao ser a arvore exportada.
    & $Git -C $Raiz push origin HEAD --follow-tags
    if ($LASTEXITCODE -ne 0) { throw "Falha no push. A tag existe localmente; nada foi publicado." }

    Passo "Criando a release"
    $argsGh = @("release", "create", $Tag, $zipFinal, $arqHash, "--title", "PUG $Versao")
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
