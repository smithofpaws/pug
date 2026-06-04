class_name MatriculaIrregular extends ReferenceRect
## Relacionado a listagem de discentes em situação de matrícula irregular.
## [br]
## Verifica, para todos os alunos, quais estão matriculados em disciplinas sem possuir
## os pré-requisitos necessários (condição [code]matricula_irregular[/code] e
## [code]matricula_irregular_aproveitamento[/code] do arquivo [code]base_config.json[/code]).
## A análise utiliza [method AnaliseHistorico.condicoes_discentes] para cruzar o histórico
## com as grades curriculares e determinar as irregularidades.

# Classes instanciadas.
var file_handling := FileHandling.new()
var analise_historico := AnaliseHistorico.new()
var analise_grades := AnaliseGrades.new()

## Recebido pelo main em sua criação e vem do arquivo [code]base_config.json[/code].
var posicoes_histcsv: Dictionary

## Recebido pelo main em sua criação e vem do arquivo [code]base_config.json[/code].
var condicoes: Array[String]

## Recebido pelo main em sua criação e vem da pasta de grades. [br]
## Formato de [param grades_disciplinas_curriculos] deve conter múltiplas grades, com chave no padrão
## [code]<cod_curso>_<versao>[/code]. Exemplo: [br]
## { [br]
## "alec_2010": Dicionário copia de [code]/arquivos/grades/alec_2010.json[/code], [br]
## "alec_2023": Dicionário copia de [code]/arquivos/grades/alec_2023.json[/code] [br]
## }
var grades_disciplinas_curriculos: Dictionary = {}

## Recebido pelo main em sua criação e vem da pasta de equivalencias.
var equivalencias: Dictionary = {}

## Recebido pelo main, contem as cores padrao do terminal.
var cores_terminal: Dictionary = {}

## Recebido pelo main, contem os efeitos de texto do terminal.
var efeitos: Dictionary = {}

# Contém os dados do historico, de todos os alunos, que importam para esta análise.
var _historico: Dictionary

# É uma array contendo em cada elemento a combinação do nome do aluno e sua matrícula.
var _lista_alunos: Array[Array]

# Contém as disciplinas que todos alunos se enquadram dentro de [param condicoes].
var _condicoes_discentes: Dictionary

func _ready() -> void:
	# Lê o historico
	_historico = file_handling.ler_dados(GV.dir_saida, "hist.csv", posicoes_histcsv, false, grades_disciplinas_curriculos)
	# Simplifica para conter apenas as linhas aprovadas, dispensadas e em matrícula.
	analise_historico.simplificar_historico(_historico, "situacao", \
		["aprovado", "dispensado", "matr"])
	# Prepara a lista de alunos.
	_lista_alunos = analise_historico.criar_lista_alunos(_historico)
	# Verificar, para todos alunos, as disciplinas matriculadas, matriculáveis, etc (conforme [param condicoes]).
	_condicoes_discentes = analise_historico.condicoes_discentes(_lista_alunos, _historico, condicoes, \
	grades_disciplinas_curriculos, equivalencias)
	# Imprime os alunos em situação irregular no terminal.
	_imprimir_irregulares()


# Percorre todos os alunos e imprime no terminal aqueles que possuem disciplinas
# nas condições [code]matricula_irregular[/code] ou [code]matricula_irregular_aproveitamento[/code].
func _imprimir_irregulares() -> void:
	$"%Terminal".titulo("Alunos em situação de matrícula irregular", true)
	$"%Terminal".linha("Disciplinas matriculadas sem os pré-requisitos necessários.")
	$"%Terminal".espaco()
	var alunos_listados: int = 0
	for aluno in _lista_alunos:
		var matricula: String = aluno[0]
		var nome: String = aluno[1].capitalize()
		var disc_aluno: Dictionary = _condicoes_discentes.get(matricula, {})
		var irregulares: Array = disc_aluno.get("matricula_irregular", [])
		var irregulares_aprov: Array = disc_aluno.get("matricula_irregular_aproveitamento", [])
		if irregulares.size() == 0 and irregulares_aprov.size() == 0:
			continue
		alunos_listados += 1
		$"%Terminal".secao(nome + " (" + matricula + ")")
		for codigo in irregulares:
			var nome_disc: String = analise_grades.info_grade(grades_disciplinas_curriculos, codigo, "nome")
			$"%Terminal".item(codigo + ": " + nome_disc + " [IRREGULAR]", 0, cores_terminal["erro"])
		for codigo in irregulares_aprov:
			var nome_disc: String = analise_grades.info_grade(grades_disciplinas_curriculos, codigo, "nome")
			$"%Terminal".item(codigo + ": " + nome_disc + " [IRREGULAR - APROVEITAMENTO]", 0, cores_terminal["erro"])
		$"%Terminal".espaco()
	if alunos_listados == 0:
		$"%Terminal".linha("Nenhum aluno em situação de matrícula irregular encontrado.", cores_terminal["sucesso"])
	else:
		$"%Terminal".linha("Total de alunos com matrícula irregular: " + str(alunos_listados), cores_terminal["alerta"])
