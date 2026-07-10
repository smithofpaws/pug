@echo off
REM ============================================================
REM  atualizar_dados_compartilhados.bat  (pug / Godot)
REM  Fica em arquivos/compartilhado/ (junto dos dados que atualiza).
REM  Atualiza os dados compartilhados de cada curso em
REM  arquivos/compartilhado/<curso>/ a partir dos repositorios
REM  canonicos (ex.: alec-data) via 'git subtree pull --squash'.
REM
REM  SENTIDO UNICO: edite sempre no repo canonico e faca push la;
REM  NUNCA edite arquivos/compartilhado/ diretamente (gera conflito
REM  no proximo pull). Duplo-clique para rodar.
REM ============================================================
setlocal EnableDelayedExpansion
REM O 'git subtree' precisa rodar na raiz do repo; este .bat esta em
REM arquivos/compartilhado/, entao subimos dois niveis (..\..).
cd /d "%~dp0..\.."

set "BRANCH=main"

REM --- Repositorios canonicos por curso (adicione novos cursos aqui) ---
set "REPO_alec=https://github.com/smithofpaws/alec-data.git"

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

set "BASE=arquivos/compartilhado"
if not exist "%BASE%" (
  echo Nada a atualizar: a pasta %BASE% nao existe.
  echo.
  pause
  exit /b 0
)

set "HOUVE_ERRO="
for /d %%C in ("%BASE%\*") do (
  set "CURSO=%%~nxC"
  set "URL=!REPO_%%~nxC!"
  if "!URL!"=="" (
    echo [PULAR] !CURSO!: sem repo definido no script ^(defina REPO_!CURSO!^).
  ) else (
    echo.
    echo === Atualizando %BASE%/!CURSO!/ a partir de !URL! ^(%BRANCH%^) ===
    git subtree pull --prefix=%BASE%/!CURSO! !URL! %BRANCH% --squash
    if errorlevel 1 (
      echo FALHA no 'git subtree pull' de !CURSO!. Veja os erros/conflitos acima.
      set "HOUVE_ERRO=1"
    )
  )
)

echo.
if defined HOUVE_ERRO (
  echo Concluido COM erros. Revise as mensagens acima antes de commitar.
) else (
  echo OK. Se houve mudancas, um commit de merge foi criado por curso.
  echo Revise e faca 'git push' quando quiser publicar.
)
echo.
pause
