# Handoff — 2026-08-25 (fim)

## Onde parei
Começou como faxina do `IDEAS.md` e virou correção de dado curricular. A
decisão de grade aprovada em 2025 (SEI 1848924) estava aplicada pela metade no
`alec-data`; foi completada, publicada e sincronizada para o pug. O card 0005
nasceu daí e está `ready`, **não executado**.

## Card ativo
Nenhum em execução. **0005 está `ready`** (validação de coerência dos dados
curriculares) — aprovado pelo dev, nunca passou pelo pipeline.

## Feito nesta sessão
Tudo commitado. Duas partes.

**1. Faxina (commits `bbd20e3`, `ea15b0a`, `98f0289`, `367a021`, todos pushados)**
- `IDEAS.md`: removidos os dois `[x]` já entregues e a duplicata de CH mínima;
  referências por número de linha trocadas por nome de função/chave; os 4
  defeitos do `percentagem_curso` migrados do handoff para o backlog.
- A linha do "Modo Ajuste de Matrícula" **não** foi removida: metade existe
  (download por URL), metade não (importar `.csv` do disco). Foi reescrita para
  a metade que falta.
- Branch `cards/2026-08-22`, já mesclada, apagada local e no `origin`.

**2. Dado curricular — a parte que importa**
- **`alec-data` (3 commits, pushados):** aplicada a decisão SEI 1848924 inteira,
  aprovada por unanimidade na Comissão do Curso (17/07/2025), CLE (10/09/2025,
  SEI 1834218) e Conselho do Campus (24/09/2025). Hidrologia (`al0109`) → 6º,
  Arquitetura (`al0171`) → 5º, Instalações Hidráulicas (`al0163`) → 7º com
  Arquitetura como pré-requisito, Arquitetura incluída em Instalações Elétricas
  (`al0081`) e removida de Projeto Integrado (`al0408`). Concreto Protendido
  (`al2243`) incluída na `alec_2010`, onde faltava pelo item (a) da mesma ata.
- **Sincronizado** para `arquivos/grades/` com `sincronizar_dados_curso.ps1`.
- **Card 0005** escrito e aprovado; `cargaexigida/alem_2023.json` (JSON inválido,
  vírgula sobrando) corrigido.

## Pela metade / não verificado
- **O card 0005 nunca rodou.** Está `ready` e nada mais.
- **A auditoria das atas está só começada.** Confirmei o item de grade da SEI
  1848924; as outras ~20 pastas de `Coordenacao/Atualizacao PPCs/` **não foram
  conferidas**. Duas decisões já apareceram aplicadas pela metade, então a taxa
  de acerto do passivo é desconhecida. Anotado no `IDEAS.md`.
- **O PPC em Typst continua imprimindo a matriz antiga.** Ele lê
  `data/grades/alec_2023.json` via subtree (`atualizar_alec_data.bat`, em
  `Documentos/PPC/2023/Typst/`), que **não foi rodado** — é uma máquina e um
  repositório fora do pug, e a decisão é do dev. Enquanto não rodar, a Tabela 5
  do PPC mostra Arquitetura no 6º.
- **`percentagem_curso` segue sem card**, e a sessão achou evidência concreta do
  seu defeito nº 2: chaves do `cargaexigida` que não são núcleo de disciplina
  nenhum (`estagio`, `tcc`, `praticas`, `acg`/`agc`) somam no denominador e
  nunca no numerador.
- Não conferi se as outras 11 disciplinas que existem só na `alec_2023` (e não
  na `alec_2010`) deveriam estar nas duas. Só o `al2243` tinha ata explícita.

## Estado dos portões
guardrails: ok (limpo, 375 pré-existentes na baseline) · testes: ok (41/41) ·
parser: não rodado (nenhum `.gd` mudou nesta sessão) — em 2026-08-25, depois da
troca das grades.

## Estado do git
- **pug:** `master`, working tree limpo. 5 commits nesta sessão; os 4 primeiros
  pushados, o último (card 0005 + `alem_2023`) pendente no momento em que este
  arquivo foi escrito.
- **`alec-data`:** `main` sincronizada com `origin/main`, 3 commits pushados.

## Decisões tomadas que não estão em card nenhum
- **Item de backlog só sai do `IDEAS.md` quando o comportamento existe inteiro.**
  Escopo entregue pela metade é reescrito para a metade que falta, não apagado.
- **Ata aprovada exige conferir os dois campos.** A decisão de 2025 foi aplicada
  na `posicao_grade` e não no campo `semestre`, e ficou assim por meses sem que
  nada acusasse. As três disciplinas com `semestre` × `posicao_grade`
  divergentes eram exatamente as três movidas pela ata. Quando uma ata for
  aplicada, conferir os dois campos e rodar o card 0005 depois que ele existir.
- **Nome de arquivo canônico não se corrige direto em `arquivos/`.** Editar no
  repositório do curso, push, e só então sincronizar — o script clona do
  GitHub, não da pasta local, então sem push a sincronização não vê nada.

## Próximo passo concreto
Rodar o pipeline do card 0005 (`args: {cardId: "0005-validacao-coerencia-dados-curriculares"}`).
Ele é headless puro, tem 12 ACs falsificáveis e três defeitos reais nos dados
para provar contra.

## Em aberto para o dev
- Rodar `atualizar_alec_data.bat` no projeto do PPC em Typst, para o PDF passar
  a refletir a grade nova?
- `percentagem_curso`: escopo do card ainda não decidido (itens 1 e 3 só, ou os
  quatro esperando a fórmula oficial da Unipampa). Decisão adiada por escolha
  dele.
- `agc` vs `acg`: qual é a grafia boa?
