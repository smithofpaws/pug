---
id: 0009-busca-no-terminal
title: Busca com Ctrl+F no Terminal
status: in_progress
origin: novo (pedido do dev)
layers: [standalone_scripts/utils, scenes/Complementares/Terminal, MANUAL.md]
interviewed: true
---

# 0009 - Busca com Ctrl+F no Terminal

> Pipeline concluído em 2026-10-02 (fila, branch `cards/2026-10-02`), em 1
> rodada: os 8 ACs `headless` estão provados e a suíte passa 137/137. O card
> **não** é `done` porque os ACs 9 a 16 são `manual` (teclado, foco, rolagem,
> cópia, tema, dicas e manual) e só fecham por relato do dev. Roteiro em
> `spec.md` (R1 a R8). Os testes de fiação (`test_terminal_fiacao_busca.gd`)
> exercitam a cena real e servem de apoio, mas não substituem o roteiro.

## Goal
Com o foco no Terminal (depois de clicar nele), **Ctrl+F** abre uma faixa de
busca no topo. Ao digitar, todas as ocorrências ficam realçadas, a atual com
destaque mais forte, e a tela rola até ela. **Enter** vai para a próxima e
**Shift+Enter** para a anterior, em ciclo. Como o Terminal é um componente
único, a busca vale em todos os módulos sem mudar nenhum deles.

## Contexto técnico
- O Terminal (`scenes/Complementares/Terminal/`) é um `ReferenceRect` com um
  `RichTextLabel` (`%TextEdit`, BBCode, `selection_enabled`, `focus_mode` ALL)
  e guarda o que foi escrito em `_buffer` (texto, token de cor, efeito, quebra
  de linha, fundo). A troca de tema re-renderiza tudo a partir do buffer
  (`_renderizar`).
- O `RichTextLabel` do Godot 4.7.2 **não** seleciona um trecho por código (só
  `select_all`/`deselect`). Ele oferece `get_parsed_text`,
  `get_character_line`/`get_character_paragraph` e
  `scroll_to_line`/`scroll_to_paragraph`. Portanto o realce é feito
  **re-renderizando o BBCode** com `[bgcolor]` em volta das ocorrências, e a
  rolagem usa as funções de linha.
- O texto das entradas pode conter BBCode (`[url=chave]` das dicas, `[b]`) e
  as tags de cor que o próprio Terminal gera (`[color=#...]`). A busca precisa
  enxergar só o **texto visível**.
- Não há atalho Ctrl+F em uso no programa. O precedente de atalho é o Ctrl+Z do
  Planejamento de Horário (`_unhandled_key_input`, que não dispara quando um
  campo de texto consumiu a tecla).

## Decisões do dev
- Compara **ignorando maiúsculas e acentos** (`calculo` acha `Cálculo`).
- Realça **todas** as ocorrências (fundo leve) e a **atual** (fundo forte), com
  contador `i de n`.
- Busca **ao digitar**, rolando até a primeira ocorrência.
- **Shift+Enter** volta; navegação **circular**; **Esc** fecha; botões
  **↑ ↓ ✕** na faixa.
- Qualquer **mudança de conteúdo** do Terminal com a faixa aberta **fecha** a
  busca e remove o realce.
- A faixa ocupa a **largura total** no topo e **empurra** o texto para baixo
  enquanto está aberta.

## Non-goals
- **Nenhum módulo muda.** A API pública do Terminal (`titulo`, `secao`, `item`,
  `linha`, `text_edit`, `registrar_meta`...) continua igual, e nenhum chamador
  precisa ser tocado.
- Busca em outros componentes (grades, listas, painéis, seletores, diálogos).
- Substituir, regex, "palavra inteira" ou opção de diferenciar maiúsculas.
- Ctrl+F com o foco fora do Terminal (atalho global).
- Guardar o termo ou um histórico de buscas entre sessões.
- Manter o realce depois de uma mudança de conteúdo (a faixa fecha).
- Cor nova: o realce usa o token `selecao` da `PaletaSemantica`, com
  intensidades diferentes para "todas" e "atual".

## Acceptance criteria
A lógica de busca fica numa classe **pura** em `standalone_scripts/utils/`
(nome e assinatura no design): recebe o buffer de entradas do Terminal e o
termo, e devolve as ocorrências e o BBCode realçado. O Terminal só cuida de
teclado, faixa e rolagem.

- [x] Ignora maiúsculas e acentos: `calculo` encontra `Cálculo` e `CÁLCULO`; `acao` encontra `Ação` -- verify: `headless`
- [x] Ocorrências saem na ordem do texto e sem sobreposição (`aa` em `aaaa` dá 2); termo vazio ou só espaços dá nenhuma -- verify: `headless`
- [x] Só o texto visível conta: o termo não casa dentro de tags (`[color=#ffcc00]`, `[url=chave]`, `[bgcolor=...]`) -- verify: `headless`
- [x] Ocorrência que atravessa duas entradas do buffer na mesma linha (segmentos de cores diferentes, `newline = false`) é encontrada e realçada nas duas partes -- verify: `headless`
- [x] Realçar não altera o conteúdo: removidas as tags, o BBCode realçado dá exatamente o mesmo texto visível do original, inclusive com tag no meio de uma ocorrência -- verify: `headless`
- [x] A ocorrência atual recebe realce diferente das demais, e trocar a atual só move o realce forte -- verify: `headless`
- [x] Navegação circular: depois da última vem a primeira, antes da primeira vem a última; com zero ocorrências não há atual -- verify: `headless`
- [x] Os testes existentes seguem passando -- verify: `headless`
- [ ] Clicar no Terminal e apertar Ctrl+F abre a faixa no topo com o campo focado, e o texto desce; Ctrl+F com o foco fora do Terminal não abre nada. Conferido em pelo menos dois módulos (ex.: Situação de Alunos e Planejamento de Oferta) -- verify: `manual`
- [ ] Ao digitar, todas as ocorrências ficam realçadas, a primeira com destaque forte, a tela rola até ela e o contador mostra `1 de N`; sem ocorrências, o contador indica zero e Enter não faz nada -- verify: `manual`
- [ ] Enter e ↓ vão para a próxima, Shift+Enter e ↑ para a anterior, em ciclo, e a rolagem acompanha -- verify: `manual`
- [ ] Esc ou ✕ fecham a faixa, removem o realce e devolvem o foco ao Terminal; a rolagem fica onde estava, sem pular para o início nem para o fim -- verify: `manual`
- [ ] Com a faixa aberta, uma mudança de conteúdo (ex.: trocar de aluno) fecha a faixa e remove o realce; trocar o **tema** não fecha e mantém o realce nas cores do tema novo -- verify: `manual`
- [ ] Copiar (Ctrl+C) um trecho com realce ativo dá o mesmo texto que sem realce -- verify: `manual`
- [ ] Os botões ↑ ↓ ✕ têm dica via `DicaFlutuante`, citando o atalho (Shift+Enter, Enter, Esc) -- verify: `manual`
- [ ] O `MANUAL.md` (seção 3.2, Terminal) descreve a busca e os atalhos -- verify: `manual`

## Edge cases
- **Desempenho:** realçar re-renderiza o Terminal inteiro a cada tecla. Um
  relatório longo (milhares de linhas) não pode travar a digitação; se travar,
  adiar a busca alguns milissegundos depois da última tecla é aceitável.
- **Saída assíncrona:** uma linha nova escrita por uma operação em andamento
  (rede, sincronização) fecha a faixa mesmo no meio da digitação. É
  consequência aceita da decisão "mudança de conteúdo fecha".
- **Reabrir:** Ctrl+F de novo, com a faixa aberta, só devolve o foco ao campo e
  seleciona o termo. Depois de fechada, reabre com o último termo já
  selecionado (digitar substitui), como no navegador.
- **Seleção do usuário:** re-renderizar desfaz a seleção de texto feita com o
  mouse. É aceitável enquanto a busca está aberta.
- **Colchete literal:** texto com `[` que não é tag precisa continuar aparecendo
  igual depois do realce.
- **Rolagem ao fechar:** remover o realce também re-renderiza; a posição de
  leitura tem de ser preservada, não resetada.
- **LGPD:** a busca é local; o termo não é gravado em lugar nenhum.

## Smoke scenarios
Nenhum. A lógica é pura e testada headless. Todos os ACs visuais dependem de
teclado e foco, para os quais não há harness de input: são `manual`, roteiro
para o dev.
