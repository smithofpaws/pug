# alec-data

Fonte única (canônica) dos dados curriculares do curso **Engenharia Civil** (UNIPAMPA,
Alegrete), usados por múltiplos projetos. Contém apenas dados — sem código.

## Estrutura

Organizado por tipo, espelhando as pastas de `arquivos/` do pug. As chaves de arquivo seguem
as convenções do projeto (`<cod_curso>_<versao>` e `<origem>-<destino>`):

- `grades/` — catálogo de componentes por versão do PPC:
  - `alec_2023.json` — currículo **Engenharia Civil 2023** (PPC 2023, Tabelas 5 e 6).
  - `alec_2010.json` — currículo anterior (PPC 2010).
  - Dicionário chaveado pelo código da disciplina (minúsculo, ex.: `al0362`); cada entrada tem
    `nome`, `semestre`, `ch` (total), `posicao_grade`, pré/co-requisitos e `nucleo`.
- `cargaexigida/` — carga horária exigida por versão do PPC (`alec_2010.json`, `alec_2023.json`).
- `equivalencias/` — equivalências **intracurso** (entre versões do próprio alec):
  `alec_2010-alec_2023.json`, `alec_2023-alec_2010.json` (direcionais, `<origem>-<destino>`).
  Equivalências **entre cursos** (ex.: alec↔alea) NÃO ficam aqui — pertencem a dois cursos e
  são mantidas localmente no consumidor.

## Consumidores

Este repositório é incorporado nos projetos abaixo via **`git subtree`** (os arquivos ficam
committados dentro de cada consumidor — clones normais funcionam offline):

- **pug** (ferramenta Godot) — prefixo `arquivos/compartilhado/alec/`; o loader varre
  `grades/`, `cargaexigida/` e `equivalencias/` e mescla com os dados locais do programa.
- **ppc2023** (documento Typst) — prefixo `data/`; lido por `template.typ`
  (`json("data/grades/alec_2023.json")`). Usa apenas a grade; as demais pastas são ignoradas.

## Fluxo de edição

1. Edite o(s) arquivo(s) aqui, faça commit e push.
2. Em cada consumidor, propague:
   `git subtree pull --prefix=<prefixo> https://github.com/smithofpaws/alec-data.git main --squash`
   (prefixo: `data` no ppc2023; `arquivos/compartilhado/alec` no pug)

Editar sempre aqui (sentido único). O JSON deve ser **estritamente válido** (sem vírgula
final): o Typst tem parser rígido; o Godot é tolerante, mas mantemos o padrão estrito.
