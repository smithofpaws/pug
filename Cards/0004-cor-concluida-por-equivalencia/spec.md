# Spec — 0004-cor-concluida-por-equivalencia

Card: `Cards/0004-cor-concluida-por-equivalencia/card.md`.
Objetivo: na grade de integralização da Situação Alunos, disciplina concluída
sob o código de outra grade (via equivalência, respeitando a regra de
disciplina dividida de `AnaliseGrades.alvo_completo`) recebe o mesmo dourado de
"cursada" (`lista_cores["cursada"]`, token `cursada` da `PaletaSemantica` —
`GOLDENROD`). Hoje `AnaliseHistorico.disciplinas_concluidas` devolve só os
códigos brutos do histórico, então o alvo equivalente fica sem cor, embora a
hachura de distantes (`disciplinas_distantes`) já o reconheça como concluído.

## Camadas tocadas

| Arquivo | Por quê |
|---|---|
| `standalone_scripts/analise/analise_grades.gd` | Ganha a função pura nova `concluidas_por_equivalencia` (ao lado de `alvo_completo` e `para_o_codigo_qual_a_equivalencia`, que ela reutiliza — "a mesma via" pedida pelo card). Docstring do `[param cursadas]` de `montar_grade_curricular` ganha uma frase dizendo que a lista pode vir somada aos alvos de `concluidas_por_equivalencia`. **Nenhuma função existente muda de assinatura ou comportamento** — em especial `disciplinas_distantes` fica byte a byte igual (ver "Decisão: por que a hachura não é refatorada"). |
| `scenes/Modulos/SituacaoAlunos/situacao_alunos.gd` | Helper privado `_cursadas_com_equivalencia` e uso dele nos DOIS pontos que montam a grade curricular: `_analisar_matricula` (hoje linha ~335) e `_atualizar_grade_curricular` (hoje linha ~999). O módulo já recebe `equivalencias` injetadas pelo main (`var equivalencias`, linha 38) — **`main.gd` não muda** (compromisso do card). |
| `test/unit/test_analise_grades.gd` | Arquivo NOVO (primeira suíte de `AnaliseGrades`), GUT, com fixtures sintéticas inline (grade + equivalências fictícias, cursos `zz`/`yy` inexistentes). Cobre ACs 1–4 e os edges do card. |
| `MANUAL.md` | Seção "Grade curricular" (Situação dos Alunos, ~linha 146–148): uma frase dizendo que disciplina concluída sob o código de outra grade (aproveitamento por equivalência) aparece com a cor de cursada — complementando a frase existente de que ela não é hachurada. |

Fora do diff: `main.gd`, `grade_curricular.gd` (componente só renderiza a matriz
que recebe), `planejamentooferta.gd` e Situação de Disciplinas (non-goals do
card: grades agregadas, sem cursadas por aluno), `base_config.json` e qualquer
arquivo de `arquivos/` (nenhum token de cor novo, nenhuma equivalência editada).

## Contrato público novo ou alterado

Uma função pública nova, em `AnaliseGrades`:

```gdscript
func concluidas_por_equivalencia(cursadas: Array[String], equivalencias: Dictionary, versao_grade: String) -> Array[String]
```

- **O que faz:** para cada código de `cursadas`, obtém os alvos na grade
  `versao_grade` via `para_o_codigo_qual_a_equivalencia` e devolve **apenas os
  alvos cujo grupo está completo** segundo `alvo_completo`, usando como
  `codigos_presentes` o conjunto dos próprios `cursadas` (em minúsculas). Isto
  é: alvo entra somente quando TODAS as fontes de algum grupo foram
  **concluídas** — não basta constar no histórico (critério do AC2; mais
  estrito que o da hachura, de propósito — ver decisão abaixo).
- **Retorno:** somente os alvos NOVOS, em minúsculas, sem duplicatas, **excluindo
  os que já estão em `cursadas`** (idempotência: `cursadas + retorno` nunca
  duplica nem "rebaixa" um alvo já cursado diretamente). Sem equivalência
  aplicável à `versao_grade` (dicionário vazio ou só chaves com outro destino),
  retorna `[]` sem erro — `determinar_aproveitaveis` já filtra por destino e
  devolve lista vazia (AC3, no-op silencioso; é assim que o programa fica quando
  o curso não tem arquivo de equivalência).
- **Quem chama:** `situacao_alunos.gd::_cursadas_com_equivalencia` (produção) e
  a suíte nova (testes). Nenhum outro chamador neste card.
- **O que garante:** pureza (nenhum `FileAccess`, nenhum `GV`, nenhum nó);
  determinismo (ordem: iteração de `cursadas`, depois a ordem dos alvos de cada
  fonte); trata valor de equivalência `String` e `Array` (1:N) porque delega
  aos primitivos existentes; case-insensitive nos códigos de `cursadas`
  (normaliza com `to_lower()` antes do lookup, como `disciplinas_distantes` já
  faz na linha 239 — as chaves dos JSONs de equivalência são minúsculas por
  convenção snake_case).
- **O que assume do chamador:** `cursadas` é a saída de
  `AnaliseHistorico.disciplinas_concluidas` (códigos concluídos — aprovado ou
  dispensado); `equivalencias` é o dicionário injetado pelo main (uma chave
  `<origem>-<destino>` por arquivo de `arquivos/equivalencias/`);
  `versao_grade` é chave canônica `<cod_curso>_<versao>`.

Helper privado novo no módulo (não é contrato público, listado por completude):

```gdscript
func _cursadas_com_equivalencia(cursadas: Array[String]) -> Array[String]
```

Devolve `cursadas + analise_grades.concluidas_por_equivalencia(cursadas,
equivalencias, _grade_ativa)` (cópia — não muta o argumento). Usado apenas como
argumento `cursadas` de `montar_grade_curricular` nos dois call sites. A
variável `cursadas` original continua sendo a passada para `_codigos_distantes`
(inalterado) e para o restante do relatório — a previsão de formatura
(`caminho_critico_formatura`, `cursadas_prev`) fica fora do escopo (o card é só
a cor da grade).

`montar_grade_curricular` **não muda de assinatura nem de corpo**: ela já pinta
qualquer código de `cursadas` com `lista_cores["cursada"]` DEPOIS de mapear as
condições (linhas 118–120), o que dá a precedência de cursada sobre condições
que o AC4 exige. A expansão acontece no chamador, preservando os outros
consumidores (`planejamentooferta.gd` passa `[]`).

### Decisão: por que a hachura não é refatorada

`disciplinas_distantes` continua com sua expansão interna própria, que usa
`codigos_historico` (TODOS os códigos do histórico, inclusive matrículas em
aberto) como conjunto de presença. Os dois critérios são deliberadamente
diferentes:

- **Dourado (novo):** todas as fontes do grupo **concluídas** (`cursadas`) —
  disciplina dividida cursada pela metade não fica dourada (AC2).
- **Não-hachurado (existente):** alguma fonte concluída + todas as fontes do
  grupo **presentes no histórico** — dividida com metade concluída e metade em
  curso não é "distante" (e o alvo tampouco entra em
  `matriculado_agora_aproveitamento`, ver comentário em `situacao_alunos.gd`
  ~linha 466; a célula fica sem dourado e sem hachura, o que é o estado correto).

O invariante do card — **célula dourada nunca hachurada** — vale por
monotonicidade, não por compartilhar o conjunto de presença: `cursadas` ⊆
`codigos_historico` (ambos derivam dos mesmos `dados` do histórico, ver
`disciplinas_concluidas` e `_codigos_distantes`), e `alvo_completo` é monótona
no conjunto de presença (mais códigos presentes nunca desfazem um grupo
completo). Logo dourado ⇒ `alvo_completo(historico)` ⇒ o alvo está em
`definidas` ⇒ não é distante. "A mesma via" do card é atendida no nível certo:
cor e hachura usam os MESMOS primitivos (`para_o_codigo_qual_a_equivalencia` +
`alvo_completo` + `determinar_aproveitaveis`), então um arquivo de equivalência
novo, um grupo dividido novo ou uma rota alternativa (OR entre grupos) afetam
as duas na mesma direção. O invariante é congelado em teste
(`test_alvo_dourado_nunca_hachurado`). Refatorar `disciplinas_distantes` para
chamar a função nova mudaria o comportamento da hachura no caso
dividida-parcial — exatamente o que os non-goals proíbem.

## Invariantes

1. **LGPD** — toca de leve: a suíte nova usa exclusivamente fixtures sintéticas
   inline (grade e equivalências fictícias, códigos `zz0001`/`zz9001`, cursos
   `zz`/`yy` que não existem; nenhuma matrícula, nenhum nome). O roteiro manual
   (`smoke.md`) instrui o dev a usar os dados locais da máquina, mas o arquivo
   versionado não cita matrícula/nome real nenhum — passos genéricos
   ("selecione um aluno que..."). Nenhum PNG versionado (decisão do card).
   Nenhum arquivo novo na raiz do projeto (nada a acrescentar em
   `exclude_filter`; `test/*` já está no filtro de todos os presets). Nenhum
   print/log novo em produção.
2. **snake_case** — respeitado: `concluidas_por_equivalencia`,
   `_cursadas_com_equivalencia`, códigos minúsculos internamente; nenhum texto
   de UI novo (a cor é a única saída visual).
3. **Cursos e chaves canônicas** — respeitado por construção: a função nova só
   enxerga equivalências pelas chaves `<origem>-<destino>` via
   `determinar_aproveitaveis` (comparação estrita do destino, sem falso
   positivo entre cursos de mesma versão); intracurso e entre cursos passam
   pelo mesmo caminho (edge do card, congelado em teste). Nenhuma lista de
   cursos duplicada.
4. **Leitura de arquivo no main; módulo recebe injetado** — respeitado: zero
   I/O novo. A função é pura; o módulo usa a variável `equivalencias` que o
   main já injeta (`main.gd` intocado). Curso sem arquivo de equivalência =
   dicionário sem a chave = retorno vazio, sem crash (AC3).
5. **UI pelas fachadas** — respeitado: a cor vem do token `cursada` já
   existente em `PaletaSemantica.tokens_lista()` (injetado como `lista_cores`);
   nenhum tooltip novo (non-goal explícito), nenhum diálogo, nenhum token novo.

## Mapeamento AC → prova

ACs 1–4 headless em `test/unit/test_analise_grades.gd` (GUT, arquivo novo),
rodados por `python .tools/run_tests.py`. Fixtures inline no teste:

- Grade `zz_2023`: `zz0001` (`posicao_grade [1,1]`), `zz0002` (`[1,2]`),
  `zz0003` (`[2,1]`), com `nome` fictício.
- Equivalências: `{"zz_2010-zz_2023": {"zz9001": "zz0001", "zz9002":
  ["zz0002"], "zz9003": "zz0003", "zz9004": "zz0003"}, "yy_0000-zz_2023":
  {"yy0001": "zz0002"}}` — cobre 1:1, valor em Array (1:N), disciplina
  dividida (duas fontes → `zz0003`) e equivalência entre cursos.

| AC do card | Método | Onde |
|---|---|---|
| AC1 — cursada fonte com equivalência para a grade ativa → o alvo entra na lista | headless | `test/unit/test_analise_grades.gd::test_fonte_cursada_gera_alvo_concluido` — `concluidas_por_equivalencia(["zz9001"], EQUIV, "zz_2023") == ["zz0001"]`; segundo assert com a fonte em maiúsculas (`["ZZ9001"]`) prova a normalização `to_lower` |
| AC2 — disciplina dividida: o alvo só entra quando TODAS as fontes foram cursadas | headless | `::test_disciplina_dividida_exige_todas_as_fontes` — com `["zz9003"]` retorna `[]`; com `["zz9003", "zz9004"]` retorna `["zz0003"]` |
| AC3 — grade ativa sem arquivo de equivalência → retorno vazio, sem erro (no-op) | headless | `::test_sem_equivalencia_retorna_vazio` — `equivalencias = {}` → `[]`; e `equivalencias` contendo só chave de outro destino (`"zz_2010-yy_2020"`) → `[]` (o filtro estrito de destino é o mesmo caminho do arquivo ausente) |
| AC4 — `montar_grade_curricular` com as cursadas expandidas pinta o alvo com `lista_cores["cursada"]`, precedência sobre condições | headless | `::test_grade_pinta_alvo_expandido_de_cursada` — monta com `disc_cursaveis = {"matriculavel": ["zz0001"]}` (alvo também numa condição), `cursadas = ["zz9001"] + concluidas_por_equivalencia(...)` (composição real das duas funções) e `lista_cores = {"cursada": "COR_CURSADA_TESTE", "matriculavel": "COR_MATRICULAVEL_TESTE"}`; asserta `matriz[0][1]["cor_central"] == "COR_CURSADA_TESTE"` |
| AC5 — visual: aluno com disciplina cursada sob código de outra grade vê a célula dourada na grade de integralização | manual | Roteiro em `Cards/0004-cor-concluida-por-equivalencia/smoke.md` (sem PNG versionado, conforme o card). Passos: rodar o programa com os dados locais, abrir Situação dos Alunos, selecionar um aluno da grade nova que concluiu disciplina sob código da grade antiga (o relatório do terminal lista "Disciplinas cursadas fora da grade atual" — usar uma cujo alvo tem grupo completo), conferir que a célula do alvo está dourada (mesma cor das demais cursadas) e sem hachura; contraprova: um alvo de disciplina dividida cursada pela metade continua SEM dourado. Nenhuma matrícula/nome real vai para o `smoke.md`. |

Edges do card (não são ACs, mas o card os nomeia — mesma suíte):

| Edge case | Onde |
|---|---|
| Alvo já cursado diretamente: expansão idempotente (não duplica, não rebaixa) | `::test_alvo_ja_cursado_nao_duplica` — `concluidas_por_equivalencia(["zz9001", "zz0001"], ...)` retorna `[]`, então `cursadas + retorno` não tem duplicata e o alvo segue "cursada" |
| Célula dourada nunca hachurada como distante | `::test_alvo_dourado_nunca_hachurado` — grupo dividido completo (`["zz9003", "zz9004"]`): o alvo `zz0003` está na expansão E não está em `disciplinas_distantes(...)` chamada com `codigos_historico` superset (as duas fontes + um código em curso qualquer) |
| Equivalência intracurso e entre cursos pelo mesmo caminho | `::test_equivalencia_entre_cursos` — fonte `yy0001` (chave `yy_0000-zz_2023`) → `["zz0002"]`; o valor em Array da fixture prova de passagem o suporte 1:N |

Cobertos sem teste dedicado: "programa nunca crasha por arquivo ausente" é o
AC3 (arquivo ausente = chave ausente no dicionário injetado — o main já não
cria chave para arquivo que não existe); "cor e hachura usam a mesma expansão"
é o par AC1/AC2 + `test_alvo_dourado_nunca_hachurado` (mesmos primitivos,
invariante congelado).

## Riscos de contrato de dados

- **Nenhum renome, nenhuma chave nova.** JSONs de `arquivos/` (grades,
  equivalências), `base_config.json`, records do Kinto e formatos de `dados/`
  ficam intocados. A feature só LÊ as equivalências já injetadas, pelos
  primitivos que já as leem.
- **Formato da célula da grade inalterado:** `montar_grade_curricular` continua
  emitindo as mesmas chaves (`cor_central`, `texto_central`, ...); o consumidor
  (`grade_curricular.gd`) não distingue de onde veio a cor. Mudança visível é
  só a pretendida: células antes sem cor passam a dourado.
- **Tipos do JSON:** valor de equivalência pode ser `String` ou `Array`
  (1:N) — tratado pelos primitivos reutilizados e coberto pela fixture. Não há
  números envolvidos (códigos são String), então a armadilha float/int do JSON
  não se aplica aqui.
- **Case dos códigos:** chaves de equivalência são minúsculas por convenção;
  `disciplinas_concluidas` já devolve minúsculas. A função normaliza com
  `to_lower()` mesmo assim (mesma defesa de `disciplinas_distantes`), porque
  `para_o_codigo_qual_a_equivalencia` compara com `==` estrito.
- **LGPD:** o dado novo em tela é uma COR sobre célula de disciplina — nenhum
  dado de aluno novo aparece, nada sai do PC, nada vai a log ou exportação
  nova. Testes e spec só com códigos fictícios; roteiro manual sem dados reais
  no arquivo versionado.

## Ordem de implementação

Cada passo termina com `python .tools/run_tests.py` verde e
`python .tools/guardrails.py` limpo.

1. **ACs 1–3 vermelhos primeiro:** criar `test/unit/test_analise_grades.gd` com
   as fixtures e `test_fonte_cursada_gera_alvo_concluido`,
   `test_disciplina_dividida_exige_todas_as_fontes`,
   `test_sem_equivalencia_retorna_vazio` (falham: função não existe).
   Implementar `concluidas_por_equivalencia` em `analise_grades.gd` (após
   `alvo_completo`), forma mínima: montar `presentes` a partir de `cursadas`,
   iterar fontes → alvos → filtrar por `alvo_completo` → excluir já-cursadas e
   duplicatas. Verde.
2. **AC4 e edges:** `test_grade_pinta_alvo_expandido_de_cursada`,
   `test_alvo_ja_cursado_nao_duplica`, `test_alvo_dourado_nunca_hachurado`,
   `test_equivalencia_entre_cursos` (nascem verdes com o passo 1 — entram para
   congelar precedência, idempotência e o invariante cor/hachura). Verde.
3. **Fiação do módulo:** `_cursadas_com_equivalencia` em `situacao_alunos.gd` e
   troca do argumento `cursadas` nos dois call sites de
   `montar_grade_curricular` (`_analisar_matricula` e
   `_atualizar_grade_curricular`); `_codigos_distantes` continua recebendo a
   lista crua. Validar com o parser real:
   `"C:/Program Files/Godot/Godot_console.exe" --headless --path . --editor --quit`
   (módulo de cena não tem cobertura headless; `--check-only` isolado é falso
   positivo, não usar).
4. **Docstrings:** a da função nova (formato `##` com `[param]`/`[method]`,
   citando `alvo_completo` e o critério "todas as fontes cursadas") e a frase
   no `[param cursadas]` de `montar_grade_curricular`.
5. **MANUAL.md:** frase na seção "Grade curricular" (aproveitamento por
   equivalência aparece com a cor de cursada, disciplina dividida só com todas
   as partes concluídas).
6. **AC5:** escrever `Cards/0004-cor-concluida-por-equivalencia/smoke.md` com o
   roteiro manual (sem dados reais) e executá-lo na máquina do dev.
7. **Portões finais:** `python .tools/guardrails.py`,
   `python .tools/run_tests.py` e o parser headless de novo; conferir no diff
   que `disciplinas_distantes`, `montar_grade_curricular` (corpo), `main.gd` e
   os arquivos de `arquivos/` não mudaram.
