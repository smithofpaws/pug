# Smoke - 0005-validacao-coerencia-dados-curriculares

Executado em 2026-10-02. Godot 4.7, GL Compatibility.
Ambiente de dados: `dados/` sem CSVs (apenas `saida/` e `temp/`); nenhuma captura de tela feita.

| AC | Metodo | Cenario | Evidencia | Veredito |
|---|---|---|---|---|
| Todos (11) | headless | O card declara "Smoke scenarios: nenhum"; ACs sao cobertos por GUT | n/a | fora do escopo do smoke |
| Boot | smoke | Boot do programa com `--quit-after 30` | log: exit 0, 0 ERROR/Parse Error | passou |

## Log
Baseline (pre-existente, nao e desta mudanca): 5 avisos `VALIDACAO JSON` em
`base_config.json` (largura/altura float, delimitadores String).
Com a mudanca: 0 erros; avisos novos `VALIDACAO COERENCIA` sao a saida pretendida do
card (defeitos reais em alec_2010 e alec_2023, ex.: `ch 50%` em al5022). Sem regressao.
Obs.: baseline sem a mudanca nao foi capturado via stash (arvore com mudancas nao commitadas); comparacao feita por prefixo de aviso.

## LGPD
Nenhum PNG gerado. Nenhum dado pessoal em smoke.md.

## Nao foi possivel verificar
Nada visual a verificar: a feature nao tem UI.
