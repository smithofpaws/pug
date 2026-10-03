# Handoff — 2026-10-02 17:09

## Onde parei
A fila rodou os quatro cards `ready` (0005, 0007, 0008, 0009) na branch
**`cards/2026-10-02`**, todos commitados, nenhum pushado, a branch **não**
mesclada na `master`. Três cards esperam ACs `manual` do dev.

## Card ativo
Nenhum em execução. Estado de cada um:

| Card | Status | ACs pendentes (manual) | Commit |
|---|---|---|---|
| 0005 | `done` | nenhum | `c0f3c38` |
| 0007 | `in_progress` | 13-16 (diálogo com AL0037/AL2126/AL2129; não reabre ao trocar de aluno; sem horarios.txt; manual 4.3) | `902bc1e` |
| 0008 | `in_progress` | 12-13 (14 nomes da lista com filtro Eng. Civil; dica e manual) | `da91b3d` |
| 0009 | `in_progress` | 9-16 (Ctrl+F, teclado, rolagem, cópia, tema, dicas, manual 3.2) | `d9db515` |

Roteiros manuais: `Cards/<id>/spec.md` (R1...). Cada AC `manual` fecha por relato
do dev, um a um.

## Feito nesta sessão
- `262362f` AGENTS.md "Setup por máquina"; `8644e45`, `f236e98`, `fd2d2f8` cards
  0007, 0008 e 0009 (na `master`, não pushados).
- Fila na branch `cards/2026-10-02`: os 4 commits da tabela acima.
- Suíte: 52 → 137 testes.

## Pela metade / não verificado
- **ACs manuais** dos cards 0007, 0008 e 0009 (tabela acima). Nada visual foi
  visto por ninguém ainda.
- **O guardrails aprova arquivo que o gdtoolkit não consegue ler.** Quando o
  parser do gdtoolkit falha, o `run_gdlint` não acha linhas `arquivo:linha:
  Error:` e conta zero violações — o arquivo inteiro fica fora do lint e das
  regras do projeto, em silêncio. Aconteceu no 0007 (`analise_horarios.gd`, já
  corrigido). **Não corrigido no guardrails.**
- **`scenes/Modulos/SituacaoDisciplinas/situacao_disciplinas.gd` está ilegível
  para o gdtoolkit desde `219131f`** (linha 270, string). Está sem lint desde
  então. Não mexido.
- **Defeito de escrita dos agentes neste ambiente:** barra invertida dupla em
  comando/edição chega como barra simples. Efeitos vistos: `"\n"` virando
  quebra de linha real dentro de string (0007), continuação de linha (barra +
  quebra) virando tabs no meio da linha (0007, 0008), `\n` literal quebrando o
  parse do `planejamentooferta.gd` (0008, pego pelo review). O orquestrador
  conferiu, depois de cada card: gdlint lê cada `.gd` tocado, sem tabs no meio de
  linha, sem string aberta no fim da linha.
- **Workflow com raiz fixa de outra máquina:** `godot-feature-pipeline.js` tem
  `ROOT` padrão `O:/OneDrive/...`, que não existe na `apex`. Rodou com
  `args.root` explícito. Não corrigido.
- **Teste de recusa do pre-commit na `apex`: não rodado** (o dev negou). Os
  commits da fila mostraram o pre-commit rodando guardrails + testes de verdade,
  o que é indício, não a prova de recusa.
- **0005 diverge do card em dois pontos** (decididos na spec, não pelo dev):
  reporta 8 pré-requisitos inexistentes, não só o `al5022` da 2023; e **não**
  detecta `agc` × `acg`. O teste do AC12 compara com os dados reais: corrigir um
  desses defeitos no alec-data e sincronizar reprova a suíte até atualizar o
  `SNAPSHOT` em `test/unit/test_validacao_curricular.gd`.

## Estado dos portões
guardrails: ok (370 toleradas, baseline só apertou) · testes: ok (137/137) ·
parser: ok · rodados em 2026-10-02 17:00, na branch `cards/2026-10-02`.

## Estado do git
Branch `cards/2026-10-02`, working tree limpo (fora este handoff). `master` está
4 commits à frente de `origin/master`; a branch, mais 4 (+ este handoff). Nada
pushado.

## Decisões tomadas que não estão em card nenhum
- **Migrar para o AGENTS.md (Troubleshooting):** o colapso da barra dupla nas
  edições dos agentes e a checagem pós-card que o pega; e que guardrails "limpo"
  não prova que o arquivo foi lido.

## Próximo passo concreto
O dev roda os roteiros manuais (começar pelo 0009, que é o mais visível) e relata
AC por AC. Com os ACs fechados: mesclar `cards/2026-10-02` na `master` e
`git push`.

## Em aberto para o dev
- Corrigir o guardrails para **reprovar** arquivo ilegível? Exige também
  consertar o `situacao_disciplinas.gd`, senão o portão completo passa a falhar.
- Corrigir o `ROOT` padrão do workflow (ou torná-lo obrigatório)?
- Cards novos: vocabulário de categorias de carga (`agc` × `acg`); chave
  `al0367` duplicada em `alec_2023-alec_2010.json`; os `avisos_leitura` da
  Situação de Alunos possivelmente apagados no `_ready`; o manual da Sugestão de
  oferta desatualizado (achado do 0008).
