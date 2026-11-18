---
id: 0010-conversao-cp1252-nativa
title: Conversão de Windows-1252 para UTF-8 em GDScript, sem o ansi_to_utf8.exe
status: in_progress
origin: novo (defeito relatado: horarios.txt novo não importa no Linux)
layers: [standalone_scripts/utils, standalone_scripts/io/file_handling.gd, standalone_scripts/io/arquivos_planejamento.gd, scenes/TelaPrincipal/VerificadorArquivos, scenes/Modulos/PlanejamentoHorario/Complementos/importador_preferencias.gd, externo/]
interviewed: true
---

# 0010 - Conversão de Windows-1252 para UTF-8 em GDScript

> Pipeline concluído em 2026-11-17 na máquina Linux (fila, branch
> `cards/2026-11-17`, uma rodada, review sem findings). Os ACs 1 a 8 (`headless`)
> estão provados: o orquestrador refez os portões com código de saída
> (guardrails `EXIT=0`, 365 toleradas, eram 370; suíte 163/163; parser
> `EXIT=0`). Os ACs 9 a 12 são `manual` e só fecham por relato do dev, um a um
> (roteiros R9 a R12 em `spec.md`). Em 2026-11-18, num PC Windows, o dev aprovou
> o 9 e o 12, e os portões passaram também no Windows (guardrails `EXIT=0`,
> 163/163, parser `EXIT=0`). O código seguiu na release 1.1.1. O card **não** é
> `done`: faltam o 10 e o 11, que pedem a máquina Linux.

## Contexto

Em 2026-11-17 o dev importou pelo verificador de arquivos, com o programa rodando
no Linux, o `horarios.txt` novo gerado pelo programa de horários da universidade.
O formato novo traz a coluna 0 (`linha`) vazia, `tipo`/`sala` = `EaD` e turma
`T100`, e o arquivo vem em Windows-1252. O log mostra a sequência:

1. `FileHandling._precisa_conversao_utf8` decodifica os bytes como UTF-8 para
   procurar U+FFFD. O Godot registra um `Unicode parsing error` por byte
   acentuado: foram 1574 linhas por importação.
2. `convertto_utf8` chama `externo/bin/ansi_to_utf8.exe`, que no Linux falha com
   `Permission denied`.
3. O verificador imprime `Arquivo convertido!` mesmo assim. O arquivo novo nunca
   chega em `dados/saida/`, e o programa segue usando o `horarios.txt` anterior
   sem avisar ninguém.

A mudança de formato em si não quebra a leitura: os dois leitores toleram a
coluna 0 vazia. O defeito é a conversão depender de um executável Windows.

## Goal

Todo arquivo importado em Windows-1252 é convertido para UTF-8 pelo próprio
programa, em qualquer sistema operacional, sem executável externo e sem encher o
log com erros de decodificação. Quando a conversão falha, o programa não anuncia
que converteu.

## Non-goals

- **Exportar o `horarios.txt`** (`HorariosExe._para_cp1252`, coluna 0 numerada).
  O dev não exporta mais esse arquivo.
- **Interpretar os campos novos do formato.** `tipo`/`sala` = `EaD` e as linhas
  de modelo não preenchidas (`Salas`, `Dias`, `Tipo de Aula`, `Turma`) seguem
  tratados como hoje; a leitura já os tolera.
- **As outras dependências de Windows no Linux** (`xlsx_to_csv.exe`, `typst.exe`,
  atualizador em PowerShell). Estão registradas no `IDEAS.md`.
- **Mensagem nova na interface do verificador** para falha de conversão. A falha
  vai para o log via `push_error`.
- **Outras codificações** (UTF-16, ISO-8859-15...). A entrada continua sendo
  UTF-8 ou Windows-1252, como hoje.
- **Atualizar o `MANUAL.md`.** Nada muda para o usuário: os arquivos importados
  já eram "convertidos para UTF-8".

## Acceptance criteria

- [x] 1. Bytes em Windows-1252 viram o texto equivalente: ASCII fica intacto;
  `0xA0`–`0xFF` viram U+00A0–U+00FF (ex.: `0xE7 0xE3 0x6F` → `ção`); os bytes
  definidos de `0x80`–`0x9F` viram seus caracteres (ex.: `0x80` → `€`,
  `0x96` → `–`, `0x93`/`0x94` → aspas curvas). -- verify: `headless`
- [x] 2. Os cinco bytes sem caractere no Windows-1252 (`0x81`, `0x8D`, `0x8F`,
  `0x90`, `0x9D`) viram U+FFFD sem interromper a conversão. É o mesmo resultado
  do `ansi_to_utf8.py` (`errors="replace"`). -- verify: `headless`
- [x] 3. A detecção responde "já é UTF-8" para ASCII puro, arquivo vazio, UTF-8
  acentuado e UTF-8 com BOM, e "precisa converter" para Windows-1252 acentuado.
  Ela não usa `get_string_from_utf8()`, que é o que registra um erro por byte
  inválido. -- verify: `headless`
- [x] 4. `convertto_utf8` com origem em Windows-1252 grava um destino UTF-8 com o
  mesmo texto e as mesmas quebras de linha (CRLF continua CRLF) e devolve
  sucesso. -- verify: `headless` (fixture fictícia gravada em `user://`)
- [x] 5. `convertto_utf8` com origem já em UTF-8 copia o arquivo byte a byte e
  devolve sucesso, sem conversão dupla (`á` não vira `Ã¡`). -- verify: `headless`
- [x] 6. `convertto_utf8` com origem inexistente devolve falha e não cria o
  destino. Com origem igual ao destino, não toca no arquivo (comportamento
  atual). -- verify: `headless`
- [x] 7. Um `horarios.txt` fictício no formato novo (coluna 0 vazia,
  Windows-1252, CRLF, `tipo` = `EaD`, turma `T100`, dias `Terça` e `Sábado`)
  passa por `convertto_utf8` e depois por `HorariosExe.carregar_horarios_txt`
  com `dia` = `terça`/`sábado`, `linha` = `""` e código de disciplina extraível
  (`al0171`). -- verify: `headless`
- [x] 8. Converter 5 MB sintéticos em Windows-1252 leva menos de 3 s no teste
  headless. O `hist.csv` real tem cerca de 4,7 MB, e o `.exe` fazia isso em
  cerca de 1 s. -- verify: `headless`
- [x] 9. O `ansi_to_utf8.exe` sai do projeto: `externo/bin/ansi_to_utf8.exe` e
  `externo/src/ansi_to_utf/` deixam o git, e `git grep ansi_to_utf8` não
  encontra mais nada fora de `Cards/` e `.claude/handoff/`. -- verify: `manual`
  *(aprovado pelo dev em 2026-11-18, PC Windows, sobre a saída do R9: `git grep`
  vazio, exit 1, e os dois caminhos ausentes do checkout)*
- [ ] 10. No Linux, importar pelo verificador o `horarios.txt` real recebido em
  2026-11 atualiza `dados/saida/horarios.txt` (data do dia, UTF-8, `Terça` e
  `Sábado` corretos) e não deixa nenhuma linha `Unicode parsing error` no log
  (`user://logs/godot.log`). -- verify: `manual`
- [ ] 11. No Linux, apontar o verificador para um arquivo sem permissão de leitura
  (`chmod 000`) registra um erro com o nome do arquivo e **não** registra
  `Arquivo convertido!`. -- verify: `manual`
- [x] 12. Num PC Windows, a mesma importação do AC 10 continua funcionando (é a
  regressão do caminho que usava o `.exe`). -- verify: `manual`
  *(relato do dev em 2026-11-18: importou num PC Windows, já sem o `.exe`, e
  funcionou. Conferido no `godot.log` daquela sessão: zero `Unicode parsing
  error` e um `Arquivo convertido!`; `dados/saida/horarios.txt` é UTF-8 estrito,
  com `Terça` e `Sábado` presentes. Só contagens, sem conteúdo.)*

## Edge cases

- **Arquivo misto** (parte UTF-8, parte Windows-1252): a detecção diz "precisa
  converter" e o arquivo inteiro é convertido; os trechos que já eram UTF-8 viram
  mojibake. O `.exe` fazia o mesmo. Aceito, não é erro visível.
- **Windows-1252 que por acaso forma UTF-8 válido**: improvável em texto em
  português. Nesse caso é tratado como UTF-8, igual a hoje.
- **BOM UTF-8**: é mantido, porque a cópia é byte a byte.
- **Arquivo vazio**: é UTF-8 válido; vira um destino vazio, com sucesso.
- **Instalações antigas**: a atualização só acrescenta arquivos, então continuam
  com o `ansi_to_utf8.exe` em `externo/bin/`. É inofensivo, porque nada mais o
  chama.
- **Chamadores que contam com o destino existir no retorno** (`importador_preferencias`,
  `analise_grades.validar_contra_cadastro`, `planejamentohorario`): no sucesso o
  destino existe, como hoje. Na falha não existe, também como hoje; a diferença é
  que agora o retorno diz isso.

## Notas para o design

- A conversão e a detecção são funções puras sobre `PackedByteArray`, em
  `standalone_scripts/utils/`. O `FileHandling` só faz o I/O em volta delas.
- Há três cópias da heurística atual: `FileHandling._precisa_conversao_utf8`,
  `ArquivosPlanejamento._verifica_se_windows1252` e o teste inline em
  `ImportadorPreferencias`. Todas passam a usar a detecção nova. Deixar uma cópia
  antiga para trás mantém o ruído no log.
- A tabela de `0x80`–`0x9F` é o inverso de `HorariosExe._unicode_para_cp1252`.
  Vale ter uma tabela só, nos dois sentidos.
- Os doc comments que citam o `ansi_to_utf8.exe` (`file_handling.gd`,
  `arquivos_planejamento.gd`, `importador_preferencias.gd`,
  `planejamentohorario.gd`) precisam ser atualizados.
- **LGPD:** as fixtures são fictícias (nomes como `Maria da Silva Souza`). O
  `horarios.txt` real tem nomes de docentes e **não** entra em `test/fixtures/`.
  A conversão continua gravando nos mesmos lugares de hoje, então a superfície
  de exposição não muda.

## Smoke scenarios

Nenhum. Não há mudança visual, e a prova do AC 10 usa dado real, que não pode
virar PNG. Ela fica com o dev (`manual`).
