# Smoke - 0009-busca-no-terminal

Executado em 2026-10-02. Godot 4.7, GL Compatibility.
Ambiente de dados: nenhuma captura de tela feita (ver abaixo); `dados/` nao foi lido.

O card declara "Smoke scenarios: Nenhum". Todos os ACs visuais dependem de teclado e foco
(Ctrl+F, Enter, Esc), e o projeto nao tem harness de input. Por isso nao ha PNG.

| AC | Metodo | Cenario | Evidencia | Veredito |
|---|---|---|---|---|
| AC1-AC8 (logica pura) | headless | cobertos por GUT, fora do escopo do smoke | - | n/a aqui |
| AC9 a AC16 (visuais) | manual | roteiro abaixo | - | nao verificado |

## Log
Boot headless (`--headless --quit-after 60`): 0 erros, 0 SCRIPT ERROR, 0 Parse Error.
Avisos (VALIDACAO JSON / VALIDACAO COERENCIA de base_config.json e grades/alec_2010.json) sao
dados pre-existentes, nenhum menciona Terminal ou busca. Nao foi capturado baseline pre-mudanca
em separado; a avaliacao e por inspecao: nenhum aviso toca o codigo alterado.

## LGPD
Nenhum PNG gerado, logo nenhum dado pessoal versionado.

## Nao foi possivel verificar (roteiro manual)
Pre-requisito: abrir o programa com dados fictcios ou com um modulo que nao mostre dados reais.
1. Clicar no Terminal, Ctrl+F: faixa aparece no topo com campo focado e texto desce. Com foco
   fora do Terminal, Ctrl+F nao abre nada. Repetir em dois modulos.
2. Digitar um termo: ocorrencias realcadas, a primeira mais forte, rola ate ela, contador `1 de N`.
   Termo sem resultado: contador zero, Enter nao faz nada.
3. Enter/seta para baixo avancam, Shift+Enter/seta para cima voltam, em ciclo.
4. Esc ou X fecham, removem realce, devolvem foco ao Terminal, sem pular a rolagem.
5. Com a faixa aberta, trocar de aluno fecha a faixa; trocar o tema nao fecha e recolore o realce.
6. Ctrl+C num trecho realcado copia o mesmo texto que sem realce.
7. Passar o mouse nos botoes: dica DicaFlutuante cita Shift+Enter, Enter, Esc.
8. Conferir MANUAL.md secao 3.2.
