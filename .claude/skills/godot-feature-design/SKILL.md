---
name: godot-feature-design
description: Projeta a implementação de uma feature em GDScript no PUG (Godot 4.7) antes de escrever código, produzindo uma spec com contrato tipado, invariantes de domínio e mapeamento AC→teste. Aplica arquitetura em camadas usando os nomes reais do repositório (analise_* como núcleo puro, main.gd como composição e injeção, FileHandling como adaptador de persistência, módulos de cena como adaptadores de UI) em vez de impor uma taxonomia de pastas nova. Use esta skill SEMPRE antes de implementar qualquer card, e também quando alguém perguntar onde uma funcionalidade nova deve morar, se uma mudança viola camada, como modelar dado novo nos JSONs de arquivos/, ou pedir revisão de arquitetura/design de uma feature Godot — mesmo que não use as palavras "hexagonal", "DDD" ou "spec".
---

# Design de feature — PUG

Transforma um card aprovado em spec executável. A spec vai para
`Cards/<id>/spec.md` e é o que o agente de implementação lê.

Nada de código aqui. Se você está escrevendo GDScript, saiu do escopo desta skill.

---

## O projeto já tem camadas — use os nomes que ele tem

Não crie `domain/`, `application/` ou `infrastructure/`. A separação já existe, com
outros nomes, e o `AGENTS.md` a descreve. O resumo que decide a maioria dos casos:

| Papel | Neste repositório |
|---|---|
| Núcleo de domínio (lógica pura) | `standalone_scripts/analise/*` — AnaliseHistorico, AnaliseGrades, AnaliseCurricular, AnaliseHorarios, AnaliseReprovacoes, CalculoCargaHoraria |
| Utilitários puros | `standalone_scripts/utils/*` — GeneralFunctions, JsonValidator, MarkdownHtml |
| Composição e injeção | `scenes/main.gd` — lê arquivos, monta os dados e injeta nos módulos |
| Adaptador de persistência | `standalone_scripts/io/file_handling.gd` — leitura/escrita canônica de disco |
| Adaptadores de rede | `standalone_scripts/io/sincronizacao*.gd` (Kinto), `atualizador.gd` (releases) |
| Adaptador driving (UI) | `scenes/Modulos/*` e `scenes/Complementares/*` |
| Configuração | `base_config.json` (sobreposto por `config_usuario.json`) — nunca `GV` |

**Regra de dependência:** módulo de cena conhece as classes de análise; a análise
não conhece módulo, nó de cena, nem arquivo. Uma classe `Analise*` recebe
dicionários e arrays por parâmetro (o main leu e o módulo repassa) — nunca abre
`FileAccess` nem lê `GV` mutável.

## Dependência como parâmetro é a porta

O padrão canônico do repositório: os módulos declaram **variáveis injetadas**
(`## Recebido pelo main...`) e as análises recebem tudo por argumento:

```gdscript
func condicoes_discentes(lista_alunos: Array[Array], historico: Dictionary,
		condicoes: Dictionary, grades: Dictionary, equivalencias: Dictionary) -> Dictionary:
```

Sempre que projetar lógica nova, pergunte: dá para receber o que ela precisa em vez
de buscar? Se sim, ela cai na camada testável headless e o card ganha ACs
`headless` em vez de `manual`. Extrair a lógica de um módulo de cena para uma
classe de `standalone_scripts/` costuma ser a melhoria de design mais valiosa de
um card.

---

## Proibição nomeada: contratos de dados são congelados

**Nunca renomeie nem mude o significado de uma chave existente** nos formatos que
o programa grava ou consome:

- **JSONs de `arquivos/`** (grades, cargas exigidas, equivalências, dicas): são
  consumidos também fora do programa — repositórios de curso (`alec-data`) e o
  `ppc2023` em Typst leem a mesma grade. Uma chave renomeada não dá erro: o
  consumidor lê default em silêncio.
- **`base_config.json`**: sobreposto por `config_usuario.json` via merge — chave
  renomeada deixa o override do usuário órfão, sem aviso.
- **Records do Kinto** (`planejamentos`): outros coordenadores têm clientes em
  versões diferentes.
- **Formatos de `dados/`** (hist.csv, planejamento.csv, horarios.txt): vêm do GURI
  e do Google — o programa se adapta a eles, nunca o contrário. As posições vivem
  em `base_config.json:posicoes_histcsv`.

Adicionar chave nova com default seguro é ok. Renomear/remodelar é um card próprio
de migração, com plano para os arquivos já existentes nas 3 máquinas e nos
repositórios de curso.

**Atenção aos tipos do JSON:** número em JSON carrega como float — turma `40`
vira `40.0`, e comparar por `str()` contra o `40` do histórico falha. Compare por
`int()` (defeito já mordido; ver memória do projeto).

---

## Padrões que o repositório já usa

Cite o precedente ao propor — é mais convincente e mantém o código coerente.

| Padrão | Onde já está |
|---|---|
| Injeção pelo composition root | `main.gd` → variáveis `## Recebido pelo main` dos módulos |
| Núcleo puro chamável por parâmetro | `AnaliseHorarios.detectar_choques`, `CalculoCargaHoraria` |
| Fachada de diálogo única | `Dialogos.confirmar/avisar/escolha_lista` + `limitar_a_tela` |
| Tokens semânticos de cor | `PaletaSemantica.cor/cor_hex/cor_adaptada` |
| Rótulo separado do valor canônico | `SeletorAvancado` com par `_retorno` |
| Saída padronizada de relatório | helpers do `Terminal` (`titulo`, `secao`, `item`, `linha`) |
| Estado por máquina fora do sync | `user://` (`admin_kinto.json`, `atualizacao.json`) vs `config_usuario.json` |
| Degradação sem crash | `main.gd` checa existência de `arquivos/oferta/` antes de ler |

## Invariantes de domínio que a spec precisa preservar

Quebrar uma destas é finding bloqueante no review:

1. **Dado pessoal não sai do PC.** Nada de aluno/docente em arquivo versionado,
   log commitável, exportação fora de `exportacoes/`, PNG de smoke, ou rede — a
   única exceção é o planejamento de oferta via Kinto (dado funcional,
   autenticado, Tailscale). Arquivo novo gitignorado na raiz do projeto precisa
   entrar no `exclude_filter` de **todos** os presets de export (o PCK embute
   tudo com `all_resources` — foi assim que o token do Kinto vazou na 1.0.0).
2. **snake_case interno, formatação só na UI.** Chave de dicionário, valor de
   lógica e identificador ficam sem acento/espaço; a conversão para apresentação
   acontece no momento de inserir na UI.
3. **Cursos e chaves canônicas.** `base_config.json:cursos` é a fonte única;
   grade = `<cod_curso>_<versao>`, equivalência = `<origem>-<destino>`, `0000` é
   o placeholder "sem grade". Nenhuma lista de cursos duplicada.
4. **Leitura de arquivo no main/FileHandling; módulo recebe injetado.** E o
   programa funciona com o arquivo ausente — checagem de existência + módulo
   degradado, nunca crash.
5. **UI pelas fachadas.** Tooltip = `DicaFlutuante`; diálogo = `Dialogos` (ou
   `AcceptDialog` custom para formulário, sempre com `limitar_a_tela` após
   `popup_centered`); cor = `PaletaSemantica`; identidade de oferta =
   `chave_planejamento` (nunca buscar por codigo+semestre).

---

## Formato da spec

Grave em `Cards/<id>/spec.md`:

```markdown
# Spec — NNNN-slug

## Camadas tocadas
Quais arquivos, e por quê cada um. Se toca mais de três camadas, justifique.

## Contrato público novo ou alterado
Assinaturas completas e tipadas, como vão existir no código:
    func disciplinas_concluidas_expandidas(historico: Dictionary, equivalencias: Dictionary) -> Dictionary
Para cada uma: quem chama, o que garante, o que assume do chamador.

## Invariantes
Quais das cinco acima esta feature toca, e como não as quebra.

## Mapeamento AC → prova
| AC do card | Método | Onde |
|---|---|---|
| AC1 | headless | test/unit/test_analise_grades.gd::test_equivalencia_expandida |
| AC3 | smoke | Cards/NNNN/smoke/ac3-grade-dourada.png |
| AC4 | manual | roteiro em smoke.md |

## Riscos de contrato de dados
Chave nova em JSON? Default escolhido e por quê. Nenhum renome. O dado toca
LGPD? Onde ele aparece (tela, exportação, rede, log)?

## Ordem de implementação
Passos, cada um deixando a suíte verde.
```

## Antes de entregar a spec

- Todo AC do card aparece no mapeamento. Um AC sem prova é um card que vai passar
  sem estar pronto.
- Nenhuma assinatura nova viola a regra de dependência.
- Nenhuma chave de contrato de dados mudou de nome ou significado.
- A lógica pura foi separada do que precisa de UI/rede, quando possível.
- A superfície LGPD foi mapeada explicitamente (mesmo que a resposta seja "não
  toca dado pessoal").
