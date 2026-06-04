# Recuperação do projeto — resumo completo (04/06/2026)

Documento de retomada. Lê de cima pra baixo. **Nada do projeto original foi perdido.**

---

## 1. TL;DR — onde tudo está agora

- **Projeto oficial (em uso):** `C:\Users\diego\OneDrive\...\Auxiliar de Coordenacao GD4`
  → é o trabalho **de HOJE (04/06)**, funcionando, com a feature `alteracoes.md`. Os 19
  arquivos de conflito `-DiegoVirt` já foram **removidos**. Este é o estado bom atual.
- **Backup de ONTEM (03/06):** `C:\Users\diego\Desktop\Auxiliar de Coordenacao GD4.7z`
  → extraído em `C:\Users\diego\Recovery_GD4\backup_yesterday\` (projeto completo de ontem,
  com a feature de **grade curricular**). É a referência pra portar o que falta.
- **Foto de segurança (início da recuperação):** `C:\Users\diego\Recovery_GD4\snapshot_raw\`
  → o projeto como estava ao começar, incluindo os `-DiegoVirt`. Rede de segurança.

**Regra de ouro:** o trabalho de hoje está no projeto OneDrive **e agora versionado no git**
(commits `ab1b238` + `6e5568c`); o de ontem está no `.7z` + `backup_yesterday`. Os dois existem.
Pode descansar tranquilo.

---

## 2. O que aconteceu (diagnóstico)

1. **Git vazio:** o repositório tem `git init` mas **zero commits**. Não há histórico nem
   ancestral comum versionado.
2. **OneDrive + duas máquinas:** ontem você trabalhou na máquina "DiegoVirt"; hoje nesta.
   O OneDrive não tinha sincronizado, e ao religar gerou cópias de conflito `*-DiegoVirt.*`.
3. **Divergência maior que "ontem vs hoje":** as duas máquinas divergiram **~1 semana** em
   linhas diferentes. **28 arquivos** diferem entre o backup (ontem) e esta máquina (hoje).
   Os 11 `-DiegoVirt` eram só onde o OneDrive detectou conflito; havia mais diferenças sem
   cópia de conflito.

---

## 3. Decisão tomada (você aprovou)

**Manter o projeto de HOJE como oficial** (já funcionava, com todo o trabalho de hoje +
`alteracoes.md`), **limpar os `-DiegoVirt`**, e **portar a feature de grade de ontem depois**
usando o backup como referência. Nada se perde — só a grade ainda não está integrada.

> Tentei antes um merge automático 3-way (pasta `merged/` e `assembled/`), mas descobri que
> a "base" de 02/06 que baixei **NÃO é o ancestral comum real** (as máquinas divergiram antes
> disso). Por isso **descartei o merge automático**. Exceção aproveitável:
> `Recovery_GD4\merged\planejamentooferta.gd` = versão de ontem (grade) + nossa feature
> `alteracoes.md` reconciliada por cima — útil no port da grade.

---

## 4. O que JÁ foi feito ✅

- Foto de segurança fora do OneDrive (`snapshot_raw`).
- Backup de ontem extraído (`backup_yesterday`).
- Mapeada toda a divergência (28 arquivos).
- **Projeto oficial limpo:** 19 arquivos `-DiegoVirt` removidos; projeto validado (carrega
  sem erros no `--editor --quit`).
- Memórias registradas (port da grade + lição OneDrive/git).
- **Git instalado e versionado** (04/06): Git 2.54.0 via winget; 1º commit `ab1b238`
  (estado limpo, 250 arquivos) + commit `6e5568c` (correção do bug da seta). Repo travado.
- **Bug da seta corrigido** (04/06): nó `SeletorGrade` restaurado no `GradeCurricular.tscn`
  (causa real abaixo, seção 6). Falta só a confirmação visual no app.
- **OneDrive reativado** (04/06): esta máquina é a fonte da verdade; sem novos conflitos aqui.

---

## 5. Tarefas PENDENTES

### 5.1. ✅ Bug da seta de requisitos — RESOLVIDO (04/06, ver seção 6)
Clicar (esq/dir) numa célula da grade curricular no **Situação de Alunos** não mostrava a
seta de pré-requisitos. **Causa:** o `GradeCurricular.tscn` de hoje perdeu o nó `SeletorGrade`,
que o `grade_curricular.gd:46` referencia incondicionalmente no `_ready()` — sem o nó o `_ready`
abortava antes de conectar `celula_clicada` (linhas 50-51). Nó restaurado no commit `6e5568c`.
**Pendente apenas a confirmação visual** (abrir app → Situação de Alunos → selecionar discente →
clicar numa célula → a seta deve aparecer).

### 5.2. ✅ Portar a feature de grade curricular — CONCLUÍDA (04/06, commit `34044de`)
Portadas **3 features** (escopo escolhido pelo usuário): grade curricular (toggle `OnOffGrade`,
com demanda no rodapé), seletor de **Curso** no PainelAtribuicoes, e **botão Exportar** dedicado
(json/csv/alteracoes.md movidos do seletor Importar). Mexeu em 5 arquivos + MANUAL. Verificado com
`--editor --quit` e harness runtime (instanciou o módulo, todas as refs `%` resolvem).
**Nota:** o projeto de hoje estava mais avançado que o documento supunha (já tinha a UI de
Configurações do rodapé e as assinaturas de análise); a pasta `merged/` citada estava vazia, então
a reconciliação foi feita do zero sobre a base de hoje. Detalhe histórico do escopo abaixo:

Já está no local: o componente **`grade_curricular.gd`** (idêntico). Falta:
- **Cenas (`.tscn`):**
  - `PlanejamentoOferta.tscn`: nós `SeletorExportar`, `GradeCurricular`, `VSeparator3`
    (+ verificar botão de toggle `OnOffGrade`).
  - `PainelAtribuicoes.tscn`: nós `LinhaCurso`, `LabelCurso`, `SeletorCurso`.
- **Scripts:**
  - `planejamentooferta.gd`: integração da grade (3 membros, 2 `@onready`, ~10 funções,
    blocos no `_ready`). **Já reconciliado** em `Recovery_GD4\merged\planejamentooferta.gd`.
  - `painel_atribuicoes.gd`: feature de curso (sinal `curso_alterado`, `configurar()` 3 args,
    `exibir_disciplina()` 9 args, `_popular_opt_curso`, `_selecionar_curso_no_opt`,
    `_on_seletor_curso_opcao_selecionada`) — pegar da versão de ontem (`backup_yesterday`).
  - `relatorios_oferta.gd`: praticamente igual (606 vs 605 linhas) — manter o de hoje.
- **Config:** `base_config.json` — adicionar `situacoes_rodape` e `condicoes_rodape_disponiveis`.
- **Módulo irmão (opcional):** `planejamentohorario.gd` — mesmo padrão de "Exportar" separado
  (`_on_exportar_opcao_selecionada`).
- **Risco:** os `.tscn` (IDs de `ext_resource`/nós). Verificar **carregando o módulo de
  verdade** (não só `--editor --quit`, que NÃO pega módulos carregados via `load()` em runtime).

### 5.3. ✅ Git: instalado e versionado (04/06)
Git 2.54.0 instalado via winget. `git` ainda **não está no PATH desta sessão** — usar o caminho
completo `C:\Program Files\Git\cmd\git.exe` (ou abrir um terminal novo). Config local do repo:
`user.name = "Diego Arthur Hartmann"`, `user.email = diego.hartmann@gmail.com`, `core.autocrlf false`.
Commits: `ab1b238` (estado limpo, 250 arquivos) e `6e5568c` (correção da seta).
**Próximo passo recomendado:** criar um remoto **privado** no GitHub e dar `push` (backup off-machine).
Binários grandes versionados (`externo/bin/typst.exe` 36MB etc.) — todos <100MB, cabem no GitHub.

### 5.4. ✅ OneDrive reativado (04/06) — monitorar
Reativado nesta máquina (a **fonte da verdade**). Sem novos `-DiegoVirt` aqui. **Atenção:** ao
ligar a outra máquina ("DiegoVirt"), o OneDrive pode gerar `-DiegoVirt` lá — são **apagáveis**
(o estado bom está nesta máquina + git + backup de ontem). **Prevenção contínua:** commitar no
git com regularidade e dar `push` pro GitHub; não editar em duas máquinas em paralelo sem sincronizar.

---

## 6. Análise do bug da seta de requisitos (5.1) — ✅ RESOLVIDO

> **CAUSA RAIZ CONFIRMADA (04/06):** o `GradeCurricular.tscn` de hoje **perdeu o nó `SeletorGrade`**.
> O `grade_curricular.gd:46` faz `$"%SeletorGrade".opcao_selecionada.connect(...)`
> **incondicionalmente** no `_ready()`. Sem o nó, isso vira acesso a `null` → erro de runtime →
> o `_ready()` **aborta antes das linhas 50-51**, que conectam `celula_clicada`/`celula_clicada_direita`
> aos handlers. Resultado: a grade renderiza (o setter `_set_dados` injeta dados direto no `_grade`),
> mas o **clique não dispara nada** → sem seta. Com script idêntico ao de ontem, a única diferença
> era o nó ausente — daí "funcionava ontem, quebrou hoje".
>
> **A hipótese do `unique_id` (abaixo) estava ERRADA:** o `unique_id=NNN` é um atributo *extra*
> (não substituiu `unique_name_in_owner = true`, que continua presente), é tolerado pelo Godot
> (235 ocorrências em 16 `.tscn`, projeto carrega normal) e **não tem relação** com este bug.
> Fica anotado como anomalia separada a investigar (provável artefato de merge/recuperação).
>
> **Correção aplicada:** nó `SeletorGrade` restaurado (oculto, `unique_name_in_owner = true`),
> commit `6e5568c`. Falta só a confirmação visual no app.

---

**(Histórico da investigação — mantido para referência)**

**Sintoma:** clique esq/dir na grade curricular (módulo Situação de Alunos) não desenha mais a
seta de pré-requisitos. Funciona no backup de ontem.

**Fluxo do recurso (como deveria funcionar):**
1. `grade.gd` (componente que desenha) emite `celula_clicada` / `celula_clicada_direita`.
2. `grade_curricular.gd` (`_on_grade_celula_clicada`) traduz para `celula_selecionada(codigo)`.
3. `situacao_alunos.gd` recebe, calcula os requisitos (via `AnaliseGrades.montar_conexoes`) e
   seta `GradeCurricular.conexoes`.
4. `grade.gd._desenhar_conexoes()` desenha as setas (curvas Bézier).

**O que está IGUAL entre ontem e hoje (descarta como causa):**
- `grade.gd` (331 linhas) — **idêntico** (desenho das setas intacto).
- `grade_curricular.gd` (115 linhas) — **idêntico**.
- `analise_grades.gd`, `analise_curricular.gd`, `painel_disciplinas.gd` — **idênticos**.
- `Grade.tscn` — **idêntico**.
- `situacao_alunos.gd` — difere SÓ na refatoração da API do Terminal (`text_edit` →
  `titulo/secao/linha/item`). **Nada a ver** com requisitos.

**O que DIFERE (cenas):** `GradeCurricular.tscn`, `PainelDisciplinas.tscn`, `SituacaoAlunos.tscn`.
- `SituacaoAlunos.tscn`: só perdeu `size_flags_stretch_ratio = 1.0` (layout, improvável).
- **`GradeCurricular.tscn` — SUSPEITO PRINCIPAL:** a versão de HOJE está anômala:
  - usa `unique_id=NNN` nos nós (ex.: `unique_id=844458630`) — **sintaxe NÃO-padrão** do Godot;
    o normal é `unique_name_in_owner = true`;
  - perdeu o `load_steps=4` no cabeçalho e o nó `SeletorGrade`;
  - o `ext_resource` do script ganhou um `uid=`.
- `PainelDisciplinas.tscn` (hoje) também tem `unique_id=NNN`.

**Hipótese (NÃO confirmada):** o `grade_curricular.gd` (idêntico) usa referências `%SeletorOpcoes`
/ `%SeletorGrade`, que dependem de `unique_name_in_owner = true`. Se o Godot ignora `unique_id`,
essas referências `%` falham e parte da interação quebra. **Porém** a grade ainda aparece e é
clicável, então pode ser que o `%` funcione e o problema seja outro — **precisa testar**.

**Próximo passo diagnóstico (empírico, rápido):**
1. Copiar `backup_yesterday\scenes\Complementares\GradeCurricular\GradeCurricular.tscn` por cima
   do atual e testar se a seta volta. Se voltar → a causa é o `.tscn` (formato `unique_id`).
2. Se não voltar, investigar `PainelDisciplinas.tscn` (mesmo `unique_id`) e a conexão do sinal
   `celula_selecionada` → handler de requisitos no `situacao_alunos.gd`.
3. Investigar de onde veio o `unique_id` (parece um formato estranho/experimental ou artefato);
   se for sistêmico em vários `.tscn` de hoje, pode afetar mais coisas além desta seta.

> ⚠️ Atenção ao corrigir: NÃO basta copiar o `GradeCurricular.tscn` de ontem cegamente se formos
> portar a grade — a versão de ontem tem o nó `SeletorGrade` (da feature de grade do Planejamento
> de Oferta). Para o Situação de Alunos isso fica oculto (`visible = false`), então é compatível.

---

## 7. Mapa das pastas em `C:\Users\diego\Recovery_GD4\`

| Pasta | O que é |
|---|---|
| `snapshot_raw\` | Foto do projeto no início da recuperação (com `-DiegoVirt`). Segurança. |
| `backup_yesterday\` | Projeto COMPLETO de ontem (extraído do `.7z`). Referência da grade. |
| `base\` | Versões 02/06 baixadas do OneDrive (8 arquivos). ⚠️ NÃO é o ancestral real. |
| `today\`, `yesterday\` | Pares dos 11 arquivos de conflito (hoje vs ontem). |
| `merged\`, `assembled\` | Tentativa de merge automático — **DESCARTADA** (base errada). |
| `merged\planejamentooferta.gd` | ÚTIL: ontem (grade) + nossa `alteracoes.md` reconciliado. |
| `merge_driver.py`, `*.py` | Scripts da tentativa de merge (descartável). |

---

## 8. Recomendação de ordem ao retomar

1. ✅ **Instalar git + commit** (5.3) — feito (`ab1b238`).
2. ✅ **Resolver o bug da seta** (5.1/6) — feito (`6e5568c`); confirmado visualmente.
3. ✅ **Reativar OneDrive** (5.4) — feito; monitorar a outra máquina.
4. ✅ **Portar a grade** (5.2) — feito (`34044de`): grade + Curso + Exportar; verificado runtime.
   Falta só a confirmação interativa do usuário (demanda com hist.csv, exportações, prefixo por curso).
5. ⏳ **Push pro GitHub** (privado) — backup off-machine; fazer assim que possível. ← próximo passo.
