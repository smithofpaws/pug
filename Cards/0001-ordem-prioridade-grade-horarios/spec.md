# Spec — 0001-ordem-prioridade-grade-horarios

Transforma o card em plano executável. Leitura obrigatória antes de codar:
`Cards/0001-ordem-prioridade-grade-horarios/card.md`.

## Resumo da decisão de design

A ordenação canônica entra em **um único ponto de produção**:
`AnaliseHorarios.determinar_horarios`, que é o funil por onde **toda** grade de
horários passa (Situação de Alunos, com e sem modo ajuste, e Situação de
Disciplinas — inclusive a grade consolidada, que concatena grades individuais já
ordenadas). Nenhum módulo de cena muda: `situacao_alunos.gd` pode continuar
anexando `ajuste_incluir`/`ajuste_excluir` no fim do array, porque a análise
reordena. É exatamente o que o card pede ("aplicada dentro de `AnaliseHorarios`")
e elimina a dependência da ordem do chamador pela raiz.

A lógica de ordenação em si é uma **função pura estática** que recebe a lista
canônica por parâmetro — testável headless sem `GV`. A leitura de
`GV.configuracao_base:condicoes` fica confinada a `determinar_horarios`, no mesmo
seam que a classe já usa para `dias_da_semana()`/`horas_das_aulas()` ("valores
universais definidos em base_config.json") — precedente do próprio arquivo.

## Camadas tocadas

| Arquivo | Por quê |
|---|---|
| `standalone_scripts/analise/analise_horarios.gd` | Única mudança de produção: nova função pura `ordenar_condicoes` + aplicação dela em `determinar_horarios`. |
| `test/unit/test_analise_horarios.gd` | **Novo** arquivo de teste GUT (padrão do `.gutconfig.json`: `res://test`, prefixo `test_`). Prova AC1–AC3. |
| `MANUAL.md` § 4.3 "Grade de horários" | Uma frase descrevendo a ordem das disciplinas na célula (pedidas do ajuste primeiro, depois matriculadas, matriculáveis e demais). Regra do projeto: manual acompanha mudança funcional visível. |

O front-matter do card lista `scenes/Modulos/SituacaoAlunos` e
`scenes/Modulos/SituacaoDisciplinas` como camadas — **de propósito, elas não são
editadas**: ambas chamam `determinar_horarios` e herdam a ordem canônica de
graça. Editar os chamadores reintroduziria o defeito (ordem dependente de quem
chama). Duas camadas de produção tocadas: dentro do limite de três.

## Contrato público novo ou alterado

### Novo — `AnaliseHorarios`

```gdscript
## Condicoes sinteticas do Modo Ajuste, em ordem de prioridade. Nao existem em
## base_config.json:condicoes — sao criadas em memoria pelo chamador (hoje
## situacao_alunos.gd) e nunca persistidas.
const CONDICOES_AJUSTE: Array[String] = ["ajuste_incluir", "ajuste_excluir"]

## Ordena [param condicoes] na ordem canonica de prioridade da grade de horarios:
## primeiro as de CONDICOES_AJUSTE (na ordem da constante), depois as presentes em
## [param condicoes_base] (na ordem dela), por fim as desconhecidas, preservando a
## ordem relativa de entrada entre si. Retorna um array NOVO; nao muta a entrada.
static func ordenar_condicoes(condicoes: Array, condicoes_base: Array) -> Array[String]
```

- **Quem chama:** `determinar_horarios` (único chamador de produção) e os testes.
- **O que garante:**
  - retorna array novo (`Array[String]` montado via `assign`); `condicoes` não é
    mutado;
  - ordem total: tier ajuste (`ajuste_incluir` antes de `ajuste_excluir`, apenas
    as presentes na entrada) → tier base (ordem de `condicoes_base`, apenas as
    presentes) → tier desconhecidas (tudo que não está em nenhum dos dois),
    **estável**: desconhecidas mantêm a ordem relativa em que chegaram;
  - duplicatas na entrada são preservadas (comportamento atual: renderizam duas
    vezes — não é papel desta função deduplicar);
  - `condicoes_base` vazio degrada sem crash: só o tier ajuste é reordenado, o
    resto mantém a ordem de entrada (= comportamento atual).
- **O que assume:** elementos são `String` snake_case; `condicoes_base` é a lista
  `base_config.json:condicoes` **injetada pelo chamador** — a função não lê `GV`
  nem arquivo.
- **Armadilha de implementação (obrigatório contornar):** `Array.sort_custom` do
  Godot **não é estável**. Implementar por prioridade explícita — decorar cada
  item com `[prioridade, indice_original]` e ordenar por esse par, ou construir
  por baldes (tier ajuste, tier base por índice, tier desconhecidas na ordem de
  entrada). O teste de estabilidade (duas desconhecidas) pega regressão aqui.

Prioridade sugerida (determinística): `ajuste_incluir` = 0, `ajuste_excluir` = 1,
presente em `condicoes_base` = `2 + indice_na_base`, desconhecida =
`2 + condicoes_base.size()` com desempate pelo índice original. O tier ajuste é
checado **antes** do tier base, então mesmo que alguém um dia inclua
`ajuste_incluir` em `base_config.json:condicoes` (non-goal: não alterar o
base_config), o resultado não muda.

### Alterado (comportamento; assinatura intacta) — `determinar_horarios`

```gdscript
func determinar_horarios(horarios_ini: Dictionary, horarios_txt: Array, disc_cursaveis: Dictionary,\
historico_matricula: Dictionary, condicoes: Array = ["matriculado_agora"], \
lista_cores: Dictionary = {"matriculado_agora": "GREEN"}, forma_apresentacao: String = "somente_codigo", \
codigos_incluir: Array = [], codigos_excluir: Array = []) -> Array
```

Antes de chamar `_preparar_horarios`, aplica:

```gdscript
var condicoes_ordenadas: Array = ordenar_condicoes(condicoes, \
GV.configuracao_base.get("condicoes", []))
```

e passa `condicoes_ordenadas` adiante (documentar no doc-comment da função).

- **Garantia nova:** a ordem de concatenação nas células **independe** da ordem
  do array `condicoes` recebido e da ordem de toggle no `SeletorCondicoes`.
- **Efeito colateral removido (intencional):** hoje `_preparar_horarios` faz
  `remove_at` **no array do chamador** ao filtrar condições sem entrada em
  `horarios_txt_condicao` — como os módulos passam
  `$"%Horarios".lista_condicoes_verdadeiras` por referência, o componente de UI
  tinha a própria lista podada por baixo dos panos. Com a ordenação devolvendo um
  array novo, o filtro passa a agir na cópia e `condicoes` do chamador fica
  intacto. Nenhum chamador depende da poda (ela só afetava re-renderizações que
  refariam o mesmo filtro); cobrir com um teste de não-mutação.
- **Sem mudança:** o filtro de condições inválidas em `_preparar_horarios`
  continua existindo (edge case do card "condição sem entrada segue no-op"),
  agora operando sobre a cópia ordenada; BBCode, cores, `[shake]` para condição
  sem cor e `[bgcolor]` do ajuste ficam como estão (non-goal).

`_preparar_horarios` (privada) não muda de assinatura; apenas recebe o array já
ordenado.

## Invariantes

1. **LGPD** — não toca dado pessoal: nenhuma rede, log, exportação ou arquivo
   novo. Fixtures de teste 100% fictícias e **sem nomes de pessoa** (entradas de
   `horarios_txt` só precisam de `disciplina`/`turma`/`dia`/`horario`;
   `historico_matricula` de teste usa `{"nomedoaluno": "aluno ficticio",
   "dados": []}`). Nenhum arquivo gitignorado novo → `exclude_filter` dos presets
   fica intacto.
2. **snake_case interno** — as chaves de condição já são snake_case; a ordenação
   compara identificadores crus, nenhuma formatação de UI entra na análise.
3. **Chaves canônicas** — a fonte da ordem 2–4 é `base_config.json:condicoes`
   lida de `GV.configuracao_base` (que o main carregou); **nenhuma lista de
   condições é duplicada em código**. `CONDICOES_AJUSTE` não duplica o
   base_config: são chaves sintéticas que nunca existiram lá (e o non-goal do
   card proíbe adicioná-las).
4. **Leitura de arquivo no main** — nenhum `FileAccess` novo; `determinar_horarios`
   lê `GV.configuracao_base` no mesmo seam já usado por `dias_da_semana()` no
   mesmo arquivo (o guardrails `filesystem-boundary` não é acionado). A lógica
   nova em si (`ordenar_condicoes`) é pura e recebe tudo por parâmetro.
5. **UI pelas fachadas** — nenhuma UI tocada; tokens de cor, `DicaFlutuante` e
   `PaletaSemantica` intactos.

## Mapeamento AC → prova

| AC do card | Método | Onde |
|---|---|---|
| AC1 — condições embaralhadas em `determinar_horarios` ⇒ célula na ordem canônica | headless | `test/unit/test_analise_horarios.gd::test_determinar_horarios_concatena_na_ordem_canonica` |
| AC2 — `ajuste_incluir` antes de `ajuste_excluir`, ambas antes de qualquer outra | headless | `test/unit/test_analise_horarios.gd::test_ordenar_condicoes_poe_ajuste_primeiro` (função pura, entrada embaralhada) |
| AC3 — condição desconhecida no fim, `[shake]` preservado | headless | `test/unit/test_analise_horarios.gd::test_condicao_desconhecida_fica_no_fim_com_shake` (via `determinar_horarios`: posição **e** marcação) |
| AC4 — visual modo ajuste: pedida de inclusão primeiro, fundo verde | manual | Roteiro na seção "Roteiro manual (AC4)" abaixo; registrar o resultado no card ao fechar |

Testes de suporte (não mapeiam AC, protegem o design):

- `test_ordenar_condicoes_e_estavel_para_desconhecidas` — duas desconhecidas
  mantêm ordem relativa (pega a armadilha do `sort_custom` instável);
- `test_ordenar_condicoes_nao_muta_entrada` e
  `test_determinar_horarios_nao_muta_condicoes_do_chamador` — garantia de
  não-mutação (fim da poda de `lista_condicoes_verdadeiras`);
- `test_ordenar_condicoes_com_base_vazia_nao_crasha` — degradação sem crash.

### Desenho da prova headless (fixtures)

O harness GUT roda com `--path .`, então o autoload `GV` existe, mas
`GV.configuracao_base` está **vazio** (o `main.gd` não roda). O teste de AC1/AC3:

- `before_each`: guarda `GV.configuracao_base` num membro e injeta um dicionário
  fictício com `dias_semana: ["segunda"]`, `horarios_aula: ["07:30"]` e
  `condicoes: [<as 12 da lista canônica>]`; `after_each`: restaura o original
  (não vazar estado para outros testes).
- `horarios_txt`: 6 entradas, todas em `segunda`/`07:30` (a mesma célula), com
  `disciplina` no formato do horarios.txt — ex. `"Disciplina Quatro (al0004)"` —
  e `turma: "T10"`. Sem professor/sala: chaves não usadas pelo caminho testado.
- `disc_cursaveis` (embaralhado de propósito na ordem das chaves e no array
  `condicoes` passado): `{"seaprovado": ["al0003"], "ajuste_excluir": ["al0005"],
  "condicao_futura": ["al0009"], "matriculavel": ["al0001"],
  "ajuste_incluir": ["al0004"], "matricula_irregular": ["al0002"]}`.
  Usa `matricula_irregular` como representante do tier "matriculadas" porque
  `matriculado_agora` exige linhas de histórico com turma casada
  (`matriculada_com_turma`) — o tier 2 via `matriculado_agora` fica coberto pelo
  teste puro de AC2, onde a lista completa entra sem fixture de histórico.
- `historico_matricula`: `{"nomedoaluno": "aluno ficticio", "dados": []}` —
  `matriculada_com_turma` devolve vazio com segurança e todas as condições fluem
  pelo ramo `disc_cursaveis` de `extrair_horarios_txt`.
- `lista_cores`: todas as condições da fixture **exceto** `condicao_futura`
  (para o `[shake]` de AC3); `condicoes` passado embaralhado:
  `["seaprovado", "ajuste_excluir", "condicao_futura", "matriculavel",
  "ajuste_incluir", "matricula_irregular"]`.
- Asserções por posição na string da célula `matriz[1][1]` (via `find`):
  `AL0004 < AL0005 < AL0002 < AL0001 < AL0003 < AL0009`; AC3 ainda exige
  `AL0009` embrulhado por `[shake rate=20.0 level=10]...[/shake]` e por último.

### Roteiro manual (AC4)

Pré-condição LGPD: `dados/` **apenas com fixtures fictícias** (hist.csv,
horarios.txt, horarios.ini e respostas de ajuste inventados). Nenhuma captura de
tela com dado real; se uma imagem for anexada ao card, só com dados fictícios.

1. Abrir o PUG com as fixtures; módulo **Situação de Alunos**; selecionar o
   aluno fictício.
2. Carregar as respostas do formulário de ajuste contendo, para esse aluno, um
   pedido de **inclusão** de uma disciplina e um de **exclusão** de outra, ambas
   com aula no mesmo dia/horário de uma disciplina em outra condição (para as
   três dividirem a célula).
3. Conferir na célula da grade de horários: a disciplina pedida para inclusão
   aparece **primeiro**, com fundo verde (`FUNDO_AJUSTE_INCLUIR`); a de exclusão
   em seguida, com fundo vermelho; as demais condições depois, na ordem do
   base_config.
4. Alternar toggles do seletor de condições em ordens diferentes e reanalisar: a
   ordem na célula não muda.

## Riscos de contrato de dados

- **Nenhuma chave nova, renomeada ou remodelada.** `base_config.json` não muda
  (non-goal do card); a lista `condicoes` é apenas **lida** — e já era o contrato
  documentado de `AnaliseHorarios` ("Formato de [param condicoes] deve ser a
  lista de condições no arquivo base_config.json").
- `ajuste_incluir`/`ajuste_excluir` continuam sendo chaves **em memória**, nunca
  gravadas em JSON, CSV, Kinto ou exportação — a const `CONDICOES_AJUSTE` só
  formaliza a grafia que `situacao_alunos.gd` já usa.
- **LGPD:** a feature não cria tela, exportação, log nem tráfego novo; só muda a
  ordem de concatenação de um texto que já existia. Superfície de dado pessoal:
  nenhuma. Fixtures de teste sem nomes reais (ver acima).
- Sem risco de float/int: a ordenação compara apenas strings de condição.

## Ordem de implementação

Cada passo termina com a suíte verde (`python .tools/run_tests.py`).

1. **Teste puro (vermelho):** criar `test/unit/test_analise_horarios.gd` com os
   testes de `ordenar_condicoes` (AC2, estabilidade, não-mutação, base vazia).
   Rodar a suíte e ver falhar pela função inexistente.
2. **Implementação mínima (verde):** adicionar `CONDICOES_AJUSTE` e
   `ordenar_condicoes` em `analise_horarios.gd` (função pública estática, antes
   das privadas, doc `##`, tipagem completa — FORMATACAO.md; sem `sort_custom`
   puro — ordenar por `[prioridade, indice_original]` ou por baldes).
3. **Teste de integração (vermelho):** acrescentar os testes via
   `determinar_horarios` (AC1, AC3, não-mutação do array do chamador), com o
   backup/restauração de `GV.configuracao_base` no `before_each`/`after_each`.
4. **Ligação (verde):** aplicar `ordenar_condicoes` em `determinar_horarios`
   antes de `_preparar_horarios`, atualizando o doc-comment (ordem canônica +
   não-mutação de `condicoes`).
5. **Portões:** `python .tools/guardrails.py`, `python .tools/run_tests.py` e
   `"C:/Program Files/Godot/Godot_console.exe" --headless --path . --editor --quit`
   (não usar `--check-only` isolado — falso positivo de autoload).
6. **Manual:** uma frase em `MANUAL.md` § 4.3 "Grade de horários" descrevendo a
   ordem das disciplinas na célula.
7. **AC4:** executar o roteiro manual com fixtures fictícias e registrar o
   resultado no card.
