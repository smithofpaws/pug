# Smoke - 0011-compartilhadas-horarios-txt

Executado em 2026-11-18. Godot 4.7.1 (stable), GL Compatibility, Windows.
Ambiente de dados: `dados/` e `arquivos/oferta/` nao inspecionados (leitura proibida para agentes).
Nenhuma captura de tela feita; os testes usam so fixtures ficticias geradas em `user://teste_0011/`.

O card declara "Smoke scenarios: Nenhum". A logica esta em `ArquivosPlanejamento`
(`standalone_scripts/io`), sem mudanca de UI, e a conferencia na tela depende dos dados reais de
oferta do dev. Nenhum AC tem verificacao `smoke`: ACs 1-12 sao `headless` e ACs 13-14 sao `manual`.
Por isso nao ha PNG nesta pasta, e isso e intencional (tambem elimina qualquer risco de LGPD).
O que o smoke fez foi (a) rodar os tres portoes, (b) conferir que cada teste de AC existe e passa
na suite, e (c) bootar o programa headless para comparar o log.

| AC | Metodo | Cenario | Evidencia | Veredito |
|---|---|---|---|---|
| AC1 | headless | Card `al0015_ec03` existe, 4 linhas `EC03;EMExtra` saem com a chave do card | `test_compartilhada_casa_com_card_do_planejamento_csv` (GUT, passou) | passou |
| AC2 | headless | `EE03;EC03` com `["ec"]` nao e descartada, vai para `al0022_ec03` | `test_filtro_aceita_curso_fora_do_comeco_do_campo` | passou |
| AC3 | headless | `EA09; ee09 ;EC07` casa com `al0390_ec07` | `test_campo_com_espacos_e_caixa_mista_casa_com_card` | passou |
| AC4 | headless | `EE01;EM01` com `["ec"]` continua descartada | `test_linha_sem_parte_do_curso_continua_descartada` | passou |
| AC5 | headless | Varios cursos: so `al0022_ee03` recebe | `test_varios_cursos_so_o_card_da_primeira_parte_recebe` | passou |
| AC6 | headless | Chaves duplicadas desempatam pela oferta (`_ec07` x `_ec07_2`) | `test_chaves_duplicadas_desempatam_pela_oferta` | passou |
| AC7 | headless | Sem card: um card novo `al0015_ec03`, oferta `EC03;EMExtra`, CH 4 | `test_sem_card_gera_um_card_novo_no_formato_do_csv` (+ 2 de apoio) | passou |
| AC8 | headless | Nao-regressao: `EC07` simples mantem `al0395_ec07` | `test_linha_nao_compartilhada_mantem_a_chave` | passou |
| AC9 | headless | Nao-regressao do import de referencia (prefixos vazios, campo inteiro) | `test_import_de_referencia_mantem_o_campo_inteiro` | passou |
| AC10 | headless | Ida e volta: `exportar_planejamento_json` traz a `al0015` com 4 alocacoes | `test_ida_e_volta_pelo_planejamento_json` | passou |
| AC11 | headless | Atualizar planejamento preserva sala/dia/horario da compartilhada | `test_atualizar_planejamento_preserva_a_compartilhada` | passou |
| AC12 | headless | Suite existente continua passando | `python .tools/run_tests.py`, exit 0, 179/179 (163 anteriores + 16 novos) | passou |
| AC13 | manual | Dados reais da EC: 8 disciplinas na grade, sem card duplicado, fora do dialogo "fora do planejamento" | roteiro R13 abaixo | nao verificado |
| AC14 | manual | Dados reais: Salvar e reabrir pelo `planejamento.json` mantem as alocacoes | roteiro R14 abaixo | nao verificado |

Os 16 testes de `test/unit/test_compartilhadas_horarios_txt.gd` aparecem no relatorio do GUT como
16/16 passed: 11 testes dos ACs 1-11 e 5 de apoio (`test_card_novo_leva_a_oferta_ao_planejamento` e
`test_variantes_do_campo_somam_no_mesmo_card_novo`, do AC7; `test_parte_receptora_respeita_ordem_filtro_e_caixa`;
`test_desempate_cai_na_base_sem_oferta_igual`; `test_atualizar_planejamento_ignora_entrada_de_referencia`).
O arquivo de teste foi lido inteiro: cada teste de AC passa pela funcao publica de ponta a ponta e
as fixtures sao ficticias (`Maria da Silva Souza`, `Carlos Ficticio Lima`, `Disciplina Ficticia X`,
`Sala 101`...).

## Portoes (rodados nesta execucao, na raiz do projeto)

| Portao | Comando | Resultado |
|---|---|---|
| guardrails | `python .tools/guardrails.py` | exit 0, "limpo (365 violacoes pre-existentes toleradas pela baseline)". A contagem e a mesma que a review registrou, entao nenhuma violacao nova |
| testes | `python .tools/run_tests.py` | exit 0, 12 scripts, 179 testes, 179 passando, 1091 asserts |
| parser Godot | `Godot_console.exe --headless --path . --editor --quit` | exit 0, nenhum `ERROR`/`SCRIPT ERROR`/`Parse Error` |

## Log

Boot headless do programa (`Godot_console.exe --headless --path . --quit-after 60`), exit 0, saida
guardada fora do repositorio e so resumida aqui.

- 0 `SCRIPT ERROR`, 0 `Parse Error`, 0 `ERROR`, 0 `push_error`, 0 `Unicode parsing error`.
- 13 `push_warning`, todos de `json_validator.gd` chamado por `main.gd:49` (`validar_base_config`):
  5 de `VALIDACAO JSON` (tipo de valores do `base_config.json`) e 8 de `VALIDACAO COERENCIA`
  (7 em `grades/alec_2010.json`, 1 em `grades/alec_2023.json`: prerequisitos que apontam para codigo
  inexistente na grade).
- Nenhuma linha do log menciona `arquivos_planejamento`, `preparar_alocacoes`,
  `mesclar_planejamento`, `parte_receptora` ou `desempatar`.

Baseline: **nao foi possivel montar um baseline executavel.** Criar uma copia do projeto no commit
anterior (worktree ou `git archive` para area temporaria) foi negado pelo ambiente, e `git stash`
com indice sujo (arquivos staged e `-N`) seria risco desnecessario. O baseline e portanto por
construcao, nao por diff de duas execucoes:

- `git diff HEAD --name-only` lista so `spec.md`, `MANUAL.md`, `arquivos_planejamento.gd` e o teste
  novo (com seu `.uid`). **Nenhum** de `base_config.json`, `arquivos/grades/` ou
  `standalone_scripts/utils/json_validator.gd` mudou. Entradas e codigo que produzem os 13 avisos
  sao identicos aos do HEAD, entao um boot do HEAD imprimiria os mesmos 13;
- os 8 avisos de `VALIDACAO COERENCIA` (7 em `alec_2010.json`, 1 em `alec_2023.json`, o `al5022` com
  `'ch 50%'`) sao exatamente o conjunto que o teste `test_arquivos_reais_reportam_so_os_defeitos_conhecidos`
  (`test_validacao_curricular.gd`) fixa para os arquivos reais, e esse teste passou nesta execucao;
- os smokes dos cards 0008 (2026-10-02) e 0010 (2026-11-17) tambem registraram 13 `push_warning`
  de validacao de JSON e 0 erros (confirmacao por registro anterior, nao a base do argumento);
- no relatorio do GUT, os unicos `ERROR`/`WARNING` sao os `push_error` do card 0010 e os
  `push_warning` do card 0005, todos marcados `[ExpectedError]` pelos proprios testes deles. A secao
  do script novo (`test_compartilhadas_horarios_txt.gd`) nao tem nenhum `ERROR` nem `WARNING`,
  so `print_debug` do leitor de CSV.

Limite do que o log prova: `preparar_alocacoes_do_txt` e `mesclar_planejamento_com_horarios_txt` so
rodam em **Importar > Abrir horarios.txt** e **Atualizar planejamento**, ambos com clique, entao o
boot headless **nao alcanca o codigo alterado**. Ele prova apenas que o script modificado carrega
sem erro de parse ou de execucao e que o programa sobe. A evidencia de log dos caminhos alterados e
a secao do GUT do script novo, que roda esses caminhos e saiu sem `ERROR` nem `WARNING`. "Log limpo"
vale nesses dois sentidos e nao mais que isso.

## LGPD

Nenhum PNG gerado. Nenhum arquivo de `dados/` ou `arquivos/oferta/` foi lido por este smoke. O boot
headless foi o unico momento em que o programa pode ter tocado esses caminhos (como em qualquer
execucao dele); a saida foi gravada fora do repositorio e so contagens e prefixos de aviso (todos de
validacao de JSON da pasta `arquivos/`) foram lidos. `git status` depois do boot: so as mudancas do
card, nada novo.

## Nao foi possivel verificar

Os dois ACs `manual` dependem dos arquivos reais da EC (`dados/saida/planejamento.csv` e
`horarios.txt`) e de cliques. Nao ha harness de input neste projeto e agentes nao leem `dados/`.
Roteiros completos em `spec.md` (R13 e R14); o registro no card e so "aprovado" ou "reprovado" e,
se reprovado, o codigo da disciplina que falhou. **Sem captura de tela e sem nome de professor.**

- **AC13 (R13).** No PUG, abrir **Planejamento de horario**. **Importar > Abrir planejamento.csv**,
  marcar so a Engenharia Civil e confirmar. **Importar > Abrir horarios.txt**, marcar so a
  Engenharia Civil e confirmar. Se aparecer no terminal
  `Disciplinas no horarios.txt fora do planejamento carregado: ...` ou o dialogo "Disciplinas do
  horarios.txt fora do planejamento", conferir que **nenhuma** destas esta na lista: AL0015, AL0019,
  AL0022, AL0002, AL0381, AL0394, AL0390, AL0142 (fechar o dialogo com **Nao adicionar**). No painel,
  cada uma das 8 deve ter **um** card com semestre simples (`EC03`, `EC07`...), sem segundo card com
  o semestre combinado (`EC03;EMExtra`), e estar completa, sem "h pendente". Na grade, cada uma deve
  ocupar as celulas que tem no `horarios.txt`.
  Nao e reprovacao: `al0390_ec07_2` e `al0142_ec09_2` com CH 0 continuarem existindo, nem a AL0375
  continuar pendente (ambos non-goals do card).
- **AC14 (R14).** Continuando do fim do R13: **Importar > Salvar planejamento.json** (se perguntar
  sobre disciplinas de outro curso, escolher so o seu curso). Depois **Importar > Abrir
  planejamento.json** (ou fechar e reabrir o modulo). As 8 disciplinas devem continuar nas mesmas
  celulas, com os cards completos.
  Nao e reprovacao: ao reabrir o JSON, as alocacoes das chaves `_2` aparecem no card base (AL0390 e
  AL0142 ficam com um card so). O JSON funde codigo+semestre iguais; e comportamento atual e
  non-goal.

Os ACs 13 e 14 continuam abertos: o card nao fecha sem o dev confirmar.

## Observacoes para o dev (nao sao ACs)

- A review (`review.md`) registra 2 findings baixos e nao bloqueantes: falta um teste do caminho
  `removidas` + `entries_removidas` de uma linha compartilhada, e o comentario de
  `_chaves_do_txt_pelo_planejamento` descreve "campo inteiro" quando o codigo devolve a primeira
  parte. Nao afetam o veredito deste smoke.
