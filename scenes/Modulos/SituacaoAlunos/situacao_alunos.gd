class_name SituacaoAlunos extends ReferenceRect

## Emitido para que o [code]main.gd[/code] centralize a gravacao de configuracoes do usuario em
## [code]config_usuario.json[/code] (mesmo caminho usado pela JanelaConfiguracoes e pelo
## PlanejamentoHorario). O modulo nunca grava arquivos diretamente.
signal override_config(caminho: Array, valor: Variant)
## Relacionado a ilustração da situação dos discentes em disciplinas. Especialmente interessante 
## na realização dos ajustes de matrícula. [br]
##
## Os principais empregos são: [br]
## - Apresentar as disciplinas que os discentes estão matriculados e que podem se matricular; [br]
## - Apresentar os horários que cada discente tem aula e os horários das disciplinas em que 
## podem se matricular; [br]
## - Apresentar a grade curricular indicando visualmente quais disciplinas foram cursadas e quais
## podem ser cursadas.

# Seções do relatório que só aparecem no terminal com o "Modo Detalhado" marcado: são analíticas
# (leitura do histórico como um todo) e atrapalham quem só quer conferir a situação de matrícula.
const SECOES_DETALHADAS: Array[String] = ["previsao_formatura", "indice_aprovacao"]

# Classes instanciadas.
var file_handling := FileHandling.new()
var analise_historico := AnaliseHistorico.new()
var analise_grades := AnaliseGrades.new()
var analise_horarios := AnaliseHorarios.new()
var horarios_exe := HorariosExe.new()
# Cliente do Modo Ajuste (baixa+parseia a planilha de respostas). É um Node: adicionado à árvore no
# _ready (precisa de um HTTPRequest filho) e liberado junto com o módulo ao sair.
var planilha_ajuste := PlanilhaAjuste.new()

## Recebido pelo main em sua criação e vem do arquivo [code]base_config.json[/code].
var condicoes: Array[String]

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

## Recebido pelo main em sua criação e vem de [code]base_config.json:cursos[/code]. [br]
## Mapeia cada [code]cod_curso[/code] aos seus metadados (nome, grades, etc.). É a fonte para
## o filtro de curso do Topo: um curso (e.g. [code]alec[/code]) abrange várias grades
## (e.g. [code]alec_2010[/code], [code]alec_2023[/code]).
var cursos: Dictionary = {}

## Recebido pelo main em sua criação e vem da pasta de cargas exigidas.
var cargas_exigidas: Dictionary = {}

## Recebido pelo main em sua criação e vem do arquivo base_config.json.
var lista_cores: Dictionary = {}

## Recebido pelo main, contem as cores padrao do terminal.
var cores_terminal: Dictionary = {}

## Recebido pelo main, contem os efeitos de texto do terminal.
var efeitos: Dictionary = {}

## Recebido pelo main, diretorio onde os arquivos exportados sao salvos
## (e.g. [code]<raiz>/exportacoes[/code]). Sem barra final.
var diretorio_exportacao: String = ""

## Configuracoes globais de interface, de [code]base_config.json[/code].
var config_interface: Dictionary = {}

## Modos de exibição das células da grade (lista canônica), de [code]base_config.json:formatos_grade[/code].
var formatos_grade: Dictionary = {}

## Endereço da planilha do Google publicada em CSV, usada pelo Modo Ajuste. Recebido pelo main em sua
## criação (vem de [code]config_usuario.json:modo_ajuste.url_planilha[/code]) e persistido de volta
## pelo main ao confirmar o diálogo.
var url_planilha_ajuste: String = ""

# Modo Ajuste — respostas processadas do formulário de ajuste de matrícula.
# Chave: matrícula em minúsculas. Valor: { "matricula", "valida", "incluir":[cods], "excluir":[cods],
# "incluir_problemas":[entradas], "excluir_problemas":[entradas], "assinatura" }.
var _ajuste_por_matricula: Dictionary = {}

# Assinaturas de preenchimento já alertadas nesta sessão (dedup dos avisos). Como o módulo é recriado
# ao reabrir, este conjunto reseta naturalmente — então sair e voltar realerta os mesmos problemas.
var _assinaturas_alertadas: Dictionary = {}

# Timer da verificação automática da planilha (a cada 5 min enquanto o módulo está aberto).
var _timer_ajuste: Timer

# Ícone verde reaproveitado para marcar, na lista, os alunos que preencheram o formulário.
var _icone_ajuste: Texture2D

# Evita verificações sobrepostas (timer disparando durante uma verificação manual): a segunda é
# silenciosamente ignorada, em vez de poluir o terminal com um erro de "já em andamento".
var _verificando: bool = false

# Contém os dados do historico, de todos os alunos, que importam para esta análise.
var _historico: Dictionary

# Contém as disciplinas que todos alunos se enquadram dentro de [param condicoes].
var _condicoes_discentes: Dictionary

# Contém os dados do arquivo ini, organizados em forma de um dicionário.
var _horarios_ini: Dictionary

# Contém os dados do arquivo txt, organizados em forma de um dicionário.
var _horarios_txt: Array

# É uma array contendo em cada elemento a combinação do nome do aluno e sua matrícula.
# Apenas a porção FILTRADA pelo curso ativo (alimenta o seletor de alunos e a exportação).
var _lista_alunos: Array[Array]

# Lista completa de alunos do hist.csv (todos os cursos), antes do filtro de curso.
# _condicoes_discentes é computado sobre ela, para a troca de curso não exigir recálculo.
var _lista_alunos_todos: Array[Array]

# Mapa matrícula -> cod_curso, computado uma vez para filtrar a lista por curso.
var _curso_por_matricula: Dictionary = {}

# cod_curso atualmente filtrado no Topo. String vazia ("") significa "Todos os cursos".
var _curso_filtro: String = ""

# É uma array contendo as informações de reprovação de todas matrículas.
var _analisado_reprov: Dictionary

# Índice de aprovação por semestre de cada matrícula, pré-computado pelo main sobre o histórico
# completo (o histórico deste módulo é o simplificado, sem as reprovações que formam o denominador).
# Formato: { "<matricula>": [ {ano, semestre, periodo, aprovadas, cursadas, percentual} ] }.
var _indice_aprovacao: Dictionary = {}

# Carga horária exigida para a grade do discente atualmente selecionado (já ajustada por TCC/estágio).
var _ch_exigida: Dictionary = {}

# É uma string no padrão [code]<cod_curso>_<versao>[/code] que define a grade a ser usada
# (e.g. [code]alec_2023[/code]).
var _grade_ativa: String = ""

# Vem de [method AnaliseHorarios._preparar_horarios], e remete a forma de apresentação 
# dos horários na grade de horários.
var _forma_de_apresentacao: String = "somente_codigo"

# Vem do SeletorOpcoes da GradeCurricular e define como as disciplinas são exibidas nas células.
var _forma_apresentacao_grade: String = "nome_reduzido"

# Matrícula do discente atualmente selecionado.
var _matricula_atual: String = ""

# Código da disciplina selecionada na GradeCurricular (para destacar pré-requisitos).
var _codigo_selecionado: String = ""

# Códigos das disciplinas que devem ser destacadas visualmente (pré-requisitos da selecionada).
var _codigos_destacar: Array[String] = []

# Código da disciplina selecionada com botão direito (para destacar disciplinas bloqueadas).
var _codigo_selecionado_direito: String = ""

# Códigos das disciplinas bloqueadas pela selecionada (botão direito), com cor por profundidade.
var _codigos_destacar_secundario: Dictionary = {}

# Código da disciplina realçada na GradeHorarios (toggle ao clicar na célula).
var _codigo_realcado: String = ""

## Impede que os signals de inicialização disparem [_rodar_análise] múltiplas vezes.
var _pronto := false

func _ready() -> void:
	$"%Horarios".formatos_grade = formatos_grade
	$"%Horarios".condicoes = condicoes
	# Consome o cache de dados discentes pre-computado pelo main (a leitura de hist.csv é
	# centralizada em main._garantir_dados_discentes). Cache vazio = hist.csv ausente ou cena
	# aberta fora do fluxo principal: avisa e segue com dados vazios.
	if not GV.dados_discentes.is_empty():
		_historico = GV.dados_discentes["historico"]
		_analisado_reprov = GV.dados_discentes["reprovacoes"]
		_indice_aprovacao = GV.dados_discentes.get("indice_aprovacao", {})
		_lista_alunos_todos = GV.dados_discentes["lista_alunos"]
		_condicoes_discentes = GV.dados_discentes["condicoes_discentes"]
		# Exibe avisos de validação do cabeçalho, se houver.
		for aviso in GV.dados_discentes.get("avisos_leitura", []):
			$"%Terminal".text_edit(aviso, cores_terminal["aviso"], true, true)
	else:
		$"%Terminal".text_edit("Dados discentes indisponíveis (hist.csv ausente ou módulo " + \
			"aberto fora do fluxo principal).", cores_terminal["aviso"], true, true)
	# Lê os horários (arquivos pequenos; mantidos locais ao módulo).
	_horarios_ini = horarios_exe.carregar_horarios_ini(GV.dir_saida,"horarios.ini")
	_horarios_txt = horarios_exe.carregar_horarios_txt(GV.dir_saida,"horarios.txt", posicoes_horarios_txt)
	# Mapeia cada matrícula ao seu cod_curso (uma única vez) para alimentar o filtro de curso.
	_mapear_cursos()

	SeletorAvancado.dimensionar([$"%SeletorListaAlunos", $"%SeletorCurso"], config_interface)
	$"%SeletorListaAlunos".atualizar_texto_padrao = true
	$"%SeletorCurso".atualizar_texto_padrao = true
	# Monta o seletor de curso e pré-seleciona o curso do ppc_principal. Ao selecionar, o handler
	# chama _montar_lista_alunos (repovoa o seletor de alunos). _pronto ainda é false: não roda análise.
	_montar_seletor_curso()

	# Seleciona primeira condicao e opcao do visualizador (dispara signals).
	$"%Horarios".selecionar_condicao(0)
	$"%Horarios".selecionar_condicao(1)
	$"%Horarios".selecionar_opcao_por_valor("nome_completo")
	# Executa a análise uma única vez após toda a configuração inicial.
	_pronto = true
	_rodar_análise()
	var btn_exportar := $"Topo/HBoxContainer/Exportar"
	if not btn_exportar.pressed.is_connected(_on_exportar_button_up):
		btn_exportar.pressed.connect(_on_exportar_button_up)
	$"%GradeCurricular".celula_selecionada.connect(_on_grade_celula_selecionada)
	$"%GradeCurricular".celula_selecionada_direita.connect(_on_grade_celula_selecionada_direita)
	var grade_horarios = $"%Horarios".get_node("GradeHorarios")
	if grade_horarios:
		grade_horarios.celula_clicada.connect(_on_horarios_celula_clicada)
	# Realce inicial dos botoes OnOff conforme a visibilidade dos paineis.
	TogglePaineis.sincronizar_botoes(_mapa_toggles())

	# Modo Detalhado: alterna as seções analíticas do relatório (ver SECOES_DETALHADAS). Alternar só
	# reimprime o terminal (ver _reimprimir_relatorio) — grade, horários e realces ficam como estão.
	$"%ModoDetalhado".toggled.connect(_on_modo_detalhado_alternado)
	DicaFlutuante.vincular($"%ModoDetalhado", "Mostra no terminal as seções analíticas do relatório " \
		+ "(previsão de formatura e índice de aprovação).\nDesmarcado, o relatório fica restrito à " \
		+ "situação de matrícula do discente.")

	# Modo Ajuste: prepara o cliente da planilha, o ícone de destaque e os gestos do botão. NÃO inicia
	# sozinho ao abrir o módulo (mesmo com URL já configurada) — só sob demanda do usuário, pois na
	# maior parte do tempo não se está em ajuste.
	add_child(planilha_ajuste)
	_icone_ajuste = _criar_icone_ajuste()
	var btn_ajuste := $"Topo/HBoxContainer/ModoAjuste"
	btn_ajuste.gui_input.connect(_on_modo_ajuste_gui_input)
	DicaFlutuante.vincular(btn_ajuste, "[b]Esquerdo[/b]: configurar o endereço da planilha (CSV publicado).\n" \
		+ "[b]Direito[/b]: iniciar/atualizar o ajuste agora.\n" \
		+ "Cor do botão — vermelho: falha · laranja: obtendo · verde: obtido.")


# Roda a análise para a seleção atual.
func _rodar_análise() -> void:
	_codigo_selecionado = ""
	_codigos_destacar = []
	_codigo_selecionado_direito = ""
	_codigos_destacar_secundario = {}
	_limpar_realces_horarios()
	_grade_ativa = analise_historico.detectar_versao_grade(_matricula_atual, _historico)
	if not _validar_grade_ativa():
		return
	# Carga exigida é opcional: se a grade não tiver arquivo em cargaexigida/, a análise segue
	# (grade, horários e condições não dependem dela) — apenas o percentual de conclusão fica
	# indisponível. Aviso discreto no terminal para a coordenação saber como habilitá-lo.
	if cargas_exigidas.has(_grade_ativa):
		_ch_exigida = cargas_exigidas[_grade_ativa]
		_ch_exigida = analise_grades.ajustarch_tccestagio(grades_disciplinas_curriculos[_grade_ativa], _ch_exigida)
	else:
		_ch_exigida = {}
		$"%Terminal".item("Carga horária exigida não cadastrada para a grade " + _grade_ativa \
			+ " (crie arquivos/cargaexigida/" + _grade_ativa + ".json). Percentual de conclusão indisponível.", \
			0, cores_terminal["aviso"])
	# Modo Ajuste: a listagem incluir/excluir é impressa dentro de _imprimir_analise, logo antes da
	# seção "Matriculado Agora" (ver _imprimir_analise).
	_analisar_matricula(_matricula_atual)

# Verifica se [_grade_ativa] e chave valida no dicionario de grades (requisito real da analise).
# A carga exigida NAO e verificada aqui: e opcional (ver [method _rodar_análise]).
# Retorna true se valido; caso contrario loga erro e retorna false.
func _validar_grade_ativa() -> bool:
	if not grades_disciplinas_curriculos.has(_grade_ativa):
		print_debug("ERRO: Grade '" + _grade_ativa + "' nao encontrada em grades_disciplinas_curriculos.")
		return false
	return true

# Faz a análise da integralização e horários para uma [param matricula]. [br]
# Formato de [param matricula] deve ser apenas a sequencia numérica da matrícula em formato String. [br]
# Quando [param impressao] é verdadeiro são impressos os dados no terminal visual. [br]
# Quando [param revisao] é verdadeiro são verificados e apresentados alguns problemas na matrícula. [br]
func _analisar_matricula(matricula: String, impressao: bool = true, revisao: bool = true) -> void:
	# Determina quantas horas foram cursadas e o percentual de curso ignorando tccs e estágio.
	var ch_data: Dictionary = analise_historico.ch_vencida(matricula, \
		grades_disciplinas_curriculos[_grade_ativa], _historico)
	var ch_vencida: Dictionary = ch_data["ch"]
	# Percentual só é calculado quando há carga exigida cadastrada (evita divisão por zero).
	var percentual_tcc: float = analise_historico.percentagem_curso(_ch_exigida, ch_vencida) \
		if not _ch_exigida.is_empty() else 0.0
	# Exibe divergencias entre CH do historico e da grade
	if ch_data.has("divergencias"):
		for div in ch_data["divergencias"]:
			$"%Terminal".item(div["codigo"] + ": hist.csv=" + str(div["ch_historico"]) \
			+ "h, grade=" + str(div["ch_grade"]) + "h", 0, cores_terminal["aviso"])
	# Obtem a lista de disciplinas que o aluno cursou mas não estão descritas na grade curricular escolhida.
	var disc_semgrade: Array[Array]
	if revisao:
		disc_semgrade = analise_historico.revisar_historico(_historico,grades_disciplinas_curriculos, matricula, false)
	# Obtem, para a matrícula em questão, as disciplinas que se enquadrem nas [param condicoes].
	var disc_cursaveis: Dictionary = _condicoes_discentes.get(matricula, {})
	# Determina o numero de créditos matriculado nas condições "matriculado_agora" e "matriculado_agora_aproveitamento".
	var creditos_disciplinas: Dictionary
	creditos_disciplinas = analise_historico.creditos_disciplinas(matricula, _historico, disc_cursaveis, grades_disciplinas_curriculos)
	# Envia para a grade de horarios os horarios a listagem de disciplinas. Modo Ajuste: se o discente
	# preencheu o formulario, forca a exibicao das disciplinas pedidas (fundo verde p/ incluir, vermelho
	# p/ excluir) via condicoes sinteticas, independente dos toggles e da elegibilidade.
	var registro_aj: Dictionary = _ajuste_por_matricula.get(matricula.to_lower(), {})
	var cods_incluir: Array = registro_aj.get("incluir", [])
	var cods_excluir: Array = registro_aj.get("excluir", [])
	var disc_cursaveis_grade: Dictionary = disc_cursaveis
	var condicoes_grade: Array = $"%Horarios".lista_condicoes_verdadeiras
	var cores_grade: Dictionary = lista_cores
	if not cods_incluir.is_empty() or not cods_excluir.is_empty():
		disc_cursaveis_grade = disc_cursaveis.duplicate(true)
		# Remove os codigos do ajuste das condicoes reais para nao renderizar em duplicidade.
		for cond in disc_cursaveis_grade.keys():
			var filtrada: Array = []
			for c in disc_cursaveis_grade[cond]:
				var cl: String = str(c).to_lower()
				if not cl in cods_incluir and not cl in cods_excluir:
					filtrada.append(c)
			disc_cursaveis_grade[cond] = filtrada
		disc_cursaveis_grade["ajuste_incluir"] = cods_incluir.duplicate()
		disc_cursaveis_grade["ajuste_excluir"] = cods_excluir.duplicate()
		condicoes_grade = []
		condicoes_grade.append_array($"%Horarios".lista_condicoes_verdadeiras)
		condicoes_grade.append("ajuste_incluir")
		condicoes_grade.append("ajuste_excluir")
		# Token de cor desconhecido cai na cor de texto (sem [shake]); o fundo verde/vermelho aplicado
		# em analise_horarios (FUNDO_AJUSTE_INCLUIR/EXCLUIR) faz a distincao incluir vs excluir.
		cores_grade = lista_cores.duplicate()
		cores_grade["ajuste_incluir"] = "ajuste_incluir"
		cores_grade["ajuste_excluir"] = "ajuste_excluir"
	$"%Horarios".dados = analise_horarios.determinar_horarios(_horarios_ini, _horarios_txt, disc_cursaveis_grade, \
	_historico.get(matricula), condicoes_grade, cores_grade, _forma_de_apresentacao, cods_incluir, cods_excluir)
	# Monta e envia a grade curricular do discente, colorindo conforme a situacao. As disciplinas
	# ainda distantes (nenhuma condicao e nao concluidas) recebem hachura leve, separando "falta so
	# uma aprovacao" de "falta uma cadeia de aprovacoes".
	var cursadas: Array[String] = analise_historico.disciplinas_concluidas(matricula, _historico)
	var vazio_destacar: Array[String] = []
	$"%GradeCurricular".dados = analise_grades.montar_grade_curricular(grades_disciplinas_curriculos[_grade_ativa], \
	disc_cursaveis, _cursadas_com_equivalencia(cursadas), lista_cores, _forma_apresentacao_grade, vazio_destacar, \
	{}, {}, [], [], Color.TRANSPARENT, _codigos_distantes(matricula, disc_cursaveis, cursadas))
	# Nova análise zera a seleção de pré-requisitos e remove as linhas de conexão.
	_codigo_selecionado = ""
	_codigo_selecionado_direito = ""
	_codigos_destacar = []
	_codigos_destacar_secundario = {}
	$"%GradeCurricular".conexoes = []
	# Imprime o resultado da análise
	if impressao:
		_imprimir_analise(matricula, disc_cursaveis, disc_semgrade, ch_vencida, \
		creditos_disciplinas, _analisado_reprov.get(matricula, {}))

# Reimprime o relatório do discente atual recalculando só o que a impressão consome. Não passa por
# [method _analisar_matricula] de propósito: a análise completa remonta a grade curricular e a de
# horários, zerando a seleção de pré-requisitos e os realces que o usuário acabou de montar.
func _reimprimir_relatorio() -> void:
	if _matricula_atual.is_empty() or not grades_disciplinas_curriculos.has(_grade_ativa):
		return
	var ch_data: Dictionary = analise_historico.ch_vencida(_matricula_atual, \
		grades_disciplinas_curriculos[_grade_ativa], _historico)
	var disc_semgrade: Array[Array] = analise_historico.revisar_historico(_historico, \
		grades_disciplinas_curriculos, _matricula_atual, false)
	var disc_cursaveis: Dictionary = _condicoes_discentes.get(_matricula_atual, {})
	var creditos_disciplinas: Dictionary = analise_historico.creditos_disciplinas(_matricula_atual, \
		_historico, disc_cursaveis, grades_disciplinas_curriculos)
	_imprimir_analise(_matricula_atual, disc_cursaveis, disc_semgrade, ch_data["ch"], \
		creditos_disciplinas, _analisado_reprov.get(_matricula_atual, {}))

# Organiza os dados da análise em seções estruturadas. Retorna um Array de Dictionary.
# Cada dicionário possui a chave "tipo" indicando o tipo de seção (versao, ch, sem_grade, condicao, etc).
# Esta é a única fonte de verdade dos dados exibidos. As funções de saída consomem este Array.
func _formatar_analise(matricula: String, disc_cursaveis: Dictionary, disc_semgrade: Array, ch_vencida: Dictionary, \
creditos_disciplinas: Dictionary, analisado_reprov: Dictionary) -> Array[Dictionary]:
	var secoes: Array[Dictionary] = []
	var sem_grade: bool = disc_semgrade.size() > 0

	# Versão do currículo
	secoes.append({"tipo": "versao", "texto": _grade_ativa, "sem_grade": sem_grade})

	# Matrícula
	secoes.append({"tipo": "matricula", "texto": matricula})

	# Carga horária vencida
	var ch_itens: Array[Array] = []
	var ch_total: int = 0
	for key in ch_vencida.keys():
		ch_itens.append([key.capitalize(), str(ch_vencida.get(key, 0))])
		ch_total += ch_vencida.get(key, 0)
	var ch_secao: Dictionary = {"tipo": "ch", "itens": ch_itens, "total": ch_total}
	# TODO Mover esta regra específica (exigência de 2550h para TCC) para [code]base_config.json:cursos[/code].
	if _grade_ativa.ends_with("_2010"):
		ch_secao["para_tcc"] = {"horas": "2550", "total_aluno": ch_total}
	secoes.append(ch_secao)

	# Previsão de formatura: maior cadeia de pré-requisitos obrigatórios ainda pendente (caminho
	# crítico). Ancora o período no ano/semestre mais recente das disciplinas em curso (situação
	# "matr"); sem matrícula em aberto, recai na data do sistema.
	var grade_atual: Dictionary = grades_disciplinas_curriculos.get(_grade_ativa, {})
	var cursadas_prev: Array[String] = analise_historico.disciplinas_concluidas(matricula, _historico)
	# Disciplinas em curso, já nos códigos da grade atual: inclui as matriculadas diretamente
	# (matriculado_agora) e as cursadas agora sob código equivalente de outra grade
	# (matriculado_agora_aproveitamento). Usar disc_cursaveis (e não o histórico bruto) garante que
	# uma disciplina retomada por aproveitamento — ex.: al0388 (grade 2023) cobrindo al0107 (grade
	# 2010) — conte como em curso (offset 0), e não como pendente, evitando inflar a cadeia.
	var em_curso: Array[String] = []
	for cod in disc_cursaveis.get("matriculado_agora", []):
		var cl: String = str(cod).to_lower()
		if not cl in em_curso:
			em_curso.append(cl)
	for cod in disc_cursaveis.get("matriculado_agora_aproveitamento", []):
		var cl: String = str(cod).to_lower()
		if not cl in em_curso:
			em_curso.append(cl)
	# Âncora do período: ano/semestre mais recente entre as matrículas em aberto do histórico bruto
	# (independe do filtro de grade). Sem matrícula em aberto, recai na data do sistema.
	var ano_ancora: int = Time.get_date_dict_from_system()["year"]
	var sem_ancora: int = int(GeneralFunctions.semestre_atual())
	var tem_matricula: bool = false
	for dado in _historico.get(matricula, {}).get("dados", []):
		if not str(dado.get("situacao", "")).begins_with("matr"):
			continue
		var ano_dado: int = int(dado.get("ano", ""))
		var sem_dado: int = int(dado.get("semestre", ""))
		if ano_dado > 0 and sem_dado > 0 and (not tem_matricula \
		or ano_dado > ano_ancora or (ano_dado == ano_ancora and sem_dado > sem_ancora)):
			ano_ancora = ano_dado
			sem_ancora = sem_dado
			tem_matricula = true
	var critico: Dictionary = analise_grades.caminho_critico_formatura(grade_atual, cursadas_prev, em_curso)
	var offset_form: int = critico["offset"]
	var periodo: Dictionary = GeneralFunctions.avancar_semestre(ano_ancora, sem_ancora, max(offset_form, 0))
	secoes.append({
		"tipo": "previsao_formatura",
		"periodo": "%d/%d" % [periodo["ano"], periodo["semestre"]],
		"semestres": offset_form + 1,
		"cadeia": critico["cadeia"],
		"integralizado": offset_form < 0,
	})

	# Índice de aprovação: percentual de aprovações por semestre cursado (só períodos regulares com
	# resultado lançado; ver [method AnaliseReprovacoes.indice_aprovacao]).
	secoes.append({
		"tipo": "indice_aprovacao",
		"itens": _indice_aprovacao.get(matricula, []),
	})

	# Disciplinas sem grade - separadas por matriculadas (situacao "matr*") e nao matriculadas
	var sem_grade_matriculadas: Array[Array] = []
	var sem_grade_nao_matriculadas: Array[Array] = []
	var dados_aluno: Array = _historico.get(matricula, {}).get("dados", [])
	for item in disc_semgrade:
		var codigo_lower: String = item[0].to_lower()
		var matriculada: bool = false
		for entry in dados_aluno:
			if entry.get("codigocurriculo", "").to_lower() == codigo_lower \
			and entry.get("situacao", "").begins_with("matr"):
				matriculada = true
				break
		if matriculada:
			sem_grade_matriculadas.append(item)
		else:
			sem_grade_nao_matriculadas.append(item)
	if sem_grade_matriculadas.size() > 0:
		secoes.append({"tipo": "sem_grade_matriculadas", "itens": sem_grade_matriculadas})
	if sem_grade_nao_matriculadas.size() > 0:
		secoes.append({"tipo": "sem_grade_nao_matriculadas", "itens": sem_grade_nao_matriculadas})

	# Matrículas reais em OUTRA grade que não entram na grade do aluno e não são aproveitamento
	# completo (ex.: disciplina dividida cursada só pela metade — al0391 sem al0399). São matrículas
	# de fato (ocupam horário), mas ficariam invisíveis: não estão na grade (não viram
	# matriculado_agora), não estão "sem grade" (existem em outra grade) e o alvo delas não entra no
	# matriculado_agora_aproveitamento. Ganham seção própria para a análise de horários.
	var matriculada_outra_grade: Array[Array] = []
	var maa_alvos: Dictionary = {}
	for t in disc_cursaveis.get("matriculado_agora_aproveitamento", []):
		maa_alvos[str(t).to_lower()] = true
	var vistos_outra: Dictionary = {}
	for entry in dados_aluno:
		if not str(entry.get("situacao", "")).begins_with("matr"):
			continue
		var cod: String = str(entry.get("codigocurriculo", ""))
		var cl: String = cod.to_lower()
		if vistos_outra.has(cl):
			continue
		# Pula se está na grade do aluno (já aparece como matriculado_agora).
		if grades_disciplinas_curriculos.get(_grade_ativa, {}).has(cl):
			continue
		# Pula se não está em nenhuma OUTRA grade (essas são "sem grade", já listadas acima).
		var em_outra_grade: bool = false
		for g in grades_disciplinas_curriculos.keys():
			if g != _grade_ativa and grades_disciplinas_curriculos[g].has(cl):
				em_outra_grade = true
				break
		if not em_outra_grade:
			continue
		# Pula se é aproveitamento completo (algum alvo dela está no matriculado_agora_aproveitamento).
		var completo: bool = false
		for alvo in analise_grades.para_o_codigo_qual_a_equivalencia(cod, equivalencias, _grade_ativa):
			if maa_alvos.has(str(alvo).to_lower()):
				completo = true
				break
		if completo:
			continue
		vistos_outra[cl] = true
		var nome_outra: String = str(analise_grades.info_grade(grades_disciplinas_curriculos, cod, "nome"))
		matriculada_outra_grade.append([cod, nome_outra])
	if matriculada_outra_grade.size() > 0:
		secoes.append({"tipo": "matriculada_outra_grade", "itens": matriculada_outra_grade})

	# Título que agrupa o aviso de reprovações e todas as seções de condição que vêm a seguir (elas são
	# subseções deste bloco, e não da previsão de formatura).
	secoes.append({"tipo": "previsao_matriculas"})

	# Aviso sobre reprovações
	secoes.append({"tipo": "aviso_reprovacoes"})

	# Disciplinas nas condições
	var limiar_presenca: float = GV.configuracao_base.get("choque", {}).get("limiar_presenca", 0.75)
	# Constroi slots das disciplinas ja matriculadas (para calculo de choque de horario).
	# Usa os codigos REAIS de matricula do historico (situacao "matr"), que casam com a oferta
	# (_horarios_txt). Os codigos-alvo da grade em matriculado_agora_aproveitamento NAO batem com a
	# oferta (ela usa o codigo sob o qual o aluno se matriculou, de outra grade). Cobre tambem as
	# matriculas irregulares, que no historico tambem tem situacao "matricula".
	var codigos_matriculados: Array[String] = []
	for dado in _historico.get(matricula, {}).get("dados", []):
		if str(dado.get("situacao", "")).begins_with("matr"):
			codigos_matriculados.append(str(dado.get("codigocurriculo", "")).to_lower())
	var slots_matriculadas: Array[Dictionary] = []
	for entry in _horarios_txt:
		var cod_entry: String = horarios_exe.extrair_cod_horarios_txt(entry.get("disciplina", "")).to_lower()
		if cod_entry in codigos_matriculados:
			slots_matriculadas.append(entry)
	var condicoes_choque: Array[String] = ["matriculavel", "matriculavel_aproveitamento", \
		"corequisito_matriculavel", "corequisito_matriculavel_aproveitamento"]
	var todas_cccgs: Dictionary = {}
	for condicao in disc_cursaveis.keys():
		if disc_cursaveis[condicao].size() > 0:
			var itens: Array[Dictionary] = []
			var lista_cccg: Array[Array] = []
			for a in disc_cursaveis[condicao].size():
				var codigo: String = disc_cursaveis[condicao][a]
				var nome_disc: String = str(analise_grades.info_grade(grades_disciplinas_curriculos, codigo, "nome"))
				var creditos: String = str(creditos_disciplinas.get(codigo, 0))
				var nucleo: String = str(analise_grades.info_grade(grades_disciplinas_curriculos, codigo, "nucleo"))
				# Soma as reprovações desta disciplina com as de suas equivalentes de outras grades
				# (aproveitamento): aluno que reprovou na versão antiga e migrou de PPC carrega o total.
				var reprov: Dictionary = analise_grades.reprovacoes_aproveitadas(
					analisado_reprov, codigo, equivalencias, _grade_ativa)
				var reprov_nota: int = reprov["nota"]
				var reprov_falta: int = reprov["falta"]
				var reprovacoes: String = ""
				if reprov_falta != 0 or reprov_nota != 0:
					reprovacoes = "(" + str(reprov_nota) + " RN / " + str(reprov_falta) + " RF)"
				# Calcula choque de horario para disciplinas matriculaveis
				var info_choque: Dictionary = {}
				if condicao in condicoes_choque and slots_matriculadas.size() > 0:
					info_choque = analise_horarios.calcular_choque_disciplina(
						codigo, _horarios_txt, slots_matriculadas
					)
					if info_choque["slots_total"] > 0:
						var exclusivos: int = info_choque["exclusivos"]
						var total: int = info_choque["slots_total"]
						var conflito: int = info_choque["slots_conflito"]
						var necessario: int = max(0, int(ceil(limiar_presenca * total)) - exclusivos)
						info_choque["necessario"] = necessario
						# Presenca maxima possivel considerando alocacao otima dos slots
						if necessario <= conflito:
							info_choque["max_presenca"] = int(limiar_presenca * 100.0)
						else:
							info_choque["max_presenca"] = int(float(exclusivos + conflito) / float(total) * 100.0)
						# Resolve codigos conflitantes para nomes
						var nomes_conflito: Dictionary = {}
						for cod_conf in info_choque["conflitos"].keys():
							var nome = analise_grades.info_grade(grades_disciplinas_curriculos, cod_conf, "nome")
							if nome.begins_with("Codigo") or nome.is_empty():
								nome = cod_conf
							nomes_conflito[cod_conf] = nome
						info_choque["nomes_conflito"] = nomes_conflito
				if nucleo == "cccg":
					lista_cccg.append([codigo, nome_disc, creditos])
				else:
					itens.append({"codigo": codigo, "nome_disc": nome_disc, \
						"creditos": creditos, "reprovacoes": reprovacoes, "nucleo": nucleo, \
						"info_choque": info_choque})
			if lista_cccg.size() > 0:
				todas_cccgs[condicao] = lista_cccg
			secoes.append({"tipo": "condicao", "nome": condicao, "itens": itens})

	# CCCGs ao final
	for condicao in todas_cccgs.keys():
		var itens_cccg: Array[Dictionary] = []
		for a in todas_cccgs[condicao].size():
			itens_cccg.append({"codigo": todas_cccgs[condicao][a][0], \
				"nome_disc": todas_cccgs[condicao][a][1], "creditos": todas_cccgs[condicao][a][2]})
		secoes.append({"tipo": "condicao_cccg", "nome": condicao, "itens": itens_cccg})

	return secoes


# Fração da carga horária do semestre que, se reprovada, impede a solicitação de estágio. Usada só
# nos rodapés (o cálculo em si vem pronto na chave "apto_estagio", computada pelo main).
func _limite_reprovacao_estagio() -> float:
	return float(GV.configuracao_base.get("estagio", {}).get("limite_reprovacao", 0.6))

# Organiza e imprime os dados no terminal.
func _imprimir_analise(matricula: String, disc_cursaveis: Dictionary, disc_semgrade: Array, ch_vencida: Dictionary, \
creditos_disciplinas: Dictionary, analisado_reprov: Dictionary) -> void:
	var secoes: Array[Dictionary] = _formatar_analise(matricula, disc_cursaveis, disc_semgrade, \
		ch_vencida, creditos_disciplinas, analisado_reprov)
	var primeiro: bool = true
	# Modo Ajuste: imprime incluir/excluir uma única vez, logo antes da primeira seção
	# "matriculado_agora*". Fallback após o laço cobre discentes sem essa seção (no-op se não houver
	# ajuste — _imprimir_ajuste retorna cedo).
	var ajuste_impresso: bool = false
	var detalhado: bool = $"%ModoDetalhado".button_pressed
	for secao in secoes:
		# Modo Detalhado desmarcado: seções analíticas ficam fora do terminal (a exportação, por ser um
		# relatório completo, continua trazendo todas).
		if not detalhado and secao["tipo"] in SECOES_DETALHADAS:
			continue
		if not ajuste_impresso and secao["tipo"] == "condicao" \
		and str(secao["nome"]).begins_with("matriculado_agora"):
			_imprimir_ajuste(matricula)
			ajuste_impresso = true
		match secao["tipo"]:
			"versao":
				var texto: String = "Versão do currículo: " + secao["texto"]
				if secao["sem_grade"]:
					texto += " (disciplinas sem grade detectadas)"
				if primeiro:
					$"%Terminal".titulo(texto, true)
					primeiro = false
				else:
					$"%Terminal".secao(texto)
			"matricula":
				$"%Terminal".linha("Matrícula: " + secao["texto"], cores_terminal["alerta"])
				$"%Terminal".espaco()
			"ch":
				$"%Terminal".secao("Carga horária vencida")
				if secao["itens"].size() == 0:
					$"%Terminal".item("Discente não concluiu nenhuma disciplina!", 0, cores_terminal["alerta"])
				for item in secao["itens"]:
					$"%Terminal".item(item[0] + ": " + item[1])
				if secao.has("para_tcc"):
					$"%Terminal".linha("Para TCC são necessárias " + secao["para_tcc"]["horas"] + \
						" horas. O discente tem " + str(secao["para_tcc"]["total_aluno"]) + ".")
				$"%Terminal".espaco()
			"previsao_formatura":
				$"%Terminal".secao("Previsão de formatura")
				if secao["integralizado"]:
					$"%Terminal".item("Todas as disciplinas obrigatórias concluídas ou em curso.")
				else:
					$"%Terminal".linha(secao["periodo"] + " (mínimo de " + str(secao["semestres"]) \
						+ " semestres, contando o atual)", cores_terminal["alerta"])
					var nomes_cadeia: Array[String] = []
					for disc in secao["cadeia"]:
						nomes_cadeia.append(disc["nome"])
					if nomes_cadeia.size() > 0:
						$"%Terminal".item("Caminho crítico: " + " → ".join(nomes_cadeia))
				$"%Terminal".espaco()
			"indice_aprovacao":
				$"%Terminal".secao("Índice de aprovação")
				if secao["itens"].size() == 0:
					$"%Terminal".item("Nenhum semestre com resultado lançado.")
				for periodo_indice in secao["itens"]:
					# Verde/vermelho: critério de estágio do semestre (ver AnaliseReprovacoes.indice_aprovacao).
					var token_indice: String = cores_terminal["sucesso"] if periodo_indice["apto_estagio"] \
						else cores_terminal["erro"]
					$"%Terminal".item(periodo_indice["periodo"] + ": " \
						+ str(int(round(periodo_indice["percentual"]))) + "% (" \
						+ str(periodo_indice["aprovadas"]) + " de " \
						+ str(periodo_indice["cursadas"]) + ") | " \
						+ str(int(round(periodo_indice["percentual_ch_aprovada"]))) + "% da CH (" \
						+ str(int(round(periodo_indice["ch_aprovada"]))) + " de " \
						+ str(int(round(periodo_indice["ch_cursada"]))) + "h)", 0, token_indice)
				$"%Terminal".linha("Os percentuais consideram as disciplinas com resultado lançado (aprovação ou reprovação); matrículas em aberto, dispensas e trancamentos ficam de fora.")
				$"%Terminal".linha("O percentual de CH e a cor seguem o critério de estágio: verde enquanto o discente aprova ao menos " \
					+ str(int(round((1.0 - _limite_reprovacao_estagio()) * 100.0))) + "% da carga horária matriculada no semestre (o regulamento exige não reprovar, por nota e por frequência, em mais de " \
					+ str(int(round(_limite_reprovacao_estagio() * 100.0))) + "% dela).")
				$"%Terminal".espaco()
			"sem_grade_matriculadas":
				$"%Terminal".secao("Disciplinas sem grade (matriculadas atualmente)")
				for item in secao["itens"]:
					$"%Terminal".item(item[0] + " " + item[1], 0, cores_terminal["alerta"])
				$"%Terminal".espaco()
			"sem_grade_nao_matriculadas":
				$"%Terminal".secao("Disciplinas sem grade (nao matriculadas)")
				for item in secao["itens"]:
					$"%Terminal".item(item[0] + " " + item[1], 0, cores_terminal["alerta"])
				$"%Terminal".espaco()
			"matriculada_outra_grade":
				$"%Terminal".secao("Matriculada em outra grade (aproveitamento incompleto)")
				for item in secao["itens"]:
					$"%Terminal".item(item[0] + ": " + item[1], 0, cores_terminal["alerta"])
				$"%Terminal".espaco()
			"previsao_matriculas":
				$"%Terminal".secao("Previsão de matrículas")
			"aviso_reprovacoes":
				$"%Terminal".linha("Valores em parênteses indicam reprovações por nota e por faltas (somando disciplinas equivalentes de outras grades).")
				$"%Terminal".espaco()
			"condicao":
				$"%Terminal".subsecao(secao["nome"].replacen("_", " ").capitalize())
				for disc in secao["itens"]:
					var linha: String = disc["codigo"] + ": " + disc["nome_disc"] + " (" + \
						disc["creditos"] + " Créditos) " + disc["reprovacoes"]
					# Adiciona info de choque de horario
					if disc.has("info_choque") and not disc["info_choque"].is_empty() \
					and disc["info_choque"]["slots_conflito"] > 0:
						var necessario: int = disc["info_choque"].get("necessario", 0)
						if necessario <= 0:
							continue
						var max_pct: int = disc["info_choque"].get("max_presenca", 0)
						var nomes: Dictionary = disc["info_choque"].get("nomes_conflito", {})
						var nomes_lista: Array[String] = []
						for _cod in nomes:
							nomes_lista.append(nomes[_cod])
						var choque_str: String = " | Conflito com " \
							+ ", ".join(nomes_lista) + " (" \
							+ str(max_pct) + "% presenca maxima)"
						linha += choque_str
					$"%Terminal".item(linha, 0, lista_cores[secao["nome"]])
				$"%Terminal".espaco()
			"condicao_cccg":
				$"%Terminal".subsecao(secao["nome"].replacen("_", " ").capitalize() + " (CCCGs)")
				for disc in secao["itens"]:
					$"%Terminal".item(disc["codigo"] + ": " + disc["nome_disc"] + " (" + \
						disc["creditos"] + " Créditos)", 0, lista_cores[secao["nome"]])
				$"%Terminal".espaco()
	# Sem seção "matriculado_agora" (discente não matriculado em nada): imprime o ajuste ao final.
	if not ajuste_impresso:
		_imprimir_ajuste(matricula)


# Formata os dados de um aluno em linhas markdown.
func _formatar_analise_markdown(matricula: String, nome: String, disc_cursaveis: Dictionary, disc_semgrade: Array, \
ch_vencida: Dictionary, creditos_disciplinas: Dictionary, analisado_reprov: Dictionary) -> Array[String]:
	var secoes: Array[Dictionary] = _formatar_analise(matricula, disc_cursaveis, disc_semgrade, \
		ch_vencida, creditos_disciplinas, analisado_reprov)
	var md: Array[String] = []

	md.append("## " + nome + " (Matricula: " + matricula + ")")
	md.append("")

	for secao in secoes:
		match secao["tipo"]:
			"versao":
				var extra: String = ""
				if secao["sem_grade"]:
					extra = " *(disciplinas sem grade detectadas)*"
				md.append("**Versao do curriculo:** " + secao["texto"] + extra)
			"matricula":
				pass  # Já incluída no cabeçalho
			"ch":
				md.append("### Carga horaria vencida")
				if secao["itens"].size() == 0:
					md.append("- *Discente nao concluiu nenhuma disciplina!*")
				for item in secao["itens"]:
					md.append("- " + item[0] + ": " + item[1])
				if secao.has("para_tcc"):
					md.append("*Para TCC sao necessarias " + secao["para_tcc"]["horas"] + \
						" horas. O discente tem " + str(secao["para_tcc"]["total_aluno"]) + ".*")
				md.append("**Total:** " + str(secao["total"]) + " horas")
			"previsao_formatura":
				md.append("### Previsao de formatura")
				if secao["integralizado"]:
					md.append("- *Todas as disciplinas obrigatorias concluidas ou em curso.*")
				else:
					md.append("**" + secao["periodo"] + "** (minimo de " + str(secao["semestres"]) \
						+ " semestres, contando o atual)")
					var nomes_cadeia: Array[String] = []
					for disc in secao["cadeia"]:
						nomes_cadeia.append(disc["nome"])
					if nomes_cadeia.size() > 0:
						md.append("- Caminho critico: " + " -> ".join(nomes_cadeia))
			"indice_aprovacao":
				md.append("### Indice de aprovacao")
				if secao["itens"].size() == 0:
					md.append("- *Nenhum semestre com resultado lancado.*")
				for periodo_indice in secao["itens"]:
					# O Markdown nao tem a cor do terminal: o criterio de estagio vira texto.
					var estagio_md: String = " — cumpre o criterio de estagio" if periodo_indice["apto_estagio"] \
						else " — NAO cumpre o criterio de estagio"
					md.append("- " + periodo_indice["periodo"] + ": " \
						+ str(int(round(periodo_indice["percentual"]))) + "% (" \
						+ str(periodo_indice["aprovadas"]) + " de " \
						+ str(periodo_indice["cursadas"]) + ") | " \
						+ str(int(round(periodo_indice["percentual_ch_aprovada"]))) + "% da CH (" \
						+ str(int(round(periodo_indice["ch_aprovada"]))) + " de " \
						+ str(int(round(periodo_indice["ch_cursada"]))) + "h)" + estagio_md)
				md.append("*Os percentuais consideram as disciplinas com resultado lancado (aprovacao ou reprovacao); matriculas em aberto, dispensas e trancamentos ficam de fora.*")
				md.append("*Criterio de estagio: cumpre quem aprova ao menos " \
					+ str(int(round((1.0 - _limite_reprovacao_estagio()) * 100.0))) \
					+ "% da carga horaria matriculada no semestre (o regulamento exige nao reprovar em mais de " \
					+ str(int(round(_limite_reprovacao_estagio() * 100.0))) + "% dela).*")
			"sem_grade_matriculadas":
				md.append("### Disciplinas sem grade (matriculadas)")
				for item in secao["itens"]:
					md.append("- " + item[0] + " " + item[1])
			"sem_grade_nao_matriculadas":
				md.append("### Disciplinas sem grade (nao matriculadas)")
				for item in secao["itens"]:
					md.append("- " + item[0] + " " + item[1])
			"matriculada_outra_grade":
				md.append("### Matriculada em outra grade (aproveitamento incompleto)")
				for item in secao["itens"]:
					md.append("- " + item[0] + ": " + item[1])
			"previsao_matriculas":
				md.append("### Previsao de matriculas")
			"aviso_reprovacoes":
				md.append("*Valores entre parenteses indicam reprovacoes por nota e por faltas (somando disciplinas equivalentes de outras grades).*")
			"condicao":
				md.append("#### " + secao["nome"].replacen("_", " ").capitalize())
				for disc in secao["itens"]:
					var linha_md: String = "- " + disc["codigo"] + ": " + disc["nome_disc"] + " (" + \
						disc["creditos"] + " Creditos)" + disc["reprovacoes"]
					if disc.has("info_choque") and not disc["info_choque"].is_empty() \
					and disc["info_choque"]["slots_conflito"] > 0:
						var necessario: int = disc["info_choque"].get("necessario", 0)
						if necessario <= 0:
							continue
						var max_pct: int = disc["info_choque"].get("max_presenca", 0)
						var nomes: Dictionary = disc["info_choque"].get("nomes_conflito", {})
						var nomes_lista: Array[String] = []
						for _cod in nomes:
							nomes_lista.append(nomes[_cod])
						linha_md += " | Conflito com " \
							+ ", ".join(nomes_lista) + " (" \
							+ str(max_pct) + "% presenca maxima)"
					md.append(linha_md)
			"condicao_cccg":
				md.append("#### " + secao["nome"].replacen("_", " ").capitalize() + " (CCCGs)")
				for disc in secao["itens"]:
					md.append("- " + disc["codigo"] + ": " + disc["nome_disc"] + " (" + \
						disc["creditos"] + " Creditos)")
		md.append("")

	md.append("")
	return md


#region Filtro de curso
# Preenche [_curso_por_matricula] mapeando cada matrícula da lista completa ao seu cod_curso.
func _mapear_cursos() -> void:
	_curso_por_matricula.clear()
	for aluno in _lista_alunos_todos:
		_curso_por_matricula[aluno[0]] = _detectar_curso(aluno[0])

# Detecta o cod_curso de uma [param matricula]: resolve a grade do aluno (via detectar_versao_grade)
# e devolve o curso cuja lista de grades a contém. A lista [code]cursos[cod].grades[/code] é derivada
# dos arquivos em [code]arquivos/grades/[/code] no startup, então cobre todas as grades existentes.
# Retorna "" se não encontrar.
func _detectar_curso(matricula: String) -> String:
	return _curso_da_grade(analise_historico.detectar_versao_grade(matricula, _historico))

# Retorna o cod_curso cuja lista [code]grades[/code] contém a [param grade] informada (ou "").
func _curso_da_grade(grade: String) -> String:
	return analise_historico.curso_da_grade(grade, cursos)

# Monta o seletor de curso do Topo. Lista apenas os cursos presentes no hist.csv, precedidos da
# opção "Todos os cursos" (retorno ""). Pré-seleciona o curso dono do ppc_principal; se ele não
# tiver alunos no arquivo, recai em "Todos os cursos". Selecionar o item dispara o handler, que
# repovoa o seletor de alunos via [_montar_lista_alunos].
func _montar_seletor_curso() -> void:
	# Cursos efetivamente presentes no hist.csv, preservando a ordem de base_config:cursos.
	var presentes: Array[String] = []
	for cod in cursos:
		if cod in _curso_por_matricula.values():
			presentes.append(cod)
	var nomes: Array[String] = ["Todos os cursos"]
	var cods: Array[String] = [""]
	for cod in presentes:
		nomes.append(str(cursos[cod].get("nome", cod)))
		cods.append(cod)
	$"%SeletorCurso".popular("cursos", nomes, cods)
	# Índice 0 = "Todos os cursos". Tenta posicionar no curso do ppc_principal.
	var indice: int = 0
	var ppc: String = GV.configuracao_base.get("ppc_principal", "")
	if not ppc.is_empty():
		var pos: int = cods.find(_curso_da_grade(ppc))
		if pos > 0:
			indice = pos
	$"%SeletorCurso".selecionar_item(indice)

# Reconstrói a lista de alunos exibida aplicando o filtro [_curso_filtro] sobre a lista completa,
# repovoando o seletor de alunos. A análise é disparada pela seleção do primeiro aluno.
func _montar_lista_alunos() -> void:
	_lista_alunos.clear()
	for aluno in _lista_alunos_todos:
		if _curso_filtro == "" or _curso_por_matricula.get(aluno[0], "") == _curso_filtro:
			_lista_alunos.append(aluno)
	var alunos_itens: Array[String] = []
	var alunos_retorno: Array[String] = []
	# Ícone verde (Modo Ajuste) para os alunos que já preencheram o formulário.
	var alunos_icones: Array = []
	for a in _lista_alunos.size():
		alunos_itens.append(_lista_alunos[a][1].capitalize())
		alunos_retorno.append(_lista_alunos[a][0])
		alunos_icones.append(_icone_ajuste if _ajuste_por_matricula.has(_lista_alunos[a][0].to_lower()) else null)
	$"%SeletorListaAlunos".lista_itens = {
		"_alunos*": alunos_itens,
		"_alunos_retorno": alunos_retorno,
		"_alunos_icones": alunos_icones
	}
	if _lista_alunos.size() > 0:
		_matricula_atual = _lista_alunos[0][0]
		$"%SeletorListaAlunos".selecionar_item(0)
	else:
		_matricula_atual = ""
#endregion

#region Sinais
# Mapa botao OnOff -> painel que ele controla. Base unica para alternar (Shift+clique isola/restaura)
# e para o realce: o botao fica "afundado" (toggle_mode) quando seu painel esta visivel.
func _mapa_toggles() -> Dictionary:
	return {
		$"%OnOffTerminal": $"%Terminal",
		$"%OnOffHorarios": $"%Horarios",
		$"%OnOffGrade": $"%GradeCurricular",
	}

func _toggle(alvo: Control) -> void:
	var mapa := _mapa_toggles()
	TogglePaineis.aplicar(mapa.values(), alvo, Input.is_key_pressed(KEY_SHIFT))
	TogglePaineis.sincronizar_botoes(mapa)

func _on_on_off_terminal_button_up() -> void:
	_toggle($"%Terminal")

func _on_on_off_horarios_button_up() -> void:
	_toggle($"%Horarios")

func _on_on_off_grade_button_up() -> void:
	_toggle($"%GradeCurricular")

# Reimprime o relatório com ou sem as seções analíticas (ver SECOES_DETALHADAS).
func _on_modo_detalhado_alternado(_ativo: bool) -> void:
	if _pronto:
		_reimprimir_relatorio()

func _on_seletor_lista_alunos_opcao_selecionada(retorno: String, _lista_selecionada: Array) -> void:
	_matricula_atual = retorno
	if _pronto:
		_rodar_análise()

# Troca o curso filtrado e repovoa a lista de alunos. A análise é disparada pela seleção do
# primeiro aluno (selecionar_item em _montar_lista_alunos aciona _on_seletor_lista_alunos_*).
func _on_seletor_curso_opcao_selecionada(retorno: String, _lista_selecionada: Array) -> void:
	_curso_filtro = retorno
	_montar_lista_alunos()

func _on_horarios_listacondicoes_alterada() -> void:
	if not _pronto:
		return
	_rodar_análise()

func _on_horarios_listaopcoes_alterada(opcao: String) -> void:
	_forma_de_apresentacao = opcao
	if not _pronto:
		return
	_rodar_análise()

func _on_grade_curricular_listaopcoes_alterada(opcao: String) -> void:
	_forma_apresentacao_grade = opcao
	_rodar_análise()

func _on_grade_celula_selecionada(codigo: String) -> void:
	# Toggle: clicar novamente na mesma disciplina limpa o destaque.
	if _codigo_selecionado == codigo:
		_codigo_selecionado = ""
		_codigos_destacar = []
	else:
		_codigo_selecionado = codigo
		_codigos_destacar = analise_grades.prerequisitos_transitivos(codigo, grades_disciplinas_curriculos[_grade_ativa])
	_atualizar_grade_curricular()

## Trata clique direito: destaca transitivamente disciplinas que têm [param codigo]
## como pré-requisito (bloqueadas), com cor decrescente por profundidade.
func _on_grade_celula_selecionada_direita(codigo: String) -> void:
	if _codigo_selecionado_direito == codigo:
		_codigo_selecionado_direito = ""
		_codigos_destacar_secundario = {}
	else:
		_codigo_selecionado_direito = codigo
		_codigos_destacar_secundario = analise_grades.obter_bloqueadas_transitivas(codigo, grades_disciplinas_curriculos[_grade_ativa])
	_atualizar_grade_curricular()

# Códigos que recebem hachura leve na grade: os que ainda estão distantes de serem cursáveis (ver
# [method AnaliseGrades.disciplinas_distantes]). Monta o conjunto de códigos do histórico que aquela
# função usa para reconhecer as disciplinas já concluídas sob o código de outra grade.
func _codigos_distantes(matricula: String, disc_cursaveis: Dictionary, cursadas: Array[String]) -> Array[String]:
	var codigos_historico: Dictionary = {}
	for dado in _historico.get(matricula, {}).get("dados", []):
		codigos_historico[str(dado.get("codigocurriculo", "")).to_lower()] = true
	return analise_grades.disciplinas_distantes(grades_disciplinas_curriculos[_grade_ativa], \
		disc_cursaveis, cursadas, equivalencias, _grade_ativa, codigos_historico)

# Soma a [param cursadas] os alvos concluídos por equivalência na grade ativa (ver
# [method AnaliseGrades.concluidas_por_equivalencia]), para que a grade curricular pinte esses alvos
# com a cor de "cursada". Não muta o argumento; usada só como entrada de [method montar_grade_curricular]
# — a lista crua de [param cursadas] continua indo para [method _codigos_distantes] e o resto do relatório.
func _cursadas_com_equivalencia(cursadas: Array[String]) -> Array[String]:
	var expandidas: Array[String] = []
	expandidas.append_array(cursadas)
	expandidas.append_array(analise_grades.concluidas_por_equivalencia(cursadas, equivalencias, _grade_ativa))
	return expandidas

## Regera apenas a grade curricular (sem reprocessar horários ou percentuais),
## aplicando os destaques de pré-requisitos conforme [_codigos_destacar].
func _atualizar_grade_curricular() -> void:
	var cursadas: Array[String] = analise_historico.disciplinas_concluidas(_matricula_atual, _historico)
	var disc_cursaveis: Dictionary = _condicoes_discentes.get(_matricula_atual, {})
	var grade_ativa: Dictionary = grades_disciplinas_curriculos[_grade_ativa]
	$"%GradeCurricular".dados = analise_grades.montar_grade_curricular(
		grade_ativa,
		disc_cursaveis,
		_cursadas_com_equivalencia(cursadas),
		lista_cores,
		_forma_apresentacao_grade,
		_codigos_destacar,
		_codigos_destacar_secundario,
		{},
		[],
		[],
		Color.TRANSPARENT,
		_codigos_distantes(_matricula_atual, disc_cursaveis, cursadas)
	)
	# Monta as linhas de conexão em dominó: cadeia de pré-requisitos (esquerdo) e de dependentes
	# (direito). Sem seleção, a lista fica vazia e nenhuma linha é desenhada.
	var conexoes: Array = []
	if _codigo_selecionado != "":
		conexoes.append_array(analise_grades.conexoes_prerequisitos(_codigo_selecionado, grade_ativa))
	if _codigo_selecionado_direito != "":
		conexoes.append_array(analise_grades.conexoes_bloqueios(_codigo_selecionado_direito, grade_ativa))
	$"%GradeCurricular".conexoes = conexoes

# Limpa os realces de horarios e reseta [_codigo_realcado].
func _limpar_realces_horarios() -> void:
	_codigo_realcado = ""
	var grade_horarios = $"%Horarios".get_node("GradeHorarios")
	if not grade_horarios:
		return
	var dias: Array = GV.configuracao_base.get("dias_semana", [])
	var horas: Array = GV.configuracao_base.get("horarios_aula", [])
	for lin in horas.size() + 1:
		for col in dias.size() + 1:
			var cel: Celula = grade_horarios.get_celula(lin, col)
			if cel:
				cel.cor_fundo = Color(0.173, 0.173, 0.173, 1)

## Realca na GradeHorarios todas as celulas do codigo informado (toggle).
func _realcar_por_codigo(codigo: String) -> void:
	if _codigo_realcado == codigo:
		_limpar_realces_horarios()
		return
	_limpar_realces_horarios()
	_codigo_realcado = codigo
	var cod_lower: String = codigo.to_lower()
	var grade_horarios = $"%Horarios".get_node("GradeHorarios")
	if not grade_horarios:
		return
	var dias: Array = GV.configuracao_base.get("dias_semana", [])
	var horas: Array = GV.configuracao_base.get("horarios_aula", [])
	for lin in horas.size() + 1:
		for col in dias.size() + 1:
			var cel: Celula = grade_horarios.get_celula(lin, col)
			if not cel:
				continue
			var txt: String = GeneralFunctions.remover_bbcode_cor(cel.texto_central)
			# Verifica se algum codigo na celula corresponde ao alvo
			var partes_txt: PackedStringArray = txt.split(",")
			var encontrou: bool = false
			for parte_txt in partes_txt:
				if horarios_exe.extrair_cod_horarios_txt(parte_txt.strip_edges()).to_lower() == cod_lower:
					encontrou = true
					break
			if encontrou:
				cel.cor_fundo = Color(0.3, 0.6, 0.3, 0.3)

## Abre um AcceptDialog com botoes para cada disciplina na celula.
func _mostrar_selecao_disciplinas(partes: PackedStringArray, codigos: Array[String]) -> void:
	var dialogo := AcceptDialog.new()
	dialogo.title = "Selecione a disciplina"
	dialogo.ok_button_text = "Cancelar"
	dialogo.min_size = Vector2(400, 0)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in codigos.size():
		var nome: String = horarios_exe.extrair_nome_horarios_txt(partes[i]).strip_edges()
		var btn := Button.new()
		btn.text = nome + " (" + codigos[i].to_upper() + ")"
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_realcar_por_codigo.bind(codigos[i]))
		btn.pressed.connect(dialogo.queue_free)
		vbox.add_child(btn)
	dialogo.add_child(vbox)
	add_child(dialogo)
	dialogo.popup_centered()
	Dialogos.limitar_a_tela(dialogo)

## Realca na GradeHorarios todas as celulas da disciplina clicada (toggle).
## Se a celula tiver multiplas disciplinas, abre popup de selecao.
func _on_horarios_celula_clicada(linha: int, coluna: int) -> void:
	var grade_horarios = $"%Horarios".get_node("GradeHorarios")
	if not grade_horarios:
		return
	var celula: Celula = grade_horarios.get_celula(linha, coluna)
	if not celula or celula.texto_central.is_empty():
		_limpar_realces_horarios()
		return
	# Extrai todos os codigos da celula (separados por virgula no texto BBCode)
	var texto_limpo: String = GeneralFunctions.remover_bbcode_cor(celula.texto_central)
	var codigos: Array[String] = []
	var partes: PackedStringArray = texto_limpo.split(",")
	for parte in partes:
		var parte_limpa: String = parte.strip_edges()
		var cod: String = horarios_exe.extrair_cod_horarios_txt(parte_limpa)
		if not cod.is_empty():
			codigos.append(cod.to_lower())
	if codigos.is_empty():
		_limpar_realces_horarios()
		return
	if codigos.size() == 1:
		_realcar_por_codigo(codigos[0])
	else:
		_mostrar_selecao_disciplinas(partes, codigos)

## Clique ESQUERDO no botão Modo Ajuste abre as opções (diálogo de configuração da URL da planilha).
func _on_modo_ajuste_button_up() -> void:
	_abrir_dialogo_url()

## Clique DIREITO inicia/atualiza o Modo Ajuste agora (verifica e liga a atualização automática). O
## botão indica o status pela cor (laranja obtendo, verde obtido, vermelho falha).
func _on_modo_ajuste_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_iniciar_modo_ajuste()

## Diálogo que pede o endereço da planilha publicada em CSV. O campo vem pré-preenchido com a URL
## salva; ao confirmar, atualiza o membro, emite [signal override_config] para o main persistir em
## [code]config_usuario.json[/code] e, se a URL não ficar vazia, inicia o timer e verifica de imediato.
func _abrir_dialogo_url() -> void:
	var dialogo := ConfirmationDialog.new()
	dialogo.title = "Modo Ajuste — Planilha de respostas"
	dialogo.get_ok_button().text = "Ok"
	dialogo.get_cancel_button().text = "Cancelar"

	var vbox := VBoxContainer.new()
	dialogo.add_child(vbox)
	var rotulo := Label.new()
	rotulo.text = "Endereço da planilha do Google publicada em CSV:"
	vbox.add_child(rotulo)
	var ed_url := LineEdit.new()
	ed_url.placeholder_text = "https://docs.google.com/spreadsheets/d/.../export?format=csv"
	ed_url.text = url_planilha_ajuste
	ed_url.custom_minimum_size = Vector2(460, 0)
	vbox.add_child(ed_url)

	dialogo.confirmed.connect(func():
		var url: String = ed_url.text.strip_edges()
		# Atualiza o membro local (uso imediato na sessão) e emite para o main persistir em disco.
		url_planilha_ajuste = url
		override_config.emit(["modo_ajuste", "url_planilha"], url)
		# Dar "Ok" com uma URL inicia o Modo Ajuste (verifica agora + liga a atualização automática).
		_iniciar_modo_ajuste())
	# Libera o nó em qualquer caminho de fechamento (Ok/Cancelar/Esc/X), sem risco de free duplo.
	dialogo.visibility_changed.connect(func():
		if not dialogo.visible:
			dialogo.queue_free())
	add_child(dialogo)
	dialogo.popup_centered()
	Dialogos.limitar_a_tela(dialogo)

# Inicia o Modo Ajuste sob demanda (nunca automaticamente ao abrir o módulo): faz uma verificação
# imediata e liga a atualização automática a cada 5 min. Sem URL configurada, orienta a configurar.
func _iniciar_modo_ajuste() -> void:
	if url_planilha_ajuste.strip_edges().is_empty():
		$"%Terminal".text_edit("Modo Ajuste: configure o endereço da planilha primeiro (clique esquerdo no botão).", \
			cores_terminal["aviso"], true, false)
		return
	_iniciar_timer_ajuste()
	_verificar_planilha()

# Cria (uma vez) e (re)inicia o timer de verificação automática a cada 5 minutos.
func _iniciar_timer_ajuste() -> void:
	if _timer_ajuste == null:
		_timer_ajuste = Timer.new()
		_timer_ajuste.one_shot = false
		_timer_ajuste.wait_time = 300.0
		_timer_ajuste.timeout.connect(_verificar_planilha)
		add_child(_timer_ajuste)
	_timer_ajuste.start()

## Baixa e processa a planilha de ajuste: marca quem preencheu (ícone verde), alerta uma única vez
## sobre respostas problemáticas e atualiza terminal/grade do aluno selecionado, se ele preencheu.
func _verificar_planilha() -> void:
	var url: String = url_planilha_ajuste.strip_edges()
	if url.is_empty() or _verificando:
		return
	_verificando = true
	_definir_estado_botao_ajuste("ch_extra")  # laranja: obtendo (ou tentando)
	var baixa: Dictionary = await planilha_ajuste.baixar(url)
	if not baixa["ok"]:
		_verificando = false
		_definir_estado_botao_ajuste("erro")  # vermelho: falha
		$"%Terminal".text_edit("Modo Ajuste: " + str(baixa["erro"]), cores_terminal["erro"], true, false)
		return
	var resultado: Dictionary = planilha_ajuste.parse(baixa["csv"])
	if not resultado["ok"]:
		_verificando = false
		_definir_estado_botao_ajuste("erro")  # vermelho: falha
		$"%Terminal".text_edit("Modo Ajuste: " + str(resultado["erro"]), cores_terminal["erro"], true, false)
		# Diagnóstico: mostra o início do conteúdo recebido. Uma resposta HTML (em vez de CSV) indica
		# que a URL exige login — use o link "Publicar na web › CSV" ou compartilhe a planilha como
		# "qualquer pessoa com o link".
		var amostra: String = str(baixa["csv"]).strip_edges().replace("\n", " ").replace("\r", " ")
		if amostra.length() > 200:
			amostra = amostra.substr(0, 200) + "…"
		if amostra.is_empty():
			$"%Terminal".item("A planilha respondeu vazia.", 1, cores_terminal["aviso"])
		elif amostra.begins_with("<") or amostra.to_lower().contains("<html") or amostra.to_lower().contains("<!doctype"):
			$"%Terminal".item("A URL retornou HTML, não CSV (provável página de login). Publique a " \
				+ "planilha em CSV (Arquivo › Compartilhar › Publicar na web › CSV) ou compartilhe como " \
				+ "'qualquer pessoa com o link'.", 1, cores_terminal["aviso"])
		else:
			$"%Terminal".item("Conteúdo recebido (início): " + amostra, 1, cores_terminal["aviso"])
		return
	_processar_respostas_ajuste(resultado["respostas"])
	_verificando = false
	_definir_estado_botao_ajuste("sucesso")  # verde: dados obtidos

# Converte as respostas cruas em [_ajuste_por_matricula], dispara os alertas dos preenchimentos novos
# (dedup por assinatura) e repinta os ícones. Só re-roda a análise se a resposta DO aluno selecionado
# mudou, para não atrapalhar o estudo de outro aluno.
func _processar_respostas_ajuste(respostas: Array) -> void:
	var assinatura_antes: String = _assinatura_de(_matricula_atual)
	var novo_ajuste: Dictionary = {}
	var a_alertar: Array[Dictionary] = []
	for resp in respostas:
		var matricula: String = str(resp["matricula"]).strip_edges()
		var valida: bool = _curso_por_matricula.has(matricula)
		var grade: String = analise_historico.detectar_versao_grade(matricula, _historico) if valida else ""
		var inc: Dictionary = _classificar_codigos(resp["incluir"], grade)
		var exc: Dictionary = _classificar_codigos(resp["excluir"], grade)
		var registro: Dictionary = {
			"matricula": matricula,
			"valida": valida,
			"incluir": inc["codigos"],
			"excluir": exc["codigos"],
			"incluir_problemas": inc["problemas"],
			"excluir_problemas": exc["problemas"],
			"assinatura": _assinatura_resposta(matricula, resp["incluir"], resp["excluir"]),
		}
		if valida:
			novo_ajuste[matricula.to_lower()] = registro
		# Enfileira o alerta dos preenchimentos NOVOS (assinatura inédita nesta sessão).
		if not _assinaturas_alertadas.has(registro["assinatura"]):
			_assinaturas_alertadas[registro["assinatura"]] = true
			a_alertar.append(registro)
	_ajuste_por_matricula = novo_ajuste
	_atualizar_icones_ajuste()
	# Re-roda a análise ANTES de alertar: [_imprimir_analise] limpa o terminal (titulo com clear), então
	# os alertas têm de ser emitidos por último para não serem apagados (matrícula inválida só aparece
	# aqui — não há outra superfície para ela).
	if _pronto and not _matricula_atual.is_empty() and _assinatura_de(_matricula_atual) != assinatura_antes:
		_rodar_análise()
	for registro in a_alertar:
		_alertar_problemas_ajuste(registro)

# Para cada entrada de texto livre, extrai o código de disciplina e o valida no escopo do curso do
# aluno (grade dele primeiro; qualquer grade como reconhecedor). Retorna { "codigos", "problemas" },
# onde "problemas" guarda as entradas sem código válido (alvo dos alertas).
func _classificar_codigos(entradas: Array, grade: String) -> Dictionary:
	var codigos: Array[String] = []
	var problemas: Array[String] = []
	for entrada in entradas:
		var candidatos: Array = planilha_ajuste.extrair_codigos(str(entrada))
		var achou: String = ""
		# Preferência: código presente na grade do aluno (desempata disciplinas de mesmo código entre
		# cursos). Senão, qualquer código existente em alguma grade.
		for cand in candidatos:
			if not grade.is_empty() and grades_disciplinas_curriculos.get(grade, {}).has(cand):
				achou = cand
				break
		if achou.is_empty():
			for cand in candidatos:
				if analise_grades.existe_codigo(grades_disciplinas_curriculos, cand):
					achou = cand
					break
		if achou.is_empty():
			problemas.append(str(entrada))
		elif not achou in codigos:
			codigos.append(achou)
	return { "codigos": codigos, "problemas": problemas }

# Emite no terminal os alertas de uma resposta nova: matrícula inválida, ou disciplinas sem código
# válido. Respostas íntegras não geram alerta (só o destaque verde na lista).
func _alertar_problemas_ajuste(registro: Dictionary) -> void:
	if not registro["valida"]:
		$"%Terminal".text_edit("Modo Ajuste: recebida resposta com matrícula inválida ou desconhecida (" \
			+ str(registro["matricula"]) + ").", cores_terminal["erro"], true, false)
		return
	var problemas: Array = registro["incluir_problemas"] + registro["excluir_problemas"]
	if problemas.is_empty():
		return
	$"%Terminal".text_edit("Modo Ajuste: a resposta de " + _nome_de(registro["matricula"]) + " (" \
		+ str(registro["matricula"]) + ") tem disciplina(s) sem código válido:", cores_terminal["aviso"], true, false)
	for p in problemas:
		$"%Terminal".item(str(p), 1, cores_terminal["aviso"])

# Repinta os ícones do seletor: verde para quem preencheu, nada para os demais. Sem reconstruir a
# lista (preserva a seleção atual).
func _atualizar_icones_ajuste() -> void:
	for aluno in _lista_alunos:
		var marcado: bool = _ajuste_por_matricula.has(str(aluno[0]).to_lower())
		$"%SeletorListaAlunos".definir_icone_item(aluno[0], _icone_ajuste if marcado else null)

# Pinta o botão Modo Ajuste como indicador de status da conexão com a planilha: laranja ("ch_extra")
# obtendo, verde ("sucesso") obtido, vermelho ("erro") falha. Fundo via StyleBoxFlat e texto
# escuro/claro conforme a luminância da cor, para leitura em qualquer tema.
func _definir_estado_botao_ajuste(token: String) -> void:
	var btn: Button = $"Topo/HBoxContainer/ModoAjuste"
	var cor: Color = PaletaSemantica.cor(token)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = cor
	estilo.set_corner_radius_all(4)
	estilo.set_content_margin_all(4)
	for estado in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(estado, estilo)
	var cor_texto: Color = Color.BLACK if cor.get_luminance() > 0.45 else Color.WHITE
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(c, cor_texto)

# Gera uma pequena bolinha verde (cor semântica "sucesso") para marcar os alunos que preencheram.
# É um círculo (não quadrado) para não se confundir com a caixa de seleção do item da lista.
func _criar_icone_ajuste() -> Texture2D:
	var tam: int = 16
	var img := Image.create(tam, tam, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))  # fundo transparente
	var cor: Color = PaletaSemantica.cor("sucesso")
	var centro: float = (tam - 1) / 2.0
	var raio: float = tam / 2.0 - 1.5
	for y in tam:
		for x in tam:
			var dx: float = x - centro
			var dy: float = y - centro
			if dx * dx + dy * dy <= raio * raio:
				img.set_pixel(x, y, cor)
	return ImageTexture.create_from_image(img)

## Imprime no terminal as disciplinas que o discente pediu para incluir/excluir, cruzando com as
## condições (matriculável, já matriculado, etc.) para apoiar a decisão de deferimento.
func _imprimir_ajuste(matricula: String) -> void:
	var registro: Dictionary = _ajuste_por_matricula.get(matricula.to_lower(), {})
	if registro.is_empty():
		return
	var disc_cursaveis: Dictionary = _condicoes_discentes.get(matricula, {})
	# Subseções: o ajuste é impresso dentro do bloco "Previsão de matrículas" (ver _imprimir_analise).
	$"%Terminal".subsecao("Ajuste de matrícula — deseja INCLUIR")
	if registro["incluir"].is_empty() and registro["incluir_problemas"].is_empty():
		$"%Terminal".item("(nenhuma)")
	for codigo in registro["incluir"]:
		var st: Dictionary = _status_incluir(codigo, disc_cursaveis)
		$"%Terminal".item(_rotulo_disc(codigo) + " — " + st["texto"], 0, st["token"], PaletaSemantica.FUNDO_AJUSTE_INCLUIR)
	for prob in registro["incluir_problemas"]:
		$"%Terminal".item(str(prob) + " — código inválido/ausente", 0, cores_terminal["erro"], PaletaSemantica.FUNDO_AJUSTE_INCLUIR)
	$"%Terminal".espaco()
	$"%Terminal".subsecao("Ajuste de matrícula — deseja EXCLUIR")
	if registro["excluir"].is_empty() and registro["excluir_problemas"].is_empty():
		$"%Terminal".item("(nenhuma)")
	for codigo in registro["excluir"]:
		var st2: Dictionary = _status_excluir(codigo, disc_cursaveis)
		$"%Terminal".item(_rotulo_disc(codigo) + " — " + st2["texto"], 0, st2["token"], PaletaSemantica.FUNDO_AJUSTE_EXCLUIR)
	for prob in registro["excluir_problemas"]:
		$"%Terminal".item(str(prob) + " — código inválido/ausente", 0, cores_terminal["erro"], PaletaSemantica.FUNDO_AJUSTE_EXCLUIR)
	$"%Terminal".espaco()

# Status de uma disciplina que o aluno quer incluir, conforme a condição em que ela cai para ele.
# A cor (token) segue a da própria condição (mesma regra das seções de condição), via lista_cores.
func _status_incluir(codigo: String, disc_cursaveis: Dictionary) -> Dictionary:
	var cond: String = _condicao_do_codigo(codigo, disc_cursaveis)
	if cond.begins_with("matriculavel") or cond.begins_with("corequisito_matriculavel"):
		var aprov: String = " (com aproveitamento)" if cond.ends_with("_aproveitamento") else ""
		return { "texto": "matriculável" + aprov, "token": lista_cores.get(cond, cores_terminal["sucesso"]) }
	if cond.begins_with("matriculado_agora"):
		return { "texto": "já está matriculado", "token": lista_cores.get(cond, cores_terminal["aviso"]) }
	if cond.is_empty():
		return { "texto": "não está matriculável", "token": cores_terminal["erro"] }
	return { "texto": cond.replacen("_", " "), "token": lista_cores.get(cond, cores_terminal["aviso"]) }

# Status de uma disciplina que o aluno quer excluir (espera-se que esteja matriculado nela).
# A cor (token) segue a da própria condição, via lista_cores.
func _status_excluir(codigo: String, disc_cursaveis: Dictionary) -> Dictionary:
	var cond: String = _condicao_do_codigo(codigo, disc_cursaveis)
	if cond.begins_with("matriculado_agora") or cond.begins_with("matricula_irregular"):
		return { "texto": "matriculado", "token": lista_cores.get(cond, cores_terminal["sucesso"]) }
	return { "texto": "não consta como matriculado", "token": cores_terminal["aviso"] }

# Retorna a primeira condição de [disc_cursaveis] que contém [codigo] (minúsculo), ou "" se nenhuma.
func _condicao_do_codigo(codigo: String, disc_cursaveis: Dictionary) -> String:
	for cond in disc_cursaveis.keys():
		for c in disc_cursaveis[cond]:
			if str(c).to_lower() == codigo:
				return cond
	return ""

# Rótulo "CODIGO: Nome da disciplina" a partir das grades.
func _rotulo_disc(codigo: String) -> String:
	return codigo.to_upper() + ": " + str(analise_grades.info_grade(grades_disciplinas_curriculos, codigo, "nome"))

# Nome (capitalizado) do aluno de uma matrícula, buscando na lista completa; devolve a matrícula se
# não encontrar.
func _nome_de(matricula: String) -> String:
	for aluno in _lista_alunos_todos:
		if aluno[0] == matricula:
			return str(aluno[1]).capitalize()
	return matricula

# Assinatura de uma resposta (matrícula + entradas cruas), usada para detectar mudanças e deduplicar
# alertas. Qualquer alteração no texto preenchido muda a assinatura.
func _assinatura_resposta(matricula: String, incluir: Array, excluir: Array) -> String:
	return matricula + "|" + "/".join(PackedStringArray(incluir)) + "|" + "/".join(PackedStringArray(excluir))

# Assinatura atualmente armazenada para uma matrícula (ou "" se ela não preencheu).
func _assinatura_de(matricula: String) -> String:
	return str(_ajuste_por_matricula.get(matricula.to_lower(), {}).get("assinatura", ""))


## Abre um diálogo de confirmação antes de exportar a situação dos alunos (do curso filtrado).
func _on_exportar_button_up() -> void:
	var rotulo_curso: String = "todos os cursos"
	if _curso_filtro != "":
		rotulo_curso = str(cursos.get(_curso_filtro, {}).get("nome", _curso_filtro))
	Dialogos.confirmar(self, "Exportar Situação dos Alunos", \
		"Deseja exportar a situação dos alunos de %s (%d) para um arquivo?" % [rotulo_curso, _lista_alunos.size()], \
		_exportar, "Exportar")

func _exportar() -> void:
	var time: Dictionary = Time.get_date_dict_from_system()
	var time_hora: Dictionary = Time.get_time_dict_from_system()
	var data_hora: String = "%02d/%02d/%04d %02d:%02d" % [time["day"], time["month"], time["year"], time_hora["hour"], time_hora["minute"]]
	var data_arquivo: String = str(time["year"]) + "_" + "%02d" % time["month"] + "_" + "%02d" % time["day"]
	var linhas: Array[String] = []

	# Cabeçalho do documento
	var rotulo_curso: String = "Todos os cursos"
	if _curso_filtro != "":
		rotulo_curso = str(cursos.get(_curso_filtro, {}).get("nome", _curso_filtro))
	linhas.append("# Situacao dos Alunos")
	linhas.append("")
	linhas.append("**Exportado em:** " + data_hora)
	linhas.append("**Curso:** " + rotulo_curso)
	linhas.append("**Total de alunos:** " + str(_lista_alunos.size()))
	linhas.append("")

	for aluno in _lista_alunos:
		var matricula: String = aluno[0]
		var nome: String = aluno[1].capitalize()

		# Detecta grade e CH exigida para o aluno
		_grade_ativa = analise_historico.detectar_versao_grade(matricula, _historico)
		if not _validar_grade_ativa():
			continue
		# Carga exigida opcional: ausência não exclui o aluno da exportação (só o percentual).
		if cargas_exigidas.has(_grade_ativa):
			_ch_exigida = cargas_exigidas[_grade_ativa]
			_ch_exigida = analise_grades.ajustarch_tccestagio(grades_disciplinas_curriculos[_grade_ativa], _ch_exigida)
		else:
			_ch_exigida = {}

		# Computa os dados
		var ch_data: Dictionary = analise_historico.ch_vencida(matricula, \
			grades_disciplinas_curriculos[_grade_ativa], _historico)
		var ch_vencida: Dictionary = ch_data["ch"]
		var disc_semgrade: Array[Array] = analise_historico.revisar_historico(_historico, \
			grades_disciplinas_curriculos, matricula, false)
		var disc_cursaveis: Dictionary = _condicoes_discentes.get(matricula, {})
		var creditos_disciplinas: Dictionary = analise_historico.creditos_disciplinas(matricula, \
			_historico, disc_cursaveis, grades_disciplinas_curriculos)
		var analisado_reprov: Dictionary = _analisado_reprov.get(matricula, {})

		# Formata o aluno em markdown
		linhas.append("---")
		linhas.append("")
		linhas.append_array(_formatar_analise_markdown(matricula, nome, disc_cursaveis, disc_semgrade, \
			ch_vencida, creditos_disciplinas, analisado_reprov))

	# Salva o arquivo
	var nome_arquivo: String = "situacao_alunos_" + data_arquivo + ".md"
	file_handling.check_create_dir(diretorio_exportacao)
	file_handling.save_text_file(diretorio_exportacao, nome_arquivo, linhas)
	$"%Terminal".text_edit("Arquivo exportado: " + diretorio_exportacao + nome_arquivo, \
		cores_terminal["sucesso"], true, true)

#endregion
