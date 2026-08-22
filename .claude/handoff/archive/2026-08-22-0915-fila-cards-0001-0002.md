# Handoff — 2026-08-22 09:15

## Onde parei
A fila automática rodou pela primeira vez e entregou os cards 0001 e 0002 na
branch `cards/2026-08-22` (4 commits). O pipeline
(`godot-feature-pipeline.js`) funcionou de ponta a ponta nas duas execuções —
o piloto passou. A branch ainda **não foi mesclada em `master`**.

## Card ativo
Nenhum. 0001 e 0002 estão `done`; não há card `ready` nem `todo` no índice.

## Feito nesta sessão
Tudo commitado na branch `cards/2026-08-22`:
- `1dcbc4a` / `beb9bb1` — cards 0001 e 0002 registrados (entrevistados numa
  sessão anterior, estavam sem commit no working tree).
- `fd50092` — **Card 0001**: `AnaliseHorarios.ordenar_condicoes` (ordem
  canônica ajuste → base_config → desconhecidas), efeito colateral de poda no
  array do chamador removido, 8 testes novos, MANUAL.md atualizado.
- `0270e15` — **Card 0002**: `PlanilhaAjuste.parse()` mescla respostas
  múltiplas (união; conflito = menção mais recente; mesma resposta = exclusão
  prevalece), regex de código com `\b`, 13 testes novos + fixture fictícia,
  MANUAL.md atualizado.
- Handoff atualizado (este arquivo).

## Pela metade / não verificado
- **AC4 (`manual`) do card 0001 está aberto**: conferir que, no modo ajuste, a
  pedida de inclusão (fundo verde) vem primeiro na célula. Roteiro em
  `Cards/0001-ordem-prioridade-grade-horarios/smoke/smoke.md`. Só o dev fecha,
  com dados fictícios. A caixa do AC4 no card segue desmarcada de propósito.
- O comportamento do 0002 nunca foi observado com um CSV real do Forms — os 26
  testes usam fixtures. O primeiro uso real do Modo Ajuste é a validação de
  campo.
- Finding residual **não-bloqueante** do 0002: token curto isolado antes de
  número ("Lab 101", "em 2026") ainda vira candidato de código. Documentado no
  comentário do regex e travado por 2 testes como limitação aceita; estreitar
  mais é decisão futura do dev (validação contra grade é non-goal do card).
- Nenhum smoke com PNG foi exercitado ainda (os dois cards não tinham cenário
  visual). O caminho `--write-movie` do smoke segue não testado neste projeto.

## Estado dos portões
guardrails: ok (0 acima da baseline de 375) · testes: ok (26/26, 3 scripts) ·
parser: ok — rodados pelo pipeline do 0002 e re-rodados pelo pre-commit do
Lefthook em cada commit, em 2026-08-22.

## Estado do git
Branch `cards/2026-08-22`, working tree limpo, 4 commits à frente de `master`
(+ o commit deste handoff). `master` local = `origin/master`. Merge em
`master` é decisão do dev (seria fast-forward).

## Decisões tomadas que não estão em card nenhum
- Menção multi-código no 0002 emite **o código puro** por decisão, não a
  entrada inteira (evita o módulo re-extrair sempre o primeiro candidato) —
  registrada no comentário de `_mesclar_lado` e na spec do card, não precisa
  migrar para o AGENTS.md.

## Próximo passo concreto
Dev executa o roteiro do AC4 do 0001 (`smoke/smoke.md`) com dados fictícios e
registra o resultado no `card.md`; depois decide o merge de
`cards/2026-08-22` em `master` e o push de `master`.

## Em aberto para o dev
- AC4 do 0001: confere e marca a caixa (ou reporta falha — aí vira reabertura).
- Mesclar `cards/2026-08-22` em `master` agora ou deixar a branch maturar?
- O residual do regex do 0002 incomoda o suficiente para virar ideia no
  `IDEAS.md`?
