# Handoff — 2026-08-21

## Onde parei
O pipeline de desenvolvimento do 3d World foi portado e adaptado para o PUG:
skills, workflow, Cards/, handoff, portões (guardrails + GUT + parser), hooks do
Claude Code e pre-commit do Lefthook. Tudo criado nesta sessão, nada commitado
ainda.

## Card ativo
Nenhum. O índice em `Cards/README.md` está vazio — o primeiro card nasce da
entrevista da skill `godot-session-setup` (ou do modo migração sobre o `IDEAS.md`).

## Feito nesta sessão
- `.tools/guardrails.py` (gdlint + regras do projeto, com **baseline/catraca** em
  `.tools/guardrails_baseline.json` — 375 violações históricas congeladas em 99
  pares arquivo+regra), `.tools/run_tests.py`, `.tools/claude_hooks.py`.
- `gdlintrc`, `lefthook.yml` (pre-commit instalado), `.gutconfig.json`.
- `addons/gut/` copiado do 3DWorld (GUT 9.x); `test/unit/test_general_functions.gd`
  (5 testes, 12 asserts, verdes); `test/fixtures/README.md` (regra: só dado fictício).
- `Cards/README.md` (convenção + índice vazio) e `Cards/.gdignore`.
- `.claude/settings.json` (hooks + permissões), `.claude/handoff/` (este arquivo),
  `.claude/workflows/godot-feature-pipeline.js`, `.mcp.json` (MCP godot).
- 5 skills em `.claude/skills/`: godot-session-setup, godot-feature-design,
  godot-gdscript-dev, godot-code-review, godot-smoke-test — todas adaptadas ao
  domínio do PUG (LGPD, multi-curso, snake_case, injeção pelo main).
- `AGENTS.md`: nova seção "Pipeline de desenvolvimento (cards)".
- `IDEAS.md`: cabeçalho ligando o backlog ao modo migração (título "TODO" → "IDEAS").
- `export_presets.cfg`: `addons/gut/*` e `test/*` no exclude_filter dos 4 presets.
- `.gitignore`: `__pycache__/`, `.claude/settings.local.json`, `.claude/worktrees/`.

## Pela metade / não verificado
- **O workflow (`godot-feature-pipeline.js`) nunca rodou de ponta a ponta** — foi
  adaptado do 3DWorld mas nenhum card existe ainda. O primeiro card é o piloto do
  pipeline; esperar ajustes (especialmente no smoke, que aqui tem a restrição
  LGPD de captura).
- **Smoke test nunca foi exercitado neste projeto**: `--write-movie` foi validado
  no 3DWorld (mesma engine), não aqui. O primeiro card com AC `smoke` prova.
- **MCP godot não testado nesta sessão** (`.mcp.json` copiado do 3DWorld; o
  servidor existe em `C:/Users/diego/mcp-servers/godot-mcp`). Requer reiniciar a
  sessão do Claude Code para carregar.
- A baseline congela dívida real (86 static-typing, 115 trailing-whitespace, 55
  tabs, 53 private-docstring, 34 section-order...). Queimá-la é trabalho de card
  futuro — sugestão registrada abaixo.

## Estado dos portões
guardrails: ok (0 acima da baseline) · testes: ok (5/5) · parser: ok (exit 0) —
rodados em 2026-08-21, ao fim da implementação.

## Estado do git
Branch `master`, working tree SUJO — toda a implementação está sem commit.
Modificados: `.gitignore`, `AGENTS.md`, `IDEAS.md`, `export_presets.cfg`.
Novos: `.claude/`, `.tools/`, `Cards/`, `addons/`, `test/`, `gdlintrc`,
`lefthook.yml`, `.gutconfig.json`, `.mcp.json`.

## Decisões tomadas que não estão em card nenhum
- **Baseline/catraca** em vez de corrigir as 375 violações históricas: portão
  nasce verde, violação nova é barrada, dívida registrada. Já documentada em
  `AGENTS.md` e `Cards/README.md`.
- Allowlist de `FileAccess` no guardrails é **congelamento** dos 10 arquivos que
  já tocavam disco, não endosso — código novo lê via main/FileHandling.
- `Cards/` fica fora do PCK por `.gdignore`; `addons/gut/*` e `test/*` por
  exclude_filter (eles precisam ser visíveis ao Godot para o GUT rodar).

## Próximo passo concreto
Commitar por tema (sugestão: 1. portões e ferramentas; 2. GUT + testes;
3. Cards/ + handoff + skills + workflow; 4. AGENTS/IDEAS/presets/gitignore) e
então rodar a primeira entrevista de card — candidato natural: um dos BUGs de
alta prioridade do `IDEAS.md` (ex.: "disciplina concluída por equivalência não
recebe cor na grade", que já tem edge cases mapeados).

## Em aberto para o dev
- Aprovar (ou ajustar) a estratégia da baseline — alternativa seria limpar as
  violações mecânicas (whitespace) num card dedicado.
- Decidir se o primeiro card vem de entrevista nova ou da migração de um item do
  `IDEAS.md`.
