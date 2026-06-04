# TODO

# GERAL

## BUGs

### Alta prioridade

- [ ] **calculo_carga_horaria.gd:13** -- Revisar se a forma de calculo de percentagem do curso esta correta. Validar contra regras de negocio da universidade.

## A IMPLEMENTAR

- [ ] **Talvez usar Kinto** (https://github.com/Kinto/kinto) para salvar jsons em servidor próprio.
- [ ] **T90 (turma multi-curso)** — Turma 90 significa "oferecida para todos os cursos". Não implementado: requer alterações no `turma_para_curso()` em `analise_afinidade.gd:242` e possível seção `turmas_globais` no `base_config.json`. Não prioritário pois T90 não aparece no `horarios.txt` atual.
- [ ] **Sistema de dicas** Utilizar a DicaFlutuante para inserir dicas sobre funcionalidades do programa.
- [ ] No PlanejamentoHorarios, a ação Atualizar do planejamento não é clara.
- [ ] Chamar o claude pelo programa pra analisar os textos dos professores nas preferencias de horarios
- [ ] Ao importar o hist.csv, assume-se apenas um curso. Mas e se o hist.csv vier de diversos cursos, como fica? O programa está preparado para tal situação?

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
