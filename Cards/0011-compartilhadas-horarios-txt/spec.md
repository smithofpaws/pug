# Spec — 0011-compartilhadas-horarios-txt

Card: `Cards/0011-compartilhadas-horarios-txt/card.md`.

Objetivo: uma linha do `horarios.txt` cuja disciplina é ofertada para mais de
um curso (semestre `EC03;EMExtra`, `EE03;EC03`…) passa a usar a **mesma chave
que o `planejamento.csv` gerou** para ela (`al0015_ec03`). Hoje ela usa o campo
inteiro (`al0015_ec03;emextra`). Para isso, entram em `ArquivosPlanejamento`
duas funções `static` puras: uma escolhe a parte que recebe a linha (regras
1–3 e 5 do card) e outra desempata as chaves duplicadas (regra 4). Elas são
usadas em `preparar_alocacoes_do_txt` (Abrir horarios.txt) e em
`mesclar_planejamento_com_horarios_txt` (Atualizar planejamento). O
`adicionar_planejamento_csv_do_txt` passa a preservar a oferta combinada. O
módulo de cena não muda.

## Fatos do código que esta spec usa

Conferidos na leitura do código em 2026-11-18. Nenhum arquivo de `dados/` foi
lido.

- **O leitor do CSV põe tudo em minúsculas.** `FileHandling.read_csvfile`
  aplica `get_line().to_lower()` antes de dividir a linha. Por isso o
  `_planejamento_csv` que vem do `planejamento.csv` fica assim:
  - `semestre = "ec03"`;
  - `oferta = "ec03;emextra"`: a célula inteira, inclusive os espaços que ela
    tiver (`"ea09; ee09; ec07"`);
  - os nomes de professor também em minúsculas.

  A chave é `<codigo>_<parte.strip_edges().to_lower()>`. Quando a mesma
  disciplina e a mesma parte se repetem, a chave ganha `_2`, `_3`… num laço
  `while planejamento.has(chave)` (`file_handling.gd:170-175`).
- **`FileHandling.dividir_semestres` quebra a célula só no primeiro delimitador
  presente.** Com `[";", "/"]`, `"EC03/EE03;EM03"` vira `["EC03/EE03", "EM03"]`.
  Para manter a paridade com o CSV, o txt usa **a mesma função**, com o mesmo
  comportamento. Não se escreve um terceiro divisor.
- **Delimitadores.** Sem lista, `dividir_semestres` usa `[";", "/", "-"]`. O
  `base_config.json:delimitadores.planejamento` traz `[";", "/"]`. O código novo
  lê `_delimitadores.get("planejamento", [])`, porque o helper de teste do card
  0010 injeta `{}` e `_delimitadores["planejamento"]` quebraria. Os testes desta
  spec injetam `{"planejamento": [";", "/"]}`, igual ao config.
- **`preparar_alocacoes_do_txt` devolve `valido = false` quando sobra uma linha
  ou nenhuma depois do filtro** (`arquivos_planejamento.gd:287`). Com prefixos,
  a linha de cabeçalho (`1," "," "…`) não passa no filtro. Por isso toda fixture
  chamada com prefixos precisa de **pelo menos 2 linhas que passem**.
- **Os limites da grade são exclusivos.** A hora de índice `i` vira a linha
  `i + 1`, que só entra se for `< linhas_grade`. O teste passa
  `linhas_grade = HORAS.size() + 1` e `colunas_grade = DIAS.size() + 1`. Sem
  isso, toda linha cai em `ignoradas`.
- **`read_csvfile` descarta linha com menos colunas que o cabeçalho**
  (`nof_columns <= line.size()`). Toda linha do CSV de teste tem o mesmo número
  de vírgulas do cabeçalho, inclusive os campos vazios do fim.
- **Quem chama `preparar_alocacoes_do_txt` com prefixos vazios:**
  - `_aplicar_referencia_txt` (import de referência,
    `planejamentohorario.gd:2373`);
  - `_on_importar_horarios_button_up` (linha 546). Esse não está ligado a
    nenhum sinal, nem no `.tscn` nem no código: é código morto.

  O caminho do curso próprio
  (`_on_cursos_selecionados_horario` → `_importar_horarios_com_prefixos`) nunca
  chama com lista vazia, porque aborta antes.
- **`_aplicar_referencia_txt` depende do campo inteiro.** Três pontos dele usam
  o que `preparar` devolve:
  - pula a disciplina quando `_planejamento_csv.has(chave)`;
  - deduz o curso de origem por `info["sem"]`;
  - grava `oferta = info["sem"]`. É essa oferta que `_oferta_cruza_cursos` lê
    para o aviso de compartilhada divergente.

  Se a referência passasse a usar `al0019_ec03`, a primeira checagem a
  descartaria (é a chave do card próprio), e o aviso sumiria. É o AC9.
- **O lado do planejamento em `mesclar` casa por `chave_base` + professor.**
  `chave_base` = `codigo.to_lower() + "_" + semestre.to_lower()`, sem o `_N`
  (`arquivos_planejamento.gd:610`). As chaves `_2` de uma mesma disciplina
  consomem a mesma lista de horários do txt. Isso é comportamento atual, e esta
  spec não o muda.
- **Reabrir o `planejamento.json` funde as duplicadas.**
  `_converter_disciplinas_json` junta código+semestre iguais na chave base. As
  alocações de `al0390_ec07_2` voltam no card `al0390_ec07`. É comportamento
  atual e non-goal. O R14 avisa o dev disso.
- **`dias_da_semana` e `horas_das_aulas` leem `GV.configuracao_base`, não o
  `horarios.ini`.** `exportar_planejamento_json` precisa deles para preencher
  `dia` e `horario`. O teste salva e restaura `GV.configuracao_base`, como faz
  `test_analise_horarios.gd`.
- **Nada no caminho emite `push_error`.** `AnaliseGrades.info_grade(...,
  silencioso = true)`, `read_csvfile`, `carregar_planejamento` e
  `parse_horarios_txt` só usam `print_debug` ou ficam calados. Nenhum
  `push_error` vai reprovar teste no GUT.

## Camadas tocadas

| Arquivo | Por quê |
|---|---|
| `standalone_scripts/io/arquivos_planejamento.gd` | Toda a mudança: as duas `static` novas, o modo curso de `preparar_alocacoes_do_txt`, a chave do txt em `mesclar_planejamento_com_horarios_txt` e a oferta em `adicionar_planejamento_csv_do_txt`. Fica na camada de I/O porque é o mesmo arquivo que já faz o parse do txt. As funções novas são `static` e puras, como `mesclar_planejamentos` e `dividir_csv`, que já moram ali. |
| `test/unit/test_compartilhadas_horarios_txt.gd` (**novo**) | Prova os ACs 1 a 11 e traz os testes de apoio. As fixtures são fictícias, geradas em memória e gravadas em `user://teste_0011/`. |
| `MANUAL.md` | Uma frase no item **Abrir horarios.txt** (linha 321). Ver "Ordem de implementação", passo 7. |

Fica fora do diff, de propósito:

- **`scenes/Modulos/PlanejamentoHorario/planejamentohorario.gd`**, embora o
  card o liste em `layers`. Ele consome `cards_novos` e `alocacoes` pelos mesmos
  campos de hoje: `codigo, nome, profs, ch_total, sem, chave` e
  `linha, coluna, chave, aloc`. O campo novo `oferta` só é lido por
  `adicionar_planejamento_csv_do_txt`, que fica em `ArquivosPlanejamento`. O
  import de referência continua igual porque o modo legado é decidido **dentro**
  de `preparar` pelos prefixos vazios (contrato abaixo, pregado pelo AC9).
- **`standalone_scripts/io/file_handling.gd`.** As estáticas
  `dividir_semestres` e `semestre_casa_prefixos` são reusadas sem mudança, e o
  `carregar_planejamento` não muda.
- **`standalone_scripts/analise/horarios_exe.gd`**: a exportação é non-goal.
- **`scenes/main.gd`, `base_config.json`, `export_presets.cfg`.** Não há leitura
  nova, nem chave nova, nem arquivo novo na raiz.

## Contrato público novo ou alterado

### `ArquivosPlanejamento.parte_receptora_txt` (nova, `static`)

```gdscript
static func parte_receptora_txt(codigo: String, semestre_txt: String, chaves_existentes: Dictionary, prefixos: Array = [], delimitadores: Array = []) -> Dictionary
```

Implementa as regras 1, 2, 3 e 5 do card: escolhe **qual parte** do campo
recebe a linha.

- **Quem chama:** `preparar_alocacoes_do_txt`, no modo curso (com os prefixos
  do curso); `mesclar_planejamento_com_horarios_txt`, sem prefixos; e os testes.
- **Entradas:**
  - `codigo`: código da disciplina, em qualquer caixa;
  - `semestre_txt`: o campo de semestre cru da linha (`S`);
  - `chaves_existentes`: só as **chaves** importam, os valores são ignorados.
    Isso permite passar o mesmo dicionário de ofertas usado no desempate;
  - `prefixos`: **lista vazia quer dizer "sem filtro"**, e toda parte é
    candidata. Em `preparar` isso é diferente: lá a lista vazia liga o modo
    legado, e esta função nem é chamada;
  - `delimitadores`: os de `planejamento`.
- **Algoritmo:**
  1. `partes` = `FileHandling.dividir_semestres(semestre_txt, delimitadores)`,
     cada uma com `strip_edges()`, sem as vazias, na ordem do campo.
  2. `candidatas` = as partes que passam no filtro. Com `prefixos` vazio, todas
     passam. Senão, passa a que satisfaz
     `FileHandling.semestre_casa_prefixos(parte, prefixos, delimitadores)`.
  3. Para cada candidata, na ordem: `base = codigo.to_lower() + "_" +
     parte.to_lower()`. Se `chaves_existentes.has(base)`, devolve
     `{ "chave": base, "semestre": parte }`.
  4. Se nenhuma candidata tem card, devolve
     `{ "chave": codigo.to_lower() + "_" + candidatas[0].to_lower(),
     "semestre": candidatas[0] }`.
  5. Se não há candidata, devolve `{ "chave": "", "semestre": "" }`.
- **Garante:**
  - `chave` é sempre minúscula e nunca traz `_N`;
  - `semestre` é a parte com a caixa do txt e sem bordas (`"EC03"`,
    `"ECExtra"`);
  - não muta argumento, não lê arquivo nem `GV`, não loga.

### `ArquivosPlanejamento.desempatar_chave_duplicada` (nova, `static`)

```gdscript
static func desempatar_chave_duplicada(chave_base: String, semestre_txt: String, ofertas_existentes: Dictionary, delimitadores: Array = []) -> String
```

Implementa a regra 4 do card: escolhe entre `C_<parte>`, `C_<parte>_2`, `_3`…

- **Quem chama:** `preparar_alocacoes_do_txt`, no modo curso, e os testes.
- **Entradas:**
  - `ofertas_existentes`: chave → oferta (`String`; `""` quando não se sabe);
  - `chave_base`: o retorno de `parte_receptora_txt`.
- **Algoritmo:**
  1. Se `chave_base` não está em `ofertas_existentes`, devolve `chave_base`.
     É um card novo.
  2. `grupo = [chave_base]`, mais `chave_base + "_" + str(n)` para
     `n = 2, 3, …` **enquanto a chave existir**. É o mesmo laço que gera as
     chaves no CSV.
  3. Devolve a primeira chave do grupo cujo **conjunto de partes da oferta**
     seja igual ao conjunto de partes de `semestre_txt`.
  4. Se nenhuma for igual, devolve `chave_base`.
- **Conjunto de partes:** `dividir_semestres`, depois `strip_edges()`,
  `to_lower()`, sem as vazias e sem repetição. A comparação ignora a ordem, os
  espaços e a caixa. Fica num helper privado `static`:
  `_conjunto_partes(oferta: String, delimitadores: Array) -> Array[String]`,
  que devolve a lista **ordenada**, para a comparação ser `==`.
- **Garante:** devolve uma chave do grupo ou a própria `chave_base`. É pura.

### `preparar_alocacoes_do_txt` (assinatura igual, comportamento novo)

```gdscript
func preparar_alocacoes_do_txt(caminho: String, dias: Array[String], horas: Array[String], linhas_grade: int, colunas_grade: int, chaves_existentes: Array, prefixos: Array[String] = []) -> Dictionary
```

Agora tem dois modos, escolhidos por `prefixos`. O doc comment passa a dizer
isso com todas as letras.

**`prefixos` vazio → modo referência (legado, byte a byte igual a hoje).**

- Não há filtro.
- A chave é `codigo + "_" + sem.to_lower()`, sobre o campo inteiro, **sem**
  `strip_edges`, como hoje.
- Card novo: `sem = S` e `oferta = S`.
- `aloc["semestre"] = S`.

É o que `_aplicar_referencia_txt` exige (AC9).

**`prefixos` não vazio → modo curso.**

1. **Filtro (regra 2):**
   `FileHandling.semestre_casa_prefixos(S, prefixos, delimitadores)` substitui
   o `begins_with` das linhas 278–286.
2. A guarda de `size() <= 1` continua como está.
3. **Resolução, primeira passada.** Percorre as linhas filtradas com
   disciplina `!= " "` e código não vazio. Entram **também** as que vão cair
   fora da grade: é a mesma cobertura da contagem de CH de hoje.
   - `ofertas = { k: _planejamento_csv.get(k, {}).get("oferta", "") }` para
     cada `k` de `chaves_existentes`;
   - `r = parte_receptora_txt(codigo, S, ofertas, prefixos, delimitadores)`;
   - `chave = desempatar_chave_duplicada(r["chave"], S, ofertas, delimitadores)`;
   - se `not ofertas.has(chave)`, faz `ofertas[chave] = S.strip_edges()`. O card
     criado por uma linha passa a ser "existente" para as linhas seguintes. É
     isso que faz as variantes de `S` da mesma disciplina somarem num card só
     (edge case "Contagem de CH do card novo").
4. **CH por chave** contada sobre as chaves resolvidas.
5. **Montagem, segunda passada.** Igual à de hoje, mas com a chave resolvida:
   - card novo com `sem = r["semestre"]` e `oferta = S.strip_edges()`;
   - `aloc["chave"] = chave` e `aloc["semestre"] = r["semestre"]`, que é a
     parte do card que recebe.

**Retorno:** os mesmos campos de hoje. Cada item de `cards_novos` ganha
`oferta`: `{ codigo, nome, profs, ch_total, sem, oferta, chave }`.

**`ignoradas`:** o significado não muda. Conta só linha fora da grade. Linha
descartada pelo filtro não entra na conta.

**Por que `aloc["semestre"]` vira a parte.**

- É o que uma alocação carrega quando vem do JSON: `_aplicar_alocacoes_json`
  grava o `semestre` da disciplina, que é por parte.
- É o que o posicionador lê primeiro (`posicionador_automatico.gd:189`). Com o
  campo inteiro, `"EA09;EE09;EM09;ET03;EC07"` daria semestre 9 à R3, e não 7.
- Numa linha não compartilhada, a parte é o próprio campo. O valor fica igual
  ao de hoje (AC8).

**Helpers privados que mudam:**

- `_resolver_linhas_txt(dados_txt: Array[Dictionary], chaves_existentes: Array, prefixos: Array[String]) -> Array[Dictionary]`
  (**novo**). Faz a primeira passada nos dois modos e devolve uma lista
  paralela a `dados_txt`. Cada item é `{ "chave", "semestre", "oferta" }`, ou
  `{}` para linha pulada.
- `_contar_ch_por_chave(resolvidas: Array[Dictionary]) -> Dictionary`. Passa a
  contar pelas chaves resolvidas, e não pelo campo cru.
- `_montar_card_novo(entry: Dictionary, codigo: String, sem: String, oferta: String, chave: String, disc_str: String, ch_por_chave: Dictionary) -> Dictionary`.
  Ganha `oferta` e a devolve no dicionário.

### `adicionar_planejamento_csv_do_txt` (alterada)

`"oferta": sem` vira `"oferta": str(c.get("oferta", sem))`.

**Por quê:**

- Hoje um card vindo do txt tem `sem = S`, então já grava `oferta = S`.
- Com `sem` virando a parte, manter `"oferta": sem` rebaixaria a oferta para
  `EC03` sem aviso. Isso quebraria três coisas que leem a oferta:
  - a detecção de compartilhada (`_oferta_cruza_cursos`);
  - o filtro de envio por curso (`exportar_planejamento_json`);
  - a identidade da mesclagem do campus (`codigo|oferta`).

Card sem `oferta` cai em `sem`, como hoje. Vale também para
`montar_planejamento_csv_do_txt`, que delega para esta função.

### `mesclar_planejamento_com_horarios_txt` (assinatura igual)

```gdscript
func mesclar_planejamento_com_horarios_txt(caminho_horarios_txt: String) -> Dictionary
```

- Antes do laço do txt, monta `bases`, um dicionário com uma chave para cada
  entrada de `_planejamento_csv` **que não seja de referência**
  (`not dados.get("referencia", false)`):
  `codigo.to_lower() + "_" + semestre.to_lower()`. É exatamente a `chave_base`
  que o lado do planejamento já usa.
  - **Por que excluir a referência.** `_aplicar_referencia` (Ver outros cursos)
    põe no `_planejamento_csv` entradas por parte, como `al0022_ee03`, com
    `referencia: true`. Como `mesclar` resolve sem prefixos, a linha
    `EE03;EC03` cairia nessa entrada da referência (a primeira parte com
    entrada), e o card próprio `al0022_ec03` ficaria com linhas vazias. Hoje
    nenhuma das duas casa; sem a guarda, a correção criaria um resultado
    errado novo justamente nas compartilhadas.
  - O laço do lado do planejamento continua como está, inclusive iterando as
    entradas de referência. Elas ficam sem casamento, como hoje.
  - Em `preparar` essa guarda não entra: lá o filtro de prefixos do curso já
    exclui as partes da referência, e excluir a chave faria o card novo
    resolvido substituir o card da referência no painel
    (`popular_card_extra` apaga a chave repetida).
- A `chave_txt` de cada linha passa a ser
  `parte_receptora_txt(codigo, S, bases, [], delimitadores)["chave"]`. Se o
  retorno vier vazio, usa a fórmula antiga `codigo + "_" + S.to_lower()`.
  - **Sem prefixos:** o `_planejamento_csv` só tem as partes dos cursos
    carregados, então existir em `bases` já faz o papel do filtro.
- A `chave_txt` é calculada **uma vez por linha** e guardada numa lista
  paralela a `dados_txt`. Dois pontos usam essa lista: o lookup
  (linhas 585–590) e o laço de `entries_removidas` (linhas 653–660). Hoje o
  segundo laço recalcula a chave com a fórmula antiga. Se os dois pontos não
  concordarem, uma linha resolvida aparece como removida, ou uma removida se
  perde.
- **Sem desempate.** O lado do planejamento continua casando por `chave_base` +
  professor. Uma chave `_2` vinda do txt nunca casaria e cairia em `removidas`.
  Passar `mesclar` a casar pela chave completa (`_N` incluído) é outro card;
  ver "Notas para o handoff".
- O lado do planejamento e o formato de retorno não mudam.

## Invariantes

1. **Dado pessoal não sai do PC.**
   - Não há rede, log commitável, exportação nova nem arquivo novo na raiz.
   - Os testes usam fixtures fictícias geradas em memória:
     - professores `Maria da Silva Souza` e `Carlos Ficticio Lima`;
     - disciplinas `Disciplina Ficticia A/B/…` com códigos públicos de
       disciplina (`AL0015`, `AL0022`…);
     - salas `Sala 101`…

     As fixtures vão para `user://teste_0011/` e são apagadas no `after_each`.
     Nenhuma fica versionada.
   - **Os agentes não leem `dados/`.** Os ACs 13 e 14 são roteiros que o dev
     executa com os dados dele. O registro no card é só aprovado ou reprovado,
     **sem** captura de tela e sem nome de professor.
2. **snake_case interno.** Chaves, conjuntos de partes e comparações são em
   minúsculas. O `semestre` do card e da alocação guarda a caixa do txt
   (`"EC03"`) porque é texto de exibição, como hoje.
3. **Cursos e chaves canônicas.**
   - Os prefixos continuam vindo de `base_config.json:cursos[*].prefixos_semestre`,
     pelo módulo. Não surge lista nova de cursos.
   - Os delimitadores vêm de `base_config.json:delimitadores.planejamento`,
     injetados por `configurar`.
   - A chave segue `<codigo>_<parte>[_N]`, exatamente como o CSV a produz.
4. **Leitura de arquivo.** Nenhuma leitura nova. `parse_horarios_txt` e
   `carregar_planejamento` são os de hoje, e `arquivos_planejamento.gd` já está
   em `FILESYSTEM_ALLOWED`. Com arquivo ausente, os caminhos de "não
   encontrado" não mudam.
5. **UI e identidade.** Não há UI nova. A alocação carrega a
   `chave_planejamento` do card resolvido (`aloc["chave"]`) e nunca é buscada
   por código+semestre. Isso segue a memória do projeto "Identidade da oferta =
   chave_planejamento".

## Mapeamento AC → prova

Arquivo de teste: `test/unit/test_compartilhadas_horarios_txt.gd` (abreviado
`T::` abaixo). Cada teste de AC passa pela função pública de ponta a ponta
(`preparar_alocacoes_do_txt`, `exportar_planejamento_json` ou
`mesclar_planejamento_com_horarios_txt`). Os testes das duas `static` são
apoio, não prova.

| AC do card | Método | Onde |
|---|---|---|
| AC1: card `al0015_ec03` existe, prefixos `["ec"]`, 4 linhas `EC03;EMExtra` saem com `al0015_ec03` e `cards_novos` não traz a `al0015` | headless | `T::test_compartilhada_casa_com_card_do_planejamento_csv` |
| AC2: `EE03;EC03` com `["ec"]` não é descartada e sai com `al0022_ec03` | headless | `T::test_filtro_aceita_curso_fora_do_comeco_do_campo` |
| AC3: `EA09; ee09 ;EC07` casa com `al0390_ec07` | headless | `T::test_campo_com_espacos_e_caixa_mista_casa_com_card` |
| AC4: `EE01;EM01` com `["ec"]` continua descartada | headless | `T::test_linha_sem_parte_do_curso_continua_descartada` |
| AC5: cards `al0022_ee03` e `al0022_ec03`, `["ec", "ee"]`, linha `EE03;EC03`: só `al0022_ee03` recebe | headless | `T::test_varios_cursos_so_o_card_da_primeira_parte_recebe` |
| AC6: `al0390_ec07` (oferta `EA09;EE09;EC07`) e `al0390_ec07_2` (oferta `EC07`): a linha `EA09;EE09;EC07` vai para a base e a `EC07` vai para a `_2` | headless | `T::test_chaves_duplicadas_desempatam_pela_oferta` |
| AC7: sem card, as 4 linhas `EC03;EMExtra` geram **um** card `al0015_ec03`, semestre `EC03`, oferta `EC03;EMExtra`, CH 4 | headless | `T::test_sem_card_gera_um_card_novo_no_formato_do_csv`. Apoio: `T::test_card_novo_leva_a_oferta_ao_planejamento` e `T::test_variantes_do_campo_somam_no_mesmo_card_novo` |
| AC8: a linha `EC07` da `AL0395` continua com `al0395_ec07` | headless | `T::test_linha_nao_compartilhada_mantem_a_chave` |
| AC9: com prefixos `[]` (como `_aplicar_referencia_txt`) e o card próprio `al0019_ec03`, a linha `EC03;EE03;ET03;EM03` não se anexa a ele e continua como disciplina nova | headless | `T::test_import_de_referencia_mantem_o_campo_inteiro` |
| AC10: depois de aplicar as alocações resolvidas, `exportar_planejamento_json` traz a `al0015` com as 4 alocações | headless | `T::test_ida_e_volta_pelo_planejamento_json` |
| AC11: `mesclar_planejamento_com_horarios_txt` preserva sala, dia e horário nas 4 entradas da `al0015`, e `removidas` não a contém | headless | `T::test_atualizar_planejamento_preserva_a_compartilhada` |
| AC12: a suíte existente continua passando | headless | `python .tools/run_tests.py` com exit 0, rodado no fim. O total sobe de 163 para 163 + os testes novos, com zero falhas |
| AC13: com os dados reais, as 8 disciplinas aparecem na grade, nos cards completos, sem card duplicado e fora do diálogo de "fora do planejamento" | manual | Roteiro R13 (abaixo) |
| AC14: com os dados reais, depois de Salvar e reabrir pelo `planejamento.json`, as alocações continuam | manual | Roteiro R14 (abaixo) |

Testes de apoio, além dos citados na tabela:

- `T::test_parte_receptora_respeita_ordem_filtro_e_caixa`: `static` pura.
  Cobre a ordem do campo, o filtro, `ECExtra` → `al0375_ecextra`, prefixos
  vazios → toda parte é candidata, e campo vazio → `chave` `""`.
- `T::test_desempate_cai_na_base_sem_oferta_igual`: `static` pura. Cobre a base
  inexistente (devolve a base), nenhuma oferta igual (devolve a base) e duas
  duplicadas com a mesma oferta (devolve a primeira do grupo).
- `T::test_atualizar_planejamento_ignora_entrada_de_referencia`:
  - CSV: `EE03;EC03` da AL0022 com Maria e CH 2, carregado com `["ec"]`
    (dá o card próprio `al0022_ec03`);
  - depois, à mão, uma entrada de referência
    `ap._planejamento_csv["al0022_ee03"] = { codigo "al0022", semestre "EE03",
    professor ["carlos ficticio lima"], ch ["2"], oferta "EE03;EC03",
    ch_disciplina "2", referencia true, curso_origem "alee" }`, no formato que
    `_aplicar_referencia` grava (aqui o dicionário à mão é o certo: a entrada
    vem do servidor, não de um leitor de arquivo);
  - txt: 2 linhas `EE03;EC03` da AL0022, professora `Maria da Silva Souza`,
    com sala, dia e horário;
  - confere: as entries da AL0022 com semestre `ec03` mantêm sala, dia e
    horário do txt; nenhuma chave de `removidas` começa com `al0022`.

### Desenho dos testes

**Ambiente comum.**

- `const RAIZ: String = "user://teste_0011/"`.
- `DIAS`: `["Segunda", "Terca", "Quarta", "Quinta", "Sexta"]`. Sem acento, para
  não depender de `to_lower` com Unicode.
- `HORAS`: `["07:30", "08:30", "09:30", "10:30", "13:30", "14:30"]`.
- **`before_each`:**
  - cria `RAIZ`;
  - guarda `GV.configuracao_base` e põe no lugar
    `{"dias_semana": DIAS, "horarios_aula": HORAS}`.
- **`after_each`:**
  - restaura `GV.configuracao_base`;
  - apaga os arquivos de `RAIZ` e a pasta.

**Helper `_ap() -> ArquivosPlanejamento`.**

```gdscript
var ap := ArquivosPlanejamento.new()
ap.configurar(FileHandling.new(), AnaliseHorarios.new(), AnaliseGrades.new(), HorariosExe.new(), {}, {"planejamento": [";", "/"]}, RAIZ + "regras", {}, {})
```

**Helper `_gravar_csv(linhas: Array[String])`.** Grava
`RAIZ + "planejamento.csv"` com este cabeçalho, seguido das linhas:

```
n,semestre,codigo,ch,matricula,Maria da Silva Souza,Carlos Ficticio Lima
```

- As posições são as defaults de `carregar_planejamento`: semestre 1, código 2,
  CH 3, professores depois da coluna `matr…`.
- Toda linha tem **7 campos**. Exemplo: `1,EC03;EMExtra,AL0015 DISCIPLINA
  FICTICIA A,4,,4,`.
- O `_planejamento_csv` sai **de `ap.carregar_planejamento(RAIZ, prefixos)`**,
  nunca de um dicionário escrito à mão. O defeito é de paridade entre os dois
  leitores. Só o leitor real prova que a chave do txt é a que o CSV gera,
  inclusive as minúsculas e o `_2`.

**Helper `_gravar_txt(linhas: Array[String])`.** Grava
`RAIZ + "horarios.txt"`. A primeira linha é o cabeçalho que
`exportar_horarios_ref` escreve, `1," "," "," "," "," "," "," "," "," ",1,1,1`,
seguido das linhas dadas.

**Helper `_linha_txt(prof, sala, sem, hora, dia, codigo) -> String`.** Monta:

```
,"<prof>",<sala>,<sem>,<hora>,<dia>,"Disciplina Ficticia (<CODIGO>)",Teorica,T20,Vagas,1,1,1
```

**Arrays tipados.** `carregar_planejamento` e `preparar_alocacoes_do_txt`
recebem `Array[String]`. Toda variável de prefixos e todo parâmetro de helper
que chegue a elas é declarado `Array[String]` (ou convertido com
`as Array[String]`). Um `Array` sem tipo dá erro de tipo em tempo de execução,
que no relatório do GUT parece falha de lógica.

**Chamada padrão:**

```gdscript
ap.preparar_alocacoes_do_txt(RAIZ + "horarios.txt", DIAS, HORAS, HORAS.size() + 1, DIAS.size() + 1, ap._planejamento_csv.keys(), prefixos)
```

Assim como no painel, os cards existentes são as chaves do planejamento
carregado.

**Conteúdo de cada teste de AC:**

- **AC1.**
  - CSV: `1,EC03;EMExtra,AL0015 DISCIPLINA FICTICIA A,4,,4,`. Carregado com
    `["ec"]`.
  - txt: 4 linhas `EC03;EMExtra` da AL0015, em 4 células distintas.
  - Confere:
    - `_planejamento_csv.has("al0015_ec03")`. É o lado do CSV, a sanidade do
      teste;
    - as 4 alocações têm `chave` e `aloc.chave` iguais a `al0015_ec03`;
    - nenhum item de `cards_novos` tem `codigo` `al0015`;
    - apoio: `aloc.semestre == "EC03"` nas 4.
- **AC2.**
  - CSV: `EE03;EC03` da AL0022, com `["ec"]`, o que dá a chave `al0022_ec03`.
  - txt: 2 linhas `EE03;EC03`.
  - Confere:
    - 2 alocações com `al0022_ec03`;
    - `cards_novos` vazio.
- **AC3.**
  - CSV: `1,EA09; EE09; EC07,AL0390 …` e `2,EC07,AL0390 …`. Gera
    `al0390_ec07`, com oferta `"ea09; ee09; ec07"`, e `al0390_ec07_2`, com
    oferta `"ec07"`.
  - txt: 2 linhas com o campo literal `EA09; ee09 ;EC07`.
  - Confere: as 2 linhas saem com `al0390_ec07`.
  - Isso exercita o divisor, a limpeza das bordas e a caixa, e também o
    desempate contra uma oferta com espaçamento diferente.
- **AC4.**
  - txt:
    - 2 linhas `EE01;EM01` da AL0101;
    - 2 linhas `EC07` da AL0395, para a chamada continuar válida.
  - Prefixos `["ec"]`, sem CSV.
  - Confere:
    - nenhuma alocação e nenhum card novo com `codigo` `al0101`;
    - `ignoradas == 0`.
- **AC5.**
  - CSV: `EE03;EC03` da AL0022, carregado com `["ec", "ee"]`. Gera as duas
    chaves.
  - txt: 2 linhas `EE03;EC03`.
  - Confere:
    - as 2 alocações com `al0022_ee03`;
    - nenhuma com `al0022_ec03`;
    - `cards_novos` vazio.
- **AC6.**
  - CSV: `1,EA09;EE09;EC07,AL0390 …` e `2,EC07,AL0390 …`, com `["ec"]`.
  - txt:
    - 2 linhas `EA09;EE09;EC07`, nas células A e B;
    - 2 linhas `EC07`, nas células C e D.
  - Confere:
    - sanidade: as duas chaves existem, com as ofertas esperadas;
    - A e B → `al0390_ec07`;
    - C e D → `al0390_ec07_2`.
- **AC7.**
  - Sem CSV: `_planejamento_csv` vazio, chaves `[]`, prefixos `["ec"]`.
  - txt: 4 linhas `EC03;EMExtra` da AL0015.
  - Confere:
    - `cards_novos.size() == 1`;
    - o card: `chave == "al0015_ec03"`, `sem == "EC03"`,
      `oferta == "EC03;EMExtra"`, `ch_total == 4`;
    - as 4 alocações com `al0015_ec03`.
  - Apoio:
    - `test_card_novo_leva_a_oferta_ao_planejamento`: depois de
      `ap.montar_planejamento_csv_do_txt(plano["cards_novos"])`,
      `_planejamento_csv["al0015_ec03"]` tem `semestre "EC03"` e
      `oferta "EC03;EMExtra"`;
    - `test_variantes_do_campo_somam_no_mesmo_card_novo`: 2 linhas
      `EC03;EMExtra` e 1 linha `EC03`. Confere 1 card com `ch_total == 3`.
- **AC8.**
  - Dois casos:
    - com o CSV `EC07` da AL0395;
    - sem CSV.
  - txt: 2 linhas `EC07`.
  - Confere:
    - nos dois casos, `chave == "al0395_ec07"` e `aloc.semestre == "EC07"`,
      igual a hoje;
    - no caso sem CSV, o card novo tem `sem == "EC07"` e
      `oferta == "EC07"`.
- **AC9.**
  - CSV: `EC03;EE03;ET03;EM03` da AL0019, com `["ec"]`. Gera o card próprio
    `al0019_ec03`.
  - txt, de "outro curso": 2 linhas `EC03;EE03;ET03;EM03`.
  - Chamada: `preparar(…, ap._planejamento_csv.keys(), [])`, exatamente como
    `_aplicar_referencia_txt` chama.
  - Confere:
    - nenhuma alocação tem chave `al0019_ec03`;
    - as 2 têm `al0019_ec03;ee03;et03;em03`;
    - `cards_novos` traz essa chave, com `sem` e `oferta` iguais a
      `"EC03;EE03;ET03;EM03"`;
    - `not ap._planejamento_csv.has("al0019_ec03;ee03;et03;em03")`. Por isso
      `_aplicar_referencia_txt` não pula a disciplina, e a oferta que ele grava
      continua cruzando cursos, o que mantém o aviso de divergência.
- **AC10.**
  - CSV e txt do AC1. As 4 linhas têm `Sala 101`…`Sala 104` e pares
    (hora, dia) conhecidos.
  - Monta `alocacoes` como `_popular_grade_do_txt` faz:
    `"%d_%d" % [linha, coluna]` → `Array` com o `aloc` anexado.
  - Chama `ap.exportar_planejamento_json(alocacoes)`.
  - Confere, na disciplina de `codigo` `al0015`:
    - `alocacoes.size() == 4`;
    - os pares (`horario`, `dia`) e as `sala` são os do txt;
    - apoio: `oferta == "ec03;emextra"`, como o CSV gravou.
- **AC11.**
  - CSV:
    - `EC03;EMExtra` da AL0015, com Maria e CH 4;
    - `EC07` da AL0395, com Maria e CH 2, como controle não compartilhado.
  - txt:
    - 4 linhas `EC03;EMExtra` da AL0015, professora `Maria da Silva Souza`,
      com sala, dia e horário;
    - 2 linhas `EC07` da AL0395.
  - Chama `ap.mesclar_planejamento_com_horarios_txt(RAIZ + "horarios.txt")`.
  - Confere:
    - as entries cuja `disciplina` contém `(AL0015)` são 4;
    - o multiconjunto de (`sala`, `dia`, `horario`) delas é o do txt;
    - nenhuma chave de `removidas` começa com `al0015`;
    - nenhuma entry de `entries_removidas` é da AL0015;
    - controle: as 2 entries da AL0395 também mantêm os horários.
  - O professor casa por minúsculas: o CSV o grava minúsculo, e o lookup aplica
    `to_lower` nos dois lados.

## Riscos de contrato de dados

- **Nenhuma chave muda de nome.** `cards_novos` ganha `oferta`. É um
  dicionário em memória, consumido só por `adicionar_planejamento_csv_do_txt`,
  e quem não o lê continua igual.
- **Valores que mudam, só no modo curso e só em linha compartilhada.**
  - `semestre` do card que vem do txt e da alocação: era o campo inteiro e
    passa a ser a parte. Ele chega ao `planejamento.json` (campo `semestre`) e
    ao record do Kinto.
  - Isso **alinha** o txt ao CSV e ao JSON, que já gravam uma disciplina por
    parte.
  - A `oferta` do card que vem do txt **mantém o valor de hoje** (`S`). Por
    isso não mudam:
    - o filtro de envio por curso;
    - a detecção de compartilhada;
    - a identidade `codigo|oferta` da mesclagem do campus.
- **JSON antigo.** Um `planejamento.json` salvo antes da correção não é
  reparado (non-goal do card). Ele continua abrindo como hoje.
- **Mais avisos de "Compart. divergentes" com referência sobreposta.** As
  compartilhadas do próprio curso agora ficam no card do CSV, cuja `oferta`
  cruza cursos. Com uma referência sobreposta,
  `_verificar_compartilhadas_divergentes` passa a contá-las do lado "seu", e
  podem surgir avisos onde antes não havia. É o comportamento correto (antes
  elas ficavam num card-fantasma), não regressão. R13 e R14 não sobrepõem
  referência, então não são afetados.
- **Formatos de `dados/`:** o programa só muda a forma de **ler** o
  `horarios.txt`. O arquivo não muda, e a exportação continua igual
  (non-goal).
- **LGPD:**
  - nenhum dado novo vai para tela, exportação, rede ou log;
  - os testes usam só dado fictício, em `user://`;
  - os roteiros manuais rodam na máquina do dev, sem captura;
  - os 8 códigos de disciplina do card são públicos.

## Ordem de implementação

Cada passo termina com `python .tools/run_tests.py` verde. Testes vermelhos só
existem dentro do passo que os faz passar.

1. **Pregar o comportamento atual.** Criar
   `test/unit/test_compartilhadas_horarios_txt.gd` com o ambiente, os helpers e
   os testes que já passam hoje: AC4, AC8 e AC9. Rodar a suíte; deve ficar
   verde **sem** mudar código de produção. Esse é o cinto de segurança do modo
   legado e do caminho não compartilhado.
   - **Exceção:** o card de hoje não tem o campo `oferta`. As asserções de
     `oferta` do AC8 (caso sem CSV) e do AC9 só entram no passo 3, junto com o
     campo. Neste passo, AC8 e AC9 conferem só `chave`, `sem` e
     `aloc.semestre`.
2. **Núcleo puro.** Escrever os testes de apoio das duas `static`, que ficam
   vermelhos. Depois implementar `parte_receptora_txt`,
   `desempatar_chave_duplicada` e `_conjunto_partes`. A suíte volta ao verde.
3. **Modo curso em `preparar`.** Escrever AC1, AC2, AC3, AC5, AC6 e AC7, mais
   o apoio de variantes, que ficam vermelhos. Depois implementar:
   - o filtro novo;
   - `_resolver_linhas_txt`;
   - a nova `_contar_ch_por_chave`;
   - `_montar_card_novo` com `oferta`;
   - `aloc.semestre`.

   Atualizar o doc comment com os dois modos. AC4, AC8 e AC9 continuam verdes.
4. **Oferta no planejamento.** Escrever o apoio
   `test_card_novo_leva_a_oferta_ao_planejamento`, que fica vermelho, e mudar
   `adicionar_planejamento_csv_do_txt`. Volta ao verde.
5. **Ida e volta.** Escrever o AC10. Ele deve passar só com o passo 3. Se não
   passar, o defeito está no passo 3, não em `exportar_planejamento_json`, que
   não muda.
6. **Atualizar planejamento.** Escrever o AC11 e o apoio
   `test_atualizar_planejamento_ignora_entrada_de_referencia`, que ficam
   vermelhos. Depois implementar `bases` (sem as entradas de referência), a
   `chave_txt` resolvida uma vez por linha e o reuso no laço de
   `entries_removidas`. Volta ao verde.
7. **Manual.** Acrescentar uma frase ao item **Abrir horarios.txt** de
   `MANUAL.md` (linha 321), sem dado pessoal:

   > Disciplinas compartilhadas entre cursos (ex.: `EC03;EM03`) ocupam o card
   > que o planejamento já criou para o seu curso. Com mais de um curso
   > selecionado, a aula vai para o card do primeiro curso que aparece no
   > campo de semestre do `horarios.txt`.

   O item **Atualizar planejamento** (linhas 442–445) não precisa de texto
   novo: "disciplinas que permanecem mantêm o horário" passa a valer também
   para as compartilhadas.
8. **Portões**, os três, nesta ordem:
   - `python .tools/guardrails.py` (exit 0);
   - `python .tools/run_tests.py` (exit 0, AC12);
   - `"C:/Program Files/Godot/Godot_console.exe" --headless --path . --editor --quit`
     no Windows, ou `godot --headless --path . --editor --quit` no Linux.

   O guardrails tem estas regras a observar em `arquivos_planejamento.gd`
   (baseline: `max-line-length` 1 e `section-order` 1):
   - as `static` públicas novas ficam junto das públicas, logo depois de
     `preparar_alocacoes_do_txt`;
   - os helpers privados ficam junto de `_contar_ch_por_chave` e
     `_montar_card_novo`;
   - doc comment `##` nas públicas e `#` nas privadas;
   - toda variável local tipada;
   - linha nova com no máximo 200 colunas, o que pede quebrar com `\` a
     assinatura de `_montar_card_novo`, se passar.

   Nenhuma contagem pode subir. A baseline nunca é afrouxada.

## Edge cases (decisões fechadas)

- **Ordem diferente entre os arquivos**
  (`EA09; EE09; EM09; ET03; EC07` × `EA09;EE09;EM09;ET03;EC07`). O casamento é
  parte a parte. A oferta inteira só é comparada, como conjunto, no desempate
  (AC3 e AC6).
- **Várias variantes de `S` da mesma disciplina sem card.** Somam no card
  criado pela primeira linha, cuja `oferta` é o `S` dessa linha. É o que a
  primeira passada sequencial garante (apoio do AC7).
- **Vários cursos, sem card.** A linha `EE03;EC03` com `["ec", "ee"]` cria um
  card só, `al0022_ee03`: é a primeira parte que passa no filtro. É coerente com
  a regra 3. Alocar em todos os cursos é non-goal.
- **Duplicadas com a mesma oferta.** Por exemplo, `al0390_ec07` e
  `al0390_ec07_2`, ambas `EC07`. Todas as linhas vão para a primeira do grupo,
  a base, e a `_2` fica pendente. É igual a hoje, porque hoje a chave do campo
  inteiro também cai na base.
- **Lacuna no grupo.** Se o usuário remover o card `_2` do painel e o `_3`
  continuar, o laço para no `_2` e não considera o `_3`. É o mesmo laço do
  gerador do CSV e um caso raro. A linha cai na base ou no primeiro anterior que
  casar.
- **Referência sobreposta com a mesma chave.**
  - Em `preparar`: se uma referência do servidor tiver uma chave igual à
    resolvida (só acontece marcando no import o próprio curso dela), a linha se
    anexa a essa chave, como hoje aconteceria com uma chave igual. A spec não
    muda isso.
  - Em `mesclar`, que não tem filtro, a referência fica **fora** de `bases`
    (ver o contrato). A linha compartilhada vai para o card próprio, e a
    entrada da referência continua sem casamento, como hoje.
- **`ECExtra`** casa com o prefixo `ec`, e a chave é `C_ecextra`, como o CSV a
  grava (apoio da `static`).
- **Linha de cabeçalho ou vazia** (disciplina `" "`) continua ignorada. A
  **turma** não participa da regra.
- **Arquivo ausente:** nada muda.

## Roteiros manuais

Os dois roteiros rodam **no PC do dev**, com os arquivos reais de
`dados/saida/` (`planejamento.csv` e `horarios.txt` da EC). Os agentes não os
leem. O registro no card é "aprovado"/"reprovado" e, se reprovado, o código da
disciplina que falhou. Sem captura de tela e sem nome de professor.

### R13 (AC13): grade preenchida com as compartilhadas

1. Abrir o PUG e ir em **Planejamento de horário**.
2. **Importar › Abrir planejamento.csv**, marcar **só** a Engenharia Civil e
   confirmar.
3. **Importar › Abrir horarios.txt**, marcar **só** a Engenharia Civil e
   confirmar.
4. No terminal, se aparecer
   `Disciplinas no horarios.txt fora do planejamento carregado: …`, conferir que
   **nenhuma** destas está na lista: AL0015, AL0019, AL0022, AL0002, AL0381,
   AL0394, AL0390, AL0142. Se o diálogo "Disciplinas do horarios.txt fora do
   planejamento" abrir, conferir o mesmo nele e fechar com **Nao adicionar**.
5. No painel de disciplinas, procurar cada uma das 8. Cada uma:
   - tem **um** card com semestre simples (`EC03`, `EC07`…). Não pode haver um
     segundo card com o semestre combinado (`EC03;EMExtra`);
   - está **completa**, sem "h pendente".
6. Na grade, conferir que cada uma ocupa as células que tem no `horarios.txt`
   (comparar com o Horarios.exe ou com o arquivo aberto num editor).

**Não é reprovação:**

- os cards `al0390_ec07_2` e `al0142_ec09_2`, com CH 0, continuarem existindo
  (non-goal: linhas duplicadas no CSV);
- a AL0375 continuar pendente (non-goal: dado divergente entre os arquivos).

### R14 (AC14): sobrevive a Salvar e reabrir

1. Continuar do fim do R13. **Importar › Salvar planejamento.json**. Se o
   programa perguntar sobre disciplinas de outro curso, escolher **só o seu
   curso**.
2. **Importar › Abrir planejamento.json**, ou fechar e reabrir o módulo e
   abrir o JSON.
3. Conferir que as 8 disciplinas continuam nas mesmas células e que os cards
   seguem completos.

**Não é reprovação:** ao reabrir o JSON, as alocações das chaves `_2` aparecem
no card base. A AL0390 e a AL0142 ficam com um card só. O JSON funde
código+semestre iguais; é comportamento atual e non-goal.

## Notas para o handoff

- **`_on_importar_horarios_button_up`** (`planejamentohorario.gd:546`) é código
  morto: não está ligado a nenhum sinal. Candidato a remoção num card de
  limpeza.
- **`mesclar_planejamento_com_horarios_txt` casa as duplicadas por
  `chave_base`.** As chaves `_2` consomem os mesmos horários da base, o que
  duplica as linhas no `horarios.txt` gerado. Casar pela chave completa (com o
  desempate desta spec) é um card próprio, com teste de não-regressão do
  Atualizar planejamento. Candidato ao `IDEAS.md`.
