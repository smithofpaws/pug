# TODO

# GERAL

## BUGs

### Alta prioridade

- [ ] **calculo_carga_horaria.gd:13** -- Revisar se a forma de calculo de percentagem do curso esta correta. Validar contra regras de negocio da universidade.
- [x] **calculo da reprovação por nota e por falta** uma discente, por exemplo, tem 5 RN apesar de ter reprovado apenas uma vez. — Causa: o `hist.csv` exportado do GURI repete a mesma linha várias vezes (fan-out da consulta; no arquivo de 10/08/2026 são 17.799 linhas para 6.214 reais). `FileHandling.ler_dados` agora descarta, dentro de cada matrícula, linhas idênticas em todas as colunas lidas — reprovações da mesma disciplina em **semestres diferentes** continuam contando. Corrige junto o CR (`calculadorcr.gd` somava nota×CH por linha) e as contagens de Situação de Disciplinas.
- [ ] **indicador de matriculável na grade** as disciplinas matriculáveis e não matriculáveis tem a mesma cor de fonte na grade.

## A IMPLEMENTAR

- [ ] Chamar o claude pelo programa pra analisar os textos dos professores nas preferencias de horarios
- [ ] Adicionar ao SituaçãoAlunos o modo "Ajuste de Matrícula". Permite importar uma planilha csv ou direto a planilha resposta do google com atualização
- [ ] Nos exportadores de disciplinas falta indicar quais são corequisitos (os corequisitos aparecem apenas como pre)

## Divergências de CH entre grades `alec_2010` e `alec_2023`

Disciplinas compartilhadas cuja carga horária diverge entre as grades:

| Código | Nome | CH 2010 | CH 2023 |
|--------|------|---------|---------|
| `al5144` | Pavimentos e Meio Ambiente | 60 h | 30 h |
| `al5072` | Fundamentos de análise experimental de estruturas | 60 h | 30 h |
| `al5025` | Planejamento Experimental e Otimização de Processos | 60 h | 30 h |
| `al0157` | Trabalho de Conclusão de Curso II | 30 h (`ignorahora`) | sem campo `ch` |
| `al0148` | Trabalho de Conclusão de Curso I | 30 h (`ignorahora`) | sem campo `ch` |

---

# Modulo: Exportadores

## A IMPLEMENTAR

Tudo certo neste módulo.

---

# Modulo: LimeSurvey

## A IMPLEMENTAR

Tudo certo neste módulo.

---

# Modulo: Planejamento de Horario

## A IMPLEMENTAR

Clique com botão direito na grade ainda está subimplementado.

---

# Modulo: Planejamento de Oferta

## A IMPLEMENTAR

Tudo certo neste módulo.

---

# Modulo: Situacao Alunos

## BUGs

### Alta prioridade

### Media prioridade

## A IMPLEMENTAR

- [ ] **Verificar carga horária mínima do discente** nos horários e no trancamento (útil para verificar mínimo de 20h para bolsa).
- [ ] **Verificar se o cálculo da carga horária do aluno bate com a do sistema GURI**
- [ ] **Regra 2550h para TCC** — Verificar se `cargarequisito` nas grades (ex.: `alec_2010.json`) está correto e se a funcionalidade já é implementada em tempo de execução. Atualmente hardcoded em `situacao_alunos.gd:257-260`. Verificar também a funcionalidade geral de `cargarequisito` se está implementada (ex.: `al0410` Estágio tem `cargarequisito: "50"`).

---

# Modulo: Situacao Disciplinas

## A IMPLEMENTAR

- [ ] **Modo de ver os dias das aulas de todos professores** ou professores selecionados, útil para marcar reuniões.
- [ ] **Verificar discentes sem matrículas no semestre** ou nos últimos semestres.

---

# Modulo: Calculador de CR

## A IMPLEMENTAR

- [ ] **Adicionar CR por área da disciplina** — detalhar área no JSON para saber se aluno é melhor em área A ou B.
- [ ] **Adicionar seleção de disciplinas para calcular o CR** apenas das selecionadas.

---

# Modulo: Trancamentos

## A IMPLEMENTAR

- [ ] **trancamentos.gd** -- Revisar integracao com `base_config.json:48` (`"enabled": false`). Modulo desabilitado por padrao.

---

# Novos Modulos Sugeridos

- [ ] **Módulo de verificação de carga horária mínima** para análise de bolsas (mínimo de 20h).
- [ ] **Opção de mostrar disciplinas não suprimidas no tempo** (ex.: mostrar IEC ao invés de ICT).
