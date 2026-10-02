# Spec — 0005-validacao-coerencia-dados-curriculares

Card: `Cards/0005-validacao-coerencia-dados-curriculares/card.md`.

Objetivo: depois de carregar `arquivos/grades/`, `arquivos/equivalencias/` e
`arquivos/cargaexigida/`, o `main.gd` passa a rodar uma checagem de coerência
**entre** os arquivos (o `JsonValidator` continua cuidando só de tipos, um
arquivo por vez). Cada inconsistência vira um `push_warning` com prefixo
próprio. Nada é corrigido, nada é bloqueado, nenhuma UI nova.

A lógica vai para uma classe pura nova, `ValidacaoCurricular`, que recebe os
três dicionários já carregados e devolve os achados como dados. O `main.gd`
ganha uma linha.

---

## Divergências entre o card e os dados reais (ler antes de implementar)

Rodei as regras desta spec, emuladas fora do Godot, sobre os 14 arquivos
versionados de hoje (`fd2d2f8`). O resultado diverge da lista "Defeitos reais"
do card em quatro pontos. A spec resolve cada um como descrito abaixo e o
snapshot do AC12 reflete essas resoluções.

1. **Há 8 defeitos reais de pré-requisito, não 1.** O card cita só o `al5022`
   da `alec_2023`. Pela regra do AC1 ("código que não existe na própria grade"),
   a `alec_2010` tem mais **7**: o mesmo `al5022` (`"ch 50%"`) e 6
   complementares que apontam para códigos que não estão em grade nenhuma
   carregada (`al2106→al0066`, `al2114.prerequisito2→al0149`, `al2128→al0087`,
   `al2144→al0149`, `al2146→al0128`, `al2189→al0062`). O AC1 obriga a
   reportá-los, e o AC12 proíbe reportar "outros". Resolvo o conflito a favor
   do AC1: os 7 são positivos verdadeiros que o levantamento do card (feito na
   `alec_2023`) não pegou, e entram no snapshot. Podem ser códigos de um PPC
   anterior que nunca foi carregado. A triagem fica com o coordenador, que é o
   non-goal "não corrige nada".
2. **`agc` × `acg` não é detectável dentro do escopo do card.** O AC10 diz que
   uma chave de `cargaexigida/` que não corresponde a núcleo nenhum **não** é
   reportada, e `agc` é exatamente isso. O goal do card enumera cinco tipos de
   regra, e nenhum deles alcança essa chave. Para pegá-la seria preciso um
   vocabulário canônico de categorias de carga. Esse vocabulário (que na
   `alec_2023` também teria `obrigatórios`, `unipampa_cidada`,
   `unipampa_comunidade` e `outras_extensoes`) seria uma chave nova de
   `base_config.json` e um contrato de dados novo. Isso é escopo de outro card.
   A spec **congela** o comportamento de não reportar (o AC12 prova que `agc`
   fica fora dos 8 achados), e o caso continua como "herança aberta", que é o
   status que já tem no handoff de 2026-10-02.
3. **`cargaexigida/alem_2023.json` já é JSON válido.** O commit `a8d7339`
   ("...corrige o JSON invalido da carga exigida do alem") corrigiu o arquivo.
   O requisito do card continua de pé ("comportar-se bem quando o parse falhou e
   o dicionário chega vazio") e é provado com fixture no AC11. Hoje ele não
   aparece nos dados reais.
4. **Os arquivos de equivalência usam chaves `//...` como comentário.**
   `alec_2010-alec_2023.json` tem 4 dessas chaves (o arquivo inteiro é
   comentário: "nao usar este arquivo") e `alec_2023-alec_2010.json` tem 3.
   Sem tratamento, elas gerariam 14 falsos positivos (origem e destino de cada
   uma). Regra: chave de equivalência que começa com `//` é comentário e é
   ignorada inteira. Não existe precedente no código; o precedente está no
   próprio dado.

Duas decisões de interpretação, também refletidas nos testes:

- **AC4, "prerequisitoN + corequisitoN".** Nos dados reais o idioma usa índices
  **diferentes**: `al0385` tem `prerequisito1` + `corequisito0` (é o exemplo que
  o próprio card cita), e `al0088` e `al0164`, na 2010, seguem o mesmo padrão.
  Só o `al0142` usa o mesmo índice. A exceção vale **por código**: o
  pré-requisito cujo código aparece em qualquer `corequisitoM` da mesma
  disciplina fica fora da regra de ordem, qualquer que seja o `M`.
- **`corequisito*` entra nas regras de código inexistente e de numeração.** O
  card cita só `prerequisito*`, mas todo leitor do programa percorre as duas
  famílias com `while has(prefixo + str(i))`, então um buraco trunca as duas do
  mesmo jeito. Pior: `analise_curricular.gd:133` indexa
  `grades[versao][codigo_do_corequisito]` sem `get`, de modo que um corequisito
  com código inexistente **quebra** a análise. A extensão não muda o snapshot:
  todo corequisito real existe na sua grade.

Um resíduo que este validador **não** alcança, registrado para o handoff:
`alec_2023-alec_2010.json` tem a chave `al0367` **repetida** (`→ al0174` e
`→ al0047`). Quando o dicionário chega ao validador, o parse já ficou com um
valor só. A forma correta no formato existente seria um Array
(`"al0367": ["al0174", "al0047"]`), que é o 1:N já suportado. Detectar isso
exige ler o texto cru, e fica fora deste card.

---

## Camadas tocadas

| Arquivo | Por quê |
|---|---|
| `standalone_scripts/analise/validacao_curricular.gd` | **Novo.** `class_name ValidacaoCurricular extends Resource`, com cabeçalho GPL como os demais `analise_*`. Funções `static`, seguindo o precedente do `JsonValidator.validar_*` e do `AnaliseHorarios.ordenar_condicoes`, para o main chamar sem instância. Fica em `analise/` e não em `utils/` porque codifica regra de domínio (ordem de pré-requisitos, placeholder `0000`, núcleo × carga), não um utilitário genérico. Também não vira extensão do `JsonValidator`: aquele valida **um arquivo por vez** via `Callable` no `_carregar_json_de`, e esta checagem precisa dos três conjuntos carregados. |
| `scenes/main.gd` | Uma chamada em `_carregar_arquivos()`, logo depois dos três `_carregar_json_de` e antes de `_derivar_grades_cursos()`: `ValidacaoCurricular.validar(GV.grades, GV.equivalencias, GV.ch_exigida)`, com o retorno ignorado (precedente: `JsonValidator.validar_base_config` na linha 49). Nenhuma leitura nova. `_carregar_json_de` e `JsonValidator` não mudam. |
| `test/unit/test_validacao_curricular.gd` | **Novo.** Suíte GUT com fixtures inline fictícias (cursos `zz`/`yy`, inexistentes) para os ACs 1–11 e os edge cases, e um teste de snapshot sobre os arquivos reais versionados de `arquivos/` para o AC12. |
| `MANUAL.md` | Subseção nova **6.6 Conferência dos dados curriculares** (ver "Ordem de implementação", passo 8). O sumário lista só as seções de topo e não muda. |

São três camadas de código (núcleo `analise/`, composição `main.gd`, teste),
dentro do limite. Os arquivos `.uid` que o Godot gera para os dois `.gd` novos
são versionados, como todos os outros.

Fora do diff, de propósito: `json_validator.gd`, `file_handling.gd`,
`base_config.json`, todo arquivo de `arquivos/` (nada é corrigido) e todo
módulo de cena (sem UI).

---

## Contrato público novo

```gdscript
const PREFIXO: String = "VALIDACAO COERENCIA"

static func inconsistencias(grades: Dictionary, equivalencias: Dictionary, cargas_exigidas: Dictionary) -> Array[Dictionary]
static func formatar(achado: Dictionary) -> String
static func validar(grades: Dictionary, equivalencias: Dictionary, cargas_exigidas: Dictionary) -> int
```

### `inconsistencias`

- **Quem chama:** `validar` (produção) e a suíte (testes).
- **O que recebe:** os três dicionários exatamente como o main os monta, cada
  um com uma chave por arquivo, igual ao nome sem `.json`:
  `grades = {"alec_2023": {...}}` (`GV.grades`),
  `equivalencias = {"alec_2023-alec_2010": {...}}` (`GV.equivalencias`) e
  `cargas_exigidas = {"alec_2023": {...}}` (`GV.ch_exigida`). O nome do
  parâmetro segue o precedente de injeção `modulo.cargas_exigidas = GV.ch_exigida`
  (`main.gd:671`).
- **O que garante:**
  - É pura: nenhum `FileAccess`/`DirAccess`, nenhum `GV`, nenhum nó, nenhum
    `push_*`, e não muta os argumentos.
  - É determinística: segue a ordem de iteração dos dicionários recebidos
    (grades, depois equivalências, depois cargas). Dentro de uma disciplina, a
    família `prerequisito` vem antes de `corequisito`.
  - Não quebra com entrada malformada: entrada de grade que não é `Dictionary`
    é pulada (o `JsonValidator` já acusa o tipo), e valor de equivalência que
    não é `String` nem `Array` também é pulado.
  - **Dicionário vazio vale como arquivo ausente**, para grade, equivalência
    ou carga: é assim que o `FileHandling.load_json` entrega um parse que
    falhou, e tratá-lo como "presente sem nada" geraria cascata de falso
    positivo.
- **O que assume do chamador:** nada além dos três dicionários, que podem vir
  vazios.

### O achado

Cada achado é um `Dictionary` com chaves em snake_case e **todos os valores
`String`**. As chaves comuns, presentes sempre, são:

| Chave | Conteúdo |
|---|---|
| `regra` | identificador da regra (tabela abaixo) |
| `chave` | chave do arquivo onde o defeito está: grade (`alec_2023`) ou equivalência (`alec_2023-alec_2010`). Em `nucleo_sem_carga`, é a chave da grade, que é também o nome do arquivo de carga |
| `codigo` | disciplina (regras de grade), chave-fonte da equivalência ou núcleo |

E as chaves específicas de cada regra (precedente: os dicionários de
`divergencias` em `CalculoCargaHoraria.ch_vencida`):

| `regra` | Chaves extras | Quando |
|---|---|---|
| `requisito_inexistente` | `nome`, `campo` (`prerequisito0`, `corequisito1`...), `valor` (o código apontado, via `str()`) | o valor de `prerequisitoK`/`corequisitoK` não é chave da **própria** grade. A comparação é exata, sem `to_lower`: a convenção é minúscula, e o valor literal entre aspas na mensagem deixa um problema de caixa evidente |
| `requisito_numeracao` | `nome`, `campo` (`prerequisito` ou `corequisito`), `indice_ausente` | existe uma chave `prefixoK` (`K` inteiro) que a leitura sequencial do programa (`prefixo0`, `prefixo1`... até a primeira ausente) não alcança. `indice_ausente` é o primeiro índice que a leitura não encontra. Exemplos: `{0, 1, 3}` dá `"2"` e `{1}` dá `"0"`. Um achado por disciplina e família |
| `requisito_fora_de_ordem` | `nome`, `campo` (`prerequisitoK`), `valor` (código do pré-requisito), `semestre`, `semestre_requisito` | a disciplina e o pré-requisito **participam da ordem** (ver abaixo), o pré-requisito existe na grade, `semestre_requisito >= semestre`, e o código do pré-requisito **não** aparece em nenhum `corequisito*` da disciplina |
| `semestre_posicao_divergente` | `nome`, `semestre`, `posicao_grade` | a disciplina **tem** `posicao_grade` e `semestre` como inteiro difere de `int(posicao_grade[0])`. O valor vem do JSON como float (`4.0`), então a comparação é por `int`, nunca por `str`. Um `posicao_grade` que não é `Array` ou é vazio conta como divergente, com `posicao_grade = str(valor)` |
| `equivalencia_inexistente` | `campo` (`origem` ou `destino`), `valor` (código ausente), `grade` (chave da grade onde ele falta) | ver "Regra de equivalência" |
| `nucleo_sem_carga` | `disciplinas` (quantas disciplinas da grade usam o núcleo) | ver "Regra de núcleo" |

**Participa da ordem** (regras `requisito_fora_de_ordem` e, só pela presença
de `posicao_grade`, `semestre_posicao_divergente`): a disciplina tem
`posicao_grade` **e** `semestre` como inteiro maior que 0. `semestre` não
numérico conta como 0. Ficam de fora, dos dois lados da relação, a
complementar (`semestre: "0"`, sem `posicao_grade`) e a disciplina de grade
placeholder (`alcc_0000`: `semestre: "1"` sem `posicao_grade`). Isso cumpre o
AC6. O semestre usado na comparação de ordem é o campo `semestre`; a
divergência dele com `posicao_grade` é problema da outra regra.

**Regra de equivalência.** A chave do arquivo é partida em `-`. Se não sair
exatamente `<origem>-<destino>`, o arquivo é pulado em silêncio (nome de
arquivo fora da convenção não é assunto deste card). Para cada entrada:

- chave que começa com `//`: comentário, pulada inteira;
- **origem:** se a grade de origem não termina em `_0000` (o mesmo predicado
  `ends_with("_0000")` que `exportadores.gd:116`, `matricula_irregular.gd:81` e
  `situacao_disciplinas.gd:140` já usam) e está carregada e não vazia, a
  chave-fonte precisa ser chave dessa grade. Caso contrário, o achado sai com
  `campo: "origem"`, `valor` = chave-fonte e `grade` = origem;
- **destino:** com o mesmo filtro aplicado à grade de destino, cada valor (a
  `String` ou cada elemento do `Array`, o 1:N) precisa ser chave dela. Caso
  contrário, sai um achado por valor ausente com `campo: "destino"`;
- `codigo` é sempre a chave-fonte.

**Regra de núcleo.** Para cada grade cuja carga exigida existe e não está
vazia, cada `nucleo` não vazio usado por alguma disciplina precisa ser chave da
carga. Sai **um achado por núcleo** (não um por disciplina), com
`codigo` = núcleo. Disciplina sem `nucleo` é ignorada: na `alec_2023`, as 71
obrigatórias não têm o campo. Chaves da carga que não são núcleo (`estagio`,
`tcc`, `praticas`, `acg`, `obrigatórios`, `unipampa_*`, `agc`...) nunca geram
achado (AC10). Carga sem grade correspondente, e grade sem carga, são no-op.

### `formatar`

- **Quem chama:** `validar`, e os testes, para provar que a mensagem nomeia
  disciplina e código.
- **O que garante:** a mensagem começa com `PREFIXO + ": "`, cita o arquivo
  pelo caminho relativo a `arquivos/` (pasta deduzida da regra) e contém
  `codigo` e, quando o achado tem, `nome` e `valor`. Achado com `regra`
  desconhecida não quebra: sai `PREFIXO + ": " + str(achado)`. A parte fixa do
  texto vai sem acento, como no `JsonValidator`; `nome` vem do dado como está.
  É a conversão para apresentação, feita no momento da saída (regra snake_case
  do `AGENTS.md`).
- Modelos (guia, não contrato literal; os testes só exigem prefixo, arquivo e
  os campos citados):

  | `regra` | Mensagem |
  |---|---|
  | `requisito_inexistente` | `VALIDACAO COERENCIA: grades/alec_2023.json -> al5022 (Metodologia de Trabalho Científico): prerequisito0 aponta para 'ch 50%', que nao existe nesta grade` |
  | `requisito_numeracao` | `... -> zz0005 (...): numeracao de prerequisito pula o indice 2; os seguintes nao sao lidos pelo programa` |
  | `requisito_fora_de_ordem` | `... -> zz0004 (...): prerequisito0 = zz0003 e do semestre 3, igual ou posterior ao da disciplina (3)` |
  | `semestre_posicao_divergente` | `... -> zz0006 (...): semestre 3 difere de posicao_grade[0] = 4` |
  | `equivalencia_inexistente` | `VALIDACAO COERENCIA: equivalencias/zz_2010-zz_2023.json -> zz9001: codigo 'zz0404' (destino) nao existe na grade zz_2023` |
  | `nucleo_sem_carga` | `VALIDACAO COERENCIA: cargaexigida/zz_2023.json nao tem a chave 'basico', nucleo usado por 2 disciplina(s) de grades/zz_2023.json` |

### `validar`

- **Quem chama:** `main.gd::_carregar_arquivos` (produção, retorno ignorado) e
  os testes de emissão.
- **O que garante:** chama `inconsistencias`, emite **um** `push_warning(formatar(achado))`
  por achado, na ordem dos achados, e devolve quantos emitiu. Sem achado, não
  emite nada e devolve 0 (é o "no-op silencioso" do AC11).
- Este é o único ponto com efeito colateral (o log). A separação dados/emissão
  é o que deixa os ACs testáveis por estrutura, e não por texto de log.

Helpers privados sugeridos, que não são contrato: `_inconsistencias_grade`,
`_inconsistencias_equivalencia`, `_inconsistencias_carga`,
`_participa_da_ordem`, `_chaves_da_familia`, `_semestre`, `_eh_placeholder`,
`_eh_comentario`. São `static`, documentados com `#`.

Regra de dependência: a classe só conhece `Dictionary`/`Array`/`String`.
Nenhum módulo de cena, nenhum `GV`, nenhum arquivo. O guardrail
`filesystem-boundary` não tem o que acusar.

---

## Invariantes

| Invariante | Como esta feature se comporta |
|---|---|
| **1. Dado pessoal não sai do PC** | Toca só dado curricular público (`arquivos/grades\|equivalencias\|cargaexigida`, versionados no repositório público): códigos e nomes de disciplina, chaves de grade, nomes de núcleo. A saída é `push_warning` (console e `user://logs/`, fora do repositório). Nenhuma exportação, nenhuma rede. O teste do AC12 lê **só** essas três pastas e nunca `arquivos/oferta/` (dado nominal de docente) nem `dados/`. As fixtures dos outros testes são inline e fictícias (`zz`/`yy`). Nenhum arquivo novo na raiz do projeto, então o `exclude_filter` não muda (`test/*` já está em todos os presets). Sem PNG de smoke. |
| **2. snake_case interno, formatação só na UI** | Os achados são dados em snake_case (`regra`, `chave`, `codigo`, `campo`, `indice_ausente`, `semestre_requisito`...). Os identificadores de regra também são snake_case. O texto legível só nasce em `formatar`, no momento do `push_warning`. A chave `obrigatórios` (com acento) da carga exigida é dado existente e congelado: o validador só a lê como chave e não a renomeia nem a cobra. |
| **3. Cursos e chaves canônicas** | Usa as convenções sem duplicá-las: grade `<cod_curso>_<versao>` como chave recebida, equivalência `<origem>-<destino>` partida em `-` e placeholder pelo mesmo `ends_with("_0000")` dos três módulos que já o tratam. Nenhuma lista de cursos, nenhum acesso a `base_config.json:cursos`. |
| **4. Leitura no main; programa funciona com arquivo ausente** | Zero I/O novo. O main já leu tudo e só repassa `GV.grades`, `GV.equivalencias` e `GV.ch_exigida`. Pasta ausente, arquivo ausente ou parse falho chegam como chave ausente ou dicionário vazio, e o resultado é no-op sem erro (AC11). A validação nunca impede o carregamento: o retorno é ignorado, como o do `JsonValidator`. |
| **5. UI pelas fachadas** | Não toca. Nenhum tooltip, diálogo, cor ou Terminal (non-goal explícito do card). |

---

## Mapeamento AC → prova

Todos os testes ficam em `test/unit/test_validacao_curricular.gd` e rodam com
`python .tools/run_tests.py` (`-gselect=validacao` roda só esta suíte). Os
nomes abaixo são contrato para a fase de implementação.

Fixtures inline: grade fictícia `zz_2023` montada por teste, mínima (só o que
o AC exige), com `nome` fictício ("Disciplina Zeta Um"...) e `posicao_grade`
como Array de float (`[1.0, 1.0]`), para reproduzir o tipo que o JSON entrega.
Equivalências com `zz_2010-zz_2023` e `yy_0000-zz_2023`. Nenhum código real
nas fixtures.

| AC do card | Método | Onde |
|---|---|---|
| AC1. `prerequisito0` para código inexistente é reportado, nomeando disciplina e código | headless | `::test_prerequisito_inexistente_e_reportado`. Grade com `zz0002.prerequisito0 = "zz9999"`. `inconsistencias` devolve exatamente `[{regra: requisito_inexistente, chave: zz_2023, codigo: zz0002, nome: <nome>, campo: prerequisito0, valor: zz9999}]`, e `formatar` desse achado contém `zz0002`, o nome e `zz9999` |
| AC2. Buraco na numeração (`0`, `1`, `3`) é reportado | headless | `::test_buraco_na_numeracao_de_prerequisito_e_reportado`. `zz0005` com `prerequisito0/1/3` apontando para códigos existentes de semestre anterior, para nenhuma outra regra disparar, gera exatamente um achado `requisito_numeracao` com `campo: prerequisito` e `indice_ausente: "2"`. Segundo caso: só `prerequisito1` gera `indice_ausente: "0"` |
| AC3. Pré-requisito do mesmo semestre ou de semestre posterior é reportado | headless | `::test_prerequisito_de_semestre_igual_ou_posterior_e_reportado`. Disciplina do semestre 3 com um pré-requisito do semestre 3 e outra do semestre 2 com um do semestre 4: dois achados `requisito_fora_de_ordem` (`assert_has` + tamanho), com `semestre` e `semestre_requisito` corretos. Controle no mesmo teste: um pré-requisito de semestre anterior não gera achado |
| AC4. Par `prerequisito` + `corequisito` do mesmo código não é reportado pela regra de ordem | headless | `::test_par_prerequisito_corequisito_nao_e_fora_de_ordem`. Mesmo semestre, nas duas formas reais: mesmo índice (`prerequisito0` + `corequisito0`, como `al0142`) e índice cruzado (`prerequisito1` + `corequisito0`, como `al0385`). `inconsistencias == []` |
| AC5. `semestre` diferente de `posicao_grade[0]` é reportado | headless | `::test_semestre_divergente_de_posicao_grade_e_reportado`. `semestre: "3"`, `posicao_grade: [4.0, 1.0]` geram `{regra: semestre_posicao_divergente, semestre: "3", posicao_grade: "4"}`. Controle: `semestre: "2"`, `[2.0, 5.0]` não geram achado, o que prova a comparação por `int` diante do float do JSON |
| AC6. Disciplina sem `posicao_grade` (complementar) não é reportada pelas regras de semestre | headless | `::test_disciplina_sem_posicao_grade_fica_fora_das_regras_de_semestre`. Complementar `semestre: "0"` sem `posicao_grade` exigindo uma obrigatória do semestre 9; obrigatória exigindo complementar; complementar exigindo complementar; e uma disciplina `semestre: "1"` sem `posicao_grade` (forma do `alcc_0000`) exigindo outra igual. `inconsistencias == []` |
| AC7. Equivalência para código ausente na grade correspondente é reportada | headless | `::test_equivalencia_para_codigo_ausente_e_reportada`. Em `zz_2010-zz_2023`: destino `String` ausente (`zz9001 → zz0404`), origem ausente (`zz9404` fora da `zz_2010`) e destino `Array` com um elemento ausente (`zz9002 → ["zz0001", "zz0405"]`). Saem três achados `equivalencia_inexistente` com `campo`, `valor` e `grade` corretos; o elemento presente do Array não gera achado |
| AC8. Lado placeholder `0000` não é reportado | headless | `::test_lado_placeholder_0000_nao_e_reportado`. `yy_0000` **carregada**, mas sem a fonte (`yy_0000-zz_2023: {yy0999: zz0001}`), e `zz_2023-yy_0000: {zz0001: yy0998}` com destino placeholder: `inconsistencias == []` |
| AC9. Núcleo usado sem chave na carga exigida da mesma grade é reportado | headless | `::test_nucleo_sem_carga_exigida_e_reportado`. Duas disciplinas `basico`, uma `cccg`, carga `{"cccg": "100"}`: exatamente `[{regra: nucleo_sem_carga, chave: zz_2023, codigo: basico, disciplinas: "2"}]` |
| AC10. Chave da carga sem núcleo correspondente não é reportada | headless | `::test_chave_de_carga_sem_nucleo_nao_e_reportada`. Grade só com `cccg` e carga `{cccg, estagio, tcc, praticas, acg}`: `inconsistencias == []` |
| AC11. Grade, equivalência ou carga ausente é no-op silencioso, sem erro | headless | `::test_arquivos_ausentes_sao_no_op_silencioso`: `validar({}, {}, {}) == 0` e `assert_push_warning_count(0)`; grade sem carga, equivalência com origem e destino não carregados, e carga sem grade dão 0 avisos. `::test_dicionario_vazio_por_parse_falho_e_no_op`: carga `{}` para grade com núcleos e grade `{}` referenciada por equivalência dão 0 avisos (é o caso do `alem_2023` inválido descrito no card). O "sem erro" vem do GUT, que reprova por padrão qualquer erro de engine ou `push_error` (`failure_error_types`) |
| AC12. Sobre os arquivos reais, `push_warning` para os defeitos conhecidos e para nenhum outro | headless | `::test_arquivos_reais_reportam_so_os_defeitos_conhecidos`. Carrega `res://arquivos/grades/`, `equivalencias/` e `cargaexigida/` como o main faz (só `.json`, chave = nome sem extensão, parse por `FileHandling.load_json`). Compara a **identidade** de cada achado (`regra`, `chave`, `codigo`, `campo`, `valor`; sem `nome`, para não quebrar se o nome mudar) com o snapshot abaixo, exigindo que os conjuntos sejam iguais nos dois sentidos. Depois chama `validar` e exige `assert_push_warning_count(8)` e `assert_push_warning("al5022")`. A mensagem de falha deve dizer o que fazer: "defeito X não aparece mais: se foi corrigido no repositório do curso e sincronizado, remova-o do snapshot" e "achado novo Y: triagem — defeito real (some ao snapshot) ou falso positivo (corrija a regra)" |

### Snapshot do AC12 (dados de `fd2d2f8`)

Exatamente estes 8 achados, todos com `regra: requisito_inexistente`
(identidade sem `nome`):

| # | `chave` | `codigo` | `campo` | `valor` |
|---|---|---|---|---|
| 1 | `alec_2010` | `al2106` | `prerequisito0` | `al0066` |
| 2 | `alec_2010` | `al2114` | `prerequisito2` | `al0149` |
| 3 | `alec_2010` | `al2128` | `prerequisito0` | `al0087` |
| 4 | `alec_2010` | `al2144` | `prerequisito0` | `al0149` |
| 5 | `alec_2010` | `al2146` | `prerequisito0` | `al0128` |
| 6 | `alec_2010` | `al2189` | `prerequisito0` | `al0062` |
| 7 | `alec_2010` | `al5022` | `prerequisito0` | `ch 50%` |
| 8 | `alec_2023` | `al5022` | `prerequisito0` | `ch 50%` |

As outras cinco regras dão zero achados nos dados reais. Isso já inclui as 7
chaves `//` ignoradas, os lados `_0000`, as 4 duplas pré + co (nenhuma de
mesmo semestre), as 71 obrigatórias sem `nucleo` da `alec_2023` e as chaves
não-núcleo das três cargas, `agc` entre elas. É essa ausência que dá o "nenhum
outro" do AC.

### Edge cases do card e decisões da spec (mesma suíte)

| Caso | Onde |
|---|---|
| Corequisito para código inexistente (extensão; evita o crash de `analise_curricular.gd:133`) | `::test_corequisito_inexistente_e_reportado`: `corequisito0 = "zz9998"` gera `requisito_inexistente` com `campo: corequisito0` |
| Chave `//` em equivalência é comentário | `::test_comentario_em_equivalencia_e_ignorado`: `{"//cod de zz_2010": "que equivale este cod de zz_2023"}` gera `[]` |
| Grade com obrigatórias sem `nucleo` (forma da `alec_2023`) | `::test_obrigatorias_sem_nucleo_nao_sao_reportadas`: obrigatórias sem o campo, complementares `cccg` e carga `{cccg}` geram `[]` |
| Emissão: um aviso por achado, com prefixo | `::test_validar_emite_um_push_warning_por_achado`: fixture com 2 achados dá `validar == 2`, `assert_push_warning_count(2)` e `assert_push_warning("VALIDACAO COERENCIA")` |
| Entrada malformada não quebra | `::test_entrada_malformada_nao_quebra`: entrada de grade que não é `Dictionary` é pulada; `posicao_grade: []` gera `semestre_posicao_divergente`; valor de equivalência numérico é pulado. Sem erro de engine |

Se o rastreador de `push_warning` do GUT 9.7.1 (`assert_push_warning*`,
`error_tracker.gd`) não capturar avisos neste setup headless, o implementador
registra isso no review e cai para o retorno de `validar` (a contagem) mais as
asserções estruturais sobre `inconsistencias`. A emissão em si é um laço de
uma linha.

---

## Riscos de contrato de dados

- **Nenhuma chave nova, nenhum renome, nenhum arquivo de dado editado.** Os
  JSONs de `arquivos/`, o `base_config.json`, os records do Kinto e os formatos
  de `dados/` ficam intocados. O validador só **lê** os dicionários que o main
  já carrega.
- **Convenções que o validador passa a assumir, todas já presentes no dado:**
  - `//` no início de chave de equivalência é comentário;
  - `_0000` é placeholder;
  - pré-requisito e corequisito em `prefixoK` sequencial a partir de 0, como
    todo leitor do programa espera;
  - `posicao_grade[0]` é o semestre.

  Nenhuma é imposta a quem não a segue: um desvio vira aviso, nunca falha de
  carga.
- **Tipos do JSON:** `posicao_grade` chega como float (`[4.0, 1.0]`) e
  `semestre` como String. A comparação é sempre `int` × `int`, a armadilha já
  mordida no projeto (turma `40` × `40.0`). As fixtures usam float de propósito.
- **Acoplamento do AC12 com os dados reais (aceito, intencional).** O snapshot
  congela os 8 defeitos de hoje. Quando o coordenador corrigir o `al5022` no
  `alec-data` e sincronizar, ou uma sincronização trouxer defeito novo, o
  teste falha, e o pre-commit junto. É a catraca do dado: obriga a triagem
  (corrigir o snapshot ou a regra) no próprio commit da sincronização, e a
  mensagem de falha diz o que fazer.
- **Log:** o programa passa a emitir 8 `push_warning` `VALIDACAO COERENCIA` a
  cada inicialização com os dados de hoje. O diff de log do `godot-smoke-test`
  de cards futuros vai vê-los nos dois lados (antes e depois), mas quem montar
  a baseline de log deve saber que eles são esperados.
- **LGPD:** a superfície nova é o texto dos avisos, que leva só dado curricular
  público (código, nome de disciplina, chave de grade, núcleo). Nada de aluno
  ou docente aparece em tela, log, exportação ou rede. O teste versionado cita
  códigos curriculares reais (públicos) no snapshot e nada além disso.

---

## Ordem de implementação

Cada passo termina com `python .tools/run_tests.py` verde e
`python .tools/guardrails.py` limpo.

1. **Esqueleto e regras de requisito (AC1, AC2, corequisito).** Escrever os
   testes `test_prerequisito_inexistente_e_reportado`,
   `test_buraco_na_numeracao_de_prerequisito_e_reportado` e
   `test_corequisito_inexistente_e_reportado`, que falham porque a classe não
   existe. Criar `standalone_scripts/analise/validacao_curricular.gd` (GPL,
   `class_name`, `PREFIXO`, públicas antes de privadas) com `inconsistencias`
   e as regras `requisito_inexistente` e `requisito_numeracao`. Classe com
   `class_name` nova precisa entrar no cache de classes globais antes de o GUT
   enxergá-la: rodar uma vez
   `"C:/Program Files/Godot/Godot_console.exe" --headless --path . --editor --quit`.
   Fica verde.
2. **Regras de semestre (AC3–AC6).** Testes de ordem, do par pré + co (as duas
   formas), de `posicao_grade` com o controle float e da complementar fora das
   regras. Implementar `_participa_da_ordem`, `requisito_fora_de_ordem` e
   `semestre_posicao_divergente`. Fica verde.
3. **Regra de equivalência (AC7, AC8, comentário).** Testes de origem e
   destino ausentes (String e Array), placeholder dos dois lados e chave `//`.
   Implementar. Fica verde.
4. **Regra de núcleo (AC9, AC10, obrigatórias sem núcleo).** Testes e
   implementação. Fica verde.
5. **No-op e emissão (AC11, emissão, malformado).** Testes de ausência, de
   dicionário vazio, de `validar` (contagem e `assert_push_warning*`) e de
   entrada malformada. Implementar `formatar` e `validar`. Fica verde.
6. **Snapshot real (AC12).** Teste com o carregamento de
   `res://arquivos/{grades,equivalencias,cargaexigida}/` e o snapshot dos 8.
   Ele deve nascer verde com os passos 1–5. Se não nascer, a divergência é
   achado da implementação (regra diferente desta spec) ou dado que mudou
   depois de `fd2d2f8`. As duas coisas vão para o review, sem ajustar o
   snapshot às cegas.
7. **Fiação no main.** Uma linha em `_carregar_arquivos()` depois dos três
   `_carregar_json_de`, com um comentário curto ("coerencia entre os arquivos:
   so avisa, nao bloqueia"). Validar com o parser real
   (`--headless --path . --editor --quit`; o `--check-only` isolado é falso
   positivo, não usar) e conferir no output que os 8 avisos `VALIDACAO COERENCIA`
   aparecem.
8. **MANUAL.md, subseção 6.6 "Conferência dos dados curriculares".** Ao
   iniciar, o programa confere a coerência entre grades, equivalências e
   cargas exigidas: pré-requisito ou corequisito para código inexistente,
   buraco na numeração, pré-requisito do mesmo semestre ou posterior (exceto o
   par com corequisito), semestre diferente da posição na grade, equivalência
   para código ausente (o lado `_0000` e as chaves `//` ficam de fora) e núcleo
   sem carga exigida. Os avisos aparecem só no console (`Auxiliar.console.exe`
   e `Auxiliar_debug.console.exe`) ou no editor. Nada é corrigido nem bloqueado:
   a correção é feita no repositório do curso. Tom e formato das seções 6.x
   vizinhas.
9. **Portões finais.** `python .tools/guardrails.py`,
   `python .tools/run_tests.py` e o parser headless. Conferir no diff que
   `json_validator.gd`, `file_handling.gd`, `base_config.json` e todo arquivo
   de `arquivos/` não mudaram, que os dois `.uid` novos entraram e que
   `git status` não mostra nada de `dados/` ou de `arquivos/oferta/`. Os
   resíduos desta spec (o `agc` sem vocabulário canônico, a chave duplicada
   `al0367` e os 7 códigos órfãos da `alec_2010` para triagem do coordenador)
   vão para o `review.md` e o handoff, **não** viram card nesta execução.
