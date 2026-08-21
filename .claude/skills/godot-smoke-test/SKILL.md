---
name: godot-smoke-test
description: Prova com o PUG rodando de verdade que os critérios de aceite visuais de um card acontecem, capturando PNGs nomeados por AC dentro de Cards/<id>/smoke/ e conferindo que a saída de debug não ganhou push_error nem push_warning novo. Usa o MCP do Godot para o ciclo de vida (run_project, get_debug_output, stop_project) e a CLI --write-movie para a captura de frame, porque o MCP não tira screenshot. Regra absoluta: nenhuma captura com dados pessoais reais — dados/ vazio ou fixtures fictícias. Use esta skill SEMPRE que precisar verificar visualmente uma mudança no programa, tirar screenshot do Godot, rodar o projeto para conferir se algo funciona na tela, ou fechar um card cujos ACs incluem verificação visual.
---

# Smoke test — PUG

Último passo do pipeline. Prova o que teste headless não alcança: que a coisa
aparece na tela, certa, sem erro no console.

Um smoke que só diz "rodou sem crashar" não vale a execução. O que vale é o PNG que
prova um AC específico e o diff de log contra o baseline.

---

## Regra zero: LGPD antes de qualquer captura

`Cards/<id>/smoke/` é **versionado num repositório público**. Um PNG com nome de
aluno, matrícula ou e-mail real é um vazamento permanente e cacheável.

Antes de capturar:

1. Confira o que há em `dados/` — se houver CSVs reais, a captura só pode
   acontecer em telas que não os exibem, ou com o programa apontado para
   fixtures fictícias (`test/fixtures/`).
2. `arquivos/oferta/` contém nomes de docentes reais: telas do Planejamento de
   Oferta que os exibem não podem ser capturadas com a pasta presente.
3. **PNG com dado pessoal real = smoke reprovado**, mesmo que o AC tenha passado.
   Refaça a captura com dados fictícios; se não der, o AC vira `manual` com
   roteiro (o dev olha a própria tela, sem versionar imagem).

## Divisão de trabalho: MCP faz uma coisa, CLI faz outra

| Tarefa | Ferramenta |
|---|---|
| Lançar o projeto, ler debug, encerrar | MCP `godot` — `run_project`, `get_debug_output`, `stop_project` |
| Capturar frame em PNG | CLI `--write-movie` |

**O MCP não tem ferramenta de screenshot.** Não invente nomes de ferramenta —
confira a lista real no handshake do servidor.

Se o MCP não estiver conectado, degrade para CLI pura: rode com `--write-movie`,
leia o stderr do processo, e diga no relatório que a asserção de log veio do stderr
em vez do `get_debug_output`.

---

## Captura de PNG

```bash
"C:/Program Files/Godot/Godot_console.exe" --path . --write-movie Cards/<id>/smoke/frame.png --fixed-fps 10 --quit-after 12
```

Comportamento (verificado no 3d World, mesma engine): `--quit-after N` grava
exatamente N arquivos, `frame00000000.png` … `frame%08d.png`, e sai com 0.

**Sempre limite com `--quit-after`.** Sem ele, o modo Movie Maker grava até o
programa fechar e enche a pasta do card.

Depois da captura:

1. Escolha os frames que provam cada AC.
2. **Renomeie pelo AC**: `ac2-grade-dourada.png`, não `frame00000007.png`. Daqui a
   três meses o nome é a única pista do que a imagem prova.
3. Apague o resto.
4. **Olhe cada PNG antes de gravar** procurando dado pessoal (regra zero).

O frame 0 costuma pegar a cena antes de estabilizar. Prefira os últimos.

O que dá para capturar sem input: estado inicial do programa, a barra de módulos,
resultado de análises que rodam sozinhas ao carregar com fixtures, e qualquer
coisa alcançável por dado já presente. O que exige clique (trocar de módulo,
selecionar aluno, abrir diálogo) é `manual`.

## Asserção de log, não só de imagem

Um PNG bonito com erro no console é falha.

1. Capture um baseline **antes** da mudança (ou use `git stash`).
2. Rode com a mudança.
3. Compare: nenhum `push_error`, `push_warning`, `SCRIPT ERROR` ou
   `Parse Error` **novo**.

Avisos que já existiam no baseline não são regressão desta mudança — mas
registre-os no relatório, para não virarem paisagem.

Atenção ao ambiente: o programa degrada sem crash quando `dados/` ou
`arquivos/oferta/` faltam — mensagens de "arquivo não encontrado" esperadas nesse
cenário fazem parte do baseline, não da mudança.

---

## O limite honesto desta skill

**Não há harness de input neste projeto.** Nenhuma ferramenta disponível injeta
clique ou teclado no Godot. Isso significa que um AC do tipo "clicar no aluno
mostra a grade" **não pode ser automatizado**.

Nesses casos:

- Marque o AC como `manual` no relatório.
- Escreva o **roteiro** para o dev: qual módulo abrir, qual arquivo de dados ter
  na pasta, onde clicar, o que deve aparecer.
- **Nunca declare sucesso no lugar dele.** Um AC marcado como provado sem prova é
  pior do que um AC pendente: o card fecha errado e ninguém revisita.
- A saída "o dev tira um print" não vale como padrão — a captura pega a tela
  inteira, com dados pessoais dentro.

---

## Formato de saída

Grave `Cards/<id>/smoke/smoke.md`:

```markdown
# Smoke — NNNN-slug

Executado em <data>. Godot 4.7.1, GL Compatibility.
Ambiente de dados: <dados/ vazio | fixtures fictícias (quais)>.

| AC | Método | Cenário | Evidência | Veredito |
|---|---|---|---|---|
| AC3 | smoke | Boot com fixture de grade mínima | ![](ac3-grade-dourada.png) | passou |
| AC4 | manual | Selecionar aluno fictício e abrir a grade | roteiro abaixo | não verificado |

## Log
Baseline: 0 erros, N avisos (pré-existentes: <quais>).
Com a mudança: 0 erros, N avisos. Sem regressão.

## LGPD
PNGs conferidos um a um: nenhum dado pessoal real.

## Não foi possível verificar
- AC4 exige clique. Roteiro: ...
```

E devolva ao workflow:

```json
{
  "smoke_passed": true,
  "log_clean": true,
  "ac_results": [
    {"ac": "AC3", "method": "smoke", "verdict": "passed", "evidence": "ac3-grade-dourada.png"},
    {"ac": "AC4", "method": "manual", "verdict": "not_verified", "evidence": "roteiro em smoke.md"}
  ]
}
```

`smoke_passed` é `true` quando nenhum AC `smoke` reprovou **e** o log está limpo
**e** nenhum PNG contém dado pessoal. Um AC `manual` pendente não reprova o smoke
— mas aparece no relatório, e o card não fecha sem o dev confirmar.

## Antes de entregar

- Todo AC `smoke` do card tem um PNG nomeado por ele.
- Nenhum `frame%08d.png` sobrou na pasta.
- O log foi comparado com um baseline, não só lido.
- Todo AC que não deu para verificar está dito, com roteiro.
- Cada PNG foi olhado procurando dado pessoal.
