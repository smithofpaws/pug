---
id: 0002-mesclar-respostas-ajuste
title: Mesclar múltiplas respostas do mesmo aluno no ajuste de matrícula
status: done
origin: IDEAS.md (seção GERAL)
layers: [standalone_scripts/io]
interviewed: true
---

# 0002 - Mesclar múltiplas respostas do mesmo aluno no ajuste de matrícula

## Goal

Quando o mesmo aluno responde o formulário de ajuste mais de uma vez,
`PlanilhaAjuste.parse()` **mescla** todas as respostas em vez de descartar as
anteriores (hoje é last-wins por matrícula): `incluir`/`excluir` viram a união
das respostas, e conflito por disciplina — mesmo código nos dois lados em
respostas **diferentes** — é resolvido pela **menção mais recente** (as linhas
do CSV estão em ordem cronológica do Forms).

## Non-goals

- Avisar o coordenador sobre respostas múltiplas (sem UI nova);
- Ler a coluna de carimbo de data/hora (ordem das linhas = cronológica);
- Validar códigos contra as grades (continua no módulo);
- Mudanças em `baixar()`.

## Acceptance criteria

- [x] Duas respostas da mesma matrícula com inclusões disjuntas → o resultado é
      a união de todas -- verify: `headless`
- [x] Código incluído na 1ª resposta e excluído na 2ª → só aparece em
      `excluir` (e vice-versa) -- verify: `headless`
- [x] Mesmo código no mesmo lado em 2 respostas → uma entrada só, com o texto
      da menção mais recente -- verify: `headless`
- [x] Entrada sem código extraível é mantida (dedup por texto normalizado) e
      continua chegando ao módulo para aparecer como inválida -- verify: `headless`
- [x] Formato de retorno inalterado:
      `{ok, respostas: [{matricula, incluir, excluir}]}` -- verify: `headless`

## Edge cases

- Mesmo código nos dois lados **na mesma resposta** (sem "mais recente"
  possível): a **exclusão prevalece** (decisão conservadora, aprovada na
  entrevista);
- Resposta posterior com célula vazia **não apaga** o que outra resposta pediu
  (vazio ≠ "desfazer");
- Matrícula com espaços nas pontas: já normalizada por `strip_edges`;
- Uma entrada de texto com **mais de um** código extraível segue o mesmo
  princípio por código.

## Smoke scenarios

Nenhum (todos os ACs são `headless`; `parse()` é puro dado um CSV fictício em
`test/fixtures/`).
