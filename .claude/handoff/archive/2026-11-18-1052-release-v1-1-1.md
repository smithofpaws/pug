# Handoff — 2026-11-18 10:52 (release v1.1.1 publicada)

## Onde parei
A versão 1.1.1 está publicada no GitHub como `Latest`. Ela leva o card 0010
(conversão Windows-1252 → UTF-8 em GDScript, sem o `ansi_to_utf8.exe`). A branch
`cards/2026-11-17` foi mesclada na `master` por fast-forward, e a `master` está
sincronizada com o GitHub.

## Card ativo
0010-conversao-cp1252-nativa, `in_progress`. ACs 1 a 9 e 12 fechados. Faltam o
10 e o 11, que são `manual` e pedem a máquina Linux (roteiros R10 e R11 em
`Cards/0010-conversao-cp1252-nativa/spec.md`).

## Feito nesta sessão (2026-11-18, PC Windows)
- AC 9 aprovado pelo dev sobre a saída do R9: `git grep` vazio e os dois caminhos
  fora do checkout.
- AC 12 por relato do dev ("importei aqui, funciona"). Conferido por contagem, sem
  ler conteúdo:
  - o `godot.log` da sessão das 10:44 tem zero `Unicode parsing error` e um
    `Arquivo convertido!`;
  - `dados/saida/horarios.txt` é UTF-8 estrito, com `Terça` e `Sábado` presentes.

  O passo do VSCodium do R12 não foi feito; a checagem de UTF-8 estrito o
  substitui.
- Portões no Windows antes da release: guardrails `EXIT=0` (365 toleradas) ·
  testes 163/163 · parser `EXIT=0`.
- Commits:
  - `77345c5`: card com os ACs 9 e 12.
  - `901e5fb`: `Versao 1.1.1`, feito pelo script, com a tag `v1.1.1`.
- Release `v1.1.1` com 4 assets: `PUG_WIN_X64.zip` (140 MB),
  `PUG_WIN_ARM64.zip` (128 MB) e um `.sha256` de cada. As notas foram escritas à
  mão para o usuário (não usamos `--generate-notes`).
  - As 4 conferências de PCK deram "260 arquivos, nenhum proibido".
  - Layout dos dois ZIPs conferido (33 entradas).
  - O `base_config.json` de cada pacote aponta para o próprio asset.

## Pela metade / não verificado
- **ACs 10 e 11 (Linux) não verificados.** A release saiu antes deles por
  decisão do dev. Ela é só para Windows, e o AC 12 cobre o caminho do Windows.
- **Ninguém viu um PC instalado se atualizar sozinho para a 1.1.1.** O
  atualizador do começo ao fim segue sem testemunha desde a 1.1.0. O próximo PC
  que abrir uma instalação 1.1.0 deve oferecer a atualização: vale observar e
  conferir o `user://atualizacao/log.txt`.
- O `ansi_to_utf8.exe` continua nas instalações já existentes, porque a
  atualização copia de forma aditiva. Ninguém mais o referencia. Isso é
  esperado (AGENTS.md, "Como a troca acontece"), não é defeito.
- O `hist.csv` e os outros CSVs do GURI passam pela mesma `convertto_utf8` que
  o `horarios.txt`, mas só o `horarios.txt` foi importado de verdade com o
  código novo.
- **Teste de recusa do hook neste PC Windows: não feito.** O lefthook 2.1.10 roda
  aqui: ele apareceu nos dois commits desta sessão, mas os jobs foram pulados
  porque não havia `.gd`. Isso mostra que o hook está ligado, mas não que ele
  recusa.
- Continua aberto desde 2026-10-03: conferir se o `ppc2023` lê
  `agc`/`unipampa_comunidade`.

## Estado dos portões
Windows, 2026-11-18 ~10:30: guardrails `EXIT=0` (365 toleradas) · testes
163/163 · parser `EXIT=0`.

## Estado do git
`master` em `901e5fb` + o commit deste handoff, sincronizada com
`origin/master`. Tag `v1.1.1` no GitHub. A branch local `cards/2026-11-17` já
está toda contida na `master` e nunca foi enviada; pode ser apagada com
`git branch -d cards/2026-11-17`. Working tree limpo depois do commit deste
handoff.

## Decisões tomadas que não estão em card nenhum
Nenhuma.

## Próximo passo concreto
Na máquina Linux: `git pull` e rodar o R10 (importar o `horarios.txt` real pelo
verificador) e o R11 (arquivo com `chmod 000`). Com os dois aprovados, o card
0010 vira `done`.

## Em aberto para o dev
- Relatar os ACs 10 e 11.
- Teste de recusa do hook neste PC Windows (receita no AGENTS.md, "Setup por
  máquina").
