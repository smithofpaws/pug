---
id: 0001-ordem-prioridade-grade-horarios
title: Ordem de prioridade das disciplinas na grade de horários
status: ready
origin: IDEAS.md (seção GERAL)
layers: [standalone_scripts/analise, scenes/Modulos/SituacaoAlunos, scenes/Modulos/SituacaoDisciplinas]
interviewed: true
---

# 0001 - Ordem de prioridade das disciplinas na grade de horários

## Goal

Cada célula da grade de horários concatena as disciplinas em ordem canônica de
prioridade, independentemente da ordem em que as condições foram ligadas no
seletor ou passadas pelo chamador:

1. Pedidas do modo ajuste: `ajuste_incluir`, depois `ajuste_excluir`;
2. Matriculadas: `matriculado_agora`, `matriculado_agora_aproveitamento`,
   `matricula_irregular`, `matricula_irregular_aproveitamento`;
3. Matriculáveis: `matriculavel`, `matriculavel_aproveitamento`,
   `corequisito_matriculavel`, `corequisito_matriculavel_aproveitamento`;
4. Demais: `seaprovado`, `seaprovado_aproveitamento`, `corequisito_seaprovado`,
   `corequisito_seaprovado_aproveitamento`.

A ordem dos itens 2–4 coincide com `base_config.json:condicoes` — a regra é
"ajuste primeiro, depois a ordem do base_config", aplicada dentro de
`AnaliseHorarios` (hoje `situacao_alunos.gd` anexa o ajuste no **fim** e a ordem
depende de quem chama). Vale para toda grade de horários: Situação Alunos e
Situação de Disciplinas.

## Non-goals

- Mudar cores, fundos ou o BBCode das células;
- Reordenar o seletor de condições (UI);
- Mexer na grade curricular (integralização);
- Alterar `base_config.json`.

## Acceptance criteria

- [ ] Com condições passadas em ordem embaralhada a `determinar_horarios`, a
      célula concatena na ordem canônica -- verify: `headless`
- [ ] `ajuste_incluir` aparece antes de `ajuste_excluir`, e ambas antes de
      qualquer outra condição -- verify: `headless`
- [ ] Condição desconhecida (fora da lista canônica) fica no fim, preservando o
      destaque atual ([shake] para condição sem cor) -- verify: `headless`
- [ ] Visual no modo ajuste: a pedida de inclusão aparece primeiro na célula,
      com o fundo verde (`FUNDO_AJUSTE_INCLUIR`) -- verify: `manual`

## Edge cases

- Condição sem entrada em `horarios_txt_condicao`: já é removida por
  `_preparar_horarios` — segue no-op;
- Forma de apresentação `esferas` (células sem vírgula separadora): a ordem
  canônica ainda vale;
- Situação de Disciplinas não tem modo ajuste — lá só muda a ordenação das
  condições comuns;
- A ordem **não** pode depender da ordem de toggle no `SeletorCondicoes` nem da
  ordem do array recebido.

## Smoke scenarios

Nenhum (ACs são `headless` + 1 `manual`). O AC manual: com dados fictícios em
modo ajuste, conferir na célula que a disciplina pedida (fundo verde) vem antes
das demais.
