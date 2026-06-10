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

# Curso (cod_curso) cuja lista de irregulares está sendo exibida. Definido pelo seletor de grade.
var _curso_ativo: String = ""

# Cache { matricula: cod_curso } para filtrar a lista por curso sem redetectar a grade a cada render.
var _curso_por_matricula: Dictionary = {}

# Guarda contra impressões durante a configuração inicial (o selecionar_item do seletor dispara o
# sinal antes de tudo estar pronto). Espelha o padrão de outros módulos.
var _pronto: bool = false

func _ready() -> void:
	# Consome o cache de dados discentes pre-computado pelo main (evita recalcular a cada troca de
	# modulo). Fallback: se o cache estiver vazio (ex.: cena aberta fora do fluxo), computa local.
	if not GV.dados_discentes.is_empty():
		_historico = GV.dados_discentes["historico"]
		_lista_alunos = GV.dados_discentes["lista_alunos"]
		_condicoes_discentes = GV.dados_discentes["condicoes_discentes"]
	else:
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
	# Mapeia cada matrícula ao seu curso para o filtro por curso.
	_construir_cache_curso()
	# Seletor de grade no topo: auto-seleciona o PPC principal e define o curso ativo (o selecionar_item
	# dispara o handler, que com _pronto=false ainda não imprime).
	_preparar_seletor_grades()
	# Imprime os alunos em situação irregular do curso ativo no terminal.
	_pronto = true
	_imprimir_irregulares()


# Popula o seletor de grades (ignora placeholders [code]_0000[/code]) e auto-seleciona a grade do PPC
# principal das configurações. O filtro da lista é por CURSO, então a versão da grade escolhida não
# altera o resultado — serve apenas para identificar o curso.
func _preparar_seletor_grades() -> void:
	var chaves_validas: Array[String] = []
	for key in grades_disciplinas_curriculos.keys():
		if str(key).ends_with("_0000"):
			continue
		chaves_validas.append(str(key))
	chaves_validas.sort()
	$"%SeletorListaGrades".lista_itens = { "_grades*": chaves_validas }
	$"%SeletorListaGrades".atualizar_texto_padrao = true
	if chaves_validas.size() > 0:
		var indice: int = chaves_validas.size() - 1
		var ppc: String = GV.configuracao_base.get("ppc_principal", "")
		if not ppc.is_empty():
			for i in chaves_validas.size():
				if chaves_validas[i] == ppc:
					indice = i
					break
		$"%SeletorListaGrades".selecionar_item(indice)


# Detecta, uma única vez, o curso (cod_curso) de cada matrícula a partir da grade do discente
# ([code]<cod_curso>_<versao>[/code] → prefixo). Cacheia para o filtro não redetectar a cada render.
func _construir_cache_curso() -> void:
	_curso_por_matricula.clear()
	for aluno in _lista_alunos:
		var grade: String = analise_historico.detectar_versao_grade(aluno[0], _historico)
		_curso_por_matricula[aluno[0]] = grade.split("_")[0] if not grade.is_empty() else ""


# Troca o curso ativo conforme a grade selecionada (o curso é o prefixo da chave da grade) e reimprime.
func _on_seletor_lista_grades_opcao_selecionada(retorno: String, _lista_selecionada: Array) -> void:
	_curso_ativo = retorno.split("_")[0]
	if _pronto:
		_imprimir_irregulares()


# Percorre todos os alunos e imprime no terminal aqueles que possuem disciplinas
# nas condições [code]matricula_irregular[/code] ou [code]matricula_irregular_aproveitamento[/code].
func _imprimir_irregulares() -> void:
	var nome_curso: String = str(GV.configuracao_base.get("cursos", {}).get(_curso_ativo, {}).get("nome", _curso_ativo.to_upper()))
	$"%Terminal".titulo("Alunos em situação de matrícula irregular — " + nome_curso, true)
	$"%Terminal".linha("Disciplinas matriculadas sem os pré-requisitos necessários.")
	$"%Terminal".espaco()
	var alunos_listados: int = 0
	for aluno in _lista_alunos:
		var matricula: String = aluno[0]
		# Filtra pelo curso ativo, independente da versão da grade do discente.
		if _curso_por_matricula.get(matricula, "") != _curso_ativo:
			continue
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
