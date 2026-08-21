---
name: godot-session-setup
description: Ponto de entrada de toda sessão de trabalho no PUG (Godot 4.7). Começa lendo .claude/handoff/latest.md para saber onde a sessão anterior parou, entrevista o desenvolvedor até a feature estar bem descrita — aplicando os fundamentos do domínio (escopo, LGPD, convenções multi-curso, snake_case, injeção pelo main) para fazer as perguntas certas — e então escreve um card em Cards/ com goal, non-goals e critérios de aceite falsificáveis. Também roda a fila automática de cards aprovados e grava o handoff ao encerrar. Use esta skill SEMPRE que o dev descrever algo que quer construir, mudar ou corrigir no programa — inclusive quando ele já chegar pedindo implementação direta ("adiciona X", "faz o botão Y", "quero que Z funcione"), porque o card vem antes do código. Use também no começo de qualquer sessão, e quando ele disser "onde paramos", "retoma", "continua de ontem", "roda a fila", "modo automático", "o que tem pra fazer" ou "quais cards estão abertos".
---

# Setup de sessão do PUG

Quatro responsabilidades: **retomar de onde a sessão anterior parou** (handoff),
**transformar uma ideia em card** (modo intake, o default), **migrar uma ideia do
`IDEAS.md` para um card `todo` sem entrevistar** (modo migração) e **executar
cards já aprovados em sequência** (modo fila).

Nenhuma delas escreve código de produção. Quem escreve é o pipeline
(`.claude/workflows/godot-feature-pipeline.js`), e ele só aceita card `ready`.

---

## Passo 0 — leia o handoff antes de qualquer coisa

**Primeira ação, sempre:** leia `.claude/handoff/latest.md`.

Ele diz o que a sessão anterior fez, onde exatamente parou e o que ficou pela
metade. Sem isso você recomeça do zero, refaz decisão já tomada e às vezes desfaz
trabalho pela metade sem perceber que estava pela metade.

Depois de ler:

1. Confira se o estado descrito ainda vale — `git status --short`, `git log --oneline -5`,
   e os portões se o handoff disser que estavam quebrados. **O arquivo descreve o
   passado; o repositório é a verdade.** Se divergirem, o repositório ganha e você
   diz que divergiu.
2. Resuma ao dev em duas ou três frases: onde parou, qual era o próximo passo, o que
   ficou em aberto.
3. Pergunte se ele quer continuar dali ou começar outra coisa.

Se `latest.md` não existir (primeira sessão, ou foi limpo), diga isso e siga para o
intake normalmente — não invente um estado anterior.

---

## Modo intake

### Por que entrevistar antes de escrever

Um card mal descrito custa muito mais caro depois: o pipeline gasta ~11 agentes por
card, e um AC ambíguo faz o dev implementar uma coisa, o review aprovar outra e o
smoke não saber o que provar. A entrevista é o ponto mais barato de descobrir que a
feature na verdade eram duas.

### O que precisa estar claro antes de escrever o card

Pergunte até saber responder cada um destes. Se você já sabe pelo repositório, não
pergunte — confirme.

1. **Qual módulo / camada.** SituacaoAlunos, SituacaoDisciplinas, PlanejamentoOferta,
   PlanejamentoHorario, MatriculaIrregular, Trancamentos, CalculadorCR, Exportadores,
   LimeSurvey — ou um Complementar (Terminal, Grade, seletores)? Toca
   `standalone_scripts/` (lógica), `scenes/` (UI) ou os dois?
2. **O comportamento observável**, não a implementação. "A grade pinta de dourado a
   disciplina concluída por equivalência" é comportamento; "expandir equivalências em
   `disciplinas_concluidas`" não é.
3. **As entradas** — qual arquivo de dados alimenta (hist.csv, planejamento,
   horarios.txt, grades JSON, equivalências), qual configuração em `base_config.json`,
   qual interação de UI. Feature que precisa de dado novo implica o **main.gd ler e
   injetar** — módulo não lê arquivo.
4. **Os casos de borda**: aluno sem histórico, disciplina sob código de outra grade,
   curso sem arquivo de equivalência, CSV com linhas duplicadas (fan-out do GURI),
   turma como float no JSON vs int no histórico, arquivo ausente (o programa abre
   "mudo", nunca crasha). O que é no-op e o que é erro visível?
5. **O que fica de fora.** Non-goals são metade do valor do card.
6. **Como se vê que funcionou** — e por qual dos três métodos (abaixo).

### Fundamentos do domínio que mudam a pergunta

Você não é um coletor de requisitos. O valor da entrevista está em trazer o que se
sabe sobre este programa para dentro da conversa — o dev conhece a coordenação
dele, mas raramente pensa em LGPD e compatibilidade de arquivo no momento em que a
ideia aparece. Os cinco que mais mudam a conversa (detalhes no `AGENTS.md`):

**1. Escopo é o que mata projeto solo.** A pergunta mais valiosa costuma ser "qual é
a versão menor disto que ainda vale a pena?". Se a feature tem três partes e só uma é
indispensável, são três cards, e talvez só o primeiro seja feito.

**2. LGPD é requisito, não detalhe.** O repositório é público, as releases são
públicas e o programa processa dados de alunos e docentes. Toda feature que grava,
exporta, sincroniza ou loga algo precisa responder: esse dado sai do PC? Aparece
num arquivo versionado, no ZIP da release, no PCK, num PNG de smoke? A única
exceção controlada é a sincronização Kinto (planejamento de oferta, dado
funcional). Se a resposta mudar a superfície de exposição, isso vira AC.

> "Essa exportação nova vai para `exportacoes/` (gitignorada) ou para um lugar
> novo? O nome do aluno aparece no arquivo?"

**3. Dado canônico vs. apresentação.** Tudo que não é impresso vive em snake_case
(sem acento, sem espaço); a formatação (acentos, capitalização sentence case)
acontece só ao inserir na UI. Uma feature que introduz um valor novo precisa dizer
qual é a chave canônica e qual é o rótulo — e se há `SeletorAvancado`, o par
`_retorno` separa os dois.

**4. Fonte única de verdade e compatibilidade de arquivo.** `base_config.json:cursos`
define os identificadores canônicos; chaves de grade são `<cod_curso>_<versao>` e
equivalências `<origem>-<destino>`. Os JSONs de `arquivos/` são consumidos também
fora do programa (repositórios de curso, `ppc2023` em Typst) — **mudar o
significado ou o nome de uma chave existente quebra consumidores em silêncio**
(JSON com chave ausente vira default, não erro). Adicionar chave é seguro; renomear
é um card de migração.

**5. Injeção pelo main.** Leitura de arquivo é concentrada no `main.gd`, que injeta
nos módulos. O programa precisa continuar funcionando com o arquivo ausente
(precedente: `arquivos/oferta/` — o módulo abre sem sugerir professores, sem
crashar). Se a feature pede leitura nova, a pergunta é "o que o main injeta e o que
acontece quando não existe?".

**E a consistência de interface é requisito verificável:** tooltip é `DicaFlutuante`,
diálogo é `Dialogos.confirmar/avisar/escolha_lista`, cor é `PaletaSemantica`, status
é `StatusBar`, saída de relatório usa os helpers do `Terminal`, popup chama
`Dialogos.limitar_a_tela`. Quando a feature cria UI, esses pontos viram AC ou
non-goal explícito.

### Como perguntar

Uma dimensão por vez, com o precedente do repositório dentro da pergunta. Pergunta
com contexto rende resposta melhor que questionário despejado:

> "A grade de integralização já distingue 'distante' por hachura leve
> (`HachuraOverlay.leve`) para não criar cor nova. A concluída por equivalência
> deve receber o mesmo dourado de 'cursada' ou um token próprio na
> `PaletaSemantica`?"

é melhor que "qual cor você quer?".

Use `AskUserQuestion` quando as opções forem discretas e você conseguir enumerá-las.
Use texto corrido quando a resposta for aberta.

### Sinais de que ainda não dá para escrever o card

- O goal descreve implementação em vez de comportamento.
- Nenhum AC é falsificável — não dá para imaginar o teste que falharia.
- Não dá para dizer o que acontece num caso de borda.
- A feature na verdade são duas. Divida em dois cards e diga isso.
- O card depende de uma decisão que ninguém tomou (ex.: qual token de cor, onde
  mora um campo novo do JSON de grade). Escreva o card com status `todo` e
  registre a decisão pendente como o primeiro passo — não invente a decisão.

### Declarar como cada AC é verificado

Todo AC carrega um dos três métodos. É esse campo que liga o card aos portões; sem
ele o pipeline não sabe onde provar o quê.

| Método | Quando | Onde roda |
|---|---|---|
| `headless` | A lógica é pura ou de dados | teste GUT em `test/`, via `python .tools/run_tests.py` |
| `smoke` | Precisa aparecer na tela | PNG em `Cards/<id>/smoke/` (só dados fictícios) |
| `manual` | Exige interação de mouse/diálogo | roteiro para o dev executar |

**Camada testável headless:** `standalone_scripts/analise/*` (AnaliseHistorico,
AnaliseGrades, AnaliseCurricular, AnaliseHorarios, AnaliseReprovacoes,
CalculoCargaHoraria), `standalone_scripts/utils/*` (GeneralFunctions,
JsonValidator, MarkdownHtml), os parsers de `standalone_scripts/io/`
(EmentaParser, partes puras de FileHandling e ArquivosPlanejamento — com fixtures
fictícias em `test/fixtures/`), e qualquer função pura extraída de módulo.

**Não testável headless** (não force um AC `headless` aqui, o dev vai fabricar
teste): `scenes/Modulos/*`, `scenes/Complementares/*`, `main.gd`,
`barraprincipal.gd`, e os caminhos de rede (`sincronizacao*.gd`, `atualizador.gd`
— a lógica pura deles, como comparação de versão, é testável; a rede não).

Se uma feature cai inteira no lado não testável, pergunte se dá para extrair a
lógica pura para uma classe de `standalone_scripts/` que receba os dados por
parâmetro — isso costuma ser a melhoria de design mais valiosa do card.

### Formato do `card.md`

```markdown
---
id: NNNN-slug
title: ...
status: ready
origin: IDEAS.md (seção X) | novo
layers: [standalone_scripts, scenes/Modulos/SituacaoAlunos]
interviewed: true
---

# NNNN - Título

## Goal
1 a 3 frases, comportamento observável.

## Non-goals
- o que explicitamente não entra

## Acceptance criteria
- [ ] AC falsificável -- verify: `headless` | `smoke` | `manual`

## Edge cases
...

## Smoke scenarios
O que cada PNG precisa mostrar, nomeado pelo AC. Lembrete: dados fictícios.
```

Numere o card com o próximo inteiro livre em `Cards/` (começando em 0001). Crie a
pasta com o subdiretório `smoke/` vazio.

### Fim do intake

1. Mostre o card ao dev.
2. Peça aprovação explícita.
3. Só depois grave `status: ready` e `interviewed: true`, e acrescente a linha em
   `Cards/README.md`.
4. **Não dispare o workflow.** Isso é um comando separado do dev.

---

## Modo migração (`IDEAS.md` → card `todo`)

Ativado só por pedido explícito: "pega essa ideia do `IDEAS.md` e transforma em
card", ou equivalente. O `IDEAS.md` é o backlog por módulo que alimenta o índice
de cards com rascunhos não entrevistados.

**Não é o intake.** Não entreviste, não gere AC falsificável, não pergunte sobre
non-goals nem sobre os fundamentos do domínio. É transcrição de escopo, não design.

1. Remova a linha (ou o item) da ideia do `IDEAS.md`.
2. Numere o card com o próximo inteiro livre em `Cards/`; crie a pasta com o
   subdiretório `smoke/` vazio.
3. Escreva `card.md` com `status: todo`, `interviewed: false` e `origin: IDEAS.md
   (seção <nome da seção>)`.
4. Abra o corpo do card com o aviso:

   ```markdown
   > Rascunhado a partir do `IDEAS.md`, **sem entrevista**. Os ACs abaixo são
   > uma leitura do texto original, não um acordo. O card só vira `ready` (e só
   > então entra na fila automática) depois de passar pela skill
   > `godot-session-setup`.
   ```

5. `Goal`, `Non-goals`, `Acceptance criteria` e `Edge cases` são uma leitura de
   boa fé do texto original — cole ou parafraseie. Não force um AC que o texto
   não sustenta; é melhor um card com menos ACs rascunhados do que um com AC
   inventado por você.
6. Acrescente a linha no índice do `Cards/README.md`, status `todo`, origem
   `IDEAS.md (seção X)`.
7. **Não entreviste em seguida, mesmo que pareça o próximo passo óbvio.** A
   entrevista é um pedido separado do dev; este modo só mudou a ideia de lugar.

---

## Modo fila (automático)

Ativado só por pedido explícito: "roda a fila", "modo automático", ou equivalente.

Aqui o **orquestrador** coordena e os subagentes **Sonnet** implementam, revisam,
corrigem e fazem o smoke. Um card por vez.

### Pré-condições, checadas antes de começar

Se qualquer uma falhar, pare e diga qual — não tente contornar.

- Working tree limpo (`git status --short` vazio).
- `python .tools/guardrails.py` sai 0.
- `python .tools/run_tests.py` sai 0.
- Existe ao menos um card `ready`.

### Branch

O repositório fica em `master`. Na primeira vez, crie uma branch `cards/<data>` e
commite todos os cards da fila nela — um commit por card, mensagem referenciando o
id. Não commite direto em `master` sem o dev pedir.

### O laço

Para cada card `ready`, na ordem do índice:

1. `status: in_progress` no `card.md` e no índice.
2. Rode `.claude/workflows/godot-feature-pipeline.js` com `args: {cardId}`.
3. Leia o resultado estruturado.
4. **Se passou:** `status: done`, marque os ACs provados (confira as caixas contra
   a coluna de veredito do `smoke.md`, nunca contra a narrativa), atualize o
   índice, commite.
5. **Se falhou:** `status: blocked`, motivo em `review.md`, **pare a fila** e
   apresente a situação ao dev.

### Por que a fila para em vez de seguir

Os cards seguintes seriam construídos sobre uma base quebrada, e o defeito ficaria
mais caro a cada card. Parar também vale se um portão quebrar no meio, ou se o
working tree ficar sujo de forma inesperada.

### O que a fila nunca faz

- **Entrevistar.** Card `todo` não entra. A fila executa escopo já acordado; ela não
  cria escopo.
- **Pular um portão.** Sem `--no-verify`, sem `LEFTHOOK=0`. Se o commit não passa, o
  card falhou — e é exatamente o comportamento desejado.
- **Afrouxar a baseline dos guardrails** (`--update-baseline` para cima). Se um card
  exige violar uma regra, ele está bloqueado por decisão de design, não por lint.
- **Fechar AC `manual` sozinha.** Cada AC `manual` fecha por relato do dev, um a
  um. Uma sessão não certifica o próprio trabalho.

---

## Escrever o handoff

Grave `.claude/handoff/latest.md` **sempre que**:

- o dev disser que está parando, ou algo equivalente ("por hoje é isso", "amanhã
  continuo", "vou almoçar");
- um card fechar ou for bloqueado;
- a fila parar;
- você perceber que o contexto está longo e uma compactação vem por aí.

Não espere ser pedido. Um handoff que não foi escrito porque a sessão acabou de
repente é exatamente o caso em que ele valeria mais.

### O que o handoff precisa ter

O valor está em ser **honesto sobre o que ficou pela metade**. Um handoff que só
lista vitórias é pior que nenhum: a próxima sessão assume que está tudo pronto.

```markdown
# Handoff — <data e hora>

## Onde parei
Uma ou duas frases. O estado real, não o pretendido.

## Card ativo
NNNN-slug, status <x>. Ou "nenhum".

## Feito nesta sessão
- ... (o que está commitado vs. o que está só no working tree)

## Pela metade / não verificado
O item mais importante do arquivo. Teste vermelho pendente, portão não rodado,
suposição não confirmada, refactor no meio. Diga o que NÃO foi provado.

## Estado dos portões
guardrails: ok/falha · testes: ok/falha · parser: ok/falha · (quando rodou)

## Estado do git
branch, working tree limpo ou não, o que está sem commit.

## Decisões tomadas que não estão em card nenhum
Se virou convenção, isso pertence ao AGENTS.md — anote aqui que precisa migrar.

## Próximo passo concreto
Uma ação, específica o bastante para começar sem reler tudo.

## Em aberto para o dev
Perguntas que travam o próximo passo.
```

### Regras do arquivo

- `latest.md` é **sobrescrito** a cada gravação. Antes de sobrescrever, mova o
  anterior para `.claude/handoff/archive/<AAAA-MM-DD-HHMM>-<card-ou-tema>.md`.
- Ele é versionado no git de propósito: o projeto é usado em 3 máquinas e o
  estado precisa sobreviver a uma troca de computador.
- **É estado, não documentação.** Conhecimento durável sobre o projeto vai para o
  `AGENTS.md`; escopo de trabalho vai para um card. Se você está escrevendo no
  handoff algo que vale daqui a três meses, está escrevendo no lugar errado.
- Sem datas relativas. "Ontem" não significa nada para quem lê depois.
- Sem dado pessoal real — o repositório é público.

## Estado do projeto que vale ter em mente

- Godot **4.7**, renderer GL Compatibility, autoload único `GV`.
- Convenções em `AGENTS.md` (arquitetura, LGPD, multi-curso, diálogos) e
  `FORMATACAO.md` (estilo, UI).
- Portões: `python .tools/guardrails.py` (com baseline/catraca — ver
  `Cards/README.md`) e `python .tools/run_tests.py`.
- Parser do projeto: `"C:/Program Files/Godot/Godot_console.exe" --headless
  --path . --editor --quit`. O `--check-only` isolado dá falso positivo
  (autoloads não resolvem).
- git: começar a sessão com `git pull`, terminar com push; o dev está aprendendo
  git — explique o porquê antes de rodar comandos incomuns.
