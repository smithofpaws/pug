# IDEAS

Backlog de ideias e pendências, organizado por módulo. Nada aqui tem critério de
aceite acordado nem prazo — quando um item amadurecer a ponto de virar trabalho,
ele sobe para um card em `Cards/` pela entrevista da skill `godot-session-setup`
(ou pelo modo migração, que o transcreve como card `todo` sem entrevista).
Apagar uma linha não exige justificativa.

# GERAL

- Adicionar no PUG também o ranking, para saber se a pessoa está no horário correto;
- Na grade de integralização, indicar a origem de uma disciplina concluída por equivalência (ex.: tooltip `DicaFlutuante` na célula mostrando o código cursado e a grade de origem). A célula da `Grade` não tem tooltip hoje — seria infraestrutura nova no componente; ficou de fora do card 0004 por decisão de escopo. Alternativa mais barata: linha no relatório do terminal.
- Adicionar um check online para bloquear o software de funcionar se eu quiser;
- **Auditar as atas aprovadas contra o `alec-data`.** Duas decisões já foram encontradas aplicadas pela metade (a de 2025, SEI 1848924, teve o item de grade corrigido em 2026-08-25). Faltam conferir as demais pastas de `Coordenacao/Atualizacao PPCs/` — 21 pastas, ~65 PDFs: `2025 ACGs 2023`, `2025 Correcao da carga horaria total`, `2025 Pre requisitos tabela 6`, `2026 Alteracao regulamentacao AGC`, `2026 Regra de aproveitamento` e as de disciplina individual. É trabalho de dado, não de código — o card 0005 automatiza só a detecção dos defeitos estruturais.
- **Chave `agc` vs `acg` na carga exigida.** `cargaexigida/alec_2010.json` usa `agc`; a `alec_2023.json` usa `acg` (Atividades Complementares de Graduação). Nenhum `.gd` lê essas chaves pelo nome, então nada quebra visivelmente — mas a chave entra no denominador de `CalculoCargaHoraria.percentagem_curso` sem nunca somar no numerador. Decidir qual é a grafia boa e unificar (o `alec_2010` é do `alec-data`; editar lá).
- Na `alec_2023`, `al5022` (Metodologia de Trabalho Científico) tem `prerequisito0: "ch 50%"` — texto livre num campo que em todo o resto contém código de disciplina. Provável candidato a `cargarequisito`. Editar no `alec-data`.

## BUGs

### Alta prioridade

- [ ] **`CalculoCargaHoraria.percentagem_curso`** — o percentual de conclusão do curso está errado. Quatro defeitos já levantados:
  1. Reprovações e trancamentos contam como CH vencida (o filtro é "não-matriculado" em vez de aprovado/dispensado);
  2. Sem teto por núcleo e sem conferência de que as chaves do `estcurricular` batem com as da carga exigida;
  3. `ignorahora` ajusta o denominador (`AnaliseGrades.ajustarch_tccestagio`) mas não o numerador;
  4. Equivalências não expandem — mesma raiz do card 0004.

  Os itens **1 e 3** são corrigíveis sem regra de negócio nova (candidatos a um card headless); o **2** depende da fórmula oficial da Unipampa. Validar o resultado contra o GURI (ver Situação Alunos › A IMPLEMENTAR).

## A IMPLEMENTAR

- [ ] **Texto re-anexado some no caminho multi-código do ajuste** Em `PlanilhaAjuste`, um fragmento sem código re-anexado (card 0003) a uma menção com 2 ou mais códigos é descartado do retorno — `_mesclar_lado` (card 0002) emite o código puro nesse caminho, então o texto não vira menção nem problema (antes do 0003 aparecia como "código inválido/ausente"). Ajustar `_mesclar_lado` para não descartar o texto re-anexado; comportamento atual travado em `test_fragmento_reanexado_a_mencao_multi_codigo_perde_o_texto`.
- [ ] **Colisão de cor na paleta semântica** `matriculavel_aproveitamento` e `corequisito_matriculavel` usam ambos `WEB_GRAY` em `paleta_semantica.gd`, ficando indistinguíveis. O desenho previsto pelo próprio arquivo é uma matiz por família (matriculável, corequisito, seaprovado) com o alvo de contraste sutil diferenciando a variante `_aproveitamento` — decidir as matizes e unificar.
- [ ] Chamar o claude pelo programa pra analisar os textos dos professores nas preferencias de horarios
- [ ] **Importar planilha CSV local no Modo Ajuste** O Modo Ajuste do SituaçãoAlunos já existe, mas só baixa a planilha do Google publicada, por URL (`PlanilhaAjuste.baixar`; endereço em `config_usuario.json:modo_ajuste.url_planilha`). Falta o caminho de abrir um `.csv` do disco — útil sem rede ou com a planilha exportada à mão.
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

- [ ] **Verificar carga horária mínima do discente** nos horários e no trancamento, para conferir o mínimo de 20h exigido para bolsa. (Absorve a ideia de um módulo próprio de verificação de CH mínima, que estava repetida em "Novos Módulos Sugeridos".)
- [ ] **Verificar se o cálculo da carga horária do aluno bate com a do sistema GURI** — mesma área do bug de `CalculoCargaHoraria.percentagem_curso` (GERAL › BUGs › Alta prioridade); bater contra o GURI é o teste de aceitação natural daquela correção.
- [ ] **Regra 2550h para TCC** — a exigência está hardcoded em `situacao_alunos.gd:386-388`, com um `TODO` no próprio arquivo para movê-la para `base_config.json:cursos`. O consumo genérico de `cargarequisito` **já existe** (`analise_curricular.gd:172`); falta conferir se os valores nas grades estão certos (ex.: `al0410` Estágio, `cargarequisito: "50"`).

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

- [ ] **trancamentos.gd** — revisar a integração; o módulo vem desabilitado por padrão (`base_config.json:modulos.trancamento = false`).

---

# Novos Modulos Sugeridos

- [ ] **Opção de mostrar disciplinas não suprimidas no tempo** (ex.: mostrar IEC ao invés de ICT).
