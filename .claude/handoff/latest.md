# Handoff — 2026-10-03 07:42

## Onde parei
Resolvidas três pendências do dev (guardrails falha fechado, `root` obrigatório
no workflow, manual da Sugestão de oferta), todas commitadas na branch
**`cards/2026-10-02`**. Depois o dev corrigiu o alec-data, a sincronização
trouxe o `acg` (`c918e73`), e a branch foi mesclada na `master` (fast-forward) e
**pushada**. Os ACs manuais dos cards 0007, 0008 e 0009 continuam esperando o dev.

## Card ativo
Nenhum em execução.

| Card | Status | ACs pendentes (manual) | Commit |
|---|---|---|---|
| 0005 | `done` | nenhum | `c0f3c38` |
| 0007 | `in_progress` | 13-16 (diálogo com AL0037/AL2126/AL2129; não reabre ao trocar de aluno; sem horarios.txt; manual 4.3) | `902bc1e` |
| 0008 | `in_progress` | 12-13 (14 nomes da lista com filtro Eng. Civil; dica e manual) | `da91b3d` |
| 0009 | `in_progress` | 9-16 (Ctrl+F, teclado, rolagem, cópia, tema, dicas, manual 3.2) | `d9db515` |

Roteiros manuais: `Cards/<id>/spec.md` (R1...). Cada AC `manual` fecha por relato
do dev, um a um.

## Feito nesta sessão (2026-10-03)
- `4028277` **Guardrails falha fechado.** `.gd` que o parser do gdtoolkit não lê
  vira a violação `ilegivel` (nunca entra na baseline); `--update-baseline` se
  recusa enquanto houver uma; gdtoolkit ausente aborta com código 2. Provado:
  o `situacao_disciplinas.gd` ainda quebrado reprovou isolado e no projeto, o
  `--update-baseline` recusou sem tocar a baseline, e os dois caminhos de
  módulo ausente (simulados) abortaram.
- No mesmo commit, **`situacao_disciplinas.gd` voltou a ser legível** (string
  quebrada com barra dentro das aspas, desde `219131f`). A baseline foi criada
  com ele já ilegível, então a dívida dele nunca foi congelada: as 12 violações
  que apareceram foram **corrigidas**, não congeladas (tipos, espaços no fim,
  `_rodar_análise` → `_rodar_analise`, ordem das funções). Baseline intacta.
- `45c6de8` **`root` obrigatório** no `godot-feature-pipeline.js` (sem padrão
  fixo `O:/...`); para antes do primeiro agente, normaliza barras. Testado com
  quatro formatos de entrada no Node. Skill de setup e AGENTS.md atualizados.
- `d1e6f78` **Manual da Sugestão de oferta** corrigido (usa a lista oficial com
  filtro; o histórico só quando a lista não cobre o curso).
- AGENTS.md: parágrafo do guardrails reescrito para o comportamento novo.

## Pela metade / não verificado
- `c918e73` **Sincronização com o alec-data:** `agc` → `acg` na carga da
  `alec_2010`; na `alec_2023`, `unipampa_comunidade` (15 h) incorporada a
  `outras_extensoes` (205 → 220 h) e `ch_teorica`/`ch_pratica`/`ch_extensao` em 5
  disciplinas. Suíte e snapshot da validação seguem iguais. Não foi conferido se
  o `ppc2023` lia `agc` ou `unipampa_comunidade`.
- **`situacao_disciplinas.gd` mudou sem teste** (módulo de cena): o parser do
  Godot compilou sem erro de tipo, mas ninguém abriu a Situação de Disciplinas
  depois. Vale uma conferência rápida (análise isolada e comparação).
- ACs manuais dos cards 0007, 0008 e 0009.
- Teste de recusa do pre-commit na `apex`: ainda não rodado pelo dev. Os commits
  mostram o pre-commit rodando guardrails + testes de verdade.

## Estado dos portões
guardrails: ok (370 toleradas) · testes: ok (137/137) · parser: ok · rodados em
2026-10-03, na branch `cards/2026-10-02`. O guardrails agora falha fechado.

## Estado do git
`master` sincronizada com `origin/master` em `c918e73` (mais o commit deste
handoff). A branch `cards/2026-10-02` foi mesclada (fast-forward) e pode ser
apagada com `git branch -d cards/2026-10-02`.

## Decisões tomadas que não estão em card nenhum
- O nome da categoria de carga é só `acg` (decisão do dev, 2026-10-03).
- Migrar para o AGENTS.md (Troubleshooting): o colapso da barra dupla nas
  edições dos agentes neste ambiente e a checagem pós-card que o pega
  (gdlint lê cada `.gd` tocado, sem tabs no meio de linha, sem string aberta).

## Próximo passo concreto
O dev roda os roteiros manuais (começar pelo 0009) e relata AC por AC; cada AC
confirmado fecha a caixa no card, e o card vira `done` quando não sobrar nenhum.

## Em aberto para o dev
- Cards possíveis: chave `al0367` duplicada em `alec_2023-alec_2010.json`; os
  `avisos_leitura` da Situação de Alunos possivelmente apagados no `_ready`.
