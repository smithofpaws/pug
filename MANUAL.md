# Manual do Usuário — Pacote de Utilidades para Graduação (PUG)

## Sumário

1. [Visão Geral](#1-visão-geral)
2. [Primeiros Passos](#2-primeiros-passos)
3. [Interface Principal](#3-interface-principal)
4. [Módulos](#4-módulos)
   - [Tela Principal](#41-tela-principal)
   - [Calculador de CR](#42-calculador-de-cr)
   - [Situação de Alunos](#43-situação-de-alunos)
   - [Situação de Disciplinas](#44-situação-de-disciplinas)
   - [Planejamento de Oferta](#45-planejamento-de-oferta)
   - [Planejamento de Horário](#46-planejamento-de-horário)
   - [Exportadores](#47-exportadores)
   - [Matrícula Irregular](#48-matrícula-irregular)
   - [Trancamentos](#49-trancamentos)
5. [Configurações](#5-configurações)
6. [Arquivos de Entrada](#6-arquivos-de-entrada)
7. [Arquivos de Saída](#7-arquivos-de-saída)
8. [Fluxo de Trabalho Típico](#8-fluxo-de-trabalho-típico)

---

## 1. Visão Geral

O **Pacote de Utilidades para Graduação (PUG)** é uma ferramenta de apoio à coordenação acadêmica e dos cursos. Com ele, é possível analisar a situação de alunos e disciplinas, planejar a oferta semestral e a grade de horários, calcular coeficientes de rendimento, identificar matrículas irregulares e gerar relatórios para diferentes públicos.

O programa é organizado em **módulos independentes**, acessíveis pela barra de navegação no topo da janela. Cada módulo trabalha com um conjunto específico de arquivos de entrada e produz resultados próprios.

---

## 2. Primeiros Passos

### 2.1 Arquivos necessários

O programa lê arquivos externos fornecidos pelo usuário. Antes de usar qualquer módulo, verifique quais arquivos ele exige e coloque-os na pasta `dados/` dentro do diretório do programa.

| Arquivo | Descrição |
|---|---|
| `hist.csv` | Histórico acadêmico exportado do GURI: matrículas, disciplinas, notas e situações |
| `horarios.txt` | Grade de horários do semestre atual: professor, sala, horário, turma e vagas |
| `planejamento.csv` | Oferta de disciplinas: código, carga horária e professor(es) alocado(s) |

Cada módulo indica, ao ser aberto, quais desses arquivos são obrigatórios para seu funcionamento.

### 2.2 Navegação

Use o **menu suspenso** no topo da janela para trocar de módulo a qualquer momento. O módulo anterior é descarregado e o novo é carregado em seu lugar.

---

## 3. Interface Principal

### 3.1 Barra de navegação

Localizada no topo da janela. Contém:

- **Seletor de módulo** — menu suspenso para escolher o módulo ativo.
- **Ícone de configurações** — abre a janela de configurações do programa.
- **Indicador de problemas** — exibe alertas quando algum arquivo necessário está ausente ou com erro.

### 3.2 Terminal

Vários módulos exibem um painel de texto (chamado *terminal*) com análises, relatórios e avisos em texto colorido. O terminal pode ser ocultado e reexibido com o botão correspondente; o conteúdo é preservado.

### 3.3 Botões de painel (mostrar/ocultar)

Vários módulos têm botões que mostram ou ocultam painéis — terminal, grade de horários, grade curricular, painel de disciplinas, etc. Esses botões têm dois comportamentos:

- **Clique normal:** alterna apenas aquele painel (mostra se estava oculto, oculta se estava visível); os demais não mudam.
- **Shift + clique:** *isola* o painel — deixa visível somente o painel clicado e oculta todos os outros do módulo. Repetir o Shift + clique no painel já isolado **restaura** todos os painéis. Útil para focar rapidamente em um painel sem ter de ocultar os demais um a um.

Cada botão indica seu estado: aparece **pressionado (afundado)** quando o painel que ele controla está visível e **solto** quando o painel está oculto. O realce acompanha o tema em uso.

### 3.4 Dicas flutuantes

Ao posicionar o cursor sobre elementos da interface, uma dica flutuante pode aparecer explicando a função daquele elemento.

---

## 4. Módulos

### 4.1 Tela Principal

A tela inicial do programa. Exibe o nome do programa e os módulos disponíveis. Quando algum arquivo necessário está ausente ou há erros de carregamento, as informações de diagnóstico aparecem aqui.

---

### 4.2 Calculador de CR

**Arquivos necessários:** `hist.csv`

Calcula o Coeficiente de Rendimento (CR) dos discentes a partir do histórico acadêmico.

#### Tipos de análise

- **Prováveis formandos** — lista todos os alunos próximos de concluir o curso, ordenados do maior para o menor CR.
- **Aluno específico** — análise detalhada de um único aluno selecionado.

#### O que é exibido

O terminal mostra, para cada aluno analisado:

- Nome e CR (escala 0–10).
- Carga horária acumulada por grupo complementar (Ensino, Pesquisa, Extensão, Cultura).
- Indicação de TCC concluído.

#### Regras de cálculo

- Dispensas são contabilizadas com nota 6.
- Reprovações por frequência entram na carga horária, mas não na média.
- O cálculo respeita os grupos complementares definidos para o currículo do aluno.

---

### 4.3 Situação de Alunos

**Arquivos necessários:** `hist.csv`, `horarios.txt`

Módulo central de análise individual. Permite examinar em detalhes a situação acadêmica de qualquer aluno do histórico.

#### Seleção de aluno

Escolha o aluno pelo menu suspenso no topo do módulo. A interface é atualizada imediatamente com os dados do aluno selecionado.

#### Grade curricular

Exibe a estrutura completa do currículo, organizada por semestres. Cada célula representa uma disciplina e recebe uma cor conforme a situação do aluno nela (cursada, disponível para matrícula, bloqueada por pré-requisitos, etc.).

- **Clique esquerdo** em uma disciplina: destaca todos os seus pré-requisitos (diretos e transitivos), com linhas de conexão entre elas.
- **Clique direito** em uma disciplina: destaca todas as disciplinas que dependem dela, ou seja, que ficam bloqueadas enquanto ela não for cursada.

O formato de exibição das células pode ser alterado: somente código, código e nome, nome completo ou esferas coloridas.

#### Grade de horários

Exibe uma tabela com os horários do semestre (linhas) cruzados com os dias da semana (colunas). Mostra:

- Disciplinas nas quais o aluno **já está matriculado**.
- Disciplinas nas quais o aluno **poderia se matricular**, conforme os pré-requisitos.
- **Indicação de choque:** quando uma disciplina disponível conflita com uma já matriculada no mesmo horário.

Filtros permitem exibir apenas disciplinas em condições específicas (matriculado, matriculável, etc.).

#### Relatório no terminal

O terminal apresenta um relatório completo do aluno:

- Versão do currículo e matrícula.
- Carga horária vencida por categoria (obrigatória, complementar, etc.).
- Disciplinas cursadas fora da grade atual.
- Histórico de reprovações (por nota e por frequência).
- Lista de disciplinas organizadas por condição de matrícula:
  - **Matriculado agora** — disciplinas em que está cursando neste semestre.
  - **Matriculável** — cumpridos todos os pré-requisitos, sem choque de horário.
  - **Se aprovado** — poderá cursar se for aprovado nas disciplinas do semestre atual.
  - **Corequisito matriculável** — pode ser cursada junto com outra disciplina específica.
  - **Matrícula irregular** — matriculado sem cumprir os pré-requisitos (requer atenção).
- Para cada disciplina: código, nome, créditos e histórico de reprovações nela.

#### Exportação

O botão **Exportar** gera um arquivo Markdown com a situação de todos os alunos do histórico, incluindo carga horária vencida e condições de matrícula de cada um.

---

### 4.4 Situação de Disciplinas

**Arquivos necessários:** `hist.csv`, `horarios.txt`

Analisa o perfil de discentes vinculados a uma ou duas disciplinas.

#### Tipos de análise

Selecione o tipo no menu suspenso:

- **Análise isolada** — foca em uma única disciplina.
- **Comparação** — coloca duas disciplinas lado a lado.

#### Análise isolada

Escolha a disciplina (separada entre obrigatórias e complementares) e a versão de grade. O terminal exibe:

- O núcleo a que a disciplina pertence (obrigatória, complementar, CCCG).
- A lista de alunos matriculados, agrupados por condição (matriculado agora, matriculável, etc.).
- O histórico de reprovações de cada aluno nesta disciplina.

A grade de horários mostra a ocupação **consolidada** de todos os alunos vinculados à disciplina — um panorama de quais horários estão livres ou ocupados pela turma, útil para decidir o melhor horário para a aula.

#### Comparação entre duas disciplinas

Selecione duas disciplinas. O terminal exibe os alunos que aparecem **em ambas**, com a condição de cada um em cada disciplina. Ajuda a entender relações de dependência indireta ou conflitos de público entre duas disciplinas.

Na comparação, a grade de horários não está disponível.

---

### 4.5 Planejamento de Oferta

**Arquivos necessários:** `hist.csv`, `planejamento.csv` (opcional como base inicial)

Apoia a decisão de **quais disciplinas oferecer** e **quais professores alocar** no semestre seguinte.

#### Menu Arquivo

Todas as operações de arquivo ficam reunidas no botão **Arquivo**, organizado em grupos:

- **Locais**
  - **Abrir planejamento.json** — retoma um planejamento salvo anteriormente pelo próprio programa (formato `.json`).
  - **Abrir planejamento.csv** — carrega o `planejamento.csv` do diretório de saída como ponto de partida (oferta anterior, por exemplo).
  - **Salvar planejamento.json** — salva o estado atual em formato `.json` para retomar depois.
- **Grades** — usa a grade de um curso como sugestão de disciplinas a ofertar.
- **Importar**
  - **planejamento.csv** — seleciona um `planejamento.csv` externo, converte para UTF-8 e o salva no diretório de saída.
- **Exportar**
  - **planejamento.csv** — gera um arquivo `.csv` compatível com o Planejamento de Horário.
  - **alteracoes.md** — gera um Markdown com a diferença entre o planejamento importado (base) e o estado atual editado, organizado em disciplinas adicionadas, removidas e alteradas. Serve de guia do que ajustar na planilha de planejamento online. O estado inicial usado como base é o da última importação; ele é preservado dentro do `planejamento.json` ao salvar, sobrevivendo a fechar e reabrir.

Ao abrir/importar **com um planejamento já carregado na tela**, um diálogo pergunta se deseja **mesclar** os dados com o que já está na tela ou **substituir** completamente. Em ambos os casos, **o registro de alterações usado em `alteracoes.md` é redefinido**: a base de comparação passa a ser o estado resultante da importação. Se ainda precisar das diferenças acumuladas até então, **exporte `alteracoes.md` antes** de mesclar ou substituir. (Ao **substituir** abrindo um `planejamento.json` salvo pelo programa, o registro de alterações guardado naquele arquivo é restaurado — ver acima.)

#### Painel de disciplinas

Exibe os cards das disciplinas do currículo. Filtros em cascata permitem visualizar por curso, semestre e se a disciplina já está marcada para oferta ou não.

#### Atribuição de professores

Ao clicar em uma disciplina, o painel lateral mostra:

- **Professores disponíveis** — com menu suspenso para selecionar um ou mais por disciplina.
- **Afinidade** — professores com histórico de oferta desta disciplina aparecem destacados no topo, com percentual de afinidade calculado automaticamente.
- **Carga horária** — exibe a carga total semanal de cada professor alocado, com indicação visual de status: verde (dentro do ideal), amarelo (abaixo do ideal) e vermelho (acima do máximo ou abaixo do mínimo).

#### Ações disponíveis

- **Determinar demanda** — analisa o histórico para contar quantos alunos precisam de cada disciplina neste semestre.
- **Determinar demanda (ignorar já ofertados)** — igual ao anterior, mas ignora alunos que já cursaram a disciplina neste semestre.
- **Verificar carga horária** — gera um relatório consolidado da carga total de cada professor.
- **Sugerir oferta** — propõe automaticamente quais disciplinas oferecer, com base na demanda levantada e na afinidade dos professores.
- **Verificar erro de afinidade** — valida a integridade dos dados históricos de afinidade.
- **Detectar problemas** — confere a oferta planejada contra as grades curriculares do **curso selecionado no filtro** e aponta inconsistências: (1) disciplinas obrigatórias da grade que faltam na oferta — considerando equivalências e respeitando a paridade do semestre em edição (1º/2º); e (2) disciplinas ofertadas alocadas em um semestre diferente do previsto na grade. As equivalências usadas para cobrir obrigatórias ausentes são listadas para conferência. Requer um curso selecionado no filtro.

> As operações de salvar (`.json`) e exportar (`.csv`) ficam no menu **Arquivo**, descrito acima.

---

### 4.6 Planejamento de Horário

**Arquivos necessários:** `horarios.txt`, `planejamento.csv` (ou `.json` salvo)

Editor visual da **grade de aulas do semestre**. Permite alocar disciplinas em horários e detectar conflitos.

#### Menu Arquivo

Todas as operações de arquivo ficam reunidas no botão **Arquivo**, organizado em grupos:

- **Locais**
  - **Abrir planejamento.json** — retoma um planejamento salvo anteriormente pelo próprio programa (formato `.json`).
  - **Abrir planejamento.csv** — carrega o `planejamento.csv` do diretório de saída (lista de disciplinas a alocar).
  - **Salvar planejamento.json** — salva o estado atual em `.json` para retomar depois.
- **Importar**
  - **planejamento.csv** — seleciona um `planejamento.csv` externo, converte para UTF-8 e o salva no diretório de saída.
  - **horarios.txt** — carrega `horarios.txt` (horários já definidos por disciplina).
  - **professor.xlsx (.csv)** — importa as preferências de horário de um professor (Excel ou CSV).
- **Exportar**
  - **horarios.txt** — gera o `horarios.txt` da grade atual.

Ao abrir o `planejamento.csv`/`horarios.txt`, um diálogo permite selecionar quais **cursos** incluir, e é possível **mesclar** os dados com os existentes ou **substituir**.

#### Painel de disciplinas (cards)

Exibe as disciplinas a alocar como cartões coloridos. Filtros permitem navegar por curso, semestre e turma. Clique em um card para selecioná-lo; arraste-o para uma célula da grade para alocar.

#### Grade de horários

Tabela com horários (linhas) × dias da semana (colunas). Cada célula pode conter uma ou mais disciplinas. As células são coloridas por semestre para facilitar a leitura visual.

- Clique em uma célula para abrir o **editor de célula**, onde é possível definir ou alterar disciplina, professor, sala, vagas, tipo (teórica/prática/laboratório) e turma.
- É possível adicionar mais de um professor por célula.

O **filtro de semestre** destaca visualmente apenas as células de um semestre específico.

O **filtro de curso** oculta na grade os nomes das disciplinas de outros cursos: com Engenharia Civil selecionada, apenas as `ECxx` aparecem (incluindo compartilhadas como `EC04;EM04` e `ECCG;EACG`). Em células com disciplinas sobrepostas de cursos diferentes, mostra somente a do curso filtrado.

#### Indicadores de problemas

Um conjunto de indicadores visuais mostra conflitos detectados automaticamente na grade:

| Indicador | Significado |
|---|---|
| Choque de professor | Um professor está alocado em dois ou mais horários simultâneos |
| Choque de sala | Uma sala está atribuída a duas ou mais disciplinas simultâneas |
| Choque de alunos | Um grupo de alunos está em dois ou mais horários simultâneos |
| Carga horária excedida | Professor ultrapassou o limite semanal de horas |
| Carga diária elevada | Professor com seis ou mais horas no mesmo dia |
| Noturna seguida de matinal | Professor com aula noturna num dia e matinal no dia seguinte |
| Sem professor | Célula alocada sem professor atribuído |

Cada indicador pode ser ativado ou desativado individualmente, conforme o critério de análise desejado.

#### Verificador de carga horária

Exibe um resumo da carga semanal de cada professor, com marcação visual (amarelo = carga diária elevada, vermelho = carga semanal excedida).

#### Posicionador automático

O botão **Posicionar automaticamente** abre um diálogo de configuração e, em seguida, tenta alocar automaticamente as disciplinas ainda não posicionadas. Parâmetros configuráveis:

- **Turno inicial preferido** — manhã, tarde ou noite.
- **Permitir sábado** — inclui ou exclui o sábado na tentativa de alocação.

O algoritmo considera preferências de professores (quando disponíveis), choques existentes e prioridades configuradas. O resultado pode ser ajustado manualmente após a execução.

#### Exportação

As saídas ficam no menu **Arquivo** (descrito acima): **Salvar planejamento.json** (grupo Locais) preserva o estado para retomar depois, e **Exportar › horarios.txt** (grupo Exportar) gera a grade no formato compatível com o Horários.exe.
- O relatório de choques detectados também pode ser exportado separadamente.

---

### 4.7 Exportadores

**Arquivos necessários:** variam por tipo de exportação (veja abaixo)

Reúne ferramentas para gerar relatórios e documentos avulsos.

#### Lista de pré-requisitos

**Necessário:** grade curricular configurada.

Exporta um arquivo Markdown com uma tabela listando, para cada disciplina, seus pré-requisitos e co-requisitos. Indicado para compartilhar com os alunos antes do período de matrículas.

Selecione a versão de grade antes de exportar.

#### Ementa de disciplina

**Necessário:** arquivo de ementa da disciplina (`.txt` estruturado).

Selecione uma disciplina e gere um PDF formatado com sua ementa completa. Útil para documentação oficial e para envio a outros setores.

#### Choques de horário

**Necessário:** `hist.csv`, `horarios.txt`.

Selecione a versão de grade e as condições de matrícula a analisar. O relatório Markdown gerado lista, para cada par de disciplinas que compartilham alunos em horários conflitantes, o número de alunos afetados. Apoia a decisão de reorganização de horários.

#### Validar cadastro (GURI 5104)

**Necessário:** `hist.csv`.

Verifica se os alunos estão em situação regular no sistema GURI. É possível analisar um aluno específico ou todos de uma vez. O relatório aponta discrepâncias encontradas.

#### Lista para planos de ensino

**Necessário:** `planejamento.csv` ou dados de horário carregados.

Gera uma lista formatada de disciplinas por professor, facilitando o preenchimento dos planos de ensino semestrais.

---

### 4.8 Matrícula Irregular

**Arquivos necessários:** `hist.csv`

Identifica alunos matriculados em disciplinas sem cumprir os pré-requisitos exigidos.

O terminal exibe, para cada aluno com irregularidade detectada:

- Nome e matrícula.
- Disciplinas em situação irregular, com indicação do tipo (matrícula sem pré-requisito ou aproveitamento irregular).
- Total de alunos com irregularidades.

Use este módulo para identificar casos que exigem correção de matrícula ou formalização de exceção pela coordenação.

---

### 4.9 Trancamentos

**Arquivos necessários:** `hist.csv`

Verifica o histórico de trancamentos de cada aluno e avalia se os limites regulamentares foram atingidos.

#### Seleção de aluno

Escolha o aluno no menu suspenso. O módulo exibe:

- **Trancamentos totais** — semestres em que o aluno trancou o período inteiro.
- **Trancamentos parciais** — disciplinas específicas trancadas.
- **Status em relação aos limites:** verde (dentro do permitido), amarelo (próximo do limite) e vermelho (limite atingido ou ultrapassado).

Os limites verificados (quantidade total de trancamentos, limite de trancamentos consecutivos e restrição para ingressantes) são configuráveis e baseados na Resolução 29, Art. 48.

O módulo também exibe o trecho da legislação aplicável ao caso do aluno selecionado.

---

## 5. Configurações

A janela de configurações é acessada pelo ícone na barra de navegação. As alterações são salvas automaticamente.

### 5.1 Interface

- **Escala da interface** — ajusta o tamanho geral da janela (de 50% a 300%, com suporte a ajuste por DPI do monitor).
- **Tamanho de fonte** — define o tamanho base do texto (10pt a 32pt).
- **Tema visual** — escolha entre os temas disponíveis: Nord, Nord Frost, Everforest, Lucent Orange, Material, Zenburn, Mac Platinum, Windows 98. A mudança é imediata.

### 5.2 Módulos

Parâmetros específicos de cada módulo, como pesos do posicionador automático, limites de carga horária e configurações de oferta. Consulte as descrições de cada campo na própria janela.

### 5.3 Restaurar padrões

Retorna todas as configurações para os valores padrão definidos no arquivo `base_config.json`.

---

## 6. Arquivos de Entrada

### 6.1 hist.csv

Histórico acadêmico exportado do GURI. Deve conter as colunas de matrícula, nome do aluno, código e nome da disciplina, nota final, situação (aprovado, reprovado, trancado, etc.) e carga horária. O programa aceita arquivos com separador `;` ou `,`.

### 6.2 horarios.txt

Grade de horários do semestre. Cada linha representa uma aula com professor, sala, disciplina, turno, dia, horário, tipo (T/P/L) e número de vagas. O formato exato é definido no `base_config.json`.

### 6.3 planejamento.csv

Oferta de disciplinas para o semestre planejado. Contém código da disciplina, carga horária e o(s) professor(es) alocado(s). Pode ser gerado pelo módulo Planejamento de Oferta ou editado manualmente em planilha.

---

## 7. Arquivos de Saída

Todas as exportações são salvas na pasta `exportacoes/`, localizada dentro do diretório do programa. O caminho desta pasta é configurável em `base_config.json`.

| Formato | Gerado por |
|---|---|
| `.md` (Markdown) | Situação de Alunos, Exportadores, Planejamento de Horário |
| `.csv` | Planejamento de Oferta, Planejamento de Horário |
| `.json` | Planejamento de Oferta (salvar para retomar depois) |
| `.pdf` | Exportadores → Ementa de disciplina |

---

## 8. Fluxo de Trabalho Típico

A seguir, um exemplo de uso completo do programa para preparar um semestre letivo.

### Etapa 1 — Análise da situação atual

1. Exporte o `hist.csv` do GURI e o `horarios.txt` do semestre corrente. Coloque ambos em `dados/`.
2. Abra **Matrícula Irregular** para identificar e corrigir problemas de matrícula antes do início das aulas.
3. Abra **Trancamentos** para verificar alunos que atingiram ou estão próximos do limite.
4. Abra **Situação de Alunos** para analisar individualmente alunos com situações específicas.

### Etapa 2 — Planejamento da oferta

1. Abra **Planejamento de Oferta**.
2. Importe o `planejamento.csv` do semestre anterior como base.
3. Use **Determinar demanda** para ver quantos alunos precisam de cada disciplina.
4. Use **Sugerir oferta** para obter uma recomendação automática.
5. Ajuste manualmente a alocação de professores, verificando a carga horária de cada um.
6. Exporte o planejamento como `.csv` para usar na próxima etapa.

### Etapa 3 — Montagem da grade de horários

1. Abra **Planejamento de Horário**.
2. Importe o `planejamento.csv` gerado na etapa anterior e o `horarios.txt` com os horários pré-definidos.
3. Aloque as disciplinas na grade arrastando os cards para as células desejadas.
4. Ative os indicadores de choque para identificar conflitos.
5. Se desejar, use o **Posicionador automático** para uma alocação inicial e ajuste manualmente depois.
6. Exporte a grade em Markdown ou CSV.

### Etapa 4 — Geração de relatórios

1. Abra **Exportadores**.
2. Gere a **Lista de pré-requisitos** para divulgar aos alunos antes das matrículas.
3. Gere a **Lista para planos de ensino** para os professores.
4. Gere o relatório de **Choques de horário** para apoiar a revisão final da grade.

### Etapa 5 — Cálculos finais

1. Abra **Calculador de CR** e selecione **Prováveis formandos** para identificar os alunos em fase de conclusão.
2. Use **Situação de Alunos** para verificar individualmente os alunos que procuram a coordenação com dúvidas sobre matrícula.
3. Exporte a situação completa de todos os alunos para um arquivo compartilhável com a equipe.
