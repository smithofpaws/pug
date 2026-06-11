extends ReferenceRect
## Relacionado a ilustração da situação das disciplinas. Especialmente na determinação de  
## horários livres para discentes em uma turma e choques de horários.
##
## Os principais empregos são: [br]
## - Apresentar os horários livres e ocupados dos discentes em uma dada disciplina; [br]
## - Verificar choques de horário entre disciplinas.

# Classes instanciadas.
var file_handling := FileHandling.new()
var analise_historico := AnaliseHistorico.new()
var analise_grades := AnaliseGrades.new()
var analise_horarios := AnaliseHorarios.new()
var horarios_exe := HorariosExe.new()

## Recebido pelo main em sua criação e vem do arquivo base_config.json.
var lista_cores: Dictionary = {}

## Recebido pelo main em sua criação e vem do arquivo [code]base_config.json[/code].
var condicoes: Array[String]

## Recebido pelo main em sua criação e vem do arquivo [code]base_config.json[/code].
var posicoes_histcsv: Dictionary

## Recebido pelo main em sua criação e vem do arquivo [code]base_config.json[/code].
var posicoes_horarios_txt: Dictionary

## Recebido pelo main em sua criação e vem da pasta de equivalencias.
var equivalencias: Dictionary = {}

## Recebido pelo main em sua criação e vem da pasta de grades. [br]
## Formato de [param grades_disciplinas_curriculos] deve conter múltiplas grades, com chave no padrão
## [code]<cod_curso>_<versao>[/code]. Exemplo: [br]
## { [br]
## "alec_2010": Dicionário copia de [code]/arquivos/grades/alec_2010.json[/code], [br]
## "alec_2023": Dicionário copia de [code]/arquivos/grades/alec_2023.json[/code] [br]
## }
var grades_disciplinas_curriculos: Dictionary = {}

## Recebido pelo main, contem as cores padrao do terminal.
var cores_terminal: Dictionary = {}

## Recebido pelo main, contem os efeitos de texto do terminal.
var efeitos: Dictionary = {}

## Configuracoes globais de interface, de [code]base_config.json[/code].
var config_interface: Dictionary = {}

## Modos de exibição das células da grade (lista canônica), de [code]base_config.json:formatos_grade[/code].
var formatos_grade: Dictionary = {}

# Grade atualmente selecionada.
var _grade_ativa: String

# Contem os dados do historico, de todos os alunos, que importam para esta análise.
var _historico: Dictionary

# Contem as disciplinas que todos alunos se enquadram dentro de [param condicoes].
var _condicoes_discentes: Dictionary

# Contem os dados do arquivo ini, organizados em forma de um dicionário.
var _horarios_ini: Dictionary

# Contem os dados do arquivo ini, organizados em forma de um dicionário.
var _horarios_txt: Array

# É uma array contendo em cada elemento a combinação do nome do aluno e sua matrícula.
var _lista_alunos: Array[Array]

# É uma array contendo as informações de reprovação de todas matrículas.
var _analisado_reprov: Dictionary

# É uma array contendo em cada elemento a combinação do nome da disciplina e seu código.
var _lista_disciplinas: Array[Array]

# Lista de modos de análise.
var _lista_opcoes: Dictionary = {
	"_lista": ["Análise isolada", "Comparação"],
	"_lista_retorno": ["isolada", "comparacao"]
}

# Vem de [method AnaliseHorarios._preparar_horarios], e remete a forma de apresentação
# dos horários na grade de horários.
var _forma_de_apresentacao: String = "esferas"

# Tipo de análise selecionada.
var _retorno: String = "isolada"

# Linha selecionada em OptionListaDisciplinas1
var _linha_selecionada1: int = 0

# Linha selecionada em OptionListaDisciplinas2
var _linha_selecionada2: int = 0

## Impede que os signals de inicialização disparem [_rodar_análise] múltiplas vezes.
var _pronto := false

func _ready() -> void:
	# Preparação das cenas.
	$"%Horarios".formatos_grade = formatos_grade
	$"%Horarios".condicoes = condicoes
	$"%SeletorTipoAnalise".lista_itens = _lista_opcoes
	$"%SeletorTipoAnalise".atualizar_texto_padrao = true
	_preparar_grades()
	# Consome o cache de dados discentes pre-computado pelo main (evita recalcular a cada troca de
	# modulo). Fallback: se o cache estiver vazio (ex.: cena aberta fora do fluxo), computa local.
	if not GV.dados_discentes.is_empty():
		_historico = GV.dados_discentes["historico"]
		_analisado_reprov = GV.dados_discentes["reprovacoes"]
		_lista_alunos = GV.dados_discentes["lista_alunos"]
		_condicoes_discentes = GV.dados_discentes["condicoes_discentes"]
	else:
		# Lê o historico
		_historico = file_handling.ler_dados(GV.dir_saida, "hist.csv", posicoes_histcsv, false, grades_disciplinas_curriculos)
		# Analisa as reprovações de cada discente
		var _lista_situacoes = analise_historico.listar_situacao(_historico, ["reprovado com nota", "Reprovado por Frequência"])
		_analisado_reprov = analise_historico.processar_reprovacoes(_lista_situacoes)
		# Simplifica para conter apenas as linhas aprovadas.
		analise_historico.simplificar_historico(_historico, "situacao", ["aprovado","dispensado","matr"])
		# Prepara a lista de alunos.
		_lista_alunos = analise_historico.criar_lista_alunos(_historico)
		# Verificar, para todos alunos, as disciplinas matriculadas, matriculáveis, etc (conforme [param condicoes]).
		_condicoes_discentes = analise_historico.condicoes_discentes(_lista_alunos, _historico, condicoes, \
		grades_disciplinas_curriculos, equivalencias)
	# Lê os horários (arquivos pequenos; mantidos locais ao módulo).
	_horarios_ini = horarios_exe.carregar_horarios_ini(GV.dir_saida,"horarios.ini")
	_horarios_txt = horarios_exe.carregar_horarios_txt(GV.dir_saida,"horarios.txt", posicoes_horarios_txt)
	# Prepara a lista de disciplinas.
	_lista_disciplinas = _criar_listadisciplinas()
	# Seleciona primeira condicao e opcao do visualizador (dispara signals).
	$"%Horarios".selecionar_condicao(0)
	$"%Horarios".selecionar_opcao_por_valor("completo")
	# Seleciona o tipo de análise e roda uma única vez após toda a configuração.
	_pronto = true
	$"%SeletorTipoAnalise".selecionar_item(0)
	# Realce inicial dos botoes OnOff conforme a visibilidade dos paineis.
	TogglePaineis.sincronizar_botoes(_mapa_toggles())

	SeletorAvancado.dimensionar([$"%SeletorTipoAnalise", $"%SeletorListaDisciplinas1", \
		$"%SeletorListaDisciplinas2", $"%SeletorListaGrades"], config_interface)

#region Preparação dos dados iniciais
# Prepara a lista de grades disponíveis na pasta de grades. Ignora placeholders com sufixo [code]_0000[/code]
# (usados como recipiente de equivalências para disciplinas sem versão específica de grade).
func _preparar_grades() -> void:
	var chaves_validas: Array[String] = []
	for key in grades_disciplinas_curriculos.keys():
		if str(key).ends_with("_0000"):
			continue
		chaves_validas.append(str(key))
	chaves_validas.sort()
	$"%SeletorListaGrades".popular("grades", chaves_validas)
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
		_grade_ativa = chaves_validas[indice]


# Cria uma array das disciplinas contendo o código e o nome.
func _criar_listadisciplinas() -> Array:
	var obrigatorias_itens: Array[String] = []
	var obrigatorias_retorno: Array[String] = []
	var complementares_itens: Array[String] = []
	var complementares_retorno: Array[String] = []
	var temp_obrigatorias: Array[Array] = []
	var temp_complementares: Array[Array] = []
	for key in grades_disciplinas_curriculos[_grade_ativa].keys():
		var nome: String = grades_disciplinas_curriculos[_grade_ativa][key].get("nome", "disciplina sem nome")
		var nucleo: String = grades_disciplinas_curriculos[_grade_ativa][key].get("nucleo", "")
		var chave_ordenacao: String = _remover_acentos(nome).to_lower()
		if nucleo == "cccg":
			temp_complementares.append([key, nome, chave_ordenacao])
		else:
			temp_obrigatorias.append([key, nome, chave_ordenacao])
	temp_obrigatorias.sort_custom(_comparar_disciplinas_por_nome)
	temp_complementares.sort_custom(_comparar_disciplinas_por_nome)
	for par in temp_obrigatorias:
		obrigatorias_itens.append(par[1])
		obrigatorias_retorno.append(par[0])
	for par in temp_complementares:
		complementares_itens.append(par[1])
		complementares_retorno.append(par[0])
	for s in [$"%SeletorListaDisciplinas1", $"%SeletorListaDisciplinas2"]:
		s.lista_itens = {
			"Obrigatorias*": obrigatorias_itens,
			"Obrigatorias_retorno": obrigatorias_retorno,
			"Complementares*": complementares_itens,
			"Complementares_retorno": complementares_retorno
		}
		s.atualizar_texto_padrao = true
		# Remove asterisco dos separadores (preserva * para comportamento de selecao unica)
		var popup = s.get_node("MenuButton").get_popup()
		for i in popup.get_item_count():
			if popup.is_item_separator(i):
				popup.set_item_text(i, popup.get_item_text(i).trim_suffix("*"))
	var temp_lista: Array[Array] = temp_obrigatorias + temp_complementares
	_lista_disciplinas = temp_lista
	if temp_lista.size() > 0:
		$"%SeletorListaDisciplinas1".selecionar_item(1)
		$"%SeletorListaDisciplinas2".selecionar_item(1)
	return temp_lista
#endregion


func _comparar_disciplinas_por_nome(a: Array, b: Array) -> bool:
	return a[2] < b[2]


func _remover_acentos(s: String) -> String:
	var acentos := {
		"á": "a", "à": "a", "ã": "a", "â": "a", "ä": "a",
		"é": "e", "è": "e", "ê": "e", "ë": "e",
		"í": "i", "ì": "i", "î": "i", "ï": "i",
		"ó": "o", "ò": "o", "õ": "o", "ô": "o", "ö": "o",
		"ú": "u", "ù": "u", "û": "u", "ü": "u",
		"ç": "c",
		"Á": "A", "À": "A", "Ã": "A", "Â": "A", "Ä": "A",
		"É": "E", "È": "E", "Ê": "E", "Ë": "E",
		"Í": "I", "Ì": "I", "Î": "I", "Ï": "I",
		"Ó": "O", "Ò": "O", "Õ": "O", "Ô": "O", "Ö": "O",
		"Ú": "U", "Ù": "U", "Û": "U", "Ü": "U",
		"Ç": "C",
	}
	for a in acentos:
		s = s.replace(a, acentos[a])
	return s


#region Controle principal do tipo de análise: Isolada
# Analisa, para uma disciplina com código [param cod_disc] quais discentes se enquadram 
# nas condições como matriculado_agora, matriculável, etc.
func _disciplina_isolada(cod_disc: String) -> void:
	# Obtem a lista de matrículas de discentes em cada condição na disciplina de código [param cod_disc].
	var discentes_disc_condicoes: Dictionary = _disc_disciplina(cod_disc)
	# Envia o resultado da análise para o terminal.
	_resultados_analise_isolada(discentes_disc_condicoes)
	
	# Matriz combinada de horários dos alunos.
	var horarios_alunos: Array[Array] = []
	# Obtem os horarios de todos discentes em [param condicao] com a disciplina e concatena em uma unica matriz.
	for condicao in discentes_disc_condicoes.keys():
		for a in discentes_disc_condicoes[condicao].size():
			var matricula = discentes_disc_condicoes[condicao][a]
			# Obtém, para a matrícula em questão, as disciplinas que se enquadrem nas [param condicoes].
			var disc_cursaveis: Dictionary
			disc_cursaveis = _condicoes_discentes.get(matricula, {})
			# Obtém os horarios do aluno atual.
			if condicao in $"%Horarios".lista_condicoes_verdadeiras:
				horarios_alunos.append(analise_horarios.determinar_horarios(_horarios_ini, _horarios_txt, \
				disc_cursaveis, _historico.get(matricula), $"%Horarios".lista_condicoes_verdadeiras, \
				lista_cores, _forma_de_apresentacao))
	# Prepara e envia o resultado da análise para a grade.
	var horarios_concatenados: Array[Array] = []
	for a in horarios_alunos.size():
		horarios_concatenados = analise_horarios.concatenar_horarios(horarios_concatenados, horarios_alunos[a])
	# Mesmo sem discentes em condicao alguma, exibe a grade base (dias x horarios) com celulas
	# vazias, em vez de uma grade em branco — determinar_horarios com dados de aluno vazios
	# devolve apenas a estrutura montada por _preparar_horarios.
	if horarios_concatenados.is_empty():
		# historico_matricula precisa da chave "dados" (lista vazia = nenhuma aula a posicionar).
		horarios_concatenados = analise_horarios.determinar_horarios(_horarios_ini, _horarios_txt, {}, {"dados": []}, \
			$"%Horarios".lista_condicoes_verdadeiras, lista_cores, _forma_de_apresentacao)
	$"%Horarios".dados = horarios_concatenados

# Plota os resultados da análise no terminal.
func _resultados_analise_isolada(discentes_disc_condicoes: Dictionary) -> void:
	var nucleo: String = grades_disciplinas_curriculos.get(_grade_ativa, {}).get(_lista_disciplinas[_linha_selecionada1][0],{}).get("nucleo", "sem grupo")
	$"%Terminal".titulo("A disciplina pertence ao grupo: " + nucleo, true)
	$"%Terminal".espaco()
	$"%Terminal".secao("Lista de discentes na disciplina")
	$"%Terminal".linha("Valores em parênteses indicam reprovações por nota e por faltas (somando \
	disciplinas equivalentes de outras grades).")
	for condicao in discentes_disc_condicoes.keys():
		if discentes_disc_condicoes[condicao].size() > 0:
			$"%Terminal".espaco()
			$"%Terminal".secao(condicao.replacen("_", " ").capitalize() +" (" \
			+ str(discentes_disc_condicoes[condicao].size()) +")")
		for a in discentes_disc_condicoes[condicao].size():
			for b in _lista_alunos.size():
				if discentes_disc_condicoes[condicao][a] == _lista_alunos[b][0]:
					var codigo = _lista_disciplinas[_linha_selecionada1][0]
					# Soma as reprovações desta disciplina com as de suas equivalentes de outras
					# grades (aproveitamento de reprovações entre PPCs).
					var reprov: Dictionary = analise_grades.reprovacoes_aproveitadas(
						_analisado_reprov[_lista_alunos[b][0]], codigo, equivalencias, _grade_ativa)
					var reprov_nota: int = reprov["nota"]
					var reprov_falta: int = reprov["falta"]
					var reprovacoes: String = ""
					if reprov_falta != 0 or reprov_nota != 0:
						reprovacoes = "(" + str(reprov_nota) + " RN / " + str(reprov_falta) + " RF)"
					$"%Terminal".item(_lista_alunos[b][1].capitalize() + " " + reprovacoes, 0, lista_cores[condicao])
					break
#endregion

#region Controle principal do tipo de análise: Combinada
func _analise_combinada(cod_disc1: String, cod_disc2: String) -> void:
	var discentes_ambas = analise_historico.comparar_discentes_disciplina(cod_disc1, cod_disc2, _condicoes_discentes, condicoes)
	$"%Terminal".titulo("Discentes em ambas disciplinas", true)
	$"%Terminal".linha("Disciplina 1 → Disciplina 2")
	$"%Terminal".espaco()
	for matr in discentes_ambas.keys():
		$"%Terminal".item(str(matr+" - "+_historico[matr]["nomedoaluno"]).capitalize())
		for a in discentes_ambas[matr].size():
			$"%Terminal".item(discentes_ambas[matr][a][0].capitalize()+" → "+discentes_ambas[matr][a][1].capitalize(), 1)
		$"%Terminal".espaco()
	var placeholder: Array[Array] = []
	placeholder.append(["Grade de horários indisponível para esta análise."])
	$"%Horarios".dados = placeholder
#endregion

#region Funções complementares específicas a este módulo
func _rodar_análise() -> void:
	if _retorno == "isolada":
		_disciplina_isolada(_lista_disciplinas[_linha_selecionada1][0])
	elif _retorno == "comparacao":
		_analise_combinada(_lista_disciplinas[_linha_selecionada1][0], _lista_disciplinas[_linha_selecionada2][0])

# Prepara uma lista de discentes nas [param condicoes] para a disciplina de código [param cod_disc]. 
# Retorna um dicionário contendo uma chave para cada [param condicao] e em cada chave uma matriz de matrículas.
func _disc_disciplina(cod_disc: String) -> Dictionary:
	# Lista de matrículas de discentes em cada condição na disciplina de código [param cod_disc].
	var discentes_disc_condicoes: Dictionary = {}
	# Prepara o dicionário [param discentes_disc_condicoes].
	for a in condicoes.size():
		discentes_disc_condicoes[condicoes[a]] = []
	# Iteração principal, aluno a aluno.
	for a in _lista_alunos.size():
		var matricula = _lista_alunos[a][0]
		# Obtém, para a matrícula em questão, as disciplinas que se enquadram nas [param condicoes].
		var disc_cursaveis: Dictionary
		disc_cursaveis = _condicoes_discentes.get(matricula, {})
		# Busca se o aluno atual tem a disciplina atual em alguma condição.
		for condicao in disc_cursaveis.keys():
			if disc_cursaveis[condicao].has(cod_disc):
				# Adiciona aluno atual a lista.
				discentes_disc_condicoes[condicao].append(matricula)
	return discentes_disc_condicoes
#endregion

#region Sinais
func _obter_indice_disciplina(codigo: String) -> int:
	for a in _lista_disciplinas.size():
		if _lista_disciplinas[a][0] == codigo:
			return a
	return 0

func _on_seletor_lista_grades_opcao_selecionada(retorno: String, _lista_selecionada: Array) -> void:
	_grade_ativa = retorno
	_lista_disciplinas = _criar_listadisciplinas()
	_linha_selecionada1 = 0
	if _pronto:
		_rodar_análise()

func _on_seletor_lista_disciplinas_1_opcao_selecionada(retorno: String, _lista_selecionada: Array) -> void:
	_linha_selecionada1 = _obter_indice_disciplina(retorno)
	_rodar_análise()

func _on_seletor_lista_disciplinas_2_opcao_selecionada(retorno: String, _lista_selecionada: Array) -> void:
	_linha_selecionada2 = _obter_indice_disciplina(retorno)
	_rodar_análise()

func _on_horarios_listacondicoes_alterada() -> void:
	if not _pronto:
		return
	_rodar_análise()

func _on_horarios_listaopcoes_alterada(opcao: String) -> void:
	_forma_de_apresentacao = opcao
	if not _pronto:
		return
	_rodar_análise()

func _on_seletor_tipo_analise_opcao_selecionada(retorno, lista_selecionada) -> void:
	_retorno = retorno
	if _retorno == "isolada":
		$"%LabelDisciplina2".hide()
		$"%SeletorListaDisciplinas2".hide()
	elif _retorno == "comparacao":
		$"%LabelDisciplina2".show()
		$"%SeletorListaDisciplinas2".show()
		
	else:
		print_debug("ERRO: Tipo de análise é inválida: ", _retorno)
		return
	if lista_selecionada.size() == 0:
		print_debug("ERRO: Tamanho da lista selecionada é zero.")
	_rodar_análise()

# Mapa botao OnOff -> painel que ele controla. Base unica para alternar (Shift+clique isola/restaura)
# e para o realce: o botao fica "afundado" (toggle_mode) quando seu painel esta visivel.
func _mapa_toggles() -> Dictionary:
	return {$"%OnOffTerminal": $"%Terminal", $"%OnOffHorarios": $"%Horarios"}

func _toggle(alvo: Control) -> void:
	var mapa := _mapa_toggles()
	TogglePaineis.aplicar(mapa.values(), alvo, Input.is_key_pressed(KEY_SHIFT))
	TogglePaineis.sincronizar_botoes(mapa)

func _on_on_off_terminal_button_up() -> void:
	_toggle($"%Terminal")

func _on_on_off_horarios_button_up() -> void:
	_toggle($"%Horarios")
#endregion
