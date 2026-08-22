# Smoke — 0002-mesclar-respostas-ajuste

Executado em 2026-08-22. Godot 4.7.1, GL Compatibility.
Ambiente de dados: nenhuma captura de tela foi necessária (ver "Sem cenário visual"
abaixo), então `dados/` e `arquivos/oferta/` não influenciam este relatório.

## Sem cenário visual

O card declara explicitamente, na seção "Smoke scenarios":

> Nenhum (todos os ACs são `headless`; `parse()` é puro dado um CSV fictício em
> `test/fixtures/`).

Confirmado lendo `card.md` e `spec.md`: os 5 ACs têm `verify: headless`, a mudança
de produção é só `standalone_scripts/io/planilha_ajuste.gd::parse()` (lógica pura,
recebe `String` e devolve `Dictionary`, sem nó de cena, sem UI nova — `baixar()` e
`situacao_alunos.gd` não são tocados). Não há tela nova, diálogo novo ou estado
visual novo para fotografar. Portanto **nenhum PNG foi capturado** — não há AC
visual para provar, e capturar uma tela genérica do programa (ex.: o módulo
Situação de Alunos aberto) não provaria nada específico da mudança, além de
arriscar expor `dados/` (respostas reais de alunos baixadas do Forms — é
exatamente essa tela que consome `parse()`) sem necessidade.

Esta constatação por si é o resultado do smoke test para este card: confirmar que
não há lacuna visual a cobrir, e revalidar os portões com o estado atual do
código antes de fechar.

## AC → prova

| AC | Método | Cenário | Evidência | Veredito |
|---|---|---|---|---|
| AC1 — inclusões disjuntas → união | headless | `test_respostas_disjuntas_viram_uniao` | `python .tools/run_tests.py` (26/26 passando) | passou |
| AC2 — código troca de lado → menção mais recente | headless | `test_codigo_troca_de_lado_vence_mencao_mais_recente` | idem | passou |
| AC3 — mesmo lado, 2 respostas → 1 entrada, texto mais recente | headless | `test_mesmo_lado_uma_entrada_com_texto_mais_recente` | idem | passou |
| AC4 — entrada sem código mantida, dedup normalizado | headless | `test_entrada_sem_codigo_mantida_com_dedup_normalizado` | idem | passou |
| AC5 — formato de retorno inalterado | headless | `test_formato_de_retorno_inalterado` (fixture `test/fixtures/ajuste_respostas.csv`) | idem | passou |

Todos os ACs já são cobertos por teste headless (GUT), executado e verde nesta
sessão de smoke — não apenas lido no `review.md`. Não há AC `manual` pendente
neste card (nenhum exige clique/interação de mouse).

## Portões executados nesta sessão

- `python .tools/guardrails.py` → `limpo (375 violacao(oes) pre-existentes
  toleradas pela baseline)`. Nenhuma violação nova.
- `python .tools/run_tests.py` → `26/26 passed` (13 de
  `test/unit/test_planilha_ajuste.gd` + 13 da suíte pré-existente). 0 falhas.
- `"C:/Program Files/Godot/Godot_console.exe" --headless --path . --editor --quit`
  → completa `first_scan_filesystem` e `loading_editor_layout` com `[ DONE ]` nas
  duas etapas, sem `SCRIPT ERROR`, `Parse Error` nem `push_error`/`push_warning`
  na saída.

## Log

Baseline: não aplicável (nenhum processo do jogo/editor foi lançado com
`--write-movie` — não há captura para comparar contra um baseline de execução).
A saída dos três portões acima é, ela mesma, a evidência de log limpo: 0 erros,
0 avisos novos nos três comandos.

## LGPD

Nenhum PNG capturado, então não há imagem a conferir. A única fonte de dados
tocada pelo card é `test/fixtures/ajuste_respostas.csv`, já revisada em
`review.md` (rodadas 1 e 2): matrículas sintéticas (`2409990011`, `2409990022`) e
nomes fictícios (`Maria da Silva Souza`, `Joao Pereira Lima`), conforme AGENTS.md.
Nem `dados/` (respostas reais de alunos, consumidas pela tela Situação de
Alunos/Modo Ajuste) nem `arquivos/oferta/` (docentes reais) foram lidos nesta
sessão.

## Não foi possível verificar

Nada pendente. Todos os ACs do card são `headless` e passaram nos testes
automatizados; não há AC visual ou que exija interação de mouse neste card.
