@echo off
REM Atalho de duplo clique para sincronizar_dados_curso.ps1.
REM
REM O Windows nao executa arquivos .ps1 com duplo clique -- o Explorer os abre no editor de texto.
REM Este .bat chama o script pelo PowerShell com a politica de execucao liberada so para esta chamada.
REM
REM Sem acentos de proposito: o console do Windows usa outra codepage.

setlocal
set "AQUI=%~dp0"

echo ==========================================================
echo   PUG - Sincronizar dados de curso
echo ==========================================================
echo.
echo Traz grades, cargas, equivalencias e a pasta oferta/ dos
echo repositorios canonicos de cada curso (alec-data e afins).
echo.
echo Requer 'gh auth login' feito nesta maquina.
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%AQUI%sincronizar_dados_curso.ps1"

echo.
pause
endlocal
