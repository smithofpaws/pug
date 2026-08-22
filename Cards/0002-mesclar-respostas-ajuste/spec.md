# Spec — 0002-mesclar-respostas-ajuste

Card: `Cards/0002-mesclar-respostas-ajuste/card.md`.
Objetivo: `PlanilhaAjuste.parse()` deixa de ser last-wins por matrícula e passa a
**mesclar** todas as respostas do mesmo aluno, com conflito resolvido pela menção
mais recente (ordem das linhas do CSV = cronológica do Forms).

## Camadas tocadas

| Arquivo | Por quê |
|---|---|
| `standalone_scripts/io/planilha_ajuste.gd` | Única mudança de produção: a mesclagem acontece dentro de `parse()` (laço das linhas 95–107 hoje) mais dois helpers privados. O card fixa a camada (`layers: [standalone_scripts/io]`); `parse()` já é lógica pura (recebe `String`, sem I/O — o `HTTPRequest` é só do `baixar()`, intocado), então já vive na camada testável headless. Não criar classe nova: o parser é coeso e a extração fragmentaria sem ganho. |
| `test/unit/test_planilha_ajuste.gd` | Novo. Todos os ACs são headless via `parse()` real (cobre também detecção de colunas e o parser CSV). |
| `test/fixtures/ajuste_respostas.csv` | Novo. Fixture fictícia para o teste integrado de formato (AC5). |
| `MANUAL.md` | Uma frase na seção 4.3 (Situação de Alunos / Modo Ajuste) documentando a política de respostas múltiplas — comportamento visível ao coordenador. |

Nada muda em `scenes/` (o `situacao_alunos.gd` já consome listas arbitrárias de
entradas) nem em `main.gd`.

## Contrato público novo ou alterado

```gdscript
func parse(csv: String) -> Dictionary
```

- **Assinatura inalterada; semântica alterada.** Continua retornando
  `{ "ok": bool, "respostas": Array, "erro": String }`, cada item de `respostas` =
  `{ "matricula": String, "incluir": Array[String], "excluir": Array[String] }`.
  Nenhuma chave nova, renomeada ou removida.
- **Quem chama:** `situacao_alunos.gd::_verificar_planilha()` (único consumidor).
- **O que garante:** uma entrada por matrícula, com `incluir`/`excluir` resultado
  da mesclagem de TODAS as respostas daquela matrícula (regras abaixo). Ordem de
  `respostas` = primeira aparição da matrícula (inalterada). Erros de cabeçalho e
  planilha vazia: comportamento atual intacto.
- **O que assume:** linhas do CSV em ordem cronológica (garantia do Forms —
  non-goal ler o carimbo de data/hora); matrícula já normalizada por
  `strip_edges` (mantido).
- **Docstring de `parse()` reescrita** — hoje ela promete "mantendo a resposta
  mais recente", que deixa de ser verdade.

Helpers privados novos (comentário `#`, não `##` — regra do guardrails para
privados):

```gdscript
func _mesclar_lado(estado: Dictionary, entradas: Array[String], lado: String, ordem: int) -> void
func _montar_resposta(estado: Dictionary) -> Dictionary
```

`extrair_codigos()` não muda de contrato, mas passa a ser chamado também de
dentro do `parse()` (hoje só o módulo o chama).

### Modelo de mesclagem (a decisão de design)

A mesclagem é **por código de disciplina**, não por resposta inteira — os edge
cases do card caem naturalmente dessa estrutura. Estado por matrícula:

```gdscript
{
    "matricula": String,
    "decisoes": Dictionary,           # codigo -> { "lado": String, "texto": String, "ordem": int }
    "problemas_incluir": Dictionary,  # chave normalizada -> texto original da 1a ocorrencia
    "problemas_excluir": Dictionary,  # idem
}
```

**Processamento** — para cada linha `i` (1..n), na matrícula da linha, processa a
célula `incluir` e DEPOIS a `excluir` (ordem importa para o desempate). Para cada
entrada de `_separar_entradas`:

1. `codigos := extrair_codigos(entrada)`.
2. **Sem código extraível** → problema do lado: registra em
   `problemas_<lado>[chave]` se a chave for inédita, onde
   `chave := _sem_acento(entrada)` (reuso do helper existente: minúsculas + sem
   acento; a entrada já chega com `strip_edges` de `_separar_entradas`). Primeira
   ocorrência define o texto exibido.
3. **Com código(s)** → para cada `codigo`, uma menção
   `{ "lado": lado, "texto": t, "ordem": i }`, onde `t` = a própria `entrada` se
   `codigos.size() == 1`, senão o **próprio `codigo`** (menção multi-código emite
   uma entrada por código; reusar o texto inteiro faria o módulo re-extrair o
   código errado — `_classificar_codigos` pega só o primeiro candidato válido por
   entrada). Regra de substituição sobre `decisoes[codigo]` existente:

   ```
   substitui := mencao.ordem > atual.ordem
       or (mencao.ordem == atual.ordem and mencao.lado == "excluir")
   ```

   - `ordem` maior → menção mais recente vence (lado E texto) — ACs 2 e 3;
   - mesma linha, lados diferentes → **excluir prevalece** (decisão conservadora
     do card; funciona porque incluir é processado antes de excluir na linha);
   - inexistente → grava.

**Reconstrução** (`_montar_resposta`): percorre `decisoes` em ordem de inserção
(Dictionary do Godot preserva inserção, inclusive em overwrite — posição estável
= primeira menção do código) e anexa `texto` à lista do `lado` decidido; depois
anexa os valores de `problemas_incluir`/`problemas_excluir` ao respectivo lado.
Não há dedup na reconstrução: cada código emite exatamente uma entrada, e os
problemas já foram dedupados por chave normalizada.

**Consequências verificáveis do modelo** (é isso que os testes de edge provam):

- Célula vazia posterior não apaga nada: sem menção, sem mudança de decisão;
- União de inclusões disjuntas: decisões independentes por código;
- Resposta única passa intacta (menções single-código preservam o texto original,
  na ordem original) — é o que mantém o AC5 verdadeiro;
- Menção multi-código dividida entre lados: cada código sai no seu lado, como
  código puro, sem ambiguidade para o módulo. Efeito colateral aceito e
  documentado: um código inválido dentro de menção multi-código, que hoje é
  descartado em silêncio pelo módulo, passa a aparecer como problema (texto = o
  código) — melhora, não regressão.

## Invariantes

1. **LGPD** — toca: fixtures e testes só com dados fictícios (matrículas
   sintéticas tipo `2409990011`, nomes tipo `Maria da Silva Souza`, nunca CSV
   real). Nenhum log/print novo em produção; superfície de rede intocada
   (`baixar()` não muda); nenhum arquivo novo na raiz (nada a acrescentar em
   `exclude_filter`). `test/*` já está no `exclude_filter` dos presets.
2. **snake_case** — toca de leve: chaves novas do estado interno em snake_case;
   códigos normalizados para minúsculas por `extrair_codigos` (já existente). O
   texto livre do aluno é dado, não identificador — preservado como está.
3. **Chaves multi-curso** — não toca (validação contra grades continua no módulo,
   non-goal do card).
4. **Leitura de arquivo no main/FileHandling** — não toca: `parse()` segue
   recebendo `String`; nenhum `FileAccess` novo em produção. O teste lê a fixture
   com `FileAccess`, permitido pelo guardrails (`FILESYSTEM_ALLOWED_PREFIXES`
   inclui `test/`).
5. **UI pelas fachadas** — não toca (sem UI nova, non-goal).

## Mapeamento AC → prova

Todos headless, em `test/unit/test_planilha_ajuste.gd` (GUT). O teste instancia
com `autofree(PlanilhaAjuste.new())` — `parse()` não precisa da árvore — e monta
CSVs inline com um helper `_csv_respostas(linhas)` usando cabeçalho realista do
Forms (`Carimbo de data/hora,Matrícula,Disciplinas a incluir,Disciplinas a excluir`,
células com vírgula entre aspas), exceto o AC5, que lê a fixture.

| AC do card | Método | Onde |
|---|---|---|
| AC1 — inclusões disjuntas → união | headless | `test/unit/test_planilha_ajuste.gd::test_respostas_disjuntas_viram_uniao` |
| AC2 — incluído na 1ª, excluído na 2ª → só `excluir` (e vice-versa) | headless | `test/unit/test_planilha_ajuste.gd::test_codigo_troca_de_lado_vence_mencao_mais_recente` (asserta os dois sentidos) |
| AC3 — mesmo lado em 2 respostas → uma entrada, texto mais recente | headless | `test/unit/test_planilha_ajuste.gd::test_mesmo_lado_uma_entrada_com_texto_mais_recente` |
| AC4 — entrada sem código mantida, dedup por texto normalizado | headless | `test/unit/test_planilha_ajuste.gd::test_entrada_sem_codigo_mantida_com_dedup_normalizado` (dedup provado com variação de caixa/acento; asserta que a entrada chega no retorno) |
| AC5 — formato de retorno inalterado | headless | `test/unit/test_planilha_ajuste.gd::test_formato_de_retorno_inalterado` (fixture `test/fixtures/ajuste_respostas.csv`; asserta o conjunto exato de chaves do topo e de cada item, tipos das listas, e que resposta única sai idêntica ao comportamento atual) |

Testes de edge (não são ACs, mas o card os nomeia — entram na mesma suíte):

| Edge case | Onde |
|---|---|
| Mesmo código nos dois lados na mesma resposta → excluir prevalece | `::test_excluir_prevalece_na_mesma_resposta` |
| Célula vazia posterior não apaga | `::test_celula_vazia_posterior_nao_apaga` |
| Menção com vários códigos → princípio por código (split entre lados) | `::test_mencao_multi_codigo_decide_por_codigo` |
| Matrícula com espaços nas pontas mescla com a sem espaços | `::test_matricula_com_espacos_mescla` |

Smoke: nenhum (conforme o card — sem AC visual).

## Riscos de contrato de dados

- **Retorno de `parse()`:** chaves e tipos idênticos (AC5 congela isso em teste).
  O *conteúdo* muda quando há respostas múltiplas — era exatamente o defeito.
  Único consumidor é `situacao_alunos.gd`, que já trata listas arbitrárias;
  `_assinatura_resposta` muda de valor para respostas múltiplas, mas o dedup de
  alertas por assinatura é estado de sessão (memória), sem migração.
- **Nenhum renome.** Nenhum JSON de `arquivos/`, `base_config.json`, record do
  Kinto ou formato de `dados/` é tocado.
- **Emissão de código puro** para menções multi-código: entrada nova possível no
  retorno (ex.: `"al0400"` em vez do texto original). O módulo a trata pelo
  caminho normal (`extrair_codigos` reencontra o código). Superfície: no máximo o
  alerta de problema do terminal exibe o código em vez do texto original — sem
  dado pessoal novo.
- **LGPD:** as respostas dos alunos seguem no fluxo já existente (download pelo
  coordenador, exibição no módulo). Nada novo sai do PC, nada novo é gravado em
  disco ou log.

## Ordem de implementação

Cada passo termina com `python .tools/run_tests.py` verde e
`python .tools/guardrails.py` limpo.

1. **Fixture + teste de formato (AC5) primeiro**, contra o código atual: criar
   `test/fixtures/ajuste_respostas.csv` (fictícia, com uma matrícula de resposta
   única e cabeçalho real do Forms) e `test/unit/test_planilha_ajuste.gd` com
   `test_formato_de_retorno_inalterado`. Deve passar **antes** da mudança — é a
   rede de segurança da regressão de formato.
2. **AC1** (`test_respostas_disjuntas_viram_uniao`, vermelho) → introduzir o
   estado por matrícula (`decisoes` + `_mesclar_lado` + `_montar_resposta`) com o
   mínimo: menção grava/substitui por `ordem`. Verde.
3. **AC3** (texto da menção mais recente) e **AC2** (troca de lado, os dois
   sentidos). A regra de substituição completa entra aqui. Verde.
4. **Edge da mesma resposta** (`test_excluir_prevalece_na_mesma_resposta`) —
   desempate `ordem igual → excluir`. Verde.
5. **AC4 + dedup** (`test_entrada_sem_codigo_mantida_com_dedup_normalizado`) —
   ramo dos problemas com chave `_sem_acento`. Verde.
6. **Edges restantes**: célula vazia, multi-código (emissão do código puro),
   matrícula com espaços. Verde.
7. **Docstring** de `parse()` reescrita descrevendo a mesclagem;
   frase no `MANUAL.md` §4.3 (Modo Ajuste): respostas múltiplas do mesmo aluno
   são mescladas e, em conflito por disciplina, vale a menção mais recente
   (na mesma resposta, a exclusão prevalece).
8. **Portões finais:** `python .tools/guardrails.py`,
   `python .tools/run_tests.py` e
   `"C:/Program Files/Godot/Godot_console.exe" --headless --path . --editor --quit`
   (também gera o `.uid` do teste novo — commitar junto).
