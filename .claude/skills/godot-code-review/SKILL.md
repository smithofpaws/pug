---
name: godot-code-review
description: Revisa código GDScript do PUG (Godot 4.7) buscando o que exige julgamento — vazamento de dado pessoal (LGPD), quebra de contrato de dados nos JSONs/CSVs compartilhados, regressão em caminho sem teste, violação das convenções multi-curso, AC do card sem cobertura real e duplicação de utilitário existente — e devolve findings estruturados com campo `blocking` que fecha o laço do pipeline. Não repete o que o linter já cobre: estilo, tipagem e violação de camada são do guardrails.py. Use esta skill SEMPRE que for revisar, auditar ou dar parecer sobre código .gd deste projeto, inclusive quando o pedido vier como "dá uma olhada nisso", "isso está certo?", "revisa aí" ou ao avaliar um diff antes de commitar.
---

# Code review — PUG

Revisa GDScript com saída estruturada. O campo `blocking` é o que faz o laço do
pipeline terminar; sem ele o `while` do workflow não sabe parar.

---

## O que NÃO é sua responsabilidade

O `python .tools/guardrails.py` já reprovou o código antes de ele chegar aqui. Ele
cobre, deterministicamente:

estilo e formatação · tipagem estática · tabs · `##` em membro privado · ordem de
seções · `get_node()` · `preload().new()` · `FileAccess` fora do main/FileHandling ·
`tooltip_text` fora da DicaFlutuante

**Não gaste finding nisso.** Se você está escrevendo "use tabs em vez de espaços",
ou o linter está desligado (verifique) ou você está queimando a rodada de review em
ruído. O review existe para o que uma máquina não decide.

(As violações históricas congeladas na baseline também não são finding — são
dívida registrada, não descoberta sua.)

---

## O que revisar, em ordem de importância

### 1. Vazamento de dado pessoal (LGPD)

O repositório e as releases são públicos; o programa processa dados de alunos e
docentes. Procure:

- Nome real, matrícula ou e-mail em arquivo **versionável**: teste, fixture,
  card, spec, comentário, exemplo de manual, PNG de smoke.
- Dado pessoal saindo do PC por caminho novo: rede além do Kinto autenticado,
  exportação fora de `exportacoes/`, log gravado em lugar versionado.
- Arquivo gitignorado novo **na raiz do projeto** sem entrada no
  `exclude_filter` de **todos** os presets de `export_presets.cfg` — o
  `all_resources` embute no PCK tudo que o Godot enxerga (foi assim que o token
  do Kinto vazou na release 1.0.0). Pasta nova com dado sensível precisa de
  `.gdignore`.
- Credencial em arquivo sincronizado: senha/token pertence a `user://`
  (por máquina), nunca a `config_usuario.json` (sincronizado nos 3 PCs).

### 2. Quebra de contrato de dados

Nenhum guardrail pega isso:

- Chave renomeada ou com **semântica** mudada em JSON de `arquivos/` (grades,
  cargas, equivalências) — consumidores externos (repositórios de curso,
  `ppc2023`) leem default em silêncio.
- Mudança de formato em `base_config.json` que deixa órfão o override de
  `config_usuario.json` (merge por chave).
- Mudança no record do Kinto que clientes de outros coordenadores não entendem.
- Suposição nova sobre `dados/` (hist.csv, planejamento.csv, horarios.txt) — o
  formato vem do GURI/Google; o programa se adapta, nunca exige.
- Comparação de tipos do JSON: número carrega como float (turma `40.0` vs `40`);
  comparar por `str()` é o defeito clássico — exija `int()`.

### 3. Regressão em caminho sem teste

Onde a mudança altera comportamento que nenhum teste cobre. Descreva o cenário
concreto de falha — entradas e estado que produzem o resultado errado — não a
categoria. Atenção especial a: equivalências entre grades (inclusive disciplina
dividida — o alvo só é concedido com TODAS as fontes), linhas duplicadas do
hist.csv, aluno matriculado sob código de outra grade, arquivo ausente
(o módulo degrada sem crash?).

### 4. Violação das convenções multi-curso

- Curso hardcoded onde deveria vir de `base_config.json:cursos`.
- Chave fora do padrão `<cod_curso>_<versao>` / `<origem>-<destino>`.
- Identidade de oferta por codigo+semestre em vez de `chave_planejamento`.
- Valor canônico snake_case misturado com rótulo formatado (falta o par
  `_retorno` no `SeletorAvancado`).

### 5. AC do card sem cobertura real

Para cada AC marcado `headless` na spec: existe teste? Ele **falha** se a
implementação for revertida? Um teste que passa em ambos os casos não cobre o AC.

### 6. Simplificação e reuso

Código novo que duplica algo existente. Os candidatos frequentes:
`GeneralFunctions` (split, remover_acentos, avancar_semestre, merge_profundo,
ajustar_contraste), `Dialogos`, `PaletaSemantica`, `StatusBar`, helpers do
`Terminal`, `SeletorAvancado`, `JsonValidator`, `DicaFlutuante`.

---

## Regra anti-ruído

Reporte só o que muda o código. Cada finding precisa de:

- `arquivo:linha` — a âncora exata.
- Um **modo de falha concreto**: entradas ou estado → resultado errado. Se você não
  consegue escrever o cenário, é uma impressão, não um finding.
- O conserto — o que fazer, não só o que está errado.

Não reescreva estilo já conforme. Não sugira refactor que a spec não pediu. Não
transforme preferência em finding.

## O que é bloqueante

`blocking: true` só para: vazamento LGPD, quebra de contrato de dados, regressão,
violação multi-curso que grava dado errado, ou AC descoberto.

`blocking: false` para: simplificação, reuso, nomenclatura de método novo,
cobertura de teste desejável mas não exigida por AC.

A distinção importa porque o pipeline só repete a rodada quando há bloqueante.
Marcar uma preferência como bloqueante gasta uma rodada inteira de dev + gate +
review.

---

## Formato de saída obrigatório

```json
{
  "findings": [
    {
      "file": "standalone_scripts/analise/analise_grades.gd",
      "line": 214,
      "severity": "high",
      "blocking": true,
      "summary": "disciplinas_concluidas nao expande equivalencias intercurso",
      "failure_scenario": "Discente aprovado em al0383 (alec_2023) com equivalencia para al0067 (alec_2010): a grade da alec_2010 mostra al0067 sem cor de cursada, e a previsao de formatura conta a disciplina como pendente.",
      "fix": "Expandir os codigos do historico pelo mapa de equivalencias antes de cruzar com a grade, reusando o mesmo caminho que disciplinas_distantes ja usa."
    }
  ],
  "verdict": "changes_required"
}
```

`verdict` é `"clean"` quando nenhum finding tem `blocking: true`, senão
`"changes_required"`.

Anexe os findings da rodada a `Cards/<id>/review.md`, com o número da rodada.

## Antes de entregar

- Nenhum finding é sobre algo que o `guardrails.py` já cobre.
- Todo finding tem cenário de falha concreto, não categoria.
- Nenhuma preferência está marcada como bloqueante.
- Se o veredito é `clean`, você conferiu os ACs do card um a um — não só leu o diff.
- Você procurou dado pessoal no diff **inteiro**, inclusive em testes e fixtures.
