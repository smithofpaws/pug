---
id: 0003-reanexar-fragmentos-rotulo-ajuste
title: Re-anexar fragmentos de rótulo sem código no ajuste de matrícula
status: done
origin: IDEAS.md (seção GERAL)
layers: [standalone_scripts/io]
interviewed: true
---

# 0003 - Re-anexar fragmentos de rótulo sem código no ajuste de matrícula

## Goal

O Forms junta as opções marcadas numa célula separadas por vírgula — e um
rótulo de opção que contém vírgulas hoje é estilhaçado em entradas falsas
("T40;60;80", nome do professor), que o módulo exibe como "código
inválido/ausente" e alerta para cada aluno que marcou a disciplina.

`PlanilhaAjuste.parse()` passa a dividir a célula em menções **pelos fragmentos
que contêm código extraível**: fragmento sem código é re-anexado à entrada
anterior da mesma célula (re-juntado com ", "), reconstituindo o texto
original. Uma opção marcada = uma menção, mesmo com vírgulas no rótulo.

## Non-goals

- Mudar o formulário ou recomendar formato de rótulo (fora do programa);
- Validar códigos contra as grades (continua no módulo);
- Mexer em `situacao_alunos.gd` ou na exibição;
- Tratar o residual do regex do 0002 (token curto isolado, "Lab 101");
- Mudanças em `baixar()`.

## Acceptance criteria

- [x] Célula `"AL0394: Administração, T40;60;80, João Pereira Lima;"` produz
      UMA menção (código `al0394`) e zero problemas -- verify: `headless`
- [x] Duas opções com código na mesma célula, cada uma com vírgulas no rótulo,
      produzem DUAS menções com os códigos corretos -- verify: `headless`
- [x] Fragmento sem código no INÍCIO da célula (sem entrada anterior) continua
      como problema visível -- verify: `headless`
- [x] Célula só com texto livre com vírgulas vira UM problema com o texto
      re-juntado -- verify: `headless`
- [x] Comportamento aceito travado em teste: texto livre após vírgula numa
      menção com código é absorvido por ela (não alerta mais) -- verify: `headless`
- [x] Suíte do 0002 continua verde sem alteração nos testes existentes
      -- verify: `headless`

## Edge cases

- Fragmento que contém código nunca é re-anexado — ele é o delimitador que
  inicia menção nova;
- O re-anexo acontece na separação de entradas, ANTES da mesclagem do 0002:
  decisão por código, "menção mais recente vence", exclusão prevalece na mesma
  resposta e dedup de problemas por texto normalizado seguem intactos;
- Rótulo sem vírgulas (formato atual do formulário, "Nome - Professor -
  AL0385 - T20") não é dividido — comportamento idêntico ao de hoje;
- Trade-off aceito na entrevista: pedido em texto livre escrito após vírgula
  numa menção válida ("AL0400 Fundações, quero também a de concreto") é
  absorvido pela menção e deixa de aparecer como "código inválido/ausente".

## Smoke scenarios

Nenhum (todos os ACs são `headless`; `parse()` é função pura String →
Dictionary, provada em `test/unit/test_planilha_ajuste.gd`).
