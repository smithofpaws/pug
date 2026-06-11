extends ReferenceRect

var file_handling := FileHandling.new()
var general_functions := GeneralFunctions.new()
var analise_historico := AnaliseHistorico.new()

# ~historico contem os dados do historico, de todos os alunos, que importam para esta análise
# ~lista_alunos é uma array contendo em cada elemento a combinação do nome do aluno e sua matrícula
var historico: Dictionary
var lista_alunos: Array[Array]

# ~posicoes_histcsv é recebido pelo main em sua criação e vem do arquivo base_config.json
# ~limites é recebido pelo main em sua criação e vem do arquivo base_config.json
var posicoes_histcsv: Dictionary = {}
var limites: Dictionary = {}
var cores_terminal: Dictionary = {}
var efeitos: Dictionary = {}

func _ready() -> void:
	# Lê e simplifica o historico para conter apenas as linhas aprovadas
	historico = file_handling.ler_dados(GV.dir_saida, "hist.csv", posicoes_histcsv, false, GV.grades)
	analise_historico.simplificar_historico(historico, "situacao", ["tranc"])
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

func _on_seletor_lista_alunos_opcao_selecionada(retorno: String, _lista_selecionada: Array) -> void:
	var index: int = -1
	for a in lista_alunos.size():
		if lista_alunos[a][0] == retorno:
			index = a
			break
	if index < 0:
		return
	var local_historico: Array[Dictionary] = historico[lista_alunos[index][0]]["dados"]
	var trancamentos_totais: Array[Array] = []
	if local_historico.size() == 0:
		$"%Terminal".text_edit("Não foram encontrados trancamentos para o discente.", cores_terminal["padrao"], false, true)
	else:
		$"%Terminal".titulo("Trancamentos do discente", true)
	for a in local_historico.size():
		var semestre: String = local_historico[a].get("semestre", "")
		if local_historico[a]["situacao"] == "trancamento parcial":
			$"%Terminal".text_edit("- Foi realizado um " + local_historico[a]["situacao"], cores_terminal["padrao"], true)
			$"%Terminal".text_edit(" na disciplina " + local_historico[a]["nomeativcurricular"], cores_terminal["padrao"], false)
			$"%Terminal".text_edit(" no semestre " + local_historico[a]["ano"] + "/" + semestre + ".", cores_terminal["padrao"], false)
		else:
			$"%Terminal".text_edit("- Foi realizado um " + local_historico[a]["situacao"], cores_terminal["padrao"], true)
			$"%Terminal".text_edit(" no semestre " + local_historico[a]["ano"] + "/" + semestre + ".", cores_terminal["padrao"], false)
			trancamentos_totais.append([local_historico[a]["ano"], semestre])
	$"%Terminal".espaco()
	if limites.get("total", -1) == -1 or limites.get("consecutivo", -1) == -1:
		print_debug("ERRO: Não foi possível obter os limites de trancamentos (total e consecutivo). Verificar base_conf.json!")
		return
	if trancamentos_totais.size() >= limites["total"]:
		# Se o número máximo de trancamentos foi atingido
		$"%Terminal".linha("Este discente já realizou o limite de trancamentos totais (" + \
		str(trancamentos_totais.size()) + "/"+str(limites["total"])+")!", cores_terminal["erro"])
		$"%Terminal".linha("De acordo com a resolução 29, Art 48, §4:")
		$"%Terminal".linha(" \"§4º O número máximo de trancamentos totais é 4 (quatro), devendo ser:\"")
		# Se já foram realizados trancamentos
	elif trancamentos_totais.size() > 0:
		$"%Terminal".secao("Trancamentos totais do discente")
		for a in trancamentos_totais.size():
			$"%Terminal".item(trancamentos_totais[a][0] + "/" + trancamentos_totais[a][1])
		$"%Terminal".linha("Observar de acordo com a resolução 29, Art 48, §4, b):")
		$"%Terminal".linha(" \"b) permitido no máximo 2 (dois) trancamentos totais consecutivos.\"")
	elif int(lista_alunos[index][0].left(2)) == 23:
		# Se o aluno é ingressante
		$"%Terminal".linha("Este discente não pode realizar trancamento total pois é ingressante!", cores_terminal["aviso"])
		$"%Terminal".linha("Observar de acordo com a resolução 29, Art 48, §5:")
		$"%Terminal".linha(" \"§5º Não é concedido Trancamento Total ao discente ingressante, independente da forma de ingresso, exceto nas situações previstas na legislação.\"")
	print(int(lista_alunos[index][0].left(2)))
