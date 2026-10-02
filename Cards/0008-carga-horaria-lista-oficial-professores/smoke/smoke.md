# Smoke - 0008-carga-horaria-lista-oficial-professores

Executado em 2026-10-02. Godot 4.7.2, GL Compatibility.
Ambiente de dados: `dados/` sem dados reais (so `.gdignore`, `saida/`, `temp/`). Nenhuma captura de tela foi gravada.

O card declara "Smoke scenarios: nenhum": a logica nova e pura (testada headless) e a conferencia na tela exige dados reais de docentes. Nao ha AC com verificacao `smoke`. Foi feito apenas o boot headless para checar o log.

| AC | Metodo | Cenario | Evidencia | Veredito |
|---|---|---|---|---|
| AC1-AC11 | headless | Suite GUT (fora do escopo deste smoke) | n/a | coberto pelo portao de testes |
| AC12 | manual | Dados reais, filtro Engenharia Civil | roteiro R1 da spec | nao verificado |
| AC13 | manual | Dica e MANUAL.md | roteiro R2 da spec | nao verificado |

## Log
Boot headless (`--quit-after 60`): 0 erros (SCRIPT ERROR / Parse Error / ERROR), 0 mencoes a carga_docente, relatorios_oferta ou planejamentooferta.
Avisos: 13 `push_warning` de VALIDACAO JSON/COERENCIA (base_config.json com float no lugar de int, delimitadores como String, prerequisitos de `grades/alec_2010.json` inexistentes). Sao dados em arquivos que este card nao toca; tratados como pre-existentes. Baseline por `git stash` nao foi feito (indice com arquivos staged, risco desnecessario); a atribuicao e por inspecao do conteudo dos avisos.

## LGPD
Nenhum PNG gerado.

## Nao foi possivel verificar
- AC12 exige abrir o Planejamento de Oferta com dados reais e clicar. Roteiro R1 em `spec.md`. Sem captura.
- AC13 exige passar o mouse na acao e ler o manual. Roteiro R2 em `spec.md`.
