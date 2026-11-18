
## Rodada 1 de 3

Portoes (rodados nesta rodada): `python .tools/guardrails.py` limpo (365 violacoes da baseline,
nenhuma nova); `python .tools/run_tests.py` 179/179 (163 anteriores + 16 do arquivo novo); parser do
Godot (`--headless --path . --editor --quit`) exit 0. Diff inteiro lido com `git add -N .` antes do
`git diff HEAD`: `arquivos_planejamento.gd`, `MANUAL.md`, `spec.md` e o teste novo com seu `.uid`.

LGPD: nenhum dado pessoal real. Os testes usam `Maria da Silva Souza` e `Carlos Ficticio Lima`,
`Disciplina Ficticia X` e salas genericas, gerados em memoria e gravados em `user://teste_0011/`
(apagados no `after_each`). Os codigos `AL0015`, `AL0022` etc. sao publicos. Nenhum arquivo
gitignorado novo na raiz, entao `export_presets.cfg` nao precisa mudar. Nenhuma rede, log ou
exportacao nova.

Contrato de dados: nenhuma chave renomeada. `cards_novos` ganha `oferta` (so em memoria) e
`adicionar_planejamento_csv_do_txt` a preserva, entao filtro de envio, deteccao de compartilhada e
identidade `codigo|oferta` da mesclagem do campus mantem o valor de hoje. O modo referencia
(`prefixos` vazio) ficou byte a byte igual: o AC9 falha se ele passar a usar a chave por parte.
`_parte_casa_prefixos` (em vez de `semestre_casa_prefixos(parte, ...)` como a spec escreve) esta
certo: re-dividir a parte aceitaria `EM03/EC03` com prefixo `ec`, que o leitor do CSV recusa.

ACs conferidos um a um:

- AC1, AC2, AC3, AC5, AC6, AC7, AC10, AC11: cobertos por teste que falha se o codigo antigo
  voltar (chave do campo inteiro, filtro `begins_with`, chave `chave_txt` do `mesclar`).
- AC4, AC8, AC9: testes de nao-regressao, passam nos dois lados por desenho. AC4 tem duas guardas:
  o filtro do topo de `preparar` e o `{}` que `_resolver_linhas_txt` devolve quando
  `parte_receptora_txt` nao acha candidata; so fica vermelho se as duas sairem. AC8 guarda a chave e
  o `aloc.semestre` de uma linha `EC07` simples no modo curso (falha se `parte_receptora_txt` ou o
  tratamento de bordas/caixa mudar a chave). AC9 guarda o modo referencia (falha se `prefixos` vazio
  passar a resolver por parte).
- Estas conclusoes de "falha se revertido" vem da leitura do codigo e dos testes; nao rodei
  mutacao (a copia de trabalho em area temporaria foi negada nesta sessao).
- AC12: 179/179. AC13 e AC14 sao `manual`, a cargo do dev.
- Apoio de referencia em `mesclar` (`test_atualizar_planejamento_ignora_entrada_de_referencia`):
  falha sem a guarda `referencia`, porque a linha cairia no card da referencia.

Findings (nenhum bloqueante):

1. `standalone_scripts/io/arquivos_planejamento.gd:777` (baixa, nao bloqueante) — o caminho
   `removidas` + `entries_removidas` de uma linha compartilhada nao tem teste. Nenhum teste da
   suite tem `removidas` nao vazio, entao voltar o laco de `entries_removidas` para a formula
   antiga (`codigo + "_" + semestre.to_lower()`) mantem a suite verde. E exatamente o risco que a
   spec aponta ("os dois pontos tem de concordar"). Cenario: planejamento so com `al0015_ec03`; txt
   com 4 linhas `EC03;EMExtra` da AL0015 e 2 linhas `EE01;EM01` da AL0101. Esperado:
   `removidas == ["al0101_ee01"]` e 2 itens da AL0101 em `entries_removidas`; com a formula antiga
   no segundo laco, `entries_removidas` fica vazio e o "Incluir" do dialogo perde as linhas. Conserto:
   acrescentar esse teste a `test_compartilhadas_horarios_txt.gd`.
2. `standalone_scripts/io/arquivos_planejamento.gd:411` (baixa, nao bloqueante) — o comentario de
   `_chaves_do_txt_pelo_planejamento` diz "Sem nenhuma parte com card, vale o campo inteiro", mas
   `parte_receptora_txt` devolve a chave da primeira parte (`al0101_ee01` para `EE01;EM01`); o
   campo inteiro so vale quando nao ha parte nenhuma. Efeito visivel: o dialogo "Disciplinas
   Removidas" lista `al0101_ee01` onde antes listava `al0101_ee01;em01`. Conserto: corrigir o
   comentario para "vale a primeira parte" (e o passo 4 de `parte_receptora_txt` na spec).

Verdict: clean
