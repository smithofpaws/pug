# Smoke — 0001-ordem-prioridade-grade-horarios

Executado em 2026-08-22. Godot 4.7.1, GL Compatibility.
Ambiente de dados: `dados/` da máquina do usuário contém dados **reais**
(`hist.csv`, `email.csv`, `planejamento.csv`, `horarios.txt`/`.ini`) e
`arquivos/oferta/` contém nomes reais de docentes. Por isso **nenhuma captura de
tela foi feita** — ver seção LGPD.

## Por que não há PNG

O próprio card declara `Smoke scenarios: Nenhum` — AC1, AC2 e AC3 são
`verify: headless` (a prova é o teste GUT, não uma imagem) e AC4 é
`verify: manual`. Não existe, portanto, nenhum cenário visual que este smoke
devesse capturar. Além disso, mesmo que houvesse, o AC4 exige clicar em um
aluno e carregar um formulário de ajuste — interação de mouse que a skill
proíbe automatizar — e a pasta `dados/` da máquina não está com fixtures
fictícias (está com dados reais de produção, que agentes não devem ler nem
usar para navegar o programa). As duas condições para capturar o AC4 (input
manual + dados fictícios) estão fora do alcance deste smoke.

| AC | Método | Cenário | Evidência | Veredito |
|---|---|---|---|---|
| AC1 | headless | `determinar_horarios` com `condicoes` embaralhado ⇒ célula na ordem canônica | `test/unit/test_analise_horarios.gd::test_determinar_horarios_concatena_na_ordem_canonica` | passou |
| AC2 | headless | `ajuste_incluir` antes de `ajuste_excluir`, ambas antes de qualquer outra condição | `test/unit/test_analise_horarios.gd::test_ordenar_condicoes_poe_ajuste_primeiro` | passou |
| AC3 | headless | Condição desconhecida fica no fim, com `[shake]` preservado | `test/unit/test_analise_horarios.gd::test_condicao_desconhecida_fica_no_fim_com_shake` | passou |
| AC4 | manual | Modo ajuste: pedida de inclusão aparece primeiro, fundo verde | roteiro abaixo | não verificado |

Reexecutei a suíte de forma independente (não apenas confiei no `review.md`):
`python .tools/run_tests.py` → 13/13 testes passando (8 em
`test_analise_horarios.gd`, incluindo os três da tabela acima; 5 pré-existentes
em `test_general_functions.gd`).

## Verificação de boot (runtime, não apenas parser)

Guardrails e o `--editor --quit` são checagens de lint/parser, não a asserção
de log em runtime que a skill pede. Por isso rodei também o programa (modo
jogo, não editor) via MCP `godot`:

1. `run_project` → aguardei ~6s para estabilizar o boot.
2. `get_debug_output` → sem navegar para nenhum módulo (boot puro; a tela
   inicial não expõe dado de aluno/docente).
3. `stop_project`.

**Resultado:** zero `push_error`, zero `SCRIPT ERROR`, zero `Parse Error`. Os
avisos presentes (~40) são todos pré-existentes e alheios a este card:
warnings estáticos de `reload` (variável sombreando função, divisão inteira,
parâmetro não usado) espalhados por vários arquivos que este card não tocou, e
avisos de `VALIDACAO JSON` sobre tipos em `base_config.json`
(`interface.tamanho_janela.largura/altura` como float, alguns `delimitadores`
como String) — mesmo padrão de divergência de schema já visto antes desta
mudança. Conferi especificamente `analise_horarios.gd:286` e `:318`
(`num_str` não usado, parâmetros sombreando função) contra o diff: ambos caem
em código **não tocado** por este card (`_obter_turmas`/`_preparar_horarios`
preexistentes; só mudaram de linha por causa do código novo inserido acima).
Nenhum nome de aluno ou docente aparece no log — a tela inicial não chega a
ler os CSVs de `dados/saida/` além de registrar os diretórios configurados.

**Escopo honesto desta verificação:** é um boot sem navegação — não exercita
`determinar_horarios` (isso exige selecionar um aluno em Situação de Alunos ou
Situação de Disciplinas). Ela cobre erro de carregamento/tipagem em tempo de
load (relevante aqui: `CONDICOES_AJUSTE` é `const Array[String]` e
`ordenar_condicoes`/`_prioridade_condicao` são `static` — um erro de tipagem
nessas declarações apareceria já no `reload`/parse), mas não prova a ordenação
em si. A ordenação está provada pelos três testes headless da tabela acima.

Como o boot já saiu limpo (sem `push_error`/`SCRIPT ERROR`/`Parse Error`
novos), não houve necessidade de rodar um baseline `git stash` para
comparação — não há nada de novo para atribuir à mudança.

## LGPD

- Nenhum PNG foi gerado (sem cenário visual dentro do alcance deste smoke).
- O log de boot foi conferido antes de citá-lo aqui: nenhum nome, matrícula ou
  e-mail real aparece nas linhas reproduzidas acima (só caminhos de diretório
  e avisos de código/schema).
- `dados/` e `arquivos/oferta/` não foram lidos por este agente — apenas
  listados por nome de arquivo (`ls`) para confirmar que contêm dados reais e,
  portanto, que nenhuma navegação de UI deveria acontecer com eles presentes.

## Não foi possível verificar

- **AC4** exige clique (selecionar aluno, carregar respostas de ajuste) —
  fora do alcance de automação desta skill — **e** dados fictícios em
  `dados/`, que a máquina não tem no momento (tem dados reais de produção).
  Roteiro (copiado da spec, `Cards/0001-ordem-prioridade-grade-horarios/spec.md`
  § "Roteiro manual (AC4)"), para o dev rodar manualmente:

  Pré-condição LGPD: `dados/` **apenas com fixtures fictícias** (hist.csv,
  horarios.txt, horarios.ini e respostas de ajuste inventados). Nenhuma
  captura de tela com dado real; se uma imagem for anexada ao card, só com
  dados fictícios.

  1. Abrir o PUG com as fixtures; módulo **Situação de Alunos**; selecionar o
     aluno fictício.
  2. Carregar as respostas do formulário de ajuste contendo, para esse aluno,
     um pedido de **inclusão** de uma disciplina e um de **exclusão** de
     outra, ambas com aula no mesmo dia/horário de uma disciplina em outra
     condição (para as três dividirem a célula).
  3. Conferir na célula da grade de horários: a disciplina pedida para
     inclusão aparece **primeiro**, com fundo verde
     (`FUNDO_AJUSTE_INCLUIR`); a de exclusão em seguida, com fundo
     vermelho; as demais condições depois, na ordem do base_config.
  4. Alternar toggles do seletor de condições em ordens diferentes e
     reanalisar: a ordem na célula não muda.

  Registrar o resultado no `card.md` ao fechar (AC4 permanece `[ ]` até o dev
  confirmar).
