# Smoke - 0010-conversao-cp1252-nativa

Executado em 2026-11-17. Godot 4.7.2 (stable), GL Compatibility, Linux.
Ambiente de dados: `dados/` nao inspecionado (leitura proibida); nenhuma captura de tela feita.

O card declara "Smoke scenarios: Nenhum" (sem mudanca visual). Nenhum AC tem verificacao
visual: ACs 1-8 sao `headless` (suite GUT), ACs 9-12 sao `manual`. Por isso nao ha PNG
nesta pasta, e isso e intencional (tambem evita qualquer risco de LGPD).

| AC | Metodo | Cenario | Evidencia | Veredito |
|---|---|---|---|---|
| AC1-AC8 | headless | Coberto pela suite GUT (portao), fora do escopo do smoke | n/a | nao verificado aqui |
| AC9 | manual | `git grep ansi_to_utf8` fora de `Cards/` e `.claude/handoff/` | git grep rodado: ver Log | ver abaixo |
| AC10-AC12 | manual | Importacao real / chmod 000 / Windows | roteiros abaixo | nao verificado |

## Log
Boot headless do programa (`godot --headless --path . --quit-after 60`), saida 0.
Nenhum `ERROR`, `SCRIPT ERROR`, `Parse Error`, `Unicode parsing error`. Unicas ocorrencias
sao 13 `push_warning` de `VALIDACAO JSON`/`VALIDACAO COERENCIA` (json_validator.gd, vindos de
`base_config.json` e `grades/alec_2010.json`), nao relacionados a conversao de codificacao.
Baseline: nao foi possivel montar (criar worktree do commit anterior foi negado pelo
ambiente). A comparacao e portanto por inspecao: nenhum aviso/erro menciona
codificacao, conversao ou `ansi_to_utf8`; os avisos sao de validacao de JSON em arquivos
que este card nao toca. Ressalva: sem baseline formal.

AC9 (grep): `git grep ansi_to_utf8` fora de `Cards/` e `.claude/handoff/` retornou vazio.

## LGPD
Nenhum PNG gerado.

## Nao foi possivel verificar
- AC10 (manual). Roteiro: no Linux, com o `horarios.txt` real, abrir o verificador de arquivos
  e importa-lo; conferir que `dados/saida/horarios.txt` tem a data do dia, esta em UTF-8, com
  `Terca`/`Sabado` acentuados, e que `grep -c "Unicode parsing error" ~/.local/share/godot/app_userdata/<projeto>/logs/godot.log`
  nao aumenta.
- AC11 (manual). Roteiro: `chmod 000` num arquivo de entrada, aponta-lo no verificador; deve
  haver `push_error` com o nome do arquivo e nenhuma linha `Arquivo convertido!`.
- AC12 (manual). Roteiro: repetir o AC10 num PC Windows.
