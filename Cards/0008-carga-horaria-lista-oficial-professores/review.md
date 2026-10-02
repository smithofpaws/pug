
## Rodada 1 de 3

Veredito: changes_required

1. [BLOQUEANTE, high] `scenes/Modulos/PlanejamentoOferta/planejamentooferta.gd:1277` - a chamada de `verificar_carga_horaria` contem `\n` literal (barra + n) seguido de quebra de linha. Parse Error: `Expected new line after "\"`; o script do modulo inteiro nao carrega. Conserto: trocar por `\` seguido de quebra de linha real (como na chamada de `sugerir_oferta`) ou juntar na mesma linha. Os testes GUT passam porque nao carregam a cena.
2. [nao bloqueante, low] `scenes/Modulos/PlanejamentoOferta/Complementos/relatorios_oferta.gd:246` - tabs soltos no meio da linha (`cod_curso, <tab><tab>_afinidade...`). Remover.

## Rodada 2 de 3

Veredito: changes_required

Rodada 1 item 1 (quebra de linha com `\`) corrigido; Godot --editor --quit sem erro de parse; GUT 107/107. ACs headless conferidos um a um contra test_carga_docente.gd / test_relatorios_oferta.gd: cobertos. Nenhum dado pessoal real (nomes ficticios).

1. [BLOQUEANTE, medium] `.tools/guardrails_baseline.json:43` - o diff removeu da baseline as entradas de `planejamentooferta.gd` (`gdlint:max-line-length`, `section-order`, `static-typing: 3`), mas o arquivo ainda tem essas violacoes (linhas 314, 683, 757, 985). `python .tools/guardrails.py` reprova: "4 violacao(oes) em 1 arquivo(s) acima da baseline". Conserto: restaurar as 3 entradas removidas (`git checkout HEAD -- .tools/guardrails_baseline.json` e reaplicar so a reducao legitima de `analise_horarios.gd|gdlint:trailing-whitespace` 13->10, se confirmada), ou de fato corrigir as violacoes. Nao afrouxar a catraca alem do estado original.
2. [nao bloqueante, low] `scenes/Modulos/PlanejamentoOferta/Complementos/relatorios_oferta.gd:246` - persiste da rodada 1: dois tabs soltos no meio da linha (`cod_curso, <tab><tab>_afinidade...`). Remover.

## Rodada 3 de 3

Veredito: clean

Rodada 2 item 1 (baseline) corrigido: o diff da baseline agora so reduz `analise_horarios.gd|gdlint:trailing-whitespace` 13->10; `guardrails.py` limpo, GUT passa, Godot --editor --quit sem erro de parse. ACs headless reconferidos contra os testes; nenhum dado pessoal real no diff.

1. [nao bloqueante, low] `scenes/Modulos/PlanejamentoOferta/Complementos/relatorios_oferta.gd:246` - persiste desde a rodada 1: dois tabs soltos no meio da linha (`cod_curso, <tab><tab>_afinidade...`). Remover.
