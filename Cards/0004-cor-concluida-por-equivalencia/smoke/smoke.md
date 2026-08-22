# Smoke — 0004-cor-concluida-por-equivalencia

Executado em 2026-08-22. Godot 4.7.1, GL Compatibility.
Ambiente de dados: nenhum — o programa **não foi executado** nesta rodada (ver
"Log" abaixo). Os quatro ACs headless têm fixtures fictícias inline (grade
`zz_2023`, cursos `zz`/`yy` inexistentes) em `test/unit/test_analise_grades.gd`;
o AC5 é visual e fica `manual`, sem PNG (decisão do próprio card — ver
"Smoke scenarios" em `card.md`).

| AC | Método | Cenário | Evidência | Veredito |
|---|---|---|---|---|
| AC1 | headless | Fonte cursada (`zz9001`) com equivalência 1:1 para a grade ativa vira alvo concluído; repetido com a fonte em maiúsculas para provar `to_lower` | `test_analise_grades.gd::test_fonte_cursada_gera_alvo_concluido` | passou |
| AC2 | headless | Disciplina dividida (`zz9003`+`zz9004` → `zz0003`): uma fonte só não libera o alvo, as duas liberam | `test_analise_grades.gd::test_disciplina_dividida_exige_todas_as_fontes` | passou |
| AC3 | headless | Sem arquivo de equivalência (`{}`) e com equivalência de outro destino → retorno vazio, sem erro | `test_analise_grades.gd::test_sem_equivalencia_retorna_vazio` | passou |
| AC4 | headless | `montar_grade_curricular` com `cursadas` expandida pinta o alvo (`zz0001`, também presente como condição `matriculavel`) com `lista_cores["cursada"]` — precedência sobre condição | `test_analise_grades.gd::test_grade_pinta_alvo_expandido_de_cursada` | passou |
| AC5 | manual | Aluno real com disciplina cursada sob código de outra grade — célula dourada na grade de integralização | roteiro abaixo | não verificado |

Edge cases da mesma suíte (não são ACs, mas provados junto): idempotência
(`test_alvo_ja_cursado_nao_duplica`), invariante "dourado nunca hachurado"
(`test_alvo_dourado_nunca_hachurado`), equivalência entre cursos + valor em
Array/1:N (`test_equivalencia_entre_cursos`) — todos verdes.

## Por que não houve captura de tela

O card já decide isto na seção "Smoke scenarios": nenhum PNG, porque o único AC
visual (AC5) exige selecionar um aluno por clique — sem harness de input neste
projeto — e `dados/saida/` desta máquina tem `hist.csv`/`email.csv` **reais**.
Rodar o programa aqui para tirar print, mesmo sem publicar a imagem, ainda
arriscaria expor matrícula/nome real no relatório impresso no terminal
("Disciplinas cursadas fora da grade atual") capturado por qualquer ferramenta
de debug. Por isso esta rodada não inicializou o programa: a prova visual fica
inteiramente com o roteiro manual, executado pelo dev na própria máquina.

## Log

Não houve execução do jogo (Godot em modo `--write-movie` ou MCP `run_project`)
nesta rodada — logo não há log de runtime para comparar com baseline. A
asserção de "sem regressão" vem de dois portões que **leem e parseiam todo o
projeto**, incluindo o módulo de cena tocado (`situacao_alunos.gd`, sem
cobertura headless de outra forma):

- `python .tools/run_tests.py`: 41/41 testes passando (suíte GUT completa),
  incluindo os 7 testes novos de `test_analise_grades.gd`. 0 falhas.
- `"C:/Program Files/Godot/Godot_console.exe" --headless --path . --editor --quit`:
  saída limpa — 0 linhas `SCRIPT ERROR`, `Parse Error`, `push_error` ou
  `push_warning`. Este comando carrega e resolve todos os scripts do projeto
  (diferente do `--check-only` isolado, que dá falso positivo em autoload —
  ver `AGENTS.md`), então cobre a fiação de `_cursadas_com_equivalencia` nos
  dois call sites de `montar_grade_curricular` mesmo sem teste GUT direto ali.
- `python .tools/guardrails.py`: limpo (375 violações pré-existentes toleradas
  pela baseline; nenhuma violação nova).

Sem regressão nos três portões.

## LGPD

Nenhum PNG foi produzido nesta rodada — nada a inspecionar por dado pessoal.
`dados/saida/` desta máquina contém `hist.csv` e `email.csv` reais; é
justamente por isso que o programa não foi executado e que o AC5 permanece
`manual`, sem captura versionada (decisão já registrada no `card.md` e na
`spec.md`). Este arquivo não cita matrícula, nome ou e-mail real nenhum.

## Roteiro manual — AC5

1. Rode o programa (editor ou executável) com `dados/` populado normalmente.
2. Abra **Situação dos Alunos**.
3. No menu de aluno, escolha um aluno de uma grade que tenha arquivo de
   equivalência para uma grade anterior (ex.: um aluno em `alec_2023` que
   migrou de `alec_2010`). O relatório impresso no terminal lista a seção
   "Disciplinas cursadas fora da grade atual" — escolha um aluno cujo
   histórico tenha um código dessa lista cujo grupo de equivalência esteja
   **completo** (disciplina 1:1, ou dividida com todas as partes cursadas).
4. Na grade curricular exibida, localize a célula do código-alvo (o código
   da grade ATUAL equivalente à disciplina cursada na grade antiga).
   - **Esperado:** célula na mesma cor dourada das demais disciplinas
     cursadas, e SEM hachura.
5. **Contraprova:** se o histórico do aluno (ou de outro aluno) tiver uma
   disciplina dividida (duas ou mais fontes mapeando para o mesmo alvo) com
   apenas PARTE das fontes cursada, confirme que o alvo NÃO fica dourado
   (nem hachurado, se as fontes cursadas parciais também estiverem no
   histórico — ver decisão da spec sobre os dois critérios distintos de
   dourado vs. hachura).

### Resultado

- [ ] Passo 4 confirmado: célula dourada, sem hachura.
- [ ] Passo 5 confirmado: divisão parcial não pinta de dourado.

## Não foi possível verificar

- **AC5** exige clique (selecionar aluno) — sem harness de input neste
  projeto — e os dados reais desta máquina impedem captura versionada mesmo
  se houvesse. Roteiro acima entregue ao dev; nenhum sucesso foi declarado em
  seu lugar.

## Nota para o dev

O finding não-bloqueante do `review.md` (Rodada 1, item 1) registra que
reverter só a fiação em `situacao_alunos.gd` — apagar
`_cursadas_com_equivalencia` e as duas trocas de argumento — mantém os 7
testes novos verdes, porque `test_grade_pinta_alvo_expandido_de_cursada`
compõe `concluidas_por_equivalencia` + `montar_grade_curricular` diretamente,
sem passar pelos call sites reais. Ou seja: **o roteiro manual acima é a única
prova de que a correção do bug chega à tela** — não é burocracia opcional. O
card não deve ir para `done` (nem os checkboxes de AC5 marcados) até o dev
rodar os 5 passos e preencher o "Resultado" acima.
