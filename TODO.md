# TODO

# GERAL

## BUGs

### Alta prioridade

- [ ] **calculo_carga_horaria.gd:13** -- Revisar se a forma de calculo de percentagem do curso esta correta. Validar contra regras de negocio da universidade.

## A IMPLEMENTAR

- [x] **Usar Kinto** (https://github.com/Kinto/kinto) para salvar jsons em servidor próprio. — MVP implementado: módulo Planejamento de horário envia/baixa o planejamento de oferta (Enviar/Baixar/Configurar servidor no menu Arquivo › Servidor), via `SyncKinto` (`standalone_scripts/io/sincronizacao.gd`). Servidor Kinto na rede Tailscale; 1 record por curso (`id = <cod_curso>`, derivado do `ppc_principal`), login por coordenador com token revogável. Envio já **filtra o planejamento por curso** (só as disciplinas do próprio curso, via `prefixos_semestre`; compartilhadas entram nos dois). **Administração pela interface** (Configurações › "Administração do servidor…", `scenes/Complementares/PainelAdminKinto/` + `SyncKintoAdmin`): gerencia contas/grupo de coordenadores, apaga records, ajusta permissões e **mescla o campus** (record `campus` + `planejamento.json` local, com reconciliação de conflitos). Senha de admin opcional em `user://` (fora do OneDrive). Futuro: migrar servidor para infra da Unipampa.
- [ ] **Sincronização JSON** Cada coordenador controla um arquivo json e não pode editar as disciplinas dos outros coordenadores e seus JSON. As disciplinas compartilhadas, porém, podem ser editadas por qualquer coordenador que seja do curso da disciplina. Exemplo: Tanto o coordenador da Engenharia Civil quanto o coordenador da Engenharia Mecânica podem alterar os horários de EM01;EC02. — Parcial: camada de referência **somente-leitura** (Servidor › Ver outros cursos) sobrepõe o plano de outros cursos na grade, sinaliza compartilhadas em horário divergente e detecta choques de professor/sala entre cursos; export/envio nunca incluem a referência. Falta: permitir **editar** a compartilhada por qualquer coordenador do curso dela (escrita coordenada no record do dono).
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
