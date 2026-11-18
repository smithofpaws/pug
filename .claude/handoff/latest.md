# Handoff — 2026-11-18 17:34 (release v1.1.2 publicada)

## Onde parei
A versão 1.1.2 está publicada no GitHub como `Latest`. Ela leva o card 0011:
disciplinas compartilhadas do horarios.txt agora caem no card do planejamento,
e o Atualizar planejamento deixa de perder a sala e o horário delas. A branch
`cards/2026-11-18` foi mesclada na `master` por fast-forward, e a `master` está
sincronizada com o GitHub.

## Card ativo
- **0011-compartilhadas-horarios-txt**: `done`. Os 14 ACs estão fechados, e o
  13 e o 14 foram aprovados pelo dev ("Funcionando").
- **0010-conversao-cp1252-nativa**: segue `in_progress`, à espera dos ACs 10 e
  11 na máquina Linux. Nada mudou nele.

## Feito nesta sessão (2026-11-18, PC Windows)
- **Card 0011, do diagnóstico até a release.** O registro da fila está em
  `archive/2026-11-18-1716-fila-0011.md`.
- **ACs 13 e 14.** Relato do dev, conferido por contagem e sem ler nomes:
  - o `planejamento.json` foi salvo às 17:29, com backup
    `.backup/planejamentohorario/2026-11-18_172906_salvar`;
  - as 8 disciplinas estão lá com todas as alocações, sob a chave do card do
    CSV.
- **Conferência extra, headless sobre os dados reais e só leitura.** O
  Atualizar planejamento mantém dia e horário das 8 disciplinas. As únicas
  "removidas" com o mesmo código são turmas de outros cursos (`al0022_ea03`,
  `al0002_ee01`), o que é esperado: o txt traz todos os cursos.
- **Commits:**
  - `77cef2d`: card `done`;
  - `8564f55`: `Versao 1.1.2`, feito pelo script, com a tag `v1.1.2`.
- **Release `v1.1.2`.** Tem 4 assets: `PUG_WIN_X64.zip` (140 MB),
  `PUG_WIN_ARM64.zip` (128 MB) e um `.sha256` de cada.
  - As 4 conferências de PCK deram "260 arquivos, nenhum proibido".
  - Layout dos dois ZIPs conferido (33 entradas).
  - O `base_config.json` de cada pacote aponta para o próprio asset.
  - O SHA-256 dos ZIPs locais bate com os `.sha256`.
  - As notas foram escritas à mão para o usuário.
- **Tropeço na publicação.** A 1ª tentativa parou depois do commit da versão,
  porque redirecionei a saída do script (`*>`) e o stderr do lefthook virou
  erro terminante. Nada tinha sido publicado. A 2ª tentativa, sem
  redirecionamento, fechou. A regra foi para o `AGENTS.md`
  ("Distribuição e atualização").

## Pela metade / não verificado
- **Dois findings baixos do card 0011, sem correção** (estão em
  `Cards/0011-compartilhadas-horarios-txt/review.md`):
  - falta teste do caminho `removidas`/`entries_removidas` com linha
    compartilhada;
  - um comentário de `_chaves_do_txt_pelo_planejamento` fala em "campo
    inteiro", mas o código usa a 1ª parte.
- **`planejamento.json` antigo não é reparado.** Quem salvou antes da 1.1.2
  precisa reabrir o CSV e o txt e salvar de novo. Isso está nas notas da
  release.
- **Ninguém viu um PC instalado se atualizar sozinho**, nem para a 1.1.1 nem
  para a 1.1.2. Conferir o `user://atualizacao/log.txt` na próxima vez que uma
  instalação antiga abrir.
- Pendências herdadas, sem mudança:
  - ACs 10 e 11 do card 0010 (Linux);
  - teste de recusa do hook neste PC;
  - `ppc2023` × `agc`/`unipampa_comunidade`.

## Estado dos portões
Windows, 2026-11-18 ~17:00: guardrails `EXIT=0` (365 toleradas) · testes
179/179 · parser `EXIT=0`. A `master` não mudou de código desde então: só o
card, a versão, o AGENTS.md e este handoff.

## Estado do git
- `master` em `8564f55`, mais o commit deste handoff/AGENTS.md. Sincronizada
  com `origin/master` depois do push. Tag `v1.1.2` no GitHub.
- As branches locais `cards/2026-11-17` e `cards/2026-11-18` foram apagadas
  pelo dev (já estavam contidas na `master`). Só existe a `master`.

## Decisões tomadas que não estão em card nenhum
Nenhuma. A regra do redirecionamento já foi para o `AGENTS.md`.

## Próximo passo concreto
Na máquina Linux: `git pull`, depois rodar os roteiros R10 e R11 do card 0010.
Com os dois aprovados, o 0010 vira `done`.

## Em aberto para o dev
- Decidir se os dois findings baixos do 0011 viram ajuste.
- Relatar os ACs 10 e 11 do card 0010.
