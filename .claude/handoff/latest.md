# Handoff — 2026-10-03 09:05

## Onde parei
**Release v1.1.0 publicada** (`6522719`, tag `v1.1.0`), com os cards 0005 a 0009
dentro. É a release `latest` do GitHub, então as instalações recebem o aviso de
atualização no próximo início. `master` sincronizada com o GitHub.

## Card ativo
Nenhum. Os cards 0005 a 0009 estão `done`. Não há card `ready` na fila.

## Feito nesta sessão (2026-10-03)
- `4028277` guardrails falha fechado (arquivo ilegível vira `ilegivel`; sem
  gdtoolkit aborta) + `situacao_disciplinas.gd` legível de novo, com as 12
  violações escondidas corrigidas (não congeladas).
- `45c6de8` `root` obrigatório no `godot-feature-pipeline.js`.
- `d1e6f78` manual da Sugestão de oferta.
- `c918e73` sincronização com o alec-data: `agc` → `acg` (decisão do dev),
  `unipampa_comunidade` incorporada a `outras_extensoes` na `alec_2023`, campos
  de CH em 5 disciplinas da grade 2023.
- Branch `cards/2026-10-02` mesclada na `master` (fast-forward) e apagada.
- `5113f9d` cards 0007, 0008 e 0009 fechados: o dev testou os 14 ACs manuais e
  confirmou todos num relato único ("Já testei [...] Está funcionando").
- `1e0c9ff` guarda do PCK do `publicar_release.ps1` aceita o log do Godot em
  português ("Armazenando Arquivo:"); a primeira tentativa da 1.1.0 abortou ali,
  sem publicar nada. Testada contra o log real e contra injeção de arquivo
  proibido nos dois idiomas.
- `6522719` + tag `v1.1.0` + release: dois pacotes (x64 146,8 MB, ARM64
  134,7 MB) com `.sha256`; as quatro exportações conferidas (258 arquivos no PCK,
  nenhum proibido). Notas em português, uma linha por novidade (o diálogo de
  atualização mostra o corpo da release linha a linha, sem markdown).

## Pela metade / não verificado
- **Ninguém instalou a 1.1.0 pelo atualizador ainda.** O ciclo (aviso → download
  → SHA-256 → troca do executável → relançamento) não foi observado com esta
  versão. Primeiro PC que abrir o programa na 1.0.2 é o teste real.
- Não foi conferido se o `ppc2023` lia as chaves `agc` ou `unipampa_comunidade`.
- `situacao_disciplinas.gd` foi corrigido sem teste automático; o dev testou os
  cards, mas não relatou especificamente a Situação de Disciplinas.
- Teste de recusa do pre-commit nos outros dois PCs (setup por máquina, ver
  AGENTS.md).

## Estado dos portões
guardrails: ok (370 toleradas; agora falha fechado) · testes: ok (137/137) ·
parser: ok · rodados em 2026-10-03.

## Estado do git
`master` = `origin/master` em `6522719` (mais o commit deste handoff). Tag
`v1.1.0` no GitHub. Sem branches extras.

## Decisões tomadas que não estão em card nenhum
- Migrar para o AGENTS.md (Troubleshooting): o colapso da barra dupla nas
  edições dos agentes neste ambiente e a checagem pós-card que o pega (gdlint lê
  cada `.gd` tocado, sem tabs no meio de linha, sem string aberta no fim da
  linha).
- Notas de release: texto puro, uma novidade por linha, em português para o
  usuário final (o `--generate-notes` produzia só um link "Full Changelog" cru).

## Próximo passo concreto
Nos outros dois PCs: `git pull`, conferir o setup (gdtoolkit + lefthook, teste de
recusa) e abrir o programa instalado para ver o aviso da 1.1.0.

## Em aberto para o dev
- Cards possíveis: chave `al0367` duplicada em `alec_2023-alec_2010.json`; os
  `avisos_leitura` da Situação de Alunos possivelmente apagados no `_ready`.
