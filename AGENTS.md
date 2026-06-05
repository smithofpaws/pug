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
- **Separação de pastas:**
  - `arquivos/`: arquivos próprios do programa (grades, cargas, equivalências). Devem seguir rigorosamente as convenções;
  - `dados/`: dados externos importados pelo usuário (hist.csv, planejamento.csv, horarios.txt). Têm lógica própria de origem e são convertidos na leitura — não misturar os formatos destes arquivos com as convenções de `arquivos/`.
  - `exportacoes/`: saídas geradas pelo programa. Pasta na raiz do projeto, configurável em `base_config.json:diretorios.exportacoes`.

## Controle de versão (git) e múltiplos computadores

O projeto é usado em 3 computadores e vive numa pasta do **OneDrive**. O **git é o histórico
canônico — não o OneDrive**. Editar em duas máquinas em paralelo via OneDrive já causou
divergência séria no passado.

**O usuário está aprendendo git.** Ao ajudar: explicar o *porquê* em linguagem simples antes de
rodar comandos; reforçar o hábito de **commitar cedo e por tema** (um commit = uma ideia, mensagem
clara em português). Lembrar que commit local já é ponto de retorno; o push leva ao GitHub (backup
e sincroniza os 3 PCs).

- **Remoto:** `origin` = `https://github.com/smithofpaws/pug.git` (privado). Autenticação por
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

`arquivos/` (grades, cargas, equivalências) **é** versionado. Antes de qualquer `push`/commit,
conferir `git status` para garantir que nenhum CSV de `dados/` ou token entrou.

## Ferramentas

- Godot 4.x com GL Compatibility
- GDScript tipado estaticamente

### Regras de organização

- **Sempre usar `DicaFlutuante` para tooltips no programa.** Não usar `Control.tooltip_text`, nem tooltips nativos de engine, nem implementações ad-hoc em módulos individuais. Isso garante consistência visual em toda a aplicação.

#### Diálogos
- **Sim/não:** `Dialogos.confirmar(pai, título, texto, ao_confirmar, texto_ok := "Sim", texto_cancelar := "Cancelar")`. NÃO instanciar `ConfirmationDialog` ad-hoc.
- **Customizado** (checkboxes, formulários, 3+ saídas): usar `AcceptDialog`/`ConfirmationDialog` diretamente. Ex.: `seletor_cursos.gd`, `seletor_disciplinas_grade.gd`, `planejamentooferta.gd`.

## Registro INPI

- **GRU:** 29409192354476831 (Serviço 730 - Registro de Software)
- **Hash SHA-512:** `6407F5D4C317E1DC6ABFA20A780D2192411FC50FE6F708BD16B2E8A3082697EEF798E9997B74EE8E32F9F1F0FCECC83BCD2DE2A4B70B613C50AC35DF652D2A76`
- **Arquivo fonte:** `PUG_Fonte_Registro_INPI.zip`
- **Titular:** Diego Arthur Hartmann (CPF: [removido])

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

## Manual

- **Atualização** Sempre atualize o manual quando uma nova função for adicionada ou removida.