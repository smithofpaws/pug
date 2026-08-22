# Handoff — 2026-08-22 13:30

## Onde parei
Três cards entregues pela fila hoje. Os cards 0001 e 0002 já estão mesclados em
`master` e pushados; o card 0003 está entregue na branch `cards/2026-08-22`
(commits `1ea5c49` card + `0d100dd` entrega), **ainda não mesclada em `master`**
nesta segunda leva. O pipeline rodou de ponta a ponta três vezes sem falha.

## Card ativo
Nenhum. 0001, 0002 e 0003 estão `done`; não há card `ready`/`todo` no índice.

## Feito nesta sessão
- Fila da manhã: cards 0001 (ordem canônica na grade de horários) e 0002
  (mesclagem de respostas do ajuste) — entregues, mesclados em `master`,
  pushados.
- `2152fb5` (em `master`): regra LGPD refinada por decisão do dev — dado de
  aluno segue todo protegido (inclusive nome); de docente, o nome sozinho não é
  sensível, dados além do nome sim. `AGENTS.md` + `Cards/README.md`.
- Card 0003 (na branch): rótulo de opção do Forms com vírgulas era estilhaçado
  em entradas fantasma ("T40;60;80", nome de professor) exibidas como "código
  inválido/ausente". `_separar_entradas` agora re-anexa fragmento sem código à
  entrada anterior da célula. 8 testes novos (34/34 na suíte), review limpo em
  1 rodada, 2 findings não-bloqueantes já aplicados (mensagem de asserção
  corrigida; limitação multi-código registrada na spec e no `IDEAS.md`).

## Pela metade / não verificado
- **AC4 (`manual`) do card 0001 segue aberto**: conferir no modo ajuste que a
  pedida de inclusão (fundo verde) vem primeiro na célula. Roteiro em
  `Cards/0001-ordem-prioridade-grade-horarios/smoke/smoke.md`. Só o dev fecha.
- 0002 e 0003 nunca foram observados com um CSV real do Forms — a validação de
  campo é o próximo uso real do Modo Ajuste.
- Limitação nova registrada (item no `IDEAS.md`, "A IMPLEMENTAR"): texto
  re-anexado a menção multi-código é descartado do retorno (causa em
  `_mesclar_lado`/0002) — candidato a card futuro.
- Merge de `cards/2026-08-22` (0003) em `master` pendente de palavra do dev
  (seria fast-forward).

## Estado dos portões
guardrails: ok (0 acima da baseline de 375) · testes: ok (34/34, 3 scripts) ·
parser: ok — pipeline do 0003 + pre-commit do Lefthook, em 2026-08-22.

## Estado do git
Branch `cards/2026-08-22`, working tree limpo, 3 commits à frente de `master`
(card 0003 + entrega + este handoff), branch pushada. `master` local =
`origin/master` (contém 0001, 0002 e a regra LGPD).

## Decisões tomadas que não estão em card nenhum
- Regra LGPD sobre nome de docente: já migrada para o `AGENTS.md` (`2152fb5`).
- Trade-off do 0003 (texto livre após vírgula em menção válida não alerta
  mais): documentado na spec do card, no MANUAL e travado em teste.

## Próximo passo concreto
Mesclar `cards/2026-08-22` em `master` e pushar (aguardando o dev); depois,
dev executa o roteiro do AC4 do 0001 e registra no `card.md`.

## Em aberto para o dev
- Merge do 0003 em `master` agora?
- AC4 do 0001: rodar o roteiro manual.
- O item novo do `IDEAS.md` (texto descartado no caminho multi-código) merece
  virar card já, ou espera aparecer na prática?
