# Spec — 0008-carga-horaria-lista-oficial-professores

Card: `Cards/0008-carga-horaria-lista-oficial-professores/card.md`.

Objetivo: em **Planejamento de Oferta › Ações › Carga horária › Verificar**,
com um curso no filtro, o relatório passa a listar também todos os
professores da lista oficial do curso. Isso inclui quem não tem carga no
plano (aparece com 0 cr, "abaixo do minimo") e quem tem carga mas nunca
lecionou para o curso pelo histórico. A decisão de quem entra, com qual carga
e com qual status sai de `RelatoriosOferta.verificar_carga_horaria` e vai para
uma classe pura nova, `CargaDocente`, em `standalone_scripts/analise/`. O
relatório passa a só imprimir. A montagem da lista oficial por curso, que hoje
vive em dois privados do módulo, vai para a mesma classe. O destaque do painel
lateral, a Sugestão de oferta e o relatório passam a chamar uma implementação
única, e é ela que os testes cobrem.

## Camadas tocadas

| Arquivo | Por quê |
|---|---|
| `standalone_scripts/analise/carga_docente.gd` (**novo**) | Núcleo puro. `class_name CargaDocente extends Resource`, só funções `static`, com cabeçalho GPL. O precedente é `ValidacaoCurricular` (`validacao_curricular.gd`): mesma pasta, mesmo formato, standalone com GPL (FORMATACAO.md §1). Tem quatro públicas: `indexar_lista_oficial`, `lista_oficial_do_curso`, `status_carga` e `verificacao_carga`. |
| `scenes/Modulos/PlanejamentoOferta/Complementos/relatorios_oferta.gd` | Adaptador de saída (Terminal). `verificar_carga_horaria` ganha o parâmetro `profs_oficiais_curso` (com default) e troca o filtro e o status inline por uma chamada a `CargaDocente.verificacao_carga`. Mantém o título, o "Filtro curso", as duas mensagens de vazio, o texto de cada item e o rodapé exatamente como estão hoje. |
| `scenes/Modulos/PlanejamentoOferta/planejamentooferta.gd` | Composição local do módulo. (1) A chamada da ação (linha 1302) passa `_calcular_profs_destacar()` como terceiro argumento, como a Sugestão de oferta já faz (linha 1309). (2) Os corpos de `_inicializar_lista_professores` (286–302) e `_calcular_profs_destacar` (305–320) passam a delegar para `CargaDocente`. É um **refactor sem mudança de comportamento**: as duas funções continuam existindo, com os mesmos nomes e chamadores. |
| `test/unit/test_carga_docente.gd` (**novo**) | Testes dos ACs 1–11 sobre o núcleo, com fixtures inline e fictícias. |
| `test/unit/test_relatorios_oferta.gd` (**novo**) | Testes de fiação do relatório com um Terminal falso. Provam que `verificar_carga_horaria` de fato consome o núcleo (AC1 e AC11 no texto impresso) e que os rótulos de status não mudaram (AC9). |
| `arquivos/dicas.json` | Só o **valor** de `planejamento_oferta_acoes.verificar_carga_horaria` (AC13). A chave fica igual. |
| `MANUAL.md` | Só o item **Verificar carga horária** de "Planejamento de Oferta › Ações disponíveis" (AC13). |
| `.tools/guardrails_baseline.json` | Só **aperta** a catraca. O `var lista = ...` sem tipo (`planejamentooferta.gd:294`) sai do módulo, e `planejamentooferta.gd|static-typing` cai de 3 para 2. |

São quatro camadas: núcleo, adaptador de UI (relatório e módulo, que são a
mesma camada), testes e documentação. Passa de três porque o AC13 obriga a
mexer na dica e no manual, e porque a prova de fiação do relatório exige um
teste próprio. Sem esse teste, os ACs 1–11 passariam com o núcleo pronto e o
relatório sem ligação com ele.

**Por que `_calcular_profs_destacar` e `_inicializar_lista_professores` entram
no diff**, se o card diz que o painel lateral e a Sugestão não mudam: os ACs 6
e 7 são `headless`. A normalização do nome da lista (`Maria_da_Silva_Souza` →
`Maria Da Silva Souza`) e a escolha das chaves pelos `prefixos_semestre` vivem
hoje nesses dois privados de um nó de cena, e lá nenhum teste chega. Há duas
saídas. Uma é copiar a regra para o núcleo, o que gera duplicação, que a
review acusa. A outra é mover a regra e fazer o módulo delegar. A spec escolhe
mover: o comportamento visível do painel e da Sugestão é o mesmo, e os testes
passam a cobrir o caminho que a produção percorre.

Fica fora do diff, de propósito:

- **`scenes/main.gd`.** Nenhuma leitura nova e nenhuma injeção nova. O
  `lista_professores` já chega ao módulo (`main.gd:775`), com checagem de
  existência.
- **`AnaliseAfinidade`.** É reusada sem mudança: `normalizar_nome` (estática) e
  `professores_do_curso` (o relatório continua chamando, como hoje).
- **`sugerir_oferta`, `verificar_erro_afinidade`, `PainelAtribuicoes`.** Não são
  tocados. O que muda para eles é só o corpo de `_calcular_profs_destacar`, que
  devolve o mesmo conjunto de antes.
- **`_atualizar_status_bar`.** Continua contando só quem tem carga no plano. Ver
  "Riscos": é uma divergência conhecida, fora do escopo.
- **O item "Sugerir oferta" do `MANUAL.md`.** A observação lateral do card (o
  manual está desatualizado ali) fica fora do escopo. Não edite esse item.
- **`base_config.json`, `lista_professores.json`, Kinto, `dados/`.** Nenhuma
  chave e nenhum formato são tocados.

## Contrato público novo ou alterado

### `CargaDocente` (novo, `standalone_scripts/analise/carga_docente.gd`)

Todas as funções são `static`, puras e determinísticas. Nenhuma tem
`FileAccess`, `GV`, nó ou `print`, e nenhuma muta os argumentos. A única
dependência é `AnaliseAfinidade.normalizar_nome`, uma função estática pura
(classe sem UI, embora o arquivo more em `scenes/.../Complementos/`). Essa
referência é tolerada, como a de `analise_horarios.gd` a `PaletaSemantica`.
Duplicar o normalizador seria pior: o card proíbe mexer nele, e duas cópias
divergiriam. A ordem no arquivo segue a lista abaixo: públicas e depois
privadas, se houver alguma (guardrail `section-order`).

```gdscript
static func indexar_lista_oficial(lista_professores: Dictionary) -> Dictionary
```

- **Quem chama:** `planejamentooferta.gd::_inicializar_lista_professores`, uma vez
  no `_ready`, guardando o retorno em `_lista_professores_por_curso`. Os testes
  também chamam.
- **Entrada:** `lista_professores` como o main injeta, ou seja, o JSON cru de
  `arquivos/oferta/lista_professores.json`, `{ <chave>: [nome, ...] }`, ou `{}`
  quando o arquivo está ausente.
- **Garante:** devolve `{ <chave em minúsculas>: { <nome normalizado>: true } }`,
  com a regra de hoje **movida sem alteração**:
  - entrada cujo valor não é `Array` é ignorada;
  - cada nome passa por `AnaliseAfinidade.normalizar_nome(str(nome))`, e o nome
    que normaliza para vazio é ignorado;
  - a chave é `str(chave).to_lower()`; duas chaves que só diferem em caixa
    ficam com o último `Array` da iteração, como hoje (atribuição, não união);
  - `{}` na entrada dá `{}` na saída.
- A variável do valor é tipada (`var lista: Variant = ...`). É essa a linha que
  hoje conta como violação `static-typing` no módulo.

```gdscript
static func lista_oficial_do_curso(lista_indexada: Dictionary, cursos: Dictionary, cod_curso: String) -> Dictionary
```

- **Quem chama:** `planejamentooferta.gd::_calcular_profs_destacar`, com
  `_lista_professores_por_curso`, `cursos` e `_painel_disciplinas.filtro_curso`.
  Hoje ela alimenta o destaque do painel lateral e a Sugestão de oferta e, com
  este card, também o relatório de carga. Os testes também chamam.
- **Entrada:** `lista_indexada` no formato de retorno de
  `indexar_lista_oficial`, e `cursos` no formato de `base_config.json:cursos`.
- **Garante:** devolve a **união** `{ <nome normalizado>: true }` das listas de
  `lista_indexada` cujas chaves são `str(prefixo).to_lower()` para algum
  prefixo de `cursos[cod_curso].prefixos_semestre`. Devolve `{}` quando
  `cod_curso` é vazio, quando não está em `cursos` ou quando nenhuma chave
  casa. O retorno é **sempre um `Dictionary` novo**, nunca uma referência a um
  valor de `lista_indexada`, porque quem recebe pode guardá-lo e mexer nele.
  Regra de hoje, movida sem alteração.

```gdscript
static func status_carga(ch: int, config_oferta: Dictionary) -> String
```

- **Quem chama:** `verificacao_carga`. Os testes também chamam.
- **Entrada:** `config_oferta` é `base_config.json:planejamento_oferta`, com
  `ch_minimo`, `ch_ideal` e `ch_maximo` como **float** (JSON), lidos por
  `int(config_oferta.get("ch_minimo", 8))`, `int(...get("ch_ideal", 12))` e
  `int(...get("ch_maximo", 20))`, com os mesmos defaults do relatório.
- **Garante:** devolve um token em snake_case, com a precedência de hoje
  (`relatorios_oferta.gd:257-267`) e sem mudança de regra:
  1. `ch > ch_maximo` → `"acima_maximo"`
  2. senão, `ch > ch_ideal` → `"acima_ideal"`
  3. senão, `ch < ch_minimo` → `"abaixo_minimo"`
  4. senão → `"ok"`
- Escreva como uma sequência de `if ...: return` sem `elif`/`else` depois de
  `return`. O gdlint cobra `no-elif-return` e `no-else-return`.

```gdscript
static func verificacao_carga(carga_por_prof: Dictionary, cod_curso: String, profs_historico_curso: Dictionary, profs_oficiais_curso: Dictionary, config_oferta: Dictionary) -> Array[Dictionary]
```

- **Quem chama:** `RelatoriosOferta.verificar_carga_horaria`. Os testes também
  chamam.
- **Entrada:**
  - `carga_por_prof`: `{ <nome normalizado>: int }`, a saída de
    `planejamentooferta.gd::_calcular_carga_por_prof` (soma do plano inteiro,
    de qualquer curso). **Assume** que as chaves já estão normalizadas, porque
    a importação passa todo nome por `normalizar_nome` (linhas 412, 427 e 712).
    A função **não** renormaliza as chaves de `carga_por_prof`: fazer isso
    fundiria entradas que hoje saem separadas e mudaria a regra atual.
  - `cod_curso`: o filtro de curso. Só importa se está vazio ou não.
  - `profs_historico_curso`: `{ <nome normalizado>: true }`, a saída de
    `AnaliseAfinidade.professores_do_curso(cod_curso)`. **É o cache interno da
    `AnaliseAfinidade`** (`_prof_curso_cache`). Mutá-lo corromperia a Sugestão e
    a Verificação de afinidade, por isso a função não pode mexer nele.
  - `profs_oficiais_curso`: `{ <nome normalizado>: true }`, a saída de
    `lista_oficial_do_curso`.
  - `config_oferta`: como em `status_carga`.
- **Algoritmo (contrato, não implementação):**
  1. `carga_por_prof` vazio → devolve `[]`, com ou sem filtro e com ou sem
     lista (AC11).
  2. `cod_curso` vazio → os nomes são **todas** as chaves de `carga_por_prof`.
     `profs_historico_curso` e `profs_oficiais_curso` são **ignorados**, mesmo
     se vierem preenchidos (AC5).
  3. `cod_curso` não vazio → os nomes são a **união** de:
     - as chaves de `carga_por_prof` presentes em `profs_historico_curso` **ou**
       em `profs_oficiais_curso` (regra atual, mais o AC2);
     - todas as chaves de `profs_oficiais_curso` (AC1).

     Cada nome entra **uma vez**, porque o conjunto é um `Dictionary` (AC6).
     **Atenção:** não copie a regra da Sugestão de oferta
     (`relatorios_oferta.gd:396-398`: "lista oficial se existir, senão
     histórico"). Lá a lista **substitui** o histórico; aqui ela se **soma** a
     ele. Copiar a da Sugestão derruba o AC3.
  4. Para cada nome: `ch := int(carga_por_prof.get(nome, 0))` e
     `status := status_carga(ch, config_oferta)`.
  5. Ordena por `ch` **decrescente** e, no empate, por `nome` **crescente**
     (`<` de `String`, o mesmo critério de `_todos_professores.sort_custom`,
     linha 282). As chaves são únicas, então a ordem é total e o resultado é
     determinístico (AC10). Vale com e sem filtro.
- **Retorno:** `Array[Dictionary]`, um item por professor, com chaves em
  snake_case e exatamente estes três campos:

  | Chave | Tipo | Conteúdo |
  |---|---|---|
  | `nome` | `String` | a chave normalizada, crua (a formatação `capitalize()` é do relatório) |
  | `ch` | `int` | carga do plano inteiro, `0` para quem só está na lista |
  | `status` | `String` | `"acima_maximo"`, `"acima_ideal"`, `"abaixo_minimo"` ou `"ok"` |

  Não há campo de "origem" (lista/histórico): o card proíbe rótulo novo.

### `RelatoriosOferta.verificar_carga_horaria` (alterada)

```gdscript
func verificar_carga_horaria(carga_por_prof: Dictionary, cod_curso: String = "", profs_oficiais_curso: Dictionary = {}) -> void
```

- **Quem chama:** `planejamentooferta.gd`, na ação `"verificar_carga_horaria"`:
  `_relatorios.verificar_carga_horaria(_calcular_carga_por_prof(), _painel_disciplinas.filtro_curso, _calcular_profs_destacar())`.
  O parâmetro novo fica por último e com default `{}`, como o
  `profs_oficiais_curso` de `sugerir_oferta`. Sem ele, o resultado é o de hoje.
- **Corpo (ordem preservada):**
  1. `ch_min`, `ch_ideal` e `ch_max` lidos como hoje, para o rótulo e o rodapé.
  2. `titulo("Verificacao de carga horaria", true)` e, com filtro,
     `linha("Filtro curso: ...", "aviso")`, como hoje.
  3. `carga_por_prof` vazio → `linha("Nenhum professor alocado.")` e `return`.
     A checagem continua **antes** de qualquer consulta, como hoje (AC11).
  4. `linhas := CargaDocente.verificacao_carga(carga_por_prof, cod_curso, _afinidade.professores_do_curso(cod_curso), profs_oficiais_curso, _config_oferta)`.
     `professores_do_curso("")` devolve `{}`.
  5. `linhas` vazio → `linha("Nenhum professor alocado que tenha lecionado para o curso.")`
     e `return`. Isso só acontece com filtro, sem lista para o curso e sem
     ninguém do histórico (edge case "Mensagens de lista vazia").
  6. Para cada item, um `match item["status"]` traduz o token em rótulo e cor,
     com os **mesmos textos de hoje**:

     | `status` | Texto | Token |
     |---|---|---|
     | `acima_maximo` | `"ACIMA DO MAXIMO (%d cr)" % ch_max` | `erro` |
     | `acima_ideal` | `"acima do ideal (%d cr)" % ch_ideal` | `aviso` |
     | `abaixo_minimo` | `"abaixo do minimo (%d cr)" % ch_min` | `aviso` |
     | `ok` | `"OK"` | `sucesso` |

     e `_terminal.item("%s: %d cr — %s" % [nome.capitalize(), ch, texto], 0, token)`.
  7. `espaco()` e o rodapé `"Minimo: %d cr | Ideal: ate %d cr | Maximo absoluto: %d cr"`,
     como hoje.
- O `match` fica **inline** em `verificar_carga_horaria`, sem privado novo. O
  arquivo já tem 1 `section-order` congelado, e um privado entre as públicas
  não pioraria a contagem, mas também não é necessário.
- A docstring `##` da função passa a descrever a regra nova: com filtro,
  "quem já lecionou ao curso pelo histórico **mais** a lista oficial do curso,
  esta com carga 0 quando fora do plano".

### Privados do módulo (refactor sem mudança de comportamento)

```gdscript
func _inicializar_lista_professores() -> void      # corpo: _lista_professores_por_curso = CargaDocente.indexar_lista_oficial(lista_professores)
func _calcular_profs_destacar() -> Dictionary      # corpo: return CargaDocente.lista_oficial_do_curso(_lista_professores_por_curso, cursos, _painel_disciplinas.filtro_curso)
```

Os nomes, as posições no arquivo e os chamadores (linhas 233, 1309 e 1442,
mais a nova da 1302) ficam iguais. Os comentários `#` são encurtados para
apontar a `CargaDocente`. Fica permitido, e não obrigatório, corrigir a
docstring de `lista_professores` (linha 80), que cita
`arquivos/lista_professores.json`. O caminho real é
`arquivos/oferta/lista_professores.json`.

Regra de dependência preservada: o módulo e o relatório conhecem
`CargaDocente`, e `CargaDocente` não conhece módulo, nó, arquivo nem `GV`.

## Invariantes

| Invariante | Como esta feature se comporta |
|---|---|
| **1. Dado pessoal não sai do PC** | Os nomes de docente (dado funcional) continuam só no Terminal, como hoje. A novidade é que os nomes da lista oficial sem carga passam a aparecer ali também. Nada vai para log, exportação, rede ou Kinto. Os testes usam **só** nomes fictícios inline (`Maria da Silva Souza`, `Ana Ficticia Costa`, `Bruno Ficticio Alves`, `Carla Ficticia Dias`, `Davi Ficticio Lopes`, `Beatriz Ficticia Melo`, `Edu Ficticio Neves`) e cursos inexistentes (`alzz`/`zz`, `alyy`/`yy`, `alxx`/`xa`+`xb`). **Nenhum teste lê `arquivos/oferta/`**, que é gitignorada e tem dado nominal real. Não há fixture em arquivo nem PNG. Nenhum arquivo novo na raiz do projeto, então o `exclude_filter` dos presets não muda (`test/*` já está excluído). |
| **2. snake_case interno, formatação só na UI** | Chaves novas só em memória: `nome`, `ch`, `status`. Os valores de `status` são tokens snake_case. O rótulo ("ACIMA DO MAXIMO (20 cr)", "abaixo do minimo (8 cr)") e o `capitalize()` do nome só aparecem no `match` do relatório, na hora de escrever no Terminal. |
| **3. Cursos e chaves canônicas** | `cursos` (de `base_config.json`) é a única fonte dos `prefixos_semestre`. Nenhuma lista de cursos é duplicada. A chave do `lista_professores.json` continua sendo o prefixo de semestre (non-goal), comparada sem diferenciar maiúsculas. |
| **4. Leitura no main/FileHandling; módulo recebe injetado** | Nenhuma leitura nova (o guardrail `filesystem-boundary` não tem o que acusar). `CargaDocente` recebe tudo por parâmetro. Lista ausente → o main injeta `{}` → `indexar_lista_oficial({})` devolve `{}` → resultado igual ao de hoje, sem erro (AC8). |
| **5. UI pelas fachadas** | Saída pelos helpers do `Terminal` (`titulo`, `linha`, `item`, `espaco`), com os tokens semânticos de hoje (`erro`, `aviso`, `sucesso`). Sem diálogo, sem tooltip novo (a dica existente só muda de texto, via `DicasPrograma`) e sem cor nova. Nada envolve `chave_planejamento`. |

## Mapeamento AC → prova

Os ACs `headless` rodam com `python .tools/run_tests.py` (`-gselect=carga_docente`
ou `-gselect=relatorios_oferta` para uma suíte só). Os nomes de teste abaixo
são contrato para a implementação. Os testes do núcleo montam as entradas
direto, sem `AnaliseAfinidade`, e as que vêm da lista crua passam por
`indexar_lista_oficial` → `lista_oficial_do_curso` → `verificacao_carga`, o
mesmo caminho da produção. Quando o AC depende de uma pré-condição, o teste a
afirma antes, para não ser vácuo (ex.: "Ana não está em
`profs_historico_curso`").

| AC do card | Método | Onde |
|---|---|---|
| AC1: com filtro, professor da lista sem carga entra com 0 cr e "abaixo do mínimo" | headless | `test_carga_docente.gd::test_lista_oficial_sem_carga_entra_com_zero_abaixo_do_minimo` (núcleo: item `{"nome": "Ana Ficticia Costa", "ch": 0, "status": "abaixo_minimo"}`). Fiação: `test_relatorios_oferta.gd::test_verificar_carga_horaria_imprime_lista_oficial_com_zero_cr` (texto `"- Ana Ficticia Costa: 0 cr — abaixo do minimo (8 cr)"`, token `aviso`). |
| AC2: com filtro, professor da lista com carga que nunca lecionou para o curso entra com a carga real | headless | `test_carga_docente.gd::test_lista_oficial_com_carga_que_nunca_lecionou_entra_com_carga_real` |
| AC3: com filtro, quem tem carga e lecionou para o curso, mas não está na lista, continua entrando | headless | `test_carga_docente.gd::test_professor_do_historico_fora_da_lista_continua_entrando`. A lista vem **preenchida** com outro nome, o que pega quem copiar a regra "lista substitui histórico" da Sugestão. |
| AC4: com filtro, quem tem carga, não lecionou e não está na lista continua fora | headless | `test_carga_docente.gd::test_professor_sem_historico_e_fora_da_lista_continua_fora` |
| AC5: sem filtro, a lista não acrescenta ninguém (todos com carga no plano) | headless | `test_carga_docente.gd::test_sem_filtro_lista_oficial_nao_acrescenta_ninguem`. Fiação: `test_relatorios_oferta.gd::test_verificar_carga_horaria_sem_filtro_ignora_lista`. |
| AC6: quem está na lista e no plano aparece uma vez, com a carga do plano (`Maria_da_Silva_Souza` casa com `Maria Da Silva Souza`) | headless | `test_carga_docente.gd::test_nome_da_lista_com_sublinhado_casa_com_o_plano_uma_vez`. Percorre o caminho completo a partir da lista crua. |
| AC7: só entra a lista das chaves dos `prefixos_semestre` do curso filtrado | headless | `test_carga_docente.gd::test_so_entra_a_lista_dos_prefixos_do_curso_filtrado` |
| AC8: lista vazia ou ausente dá o resultado de hoje, sem erro | headless | `test_carga_docente.gd::test_lista_vazia_ou_ausente_mantem_resultado_de_hoje` |
| AC9: status pelos limites de `config_oferta`, nas fronteiras, sem mudança de regra | headless | `test_carga_docente.gd::test_status_carga_nas_fronteiras_dos_limites`. Rótulos: `test_relatorios_oferta.gd::test_verificar_carga_horaria_mantem_rotulos_de_status`. |
| AC10: carga decrescente, empate pelo nome | headless | `test_carga_docente.gd::test_ordena_por_carga_decrescente_e_nome_no_empate` |
| AC11: plano sem alocação mantém "Nenhum professor alocado.", mesmo com filtro e lista | headless | Núcleo: `test_carga_docente.gd::test_plano_sem_alocacao_nao_lista_ninguem_mesmo_com_filtro_e_lista`. Mensagem: `test_relatorios_oferta.gd::test_verificar_carga_horaria_plano_vazio_mostra_nenhum_professor_alocado`. |
| AC12: dados reais, filtro Engenharia Civil → os 14 da lista, e os sem carga como "abaixo do mínimo" | manual | Roteiro R1, abaixo. Executado pelo dev, **sem captura**. |
| AC13: a dica (`planejamento_oferta_acoes.verificar_carga_horaria`) e o `MANUAL.md` descrevem a regra nova | manual | Roteiro R2. O conteúdo exigido está na seção "Textos", abaixo. |

### Cenários dos testes do núcleo (`test/unit/test_carga_docente.gd`)

Constantes do arquivo:
`CONFIG := {"ch_minimo": 8.0, "ch_ideal": 12.0, "ch_maximo": 20.0}`, em float
como o JSON entrega, e
`CURSOS := {"alzz": {"nome": "Curso Ficticio Zeta", "prefixos_semestre": ["zz"], "turmas": [20.0]}, "alyy": {"nome": "Curso Ficticio Ipsilon", "prefixos_semestre": ["yy"], "turmas": [30.0]}, "alxx": {"nome": "Curso Ficticio Xis", "prefixos_semestre": ["xa", "xb"], "turmas": [50.0]}}`.
Abaixo, `V(carga, cod, hist, oficiais)` abrevia
`CargaDocente.verificacao_carga(carga, cod, hist, oficiais, CONFIG)`, e os
nomes são os normalizados.

| Teste | Entrada | Esperado |
|---|---|---|
| AC1 | `V({"Carla Ficticia Dias": 10}, "alzz", {"Carla Ficticia Dias": true}, {"Ana Ficticia Costa": true})` | exatamente `[{"nome": "Carla Ficticia Dias", "ch": 10, "status": "ok"}, {"nome": "Ana Ficticia Costa", "ch": 0, "status": "abaixo_minimo"}]` |
| AC2 | `V({"Ana Ficticia Costa": 10, "Carla Ficticia Dias": 14}, "alzz", {"Carla Ficticia Dias": true}, {"Ana Ficticia Costa": true})`; pré-condição: Ana fora de `hist` | `[Carla 14 "acima_ideal", Ana 10 "ok"]` |
| AC3 | mesma entrada do AC1 | Carla presente, com `ch == 10`, apesar de `oficiais` não vazio e sem ela |
| AC4 | `V({"Edu Ficticio Neves": 6, "Carla Ficticia Dias": 10}, "alzz", {"Carla Ficticia Dias": true}, {"Ana Ficticia Costa": true})` e a mesma com `oficiais = {}` | nomes `["Carla Ficticia Dias", "Ana Ficticia Costa"]` e `["Carla Ficticia Dias"]`; Edu ausente nos dois |
| AC5 | `V({"Edu Ficticio Neves": 6, "Carla Ficticia Dias": 10}, "", {}, {"Ana Ficticia Costa": true})` e a mesma com `hist = {"Carla Ficticia Dias": true}` | nos dois: `[Carla 10 "ok", Edu 6 "abaixo_minimo"]`; Ana ausente; o `hist` preenchido não filtra sem curso |
| AC6 | lista crua `{"zz": ["Maria_da_Silva_Souza"]}` → `indexar_lista_oficial` → `lista_oficial_do_curso(idx, CURSOS, "alzz")`; pré-condição: `oficiais == {"Maria Da Silva Souza": true}`; depois `V({"Maria Da Silva Souza": 10}, "alzz", {}, oficiais)` | exatamente `[{"nome": "Maria Da Silva Souza", "ch": 10, "status": "ok"}]` (um item, carga do plano) |
| AC7 | lista crua `{"ZZ": ["Ana_Ficticia_Costa"], "yy": ["Bruno_Ficticio_Alves"], "xa": ["Davi_Ficticio_Lopes"], "xb": ["Beatriz_Ficticia_Melo"]}`; carga `{"Carla Ficticia Dias": 10}`; (a) `alzz` com `hist = {"Carla Ficticia Dias": true}`; (b) `alyy` com `hist = {}`; (c) `alxx` com `hist = {}` | (a) `["Carla Ficticia Dias", "Ana Ficticia Costa"]`, sem Bruno/Davi/Beatriz (a chave `"ZZ"` casa com o prefixo `"zz"`); (b) `["Bruno Ficticio Alves"]`; (c) `["Beatriz Ficticia Melo", "Davi Ficticio Lopes"]` (união dos dois prefixos, empate em 0 por nome) |
| AC8 | carga `{"Carla Ficticia Dias": 10, "Edu Ficticio Neves": 6}`, `alzz`, `hist = {"Carla Ficticia Dias": true}`; `oficiais` saído do caminho completo para cada lista crua: `{}` (ausente: o main injeta `{}`), `{"zz": []}`, `{"zz": "texto"}` (não é `Array`) e `{"yy": ["Bruno_Ficticio_Alves"]}` (só de outro curso) | as quatro variantes dão `[{"nome": "Carla Ficticia Dias", "ch": 10, "status": "ok"}]`, que é a regra de hoje (carga ∩ histórico), sem erro nem `push_error` |
| AC9 | `status_carga(ch, CONFIG)` para `ch` em `0, 7, 8, 12, 13, 20, 21`; e `V` sem filtro com uma carga por valor | `abaixo_minimo, abaixo_minimo, ok, ok, acima_ideal, acima_ideal, acima_maximo`; os mesmos status nos itens de `V` |
| AC10 | `V({"Bruno Ficticio Alves": 10, "Ana Ficticia Costa": 10, "Carla Ficticia Dias": 15}, "alzz", {os três: true}, {"Davi Ficticio Lopes": true, "Beatriz Ficticia Melo": true})`, com as chaves inseridas **fora** da ordem esperada; e `V({"Bruno Ficticio Alves": 10, "Ana Ficticia Costa": 10}, "", {}, {})` | `["Carla Ficticia Dias", "Ana Ficticia Costa", "Bruno Ficticio Alves", "Beatriz Ficticia Melo", "Davi Ficticio Lopes"]`; sem filtro, `["Ana Ficticia Costa", "Bruno Ficticio Alves"]` |
| AC11 | `V({}, "alzz", {"Carla Ficticia Dias": true}, {"Ana Ficticia Costa": true})` e `V({}, "", {}, {"Ana Ficticia Costa": true})` | `[]` nos dois |

### Testes de apoio do núcleo (não são ACs; cobrem edge cases do card)

| Edge case / contrato | Teste |
|---|---|
| Defaults 8/12/20 quando `config_oferta` vem sem as chaves | `test_status_carga_usa_defaults_sem_config`: `status_carga(ch, {})` dá os mesmos status do AC9 |
| "Entrada que não é Array é ignorada" e "chave sem diferenciar maiúsculas" (regra movida) | `test_indexar_lista_oficial_normaliza_e_ignora_entrada_invalida`: `{"EC": ["Maria_da_Silva_Souza", ""], "zz": "texto", "yy": 7}` → `{"ec": {"Maria Da Silva Souza": true}}` |
| `lista_oficial_do_curso` igual à regra anterior em `cod_curso` vazio e em curso inexistente | `test_lista_oficial_do_curso_vazia_sem_filtro_ou_curso_desconhecido`: `""` → `{}`; `"alww"` (fora de `CURSOS`) → `{}` |
| Não muta entradas; o cache da `AnaliseAfinidade` e o índice do módulo ficam intactos | `test_nao_muta_entradas`: compara `carga_por_prof`, `hist`, `oficiais`, a lista crua e o índice com um `duplicate(true)` tirado antes; e confirma que mexer no retorno de `lista_oficial_do_curso` não altera `lista_indexada` |
| Formato do item | `test_item_tem_exatamente_nome_ch_status`: usa a entrada do AC1 e afirma primeiro que o resultado **não** é vazio (senão o teste passa no vácuo com o stub); depois, as chaves de cada item são exatamente `nome`, `ch`, `status`, e `ch` é `int` (`typeof == TYPE_INT`), inclusive no item que veio só da lista |

### Testes de fiação do relatório (`test/unit/test_relatorios_oferta.gd`)

**Terminal falso:** classe interna no topo do arquivo,
`class TerminalFalso extends Node`, com `var registros: Array[Dictionary] = []`
e os métodos tipados `titulo(texto: String, limpar: bool = false)`,
`secao(texto: String)`, `item(texto: String, nivel: int = 0, token: String = "padrao", bg: String = "")`,
`linha(texto: String, token: String = "padrao")`, `espaco()`,
`text_edit(...)` e `registrar_meta(chave: String, texto_bbcode: String)`.
Cada um grava `{"texto": <texto como o Terminal real escreveria>, "token": <token>}`,
com `"# "` no título, `"  ".repeat(nivel) + "- "` no item e `""` no espaço,
espelhando `terminal.gd:76-106`. O `_terminal` do relatório é tipado como
`Node`, e a chamada dinâmica já é como funciona hoje. A instância passa por
`autofree`.

**Montagem (helper privado no fim do arquivo):**
`RelatoriosOferta.new().configurar(terminal, afinidade, AnaliseHistorico.new(), {}, [] as Array[String], CONFIG, CURSOS)`,
com `afinidade := AnaliseAfinidade.new()` configurada por
`afinidade.configurar(HISTORICO, CURSOS, {}, 15, [])`, onde
`HISTORICO := {"Carla_Ficticia_Dias": {"zz0001": {"2025": {"1": [{"turma": [20.0]}]}}}}`.
Isso faz `professores_do_curso("alzz") == {"Carla Ficticia Dias": true}`, e o
teste afirma essa pré-condição uma vez. `CONFIG`/`CURSOS` são os mesmos do
núcleo (repetidos no arquivo, pois são constantes de teste).

| Teste | Chamada | Esperado |
|---|---|---|
| `test_verificar_carga_horaria_imprime_lista_oficial_com_zero_cr` (AC1) | `verificar_carga_horaria({"Carla Ficticia Dias": 10}, "alzz", {"Ana Ficticia Costa": true})` | os itens, em ordem, são `"- Carla Ficticia Dias: 10 cr — OK"` (`sucesso`) e `"- Ana Ficticia Costa: 0 cr — abaixo do minimo (8 cr)"` (`aviso`); o rodapé `"Minimo: 8 cr \| Ideal: ate 12 cr \| Maximo absoluto: 20 cr"` está presente |
| `test_verificar_carga_horaria_plano_vazio_mostra_nenhum_professor_alocado` (AC11) | `verificar_carga_horaria({}, "alzz", {"Ana Ficticia Costa": true})` | há uma linha `"Nenhum professor alocado."`; nenhum registro contém `"Ana Ficticia Costa"`; nenhum item |
| `test_verificar_carga_horaria_sem_ninguem_do_curso_mantem_mensagem` (edge "Mensagens de lista vazia") | `verificar_carga_horaria({"Edu Ficticio Neves": 6}, "alzz", {})` | há uma linha `"Nenhum professor alocado que tenha lecionado para o curso."`; nenhum item |
| `test_verificar_carga_horaria_sem_filtro_ignora_lista` (AC5) | `verificar_carga_horaria({"Edu Ficticio Neves": 6}, "", {"Ana Ficticia Costa": true})` | um único item, `"- Edu Ficticio Neves: 6 cr — abaixo do minimo (8 cr)"`; nenhuma linha `"Filtro curso: ..."`; Ana ausente |
| `test_verificar_carga_horaria_mantem_rotulos_de_status` (AC9) | sem filtro, `{"Ana Ficticia Costa": 21, "Bruno Ficticio Alves": 13, "Carla Ficticia Dias": 10, "Davi Ficticio Lopes": 7}` | itens `"... 21 cr — ACIMA DO MAXIMO (20 cr)"` (`erro`), `"... 13 cr — acima do ideal (12 cr)"` (`aviso`), `"... 10 cr — OK"` (`sucesso`) e `"... 7 cr — abaixo do minimo (8 cr)"` (`aviso`), nesta ordem |

Os textos esperados usam o travessão `—` e os rótulos sem acento,
exatamente como `relatorios_oferta.gd:258-268` escreve hoje.

## Riscos de contrato de dados

- **Nenhuma chave renomeada, nenhuma chave nova em arquivo.** O
  `lista_professores.json` (chave por prefixo de semestre, lista de nomes) não
  muda (non-goal). Em `base_config.json`, só se **leem** `ch_minimo`, `ch_ideal`
  e `ch_maximo` (float, por `int()`) e `cursos.<cod>.prefixos_semestre`, que já
  existem. Em `arquivos/dicas.json`, muda só o **texto** do valor
  `planejamento_oferta_acoes.verificar_carga_horaria`, e a chave consumida por
  `DicasPrograma.texto([...])` (`planejamentooferta.gd:183`) fica igual. Kinto,
  `dados/` e `user://` não são tocados. As chaves `nome`, `ch` e `status` vivem
  só em memória.
- **Refactor alcança dois consumidores que o card diz não mudarem.** O destaque
  do painel lateral (`_exibir_disciplina_selecionada`, linha 1442) e a Sugestão
  de oferta (linha 1309) consomem `_calcular_profs_destacar`. A mudança é
  mecânica (mover o corpo para `CargaDocente`). Os testes de apoio de
  `indexar_lista_oficial`/`lista_oficial_do_curso` congelam a regra antiga, e o
  roteiro R1 confere os dois na tela.
- **Grafia diferente entre lista e plano.** `normalizar_nome` não ignora caixa
  nem acento. Um nome que, na lista, difira do plano só por caixa ou acento sai
  **duplicado** (uma linha com a carga, outra com 0 cr). É a limitação conhecida
  da Sugestão e do destaque, não corrigida aqui (edge case do card). O manual
  passa a mencioná-la, e não há teste congelando esse defeito.
- **Status bar diverge do relatório.** `_atualizar_status_bar` conta só quem tem
  carga no plano. Com filtro e lista, o relatório pode mostrar mais professores
  "abaixo do minimo" que o segmento `<8 cr` do rodapé. Não é regressão: o
  rodapé não filtra por curso nem hoje e está fora do escopo. Candidato a ideia
  no `IDEAS.md`, sem mudança neste card.
- **Ordem sem filtro muda nos empates.** Hoje o empate fica em ordem
  indefinida. Passa a ser por nome, o que o AC10 pede. Não há outro consumidor
  dessa ordem.
- **Class_name novo.** `CargaDocente` só resolve depois que o editor registra a
  classe (`.godot/global_script_class_cache.cfg`, gitignorado). Por isso o
  portão do parser roda **antes** do primeiro `run_tests.py` (passo 2 da
  ordem).
- **LGPD.** O dado tocado é o nome de docente (funcional) e a carga planejada
  (o mesmo dado do planejamento de oferta). Ele aparece **só na tela**, no
  Terminal, como hoje, e não vai para log, arquivo, exportação nem rede. Os
  testes e a spec só têm nomes fictícios e não leem `arquivos/oferta/`. O
  roteiro manual R1 é feito com dado real **sem captura** e sem gravar nada no
  repositório.

## Textos (AC13)

**`arquivos/dicas.json`, `planejamento_oferta_acoes.verificar_carga_horaria`.**
Precisa dizer: (a) relatório da carga total de cada professor; (b) com curso
no filtro, entra quem já lecionou para ele **e** todos os professores da lista
oficial do curso; (c) quem está na lista sem carga aparece com 0 cr, abaixo do
mínimo. Use o mesmo tom e o mesmo `[b]...[/b]` das vizinhas. Sugestão:

> `Relatório consolidado da [b]carga total[/b] de cada professor. Com um curso no filtro, mostra quem já lecionou para ele e [b]todos os professores da lista oficial[/b] do curso, inclusive os sem carga (0 cr, abaixo do mínimo).`

**`MANUAL.md`, Planejamento de Oferta › Ações disponíveis, item "Verificar
carga horária"** (substitui o item atual, e só ele). Precisa dizer:

1. o relatório traz a carga total de cada professor e o status frente aos
   limites mínimo, ideal e máximo (`base_config.json:planejamento_oferta`);
2. a ordem é da maior para a menor carga e, no empate, pelo nome;
3. sem curso no filtro, entra apenas quem tem carga no planejamento;
4. com curso no filtro, entram os que já lecionaram para o curso (código da
   turma no histórico) **e** todos os da lista oficial do curso
   (`arquivos/oferta/lista_professores.json`), mesmo sem nenhuma disciplina no
   planejamento. Estes aparecem com **0 cr**, como abaixo do mínimo, para que
   ninguém seja esquecido;
5. a carga mostrada é sempre a soma de todas as disciplinas do planejamento,
   de qualquer curso: o filtro escolhe **quem** aparece, não **o que** se soma;
6. sem a lista oficial (pasta `arquivos/oferta/` não sincronizada), vale só o
   histórico;
7. um nome grafado de forma diferente na lista e no planejamento (maiúsculas
   ou acentos) aparece duas vezes.

Exemplos, se houver, só com nome fictício (`Maria da Silva Souza`).

## Roteiros dos ACs manuais

Executados pelo dev, na máquina com `arquivos/oferta/` sincronizada
(`ferramentas/sincronizar_dados_curso.ps1`) e o planejamento do semestre.
**Nenhuma captura de tela** e nada gravado no repositório: a tela mostra nomes
reais e a carga de docentes.

**R1 (AC12).**
0. *(Opcional, para comparar.)* Antes de aplicar o card (no `master`), rodar
   os passos 2–4 e anotar, **fora do repositório**, quem aparece com filtro e
   sem filtro.
1. Conferir que `arquivos/oferta/lista_professores.json` existe e tem a chave
   `ec` com os 14 nomes. O agente não lê esse arquivo; a conferência é do dev.
2. Abrir **Planejamento de Oferta** e carregar o planejamento
   (`Abrir planejamento.json` ou `.csv`).
3. No filtro de curso, escolher **Engenharia Civil**.
4. **Ações › Carga horária › Verificar.**
5. **Passa** se:
   - cada um dos 14 nomes da lista aparece **exatamente uma vez**;
   - os que não têm disciplina no plano aparecem como `0 cr — abaixo do minimo (8 cr)`,
     na cor de aviso;
   - quem aparecia antes do card (passo 0) continua aparecendo, com a mesma
     carga;
   - a ordem é carga decrescente e, no empate (inclusive entre os 0 cr), pelo
     nome.
6. Filtro em **Todos**, repetir o passo 4. **Passa** se nenhum `0 cr` de
   professor fora do plano aparecer e se a lista for a mesma do passo 0 (só a
   ordem dos empates pode mudar).
7. Regressão do refactor, com o filtro em Engenharia Civil: clicar numa
   disciplina e conferir que o painel lateral continua destacando os
   professores da lista do curso. Depois, **Ações › Oferta › Sugerir** e
   conferir que a lista de professores abaixo do mínimo é a mesma de antes.
8. Se algum nome aparecer duas vezes (uma com carga, outra com 0 cr), é a
   limitação de grafia registrada em "Riscos". Anote para corrigir na lista
   oficial ou no planejamento, não no código.

**R2 (AC13).**
1. `grep -n "lista oficial" arquivos/dicas.json MANUAL.md`: precisa achar a
   dica e o item do manual.
2. No módulo, passar o mouse em **Ações › Carga horária › Verificar**. **Passa**
   se a dica cobrir os pontos (a)–(c) da seção "Textos".
3. Ler o item no `MANUAL.md`. **Passa** se cobrir os pontos 1–7 e se o item
   "Sugerir oferta" estiver intacto.

## Smoke

Sem PNG, como diz o card. A lógica nova é pura e está na camada headless, e a
conferência na tela exige dados reais de docentes, que não viram captura. A
etapa de smoke do pipeline, se rodar, limita-se a conferir com `dados/` vazio
que abrir o programa não gera `push_error`/`push_warning` novo. Ela não navega
até a ação, porque não há harness de input.

## Ordem de implementação

Cada passo termina com `python .tools/run_tests.py` verde, exceto os passos 3
e 6, que são o vermelho do TDD.

1. **Leitura.** `relatorios_oferta.gd:231-270` (`verificar_carga_horaria`) e
   `392-416` (a regra da Sugestão, para **não** copiá-la);
   `planejamentooferta.gd:259-320` e `1301-1309`;
   `analise_afinidade.gd:273-332`; e o cabeçalho de `validacao_curricular.gd`
   como modelo de classe estática.
2. **Esqueleto.** Criar `standalone_scripts/analise/carga_docente.gd` com o
   cabeçalho GPL, `class_name CargaDocente extends Resource`, docstring de
   classe `##` e as quatro assinaturas com `##` e corpo trivial (`return {}`,
   `return {}`, `return "ok"`, `return []`). Rodar
   `"C:/Program Files/Godot/Godot_console.exe" --headless --path . --editor --quit`
   para registrar o `class_name`. Suíte verde.
3. **Testes do núcleo (vermelho).** Escrever `test/unit/test_carga_docente.gd`
   com as constantes, os cenários e os testes de apoio. Conferir que falham
   **pelo motivo certo**. AC11, `lista_oficial_do_curso` vazia e o teste de
   não-mutação já passam com o stub e entram como congelamento. Os demais
   falham por asserção.
4. **Núcleo (verde).** Implementar as quatro funções conforme o contrato. Sem
   `print`, sem `elif` depois de `return`.
5. **Delegação no módulo.** Trocar os corpos de `_inicializar_lista_professores`
   e `_calcular_profs_destacar` pelas chamadas a `CargaDocente`. Suíte verde. O
   `var lista` sem tipo sai do módulo.
6. **Relatório.** (a) Acrescentar só o parâmetro
   `profs_oficiais_curso: Dictionary = {}`, sem mudar o corpo. (b) Escrever
   `test/unit/test_relatorios_oferta.gd` (vermelho): o teste do AC1 falha
   porque a Ana não é impressa. O do AC5, o da mensagem de vazio, o do AC11 e
   o dos rótulos já passam e entram como congelamento do texto de hoje. (c)
   Trocar o filtro e o status inline pela chamada a
   `CargaDocente.verificacao_carga` e pelo `match`, e atualizar a docstring.
   Verde. (d) No módulo, passar `_calcular_profs_destacar()` na linha 1302.
7. **Textos.** Dica em `arquivos/dicas.json` e item em `MANUAL.md`, conforme
   "Textos". Conferir que o `dicas.json` continua sendo JSON válido (o main o
   carrega na abertura).
8. **Portões.**
   - `python .tools/guardrails.py`. A catraca está em
     `planejamentooferta.gd`: 3 `static-typing`, 5 `private-docstring`, 1
     `section-order`, 1 `max-line-length`; e em `relatorios_oferta.gd`: 1
     `section-order`, 1 `max-line-length`. Os dois arquivos novos de teste e
     `carga_docente.gd` nascem **sem** violação. Depois do passo 5, rodar
     `python .tools/guardrails.py --update-baseline` e conferir no diff do JSON
     que **só** `planejamentooferta.gd|static-typing` mudou, de 3 para 2.
     Apertar é permitido; afrouxar, nunca.
   - `python .tools/run_tests.py`.
   - `"C:/Program Files/Godot/Godot_console.exe" --headless --path . --editor --quit`.
9. **ACs manuais.** Entregar os roteiros R1 e R2 ao dev.
