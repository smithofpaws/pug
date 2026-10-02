# Handoff — 2026-10-02 14:45

## Onde parei
Card **0007** entrevistado, aprovado pelo dev e commitado como `ready`. Nada
foi implementado. O parágrafo sobre hooks × OneDrive, pendente desde
2026-08-31, foi escrito no `AGENTS.md`.

## Card ativo
Nenhum em execução. A fila tem **dois** `ready`, nesta ordem no índice:
**0005** (validação de coerência dos dados curriculares, nunca rodou) e
**0007** (aviso de turma sem correspondência no `horarios.txt`).

## Feito nesta sessão
Tudo commitado em `master`, **não pushado** (`ahead 2`):

- `262362f` — `AGENTS.md`, item "Setup por máquina": o OneDrive replica o
  `.git/hooks/`, mas não o lefthook nem o gdtoolkit; os dois pontos em que o
  portão deixa tudo passar sem avisar (hook sem `exit 1`; `run_gdlint` sem
  tratar módulo ausente); o teste de recusa. `Cards/README.md` passou a dizer
  "uma vez por máquina" e inclui o `winget install evilmartians.lefthook`.
- `8644e45` — card 0007. Decisão do dev: **não corrigir o casamento**, só
  avisar. Diálogo `Dialogos.escolha_lista` (1 botão, sem Cancelar) ao abrir a
  Situação de Alunos, listando disciplina, turmas e contagem de discentes.

## Pela metade / não verificado
- **Teste de recusa do pre-commit nesta máquina (`apex`): não rodado** — o dev
  negou a execução. Aqui lefthook e gdtoolkit estão instalados, o guardrails
  dá limpo com 374 toleradas (bate com a baseline) e a suíte passa; isso é
  indício, não prova. Os outros PCs seguem sem conferência.
- **O `hist.csv` mudou depois do 0006** (arquivo de 2026-09-14; o
  `horarios.txt` é de 2026-08-04). A contagem do 0007 (5 matrículas: AL0037
  `20/80` ×2, AL2126 `20` ×2, AL2129 `20` ×1) foi feita com esses arquivos.
- **Suspeita sem card:** os `avisos_leitura` do `hist.csv` impressos no
  `_ready` da Situação de Alunos (`situacao_alunos.gd:184`) são apagados pela
  primeira análise, que limpa o Terminal. Deduzido do código, **não visto na
  tela**. Anotado como observação lateral no card 0007.
- **Herança ainda aberta:** auditoria das atas de PPC; o PPC em Typst com a
  matriz antiga; `percentagem_curso` sem card; as 11 disciplinas só da
  `alec_2023`; `agc` vs `acg`.

## Estado dos portões
guardrails: ok (374 toleradas) · testes: ok · parser: não rodado nesta sessão
· pre-commit: dispara (pulou os portões nos dois commits porque não havia
`.gd` em staging), recusa **não provada** aqui. Rodados em 2026-10-02.

## Estado do git
`master`, 2 commits à frente de `origin/master` (mais o commit deste handoff,
se já feito). Working tree limpo fora isso.

## Decisões tomadas que não estão em card nenhum
- O número da turma no `horarios.txt` (Horarios.exe) e no GURI pode divergir
  para a mesma turma — nos 3 casos o docente é o mesmo. Se a origem é
  sistemática ficou **desconhecida** (resposta do dev: "não sei").

## Próximo passo concreto
Push dos commits (`! git push`). Depois, decidir a ordem da fila: rodar o
**0005** e depois o **0007**, ou só o 0007, com o workflow
`godot-feature-pipeline` (`args: {cardId}`).

## Em aberto para o dev
- Rodar o teste de recusa do pre-commit nesta máquina e nos outros dois PCs.
- Os avisos de leitura apagados viram card próprio?
