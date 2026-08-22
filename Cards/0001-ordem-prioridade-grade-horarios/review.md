# Review — 0001-ordem-prioridade-grade-horarios

## Rodada 1

**Verdito: clean** (nenhum finding bloqueante)

### Escopo revisado

- `standalone_scripts/analise/analise_horarios.gd` (`CONDICOES_AJUSTE`, `ordenar_condicoes`,
  `_prioridade_condicao`, aplicação em `determinar_horarios`).
- `test/unit/test_analise_horarios.gd` (8 testes novos).
- `MANUAL.md` § 4.3.
- Bookkeeping de status em `card.md`/`Cards/README.md`.
- Confirmado que `scenes/Modulos/SituacaoAlunos/situacao_alunos.gd` e
  `scenes/Modulos/SituacaoDisciplinas/situacao_disciplinas.gd` **não** foram tocados (`git diff
  HEAD --stat`), conforme a decisão de design da spec.

### Portões

- `python .tools/guardrails.py` → limpo (baseline de 375 violações pré-existentes intacta, zero
  violação nova).
- `python .tools/run_tests.py` → 13/13 testes passando (8 novos + 5 da suíte existente).
- `Godot_console.exe --headless --path . --editor --quit` → sem erro de parser.

### Cobertura de AC

| AC | Prova | Falsificável? |
|---|---|---|
| AC1 (ordem canônica com entrada embaralhada) | `test_determinar_horarios_concatena_na_ordem_canonica` | Sim — `condicoes` é passado embaralhado; se a ordenação não fosse aplicada, as asserções de posição por `find()` falhariam. |
| AC2 (ajuste antes de tudo) | `test_ordenar_condicoes_poe_ajuste_primeiro` | Sim — testa `ordenar_condicoes` isolada com entrada embaralhada. |
| AC3 (desconhecida no fim, `[shake]` preservado) | `test_condicao_desconhecida_fica_no_fim_com_shake` | Sim — verifica posição **e** a marcação `[shake rate=20.0 level=10]...[/shake]`. |
| AC4 (visual, modo ajuste) | Roteiro manual na spec | Fora do escopo desta rodada (verify: `manual`). |

Testes de suporte também presentes e válidos: estabilidade para desconhecidas
(`test_ordenar_condicoes_e_estavel_para_desconhecidas` — pega a armadilha do `sort_custom` não
estável, que a spec exige contornar), não-mutação da entrada
(`test_ordenar_condicoes_nao_muta_entrada`, `test_determinar_horarios_nao_muta_condicoes_do_chamador`),
degradação com base vazia (`test_ordenar_condicoes_com_base_vazia_nao_crasha`), e o teste de
regressão específico do efeito colateral removido
(`test_determinar_horarios_nao_poda_condicoes_entre_chamadas` — duas chamadas sequenciais
reusando o mesmo array `condicoes` por referência, como `situacao_alunos.gd` faz na prática).

### Verificação adicional: efeito colateral da não-mutação nos dois chamadores de produção

A spec afirma "nenhum chamador depende da poda" que `_preparar_horarios` fazia (`remove_at`) no
array `condicoes` do chamador. Tracei os dois pontos de chamada de produção para confirmar:

- **`situacao_disciplinas.gd:248/260`** (`_disciplina_isolada`): `disc_cursaveis` vem de
  `_condicoes_discentes.get(matricula, {})`, e `_condicoes_discentes` é populado por
  `AnaliseCurricular.disciplinas_cursaveis`, que pré-inicializa **todas** as 12 condições
  canônicas (`for a in condicoes.size(): cursaveis[condicoes[a]] = []`, linha 55-56 de
  `analise_curricular.gd`) para todo aluno presente no dicionário. Como a matrícula usada nesse
  loop vem de iterar as chaves do próprio `_condicoes_discentes` (via
  `AnaliseCurricular.discentes_disciplina`), `disc_cursaveis` nunca é `{}` nesse caminho — logo
  `horarios_txt_condicao.keys()` sempre contém a condição buscada e o filtro de poda em
  `_preparar_horarios` nunca removia nada aqui, antes ou depois da mudança. O guard `if condicao
  in $"%Horarios".lista_condicoes_verdadeiras:` (linha 247) lê o mesmo array em todas as
  iterações do loop, sem diferença de comportamento.
- **`situacao_alunos.gd:328`** (fora do Modo Ajuste): mesma fonte (`_condicoes_discentes.get(matricula,
  {})`) com a mesma garantia de chaves completas — poda também nunca disparava no caminho feliz.
  No Modo Ajuste (linhas 304-322), `disc_cursaveis_grade` mantém as 12 chaves originais e ganha
  `ajuste_incluir`/`ajuste_excluir`; `condicoes_grade` é sempre subconjunto dessas chaves — poda
  também não dispara.
- A poda só disparava (e corrompia o array por referência) quando `disc_cursaveis` chegava vazio
  (matrícula ausente de `_condicoes_discentes`) — exatamente o cenário do teste de regressão
  `test_determinar_horarios_nao_poda_condicoes_entre_chamadas`. Não há caminho de produção onde a
  remoção do efeito colateral troque conteúdo exibido (nem em `situacao_disciplinas.gd`, que o
  card explicitamente limita a "só muda a ordenação"); o comportamento observável muda apenas para
  melhor no caso de corrupção cross-aluno que já era um bug latente.

Conclusão: a claim da spec se sustenta sob inspeção dos dois chamadores reais; nenhum finding
bloqueante decorre da mudança de não-mutação.

### Outras observações (não-finding)

- `_prioridade_condicao` já existe como nome de função privada em
  `scenes/Modulos/PlanejamentoHorario/Complementos/choques_alunos.gd`, mas é uma heurística
  diferente (substring, para ordenar exibição de choques), em arquivo/domínio não tocado por este
  card — não é duplicação a resolver aqui.
- `base_config.json:condicoes` já está na ordem canônica exigida pelo card (conferido via
  `python -c "json.load(...)"`), então a garantia de "ordem 2-4 = ordem do base_config" (invariante
  3 da spec) é satisfeita sem duplicar a lista em código.
