# Handoff — 2026-11-17 (fim da fila do card 0010)

## Onde parei
A fila rodou o card 0010 na máquina Linux e **passou** numa rodada, com review
sem findings. Os ACs 1 a 8 (`headless`) estão provados e commitados na branch
`cards/2026-11-17`. O card continua `in_progress` porque os ACs 9 a 12 são
`manual` e esperam o relato do dev. A branch **não** foi mesclada na `master` nem
enviada ao GitHub.

## Card ativo
0010-conversao-cp1252-nativa, `in_progress`. Faltam os ACs manuais 9 a 12
(roteiros R9 a R12 em `Cards/0010-conversao-cp1252-nativa/spec.md`).

## Feito nesta sessão (2026-11-17)
- Diagnóstico do `horarios.txt` novo. O que quebrava era o `ansi_to_utf8.exe`,
  um executável Windows, falhando no Linux, e não a mudança de formato. Ver o
  "Contexto" do card 0010.
- Setup do Linux no host, sem sudo (Godot wrapper, gdtoolkit 4.5.0, lefthook
  2.2.2) e teste de recusa ok. Documentado no AGENTS.md (Setup por máquina).
- Commits, em ordem:
  - `ae3cd02` (master, no GitHub): card 0010 e três itens de Linux no
    IDEAS.md.
  - `8fb23c6` (master, **não enviado**): caminho do Godot do Linux no pipeline e
    nas skills; seção Linux no AGENTS.md.
  - `c0230b5` (branch): card `in_progress`.
  - `9ebab01` (branch): a implementação. `CodificacaoTexto` em
    `standalone_scripts/utils/` (funções puras: detecção UTF-8 estrita e tabela
    Windows-1252 nos dois sentidos). `convertto_utf8` agora devolve `bool`. Saem
    as três heurísticas duplicadas, o `.exe` e a fonte dele. Entram 26 testes.
- O orquestrador refez os portões com código de saída, porque o agente dos
  portões não os capturou (zsh). Conferiu também que os testes de cada AC
  existem e que o diff não traz nenhum dos nomes reais de docentes do
  `horarios.txt` recebido.

## Pela metade / não verificado
- **Os ACs 9 a 12 não foram verificados pelo dev.**
  - O AC 10, o caso real, nunca rodou: ninguém importou o `horarios.txt` real
    pelo verificador com o código novo.
  - O AC 9 tem evidência automática (o `git grep` sai vazio e os arquivos
    saíram do git), mas fecha por relato.
- O smoke não montou o baseline de log (foi negada a criação de worktree), então
  o `log_clean` veio de inspeção do log de um boot headless, sem diff contra o
  baseline. O card não tem AC visual.
- O `convertto_utf8` mudou de comportamento em três pontos, aceitos no spec
  ("Riscos de contrato de dados"):
  - a quebra de linha é preservada byte a byte;
  - a codificação é sempre Windows-1252, em vez da página ANSI do sistema;
  - um UTF-8 que contém U+FFFD deixa de ser reconvertido.

  O `hist.csv` e os outros CSVs do GURI só serão exercitados de verdade no uso
  normal.
- **O hook nos PCs Windows é agora a versão Linux** (replicado pelo OneDrive).
  É preciso refazer o teste de recusa lá.
- Continuam abertos do handoff de 2026-10-03: ninguém viu o atualizador instalar
  a 1.1.0 do começo ao fim, nem conferiu se o `ppc2023` lia
  `agc`/`unipampa_comunidade`.

## Estado dos portões
Linux, 2026-11-17, depois do card: guardrails `EXIT=0` (365 toleradas; a
baseline apertou de 370) · testes 163/163 · parser `EXIT=0`. O pre-commit do
`9ebab01` também passou.

## Estado do git
Branch `cards/2026-11-17` (3 commits à frente de `origin/master`: `8fb23c6`,
`c0230b5`, `9ebab01`, mais este handoff). `master` local está em `8fb23c6`, à
frente da `origin/master` (`ae3cd02`). Working tree limpo depois do commit
deste handoff.

## Decisões tomadas que não estão em card nenhum
Nenhuma pendente. O setup do Linux já está no AGENTS.md.

## Próximo passo concreto
O dev roda o R10 (`spec.md` do card 0010): importa o `horarios.txt` real pelo
verificador no Linux e confere a data, o UTF-8, `Terça`/`Sábado` e zero
`Unicode parsing error` no `godot.log`.

## Em aberto para o dev
- Relatar os ACs 9 a 12, um a um. O 12 exige um PC Windows.
- Mesclar `cards/2026-11-17` na `master` e enviar ao GitHub: agora ou depois
  dos ACs manuais?
