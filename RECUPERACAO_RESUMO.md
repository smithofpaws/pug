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

**Regra de ouro:** o trabalho de hoje está no projeto OneDrive; o de ontem está no `.7z` +
`backup_yesterday`. Os dois existem. Pode descansar tranquilo.

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

---

## 5. Tarefas PENDENTES

### 5.1. 🐞 Bug da seta de requisitos (em análise — ver seção 6)
Clicar (esq/dir) numa célula da grade curricular no **Situação de Alunos** deveria mostrar a
seta de pré-requisitos. **Funciona no backup de ontem, quebrou no projeto atual.**

### 5.2. 🔧 Portar a feature de grade curricular (escopo levantado)
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

### 5.3. 🔒 Git: instalar e fazer o 1º commit
Git não está instalado. Para travar o estado: rodar no prompt da sessão (pede confirmação):
```
! winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements
```
Depois: ajustar `.gitignore` (já é razoável) e `git add -A && git commit`.

### 5.4. ☁️ Reativar o OneDrive (com cuidado)
Está pausado 24h nas duas máquinas. Ao religar: **esta máquina é a fonte da verdade**; vão
aparecer novos `-DiegoVirt` na outra máquina (apagáveis, pois ontem está no backup).
**Prevenção:** commitar no git com regularidade (idealmente remoto/GitHub); não editar em duas
máquinas em paralelo sem sincronizar.

---

## 6. Análise do bug da seta de requisitos (5.1) — estado da investigação

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

1. **Primeiro instalar git + commit** (5.3) — trava o estado atual antes de qualquer mudança.
2. **Resolver o bug da seta** (5.1/6) — é pequeno e isolado; bom aquecimento.
3. **Portar a grade** (5.2) — tarefa maior; entrar em plan mode antes.
4. **Reativar OneDrive** (5.4) por último.
