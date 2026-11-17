# Spec — 0010-conversao-cp1252-nativa

Card: `Cards/0010-conversao-cp1252-nativa/card.md`.

Objetivo: a conversão Windows-1252 → UTF-8 passa a ser feita pelo próprio
programa, em GDScript, sobre bytes. Uma classe pura nova, `CodificacaoTexto`
(`standalone_scripts/utils/`), faz a detecção e a conversão e guarda a única
tabela de `0x80`–`0x9F`, usada nos dois sentidos. O `FileHandling.convertto_utf8`
só faz o I/O em volta dela e passa a **devolver `bool`**. Quem anunciava sucesso
sem conferir passa a usar esse retorno. As três cópias da heurística antiga
(decodificar com `get_string_from_utf8()` e procurar U+FFFD) desaparecem, e o
`ansi_to_utf8.exe` e a fonte dele saem do git.

## Fatos do motor que esta spec usa

Todos foram conferidos no Godot 4.7.2 headless, com GUT 9.7.1, num projeto
descartável fora do repositório.

- **O GUT não enxerga o `Unicode parsing error`.** `get_string_from_utf8()` em
  bytes inválidos imprime uma linha `Unicode parsing error: ...` por byte ruim.
  Essas linhas **não** passam pelo rastreador de erros do GUT:
  `assert_engine_error_count(0)` passa mesmo com elas impressas, e o teste não
  reprova. Um `Logger` próprio, registrado com `OS.add_logger`, recebe cada
  linha em `_log_message(mensagem, true)`. **É esse o instrumento de prova** dos
  critérios "não registra erro de decodificação" (ver "Captura de log nos
  testes").
- **`push_error` reprova o teste se ninguém o consumir.** No GUT 9.7.1,
  `failure_error_types` inclui `push_error` por padrão. Um teste que espera o
  erro chama `assert_push_error("<trecho>")`, que compara sem diferenciar
  maiúsculas.
- **Validador estrito e parser do Godot concordam.** Um validador pela Tabela
  3-7 do Unicode (RFC 3629) devolveu "válido" exatamente nos casos em que
  `get_string_from_utf8()` registrou zero erros. O corpus tinha 21 casos: vazio,
  ASCII, BOM + `A`, BOM sozinho, `C3 A7`, emoji de 4 bytes, `C0 80`, `C1 BF`,
  `E0 80 80` (overlong), `ED A0 80` (surrogate), `F4 90 80 80` (> U+10FFFF), `F5`,
  continuação solta `80`, sequência truncada no fim (`41 C3` e `E2 82`), CP1252
  `E7 E3 6F`, `93 41 94` e `FF`, `41 00 C3 A7`, U+FFFD em UTF-8 (`EF BF BD`) e
  U+FFFE (`EF BF BE`).
- `get_string_from_utf8()` **descarta o BOM** (`EF BB BF 41` vira `"A"`) e para no
  primeiro `0x00`, sem erro.
- `get_string_from_ascii()` decodifica `0x01`–`0xFF` como Latin-1, sem erro, mas
  **para no primeiro `0x00`** (`41 00 42` vira `"A"`). Por isso ela não serve de
  base para a conversão.
- **Desempenho** (Intel Core Ultra 9 285HX, 5 MiB):
  - conversão byte a byte com buffer pré-alocado (`resize(n * 3)`, escrita por
    índice, `resize(j)` no fim): **127 ms**;
  - validação UTF-8 que percorre o arquivo inteiro: 173 ms em UTF-8 acentuado e
    101 ms em ASCII puro;
  - validação de CP1252 acentuado: sai no primeiro acento, cerca de 0 ms;
  - a alternativa nativa (`get_string_from_ascii` + 32 `replace` +
    `to_utf8_buffer`) leva 52 ms. Ela dá saída idêntica byte a byte, mas cai no
    problema do `0x00` acima.
- **`FileAccess.open`** devolve `null` sem registrar erro do motor, tanto para
  arquivo inexistente (`get_open_error()` = `ERR_FILE_NOT_FOUND`) quanto para
  arquivo com `chmod 000` (`ERR_FILE_CANT_OPEN`). Neste segundo caso,
  `FileAccess.file_exists` devolve **`true`**.
- `FileAccess.store_buffer` devolve `bool`, e devolve `true` também para buffer
  vazio. `get_buffer(0)` devolve vazio, sem erro. `get_line()` remove o `\r` do
  CRLF.
- **Nenhuma fixture desta spec pode ser versionada.** O `.gitattributes` tem
  `* text=auto eol=lf`, e um arquivo CP1252/CRLF versionado seria normalizado para
  LF. Por isso as fixtures são **geradas em memória pelo teste** e gravadas em
  `user://teste_0010/`.

## Camadas tocadas

| Arquivo | Por quê |
|---|---|
| `standalone_scripts/utils/codificacao_texto.gd` (**novo**) | É o núcleo puro: `class_name CodificacaoTexto extends RefCounted`, só funções `static`, **sem** cabeçalho GPL. Segue o precedente de `BuscaTerminal` e `MarkdownHtml`. Não usa `FileAccess`, `GV`, nó, `print` nem `push_*`. |
| `standalone_scripts/io/file_handling.gd` | `convertto_utf8` vira nativo e devolve `bool`. Sai `_precisa_conversao_utf8` e sai o código morto comentado (PowerShell e `OS.execute`). A assinatura é reescrita com continuação em **tab**: a linha atual começa com espaços e é a única ocorrência de `tabs-only` na baseline do arquivo. |
| `standalone_scripts/io/arquivos_planejamento.gd` | `ler_comentarios_professor` decodifica em memória. Some `_verifica_se_windows1252` e some a cópia temporária gravada em `GV.dir_temp`. O doc comment é atualizado. |
| `standalone_scripts/analise/horarios_exe.gd` | `_para_cp1252` delega para `CodificacaoTexto.texto_para_cp1252`, e `_unicode_para_cp1252` sai. O comportamento não muda, e um teste de fixação escrito **antes** do refactor prova isso. A exportação em si é non-goal, e só a tabela muda de lugar. |
| `scenes/TelaPrincipal/VerificadorArquivos/verificador_arquivos.gd` | `_converter_utf8` só imprime `Arquivo convertido!` quando o retorno é `true` (AC11). |
| `scenes/Modulos/PlanejamentoHorario/Complementos/importador_preferencias.gd` | A heurística inline e a volta por arquivo temporário são trocadas por **uma** chamada a `convertto_utf8`, que já detecta, converte ou copia. O arquivo deixa de usar `FileAccess`. Os doc comments mudam. |
| `scenes/Modulos/PlanejamentoHorario/planejamentohorario.gd` | As duas chamadas usam o retorno em vez de `FileAccess.file_exists`, que podia achar um arquivo velho. O doc comment de `_importar_preferencias_professor` muda. |
| `scenes/Modulos/PlanejamentoOferta/planejamentooferta.gd` | `_converter_planejamento_csv` só anuncia "convertido" e só encadeia a importação quando o retorno é `true`. |
| `externo/bin/ansi_to_utf8.exe`, `externo/src/ansi_to_utf/ansi_to_utf8.py` | Saem com `git rm` (AC9). |
| `AGENTS.md`, `IDEAS.md` | Uma frase em cada, para tirar o nome do executável antigo (AC9). |
| `test/unit/test_codificacao_texto.gd` (**novo**) | Testes do núcleo: AC1, AC2 e AC3, mais os de apoio e a fixação do `HorariosExe`. |
| `test/unit/test_conversao_utf8_arquivo.gd` (**novo**) | Testes de I/O: AC4 a AC8, mais os de apoio dos chamadores (`ImportadorPreferencias` e `ArquivosPlanejamento`). |
| `.tools/guardrails_baseline.json` | Só **aperta**, e só se o guardrails mostrar contagem menor. Candidatos: `file_handling.gd\|tabs-only` (1 → 0) e `horarios_exe.gd\|gdlint:max-returns` (1 → 0, que é o `match` de 28 `return` do `_unicode_para_cp1252`). Nunca afrouxar. |

A spec toca mais de três camadas: utils, io, analise, módulos de cena,
`externo/` e documentação. A razão é que o card troca uma primitiva de I/O usada
em **sete** pontos do programa, e o handoff de 2026-11-17 registra que o dev
aprovou o escopo cobrindo os sete. Cada chamador muda em poucas linhas, e a
lógica nova inteira fica na camada pura.

Fica fora do diff, de propósito:

- **`standalone_scripts/analise/analise_grades.gd`** (`validar_contra_cadastro`),
  o sétimo ponto. O fluxo atual já trata a falha: sem o temporário,
  `read_csvfile` devolve `[]`, o código faz
  `push_error("Falha ao ler o CSV do cadastro 5104.")` e devolve `{}`. O
  temporário é apagado a cada leitura, então não sobra arquivo velho. O retorno
  novo pode ser ignorado ali.
- **`scenes/main.gd`, `base_config.json`, `export_presets.cfg`.** Não há leitura
  nova, chave nova nem arquivo novo na raiz.
- **`MANUAL.md`**, que é non-goal do card. O `git grep` não acha menção ao
  executável nele.
- **`ferramentas/publicar_release.ps1`.** Ele monta `externo/bin/` a partir do
  `git ls-files`, então o `.exe` sai do ZIP sozinho.
- **A exportação do `horarios.txt`** (`HorariosExe.exportar_*`,
  `ArquivosPlanejamento` linhas 455 e 694), que é non-goal. Esses pontos
  continuam chamando `_horarios_exe._para_cp1252` como hoje.
- **`converter_xlsx_para_csv`, `typst_*`, `zip_files`**, que são as outras
  dependências de Windows (non-goal).

## Contrato público novo ou alterado

### `CodificacaoTexto` (novo, `standalone_scripts/utils/codificacao_texto.gd`)

Todas as funções são `static`, puras, determinísticas e totais (aceitam qualquer
entrada), e nenhuma muta o argumento. A ordem no arquivo é: constante privada,
depois as públicas, depois as privadas, se houver.

**Tabela única** (constante privada, 32 entradas, índice = byte − `0x80`, `-1`
para os cinco bytes sem caractere):

```
const _CP1252_80_9F: Array[int] = [
	0x20AC, -1,     0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021,  # 80–87
	0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, -1,     0x017D, -1,      # 88–8F
	-1,     0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,  # 90–97
	0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, -1,     0x017E, 0x0178,  # 98–9F
]
```

Os 27 valores definidos são exatamente os do `match` atual de
`HorariosExe._unicode_para_cp1252`. Os indefinidos são `-1`, e não `0xFFFD`.
Assim a busca inversa nunca devolve um byte indefinido para U+FFFD.

```gdscript
static func eh_utf8_valido(bytes: PackedByteArray) -> bool
```

- **Quem chama:** `FileHandling.convertto_utf8`,
  `ArquivosPlanejamento.ler_comentarios_professor` e os testes.
- **Garante:** devolve `true` se e somente se `bytes` é UTF-8 bem formado pela
  Tabela 3-7 do Unicode. As regras:
  - `00`–`7F` é um byte só;
  - `C2`–`DF` pede 1 continuação;
  - `E0`–`EF` pede 2 e `F0`–`F4` pede 3;
  - a **segunda** byte tem faixa restrita: `E0` → `A0`–`BF`, `ED` → `80`–`9F`,
    `F0` → `90`–`BF`, `F4` → `80`–`8F` e, nos demais, `80`–`BF`;
  - as continuações seguintes são `80`–`BF`;
  - `80`–`C1` e `F5`–`FF` como líder são inválidos, e uma sequência truncada no
    fim também.
- Os casos de borda:
  - vazio é `true`;
  - BOM (`EF BB BF`) é `true`;
  - `00` é `true`, porque é ASCII;
  - U+FFFD codificado (`EF BF BD`) é `true`. A heurística antiga dizia
    "converter" nesse caso e reconvertia um arquivo que já tinha passado pela
    conversão.
- **Equivalência com o motor:** `eh_utf8_valido(b)` é `true` se e somente se
  `b.get_string_from_utf8()` não registra nenhum `Unicode parsing error`. É por
  isso que o ramo UTF-8 de `ler_comentarios_professor` pode decodificar com
  `get_string_from_utf8()` sem gerar ruído.
- **Nunca** chama `get_string_from_utf8()` nem nenhum outro decodificador do
  motor, e não registra nada no log. Faz uma passada só, sai no primeiro byte
  inválido e pula ASCII com uma comparação.

```gdscript
static func cp1252_para_utf8(bytes: PackedByteArray) -> PackedByteArray
```

- **Quem chama:** `FileHandling.convertto_utf8` (quando `eh_utf8_valido` é
  falso), `ArquivosPlanejamento.ler_comentarios_professor` e os testes.
- **Garante:** devolve os bytes UTF-8 do texto que `bytes` representa em
  Windows-1252. O mapa:
  - `00`–`7F` sai igual, um byte (inclusive `00`, `0D` e `0A`, então as quebras
    de linha e a ordem não mudam);
  - `A0`–`FF` vira U+00A0–U+00FF (`C2`/`C3` + continuação);
  - `80`–`9F` passa pela tabela, e os `-1` viram U+FFFD (`EF BF BD`) sem
    interromper a conversão.
- **Saída:** sempre UTF-8 válido, sem BOM acrescentado, com
  `n <= saida.size() <= 3 * n`.
- **Algoritmo:** o laço medido acima, com `resize(bytes.size() * 3)`, escrita
  por índice e `resize(j)` no fim. **Não** usar `get_string_from_ascii()`, que
  trunca no `00`. **Não** concatenar `String` caractere a caractere.

```gdscript
static func texto_para_cp1252(texto: String) -> PackedByteArray
```

- **Quem chama:** `HorariosExe._para_cp1252`, e por meio dele as exportações em
  CP1252 de `ArquivosPlanejamento`. Os testes também chamam.
- **Garante:** um byte por caractere (`saida.size() == texto.length()`):
  - código `<= 0x7F` sai igual;
  - `0xA0`–`0xFF` sai igual;
  - se o código está em `_CP1252_80_9F` (busca com `find`), sai `0x80 + índice`;
  - qualquer outro sai `0x3F` (`?`). Isso inclui U+FFFD, os controles C1
    U+0080–U+009F e qualquer caractere fora da página.
- É **idêntico** ao `HorariosExe._para_cp1252` de hoje. A propriedade de ida e
  volta: para todo `b` em `01`–`FF`, exceto `81`, `8D`, `8F`, `90` e `9D`,
  `texto_para_cp1252(cp1252_para_utf8([b]).get_string_from_utf8()) == [b]`. O
  `00` fica de fora porque `get_string_from_utf8` para nele.

### `FileHandling.convertto_utf8` (alterada: `void` → `bool`)

```gdscript
func convertto_utf8(directory: String, filename: String,
		output_directory: String = GV.dir_saida, output_filename: String = "out.csv") -> bool
```

Os parâmetros, os defaults e o formato (`directory` termina em `/`) não mudam.
A continuação da assinatura é com tabs.

- **Quem chama:** os sete pontos listados em "Camadas tocadas" e os testes.
- **Garante:** devolve `true` se e somente se, no retorno, o arquivo de destino
  contém o texto da origem em UTF-8. O passo a passo:
  1. `origem = directory + filename` e `destino = output_directory + output_filename`.
  2. Lê a origem inteira (`FileAccess.open` + `get_buffer(get_length())`). Se não
     abrir, faz
     `push_error("Conversao para UTF-8: nao foi possivel ler '%s' (%s)." % [origem, error_string(FileAccess.get_open_error())])`
     e devolve `false`. Nesse caso **não cria** pasta nem arquivo de destino, e um
     destino que já existia fica intacto.
  3. **Origem igual ao destino** (a comparação de hoje, por
     `simplify_path().to_lower()`): não grava nada. Devolve
     `eh_utf8_valido(bytes)`. Se for `false`, faz antes
     `push_error("Conversao para UTF-8: '%s' e origem e destino ao mesmo tempo e nao esta em UTF-8; nada foi gravado." % origem)`.
  4. `saida = bytes` se `eh_utf8_valido(bytes)`, senão `cp1252_para_utf8(bytes)`.
     O caso UTF-8 é a cópia byte a byte: o BOM fica, e nada é reconvertido.
  5. `DirAccess.make_dir_recursive_absolute(output_directory)`, depois
     `FileAccess.open(destino, WRITE)` e `store_buffer(saida)`. Se não abrir, faz
     `push_error` com `destino` e `error_string` e devolve `false`. Se o
     `store_buffer` devolver `false`, fecha o arquivo, **remove o destino
     parcial** (`DirAccess.remove_absolute`), faz `push_error` com `destino` e
     devolve `false`. Um destino truncado não pode sobrar: o verificador
     moveria o que estiver em `dados/temp/` para `dados/saida/`.
  6. Um `print_debug` diz qual caminho foi seguido, "convertido de Windows-1252"
     ou "ja em UTF-8, copiado", com origem e destino. Depois devolve `true`.
- **Nunca** chama `get_string_from_utf8()` nem `OS.execute`, e não usa mais
  `GV.dir_principal`.
- **Destino existente:** no sucesso é sobrescrito, como hoje. Na falha de
  leitura fica intacto. Quem precisa saber se a conversão aconteceu usa o
  retorno, e não `file_exists`.
- **Doc comment novo:** diz que a conversão é nativa, descreve o retorno e diz
  que UTF-8 é copiado byte a byte. Some a frase "Em qualquer dos casos o arquivo
  de saída existe ao retornar". As mensagens de log seguem o padrão do arquivo,
  sem acento.

### `HorariosExe._para_cp1252` (interna; assinatura e comportamento intactos)

`func _para_cp1252(texto: String) -> PackedByteArray` passa a ser
`return CodificacaoTexto.texto_para_cp1252(texto)`. O
`_unicode_para_cp1252` sai do arquivo. O comentário vira algo como "Converte
para bytes Windows-1252; a tabela vive em [CodificacaoTexto]".

### Privados e chamadores (sem API pública nova)

- `ArquivosPlanejamento.ler_comentarios_professor(arquivo_selecionado: String) -> Array[String]`
  mantém a assinatura e o retorno. Por dentro:
  `texto_utf8 = raw.get_string_from_utf8()` se
  `CodificacaoTexto.eh_utf8_valido(raw)`, senão
  `CodificacaoTexto.cp1252_para_utf8(raw).get_string_from_utf8()`. Sem arquivo
  temporário e sem `_file_handling.convertto_utf8`. `_verifica_se_windows1252`
  é removida.
- `ImportadorPreferencias.importar(caminho: String) -> Dictionary` mantém a
  assinatura e as chaves `ok`/`mensagem`. O bloco que vai da linha "Detecta
  encoding" até o `else` da cópia vira uma chamada:
  `_file_handling.convertto_utf8(csv_para_importar.get_base_dir() + "/", csv_para_importar.get_file(), _diretorio_regras + "/", nome_arquivo)`.
  - Com `false`: `_limpar_temp(temp_xlsx)` e
    `{"ok": false, "mensagem": "Erro ao salvar arquivo em " + _diretorio_regras}`
    (texto que já existe).
  - Com `true`: `destino_final = _diretorio_regras + "/" + nome_arquivo` e segue
    como hoje.
  - O `_dir_temp` fica só para o intermediário xlsx → csv. O doc de
    `configurar` e o da classe são atualizados.
- `VerificadorArquivos._converter_utf8` (`verificador_arquivos.gd`):
  `print_debug("Arquivo convertido!")` só quando `convertto_utf8` devolve
  `true`. Não há `else` nem mensagem nova na interface (non-goal), porque o
  `push_error` do `FileHandling` já nomeia o arquivo.
- `planejamentohorario.gd`, na importação de referência (linha ~2370): a condição
  `if not FileAccess.file_exists(tmp_caminho):` vira
  `if not file_handling.convertto_utf8(dir_in, nome_arq, GV.dir_saida, tmp_nome):`.
  A mensagem `"Falha ao converter %s — ignorado."` continua a mesma. Assim uma
  falha na 2ª iteração não reaproveita o `_ref_tmp.txt` da 1ª.
- `planejamentohorario.gd`, na lambda de `_abrir_dialogo_conversao`: guarda o
  retorno e faz `fd.queue_free()`.
  - Com `false`:
    `$"%Terminal".text_edit("Falha ao converter %s; nada foi importado." % file_name, "aviso", true, false)`
    e `return`.
  - Com `true`: a mensagem de sucesso de hoje e `ao_concluir.call()`. O
    `FileAccess.file_exists` redundante sai.
- `planejamentooferta.gd`, em `_converter_planejamento_csv`: o mesmo desenho,
  com `_log("Falha ao converter %s; nada foi importado." % file_name, "aviso", true, true)`.
  Só com `true` vêm o `_log` de sucesso e `_abrir_janela_selecao_cursos()`.

### Removidos

`FileHandling._precisa_conversao_utf8`, `ArquivosPlanejamento._verifica_se_windows1252`,
`HorariosExe._unicode_para_cp1252`, a detecção inline de `ImportadorPreferencias`,
`externo/bin/ansi_to_utf8.exe` e `externo/src/ansi_to_utf/ansi_to_utf8.py`.

## Invariantes

1. **Dado pessoal não sai do PC.** A conversão lê arquivos do usuário
   (`hist.csv` tem dado de aluno, `horarios.txt` tem nome de docente). Ela grava
   **nos mesmos destinos de hoje**: `dados/temp/`, `dados/saida/`, a pasta de
   regras e a pasta do cadastro. A superfície até encolhe: `ler_comentarios_professor`
   deixa de gravar uma cópia temporária do CSV de preferências em `dados/temp/`,
   e o importador deixa de passar pelo temporário. Não há rede. As mensagens de
   log só levam caminhos de arquivo, como o `print_debug` de hoje, e vão para
   `user://logs/`, que não é versionado. Os testes usam só texto fictício
   (`Maria da Silva Souza`), gerado em memória e gravado em `user://teste_0010/`,
   que é apagada ao fim de cada teste. Nada novo entra na raiz do projeto, então
   o `exclude_filter` não muda. O `horarios.txt` real do AC10 **nunca** vai para
   `test/fixtures/` nem para PNG.
2. **snake_case interno.** Não há chave nova. Os textos novos aparecem só na
   interface (Terminal) e no log.
3. **Cursos e chaves canônicas.** A feature não toca nisso.
4. **Leitura de arquivo no main/FileHandling; degradação sem crash.** O núcleo
   não lê arquivo. O I/O novo fica em `FileHandling`. `ImportadorPreferencias`
   **deixa** de usar `FileAccess`, e `ArquivosPlanejamento` (congelado) deixa de
   gravar temporário. Nenhum arquivo novo entra em `FILESYSTEM_ALLOWED`. Na falha,
   a função devolve `false` e faz `push_error`, nunca crash.
5. **UI pelas fachadas.** Não há diálogo, tooltip nem cor nova. As duas
   mensagens novas de falha usam o Terminal do módulo com o token `aviso`, que já
   existe.

## Mapeamento AC → prova

Os ACs `headless` rodam com `python .tools/run_tests.py`. Para uma suíte só, use
`-gselect=codificacao_texto` ou `-gselect=conversao_utf8_arquivo`. Os nomes de
teste abaixo são contrato para a implementação.

| AC do card | Método | Onde |
|---|---|---|
| AC1: CP1252 vira o texto equivalente (ASCII intacto, `A0`–`FF` → U+00A0–U+00FF, `80`–`9F` definidos → seus caracteres) | headless | `test_codificacao_texto.gd::test_ascii_passa_intacto`, `::test_faixa_a0_ff_vira_latin1`, `::test_faixa_80_9f_definidos_viram_seus_caracteres` |
| AC2: os cinco indefinidos viram U+FFFD sem interromper | headless | `test_codificacao_texto.gd::test_bytes_indefinidos_viram_fffd_sem_interromper` |
| AC3: a detecção acerta ASCII, vazio, UTF-8 acentuado, BOM e CP1252, sem `get_string_from_utf8()` | headless | `test_codificacao_texto.gd::test_detecao_reconhece_utf8_e_cp1252` (respostas) e `::test_detecao_nao_registra_unicode_parsing_error` (zero linhas no `CapturaLog`; a versão antiga reprova aqui). Apoio: `test_conversao_utf8_arquivo.gd::test_heuristicas_antigas_foram_removidas`. |
| AC4: `convertto_utf8` de CP1252 grava UTF-8 com o mesmo texto e CRLF, e devolve sucesso | headless | `test_conversao_utf8_arquivo.gd::test_converte_cp1252_mantendo_texto_e_crlf` |
| AC5: origem UTF-8 é copiada byte a byte, sem conversão dupla | headless | `test_conversao_utf8_arquivo.gd::test_origem_utf8_e_copiada_byte_a_byte`. Apoio: `::test_origem_utf8_com_bom_mantem_bom`. |
| AC6: origem inexistente falha sem criar destino; origem = destino não toca no arquivo | headless | `test_conversao_utf8_arquivo.gd::test_origem_inexistente_falha_sem_criar_destino` e `::test_origem_igual_ao_destino_nao_toca_no_arquivo` |
| AC7: `horarios.txt` fictício no formato novo passa por `convertto_utf8` e `carregar_horarios_txt` | headless | `test_conversao_utf8_arquivo.gd::test_horarios_txt_formato_novo_cp1252_carrega_dias_e_codigo` |
| AC8: 5 MB de CP1252 em menos de 3 s | headless | `test_conversao_utf8_arquivo.gd::test_converte_5mib_cp1252_em_menos_de_3s`. Apoio (pior caso da detecção): `::test_valida_e_copia_5mib_utf8_em_menos_de_3s`. |
| AC9: o `.exe` e a fonte saem do git, e `git grep` não acha o nome fora de `Cards/` e `.claude/handoff/` | manual | Roteiro R9, abaixo. É determinístico: o agente de implementação o executa e cola a saída no review. |
| AC10: Linux, `horarios.txt` real pelo verificador atualiza `dados/saida/horarios.txt` em UTF-8, sem `Unicode parsing error` | manual | Roteiro R10, executado pelo dev, **sem captura** (dado real). Prova parcial headless: AC7 com `CapturaLog`. |
| AC11: Linux, arquivo com `chmod 000` registra erro com o nome e não registra `Arquivo convertido!` | manual | Roteiro R11. Prova parcial headless: `test_origem_inexistente_falha_sem_criar_destino`, que exige o `push_error` com o nome do arquivo (é o mesmo ramo, `FileAccess.open` nulo). |
| AC12: Windows, a importação do AC10 continua funcionando | manual | Roteiro R12, num PC Windows, depois do `git pull` que remove o `.exe`. |

### Captura de log nos testes

Os dois arquivos de teste declaram a mesma classe interna:
`class CapturaLog extends Logger`, com `var mensagens: Array[String]`, um `Mutex`
e `func _log_message(message: String, error: bool) -> void`, que anexa a
mensagem sob o mutex. O `Logger` pode ser chamado de qualquer thread.

- `before_each` cria a captura e faz `OS.add_logger`. `after_each` faz
  `OS.remove_logger`, **sempre**.
- Um helper `_erros_unicode() -> int` conta as mensagens que contêm
  `"Unicode parsing error"`. Só essas contam: o GUT também imprime pelo log.
- Os testes não usam `assert_engine_error_count(0)` como prova de "sem ruído",
  porque ele não enxerga essas linhas (ver "Fatos do motor").

### Cenários de `test/unit/test_codificacao_texto.gd`

O arquivo tem um oráculo próprio, que **não lê a constante de produção**:
`const ORACULO_80_9F: Dictionary`, com os 27 pares byte → código da tabela
acima, e `const INDEFINIDOS: Array[int] = [0x81, 0x8D, 0x8F, 0x90, 0x9D]`. Abaixo,
`C` = `CodificacaoTexto`.

| Teste | Entrada | Esperado |
|---|---|---|
| AC1 `test_ascii_passa_intacto` | os 128 bytes `00`–`7F` num só array | `C.cp1252_para_utf8(b) == b` |
| AC1 `test_faixa_a0_ff_vira_latin1` | cada `b` em `A0`–`FF`; e `[0xE7, 0xE3, 0x6F]` | `== String.chr(b).to_utf8_buffer()`; e `== "ção".to_utf8_buffer()` |
| AC1 `test_faixa_80_9f_definidos_viram_seus_caracteres` | cada um dos 27 de `ORACULO_80_9F`; e os exemplos do card | `== String.chr(ORACULO_80_9F[b]).to_utf8_buffer()`; e `[0x80]` → `"€"`, `[0x96]` → `"–"`, `[0x93, 0x94]` → `"“”"` |
| AC2 `test_bytes_indefinidos_viram_fffd_sem_interromper` | `[0x41, 0x81, 0x42, 0x8D, 0x8F, 0x90, 0x9D, 0xE7]` | `== "A\uFFFDB\uFFFD\uFFFD\uFFFD\uFFFDç".to_utf8_buffer()` |
| AC3 `test_detecao_reconhece_utf8_e_cp1252` | `"Maria da Silva Souza".to_utf8_buffer()`; `PackedByteArray()`; `"Terça e Sábado".to_utf8_buffer()`; `[0xEF, 0xBB, 0xBF]` + `"ação".to_utf8_buffer()`; e `[0x54, 0x65, 0x72, 0xE7, 0x61]` ("Terça" em CP1252) | `true`, `true`, `true`, `true`, `false` |
| AC3 `test_detecao_nao_registra_unicode_parsing_error` | as cinco entradas acima, mais um bloco de 64 KiB de CP1252 acentuado | `_erros_unicode() == 0` depois de chamar `C.eh_utf8_valido` em todas |

Testes de apoio (não são ACs; cobrem o contrato e as bordas do card):

| Teste | Entrada | Esperado |
|---|---|---|
| `test_detecao_concorda_com_parser_do_godot` | o corpus de 21 casos de "Fatos do motor" | para cada `b`, `C.eh_utf8_valido(b) == (erros capturados em b.get_string_from_utf8() == 0)`. O teste chama o decodificador do motor **de propósito**: é a referência. Como o GUT não rastreia essas linhas, elas não reprovam. |
| `test_saida_e_sempre_utf8_valido` | os 256 bytes `00`–`FF` num só array | `C.eh_utf8_valido(C.cp1252_para_utf8(b))` |
| `test_ida_e_volta_para_todos_os_bytes_definidos` | cada `b` em `01`–`FF` fora de `INDEFINIDOS` | `C.texto_para_cp1252(C.cp1252_para_utf8([b]).get_string_from_utf8()) == [b]` |
| `test_texto_para_cp1252_sem_mapa_vira_interrogacao` | `"✓"`, `"\uFFFD"`, `String.chr(0x81)`, `"あ"` | cada um vira `PackedByteArray([0x3F])` |
| `test_para_cp1252_do_horarios_exe_mantem_bytes` (**fixação**, escrito antes do refactor) | `HorariosExe.new()._para_cp1252("Ação – “Cálculo” € ✓\r\n")` | `[0x41, 0xE7, 0xE3, 0x6F, 0x20, 0x96, 0x20, 0x93, 0x43, 0xE1, 0x6C, 0x63, 0x75, 0x6C, 0x6F, 0x94, 0x20, 0x80, 0x20, 0x3F, 0x0D, 0x0A]` |

### Cenários de `test/unit/test_conversao_utf8_arquivo.gd`

`const RAIZ: String = "user://teste_0010/"`, com as subpastas `origem/`,
`destino/`, `regras/` e `temp/`.

- `before_each` apaga e recria `RAIZ` e registra o `CapturaLog`. `after_each`
  apaga `RAIZ`, nunca nada fora dela, e remove o logger. A remoção é por arquivo
  e depois a pasta, só se existir.
- As fixtures são geradas em memória. O helper de teste `_cp1252(texto: String) -> PackedByteArray`
  codifica com o oráculo do próprio arquivo: Latin-1 mais os 27 da tabela. Ele
  **não** chama `CodificacaoTexto` (o oráculo é independente). Outro helper,
  `_gravar(caminho, bytes)`, grava os bytes; `_ler(caminho)` os lê.
- `F` = `FileHandling.new()`.
- Os testes AC4 e AC7 conferem antes a pré-condição
  `assert_false(CodificacaoTexto.eh_utf8_valido(origem))`, para não serem vácuos.
  Todos os testes que convertem afirmam `_erros_unicode() == 0`.

| Teste | Entrada | Esperado |
|---|---|---|
| AC4 `test_converte_cp1252_mantendo_texto_e_crlf` | `T = "Maria da Silva Souza;Terça;Sábado;Ação – “x” €\r\nLinha 2;Mecânica\r\n"`; origem `_cp1252(T)` em `origem/entrada.txt`; `F.convertto_utf8(RAIZ + "origem/", "entrada.txt", RAIZ + "destino/", "saida.txt")` | retorna `true`; `_ler(destino) == T.to_utf8_buffer()` (o mesmo texto, os dois `\r\n` e nenhum BOM acrescentado) |
| AC5 `test_origem_utf8_e_copiada_byte_a_byte` | origem `"Sábado – ação\r\n".to_utf8_buffer()` | `true`; destino `==` origem; o destino não contém a sequência `C3 83 C2 A1` (o `á` duplicado) |
| AC6 `test_origem_inexistente_falha_sem_criar_destino` | origem `origem/nao_existe.txt`, que não existe | `false`; `assert_push_error("nao_existe.txt")`; `FileAccess.file_exists(RAIZ + "destino/saida.txt") == false` |
| AC6 `test_origem_igual_ao_destino_nao_toca_no_arquivo` | (a) `_cp1252("Terça\r\n")` em `origem/a.txt`, com origem e destino iguais; (b) `"Terça\r\n".to_utf8_buffer()` em `origem/b.txt`, com origem e destino iguais | (a) `false`, `assert_push_error("a.txt")` e bytes idênticos aos de antes; (b) `true`, bytes idênticos e nenhum `push_error` |
| AC7 `test_horarios_txt_formato_novo_cp1252_carrega_dias_e_codigo` | origem `_cp1252` de duas linhas CRLF: `,"Maria da Silva Souza",EaD,ec03,13:30,Terça,"Mecânica dos Sólidos (al0171)",EaD,T100,Vagas,1,1,1` e a mesma com `08:30,Sábado`. Converte para `destino/horarios.txt` e chama `HorariosExe.new().carregar_horarios_txt(RAIZ + "destino/", "horarios.txt", POSICOES)` | `convertto_utf8` devolve `true`; o resultado tem 2 itens; `[0]["linha"] == ""`; `[0]["dia"] == "terça"`; `[1]["dia"] == "sábado"`; `[0]["sala"] == "ead"`; `[0]["tipo"] == "ead"`; `[0]["turma"] == "t100"`; `extrair_cod_horarios_txt([0]["disciplina"]) == "al0171"`; `_erros_unicode() == 0` em todo o percurso |
| AC8 `test_converte_5mib_cp1252_em_menos_de_3s` | uma linha CP1252 fictícia com acentos, `0x80`, `0x93`/`0x94` e `0x96`, terminando em CRLF, repetida até `>= 5 * 1024 * 1024` bytes e gravada antes da medição | `Time.get_ticks_msec()` em volta **só** do `convertto_utf8`: menos de `3000` ms; retorna `true`; o destino é igual à linha UTF-8 esperada repetida o mesmo número de vezes. O tempo medido é impresso com `gut.p` |

`POSICOES` é uma cópia literal de `base_config.json:horarios_txt`, **em float**
como o JSON entrega: `{"linha": 0.0, "professor": 1.0, "sala": 2.0, "semestre": 3.0, "horario": 4.0, "dia": 5.0, "disciplina": 6.0, "tipo": 7.0, "turma": 8.0, "vagas": 9.0, "p": 10.0, "s": 11.0, "t": 12.0}`.

Testes de apoio:

| Teste | Esperado |
|---|---|
| `test_origem_utf8_com_bom_mantem_bom` | origem `[EF BB BF]` + `"Sábado\r\n"` em UTF-8; o destino é igual à origem e começa com `EF BB BF` |
| `test_origem_vazia_gera_destino_vazio` | `true`; o destino existe com 0 bytes |
| `test_destino_existente_e_sobrescrito` | o destino começa com outro conteúdo; depois do `true` ele traz só o novo |
| `test_origem_so_com_lf_continua_lf` | `_cp1252("Terça\nSábado\n")` vira exatamente `"Terça\nSábado\n".to_utf8_buffer()` |
| `test_valida_e_copia_5mib_utf8_em_menos_de_3s` | 5 MiB de UTF-8 acentuado, que é o pior caso da detecção (percorre tudo); menos de 3000 ms; destino idêntico |
| `test_heuristicas_antigas_foram_removidas` | `FileHandling.new().has_method("_precisa_conversao_utf8") == false` e `ArquivosPlanejamento.new().has_method("_verifica_se_windows1252") == false` |
| `test_importador_preferencias_converte_cp1252` | `ImportadorPreferencias.new()`, `configurar(F, RAIZ + "regras", RAIZ + "temp/")`, `importar(RAIZ + "origem/prefs_ficticio.csv")` com origem `_cp1252("Não colocar aula na sexta, à tarde,,,,\r\n")`: `ok == true` e `regras/prefs_ficticio.csv` igual ao texto em UTF-8; `_erros_unicode() == 0` (prova que a heurística inline saiu) |
| `test_importador_preferencias_copia_utf8_sem_alterar` | a mesma coisa com origem já em UTF-8: arquivo em `regras/` byte a byte igual |
| `test_ler_comentarios_professor_em_cp1252` | CSV de 28 linhas em CP1252: as linhas 1–23 são `,,,,`, a 24ª é `Condições adicionais,,,,`, a 25ª é `"Não colocar aula na sexta, à tarde",,,,` e as demais são `,,,,`. `ArquivosPlanejamento.new()`, configurado com `FileHandling`, `AnaliseHorarios`, `AnaliseGrades` e `HorariosExe` novos, `{}`, `{}`, `RAIZ + "regras"` e `{}`. `ler_comentarios_professor("prefs.csv") == ["Não colocar aula na sexta, à tarde"]`, com `_erros_unicode() == 0`. O mesmo CSV em UTF-8 dá o mesmo resultado. |

Fica sem teste headless, e coberto só por review: a falha de **escrita** do
destino (abrir para escrita, ou `store_buffer` devolvendo `false`, com remoção do
parcial). Simular disco cheio ou pasta sem escrita de forma portátil entre Linux
e Windows não compensa.

**AC9 vale também para os testes:** nenhum teste, comentário ou mensagem novos
podem conter a string do nome do executável antigo. Quando precisar citá-lo,
escreva "o conversor externo antigo".

## Riscos de contrato de dados

- **Nenhuma chave muda.** Os JSONs de `arquivos/`, o `base_config.json`, o
  `config_usuario.json` e os records do Kinto ficam iguais.
- **O único contrato alterado** é o retorno de `FileHandling.convertto_utf8`,
  que passa de `void` a `bool`. Chamadores que ignoram o retorno continuam
  compilando: o `project.godot` não liga o aviso `RETURN_VALUE_DISCARDED`.
- **Formato dos arquivos em `dados/`.** O conteúdo convertido é o mesmo texto,
  mas há três diferenças em relação ao executável antigo, todas aceitas:
  1. **Fim de linha preservado byte a byte.** O conversor antigo era Python em
     modo texto no Windows, que lê com newline universal e grava `os.linesep`.
     Então ele provavelmente transformava LF em CRLF. Agora LF continua LF e CRLF
     continua CRLF (AC4). Os leitores (`get_line`, `split("\n")`) aceitam os
     dois.
  2. **Página fixa.** Antes valia a página ANSI do Windows em uso. Agora é
     sempre Windows-1252, independentemente do locale e do sistema.
  3. **Detecção estrita.** Um arquivo UTF-8 válido que contém U+FFFD (por
     exemplo, um já convertido que tinha os bytes indefinidos) é tratado como
     UTF-8 e copiado. Antes ele era reconvertido e virava mojibake.
- **Edge cases do card, mantidos:** um arquivo misto é convertido inteiro, e o
  trecho UTF-8 vira mojibake, como fazia o `.exe`. Um CP1252 que por acaso forma
  UTF-8 válido é tratado como UTF-8. O BOM é mantido. Um arquivo vazio gera
  destino vazio. Instalações antigas mantêm o `.exe` órfão, o que é inofensivo.
- **Destino existente na falha.** Na falha de leitura, um destino que já existia
  **não é apagado**: pode ser o `planejamento.csv` bom de ontem. Por isso os
  chamadores passam a decidir pelo retorno, e não por `file_exists`. Na falha de
  escrita, o destino parcial é removido.
- **Refactor em caminho que o dev não usa mais** (`_para_cp1252` da exportação):
  o teste de fixação é escrito e passa **antes** da troca. Sem ele, uma regressão
  ali passaria despercebida.
- **Desempenho em PCs mais lentos:** o pior caso medido para 5 MiB é ~0,3 s
  (validação completa mais conversão) num processador rápido, contra um orçamento
  de 3 s. A margem passa de 10×. O AC8 roda na máquina que executa a suíte.
- **Comparação de mesmo arquivo sem diferenciar maiúsculas** (já existe hoje). No
  Linux, `A.txt` e `a.txt` são tratados como o mesmo arquivo, e nada é gravado.
  Foi mantida porque o AC6 pede o comportamento atual.
- **LGPD:** a feature não muda onde o dado aparece, e a superfície encolhe (ver
  Invariante 1). O log ganha mensagens com caminho de arquivo, como já tinha. A
  prova do AC10 usa dado real e por isso é manual e sem captura.

## Textos

Todas as mensagens novas, em lugar nenhum além destes:

| Onde | Texto |
|---|---|
| `FileHandling` (`push_error`, leitura) | `Conversao para UTF-8: nao foi possivel ler '<origem>' (<error_string>).` |
| `FileHandling` (`push_error`, mesmo arquivo) | `Conversao para UTF-8: '<origem>' e origem e destino ao mesmo tempo e nao esta em UTF-8; nada foi gravado.` |
| `FileHandling` (`push_error`, escrita) | `Conversao para UTF-8: nao foi possivel gravar '<destino>' (<error_string>).` |
| `FileHandling` (`print_debug`, sucesso) | `Convertido de Windows-1252 para UTF-8: <origem> -> <destino>` ou `Ja em UTF-8, copiado: <origem> -> <destino>` |
| `planejamentohorario.gd` e `planejamentooferta.gd` (Terminal, token `aviso`) | `Falha ao converter <arquivo>; nada foi importado.` |

As frases que tiram o nome do executável (AC9):

- `AGENTS.md` (Setup por máquina, item do Linux): "Os executáveis de
  `externo/bin/` são do Windows e não rodam no Linux. A conversão
  Windows-1252 → UTF-8 deixou de depender deles no card 0010; os demais estão no
  `IDEAS.md`."
- `IDEAS.md:37`: troque "Mesmo caminho que o card 0010 resolveu para o
  `ansi_to_utf8.exe`." por "Mesmo caminho que o card 0010 seguiu para a conversão
  Windows-1252 → UTF-8 (`CodificacaoTexto`, em GDScript)."
- Os doc comments de `file_handling.gd`, `arquivos_planejamento.gd`,
  `importador_preferencias.gd` e `planejamentohorario.gd` passam a dizer
  "conversão nativa ([method FileHandling.convertto_utf8])".

## Roteiros dos ACs manuais

**R9 (AC9).** Na raiz do checkout:

```bash
git rm externo/bin/ansi_to_utf8.exe externo/src/ansi_to_utf/ansi_to_utf8.py
git grep -n ansi_to_utf8 -- ':!Cards' ':!.claude/handoff'   # tem de sair VAZIO (exit 1)
git ls-files externo                                          # sem o .exe e sem externo/src/ansi_to_utf/
```

Passa se o `git grep` não imprime nada e o `git ls-files` não lista os dois
caminhos.

**R10 (AC10, Linux, dado real, sem captura, pelo dev).**

1. Anote a data atual: `ls -l --time-style=long-iso dados/saida/horarios.txt`.
2. Abra o PUG (editor ou `godot --path .`). Na Tela principal, no verificador de
   arquivos, linha `horarios.txt`, selecione o `horarios.txt` recebido em 2026-11.
3. Feche o programa. Confira:
   - `ls -l --time-style=long-iso dados/saida/horarios.txt` mostra a data de
     hoje;
   - `iconv -f utf-8 -t utf-8 dados/saida/horarios.txt > /dev/null && echo UTF8_OK`
     imprime `UTF8_OK`;
   - `grep -c "Terça" dados/saida/horarios.txt` e `grep -c "Sábado" dados/saida/horarios.txt`
     dão mais que 0;
   - `grep -c "Unicode parsing error" "$HOME/.local/share/godot/app_userdata/Pacote de Utilidades para Graduação/logs/godot.log"`
     dá `0`;
   - o mesmo log tem `Arquivo convertido!`.
4. Confira antes de abrir o programa de novo, porque o `godot.log` é da última
   sessão.

**R11 (AC11, Linux, sem dado real).**

1. Crie o arquivo:
   `mkdir -p ~/pug_ac11 && printf 'teste\r\n' > ~/pug_ac11/sem_permissao.txt && chmod 000 ~/pug_ac11/sem_permissao.txt`.
2. Anote a data de `dados/saida/horarios.txt`.
3. No verificador, linha `horarios.txt`, selecione `~/pug_ac11/sem_permissao.txt`.
4. Feche e confira no `godot.log`:
   - `grep -n "sem_permissao.txt" .../godot.log` mostra a linha `ERROR:` do
     `push_error`, com o caminho;
   - `grep -c "Arquivo convertido!" .../godot.log` dá `0`, se não houve outra
     importação na sessão;
   - `dados/saida/horarios.txt` continua com a data anotada.
5. Limpe: `chmod 600 ~/pug_ac11/sem_permissao.txt && rm -r ~/pug_ac11`.

**R12 (AC12, PC Windows, pelo dev).**

1. `git pull`. O `externo\bin\ansi_to_utf8.exe` deve **sumir** do checkout: é
   isso que prova que nada mais depende dele.
2. Repita os passos 1 a 3 do R10. Para a data, use
   `(Get-Item dados\saida\horarios.txt).LastWriteTime`.
3. Confira o log:
   `Select-String -Path "$env:APPDATA\Godot\app_userdata\Pacote de Utilidades para Graduação\logs\godot.log" -Pattern "Unicode parsing error"`
   não pode devolver nada, e `-Pattern "Arquivo convertido!"` deve devolver
   uma linha.
4. Abra `dados\saida\horarios.txt` no VSCodium. A barra de status mostra
   `UTF-8`, e `Terça`/`Sábado` aparecem corretos.

## Smoke

Nenhum. Não há mudança visual, e a prova do AC10 usa dado real, que não pode
virar PNG (card, "Smoke scenarios").

## Ordem de implementação

Cada passo termina com a suíte verde (`python .tools/run_tests.py`) e o
guardrails sem violação nova (`python .tools/guardrails.py`).

1. **Fixação antes de mexer.** Crie `test_codificacao_texto.gd` só com
   `test_para_cp1252_do_horarios_exe_mantem_bytes`. Ele passa contra o código
   atual.
2. **Conversão e tabela.** Escreva os testes de AC1 e AC2, de ida e volta, de
   saída válida e de "sem mapa vira `?`" (vermelhos). Crie `codificacao_texto.gd`
   com `_CP1252_80_9F`, `cp1252_para_utf8` e `texto_para_cp1252` (verdes).
3. **Detecção.** Escreva os testes de AC3 e o de concordância com o parser, com
   o `CapturaLog` no arquivo (vermelhos). Implemente `eh_utf8_valido` (verdes).
4. **Tabela única.** `HorariosExe._para_cp1252` passa a delegar, e sai
   `_unicode_para_cp1252`. A fixação do passo 1 continua verde.
5. **I/O.** Crie `test_conversao_utf8_arquivo.gd` com AC4 a AC8 e os testes de
   apoio de `FileHandling` (vermelhos). Reescreva `convertto_utf8` (nativo,
   `-> bool`, assinatura com tabs, doc novo) e remova `_precisa_conversao_utf8`
   e o código comentado (verdes).
6. **Chamadores, um por vez, com teste quando houver:**
   - `ArquivosPlanejamento`: `test_ler_comentarios_professor_em_cp1252` primeiro,
     depois a decodificação em memória e a remoção de `_verifica_se_windows1252`;
   - `ImportadorPreferencias`: os dois testes do importador, depois a chamada
     única;
   - `test_heuristicas_antigas_foram_removidas`;
   - por último, sem teste headless e por inspeção: o verificador
     (`Arquivo convertido!` só no sucesso), `planejamentohorario.gd` (dois
     pontos mais o doc) e `planejamentooferta.gd`.
7. **Remoção (AC9).** Faça o `git rm` dos dois arquivos de `externo/` e troque as
   frases de `AGENTS.md` e `IDEAS.md`. Rode o R9 e cole a saída no review.
8. **Portões finais:**
   - `python .tools/guardrails.py`; se alguma contagem da baseline caiu, rode
     `python .tools/guardrails.py --update-baseline` para apertar;
   - `python .tools/run_tests.py`;
   - o parser do Godot (`godot --headless --path . --editor --quit` no Linux;
     `"C:/Program Files/Godot/Godot_console.exe" --headless --path . --editor --quit`
     no Windows).

   Os roteiros R10, R11 e R12 ficam com o dev.
