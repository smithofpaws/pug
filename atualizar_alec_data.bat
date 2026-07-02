@echo off
REM ============================================================
REM  atualizar_alec_data.bat  (pug / Godot)
REM  Atualiza arquivos/grades_shared/alec_2023.json a partir do
REM  repositorio canonico alec-data via 'git subtree pull'.
REM  Duplo-clique.
REM ============================================================
setlocal
cd /d "%~dp0"

set "REPO=https://github.com/smithofpaws/alec-data.git"
set "PREFIX=arquivos/grades_shared"
set "BRANCH=main"

echo.
echo Atualizando %PREFIX%/ a partir de %REPO% (%BRANCH%) ...
echo.

REM subtree pull exige arvore de trabalho limpa (sem alteracoes rastreadas pendentes)
git diff --quiet HEAD
if errorlevel 1 (
  echo ERRO: ha alteracoes nao commitadas neste repositorio.
  echo Faca commit ou stash antes de atualizar o subtree.
  echo.
  git status --short
  echo.
  pause
  exit /b 1
)

git subtree pull --prefix=%PREFIX% %REPO% %BRANCH% --squash
if errorlevel 1 (
  echo.
  echo FALHA no 'git subtree pull'. Veja os erros/conflitos acima.
  pause
  exit /b 1
)

echo.
echo OK. Se houve mudancas, um commit de merge foi criado.
echo Revise e faca 'git push' quando quiser publicar.
echo.
pause
