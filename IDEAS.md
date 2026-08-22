# IDEAS

Backlog de ideias e pendências, organizado por módulo. Nada aqui tem critério de
aceite acordado nem prazo — quando um item amadurecer a ponto de virar trabalho,
ele sobe para um card em `Cards/` pela entrevista da skill `godot-session-setup`
(ou pelo modo migração, que o transcreve como card `todo` sem entrevista).
Apagar uma linha não exige justificativa.

# GERAL

- Adicionar no PUG também o ranking, para saber se a pessoa está no horário correto;
- Atualizar no json 2023 que parece que inst eletrica predial nao tem arquitetura;
- Adicionar um check online para bloquear o software de funcionar se eu quiser;

## BUGs

### Alta prioridade

- [ ] **calculo_carga_horaria.gd:13** -- Revisar se a forma de calculo de percentagem do curso esta correta. Validar contra regras de negocio da universidade.
- [x] **calculo da reprovação por nota e por falta** uma discente, por exemplo, aparecia com 5 RN apesar de ter reprovado apenas uma vez. — Causa: o `hist.csv` exportado do GURI repete a mesma linha várias vezes (fan-out da consulta; no arquivo de 10/08/2026 são 17.799 linhas para 6.214 reais). `FileHandling.ler_dados` agora descarta, dentro de cada matrícula, linhas idênticas em todas as colunas lidas — reprovações da mesma disciplina em **semestres diferentes** continuam contando. Corrige junto o CR (`calculadorcr.gd` somava nota×CH por linha) e as contagens de Situação de Disciplinas.
- [x] **indicador de matriculável na grade** as disciplinas matriculáveis e não matriculáveis tem a mesma cor de fonte na grade. — Resolvido por **hachura**, não por cor: na grade de integralização as disciplinas ainda **distantes** (nenhuma condição e não concluídas — dependem de uma cadeia de aprovações) recebem hachura leve, ficando levemente mais escuras (`AnaliseGrades.disciplinas_distantes` + `HachuraOverlay.leve`). Assim, matriculável e distante deixam de ser indistinguíveis mesmo mantendo a mesma cor de fonte. A alternativa por cor foi testada e descartada (`matriculavel` segue como token neutro em `paleta_semantica.gd`).
- [ ] **disciplina concluída por equivalência não recebe cor na grade** Quem cursou a disciplina sob o código de outra grade (ex.: discente aprovado em `al0383` Mecânica dos Solos I da `alec_2023`, equivalente a `al0067` da `alec_2010`) aparece na grade **sem cor nenhuma** — igual a uma disciplina matriculável. `disciplinas_concluidas` só olha os códigos brutos do histórico, sem expandir equivalências. A hachura de distantes já trata esses casos corretamente (não os hachura, via `AnaliseGrades.disciplinas_distantes`), mas a **cor** de "cursada" continua faltando. Decidir se a concluída por equivalência recebe o dourado de "cursada" ou um token próprio.

## A IMPLEMENTAR

- [ ] **Colisão de cor na paleta semântica** `matriculavel_aproveitamento` e `corequisito_matriculavel` usam ambos `WEB_GRAY` em `paleta_semantica.gd`, ficando indistinguíveis. O desenho previsto pelo próprio arquivo é uma matiz por família (matriculável, corequisito, seaprovado) com o alvo de contraste sutil diferenciando a variante `_aproveitamento` — decidir as matizes e unificar.
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
