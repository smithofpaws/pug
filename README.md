# alec-data

Fonte única (canônica) do catálogo de componentes curriculares usado por múltiplos
projetos. Contém apenas dados — sem código.

## Conteúdo

- `alec_2023.json` — catálogo do currículo **Engenharia Civil 2023** (UNIPAMPA, Alegrete).
  Dicionário chaveado pelo código da disciplina (minúsculo, ex.: `al0362`); cada entrada tem
  `nome`, `semestre`, `ch` (total), `posicao_grade`, pré/co-requisitos e `nucleo`. Referência de
  verdade: `PPC Engenharia Civil 2023.docx` (Tabelas 5 e 6).

## Consumidores

Este repositório é incorporado nos projetos abaixo via **`git subtree`** (o arquivo fica
committado dentro de cada consumidor — clones normais funcionam offline):

- **ppc2023** (documento Typst) — prefixo `data/`; lido por `template.typ` (`json("data/alec_2023.json")`).
- **pug** (ferramenta Godot) — prefixo `arquivos/grades_shared/`; varrido pelo loader de grades.

## Fluxo de edição

1. Edite o(s) arquivo(s) aqui, faça commit e push.
2. Em cada consumidor, propague:
   `git subtree pull --prefix=<prefixo> <url-deste-repo> main --squash`

Editar sempre aqui (sentido único). O JSON deve ser **estritamente válido** (sem vírgula final):
o Typst tem parser rígido; o Godot é tolerante.
