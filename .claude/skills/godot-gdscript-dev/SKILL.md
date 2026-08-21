---
name: godot-gdscript-dev
description: Implementa features em GDScript no PUG (Godot 4.7) sob TDD — teste primeiro, implementação mínima, refactor — com tipagem estática completa e comentários mínimos, seguindo FORMATACAO.md e AGENTS.md. Conhece o escopo real de TDD neste projeto (o que dá para testar headless com GUT e o que não dá, sem fabricar teste), a armadilha de falso positivo do --check-only e as regras de lugar que subagentes costumam errar (módulo não lê arquivo, tooltip é DicaFlutuante, cor é PaletaSemantica, turma do JSON é float). Use esta skill SEMPRE que for escrever, editar ou corrigir qualquer arquivo .gd deste projeto — inclusive num ajuste pequeno, porque as convenções deste repositório divergem do style guide oficial do Godot em pontos que o linter cobra.
---

# Implementação em GDScript — PUG

Escreve código a partir de uma spec (`Cards/<id>/spec.md`). Ciclo TDD, tipagem
total, comentário mínimo.

---

## Antes de escrever a primeira linha

Leia a spec e responda: **este código cai na camada testável?**

**Sim — escreva o teste antes:** `standalone_scripts/analise/*`,
`standalone_scripts/utils/*`, os parsers de `standalone_scripts/io/`
(EmentaParser; funções puras de FileHandling/ArquivosPlanejamento, com fixtures
fictícias em `test/fixtures/` ou `user://` temporário).

**Não — e não invente teste:** `scenes/Modulos/*`, `scenes/Complementares/*`,
`main.gd`, `barraprincipal.gd`, e os caminhos de rede vivos
(`sincronizacao*.gd`, `atualizador.gd` — a lógica pura deles, como comparação de
versão ou montagem de payload, é testável; a chamada HTTP não).

Um teste fabricado para a camada de UI custa mais do que não ter teste: ele passa
sempre e dá falsa confiança. Aqui a entrega é outra:

1. Extraia a lógica pura para uma classe/função de `standalone_scripts/` que
   receba o que precisa por parâmetro — o padrão das `Analise*`, que recebem
   histórico, grades e equivalências prontos do módulo. Essa função ganha teste.
2. O resto vira cenário de smoke ou roteiro manual no card.

**Fixtures são fictícias, sempre.** O repositório é público: nome de pessoa,
matrícula e e-mail em teste são inventados. Nunca copie um CSV real de `dados/`.

## O ciclo

```
teste vermelho → implementação mínima → verde → refactor → suíte inteira → parser
```

```bash
python .tools/run_tests.py                    # suíte GUT headless
python .tools/run_tests.py -gselect=grades    # só os testes que casam com "grades"
python .tools/guardrails.py <arquivo.gd>      # lint + regras do projeto
```

Testes ficam em `test/unit/`, prefixo `test_`, `extends GutTest`. Configuração em
`.gutconfig.json` — não repita as flags na linha de comando.

### Validar sintaxe: a armadilha

```bash
# CONFIÁVEL
"C:/Program Files/Godot/Godot_console.exe" --headless --path . --editor --quit

# FALSO POSITIVO — não use isolado
Godot_console.exe --headless --check-only --script arquivo.gd
```

O `--check-only` isolado acusa erro que não existe: autoloads não resolvem
(`Identifier not found: GV`) e ciclos de `preload` viram
`referenced non-existent resource`.

---

## O que o linter cobra e você não precisa memorizar

`python .tools/guardrails.py` roda a cada edição de `.gd` (hook `PostToolUse`) e no
`pre-commit`. Ele já verifica: tipagem estática completa, tabs, `##` só em membro
público, ordem de seções, `get_node()`, `preload().new()`, `FileAccess` fora do
main/FileHandling e `tooltip_text` fora da `DicaFlutuante`.

O código antigo carrega violações **congeladas numa baseline**
(`.tools/guardrails_baseline.json`, catraca por arquivo+regra): você não precisa
limpá-las para trabalhar, mas **não pode criar novas**. Se o hook reclamar,
corrija o que ele apontou. Não discuta com ele e não tente silenciá-lo editando
`gdlintrc` nem afrouxando a baseline.

## O que exige decisão sua — o linter não decide

### Divergências deliberadas do style guide oficial do Godot

O projeto diverge de propósito. **Não "corrija" para o padrão da comunidade:**

- **Constantes em `snake_case`** aceitas (FORMATACAO.md §5).
- **1 linha em branco entre funções**, não 2 (§11).
- **`class_name X extends Y` na linha 1**, na mesma linha (§1).
- **Quebra de linha longa com `\`**, mantendo o nível de indentação (§9).

### Ordem de seções — dois layouts

```gdscript
# Script standalone (Resource):
# 1. Classes instanciadas  2. Variáveis injetadas (##)  3. Variáveis privadas (#)
# 4. Funções públicas (##)  5. Funções privadas (#)

# Módulo de cena (extends ReferenceRect etc.):
# 1. Classes instanciadas  2. Variáveis injetadas  3. Variáveis privadas
# 4. Ciclo de vida (_ready, _process)  5. Funções privadas
# 6. #region Sinais — os _on_* SEMPRE por último
```

### Idioma e docstrings

- **Código e comentários em português brasileiro** — identificadores em
  snake_case sem acento; a exceção é `general_functions.gd` (comentários em
  inglês, utilitários genéricos).
- Strings visíveis na UI em sentence case ("Situação de alunos").
- `##` para membro público, com `[param]`, `[member]`, `[method]`, `[br]`.
- `#` para membro privado. **Nunca `##` em `_privado`.**

### Instanciação e acesso a nó

```gdscript
var file_handling := FileHandling.new()          # sim
var _h: Resource = preload("res://x.gd").new()   # não (§3)

$"%UniqueName"        # quando unique_name_in_owner = true
$"Caminho/Completo"   # com aspas, quando não tem unique name
get_node("X")         # não (§14) — mas outro_no.get_node("X") é legítimo
```

---

## Comentários mínimos

O código carrega a intenção; o comentário carrega o **porquê** que o código não
consegue dizer.

```gdscript
# ruído — reafirma a linha abaixo
# incrementa o contador
_contador += 1

# útil — explica uma decisão não óbvia
# O hist.csv do GURI repete a mesma linha varias vezes (fan-out da consulta);
# descartar duplicatas identicas preserva reprovacoes em semestres diferentes.
_remover_linhas_duplicadas(linhas)
```

`##` documenta o contrato público — o que a função garante e o que assume — não
como ela faz. `# TODO` e `# FIXME` vão na linha **anterior** ao código, sem
dois-pontos.

---

## Regras de lugar que subagentes erram

| Erro | Certo | Por quê |
|---|---|---|
| `FileAccess` num módulo | main.gd lê e injeta | Módulo recebe dado pronto (AGENTS.md); a allowlist do guardrail é congelamento, não convite |
| `tooltip_text` num Control | `DicaFlutuante` | Consistência visual única (AGENTS.md) |
| `Color.RED` / hex hardcoded | `PaletaSemantica.cor(token)` | Tema escuro/claro ajusta contraste em runtime (FORMATACAO.md §17) |
| `ConfirmationDialog.new()` ad-hoc | `Dialogos.confirmar/avisar/escolha_lista` | Par confirmar/cancelar só quando há decisão; `limitar_a_tela` sempre |
| Comparar turma por `str()` | `int()` dos dois lados | JSON carrega número como float (`40.0` ≠ `"40"`) |
| Buscar oferta por codigo+semestre | `chave_planejamento` | Ofertas da mesma disciplina só se distinguem pela chave única |
| Constante nova em `GV` | `base_config.json` | Globals só se extremamente necessário (AGENTS.md) |
| Rótulo formatado como chave de lógica | snake_case + par `_retorno` | Dado canônico separado da apresentação |
| Lambda escrevendo em variável local | escrever num membro (`self`) | Lambda captura local por cópia; `await` esperando a local vira loop infinito (AGENTS.md, Troubleshooting) |

## Antes de declarar pronto

1. `python .tools/run_tests.py` sai 0.
2. `python .tools/guardrails.py` sai 0.
3. `--headless --path . --editor --quit` sem erro de script.
4. Todo AC `headless` da spec tem teste correspondente que **falha** se a
   implementação for revertida.
5. Se adicionou função nova visível ao usuário: `MANUAL.md` atualizado
   (regra do AGENTS.md).
