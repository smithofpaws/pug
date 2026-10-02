# Spec — 0007-aviso-turma-sem-correspondencia-horarios

Card: `Cards/0007-aviso-turma-sem-correspondencia-horarios/card.md`.

Objetivo: ao abrir **Situação de Alunos**, o programa passa a avisar uma vez,
num diálogo, as matrículas atuais cuja turma do `hist.csv` não casa com
nenhuma turma da mesma disciplina no `horarios.txt`. O casamento **não muda**:
a grade continua mostrando essas aulas como "Matriculável". A regra de
casamento sai do corpo de `extrair_horarios_txt` para um helper privado único.
A grade e o aviso passam a chamar esse helper, e assim não divergem.

## Camadas tocadas

| Arquivo | Por quê |
|---|---|
| `standalone_scripts/analise/analise_horarios.gd` | Núcleo. Ganha duas funções públicas puras (`matriculadas_com_turma_por_discente` e `turmas_sem_correspondencia`) e dois helpers privados (`_turma_casa` e `_indexar_turmas_txt`). `extrair_horarios_txt` passa por um **refactor sem mudança de comportamento**: o bloco inline das linhas 234–244 (`_obter_turmas` dos dois lados + laço duplo de `_comparar_turmas`) vira uma chamada a `_turma_casa`. `_comparar_turmas`, `_partir_turma` e `_obter_turmas` ficam byte a byte iguais. |
| `test/unit/test_analise_horarios.gd` | A suíte que já cobre `extrair_horarios_txt` e `_comparar_turmas` (19 testes). Recebe os testes dos ACs 1–11 e três testes de apoio, com fixtures sintéticas inline. Nenhum teste existente é editado. |
| `scenes/Modulos/SituacaoAlunos/situacao_alunos.gd` | Adaptador de UI. Duas funções privadas novas (`_avisar_turmas_sem_correspondencia` e `_rotulo_turma_sem_correspondencia`). O `_ready` ganha **uma** linha: a chamada adiada logo depois de `_rodar_análise()`. Não lê arquivo novo: usa o `_historico`, o `_condicoes_discentes` e o `_horarios_txt` que o módulo já tem. |
| `MANUAL.md` | §4.3 ganha a subseção do aviso (AC16, regra "Manual" do `AGENTS.md`). |

São três camadas de código (núcleo, teste e adaptador de UI) mais a
documentação, dentro do limite. Fica fora do diff, de propósito:

- **`scenes/main.gd`.** Nenhuma leitura nova e nenhuma injeção nova. O histórico
  e as condições já chegam pelo cache `GV.dados_discentes`. O `horarios.txt`
  continua sendo lido pelo próprio módulo (`situacao_alunos.gd:190`). Essa
  dívida é anterior e está congelada; o card proíbe ler arquivo novo, e mover
  essa leitura não faz parte dele.
- **`standalone_scripts/analise/analise_curricular.gd` / `analise_historico.gd`.**
  `matriculada_com_turma` é **reusada sem mudança**. É ela que define o que
  conta como matrícula atual (`situacao` começando com `matr`) e que deduplica
  por código. O aviso herda essa regra chamando a função, sem copiá-la.
- **`scenes/Modulos/Exportadores/exportadores.gd`.** Chama `extrair_horarios_txt`
  (linhas 625–626) e herda o refactor, que não muda comportamento. O relatório
  de choques não ganha aviso (non-goal).
- **`base_config.json`, `arquivos/*`, `dados/*`, Kinto.** Nenhuma chave nem
  formato é tocado.
- **`_rodar_análise` / `_analisar_matricula`.** Não são tocadas. É isso que
  garante que trocar de aluno ou de curso não reabre o diálogo (AC14).

## Contrato público novo ou alterado

Tudo em `AnaliseHorarios`, como métodos de instância, porque dependem de
`analise_historico`, de `horariosexe` e de `_obter_turmas`, que são de
instância. Os métodos públicos ficam logo depois de `extrair_horarios_txt` e
antes de `_comparar_turmas` (FORMATACAO.md §2: públicas antes das privadas; o
guardrail `section-order` cobra isso). Documentação `##` nos públicos e `#`
nos privados.

### `matriculadas_com_turma_por_discente`

```gdscript
func matriculadas_com_turma_por_discente(historico: Dictionary, condicoes_discentes: Dictionary) -> Dictionary
```

- **Quem chama:** `situacao_alunos.gd::_avisar_turmas_sem_correspondencia`, com
  `_historico` e `_condicoes_discentes`. Os testes também chamam.
- **O que garante:** devolve `{ "<matricula>": <saída de matriculada_com_turma> }`
  para **toda** chave de `historico`, sem filtro de curso. Cada valor é
  exatamente
  `analise_historico.matriculada_com_turma(condicoes_discentes.get(matricula, {}), historico[matricula])`,
  ou seja `{"matriculado_agora": [[cod, turma], ...], "matriculado_agora_aproveitamento": [[cod, turma], ...]}`.
  Discente sem matrícula atual aparece com as duas listas vazias. Discente
  ausente de `condicoes_discentes` aparece com tudo em
  `matriculado_agora_aproveitamento` (comportamento documentado de
  `matriculada_com_turma` com `disc_cursaveis` vazio).
- **O que assume do chamador:** `historico` no formato simplificado do cache
  (`{matricula: {"nomedoaluno", "dados": [...]}}`). Não muta `historico` nem
  `condicoes_discentes`. Os dois são o cache compartilhado
  `GV.dados_discentes`, que outros módulos reaproveitam.
- **Por que existe:** fixa no núcleo testável a decisão de usar **todos os
  discentes do histórico** (edge case "Quem entra na conta") e a mesma chamada
  que a grade usa. Sem ela, o laço ficaria no módulo e poderia percorrer
  `_lista_alunos`, que é filtrada pelo curso, sem que nenhum teste visse.
- O retorno tem matrícula como chave. Ele vive só em memória, é consumido na
  hora por `turmas_sem_correspondencia` e não é guardado em membro, impresso
  nem exportado.

### `turmas_sem_correspondencia`

```gdscript
func turmas_sem_correspondencia(horarios_txt: Array, matriculadas_por_discente: Dictionary) -> Array[Dictionary]
```

- **Quem chama:** `situacao_alunos.gd::_avisar_turmas_sem_correspondencia`. Os
  testes também chamam.
- **Entrada:** `horarios_txt` no formato de
  `HorariosExe.carregar_horarios_txt` (só lê as chaves `disciplina` e `turma`)
  e `matriculadas_por_discente` no formato de retorno de
  `matriculadas_com_turma_por_discente`.
- **Algoritmo (contrato, não implementação):**
  1. Indexa `horarios_txt` por código uma única vez (`_indexar_turmas_txt`).
     Linha cujo código extraído é vazio fica fora do índice.
  2. Para cada matrícula e cada par `[cod, turma]` das **duas** chaves
     (`matriculado_agora` e `matriculado_agora_aproveitamento`, avaliadas da
     mesma forma, conforme o AC7), com `codigo := str(cod)` e
     `turma_historico := str(turma)`:
     - código vazio ou ausente do índice → **ignora**. É o non-goal "disciplina
       sem nenhuma linha no txt" (AC6).
     - alguma turma do índice daquele código satisfaz
       `_turma_casa(turma_txt, turma_historico)` → casou, ignora.
     - nenhuma satisfaz → a matrícula entra no grupo
       `(codigo, turma_historico)`.
  3. Cada grupo vira um item. A contagem é de **matrículas distintas**: o mesmo
     discente repetido no mesmo grupo (fan-out, ou o par presente nas duas
     chaves) conta uma vez (AC4).
- **Retorno:** `Array[Dictionary]`, um item por `(codigo, turma_historico)`,
  com chaves em snake_case:

  | Chave | Tipo | Conteúdo |
  |---|---|---|
  | `codigo` | `String` | código como veio de `matriculada_com_turma` (minúsculo pela leitura) |
  | `nome` | `String` | `horariosexe.extrair_nome_horarios_txt` da **primeira** linha do txt com esse código |
  | `turma_historico` | `String` | turma do `hist.csv` crua, `""` se vazia (AC8) |
  | `turmas_txt` | `Array[String]` | turmas **distintas** das linhas do txt com esse código, cruas, em `sort()` ascendente |
  | `discentes` | `int` | nº de matrículas distintas no grupo, ≥ 1 |

  Ordenação: `codigo` ascendente e, no empate, `turma_historico` ascendente
  (comparação `<` de `String`, AC10). Não há empate entre itens, porque o par
  é único, então a instabilidade do `sort_custom` não importa.
- **O que garante:** é pura, sem `FileAccess`, sem `GV`, sem nó e sem `print`.
  É determinística e não muta nenhuma entrada. **Nenhum item carrega matrícula,
  nome ou qualquer dado de discente**, só o código, o nome da disciplina, as
  turmas e a contagem (non-goal "Não lista discentes"). Com `horarios_txt`
  vazio, ou sem nenhum par, devolve `[]` (AC9).
- **Coerência com a grade (AC11), o enunciado exato.** Sejam
  `disc := {"matriculado_agora": [], "matriculado_agora_aproveitamento": [], "matriculavel": []}`
  e `res_m := extrair_horarios_txt(horarios_txt, matriculadas_por_discente[m], disc)`.
  Para toda matrícula `m`, toda condição `cond` das duas chaves e todo par
  `[cod, turma]` de `matriculadas_por_discente[m][cond]` com `cod` não vazio:

  > existe item com `codigo == cod` e `turma_historico == str(turma)`
  > **⇔** `cod` tem ≥ 1 linha em `horarios_txt` **e** `res_m[cond]` não tem
  > nenhuma linha de `cod`.

  E, para todo item, `discentes` é igual ao número de matrículas distintas que
  satisfazem o lado direito para aquele `(codigo, turma_historico)`.

  **Leitura do AC11 do card:** o card diz "entra num item **se e somente se**
  `extrair_horarios_txt` não põe nenhuma linha". Lida ao pé da letra, a frase
  contradiria o AC6: disciplina sem linha no txt também fica sem linha na
  condição e, mesmo assim, não gera item. O conjunto "`cod` tem ≥ 1 linha no
  txt" é o que concilia os dois ACs. Não muda o escopo, só torna o enunciado
  verificável.

### Privados novos em `AnaliseHorarios`

```gdscript
func _turma_casa(turma_txt: String, turma_aluno: String) -> bool
```

- **É a regra única de casamento.** Devolve `true` se algum elemento de
  `_obter_turmas(turma_txt)` e algum de `_obter_turmas(turma_aluno)` satisfazem
  `AnaliseHorarios._comparar_turmas`. É o laço duplo que hoje está inline em
  `extrair_horarios_txt`, movido sem alteração.
- **Chamadores:** `extrair_horarios_txt`, que passa as mesmas expressões que
  hoje passa a `_obter_turmas` (`horarios_txt[a].get("turma")` e
  `matriculada_com_turma[key][b][1]`), e `turmas_sem_correspondencia`.
- **Invariante estrutural (metade "sem cópia da regra" do AC11):** depois do
  card, `_obter_turmas(` e `_comparar_turmas(` só são **chamadas** dentro de
  `_turma_casa` em `analise_horarios.gd`. Os testes que chamam
  `_comparar_turmas` direto são de unidade e não contam.

```gdscript
func _indexar_turmas_txt(horarios_txt: Array) -> Dictionary
```

- Devolve `{ "<codigo>": {"nome": String, "turmas": Array[String]} }`, com o
  código vindo de
  `horariosexe.extrair_cod_horarios_txt(str(linha.get("disciplina", "")))`,
  `nome` da primeira linha e `turmas` distintas na ordem de aparição. A
  ordenação final é de `turmas_sem_correspondencia`. Ignora linha com código
  vazio, como a de cabeçalho. Atende ao edge case "Desempenho": cada matrícula
  faz um lookup O(1) e só compara contra as poucas turmas daquela disciplina.

### Privados novos em `SituacaoAlunos`

Ficam antes do primeiro handler `_on_*`, logo depois de `_validar_grade_ativa`
(FORMATACAO.md §2, layout de módulo de cena). Documentação com `#`.

```gdscript
func _avisar_turmas_sem_correspondencia() -> void
```

- Chamada **uma única vez**, no fim do caminho principal do `_ready`, na linha
  logo depois de `_rodar_análise()`, como
  `_avisar_turmas_sem_correspondencia.call_deferred()`. O adiamento evita abrir
  a janela no meio do `_ready` (edge case "Diálogo no `_ready`"). Se o AC13
  mostrar o diálogo com tamanho errado, troca-se por
  `get_tree().process_frame.connect(..., CONNECT_ONE_SHOT)`; o resto não muda.
- Corpo: monta `itens` com
  `analise_horarios.turmas_sem_correspondencia(_horarios_txt, analise_horarios.matriculadas_com_turma_por_discente(_historico, _condicoes_discentes))`.
  Se vier vazio, retorna sem fazer nada (AC15 e o caso do `hist.csv` ausente).
  Se não, chama `Dialogos.escolha_lista`:

  | Parâmetro | Valor |
  |---|---|
  | `pai` | `self`. O diálogo é filho do módulo e morre com ele. |
  | `titulo` | `"Turmas sem correspondência no horarios.txt"` |
  | `cabecalho` | `"Há discentes matriculados em turmas que não aparecem no horarios.txt para a disciplina. Na grade de horários, essas aulas ficam como Matriculável, e não como Matriculada:"` |
  | `itens` | `_rotulo_turma_sem_correspondencia(item)` de cada item, na ordem recebida |
  | `rodape` | `"Provavelmente é a mesma turma numerada de forma diferente. Corrija a numeração no horarios.txt (Horarios.exe) e reabra o módulo."` |
  | `acoes` | `[{"texto": "OK", "ao_acionar": Callable()}]`: um botão, que só fecha |
  | `texto_cancelar` | `""`. O `escolha_lista` esconde o Cancelar (`dialogos.gd:181`). |

  `escolha_lista` e não `avisar` porque a lista pode crescer e precisa rolar
  (AGENTS.md, "Diálogos"). O próprio `escolha_lista` já chama
  `limitar_a_tela`. Não escreve no Terminal (non-goal) e não faz `print`.

```gdscript
static func _rotulo_turma_sem_correspondencia(item: Dictionary) -> String
```

- É onde a formatação acontece, e só aqui (invariante 2): código e turmas em
  `to_upper()` (precedentes: `_mostrar_selecao_disciplinas`, linha 1086, e o
  modo `completo` de `_preparar_horarios`); turma vazia ou só com espaço vira
  `"(sem turma)"`, no histórico e no txt; `"1 discente"` no singular,
  `"N discentes"` no plural. O nome sai como vem do txt, igual a
  `_mostrar_selecao_disciplinas`.
- Modelo: `"• <CODIGO> <nome>: turma <TURMA_HIST> no histórico; no horarios.txt: <TURMA_TXT_1>, <TURMA_TXT_2> (<N> discente[s])"`.
  Exemplo com fixture: `"• AL0037 nome ficticio: turma 20/80 no histórico; no horarios.txt: T30;60, T90 (2 discentes)"`.
  A pontuação exata não é AC. O AC13 confere conteúdo: código, turmas,
  contagem e ausência de dado de discente.
- Usa **só** campos do item. Não consulta `_historico` nem
  `_lista_alunos`. A revisão confere isso.

Regra de dependência preservada: o módulo conhece `AnaliseHorarios`, e
`AnaliseHorarios` continua sem conhecer módulo, nó ou arquivo.

## Invariantes

| Invariante | Como esta feature se comporta |
|---|---|
| **1. Dado pessoal não sai do PC** | O diálogo mostra só dado curricular (código, nome da disciplina e turma) e uma contagem agregada. Nenhum item carrega matrícula ou nome; um teste de apoio congela o conjunto de chaves. Nada vai para o Terminal, log, exportação ou rede. O retorno intermediário com matrícula como chave fica só em memória, dentro de uma chamada. As fixtures são sintéticas: matrículas `"matricula_ficticia_N"`, `nomedoaluno` `"aluno ficticio"`, disciplina `"Nome Ficticio (alNNNN)"`, professores fictícios (`Maria da Silva Souza` e `João Pereira Lima`, só para distinguir linhas no fan-out). Os códigos de disciplina são dado curricular público. Não há PNG de smoke: os ACs visuais são manuais e sem captura, porque o módulo atrás do diálogo mostra nome de aluno. Nenhum arquivo novo na raiz do projeto, então nada a acrescentar no `exclude_filter` dos presets. |
| **2. snake_case interno, formatação só na UI** | Chaves novas: `codigo`, `nome`, `turma_historico`, `turmas_txt`, `discentes` (no item) e `nome`, `turmas` (no índice privado). Os valores internos ficam crus e minúsculos, como a leitura entrega. Maiúsculas, `"(sem turma)"` e singular/plural só aparecem em `_rotulo_turma_sem_correspondencia`, no momento de montar o diálogo. |
| **3. Cursos e chaves canônicas** | Não toca em lista de cursos, chave de grade nem equivalência. O aviso **ignora o filtro de curso de propósito**: a divergência é do arquivo, não do curso. O núcleo itera `historico` inteiro e não consulta `base_config.json:cursos`. |
| **4. Leitura no main/FileHandling; módulo recebe injetado** | Nenhuma leitura nova (guardrail `filesystem-boundary` sem nada a acusar). As funções novas recebem tudo por parâmetro. Com `horarios.txt` ausente, `_horarios_txt` chega `[]` e o núcleo devolve `[]`: sem diálogo e sem crash. Com `hist.csv` ausente, `_historico` e `_condicoes_discentes` chegam `{}` e o resultado é o mesmo. |
| **5. UI pelas fachadas** | O diálogo usa `Dialogos.escolha_lista`, que já faz `limitar_a_tela`. Não há tooltip, cor nova nem token de paleta (non-goal "nem token de cor novo"), e nada envolve `chave_planejamento`. |

## Mapeamento AC → prova

Os ACs `headless` rodam com `python .tools/run_tests.py` (`-gselect=horarios`
para só esta suíte). Os nomes de teste abaixo são contrato para a
implementação. Todos ficam em `test/unit/test_analise_horarios.gd`, sob um
bloco `## Prova o aviso de turma sem correspondência (Cards/0007-...)`.

Os testes dos ACs 1–10 montam `historico` e `condicoes_discentes` fictícios,
passam por `matriculadas_com_turma_por_discente` e depois por
`turmas_sem_correspondencia`, que é o mesmo caminho que o módulo percorre.
Quando o AC depende da classificação, o teste afirma a pré-condição
(ex.: "o par ficou em `matriculado_agora_aproveitamento`") para não ser vácuo.
Cada cenário é um helper privado `_cenario_<nome>() -> Dictionary` com
`{"horarios_txt", "historico", "condicoes_discentes"}`, reusado pelo teste do
AC11.

| AC do card | Método | Onde |
|---|---|---|
| AC1: hist `20` × txt só `T80` gera **um** item com código, turma `20`, `[T80]` e 1 discente | headless | `test_analise_horarios.gd::test_turmas_sem_correspondencia_turma_unica_divergente`. Afirma o item inteiro, incluindo `nome == "Nome Ficticio"`. |
| AC2: composta `20/80` × `T30;60` e `T90` lista as **duas** turmas do txt | headless | `test_analise_horarios.gd::test_turmas_sem_correspondencia_composta_lista_todas_as_turmas_do_txt`. Espera `turmas_txt == ["T30;60", "T90"]` e 2 discentes, o caso AL0037 do card. |
| AC3: sem item quando casa pela regra do 0006 (`20A`×`T20`, `20`×`T20A`, `30/60`×`T30;60`) | headless | `test_analise_horarios.gd::test_turmas_sem_correspondencia_ignora_turma_que_casa_pela_regra_0006`. Inclui como reforço `20/80` × `T80` (só uma parte casa). |
| AC4: dois discentes → um item com 2; fan-out do mesmo discente não infla | headless | `test_analise_horarios.gd::test_turmas_sem_correspondencia_agrupa_discentes_da_mesma_turma` e `::test_turmas_sem_correspondencia_fan_out_nao_infla_contagem`. O segundo usa duas linhas `matr` do mesmo discente, mesma disciplina e turma, diferindo só em `professor` (fan-out que sobrevive à deduplicação de `ler_dados`), e também chama o núcleo direto com o mesmo par repetido nas duas chaves de um discente. Nos dois casos `discentes == 1`. |
| AC5: mesma disciplina, `20` e `40` contra txt só `T80` → **dois** itens | headless | `test_analise_horarios.gd::test_turmas_sem_correspondencia_turmas_distintas_geram_itens_distintos` |
| AC6: disciplina matriculada sem nenhuma linha no txt **não** gera item | headless | `test_analise_horarios.gd::test_turmas_sem_correspondencia_ignora_disciplina_sem_linha_no_txt`. O txt tem linhas de **outra** disciplina, para não confundir com o AC9. |
| AC7: `matriculado_agora_aproveitamento` avaliada como `matriculado_agora` | headless | `test_analise_horarios.gd::test_turmas_sem_correspondencia_avalia_matricula_por_aproveitamento`. Usa dois discentes na mesma divergência, um classificado em cada chave (pré-condição afirmada), e espera um item com 2. |
| AC8: turma vazia no histórico gera item com turma vazia, sem crashar | headless | `test_analise_horarios.gd::test_turmas_sem_correspondencia_turma_vazia_gera_item`. Cobre `codturma: ""` e a chave `codturma` ausente; espera `turma_historico == ""`. |
| AC9: `horarios_txt` vazio ou nenhum matriculado → `[]` | headless | `test_analise_horarios.gd::test_turmas_sem_correspondencia_entradas_vazias_devolvem_lista_vazia`. Cobre txt `[]`, histórico `{}` e histórico só com `aprovado`. |
| AC10: ordenado por código e depois por turma do histórico | headless | `test_analise_horarios.gd::test_turmas_sem_correspondencia_ordena_por_codigo_e_turma`. A entrada vem embaralhada (`al2129`, `al0037 "40"`, `al2126`, `al0037 "20/80"`) e a saída esperada é `al0037 "20/80"`, `al0037 "40"`, `al2126 "20"`, `al2129 "20"`. |
| AC11: coerência com a grade, um item ⇔ nenhuma linha na condição | headless (+ checagem estrutural na review) | `test_analise_horarios.gd::test_turmas_sem_correspondencia_coerente_com_extrair_horarios_txt` itera **todos** os cenários dos ACs 1–10, mais um cenário misto (mesma disciplina, um discente casa e outro não). Para cada um, verifica o enunciado exato da seção "Coerência" contra `extrair_horarios_txt`, com mensagem que nomeia o cenário. A metade "sem cópia da regra" é estrutural: `grep -n "_obter_turmas(\|_comparar_turmas(" standalone_scripts/analise/analise_horarios.gd` só pode mostrar as definições e as chamadas dentro de `_turma_casa`. A `godot-code-review` confere. |
| AC12: os testes existentes de `test_analise_horarios.gd` seguem passando | headless | `python .tools/run_tests.py` verde. Os 19 testes existentes (8 de `ordenar_condicoes`/`determinar_horarios` e 11 do 0006) ficam **sem edição**: o diff do arquivo só acrescenta. Os 4 testes de `extrair_horarios_txt` do 0006 são a rede do refactor de `_turma_casa`. |
| AC13: dados reais 2026/2 → **um** diálogo `escolha_lista` (lista rolável, um botão, sem Cancelar) com AL0037 `20/80` (2), AL2126 `20` (2), AL2129 `20` (1), sem dado de discente | manual | Roteiro R1, abaixo. Executado pelo dev e **sem captura**. Apoio headless da parte LGPD: `test_turmas_sem_correspondencia_item_nao_carrega_dado_de_discente`. |
| AC14: trocar de aluno não reabre; fechar e reabrir o módulo reabre | manual | Roteiro R2. Apoio estrutural: a chamada existe uma única vez, no `_ready`, e `_rodar_análise` não é tocada (a review confere no diff). |
| AC15: `horarios.txt` ausente → abre sem diálogo e sem erro novo no log | manual | Roteiro R3. Apoio headless: AC9, com txt vazio → `[]`. |
| AC16: `MANUAL.md` §4.3 descreve o aviso (quando, o que significa, correção no `horarios.txt`) | manual | Roteiro R4. Conteúdo exigido na seção "Texto do MANUAL.md", abaixo. |

### Testes de apoio (não são ACs; cobrem edge cases do card)

| Edge case / contrato | Teste |
|---|---|
| "Quem entra na conta": todos os discentes, inclusive os ausentes de `condicoes_discentes`; linha não `matr` é ignorada | `test_matriculadas_com_turma_por_discente_inclui_todo_o_historico` |
| Nenhum item carrega dado de discente (apoio ao AC13) | `test_turmas_sem_correspondencia_item_nao_carrega_dado_de_discente`: as chaves de cada item são exatamente `codigo`, `nome`, `turma_historico`, `turmas_txt` e `discentes` |
| Não muta `horarios_txt`, `historico` nem `condicoes_discentes` (cache compartilhado) | `test_turmas_sem_correspondencia_nao_muta_entradas`: compara com `duplicate(true)` feito antes |

### Fixtures (formato)

- `horarios_txt`: linhas `{"disciplina": "Nome Ficticio (al2126)", "turma": "T80"}`,
  como nos testes do 0006. Turmas com `T` maiúsculo, como no card; a
  normalização é de `_obter_turmas`. A saída devolve a turma crua.
- `historico`: `{"matricula_ficticia_1": {"nomedoaluno": "aluno ficticio", "dados": [{"situacao": "matriculado", "codigocurriculo": "al2126", "codturma": "20"}]}}`.
  `situacao` e `codigocurriculo` vêm em minúsculo, como `ler_dados` entrega.
  Uma linha `"aprovado"` aparece onde for preciso provar que só `matr*` conta.
- `condicoes_discentes`: `{"matricula_ficticia_1": {"matriculado_agora": ["al2126"]}}`
  para classificar em `matriculado_agora`; para cair em
  `matriculado_agora_aproveitamento`, basta omitir o código (ou o discente).
- `disc` do teste de coerência: `{"matriculado_agora": [], "matriculado_agora_aproveitamento": [], "matriculavel": []}`.
  As duas chaves de matrícula são obrigatórias, porque `extrair_horarios_txt`
  faz `append` nelas e uma chave ausente quebraria. `matriculavel` vazia
  impede que o segundo laço da função ponha linha por outro caminho.
- Os testes novos não tocam em `GV`. O `before_each` existente continua
  trocando `GV.configuracao_base` sem efeito sobre eles.

## Riscos de contrato de dados

- **Nenhuma chave renomeada e nenhuma chave nova em arquivo.** Nada é gravado.
  As chaves do item e do índice vivem só em memória. `base_config.json`
  (inclusive `histfile` e `horarios_txt`), os JSONs de `arquivos/`, os records
  do Kinto e os formatos do `hist.csv` e do `horarios.txt` não são tocados.
- **Tipos.** As duas fontes são texto (CSV e TXT), então a armadilha do
  número de JSON virar float não se aplica. O núcleo aplica `str()` ao código
  e à turma do par e usa `.get(..., "")` nas linhas do txt. Isso torna o aviso
  robusto a valor ausente. `extrair_horarios_txt` mantém as expressões de hoje
  (`.get("turma")` sem default), e o resultado é idêntico para `String`, que é
  o que as duas leituras produzem. A assimetria só aparece com linha
  malformada sem `turma`: a grade já quebraria hoje, e o aviso não. Isso fica
  registrado para não parecer divergência.
- **O refactor alcança dois consumidores.** `determinar_horarios` (grade da
  Situação de Alunos) e `exportadores.gd:626` (relatório de choques) chamam
  `extrair_horarios_txt`. A mudança é mecânica (mover o laço para
  `_turma_casa`) e é protegida pelos 4 testes de `extrair_horarios_txt` e
  pelos 4 de `determinar_horarios`. O Exportadores não tem teste próprio, mas
  depende só da saída da função, que não muda.
- **Agrupamento pela turma crua.** `"20"` e `"20 "` formariam itens separados.
  Não ocorre nos dados, porque as duas leituras aparam os campos; o risco fica
  registrado.
- **Desempenho.** São centenas de discentes, ~1 chamada de
  `matriculada_com_turma` por discente (a mesma que o Exportadores já faz em
  laço) e um lookup O(1) por matrícula contra as poucas turmas da disciplina.
  Roda uma vez por abertura, não por troca de aluno.
- **LGPD.** O dado pessoal (matrícula e nome) entra pelo `historico`, como
  hoje, e para no núcleo: a saída é agregada. A tela mostra contagem por
  disciplina e turma, inclusive `1`. Fica na tela do coordenador, que já vê
  esse discente no seletor, e não vai para log, exportação ou rede. Nenhum
  dado real em teste, fixture, spec ou card.

## Texto do MANUAL.md (AC16)

Nova subseção `#### Aviso de turmas sem correspondência`, em §4.3, logo
depois de "Grade de horários" e antes de "Modo Ajuste". Ela precisa dizer:

1. **Quando aparece:** ao abrir a Situação de Alunos, uma vez por abertura, se
   algum discente do `hist.csv` (de qualquer curso, independentemente do
   filtro) está matriculado numa turma que não existe no `horarios.txt` para
   aquela disciplina. Trocar de aluno não reabre; sair e voltar ao módulo
   reabre.
2. **O que significa:** o GURI e o `horarios.txt` numeram a turma de forma
   diferente (em geral, é a mesma turma). Enquanto isso, a grade de horários
   mostra essas aulas como **Matriculável**, e não como Matriculada. Turma com
   o mesmo número e só a letra de subturma diferente (`20A` × `T20`) não gera
   aviso, porque já casa.
3. **O que mostra:** código, nome da disciplina, a turma do histórico, as
   turmas do `horarios.txt` e quantos discentes. Não lista os alunos.
4. **Como corrigir:** acertar a numeração da turma no `horarios.txt` (pelo
   Horarios.exe) e reabrir o módulo.
5. **Limite:** disciplina matriculada que não tem nenhuma aula no
   `horarios.txt` não entra neste aviso.

Nomes fictícios ou códigos genéricos nos exemplos; nada de aluno.

## Roteiros dos ACs manuais

Executados pelo dev, na máquina com os dados reais de 2026/2. **Nenhuma
captura de tela**: o módulo atrás do diálogo mostra nome de aluno. Nada deste
roteiro gera artefato versionado.

**R1 (AC13).**
1. `dados/` com o `hist.csv` (2026-09-14) e o `horarios.txt` (2026-08-04) em
   uso. São os arquivos da contagem do card.
2. Abrir o programa → **Situação de Alunos**.
3. **Passa** se aparecer **exatamente um** diálogo com o título "Turmas sem
   correspondência no horarios.txt", **um** botão (OK), **sem** Cancelar, a
   lista dentro de área rolável e exatamente três linhas, nesta ordem:
   AL0037 `20/80` → `T30;60`, `T90` (2 discentes); AL2126 `20` → `T80` (2);
   AL2129 `20` → `T80` (1).
4. **Passa** se nenhuma linha do diálogo tiver nome ou matrícula de aluno.
5. Fechar com OK: o módulo continua utilizável, e a grade de um aluno em
   AL2126 segue mostrando a aula como Matriculável (o non-goal "não muda o
   casamento").

**R2 (AC14).**
1. Depois do R1, trocar de aluno três vezes no seletor e trocar o curso uma
   vez. **Passa** se nenhum diálogo novo abrir.
2. Ir para outro módulo e voltar à Situação de Alunos. **Passa** se o diálogo
   reabrir uma vez.

**R3 (AC15).**
1. Fechar o programa. Renomear temporariamente `dados/horarios.txt` (ação do
   dev; agentes não tocam em `dados/`).
2. Abrir com `Auxiliar_debug.console.exe` (ou o editor) e anotar a saída.
3. Abrir a Situação de Alunos. **Passa** se não houver diálogo e se o log não
   ganhar linha nova em relação ao mesmo procedimento antes do card. A linha
   `CRITICO: Erro ao abrir arquivo ...horarios.txt!` já existia e não conta
   como nova.
4. Restaurar o nome do arquivo.

**R4 (AC16).** Ler a subseção nova em `MANUAL.md` §4.3. **Passa** se ela
cobrir os cinco pontos da seção "Texto do MANUAL.md".

## Smoke

Sem PNG, como diz o card. A lógica é pura e está na camada headless, e os ACs
visuais exigem dados reais, que não viram captura. A etapa de smoke do
pipeline, se rodar, limita-se a conferir com `dados/` vazio que abrir o
programa não gera `push_error`/`push_warning` novo. Ela não navega até o
módulo, porque não há harness de input.

## Ordem de implementação

Cada passo termina com `python .tools/run_tests.py` verde, exceto o passo 3,
que é o vermelho do TDD.

1. **Leitura.** Reler `extrair_horarios_txt` (226–260), `_comparar_turmas`,
   `_partir_turma`, `_obter_turmas` e `AnaliseCurricular.matriculada_com_turma`
   (`analise_curricular.gd:491`). Confirmar que as únicas chamadas de
   `_obter_turmas` e `_comparar_turmas` são as das linhas 234, 235 e 240.
2. **Refactor verde.** Criar `_turma_casa` com o laço das linhas 234–244 e
   trocar o bloco em `extrair_horarios_txt` por
   `var tem_turma_em_comum: bool = _turma_casa(horarios_txt[a].get("turma"), matriculada_com_turma[key][b][1])`.
   O resto da função fica intacto, inclusive o fallback para `matriculavel`.
   Rodar a suíte: os 19 testes seguem verdes.
3. **Stubs e testes (vermelho).** Acrescentar as duas assinaturas públicas com
   a documentação `##` e corpo trivial (`return {}` / `return []`), para o
   script de teste carregar sem erro de parse. Escrever os helpers
   `_cenario_*` e os testes da tabela. Conferir que falham **pelo motivo
   certo**: AC3, AC6 e AC9 e o teste de não-mutação já passam com o stub e
   entram como congelamento; os demais falham por asserção.
4. **Implementação mínima (verde).** `matriculadas_com_turma_por_discente`,
   `_indexar_turmas_txt` e o corpo de `turmas_sem_correspondencia`, conforme o
   contrato. Sem `print`.
5. **Módulo.** `_avisar_turmas_sem_correspondencia` e
   `_rotulo_turma_sem_correspondencia` depois de `_validar_grade_ativa`,
   tipados e com `#`. A linha
   `_avisar_turmas_sem_correspondencia.call_deferred()` vai logo depois de
   `_rodar_análise()` no `_ready`.
6. **Manual.** Subseção em `MANUAL.md` §4.3.
7. **Portões.**
   - `python .tools/guardrails.py`. A catraca de `analise_horarios.gd` está em
     13 `trailing-whitespace`, 1 `static-typing` e 1 `max-line-length`; a de
     `situacao_alunos.gd`, em 12 `private-docstring`, 5 `static-typing`, 1
     `section-order`, 3 `trailing-whitespace` e 1 `function-name`. O código
     novo não pode somar nada. O refactor do passo 2 pode **remover**
     espaço em branco no fim de linha (linhas 236 e 245); apertar a catraca com
     `--update-baseline` é permitido, afrouxar nunca.
   - `python .tools/run_tests.py`.
   - `"C:/Program Files/Godot/Godot_console.exe" --headless --path . --editor --quit`.
8. **ACs manuais.** Entregar os roteiros R1–R4 ao dev.
