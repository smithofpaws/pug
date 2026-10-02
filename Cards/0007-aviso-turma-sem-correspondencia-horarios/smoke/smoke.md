# Smoke — 0007-aviso-turma-sem-correspondencia-horarios

Executado em 2026-10-02. Godot 4.7, GL Compatibility.
Ambiente de dados: nenhuma captura de tela foi feita. O boot foi rodado em modo
headless e so o log foi inspecionado (filtrado por ERROR/WARNING/SCRIPT ERROR/Parse Error).

Todos os ACs visuais do card (AC13 a AC16) sao `manual`: exigem os dados reais de
2026/2 (nome de aluno atras do dialogo) e interacao (abrir o modulo, trocar de aluno).
Nao ha harness de input e PNG com dado de aluno e proibido. Por isso nao ha PNG.

| AC | Metodo | Cenario | Evidencia | Veredito |
|---|---|---|---|---|
| AC13 | manual | Dialogo unico com AL0037/AL2126/AL2129 | roteiro R1 | nao verificado |
| AC14 | manual | Trocar aluno nao reabre; reabrir modulo reabre | roteiro R2 | nao verificado |
| AC15 | manual | horarios.txt ausente: sem dialogo, sem erro novo | roteiro R3 | nao verificado |
| AC16 | manual | MANUAL.md 4.3 descreve o aviso | roteiro R4 | nao verificado |

## Log
Boot headless (`--headless --quit-after 60`), exit 0, 103 linhas.
0 ERROR, 0 SCRIPT ERROR, 0 Parse Error.
Avisos (todos de validacao de dados no carregamento, do card 0005, ja em HEAD e
sem relacao com `analise_horarios.gd` / `situacao_alunos.gd`):
- base_config.json: 2 de tipo int/float em `interface.tamanho_janela`, 3 de tipo em `delimitadores`.
- grades alec_2010 e alec_2023: 8 de prerequisito apontando para codigo inexistente na grade.
Nenhum aviso menciona turma, horarios ou Situacao de Alunos.
Limite: o baseline nao foi capturado em separado (arvore de trabalho com mudancas
nao commitadas; nao se usou stash). A comparacao e por origem dos avisos. O modulo
Situacao de Alunos nao e aberto no boot, entao o novo codigo de UI nao e exercitado aqui.

## LGPD
Nenhum PNG gerado. A saida do log nao foi versionada.

## Nao foi possivel verificar
Roteiros (executar o dev, sem captura de tela):
- R1 (AC13): com hist.csv e horarios.txt de 2026/2 em `dados/`, abrir Situacao de
  Alunos. Passa se aparecer exatamente um dialogo "Turmas sem correspondencia no
  horarios.txt", com so o botao OK (sem Cancelar), lista rolavel e tres linhas na
  ordem AL0037 20/80 -> T30;60, T90 (2); AL2126 20 -> T80 (2); AL2129 20 -> T80 (1),
  sem nome nem matricula de aluno.
- R2 (AC14): trocar de aluno 3 vezes e de curso 1 vez: nenhum dialogo novo. Ir a
  outro modulo e voltar: o dialogo reabre uma vez.
- R3 (AC15): renomear temporariamente `dados/horarios.txt`, abrir o programa com
  console e entrar em Situacao de Alunos: sem dialogo e sem linha nova no log (o
  CRITICO de arquivo ausente ja existia). Restaurar o nome.
- R4 (AC16): ler MANUAL.md 4.3 e conferir os cinco pontos (quando aparece, o que
  significa, o que mostra, como corrigir, limite).
