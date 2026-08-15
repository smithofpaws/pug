<#
.SYNOPSIS
    Traz os dados de curso dos repositorios canonicos (alec-data e afins) para arquivos/.

.DESCRIPTION
    Substitui o antigo atualizar_dados_compartilhados.bat, que usava `git subtree`.

    Por que nao subtree: ele mapeia UM repositorio para UMA pasta e traz a arvore inteira. Com os
    dados achatados em arquivos/<tipo>/, dois cursos (alec-data e um futuro alem-data) seriam donos
    da mesma pasta, e um pull apagaria ou conflitaria com o que veio do outro. Alem disso o subtree
    committa tudo no consumidor -- foi assim que dados de docentes acabaram expostos no pug publico.

    Aqui a sincronizacao e POR ARQUIVO, guiada pela convencao <cod_curso>_<versao>: cada repositorio
    manda apenas nos arquivos com o seu prefixo. O que nao casa com nenhum prefixo registrado e
    local do pug e nunca e tocado.

    SENTIDO UNICO: edite sempre no repositorio canonico e faca push la. As copias em arquivos/ sao
    sobrescritas a cada execucao.

    Observacao sobre acentos: corpo em ASCII puro de proposito (o PowerShell 5.1 le .ps1 sem BOM na
    codepage ANSI).

.PARAMETER Curso
    Sincroniza apenas o curso informado (ex.: alec). Sem isso, sincroniza todos os registrados.

.EXAMPLE
    .\ferramentas\sincronizar_dados_curso.ps1
    .\ferramentas\sincronizar_dados_curso.ps1 -Curso alec
#>
param(
    [string]$Curso = ""
)

$ErrorActionPreference = "Stop"

$Raiz = Split-Path -Parent $PSScriptRoot

# Repositorios canonicos por curso. Para acrescentar um curso, basta uma linha aqui.
$Repos = [ordered]@{
    "alec" = "smithofpaws/alec-data"
}

# Pastas curriculares: sincronizadas com FILTRO por prefixo do curso, para que o repositorio de um
# curso jamais sobrescreva arquivo de outro. As equivalencias entre cursos (alcc_0000-alec_2023 e
# afins) nao comecam com "<curso>_" e por isso nunca sao tocadas -- pertencem a dois cursos.
$PastasCurriculares = @("grades", "cargaexigida", "equivalencias")

# Pastas trazidas INTEIRAS (sem filtro). arquivos/oferta/ e gitignorada no pug: contem dados
# nominais de docentes e so existe na maquina de quem sincroniza.
$PastasIntegrais = @("oferta")

function Passo($mensagem) {
    Write-Host ""
    Write-Host ">> $mensagem" -ForegroundColor Cyan
}

$temp = Join-Path $env:TEMP "pug_sync_dados"

try {
    # O gh e usado (em vez de git clone puro) porque os repositorios de curso sao PRIVADOS e o gh ja
    # esta autenticado por maquina -- assim nenhum token precisa ser guardado no projeto.
    Passo "Conferindo autenticacao do GitHub CLI"
    & gh auth status 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw ("Nao autenticado no GitHub CLI. Rode 'gh auth login' nesta maquina e tente de novo. " +
               "Os repositorios de dados sao privados e sem isso nada pode ser baixado.")
    }
    Write-Host "   ok."

    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $temp | Out-Null

    $alvos = $Repos.Keys
    if ($Curso -ne "") {
        if (-not $Repos.Contains($Curso)) {
            throw "Curso '$Curso' nao tem repositorio registrado. Conhecidos: $($Repos.Keys -join ', ')."
        }
        $alvos = @($Curso)
    }

    $totalCopiados = 0

    foreach ($cod in $alvos) {
        $repo = $Repos[$cod]
        Passo "Curso '$cod' <- $repo"

        $clone = Join-Path $temp $cod
        & gh repo clone $repo $clone -- --depth 1 --quiet 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $clone)) {
            throw "Falha ao clonar $repo. Voce tem acesso a esse repositorio privado?"
        }

        # --- pastas curriculares, filtrando pelo prefixo do curso ---
        foreach ($pasta in $PastasCurriculares) {
            $origem = Join-Path $clone $pasta
            if (-not (Test-Path -LiteralPath $origem)) { continue }
            $destino = Join-Path $Raiz "arquivos\$pasta"
            New-Item -ItemType Directory -Force -Path $destino | Out-Null

            $arquivos = @(Get-ChildItem -LiteralPath $origem -File -Filter "*.json" |
                          Where-Object { $_.Name.StartsWith("${cod}_") })
            foreach ($a in $arquivos) {
                Copy-Item -LiteralPath $a.FullName -Destination (Join-Path $destino $a.Name) -Force
                $totalCopiados++
            }

            # Avisa sobre o que o repositorio traz mas nao lhe pertence: sintoma de arquivo no repo
            # errado, que silenciosamente nunca seria sincronizado.
            $alheios = @(Get-ChildItem -LiteralPath $origem -File -Filter "*.json" |
                         Where-Object { -not $_.Name.StartsWith("${cod}_") })
            if ($alheios.Count -gt 0) {
                Write-Host ("   [aviso] $pasta/: " + $alheios.Count +
                            " arquivo(s) sem o prefixo '${cod}_' foram IGNORADOS: " +
                            (($alheios | ForEach-Object { $_.Name }) -join ", ")) -ForegroundColor Yellow
            }
            Write-Host ("   $pasta/: " + $arquivos.Count + " arquivo(s)")
        }

        # --- pastas integrais (oferta/) ---
        foreach ($pasta in $PastasIntegrais) {
            $origem = Join-Path $clone $pasta
            if (-not (Test-Path -LiteralPath $origem)) {
                Write-Host "   $pasta/: ausente no repositorio, nada a fazer." -ForegroundColor Yellow
                continue
            }
            $destino = Join-Path $Raiz "arquivos\$pasta"
            New-Item -ItemType Directory -Force -Path $destino | Out-Null
            $arquivos = @(Get-ChildItem -LiteralPath $origem -File -Force)
            foreach ($a in $arquivos) {
                Copy-Item -LiteralPath $a.FullName -Destination (Join-Path $destino $a.Name) -Force
                $totalCopiados++
            }
            Write-Host ("   $pasta/: " + $arquivos.Count + " arquivo(s) (pasta gitignorada no pug)")
        }
    }

    Write-Host ""
    Write-Host "Sincronizacao concluida: $totalCopiados arquivo(s)." -ForegroundColor Green
    Write-Host "Lembre-se: edite sempre no repositorio canonico; o que esta em arquivos/ e copia."

    # Rede de seguranca: nada de oferta/ pode ter entrado no indice do git.
    $vazando = & "C:\Program Files\Git\cmd\git.exe" -C $Raiz ls-files "arquivos/oferta" |
               Where-Object { $_ -ne "arquivos/oferta/.gdignore" }
    if ($vazando) {
        Write-Host ""
        Write-Host "ATENCAO: ha arquivos de oferta/ versionados no git:" -ForegroundColor Red
        Write-Host ($vazando -join "`n") -ForegroundColor Red
        Write-Host "Eles contem dados pessoais e o repositorio e publico. Remova com 'git rm --cached'."
    }
}
catch {
    Write-Host ""
    Write-Host ("ERRO: " + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
finally {
    if (Test-Path -LiteralPath $temp) {
        Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
    }
}
