# Review — 0006-casamento-turma-subturma-horarios

## Rodada 1

**Escopo revisado:** `standalone_scripts/analise/analise_horarios.gd`
(`_comparar_turmas` reescrita + `_partir_turma` novo, static, puro) e
`test/unit/test_analise_horarios.gd` (11 testes novos). `Cards/.../spec.md`
adicionado (documentação).

**Portões executados nesta rodada:**
- `python .tools/guardrails.py` → limpo (108 violações pré-existentes na
  baseline, nenhuma nova).
- `python .tools/run_tests.py` → 52/52 passando; a suíte
  `test_analise_horarios.gd` sozinha: 19/19 (8 pré-existentes + 11 novos).
- `Godot_console.exe --headless --path . --editor --quit` → sem erro de
  parser.

**Conferência AC a AC (card + tabela AC→prova da spec):**
- AC1–AC7 (`_comparar_turmas` isolada: letra de um lado, simetria, letras
  distintas, idênticas, número manda, prefixo `T`/caixa, vazio não casa)
  → cada um tem teste dedicado, todos verdes. Rastreei a lógica de
  `_partir_turma`/`_comparar_turmas` linha a linha contra os exemplos do
  card (20/20a, 20a/20b, 20/80, t20/20A, "", " ", "a") — bate.
- AC8 (`al0376`, teórica `T20` sem letra casa com hist `20A`) e AC9
  (`al0003`, `T20`+`T20A` casam, `T20B` não) → testes de integração via
  `extrair_horarios_txt` reproduzem exatamente o cenário do card com
  fixtures sintéticas; tracei o duplo loop manualmente (inclui o motivo do
  `break` antecipado ao achar o primeiro casamento) e o resultado bate com
  o esperado.
- AC10 (turma composta com letra propagada, `30/60B` × `T30;60`) → tracei
  `_obter_turmas` nos dois lados (propagação de letra no hist, ausência de
  propagação no txt por a última parte já ser numérica) e confirmei que
  `_comparar_turmas("30","30b")` casa por letra ausente de um lado. Teste
  cobre.
- AC11 (non-goal: hist `20` × único `T80` continua só `matriculavel`) →
  teste dedicado, verde.
- AC12 (8 testes antigos continuam passando) → confirmado na mesma corrida
  (`ordenar_condicoes` ×4, `determinar_horarios` ×4).
- AC13 (manual, dados reais) → fora do escopo automatizável; roteiro na
  spec é adequado e não produz artefato versionado. Não é bloqueante para
  esta rodada de review de código.

**LGPD:** fixtures novas usam `"Nome Ficticio (alXXXX)"` e matrículas
fictícias, mesmo molde dos 8 testes já existentes. Nenhum nome, matrícula ou
e-mail real. Nenhum arquivo novo na raiz do projeto, nenhuma leitura de
`dados/`, nenhum `print`/log novo.

**Contrato de dados:** nenhuma chave de `arquivos/`, `base_config.json` ou
Kinto tocada. `_partir_turma` é função nova mas privada, sem persistência.
Único chamador de `_comparar_turmas` confirmado por grep no repositório
inteiro (produção + spec + card, nenhum outro módulo).

**Convenções multi-curso:** não se aplica — mudança é interna a
`AnaliseHorarios`, sem curso hardcoded nem chave de grade envolvida.

**Duplicação/reuso:** não há utilitário existente (`GeneralFunctions` etc.)
que já faça split número/letra de turma; `_partir_turma` é justificável como
novo helper privado e local, com chamador único.

### Findings

Nenhum.

**Veredito: clean.**
