---
id: 0007-aviso-turma-sem-correspondencia-horarios
title: Aviso de turma do histórico sem correspondência no horarios.txt
status: ready
origin: novo (non-goal do card 0006; casos AL0037, AL2126 e AL2129 em 2026/2)
layers: [standalone_scripts/analise/analise_horarios.gd, scenes/Modulos/SituacaoAlunos]
interviewed: true
---

# 0007 - Aviso de turma do histórico sem correspondência no horarios.txt

## Goal
Ao abrir **Situação de Alunos**, se houver discente matriculado numa turma que
não casa com nenhuma turma daquela disciplina no `horarios.txt`, o programa
mostra **uma vez** um diálogo listando cada disciplina e turma afetadas, com o
número de discentes. Hoje essas matrículas caem em "Matriculável" na grade de
horários **em silêncio**, e o coordenador acha que o aluno não está matriculado.

## Contexto
O cruzamento entre o `hist.csv` (GURI: em qual turma o discente está) e o
`horarios.txt` (Horarios.exe: quando e onde a turma tem aula) é por código da
disciplina e número da turma. O 0006 resolveu o caso de número igual e letra
de subturma diferente. Este card trata o número **diferente**. Em 2026/2, das
551 matrículas, 5 não casam:

| Disciplina | Turma no `hist.csv` | Turmas no `horarios.txt` | Discentes |
|---|---|---|---|
| AL0037 | `20/80` | `T30;60`, `T90` | 2 |
| AL2126 | `20` | `T80` | 2 |
| AL2129 | `20` | `T80` | 1 |

Nos três casos o docente é o mesmo nas duas fontes, ou seja, é a mesma turma
numerada de forma diferente. Não se sabe se isso se repete todo semestre; por
isso o programa precisa deixar de falhar calado. **Corrigir** o casamento
(por docente ou por turma única) foi considerado e **descartado** pelo dev
neste card.

## Non-goals
- **Não muda o casamento.** Nada de fallback por docente nem por turma única.
  A grade continua mostrando essas aulas como "Matriculável" (o fallback de
  `extrair_horarios_txt` fica como está).
- **Não avisa disciplina matriculada sem nenhuma aula no `horarios.txt`.** É
  outro defeito (a disciplina some da grade), e hoje não ocorre (0 de 551).
- **Não avisa no relatório do aluno** (Terminal) nem no **relatório de
  choques** dos Exportadores, que usa o mesmo cruzamento e herda o rótulo
  errado.
- **Não lista discentes.** O diálogo mostra código, nome da disciplina, turmas e
  contagem; nada de nome ou matrícula de aluno.
- **Não cria StatusBar** na Situação de Alunos, nem token de cor novo.
- **Não altera formato** de nenhum arquivo de `arquivos/` ou `dados/`, nem lê
  arquivo novo.

## Acceptance criteria
Função pura nova em `AnaliseHorarios` (nome e assinatura definidos no design),
que recebe o `horarios_txt` e as matrículas com turma de todos os discentes e
devolve a lista de divergências agrupada por (disciplina, turma do histórico).

- [ ] Discente com turma `20` numa disciplina cujas únicas linhas no txt são `T80` gera **um** item com o código, a turma do histórico `20`, as turmas do txt `[T80]` e 1 discente -- verify: `headless`
- [ ] Turma composta `20/80` contra txt com `T30;60` e `T90` gera item com as **duas** turmas do txt -- verify: `headless`
- [ ] Não gera item quando a turma casa pela regra do 0006: `20A` × `T20`, `20` × `T20A`, e composta com uma parte que casa (`30/60` × `T30;60`) -- verify: `headless`
- [ ] Dois discentes na mesma disciplina e turma geram **um** item com contagem 2; linhas repetidas do mesmo discente (fan-out do GURI) não inflam a contagem -- verify: `headless`
- [ ] Na mesma disciplina, duas turmas do histórico divergentes (`20` e `40`, txt só `T80`) geram **dois** itens -- verify: `headless`
- [ ] Disciplina matriculada sem nenhuma linha no txt **não** gera item (non-goal) -- verify: `headless`
- [ ] Matrícula na condição `matriculado_agora_aproveitamento` é avaliada como a de `matriculado_agora` -- verify: `headless`
- [ ] Matrícula com turma vazia no histórico gera item (com turma vazia), sem crashar -- verify: `headless`
- [ ] `horarios_txt` vazio ou nenhum discente matriculado devolvem lista vazia -- verify: `headless`
- [ ] Os itens saem ordenados por código da disciplina e depois por turma do histórico -- verify: `headless`
- [ ] **Coerência com a grade:** em todos os cenários acima, uma matrícula entra num item **se e somente se** `extrair_horarios_txt` não põe nenhuma linha daquela disciplina na condição de matrícula do discente. Os dois caminhos usam o mesmo critério de casamento, sem cópia da regra -- verify: `headless`
- [ ] Os testes existentes em `test/unit/test_analise_horarios.gd` seguem passando -- verify: `headless`
- [ ] Com os dados reais de 2026/2, abrir Situação de Alunos mostra **um** diálogo (`Dialogos.escolha_lista`, lista rolável, **um** botão, **sem** Cancelar) com AL0037 `20/80` (2), AL2126 `20` (2) e AL2129 `20` (1), sem nome nem matrícula de discente -- verify: `manual`
- [ ] Trocar de aluno não reabre o diálogo; fechar e reabrir o módulo reabre -- verify: `manual`
- [ ] Com o `horarios.txt` ausente, o módulo abre sem diálogo e sem erro novo no log -- verify: `manual`
- [ ] O `MANUAL.md` (seção 4.3, Situação de Alunos) descreve o aviso: quando aparece, o que significa e que a correção é na numeração do `horarios.txt` -- verify: `manual`

## Edge cases
- **Quem entra na conta:** todos os discentes do `hist.csv` carregado, sem
  depender do filtro de curso do módulo. A divergência é do arquivo, não do
  curso selecionado.
- **Só matrícula atual:** a mesma regra de `matriculada_com_turma` (situação
  `matr*`), nas duas condições (`matriculado_agora` e
  `matriculado_agora_aproveitamento`).
- **Desempenho:** a conta roda para centenas de discentes na abertura do
  módulo. Indexar o `horarios_txt` por código de disciplina antes de comparar,
  para abrir o módulo não ficar perceptivelmente mais lento.
- **Diálogo no `_ready`:** abrir uma janela durante o `_ready` pode sair com
  tamanho errado. Se for o caso, adiar para o frame seguinte. Chamar depois da
  primeira análise, que limpa o Terminal mas não afeta o diálogo.
- **Turma do txt com e sem `T`, `;` contra `/`, caixa:** a normalização já
  existe em `_obter_turmas` e `_partir_turma`; o aviso mostra as turmas como
  estão nos arquivos (`20/80`, `T30;60`).
- **Turma vazia no histórico:** no diálogo, mostrar como "(sem turma)" em vez de
  string vazia.
- **Arquivo ausente:** sem `hist.csv` ou sem `horarios.txt`, não há diálogo nem
  crash. O programa abre "mudo", como hoje.

## Smoke scenarios
Nenhum. A lógica é pura e está na camada testável. Os ACs visuais são `manual`,
fechados pelo dev contra os dados reais, que **não** podem virar PNG (dado de
aluno), como no 0006.

## Observação lateral (fora do escopo)
Os `avisos_leitura` do cabeçalho do `hist.csv` são impressos no Terminal no
`_ready` (`situacao_alunos.gd:184`) **antes** da primeira análise, que limpa o
Terminal. Suspeita: eles são apagados antes de alguém ler. Não verificado na
tela.
