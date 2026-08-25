# Handoff — 2026-08-22 19:11

## Onde parei
Quarto card do dia entregue pela fila. `master` contém os cards 0001–0003, a
regra LGPD refinada e o fechamento do AC4 do 0001 (relato do dev). O card 0004
está entregue na branch `cards/2026-08-22` (commits `9e85227` card + `6eb0a27`
entrega), branch pushada, **ainda não mesclada em `master`**.

## Card ativo
Nenhum `ready`/`in_progress`. 0001–0004 estão `done` — mas veja o AC5 do 0004
abaixo.

## Feito nesta sessão (após o handoff das 13:30)
- Card 0003 mesclado em `master` e pushado; AC4 do 0001 fechado por relato do
  dev (`3b2c01d`).
- Investigação do bug `calculo_carga_horaria.gd:13` (a pedido do dev):
  4 defeitos concretos identificados e relatados — (1) reprovações/trancamentos
  contam como CH vencida (filtro é "não-matr" em vez de aprovado/dispensado);
  (2) sem teto por núcleo e sem conferência de chaves estcurricular×exigida;
  (3) denominador ajustado por ignorahora, numerador não; (4) equivalências não
  expandem. Itens 1 e 3 corrigíveis sem regra de negócio; 2 depende da fórmula
  oficial da Unipampa; 4 tem a mesma raiz do card 0004. **Ainda não virou card.**
- Card 0004 (branch): `AnaliseGrades.concluidas_por_equivalencia` (pura, grupo
  completo CONCLUÍDO — mais estrita que a hachura, de propósito) +
  `_cursadas_com_equivalencia` nos 2 call sites da grade da Situação Alunos.
  7 testes novos (41/41), review limpo em 1 rodada, MANUAL.md atualizado.

## Pela metade / não verificado
- **AC5 (`manual`) do 0004 é o item crítico**: o review registrou que reverter
  só a fiação do módulo mantém os 41 testes verdes — o roteiro manual
  (`Cards/0004-cor-concluida-por-equivalencia/smoke/smoke.md`, 5 passos +
  contraprova) é a ÚNICA prova de que a cor chega à tela. Card marcado `done`
  pela regra da fila, mas o bug só está provado corrigido após o relato do dev.
- Bug do `calculo_carga_horaria` investigado mas sem card — aguarda o dev
  decidir escopo (sugestão: card só para os itens 1 e 3, headless).
- Ideia nova no `IDEAS.md`: origem da equivalência na célula (tooltip) — fora
  do 0004 por decisão de escopo.

## Estado dos portões
guardrails: ok (0 acima da baseline) · testes: ok (41/41, 4 scripts) ·
parser: ok — pipeline do 0004 + pre-commit, em 2026-08-22.

## Estado do git
Branch `cards/2026-08-22`, working tree limpo, pushada; 2 commits à frente de
`master` (+ este handoff). Merge em `master` aguarda o dev (fast-forward).

## Decisões tomadas que não estão em card nenhum
- Critério da expansão de equivalência para COR exige fontes concluídas
  (presença = cursadas), mais estrito que o da hachura (presença = histórico
  inteiro) — documentado na docstring de `concluidas_por_equivalencia` e na
  spec do 0004.

## Próximo passo concreto
Dev roda o roteiro do AC5 do 0004 (aluno com disciplina cursada sob código de
outra grade → célula dourada) e registra no `card.md`; merge de
`cards/2026-08-22` em `master` quando ele mandar.

## Em aberto para o dev
- AC5 do 0004 (a prova real do bug corrigido).
- Merge em `master` agora?
- O bug do `calculo_carga_horaria` vira card já (itens 1 e 3) ou espera a
  fórmula oficial para fazer tudo junto?
