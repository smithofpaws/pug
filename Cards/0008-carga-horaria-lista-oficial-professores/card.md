---
id: 0008-carga-horaria-lista-oficial-professores
title: Verificar carga horária inclui a lista oficial de professores do curso
status: ready
origin: novo (pedido do dev)
layers: [standalone_scripts/analise, scenes/Modulos/PlanejamentoOferta, arquivos/dicas.json, MANUAL.md]
interviewed: true
---

# 0008 - Verificar carga horária inclui a lista oficial de professores do curso

## Goal
Em **Planejamento de Oferta › Carga horária › Verificar carga horária**, com um
curso no filtro, o relatório passa a listar **também** todos os professores da
lista oficial do curso (`arquivos/oferta/lista_professores.json`), inclusive os
que não têm carga no plano e os que nunca lecionaram para o curso pelo
histórico. Assim, quem foi esquecido no planejamento aparece como "abaixo do
mínimo" em vez de sumir.

## Contexto
Regra de hoje (`RelatoriosOferta.verificar_carga_horaria`):
- só entra quem tem carga no plano (`_calcular_carga_por_prof`);
- com filtro de curso, só quem já lecionou para o curso pelo código de turma
  do histórico (`AnaliseAfinidade.professores_do_curso`).

A **Sugestão de oferta** já une plano e lista oficial
(`relatorios_oferta.gd`, perto da linha 393): a lista entra só com filtro, e
quem não está no plano aparece com carga 0. O conjunto da lista para o curso
filtrado já é calculado pelo módulo em `_calcular_profs_destacar()`, a partir
de `base_config.json:cursos.<cod>.prefixos_semestre` (a lista usa como chave o
prefixo de semestre, ex.: `ec`).

## Non-goals
- **Sem filtro de curso, nada muda.** A lista oficial só entra com filtro
  (decisão do dev, igual à Sugestão de oferta).
- **Sem rótulo novo:** quem tem 0 cr cai na regra normal, "abaixo do mínimo",
  na cor de aviso que já existe. Nada de "não alocado".
- **Não muda a regra atual, só acrescenta:** quem entra hoje continua entrando.
- **Não muda** o painel lateral "Carga horária" (ao clicar numa disciplina), a
  Sugestão de oferta, a Verificação de erro de afinidade nem o Verificador de
  carga horária (diária) do Planejamento de Horário.
- **Não muda** o formato do `lista_professores.json` (chave por prefixo de
  semestre) nem o `normalizar_nome`.
- **Não lê arquivo novo:** a lista já é injetada pelo `main.gd`.

## Acceptance criteria
A escolha de quem entra no relatório, com qual carga e qual status, sai do
`verificar_carga_horaria` para uma **função pura** testável headless (lugar e
assinatura definidos no design). O relatório passa a só imprimir o resultado.
Testes com nomes fictícios.

- [ ] Com filtro, professor da lista oficial sem carga no plano entra com 0 cr e status "abaixo do mínimo" -- verify: `headless`
- [ ] Com filtro, professor da lista oficial com carga no plano que nunca lecionou para o curso entra com a carga real (hoje fica de fora) -- verify: `headless`
- [ ] Com filtro, professor com carga que lecionou para o curso e **não** está na lista continua entrando (regra atual preservada) -- verify: `headless`
- [ ] Com filtro, professor com carga que não lecionou para o curso e não está na lista continua fora -- verify: `headless`
- [ ] Sem filtro, a lista oficial não acrescenta ninguém: o resultado é o de hoje (todos com carga no plano) -- verify: `headless`
- [ ] Professor que está na lista e no plano aparece **uma vez**, com a carga do plano (nome da lista com `_`, ex.: `Maria_da_Silva_Souza`, casa com `Maria Da Silva Souza` via `normalizar_nome`) -- verify: `headless`
- [ ] Só entra a lista das chaves que correspondem aos `prefixos_semestre` do curso filtrado; lista de outro curso não entra -- verify: `headless`
- [ ] Lista oficial vazia ou ausente dá o mesmo resultado de hoje, sem erro -- verify: `headless`
- [ ] Status pelos limites de `config_oferta` (`ch_minimo`, `ch_ideal`, `ch_maximo`), sem mudança de regra: acima do máximo, acima do ideal, abaixo do mínimo, OK, testado nas fronteiras -- verify: `headless`
- [ ] Ordem: carga decrescente, empate pelo nome (determinística; hoje o empate fica em ordem indefinida, e os vários 0 cr tornariam isso visível) -- verify: `headless`
- [ ] Plano sem nenhuma alocação mantém a mensagem "Nenhum professor alocado.", mesmo com filtro e lista -- verify: `headless`
- [ ] Com os dados reais e o filtro em Engenharia Civil, o relatório traz os 14 professores da lista, e os sem carga aparecem como "abaixo do mínimo" -- verify: `manual`
- [ ] A dica da ação (`arquivos/dicas.json`, `planejamento_oferta_acoes.verificar_carga_horaria`) e o `MANUAL.md` (Planejamento de Oferta › Ações disponíveis) descrevem a regra nova -- verify: `manual`

## Edge cases
- **Grafia do nome:** `normalizar_nome` troca `_` por espaço e põe maiúscula
  na primeira letra de cada palavra, mas **não** ignora caixa nem acento. Um
  nome que, na lista, difira do plano só por caixa ou acento sairia
  **duplicado** (uma linha com a carga, outra com 0). Nos dados de hoje os 14
  nomes casam. É a mesma limitação da Sugestão de oferta e do destaque de
  afinidade; não é corrigida aqui.
- **Chave da lista:** comparada sem diferenciar maiúsculas (já é assim em
  `_inicializar_lista_professores`). Entrada que não é Array é ignorada, como
  hoje.
- **Carga é do plano inteiro:** a carga mostrada soma todas as disciplinas do
  plano, de qualquer curso, como hoje. O filtro escolhe **quem** aparece, não
  **o que** se soma.
- **Mensagens de lista vazia:** "Nenhum professor alocado que tenha lecionado
  para o curso." só aparece se, depois da união, ninguém sobrar (lista ausente
  e ninguém do histórico).
- **LGPD:** nomes de docente só no Terminal, como hoje. Os testes e qualquer
  fixture usam nomes fictícios; nada de `arquivos/oferta/` (gitignorado) entra
  em teste versionado.

## Smoke scenarios
Nenhum. A lógica nova é pura e testada headless. O relatório só imprime, e a
conferência na tela é `manual`, com dados reais de docentes, que não viram
PNG versionado.

## Observação lateral (fora do escopo)
O `MANUAL.md` diz que a **Sugestão de oferta**, com filtro, "considera apenas
professores que já lecionaram para esse curso". O código prefere a lista
oficial e só cai no histórico quando ela não cobre o curso
(`relatorios_oferta.gd`, perto da linha 393). O manual está desatualizado
nesse ponto.
