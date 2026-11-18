---
id: 0011-compartilhadas-horarios-txt
title: Disciplina compartilhada do horarios.txt casa com o card do planejamento
status: in_progress
origin: novo (defeito relatado: AL0015, AL0019 e AL0022 não aparecem na grade do Planejamento de horário)
layers: [standalone_scripts/io/arquivos_planejamento.gd, scenes/Modulos/PlanejamentoHorario]
interviewed: true
---

# 0011 - Disciplina compartilhada do horarios.txt casa com o card do planejamento

## Goal
No **Planejamento de horário**, ao abrir o `planejamento.csv` e depois o
`horarios.txt`, a disciplina ofertada para mais de um curso (semestre
`EC03;EMExtra`, `EE03;EC03`…) passa a ocupar a grade **no card que o
planejamento já criou para ela**. Hoje ela vira um card-fantasma ou é
descartada, e o card verdadeiro fica pendente. O mesmo vale para o
**Atualizar planejamento**, que hoje perde a sala e o horário dela.

## Contexto: por que hoje não casa
Os dois arquivos gravam o semestre da compartilhada do mesmo jeito (a oferta
combinada, ex.: `EC03;EMExtra`), mas o programa lê esse campo de dois jeitos:

| | `planejamento.csv` (`FileHandling.carregar_planejamento`) | `horarios.txt` (`ArquivosPlanejamento.preparar_alocacoes_do_txt`) |
|---|---|---|
| Chave do card | uma por **parte**: `al0015_ec03` | o campo **inteiro**: `al0015_ec03;emextra` |
| Filtro de curso | `semestre_casa_prefixos`: **qualquer parte** | `begins_with`: só o **começo** do campo |

Daí saem dois defeitos, medidos rodando o código real sobre os arquivos do dev
de 2026-11-18 (curso EC):

1. **A chave não casa.** AL0015, AL0019, AL0002, AL0381 e AL0394 viram um card
   extra com a chave do campo inteiro. O card do planejamento fica em "4 h
   pendente". Como o card extra não está no `_planejamento_csv`, **Salvar e
   Enviar não levam essas alocações**, e elas somem ao reabrir.
2. **O filtro descarta a linha.** AL0022 (`EE03;EC03`), AL0390
   (`EA09;EE09;EM09;ET03;EC07`) e AL0142 (`EA07;EE09;EC09;ET09`) nem chegam à
   grade, porque `EC` não está no começo do campo.

`mesclar_planejamento_com_horarios_txt` (botão **Atualizar planejamento**)
monta a chave do txt do mesmo jeito. Por isso a compartilhada perde
sala/dia/horário e é listada como "removida".

## Regra acordada
Uma linha do `horarios.txt` tem o código `C` e o campo de semestre `S`.

1. **Partes.** `S` é dividido pelos mesmos delimitadores do `planejamento.csv`
   (`base_config.json:delimitadores.planejamento`), com as bordas aparadas e sem
   diferenciar caixa.
2. **Filtro de curso.** A linha entra quando **alguma** parte casa com os
   prefixos dos cursos selecionados, igual ao CSV.
3. **Card que recebe.** O card que recebe é o da **primeira parte, na ordem do
   campo do txt**, que passa no filtro e tem card existente com a chave
   `C_<parte>`. Só esse card recebe a alocação (decisão do dev: com vários
   cursos carregados, os demais cards da mesma oferta ficam pendentes).
4. **Chaves duplicadas.** O `planejamento.csv` pode gerar `C_<parte>_2`,
   `_3`… para a mesma disciplina e parte. Entre elas, recebe a de oferta com as
   **mesmas partes** de `S` (sem considerar ordem, espaço ou caixa). Se nenhuma
   tiver, recebe a chave base.
5. **Sem card.** Quando nenhuma parte tem card, cria-se um card novo, como
   hoje, mas com chave `C_<1ª parte que passa no filtro>`, semestre = essa parte
   e oferta = `S` inteiro. É o mesmo formato que o CSV produziria.

## Non-goals
- **Exportação do `horarios.txt`** (`exportar_horarios_ref` e as linhas
  escritas pelo Atualizar planejamento) continua gravando só o semestre do card
  (`EC03`), sem a oferta combinada. Decisão do dev: não importa para quem lê o
  arquivo depois.
- **Alocar em todos os cards da oferta** quando vários cursos estão carregados.
  Isso exigiria mudar o detector, que hoje acusaria choque de professor e de
  sala dentro da própria célula.
- **Import de referência** (horarios.txt de outro curso) não muda. A
  compartilhada continua entrando como referência, inclusive com a origem
  deduzida pela 1ª parte do campo, como hoje.
- Não trata **divergência de dado** entre os arquivos. Exemplo: AL0375 está
  como `EM03;ECExtra` no CSV e só `EM03` no txt. Ela segue pendente para a EC,
  e é o comportamento correto.
- Não trata as linhas duplicadas do CSV que geram card com CH 0
  (`al0390_ec07_2`, `al0142_ec09_2`). Elas continuam existindo.
- **Fluxos JSON e servidor** (Abrir planejamento.json, Baixar do servidor) não
  mudam: o JSON já grava uma disciplina por parte. Um `planejamento.json` salvo
  antes da correção **não** é reparado; para recuperar as alocações,
  reimporte o `horarios.txt`.
- Sem UI nova, sem token de cor novo, sem leitura de arquivo nova.

## Acceptance criteria
- [ ] Com card `al0015_ec03` existente e prefixos `["ec"]`, as 4 linhas `EC03;EMExtra` da `AL0015` saem com chave `al0015_ec03`, e `cards_novos` não traz a `al0015` -- verify: `headless`
- [ ] Com prefixos `["ec"]`, a linha `EE03;EC03` da `AL0022` **não** é descartada e sai com a chave do card `al0022_ec03` -- verify: `headless`
- [ ] Campo com espaços e caixa mista (`EA09; ee09 ;EC07`) casa com o card `al0390_ec07` -- verify: `headless`
- [ ] Linha sem nenhuma parte nos prefixos (`EE01;EM01` com `["ec"]`) continua descartada -- verify: `headless`
- [ ] Vários cursos: com os cards `al0022_ee03` e `al0022_ec03`, prefixos `["ec", "ee"]` e a linha `EE03;EC03`, só `al0022_ee03` recebe a alocação -- verify: `headless`
- [ ] Chaves duplicadas: com `al0390_ec07` (oferta `EA09;EE09;EC07`) e `al0390_ec07_2` (oferta `EC07`), a linha `EA09;EE09;EC07` vai para `al0390_ec07` e a linha `EC07` vai para `al0390_ec07_2` -- verify: `headless`
- [ ] Sem card no planejamento: as linhas `EC03;EMExtra` da `AL0015` geram **um** card novo com chave `al0015_ec03`, semestre `EC03`, oferta `EC03;EMExtra` e CH igual ao número de linhas (4) -- verify: `headless`
- [ ] Não-regressão: a linha não compartilhada `EC07` da `AL0395` continua com chave `al0395_ec07` -- verify: `headless`
- [ ] Não-regressão do import de referência: chamado como `_aplicar_referencia_txt` o chama e com o card próprio `al0019_ec03` existente, a linha `EC03;EE03;ET03;EM03` **não** se anexa ao card próprio. Ela continua chegando como disciplina nova, para entrar como referência e manter o aviso de compartilhada divergente -- verify: `headless`
- [ ] Ida e volta: depois de aplicar as alocações resolvidas, `exportar_planejamento_json` traz a `al0015` com as 4 alocações -- verify: `headless`
- [ ] Atualizar planejamento: com o card `al0015_ec03` no planejamento e 4 linhas `EC03;EMExtra` no txt (com sala, dia e horário), `mesclar_planejamento_com_horarios_txt` preserva sala/dia/horário nas 4 entradas, e `removidas` não contém a `al0015` -- verify: `headless`
- [ ] A suíte existente (`python .tools/run_tests.py`) continua passando -- verify: `headless`
- [ ] Com os dados reais (Abrir planejamento.csv da EC e depois Abrir horarios.txt da EC), AL0015, AL0019, AL0022, AL0002, AL0381, AL0394, AL0390 e AL0142 aparecem na grade nas suas células, os cards ficam completos, não surge card duplicado delas e o diálogo "Disciplinas do horarios.txt fora do planejamento" não as lista -- verify: `manual`
- [ ] Com os dados reais, depois de Salvar e reabrir pelo Abrir planejamento.json, as alocações dessas disciplinas continuam na grade -- verify: `manual`

## Edge cases
- **Ordem diferente entre os arquivos.** O CSV e o txt nem sempre listam as
  partes na mesma ordem nem com o mesmo espaçamento
  (`EA09; EE09; EM09; ET03; EC07` × `EA09;EE09;EM09;ET03;EC07`). Por isso a
  regra casa **parte a parte** e só compara a oferta inteira (como conjunto)
  para desempatar chaves duplicadas.
- **Contagem de CH do card novo.** Ela usa a chave já resolvida. Todas as
  linhas da mesma disciplina compartilhada somam no mesmo card, e não em um
  card por variante de `S`.
- **Linha de cabeçalho/vazia** (disciplina `" "`): continua ignorada.
- **Turma** (`T20;80`) não participa da regra; não muda.
- **`ECExtra` como parte**: casa com o prefixo `ec` e com a chave
  `C_ecextra`, que é como o CSV a grava.
- **Identidade é a chave**: a alocação carrega a `chave_planejamento` do card
  resolvido, nunca só código+semestre (memória do projeto).
- **Arquivo ausente**: nada muda; os caminhos de "não encontrado" seguem como
  estão.

## Smoke scenarios
Nenhum. A lógica está em `ArquivosPlanejamento` (`standalone_scripts/io`),
testável headless com fixtures **fictícias** em `test/fixtures/` (códigos de
disciplina públicos, professores fictícios como `Maria da Silva Souza`). A
conferência na tela depende dos dados reais de oferta do dev, então fica nos
dois ACs `manual` e não vira PNG.
