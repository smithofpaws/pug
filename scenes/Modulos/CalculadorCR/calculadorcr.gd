extends ReferenceRect

var file_handling := FileHandling.new()
var general_functions := GeneralFunctions.new()
var analise_historico := AnaliseHistorico.new()

# ~historico contem os dados do historico, de todos os alunos, que importam para esta análise
# ~lista_alunos é uma array contendo em cada elemento a combinação do nome do aluno e sua matrícula
var historico: Dictionary
var lista_alunos: Array[Array]

# ~posicoes_histcsv é recebido pelo main em sua criação e vem do arquivo base_config.json
var posicoes_histcsv: Dictionary
var grupos_complementares: Dictionary
var cores_terminal: Dictionary

## Configuracoes globais de interface, de [code]base_config.json[/code].
var config_interface: Dictionary = {}

var _metodo_analise: String = ""
var _aluno_cr_retorno: String = ""

func _ready() -> void:
	# Lê o historico para análise
	historico = file_handling.ler_dados(GV.dir_saida, "hist.csv", posicoes_histcsv, true)
	# Prepara a lista de alunos e de disciplinas
	lista_alunos = analise_historico.criar_lista_alunos(historico)
	var alunos_itens: Array[String] = []
	var alunos_retorno: Array[String] = []
	for a in lista_alunos.size():
		alunos_itens.append(lista_alunos[a][1].capitalize())
		alunos_retorno.append(lista_alunos[a][0])
	$"%SeletorListaAlunos".popular("alunos", alunos_itens, alunos_retorno)
	$"%SeletorListaAlunos".atualizar_texto_padrao = true
	if lista_alunos.size() > 0:
		$"%SeletorListaAlunos".selecionar_item(0)
		_aluno_cr_retorno = alunos_retorno[0]

	$"%SeletorMetodoAnalise".popular("metodo", ["Prováveis formandos", "Aluno específico"], \
		["provaveis_formandos", "aluno_especifico"])
	$"%SeletorMetodoAnalise".atualizar_texto_padrao = true
	$"%SeletorMetodoAnalise".selecionar_item(0)
	_metodo_analise = "provaveis_formandos"

	SeletorAvancado.dimensionar([$"%SeletorMetodoAnalise", $"%SeletorListaAlunos"], config_interface)

	# Abre já com o relatório de prováveis formandos (coerente com o método pré-selecionado).
	_calcular_cr()

func _calcular_cr(matricula: String = "") -> void:
	var provaveis_form: Array = []
	for matr in historico.keys():
		if matricula != "":
			matr = matricula
		var somanotaxch: float = 0
		var somach: float = 0
		var pesquisa: int = 0
		var ensino: int = 0
		var extensao: int = 0
		var cultura: int = 0
		var feztcc: bool = false
		for a in historico[matr]["dados"].size():
			if historico[matr]["dados"][a]["mediafinal"] != "":
				if not historico[matr]["dados"][a]["situacao"].begins_with("reprovado por freq"):
					somanotaxch += float(historico[matr]["dados"][a]["mediafinal"]) * float(historico[matr]["dados"][a]["cargahoraria"])
					somach += float(historico[matr]["dados"][a]["cargahoraria"])
				else:
					somach += float(historico[matr]["dados"][a]["cargahoraria"])
			elif historico[matr]["dados"][a]["situacao"].begins_with("dispensado"):
				somanotaxch += 6.0 * float(historico[matr]["dados"][a]["cargahoraria"])
				somach += float(historico[matr]["dados"][a]["cargahoraria"])
			if historico[matr]["dados"][a]["codigocurriculo"] == grupos_complementares["ensino"]:
				ensino += int(float(historico[matr]["dados"][a]["cargahoraria"]))
			if historico[matr]["dados"][a]["codigocurriculo"] == grupos_complementares["pesquisa"]:
				pesquisa += int(float(historico[matr]["dados"][a]["cargahoraria"]))
			if historico[matr]["dados"][a]["codigocurriculo"] == grupos_complementares["extensao"]:
				extensao += int(float(historico[matr]["dados"][a]["cargahoraria"]))
			if historico[matr]["dados"][a]["codigocurriculo"] == grupos_complementares["cultura"]:
				cultura += int(float(historico[matr]["dados"][a]["cargahoraria"]))
			if historico[matr]["dados"][a]["nomeativcurricular"].begins_with("trabalho de conclus"):
				if historico[matr]["dados"][a]["nomeativcurricular"].ends_with("ii"):
					feztcc = true
			if a == historico[matr]["dados"].size() - 1:
				if feztcc or matricula != "":
					var cr_val: float = somanotaxch / somach if somach > 0 else 0.0
					provaveis_form.append([historico[matr]["nomedoaluno"], cr_val, ensino, pesquisa, extensao, cultura])
		if matricula != "":
			break
	# Ordenando de maior CR para menor
	provaveis_form.sort_custom(func(a, b): return a[1] > b[1])
	if matricula != "":
		if provaveis_form.is_empty():
			$"%Terminal".titulo("Sem dados", true)
			$"%Terminal".linha("Nenhuma disciplina encontrada.")
		else:
			var nome: String = str(provaveis_form[0][0]).capitalize()
			var cr: String = "%.2f" % provaveis_form[0][1]
			$"%Terminal".titulo(nome, true)
			$"%Terminal".linha("CR: " + cr)
			$"%Terminal".secao("Horas Complementares")
			$"%Terminal".item("Ensino: " + str(provaveis_form[0][2]) + "h")
			$"%Terminal".item("Pesquisa: " + str(provaveis_form[0][3]) + "h")
			$"%Terminal".item("Extensão: " + str(provaveis_form[0][4]) + "h")
			$"%Terminal".item("Cultura: " + str(provaveis_form[0][5]) + "h")
	else:
		$"%Terminal".titulo("Prováveis Formandos — " + str(provaveis_form.size()) + " aluno(s)", true)
		if provaveis_form.is_empty():
			$"%Terminal".linha("Nenhum aluno com Trabalho de Conclusão II concluído.")
		else:
			for a in provaveis_form.size():
				var nome: String = str(provaveis_form[a][0]).capitalize()
				var cr: String = "%.2f" % provaveis_form[a][1]
				$"%Terminal".item(nome + " — CR: " + cr
						+ " | Ensino: " + str(provaveis_form[a][2]) + "h"
						+ " | Pesquisa: " + str(provaveis_form[a][3]) + "h"
						+ " | Extensão: " + str(provaveis_form[a][4]) + "h"
						+ " | Cultura: " + str(provaveis_form[a][5]) + "h")


func _on_seletor_metodo_analise_opcao_selecionada(retorno: String, _lista_selecionada: Array) -> void:
	_metodo_analise = retorno
	if retorno == "provaveis_formandos":
		$"%CalcularCR".show()
		$"%LabelVar1".hide()
		$"%SeletorListaAlunos".hide()
	elif retorno == "aluno_especifico":
		$"%CalcularCR".hide()
		$"%LabelVar1".show()
		$"%SeletorListaAlunos".show()
		_calcular_cr(_aluno_cr_retorno)

func _on_seletor_lista_alunos_opcao_selecionada(retorno: String, _lista_selecionada: Array) -> void:
	_aluno_cr_retorno = retorno
	_calcular_cr(retorno)

func _on_calcular_cr_button_up() -> void:
	_calcular_cr()
