# Cards

Unidade de trabalho do PUG. Um card é uma feature descrita pelo comportamento
observável, com critérios de aceite falsificáveis — não uma lista de passos de
implementação.

O backlog solto continua no `IDEAS.md` (organizado por módulo). Uma ideia vira
card pela entrevista da skill `godot-session-setup`; um card `ready` é executado
pelo pipeline (`.claude/workflows/godot-feature-pipeline.js`).

## O que é e o que não é um card

**É:** algo que o coordenador consegue ver acontecer no programa (uma análise
nova, uma coluna a mais na exportação, um diálogo que passa a avisar), ou que
quebra de forma observável se estiver errado (um cálculo de CH, uma equivalência
não expandida).

**Não é:** um passo de implementação ("criar a função X"), uma ideia sem escopo
("melhorar a performance"), nem o registro do que já foi feito — para isso
existe o histórico do git.

## Estrutura

```
Cards/
├── README.md            este arquivo: convenção + índice
├── .gdignore            o Godot não importa nem exporta esta pasta (fica fora do PCK)
└── NNNN-slug/
    ├── card.md          goal, non-goals, ACs, edge cases, smoke scenarios
    ├── spec.md          saída da skill godot-feature-design
    ├── review.md        findings de cada rodada de review
    └── smoke/           PNGs por AC + smoke.md
```

> **LGPD — regra absoluta desta pasta:** o repositório é público e `Cards/` é
> versionado. Nenhum PNG de smoke, roteiro ou texto de card pode conter dado
> pessoal real de **aluno** (nome, matrícula, e-mail) nem dado de **docente
> além do nome** (e-mail, preferências, histórico de oferta); o nome de docente
> sozinho é tolerado, mas prefira fictício. Capturas de tela só com `dados/`
> vazio ou com fixtures fictícias (`test/fixtures/`); exemplos em texto usam
> nomes fictícios (`Maria da Silva Souza`).

## Status

| Status | Significado |
|---|---|
| `todo` | Existe, mas **não foi entrevistado**. Os ACs são um rascunho, não um acordo. |
| `ready` | Entrevistado e aprovado por você. **Só cards `ready` entram na fila automática.** |
| `in_progress` | Em execução pelo pipeline. |
| `blocked` | Falhou no pipeline. O motivo está em `review.md`, e a fila **parou** aqui. |
| `done` | ACs verificados. |
| `superseded` | O escopo foi entregue por outro card. A pasta fica; o cabeçalho nomeia quem o substituiu. Nunca entra na fila. |

A promoção `todo → ready` acontece só pela skill `godot-session-setup`, que
entrevista antes de escrever. É o que impede a fila automática de executar um
escopo que ninguém acordou.

## Como cada AC é verificado

Todo AC declara o próprio método. É esse campo que liga o card aos portões:

- `headless` — teste GUT em `test/`, rodando sem janela. Vale para a camada
  testável: `standalone_scripts/analise/`, `standalone_scripts/utils/`, os
  parsers de `standalone_scripts/io/` (com fixtures fictícias) e qualquer
  função pura extraída de módulo.
- `smoke` — PNG capturado com o programa rodando (`--write-movie`), guardado em
  `smoke/` do card. Só com dados fictícios ou sem dados.
- `manual` — roteiro para você executar. Usado onde não há harness de input:
  interação de mouse nos módulos de cena, diálogos, seletores.

Um AC sem método declarado é um AC que o pipeline não sabe onde provar.

## Setup (uma vez por clone)

```bash
python -m pip install --user "gdtoolkit==4.*"   # gdlint, usado pelo guardrails
lefthook install                                 # grava o pre-commit em .git/hooks/
```

## Portões

```bash
python .tools/guardrails.py      # gdlint + regras do projeto (com baseline/catraca)
python .tools/run_tests.py       # suite GUT headless (exit != 0 se falhar)
```

O `pre-commit` do Lefthook roda os dois. Os hooks do Claude Code
(`.claude/settings.json`) rodam o `guardrails.py` a cada edição de `.gd`.

> **Baseline (catraca):** o código anterior aos guardrails carrega violações
> históricas, congeladas em `.tools/guardrails_baseline.json` por arquivo+regra.
> O portão só reprova violação **nova**. Limpar um arquivo e rodar
> `python .tools/guardrails.py --update-baseline` aperta a catraca — queimar
> essa dívida é trabalho legítimo de card.

## Índice

| # | Título | Status | Origem |
|---|---|---|---|
| 0001 | [Ordem de prioridade das disciplinas na grade de horários](0001-ordem-prioridade-grade-horarios/card.md) | done | IDEAS.md (seção GERAL) |
| 0002 | [Mesclar múltiplas respostas do mesmo aluno no ajuste de matrícula](0002-mesclar-respostas-ajuste/card.md) | done | IDEAS.md (seção GERAL) |
| 0003 | [Re-anexar fragmentos de rótulo sem código no ajuste de matrícula](0003-reanexar-fragmentos-rotulo-ajuste/card.md) | done | IDEAS.md (seção GERAL) |
| 0004 | [Disciplina concluída por equivalência recebe a cor de cursada na grade](0004-cor-concluida-por-equivalencia/card.md) | done | IDEAS.md (BUGs, alta prioridade) |
| 0005 | [Validação de coerência dos dados curriculares](0005-validacao-coerencia-dados-curriculares/card.md) | ready | novo |
| 0006 | [Casamento de turma e subturma na grade de horários](0006-casamento-turma-subturma-horarios/card.md) | ready | novo (defeito relatado) |
