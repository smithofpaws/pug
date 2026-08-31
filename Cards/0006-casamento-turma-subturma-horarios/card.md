---
id: 0006-casamento-turma-subturma-horarios
title: Casamento de turma e subturma na grade de horários
status: ready
origin: novo (defeito relatado pelo dev; uma matrícula em al0376 turma 20A aparecia como Matriculável)
layers: [standalone_scripts/analise/analise_horarios.gd]
interviewed: true
---

# 0006 - Casamento de turma e subturma na grade de horários

## Goal
A grade de horários de **Situação de Alunos** passa a reconhecer que a letra da
turma identifica uma **subturma**: quem está em `20A` pertence também à turma
`20`. Hoje a comparação é por igualdade exata de string, então a aula cuja
turma é registrada num nível de granularidade diferente do histórico não casa e
cai em "Matriculável" — mesmo o discente estando matriculado.

## Contexto: por que as duas fontes divergem
As duas fontes externas gravam a turma em granularidades diferentes:

- `horarios.txt`: a aula **teórica** leva a turma inteira (`T20`); a **prática**
  leva a subturma (`T20A`, `T20B`).
- `hist.csv` (GURI): grava o discente sempre na **subturma** (`20A`). Não existe
  linha com a turma "cheia" — o fan-out do CSV repete `20A` em todas as linhas.

Resultado com os dados de 2026/2:

- `al0376` — o txt tem **só** `T20` (nenhuma linha com letra) e o histórico diz
  `20A`. Nada casa, e a disciplina inteira aparece como Matriculável. É o caso
  relatado, e atinge as 15 matrículas da disciplina.
- `al0003`, `al0366`, `al0021` — a **prática** casa (`T20A`) e a **teórica**
  (`T20`) não. Deduzido do código e dos dados, **não observado na tela**.

## Regra acordada
Uma turma é `<número>` + letra opcional. Duas turmas casam quando os **números**
são iguais **e** as letras são compatíveis: letras iguais casam, e letra ausente
de **qualquer um** dos lados casa com qualquer letra (regra **simétrica**).

```
hist 20A  x  txt T20   -> casa      (teórica da turma 20)
hist 20A  x  txt T20A  -> casa      (prática do grupo A)
hist 20A  x  txt T20B  -> NÃO casa  (grupo B)
hist 20   x  txt T20A  -> casa      (decisão do dev: simétrica)
hist 20   x  txt T20B  -> casa
hist 20A  x  txt T80   -> NÃO casa  (turma diferente)
```

A consequência aceita da simetria: um discente registrado em `20` (sem letra)
numa disciplina que tem práticas `A` e `B` aparece matriculado nas **duas**.
Não ocorre em 2026/2 — foi verificado — e a alternativa assimétrica esconderia
a teórica de quem estivesse nesse estado.

## Non-goals
- **Não** trata turma do histórico que simplesmente não existe no txt para
  aquela disciplina (`al0037` hist `20/80` × txt `30/60/90`; `al2126` e `al2129`
  hist `20` × txt `80`). Isso é divergência de dado, não de comparação, e segue
  caindo em "Matriculável" como hoje. Fica para card próprio.
- **Não** mexe no fallback deliberado de `extrair_horarios_txt`: a aula da
  subturma que **não** é a do discente continua indo para `matriculavel`, para
  ele ver as outras opções de horário em cinza.
- **Não** muda a UI, a paleta, a ordenação das condições nem o formato de
  nenhum arquivo de `arquivos/` ou `dados/`.
- **Não** altera a propagação de letra em turma composta (`"40/80b"` →
  `40b`, `80b`), que já existe e está correta.

## Acceptance criteria
- [ ] `_comparar_turmas("20", "20a")` retorna `true` (letra de um lado só) -- verify: `headless`
- [ ] `_comparar_turmas("20a", "20")` retorna `true` (simetria) -- verify: `headless`
- [ ] `_comparar_turmas("20a", "20b")` retorna `false` (letras distintas) -- verify: `headless`
- [ ] `_comparar_turmas("20a", "20a")` e `_comparar_turmas("20", "20")` retornam `true` -- verify: `headless`
- [ ] `_comparar_turmas("20", "80")` e `_comparar_turmas("20a", "80a")` retornam `false` (número manda) -- verify: `headless`
- [ ] `_comparar_turmas("t20", "20A")` retorna `true` (prefixo `T` e caixa continuam irrelevantes) -- verify: `headless`
- [ ] Turma vazia ou só espaço não casa com nada, inclusive com outra vazia -- verify: `headless`
- [ ] Caso `al0376`: discente com turma `20A` e um `horarios_txt` cuja única linha da disciplina é `T20` — a linha vai para `matriculado_agora` e **não** aparece em `matriculavel` -- verify: `headless`
- [ ] Caso `al0003`: discente com turma `20A` e `horarios_txt` com `T20` (teórica), `T20A` e `T20B` — teórica e `T20A` vão para `matriculado_agora`; `T20B` vai para `matriculavel` -- verify: `headless`
- [ ] Turma composta com letra propagada: discente com `30/60B` casa com a linha `T30;60` -- verify: `headless`
- [ ] Não-regressão do non-goal: discente com turma `20` e disciplina cuja única linha no txt é `T80` continua indo só para `matriculavel` -- verify: `headless`
- [ ] Os 8 testes já existentes em `test/unit/test_analise_horarios.gd` seguem passando -- verify: `headless`
- [ ] Com os dados reais de 2026/2 carregados, uma matrícula em `al0376` (turma `20A`) aparece como **Matriculada** na grade de horários de Situação de Alunos -- verify: `manual`

## Edge cases
- **Turma vazia.** O `horarios.txt` tem uma linha de cabeçalho com todos os
  campos em branco (turma `" "`). A regra nova compara o número; duas turmas
  sem número **não** podem casar, senão essa linha casaria com todo discente.
  (Hoje ela é inofensiva porque não tem código de disciplina, mas a regra não
  pode depender disso.)
- **Letra sem número** (`"a"`) e **número com mais de uma letra** (`"20ab"`):
  não ocorrem nos dados; devem ser tratados pela mesma regra, sem crashar.
- **Separadores.** O txt usa `;` e o histórico usa `/`; `_obter_turmas` já
  normaliza. O card não muda isso, mas os testes de turma composta passam por lá.
- **Superfície contida.** `_comparar_turmas` tem exatamente **um** chamador
  (`analise_horarios.gd:240`, dentro de `extrair_horarios_txt`), e ambos são
  privados de `AnaliseHorarios`. Nenhum outro módulo compara turma.
- **Sem arquivo novo.** Não há leitura nova: `main.gd` já injeta `horarios_txt`
  e o histórico. Nada muda no que acontece com arquivo ausente.

## Smoke scenarios
Nenhum. Todos os ACs verificáveis são `headless` — `AnaliseHorarios` é lógica
pura e está na camada testável. O único AC visual é `manual`, fechado pelo dev
contra os dados reais, que **não** podem virar PNG (dado de aluno).
