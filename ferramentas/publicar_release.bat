@echo off
REM Atalho de duplo clique para publicar_release.ps1.
REM
REM O Windows nao executa arquivos .ps1 com duplo clique -- o Explorer os abre no editor de texto,
REM de proposito, para ninguem rodar um script por engano. Este .bat chama o script pelo PowerShell
REM com a politica de execucao liberada apenas para esta chamada.
REM
REM Sem acentos de proposito: o console do Windows usa outra codepage e eles apareceriam corrompidos.

setlocal
set "AQUI=%~dp0"

echo ==========================================================
echo   PUG - Publicacao de release
echo ==========================================================

REM O proprio script mostra a versao atual, a ultima tag publicada e as sugestoes de numeracao
REM (-Info nao exporta nada). A leitura fica no PowerShell, e nao aqui, para nao repetir em duas
REM linguagens a mesma logica de descobrir a versao.
powershell -NoProfile -ExecutionPolicy Bypass -File "%AQUI%publicar_release.ps1" -Info

echo.
set "VERSAO="
set /p VERSAO="Numero da NOVA versao (formato X.Y.Z): "
if "%VERSAO%"=="" (
    echo.
    echo Nenhuma versao informada. Cancelado.
    goto :fim
)

echo.
echo   A = x64 e ARM64 ^(padrao^)
echo   X = so x64 ^(use se os modelos de exportacao ARM64 nao estiverem instalados^)
echo.
choice /C AX /M "Arquiteturas"

set "EXTRA="
if errorlevel 2 set "EXTRA=-SemArm"

echo.
echo   S = publica no GitHub ^(cria a tag e envia a release^)
echo   N = so prepara os pacotes na Area de Trabalho, sem tocar no GitHub
echo.
choice /C SN /M "O que fazer"

if errorlevel 2 (
    echo.
    echo Preparando os pacotes ^(nada sera enviado ao GitHub^)...
    echo.
    powershell -NoProfile -ExecutionPolicy Bypass -File "%AQUI%publicar_release.ps1" -Versao %VERSAO% %EXTRA%
) else (
    echo.
    echo Publicando a versao %VERSAO% no GitHub...
    echo.
    powershell -NoProfile -ExecutionPolicy Bypass -File "%AQUI%publicar_release.ps1" -Versao %VERSAO% %EXTRA% -Publicar
)

:fim
echo.
pause
endlocal
