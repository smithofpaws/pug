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
   - [Avaliação Limesurvey](#410-avaliação-limesurvey)
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

O programa lê arquivos externos fornecidos pelo usuário. Antes de usar qualquer módulo, verifique quais arquivos ele exige e importe-os para o programa. Isto pode ser realizado diretamente na tela principal do programa.

Arquivos importados serão copiados para a pasta `dados/` dentro do diretório do programa.

> [!ATENÇÃO]
> Arquivos importados diferem de arquivos abertos temporariamente. Os importados são convertidos para UTF-8 e salvos na pasta do programa para uso posterior, sendo sempre sobrescritos a cada nova importação.
>
> Já os arquivos abertos ficam numa pasta temporária, apenas para análise pontual: as conversões são descartadas a cada inicialização do programa.

| Arquivo | Descrição |
|---|---|
| `hist.csv` | Histórico acadêmico exportado do GURI: matrículas, disciplinas, notas e situações |
| `horarios.txt` | Grade de horários do semestre atual: professor, sala, horário, turma e vagas |
| `horarios.ini` | Complemento do `horarios.txt`, no formato INI: nomes canônicos de professores e disciplinas, gerado pelo programa de horários do campus |
| `planejamento.csv` | Oferta de disciplinas: código, carga horária e professor(es) alocado(s) |

Cada módulo indica, ao ser aberto, quais desses arquivos são obrigatórios para seu funcionamento.

### 2.2 Navegação

Use o **menu suspenso** no topo da janela para trocar de módulo a qualquer momento. O módulo anterior é descarregado e o novo é carregado em seu lugar.

Ao abrir o **primeiro** módulo que analisa o histórico (Situação de Alunos/Disciplinas, Matrícula Irregular, Exportadores, Planejamento de Horário/Oferta), o programa calcula a situação de matrícula de todos os discentes e mostra uma **barra de progresso** — o tempo depende do tamanho do `hist.csv`. Esse resultado fica em cache, então as trocas seguintes entre esses módulos são praticamente **instantâneas**. O cálculo só é refeito (com nova barra) quando o `hist.csv` é reimportado ou alterado.

---

## 3. Interface Principal

### 3.1 Barra de navegação

Localizada no topo da janela. Contém:

- **Seletor de módulo** — menu suspenso para escolher o módulo ativo.
- **Ícone de configurações** — abre a janela de configurações do programa.

### 3.2 Terminal

Vários módulos exibem um painel de texto (chamado *terminal*) com análises, relatórios e avisos em texto colorido. O terminal pode ser ocultado e reexibido com o botão correspondente; o conteúdo é preservado.

### 3.3 Botões de painel (mostrar/ocultar)

Vários módulos têm botões que mostram ou ocultam painéis — terminal, grade de horários, grade curricular, painel de disciplinas, etc. Esses botões têm dois comportamentos:

- **Clique normal:** alterna apenas aquele painel (mostra se estava oculto, oculta se estava visível); os demais não mudam.
- **Shift + clique:** *isola* o painel — deixa visível somente o painel clicado e oculta todos os outros do módulo. Repetir o Shift + clique no painel já isolado **restaura** todos os painéis. Útil para focar rapidamente em um painel sem ter de ocultar os demais um a um.

### 3.4 Dicas flutuantes

Ao posicionar o cursor sobre elementos da interface, uma dica flutuante pode aparecer explicando a função daquele elemento.

### 3.5 Menus suspensos (seletores)

Os menus suspensos do programa — seletores de aluno, curso, grade, filtros, etc. — aceitam dois atalhos além do clique normal:

- **Roda do mouse sobre o seletor:** com o cursor sobre o menu (sem precisar abri-lo), girar a roda **avança ou retrocede** a opção selecionada. Útil para percorrer rapidamente alunos, disciplinas ou semestres.
- **Clique do meio nos filtros do Painel de Disciplinas** (Curso, Semestre, Professor): **limpa** aquele filtro, voltando a exibir todos os itens. Aplica-se aos filtros usados em Planejamento de Oferta e Planejamento de Horário.

---

## 4. Módulos

### 4.1 Tela Principal

A tela inicial do programa. Exibe os módulos disponíveis. Quando algum arquivo necessário está ausente ou há erros de carregamento, as informações de diagnóstico aparecem aqui.

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

**Arquivos necessários:** `hist.csv`, `horarios.txt`, `horarios.ini`

Módulo central de análise individual. Permite examinar em detalhes a situação acadêmica de qualquer aluno do histórico.

#### Seleção de curso e aluno

Quando o `hist.csv` reúne alunos de mais de um curso, o menu **Curso** no topo filtra a lista de alunos. Selecionar um curso (ex.: Engenharia Civil) restringe a lista a todos os alunos desse curso, abrangendo todas as suas versões de currículo (ex.: tanto `alec_2010` quanto `alec_2023`). A opção **Todos os cursos** remove o filtro e exibe a lista completa. O curso vem pré-selecionado conforme o **PPC principal** definido em Configurações; só aparecem no menu os cursos efetivamente presentes no histórico.

Escolha o aluno pelo menu suspenso ao lado. A interface é atualizada imediatamente com os dados do aluno selecionado.

#### Grade curricular

Exibe a estrutura completa do currículo, organizada por semestres. Cada célula representa uma disciplina e recebe uma cor conforme a situação do aluno nela (cursada, disponível para matrícula, bloqueada por pré-requisitos, etc.).

**Disciplinas distantes (célula hachurada):** as disciplinas que o aluno ainda não pode alcançar no próximo passo aparecem com uma hachura leve, deixando a célula um pouco mais escura. São aquelas que dependem de aprovação em algo que, por sua vez, ainda depende de outra aprovação. Exemplo: um aluno matriculado em *Mecânica dos Solos II* cursará *Obras de Terra* se for aprovado — essa aparece normalmente; já *Fundações e Estruturas de Contenção*, que exige *Obras de Terra*, está duas etapas à frente e aparece hachurada. A hachura separa, portanto, "falta uma aprovação" de "falta uma cadeia de aprovações". Disciplinas já concluídas sob o código de outra grade (aproveitamento) não são hachuradas.

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

O checkbox **Modo Detalhado**, no topo, controla o nível de detalhe do relatório: marcado (padrão), o terminal traz também as seções analíticas — **Previsão de formatura** e **Índice de aprovação**; desmarcado, o relatório fica restrito à situação de matrícula do aluno. A exportação em Markdown traz sempre o relatório completo, independentemente do checkbox.

O terminal apresenta um relatório completo do aluno:

- Versão do currículo e matrícula.
- Carga horária vencida por categoria (obrigatória, complementar, etc.).
- **Previsão de formatura** — período letivo mínimo em que o aluno pode se formar, calculado pela maior cadeia de pré-requisitos obrigatórios ainda pendente (o *caminho crítico*). Como cada disciplina dessa cadeia só pode ser cursada depois da anterior, ela define o prazo mínimo mesmo quando, "na teoria", faltariam poucos semestres. O relatório mostra o período previsto, o número mínimo de semestres (contando o atual) e a sequência de disciplinas que determina o prazo. O período de partida é o das matrículas em curso do aluno; eletivas/CCCG não entram nessa conta.
- **Índice de aprovação** — desempenho semestre a semestre, do mais antigo ao mais recente. Cada linha traz duas medidas de aprovação do mesmo semestre, ex.: `2023/1: 71% (5 de 7) | 67% da CH (240 de 360h)`. A primeira conta **disciplinas**; a segunda, a **carga horária** aprovada — é a medida do regulamento de estágio, apresentada como aprovação (o regulamento fala em reprovação, que é o complemento) para ler no mesmo sentido da primeira. Entram na conta apenas as disciplinas com resultado lançado (aprovação ou reprovação): matrículas em aberto, dispensas, trancamentos e aproveitamentos ficam de fora. Períodos letivos especiais (verão/inverno) não são listados, e o semestre em curso só aparece depois que as notas são lançadas.
  - **Cor da linha (critério de estágio):** verde quando o aluno aprovou **ao menos 40% da carga horária** em que estava matriculado naquele semestre — ou seja, não reprovou (por nota e por frequência somadas) em mais de 60% dela; vermelho quando reprovou acima disso. É a exigência do regulamento de estágio — quem cumpre o critério no semestre regular imediatamente anterior pode solicitar estágio no seguinte. Como a cor acompanha a carga horária e não o número de disciplinas, as duas medidas da linha não andam juntas: reprovar só em disciplinas pesadas pinta a linha de vermelho mesmo com um percentual de aprovação razoável. O limite é configurável em `base_config.json:estagio.limite_reprovacao`.
- Disciplinas cursadas fora da grade atual.
- **Previsão de matrículas** — reúne o aviso sobre reprovações e as listas por condição de matrícula descritas a seguir.
- Histórico de reprovações (por nota e por frequência).
- Lista de disciplinas organizadas por condição de matrícula:
  - **Matriculado agora** — disciplinas em que está cursando neste semestre.
  - **Matriculável** — cumpridos todos os pré-requisitos, sem choque de horário.
  - **Se aprovado** — poderá cursar se for aprovado nas disciplinas do semestre atual.
  - **Corequisito matriculável** — pode ser cursada junto com outra disciplina específica.
  - **Matrícula irregular** — matriculado sem cumprir os pré-requisitos (requer atenção).
- Para cada disciplina: código, nome, créditos e histórico de reprovações nela.

#### Exportação

O botão **Exportar** gera um arquivo Markdown com a situação dos alunos, incluindo carga horária vencida e condições de matrícula de cada um. A exportação respeita o filtro de curso ativo (o cabeçalho do arquivo indica o curso); selecione **Todos os cursos** para incluir todos.

---

### 4.4 Situação de Disciplinas

**Arquivos necessários:** `hist.csv` (`horarios.txt` opcional, para a grade de horários consolidada)

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
- **Grades** — usa a grade de um curso específico para selecionar disciplinas a ofertar.
- **Importar**
  - **planejamento.csv** — seleciona um `planejamento.csv` externo, converte para UTF-8 e o salva no diretório de saída.
- **Exportar**
  - **planejamento.csv** — gera um arquivo `.csv` compatível com o Planejamento de Horário.
  - **alteracoes.md** — gera um Markdown com a diferença entre o planejamento importado (base) e o estado atual editado, organizado em disciplinas adicionadas, removidas e alteradas. Serve de guia do que ajustar na planilha de planejamento online. O estado inicial usado como base é o da última importação; ele é preservado dentro do `planejamento.json` ao salvar, sobrevivendo a fechar e reabrir.
  - **oferta.txt** — gera um arquivo de texto com uma linha por disciplina, no formato `Nome da disciplina - Professor(es) - Código - Turma` (ex.: `Geologia de Engenharia - Maria da Silva Souza - AL0378 - T20`), em ordem alfabética. Respeita o filtro de curso ativo (todas as disciplinas se não houver filtro). Disciplinas sem professor alocado são omitidas; com mais de um professor, os nomes saem separados por ` - `. A turma é a primeira definida para o curso da disciplina.

Ao abrir/importar **com um planejamento já carregado na tela**, um diálogo pergunta se deseja **mesclar** os dados com o que já está na tela ou **substituir** completamente. Em ambos os casos, **o registro de alterações usado em `alteracoes.md` é redefinido**: a base de comparação passa a ser o estado resultante da importação. Se ainda precisar das diferenças acumuladas até então, **exporte `alteracoes.md` antes** de mesclar ou substituir. (Ao **substituir** abrindo um `planejamento.json` salvo pelo programa, o registro de alterações guardado naquele arquivo é restaurado — ver acima.)

#### Painel de disciplinas

Exibe os cards das disciplinas do currículo. Filtros em cascata permitem visualizar por curso, semestre e se a disciplina já está marcada para oferta ou não.

#### Atribuição de professores

Ao clicar em uma disciplina, o painel lateral mostra:

- **Professores disponíveis** — com menu suspenso para selecionar um ou mais por disciplina.
- **Afinidade** — professores com histórico de oferta desta disciplina aparecem destacados no topo, com percentual de afinidade calculado automaticamente.
- **Carga horária** — exibe a carga total semanal de cada professor alocado, com indicação visual de status: verde (dentro do ideal), amarelo (abaixo do ideal) e vermelho (acima do máximo ou abaixo do mínimo).

> **Turmas globais.** Algumas turmas do histórico (ex.: a turma 90) são ofertadas a **todos os cursos** ao mesmo tempo. Elas contam para qualquer curso ao identificar "professores que já lecionaram para o curso" e ao somar o bônus de afinidade. A lista dessas turmas fica em `base_config.json:turmas_globais`.

#### Ações disponíveis

- **Determinar demanda** — analisa o histórico para contar quantos alunos precisam de cada disciplina neste semestre.
- **Determinar demanda (ignorar já ofertados)** — igual ao anterior, mas ignora alunos que já cursaram a disciplina neste semestre.
- **Verificar carga horária** — gera um relatório consolidado da carga total de cada professor. Com um curso selecionado no filtro, considera apenas professores que já lecionaram para esse curso (identificados pelo código da turma no histórico).
- **Sugerir oferta** — propõe automaticamente quais disciplinas oferecer, com base na demanda levantada e na afinidade dos professores. Com um curso selecionado no filtro, considera apenas professores que já lecionaram para esse curso (identificados pelo código da turma no histórico).
- **Verificar erro de afinidade** — valida a integridade dos dados históricos de afinidade. Com um curso selecionado no filtro, considera apenas professores que já lecionaram para esse curso (identificados pelo código da turma no histórico).
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
  - **Abrir horarios.txt** — carrega o `horarios.txt` já presente no diretório de saída (horários já definidos por disciplina) e popula a grade. Se **nenhum** `planejamento.csv`/`.json` estiver carregado, o `horarios.txt` também passa a ser a fonte do **planejamento em memória** (para que salvar/enviar tenham as disciplinas); nesse caso o programa **avisa** que é preferível abrir um `planejamento.csv`/`.json` antes, pois a carga horária por professor fica menos detalhada. Se **já houver** um planejamento carregado e o `horarios.txt` trouxer disciplinas que **não estão** nele, o programa **avisa e abre um diálogo** para você escolher **quais** dessas disciplinas incorporar ao planejamento (caso contrário elas só aparecem na grade e não seriam salvas/enviadas).
  - **Salvar planejamento.json** — salva o estado atual em `.json` para retomar depois. Se o planejamento carregado contiver disciplinas de **outro curso** (por exemplo, você importou o plano de outro curso para dar uma olhada), o programa **avisa e pergunta** se deseja salvar **só o seu curso** (mais as compartilhadas) ou **tudo** — assim o seu arquivo local não fica "poluído" com dados de outro curso. Sem disciplinas de outro curso, salva direto.
- **Importar**
  - **planejamento.csv** — seleciona um `planejamento.csv` externo, converte para UTF-8 e o salva no diretório de saída.
  - **horarios.txt** — seleciona um `horarios.txt` externo, converte para UTF-8, salva no diretório de saída e abre em seguida (populando a grade — e, sem um `planejamento.csv`/`.json` carregado, também o planejamento em memória, com o mesmo aviso descrito em _Abrir horarios.txt_).
  - **horarios.txt outros cursos (referência)…** — seleciona **um ou mais** `horarios.txt` locais de outros cursos e os **sobrepõe** na grade como **camada de referência** (somente-leitura), concatenando todos. Cada disciplina é etiquetada automaticamente com o curso a que pertence (pelo prefixo de semestre); as disciplinas que já são suas têm prioridade e não são sobrepostas. Equivale ao **Servidor › Ver outros cursos (referência)…**, mas a partir de arquivos locais — útil quando o outro curso não publicou seu plano no servidor mas você tem o `horarios.txt` dele. Use **Servidor › Limpar referências** para removê-las.
  - **professor.xlsx (.csv)** — importa as preferências de horário de um professor (Excel ou CSV).
- **Exportar**
  - **horarios.txt** — gera o `horarios.txt` da grade atual.
- **Servidor** — sincronização do planejamento entre coordenadores (servidor compartilhado).
  - **Enviar ao servidor** — envia o planejamento do **seu curso** (derivado do PPC principal definido em _Configurações › Geral_; ex.: `alec_2023` → curso `alec`) para o servidor, substituindo a versão que estiver lá. O registro no servidor é **por curso, não por versão de grade** — um curso com vários PPCs ativos (ex.: 2010 e 2023) usa um único registro, pois o planejamento cobre todos. São enviadas **apenas as disciplinas do seu curso** (as compartilhadas com outro curso entram nos dois). Só funciona para o curso do qual você é o coordenador responsável. **Proteção:** se o planejamento do seu curso estiver vazio (por exemplo, você montou a grade só a partir do `horarios.txt` sem abrir o `planejamento.csv`), o envio é **cancelado** com um aviso — assim não se apaga, por engano, o plano que já está no servidor.
  - **Baixar do servidor** — lista os planejamentos disponíveis (mostrando quem enviou e quando) e permite baixar o de um curso; isso **substitui** o `planejamento.json` local e o conteúdo da grade.
  - **Ver outros cursos (referência)…** — lista os demais cursos no servidor e permite **sobrepor** um ou mais deles na sua grade como **camada de referência** (somente-leitura). Serve para co-planejar **disciplinas compartilhadas** entre cursos (ex.: `EC01;EM02`): você passa a ver onde os colegas alocaram as disciplinas, sem poder editá-las.
  - **Limpar referências** — remove da grade os cursos sobrepostos como referência, deixando só o seu plano.
  - **Configurar servidor…** — informa o endereço do servidor, o seu usuário e o seu token de acesso. As credenciais ficam salvas localmente (o token pode ser revogado no servidor).

> **Aviso automático de versão nova:** ao **abrir o módulo**, o programa consulta o servidor em segundo plano e exibe um aviso (com **quem enviou e quando**, oferecendo baixar na hora) **somente** quando o servidor tem uma versão do curso do PPC principal que você ainda não sincronizou **e** que seja mais recente, **por data**, do que o seu `planejamento.json` local. Ou seja: se o seu trabalho local for o mais novo, o aviso não aparece. Também fica em silêncio se o servidor não estiver configurado, estiver fora do ar, ou você já estiver em dia.

Ao abrir o `planejamento.csv`/`horarios.txt`, um diálogo permite selecionar quais **cursos** incluir, e é possível **mesclar** os dados com os existentes ou **substituir**.

> **Olhar outro curso sem misturar dados:** para apenas **consultar** o planejamento de outro curso, prefira **Servidor › Ver outros cursos (referência)** — ele entra como camada **somente-leitura** e **nunca** é salvo nem enviado. Já **importar/abrir** o `planejamento.csv`/`.json` de outro curso **mescla** os dados de verdade no seu plano. Mesmo nesse caso você está protegido: o **envio** sempre manda só o seu curso (+ compartilhadas) e, se houver disciplinas de outros cursos carregadas, avisa quantas ficarão de fora; e o **salvar** pergunta se quer guardar só o seu curso ou tudo (ver acima). Isso evita que o mesmo dado de uma disciplina acabe duplicado em vários planejamentos no servidor.

> **Backup automático (histórico de regressão):** ao **salvar** o `planejamento.json`, **enviar ao servidor** ou **baixar do servidor**, o programa guarda automaticamente um snapshot com data/hora dos arquivos de trabalho (`planejamento.json`, `planejamento.csv`, `horarios.txt`, `horarios.ini`) em `.backup/planejamentohorario/`. Como o backup do _baixar_ é feito **antes** de sobrescrever, o seu trabalho local fica preservado mesmo que você baixe a versão de outra pessoa. A pasta `.backup/` não vai para o Git, mas é replicada pelo OneDrive; o caminho de cada snapshot é mostrado no terminal.

> **Camada de referência (co-planejamento):** os cursos sobrepostos via _Ver outros cursos_ aparecem na grade com cor própria e o marcador `»`, são **somente-leitura** (tentar mover/remover/alocar exibe um aviso) e **nunca** entram no seu `planejamento.json` nem são reenviados ao servidor — ao salvar ou enviar, só vai o seu plano. Com a referência sobreposta, o programa: (1) **sinaliza disciplinas compartilhadas em horário divergente** — quando os dois lados de uma compartilhada (ex.: `EC01;EM02`) estão em horários diferentes, abre um aviso listando-as e mostra a contagem na barra de status (_Compart. divergentes_); e (2) passa a **detectar choques de professor/sala entre cursos** no mesmo horário. Use _Limpar referências_ para voltar a ver só o seu plano.

> **Sobre a sincronização:** cada coordenador trabalha de forma assíncrona no seu próprio curso. Apenas o **planejamento de oferta** (disciplinas e professores) trafega — nunca dados de alunos. O acesso é autenticado por usuário/token e restrito à rede privada (Tailscale).

#### Administração do servidor (somente admin)

Em **Configurações › aba Geral › "Administração do servidor…"** abre-se um painel para quem administra o servidor compartilhado. Na aba **Autenticação**, informe o usuário e a senha de **administrador** e clique **Conectar**; marque **"Lembrar nesta máquina"** para guardar a senha localmente (ela fica em `%APPDATA%`, fora do OneDrive, e nunca é sincronizada entre PCs). Após conectar, as demais abas liberam:

- **Usuários** — cria a conta de cada coordenador (usuário + senha) já adicionando-o ao grupo que pode enviar planos; permite **redefinir senha** e **apagar** o usuário. Apagar o usuário **não** apaga o plano que ele enviou.
- **Planos enviados** — lista os planos no servidor (um por curso) e permite **apagar** o que quiser.
- **Permissões** — mostra as permissões atuais e tem um botão para **liberar o envio aos coordenadores**, caso algum receba erro de permissão ao enviar.
- **Campus (mesclar)** — seleciona vários cursos e **mescla** os planos num plano único do campus, salvo localmente como `planejamento_campus.json` (nome próprio, para **não** sobrescrever o seu `planejamento.json` de trabalho) **e** publicado como o plano `campus` no servidor. Para abri-lo na grade, use _Baixar do servidor › campus_ (que aí sim substitui o `planejamento.json`, de forma explícita). Disciplinas compartilhadas idênticas são unificadas; quando os horários **divergem** entre cursos, o programa **lista os conflitos** e deixa você cancelar (para ajustar nos cursos de origem) ou mesclar mantendo a versão enviada mais recentemente — nunca decide sozinho.

#### Painel de disciplinas (cards)

Exibe as disciplinas a alocar como cartões coloridos. Filtros permitem navegar por curso, semestre e turma. Clique em um card para selecioná-lo; arraste-o para uma célula da grade para alocar.

#### Grade de horários

Tabela com horários (linhas) × dias da semana (colunas). Cada célula pode conter uma ou mais disciplinas. As células são coloridas por semestre para facilitar a leitura visual.

- **Clique direito** em uma célula: abre um menu com as disciplinas daquele horário (escolher uma aplica o filtro de semestre dela) e os professores que as lecionam (escolher um aplica o filtro daquele professor). Sob **Outras interações**, a opção **Restringir alocação** marca a célula como restrita (ver [Restrições de alocação](#restrições-de-alocação)). O menu também abre em **células vazias** (mostrando só "Outras interações").
- **Clique do meio** em uma célula: remove a alocação dali. Com um **filtro de semestre ou professor ativo** (a célula em foco/verde), remove **apenas a disciplina filtrada**, preservando as demais sobrepostas na mesma célula; sem filtro, remove todas as suas alocações da célula.
- **Arrastar com Shift:** ao alocar um card, preenche **horas consecutivas** para baixo de uma vez (até completar a CH); ao mover uma disciplina já na grade, move o **bloco contíguo inteiro** (todas as células ligadas da disciplina), e não só a célula agarrada — a célula que você pegou cai onde você soltar, e o resto do bloco a acompanha.
- **Ctrl+Z:** desfaz a última ação na grade (alocar, mover, remover, posicionar automaticamente, limpar preenchimento/restrições, marcar/remover restrição). O histórico é **multi-nível** (Ctrl+Z repetido volta várias ações), fica **em memória** durante a sessão e é **zerado ao carregar outro plano** (abrir/baixar/importar horarios.txt).
- Clique em um **card** na lista de disciplinas (à esquerda) para destacar, com **fundo verde claro**, apenas as células daquela disciplina na grade.

Os filtros do painel (curso, semestre e professor) afetam a grade: numa célula com disciplinas sobrepostas, as que **não** passam por um filtro ativo aparecem **esmaecidas** (ou são **ocultadas**, conforme a Visualização). Por exemplo, com o **filtro de professor** em Diego Arthur Hartmann, a disciplina dele fica em branco e as demais no mesmo horário ficam esmaecidas; compartilhadas de curso casam pelo prefixo (`EC04;EM04` conta como `EC`).

O botão **Visualização**, no grupo **Filtros**, controla, para cada filtro, se as disciplinas que não passam são **ocultadas** (caixa marcada) ou apenas **esmaecidas** (caixa desmarcada):

- **Curso** — vem **marcado** por padrão, mantendo a ocultação das disciplinas de outros cursos.
- **Semestre** — marque para ocultar as disciplinas fora dos semestres filtrados.
- **Professor** — marque para mostrar apenas as disciplinas do professor filtrado, ocultando as demais.

Ao **mover** uma disciplina na grade, o programa destaca o semestre dela para revelar choques de semestre — **exceto** quando há um **filtro de professor** ativo: nesse caso o destaque não é forçado, mantendo visíveis as disciplinas do professor para que você controle os choques do próprio professor durante o ajuste.

Para ajudar a achar um horário livre dos **dois** tipos de choque, durante o arraste a grade marca a dimensão complementar com **hachura** (linhas diagonais):

- Com **filtro de professor** ativo: os horários do professor ficam em verde e os horários do **semestre** da disciplina ficam **hachurados**.
- Com **filtro de semestre** ativo: os horários do semestre ficam em verde e os horários do **professor** da disciplina ficam **hachurados**.

Assim, uma célula livre de verde e de hachura é segura (sem choque de professor nem de semestre). A hachura é temporária: aparece ao iniciar o arraste e some ao soltar.

#### Restrições de alocação

Use a restrição para marcar horários que devem ser **evitados** (ex.: um professor indisponível na segunda de manhã). Pelo **clique direito** numa célula, em **Outras interações → Restringir alocação**, a célula passa a ter **fundo vermelho**. A restrição herda o escopo do **filtro ativo**:

- com **filtro de professor** ativo, vale só para aquele professor;
- com **filtro de um único semestre** ativo, vale só para aquele semestre.

A opção exige **exatamente um** filtro ativo (professor **ou** um único semestre); sem isso — nenhum filtro, ambos, ou vários semestres — ela aparece **desabilitada** com um aviso. Para remover, abra o menu com o mesmo filtro ativo: a opção vira **Remover restrição**.

A restrição fica **vermelha apenas quando o filtro correspondente está ativo** (uma restrição de professor não polui a vista de outro professor ou de semestre). Mesmo assim, ao **arrastar** uma disciplina cujo professor/semestre coincide com uma restrição, a célula restrita fica **vermelha + hachurada durante o arraste**, qualquer que seja o filtro — para você não esquecer da restrição ao reposicionar. É um **aviso**: arrastar e soltar continuam permitidos.

As restrições são **salvas no `planejamento.json`** (sobrevivem a fechar o programa e entram nos backups) e **acompanham a sincronização**: ao **enviar**, vão junto no registro do curso; ao **baixar**, vêm do servidor (útil para quem trabalha só com o plano do servidor). Para apagar todas de uma vez, use **Ações → Limpar todas as restrições** (não afeta as alocações).

#### Indicadores de problemas

A grade sinaliza os problemas detectados automaticamente seguindo uma convenção consistente: **a cor indica a severidade** e **o lado da célula indica a categoria** do problema. O **tipo exato** aparece ao **passar o mouse sobre a célula** (dica).

- **Cor (severidade):** vermelho = erro (impede a oferta), amarelo = aviso (revisar).
- **Lado da célula (categoria):**
  - **barra inferior** — choque de recurso (professor, sala ou semestre no mesmo horário);
  - **barra esquerda** — sobrecarga do professor (carga ≥6h no mesmo dia, ou aula noturna seguida de matinal no dia seguinte);
  - **barra direita** — problema da disciplina (carga horária excedida);
  - **barra superior** — preferência de horário do professor (verde→vermelho, do melhor ao pior; informativo, não é um alerta);
  - **cor do texto** — estado da alocação: vermelho = sem professor; laranja = hora extra.
- **Tooltip:** passe o mouse sobre uma célula com marcação para ver a lista exata das condições (ex.: "⚠ Choque de professor", "⚠ Carga ≥6h no mesmo dia", "✕ Sem professor").

Os indicadores podem ser ligados/desligados individualmente. Com um filtro de curso/semestre ativo, as marcações de alerta aparecem apenas nas células em foco; os problemas das demais seguem contabilizados no terminal.

#### Verificador de carga horária

Reporta no terminal os professores com carga diária elevada (≥6h num dia) e os casos de aula noturna seguida de matinal. Na grade, esses casos aparecem como aviso (amarelo) na barra esquerda da célula; o tipo exato fica no tooltip. Esses avisos são **por professor**: com um **filtro de professor** ativo, a carga e a noturna→matinal são calculadas apenas para ele — assim, numa célula compartilhada, o aviso de outro professor não é atribuído à disciplina do filtrado.

Os relatórios do terminal (choques, carga, posicionamento) são estruturados (título, seções e itens) e podem ser copiados como Markdown.

#### Posicionador automático

O botão **Posicionar automaticamente** abre um diálogo de configuração e, em seguida, tenta alocar automaticamente as disciplinas ainda não posicionadas. Parâmetros configuráveis:

- **Turno inicial preferido** — manhã, tarde ou noite.
- **Permitir sábado** — inclui ou exclui o sábado na tentativa de alocação.

O diálogo deixa explícito o **escopo** (todos os cursos ou apenas o curso filtrado) e mostra um **diagnóstico de pré-requisitos** colorido: vermelho = item obrigatório ausente (a **carga horária** das disciplinas, vinda do planejamento — sem ela o botão **Posicionar** fica desabilitado); laranja = presente mas incompleto (ex.: disciplinas sem CH, ou grade sem alguns códigos); amarelo = item opcional ausente (grade curricular, `hist.csv` ou preferências de professores — não impedem o posicionamento). O `hist.csv` só fica verde quando cobre uma fração mínima das disciplinas do escopo (padrão **80%**, ajustável em `base_config.json:posicionamento_auto.diagnostico_hist_cobertura_min`): um histórico de outro curso — sem alunos nas pendentes, ou cobrindo poucas delas — aparece em amarelo, pois influencia pouco o choque entre alunos ali.

O algoritmo considera preferências de professores (quando disponíveis), choques existentes e prioridades configuradas. O resultado pode ser ajustado manualmente após a execução.

As preferências do professor (escala 1 = desejado a 5 = indesejado, verde→vermelho) entram no custo de forma **não-linear**: o peso e o expoente são ajustáveis em **Configurações › Posicionamento** (cada campo traz uma dica explicativa). Horários que o professor deixou em branco são proibidos; um horário marcado em vermelho é fortemente evitado, mas ainda possível.

Quando há disciplinas pendentes **compartilhadas entre cursos** (ex.: `EC01;EM01`), o programa exibe um aviso antes de prosseguir, listando-as — já que o horário delas é uma decisão conjunta dos cursos envolvidos. O aviso oferece três caminhos: **Posicionar todas** (inclui as compartilhadas), **Apenas as não compartilhadas** (posiciona o restante agora e deixa as compartilhadas para depois) ou **Cancelar** (para posicioná-las manualmente primeiro).

Com um curso selecionado no filtro, o posicionamento atua apenas nas disciplinas desse curso (ex.: somente as `ECxx` com Engenharia Civil selecionada). As alocações já existentes dos demais cursos são preservadas como restrição, evitando choques.

#### Mesclar horários.txt e planejamento.json (.csv)

Esta ação **reconcilia um `horarios.txt` já montado** (uma grade que você posicionou e exportou antes) **com o planejamento atualmente carregado** — útil quando o planejamento muda depois de a grade estar pronta, para não recomeçar do zero:

- Disciplinas que **permanecem** no planejamento mantêm o horário/dia/sala que já tinham no `horarios.txt`.
- Disciplinas **novas** (no planejamento, mas ausentes do `horarios.txt`) entram **sem horário**, prontas para posicionar.
- Disciplinas que **saíram** do planejamento (constavam no `horarios.txt`) são listadas num diálogo, e você decide se as **reinclui** ou **descarta**.

A opção fica no menu **Ações** e só é **habilitada** quando há, ao mesmo tempo, um `horarios.txt` e um planejamento carregados — caso contrário aparece esmaecida. O pareamento entre as duas fontes é por **código + semestre**, então rótulos de semestre diferentes (ex.: uma compartilhada `EC02;EM02` no planejamento vs. `EC02` no `horarios.txt`) não casam e a entrada do `horarios.txt` entra como disciplina nova.

#### Verificar problemas

A opção **Ações › Verificar problemas** faz uma **varredura completa** da grade e despeja no terminal um relatório de tudo o que estiver irregular, em seções:

- **Choque de professor** — o mesmo professor em duas disciplinas no mesmo dia/horário (lista o horário, o professor e as disciplinas envolvidas).
- **Células sem professor** — alocações sem professor atribuído (lista o horário e as disciplinas).
- **Carga horária excedida** — disciplinas com mais horas alocadas do que o previsto (lista código, nome, horas alocadas e previstas; desconta horas extras explícitas).
- **Sobrecarga** — professores com ≥6h num mesmo dia e casos de aula noturna seguida de manhã cedo no dia seguinte.
- **Análise de choques** — choques de sala e de semestre. Mostra a contagem e, quando a **Preferência da grade** correspondente (*Choque de sala* / *Choque de semestre*) está marcada, detalha quais disciplinas colidem em cada horário; se estiver desmarcada, sugere reexecutar com a opção ativada para ver os detalhes.

As disciplinas listadas nos choques seguem o **modo de visualização** selecionado para a grade (*somente código*, *completo*, *nome reduzido* etc.); no modo *esferas*, cai no código.

Diferentemente dos indicadores das **Preferências da grade** (que pintam a grade conforme o que está ligado), esta ação roda **todas** as checagens de uma vez, independentemente dos indicadores marcados, e produz um relatório textual — útil para uma conferência final antes de salvar/enviar. Quando nada é encontrado, informa **"Nenhum problema encontrado"**; com a grade vazia, avisa que não há o que verificar.

#### Exportação

As saídas ficam no menu **Arquivo** (descrito acima): **Salvar planejamento.json** (grupo Locais) preserva o estado para retomar depois, e **Exportar › horarios.txt** (grupo Exportar) gera a grade no formato compatível com o Horários.exe.
- O relatório de choques detectados também pode ser exportado separadamente.

---

### 4.7 Exportadores

**Arquivos necessários para abrir o módulo:** `hist.csv`, `horarios.txt`, `horarios.ini`. Cada ferramenta de exportação usa um subconjunto desses dados (indicado abaixo).

Reúne ferramentas para gerar relatórios e documentos avulsos.

#### Lista de componentes

**Necessário:** grade curricular configurada.

Exporta um PDF com uma tabela listando, para cada componente curricular da grade, seu código e nome, a **carga horária** (coluna estreita `CH`, em horas — 15 horas por crédito) e seus pré-requisitos. Indicado para compartilhar com os alunos antes do período de matrículas.

Selecione a versão de grade antes de exportar. O arquivo é salvo como `<versão da grade>.pdf` (ex.: `alec_2023.pdf`).

#### Lista de componentes complementares

**Necessário:** grade curricular configurada.

Mesma tabela da **Lista de componentes**, restrita aos componentes marcados como complementares (CCCGs) na grade. Útil para divulgar as CCCGs a serem incorporadas ao currículo.

Selecione a versão de grade antes de exportar. O arquivo é salvo como `<versão da grade>_complementares.pdf` (ex.: `alec_2023_complementares.pdf`).

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

No topo há um **seletor de grade** que define o **curso** analisado — já vem com o curso principal das configurações pré-selecionado. A lista mostra **apenas os discentes do curso** escolhido, **independentemente da versão da grade** de cada um (selecionar `alec_2010` ou `alec_2023`, por exemplo, dá o mesmo resultado: todos os irregulares de Engenharia Civil). Troque o curso pelo seletor para ver outro.

O terminal exibe, para cada aluno com irregularidade detectada:

- Nome e matrícula.
- Disciplinas em situação irregular, com indicação do tipo (matrícula sem pré-requisito ou aproveitamento irregular).
- Total de alunos com irregularidades.

Use este módulo para identificar casos que exigem correção de matrícula ou formalização de exceção pela coordenação.

---

### 4.9 Trancamentos

> [!NOTA]
> Módulo **em desenvolvimento**. Encontra-se temporariamente **desativado** na configuração padrão; a descrição abaixo reflete o comportamento previsto.

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

### 4.10 Avaliação Limesurvey

> [!NOTA]
> Módulo **desativado temporariamente** na configuração padrão. A descrição abaixo reflete o comportamento previsto quando reativado.

**Arquivos necessários:** `hist.csv`, `email.csv`

Gera os arquivos de importação para o **LimeSurvey** usados na avaliação semestral de disciplinas e professores, evitando a montagem manual de cada questionário.

A partir do histórico, o módulo identifica as combinações de **disciplina + professor + turma** do semestre e produz, para cada avaliação:

- **Questionário (`survey.lss`)** — arquivo LimeSurvey com os dados do administrador, datas de início e expiração e o semestre já preenchidos.
- **Lista de participantes (`survey_tokens.lst`)** — relação de alunos com seus e-mails (vinda do `email.csv`), pronta para importar como participantes do questionário.

Os campos de administrador (e-mail, datas, semestre) podem ser ajustados na interface antes da geração. Os arquivos são salvos no diretório de *surveys* definido em `base_config.json`.

---

## 5. Configurações

A janela de configurações é acessada pelo ícone na barra de navegação. As alterações são salvas automaticamente.

### 5.1 Interface

- **Escala da interface** — ajusta o tamanho geral da janela (de 50% a 300%, com suporte a ajuste por DPI do monitor).
- **Tamanho de fonte** — define o tamanho base do texto (10pt a 32pt).
- **Tema visual** — escolha entre os temas disponíveis: Nord, Nord Frost, Everforest, Lucent Orange, Material, Zenburn, Mac Platinum, Windows 98. A mudança é imediata.
- **Transparência do fundo** — exibe uma imagem de fundo atrás da interface. Em 0% não há imagem (fundo sólido do tema); aumentando o valor, a imagem aparece nas áreas de fundo (margens, barra, espaços vazios). O terminal e as grades também passam a deixar a imagem transparecer, porém de forma **mais sutil** (mais opacos) que o fundo geral, de modo que continuam distinguíveis. A imagem acompanha o tema: uma versão clara nos temas claros e uma escura nos temas escuros.

### 5.2 Módulos

Parâmetros específicos de cada módulo, como pesos do posicionador automático, limites de carga horária e configurações de oferta. Consulte as descrições de cada campo na própria janela.

### 5.3 Atualização do programa

Na aba **Geral** ficam a versão instalada e os controles de atualização. O PUG se atualiza sozinho a partir das versões publicadas no GitHub.

- **Verificar atualizações ao iniciar o programa** — quando marcado, o programa consulta o GitHub ao abrir e **só avisa se houver versão nova**. A consulta é silenciosa: sem internet, ou já estando em dia, nada aparece. Desmarque para verificar apenas quando quiser.
- **Verificar atualizações** — faz a consulta na hora e relata o resultado, mesmo que não haja novidade.

Havendo versão nova, o programa mostra as novidades e três opções: **Baixar e instalar**, **Pular esta versão** (não avisa mais sobre ela ao iniciar) e **Agora não** (volta a avisar na próxima abertura).

Ao escolher instalar, o pacote é baixado e sua integridade é conferida por uma soma de verificação. Só depois de o pacote estar **inteiro e conferido** é que a instalação é oferecida — nada é substituído antes disso. Confirmando, o programa **fecha, troca os arquivos e reabre sozinho** na versão nova, na mesma variante do executável que você estava usando.

**O que é preservado na atualização:** suas configurações (`config_usuario.json`), a pasta `dados/`, a pasta `exportacoes/` e quaisquer grades ou arquivos que você tenha acrescentado em `arquivos/`. A cópia é somente aditiva — nada seu é apagado. O executável que você estava usando é guardado em `.backup/` antes da troca, para o caso de precisar voltar (só o da última atualização é mantido, já que cada um passa de 100 MB).

O pacote tem cerca de **150 MB**, porque inclui as quatro variantes do executável (com e sem depuração, com e sem console).

> **Observações**
> - A atualização automática só funciona no programa **exportado** (não pelo editor Godot).
> - Se o PUG estiver instalado dentro de uma pasta do **OneDrive**, a troca pode falhar por arquivos travados pela sincronização. O ideal é instalar fora do OneDrive.
> - Instalado em `Arquivos de Programas`, a troca exige permissão de administrador. Prefira uma pasta do seu usuário.
> - O Windows pode exibir um aviso do SmartScreen na primeira execução do executável novo, por ele não ser assinado digitalmente.
> - Se algo der errado, o relatório da última tentativa fica em `%APPDATA%\Godot\app_userdata\Pacote de Utilidades para Graduação\atualizacao\log.txt`.

### 5.4 Restaurar padrões

Retorna todas as configurações para os valores padrão definidos no arquivo `base_config.json`.

---

## 6. Arquivos de Entrada

### 6.1 hist.csv

Histórico acadêmico exportado do GURI. Deve conter as colunas de matrícula, nome do aluno, código e nome da disciplina, nota final, situação (aprovado, reprovado, trancado, etc.) e carga horária. O programa aceita arquivos com separador `;` ou `,`.

Para analisar **vários cursos** ao mesmo tempo, o botão **Historico** (na tela principal) permite **selecionar múltiplos arquivos** `hist.csv` de uma vez — um por curso, por exemplo. Eles são **concatenados** num único `hist.csv`, substituindo qualquer histórico importado anteriormente. Como cada linha guarda o curso de origem, os módulos passam a reconhecer os diversos cursos automaticamente (ex.: o filtro de curso na Situação de Alunos).

### 6.2 horarios.txt

Grade de horários do semestre. Cada linha representa uma aula com professor, sala, disciplina, turno, dia, horário, tipo (T/P/L) e número de vagas. O formato exato é definido no `base_config.json`.

### 6.3 horarios.ini

Complemento do `horarios.txt`, no formato INI, também gerado pelo programa de horários do campus. Traz os **nomes canônicos** de professores (seção `[Professores]`) e disciplinas (seção `[Disciplinas]`), usados como fonte de referência ao montar a grade. Nem todas as chaves do arquivo são lidas.

### 6.4 planejamento.csv

Oferta de disciplinas para o semestre planejado. Contém código da disciplina, carga horária e o(s) professor(es) alocado(s). Pode ser gerado pelo módulo Planejamento de Oferta ou editado manualmente em planilha.

### 6.5 Grades curriculares (`arquivos/grades/`)

Cada grade é um arquivo JSON nomeado `<cod_curso>_<versao>.json` (ex.: `alec_2023.json`, `alem_2023.json`), onde `cod_curso` é o código do curso definido em `base_config.json`. O programa **detecta automaticamente** as grades disponíveis a partir desses arquivos na inicialização — para adicionar uma nova versão de currículo, basta colocar o arquivo na pasta e reabrir o programa; não é preciso editar o `base_config.json`. O sufixo `_0000` é um placeholder para "disciplinas sem grade".

---

## 7. Arquivos de Saída

Todas as exportações são salvas na pasta `exportacoes/`, localizada dentro do diretório do programa. O caminho desta pasta é configurável em `base_config.json`.

| Formato | Gerado por |
|---|---|
| `.md` (Markdown) | Situação de Alunos, Exportadores, Planejamento de Horário |
| `.csv` | Planejamento de Oferta, Planejamento de Horário |
| `.json` | Planejamento de Oferta (salvar para retomar depois) |
| `.pdf` | Exportadores → Ementa de disciplina, Lista de componentes, Lista de componentes complementares |

---

## 8. Fluxo de Trabalho Típico

A seguir, um exemplo de uso completo do programa para preparar um semestre letivo.

### Etapa 1 — Análise da situação atual

1. Exporte o `hist.csv` do GURI.
2. Baixe os `horarios.txt` e `horarios.ini` enviados pela coordenação.
3. Importe todos pela tela inicial.

### Etapa 2 — Planejamento da oferta

1. Abra **Planejamento de Oferta**.
2. Baixe a planilha de planejamento em formato CSV — apenas a aba do planejamento, não as demais.
3. Importe o `planejamento.csv` do semestre anterior como base.
4. Use **Determinar demanda** para ver quantos alunos precisam de cada disciplina.
5. Use **Sugerir oferta** para obter uma recomendação automática.
6. Ajuste manualmente a alocação de professores, verificando a carga horária de cada um.
7. Exporte o planejamento como `.csv` para usar na próxima etapa.

### Etapa 3 — Montagem da grade de horários

1. Abra **Planejamento de Horário**.
2. Importe o `planejamento.csv` gerado na etapa anterior e o `horarios.txt` com os horários pré-definidos.
3. Aloque as disciplinas na grade arrastando os cards para as células desejadas.
4. Ative os indicadores de choque para identificar conflitos.
5. Se desejar, use o **Posicionador automático** para uma alocação inicial e ajuste manualmente depois.
6. Exporte a grade em Markdown ou CSV.

### Etapa 4 — Geração de relatórios

1. Abra **Exportadores**.
2. Gere a **Lista de componentes** para divulgar aos alunos antes das matrículas.
3. Gere a **Lista para planos de ensino** para os professores.
4. Gere o relatório de **Choques de horário** para apoiar a revisão final da grade.

### Etapa 5 — Cálculos finais

1. Abra **Calculador de CR** e selecione **Prováveis formandos** para identificar os alunos em fase de conclusão.
2. Use **Situação de Alunos** para verificar individualmente os alunos que procuram a coordenação com dúvidas sobre matrícula.
3. Exporte a situação completa de todos os alunos para um arquivo compartilhável com a equipe.
