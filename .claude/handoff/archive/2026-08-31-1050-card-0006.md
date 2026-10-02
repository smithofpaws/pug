# Handoff — 2026-08-31

## Onde parei
Um defeito relatado ("disciplina matriculada aparecendo como Matriculável")
virou o card 0006, que foi entrevistado, executado pelo pipeline, commitado e
**fechado** (`done`, AC13 confirmado pelo dev).
No meio do caminho descobri que **os portões de qualidade estavam desligados
nesta máquina, falhando em silêncio** — isso vale mais que o card.

## Card ativo
Nenhum. **0006 fechou `done`**: os 12 ACs `headless` provados pela suíte e o
AC13 (`manual`) confirmado pelo dev na tela, com os dados reais de 2026/2.
0005 continua `ready` e nunca rodou — é o próximo da fila.

## Feito nesta sessão
Tudo commitado, dois commits em `master`, **não pushados**.

**1. `94c50f9` — card 0006** (entrevista + índice).

**2. `f129dcf` — a correção.** `AnaliseHorarios._comparar_turmas` comparava
turma por igualdade exata de string. As duas fontes gravam a turma em
granularidades diferentes: o `horarios.txt` põe a turma inteira na teórica
(`T20`) e a subturma na prática (`T20A`/`T20B`), enquanto o `hist.csv` grava o
discente **sempre** na subturma (`20A`) — conferido o fan-out, não existe linha
com a turma cheia. Agora `_partir_turma` separa número e letra, e casam quando
os números são iguais e as letras são compatíveis (letra ausente de qualquer
lado casa com qualquer letra — regra simétrica, decisão do dev). Turma sem
número nunca casa.

Nos dados de 2026/2 a mudança é **puramente aditiva** (nenhuma linha deixa de
casar) e corrige **44 discentes**: `al0376` inteira (o caso relatado) mais as
teóricas de `al0003`, `al0021` e `al0366`. 11 testes novos; suíte 41 → 52.

## Pela metade / não verificado
- **Os outros 2 PCs quase certamente têm os portões quebrados do mesmo jeito**
  (ver abaixo). Não foi conferido em nenhum deles.
- **Os 3 casos de turma divergente seguem sem card**: `al0037` (hist `20/80` ×
  txt `30/60/90`), `al2126` e `al2129` (hist `20` × txt `80`). São turma que
  não existe no txt — divergência de dado, não de comparação. Continuam caindo
  em "Matriculável" em silêncio. Foi non-goal explícito do 0006.
- **Herança do handoff anterior, tudo ainda aberto:** auditoria das ~20 atas de
  PPC mal começada; o PPC em Typst ainda imprime a matriz antiga
  (`atualizar_alec_data.bat` não rodado); `percentagem_curso` sem card; as 11
  disciplinas que só existem na `alec_2023` não conferidas; `agc` vs `acg`.

## O achado que importa: os portões estavam cegos nesta máquina
Descoberto por acaso, ao tentar provar que o pre-commit barra um `.gd` sujo.
Ele **não barrava** — o arquivo sujo passou limpo.

Três camadas quebradas, todas **falhando abertas**:

1. **lefthook não instalado.** O `.git/hooks/pre-commit` existia e chamava um
   binário ausente; o script gerado pelo lefthook termina esse caminho com
   `echo "Can't find lefthook in PATH"` **sem `exit 1`**, então o commit passava
   com verificação nenhuma. Resolvido: `winget install evilmartians.lefthook`.
2. **`gdtoolkit` não instalado.** O `run_gdlint` (`.tools/guardrails.py:387`) só
   trata `FileNotFoundError`, que cobre o *executável* Python ausente, não o
   *módulo*. Recebia código 1, não achava nenhuma linha no formato
   `arquivo:linha: Error:`, registrava zero violações e devolvia "limpo". A
   mensagem "instale com pip" que o script tem pronta nunca disparava.
   Resolvido: `python -m pip install --user "gdtoolkit==4.*"`.
3. **As regras próprias do projeto também morriam** junto, porque dependem do
   parser do gdtoolkit. Isso não era óbvio: o mesmo arquivo de teste passou
   limpo antes do pip e depois foi pego por `static-typing`, que é regra do
   projeto, não do linter.

**Por que ninguém percebeu:** o `.git/hooks/` não é versionado pelo git, mas o
projeto vive no OneDrive, então o **arquivo** do hook se replicou para os 3 PCs
enquanto o **binário** não. O hook existe em toda máquina e não bloqueia em
nenhuma que não tenha o lefthook instalado.

**O sintoma que estava à vista:** o handoff anterior registrava "375
pré-existentes na baseline" e a execução reportava **108**. Eu vi a divergência,
tratei como forma de contar diferente e segui. Era o portão morto.

A baseline **não** foi corrompida: 375 entradas (147 do gdlint), intacta desde
`cb310d3`. Ninguém rodou `--update-baseline` com o linter cego, então a catraca
está preservada. Hoje a contagem é 374 — o diff do 0006 removeu de passagem um
`trailing-whitespace` pré-existente.

## Estado dos portões
Todos verificados **depois** do conserto, em 2026-08-31:
guardrails: ok (limpo, 374 toleradas) · testes: ok (52/52) · parser: ok
(`--headless --editor --quit` sem erro) · pre-commit: **ok e provado que barra**
(arquivo sujo em staging → exit 1, guardrails 🥊).

## Estado do git
`master`, sincronizada com `origin/master` em `f129dcf` — os dois commits da
sessão (`94c50f9`, `f129dcf`) foram pushados. Working tree com o card 0006
atualizado (status + ACs marcados) e este handoff; se este texto está no
GitHub, foram commitados depois.

## Decisões tomadas que não estão em card nenhum
- **A letra da turma é subturma, e a regra é simétrica.** Quem está em `20A`
  pertence à turma `20`. Consequência assumida: um discente registrado em `20`
  numa disciplina com práticas A e B casa com as duas. Não ocorre em 2026/2.
- **Portão que falha aberto é pior que portão nenhum**, porque produz confiança
  falsa. "Instalou" não é prova; a prova é o portão **recusar** um caso ruim.
- **Migrar para o AGENTS.md** (não cabe em card, é conhecimento durável): que
  `.git/hooks/` não é versionado mas **é replicado pelo OneDrive**, de modo que
  o `lefthook install` de uma máquina espalha o hook sem espalhar o binário; e
  que o setup por clone (`lefthook install` + `pip install gdtoolkit`) precisa
  ser conferido **por máquina**, com o teste de recusa, não com o de presença.

## Próximo passo concreto
Rodar os dois comandos de setup nos outros 2 PCs e, em cada um, provar que o
portão recusa: criar um `.gd` com `var x = 1`, `git add`, rodar
`lefthook run pre-commit` e exigir exit 1. **Enquanto isso não for feito, o
pipeline rodando naquelas máquinas aprova sem verificar de verdade.**

Depois disso, a fila tem o 0005 (`ready`, headless puro, 12 ACs).

## Em aberto para o dev
- Push do commit deste handoff (os dois primeiros já foram).
- Escrever o parágrafo do `AGENTS.md` sobre hooks × OneDrive?
- Card para os 3 casos de turma divergente, ou deixar para o 0005?
