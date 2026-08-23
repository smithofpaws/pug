---
id: 0004-cor-concluida-por-equivalencia
title: Disciplina concluída por equivalência recebe a cor de cursada na grade
status: done
origin: IDEAS.md (seção BUGs, alta prioridade)
layers: [standalone_scripts/analise, scenes/Modulos/SituacaoAlunos]
interviewed: true
---

# 0004 - Disciplina concluída por equivalência recebe a cor de cursada na grade

## Goal

Na grade de integralização da Situação Alunos, disciplina concluída sob o
código de outra grade (via equivalência, respeitando
`AnaliseGrades.alvo_completo` — todas as fontes do grupo cursadas) recebe o
**mesmo dourado de "cursada"** (`lista_cores["cursada"]`).

Hoje ela fica sem cor nenhuma, indistinguível de uma matriculável:
`disciplinas_concluidas` só olha os códigos brutos do histórico. A hachura de
distantes já expande equivalências corretamente
(`disciplinas_distantes` + `para_o_codigo_qual_a_equivalencia` +
`alvo_completo`); a cor deve usar a mesma via, para cor e hachura nunca
discordarem. O módulo já recebe as equivalências injetadas — sem mudança no
`main.gd`.

## Non-goals

- Tooltip/indicação de origem na célula (registrado como ideia no `IDEAS.md` —
  a célula da Grade não tem tooltip hoje);
- Token de cor novo (`base_config.json` intocado — decisão da entrevista:
  concluída é concluída, mesmo dourado);
- Situação de Disciplinas e Planejamento de Oferta (grades agregadas, sem
  cursadas por aluno);
- Mudar a regra `alvo_completo` ou os arquivos de equivalência;
- Os bugs de `calculo_carga_horaria` (card futuro próprio).

## Acceptance criteria

- [x] Cursada fonte com equivalência para a grade ativa → o alvo entra na
      lista de concluídas por equivalência -- verify: `headless`
- [x] Disciplina dividida (2 fontes → 1 alvo): o alvo só entra quando TODAS as
      fontes foram cursadas -- verify: `headless`
- [x] Grade ativa sem arquivo de equivalência → retorno vazio, sem erro
      (no-op) -- verify: `headless`
- [x] `montar_grade_curricular` com as cursadas expandidas pinta o alvo com
      `lista_cores["cursada"]`, mantendo a precedência de cursada sobre
      condições -- verify: `headless`
- [x] Visual: aluno com disciplina cursada sob código de outra grade vê a
      célula dourada na grade de integralização -- verify: `manual`
      (fechado por relato do dev em 2026-08-22, roteiro do smoke.md executado)

## Edge cases

- Alvo já cursado diretamente na grade ativa: expansão idempotente (não
  duplica, não rebaixa);
- Curso/grade sem arquivo de equivalência: no-op silencioso (programa nunca
  crasha por arquivo ausente);
- Cor e hachura usam a mesma expansão — uma célula dourada nunca pode estar
  hachurada como distante;
- Equivalência intracurso (`alec_2023-alec_2010`) e entre cursos seguem os
  mesmos arquivos `<origem>-<destino>` já injetados no módulo;
- Fixtures de teste fictícias (grade + equivalência sintéticas), sem depender
  dos arquivos reais de `arquivos/`.

## Smoke scenarios

Nenhum PNG (AC visual é `manual`: roteiro para o dev, que pode usar os dados
locais da máquina — captura versionada não há).
