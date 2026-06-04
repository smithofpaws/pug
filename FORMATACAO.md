# Regras de Formatação — GDScript

Convenções extraídas dos arquivos `.gd` deste projeto. O estilo de referência é o dos módulos novos (`SituacaoAlunos`, `MatriculaIrregular`, `PlanejamentoHorario`) e dos scripts standalone (`analise_curricular`, `analise_historico`, `file_handling`).

---

## 1. Cabeçalho do Arquivo

```gdscript
class_name NomeDoModulo extends ReferenceRect
## Descricao da classe. [br]
## [br]
## Continuacao da descricao com [code]referencias[/code], [method Metodo], [param nome].
## [br]
## [b]Nota:[/b] Observacoes relevantes.
```

- `class_name` sempre na **linha 1**, seguido de `extends`.
- Documentação da classe com `##` nas linhas seguintes. Usar `[br]` para quebra, `[code]...[/code]` para arquivos/código, `[method Nome]` para métodos, `[param nome]` para parâmetros.
- **Sem** cabeçalho de licença GPL nos módulos de cena. Licença GPL presente apenas nos scripts standalone (`analise_*.gd`, `file_handling.gd`, `globals.gd`).

---

## 2. Ordem das Seções

Dentro do corpo da classe, as seções aparecem nesta ordem:

```
# Em scripts standalone (Resource):
# 1. Classes instanciadas.
# 2. Variaveis injetadas (documentadas com ##).
# 3. Variaveis privadas (documentadas com #).
# 4. Funcoes publicas (sem _, documentadas com ##).
# 5. Funcoes privadas (com _, documentadas com #).

# Em modulos de cena (extends ReferenceRect):
# 1. Classes instanciadas.
# 2. Variaveis injetadas (documentadas com ##).
# 3. Variaveis privadas (documentadas com #).
# 4. Funcoes de ciclo de vida (_ready, _process, etc.).
# 5. Funcoes privadas (helpers internos, documentadas com #).
# 6. #region Sinais (opcional, _on_*).
```

**Regra:** funções sem `_` (públicas) sempre antes das funções com `_` (privadas).
A única exceção são os módulos de cena onde todas as funções são privadas ao módulo
e os sinais (`_on_*`) ficam por último, agrupados em `#region Sinais`.

Exemplo de script standalone:

```gdscript
class_name AnaliseHorarios extends Resource
## Documentacao da classe.

# Classes instanciadas.
var analise_historico := AnaliseHistorico.new()

# --- Funcoes publicas ---

## Obtem lista de dias da semana.
func dias_da_semana(horarios_ini: Dictionary) -> Array:
    ...

## Detecta choques de horario entre condicoes.
func detectar_choques(horarios_txt_condicao: Dictionary, regras: Array[Array]) -> Dictionary:
    ...

# --- Funcoes privadas ---

# Extrai de horarios_txt apenas as linhas relevantes.
func _extrair_horarios_txt(horarios_txt: Array, ...) -> Dictionary:
    ...
```

Exemplo de módulo de cena:

```gdscript
class_name Exemplo extends ReferenceRect
## Documentacao da classe.

# Classes instanciadas.
var file_handling := FileHandling.new()

## Recebido pelo main em sua criacao e vem do arquivo [code]base_config.json[/code].
var posicoes_histcsv: Dictionary

# Contem os dados do historico, de todos os alunos, que importam para esta analise.
var _historico: Dictionary

func _ready() -> void:
    ...

# Roda a analise para a selecao atual.
func _analisar_matricula(matricula: String) -> void:
    ...

#region Sinais
func _on_exportar_button_up() -> void:
    ...
#endregion
```

---

## 3. Instanciação de Classes

Usar `:= ClassName.new()`. **Não** usar `preload().new()`.

```gdscript
# Correto
var file_handling := FileHandling.new()
var analise_historico := AnaliseHistorico.new()

# Evitar
var file_handling: Resource = preload("res://...").new()
```

---

## 4. Documentação de Variáveis

### Variáveis públicas/injetadas — `##`

Usar `##` (docstring do Godot). Descrever a origem e o formato. Tags permitidas: `[br]`, `[code]`, `[param]`, `[method]`.

```gdscript
## Recebido pelo main em sua criacao e vem do arquivo [code]base_config.json[/code].
var posicoes_histcsv: Dictionary

## Recebido pelo main em sua criacao e vem da pasta de grades. [br]
## Formato de [param grades_disciplinas_curriculos] deve conter multiplas grades, 
## com chave no padrao [code]<cod_curso>_<versao>[/code]. Exemplo: [br]
## { [br]
## "alec_2010": Dicionario copia de [code]/arquivos/grades/alec_2010.json[/code], [br]
## "alec_2023": Dicionario copia de [code]/arquivos/grades/alec_2023.json[/code] [br]
## }
var grades_disciplinas_curriculos: Dictionary = {}

## Recebido pelo main, contem as cores padrao do terminal.
var cores_terminal: Dictionary = {}
```

### Variáveis privadas — `#`

Usar `#` (comentário simples). Sem `##`.

```gdscript
# Contem os dados do historico, de todos os alunos, que importam para esta analise.
var _historico: Dictionary

# E uma array contendo em cada elemento a combinacao do nome do aluno e sua matricula.
var _lista_alunos: Array[Array]
```

---

## 5. Nomenclatura

| Elemento | Convenção | Exemplo |
|----------|-----------|---------|
| Classe | PascalCase | `SituacaoAlunos`, `AnaliseHistorico` |
| Variável pública | snake_case | `posicoes_histcsv`, `cores_terminal` |
| Variável privada | `_snake_case` | `_historico`, `_lista_alunos` |
| Função pública | snake_case (sem `_`) | `criar_lista_alunos()`, `detectar_choques()` |
| Função privada | `_snake_case` | `_rodar_analise()`, `_extrair_horarios_txt()` |
| Sinal handler | `_on_<node>_<signal>` | `_on_exportar_button_up()` |
| **Ordem** | públicas → privadas → sinais | Funções sem `_` antes das com `_` |
| Constante | snake_case | — |
| Arquivo | snake_case | `situacao_alunos.gd` |

---

## 6. Documentação de Funções

### Funções públicas — `##`

```gdscript
## Cria uma lista de alunos a partir do historico, retornando uma Array de [matricula, nome]. [br]
## Formato de [param historico] deve ser o padrao do historico.
func criar_lista_alunos(historico: Dictionary) -> Array[Array]:
```

### Funções privadas — `#`

```gdscript
# Roda a analise para a selecao atual.
func _rodar_analise() -> void:

# Le o arquivo [code]hist.csv[/code] da pasta [code]dados/saida/[/code].
func _ler_dados() -> void:
```

---

## 7. Idioma dos Comentários

- **Português brasileiro** em todos os arquivos `.gd`, exceto:
  - `standalone_scripts/utils/general_functions.gd` — comentários em **inglês** (funções utilitárias genéricas).

---

## 8. Tipagem Estática

- Todas as funções declaradas com tipo de retorno (`-> void`, `-> Dictionary`, `-> Array[String]`, etc.).
- Todos os parâmetros de função com tipo.
- Todas as variáveis com tipo declarado.
- Tipos compostos explicitar o tipo interno: `Array[String]`, `Array[Dictionary]`, `Array[Array]`.
- Quando o tipo da variável é inferido do inicializador, usar `:=`:
  ```gdscript
  var file_handling := FileHandling.new()
  ```

---

## 9. Quebra de Linha com `\`

Para linhas longas, usar `\` ao final da linha e continuar na próxima com **mesmo nível de indentação** do início da expressão:

```gdscript
_condicoes_discentes = analise_historico.condicoes_discentes(_lista_alunos, _historico, condicoes, \
grades_disciplinas_curriculos, equivalencias)
```

Quando possível, usar colchetes/array para evitar `\`:

```gdscript
var cores_preferencias: Array[Color] = [
    Color(0,   1,   0, 255),
    Color(0.25, 0.75, 0, 255),
]
```

---

## 10. `#region` / `#endregion`

- Usar **opcionalmente** para agrupar sinais (`#region Sinais`).
- Nome da região em português, Title Case.
- Não abusar — a maioria dos arquivos usa apenas para sinais ou não usa nenhuma.

```gdscript
#region Sinais
func _on_exportar_button_up() -> void:
    ...
#endregion
```

---

## 11. Espaçamento

### Linhas em branco

| Situação | Linhas |
|----------|--------|
| Entre a última declaração de variável e `func _ready()` | 1 |
| Entre funções | 1 |
| Antes de `#region` | 1 |
| Após `#endregion` | 0 |
| Dentro de funções (separar blocos lógicos) | 1 (raro) |

### Indentação

- Exclusivamente **tabs**. Nunca espaços.

---

## 12. Marcadores `# TODO` e `# FIXME`

```gdscript
# TODO Descrever o que falta fazer.
# FIXME Descrever o bug a ser corrigido.
```

- Sempre na linha anterior ao código relacionado (não inline, exceto quando inevitável).

---

## 13. Funções Lambda

Capturar variáveis do escopo externo e definir antes do uso:

```gdscript
var my_lambda = func(cod_disc: String, hist_temp: Dictionary) -> void:
    # corpo da lambda
    ...

# Uso posterior
for cod_disc in grade:
    my_lambda.call(cod_disc, historico)
```

---

## 14. Acesso a Nós da Cena

- Usar `$"%UniqueName"` quando o nó tem `unique_name_in_owner = true` na cena.
- Usar `$"Caminho/Completo"` (com aspas) quando não tem unique name.
- Não usar `get_node()`.

```gdscript
$"%Terminal".text_edit("texto", cores_terminal["padrao"])
$"Topo/HBoxContainer/Exportar".pressed.connect(_on_exportar_button_up)
```

---

## 15. Chaves de Dicionário e Strings

- Chaves de dicionário em snake_case: `"matriculado_agora"`, `"nomedoaluno"`, `"versao_grade"`.
- Strings de saída em português.

---

## 16. Comentários

- **Gerais:** devem ser mínimos, profissionais e muito claros;
- **Idioma:** português brasileiro em todo `.gd`, exceto `standalone_scripts/utils/general_functions.gd` (inglês). [br]
  _Regra já detalhada na seção 7 acima;_
- **Documentação de funções:** usar `##` (públicas) / `#` (privadas), conforme seções 4 e 6;
- **Tags BBCode:** `[br]` para quebra de linha, `[codeblock]` para blocos de código;
- **Referência oficial:** https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_documentation_comments.html.

---

## 17. Estética e Interface

Decisões visuais/de interface unificadas no projeto. Complementam as regras de organização do `AGENTS.md`.

### Capitalização de texto visível

- **Sentence case** em todo texto da UI (botões, títulos, rótulos, placeholders, itens de menu): apenas a primeira letra maiúscula. Ex.: "Situação de alunos", "Planejamento de horário".
- **Exceções:** siglas (`CR`) e nomes próprios (`Limesurvey`, `Nord`).
- Escolhido por ser idiomático em pt-BR (em vez de Title Case).
- **Dado interno em snake_case, texto formatado só na UI:** variáveis, chaves de dicionário e valores de lógica permanecem em snake_case (sem acento, sem espaço); a conversão para texto de apresentação (espaços, acentos, capitalização) acontece apenas no momento de inserir na UI. Regra detalhada no `AGENTS.md` ("Regra snake_case").

### Cores — `PaletaSemantica`

Toda cor sai de `PaletaSemantica` (`scenes/Themes/paleta_semantica.gd`). **Proibido** hardcode de `Color`/hexadecimal nos módulos.

- O **significado** (matiz) é definido uma única vez em `PALETA`; o **contraste** (luminosidade) é ajustado ao fundo do tema em tempo de execução. Adicionar um tema novo não exige autorar cores.
- Consumir via:
  - `PaletaSemantica.cor(token)` → `Color` (ex.: célula da grade);
  - `PaletaSemantica.cor_hex(token)` → `#rrggbb`, para BBCode (Terminal, grade de horários);
  - `PaletaSemantica.cor_adaptada(token, fundo, cor_texto)` quando o consumidor conhece o próprio fundo no momento de pintar;
  - `PaletaSemantica.fundo()` → fundo do tema, para chrome que precisa **combinar** com o fundo em vez de contrastar (ex.: `DicaFlutuante`).
- Tokens neutros (`padrao`, `matriculavel`) resolvem para a cor de texto do tema.

### Dimensões de controles

- Altura dos controles da barra de topo (`Topo`): **30px** (não 32, que estoura a barra); unificada em `SeletorAvancado.tscn`.
- Rodapé `StatusBar`: **24px**.
- Largura padrão de seletor: centralizada em `base_config.json:interface.largura_padrao_seletor`.

### Componente `StatusBar`

Rodapé de status reutilizável (`scenes/Complementares/StatusBar/`, `class_name StatusBar`), ancorado à base do módulo. Preferir a este componente em vez de labels de status ad-hoc.

- `definir_segmentos({chave: texto})` — cria os segmentos uma vez (no `_ready`), separados por `VSeparator`.
- `atualizar(chave, texto, token_cor := "")` — atualiza um segmento; `token_cor` (opcional) é resolvido por `PaletaSemantica`.

### Seletores — rótulo separado do valor (`SeletorAvancado`)

Em `SeletorAvancado` (`scenes/Complementares/SeletorAvancado/`), as chaves de `lista_itens` seguem convenções:

- chave iniciando com `_` → **suprime** o separador;
- terminando em `_` → lista de **múltipla** seleção;
- terminando em `*` → lista de **seleção única**;
- terminando em `_retorno` → array paralela com os **valores canônicos** (snake_case) retornados pelo sinal;
- terminando em `_disabled` → array paralela de flags de item desabilitado.

**Regra:** quando o item é usado como chave de lógica (`match retorno`), sempre usar o par `_retorno` para separar o **rótulo exibido** (sentence case) do **valor canônico** (snake_case).

### Modos de exibição da grade de horários

Lista canônica única em `base_config.json:formatos_grade` (`rotulos` + `valores`), injetada pelo `main` em `SituacaoAlunos`, `SituacaoDisciplinas` e `PlanejamentoHorario`. Consumida por dois formatadores:

- `analise_horarios._preparar_horarios` — a partir dos dados crus do `horarios.txt`;
- `gerenciador_alocacoes.rotulo_alocacao` — a partir da alocação estruturada (nome resolvido da grade).

A `GradeCurricular` (`montar_grade_curricular`) é uma lista à parte, **não** unificada.

### Saída no Terminal (markdown + tokens)

O `Terminal` (`scenes/Complementares/Terminal/terminal.gd`) renderiza **BBCode**, não markdown. Ao **copiar**, o `RichTextLabel` entrega só o texto visível — as tags de cor **não** sobrevivem, mas marcadores markdown digitados no próprio conteúdo **sim**. Por isso a apresentação é **complementar**: a **estrutura** vai em markdown no texto (sobrevive ao copiar) e a **semântica** vai no token de cor (só na tela).

**Use os helpers do `Terminal`** em vez de formatar à mão:

| Helper | Saída no texto | Token | Uso |
|--------|----------------|-------|-----|
| `titulo(t, limpar := false)` | `# t` | `alerta` | título do relatório (abrir com `limpar=true`) |
| `secao(t)` | `## t` | `alerta` | cabeçalho de seção |
| `subsecao(t)` | `### t` | `alerta` | subseção (raro) |
| `item(t, nivel := 0, token := "padrao")` | `- t` (2 espaços/nível) | livre | item de lista |
| `linha(t, token := "padrao")` | `t` | livre | corpo ou status curto |
| `separador()` | linha em branco + `---` | `padrao` | separador maior |
| `espaco()` | linha em branco | `padrao` | separar blocos |

Regras:
- **Marcador de lista único:** `-`. Proibidos `*` e `•`.
- **Separador:** `---` (via `separador()`), nunca `===` nem `───`.
- **Campos compactos:** `Chave: valor`; múltiplos campos numa linha com ` | `.
- **Cor por papel:** títulos/seções = `alerta`; corpo = `padrao`; ok/vazio = `sucesso`; totais de atenção = `aviso`; problemas/itens com erro = `erro`.
- **Sem símbolos decorativos** (`✓`, `⚠`) nem efeito `shake` na saída padronizada; a cor já cumpre o papel. `→` é permitido apenas em mapeamentos (ex.: `Movido: MAT01 → [5, 3]`).
- **Saída tabular/CSV:** envolver num bloco cercado com ```` ``` ```` (linha só com as três crases antes e depois), para colar como código.
- **Linhas compostas multi-cor:** quando uma linha mistura cores (ex.: contagens), usar `text_edit` direto — **começando** pelo marcador markdown (`"- ..."` com `newline=true`) e seguindo com segmentos `newline=false`.
- Tooltips contextuais continuam via `registrar_meta(chave, bbcode)` + `[url=chave]` no texto.

### Tooltips e diálogos

Regras detalhadas no `AGENTS.md` (seção "Regras de organização"): usar sempre `DicaFlutuante` para tooltips e `Dialogos.confirmar(...)` para diálogos sim/não. Não duplicadas aqui.

---

## Resumo

| Regra | Exemplo |
|-------|---------|
| `class_name` na linha 1 | `class_name SituacaoAlunos extends ReferenceRect` |
| `##` para doc de classe e vars públicas | `## Recebido pelo main...` |
| `#` para vars privadas e funções privadas | `# Contem os dados do historico...` |
| `_prefixo` para privado | `_historico`, `_rodar_analise()` |
| Públicas antes de privadas | `detectar_choques()` antes de `_extrair_horarios_txt()` |
| Sinais por último | `_on_*` agrupados em `#region Sinais` |
| `:= ClassName.new()` | `var file_handling := FileHandling.new()` |
| Tipagem em tudo | `func foo(x: String) -> Dictionary:` |
| `\` para quebra de linha | `param1, param2, \` |
| Tabs para indentação | Nunca espaços |
| `%UniqueName` para nós | `$"%Terminal"` |
| Comentários em português | Exceto `general_functions.gd` |
| Sentence case na UI | "Situação de alunos", não "Situação De Alunos" |
| Cores via `PaletaSemantica` | `PaletaSemantica.cor("erro")`, nunca `Color.RED` hardcoded |
| Valor canônico via `_retorno` | rótulo "Somente código" → valor `somente_codigo` |
