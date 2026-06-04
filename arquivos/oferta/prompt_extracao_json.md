# Prompt para Extração de Dados de Professores

Atue como um assistente especialista em processamento de dados. Sua tarefa é extrair e estruturar os dados de horários de aulas de um arquivo CSV (advindo do relatorio 5204 do sistema GURI) para um formato JSON específico. Verifique se o conteúdo do relatório 5204 contempla dois semestres no ano. Relatório com apenas 1 semestres devem ser inválidos.

**Professores Alvo:** [NOME_DO_PROFESSOR]

**Contexto dos Dados de Entrada (CSV):**
O arquivo possui delimitador `;` e as seguintes colunas de interesse:
- `cod_disciplina` (Código da disciplina)
- `ano` (Ano de oferta)
- `periodo` (Semestre de oferta, ex: "1. Semestre")
- `dia_semana` (Dia da semana da aula)
- `hr_inicio` (Horário de início)
- `hr_fim` (Horário de término)
- `docente` (Nome do professor)
- `cod_turma` (Código da turma)

**Regras de Processamento:**
1. **Filtro:** Considere apenas as linhas onde a coluna `docente` corresponda ao "Professor Alvo" (ignorando diferenças de maiúsculas/minúsculas e acentos).
2. **Formatação da Chave Raiz:** O nome do professor deve ser convertido para `snake_case` sem acentos (ex: "Diego Arthur Hartmann" se torna "diego_arthur_hartmann"). Esta será a chave principal do JSON.
3. **Agrupamento:** 
   - O primeiro nível interno deve ser o código da disciplina (`cod_disciplina`), todo em letras minúsculas.
   - O segundo nível deve ser o `ano`.
   - O terceiro nível deve ser o número do semestre. Você deve extrair apenas o número da coluna `periodo` (ex: transforme "1. Semestre" em "1").
4. **Lista de Horários:** Dentro de cada semestre, crie uma lista contendo os horários das aulas. Cada item da lista deve ser um objeto com:
   - `"dia"`: O conteúdo exato da coluna `dia_semana`.
   - `"horario"`: Uma string concatenando o início e fim da aula no formato `"hr_inicio - hr_fim"`.
5. **Código Turma** Após as informações de horário deve ser informado o código da turma, que é um valor numérico que representa os cursos aos quais as disciplinas atendem. Este código pode conter letras no arquivo original, porém o arquivo final deve conter apenas números inteiros. Exemplos: `T20` deve ser apenas `[20]` (em uma lista). `T20/40` deve ser separado em uma lista, isto é `[20,40]`.

**Estrutura Exata do JSON Esperado (Exemplo):**
```json
{
    "nome_do_professor_em_snake_case": {
        "AL0067": {
            "2017": {
                "1": [
                    {
                        "dia": "Terça-feira",
                        "horario": "13:30:00 - 15:20:00"
                    },
                    {
                        "dia": "Quarta-feira",
                        "horario": "13:30:00 - 14:25:00"
                    },
						"turma:": [20,40]
                ]
            }
        }
    }
}
```
**Ação:** Baseado nos dados fornecidos do CSV e nas regras acima, gere apenas o código JSON final correspondente ao professor solicitado, sem explicações adicionais. Nomeie o arquivo como historico_professores.json