# Spec — 0009-busca-no-terminal

Card: `Cards/0009-busca-no-terminal/card.md`.

Objetivo: com o foco no `%TextEdit` do Terminal, **Ctrl+F** abre uma faixa de
busca no topo do próprio componente. Ao digitar, todas as ocorrências do termo
no **texto visível** ficam realçadas (fundo leve), a atual com fundo forte, e o
Terminal rola até ela. Enter e Shift+Enter navegam em ciclo, e Esc fecha. A lógica
inteira (tokenizar o BBCode das entradas, achar as ocorrências ignorando caixa e
acento, montar o BBCode realçado e a navegação circular) vai para uma classe pura
nova, `BuscaTerminal`. O Terminal só cuida de teclado, faixa, foco e rolagem. Como
o Terminal é um componente único, a busca chega aos nove módulos que o instanciam
sem que nenhum deles mude.

Fatos do motor que a spec usa: todos foram conferidos no Godot 4.7.2 headless
(`--headless -s`), num projeto descartável fora do repositório.

- `RichTextLabel.get_parsed_text()` funciona **fora da árvore**. Uma tag
  desconhecida (`[5, 3]`, `[B]`, `[ b]`, `[unknown=1]`) sai **literal**. Um
  fechamento que não casa com o topo da pilha (`a [/b] b`) também sai literal.
  `[lb]`/`[rb]` viram `[`/`]` e `[br]` vira `"\r"` (um caractere).
- Um `[bgcolor]` que **atravessa** uma tag quebra o texto:
  `[url=k]Cá[bgcolor=X]lculo[/url] x[/bgcolor]` aparece como
  `Cálculo[/url] x[/color]`. Por isso o realce é aplicado **por trecho**, sem
  nunca conter uma tag.
- Um `[` literal seguido de um nome de tag conhecido pode "engolir" a tag
  inserida: `see [url=` + `[bgcolor=X]` vira um `[url=...]`. Por isso, numa
  entrada realçada, todo `[` literal é reemitido como `[lb]`.
- `get_character_line(i)` usa o mesmo índice de `get_parsed_text()`. Pode
  devolver `-1` enquanto o layout está pendente. `scroll_to_line` e
  `get_line_offset` funcionam. `set_text` com o mesmo layout **não** reseta a
  rolagem.
- `select_all()` + `get_selected_text()` com `[bgcolor]` ativo devolve o mesmo
  texto que sem ele.
- Custo de um realce pesado (cerca de 6 ocorrências por linha): 2000 linhas,
  ~35 ms de `set_text` mais ~85 ms de layout; 5000 linhas, ~90 ms mais ~200 ms.
  Tokenizar e normalizar 270 mil caracteres custa poucos ms.
- `LineEdit.keep_editing_on_text_submit` e `Viewport.push_input` existem e, no
  headless, o foco (`grab_focus`/`has_focus`) funciona.

## Camadas tocadas

| Arquivo | Por quê |
|---|---|
| `standalone_scripts/utils/busca_terminal.gd` (**novo**) | Núcleo puro. `class_name BuscaTerminal extends RefCounted`, só funções `static`, **sem** cabeçalho GPL. O precedente é `MarkdownHtml` (`markdown_html.gd`): mesma pasta, `RefCounted`, estático e puro, e quem chama injeta a aparência (lá o CSS, aqui as cores do realce). Reusa `GeneralFunctions.remover_acentos` sem alteração. |
| `scenes/Complementares/Terminal/Terminal.tscn` | Ganha a faixa de busca e um `Timer`. O `%TextEdit` passa para dentro de `Margem/Coluna`, para a faixa empurrar o texto para baixo. **O `uid://hfr04nwubwo6` da cena não muda**: os nove módulos a referenciam por ele. |
| `scenes/Complementares/Terminal/terminal.gd` | Adaptador de UI. Cuida do estado da busca, dos atalhos, do contador, da rolagem e das dicas. `_renderizar` passa a aplicar o realce e a preservar a rolagem, e `_segmento_bbcode` ganha o parâmetro `texto`. **A API pública não muda.** Os handlers `_on_*` vão para `#region Sinais`, no fim do arquivo. |
| `test/unit/test_busca_terminal.gd` (**novo**) | Testes do núcleo (AC1–AC7) e paridade com o `RichTextLabel` real (AC5 no motor). Fixtures inline e fictícias. |
| `test/unit/test_terminal_fiacao_busca.gd` (**novo**) | Testes de fiação com a cena `Terminal.tscn` real. Provam que o Terminal consome o núcleo e cobrem a lógica de estado por trás dos ACs manuais 9–15. Não substituem os roteiros. |
| `MANUAL.md` | Só a seção **3.2 Terminal** (AC16). |
| `.tools/guardrails_baseline.json` | Só **aperta** a catraca. Quando os handlers vão para o fim, `scenes/Complementares/Terminal/terminal.gd|section-order` sai do arquivo (de 1 para 0). |

São três camadas de produção: utils (núcleo), componente de UI e documentação.
Os testes vêm à parte. Passa de três arquivos de produção porque o Terminal é cena
mais script. A divisão segue a frase do card: "O Terminal só cuida de teclado,
faixa e rolagem".

Fica fora do diff, de propósito:

- **Os nove módulos** (`CalculadorCR`, `Exportadores`, `LimeSurvey`,
  `MatriculaIrregular`, `PlanejamentoHorario`, `PlanejamentoOferta`,
  `SituacaoAlunos`, `SituacaoDisciplinas`, `Trancamentos`). Nenhum `.gd` e nenhum
  `.tscn` deles muda (non-goal). Eles instanciam a cena pelo uid, e nenhum
  sobrescreve propriedade de filho do Terminal (sem `editable path`, conferido).
- **`scenes/main.gd`.** Não há leitura nova nem injeção nova.
- **`base_config.json`.** Nenhuma chave nova. As constantes de aparência ficam no
  Terminal (ver "Riscos").
- **`PaletaSemantica`, `DicaFlutuante`, `GeneralFunctions`.** São reusados sem
  alteração: `cor("selecao")`, `vincular` e `remover_acentos`.
- **`export_presets.cfg`.** Não há arquivo novo na raiz. Os testes já estão no
  `exclude_filter` (`test/*`).

## Contrato público novo ou alterado

### `BuscaTerminal` (novo, `standalone_scripts/utils/busca_terminal.gd`)

Todas as funções são `static`, puras e determinísticas: nada de `FileAccess`,
`GV`, nó, `print`/`push_*` ou `PaletaSemantica`, e nenhuma muta os argumentos. A
ordem no arquivo segue a lista abaixo: constantes, depois as públicas, depois as
privadas (guardrail `section-order`). As constantes são privadas:

- `_TAGS_CONHECIDAS: Array[String]`: os nomes de tag que o `RichTextLabel` 4.7
  reconhece. A lista completa é `b, i, u, s, code, char, p, center, left, right,
  fill, indent, url, hint, dropcap, color, bgcolor, fgcolor, outline_size,
  outline_color, font, font_size, opentype_features, otf, lang, table, cell, ul,
  ol, img, wave, tornado, shake, fade, rainbow, pulse, lrm, rlm, lre, rle, lro,
  rlo, pdf, alm, zwj, zwnj, wj, shy, hr`. Ela é **completa de propósito**: uma tag
  que o motor esconde e a lista não conhece seria reemitida com `[lb]` e
  apareceria na tela.
- `_ESCAPES: Dictionary`: `{"lb": "[", "rb": "]", "br": "\r"}`.

**Formato do índice** (retorno de `indexar`, entrada de `buscar`/`realcar`). As
chaves são snake_case:

```
{
	"visivel": String,      # texto visível completo; cada entrada de nl = true contribui um "\n" antes do texto
	"normalizado": String,  # GeneralFunctions.remover_acentos(visivel); SEMPRE o mesmo comprimento de visivel
	"entradas": Array[Dictionary],  # uma por entrada do buffer, mesma ordem e tamanho
}
entradas[i] = {
	"texto": String,  # texto cru da entrada (BBCode), devolvido intacto quando não há ocorrência nela
	"inicio": int,    # posição em visivel do 1º caractere visível do texto (depois do "\n" de nl)
	"fim": int,       # inicio + comprimento visível do texto (exclusivo)
	"tokens": Array[Dictionary],  # { "tipo": "texto" | "tag" | "escape", "fonte": String, "visivel": String }
}
```

**Regra do tokenizador** (contrato, por entrada, com uma pilha local de nomes):

1. Procura o próximo `[` com `find`. Sem `[`, o resto é `texto`.
2. Sem `]` depois do `[`, o resto (com o `[`) é `texto`.
3. `tag` é o que fica entre `[` e `]`. Se `tag` está em `_ESCAPES`, o token é
   `escape`: `fonte` = `[lb]`/`[rb]`/`[br]` e `visivel` = um caractere.
4. Se `tag` começa com `/`, o fechamento só é token `tag` (e desempilha) quando a
   pilha não está vazia e o topo é igual a `tag.substr(1)`.
5. Senão, `nome` é `tag` até o primeiro `" "` ou `"="` (o que vier antes). Se
   `nome` está em `_TAGS_CONHECIDAS`, o token é `tag` (`visivel` = `""`) e `nome`
   vai para a pilha. A comparação diferencia maiúsculas: `[B]` é literal, como no
   motor.
6. Nos demais casos, o `[` é **um** caractere literal e a varredura recomeça logo
   depois dele, como no motor.
7. Caracteres literais consecutivos formam **um** token `texto`, com
   `fonte == visivel`. Ele pode conter `[` e `]` literais.

```gdscript
static func indexar(buffer: Array[Dictionary]) -> Dictionary
```

- **Quem chama:** `Terminal._abrir_busca`, uma vez por abertura, com `_buffer`.
  O retorno fica em `_indice_busca`. É um **retrato** do buffer, e continua
  válido enquanto a faixa está aberta, porque qualquer escrita fecha a busca
  antes de mexer no buffer. Os testes também chamam.
- **Entrada:** as entradas do Terminal. Lê só `texto` (`str(entrada.get("texto", ""))`)
  e `nl` (`bool(entrada.get("nl", false))`). `token`, `efeito` e `bg` são
  ignorados: eles só montam o envelope (`[color]`, `[bgcolor]`, `[shake]`), que é
  invisível.
- **Garante:**
  - `visivel` é o que `RichTextLabel.get_parsed_text()` mostra para o BBCode que
    o Terminal monta a partir do mesmo buffer. Isso vale para entradas bem
    formadas (ver "Riscos").
  - `normalizado.length() == visivel.length()`. `remover_acentos` troca um
    caractere por um, e `to_lower` do Godot também. Se um dia os comprimentos
    divergirem (um mapa novo que expanda, como `ß → ss`), `normalizado` cai para
    `visivel.to_lower()` e a busca perde só a insensibilidade a acento. O índice
    nunca desalinha.
  - `entradas.size() == buffer.size()`. `inicio`/`fim` são crescentes e não se
    sobrepõem.
  - Buffer vazio dá `{"visivel": "", "normalizado": "", "entradas": []}`.

```gdscript
static func buscar(indice: Dictionary, termo: String) -> Array[Vector2i]
```

- **Quem chama:** `Terminal._executar_busca`. Os testes também chamam.
- **Garante:** devolve as ocorrências como `Vector2i(inicio, fim)` em posições de
  `visivel` (`x` = início, `y` = fim exclusivo), **em ordem crescente e sem
  sobreposição**. A varredura é `normalizado.find(t, pos)` e, depois de cada
  achado, `pos = achado + t.length()`, então `aa` em `aaaa` dá
  `[(0,2), (2,4)]`.
  - `t = GeneralFunctions.remover_acentos(termo)`. O termo é comparado **como
    digitado**, só sem caixa e sem acento. Um espaço no fim faz parte dele, como
    no navegador.
  - `termo.strip_edges().is_empty()` (vazio, espaços, tab) dá `[]`.
  - Índice vazio, ou sem a chave `normalizado`, dá `[]`.
  - Como `normalizado` só tem texto visível, um termo nunca casa dentro de uma
    tag (AC3). O `"\n"` de `nl` está em `visivel`, então uma ocorrência só
    atravessa duas entradas quando a segunda tem `nl = false` (AC4).

```gdscript
static func realcar(indice: Dictionary, ocorrencias: Array[Vector2i], atual: int, cor_todas: String, cor_atual: String) -> Array[String]
```

- **Quem chama:** `Terminal._renderizar`, quando a busca está aberta e há
  ocorrências. Os testes também chamam.
- **Assume:** `ocorrencias` vem de `buscar` sobre o **mesmo** índice (ordenadas e
  sem sobreposição). `cor_todas`/`cor_atual` são hex aceitos por `[bgcolor]`
  (`#rrggbbaa`). A função não valida a cor.
- **Garante:** devolve **um texto interno por entrada** (o que fica dentro do
  envelope `[color]...[/color]` do Terminal), com o mesmo tamanho e a mesma ordem
  de `indice.entradas`:
  1. Uma entrada sem ocorrência que intercepte `[inicio, fim)` sai com o
     `texto` **idêntico** ao original.
  2. Uma entrada com ocorrência é reemitida token a token, com um deslocamento
     global `p` que começa em `inicio`:
     - `tag`: a `fonte` sai intacta;
     - `escape`: se `p` está dentro da ocorrência `k`, sai
       `"[bgcolor=" + C + "]" + fonte + "[/bgcolor]"`; senão, sai a `fonte`.
       Depois, `p += 1`;
     - `texto`: é cortado nas fronteiras das ocorrências. Cada pedaço tem todo
       `[` trocado por `[lb]` e, se cai dentro da ocorrência `k`, é envolvido em
       `"[bgcolor=" + C + "]" ... "[/bgcolor]"`. Depois, `p += pedaco.length()`.
     - `C` é `cor_atual` quando `k == atual`, senão `cor_todas`. Um `atual` fora
       do intervalo dá `cor_todas` para todas.
  3. **Nenhum `[bgcolor]` contém uma tag**, só um pedaço de texto ou um escape.
     Por isso a pilha de tags do motor nunca é cruzada, e um termo que atravessa
     `[/url]` sai em dois trechos realçados (AC5).
  4. Os caracteres `"\n"` de `nl` não pertencem ao texto de nenhuma entrada e não
     são realçados.
  5. `ocorrencias` vazio devolve os `texto` originais.
- **Formato fixado** (os testes dependem dele):
  `"[bgcolor=" + cor + "]" + trecho + "[/bgcolor]"`.

```gdscript
static func proxima(atual: int, total: int) -> int
static func anterior(atual: int, total: int) -> int
```

- **Quem chama:** `Terminal._navegar`. Os testes também chamam.
- **Garante:** com `total <= 0`, as duas devolvem `-1` (não há atual).
  - `proxima` = `(atual + 1) % total`; `atual = -1` dá `0`.
  - `anterior` = `(atual - 1 + total) % total`; `atual = -1` dá `total - 1`.
  - Exemplos: `proxima(2, 3) == 0`, `anterior(0, 3) == 2`,
    `proxima(0, 1) == 0`, `anterior(0, 1) == 0`.
- Escreva com `if ...: return`, sem `elif`/`else` depois de `return` (gdlint
  `no-elif-return`/`no-else-return`).

```gdscript
static func texto_visivel(texto_bbcode: String) -> String
```

- **Quem chama:** `indexar`, por entrada (a mesma tokenização, juntando os
  `visivel`). Os testes também chamam, nos AC3 e AC5.
- **Garante:** a concatenação dos `visivel` dos tokens de `texto_bbcode`, pela
  regra do tokenizador. `texto_visivel(realcar(...)[i]) == texto_visivel(texto_original)`
  para toda entrada `i` (AC5).

### `Terminal` (alterado; API pública intacta)

A API pública fica **exatamente** como está: `registrar_meta`, `text_edit`,
`titulo`, `secao`, `subsecao`, `item`, `linha`, `espaco` e `separador`, com as
mesmas assinaturas. Tudo o que é novo é privado.

**Cena (`Terminal.tscn`).** Os nomes `%` abaixo viram contrato dos testes de
fiação:

```
Terminal (ReferenceRect, script terminal.gd)                 ← inalterado
├── ColorRect                                                ← inalterado ($ColorRect)
├── Margem (MarginContainer, anchors full rect, margin_* = 5) ← substitui os offsets de 5 px do TextEdit
│   └── Coluna (VBoxContainer)
│       ├── FaixaBusca (HBoxContainer, %, visible = false)
│       │   ├── CampoBusca (LineEdit, %, SIZE_EXPAND_FILL, placeholder_text = "Buscar no terminal",
│       │   │               keep_editing_on_text_submit = true, clear_button_enabled = false)
│       │   ├── ContadorBusca (Label, %, custom_minimum_size.x = 64, horizontal_alignment = center, text = "")
│       │   ├── BotaoAnterior (Button, %, text = "↑", focus_mode = FOCUS_NONE, custom_minimum_size.x = 30)
│       │   ├── BotaoProxima (Button, %, text = "↓", focus_mode = FOCUS_NONE, custom_minimum_size.x = 30)
│       │   └── BotaoFechar (Button, %, text = "✕", focus_mode = FOCUS_NONE, custom_minimum_size.x = 30)
│       └── TextEdit (RichTextLabel, %, size_flags_vertical = EXPAND_FILL, focus_mode = 2,
│                     bbcode_enabled = true, selection_enabled = true)   ← mesmas propriedades de hoje
└── TimerBusca (Timer, %, one_shot = true, wait_time = 0.12)
```

- O `%TextEdit` continua com o mesmo nome único, então `$"%TextEdit"` não muda
  em lugar nenhum.
- Os botões levam `FOCUS_NONE` para o clique não tirar o foco do campo: o Enter
  continua funcionando depois de clicar em ↓. O `✕` segue o precedente de
  `painel_atribuicoes.gd:201`.
- **Nenhum `tooltip_text` na cena.** As dicas são vinculadas por código, com
  `DicaFlutuante`.
- Editar o `.tscn` à mão é seguro aqui (formato 3, sem `unique_id` nos nós do
  Terminal). Preserve o cabeçalho `[gd_scene ... uid="uid://hfr04nwubwo6"]` e a
  `ext_resource` do script.

**Constantes privadas** (topo de `terminal.gd`):

```gdscript
const _ALPHA_REALCE_TODAS: float = 0.25
const _ALPHA_REALCE_ATUAL: float = 0.6
const _LINHAS_CONTEXTO: int = 3
```

Os valores de alpha são o ponto de partida. O dev os ajusta no R2/R5 se o realce
ficar fraco ou atrapalhar a leitura, sem mudar o contrato.

**Estado privado:**

```gdscript
# Estado da busca (Ctrl+F). O índice é um retrato do buffer tirado ao abrir; qualquer escrita fecha a busca.
var _busca_aberta: bool = false
var _indice_busca: Dictionary = {}
var _ocorrencias: Array[Vector2i] = []
var _atual: int = -1
# Invalida rolagens adiadas (await) quando a busca muda ou fecha antes de o layout ficar pronto.
var _geracao_rolagem: int = 0
```

**Comportamento** (funções privadas; nomes sugeridos, só os comportamentos são
contrato):

- `_ready()`: mantém o que já faz e acrescenta:
  - liga `%TextEdit.gui_input`, `%CampoBusca.gui_input`,
    `%CampoBusca.text_changed`, `%TimerBusca.timeout` e o `pressed` dos três
    botões aos handlers;
  - `DicaFlutuante.vincular` nos três botões, com os textos da seção "Textos".
- `_on_text_edit_gui_input(event)`:
  - **Ctrl+F**: `InputEventKey`, `pressed`, `not echo`, `keycode == KEY_F`,
    `ctrl_pressed` e sem `shift`/`alt`/`meta`, a mesma forma do Ctrl+Z de
    `planejamentohorario.gd:1309`. Chama `$"%TextEdit".accept_event()` e
    `_abrir_busca()`.
  - **Esc** (sem `echo`) com a busca aberta: `accept_event()` e
    `_fechar_busca(true)`.
  - O resto passa adiante: Ctrl+C, Ctrl+A e a rolagem continuam do jeito de
    hoje. Como o sinal `gui_input` é emitido **antes** do `gui_input` interno do
    controle, aceitar o evento aqui impede o processamento padrão. O atalho só
    existe com o foco no `%TextEdit`. Não há `_unhandled_key_input` nem atalho
    global (non-goal).
- `_on_campo_busca_gui_input(event)`: sempre com `$"%CampoBusca".accept_event()`
  nos casos tratados.
  - **Enter/KP_Enter sem Shift** (aceita `echo`): `_navegar(true)`.
  - **Shift+Enter**: `_navegar(false)`.
  - **Esc**: `_fechar_busca(true)`.
  - **Ctrl+F**: `select_all()` no campo (reabrir com a faixa aberta).
  - Interceptar o Enter aqui garante que o `LineEdit` nunca o vê. O
    `keep_editing_on_text_submit` da cena é só uma defesa extra.
- `_on_campo_busca_text_changed(_t)`: `%TimerBusca.start()`. O timer reinicia a
  cada tecla, e a busca roda 0,12 s depois da última (o adiamento que o card
  aceita no edge case de desempenho).
- `_on_timer_busca_timeout()`: `_executar_busca()`.
- `_descarregar_busca_pendente()`: se o `%TimerBusca` não está parado, para o
  timer e chama `_executar_busca()`. Roda antes de toda navegação, para Enter
  logo depois de digitar valer sobre o termo novo.
- `_abrir_busca()`:
  - se ainda não está aberta: `_busca_aberta = true`,
    `_indice_busca = BuscaTerminal.indexar(_buffer)` e `%FaixaBusca.visible = true`;
    com o campo não vazio (reabertura), chama `_executar_busca()` **na hora**;
  - nos dois casos: `%CampoBusca.grab_focus()` e `%CampoBusca.select_all()`. Se a
    seleção não "pegar" depois do `grab_focus` (o `LineEdit` 4.4+ entra em
    edição), use `select_all.call_deferred()`.
  - O campo **não** é limpo ao fechar: reabrir traz o último termo selecionado, e
    digitar o substitui.
- `_executar_busca()`:
  - guarda se havia realce;
  - `_ocorrencias = BuscaTerminal.buscar(_indice_busca, %CampoBusca.text)`;
    `_atual = 0` se houver ocorrência, senão `-1`;
  - `_renderizar()` só se havia realce antes ou há agora;
  - `_atualizar_contador()`;
  - `_rolar_para_atual()` se `_atual >= 0`.
- `_navegar(para_frente: bool)`: `_descarregar_busca_pendente()`. Sem ocorrência,
  sai sem fazer nada (AC10: "Enter não faz nada"). Senão,
  `_atual = BuscaTerminal.proxima/anterior(_atual, _ocorrencias.size())`, depois
  `_renderizar()`, `_atualizar_contador()` e `_rolar_para_atual()`.
- `_fechar_busca(devolver_foco: bool)`:
  - se não está aberta, sai;
  - `_busca_aberta = false`, `%TimerBusca.stop()` e `_geracao_rolagem += 1`;
  - guarda se havia realce; zera `_ocorrencias`, `_atual = -1` e
    `_indice_busca = {}`;
  - se `devolver_foco`: `%TextEdit.grab_focus()` **antes** de esconder a faixa;
  - `%FaixaBusca.visible = false`;
  - `_renderizar()` se havia realce (com a rolagem preservada).
  - Esc e ✕ passam `true`. A mudança de conteúdo passa `false`: quem trocou o
    aluno está num seletor, e roubar o foco dele quebraria a roda do mouse e o
    teclado do seletor.
- `text_edit(...)`: a **primeira** instrução passa a ser
  `if _busca_aberta: _fechar_busca(false)`. Assim, o `get_text()` do acréscimo
  incremental nunca carrega o realce, e o índice nunca fica velho (AC13). O resto
  do corpo não muda, e todos os helpers (`titulo`, `item`...) passam por aqui.
- `_renderizar()`: hoje é chamado só na troca de tema.
  - se a busca está aberta e há ocorrências, `textos` recebe
    `BuscaTerminal.realcar(_indice_busca, _ocorrencias, _atual, cor_todas, cor_atual)`;
  - as cores vêm de `_cores_realce()`, **resolvidas na hora**, para a troca de
    tema já pintar com o tema novo (AC13);
  - se `textos.size() != _buffer.size()` (não deveria acontecer), renderiza sem
    realce;
  - monta o texto juntando `_segmento_bbcode(_buffer[i], textos[i] ou _buffer[i]["texto"])`
    (`PackedStringArray` + `"".join` é suficiente);
  - guarda `%TextEdit.get_v_scroll_bar().value` antes do `set_text` e o devolve
    logo depois. O realce não muda métricas, então o `max_value` não muda (AC12:
    "sem pular para o início nem para o fim"). **Consequência aceita:** a troca de
    tema também passa a preservar a rolagem.
- `_segmento_bbcode(entrada: Dictionary, texto: String) -> String`: o corpo de hoje
  fica igual, trocando `entrada["texto"]` pelo parâmetro `texto`. As duas
  chamadas (`text_edit` e `_renderizar`) passam o texto explicitamente.
- `_cores_realce() -> PackedStringArray`:
  - `base := PaletaSemantica.cor("selecao")`;
  - devolve `["#" + todas.to_html(true), "#" + atual.to_html(true)]`, onde `todas`
    e `atual` são `base` com `.a = _ALPHA_REALCE_TODAS` / `_ALPHA_REALCE_ATUAL`;
  - é o mesmo token nas duas, só a intensidade muda (non-goal: nenhuma cor nova).
- `_atualizar_contador()`: termo (`strip_edges`) vazio dá `""`; termo sem
  ocorrência dá `"0 de 0"`; senão, `"%d de %d" % [_atual + 1, _ocorrencias.size()]`.
- `_rolar_para_atual()` (corrotina, chamada sem `await`):
  1. `_geracao_rolagem += 1` e guarda a geração.
     `linha := %TextEdit.get_character_line(_ocorrencias[_atual].x)`.
  2. Se `linha < 0` (layout pendente): `await get_tree().process_frame`. Se a
     geração mudou ou a busca fechou, sai. Senão, tenta **uma** vez mais e, ainda
     com `-1`, sai em silêncio (sem `push_warning`).
  3. Com `v := %TextEdit.get_v_scroll_bar()`,
     `topo := get_line_offset(linha)` e `altura := get_line_height(linha)`: se
     `topo < v.value or topo + altura > v.value + v.page`, chama
     `scroll_to_line(maxi(linha - _LINHAS_CONTEXTO, 0))`. Se a linha já está
     visível, não rola, para não dar pulo.
- **Ordem de seções** (FORMATACAO.md §2, módulo de cena):
  1. constantes e variáveis;
  2. `_ready` e `_notification`;
  3. públicas (`registrar_meta`, `text_edit`, os helpers);
  4. privadas;
  5. `#region Sinais`, com **todos** os `_on_*`, inclusive os dois
     `_on_meta_hover_*` de hoje, que hoje ficam antes do `_notification` e são a
     violação congelada na baseline.

## Invariantes

1. **Dado pessoal não sai do PC.** O Terminal já mostra nomes de alunos, e a busca
   só repinta isso na tela. O termo vive no `LineEdit`, em memória, durante a
   sessão: não vai para `config_usuario.json`, `user://`, log, exportação nem rede.
   Nenhum `print`/`push_*` novo. Os testes usam só fixtures fictícias
   (`Maria da Silva Souza`, nomes de disciplina, códigos sintéticos). Nenhum
   arquivo novo na raiz, então o `exclude_filter` não muda. Não há smoke e não há
   captura de tela.
2. **snake_case interno, formatação só na UI.** As chaves do índice (`visivel`,
   `normalizado`, `entradas`, `inicio`, `fim`, `tokens`, `tipo`, `fonte`) e os
   valores de `tipo` (`texto`, `tag`, `escape`) são snake_case. Texto de
   apresentação (`"1 de 3"`, placeholder, dicas) só nasce no Terminal, na hora de
   pôr na UI.
3. **Cursos e chaves canônicas.** Não toca.
4. **Leitura de arquivo no main.** Nenhum `FileAccess`/`DirAccess` novo. O núcleo
   recebe o buffer por parâmetro, e o Terminal continua sem ler disco.
5. **UI pelas fachadas.** Dica = `DicaFlutuante.vincular`, sem `tooltip_text` na
   cena nem no script. Cor = `PaletaSemantica.cor("selecao")`, com alpha, sem hex
   hardcoded. Não há diálogo novo.

## Mapeamento AC → prova

Os ACs `headless` rodam com `python .tools/run_tests.py` (`-gselect=busca_terminal`
ou `-gselect=terminal_fiacao` para uma suíte só). Os nomes de teste abaixo são
contrato para a implementação. Quando um AC depende de uma pré-condição, o teste
a afirma antes, para não ser vácuo (ex.: "o índice tem 3 entradas", "a ocorrência
de fato cruza a fronteira").

Numeração: os ACs do card, na ordem em que aparecem.

| AC do card | Método | Onde |
|---|---|---|
| AC1: ignora maiúsculas e acentos (`calculo` acha `Cálculo` e `CÁLCULO`; `acao` acha `Ação`) | headless | `test_busca_terminal.gd::test_ignora_maiusculas_e_acentos` |
| AC2: ocorrências em ordem e sem sobreposição (`aa` em `aaaa` dá 2); termo vazio ou só espaços não acha nada | headless | `test_busca_terminal.gd::test_ocorrencias_em_ordem_sem_sobreposicao` e `::test_termo_vazio_ou_so_espacos_nao_acha_nada` |
| AC3: só o texto visível conta (não casa dentro de `[color=#ffcc00]`, `[url=chave]`, `[bgcolor=...]`) | headless | `test_busca_terminal.gd::test_nao_casa_dentro_de_tags` |
| AC4: ocorrência que atravessa duas entradas na mesma linha é achada e realçada nas duas partes | headless | `test_busca_terminal.gd::test_ocorrencia_atravessa_entradas_na_mesma_linha`. Contraprova: `::test_ocorrencia_nao_atravessa_quebra_de_linha` |
| AC5: realçar não altera o conteúdo, nem com tag no meio de uma ocorrência | headless | Núcleo: `test_busca_terminal.gd::test_realce_preserva_texto_visivel`. Motor: `::test_realce_preserva_texto_visivel_no_motor` (`RichTextLabel.get_parsed_text()` igual com e sem realce) |
| AC6: a atual tem realce próprio, e trocar a atual só move o realce forte | headless | `test_busca_terminal.gd::test_atual_tem_realce_proprio_e_troca_so_move_o_forte` |
| AC7: navegação circular; sem ocorrência não há atual | headless | `test_busca_terminal.gd::test_navegacao_circular` e `::test_sem_ocorrencias_nao_ha_atual` |
| AC8: os testes existentes seguem passando | headless | `python .tools/run_tests.py` (a suíte inteira, com as 7 suítes de hoje e as 2 novas) |
| AC9: clicar no Terminal e apertar Ctrl+F abre a faixa no topo com o campo focado, e o texto desce; Ctrl+F fora não abre; em 2 módulos | manual | Roteiro R1. Apoio: `test_terminal_fiacao_busca.gd::test_ctrl_f_com_foco_no_terminal_abre_faixa_e_foca_campo` e `::test_ctrl_f_com_foco_fora_nao_abre` |
| AC10: ao digitar, realça todas, a 1ª forte, rola até ela e mostra `1 de N`; sem ocorrência, zero, e Enter não faz nada | manual | Roteiro R2. Apoio: `::test_digitar_realca_e_contador_mostra_1_de_n` e `::test_sem_ocorrencias_contador_zero_e_enter_nao_faz_nada` |
| AC11: Enter e ↓ vão para a próxima, Shift+Enter e ↑ para a anterior, em ciclo, e a rolagem acompanha | manual | Roteiro R3. Apoio: `::test_enter_shift_enter_e_botoes_navegam_em_ciclo` |
| AC12: Esc ou ✕ fecham, removem o realce e devolvem o foco ao Terminal; a rolagem fica onde estava | manual | Roteiro R4. Apoio: `::test_esc_e_fechar_removem_realce_devolvem_foco_e_preservam_rolagem` |
| AC13: mudança de conteúdo fecha a faixa e remove o realce; trocar o tema não fecha e mantém o realce nas cores novas | manual | Roteiro R5. Apoio: `::test_mudanca_de_conteudo_fecha_busca` e `::test_troca_de_tema_mantem_busca_e_realce` |
| AC14: copiar (Ctrl+C) com realce ativo dá o mesmo texto que sem realce | manual | Roteiro R6. Apoio: `::test_copia_com_realce_igual_sem_realce` |
| AC15: os botões ↑ ↓ ✕ têm dica via `DicaFlutuante`, citando Shift+Enter, Enter e Esc | manual | Roteiro R7. Apoio: `::test_botoes_tem_dica_com_atalho` |
| AC16: o `MANUAL.md` (3.2, Terminal) descreve a busca e os atalhos | manual | Roteiro R8. O conteúdo exigido está na seção "Textos" |

**Leitura de "↓"/"↑" no AC11:** são os **botões** da faixa. É o que listam as
"Decisões do dev" e o AC15. As setas do teclado não são ligadas à navegação. Se o
dev quiser as setas também, é um ajuste de uma linha em
`_on_campo_busca_gui_input`, mas fora deste card.

### Cenários dos testes do núcleo (`test/unit/test_busca_terminal.gd`)

Helper local do teste: `_e(texto: String, nl: bool = true) -> Dictionary`, que
devolve `{"texto": texto, "token": "padrao", "efeito": "", "nl": nl, "bg": ""}`,
o formato de `_buffer`. `I(buf)` abrevia `BuscaTerminal.indexar(buf)` e
`B(buf, t)` abrevia `BuscaTerminal.buscar(I(buf), t)`. Cores de teste:
`TODAS := "#00000140"` e `ATUAL := "#00000280"`, hex fictícios que só servem para
distinguir os realces.

| Teste | Entrada | Esperado |
|---|---|---|
| AC1 | buffer `[_e("Cálculo Numérico", false), _e("CÁLCULO I"), _e("calculo"), _e("Ação Extensionista")]` | `B(buf, "calculo").size() == 3`; `B(buf, "CÁLCULO").size() == 3`; `B(buf, "cálculo").size() == 3`; `B(buf, "acao").size() == 1`; `B(buf, "AÇÃO").size() == 1`; e o `Vector2i` do `acao` cobre exatamente `"Ação"` (`visivel.substr(x, y - x) == "Ação"`) |
| AC2 (ordem) | `[_e("aaaa", false)]`; e `[_e("Cálculo I", false), _e("Cálculo II"), _e("Cálculo III")]` | `B(..., "aa") == [Vector2i(0, 2), Vector2i(2, 4)]`; no segundo, 3 ocorrências com `x` estritamente crescente e `y <= x` da seguinte |
| AC2 (vazio) | qualquer buffer não vazio | `B(buf, "")`, `B(buf, "   ")` e `B(buf, "\t")` devolvem `[]` |
| AC3 | `[_e("[color=#ffcc00]Cor[/color] e [url=chave]Dica[/url] e [bgcolor=#2e7d3280]Fundo[/bgcolor]", false)]` | `"ffcc00"`, `"color"`, `"chave"`, `"url"`, `"bgcolor"`, `"2e7d"` e `"[b"` dão `[]`; `"dica"`, `"cor"` e `"fundo"` dão uma ocorrência cada (`"cor"` acha só `Cor`, não `color`); pré-condição: `I(buf)["visivel"] == "Cor e Dica e Fundo"` |
| AC4 | `[_e("- Disciplina par"), _e("cial", false), _e("cial")]` | `B(buf, "parcial").size() == 1`; pré-condição: a ocorrência começa antes de `entradas[1].inicio` e termina depois dele; `realcar(I, oc, 0, TODAS, ATUAL)`: `[0]` termina com `"[bgcolor=#00000280]par[/bgcolor]"`, `[1] == "[bgcolor=#00000280]cial[/bgcolor]"` e `[2] == "cial"` (idêntico) |
| AC4 (contraprova) | `[_e("par", false), _e("cial")]` (a 2ª com `nl`) | `B(buf, "parcial") == []` |
| AC5 (núcleo) | `[_e("[url=chave]Cálc[/url]ulo [b]Numé[/b]rico", false), _e("Movido: AL0001 → [5, 3]."), _e("[lb]x[rb] fim [")]`; termos `"calculo numerico"`, `"[5, 3]"` e `"x] fim ["` | para cada termo, `oc := B(...)` não vazio (pré-condição); para todo `i`, `texto_visivel(realcar(I, oc, 0, TODAS, ATUAL)[i]) == texto_visivel(buf[i]["texto"])`; na 1ª entrada, o realce sai em 4 trechos (`Cálc`, `ulo `, `Numé`, `rico`), nenhum `[bgcolor]...[/bgcolor]` contém `[url`, `[/url]`, `[b]` ou `[/b]`, e, nas entradas **com** ocorrência, todo `[` literal sai como `[lb]` (com `"[5, 3]"`, a 2ª entrada; com `"x] fim ["`, a 3ª). As entradas sem ocorrência saem intactas, com o `[` cru |
| AC5 (motor) | lista `CASOS` (abaixo); para cada caso `c`, um buffer `[_e(c, false)]`, `L := texto_visivel(c).length()` e `oc := [Vector2i(0, L / 3), Vector2i(L / 2, L)]` montado à mão (é válido: ordenado e sem sobreposição) | com `rtl := autofree(RichTextLabel.new())`, `bbcode_enabled = true`: o `get_parsed_text()` de `"[color=#ffffff]" + c + "[/color]"` é igual ao de `"[color=#ffffff]" + realcar(I, oc, 0, TODAS, ATUAL)[0] + "[/color]"` |
| AC6 | `[_e("Cálculo e cálculo e CÁLCULO", false)]`, `oc := B(buf, "calculo")` (3) | `a := realcar(I, oc, 0, ...)[0]` e `b := realcar(I, oc, 1, ...)[0]`: cada um tem exatamente 1 `[bgcolor=#00000280]` e 2 `[bgcolor=#00000140]`; `a != b`; `a.replace(ATUAL, TODAS) == b.replace(ATUAL, TODAS)` (só o forte se moveu); em `b`, o 1º `#00000140` vem **antes** do `#00000280` |
| AC7 (ciclo) | — | `proxima(0, 3) == 1`, `proxima(2, 3) == 0`, `anterior(0, 3) == 2`, `anterior(2, 3) == 1`, `proxima(-1, 3) == 0`, `anterior(-1, 3) == 2`, `proxima(0, 1) == 0`, `anterior(0, 1) == 0` |
| AC7 (zero) | `[_e("Cálculo", false)]` | `B(buf, "zzz") == []`; `proxima(-1, 0) == -1`; `anterior(-1, 0) == -1`; `realcar(I, [], -1, TODAS, ATUAL) == ["Cálculo"]` |

`CASOS` (constante do teste) são as entradas reais e as armadilhas conferidas no
motor: `"Movido: AL0001 → [5, 3]."`, `"a [x b"`, `"a[lb]b[rb]c"`, `"a[br]b"`,
`"[b]neg[/b] [i]it[/i]"`, `"a [/b] b"`, `"x [ y ] z"`,
`"lista [\"al0001\", \"al0002\"]"`, `"vazio []fim"`,
`"[color=#00ff00]Ana Ficticia: Matriculado agora[/color] / [color=#0000ff]Bruno Ficticio: Matriculavel[/color]"`,
`"[bgcolor=#2e7d3280]Cálculo[/bgcolor]"`, `"a[unknown=1]b[/unknown]c"`,
`"a[B]b[/B]c"`, `"a[ b]c"`, `"a[url]u[/url]c"`,
`"[url=chave]Cálculo[/url] numérico"`, `"a[[b]x[/b]c"`, `"fim ["`, `"]so["`,
`"[shake rate=20.0 level=10]sh[/shake]"`, `"[font_size=20]fs[/font_size] [hint=dica]h[/hint]"`
e `"a]b"`. O caso patológico `"see [url= x y"` fica **fora** (ver "Riscos").

### Testes de apoio do núcleo (não são ACs; cobrem edge cases e o contrato)

| Edge case / contrato | Teste |
|---|---|
| O índice nunca desalinha | `test_normalizacao_preserva_comprimento`: com `s := "ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑáàâãäéèêëíìîïóòôõöúùûüçñ Aa"`, `GeneralFunctions.remover_acentos(s).length() == s.length()`; e `I(buf)["normalizado"].length() == I(buf)["visivel"].length()` para o buffer do AC1 |
| O tokenizador bate com o motor (é o que liga as posições a `get_character_line`) | `test_texto_visivel_igual_ao_do_motor`: para cada `c` em `CASOS`, `texto_visivel(c) == rtl.get_parsed_text()` de `"[color=#ffffff]" + c + "[/color]"` |
| `inicio`/`fim` e o `"\n"` de `nl` | `test_indice_mapeia_entradas_e_quebras`: `[_e("ab", false), _e("[b]cd[/b]"), _e("ef", false)]` dá `visivel == "ab\ncdef"`, `inicio/fim` `(0,2)`, `(3,5)`, `(5,7)` e `entradas.size() == 3` |
| Colchete literal continua igual depois do realce (edge case do card) | `test_colchete_literal_continua_igual_apos_realce`: `[_e("Movido: AL0001 → [5, 3].", false)]` com o termo `"5, 3"`: o realce contém `[lb]5`... e não `[5`, e o motor mostra `"Movido: AL0001 → [5, 3]."` com e sem realce |
| A entrada sem ocorrência sai idêntica | `test_entrada_sem_ocorrencia_sai_identica`: com 3 entradas e um termo só na 2ª, `realcar(...)[0]` e `[2]` são `==` ao `texto` original, incluindo as tags |
| Não muta o buffer | `test_nao_muta_buffer`: tira `buf.duplicate(true)` antes, roda `indexar`/`buscar`/`realcar` e compara com `assert_eq` |
| Buffer vazio | `test_buffer_vazio`: `I([])` dá `{"visivel": "", "normalizado": "", "entradas": []}`, e `buscar(I([]), "x") == []` |

### Testes de fiação (`test/unit/test_terminal_fiacao_busca.gd`)

Instancia a cena real
(`const _CENA: PackedScene = preload("res://scenes/Complementares/Terminal/Terminal.tscn")`,
`_CENA.instantiate()` e `add_child_autofree`), espera
`await wait_process_frames(2)` para o layout e escreve fixtures fictícias pela
**API pública** do Terminal (`titulo`, `item`, `linha`, `text_edit`). Os nós
internos são alcançados por `terminal.get_node("%Nome")`: um `get_node` com
receptor, que o guardrail aceita. As teclas vão por
`get_viewport().push_input(evento)` com o foco posto antes, o mesmo roteamento do
programa. Se o runner do GUT não rotear o `push_input` (passo 7 da ordem), emita
`gui_input` direto no controle focado e registre isso no `review.md`.

O helper `_digitar(t, termo)` faz `campo.text = termo`, depois
`campo.text_changed.emit(termo)`, e então `%TimerBusca.stop()` +
`%TimerBusca.timeout.emit()`. É determinístico e não espera os 0,12 s. "Tem
realce" é `%TextEdit.text.contains("[bgcolor=")`: as fixtures não usam `bg`.
Fixture base: `titulo("Relatório fictício", true)`, depois
`item("Cálculo Numérico — Maria da Silva Souza")`, `item("Ação Extensionista")`,
`item("CÁLCULO I")`, 60 vezes `linha("linha de enchimento %d" % i)`,
`item("Cálculo III")` e mais 60 linhas de enchimento. O `Cálculo III` fica no
**meio** do conteúdo, então rolar até ele não encosta no fim. Assim, esconder a
faixa (a área visível cresce) não obriga a barra de rolagem a recuar, e o teste
de rolagem do AC12 fica estável.

| Teste | Passos | Esperado |
|---|---|---|
| `test_texto_visivel_do_indice_igual_ao_do_terminal` | escreve a fixture e espelha no teste o buffer equivalente (mesmos `texto`/`nl`) | `BuscaTerminal.indexar(espelho)["visivel"] == %TextEdit.get_parsed_text()`: paridade com o envelope **real** do Terminal |
| `test_ctrl_f_com_foco_no_terminal_abre_faixa_e_foca_campo` (AC9) | guarda `%TextEdit.global_position.y`; `%TextEdit.grab_focus()`; `push_input(Ctrl+F)`; `await wait_process_frames(1)` | `%FaixaBusca.visible`; `%CampoBusca.has_focus()`; `%TextEdit.global_position.y` **maior** que antes (o texto desceu) |
| `test_ctrl_f_com_foco_fora_nao_abre` (AC9) | um `LineEdit` irmão (`add_child_autofree`) com o foco; `push_input(Ctrl+F)` | `not %FaixaBusca.visible` |
| `test_digitar_realca_e_contador_mostra_1_de_n` (AC10) | abre; `_digitar("calculo")` | tem realce; `%ContadorBusca.text == "1 de 3"` |
| `test_sem_ocorrencias_contador_zero_e_enter_nao_faz_nada` (AC10) | abre; `_digitar("zzzz")`; guarda `%TextEdit.text`; `push_input(Enter)` | `"0 de 0"` antes e depois do Enter; texto sem realce e inalterado; o campo continua focado |
| `test_enter_shift_enter_e_botoes_navegam_em_ciclo` (AC11) | abre; `_digitar("calculo")`; `Enter`, `Enter`, `Enter`, `Shift+Enter`, `Shift+Enter`; `%BotaoAnterior.pressed.emit()`; `%BotaoProxima.pressed.emit()` | contador em sequência: `2 de 3`, `3 de 3`, `1 de 3` (ciclo), `3 de 3` (ciclo para trás), `2 de 3`, `1 de 3`, `2 de 3`; o campo mantém o foco depois dos botões |
| `test_esc_e_fechar_removem_realce_devolvem_foco_e_preservam_rolagem` (AC12) | guarda `texto_sem_realce := %TextEdit.text`; abre; `_digitar("calculo iii")` (a última ocorrência força rolagem); `await wait_process_frames(1)`; guarda `v := get_v_scroll_bar().value` (pré-condição: `v > 0`); `push_input(Esc)`; `await wait_process_frames(1)`. Repete com `%BotaoFechar.pressed.emit()` | faixa oculta; `%TextEdit.text == texto_sem_realce`; `%TextEdit.has_focus()`; `get_v_scroll_bar().value == v` |
| `test_mudanca_de_conteudo_fecha_busca` (AC13) | abre; `_digitar("calculo")`; `terminal.linha("Linha nova escrita depois")` | faixa oculta; sem realce; `get_parsed_text().ends_with("Linha nova escrita depois")` |
| `test_troca_de_tema_mantem_busca_e_realce` (AC13) | abre; `_digitar("calculo")`; `terminal.notification(Control.NOTIFICATION_THEME_CHANGED)` | faixa visível; ainda tem realce; contador `1 de 3`. As cores do tema novo são conferidas no R5: o teste não muda o estado estático da `PaletaSemantica`, para não vazar para outros testes |
| `test_copia_com_realce_igual_sem_realce` (AC14) | `select_all()` + `get_selected_text()` sem busca; abre, `_digitar("calculo")`, e de novo | os dois textos são iguais, e iguais a `get_parsed_text()` |
| `test_botoes_tem_dica_com_atalho` (AC15) | — | `get_meta("dica_texto")` de `%BotaoAnterior` contém `"Shift+Enter"`; o de `%BotaoProxima` contém `"Enter"` e não `"Shift"`; o de `%BotaoFechar` contém `"Esc"` (a meta é gravada por `DicaFlutuante.vincular`) |
| `test_reabrir_traz_ultimo_termo_selecionado` (edge "Reabrir") | abre; `_digitar("calculo")`; Esc; `%TextEdit.grab_focus()`; Ctrl+F | `%CampoBusca.text == "calculo"`; `%CampoBusca.get_selected_text() == "calculo"`; tem realce; `1 de 3`. Com a faixa aberta e o foco no campo, mais um Ctrl+F mantém tudo e reseleciona |

## Riscos de contrato de dados

- **Nenhuma chave nova ou renomeada** em JSON de `arquivos/`, em `base_config.json`,
  em record do Kinto ou em formato de `dados/`. Nenhum arquivo é lido ou gravado.
- **Contrato interno novo:** `BuscaTerminal` lê `texto` e `nl` das entradas de
  `_buffer`. As duas chaves já existem e não mudam de significado. O comentário da
  linha 13 de `terminal.gd` passa a listar também `bg`, que já existe e hoje não
  aparece ali.
- **Constantes de aparência no Terminal, não em `base_config.json`.** O AGENTS.md
  manda constantes para o `base_config.json`, mas levá-las para lá exigiria que o
  main as injetasse no Terminal através dos nove módulos (non-goal: nenhum módulo
  muda) ou que o Terminal lesse configuração (proibido). Não são configuráveis
  pelo usuário: são aparência de um componente, como `_COR_*` em
  `seletor_horarios_liberados.gd` e `_ALVO_*` em `PaletaSemantica`.
- **Paridade com o motor (limitações aceitas, documentadas no `##` da classe):**
  - Um `[` sem `]` dentro da entrada, seguido de um nome de tag conhecido
    (`"see [url= x"`), é literal para o tokenizador. O motor, que enxerga o
    envelope, junta esse `[` com o `]` do `[/color]` do Terminal e esconde o resto
    da linha. É um defeito de renderização que **já existe** sem busca. Com
    realce, essa entrada passa a mostrar o texto todo. Nenhuma saída de hoje gera
    isso: os `[` literais são `[5, 3]` e listas `str(array)`, sempre fechados.
  - Tags com efeito visível próprio (`img`, `ul`/`ol`, `table`/`cell`, `hr`,
    `char`, `dropcap`) são reconhecidas, mas o caractere extra que o motor
    desenha (tab, marcador, glifo) não entra em `visivel`. Numa entrada com essas
    tags, a posição de rolagem pode ficar alguns caracteres deslocada. Nenhuma
    saída do Terminal usa essas tags (conferido por grep em `scenes/` e
    `standalone_scripts/`).
  - Um `[/tag]` solto que só fecharia o envelope (`[/color]` dentro do texto) é
    literal para o tokenizador e fecha a cor no motor. É patológico e não ocorre.
  - Acento em forma decomposta (NFD, `a` + U+0301) não é normalizado. Os textos
    do programa vêm em forma composta (NFC).
- **Desempenho:** realçar re-renderiza o Terminal inteiro. Um termo de uma letra
  num relatório de milhares de linhas custa até ~0,3 s (5000 linhas, ~6
  ocorrências por linha, medido no 4.7.2 headless). O timer de 0,12 s faz esse
  custo cair **depois** da pausa na digitação, não a cada tecla. O índice é
  montado uma vez por abertura, não por tecla. Ficam fora, de propósito: limite de
  ocorrências realçadas e tamanho mínimo de termo (o card pede "todas").
- **Mudança de comportamento aceita:** a troca de tema passa a preservar a
  rolagem do Terminal. O layout interno passa a usar `MarginContainer` com as
  mesmas margens de 5 px de hoje. O R1 confere a aparência nos módulos.
- **LGPD:** ver Invariante 1. A busca não cria saída nova, o termo não é
  persistido e nada vai para a rede.

## Textos

**Dicas** (`DicaFlutuante.vincular`, sentence case):

- `%BotaoAnterior`: `"Ocorrência anterior (Shift+Enter)"`
- `%BotaoProxima`: `"Próxima ocorrência (Enter)"`
- `%BotaoFechar`: `"Fechar a busca (Esc)"`

**Placeholder** do campo: `"Buscar no terminal"`. **Contador:** `""`, `"0 de 0"`
ou `"<i> de <n>"`.

**`MANUAL.md`, seção 3.2 (AC16).** Acrescentar depois do parágrafo atual, que não
muda:

```markdown
**Busca no terminal (Ctrl+F).** Clique no texto do terminal e pressione **Ctrl+F**: uma faixa de busca aparece no topo do terminal, empurrando o texto para baixo. Ao digitar, todas as ocorrências ficam realçadas, a atual com destaque mais forte, e o terminal rola até ela; o contador mostra a posição (ex.: `2 de 7`). A busca ignora maiúsculas e acentos (`calculo` encontra `Cálculo`) e considera só o texto exibido.

- **Enter** ou **↓**: próxima ocorrência; **Shift+Enter** ou **↑**: anterior. Ao passar da última, volta à primeira (e vice-versa).
- **Esc** ou **✕**: fecha a busca e remove o realce; a rolagem fica onde estava.
- **Ctrl+F** com a faixa aberta volta ao campo e seleciona o termo. Ao reabrir, o último termo já vem selecionado: basta digitar para substituí-lo.
- Se o conteúdo do terminal mudar (ex.: ao trocar de aluno), a busca fecha sozinha.
- O atalho só vale com o foco no terminal: Ctrl+F em outra parte do programa não faz nada. Copiar (Ctrl+C) com a busca aberta copia o mesmo texto de sempre.
```

O título da seção e o Sumário não mudam.

## Roteiros dos ACs manuais

Executados pelo dev, no programa rodando na máquina dele. **Nenhuma captura de
tela vai para o card:** Situação de Alunos mostra nomes reais. Os passos não
dependem de dado específico. Qualquer relatório com uma palavra repetida serve:
"Cálculo" aparece em quase toda grade de engenharia.

**R1 (AC9).**
1. Abrir **Situação de Alunos**, escolher um aluno e clicar no texto do
   terminal.
2. Apertar **Ctrl+F**. **Passa** se a faixa aparece no topo, ocupando a largura
   toda, se o cursor já está no campo (digitar escreve nele) e se o texto desce o
   equivalente à altura da faixa.
3. Esc. Clicar no **seletor de aluno** (fora do terminal) e apertar Ctrl+F.
   **Passa** se nada abre.
4. Repetir os passos 1–3 em **Planejamento de Oferta**, com o terminal de
   qualquer ação (ex.: **Ações › Carga horária › Verificar**).
5. Aparência, porque o layout interno mudou: abrir **Calculador de CR**,
   **Trancamentos**, **Exportadores**, **Situação de Disciplinas**, **Matrícula
   Irregular**, **LimeSurvey** e **Planejamento de Horário**. **Passa** se o texto
   do terminal tem a mesma margem de antes, o botão de mostrar/ocultar o terminal
   continua funcionando e as dicas `[url]` (Planejamento de Oferta) continuam
   aparecendo ao passar o mouse.

**R2 (AC10).**
1. Com um relatório que tenha "Cálculo" mais de uma vez, abrir a busca e digitar
   `calculo`. **Passa** se todas as ocorrências ficam com fundo leve, a primeira
   com fundo mais forte, a tela rola até ela (se estava fora da vista) e o
   contador mostra `1 de N`.
2. Apagar e digitar `zzzz`. **Passa** se o contador mostra `0 de 0`, nada fica
   realçado e Enter não muda nada.
3. Desempenho: no relatório mais longo à mão (ex.: Planejamento de Oferta ›
   **Sugerir oferta**, ou Exportadores › **Lista de componentes**), digitar uma
   letra só (`a`). **Passa** se a digitação não engasga. Uma pausa curta (menos de
   meio segundo) depois de parar de digitar é aceitável.
4. Legibilidade: se o realce estiver fraco demais ou atrapalhar a leitura,
   ajustar `_ALPHA_REALCE_TODAS`/`_ALPHA_REALCE_ATUAL` e repetir em um tema claro
   (**Mac Platinum**) e um escuro (**Nord**).

**R3 (AC11).** Com `calculo` e N ≥ 3: Enter (2 de N), Enter até `N de N`,
Enter (1 de N); Shift+Enter (N de N); botões ↓ e ↑ fazem o mesmo. **Passa** se o
fundo forte acompanha o contador e se a tela rola quando a ocorrência atual
estava fora da vista (e não rola quando já estava visível).

**R4 (AC12).** Rolar até o meio de um relatório longo, abrir a busca, ir para uma
ocorrência e apertar **Esc**. **Passa** se a faixa some, o realce some, o texto
não pula para o início nem para o fim e o foco volta ao terminal (Ctrl+F de novo
reabre na hora, com o termo selecionado). Repetir fechando pelo **✕**. Perto do
**fim** do texto, fechar pode fazer o texto descer até a altura da faixa: a área
visível cresce e não há mais o que rolar. Isso não é pulo.

**R5 (AC13).**
1. Situação de Alunos: abrir a busca, digitar `calculo` e **trocar de aluno** no
   seletor. **Passa** se a faixa fecha, o texto do aluno novo aparece sem realce
   e o seletor continua com o foco (a roda do mouse continua trocando de aluno).
2. Abrir a busca de novo, digitar `calculo` e, com a faixa aberta, trocar o
   **tema** (Configurações) de um escuro para um claro. **Passa** se a faixa
   continua aberta, o realce continua nas mesmas ocorrências, com as cores do
   tema novo (legível no tema claro), e o contador não muda.

**R6 (AC14).** Com o realce ativo, selecionar com o mouse um trecho que contenha
ocorrências, Ctrl+C, e colar num editor de texto. Fechar a busca, selecionar o
mesmo trecho, Ctrl+C, e colar logo abaixo. **Passa** se as duas colagens são
idênticas: sem tags e sem caractere a mais. Lembrete do card: re-renderizar
desfaz a seleção do mouse. Por isso, selecione **depois** de digitar o termo.

**R7 (AC15).** Passar o mouse em ↑, ↓ e ✕. **Passa** se aparece a
`DicaFlutuante` do programa (não o tooltip nativo), citando **Shift+Enter**,
**Enter** e **Esc**, respectivamente.

**R8 (AC16).**
1. `grep -n "Ctrl+F" MANUAL.md` acha o parágrafo novo na seção 3.2.
2. Abrir o manual pelo programa. **Passa** se o parágrafo e a lista aparecem
   formatados (o `MarkdownHtml` cobre negrito, código e lista) e se descrevem
   Ctrl+F, Enter, Shift+Enter, ↑/↓, Esc/✕, "ignora maiúsculas e acentos" e "fecha
   ao mudar o conteúdo".

## Smoke

Nenhum, como o card decide. A lógica é pura e testada headless. Os ACs visuais
dependem de teclado, foco e julgamento visual (legibilidade do realce), e por
isso são `manual`. Os testes de fiação cobrem a lógica de estado por trás deles.

## Ordem de implementação

Cada passo termina com `python .tools/run_tests.py` verde, exceto os passos 3 e
7, que são o vermelho do TDD.

1. **Leitura.**
   - `scenes/Complementares/Terminal/terminal.gd` e `Terminal.tscn` (inteiros);
   - `GeneralFunctions.remover_acentos` (`general_functions.gd:121-134`);
   - o cabeçalho de `markdown_html.gd`, modelo de classe estática pura em utils;
   - `DicaFlutuante.vincular` (`dica_flutuante.gd:36-52`, a meta `dica_texto`);
   - `planejamentohorario.gd:1309-1314`, a forma do teste de atalho.
2. **Esqueleto do núcleo.**
   - criar `standalone_scripts/utils/busca_terminal.gd`, com
     `class_name BuscaTerminal extends RefCounted`, docstring de classe `##`
     (incluindo as limitações de "Riscos"), as duas constantes e as seis
     assinaturas com `##`;
   - corpos triviais: `return {"visivel": "", "normalizado": "", "entradas": []}`,
     `return []`, `return []`, `return -1`, `return -1` e `return ""`;
   - rodar `"C:/Program Files/Godot/Godot_console.exe" --headless --path . --editor --quit`
     para registrar o `class_name` e gerar o `.uid`, que é versionado com o
     `.gd`. Suíte verde.
3. **Testes do núcleo (vermelho).**
   - escrever `test/unit/test_busca_terminal.gd` com `_e`, `CASOS`, os cenários e
     os testes de apoio;
   - conferir que falham **pelo motivo certo** (asserção, não erro de parse);
   - `test_buffer_vazio`, `test_termo_vazio_ou_so_espacos_nao_acha_nada` e o
     `proxima(-1, 0) == -1` já passam com o stub e entram como congelamento.
4. **Núcleo (verde).**
   - implementar o tokenizador (privado, com `find`, sem laço por caractere),
     `texto_visivel`, `indexar`, `buscar`, `realcar`, `proxima` e `anterior`,
     conforme o contrato;
   - sem `print`, sem `elif`/`else` depois de `return`;
   - a paridade com o motor (`test_texto_visivel_igual_ao_do_motor` e o AC5 no
     motor) fica verde aqui. Se algum caso de `CASOS` divergir, **corrija o
     tokenizador**, não o caso.
5. **Cena e refactor sem mudança de comportamento.**
   - reestruturar `Terminal.tscn` conforme a árvore do contrato, com a faixa
     oculta e o timer;
   - em `terminal.gd`, `_segmento_bbcode(entrada, texto)` e as duas chamadas;
     `_renderizar` com a rolagem preservada, ainda sem realce;
   - mover os `_on_meta_hover_*` para `#region Sinais`, no fim;
   - rodar o parser do Godot e a suíte, que devem ficar verdes;
   - escrever `test_texto_visivel_do_indice_igual_ao_do_terminal`, que deve
     passar.
6. **Catraca.**
   - `python .tools/guardrails.py` precisa estar limpo;
   - rodar `python .tools/guardrails.py --update-baseline`;
   - conferir no `git diff .tools/guardrails_baseline.json` que **só** a entrada
     `scenes/Complementares/Terminal/terminal.gd|section-order` saiu;
   - apertar é permitido; afrouxar, nunca. Se aparecer qualquer outra mudança,
     desfaça e investigue.
7. **Testes de fiação (vermelho).**
   - escrever `test/unit/test_terminal_fiacao_busca.gd`;
   - conferir logo de início, com o teste de Ctrl+F, que o `push_input` roteia no
     runner do GUT (se não rotear, use o fallback descrito na seção de fiação);
   - os testes falham porque a faixa nunca abre.
8. **Busca no Terminal (verde).**
   - estado, constantes, `_abrir_busca`, `_fechar_busca`, `_executar_busca`,
     `_navegar`, `_descarregar_busca_pendente`, `_atualizar_contador`,
     `_cores_realce`, `_rolar_para_atual`;
   - os handlers em `#region Sinais`, as ligações e dicas no `_ready`, e a
     primeira linha nova de `text_edit`;
   - nenhum `tooltip_text`, nenhum hex fixo.
9. **Manual.** Acrescentar o parágrafo da seção "Textos" ao `MANUAL.md` (3.2).
10. **Portões.**
    - `python .tools/guardrails.py`: os três arquivos novos nascem **sem**
      violação, e `terminal.gd` fica sem nenhuma;
    - `python .tools/run_tests.py`: a suíte inteira (AC8);
    - `"C:/Program Files/Godot/Godot_console.exe" --headless --path . --editor --quit`.
11. **ACs manuais.** Entregar os roteiros R1–R8 ao dev.
