# Handoff — 2026-08-25

## Onde parei
Sessão de faxina, sem código de produção. O `IDEAS.md` foi limpo (itens já
entregues removidos, referências frágeis corrigidas) e o handoff anterior — que
estava desatualizado em dois pontos — foi arquivado. Nenhum card aberto.

## Card ativo
Nenhum. Os cards 0001–0004 estão `done`, com todos os ACs marcados (o AC5
`manual` do 0004 fechou por relato do dev em `75dc761`).

## Feito nesta sessão
Tudo commitado (ver "Estado do git"):

- **Correção do handoff anterior.** Ele dizia que o card 0004 estava numa branch
  não mesclada e que o AC5 seguia sem prova. Ambos já tinham acontecido — o
  repositório mostrava `6eb0a27` e `75dc761` em `master`. Arquivado em
  `archive/2026-08-22-1911-card-0004.md`.
- **Limpeza do `IDEAS.md`.** Verifiquei item a item contra o código, não só pelas
  caixas marcadas:
  - Removidos os dois `[x]` (fan-out do GURI; hachura de distantes). O
    conhecimento deles sobrevive fora do backlog — `file_handling.gd:221` e
    `MANUAL.md:150` —, por isso a remoção não perde nada.
  - Removido o duplicado de CH mínima para bolsa, que aparecia em Situação
    Alunos e em "Novos Módulos Sugeridos"; ficou só o primeiro.
  - "Modo Ajuste de Matrícula" **não** foi removido: metade estava construída.
    O download da planilha do Google por URL existe (`PlanilhaAjuste.baixar`);
    a importação de um `.csv` do disco nunca foi feita. A linha foi reescrita
    para só essa metade.
  - Referências por número de linha trocadas por nome de função/chave onde
    tinham envelhecido (`situacao_alunos.gd:257-260` → `386-388`;
    `calculo_carga_horaria.gd:13` → `CalculoCargaHoraria.percentagem_curso`;
    `base_config.json:48` → `modulos.trancamento`).
  - Os 4 defeitos do cálculo de CH (investigados na sessão de 22/08) migraram do
    handoff para o `IDEAS.md`, que é o lugar de backlog — handoff é estado.
- **Branch `cards/2026-08-22` apagada** (local e no `origin`), já mesclada em
  `master`.

## Pela metade / não verificado
- **O bug de `CalculoCargaHoraria.percentagem_curso` continua sem card.** Está
  descrito no `IDEAS.md` com os 4 defeitos, mas descrever não é corrigir: o
  percentual de conclusão que o programa mostra hoje está errado. Itens 1 e 3
  são corrigíveis sem regra de negócio nova; o 2 depende da fórmula oficial da
  Unipampa; o 4 tem a mesma raiz do card 0004.
- **`alec_2023.json` sem Arquitetura (`al0171`) como pré-requisito de
  Instalações Elétricas Prediais (`al0081`)** — o dev confirmou nesta sessão que
  é erro de dado, não conferência já resolvida. Conferi que `al0081` tem só
  `prerequisito0: al0006`, e que isso vale para `alec_2010` também (ou seja: a
  2010 pode ter o mesmo problema, não verifiquei se lá é esperado). A correção é
  no repositório canônico `alec-data`, não em `arquivos/`.
- Não reli o `IDEAS.md` procurando itens implementados **fora** das seções que
  inspecionei em profundidade (GERAL, Situação Alunos, Trancamentos). Os itens
  de Situação Disciplinas, Calculador de CR e Planejamento de Horário foram
  lidos, mas não conferidos contra o código um a um.

## Estado dos portões
**Não rodados nesta sessão** — só houve edição de `.md`, nenhum `.gd` tocado. O
último verde é de 2026-08-22: guardrails ok (0 acima da baseline), testes ok
(41/41, 4 scripts), parser ok.

## Estado do git
Branch `master`, working tree limpo, sincronizada com `origin/master`. Dois
commits novos (limpeza do `IDEAS.md`; handoff). **Push ainda não feito** — o dev
decide.

## Decisões tomadas que não estão em card nenhum
- Item de backlog só sai do `IDEAS.md` quando o comportamento existe **inteiro**
  no código; escopo entregue pela metade é reescrito para a metade que falta, não
  apagado. Foi o que salvou a linha do Modo Ajuste. Se virar hábito, vale subir
  para o `AGENTS.md`.

## Próximo passo concreto
Entrevistar o bug de `CalculoCargaHoraria.percentagem_curso` (itens 1 e 3) e
escrever o card — é headless, cai inteiro em `standalone_scripts/analise/`, e é o
único defeito conhecido que ainda afeta um número mostrado ao coordenador.

## Em aberto para o dev
- Push destes dois commits agora?
- O card do cálculo de CH sai só com os itens 1 e 3, ou espera a fórmula oficial
  da Unipampa para fazer os quatro de uma vez?
- A falta de `al0171` em `al0081` vale também para a grade `alec_2010`, ou lá o
  pré-requisito realmente não existe?
