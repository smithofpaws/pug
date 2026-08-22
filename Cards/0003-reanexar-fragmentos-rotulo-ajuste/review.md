# Review — 0003-reanexar-fragmentos-rotulo-ajuste

## Rodada 1

**Veredito:** `clean` (nenhum finding bloqueante).

Portões conferidos nesta rodada: `python .tools/guardrails.py` (limpo, baseline
intacta), `python .tools/run_tests.py` (34/34, suíte `test_planilha_ajuste.gd`
com 21/21 incluindo os 8 testes novos do card). AC6 verificado explicitamente:
`git diff HEAD -- test/unit/test_planilha_ajuste.gd` mostra apenas linhas
adicionadas após `test_formato_de_retorno_inalterado` (nenhum teste existente
tocado) e `test/fixtures/ajuste_respostas.csv` não aparece em `git status
--short` (intocada). ACs 1–5 conferidos um a um contra `_separar_entradas` e
batem com os testes correspondentes.

LGPD: sem nome real. `Maria da Silva Souza` é o próprio exemplo do AGENTS.md,
`João Pereira Lima` já vinha do card, matrículas seguem o padrão fictício
`24099900xx` já estabelecido na suíte. Nenhum arquivo novo fora de
`test/`/`Cards/`.

### Finding 1 — medium, non-blocking

- **Arquivo:** `standalone_scripts/io/planilha_ajuste.gd:195-200` (comentário) /
  `test/unit/test_planilha_ajuste.gd:264-273` (`test_fragmento_reanexado_a_mencao_multi_codigo_perde_o_texto`)
- **Resumo:** o card documenta e testa (AC5) que texto livre após uma menção de
  **um** código é *absorvido* (some o alerta, mas o texto continua visível na
  entrada). Para uma entrada com **dois ou mais** códigos, o mesmo reanexo faz
  o texto desaparecer por completo — nem menção nem problema —, e essa
  diferença de gravidade não está registrada em nenhum lugar que o card/spec já
  usa para documentar trade-off aceito (spec.md § "Riscos de contrato de
  dados", card.md § Edge cases, MANUAL.md), só no comentário de código e no
  docstring do teste.
- **Cenário concreto:** célula `"al0400 e al0401, professor Fulano"` (rótulo do
  Forms com dois códigos extraíveis no mesmo fragmento, seguido de um
  fragmento sem código). Antes do 0003, `"professor Fulano"` virava fragmento
  próprio → entrada sem código → aparecia como "problema" visível ao
  coordenador. Depois do 0003, é reanexado ao rótulo multi-código; como
  `_mesclar_lado` emite `texto = codigo` (não `entrada`) quando
  `codigos.size() > 1` — linha inalterada por este diff, herdada do 0002 —, o
  texto reanexado desaparece do retorno inteiro. `resposta["incluir"]` vira
  `["al0400", "al0401"]`, sem qualquer rastro do pedido em texto livre.
  Confirmado empiricamente: o teste novo falha no código anterior ao 0003
  (produzia `["al0400", "al0401", "professor Fulano"]`) — ou seja, a
  informação era visível antes e some agora.
- **Por que não bloqueia:** a causa raiz (`texto = codigo` em vez de `entrada`
  para menção multi-código) é código do 0002, não tocado por este diff — corrigi-la
  exigiria mexer em `_mesclar_lado`, fora da camada que a spec reserva para
  este card ("Única mudança de produção, toda dentro de `_separar_entradas()`").
  O comportamento já está nomeado, comentado e travado num teste que
  discrimina (falha no código antigo, passa no novo) — é divulgação, não
  descoberta silenciosa. A alcançabilidade também é estreita: exige um
  fragmento com 2+ códigos extraíveis já dentro do mesmo trecho sem vírgula
  (rótulo genuinamente multi-código, ou o residual de regex do 0002 tipo
  `"AL0400 Fundações Lab 101"`) — e no caso do residual a entrada já nascia
  corrompida antes do 0003 (decisão fantasma, texto do rótulo já descartado).
- **Conserto sugerido (documentação, sem mudança de produção):** dar ao caso a
  mesma paridade de registro que o trade-off do AC5 recebeu — acrescentar em
  `spec.md` § "Riscos de contrato de dados" uma entrada explícita ("reanexo em
  menção com 2+ códigos perde o texto reanexado por completo, não apenas o
  alerta — ver teste X"), e abrir uma entrada no `IDEAS.md` para eventualmente
  fazer `_mesclar_lado` emitir a entrada completa (ou ao menos concatenar o
  texto reanexado) também no caminho multi-código, num card futuro que possa
  tocar aquela função.

### Finding 2 — low, non-blocking

- **Arquivo:** `test/unit/test_planilha_ajuste.gd:198-201`
  (`test_rotulo_com_virgulas_vira_uma_mencao`)
- **Resumo:** a segunda asserção do teste —
  `assert_eq(resposta["excluir"], [], "nenhum fragmento deve sobrar como
  problema")` — não prova o que a mensagem diz. A célula do CSV está na coluna
  **incluir**; qualquer fragmento que "sobrasse como problema" cairia em
  `problemas_incluir` e apareceria em `resposta["incluir"]`, nunca em
  `resposta["excluir"]` (que é `[]` simplesmente porque a coluna excluir da
  linha está vazia — nada relacionado ao reanexo).
- **Por que não bloqueia:** o AC1 ("zero problemas") continua genuinamente
  provado pela asserção anterior, de igualdade exata em `resposta["incluir"]`
  contra a string única esperada — um fragmento vazado como problema
  apareceria como elemento extra no array e quebraria essa igualdade. É a
  própria spec que argumenta isso (AC1 na tabela "Mapeamento AC → prova":
  "problema entraria na mesma lista"). O finding é só sobre a asserção
  redundante ter mensagem enganosa, não sobre cobertura faltando.
- **Conserto sugerido:** trocar a mensagem para refletir o que de fato está
  sendo checado (coluna excluir vazia), ou substituir por
  `assert_eq(resposta["incluir"].size(), 1, "zero problemas: nenhum elemento
  extra alem da mencao reconstituida")`, que testa a mesma coisa que a
  igualdade exata já testa, mas com mensagem correta.
