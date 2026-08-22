# Smoke — 0003-reanexar-fragmentos-rotulo-ajuste

Executado em 2026-08-22. Godot 4.7.1, GL Compatibility.

## Por que não há captura de tela

Este card não tem ACs visuais. Os seis critérios de aceite do card estão
marcados `verify: headless`, e a spec é explícita: "Smoke: nenhum (todos os
ACs são headless; `parse()` é função pura String → Dictionary)". A única
mudança de produção é `PlanilhaAjuste._separar_entradas()`, exercitada
inteiramente por testes unitários GUT — não há tela, diálogo nem módulo de UI
tocado (non-goals do card confirmam: `situacao_alunos.gd` e a exibição ficam
de fora).

Rodar o programa para tirar um PNG "de boot" não provaria nada a mais sobre
este card e seria um risco de LGPD desnecessário: `dados/saida/` tem
`hist.csv`/`email.csv` reais e `arquivos/oferta/` tem nomes reais de docentes
neste checkout. Por isso a captura foi propositalmente **não tentada**.

## AC → prova (headless, suíte GUT já existente)

| AC | Método | Cenário | Evidência | Veredito |
|---|---|---|---|---|
| AC1 | headless | Célula `"AL0394: Administração, T40;60;80, João Pereira Lima;"` → uma menção, zero problemas | `test/unit/test_planilha_ajuste.gd::test_rotulo_com_virgulas_vira_uma_mencao` (passou) | passou |
| AC2 | headless | Duas opções com código na mesma célula, cada uma com vírgulas no rótulo → duas menções | `test/unit/test_planilha_ajuste.gd::test_duas_opcoes_com_virgulas_no_rotulo_viram_duas_mencoes` (passou) | passou |
| AC3 | headless | Fragmento sem código no início da célula continua problema visível | `test/unit/test_planilha_ajuste.gd::test_fragmento_sem_codigo_no_inicio_continua_problema` (passou) | passou |
| AC4 | headless | Célula só com texto livre com vírgulas → um problema re-juntado | `test/unit/test_planilha_ajuste.gd::test_celula_so_texto_livre_vira_um_problema_rejuntado` (passou) | passou |
| AC5 | headless | Texto livre após vírgula numa menção com código é absorvido (trava o trade-off) | `test/unit/test_planilha_ajuste.gd::test_texto_livre_apos_mencao_valida_e_absorvido` (passou) | passou |
| AC6 | headless | Suíte do 0002 continua verde, sem alteração nos testes existentes | 34/34 testes passando (`python .tools/run_tests.py`); `git diff --numstat HEAD -- test/unit/test_planilha_ajuste.gd test/fixtures/ajuste_respostas.csv` → `94  0  test/unit/test_planilha_ajuste.gd` (94 inserções, **0 deleções** — qualquer linha existente alterada apareceria como +1/−1, então 0 deleções prova anexo puro) e a fixture não aparece na saída (intocada) | passou |

## Log

Rodada com a mudança (`python .tools/run_tests.py`): 3 scripts, 34 testes,
34 passando, 76 asserts, 0 falhas. `grep -iE "push_error|push_warning|SCRIPT
ERROR|Parse Error"` na saída completa: **zero ocorrências**.

Não há baseline separado para comparar (nenhum `git stash`): os testes novos
do próprio card fariam a suíte falhar no código anterior, o que tornaria a
comparação uma tautologia sem valor. Como a execução com a mudança já deu
zero erros e zero avisos, não há como isso representar regressão de nenhum
baseline possível — zero não regride.

`"C:/Program Files/Godot/Godot_console.exe" --headless --path . --editor
--quit`: projeto carrega e a inicialização completa (`first_scan_filesystem`
e `loading_editor_layout` terminam em `DONE`), sem erro de parser nem de
script.

`python .tools/guardrails.py`: limpo (375 violações pré-existentes toleradas
pela baseline — nenhuma nova).

## LGPD

Nenhum PNG foi gerado (nada a conferir por captura). `dados/saida/` e
`arquivos/oferta/` têm dados reais neste checkout, mas nenhuma tela que os
exibe foi aberta ou fotografada — o smoke deste card não passa perto delas.
Os testes headless usam só os dados fictícios já estabelecidos na suíte
(matrículas `24099900xx`, nomes `Maria da Silva Souza` / `João Pereira
Lima`), herdados do 0002 e reaproveitados pelo 0003.

## Checklist "antes de entregar" (adaptado — sem captura)

- [x] Todo AC `headless` do card tem teste GUT nomeado e passando.
- [N/A] PNG nomeado por AC — não se aplica (card sem AC visual).
- [N/A] `frame%08d.png` sobrando na pasta — não se aplica (nenhuma captura
      feita, pasta `smoke/` só tem este arquivo).
- [x] Log comparado com baseline (raciocínio acima: zero erros/avisos não
      regride nenhum baseline).
- [x] Todo AC que não deu para verificar automaticamente está dito — ver
      seção abaixo.
- [N/A] Cada PNG olhado por dado pessoal — não se aplica (nenhum PNG).

## Não foi possível verificar

Nenhum. Os seis ACs do card são `headless` e todos foram verificados pela
suíte GUT existente, sem necessidade de rodar o programa interativamente.
