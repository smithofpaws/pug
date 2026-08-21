# AGENTS.md

Instruções para o assistente ao trabalhar neste projeto.

## Preferências de arquitetura

- **Constantes e configurações** Vão em `base_config.json`, não em `GV` (globals.gd). Globals só se extremamente necessário;
- **Leitura de arquivos** Deve ser concentrada no `main.gd`, que injeta dados nos módulos. Módulos devem evitar ler arquivos diretamente, e caso for necessário pedir confirmação explicita para aplicar;
- **Estilo do código** Seguir o do código existente, amplamento discutido em @FORMATACAO.md;
- **Regra snake_case** Tratar variáveis, chaves de dicionários, e demais dados que não são impressos sempre em snake_case (letra minúscula, sem espaços e sem acentos; Conversão para texto formatado para apresentação (com espaços, acentos, capitalização) só acontece no momento de inserir na UI. 

## Convenções multi-curso

- **Importancia do base_config.json** O arquivo contém a chave "cursos", a qual define identificadores canônicos que são referência em todo o programa. É a fonte única de verdade — não duplicar em outros arquivos;
- **Chave de grade / carga exigida** `<cod_curso>_<versao>`. Ex: `alec_2023`. Mesma convenção para nomes de arquivo em `arquivos/grades/` e `arquivos/cargaexigida/`;
- **Chave de equivalência** `<origem>-<destino>` onde cada lado é uma chave de grade. Ex: `alec_2010-alec_2023.json` (intracurso entre projetos pedagógicos diferentes), `alec_2023-alea_2020.json` (entre cursos). O sufixo `0000` permanece como placeholder para "disciplinas sem grade".
- **Disciplina dividida (várias fontes → mesmo alvo)** Quando, num mesmo arquivo de equivalência, **várias** disciplinas-fonte mapeiam para o **mesmo** código-alvo (ex.: `alec_2023-alec_2010.json` com `al0391: al0162` e `al0399: al0162`, "Saneamento I + II" → "Saneamento"), entende-se que a grade nova **dividiu** uma disciplina antiga. A lógica (`AnaliseGrades.alvo_completo`) só concede o aproveitamento do alvo quando o aluno cursou **TODAS** as fontes do grupo — não exige formato especial no JSON, basta listar as fontes apontando para o mesmo alvo.
- **Separação de pastas:**
  - `arquivos/`: arquivos próprios do programa (grades, cargas, equivalências, dicas, templates). Devem seguir rigorosamente as convenções;
  - `dados/`: dados externos importados pelo usuário (hist.csv, planejamento.csv, horarios.txt). Têm lógica própria de origem e são convertidos na leitura — não misturar os formatos destes arquivos com as convenções de `arquivos/`.
  - `exportacoes/`: saídas geradas pelo programa. Pasta na raiz do projeto, configurável em `base_config.json:diretorios.exportacoes`.

### Repositórios de dados por curso

Cada curso tem um repositório **privado** com seus dados canônicos — hoje só
`smithofpaws/alec-data` (Engenharia Civil); amanhã um `alem-data` e assim por diante. Eles também
alimentam outros consumidores (o `ppc2023`, em Typst, lê a mesma grade).

- **Quem é dono de quê sai do nome do arquivo.** Um repositório de curso manda **apenas** nos
  arquivos com o seu prefixo (`alec_*` → alec-data). Arquivos de outros cursos e as equivalências
  **entre** cursos (`alcc_0000-alec_2023.json`) não pertencem a repositório nenhum: ficam versionados
  no pug. Um repositório de curso nunca deve conter arquivo de outro.
- **Sincronização:** `ferramentas/sincronizar_dados_curso.ps1` (ou o `.bat` de duplo clique). Ele
  clona cada repositório com `gh` (são privados; o `gh` já autenticado evita token no projeto) e
  copia **arquivo a arquivo**, filtrando pelo prefixo. **Sentido único:** edite no repositório
  canônico e sincronize; as cópias em `arquivos/` são sobrescritas.
- **Nada de `git subtree`.** Era o mecanismo antigo (`arquivos/compartilhado/<curso>/`, removido).
  Ele mapeia um repositório para uma pasta e traz a árvore inteira, o que (a) impede dois cursos de
  dividirem a mesma pasta e (b) **committa tudo no consumidor** — foi assim que o `README.md` do
  alec-data virou conteúdo público do pug, e seria assim que dados de docentes voltariam a vazar.
  Consumidor público só recebe cópia seletiva de arquivos.

## Controle de versão (git) e múltiplos computadores

O projeto é usado em 3 computadores e vive numa pasta do **OneDrive**. O **git é o histórico
canônico — não o OneDrive**. Editar em duas máquinas em paralelo via OneDrive já causou
divergência séria no passado.

**O usuário está aprendendo git.** Ao ajudar: explicar o *porquê* em linguagem simples antes de
rodar comandos; reforçar o hábito de **commitar cedo e por tema** (um commit = uma ideia, mensagem
clara em português). Lembrar que commit local já é ponto de retorno; o push leva ao GitHub (backup
e sincroniza os 3 PCs).

- **Remoto:** `origin` = `https://github.com/smithofpaws/pug.git` (**público** — é de lá que o
  atualizador automático baixa as releases; ver "Distribuição e atualização"). Autenticação por
  **HTTPS + Git Credential Manager** (no 1º push/pull de cada máquina abre o navegador para login;
  depois fica salvo). Existe chave SSH local não vinculada à conta — por isso usa-se HTTPS.
- **Rotina recomendada:** ao **começar** numa máquina → `git pull` (traz o que as outras
  enviaram). Ao **terminar** uma tarefa → `git status`, `git add`, `git commit`, `git push`.
- **Login interativo (1ª vez de cada máquina):** comandos que pedem autenticação (`push`/`pull`)
  devem ser rodados **pelo usuário** via prefixo `!` (ex.: `! git push`), pois o login abre o
  navegador na sessão dele. Depois das credenciais salvas, o assistente pode rodar direto.
- **git no PATH:** no **PowerShell** usar `C:\Program Files\Git\cmd\git.exe`; no **bash** (Bash
  tool e prefixo `!`) o `git` já está no PATH.
- **Lembrete visual:** auto-fetch ligado no VSCodium (`.vscode/settings.json`); o indicador de
  sincronização na barra inferior mostra `↑N` (commits a enviar) e `↓N` (commits a baixar).
- **Não editar em dois PCs em paralelo;** antes de trocar de máquina, commitar e sincronizar.
- **Backups locais** ficam em `.backup/` (gitignored); o OneDrive os replica.
- **Plano (migração):** mover o projeto para uma pasta **fora do OneDrive** e sincronizar só pelo
  GitHub (`clone` + `pull`/`push`). Enquanto estiver no OneDrive, o `.git` é sincronizado por dois
  mecanismos (OneDrive + GitHub) — frágil; deixar o OneDrive terminar de sincronizar antes de abrir
  o projeto noutra máquina. **Ao concluir a migração, atualizar esta seção.**

### Dados pessoais fora do git (LGPD)

O repositório guarda **código**, não dados pessoais. Já gitignorados, **nunca commitar**:

- `dados/` — dados importados (hist.csv, email.csv, planejamento.csv, preferências de horário).
  Contêm dados de alunos/professores. Exceção versionada: `dados/.gdignore` (marcador do Godot).
- `exportacoes/` — saídas geradas (regeneráveis; o programa recria a pasta).
- `arquivos/limesurvey/survey_tokens.lst` — tokens de participantes.
- `arquivos/oferta/` — **dados nominais de docentes** (`historico_professores.json`,
  `lista_professores.json` e o prompt que os gera). A pasta inteira é gitignorada, com exceção do
  marcador `.gdignore`. Ela **não é montada à mão**: vem do repositório privado do curso, pelo
  `ferramentas/sincronizar_dados_curso.ps1`. Um clone novo do pug simplesmente não a tem — e o
  programa funciona assim mesmo (`main.gd` checa a existência antes de ler; o Planejamento de Oferta
  apenas deixa de sugerir professores e de calcular afinidade). **Depois de clonar o pug numa
  máquina, rode a sincronização**, senão o módulo abre mudo.

`arquivos/` (grades, cargas, equivalências) **é** versionado. Antes de qualquer `push`/commit,
conferir `git status` para garantir que nenhum CSV de `dados/` ou token entrou.

**Nada de nome real de pessoa em arquivo versionado** — nem em exemplo de documentação. O repositório
é público e o `MANUAL.md` vai dentro do pacote distribuído. Use nomes fictícios (`Maria da Silva
Souza`) nos exemplos do manual, das dicas e dos prompts.

#### Exceção controlada: sincronização de planejamento (servidor Kinto)

O módulo **Planejamento de horário** pode enviar/baixar o planejamento de oferta para um servidor
[Kinto](https://github.com/Kinto/kinto) compartilhado entre coordenadores (`SyncKinto` em
`standalone_scripts/io/sincronizacao.gd`). Esta é a **única** exceção à regra "nada pessoal sai do
PC", e é controlada:

- **Só o planejamento de oferta** trafega (disciplinas + nomes de professores, dado funcional), mais
  as **restrições de alocação** do planejamento de horário (escopo por professor/semestre, na chave
  `restricoes` do record — também dado funcional). **Nunca** enviar `hist.csv`, `email.csv` ou qualquer
  dado de aluno.
- Acesso **sempre autenticado** (Basic Auth `usuario:token`, sem leitura pública) e restrito à
  **rede privada Tailscale** (o transporte já é cifrado pelo WireGuard).
- Credenciais ficam em `config_usuario.json:sincronizacao` (gitignorado); o **token é revogável**
  no servidor. Modelo: bucket `pug` / collection `planejamentos` / 1 record por **curso**
  (`id = <cod_curso>`, ex.: `alec` — não por grade/versão, pois um curso tem vários PPCs ativos e o
  planejamento cobre todos), com escrita restrita ao coordenador dono. O envio filtra o planejamento
  para mandar só as disciplinas do próprio curso (`prefixos_semestre`).
- **Administração pela interface** (Configurações › "Administração do servidor…", cena
  `scenes/Complementares/PainelAdminKinto/`): o admin autentica com a conta de admin do Kinto e
  gerencia contas de coordenadores, o grupo `coordenadores`, os records (apagar), as permissões da
  collection e a **mesclagem do campus**. Usa `SyncKintoAdmin` (`sincronizacao_admin.gd`), uma
  instância **separada** do `_sync` do coordenador. Coordenadores criam o record do seu curso porque
  o grupo `coordenadores` tem `record:create` na collection.
- **Senha de admin:** opcional ("Lembrar nesta máquina"); quando gravada, vai para
  `user://admin_kinto.json` (`%APPDATA%`, **fora do OneDrive**), **nunca** em `config_usuario.json`
  (sincronizado nos 3 PCs). O I/O desse arquivo fica em `main.gd`.
- **Mesclagem (campus):** o admin mescla os planos dos cursos num record `campus` + arquivo local
  `planejamento_campus.json` (nome próprio, para não sobrescrever o `planejamento.json` de trabalho do
  coordenador). É **reconciliação**: disciplinas compartilhadas iguais são unificadas; horários divergentes
  viram **conflito** (nunca resolvido em silêncio — o admin cancela ou opta por manter o mais
  recente). `campus` não é `cod_curso`, então é excluído da lista de "Ver outros cursos (referência)".
- **Plano:** migrar o servidor para a infraestrutura da Unipampa. **Ao concluir, atualizar aqui.**

## Ferramentas

- Godot 4.x com GL Compatibility
- GDScript tipado estaticamente

### Regras de organização

- **Sempre usar `DicaFlutuante` para tooltips no programa.** Não usar `Control.tooltip_text`, nem tooltips nativos de engine, nem implementações ad-hoc em módulos individuais. Isso garante consistência visual em toda a aplicação.

#### Diálogos
- **Sim/não:** `Dialogos.confirmar(pai, título, texto, ao_confirmar, texto_ok := "Sim", texto_cancelar := "Cancelar")`. NÃO instanciar `ConfirmationDialog` ad-hoc.
- **Aviso (botão único):** `Dialogos.avisar(pai, título, texto, texto_ok := "OK", largura_max := 420)`. Para relatar um desfecho onde não há decisão a tomar (erro de rede, "já está na versão mais recente"). NÃO usar `confirmar` para isso — o par confirmar/cancelar sugere uma escolha que não existe.
- **Lista + múltiplas ações** (aviso/escolha que mostra uma lista potencialmente longa, ex.: muitas disciplinas): `Dialogos.escolha_lista(pai, título, cabeçalho, itens, rodapé, acoes, texto_cancelar := "Cancelar")`. A lista entra num `ScrollContainer` (rola em vez de esticar a janela); `acoes` é um Array de `{ "texto", "ao_acionar": Callable }` — a 1ª vira o botão OK, as demais viram botões extras.
- **Customizado** (checkboxes, formulários, layout próprio): usar `AcceptDialog`/`ConfirmationDialog` diretamente. Ex.: `seletor_cursos.gd`, `seletor_disciplinas_grade.gd`, `planejamentooferta.gd`.
- **Sempre limitar à tela.** Todo diálogo/popup construído em runtime deve chamar `Dialogos.limitar_a_tela(janela)` logo após `popup_centered()` — impede que a janela ultrapasse a área visível (encolhe, re-centraliza e reduz o `min_size` se preciso, pois o Godot ignora `size` abaixo do `min_size`). Para conteúdo que cresce com os dados, combine com um `ScrollContainer` (`SIZE_EXPAND_FILL` + `custom_minimum_size`) para rolar em vez de esticar. `Dialogos.confirmar`/`escolha_lista` já fazem isso internamente; aplique manualmente nos demais (seletores, `FileDialog`, etc.). Exceções: tooltips (`DicaFlutuante`) e popups que já usam `popup_centered_ratio` (ex.: `editor_celula.gd`).

## Exportação
Sempre que requisitado para exportar o projeto, exporte-o na área de trabalho em um arquivo zipado, pronto para uso ao ser descompactado (portátil), isto é, com todos arquivos necessarios. A lógica de nomeacão do arquivo é "PUG_WIN_\<ARQUITETURA\>.zip" — hoje `PUG_WIN_X64.zip` e `PUG_WIN_ARM64.zip`. Arquivos temporários gerados na exportação devem ser removidos. Por enquanto exporte os executáveis com e sem debug e com e sem console, para o usuário decidir qual usar.

**Não montar o pacote à mão** — use `ferramentas/publicar_release.ps1 -Versao X.Y.Z` (sem `-Publicar`
ele só prepara e deixa os ZIPs na Área de Trabalho). O script faz exatamente o que esta seção pede e
ainda garante o contrato do ZIP descrito abaixo, do qual o atualizador automático depende. O `.bat`
de duplo clique começa mostrando a versão em `project.godot`, a última tag publicada e sugestões de
numeração (`-Info`), para a próxima versão ser escolhida com as duas informações à vista.

### Arquiteturas (x64 e ARM64)

Cada arquitetura tem seu **preset** em `export_presets.cfg` — `PUG` (`x86_64`) e `PUG_ARM64`
(`arm64`), idênticos exceto por `binary_format/architecture` — e gera **seu próprio ZIP**. O ARM64
existe para os PCs Windows com processador ARM (Snapdragon X e afins), que hoje rodam o pacote x64
pela emulação Prism, mais lenta.

- **Modelos de exportação:** o ARM64 exige `windows_release_arm64.exe` e `windows_debug_arm64.exe`
  (mais os `_console`) em `%APPDATA%\Godot\export_templates\<versão>\`. Eles vêm no pacote oficial de
  modelos — se a pasta não os tiver, instale pelo editor (Editor › Gerenciar modelos de exportação).
  O script **confere antes de exportar** e aborta com a instrução; `-SemArm` publica só o x64.
- **Cada pacote se atualiza dentro da própria arquitetura.** O `base_config.json` que entra no ZIP
  ARM tem `atualizacao.asset` reescrito para `PUG_WIN_ARM64.zip` (a única diferença entre os dois
  pacotes fora os binários). Sem isso, o primeiro update num PC ARM baixaria o pacote x64 e trocaria,
  em silêncio, binários nativos por emulados.

## Distribuição e atualização

O programa se atualiza sozinho a partir das **releases do GitHub** (`smithofpaws/pug`, público).
Cliente: `standalone_scripts/io/atualizador.gd` (`class_name Atualizador`), disparado pelo `main.gd`
— a rede e o I/O ficam no main, a `JanelaConfiguracoes` só emite o sinal `verificar_atualizacoes`.

- **Versão do programa:** `project.godot` → `application/config/version` (ex.: `"1.0.0"`), espelhada
  em `export_presets.cfg` (`application/file_version`/`product_version`, com 4 componentes:
  `1.0.0.0`). Fica **embutida no binário** — por isso não vai para o `base_config.json`, que é solto,
  substituído pela própria atualização e ainda sobreposto pelo `config_usuario.json`. Comparação
  **numérica por componente** (como texto, `1.10.0` ficaria abaixo de `1.9.0`).
- **Configuração:** `base_config.json:atualizacao` = `{ repositorio, asset, verificar_ao_iniciar }`. O
  `asset` é o nome exato do arquivo na release e **depende da arquitetura** — o versionado traz
  `PUG_WIN_X64.zip`, e o empacotador reescreve a chave no pacote ARM64 (ver "Arquiteturas").
- **Estado local:** `user://atualizacao.json` (versão dispensada). Vai para `user://` — e **não** para
  o `config_usuario.json` — porque cada um dos 3 PCs pode estar numa versão diferente, e o
  `config_usuario.json` é sincronizado entre eles (mesmo motivo de `user://admin_kinto.json`).

### Contrato do ZIP (a parte frágil)

`file_handling.configurar_diretoriobase()` faz `GV.dir_principal = OS.get_executable_path()` sem o
nome do arquivo: no build, `arquivos/`, `base_config.json`, `dados/` e `externo/bin/` são lidos do
**disco, ao lado do .exe** — não do PCK.

**A raiz do ZIP é a raiz da instalação — sem pasta de topo.** Um ZIP com pasta de topo produz uma
atualização morta, sem erro visível. Conteúdo (o mesmo em cada pacote de arquitetura): os 4
executáveis (`Auxiliar.exe`, `Auxiliar.console.exe`, `Auxiliar_debug.exe`,
`Auxiliar_debug.console.exe`), `base_config.json`, `MANUAL.md`, `arquivos/` e `externo/bin/`. Os
nomes dos executáveis **não** mudam com a arquitetura: quem distingue os pacotes é o nome do ZIP, e o
aplicador relança `OS.get_executable_path()`, que precisa continuar existindo depois da troca.

**Nunca entram no pacote** (regra geral: *nada gitignorado entra*): `config_usuario.json`, `dados/`,
`exportacoes/`, `.backup/` e — atenção — **`arquivos/limesurvey/survey_tokens.lst`**, que fica
*dentro* de uma pasta incluída. São tokens vinculados a alunos, e a release é pública: um vazamento
ali é permanente e cacheável mesmo se a release for apagada. Por isso o script monta `arquivos/` e
`externo/bin/` a partir de `git ls-files` e **aborta** se encontrar arquivo proibido no ZIP pronto.

#### O segundo lugar por onde um arquivo vaza: o PCK

O layout do ZIP não é a única superfície. `export_presets.cfg` usa
`export_filter="all_resources"`, e isso embute no **PCK, dentro de cada `.exe`**, todo arquivo solto
na raiz do projeto — gitignorado ou não. Foi assim que o `config_usuario.json`, com **usuário e
token do Kinto**, entrou nos quatro binários da **1.0.0 publicada**: `git status` limpo, ZIP
conferido, credencial vazando mesmo assim. *(Aquele token tem de ser revogado no servidor — apagar
a release não desfaz os downloads já feitos.)*

- O `exclude_filter` de **todos** os presets (hoje quatro: `PUG`, `PUG_ARM64`, Android e Linux)
  exclui `config_usuario.json`. **Todo arquivo gitignorado que passe a morar na raiz do projeto
  precisa entrar nesse filtro** — e **em todos os presets**, pois um preset novo (foi o caso do
  `PUG_ARM64`) nasce com o filtro que você copiar para ele.
- `dados/` e `exportacoes/` não dependem disso: o `.gdignore` já faz o Godot ignorar a pasta inteira.
- O `publicar_release.ps1` confere o PCK **de cada exportação** (release e debug, de cada
  arquitetura) em `Conferir-Pck`, lendo as linhas `Storing File: res://…`
  do **log da exportação**. Não adianta procurar no `.exe`: o caminho `res://` não aparece como texto
  no binário (só o conteúdo do arquivo aparece), e procurar pelo nome solto acusa qualquer menção no
  código — o `main.gd` lê `"config_usuario.json"` pelo nome. Se o log não tiver nenhuma linha
  `Storing File:`, a guarda **aborta**: formato mudado significa guarda cega, e aprovar em silêncio
  traria o ponto cego de volta.

### Como a troca acontece

O executável em uso fica travado pelo Windows, então o programa não pode se sobrescrever. O
`Atualizador` baixa para `user://atualizacao/`, confere o **SHA-256** publicado junto (asset
`<nome do pacote>.sha256`, ex.: `PUG_WIN_X64.zip.sha256`), extrai para um *staging* e só então grava e dispara
`aplicar_atualizacao.ps1` (`OS.create_process` — não `OS.execute`, que é bloqueante) e encerra o
programa. O script espera o **PID real**, copia para `.backup/` **apenas o executável em uso**
(descartando o backup da atualização anterior — cada `.exe` passa de 100 MB e a pasta é replicada pelo
OneDrive; guardar os quatro custaria ~430 MB por atualização), roda
`robocopy /E` **sem `/PURGE`** (cópia **aditiva** — grades acrescentadas localmente, `config_usuario.json`,
`dados/` e `exportacoes/` sobrevivem) e relança `OS.get_executable_path()`, de modo que a variante que
o usuário abriu é a que volta. Log em `user://atualizacao/log.txt`.

*Consequência aceita da cópia aditiva:* um arquivo **removido** entre versões permanece na instalação.
É o lado certo do trade-off (proteger as grades locais), mas não é um bug a caçar depois.

Nenhum caminho é interpolado no corpo do `.ps1` — todos entram como parâmetros nomeados, e o corpo é
**ASCII puro** (o PowerShell 5.1 lê `.ps1` sem BOM na codepage ANSI). Caminhos vindos de `user://`
passam por `ProjectSettings.globalize_path()` antes de ir ao PowerShell.

## Registro INPI

- **GRU:** 29409192354476831 (Serviço 730 - Registro de Software)
- **Hash SHA-512:** `6407F5D4C317E1DC6ABFA20A780D2192411FC50FE6F708BD16B2E8A3082697EEF798E9997B74EE8E32F9F1F0FCECC83BCD2DE2A4B70B613C50AC35DF652D2A76`
- **Arquivo fonte:** `PUG_Fonte_Registro_INPI.zip`
- **Titular:** Diego Arthur Hartmann

> O CPF do titular e demais dados do processo **não ficam aqui** — o repositório é público. Guarde-os
> fora do git (ex.: junto ao comprovante da GRU).

## Troubleshooting GDScript

- **Use o parser do Godot quando disponível.** Erros como `Could not resolve class "X", because of a parser error` podem ser em cascata. Para obter o erro real:
  ```
  & "C:\Program Files\Godot\Godot_console.exe" --headless --path "<projeto>" --check-only --script "<script>.gd"
  ```
- **Autoloads não resolvem no `--check-only` isolado.** `Identifier not found: GV` ao verificar um script isolado é falso positivo.
  ```
  & "C:\Program Files\Godot\Godot_console.exe" --headless --path "<projeto>" --editor --quit
  ```
- **Lambdas capturam variáveis locais por cópia.** Escrever numa variável **local** dentro de uma lambda (ex.: handler de sinal) NÃO propaga para fora — a lambda altera só a própria cópia. Sintoma típico: um `while local.is_empty(): await get_tree().process_frame` esperando a lambda preencher `local` fica em **loop infinito** e o `await` nunca retorna.
  - **Regra:** sinais de nós criados em runtime que precisam devolver um valor a um `await` devem escrever num **membro** (acessado via `self`, propaga normalmente) ou usar sinal dedicado / `Callable.bind`, nunca numa local capturada.
  - Verificável em segundos via headless: `extends SceneTree` + lambda escrevendo numa local vs. num membro, e comparar.

## Pipeline de desenvolvimento (cards)

O trabalho é organizado em **cards**, não em listas de TODOs: ver `Cards/README.md`
para a convenção e o índice. O `IDEAS.md` continua como backlog solto por módulo;
uma ideia vira card pela entrevista da skill `godot-session-setup`.

- **Ponto de entrada de toda sessão:** a skill
  `.claude/skills/godot-session-setup/SKILL.md`. Ela lê o handoff
  (`.claude/handoff/latest.md`), entrevista o dev até a feature virar um card com
  ACs falsificáveis, migra ideias do `IDEAS.md` e roda a fila de cards `ready`.
  **O card vem antes do código** — mesmo quando o pedido chega como "implementa X".
- **Execução de um card:** `.claude/workflows/godot-feature-pipeline.js`
  (`args: {cardId}`), que encadeia as skills `godot-feature-design` (spec),
  `godot-gdscript-dev` (TDD), `godot-code-review` (findings com `blocking`) e
  `godot-smoke-test` (PNG por AC + diff de log). Só aceita card `ready`.
- **Portões:** `python .tools/guardrails.py` (gdlint + regras do projeto),
  `python .tools/run_tests.py` (suíte GUT em `test/`) e o parser do Godot
  (`--headless --path . --editor --quit`). O pre-commit do Lefthook
  (`lefthook.yml`) roda os dois primeiros; os hooks do Claude Code
  (`.claude/settings.json` + `.tools/claude_hooks.py`) rodam o guardrails a cada
  edição de `.gd` e bloqueiam escrita em caminhos protegidos (`dados/`,
  `arquivos/oferta/`, `exportacoes/`...).
- **Baseline (catraca):** o código anterior aos guardrails carrega violações
  históricas congeladas em `.tools/guardrails_baseline.json` por arquivo+regra.
  O portão só reprova violação **nova**; limpar um arquivo e rodar
  `--update-baseline` aperta a catraca. Nunca afrouxá-la para passar um card.
- **Handoff:** `.claude/handoff/latest.md` registra onde a sessão parou (o
  anterior vai para `archive/`). É estado versionado, não documentação — regras
  no `README.md` da pasta.
- **LGPD no pipeline:** `Cards/` é versionado e público — nenhum dado pessoal
  real em card, spec, teste, fixture (`test/fixtures/`) ou PNG de smoke.
  Smoke test só com `dados/` vazio ou fixtures fictícias. `Cards/` tem
  `.gdignore` (fora do import e do PCK); `addons/gut/*` e `test/*` estão no
  `exclude_filter` de todos os presets de export.
- **Setup por clone:** `python -m pip install --user "gdtoolkit==4.*"` e
  `lefthook install` (ver `Cards/README.md`).

## Manual

- **Atualização** Sempre atualize o manual quando uma nova função for adicionada ou removida.