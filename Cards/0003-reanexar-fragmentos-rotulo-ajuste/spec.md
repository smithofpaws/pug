# Spec — 0003-reanexar-fragmentos-rotulo-ajuste

Card: `Cards/0003-reanexar-fragmentos-rotulo-ajuste/card.md`.
Objetivo: `PlanilhaAjuste.parse()` deixa de tratar toda vírgula da célula como
separador de menção. A célula é dividida em menções **pelos fragmentos que
contêm código extraível**: fragmento sem código é re-anexado à entrada anterior
da mesma célula (re-juntado com `", "`), reconstituindo o rótulo original da
opção do Forms. Uma opção marcada = uma menção, mesmo com vírgulas no rótulo.

## Camadas tocadas

| Arquivo | Por quê |
|---|---|
| `standalone_scripts/io/planilha_ajuste.gd` | Única mudança de produção, toda dentro de `_separar_entradas()` (o card fixa a camada: `layers: [standalone_scripts/io]`, e o edge case fixa o lugar: "o re-anexo acontece na separação de entradas, ANTES da mesclagem do 0002"). `_mesclar_lado`, `_montar_resposta`, `extrair_codigos` e `baixar` não mudam. Docstrings da classe e de `parse()` ajustadas (hoje prometem "separadas por vírgula; cada entrada é texto livre", que deixa de ser a regra). |
| `test/unit/test_planilha_ajuste.gd` | Testes novos **anexados** à suíte existente (AC6 exige zero alteração nos testes do 0002). Todos os ACs são headless via `parse()`/`extrair_codigos` reais, com CSVs inline pelo helper `_csv_respostas` já existente. |
| `MANUAL.md` | Uma frase na seção "Modo Ajuste" (§ do Situação de Alunos): rótulo de opção com vírgulas conta como uma única menção, e texto livre escrito após vírgula numa menção válida é absorvido por ela (comportamento visível ao coordenador — inclusive o trade-off aceito do AC5). |

Nada muda em `scenes/situacao_alunos.gd` (non-goal explícito; `_classificar_codigos`
já re-extrai o código de texto arbitrário), nem em `main.gd`, nem em fixtures —
`test/fixtures/ajuste_respostas.csv` fica intocada (faz parte da prova do AC6).

## Contrato público novo ou alterado

```gdscript
func parse(csv: String) -> Dictionary
```

- **Assinatura e formato de retorno inalterados.** Continua
  `{ "ok": bool, "respostas": Array, "erro": String }`, item =
  `{ "matricula": String, "incluir": Array[String], "excluir": Array[String] }`.
  Nenhuma chave nova, renomeada ou removida
  (`test_formato_de_retorno_inalterado` do 0002 segue congelando isso).
- **Semântica alterada só na separação de entradas** (regra abaixo). Mesclagem
  do 0002 — decisão por código, "menção mais recente vence", exclusão prevalece
  na mesma resposta, dedup de problemas por texto normalizado — intacta: recebe
  as entradas já reconstituídas e não sabe que houve re-anexo.
- **Quem chama:** `situacao_alunos.gd::_verificar_planilha()` (único consumidor).
- **O que garante:** uma opção marcada no Forms = uma entrada no retorno, mesmo
  quando o rótulo da opção contém vírgulas; texto da entrada = fragmentos
  re-juntados com `", "`.
- **O que assume:** o mesmo de hoje (linhas em ordem cronológica do Forms;
  vírgula dentro de célula protegida por aspas — `_parse_csv` já resolve).
- **Docstring de `parse()` e da classe reescritas** no trecho "separadas por
  vírgula" para descrever a regra de re-anexo.

Helper privado alterado (assinatura idêntica, semântica nova — comentário `#`
reescrito):

```gdscript
func _separar_entradas(celula: String) -> Array[String]
```

`extrair_codigos()` **não muda de contrato**, mas ganha um chamador novo:
`_separar_entradas` o usa para decidir se um fragmento inicia menção
(custo extra desprezível — uma passada de regex por fragmento).

### Regra de separação (a decisão de design)

Para cada fragmento de `celula.split(",")`, após `strip_edges` e descarte de
vazios, na ordem:

1. **Primeiro fragmento da célula** → inicia entrada (com ou sem código).
2. **Fragmento com código extraível** (`not extrair_codigos(fragmento).is_empty()`)
   → inicia entrada nova. Fragmento com código **nunca** é re-anexado — ele é o
   delimitador (edge case do card).
3. **Fragmento sem código, com entrada anterior** → re-anexado:
   `entradas[-1] += ", " + fragmento`. Vale tanto para entrada anterior com
   código (reconstitui o rótulo — ACs 1, 2, 5) quanto sem código (texto livre
   longo vira UM problema re-juntado — AC 4).

**Consequências verificáveis do modelo:**

- **Re-anexo nunca altera o conjunto de códigos da entrada.** O separador
  `", "` não pode formar código atravessando a fronteira: o regex
  (`\b[A-Za-z]{2,3}\s?\d{3,4}`) admite no máximo UM caractere de espaço entre
  letras e dígitos, e vírgula não é `\s` — `"AL, 0394"` não casa. Qualquer
  código do texto final estava inteiro no fragmento que iniciou a entrada.
- **Rótulo sem vírgulas** (formato atual do formulário) → um fragmento → uma
  entrada, byte a byte igual a hoje. É por isso que a suíte do 0002 passa sem
  edição (AC 6).
- **Reconstituição normaliza o espaçamento:** fragmentos re-juntados sempre com
  `", "`, então `"a ,b"` volta como `"a, b"` e vírgulas consecutivas (fragmento
  vazio descartado) colapsam. Aceito — o texto é para exibição, e `strip_edges`
  já não preservava o espaçamento original.
- **Residual do regex do 0002 continua residual (non-goal):** fragmento cujo
  único "código" é ruído de token curto isolado (`"Lab 101"` → `lab101`) contém
  candidato, logo **inicia menção** em vez de ser re-anexado. Mesmo limite
  deliberado do 0002, agora visível também na separação — congelado em teste de
  edge para não virar "descoberta" de novo.
- **Trade-off aceito (AC 5):** pedido em texto livre após vírgula numa menção
  com código (`"AL0400 Fundações, quero também a de concreto"`) é absorvido
  pela menção — o coordenador vê o texto completo na entrada, mas não recebe
  mais o alerta de "código inválido/ausente". Decisão da entrevista, travada em
  teste e documentada no MANUAL.

## Invariantes

1. **LGPD** — toca: testes só com dados fictícios já estabelecidos na suíte
   (matrículas `24099900xx`, nomes `Maria da Silva Souza` / `Joao Pereira
   Lima`). Nenhum log/print novo em produção, superfície de rede intocada
   (`baixar()` não muda — non-goal), nenhum arquivo novo (nada a acrescentar em
   `exclude_filter`; `test/*` já está lá).
2. **snake_case** — não toca: nenhuma chave nova; o texto re-juntado é dado do
   aluno, não identificador — preservado como está.
3. **Chaves multi-curso** — não toca (validação contra grades continua no
   módulo, non-goal).
4. **Leitura de arquivo no main/FileHandling** — não toca: `parse()` segue
   função pura `String → Dictionary`, sem `FileAccess` novo.
5. **UI pelas fachadas** — não toca (sem UI nova; a exibição no módulo é
   non-goal).

## Mapeamento AC → prova

Todos headless, em `test/unit/test_planilha_ajuste.gd` (GUT), testes **novos**
anexados após os do 0002, usando `_csv_respostas` e
`autofree(PlanilhaAjuste.new())` já existentes.

| AC do card | Método | Onde |
|---|---|---|
| AC1 — célula `"AL0394: Administração, T40;60;80, João Pereira Lima;"` → UMA menção (código `al0394`), zero problemas | headless | `test/unit/test_planilha_ajuste.gd::test_rotulo_com_virgulas_vira_uma_mencao` — asserta `incluir == ["AL0394: Administração, T40;60;80, João Pereira Lima;"]` e `excluir == []` (igualdade exata prova "uma menção e zero problemas": problema entraria na mesma lista) e `extrair_codigos(incluir[0]) == ["al0394"]` (o código pedido pelo AC) |
| AC2 — duas opções com código na mesma célula, cada uma com vírgulas no rótulo → DUAS menções com os códigos corretos | headless | `test/unit/test_planilha_ajuste.gd::test_duas_opcoes_com_virgulas_no_rotulo_viram_duas_mencoes` — célula com dois rótulos completos (códigos `al0394` e `al0401`); asserta os dois textos reconstituídos, na ordem, e o código extraível de cada um |
| AC3 — fragmento sem código no INÍCIO da célula continua problema visível | headless | `test/unit/test_planilha_ajuste.gd::test_fragmento_sem_codigo_no_inicio_continua_problema` — célula `"pedido sem codigo, AL0394: Administração, T40"`; asserta `incluir == ["AL0394: Administração, T40", "pedido sem codigo"]` (decisões antes dos problemas — ordem de `_montar_resposta`) |
| AC4 — célula só com texto livre com vírgulas → UM problema com o texto re-juntado | headless | `test/unit/test_planilha_ajuste.gd::test_celula_so_texto_livre_vira_um_problema_rejuntado` — célula na coluna **excluir** (prova de passagem que a regra vale para os dois lados); asserta a lista com exatamente o texto re-juntado |
| AC5 — travar em teste: texto livre após vírgula numa menção com código é absorvido (não alerta mais) | headless | `test/unit/test_planilha_ajuste.gd::test_texto_livre_apos_mencao_valida_e_absorvido` — célula `"AL0400 Fundações, quero também a de concreto"`; asserta `incluir` com UMA entrada (o texto completo absorvido) e comenta o trade-off aceito na entrevista |
| AC6 — suíte do 0002 verde sem alteração nos testes existentes | headless | `python .tools/run_tests.py` (suíte inteira, incluindo `test_formato_de_retorno_inalterado` com a fixture intocada); o diff do card não pode tocar nenhum teste existente nem `test/fixtures/ajuste_respostas.csv` — conferido no review (`godot-code-review`) |

Testes de edge (não são ACs, mas o card os nomeia — entram na mesma suíte):

| Edge case | Onde |
|---|---|
| Re-anexo compõe com a mesclagem do 0002 (mesmo rótulo com vírgulas incluído na 1ª resposta e excluído na 2ª → menção mais recente vence, uma entrada só em `excluir`) | `::test_reanexo_compoe_com_mesclagem_mais_recente` |
| Residual do regex: fragmento `"Lab 101"` contém candidato (`lab101`), logo inicia menção nova em vez de re-anexar — limite deliberado, non-goal tratá-lo | `::test_fragmento_residual_de_regex_inicia_mencao` — célula `"AL0400 Fundacoes, Lab 101"`; asserta `incluir == ["AL0400 Fundacoes", "Lab 101"]` |

Cobertos sem teste novo: "rótulo sem vírgulas não é dividido" (é exatamente a
suíte do 0002 inteira — AC6) e "fragmento com código nunca é re-anexado" (é o
que o AC2 asserta: o segundo rótulo vira menção nova, não cauda do primeiro).

Smoke: nenhum (conforme o card — todos os ACs são headless; `parse()` é pura).

## Riscos de contrato de dados

- **Retorno de `parse()`:** chaves e tipos idênticos (teste de formato do 0002
  congela). O *conteúdo* muda no cenário-alvo: entradas fantasma somem e textos
  de entrada agora podem conter vírgulas. Único consumidor
  (`situacao_alunos.gd`) trata texto arbitrário: `_classificar_codigos`
  re-extrai o código, e célula da grade/alerta exibem string qualquer.
- **`_assinatura_resposta` muda de valor** para respostas afetadas → o dedup de
  alertas por assinatura (estado de sessão, em memória) re-alerta uma vez após
  a atualização. Sem migração — mesmo comportamento aceito no 0002.
- **Mudança de comportamento visível (não regressão silenciosa):** o AC5 REMOVE
  um alerta que hoje existe (texto livre após vírgula em menção válida).
  Aceito na entrevista, travado em teste e documentado no MANUAL — não
  "corrigir" no futuro sem card próprio.
- **Limitação registrada (caminho multi-código):** fragmento re-anexado a uma
  menção com 2+ códigos desaparece do retorno por completo (nem menção nem
  problema), porque `_mesclar_lado` (card 0002) emite o código puro nesse
  caminho. Antes do 0003 esse fragmento aparecia como problema visível.
  Comportamento travado em
  `test_fragmento_reanexado_a_mencao_multi_codigo_perde_o_texto`; o ajuste é
  card futuro (item no `IDEAS.md`), pois a causa raiz está em `_mesclar_lado`,
  fora da camada deste card.
- **Nenhum renome.** Nenhum JSON de `arquivos/`, `base_config.json`, record do
  Kinto ou formato de `dados/` é tocado. O CSV do Forms é entrada externa — o
  programa se adapta a ele, e é exatamente o que este card faz.
- **LGPD:** as respostas seguem no fluxo já existente (download pelo
  coordenador, exibição no módulo). Nada novo sai do PC, nada novo em disco ou
  log; testes e spec só com dados fictícios.

## Ordem de implementação

Cada passo termina com `python .tools/run_tests.py` verde e
`python .tools/guardrails.py` limpo.

1. **AC1 vermelho primeiro:** `test_rotulo_com_virgulas_vira_uma_mencao`
   (falha no código atual: três entradas, duas viram problema). Implementar a
   regra de re-anexo em `_separar_entradas` — a forma mínima já é a final
   (`entradas.is_empty() or not extrair_codigos(limpa).is_empty()` decide
   iniciar; senão concatena `", "` na última). Verde.
2. **ACs 2–5:** escrever os quatro testes (alguns já nascem verdes com a regra
   do passo 1 — ainda assim entram, pois congelam comportamento que o card
   promete: em especial o trade-off do AC5). Verde.
3. **Edges:** `test_reanexo_compoe_com_mesclagem_mais_recente` e
   `test_fragmento_residual_de_regex_inicia_mencao`. Verde.
4. **Docstrings:** classe (trecho "separadas por vírgula"), `parse()` e o
   comentário `#` de `_separar_entradas` descrevendo a regra e o porquê
   (fragmento com código é o delimitador; `", "` não forma código na fronteira).
5. **MANUAL.md** (seção Modo Ajuste): frase sobre rótulo com vírgulas contar
   como uma menção e sobre o texto livre após vírgula ser absorvido pela menção.
6. **Portões finais:** `python .tools/guardrails.py`,
   `python .tools/run_tests.py` e
   `"C:/Program Files/Godot/Godot_console.exe" --headless --path . --editor --quit`.
   Conferir no diff que nenhum teste existente nem a fixture mudaram (AC6).
