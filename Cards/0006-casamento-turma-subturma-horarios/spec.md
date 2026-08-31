# Spec — 0006-casamento-turma-subturma-horarios

Card: `Cards/0006-casamento-turma-subturma-horarios/card.md`.

Objetivo: `AnaliseHorarios._comparar_turmas` deixa de comparar turma por
igualdade exata de string e passa a comparar **número + letra opcional**, com a
letra ausente de qualquer um dos lados casando com qualquer letra (regra
simétrica acordada no card). Consequência na tela: a aula teórica registrada no
`horarios.txt` como `T20` passa a casar com o discente que o `hist.csv` grava em
`20A`, e a disciplina sai de "Matriculável" para "Matriculada" na grade de
horários de Situação de Alunos.

## Camadas tocadas

| Arquivo | Por quê |
|---|---|
| `standalone_scripts/analise/analise_horarios.gd` | Única camada com mudança de comportamento. `_comparar_turmas` (hoje linha 267) troca a igualdade de string pela comparação número/letra e ganha o helper privado novo `_partir_turma`. **Nenhuma assinatura muda**, nenhuma função pública é tocada, `_obter_turmas` (linha 271) fica byte a byte igual — a propagação de letra em turma composta é non-goal explícito do card. Aproveita-se também a correção do bloco de comentário deslocado das linhas 262–266 (ver "Ordem de implementação", passo 4; comentário apenas). |
| `test/unit/test_analise_horarios.gd` | Suíte já existente de `AnaliseHorarios` (8 testes de ordenação de condições e de `determinar_horarios`). Ganha 11 testes novos: 7 de unidade em `_comparar_turmas` e 4 de integração em `extrair_horarios_txt`, todos com fixtures sintéticas inline. |

Fora do diff, e deliberadamente:

- **`scenes/main.gd`** — nenhuma leitura nova. `horarios_txt` e o histórico já
  são lidos e injetados; nada muda no comportamento com arquivo ausente.
- **`scenes/Modulos/SituacaoAlunos/*`** (inclusive `Complementos/horarios.gd`) —
  o módulo só renderiza a matriz que `determinar_horarios` devolve. Nenhuma
  mudança de UI, paleta ou ordenação de condições (non-goals do card).
- **`standalone_scripts/analise/analise_curricular.gd`** — `matriculada_com_turma`
  continua devolvendo `[cod_disciplina, cod_turma]` exatamente como hoje; a
  turma segue vindo crua do `hist.csv`, sem normalização a montante.
- **`base_config.json`, `arquivos/*`, `dados/*`** — nenhum formato, chave ou
  posição de coluna tocada.
- **`MANUAL.md`** — nenhuma função nova, removida ou renomeada na superfície do
  usuário. É correção de casamento de dado dentro de uma tela já documentada;
  não há regra de uso nova para descrever.

São duas camadas (núcleo de análise + teste), abaixo do limite de três.

## Contrato público novo ou alterado

**Nenhum contrato público muda.** As duas funções abaixo são privadas de
`AnaliseHorarios` (prefixo `_`, documentadas com `#` conforme FORMATACAO.md §4)
e ficam na seção de funções privadas do script standalone (FORMATACAO.md §2).

```gdscript
static func _comparar_turmas(turma_a: String, turma_b: String) -> bool
```

- **Assinatura idêntica à atual** — muda só a semântica. Segue `static`: o único
  chamador de produção invoca `AnaliseHorarios._comparar_turmas(...)` de dentro
  de `extrair_horarios_txt` (linha 240), e os testes chamam pela mesma via.
- **O que garante:** `true` quando os **números** das duas turmas são iguais **e**
  as letras são compatíveis — letras iguais, ou letra ausente em ao menos um dos
  lados. `false` quando qualquer um dos lados não tem número (string vazia, só
  espaço, ou só letra), inclusive quando **os dois** estão vazios. Simétrica
  (`f(a, b) == f(b, a)`), reflexiva apenas para turma com número, determinística.
  Pura: sem `FileAccess`, sem `GV`, sem nó, sem estado.
- **O que assume do chamador:** nada além de duas `String`. Continua tolerando o
  prefixo `T` do `horarios.txt` e caixa alta/baixa (normaliza internamente), de
  modo que serve tanto para a saída de `_obter_turmas` (já normalizada) quanto
  para texto cru — é o que o AC do `"t20"` × `"20A"` congela.
- **Não** trata separador composto (`/`, `;`): quem quebra `"30/60B"` em
  `["30b", "60b"]` continua sendo `_obter_turmas`, antes da chamada.

```gdscript
static func _partir_turma(turma: String) -> Dictionary
```

- **Novo.** Chamador único: `_comparar_turmas` (duas vezes por comparação).
  `static` porque `_comparar_turmas` é `static`.
- **Retorno:** `{"numero": String, "letras": String}` — chaves em snake_case,
  valores sempre `String` (nunca `null`), ambos possivelmente vazios. Normaliza
  com `strip_edges()`, `to_lower()` e a mesma remoção de `t` que `_obter_turmas`
  já faz; depois separa dígitos (→ `numero`) dos demais caracteres não-espaço
  (→ `letras`). `" "` → `{"numero": "", "letras": ""}`; `"a"` →
  `{"numero": "", "letras": "a"}`; `"20ab"` → `{"numero": "20", "letras": "ab"}`.
- **O que garante:** não crasha para entrada nenhuma; não é sensível à posição
  do dígito na string (varredura por caractere, não regex ancorada).
- **Limitação herdada e deliberada:** a letra `t` some na normalização
  (`replacen("t", "")`), como já acontecia. Nenhuma turma dos dados usa `T` como
  letra de subturma — `T` é o prefixo do `horarios.txt`. Mudar isso alteraria
  também `_obter_turmas`, e está fora do card.

Regra de dependência preservada: `AnaliseHorarios` continua recebendo tudo por
parâmetro, sem conhecer nó, arquivo ou módulo de cena.

## Invariantes

| Invariante | Como esta feature se comporta |
|---|---|
| **1. Dado pessoal não sai do PC** | Não toca. Nenhum arquivo novo, nenhuma exportação, nenhuma rede, nenhum `print`. As fixtures dos testes são sintéticas: códigos de disciplina (`al0376`, `al0003` — dado curricular público, não pessoal), turmas e a matrícula fictícia `"aluno ficticio"`, no mesmo molde dos 8 testes já existentes. Nenhum PNG de smoke. O AC `manual` roda contra `dados/` reais na máquina do dev e **não** produz artefato versionado. Nenhum arquivo novo na raiz do projeto → nada a acrescentar no `exclude_filter` dos presets. |
| **2. snake_case interno, formatação só na UI** | Chaves novas só existem no retorno de `_partir_turma`: `numero` e `letras` — minúsculas, sem acento, sem espaço. A comparação trabalha em minúsculas; a apresentação da turma na célula (`analise_horarios.gd:393`, `.to_upper()`) fica intacta. |
| **3. Cursos e chaves canônicas** | Não toca. Nenhuma chave de grade, equivalência ou curso é lida ou escrita; nenhuma lista de cursos nova. |
| **4. Leitura no main/FileHandling; módulo recebe injetado** | Preservada por omissão: nenhuma leitura nova. `_comparar_turmas` e `_partir_turma` são estáticas e puras; o guardrail `filesystem-boundary` continua sem nada a acusar em `analise_horarios.gd`. Com `horarios.txt` ausente, `horarios_txt` chega vazio e o laço simplesmente não roda — igual a hoje. |
| **5. UI pelas fachadas** | Não toca. Nenhum tooltip, diálogo, cor ou `chave_planejamento` envolvido. |

## Mapeamento AC → prova

Todos os ACs `headless` rodam por `python .tools/run_tests.py`
(`-gselect=horarios` para só esta suíte). Os nomes de teste abaixo são contrato
para a fase de implementação.

| AC do card | Método | Onde |
|---|---|---|
| AC1 — `_comparar_turmas("20", "20a")` → `true` (letra de um lado só) | headless | `test/unit/test_analise_horarios.gd::test_comparar_turmas_letra_de_um_lado_casa` |
| AC2 — `_comparar_turmas("20a", "20")` → `true` (simetria) | headless | `test/unit/test_analise_horarios.gd::test_comparar_turmas_e_simetrica` |
| AC3 — `_comparar_turmas("20a", "20b")` → `false` (letras distintas) | headless | `test/unit/test_analise_horarios.gd::test_comparar_turmas_letras_distintas_nao_casam` |
| AC4 — `("20a","20a")` e `("20","20")` → `true` | headless | `test/unit/test_analise_horarios.gd::test_comparar_turmas_identicas_casam` |
| AC5 — `("20","80")` e `("20a","80a")` → `false` (número manda) | headless | `test/unit/test_analise_horarios.gd::test_comparar_turmas_numero_diferente_nao_casa` |
| AC6 — `("t20","20A")` → `true` (prefixo `T` e caixa irrelevantes) | headless | `test/unit/test_analise_horarios.gd::test_comparar_turmas_ignora_prefixo_t_e_caixa` |
| AC7 — turma vazia ou só espaço não casa com nada, inclusive com outra vazia | headless | `test/unit/test_analise_horarios.gd::test_comparar_turmas_sem_numero_nao_casa_com_nada` |
| AC8 — caso `al0376`: hist `20A` × única linha `T20` → `matriculado_agora` e ausente de `matriculavel` | headless | `test/unit/test_analise_horarios.gd::test_extrair_horarios_txt_teorica_sem_letra_casa_com_subturma` |
| AC9 — caso `al0003`: `T20` e `T20A` → `matriculado_agora`; `T20B` → `matriculavel` | headless | `test/unit/test_analise_horarios.gd::test_extrair_horarios_txt_separa_subturma_do_grupo_errado` |
| AC10 — turma composta com letra propagada: hist `30/60B` casa com `T30;60` | headless | `test/unit/test_analise_horarios.gd::test_extrair_horarios_txt_turma_composta_com_letra_propagada` |
| AC11 — não-regressão do non-goal: hist `20` × única linha `T80` → só `matriculavel` | headless | `test/unit/test_analise_horarios.gd::test_extrair_horarios_txt_turma_ausente_no_txt_continua_matriculavel` |
| AC12 — os 8 testes já existentes seguem passando | headless | `python .tools/run_tests.py` verde; os 8 testes de `test/unit/test_analise_horarios.gd` (4 de `ordenar_condicoes` + 4 de `determinar_horarios`) permanecem sem edição |
| AC13 — com dados reais de 2026/2, matrícula em `al0376` (turma `20A`) aparece **Matriculada** | manual | roteiro em "Roteiro do AC manual", abaixo — executado pelo dev; **sem** captura de tela (dado de aluno) |

### Fixtures dos ACs de integração (formato)

`extrair_horarios_txt(horarios_txt, matriculada_com_turma, disc_cursaveis)` é
pura e recebe tudo por parâmetro — os testes montam os três argumentos inline,
sem passar por `AnaliseHistorico` nem por disco:

- `horarios_txt`: array de linhas no formato de `horarios_exe.carregar_horarios_txt`,
  com `disciplina` no formato `"Nome Ficticio (al0376)"` (é de lá que
  `extrair_cod_horarios_txt` tira o código) e `turma` como no txt (`"T20"`).
  Sem campo `professor` — como já fazem os testes existentes.
- `matriculada_com_turma`: `{"matriculado_agora": [["al0376", "20A"]], "matriculado_agora_aproveitamento": []}`.
  O código precisa bater **exatamente** (comparação por `==`, minúsculo dos dois
  lados); a turma vem crua, como o `hist.csv` a entrega.
- `disc_cursaveis`: precisa conter as chaves `"matriculado_agora"` **e**
  `"matriculavel"` — a primeira porque `matriculada_com_turma` escreve nela, a
  segunda porque é o destino do fallback deliberado. `"matriculavel": []` (vazia)
  evita que o segundo laço da função adicione a linha por outro caminho e
  confunda a asserção.

## Riscos de contrato de dados

- **Nenhuma chave renomeada, nenhuma chave nova em arquivo.** Nada é gravado.
  `numero`/`letras` vivem só em memória, num dicionário de retorno de função
  privada. `base_config.json`, os JSONs de `arquivos/`, os records do Kinto e os
  formatos de `dados/` (hist.csv, horarios.txt) ficam intocados — em particular,
  as posições de coluna de `base_config.json:histfile` (`codturma: 20`).
- **Tipo da turma.** `codturma` vem do `hist.csv` e chega como `String`; a turma
  do `horarios.txt` idem. A armadilha conhecida do projeto (número de JSON
  carregando como `float`, `40` virando `40.0`) **não** se aplica aqui, porque
  nenhuma das duas fontes é JSON. Ainda assim, a comparação de números é
  **textual** (`"20" == "20"`), não numérica: turma com zero à esquerda (`"020"`)
  não casaria com `"20"`. Não ocorre nos dados e não é regressão (hoje também não
  casa); registrado para não virar surpresa.
- **Mudança de comportamento aceita (AC7).** Hoje `_comparar_turmas("", "")`
  devolve `true`; depois devolverá `false`. Efeito prático: se um discente tiver
  turma vazia no histórico **e** houver linha do txt com turma vazia para a mesma
  disciplina, essa linha migra de `matriculado_agora` para `matriculavel`. É
  exatamente o que o card pede (a linha de cabeçalho do txt não pode casar com
  todo mundo) e hoje é inofensivo porque o cabeçalho não tem código de
  disciplina — mas a regra passa a não depender disso.
- **Alargamento do casamento (regra simétrica).** Discente registrado só em `20`
  numa disciplina com práticas `A` e `B` passa a aparecer matriculado nas duas.
  É a consequência assumida no card, verificada como inexistente em 2026/2. O
  AC11 congela o limite oposto: número diferente continua não casando.
- **LGPD.** A feature não introduz superfície nova. Turma e código de disciplina
  não são dado pessoal; o dado pessoal (nome/matrícula) já circula por
  `historico_matricula` e continua morrendo na tela, sem log, sem exportação e
  sem rede. Nada real entra em teste, fixture ou card.

## Roteiro do AC manual (AC13)

Executado pelo dev, na máquina com os dados reais. **Sem screenshot** — a tela
mostra nome de aluno.

1. `dados/` com o `hist.csv` e o `horarios.txt` de 2026/2 já em uso.
2. Abrir o programa → **Situação de Alunos** → selecionar uma matrícula que
   esteja em `al0376`, turma `20A`.
3. Na **grade de horários**, localizar `AL0376`.
4. **Passa** se ela aparecer com a cor/condição de **Matriculada**
   (`matriculado_agora`) e **não** com a de Matriculável.
5. Conferir de passagem, no mesmo aluno ou noutro, que `al0003`/`al0366`/`al0021`
   mostram a teórica junto da prática — e que a prática do **outro** grupo
   (`T20B` para quem é `20A`) continua em Matriculável, cinza, como opção.
6. Verificar que nada regrediu numa disciplina cuja turma do histórico não existe
   no txt (`al0037`): continua Matriculável, conforme o non-goal.

## Ordem de implementação

Cada passo termina com `python .tools/run_tests.py` verde (exceto o passo 2, que
é o vermelho do TDD).

1. **Leitura do código atual.** Reler `extrair_horarios_txt` (linhas 226–259),
   `_comparar_turmas` (267–268) e `_obter_turmas` (271–297) para confirmar que o
   único chamador de `_comparar_turmas` é o da linha 240.
2. **Testes primeiro (vermelho).** Acrescentar em
   `test/unit/test_analise_horarios.gd` os 11 testes da tabela AC→prova, na
   ordem: os 7 de `_comparar_turmas`, depois os 4 de `extrair_horarios_txt`.
   Rodar e conferir que falham **pelo motivo certo** (AC1, AC2, AC6, AC7, AC8,
   AC9 e AC10 falham; AC3, AC4, AC5 e AC11 já passam com o código atual e entram
   como testes de congelamento).
3. **Implementação mínima (verde).** Escrever `_partir_turma` e reescrever o
   corpo de `_comparar_turmas` conforme o contrato acima. Nada mais.
4. **Documentação in loco (só comentário).** Corrigir o bloco das linhas 262–266:
   as duas linhas "Determina qual a(s) turma(s)…" pertencem a `_obter_turmas` e
   hoje estão coladas acima de `_comparar_turmas`. Devolvê-las ao lugar e
   escrever o `#` de `_comparar_turmas` explicando a regra número+letra e a
   simetria, mais o `#` de `_partir_turma`. Manter `#` (nunca `##`) — os dois
   membros são privados (guardrail `private-docstring`).
5. **Portões.** `python .tools/guardrails.py` (a catraca do
   `analise_horarios.gd` está em 13 `trailing-whitespace`, 1 `static-typing` e
   1 `max-line-length`: o código novo precisa ser totalmente tipado, com tabs e
   sem espaço em branco no fim da linha, para não somar violação nova) e
   `"C:/Program Files/Godot/Godot_console.exe" --headless --path . --editor --quit`.
6. **AC manual.** Entregar o roteiro acima ao dev.
