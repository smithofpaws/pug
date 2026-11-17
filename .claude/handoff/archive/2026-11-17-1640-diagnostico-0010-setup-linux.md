# Handoff — 2026-11-17 (tarde)

## Onde parei
O defeito "o `horarios.txt` novo não importa" foi diagnosticado e virou o card
**0010**, aprovado pelo dev e com status `ready`. Nenhum código foi escrito. A
fila não foi disparada. Esta sessão foi feita na **máquina Linux (CachyOS)**, que
ainda não tem ambiente para os portões.

## Card ativo
0010-conversao-cp1252-nativa, status `ready` (ainda não executado).

## Feito nesta sessão (2026-11-17)
- **Diagnóstico, pelo log do Godot no Linux** (`user://logs/`):
  - O programa de horários da universidade mudou o formato: coluna 0 vazia,
    `tipo`/`sala` = `EaD`, turma `T100`. O arquivo vem em Windows-1252.
  - **Não foi isso que quebrou.** O `convertto_utf8` chama o
    `externo/bin/ansi_to_utf8.exe`, que no Linux falha com `Permission denied`.
  - O verificador imprime `Arquivo convertido!` mesmo assim. O arquivo novo nunca
    chega em `dados/saida/`, e o programa segue com o `horarios.txt` de
    2026-08-04.
  - Os `Unicode parsing error` (1574 por importação, um por byte acentuado) vêm
    da própria detecção (`_precisa_conversao_utf8` usa `get_string_from_utf8()`).
    Esse ruído também acontece no Windows.
- Card 0010 escrito e aprovado ("Aprovar como está"). O escopo cobre os 7 pontos
  que chamam `convertto_utf8`; o `.exe` e a fonte em `externo/src/ansi_to_utf/`
  saem do git.
- `IDEAS.md` (GERAL › A IMPLEMENTAR): três itens sobre o Linux, a pedido do dev
  (`xlsx_to_csv.exe`, `typst.exe`, atualizador).
- Handoff anterior arquivado em
  `archive/2026-10-03-0905-release-v1-1-0.md`.
- Tudo isso commitado num commit só ("Card 0010...") e enviado ao GitHub.

## Pela metade / não verificado
- **Ninguém confirmou que o mesmo arquivo funciona no Windows.** É a suposição
  do diagnóstico, e por isso existe o AC 12 (manual).
- Não foi confirmado se o `horarios.txt` antigo da universidade também vinha em
  Windows-1252. É provável: é nessa codificação que o próprio Auxiliar grava o
  arquivo que exporta para o programa de horários. A cópia em `dados/saida/` já
  estava convertida.
- **Setup do Linux feito (host, sem distrobox, sem sudo; Opção A aprovada pelo
  dev):**
  - `~/.local/bin/godot`: wrapper que roda o `Godot-4.7.*` mais novo de
    `~/Applications/Godot/sistema/app/`.
  - `gdtoolkit` 4.5.0 e pip 26.3 em `~/.local`, instalados pelo wheel embutido
    do `ensurepip` com `--break-system-packages`. O `ensurepip --user` direto
    é recusado pelo PEP 668.
  - `lefthook` 2.2.2 em `~/.local/bin`, com o SHA-256 conferido contra a release.
  - `lefthook install` e **teste de recusa ok** (`EXIT=1`, `[static-typing]`).
    Parser do Godot `EXIT=0`, testes 137/137.
- **O arquivo descartável do teste de recusa,
  `standalone_scripts/_teste_recusa.gd`, ainda pode existir** (untracked). O
  `rm` foi negado ao assistente; o dev precisa apagar. Até lá, o guardrails
  completo acusa esse arquivo.
- **O `.git/hooks/pre-commit` agora é a versão Linux** (procura `lefthook` e
  `/home/diego/.local/bin/lefthook`; antes procurava `lefthook.exe`/WinGet). O
  OneDrive replica esse arquivo para os PCs Windows. Lá o Git Bash deve achar o
  `lefthook.exe` pelo PATH, mas **refaça o teste de recusa em cada PC Windows**
  (ou rode `lefthook install` lá, o que devolve a versão Windows ao Linux).
- O pipeline (`godot-feature-pipeline.js`, linhas 174 e 234) e as skills
  `godot-gdscript-dev`, `godot-smoke-test` e `godot-session-setup` citam
  `C:/Program Files/Godot/Godot_console.exe`. Rodar a fila no Linux exige
  ajustar isso.
- Continuam abertos os itens do handoff anterior: ninguém viu o atualizador
  instalar a 1.1.0 do começo ao fim, nem conferiu se o `ppc2023` lia
  `agc`/`unipampa_comunidade`.

## Estado dos portões
Linux, 2026-11-17: testes 137/137 · parser ok · guardrails acusou só o arquivo
do teste de recusa (o guardrails completo, com ele apagado, **não foi rodado**).

## Estado do git
`master`, com o commit do card 0010 enviado ao GitHub. Working tree limpo depois
dele.

## Decisões tomadas que não estão em card nenhum
- O setup do Linux e o "hook é por máquina, mas o OneDrive compartilha" já foram
  migrados para o AGENTS.md (Setup por máquina). O pipeline e as skills agora
  listam o comando do parser para Windows e para Linux.

## Próximo passo concreto
Apagar `standalone_scripts/_teste_recusa.gd`, rodar
`python .tools/guardrails.py` (precisa sair 0), ajustar o caminho do Godot no
pipeline para funcionar também no Linux e rodar a fila com o card 0010.

## Em aberto para o dev
- Apagar `standalone_scripts/_teste_recusa.gd` e o `.uid` dele (o `rm` é negado
  ao assistente).
- Refazer o teste de recusa nos PCs Windows (o hook agora é a versão Linux).
