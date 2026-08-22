# Review — 0004-cor-concluida-por-equivalencia

## Rodada 1

Escopo: `standalone_scripts/analise/analise_grades.gd` (função nova
`concluidas_por_equivalencia`), `scenes/Modulos/SituacaoAlunos/situacao_alunos.gd`
(`_cursadas_com_equivalencia` + os dois call sites de `montar_grade_curricular`),
`test/unit/test_analise_grades.gd` (suíte nova), `MANUAL.md`, `card.md`,
`Cards/README.md`.

Portões conferidos e verdes: `python .tools/guardrails.py` (limpo, baseline
inalterada), `python .tools/run_tests.py` (41/41, incluindo os 7 testes novos
de `test_analise_grades.gd`), parser real do Godot
(`--headless --path . --editor --quit`, sem erro).

Conferência de call sites: `grep -rn "montar_grade_curricular"` no repo lista
só três chamadores em produção — os dois em `situacao_alunos.gd` (ambos
migrados para `_cursadas_com_equivalencia`) e `planejamentooferta.gd:1580`
(passa `vazio_cursadas = []`, fora de escopo por non-goal do card — grade
agregada, sem cursadas por aluno). Não há terceiro caminho por-aluno esquecido.

Correção do algoritmo (`concluidas_por_equivalencia`): conferida por leitura —
`houve_grupo` em `alvo_completo` não pode ser `false` para um alvo que chegou
via `para_o_codigo_qual_a_equivalencia` (a própria fonte já garante um grupo);
`presentes` é pré-computado uma vez, então o resultado independe da ordem de
iteração de `cursadas`; dedup via `presentes`/`novos` dá a idempotência pedida
no edge case; a monotonicidade de `alvo_completo` no conjunto de presença
sustenta o invariante "dourado nunca hachurado" (`cursadas ⊆ codigos_historico`
nos dois chamadores). `disciplinas_distantes` e o corpo de
`montar_grade_curricular` seguem byte a byte iguais, como a spec promete.

### Findings

1. **[não-bloqueante]** AC4, como implementado (a fiação em
   `situacao_alunos.gd`), não tem teste que falhe se for revertido.
   `test_grade_pinta_alvo_expandido_de_cursada` compõe
   `concluidas_por_equivalencia` + `montar_grade_curricular` manualmente no
   teste — prova que as duas funções puras compõem corretamente, mas não
   exercita `_cursadas_com_equivalencia` nem os call sites reais. Revertendo
   só a fiação do módulo (deletar `_cursadas_com_equivalencia` e as duas
   trocas de argumento em `_analisar_matricula`/`_atualizar_grade_curricular`,
   mantendo `analise_grades.gd` intacto) os 7 testes continuam verdes — a
   correção do bug do card fica sem guarda automatizada, coberta só pelo AC5
   manual. Consistente com a spec (módulo de cena sem cobertura headless) e
   com a seção 5 da skill de review ("cobertura de teste desejável mas não
   exigida por AC" — o card já marca o AC5 como `manual`), então não bloqueia
   a rodada; registro para o histórico.

Nenhum outro finding. Nenhum dado pessoal no diff (fixtures fictícias,
`smoke.md` sem matrícula/nome real). `test/unit/test_analise_grades.gd.uid`
é conforme — os três testes existentes também têm `.uid` versionado.

**Veredito: clean** (nenhum finding com `blocking: true`).
