# Fixtures de teste

Dados de entrada **fictícios** para testes headless e smoke tests. Ficam
versionados, então a regra do `AGENTS.md` é absoluta: **nenhum dado pessoal
real** — nomes de pessoa são inventados (`Maria da Silva Souza`), matrículas são
sintéticas, e-mails são `@exemplo.invalido`.

Nunca copie um `hist.csv`/`email.csv`/`planejamento.csv` real para cá, nem
"anonimizado na mão" — recorte colunas e invente valores. Um teste que precise
do formato real referencia as posições em `base_config.json:posicoes_histcsv`,
não um arquivo real.
