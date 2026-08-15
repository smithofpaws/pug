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
echo.

set "VERSAO="
set /p VERSAO="Numero da versao (formato X.Y.Z, ex.: 1.0.0): "
if "%VERSAO%"=="" (
    echo.
    echo Nenhuma versao informada. Cancelado.
    goto :fim
)

echo.
echo   S = publica no GitHub ^(cria a tag e envia a release^)
echo   N = so prepara o pacote na Area de Trabalho, sem tocar no GitHub
echo.
choice /C SN /M "O que fazer"

if errorlevel 2 (
    echo.
    echo Preparando o pacote ^(nada sera enviado ao GitHub^)...
    echo.
    powershell -NoProfile -ExecutionPolicy Bypass -File "%AQUI%publicar_release.ps1" -Versao %VERSAO%
) else (
    echo.
    echo Publicando a versao %VERSAO% no GitHub...
    echo.
    powershell -NoProfile -ExecutionPolicy Bypass -File "%AQUI%publicar_release.ps1" -Versao %VERSAO% -Publicar
)

:fim
echo.
pause
endlocal
