---
id: 0005-validacao-coerencia-dados-curriculares
title: Validação de coerência dos dados curriculares
status: ready
origin: novo (sessão de 2026-08-25, a partir de defeitos reais encontrados no alec-data)
layers: [standalone_scripts, scenes/main.gd]
interviewed: true
---

# 0005 - Validação de coerência dos dados curriculares

## Goal
O programa passa a apontar, no carregamento, inconsistências **semânticas** nos
arquivos de `arquivos/grades/`, `arquivos/equivalencias/` e
`arquivos/cargaexigida/` — pré-requisito que aponta para código inexistente,
buraco na numeração de `prerequisito*`, pré-requisito impossível de cumprir na
ordem da grade, `semestre` divergente da `posicao_grade` e núcleo sem carga
exigida correspondente. Hoje o `JsonValidator` confere apenas **tipos**
(`nome`, `semestre` e `ch` são String), e todos os defeitos abaixo passam por
ele em silêncio.

Cada um dos casos foi encontrado de verdade nos dados durante a sessão que
originou este card — não são hipóteses.

## Non-goals
- **Não corrige nada.** Só reporta; a correção do dado é decisão do coordenador,
  no repositório canônico do curso.
- **Não bloqueia o carregamento.** Segue o precedente do `JsonValidator`: o
  `main.gd` ignora o retorno e carrega assim mesmo (`validador.call(dados)`).
- **Não cria UI.** A saída é `push_warning` com prefixo, como o `JsonValidator`.
  Levar isso ao Terminal do programa foi considerado e ficou de fora: a
  validação roda antes de existir Terminal, e a fiação para guardar e despejar
  depois é outro card.
- Não valida o conteúdo pedagógico (se a CH está certa, se o pré-requisito faz
  sentido) — só a coerência interna dos arquivos entre si.
- Não audita as atas do curso contra os dados. Isso é trabalho de dado, fora do
  pipeline.

## Acceptance criteria
- [ ] Grade com `prerequisito0` apontando para código que não existe na própria
      grade é reportada, nomeando disciplina e código -- verify: `headless`
- [ ] Grade com `prerequisito0`, `prerequisito1` e `prerequisito3` (buraco no
      `2`) é reportada -- verify: `headless`
- [ ] Grade em que uma disciplina exige pré-requisito do **mesmo** semestre ou
      de semestre **posterior** é reportada -- verify: `headless`
- [ ] A dupla `prerequisitoN` + `corequisitoN` para o mesmo código **não** é
      reportada pela regra acima -- verify: `headless`
- [ ] Disciplina cujo `semestre` difere de `posicao_grade[0]` é reportada
      -- verify: `headless`
- [ ] Disciplina **sem** `posicao_grade` (complementar, `semestre: "0"`) não é
      reportada por nenhuma das duas regras que dependem de semestre
      -- verify: `headless`
- [ ] Equivalência apontando para código ausente na grade correspondente é
      reportada -- verify: `headless`
- [ ] Equivalência cujo lado é o placeholder `0000` ("sem grade") não é
      reportada -- verify: `headless`
- [ ] Núcleo usado por alguma disciplina da grade sem chave correspondente no
      `cargaexigida/` da mesma grade é reportado -- verify: `headless`
- [ ] Chave do `cargaexigida/` que não corresponde a núcleo nenhum **não** é
      reportada: `estagio`, `tcc`, `praticas` e `acg` são categorias agregadas,
      não núcleos de disciplina -- verify: `headless`
- [ ] Grade, equivalência ou carga exigida ausente é no-op silencioso, sem erro
      -- verify: `headless`
- [ ] Rodando sobre os arquivos reais de `arquivos/`, a validação emite
      `push_warning` para os defeitos conhecidos listados em "Edge cases" e para
      nenhum outro -- verify: `headless`

## Edge cases

**Defeitos reais que hoje existem nos dados** (a validação deve acusar todos, e
nenhum deles é corrigido por este card):

- `alec_2023.json`: `al5022` (Metodologia de Trabalho Científico) tem
  `prerequisito0: "ch 50%"` — texto livre num campo que em todo o resto do
  arquivo contém código de disciplina. Provável candidato a `cargarequisito`.
- `cargaexigida/alec_2010.json` usa a chave `agc`; a `alec_2023.json` usa `acg`.
  Nenhum `.gd` lê essas chaves pelo nome — são iteradas genericamente —, então a
  divergência não quebra nada visivelmente, mas soma no denominador de
  `CalculoCargaHoraria.percentagem_curso` sem nunca somar no numerador.
- `cargaexigida/alem_2023.json` é **JSON inválido** (vírgula sobrando antes do
  `}`): não carrega hoje, em silêncio. Este card não conserta o arquivo, mas a
  validação precisa se comportar bem quando o parse falhou e o dicionário chega
  vazio.

**Outros:**

- Grade sem `cargaexigida` correspondente é situação normal e já tratada pelo
  programa ("Carga horária exigida não cadastrada"): no-op, não inconsistência.
- Disciplina com `semestre: "0"` (complementar) não participa das regras de
  ordem nem de `posicao_grade`.
- O par `prerequisitoN` + `corequisitoN` é o idioma da grade para "pode cursar
  junto se ainda não passou" (`al0385`, `al0142`) — exceção legítima, não
  defeito.
- Um curso pode ter grade sem nenhum campo `nucleo` nas obrigatórias (é o caso
  da `alec_2023`, onde só as 46 complementares têm `nucleo`): a regra de núcleo
  não deve reportar as 71 disciplinas sem o campo.

## Smoke scenarios
Nenhum. Todos os ACs são `headless` — a saída é `push_warning`, sem UI. As
fixtures ficam em `test/fixtures/`, com códigos e nomes fictícios; nenhuma
delas usa dado de aluno.
