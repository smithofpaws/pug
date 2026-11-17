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
- **Os portões não rodam nesta máquina.** Faltam Godot, `gdtoolkit` e `lefthook`,
  e o `.git/hooks/pre-commit` chegou pelo OneDrive **sem bit de execução**: um
  commit feito daqui passa sem verificação nenhuma e sem aviso.
- O dev decidiu rodar o PUG **direto nesta máquina, sem distrobox**, com o Godot
  já instalado em `~/Applications/Godot/` (4.7.2). Ainda faltam o `gdtoolkit` e
  o `lefthook` no host, e o plano de instalação precisa ser aprovado pelo dev
  antes.
- O pipeline e as skills citam caminhos do Windows
  (`C:/Program Files/Godot/...`). Rodar a fila no Linux exige passar aos agentes
  o caminho do Godot daqui. Ninguém testou isso.
- Continuam abertos os itens do handoff anterior: ninguém viu o atualizador
  instalar a 1.1.0 do começo ao fim, nem conferiu se o `ppc2023` lia
  `agc`/`unipampa_comunidade`.

## Estado dos portões
Não rodados nesta sessão: a máquina não tem as ferramentas. Último estado
conhecido (2026-10-03, Windows): guardrails ok · testes 137/137 · parser ok.

## Estado do git
`master`, com o commit do card 0010 enviado ao GitHub. Working tree limpo depois
dele.

## Decisões tomadas que não estão em card nenhum
- Máquina Linux: o PUG roda direto no host, com o Godot de
  `~/Applications/Godot/` (está na memória local do assistente, não no
  repositório). O AGENTS.md precisa de uma seção "Linux": caminho do Godot,
  instalação do gdtoolkit/lefthook e o hook sem `+x` vindo do OneDrive.

## Próximo passo concreto
Aprovar o plano de instalação do `gdtoolkit` e do `lefthook` no host, dar
`chmod +x` no hook e fazer o teste de recusa do pre-commit. Depois rodar os três
portões com o Godot de `~/Applications/Godot/`, e só então a fila com o card
0010.

## Em aberto para o dev
- Como instalar o `gdtoolkit` e o `lefthook` no CachyOS (proposta pendente).
