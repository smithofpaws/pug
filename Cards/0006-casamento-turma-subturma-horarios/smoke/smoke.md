# Smoke — 0006-casamento-turma-subturma-horarios

Executado em 2026-08-31. Godot 4.7.2, GL Compatibility.
MCP `godot` indisponível nesta sessão (`CONNECTION_CLOSED`) — degradado para CLI
pura (headless), conforme a skill prevê. Não houve captura de PNG: o card
declara explicitamente em "Smoke scenarios" que não há cenário visual
automatizável (`AnaliseHorarios` é lógica pura, sem UI tocada) e o único AC de
tela (AC13) é `manual`, com captura proibida por LGPD.

Ambiente de dados: `dados/` **não está vazio** nesta máquina — contém
`hist.csv`, `email.csv`, `horarios.txt` e `preferenciashorarios/*.csv` com
nomes reais de docentes. Isso não bloqueia os ACs `headless` (todos usam
fixtures inline em `test/unit/test_analise_horarios.gd`, sem tocar disco), mas
**impede** qualquer captura de tela do módulo Situação de Alunos nesta sessão —
por isso o AC13 não pode virar PNG, só roteiro para o dev rodar na própria
máquina e conferir com os olhos.

## ACs

| AC | Método | Cenário | Evidência | Veredito |
|---|---|---|---|---|
| AC1 | headless | `_comparar_turmas("20","20a")` → `true` | `test_comparar_turmas_letra_de_um_lado_casa` | passou |
| AC2 | headless | `_comparar_turmas("20a","20")` → `true` (simetria) | `test_comparar_turmas_e_simetrica` | passou |
| AC3 | headless | `_comparar_turmas("20a","20b")` → `false` | `test_comparar_turmas_letras_distintas_nao_casam` | passou |
| AC4 | headless | `("20a","20a")` e `("20","20")` → `true` | `test_comparar_turmas_identicas_casam` | passou |
| AC5 | headless | `("20","80")` e `("20a","80a")` → `false` | `test_comparar_turmas_numero_diferente_nao_casa` | passou |
| AC6 | headless | `("t20","20A")` → `true` (prefixo T / caixa) | `test_comparar_turmas_ignora_prefixo_t_e_caixa` | passou |
| AC7 | headless | turma vazia/espaço não casa com nada, nem com outra vazia | `test_comparar_turmas_sem_numero_nao_casa_com_nada` | passou |
| AC8 | headless | caso `al0376`: hist `20A` × txt só `T20` → `matriculado_agora`, ausente de `matriculavel` | `test_extrair_horarios_txt_teorica_sem_letra_casa_com_subturma` | passou |
| AC9 | headless | caso `al0003`: `T20`+`T20A` → `matriculado_agora`; `T20B` → `matriculavel` | `test_extrair_horarios_txt_separa_subturma_do_grupo_errado` | passou |
| AC10 | headless | turma composta `30/60B` casa com `T30;60` | `test_extrair_horarios_txt_turma_composta_com_letra_propagada` | passou |
| AC11 | headless | non-goal: hist `20` × txt só `T80` continua só `matriculavel` | `test_extrair_horarios_txt_turma_ausente_no_txt_continua_matriculavel` | passou |
| AC12 | headless | os 8 testes já existentes de `test_analise_horarios.gd` seguem passando | suíte completa: 19/19 (8 antigos + 11 novos) | passou |
| AC13 | manual | `al0376` turma `20A` aparece Matriculada com `dados/` reais de 2026/2 | roteiro abaixo — **sem captura** (dado de aluno) | não verificado |

## Log

Comandos rodados (saída completa nos comandos da sessão, não anexada por não
conter dado pessoal):

- `python .tools/run_tests.py -gselect=horarios` → **19/19 passed**, 0 erros.
- `python .tools/run_tests.py` (suíte completa) → **52/52 passed** em 4
  scripts, 0 erros.
- `python .tools/guardrails.py` → `limpo (108 violacao(oes) pre-existentes
  toleradas pela baseline)` — nenhuma violação nova no diff (`analise_horarios.gd`
  e o arquivo de teste).
- `"C:/Program Files/Godot/Godot_console.exe" --headless --path . --editor --quit`
  → completou os 2 estágios (`first_scan_filesystem`, `loading_editor_layout`)
  sem `SCRIPT ERROR`, `Parse Error`, `push_error` nem `push_warning`.

Baseline: não foi possível isolar por `git stash` (comando bloqueado por
permissão nesta sessão). Não é regressão de risco aqui: a mudança está contida
em `standalone_scripts/analise/analise_horarios.gd`, uma camada pura sem
`FileAccess`/nó/UI (ver spec, invariante 4), então o parser do editor e a
suíte GUT já são a superfície inteira capaz de emitir erro/aviso para este
diff — e ambos vieram limpos. Nenhum aviso pré-existente relevante ao arquivo
tocado apareceu no `--editor --quit`.

## LGPD

Nenhum PNG foi gerado nesta sessão — não há imagem para conferir. Os testes
`headless` usam apenas fixtures sintéticas já presentes no arquivo de teste
(`al0376`, `al0003`, `al0055`, `al0037` — códigos de disciplina, dado curricular
público; `"aluno ficticio"` como nome fictício, no molde dos 8 testes
pré-existentes). `dados/` real na máquina não foi lido por nenhum comando desta
sessão.

## Não foi possível verificar

- **AC13** exige selecionar uma matrícula real na tela de Situação de Alunos e
  olhar a cor da célula — interação de mouse, sem harness de input neste
  projeto, e a tela expõe nome de aluno (não pode virar PNG versionado).
  **Roteiro para o dev** (idêntico ao da spec, "Roteiro do AC manual"):
  1. Com `dados/hist.csv` e `dados/horarios.txt` de 2026/2 (já presentes nesta
     máquina).
  2. Abrir o programa → **Situação de Alunos** → selecionar uma matrícula que
     esteja em `al0376`, turma `20A`.
  3. Na grade de horários, localizar `AL0376`.
  4. **Passa** se aparecer com a cor/condição de **Matriculada**
     (`matriculado_agora`) e não com a de Matriculável.
  5. Conferir de passagem que `al0003`/`al0366`/`al0021` mostram a teórica
     junto da prática, e que a prática do **outro** grupo (`T20B` para quem é
     `20A`) continua em Matriculável, cinza.
  6. Verificar que `al0037` (turma do histórico ausente no txt) continua só
     Matriculável — non-goal preservado.
