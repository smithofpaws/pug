# Handoff — 2026-11-18 17:16 (fila do card 0011)

## Onde parei
O card 0011 passou pelo pipeline numa rodada e está commitado na branch
`cards/2026-11-18`, que **não** foi mesclada na `master` nem enviada ao GitHub.
Os ACs 1 a 12 estão provados. Faltam os ACs 13 e 14, que são `manual` e
dependem de você com os dados reais.

## Card ativo
- **0011-compartilhadas-horarios-txt**, `in_progress`. ACs 1 a 12 fechados.
  Faltam o 13 e o 14 (roteiros R13 e R14 em
  `Cards/0011-compartilhadas-horarios-txt/smoke/smoke.md`).
- **0010-conversao-cp1252-nativa** continua `in_progress`, à espera dos ACs 10
  e 11 na máquina Linux. Nada mudou nele nesta sessão.

## Feito nesta sessão (2026-11-18, PC Windows)
- O dev relatou que AL0015, AL0019, AL0022 e outras não apareciam na grade
  do Planejamento de horário.
- **Diagnóstico** com o código real, rodando headless sobre o
  `planejamento.csv` e o `horarios.txt` reais (só códigos e chaves foram
  impressos). A causa era o campo de semestre da compartilhada, lido de forma
  diferente em cada arquivo:
  - **Chave que não casava.** O CSV gerava `al0015_ec03` e o txt gerava
    `al0015_ec03;emextra`. Resultado: um card-fantasma, que não era salvo nem
    enviado.
  - **Filtro que descartava a linha.** O filtro do txt usava `begins_with` no
    campo inteiro, então `EE03;EC03` era descartado.
- **Card 0011** entrevistado e aprovado. Decisões do dev:
  - com vários cursos carregados, só o card da 1ª parte recebe a alocação;
  - o Atualizar planejamento entra no card;
  - a exportação do horarios.txt perder `;EMExtra` não importa.
- **Fila:** branch `cards/2026-11-18` com 3 commits:
  - `075ec39`: card aprovado;
  - `bddbd35`: card `in_progress`;
  - `0ed8e35`: implementação, 16 testes novos, MANUAL.md e spec/review/smoke.
- Conferência independente, depois do pipeline, com os dados reais: as 8
  disciplinas agora resolvem para o card do CSV, sem card órfão. Só ficam
  pendentes as do non-goal: `al0390_ec07_2` e `al0142_ec09_2` (CH 0, linhas
  duplicadas do CSV) e `al0375_ecextra` (o txt só tem `EM03`).

## Pela metade / não verificado
- **ACs 13 e 14 não verificados na tela.** A conferência headless sobre os
  dados reais é apoio, não substitui o relato. Ela não passa pelo painel, pela
  contagem de CH dos cards, pelo diálogo "fora do planejamento" nem pelo ciclo
  Salvar → Abrir planejamento.json.
- **Dois findings baixos, não bloqueantes, em `review.md`, sem correção:**
  - falta teste do caminho `removidas`/`entries_removidas` com linha
    compartilhada no `mesclar_planejamento_com_horarios_txt`;
  - um comentário de `_chaves_do_txt_pelo_planejamento` promete "campo
    inteiro" quando o código usa a 1ª parte.
- **Mudança visível esperada:**
  - o diálogo "Disciplinas Removidas" do Atualizar planejamento passa a listar
    a chave da 1ª parte (`al0101_ee01`) e não mais o campo inteiro;
  - com referência sobreposta, podem surgir avisos novos de compartilhada
    divergente, porque as compartilhadas agora ficam no card certo.
- O modo referência foi preservado por uma convenção: `prefixos` vazio
  significa comportamento legado. O único chamador com prefixos vazios é o
  `_aplicar_referencia_txt` (o `_on_importar_horarios_button_up` também chama
  sem prefixos, mas não está ligado a nenhuma cena).
- Pendências herdadas do handoff anterior, sem mudança:
  - teste de recusa do hook neste PC;
  - atualizador automático sem testemunha;
  - `ppc2023` × `agc`/`unipampa_comunidade`.

## Estado dos portões
Windows, 2026-11-18 ~17:00, depois do pipeline: guardrails `EXIT=0` (365
toleradas, sem violação nova) · testes 179/179 · parser `EXIT=0`. O pre-commit
do commit `0ed8e35` rodou os dois primeiros e passou.

## Estado do git
- Branch `cards/2026-11-18`, 3 commits à frente da `master`, mais o commit
  deste handoff.
- Não enviada ao GitHub. A `master` está em `92d9428`, igual a
  `origin/master`.
- A branch antiga `cards/2026-11-17` (já contida na `master`) continua
  podendo ser apagada.

## Decisões tomadas que não estão em card nenhum
Nenhuma.

## Próximo passo concreto
Rodar o R13 com os dados reais (Abrir planejamento.csv da EC → Abrir
horarios.txt da EC) e relatar. Depois o R14 (Salvar → Abrir
planejamento.json). Com os dois aprovados, o card 0011 vira `done` e a branch
pode ir para a `master` por fast-forward.

## Em aberto para o dev
- Relatar os ACs 13 e 14 do card 0011.
- Decidir se os dois findings baixos viram ajuste agora ou ficam registrados.
- Mesclar `cards/2026-11-18` na `master` e fazer o push: só quando você
  pedir.
