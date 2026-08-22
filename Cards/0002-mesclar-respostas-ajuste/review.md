# Review — 0002-mesclar-respostas-ajuste

## Rodada 2

**Veredito: clean** (nenhum finding bloqueante)

### Escopo revisado

Diff completo contra HEAD (`git add -N .` + `git diff HEAD`):

- `standalone_scripts/io/planilha_ajuste.gd` — único arquivo de produção. Mudança desta rodada:
  `\b` acrescentado ao regex de `extrair_codigos` (linha 140) + comentários explicando o porquê
  (linhas 24-32, 183-190) + docstrings atualizadas.
- `test/unit/test_planilha_ajuste.gd` — 4 testes novos desde a rodada 1
  (`test_extrair_codigos_ignora_fragmento_de_palavra_como_sala_ou_turma`,
  `test_ruido_de_regex_em_sala_ou_turma_nao_vira_segundo_codigo`,
  `test_token_curto_isolado_antes_de_numero_ainda_vira_candidato`,
  `test_token_curto_isolado_via_parse_ainda_gera_entrada_fantasma`), total 13.
- `MANUAL.md`, `Cards/README.md`, `Cards/0002-mesclar-respostas-ajuste/card.md`,
  `Cards/0002-mesclar-respostas-ajuste/spec.md` — sem mudança desde a rodada 1 (spec já revisada;
  bookkeeping de status).
- `test/fixtures/ajuste_respostas.csv`, `test/fixtures/.gdignore`,
  `test/unit/test_planilha_ajuste.gd.uid` — sem mudança de conteúdo desde a rodada 1.
- Consumidor `scenes/Modulos/SituacaoAlunos/situacao_alunos.gd` reconferido (`_classificar_codigos`,
  `_processar_respostas_ajuste`, `_assinatura_resposta`) — continua não tocado pelo diff, contrato
  de `parse()` compatível.

### Portões

- `python .tools/guardrails.py` → limpo (baseline de 375 violações pré-existentes intacta, zero
  violação nova).
- `python .tools/run_tests.py` → 26/26 testes passando (13 de `test_planilha_ajuste.gd` + 13 da
  suíte existente).
- `Godot_console.exe --headless --path . --editor --quit` → sem erro de parser.

### Finding bloqueante da rodada 1: verificado corrigido

O fix escolhido foi **diferente** do sugerido no finding (que propunha nunca colapsar para código
nu em menção multi-código). Em vez disso, o dev atacou a raiz — acrescentou `\b` ao regex de
`extrair_codigos` — e manteve a emissão de código puro em menções multi-código genuinamente válidas
(com comentário explicando por que a alternativa sugerida foi descartada: duas cópias idênticas da
entrada fariam `_classificar_codigos` escolher sempre o mesmo primeiro candidato, perdendo em
silêncio o segundo código real — `test_mencao_multi_codigo_decide_por_codigo` prova isso).

Confirmado que resolve o cenário exato do finding:
`extrair_codigos("AL0400 - Fundacoes - Sala 302")` agora retorna só `["al0400"]` (rastreei a
regex manualmente: `\b` exige fronteira de palavra imediatamente antes das 2-3 letras; dentro de
"Sala" não há fronteira interna, e nenhuma posição de fronteira leva a um match de 2-3 letras
seguido de dígitos). `test_ruido_de_regex_em_sala_ou_turma_nao_vira_segundo_codigo` exercita
exatamente a entrada citada no finding via `parse()` completo e afirma que o resultado é a entrada
original inteira, não `["al0400", "ala302"]`.

**Residual aceito e agora testado**: um token curto isolado seguido de número
(`"Lab 101"`, `"em 2026"`) ainda satisfaz `\b` e ainda vira candidato — documentado no comentário do
regex (linhas 29-32) e travado por dois testes
(`test_token_curto_isolado_antes_de_numero_ainda_vira_candidato`,
`test_token_curto_isolado_via_parse_ainda_gera_entrada_fantasma`). Diferença chave em relação ao
cenário do finding original: o finding mirava o formato **padrão** que o próprio Forms produz
(`código - ementa - turma - nome`, com sala/turma anexada), que agora está coberto; o residual só se
manifesta em texto **livre digitado** pelo aluno (fora do padrão do Forms) — non-goal explícito do
card é validar contra a grade (isso ficaria no módulo, que tem o dado). Não é regressão silenciosa:
está testado e documentado, então não reabre o finding da rodada 1. Registro para o dev avaliar se
quer estreitar mais (não bloqueante — o card não pede isso e a spec já aceitava efeito colateral
parecido para o caso multi-código real).

### Finding não-bloqueante da rodada 1 (comentário vs. código do desempate mesmo-lado)

Não foi tocado nesta rodada — permanece válido como observação não-bloqueante (linhas 170-171
ainda descrevem "a primeira menção... é mantida" enquanto o código, ao reconstruir `substitui`, faz
a última menção de um código repetido vencer quando `ordem` é igual e `lado` bate; o impacto
observável continua nulo pois `_classificar_codigos` reextrai o código a partir do texto quando ele
é válido). Não bloqueia: nenhum AC ou edge case do card cobre duplicidade de código no mesmo
lado/mesma linha.

### Cobertura de AC (reconferida)

| AC | Prova | Falsificável? |
|---|---|---|
| AC1 (inclusões disjuntas → união) | `test_respostas_disjuntas_viram_uniao` | Sim. |
| AC2 (código troca de lado → menção mais recente, os dois sentidos) | `test_codigo_troca_de_lado_vence_mencao_mais_recente` | Sim. |
| AC3 (mesmo lado, 2 respostas → 1 entrada, texto mais recente) | `test_mesmo_lado_uma_entrada_com_texto_mais_recente` | Sim. |
| AC4 (entrada sem código mantida, dedup por texto normalizado) | `test_entrada_sem_codigo_mantida_com_dedup_normalizado` | Sim. |
| AC5 (formato de retorno inalterado) | `test_formato_de_retorno_inalterado` (fixture) | Sim — a fixture agora inclui uma matrícula com resposta múltipla real, além da de resposta única; a entrada `"T20"` continua não acionando o regex multi-código, mas esse caminho tem cobertura dedicada nos 4 testes novos, então deixou de ser um buraco. |

Edges do card: todos presentes e falsificáveis, incluindo os 4 testes novos que fecham a lacuna
apontada na rodada 1.

### LGPD

- Nenhum dado real no diff. Fixture e testes usam matrículas sintéticas e nomes fictícios
  (inclusive os 4 testes novos, que usam apenas strings de disciplina/sala, sem dado pessoal).
- Nenhum `FileAccess`/rede novos em produção; nenhum arquivo novo na raiz do projeto.

## Rodada 1

**Veredito: changes_required** (1 finding bloqueante)

### Escopo revisado

- `standalone_scripts/io/planilha_ajuste.gd` (`parse()`, `_mesclar_lado`, `_montar_resposta` —
  única mudança de produção).
- `test/unit/test_planilha_ajuste.gd` (9 testes novos) e `test/fixtures/ajuste_respostas.csv`
  (fixture fictícia).
- `MANUAL.md` §4.3 (nova subseção "Modo Ajuste").
- Bookkeeping de status em `card.md`/`Cards/README.md`.
- Consumidor `scenes/Modulos/SituacaoAlunos/situacao_alunos.gd` (`_verificar_planilha`,
  `_processar_respostas_ajuste`, `_classificar_codigos`, `_assinatura_resposta`) lido para
  confirmar que o contrato de `parse()` continua compatível — **não foi tocado** pelo diff.

### Portões

- `python .tools/guardrails.py` → limpo (baseline de 375 violações pré-existentes intacta, zero
  violação nova).
- `python .tools/run_tests.py` → 22/22 testes passando (9 novos + 13 da suíte existente).
- `Godot_console.exe --headless --path . --editor --quit` → sem erro de parser.

### Finding bloqueante

**`standalone_scripts/io/planilha_ajuste.gd:173-183`** — a divisão por código em menções
multi-código emite texto puro do regex, inclusive quando o "segundo código" é ruído do próprio
regex sobre uma cauda de texto livre comum (sala/turma/prédio), gerando alerta de "problema"
falso a cada resposta desse formato e, mesmo no caso válido, descartando o texto descritivo
(turma/professor) que o coordenador precisa quando a classificação falha.

- **Cenário de falha concreto** (confirmado rodando o regex isoladamente):
  `extrair_codigos("AL0400 - Fundacoes - Sala 302")` → `["al0400", "ala302"]`. `"ala302"` é falso
  positivo do regex `[A-Za-z]{2,3}\s?\d{3,4}` casando com a cauda `"Sala 302"` (mesmo padrão dispara
  em `"Turma 101"` → `rma101`, `"predio 1102"` → `dio1102` — formatos comuns em resposta de Forms
  com sala/turma anexada ao nome da disciplina). Como `codigos.size() == 2`, `_mesclar_lado` passa a
  tratar como duas menções separadas, cada uma emitindo **o código nu** como `texto` (linha 176:
  `entrada if codigos.size() == 1 else codigo`). `parse()` devolve `["al0400", "ala302"]` em vez da
  entrada original inteira. Em `situacao_alunos.gd::_classificar_codigos` (linha 1257-1278),
  `"ala302"` não bate em nenhuma grade → vira `problema` → dispara alerta novo ao coordenador
  (`_processar_respostas_ajuste`, dedupado só por assinatura de sessão) numa resposta perfeitamente
  válida. Mesmo quando o código extra é ruído inofensivo, o código válido também perde o texto
  original (`"AL0400"` nu em vez de `"AL0400 - Fundacoes - Sala 302"`), então se ele por algum
  motivo cair em `problemas` (código não bate em nenhuma grade conhecida), o coordenador não vê mais
  turma/professor para investigar.
- **Por que passou despercebido pelos testes**: `test_mencao_multi_codigo_decide_por_codigo` usa
  `"al0400 e al0401"` — dois códigos reais, sem cauda de texto livre, então nunca aciona o regex
  ruidoso. A fixture do AC5 usa `"AL0400 - Fundacoes - T20 - Maria da Silva Souza"`: `T20` tem só 1
  letra (regex exige 2-3), então por sorte não casa uma segunda vez — o AC5 ("resposta única sai
  idêntica ao comportamento atual") está sendo verificado contra uma entrada que estruturalmente não
  consegue disparar o defeito.
- **Contraste com a spec**: a spec (§ "Consequências verificáveis do modelo") aceita
  explicitamente que "um código inválido dentro de menção multi-código... passa a aparecer como
  problema — melhora, não regressão", mas o exemplo considerado era um segundo código real (typo de
  disciplina). Aqui o gatilho é ruído do próprio regex sobre texto de preenchimento comum
  (sala/turma/prédio), o que torna o caso não um edge case raro, mas potencialmente o formato
  predominante das respostas reais do formulário — inverte o trade-off que a spec aceitou.
- **Conserto**: não colapsar para o código nu quando `codigos.size() > 1`; manter
  `var texto: String = entrada` sempre (remover a ramificação da linha 176). A decisão de
  merge continua por código (uma entrada em `decisoes` por código, como hoje), só que cada cópia
  carrega o texto completo da entrada original. `_classificar_codigos` já sabe lidar com isso: ele
  re-extrai os candidatos da entrada e prefere o que bate na grade do aluno — o dedup
  `elif not achou in codigos` do próprio módulo colapsa as cópias quando os dois códigos apontam
  para o mesmo `achou`. Isso elimina o alerta falso do ruído de regex e preserva o texto descritivo
  quando a classificação falhar de verdade.
- **blocking: true** — regressão em caminho sem teste (categoria 3 da skill): a fixture do AC5
  evita estruturalmente o padrão que dispara o defeito, então nenhum AC cobre esse comportamento,
  e o cenário (sala/turma no texto) é comum, não exótico.

### Finding não-bloqueante

**`standalone_scripts/io/planilha_ajuste.gd:161-162` (comentário) / 180-181 (lógica)** — o
comentário de `_mesclar_lado` afirma "Dentro da mesma linha e mesmo lado, a primeira menção de um
código repetido é mantida (não há mais recente possível)", mas isso só vale para o lado `incluir`.
Para o lado `excluir`, o desempate testa o literal `lado == "excluir"` (não "lado oposto ao atual"),
então dentro do mesmo `_mesclar_lado` (mesmo lado, mesma `ordem`), uma segunda menção do mesmo
código **sobrescreve** a primeira — o oposto do que o comentário promete.
  - **Cenário**: célula `excluir` de uma única resposta com duas menções do mesmo código inválido em
    textos diferentes, ex. `"AL9999 turma A, AL9999 turma B"` → a decisão registrada é a da 2ª
    menção (`"AL9999 turma B"`), não a 1ª como o comentário diz.
  - **Impacto real**: baixo/cosmético hoje — para código válido, `_classificar_codigos` descarta o
    `texto` armazenado e reextrai o código, então a divergência só aparece se a entrada acabar em
    `problemas` (código não reconhecido em nenhuma grade), e mesmo aí é só qual dos dois textos
    quase-idênticos aparece no alerta. Fica mais visível depois do fix do finding bloqueante acima,
    que passa a preservar o texto completo com mais frequência.
  - **Conserto sugerido**: trocar `lado == "excluir"` por uma comparação que capture apenas o caso
    documentado (mesma linha, lados **diferentes** — que já é garantido pela ordem de chamada
    incluir-antes-excluir em `parse()`), ou ajustar o comentário para descrever o comportamento
    real. Não bloqueia porque nenhum AC ou edge case do card cobre duplicidade de código dentro do
    mesmo lado/mesma linha, e o impacto observável hoje é nulo para o caminho feliz.
  - **blocking: false**.

### Cobertura de AC

| AC | Prova | Falsificável? |
|---|---|---|
| AC1 (inclusões disjuntas → união) | `test_respostas_disjuntas_viram_uniao` | Sim — reverter a mesclagem (voltar a last-wins) faz `resposta["incluir"]` conter só `["al0401"]`. |
| AC2 (código troca de lado → menção mais recente, os dois sentidos) | `test_codigo_troca_de_lado_vence_mencao_mais_recente` | Sim — testa nos dois sentidos (incluir→excluir e excluir→incluir); âncora `al0300`/`al0400` prova que não é apenas last-wins pela última linha. |
| AC3 (mesmo lado, 2 respostas → 1 entrada, texto mais recente) | `test_mesmo_lado_uma_entrada_com_texto_mais_recente` | Sim — também prova que sobrescrever `decisoes[codigo]` não move a posição no Dictionary (ordem de saída). |
| AC4 (entrada sem código mantida, dedup por texto normalizado) | `test_entrada_sem_codigo_mantida_com_dedup_normalizado` | Sim — varia caixa/acento e afirma que só a 1ª ocorrência é mantida. |
| AC5 (formato de retorno inalterado) | `test_formato_de_retorno_inalterado` (fixture) | Parcialmente — cobre chaves/tipos e o caso de resposta única de forma robusta, mas a fixture usa uma entrada (`"...T20..."`) que estruturalmente não aciona o regex multi-código (ver finding bloqueante); não é falso positivo do AC em si, mas deixa o comportamento do finding acima sem rede de segurança. |

Edges do card: `test_excluir_prevalece_na_mesma_resposta`, `test_celula_vazia_posterior_nao_apaga`,
`test_mencao_multi_codigo_decide_por_codigo`, `test_matricula_com_espacos_mescla` — todos presentes
e falsificáveis (confirmados por leitura + os testes exercitam exatamente a regra descrita).

### LGPD

- Fixture (`test/fixtures/ajuste_respostas.csv`) e testes usam matrículas sintéticas
  (`2409990011`, `2409990022`) e nomes fictícios (`Maria da Silva Souza`, `Joao Pereira Lima`),
  conforme AGENTS.md. Nenhum dado real encontrado no diff.
- Nenhum `FileAccess`/rede novos em produção; `test/fixtures/.gdignore` presente (pasta nova sem
  dado sensível, mas já protegida por convenção do repositório).
- Nenhum arquivo novo na raiz do projeto (não há o que acrescentar em `exclude_filter`).

### Outras observações (não-finding)

- `int(atual["ordem"])` na linha 180 é um cast redundante (o valor já é `int` por construção) —
  não é finding desta revisão (estilo/redundância, não muda comportamento; e a skill pede para não
  gastar finding em algo que não muda o código de forma observável).
- Docstring pública de `parse()` (linhas 71-78) foi reescrita corretamente, descrevendo a
  mesclagem e o desempate "mesma resposta → exclusão prevalece"; consistente com o comportamento
  implementado (exceto pela ressalva do finding bloqueante acima, que é sobre menção multi-código,
  não sobre o desempate documentado).
