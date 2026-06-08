class_name PlanejamentoHorario extends ReferenceRect
## Relacionado o planejamento da oferta e horários do semestre.
##
## Os principais empregos são: [br]
## - Verificar os horários dos professores e suas preferências; [br]
## - Editar os horários das disciplinas. [br]
##
## Lógica delegada para classes em [code]Complementos/[/code]: [br]
## - [DetectorDeChoques]: detecção e marcação de choques [br]
## - [VerificadorCarga]: verificação de carga horária dos professores [br]
## - [GerenciadorAlocacoes]: CRUD de alocações e renderização de células [br]
## - [ArquivosPlanejamento]: leitura/parsing de arquivos de dados [br]
##   (movido para [code]standalone_scripts/io/arquivos_planejamento.gd[/code]) [br]
## - [PainelDisciplinas]: painel de cards e filtros cascata (compartilhado)

## Emitido quando o usuario altera uma configuracao persistente (ex.: credenciais de sincronizacao).
## O [code]main.gd[/code] conecta este sinal e centraliza a gravacao em config_usuario.json via
## override — espelha o [signal JanelaConfiguracoes.parametro_alterado].
signal override_config(caminho: Array, valor: Variant)

# Classes instanciadas.
var file_handling := FileHandling.new()
var analise_grades := AnaliseGrades.new()
var analise_horarios := AnaliseHorarios.new()
var analise_historico := AnaliseHistorico.new()
var horarios_exe := HorariosExe.new()

# Classes de Complementos
var _dados: ArquivosPlanejamento
var _ger_alocacoes: GerenciadorAlocacoes
var _detector: DetectorDeChoques
var _verif_carga: VerificadorCarga
var _aplicador: AplicadorVisualGrade
var _relatorios: RelatoriosHorario
var _posicionador: PosicionadorAutomatico

# Cliente de sincronizacao do planejamento com o servidor Kinto (instanciado no _ready).
var _sync: SyncKinto

## Recebido pelo main em sua criação e vem do arquivo base_config.json.
## Contém o endereço completo para o diretório com os arquivos csv das opções dos professores.
var diretorio_regras: String

## Recebido pelo main em sua criação e vem do arquivo [code]base_config.json[/code]
var posicoes_horarios_txt: Dictionary

## Recebido pelo main em sua criação e vem do arquivo [code]base_config.json[/code].
## Posições das colunas no arquivo [code]hist.csv[/code].
var posicoes_histcsv: Dictionary = {}

## Recebido pelo main em sua criação e vem do arquivo [code]base_config.json[/code].
## Lista de condições de matrícula (matriculavel, matriculado_agora, etc).
var condicoes: Array[String] = []

## Recebido pelo main em sua criação e vem da pasta de equivalencias.
var equivalencias: Dictionary = {}

## Recebido pelo main em sua criação e vem da pasta de grades. [br]
## Formato de [param grades_disciplinas_curriculos] deve conter múltiplas grades, com chave
## no padrão [code]<cod_curso>_<versao>[/code]. Exemplo: [br]
## { [br]
## "alec_2010": Dicionário copia de [code]/arquivos/grades/alec_2010.json[/code], [br]
## "alec_2023": Dicionário copia de [code]/arquivos/grades/alec_2023.json[/code] [br]
## }
var grades_disciplinas_curriculos: Dictionary = {}

## Recebido pelo main, contem os delimitadores padrao do programa.
var delimitadores: Dictionary = {}

## Posicoes das colunas no arquivo [code]planejamento.csv[/code], de [code]base_config.json[/code].
var posicoes_planejamento: Dictionary = {}

## Recebido pelo main, contem as cores padrao do terminal.
var cores_terminal: Dictionary = {}

## Metadados de cursos da [code]base_config.json:cursos[/code]. [br]
## Formato: [code]{<cod_curso>: {nome, prefixos_semestre, turmas, grades}}[/code].
var cursos: Dictionary = {}

## Recebido pelo main, diretorio onde os arquivos exportados sao salvos
## (e.g. [code]<raiz>/exportacoes[/code]). Sem barra final.
var diretorio_exportacao: String = ""

## Configuracoes globais de interface, de [code]base_config.json[/code].
var config_interface: Dictionary = {}

## Modos de exibição das células da grade (lista canônica), de [code]base_config.json:formatos_grade[/code].
## Compartilhada com Situação de alunos/disciplinas.
var formatos_grade: Dictionary = {}

## Recebido pelo main, de [code]base_config.json:posicionamento_auto[/code]. Faixas de período,
## horários de emergência e pesos usados pelo [PosicionadorAutomatico].
var config_posicionamento: Dictionary = {}

# Dialogo modal de selecao de cursos para a importacao do planejamento.csv.
var _seletor_cursos: SeletorCursos

# Dialogo modal de selecao de cursos para a importacao do horarios.txt.
var _seletor_cursos_horario: SeletorCursos

# Dialogo modal de configuracao do posicionamento automatico (turno inicial e aula no sabado).
var _config_posic: ConfigPosicionamento

# Ultimas escolhas no _config_posic, reapresentadas ao reabrir o dialogo.
var _inicio_manha_posic: bool = true
var _permitir_sabado_posic: bool = false
# Quando true, o posicionamento ignora as disciplinas compartilhadas entre cursos (escolha feita no
# aviso de compartilhadas). Definido a cada abertura do dialogo de configuracao.
var _excluir_compartilhadas_posic: bool = false

# Ultimos cod_curso marcados no _seletor_cursos, reapresentados ao reabrir o dialogo.
var _cursos_marcados_planejamento: Array[String] = []

# Indicadores de problemas ativos (chaves definidas em INDICADORES)
var _indicadores_ativos: Array[String] = []

# Ultimo total de choques detectado, para reaplicar a barra de status na troca de tema.
var _ultimo_total_choques: int = 0

# Condições por célula ("linha_coluna" → dict) da última recálculo da grade. Alimenta o
# AplicadorVisualGrade e o tooltip; preenchido por _montar_mapa_condicoes.
var _mapa_condicoes: Dictionary = {}

# Menu de contexto (clique direito numa célula): lista as disciplinas daquele horário; ao escolher
# uma, aplica o filtro de semestre ao semestre dela. _menu_celula_semestres guarda, por índice de
# item, o semestre correspondente.
var _menu_celula: PopupMenu
var _menu_celula_semestres: Array[String] = []
# Estado anterior do botao direito, para detectar a borda de pressao no polling de _process (reabrir o
# menu de contexto noutra celula enquanto o popup esta aberto).
var _rmb_anterior: bool = false

# Código (minúsculo) da disciplina destacada por clique em um card: suas células ficam em verde
# claro na grade. Vazio = nenhuma. Limpo ao alterar/limpar os filtros.
var _disciplina_destacada: String = ""

# Ultimo total de alunos em choque entre disciplinas sobrepostas (par a par), para a barra de status.
var _ultimo_total_alunos_choque: int = 0

# Ultimo total de disciplinas compartilhadas em horario divergente entre o seu plano e a referencia
# (outro curso sobreposto), para a barra de status. Zero quando nao ha referencia.
var _ultimo_total_compartilhadas_div: int = 0

# Dados de histórico/discentes carregados sob _ready (necessários ao indicador de choque de alunos).
var _historico: Dictionary = {}
var _lista_alunos: Array[Array] = []
var _condicoes_discentes: Dictionary = {}

# Condições de matrícula selecionadas no SeletorCondicoesChoque que contam como choque de alunos.
var _condicoes_choque_selecionadas: Array[String] = []

# Semestre destacado APENAS na grade (não filtra a lista de disciplinas). Definido ao
# clicar/arrastar um card. Dá precedência de movimento à disciplina deste semestre e, em
# células com sobreposição de semestres, oculta os nomes das alocações de outros semestres.
var _filtro_grade_semestre: String = ""

# Cache de comentários textuais por professor (nome_minúsculo → Array[String]), populado
# sob demanda por _vincular_regras_aos_cards. Evita re-ler os CSVs a cada sincronização.
var _cache_comentarios_professores: Dictionary = {}

const IND_SEM_PROFESSOR := "Células sem professor"
const IND_CHOQUE := "Choque de professor/sala/semestre"
const IND_CH_EXCEDIDA := "CH excedida"
const IND_CARGA := "Carga ≥6h/dia"
const IND_NOTURNA_MANHA := "Noturna → manhã"
const IND_CHOQUE_ALUNOS := "Choques de horário"
const IND_DETALHAR_ALUNOS := "Detalhar alunos em choque"

# Todos os indicadores oferecidos no SeletorPreferencias (na ordem do menu).
const INDICADORES_DISPONIVEIS: Array[String] = [
	IND_SEM_PROFESSOR,
	IND_CHOQUE,
	IND_CH_EXCEDIDA,
	IND_CARGA,
	IND_NOTURNA_MANHA,
	IND_CHOQUE_ALUNOS,
	IND_DETALHAR_ALUNOS,
]

# Indicadores marcados por padrão (IND_CHOQUE_ALUNOS fica desligado: depende de hist.csv e é mais pesado).
const INDICADORES_PADRAO: Array[String] = [
	IND_SEM_PROFESSOR,
	IND_CHOQUE,
	IND_CH_EXCEDIDA,
	IND_CARGA,
	IND_NOTURNA_MANHA,
]

func _ready() -> void:
	# Inicializa classes de Complementos
	_dados = ArquivosPlanejamento.new()
	_dados.configurar(file_handling, analise_horarios, analise_grades, horarios_exe, grades_disciplinas_curriculos, delimitadores, diretorio_regras, posicoes_horarios_txt, posicoes_planejamento)

	_ger_alocacoes = GerenciadorAlocacoes.new()
	_ger_alocacoes.configurar($"%GradeHorarios", {}, {}, analise_grades, grades_disciplinas_curriculos)

	_detector = DetectorDeChoques.new()
	_detector.configurar({}, {}, {})

	_verif_carga = VerificadorCarga.new()
	_verif_carga.configurar({}, {})

	_aplicador = AplicadorVisualGrade.new()
	_aplicador.configurar($"%GradeHorarios")

	_relatorios = RelatoriosHorario.new()
	_relatorios.configurar($"%Terminal")

	_posicionador = PosicionadorAutomatico.new()

	$"%PainelDisciplinas".configurar(analise_grades, grades_disciplinas_curriculos, cores_terminal, true, cursos)
	$"%PainelDisciplinas".card_interagido.connect(_on_card_interagido)
	$"%PainelDisciplinas".filtro_alterado.connect(_on_filtro_alterado)
	$"%PainelDisciplinas".filtro_limpo.connect(_on_filtro_limpo)

	# Pre-seleciona o curso do PPC principal, se definido em Configuracoes.
	var ppc: String = GV.configuracao_base.get("ppc_principal", "")
	if not ppc.is_empty():
		for cod_curso in cursos:
			if ppc in cursos[cod_curso].get("grades", []):
				$"%PainelDisciplinas".selecionar_filtro_curso(cod_curso)
				break

	# Configura o seletor de semestre de edicao no topo do modulo.
	$"%FiltroSemestreEdicao".lista_itens = {
		"_Semestre*": ["Todos", "1° semestre", "2° semestre"],
		"_Semestre_retorno": ["", "1", "2"],
	}
	$"%FiltroSemestreEdicao".opcao_selecionada.connect(_on_semestre_edicao_selecionado)
	# Auto-define o semestre de edicao baseado na data.
	var sem_atual: String = GeneralFunctions.semestre_atual()
	$"%FiltroSemestreEdicao".selecionar_item(2 if sem_atual == "1" else 1)

	_seletor_cursos = SeletorCursos.new(self)
	_seletor_cursos.cursos_selecionados.connect(_on_cursos_selecionados_planejamento)

	_seletor_cursos_horario = SeletorCursos.new(self)
	_seletor_cursos_horario.cursos_selecionados.connect(_on_cursos_selecionados_horario)

	_config_posic = ConfigPosicionamento.new(self)
	_config_posic.configuracao_definida.connect(_on_config_posicionamento_definida)

	$"%SeletorPreferencias".lista_itens = {
		"_Indicadores_": INDICADORES_DISPONIVEIS,
	}
	var popup_pref: PopupMenu = $"%SeletorPreferencias".get_node("MenuButton").get_popup()
	for i in INDICADORES_DISPONIVEIS.size():
		popup_pref.set_item_checked(i, INDICADORES_DISPONIVEIS[i] in INDICADORES_PADRAO)
	_indicadores_ativos = INDICADORES_PADRAO.duplicate()
	$"%SeletorPreferencias".selecionar_item(0)
	_configurar_seletor_condicoes_choque()
	var valores_visualizacao: Array = formatos_grade.get("valores", [])
	$"%SeletorVisualizacao".lista_itens = {
		"Nomes e códigos*": formatos_grade.get("rotulos", []),
		"Nomes e códigos_retorno": valores_visualizacao,
		"Filtros_": ["Curso", "Semestre", "Professor"],
		"Filtros_retorno": ["ocultar_curso", "ocultar_semestre", "ocultar_professor"],
	}
	# Dicas dos filtros (ocultar vs. esmaecer). Indice = 1 separador + N formatos + 1 separador.
	var base_filtros: int = valores_visualizacao.size() + 2
	$"%SeletorVisualizacao".definir_dica_item(base_filtros, DicasPrograma.texto(["planejamento_horario", "ocultar_curso"]))
	$"%SeletorVisualizacao".definir_dica_item(base_filtros + 1, DicasPrograma.texto(["planejamento_horario", "ocultar_semestre"]))
	$"%SeletorVisualizacao".definir_dica_item(base_filtros + 2, DicasPrograma.texto(["planejamento_horario", "ocultar_professor"]))
	var idx_visualizacao: int = valores_visualizacao.find("nome_reduzido")
	$"%SeletorVisualizacao".selecionar_item(idx_visualizacao if idx_visualizacao >= 0 else 0)
	var popup_viz: PopupMenu = $"%SeletorVisualizacao".get_node("MenuButton").get_popup()
	for i in popup_viz.get_item_count():
		if popup_viz.is_item_separator(i):
			popup_viz.set_item_text(i, popup_viz.get_item_text(i).trim_suffix("*"))
		# "Curso" começa marcado: mantém a ocultação de outros cursos já existente.
		elif popup_viz.is_item_checkable(i) and popup_viz.get_item_text(i) == "Curso":
			popup_viz.set_item_checked(i, true)
	_dados.carregar_horarios_ini(GV.dir_saida, "horarios.ini")
	_carregar_dados_discentes()
	_limpar_preferencias_grade()
	$"%SeletorImportar".lista_itens = {
		"Locais": ["Abrir planejamento.json", "Abrir planejamento.csv", "Salvar planejamento.json"],
		"Locais_retorno": ["abrir_json", "abrir_csv", "salvar_json"],
		"Importar": ["planejamento.csv", "horarios.txt", "professor.xlsx (.csv)"],
		"Importar_retorno": ["importar_csv", "horarios.txt", "professor.xlsx (.csv)"],
		"Exportar": ["horarios.txt"],
		"Exportar_retorno": ["exportar_horarios_txt"],
		"Servidor": ["Enviar ao servidor", "Baixar do servidor", "Ver outros cursos (referência)…", "Limpar referências", "Configurar servidor…"],
		"Servidor_retorno": ["enviar_servidor", "baixar_servidor", "ver_referencias", "limpar_referencias", "config_servidor"],
	}
	$"%SeletorImportar".opcao_selecionada.connect(_on_importar_opcao_selecionada)

	# Cliente de sincronizacao (Kinto). As credenciais ficam em config_usuario.json:sincronizacao,
	# lidas de GV (mesmo padrao do ppc_principal) e configuradas sob demanda em _garantir_sync_config.
	_sync = SyncKinto.new()
	add_child(_sync)
	# Verifica em segundo plano se ha versao mais recente do curso no servidor (avisa, nao baixa).
	_verificar_atualizacao_servidor.call_deferred()

	var largura_seletor: int = int(config_interface.get("largura_padrao_seletor", 180))
	var altura_seletor: int = 30
	for seletor in [$"%SeletorImportar", $"%SeletorAcoes", $"%FiltroSemestreEdicao"]:
		seletor.custom_minimum_size = Vector2(largura_seletor, altura_seletor)

	$"%SeletorAcoes".lista_itens = {
		"_Ações": ["Posicionar automaticamente", "Limpar preenchimento", "Mesclar horários.txt e planejamento.json (.csv)"],
		"_Ações_retorno": ["posicionar_automatico", "limpar_preenchimento", "atualizar_planejamento"],
	}
	$"%SeletorAcoes".get_node("MenuButton").get_popup().set_item_disabled(2, true)
	$"%SeletorAcoes".definir_dica_item(0, DicasPrograma.texto(["planejamento_horario", "posicionar_automatico"]))
	$"%SeletorAcoes".definir_dica_item(1, DicasPrograma.texto(["planejamento_horario", "limpar_preenchimento"]))
	$"%SeletorAcoes".definir_dica_item(2, DicasPrograma.texto(["planejamento_horario", "mesclar_horarios_planejamento"]))
	$"%SeletorAcoes".opcao_selecionada.connect(_on_acoes_opcao_selecionada)

	$"%StatusBar".definir_segmentos({
		"pendentes": "Pendentes: 0",
		"completas": "Completas: 0",
		"choques": "Choques: 0",
		"alunos_choque": "Alunos em choque: 0",
		"compartilhadas_div": "",
	})

	$"%GradeHorarios".drop_realizado.connect(_on_grade_drop_realizado)
	$"%GradeHorarios".arraste_iniciado.connect(_on_grade_arraste_iniciado)
	$"%GradeHorarios".arraste_terminado.connect(_on_grade_arraste_terminado)

	_menu_celula = PopupMenu.new()
	add_child(_menu_celula)
	_menu_celula.index_pressed.connect(_on_menu_celula_index_pressed)
	$"%GradeHorarios".celula_clicada_direita.connect(_on_grade_celula_clicada_direita)
	$"%GradeHorarios".celula_clicada_meio.connect(_on_grade_celula_clicada_meio)
	$"%GradeHorarios".celula_clicada.connect(_on_grade_celula_clicada)
	# Realce inicial dos botoes OnOff conforme a visibilidade dos paineis.
	TogglePaineis.sincronizar_botoes(_mapa_toggles())



## Reconstrói a grade sem nenhum marcador de preferência de horário.
func _limpar_preferencias_grade() -> void:
	$"%GradeHorarios".larguras_colunas = []
	$"%GradeHorarios".dados = _dados.gerar_matriz_vazia()
	_recalcular_grade(false)

# Faz a leitura do arquivo de regras .csv enviado pelos professores e prepara para exibição.
func _ler_regras_professores(arquivo_selecionado: String) -> void:
	var resultado: Array[Array] = _dados.ler_regras_professores(arquivo_selecionado)
	var matriz_horario: Array[Array] = resultado[0]
	$"%GradeHorarios".larguras_colunas = []
	$"%GradeHorarios".dados = matriz_horario
	_recalcular_grade(false)
	var comentarios: Array[String] = _dados.ler_comentarios_professor(arquivo_selecionado)
	if not comentarios.is_empty():
		$"%Terminal".secao("Regras do professor")
		for c in comentarios:
			var texto: String = c
			if texto.length() > 0:
				texto = texto[0].to_upper() + texto.substr(1)
			$"%Terminal".item(texto)

#region Sinais
func _on_seletor_preferencias_opcao_selecionada(_retorno: String, lista_selecionada: Array[String]) -> void:
	_indicadores_ativos = lista_selecionada
	# Repinta do zero para refletir os indicadores ativos (sem reimprimir relatórios no terminal).
	_recalcular_grade(false)

func _on_seletor_visualizacao_opcao_selecionada(retorno: String, lista_selecionada: Array[String]) -> void:
	match retorno:
		"ocultar_curso", "ocultar_semestre", "ocultar_professor":
			# Toggles do grupo "Filtros": atualiza os três a partir do estado dos checkboxes.
			_ger_alocacoes.ocultar_curso = "ocultar_curso" in lista_selecionada
			_ger_alocacoes.ocultar_semestre = "ocultar_semestre" in lista_selecionada
			_ger_alocacoes.ocultar_professor = "ocultar_professor" in lista_selecionada
		_:
			_ger_alocacoes.modo_visualizacao = retorno
	_recalcular_grade(false)

# Reaplica a grade após mover ou alocar disciplinas. O relato de choques no terminal fica restrito
# às [param celulas_afetadas] (a ação corrente), evitando reportar choques de outras células da grade.
func _refrescar_apos_alocacao(celulas_afetadas: Array[String] = []) -> void:
	_recalcular_grade(true, celulas_afetadas)

# Ponto único de atualização visual da grade: redetecta choques/carga/sem-professor, monta as
# condições por célula (respeitando os indicadores ativos e o foco do filtro) e aplica todas as
# camadas (fundo, barras, cor do texto e tooltip) via AplicadorVisualGrade. Quando [param reportar]
# é true, também escreve os relatórios no terminal. Substitui a antiga pintura espalhada por
# detector/verificador/gerenciador/filtro.
func _recalcular_grade(reportar: bool = true, celulas_relato: Array = []) -> void:
	if not _ger_alocacoes:
		return
	_detector.configurar(_ger_alocacoes.alocacoes, _dados._planejamento_csv, $"%PainelDisciplinas".cards_disciplinas)
	_verif_carga.configurar(_ger_alocacoes.alocacoes, _dados._planejamento_csv)
	_ger_alocacoes.filtro_semestres = $"%PainelDisciplinas".filtro_semestre
	_ger_alocacoes.definir_filtro_professor($"%PainelDisciplinas".filtro_professor)
	_ger_alocacoes.reaplicar_todas()
	var horas: Array[String] = analise_horarios.horas_das_aulas(_dados._horarios_ini)
	# Choque de semestre respeita o filtro de visualização: filtrando um semestre, só alertamos choques
	# desse semestre (reusa _aloc_passa_filtro, o mesmo predicado da pintura/foco). Sem filtro ativo, ele
	# devolve true para tudo — comportamento idêntico ao anterior.
	var painel := $"%PainelDisciplinas"
	var passa_filtro_sem := func(aloc: Dictionary) -> bool:
		return _aloc_passa_filtro(aloc, painel.filtro_curso, painel.filtro_semestre, painel.filtro_professor)
	var res_choques: Dictionary = _detector.detectar([], passa_filtro_sem)
	var res_carga: Dictionary = _verif_carga.verificar(horas, $"%PainelDisciplinas".filtro_professor)
	var sem_prof: Dictionary = _ger_alocacoes.celulas_sem_professor()
	_ultimo_total_choques = res_choques.get("total", 0)
	_ultimo_total_compartilhadas_div = _verificar_compartilhadas_divergentes().size()
	_mapa_condicoes = _montar_mapa_condicoes(res_choques, res_carga, sem_prof)
	for chave_celula in _ger_alocacoes.alocacoes:
		var partes: PackedStringArray = chave_celula.split("_")
		if partes.size() == 2:
			_aplicador.aplicar(int(partes[0]), int(partes[1]), _mapa_condicoes.get(chave_celula, {}))
	_atualizar_choques_alunos()  # também atualiza a barra de status
	if reportar:
		if celulas_relato.is_empty():
			_relatorios.choques(res_choques)
		else:
			_relatorios.choques_em(res_choques, celulas_relato)
		_relatorios.carga(res_carga)
		if IND_SEM_PROFESSOR in _indicadores_ativos:
			_relatorios.sem_professor(sem_prof.size())

# Agrega, por célula alocada, as condições ativas (filtradas pelos indicadores ligados) que
# alimentam o AplicadorVisualGrade e o tooltip. [code]em_foco[/code] vem da lógica de filtro.
func _montar_mapa_condicoes(res_choques: Dictionary, res_carga: Dictionary, sem_prof: Dictionary) -> Dictionary:
	var painel := $"%PainelDisciplinas"
	var tem_filtro: bool = painel.filtro_ativo() or not _filtro_grade_semestre.is_empty()
	var ind_choque := IND_CHOQUE in _indicadores_ativos
	var ind_ch_exc := IND_CH_EXCEDIDA in _indicadores_ativos
	var ind_carga := IND_CARGA in _indicadores_ativos
	var ind_noturna := IND_NOTURNA_MANHA in _indicadores_ativos
	var ind_sem_prof := IND_SEM_PROFESSOR in _indicadores_ativos
	var cel_choque: Dictionary = res_choques.get("celulas_choque", {})
	var cel_ch_exc: Dictionary = res_choques.get("celulas_ch_excedida", {})
	var cel_carga: Dictionary = res_carga.get("celulas_carga", {})
	var cel_noturna: Dictionary = res_carga.get("celulas_noturna", {})
	var mapa: Dictionary = {}
	for chave_celula in _ger_alocacoes.alocacoes:
		var em_foco: bool = false
		for aloc in _ger_alocacoes.alocacoes[chave_celula]:
			if _aloc_passa_filtro(aloc, painel.filtro_curso, painel.filtro_semestre, painel.filtro_professor):
				em_foco = true
				break
		var ch: Dictionary = cel_choque.get(chave_celula, {})
		var destaque_disc: bool = false
		if not _disciplina_destacada.is_empty():
			for a in _ger_alocacoes.alocacoes[chave_celula]:
				if str((a as Dictionary).get("codigo", "")).to_lower() == _disciplina_destacada:
					destaque_disc = true
					break
		var cond: Dictionary = {
			"tem_filtro": tem_filtro,
			"em_foco": em_foco,
			"destaque_disciplina": destaque_disc,
			"sem_professor": ind_sem_prof and sem_prof.has(chave_celula),
			"hora_extra": _celula_tem_extra(chave_celula),
			"choque_prof": ind_choque and ch.get("prof", false),
			"choque_sala": ind_choque and ch.get("sala", false),
			"choque_sem": ind_choque and ch.get("sem", false),
			"ch_excedida": ind_ch_exc and cel_ch_exc.has(chave_celula),
			"carga": ind_carga and cel_carga.has(chave_celula),
			"noturna": ind_noturna and cel_noturna.has(chave_celula),
		}
		cond["tooltip"] = _montar_tooltip_celula(cond)
		mapa[chave_celula] = cond
	return mapa

# Verdadeiro se alguma alocação da célula é hora extra.
func _celula_tem_extra(chave_celula: String) -> bool:
	for aloc in _ger_alocacoes.obter_alocacoes(chave_celula):
		if (aloc as Dictionary).get("is_extra", false):
			return true
	return false

# Monta o BBCode do tooltip de uma célula listando as condições ativas (✕ erro, ⚠ aviso). Vazio
# quando não há alerta ou quando a célula está fora do foco do filtro (espelha a pintura).
func _montar_tooltip_celula(cond: Dictionary) -> String:
	if cond.get("tem_filtro", false) and not cond.get("em_foco", true):
		return ""
	var hex_erro := PaletaSemantica.cor_hex("erro")
	var hex_aviso := PaletaSemantica.cor_hex("aviso")
	var linhas: Array[String] = []
	if cond.get("sem_professor", false):
		linhas.append("[color=%s]✕ Sem professor[/color]" % hex_erro)
	if cond.get("choque_prof", false):
		linhas.append("[color=%s]⚠ Choque de professor[/color]" % hex_erro)
	if cond.get("choque_sem", false):
		linhas.append("[color=%s]⚠ Choque de semestre[/color]" % hex_erro)
	if cond.get("choque_sala", false):
		linhas.append("[color=%s]⚠ Choque de sala[/color]" % hex_aviso)
	if cond.get("carga", false):
		linhas.append("[color=%s]⚠ Carga ≥6h no mesmo dia[/color]" % hex_aviso)
	if cond.get("noturna", false):
		linhas.append("[color=%s]⚠ Noturna → manhã[/color]" % hex_aviso)
	if cond.get("ch_excedida", false):
		linhas.append("[color=%s]⚠ CH excedida[/color]" % hex_aviso)
	if cond.get("hora_extra", false):
		linhas.append("[color=%s]Hora extra[/color]" % hex_aviso)
	return "\n".join(linhas)

func _on_importar_horarios_button_up() -> void:
	if _dados.carregar_horarios_txt(GV.dir_saida):
		var converted: Array = horarios_exe.exportar_horariostxt(_dados._horarios_txt_lista["horarios"])
		_dados.imprimir_horarios_txt($"%Terminal", converted, "padrao")
	else:
		$"%Terminal".text_edit("Arquivo \"horarios.txt\" não foi lido corretamente!", "padrao", false, true)
	_popular_grade_do_txt()

func _popular_grade_do_txt(prefixos: Array[String] = []) -> void:
	var grade: GradeVisual = $"%GradeHorarios"
	var dias: Array[String] = analise_horarios.dias_da_semana(_dados._horarios_ini)
	var horas: Array[String] = analise_horarios.horas_das_aulas(_dados._horarios_ini)
	var plano: Dictionary = _dados.preparar_alocacoes_do_txt(GV.dir_saida + "horarios.txt", \
		dias, horas, grade._linhas, grade._colunas, $"%PainelDisciplinas".cards_disciplinas.keys(), prefixos)
	if not plano["valido"]:
		return

	# Limpa a grade e as alocações atuais antes de repopular.
	for chave_celula in _ger_alocacoes.alocacoes:
		var partes: PackedStringArray = chave_celula.split("_")
		_ger_alocacoes.limpar_celula(int(partes[0]), int(partes[1]))
	_ger_alocacoes.limpar_alocacoes()
	for card in $"%PainelDisciplinas".cards_disciplinas.values():
		card.ch_alocada = 0

	for info in plano["cards_novos"]:
		var profs: Array[String] = []
		profs.assign(info["profs"])
		$"%PainelDisciplinas".popular_card_extra(info["codigo"], info["nome"], profs, \
			[str(info["ch_total"])], info["sem"], info["chave"])

	for item in plano["alocacoes"]:
		var chave_celula := "%d_%d" % [item["linha"], item["coluna"]]
		_ger_alocacoes.alocar(chave_celula, item["aloc"])
		var card: CardDisciplina = $"%PainelDisciplinas".cards_disciplinas.get(item["chave"])
		if card:
			card.ch_alocada += 1

	# Sincroniza referências após popular cards extras
	_sincronizar_referencias()
	_ger_alocacoes.reaplicar_todas()
	_detectar_choques()

	var msg: String = "Grade preenchida: " + str(plano["alocacoes"].size()) + " alocações"
	if plano["cards_novos"].size() > 0:
		msg += ", " + str(plano["cards_novos"].size()) + " novas disciplinas"
	if plano["ignoradas"] > 0:
		msg += ", " + str(plano["ignoradas"]) + " ignoradas"
	$"%Terminal".text_edit(msg + ".", "sucesso", true, false)

# Abre o dialogo modal de selecao de cursos antes da leitura do planejamento.csv. A leitura
# efetiva acontece em _on_cursos_selecionados_planejamento, ao confirmar a selecao.
func _abrir_janela_selecao_cursos_planejamento() -> void:
	if cursos.is_empty():
		$"%Terminal".text_edit("Nenhum curso cadastrado em base_config.json:cursos.", \
			"erro", true, true)
		return
	var pre: Array = _cursos_marcados_planejamento.duplicate()
	var ppc: String = GV.configuracao_base.get("ppc_principal", "")
	if not ppc.is_empty():
		for cod_curso in cursos:
			if ppc in cursos[cod_curso].get("grades", []):
				if not pre.has(cod_curso):
					pre.append(cod_curso)
				break
	_seletor_cursos.abrir(cursos, pre)


# Reune os prefixos de semestre dos cursos selecionados e dispara a importacao.
func _on_cursos_selecionados_planejamento(cods: Array[String]) -> void:
	if cods.is_empty():
		$"%Terminal".text_edit("Nenhum curso selecionado — importacao cancelada.", \
			"aviso", true, true)
		return
	_cursos_marcados_planejamento = cods.duplicate()
	var prefixos: Array[String] = []
	for cod in cods:
		var lista_prefixos: Array = cursos.get(cod, {}).get("prefixos_semestre", [])
		for p in lista_prefixos:
			var s: String = str(p)
			if not s.is_empty() and not s in prefixos:
				prefixos.append(s)
	if prefixos.is_empty():
		$"%Terminal".text_edit("Cursos selecionados nao possuem prefixos_semestre em base_config.json.", \
			"erro", true, true)
		return
	_importar_planejamento_csv(prefixos)


func _importar_planejamento_csv(prefixos_semestre: Array[String]) -> void:
	if _dados.carregar_planejamento(GV.dir_saida, prefixos_semestre):
		_dados.adicionar_planejamento()
		# Aviso agregado: disciplinas do planejamento que nao constam em nenhuma grade carregada.
		# Mostra "codigo (Nome)" usando o nome embutido no proprio planejamento.csv.
		var nome_por_codigo: Dictionary = {}
		for k in _dados._planejamento_csv:
			var dk: Dictionary = _dados._planejamento_csv[k]
			nome_por_codigo[str(dk.get("codigo", ""))] = str(dk.get("nome_csv", ""))
		var sem_grade: Array[String] = analise_grades.codigos_ausentes(grades_disciplinas_curriculos, nome_por_codigo.keys())
		if not sem_grade.is_empty():
			var itens: Array[String] = []
			for cod in sem_grade:
				var nm: String = str(nome_por_codigo.get(cod, "")).capitalize()
				itens.append(cod + (" (" + nm + ")" if nm != "" else ""))
			$"%Terminal".text_edit("Disciplinas do planejamento sem grade carregada: " \
				+ ", ".join(itens) + " — confira se falta um arquivo de grade ou se o codigo esta correto.", \
				"aviso", true, false)
		var converted: Array = horarios_exe.exportar_horariostxt(_dados._horarios_txt_lista["planejamento"])
		_dados.imprimir_horarios_txt($"%Terminal", converted, "padrao")
		_sincronizar_referencias()
		$"%PainelDisciplinas".popular(_dados._planejamento_csv, $"%Terminal", false)
		_sincronizar_referencias()
	else:
		$"%Terminal".text_edit("Arquivo \"planejamento.csv\" não foi lido corretamente!", "padrao", false, true)


func _abrir_janela_selecao_cursos_horario() -> void:
	if cursos.is_empty():
		$"%Terminal".text_edit("Nenhum curso cadastrado em base_config.json:cursos.", \
			"erro", true, true)
		return
	var pre: Array = []
	var ppc: String = GV.configuracao_base.get("ppc_principal", "")
	if not ppc.is_empty():
		for cod_curso in cursos:
			if ppc in cursos[cod_curso].get("grades", []):
				if not pre.has(cod_curso):
					pre.append(cod_curso)
				break
	_seletor_cursos_horario.abrir(cursos, pre)


func _on_cursos_selecionados_horario(cods: Array[String]) -> void:
	if cods.is_empty():
		$"%Terminal".text_edit("Nenhum curso selecionado — importacao cancelada.", \
			"aviso", true, true)
		return
	var prefixos: Array[String] = []
	for cod in cods:
		var lista_prefixos: Array = cursos.get(cod, {}).get("prefixos_semestre", [])
		for p in lista_prefixos:
			var s: String = str(p)
			if not s.is_empty() and not s in prefixos:
				prefixos.append(s)
	if prefixos.is_empty():
		$"%Terminal".text_edit("Cursos selecionados nao possuem prefixos_semestre em base_config.json.", \
			"erro", true, true)
		return
	_importar_horarios_com_prefixos(prefixos)


func _importar_horarios_com_prefixos(prefixos: Array[String]) -> void:
	if not _dados.carregar_horarios_txt(GV.dir_saida):
		$"%Terminal".text_edit("Arquivo \"horarios.txt\" não foi lido corretamente!", "padrao", false, true)
		return
	var converted: Array = horarios_exe.exportar_horariostxt(_dados._horarios_txt_lista["horarios"])
	_dados.imprimir_horarios_txt($"%Terminal", converted, "padrao")
	_popular_grade_do_txt(prefixos)


func _on_mesclar_csv_e_txt_button_up() -> void:
	var caminho_txt: String = GV.dir_saida + "horarios.txt"
	if not FileAccess.file_exists(caminho_txt):
		$"%Terminal".text_edit("Arquivo horarios.txt não encontrado em " + caminho_txt + ".", \
			"erro", true, false)
		return
	if _dados._planejamento_csv.size() == 0:
		$"%Terminal".text_edit("Nenhum planejamento carregado. Importe o planejamento.csv primeiro.", \
			"aviso", true, false)
		return
	var resultado: Dictionary = _dados.mesclar_planejamento_com_horarios_txt(caminho_txt)
	# Escreve merge base (sem removidas).
	_dados.escrever_horarios_txt(resultado["entries"], diretorio_exportacao, $"%Terminal", cores_terminal)
	_recarregar_horarios_txt_apos_merge(resultado["entries"])
	# Pergunta sobre removidas.
	if resultado["removidas"].size() > 0:
		var msg: String = "Disciplinas abaixo não estão no planejamento atual:\n"
		for chave in resultado["removidas"]:
			msg += "  - " + chave + "\n"
		msg += "\nDeseja incluí-las novamente no horarios.txt?"
		Dialogos.confirmar(self, "Disciplinas Removidas", msg, \
			func():
				var entries: Array = resultado["entries"].duplicate()
				for e in resultado["entries_removidas"]:
					entries.append(e)
				_dados.escrever_horarios_txt(entries, diretorio_exportacao, $"%Terminal", cores_terminal)
				_recarregar_horarios_txt_apos_merge(entries),
			"Incluir", "Ignorar")


# Atualiza _horarios_txt_lista["horarios"] e reimprime no terminal após merge.
func _recarregar_horarios_txt_apos_merge(entries: Array) -> void:
	_dados._horarios_txt_lista["horarios"] = horarios_exe.exportar_horariostxt(entries)
	var converted: Array = horarios_exe.exportar_horariostxt(entries)
	_dados.imprimir_horarios_txt($"%Terminal", converted, "padrao")

func _on_exportar_button_up() -> void:
	_dados.exportar_horarios(diretorio_exportacao, _ger_alocacoes.alocacoes, grades_disciplinas_curriculos, $"%Terminal", cores_terminal)

# Mapa botao OnOff -> painel que ele controla. Base unica para alternar (Shift+clique isola/restaura)
# e para o realce: o botao fica "afundado" (toggle_mode) quando seu painel esta visivel.
func _mapa_toggles() -> Dictionary:
	return {
		$"%OnOffTerminal": $"%Terminal",
		$"%OnOffHorarios": $"%Horarios",
		$"%OnOffPainel": $"%PainelDisciplinas",
	}

func _toggle(alvo: Control) -> void:
	var mapa := _mapa_toggles()
	TogglePaineis.aplicar(mapa.values(), alvo, Input.is_key_pressed(KEY_SHIFT))
	TogglePaineis.sincronizar_botoes(mapa)

func _on_on_off_terminal_button_up() -> void:
	_toggle($"%Terminal")

func _on_on_off_horarios_button_up() -> void:
	_toggle($"%Horarios")

func _on_on_off_painel_button_up() -> void:
	_toggle($"%PainelDisciplinas")

# Repassa a selecao do FiltroSemestreEdicao (no topo) para o painel de disciplinas.
func _on_semestre_edicao_selecionado(_retorno: String, lista_selecionada: Array[String]) -> void:
	var sem: String = lista_selecionada[0] if lista_selecionada.size() > 0 else ""
	var mapa_texto: Dictionary = {"": "Semestre", "1": "1° semestre", "2": "2° semestre"}
	$"%FiltroSemestreEdicao".texto_padrao = mapa_texto.get(sem, "Semestre")
	$"%PainelDisciplinas".definir_semestre_edicao(sem)

## Reage à alteração de filtro no PainelDisciplinas, aplicando a grade e indicadores.
func _on_filtro_alterado(_filtros: Dictionary) -> void:
	_filtro_grade_semestre = ""
	_disciplina_destacada = ""
	_ger_alocacoes.definir_filtro_professor($"%PainelDisciplinas".filtro_professor)
	_sincronizar_filtro_curso_grade()
	_carregar_preferencias_do_filtro()
	_sincronizar_destaque_semestre()
	_aplicar_filtro_grade(_ger_alocacoes.alocacoes)


## Carrega as preferências de horário do professor selecionado no filtro do painel.
## Se o filtro estiver em "Todos", limpa a grade; caso contrário, busca o CSV do
## professor e exibe a grade colorida com suas preferências.
func _carregar_preferencias_do_filtro() -> void:
	var prof_filtro: String = $"%PainelDisciplinas".filtro_professor
	if prof_filtro.is_empty():
		_limpar_preferencias_grade()
		return
	var arquivo: String = _arquivo_preferencias_de(prof_filtro)
	if not arquivo.is_empty():
		_ler_regras_professores(arquivo)
	else:
		_limpar_preferencias_grade()


## Reage ao limpar dos filtros do PainelDisciplinas.
func _on_filtro_limpo() -> void:
	_filtro_grade_semestre = ""
	_disciplina_destacada = ""
	_sincronizar_filtro_curso_grade()
	_sincronizar_destaque_semestre()
	_carregar_preferencias_do_filtro()
	_aplicar_filtro_grade(_ger_alocacoes.alocacoes)


# Sincroniza o filtro de curso da grade (oculta nomes de disciplinas de outros cursos em
# sobreposições) com o filtro de curso do painel: passa ao gerenciador os prefixos de semestre
# do curso ativo (ex.: ["EC"]), ou vazio quando não há curso filtrado.
func _sincronizar_filtro_curso_grade() -> void:
	var fc: String = $"%PainelDisciplinas".filtro_curso
	var prefixos: Array[String] = []
	if not fc.is_empty():
		for p in cursos.get(fc, {}).get("prefixos_semestre", []):
			prefixos.append(str(p).to_upper())
	_ger_alocacoes.curso_filtro_prefixos = prefixos

# Sincroniza o destaque de semestre da grade (clique em card / arraste, que oculta outros semestres
# em sobreposições) e o filtro de semestre do painel. O filtro do painel é tratado pelos toggles da
# Visualização (ocultar/esmaecer), separado do destaque temporário do arraste.
func _sincronizar_destaque_semestre() -> void:
	_ger_alocacoes.semestre_filtro = _filtro_grade_semestre
	_ger_alocacoes.filtro_semestres = $"%PainelDisciplinas".filtro_semestre
	_ger_alocacoes.reaplicar_todas()


## Ao interagir com um card (clique ou arrasto): seleciona as preferências de horário do
## primeiro professor com cadastro e destaca o semestre do card apenas na grade.
func _on_card_interagido(card: CardDisciplina) -> void:
	# Clicar em um card destaca apenas as células daquela disciplina (verde claro) na grade.
	# _selecionar_preferencias_do_card recalcula a grade (e já usa o destaque recém-definido).
	_disciplina_destacada = card.codigo.to_lower()
	_selecionar_preferencias_do_card(card)

# Seleciona o arquivo de preferências de horário do primeiro professor do card com cadastro.
func _selecionar_preferencias_do_card(card: CardDisciplina) -> void:
	if card.professores.size() == 0:
		_limpar_preferencias_grade()
		return
	for prof in card.professores:
		var arquivo: String = _arquivo_preferencias_de(prof)
		if not arquivo.is_empty():
			_ler_regras_professores(arquivo)
			return
	_limpar_preferencias_grade()

# Localiza o arquivo CSV de preferências cujo nome casa com [param nome_prof] (correspondência por
# substring, sem diferenciar caixa), ou "" se nenhum. Reusado pela seleção visual ao interagir com
# um card e pelo posicionamento automático ([method _montar_preferencias_professores]).
func _arquivo_preferencias_de(nome_prof: String) -> String:
	var dir := DirAccess.open(diretorio_regras)
	if not dir:
		return ""
	var alvo: String = nome_prof.to_lower()
	for f in dir.get_files():
		if not f.to_lower().ends_with(".csv"):
			continue
		var base: String = f.trim_suffix(".csv").to_lower()
		if base in alvo or alvo in base:
			return f
	return ""

# Destaca apenas o semestre [param sem] na grade (sem alterar a lista de disciplinas):
# reaplica o texto das células (ocultando outros semestres em sobreposições) e a coloração.
func _aplicar_filtro_grade_semestre(sem: String) -> void:
	_filtro_grade_semestre = sem
	_sincronizar_destaque_semestre()
	_aplicar_filtro_grade(_ger_alocacoes.alocacoes)

func _on_timer_timeout() -> void:
	if _dados._horarios_txt_lista.get("horarios", []).size() > 0 and _dados._horarios_txt_lista.get("planejamento", []).size() > 0:
		$"%SeletorAcoes".get_node("MenuButton").get_popup().set_item_disabled(2, false)

# Ao iniciar o arrasto de uma célula, prepara a grade para revelar onde a disciplina pode entrar
# sem choque, conforme os filtros ativos: [br]
# - só professor: mantém as disciplinas do professor em destaque (verde) e [b]hachura[/b] os
#   horários do semestre da disciplina (choque de semestre a evitar); [br]
# - só semestre: destaca o semestre (verde) e [b]hachura[/b] os horários do professor da disciplina
#   (choque de professor a evitar); [br]
# - nenhum: destaca o semestre da disciplina (padrão); [br]
# - ambos: mantém professor + semestre (não força destaque nem hachura).
func _on_grade_arraste_iniciado(linha: int, coluna: int) -> void:
	var arr: Array = _ger_alocacoes.obter_alocacoes("%d_%d" % [linha, coluna])
	if arr.is_empty():
		return
	var aloc: Dictionary = arr[_indice_com_filtro(arr)]
	var card: CardDisciplina = $"%PainelDisciplinas".cards_disciplinas.get(aloc.get("chave", ""), null)
	if not card:
		return
	var prof_ativo: bool = not $"%PainelDisciplinas".filtro_professor.is_empty()
	var sem_ativo: bool = $"%PainelDisciplinas".filtro_semestre.size() > 0
	if prof_ativo and not sem_ativo:
		_aplicar_hachura(_celulas_do_semestre(card.semestre, linha, coluna))
	elif sem_ativo and not prof_ativo:
		_aplicar_filtro_grade_semestre(card.semestre)
		_aplicar_hachura(_celulas_do_professor(_profs_da_aloc(aloc), linha, coluna))
	elif not prof_ativo and not sem_ativo:
		_aplicar_filtro_grade_semestre(card.semestre)

# Ao terminar o arrasto (drop ou cancelamento), remove a hachura de todas as células.
func _on_grade_arraste_terminado() -> void:
	var grade: GradeVisual = $"%GradeHorarios"
	for chave_celula in _ger_alocacoes.alocacoes:
		var partes: PackedStringArray = chave_celula.split("_")
		if partes.size() != 2:
			continue
		var cel: Celula = grade.get_celula(int(partes[0]), int(partes[1]))
		if cel:
			cel.hachurado = false

# Aplica hachura nas células de [param celulas] ("linha_coluna" → true) e a remove das demais.
func _aplicar_hachura(celulas: Dictionary) -> void:
	var grade: GradeVisual = $"%GradeHorarios"
	for chave_celula in _ger_alocacoes.alocacoes:
		var partes: PackedStringArray = chave_celula.split("_")
		if partes.size() != 2:
			continue
		var cel: Celula = grade.get_celula(int(partes[0]), int(partes[1]))
		if cel:
			cel.hachurado = celulas.has(chave_celula)

# Células ocupadas por alguma disciplina do semestre [param sem] (string exata, como o detector de
# choques), exceto a célula de origem do arraste.
func _celulas_do_semestre(sem: String, linha_orig: int, coluna_orig: int) -> Dictionary:
	var resultado: Dictionary = {}
	var sl: String = sem.to_lower()
	var origem: String = "%d_%d" % [linha_orig, coluna_orig]
	for chave_celula in _ger_alocacoes.alocacoes:
		if chave_celula == origem:
			continue
		for a in _ger_alocacoes.alocacoes[chave_celula]:
			if _semestre_da_aloc(a as Dictionary).to_lower() == sl:
				resultado[chave_celula] = true
				break
	return resultado

# Células ocupadas por algum dos [param profs] (minúsculo), exceto a célula de origem do arraste.
func _celulas_do_professor(profs: Array, linha_orig: int, coluna_orig: int) -> Dictionary:
	var resultado: Dictionary = {}
	var alvo: Dictionary = {}
	for p in profs:
		alvo[str(p).to_lower()] = true
	var origem: String = "%d_%d" % [linha_orig, coluna_orig]
	for chave_celula in _ger_alocacoes.alocacoes:
		if chave_celula == origem:
			continue
		for a in _ger_alocacoes.alocacoes[chave_celula]:
			var achou: bool = false
			for ap in _dados._planejamento_csv.get((a as Dictionary).get("chave", ""), {}).get("professor", []):
				if alvo.has(str(ap).to_lower()):
					achou = true
					break
			if achou:
				resultado[chave_celula] = true
				break
	return resultado

# Professores da alocação (do planejamento.csv, com fallback para o card).
func _profs_da_aloc(aloc: Dictionary) -> Array:
	var p: Array = _dados._planejamento_csv.get(aloc.get("chave", ""), {}).get("professor", [])
	if p.is_empty():
		var card: CardDisciplina = $"%PainelDisciplinas".cards_disciplinas.get(aloc.get("chave", ""))
		if card:
			return card.professores
	return p

# Semestre de uma alocação (do planejamento.csv, com fallback para o card).
func _semestre_da_aloc(aloc: Dictionary) -> String:
	var s: String = _dados._planejamento_csv.get(aloc.get("chave", ""), {}).get("semestre", "")
	if s.is_empty():
		var card: CardDisciplina = $"%PainelDisciplinas".cards_disciplinas.get(aloc.get("chave", ""))
		if card:
			s = card.semestre
	return s

# Verdadeiro se a alocação/disciplina é de outro curso sobreposto como referência (somente-leitura).
# Consulta tanto o marcador na própria alocação quanto a entrada de _planejamento_csv pela chave.
func _aloc_e_referencia(aloc: Dictionary) -> bool:
	if aloc.get("referencia", false):
		return true
	return _dados._planejamento_csv.get(aloc.get("chave", ""), {}).get("referencia", false)

func _on_grade_drop_realizado(linha: int, coluna: int, dados: Dictionary) -> void:
	if linha == 0 or coluna == 0:
		return
	# Reseta o terminal a cada movimentação na grade, para mostrar apenas o resultado desta ação.
	$"%Terminal".text_edit("", "padrao", false, true)
	var shift: bool = dados.get("shift_pressed", false) or Input.is_key_pressed(KEY_SHIFT)
	if dados.get("origem", "") == "celula":
		var linha_orig: int = dados.get("linha_origem", -1)
		var coluna_orig: int = dados.get("coluna_origem", -1)
		var chave_orig := "%d_%d" % [linha_orig, coluna_orig]
		var arr_orig: Array = _ger_alocacoes.obter_alocacoes(chave_orig)
		if arr_orig.is_empty():
			return
		var idx: int = _indice_com_filtro(arr_orig)
		var aloc: Dictionary = arr_orig[idx]
		if _aloc_e_referencia(aloc):
			$"%Terminal".text_edit("%s é de outro curso (somente-leitura): não pode ser movida." \
				% str(aloc.get("codigo", "?")).to_upper(), "aviso", true, false)
			return
		var chave_card: String = aloc.get("chave", "")
		var card_src: CardDisciplina = $"%PainelDisciplinas".cards_disciplinas.get(chave_card, null)
		# O bloco é seguido pela chave da disciplina escolhida por _indice_com_filtro,
		# então funciona mesmo com filtro ativo: move apenas a disciplina filtrada,
		# preservando outras sobrepostas na mesma célula.
		var pode_shift: bool = shift and card_src != null
		if pode_shift:
			_mover_bloco_celulas(linha_orig, coluna_orig, linha, coluna, chave_card)
			return
		else:
			if linha_orig == linha and coluna_orig == coluna:
				return
			_ger_alocacoes.remover_indice(chave_orig, idx)
			_ger_alocacoes.limpar_celula(linha_orig, coluna_orig)
			if arr_orig.size() > 0:
				_ger_alocacoes.atualizar_celula(linha_orig, coluna_orig)
			var chave_dest := "%d_%d" % [linha, coluna]
			_ger_alocacoes.alocar(chave_dest, aloc)
			_ger_alocacoes.atualizar_celula(linha, coluna)
			_refrescar_apos_alocacao([chave_orig, chave_dest])
			$"%Terminal".text_edit("Movido: %s → [%d, %d]." % \
				[aloc.get("codigo", "?").to_upper(), linha, coluna], \
				"sucesso", true, false)
			_reportar_choques_alunos_celulas([[linha, coluna]])
			return
	var chave: String = dados.get("chave", "")
	var codigo: String = dados.get("codigo", "")
	if chave.is_empty():
		return
	var card: CardDisciplina = $"%PainelDisciplinas".cards_disciplinas.get(chave, null)
	if not card:
		return
	if _dados._planejamento_csv.get(chave, {}).get("referencia", false):
		$"%Terminal".text_edit("%s é de outro curso (somente-leitura): não pode ser alocada aqui." \
			% codigo.to_upper(), "aviso", true, false)
		return
	if card.ch_alocada >= card.ch_total and not card.permite_extra:
		$"%Terminal".text_edit("Disciplina %s já com CH completa (%d/%d)." % \
			[codigo.to_upper(), card.ch_alocada, card.ch_total], \
			"aviso", true, false)
		return
	var modo_extra: bool = card.permite_extra
	var ch_restante: int = 1 if modo_extra else card.ch_total - card.ch_alocada
	var grade_vis: GradeVisual = $"%GradeHorarios"
	var slots_alocados: int = 0
	var linha_atual := linha
	while linha_atual < grade_vis._linhas and slots_alocados < ch_restante:
		var chave_celula := "%d_%d" % [linha_atual, coluna]
		var aloc_data: Dictionary = {
			"chave": chave,
			"codigo": codigo,
			"sala": "Sem Sala",
			"tipo": "Teorica",
			"turma": "T20",
			"vagas": "Vagas",
			"p": "1",
			"s": "1",
			"t": "1",
		}
		if modo_extra:
			aloc_data["is_extra"] = true
		_ger_alocacoes.alocar(chave_celula, aloc_data)
		slots_alocados += 1
		linha_atual += 1
		if not shift or modo_extra:
			break
	if slots_alocados == 0:
		return
	# Reseta permite_extra ANTES de mexer em ch_alocada: o setter de ch_alocada dispara
	# _atualizar_visual(), que recalcula a visibilidade do BtnHoraExtra. Se permite_extra
	# ainda estivesse true aqui, o botão ficaria oculto e a hora extra só poderia ser usada
	# uma vez. Resetando antes, o botão reaparece e permite novas horas extras.
	if modo_extra:
		card.permite_extra = false
		card.ch_extra += slots_alocados
	card.ch_alocada += slots_alocados
	for i in slots_alocados:
		_ger_alocacoes.atualizar_celula(linha + i, coluna)
	var afetadas: Array[String] = []
	for i in slots_alocados:
		afetadas.append("%d_%d" % [linha + i, coluna])
	if modo_extra:
		$"%Terminal".text_edit("Hora extra: %s → [%d, %d] (%d/%dh +%d extra)." % \
			[codigo.to_upper(), linha, coluna, card.ch_alocada, card.ch_total, card.ch_extra], \
			"sucesso", true, false)
	elif shift and slots_alocados > 1:
		$"%Terminal".text_edit("Alocado (Shift): %s → %dh [%d-%d, %d] (%d/%dh)." % \
			[codigo.to_upper(), slots_alocados, linha, linha + slots_alocados - 1, coluna, card.ch_alocada, card.ch_total], \
			"sucesso", true, false)
	else:
		$"%Terminal".text_edit("Alocado: %s → [%d, %d] (%d/%dh)." % \
			[codigo.to_upper(), linha, coluna, card.ch_alocada, card.ch_total], \
			"sucesso", true, false)
	_refrescar_apos_alocacao(afetadas)
	var celulas_novas: Array = []
	for i in slots_alocados:
		celulas_novas.append([linha + i, coluna])
	_reportar_choques_alunos_celulas(celulas_novas)

# Clique do meio: remove as alocações da célula (anteriormente era o clique direito).
func _on_grade_celula_clicada_meio(linha: int, coluna: int) -> void:
	if linha == 0 or coluna == 0:
		return
	var chave_celula := "%d_%d" % [linha, coluna]
	var arr: Array = _ger_alocacoes.obter_alocacoes(chave_celula)
	if arr.is_empty():
		return
	# Remove apenas as SUAS alocações; as de referência (outro curso) são somente-leitura e ficam.
	var codigos: Array[String] = []
	var mantidas: Array = []
	for a_dict in arr:
		var aloc: Dictionary = a_dict
		if _aloc_e_referencia(aloc):
			mantidas.append(aloc)
			continue
		var card: CardDisciplina = $"%PainelDisciplinas".cards_disciplinas.get(aloc.get("chave", ""), null)
		if card:
			card.ch_alocada -= 1
			if aloc.get("is_extra", false):
				card.ch_extra -= 1
		codigos.append(aloc.get("codigo", "?").to_upper())
	if codigos.is_empty():
		$"%Terminal".text_edit("Alocação de outro curso (somente-leitura): use 'Limpar referências' para removê-la.", \
			"aviso", true, false)
		return
	_ger_alocacoes.limpar_celula(linha, coluna)
	if mantidas.is_empty():
		_ger_alocacoes.remover(chave_celula)
	else:
		_ger_alocacoes.alocacoes[chave_celula] = mantidas
		_ger_alocacoes.atualizar_celula(linha, coluna)
	var codigos_str: String = " + ".join(codigos)
	$"%Terminal".text_edit("Removida alocação: %s ← [%d, %d]." % \
		[codigos_str, linha, coluna], \
		"aviso", true, false)
	_detectar_choques()

func _indice_com_filtro(arr: Array) -> int:
	if arr.size() <= 1:
		return 0
	var painel := $"%PainelDisciplinas"
	if not painel.filtro_ativo() and _filtro_grade_semestre.is_empty():
		return 0
	for i in arr.size():
		if _aloc_passa_filtro(arr[i], painel.filtro_curso, painel.filtro_semestre, painel.filtro_professor):
			return i
	return 0

# Indica se a alocação [param aloc] satisfaz os filtros de curso, semestre e professor informados.
func _aloc_passa_filtro(aloc: Dictionary, filtro_curso: String, filtro_semestre: Array, filtro_professor: String) -> bool:
	var chave_aloc: String = aloc.get("chave", "")
	var dados_csv: Dictionary = _dados._planejamento_csv.get(chave_aloc, {})
	var sem: String = dados_csv.get("semestre", "")
	if sem.is_empty():
		sem = aloc.get("semestre", "")
	if sem.is_empty():
		var card: CardDisciplina = $"%PainelDisciplinas".cards_disciplinas.get(chave_aloc)
		if card:
			sem = card.semestre
	# O destaque de semestre da grade tem precedência sobre o filtro de semestre do painel:
	# quando ativo, substitui (não soma a) a checagem de semestre, senão filtros de semestres
	# diferentes se anulariam e apagariam todas as células.
	if not _filtro_grade_semestre.is_empty():
		if sem.to_lower() != _filtro_grade_semestre.to_lower():
			return false
	elif filtro_semestre.size() > 0:
		var sem_lower: String = sem.to_lower()
		var bateu: bool = false
		for fs in filtro_semestre:
			if sem_lower == fs.to_lower():
				bateu = true
				break
		if not bateu:
			return false
	if not filtro_curso.is_empty() and not $"%PainelDisciplinas".semestre_pertence_ao_curso(sem, filtro_curso):
		return false
	if not filtro_professor.is_empty():
		var tem_prof: bool = false
		for p in dados_csv.get("professor", []):
			if str(p) == filtro_professor:
				tem_prof = true
				break
		if not tem_prof:
			tem_prof = str(aloc.get("professor", "")).to_lower() == filtro_professor.to_lower()
		if not tem_prof:
			return false
	return true

func _mover_bloco_celulas(linha_orig: int, coluna_orig: int, linha_dest: int, coluna_dest: int, chave_card: String) -> void:
	var grade_vis: GradeVisual = $"%GradeHorarios"
	var linhas_origem: Array[int] = []
	var r := linha_orig
	while r < grade_vis._linhas:
		var chave_cel := "%d_%d" % [r, coluna_orig]
		var arr: Array = _ger_alocacoes.obter_alocacoes(chave_cel)
		if arr.is_empty():
			break
		var bateu: bool = false
		for a_d in arr:
			if (a_d as Dictionary).get("chave", "") == chave_card:
				bateu = true
				break
		if bateu:
			linhas_origem.append(r)
			r += 1
		else:
			break
	if linhas_origem.is_empty():
		return
	var n: int = linhas_origem.size()
	if linha_dest + n > grade_vis._linhas:
		$"%Terminal".text_edit("Não há espaço para mover %d células a partir da linha %d." % [n, linha_dest],
			"erro", true, false)
		return
	var alocacoes_mover: Array[Dictionary] = []
	for r_orig in linhas_origem:
		var chave_cel := "%d_%d" % [r_orig, coluna_orig]
		var arr_orig: Array = _ger_alocacoes.obter_alocacoes(chave_cel)
		var idx_alvo: int = 0
		for j in arr_orig.size():
			if (arr_orig[j] as Dictionary).get("chave", "") == chave_card:
				idx_alvo = j
				break
		alocacoes_mover.append(arr_orig[idx_alvo])
		_ger_alocacoes.remover_indice(chave_cel, idx_alvo)
		_ger_alocacoes.limpar_celula(r_orig, coluna_orig)
		_ger_alocacoes.atualizar_celula(r_orig, coluna_orig)
	# Empilha cada célula no destino (sem apagar o que já existe lá): células
	# podem conter alocações sobrepostas; eventuais conflitos são sinalizados
	# pelo detector de choques, não removidos silenciosamente.
	for i in n:
		var chave_dest := "%d_%d" % [linha_dest + i, coluna_dest]
		_ger_alocacoes.alocar(chave_dest, alocacoes_mover[i])
		_ger_alocacoes.atualizar_celula(linha_dest + i, coluna_dest)
	var afetadas_bloco: Array[String] = []
	for r_orig in linhas_origem:
		afetadas_bloco.append("%d_%d" % [r_orig, coluna_orig])
	for i in n:
		afetadas_bloco.append("%d_%d" % [linha_dest + i, coluna_dest])
	_refrescar_apos_alocacao(afetadas_bloco)
	$"%Terminal".text_edit("Bloco movido (Shift): %d células → [%d-%d, %d]." %
		[n, linha_dest, linha_dest + n - 1, coluna_dest],
		"sucesso", true, false)
	var celulas_bloco: Array = []
	for i in n:
		celulas_bloco.append([linha_dest + i, coluna_dest])
	_reportar_choques_alunos_celulas(celulas_bloco)

# Clique esquerdo: mesmo efeito de soltar uma disciplina — reseta o terminal e apresenta os choques
# de horário das disciplinas presentes na célula clicada. (Comportamento será expandido futuramente.)
func _on_grade_celula_clicada(linha: int, coluna: int) -> void:
	if linha == 0 or coluna == 0:
		return
	$"%Terminal".text_edit("", "padrao", false, true)
	_reportar_choques_alunos_celulas([[linha, coluna]])

# Permite reabrir o menu de contexto direto noutra celula com um unico clique direito. O popup embutido
# tem grab modal: enquanto aberto, ele engole o clique direito de fora (nem fecha nem repassa a celula) e
# suprime _input/_gui_input dos outros nos. Por isso detectamos o clique por POLLING em _process (que
# roda sempre, independente do grab): a cada novo clique direito FORA do menu, fechamos e reabrimos na
# celula sob o cursor. So fica ativo enquanto o menu esta visivel.
func _process(_delta: float) -> void:
	var rmb: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if rmb and not _rmb_anterior and _menu_celula.visible:
		var rect := Rect2(_menu_celula.position, _menu_celula.size)
		if not rect.has_point(get_viewport().get_mouse_position()):
			var grade := $"%GradeHorarios"
			var lc: Vector2i = grade.celula_em_ponto_global(grade.get_global_mouse_position())
			if lc.x >= 0:
				# Reposiciona o popup JA aberto para a nova celula (popup() reusa a mesma janela). NAO
				# fechar antes: hide()+popup() no mesmo frame se anulavam, o menu so fechava e exigia um
				# 2o clique para reabrir.
				_abrir_menu_celula(lc.x, lc.y)
			else:
				# Clique direito fora de qualquer celula: fecha o menu.
				_menu_celula.hide()
	_rmb_anterior = rmb


# Clique direito: abre um menu com as disciplinas daquele horário. Ao escolher uma, aplica o
# filtro de semestre ao semestre dela (atalho para focar a grade naquela disciplina).
func _on_grade_celula_clicada_direita(linha: int, coluna: int) -> void:
	_abrir_menu_celula(linha, coluna)

func _abrir_menu_celula(linha: int, coluna: int) -> void:
	if linha == 0 or coluna == 0:
		return
	var arr: Array = _ger_alocacoes.obter_alocacoes("%d_%d" % [linha, coluna])
	if arr.is_empty():
		return
	_menu_celula.clear()
	_menu_celula_semestres.clear()
	for a_dict in arr:
		var aloc: Dictionary = a_dict
		var codigo: String = str(aloc.get("codigo", "")).to_upper()
		var card: CardDisciplina = $"%PainelDisciplinas".cards_disciplinas.get(aloc.get("chave", ""), null)
		var nome: String = card.nome if card else codigo
		var sem: String = _semestre_da_aloc(aloc)
		_menu_celula.add_item("%s — %s (%s)" % [codigo, nome, sem])
		_menu_celula_semestres.append(sem)
	_menu_celula.reset_size()
	# Subjanelas embutidas (padrao do Godot 4) + stretch "canvas_items": um popup embutido posiciona-se
	# no espaco do viewport (coords logicas), nao da tela. DisplayServer.mouse_get_position() devolve
	# coords fisicas globais, somando o offset da janela e o fator de escala -> o menu abria bem abaixo/a
	# direita. get_viewport().get_mouse_position() ja vem no espaco certo do popup.
	_menu_celula.popup(Rect2i(Vector2i(get_viewport().get_mouse_position()), Vector2i.ZERO))

# Ao escolher uma disciplina no menu da célula, aplica o filtro de semestre ao semestre dela.
func _on_menu_celula_index_pressed(idx: int) -> void:
	if idx < 0 or idx >= _menu_celula_semestres.size():
		return
	var sem: String = _menu_celula_semestres[idx]
	if not sem.is_empty():
		$"%PainelDisciplinas".selecionar_filtro_semestre_unico(sem)

func _detectar_choques(_celulas_afetadas: Array[String] = []) -> void:
	_recalcular_grade(true)

func _notification(what: int) -> void:
	# Na troca de tema, reaplica a barra de status (cor de choques adaptada) sem redetectar nem
	# reimprimir no terminal. O guard evita rodar antes do _ready inicializar os complementos.
	if what == NOTIFICATION_THEME_CHANGED and $"%PainelDisciplinas":
		_atualizar_status_bar()

# Atualiza os labels da barra de status com os totais de choques de recursos e de alunos.
func _atualizar_status_bar() -> void:
	var contagem: Dictionary = $"%PainelDisciplinas".contar_status_cards()
	var status_bar: StatusBar = $"%StatusBar"
	status_bar.atualizar("pendentes", "Pendentes: %d" % contagem["pendentes"])
	status_bar.atualizar("completas", "Completas: %d" % contagem["completas"])
	status_bar.atualizar("choques", "Choques: %d" % _ultimo_total_choques, \
		"erro" if _ultimo_total_choques > 0 else "")
	status_bar.atualizar("alunos_choque", "Alunos em choque: %d" % _ultimo_total_alunos_choque, \
		"aviso" if _ultimo_total_alunos_choque > 0 else "")
	# Segmento de compartilhadas divergentes: so aparece quando ha referencia (outro curso) sobreposta.
	if _ha_referencia():
		if _ultimo_total_compartilhadas_div > 0:
			status_bar.atualizar("compartilhadas_div", \
				"Compart. divergentes: %d" % _ultimo_total_compartilhadas_div, "aviso")
		else:
			status_bar.atualizar("compartilhadas_div", "Compart. alinhadas ✓", "")
	else:
		status_bar.atualizar("compartilhadas_div", "")

# Carrega hist.csv e pré-computa as condições de cada discente (necessário ao indicador de choque
# de alunos). Feito uma vez no _ready, espelhando o módulo Situação Disciplinas. Falha graciosamente
# se hist.csv estiver ausente: o indicador apenas reportará zero.
func _carregar_dados_discentes() -> void:
	# Consome o cache de dados discentes pre-computado pelo main (evita recalcular a cada troca de
	# modulo). Fallback: se o cache estiver vazio (ex.: cena aberta fora do fluxo), computa local.
	if not GV.dados_discentes.is_empty():
		_historico = GV.dados_discentes["historico"]
		_lista_alunos = GV.dados_discentes["lista_alunos"]
		_condicoes_discentes = GV.dados_discentes["condicoes_discentes"]
		return
	if not FileAccess.file_exists(GV.dir_saida + "hist.csv"):
		return
	_historico = file_handling.ler_dados(GV.dir_saida, "hist.csv", posicoes_histcsv, false, grades_disciplinas_curriculos)
	analise_historico.simplificar_historico(_historico, "situacao", ["aprovado", "dispensado", "matr"])
	_lista_alunos = analise_historico.criar_lista_alunos(_historico)
	_condicoes_discentes = analise_historico.condicoes_discentes(_lista_alunos, _historico, condicoes, \
		grades_disciplinas_curriculos, equivalencias)

# Popula o SeletorCondicoesChoque com as condições do base_config.json, marcando
# todas exceto as de matrícula irregular.
func _configurar_seletor_condicoes_choque() -> void:
	var lista_itens: Dictionary = {}
	lista_itens["_Condições choque_"] = []
	lista_itens["_Condições choque_retorno"] = []
	for condicao in condicoes:
		lista_itens["_Condições choque_"].append(condicao.replacen("_", " ").capitalize())
		lista_itens["_Condições choque_retorno"].append(condicao)
	$"%SeletorCondicoesChoque".lista_itens = lista_itens
	DicasPrograma.vincular_itens($"%SeletorCondicoesChoque", condicoes, ["condicoes_matricula"])
	# Marca todas as condições exceto as de matrícula irregular.
	_condicoes_choque_selecionadas = []
	for i in condicoes.size():
		if "irregular" in condicoes[i]:
			continue
		$"%SeletorCondicoesChoque".selecionar_item(i)
		_condicoes_choque_selecionadas.append(condicoes[i])

func _on_condicoes_choque_selecionada(_retorno: String, lista_selecionada: Array[String]) -> void:
	_condicoes_choque_selecionadas = lista_selecionada
	_atualizar_choques_alunos()

# Recalcula o total de alunos em choque (par a par) e atualiza a barra de status. Só computa
# quando o indicador "Choques de horário" está ativo e há dados de discentes carregados.
# Não imprime no terminal: o detalhamento no terminal é feito por ação (soltar/clicar numa célula).
func _atualizar_choques_alunos() -> void:
	if IND_CHOQUE_ALUNOS in _indicadores_ativos:
		_ultimo_total_alunos_choque = _contar_choques_alunos()
	else:
		_ultimo_total_alunos_choque = 0
	_atualizar_status_bar()

# Soma, sobre TODA a grade, quantos discentes estão em ambas as disciplinas de cada par de códigos
# distintos co-alocados (nas condições selecionadas). Silencioso — alimenta apenas a barra de status.
func _contar_choques_alunos() -> int:
	if _condicoes_discentes.is_empty() or _condicoes_choque_selecionadas.is_empty():
		return 0
	var pares: Dictionary = {}
	for chave_celula in _ger_alocacoes.alocacoes:
		var arr: Array = _ger_alocacoes.alocacoes[chave_celula]
		for i in arr.size():
			var cod_i: String = (arr[i] as Dictionary).get("codigo", "").to_lower()
			for j in range(i + 1, arr.size()):
				var cod_j: String = (arr[j] as Dictionary).get("codigo", "").to_lower()
				if cod_i.is_empty() or cod_j.is_empty() or cod_i == cod_j:
					continue
				var a: String = cod_i if cod_i < cod_j else cod_j
				var b: String = cod_j if cod_i < cod_j else cod_i
				pares["%s|%s" % [a, b]] = true
	var total: int = 0
	for k in pares:
		var partes: PackedStringArray = str(k).split("|")
		var discentes: Dictionary = analise_historico.comparar_discentes_disciplina(\
			partes[0], partes[1], _condicoes_discentes, _condicoes_choque_selecionadas)
		total += discentes.size()
	return total

# Imprime no terminal os choques de alunos entre disciplinas sobrepostas nas células dadas (cada item
# de [param celulas] é [linha, coluna]). Deduplica pares repetidos entre as células. Usado ao soltar
# uma disciplina e ao clicar com o esquerdo. Só age com o indicador "Choques de horário" ativo.
func _reportar_choques_alunos_celulas(celulas: Array) -> void:
	if not (IND_CHOQUE_ALUNOS in _indicadores_ativos):
		return
	if _condicoes_discentes.is_empty() or _condicoes_choque_selecionadas.is_empty():
		return
	var vistos: Dictionary = {}
	for cel in celulas:
		var arr: Array = _ger_alocacoes.obter_alocacoes("%d_%d" % [cel[0], cel[1]])
		for i in arr.size():
			for j in range(i + 1, arr.size()):
				var aloc_a: Dictionary = arr[i]
				var aloc_b: Dictionary = arr[j]
				var cod_a: String = aloc_a.get("codigo", "").to_lower()
				var cod_b: String = aloc_b.get("codigo", "").to_lower()
				if cod_a.is_empty() or cod_b.is_empty() or cod_a == cod_b:
					continue
				var k: String = (cod_a + "|" + cod_b) if cod_a < cod_b else (cod_b + "|" + cod_a)
				if vistos.has(k):
					continue
				vistos[k] = true
				_imprimir_choque_par(aloc_a, aloc_b)

# Imprime no terminal a contagem de alunos em choque entre duas disciplinas e, se o detalhamento
# estiver ativo, a lista de alunos com a situação em cada uma. O rótulo segue o modo de visualização.
func _imprimir_choque_par(aloc_a: Dictionary, aloc_b: Dictionary) -> void:
	var cod_a: String = aloc_a.get("codigo", "").to_lower()
	var cod_b: String = aloc_b.get("codigo", "").to_lower()
	var discentes: Dictionary = analise_historico.comparar_discentes_disciplina(\
		cod_a, cod_b, _condicoes_discentes, _condicoes_choque_selecionadas)
	var n: int = discentes.size()
	var rot_a: String = _ger_alocacoes.rotulo_alocacao(aloc_a)
	var rot_b: String = _ger_alocacoes.rotulo_alocacao(aloc_b)
	$"%Terminal".linha("Choque de alunos: %s × %s → %d aluno(s) em ambas." % \
		[rot_a, rot_b, n], "aviso")
	if n > 0 and IND_DETALHAR_ALUNOS in _indicadores_ativos:
		_listar_alunos_em_choque(discentes, rot_a, rot_b)

# Imprime, para um par de disciplinas, o nome de cada discente em choque e a situação em que se
# enquadra em cada uma. Útil para distinguir choques certos de choques condicionais (ex.: o aluno
# é "matriculável" em uma e "seaprovado" em outra — só haverá choque se for aprovado primeiro). [br]
# A lista é ordenada por prioridade da situação: já matriculados primeiro, depois matriculáveis,
# por último os seaprovado (ver [method _prioridade_condicao]).
func _listar_alunos_em_choque(discentes: Dictionary, rot_a: String, rot_b: String) -> void:
	var entradas: Array = []
	for matr in discentes.keys():
		var nome: String = _historico.get(matr, {}).get("nomedoaluno", str(matr))
		# Deduplica pares de condições repetidos para o mesmo aluno e guarda a prioridade de cada par.
		var vistos: Dictionary = {}
		var pares_prio: Array = []  # cada item: [prio_min, prio_max, texto]
		for par_cond in discentes[matr]:
			var cond_a: String = str(par_cond[0])
			var cond_b: String = str(par_cond[1])
			var chave_par: String = cond_a + "|" + cond_b
			if vistos.has(chave_par):
				continue
			vistos[chave_par] = true
			var pa: int = _prioridade_condicao(cond_a)
			var pb: int = _prioridade_condicao(cond_b)
			var texto: String = "%s: %s / %s: %s" % \
				[rot_a, cond_a.replacen("_", " ").capitalize(), rot_b, cond_b.replacen("_", " ").capitalize()]
			pares_prio.append([min(pa, pb), max(pa, pb), texto])
		# Ordena as situações do próprio aluno (mais "matriculado" primeiro).
		pares_prio.sort_custom(func(x, y): return x[0] < y[0] if x[0] != y[0] else x[1] < y[1])
		var situacoes: Array[String] = []
		for pp in pares_prio:
			situacoes.append(pp[2])
		# Chave de ordenação do aluno: o melhor (menor) par de prioridades que ele possui.
		var kmin: int = pares_prio[0][0] if pares_prio.size() > 0 else 9
		var kmax: int = pares_prio[0][1] if pares_prio.size() > 0 else 9
		entradas.append({"nome": nome, "kmin": kmin, "kmax": kmax, "situacoes": situacoes})
	# Ordena os alunos por prioridade de situação e, em empate, por nome.
	entradas.sort_custom(func(x, y):
		if x["kmin"] != y["kmin"]:
			return x["kmin"] < y["kmin"]
		if x["kmax"] != y["kmax"]:
			return x["kmax"] < y["kmax"]
		return str(x["nome"]) < str(y["nome"]))
	for e in entradas:
		$"%Terminal".item("%s — %s" % [str(e["nome"]).capitalize(), " ; ".join(e["situacoes"])])

# Prioridade de uma condição de matrícula para ordenar a apresentação dos choques: [br]
# 1 = já matriculado (normal, por aproveitamento ou irregular); 2 = matriculável (inclui
# corequisito e aproveitamento); 3 = seaprovado (inclui corequisito e aproveitamento). Menor = antes.
func _prioridade_condicao(cond: String) -> int:
	if cond.contains("matriculado") or cond.contains("matricula_irregular"):
		return 1
	if cond.contains("matriculavel"):
		return 2
	if cond.contains("seaprovado"):
		return 3
	return 4

func _sincronizar_referencias() -> void:
	_ger_alocacoes.configurar($"%GradeHorarios", $"%PainelDisciplinas".cards_disciplinas, _dados._planejamento_csv, analise_grades, grades_disciplinas_curriculos)
	_detector.configurar(_ger_alocacoes.alocacoes, _dados._planejamento_csv, $"%PainelDisciplinas".cards_disciplinas)
	_vincular_regras_aos_cards()


## Varre os cards de disciplina e, para cada professor que possui comentários textuais no CSV
## de preferências, vincula um [DicaFlutuante] ao card com os comentários formatados em BBCode.
## O cache [member _cache_comentarios_professores] evita re-ler arquivos a cada chamada.
func _vincular_regras_aos_cards() -> void:
	for chave in $"%PainelDisciplinas".cards_disciplinas:
		var card: CardDisciplina = $"%PainelDisciplinas".cards_disciplinas[chave]
		if card.professores.is_empty():
			continue
		var textos: Array[String] = []
		for prof in card.professores:
			var pl: String = str(prof).to_lower()
			if not _cache_comentarios_professores.has(pl):
				var arquivo: String = _arquivo_preferencias_de(str(prof))
				if not arquivo.is_empty():
					_cache_comentarios_professores[pl] = _dados.ler_comentarios_professor(arquivo)
				else:
					_cache_comentarios_professores[pl] = [] as Array[String]
			var comentarios_prof: Array = _cache_comentarios_professores[pl]
			if comentarios_prof.is_empty():
				continue
			textos.append("[b]%s[/b]" % str(prof).capitalize())
			for c in comentarios_prof:
				var texto_c: String = c
				if texto_c.length() > 0:
					texto_c = texto_c[0].to_upper() + texto_c.substr(1)
				textos.append("  • %s" % texto_c)
		if textos.is_empty():
			continue
		var bbcode: String = "\n".join(textos)
		DicaFlutuante.vincular(card, bbcode)


## Reaplica o visual da grade refletindo o filtro ativo (sem reimprimir relatórios no terminal).
## O foco do filtro (fundo destacado/esmaecido) é decidido pelo AplicadorVisualGrade a partir das
## condições por célula montadas em [method _recalcular_grade].
func _aplicar_filtro_grade(_alocacoes: Dictionary) -> void:
	_recalcular_grade(false)

func _on_importar_opcao_selecionada(retorno: String, _lista_selecionada: Array[String]) -> void:
	match retorno:
		"abrir_json":
			_importar_planejamento_json()
		"abrir_csv":
			_abrir_janela_selecao_cursos_planejamento()
		"salvar_json":
			var json: Dictionary = _dados.exportar_planejamento_json(_ger_alocacoes.alocacoes)
			file_handling.save_json(diretorio_exportacao, "planejamento.json", json)
			$"%Terminal".text_edit("Exportado: " + diretorio_exportacao + "planejamento.json" + \
				" (" + str(json["disciplinas"].size()) + " disciplinas).", \
				"sucesso", true, false)
		"importar_csv":
			_converter_planejamento_csv()
		"horarios.txt":
			_abrir_janela_selecao_cursos_horario()
		"professor.xlsx (.csv)":
			_importar_preferencias_professor()
		"exportar_horarios_txt":
			_on_exportar_button_up()
		"enviar_servidor":
			_enviar_para_servidor()
		"baixar_servidor":
			_baixar_do_servidor()
		"ver_referencias":
			_ver_outros_cursos_referencia()
		"limpar_referencias":
			_limpar_referencias()
		"config_servidor":
			_configurar_sincronizacao()


# ───────────────────────── Sincronizacao com o servidor (Kinto) ─────────────────────────

# Configura o _sync com as credenciais salvas (lidas de GV, como o ppc_principal). Se faltar algo,
# avisa e abre o dialogo de configuracao, retornando false.
func _garantir_sync_config() -> bool:
	var sinc: Dictionary = GV.configuracao_base.get("sincronizacao", {})
	_sync.configurar(str(sinc.get("url", "")), str(sinc.get("usuario", "")), str(sinc.get("token", "")))
	if not _sync.esta_configurado():
		$"%Terminal".text_edit("Configure o servidor primeiro (Importar > Configurar servidor).", \
			"aviso", true, true)
		_configurar_sincronizacao()
		return false
	return true


# O record de sincronizacao e identificado pelo CURSO (ex.: "alec"), nao pela grade/versao, porque um
# curso tem varios PPCs ativos e o planejamento cobre todos. Deriva o cod_curso do ppc_principal
# (ex.: "alec_2023" -> "alec"); vazio quando o ppc_principal nao esta definido/cadastrado.
func _meu_cod_curso() -> String:
	return analise_historico.curso_da_grade(GV.configuracao_base.get("ppc_principal", ""), cursos)


# Ao abrir o modulo, consulta o servidor em segundo plano e avisa se houver uma versao do curso do
# PPC principal que valha a pena baixar. So avisa quando AMBAS as condicoes valem:
#   1) e uma versao que este usuario ainda nao sincronizou (last_modified do Kinto > marcador local
#      em config_usuario.json:sincronizacao.versoes_sincronizadas.<curso>, atualizado a cada
#      envio/baixa) — evita reavisar a propria versao recem-enviada/baixada;
#   2) a versao do servidor e mais recente, POR DATA, do que o planejamento.json local (comparando
#      o campo "exportado_em" dos dois) — evita avisar quando o trabalho local ainda nao enviado e
#      mais novo que o que esta no servidor.
# Silencioso em todo o resto (sem credenciais, offline, curso ainda nao enviado, ou ja em dia).
func _verificar_atualizacao_servidor() -> void:
	var sinc: Dictionary = GV.configuracao_base.get("sincronizacao", {})
	_sync.configurar(str(sinc.get("url", "")), str(sinc.get("usuario", "")), str(sinc.get("token", "")))
	if not _sync.esta_configurado():
		return
	var cod: String = _meu_cod_curso()
	if cod.is_empty():
		return
	var r: Dictionary = await _sync.baixar(cod)
	if not r.get("ok", false):
		return
	var record: Dictionary = {}
	if r.get("dados") is Dictionary:
		record = r["dados"].get("data", {})

	# Condicao 1: versao do servidor ainda nao sincronizada por este usuario.
	var lm_servidor: int = int(record.get("last_modified", 0))
	var versoes: Dictionary = sinc.get("versoes_sincronizadas", {})
	if lm_servidor <= int(versoes.get(cod, 0)):
		return

	# Condicao 2: servidor mais recente, por data, do que o planejamento.json local. Os dois lados
	# usam "exportado_em", mas em formatos diferentes (o modulo Oferta grava "AAAA-MM-DD HH:MM" e o
	# Horario/SyncKinto "AAAA-MM-DDTHH:MM:SS"); converte ambos para tempo Unix antes de comparar.
	var plano_servidor: Dictionary = record.get("planejamento", {}) if record.get("planejamento") is Dictionary else {}
	var data_servidor: String = str(plano_servidor.get("exportado_em", record.get("enviado_em", "")))
	var data_local: String = ""
	if FileAccess.file_exists(diretorio_exportacao + "planejamento.json"):
		var plano_local: Dictionary = file_handling.load_json(diretorio_exportacao, "planejamento.json")
		data_local = str(plano_local.get("exportado_em", ""))
	if _data_para_unix(data_servidor) <= _data_para_unix(data_local):
		return

	var por: String = str(record.get("enviado_por", "?"))
	var em: String = str(record.get("enviado_em", "?"))
	Dialogos.confirmar(self, "Versão nova no servidor", \
		"Há uma versão mais recente do planejamento de %s no servidor (enviada por %s em %s). " \
		% [cod, por, em] + "Deseja baixá-la agora? Isso substitui o planejamento local.", \
		_baixar_curso.bind(cod), "Baixar agora", "Agora não")


# Marca localmente (config_usuario.json via override) qual versao do servidor este usuario tem para
# o curso, usando o last_modified do record retornado por enviar/baixar. Assim a verificacao
# automatica nao acusa como "nova" a propria versao que o usuario acabou de enviar ou baixar.
func _registrar_versao_sincronizada(chave_curso: String, resposta: Dictionary) -> void:
	if not resposta.get("dados") is Dictionary:
		return
	var record: Dictionary = resposta["dados"].get("data", {})
	var lm: int = int(record.get("last_modified", 0))
	if lm <= 0:
		return
	override_config.emit(["sincronizacao", "versoes_sincronizadas", chave_curso], lm)


# Converte uma data "exportado_em" (nos formatos "AAAA-MM-DD HH:MM" ou "AAAA-MM-DDTHH:MM:SS") em
# tempo Unix para comparacao numerica robusta. Vazio ou invalido vira 0 (mais antigo que tudo).
func _data_para_unix(data: String) -> int:
	if data.strip_edges().is_empty():
		return 0
	return int(Time.get_unix_time_from_datetime_string(data.strip_edges().replace(" ", "T")))


# Envia o planejamento do proprio curso (derivado do PPC principal) ao servidor (apos confirmacao).
func _enviar_para_servidor() -> void:
	if not _garantir_sync_config():
		return
	var cod: String = _meu_cod_curso()
	if cod.is_empty():
		$"%Terminal".text_edit("Defina o PPC principal em Configuracoes > Geral antes de enviar.", \
			"aviso", true, true)
		return
	Dialogos.confirmar(self, "Enviar ao servidor", \
		"Enviar o planejamento do curso %s ao servidor? Isso substitui a versao que estiver la." % cod, \
		_enviar_para_servidor_confirmado.bind(cod), "Enviar")


func _enviar_para_servidor_confirmado(cod: String) -> void:
	# Filtra a exportacao para mandar apenas as disciplinas deste curso (1 record por curso).
	var prefixos: Array = cursos.get(cod, {}).get("prefixos_semestre", [])
	var json: Dictionary = _dados.exportar_planejamento_json(_ger_alocacoes.alocacoes, prefixos)
	$"%Terminal".text_edit("Enviando planejamento de %s ao servidor..." % cod, "padrao", true, false)
	var r: Dictionary = await _sync.enviar(cod, json)
	if r.get("ok", false):
		_registrar_versao_sincronizada(cod, r)
		$"%Terminal".text_edit("Enviado: %s (%d disciplinas) para o servidor." \
			% [cod, json.get("disciplinas", []).size()], "sucesso", true, false)
	else:
		$"%Terminal".text_edit("Falha ao enviar: %s" % r.get("erro", ""), "erro", true, true)


# Lista os planejamentos no servidor e abre um dialogo para escolher qual baixar.
func _baixar_do_servidor() -> void:
	if not _garantir_sync_config():
		return
	$"%Terminal".text_edit("Consultando planejamentos no servidor...", "padrao", true, false)
	var r: Dictionary = await _sync.listar()
	if not r.get("ok", false):
		$"%Terminal".text_edit("Falha ao consultar: %s" % r.get("erro", ""), "erro", true, true)
		return
	var registros: Array = []
	if r.get("dados") is Dictionary:
		registros = r["dados"].get("data", [])
	if registros.is_empty():
		$"%Terminal".text_edit("Nenhum planejamento disponivel no servidor.", "aviso", true, true)
		return
	_abrir_selecao_download(registros)


# Dialogo customizado (AGENTS.md) com a lista dos cursos disponiveis no servidor; ao confirmar,
# baixa o curso selecionado. Mostra quem enviou e quando para orientar a escolha.
func _abrir_selecao_download(registros: Array) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Baixar planejamento do servidor"
	dialog.get_ok_button().text = "Baixar"
	dialog.get_cancel_button().text = "Cancelar"
	dialog.min_size = Vector2i(520, 320)

	var vbox := VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialog.add_child(vbox)
	var lbl := Label.new()
	lbl.text = "Escolha o curso a baixar (substitui o planejamento.json local e a grade):"
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(lbl)

	var lista := ItemList.new()
	lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lista.custom_minimum_size = Vector2(480, 220)
	vbox.add_child(lista)
	var ids: Array[String] = []
	for rec in registros:
		if not rec is Dictionary:
			continue
		var id_curso: String = str(rec.get("id", ""))
		var por: String = str(rec.get("enviado_por", "?"))
		var em: String = str(rec.get("enviado_em", "?"))
		lista.add_item("%s — enviado por %s em %s" % [id_curso, por, em])
		ids.append(id_curso)
	if lista.item_count > 0:
		lista.select(0)

	dialog.confirmed.connect(func():
		var sel: PackedInt32Array = lista.get_selected_items()
		if sel.is_empty():
			return
		_baixar_curso(ids[sel[0]]))
	dialog.visibility_changed.connect(func():
		if not dialog.visible:
			dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()
	Dialogos.limitar_a_tela(dialog)


# Baixa o record do curso, salva como planejamento.json (reaproveitando file_handling) e reimporta
# na grade pelo fluxo ja existente (_importar_planejamento_json).
func _baixar_curso(chave_curso: String) -> void:
	$"%Terminal".text_edit("Baixando %s do servidor..." % chave_curso, "padrao", true, false)
	var r: Dictionary = await _sync.baixar(chave_curso)
	if not r.get("ok", false):
		$"%Terminal".text_edit("Falha ao baixar: %s" % r.get("erro", ""), "erro", true, true)
		return
	var record: Dictionary = {}
	if r.get("dados") is Dictionary:
		record = r["dados"].get("data", {})
	var planejamento: Variant = record.get("planejamento", {})
	if not planejamento is Dictionary or not planejamento.has("disciplinas"):
		$"%Terminal".text_edit("O planejamento recebido esta vazio ou em formato invalido.", "erro", true, true)
		return
	file_handling.save_json(diretorio_exportacao, "planejamento.json", planejamento)
	_importar_planejamento_json()
	_registrar_versao_sincronizada(chave_curso, r)
	$"%Terminal".text_edit("Baixado: %s (enviado por %s em %s)." \
		% [chave_curso, str(record.get("enviado_por", "?")), str(record.get("enviado_em", "?"))], \
		"sucesso", true, false)


# ───────────────────────── Camada de referencia (ver outros cursos) ─────────────────────────
# Permite sobrepor na grade o planejamento de OUTROS cursos como somente-leitura, para co-planejar
# disciplinas compartilhadas. As alocacoes/disciplinas de referencia recebem os marcadores
# "referencia": true e "curso_origem": <chave_curso>; o resto do programa (edicao, export) usa esses
# marcadores como guarda. So fica em memoria — nunca entra no planejamento.json do usuario (Fase 3).

# Lista os cursos no servidor (exceto o PPC principal) e abre um dialogo de selecao multipla para
# escolher quais sobrepor como referencia. Reusa _sync.listar() (um GET traz todos com planejamento).
func _ver_outros_cursos_referencia() -> void:
	if not _garantir_sync_config():
		return
	$"%Terminal".text_edit("Consultando cursos no servidor...", "padrao", true, false)
	var r: Dictionary = await _sync.listar()
	if not r.get("ok", false):
		$"%Terminal".text_edit("Falha ao consultar: %s" % r.get("erro", ""), "erro", true, true)
		return
	var registros: Array = []
	if r.get("dados") is Dictionary:
		registros = r["dados"].get("data", [])
	var cod: String = _meu_cod_curso()
	var outros: Array = []
	for rec in registros:
		if not rec is Dictionary:
			continue
		var id_rec: String = str(rec.get("id", ""))
		# So sobrepoe cursos reais como referencia: exclui o proprio e agregados (ex.: 'campus'), que
		# nao sao cod_curso de base_config.json:cursos.
		if id_rec == cod or not cursos.has(id_rec):
			continue
		outros.append(rec)
	if outros.is_empty():
		$"%Terminal".text_edit("Nenhum outro curso disponivel no servidor para referencia.", "aviso", true, true)
		return
	_abrir_selecao_referencia(outros)


# Dialogo (AGENTS.md) com selecao MULTIPLA dos cursos a sobrepor como referencia.
func _abrir_selecao_referencia(registros: Array) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Ver outros cursos (referência)"
	dialog.get_ok_button().text = "Sobrepor"
	dialog.get_cancel_button().text = "Cancelar"
	dialog.min_size = Vector2i(540, 340)

	var vbox := VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialog.add_child(vbox)
	var lbl := Label.new()
	lbl.text = "Escolha os cursos a sobrepor na grade (somente-leitura; não altera o seu plano). " + \
		"Segure Ctrl/Shift para selecionar vários:"
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(lbl)

	var lista := ItemList.new()
	lista.select_mode = ItemList.SELECT_MULTI
	lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lista.custom_minimum_size = Vector2(500, 240)
	vbox.add_child(lista)
	for rec in registros:
		var id_curso: String = str(rec.get("id", ""))
		var por: String = str(rec.get("enviado_por", "?"))
		var em: String = str(rec.get("enviado_em", "?"))
		lista.add_item("%s — enviado por %s em %s" % [id_curso, por, em])

	dialog.confirmed.connect(func():
		var sel: PackedInt32Array = lista.get_selected_items()
		if sel.is_empty():
			return
		var escolhidos: Array = []
		for i in sel:
			escolhidos.append(registros[i])
		_aplicar_referencia(escolhidos))
	dialog.visibility_changed.connect(func():
		if not dialog.visible:
			dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()
	Dialogos.limitar_a_tela(dialog)


# Mescla o planejamento dos cursos escolhidos na grade como referencia (somente-leitura), sem apagar
# o plano do usuario. Reusa a logica de _importar_planejamento_json, mas: nao da clear(), nao
# sobrescreve chaves ja existentes (a sua tem prioridade) e marca tudo como referencia.
func _aplicar_referencia(registros: Array) -> void:
	# Recomeca da referencia limpa para a operacao ser idempotente (re-selecionar nao duplica).
	_remover_dados_referencia()
	var dias_json: Array[String] = analise_horarios.dias_da_semana(_dados._horarios_ini)
	var horas_json: Array[String] = analise_horarios.horas_das_aulas(_dados._horarios_ini)

	# Passo 1: adiciona as disciplinas de referencia ao _planejamento_csv (sem sobrescrever as suas).
	for rec in registros:
		if not rec is Dictionary:
			continue
		var curso_origem: String = str(rec.get("id", ""))
		var plano: Dictionary = rec.get("planejamento", {}) if rec.get("planejamento") is Dictionary else {}
		for disc in plano.get("disciplinas", []):
			if not disc is Dictionary:
				continue
			var codigo: String = str(disc.get("codigo", "")).to_lower()
			var semestre: String = str(disc.get("semestre", ""))
			if codigo.is_empty():
				continue
			var chave: String = codigo + "_" + semestre.to_lower()
			if _dados._planejamento_csv.has(chave):
				continue  # a sua (ou outra referencia ja adicionada) tem prioridade
			var nomes: Array[String] = []
			var chs: Array[String] = []
			var ch_total: int = 0
			for p in disc.get("professores", []):
				if p is Dictionary:
					var pn: String = str(p.get("nome", ""))
					if not pn.is_empty():
						nomes.append(pn)
						chs.append(str(int(p.get("ch", 0))))
						ch_total += int(p.get("ch", 0))
			_dados._planejamento_csv[chave] = {
				"codigo": codigo,
				"semestre": semestre,
				"professor": nomes,
				"ch": chs,
				"oferta": str(disc.get("oferta", semestre)),
				"ch_disciplina": str(ch_total),
				"referencia": true,
				"curso_origem": curso_origem,
			}

	# Repopula o painel (recria cards; ch_alocada e recomputada adiante) e reconfigura as referencias.
	_sincronizar_referencias()
	$"%PainelDisciplinas".popular(_dados._planejamento_csv, $"%Terminal", false)

	# Passo 2: aplica na grade as alocacoes das disciplinas de referencia (so as marcadas como tal).
	var cont_aloc: int = 0
	for rec in registros:
		if not rec is Dictionary:
			continue
		var curso_origem: String = str(rec.get("id", ""))
		var plano: Dictionary = rec.get("planejamento", {}) if rec.get("planejamento") is Dictionary else {}
		for disc in plano.get("disciplinas", []):
			if not disc is Dictionary:
				continue
			var codigo_json: String = str(disc.get("codigo", "")).to_lower()
			var semestre_json: String = str(disc.get("semestre", ""))
			if codigo_json.is_empty():
				continue
			var chave_json: String = codigo_json + "_" + semestre_json.to_lower()
			var entrada: Dictionary = _dados._planejamento_csv.get(chave_json, {})
			if not entrada.get("referencia", false):
				continue  # chave que colidiu com a sua: nao aplica a versao de referencia
			for aloc_item in disc.get("alocacoes", []):
				if not aloc_item is Dictionary:
					continue
				var col_idx: int = dias_json.find(str(aloc_item.get("dia", ""))) + 1
				var row_idx: int = horas_json.find(str(aloc_item.get("horario", ""))) + 1
				if col_idx <= 0 or row_idx <= 0:
					continue
				_ger_alocacoes.alocar("%d_%d" % [row_idx, col_idx], {
					"chave": chave_json,
					"codigo": codigo_json,
					"professor": str(aloc_item.get("professor", "")),
					"semestre": semestre_json,
					"sala": str(aloc_item.get("sala", "")),
					"tipo": str(aloc_item.get("tipo", "")),
					"turma": str(aloc_item.get("turma", "")),
					"vagas": str(aloc_item.get("vagas", "Vagas")),
					"p": str(aloc_item.get("p", "1")),
					"s": str(aloc_item.get("s", "1")),
					"t": str(aloc_item.get("t", "1")),
					"referencia": true,
					"curso_origem": curso_origem,
				})
				cont_aloc += 1

	_recomputar_ch_alocada()
	_sincronizar_referencias()
	# Dica de origem nos cards de referencia (somente-leitura).
	for chave in $"%PainelDisciplinas".cards_disciplinas:
		var entrada: Dictionary = _dados._planejamento_csv.get(chave, {})
		if entrada.get("referencia", false):
			DicaFlutuante.vincular($"%PainelDisciplinas".cards_disciplinas[chave], \
				"Disciplina de outro curso (somente-leitura): %s" % str(entrada.get("curso_origem", "")))
	_ger_alocacoes.reaplicar_todas()
	_detectar_choques()
	var nomes_cursos: Array[String] = []
	for rec in registros:
		if rec is Dictionary:
			nomes_cursos.append(str(rec.get("id", "")))
	$"%Terminal".text_edit("Referência sobreposta: %s (%d alocações). Somente-leitura." \
		% [", ".join(nomes_cursos), cont_aloc], "sucesso", true, false)

	# Sinaliza disciplinas compartilhadas em horario divergente entre o seu plano e a referencia.
	var divergencias: Array[String] = _verificar_compartilhadas_divergentes()
	if not divergencias.is_empty():
		$"%Terminal".text_edit("%d disciplina(s) compartilhada(s) em horário divergente." \
			% divergencias.size(), "aviso", true, true)
		Dialogos.escolha_lista(self, "Compartilhadas em horário divergente", \
			"Estas disciplinas compartilhadas estão em horários diferentes entre o seu plano e o " + \
			"curso de referência. Alinhe-as com o(s) coordenador(es):", \
			divergencias, "", [{ "texto": "Entendi", "ao_acionar": Callable() }], "")


# Remove da grade e do _planejamento_csv todos os dados marcados como referencia, redesenhando.
func _limpar_referencias() -> void:
	if not _ha_referencia():
		$"%Terminal".text_edit("Não há cursos de referência sobrepostos.", "aviso", true, false)
		return
	_remover_dados_referencia()
	_sincronizar_referencias()
	$"%PainelDisciplinas".popular(_dados._planejamento_csv, $"%Terminal", false)
	_recomputar_ch_alocada()
	_sincronizar_referencias()
	_ger_alocacoes.reaplicar_todas()
	_detectar_choques()
	$"%Terminal".text_edit("Referências removidas.", "sucesso", true, false)


# Remove apenas os DADOS de referencia (alocacoes + _planejamento_csv), sem redesenhar. Usado por
# _aplicar_referencia (recomeco) e _limpar_referencias (que redesenha depois).
func _remover_dados_referencia() -> void:
	for chave_celula in _ger_alocacoes.alocacoes.keys():
		var arr: Array = _ger_alocacoes.alocacoes[chave_celula]
		var mantidas: Array = []
		for aloc in arr:
			if not (aloc is Dictionary and aloc.get("referencia", false)):
				mantidas.append(aloc)
		if mantidas.is_empty():
			_ger_alocacoes.alocacoes.erase(chave_celula)
		else:
			_ger_alocacoes.alocacoes[chave_celula] = mantidas
	# Libera os cards de referencia do painel ANTES de apagar o _planejamento_csv (usa o flag para
	# identifica-los). popular(false) so removeria cards cujo codigo ainda esteja no dicionario, entao
	# disciplinas que so existiam na referencia ficariam orfas se nao fossem liberadas aqui.
	var painel := $"%PainelDisciplinas"
	for chave in painel.cards_disciplinas.keys():
		if _dados._planejamento_csv.get(chave, {}).get("referencia", false):
			painel.cards_disciplinas[chave].queue_free()
			painel.cards_disciplinas.erase(chave)
	for chave in _dados._planejamento_csv.keys():
		if _dados._planejamento_csv[chave].get("referencia", false):
			_dados._planejamento_csv.erase(chave)


# Verdadeiro se ha alguma disciplina de referencia sobreposta no momento.
func _ha_referencia() -> bool:
	for chave in _dados._planejamento_csv:
		if _dados._planejamento_csv[chave].get("referencia", false):
			return true
	return false


# Recomputa ch_alocada de TODOS os cards a partir das alocacoes atuais (suas + referencia). Necessario
# apos popular(), que recria os cards zerando ch_alocada.
func _recomputar_ch_alocada() -> void:
	var cards: Dictionary = $"%PainelDisciplinas".cards_disciplinas
	for chave in cards:
		cards[chave].ch_alocada = 0
	for chave_celula in _ger_alocacoes.alocacoes:
		for aloc in _ger_alocacoes.alocacoes[chave_celula]:
			var card: CardDisciplina = cards.get((aloc as Dictionary).get("chave", ""))
			if card:
				card.ch_alocada += 1


# Dialogo customizado para informar/editar URL, usuario e token do servidor. Persiste via override
# (sinal override_config -> main.gd grava em config_usuario.json:sincronizacao).
func _configurar_sincronizacao() -> void:
	var sinc: Dictionary = GV.configuracao_base.get("sincronizacao", {})
	var dialog := ConfirmationDialog.new()
	dialog.title = "Configurar servidor de sincronizacao"
	dialog.get_ok_button().text = "Salvar"
	dialog.get_cancel_button().text = "Cancelar"

	var vbox := VBoxContainer.new()
	dialog.add_child(vbox)
	var ed_url := LineEdit.new()
	ed_url.placeholder_text = "http://host:8888/v1"
	ed_url.text = str(sinc.get("url", ""))
	ed_url.custom_minimum_size = Vector2(380, 0)
	var ed_user := LineEdit.new()
	ed_user.text = str(sinc.get("usuario", ""))
	var ed_token := LineEdit.new()
	ed_token.secret = true
	ed_token.text = str(sinc.get("token", ""))
	for par in [["Endereco do servidor (URL da API):", ed_url], ["Usuario:", ed_user], ["Senha (token):", ed_token]]:
		var rotulo := Label.new()
		rotulo.text = par[0]
		vbox.add_child(rotulo)
		vbox.add_child(par[1])
	DicaFlutuante.vincular(ed_token, "E a [b]mesma senha[/b] que o administrador criou para a sua conta " \
		+ "no servidor (no Kinto, a senha da conta funciona como token de acesso).")

	dialog.confirmed.connect(func():
		var u: String = ed_url.text.strip_edges()
		var us: String = ed_user.text.strip_edges()
		# Token sem strip_edges(): a senha pode ter espaco no inicio/fim de proposito (ver configurar()).
		var tk: String = ed_token.text
		override_config.emit(["sincronizacao", "url"], u)
		override_config.emit(["sincronizacao", "usuario"], us)
		override_config.emit(["sincronizacao", "token"], tk)
		_sync.configurar(u, us, tk)
		$"%Terminal".text_edit("Configuracao de sincronizacao salva.", "sucesso", true, false))
	dialog.visibility_changed.connect(func():
		if not dialog.visible:
			dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()
	Dialogos.limitar_a_tela(dialog)


## Abre um [FileDialog] para selecionar um CSV externo, converte para UTF-8 e o salva
## como [code]planejamento.csv[/code] no diretorio de saida (sobreescrevendo o existente).
## Util quando o CSV vem em encoding diferente de UTF-8 e precisa ser normalizado.
func _converter_planejamento_csv() -> void:
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.title = "Selecionar planejamento para converter"
	fd.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
	fd.add_filter("*.csv", "Arquivos CSV")
	fd.file_selected.connect(func(path: String):
		var dir_in: String = path.get_base_dir() + "/"
		var file_name: String = path.get_file()
		file_handling.convertto_utf8(dir_in, file_name, GV.dir_saida, "planejamento.csv")
		$"%Terminal".text_edit("%s convertido e salvo como planejamento.csv em %s." \
			% [file_name, GV.dir_saida], "sucesso", true, true)
		fd.queue_free()
		# Encadeia direto na selecao de cursos para importar o arquivo recem-convertido,
		# poupando o usuario de abrir manualmente "Arquivo > Abrir planejamento.csv".
		if FileAccess.file_exists(GV.dir_saida + "planejamento.csv"):
			_abrir_janela_selecao_cursos_planejamento())
	fd.canceled.connect(fd.queue_free)
	add_child(fd)
	fd.popup_centered()
	Dialogos.limitar_a_tela(fd)


## Abre um [FileDialog] para o usuario selecionar arquivos CSV ou XLSX de preferencias
## de horarios de professores. Converte de Windows-1252 para UTF-8 se necessario (via
## [code]ansi_to_utf8.exe[/code]) e, para arquivos XLSX, converte para CSV antes (via
## [code]xlsx_to_csv.exe[/code] em [code]externo/bin/[/code]). O arquivo final e salvo
## em [member diretorio_regras] com o nome original.
func _importar_preferencias_professor() -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
	dialog.add_filter("*.csv", "CSV (*.csv)")
	dialog.add_filter("*.xlsx", "Excel (*.xlsx)")
	dialog.title = "Importar preferencias de horario"
	dialog.file_selected.connect(_on_preferencia_arquivo_selecionado.bind(dialog))
	dialog.files_selected.connect(_on_preferencia_arquivos_selecionados.bind(dialog))
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()
	Dialogos.limitar_a_tela(dialog)


func _on_preferencia_arquivo_selecionado(caminho: String, dialog: FileDialog) -> void:
	dialog.queue_free()
	await get_tree().process_frame
	_importar_arquivo_preferencia(caminho)


func _on_preferencia_arquivos_selecionados(caminhos: PackedStringArray, dialog: FileDialog) -> void:
	dialog.queue_free()
	await get_tree().process_frame
	for caminho in caminhos:
		_importar_arquivo_preferencia(caminho)


## Importa um arquivo de preferencias ([param caminho]) para [member diretorio_regras],
## convertendo encoding e formato conforme necessario.
func _importar_arquivo_preferencia(caminho: String) -> void:
	var ext: String = caminho.get_extension().to_lower()
	var nome_base: String = caminho.get_file().trim_suffix("." + ext)
	var nome_arquivo: String = nome_base + ".csv"

	var csv_para_importar: String = caminho
	var temp_xlsx: String = ""
	if ext == "xlsx":
		DirAccess.make_dir_recursive_absolute(GV.dir_temp)
		temp_xlsx = GV.dir_temp + nome_arquivo
		if not file_handling.converter_xlsx_para_csv(caminho, temp_xlsx):
			$"%Terminal".text_edit("Conversor .xlsx nao encontrado. Coloque xlsx_to_csv.exe em externo/bin/ para importar arquivos Excel.", \
				"erro", true, false)
			return
		csv_para_importar = temp_xlsx

	var precisa_conversao: bool = false
	var f := FileAccess.open(csv_para_importar, FileAccess.READ)
	if f != null:
		var raw: PackedByteArray = f.get_buffer(f.get_length())
		f.close()
		var teste_utf8: String = raw.get_string_from_utf8()
		precisa_conversao = "\uFFFD" in teste_utf8

	var destino_final: String
	if precisa_conversao:
		DirAccess.make_dir_recursive_absolute(GV.dir_temp)
		var temp_nome: String = nome_arquivo
		file_handling.convertto_utf8(csv_para_importar.get_base_dir() + "/", nome_arquivo, GV.dir_temp, temp_nome)
		var temp_path: String = GV.dir_temp + temp_nome
		var utf8_file := FileAccess.open(temp_path, FileAccess.READ)
		if utf8_file == null:
			$"%Terminal".text_edit("Erro ao ler arquivo convertido: " + temp_path, \
				"erro", true, false)
			if not temp_xlsx.is_empty():
				DirAccess.remove_absolute(temp_xlsx)
			return
		var utf8_bytes: PackedByteArray = utf8_file.get_buffer(utf8_file.get_length())
		utf8_file.close()
		DirAccess.make_dir_recursive_absolute(diretorio_regras)
		var destino := FileAccess.open(diretorio_regras + "/" + nome_arquivo, FileAccess.WRITE)
		if destino == null:
			$"%Terminal".text_edit("Erro ao salvar arquivo em " + diretorio_regras, \
				"erro", true, false)
			DirAccess.remove_absolute(temp_path)
			if not temp_xlsx.is_empty():
				DirAccess.remove_absolute(temp_xlsx)
			return
		destino.store_buffer(utf8_bytes)
		destino.close()
		DirAccess.remove_absolute(temp_path)
		destino_final = diretorio_regras + "/" + nome_arquivo
	else:
		DirAccess.make_dir_recursive_absolute(diretorio_regras)
		var err := DirAccess.copy_absolute(csv_para_importar, diretorio_regras + "/" + nome_arquivo)
		if err != OK:
			$"%Terminal".text_edit("Erro ao copiar arquivo para " + diretorio_regras, \
				"erro", true, false)
			if not temp_xlsx.is_empty():
				DirAccess.remove_absolute(temp_xlsx)
			return
		destino_final = diretorio_regras + "/" + nome_arquivo

	if not temp_xlsx.is_empty():
		DirAccess.remove_absolute(temp_xlsx)

	$"%Terminal".text_edit("Importado: " + destino_final, \
		"sucesso", true, false)


## Importa o [code]planejamento.json[/code] exportado do modulo Planejamento de Oferta.
## O arquivo e lido de [member diretorio_exportacao] e seus dados sao convertidos
## para o formato [code]_planejamento_csv[/code] de [PlanejamentoDados].
func _importar_planejamento_json() -> void:
	var caminho: String = diretorio_exportacao + "planejamento.json"
	if not FileAccess.file_exists(caminho):
		$"%Terminal".text_edit("Nenhum planejamento.json encontrado em " + diretorio_exportacao \
			+ ". Exporte um planejamento no modulo Planejamento de Oferta primeiro.", \
			"erro", true, true)
		return
	var dados: Dictionary = file_handling.load_json(diretorio_exportacao, "planejamento.json")
	if dados.is_empty() or not dados.has("disciplinas"):
		$"%Terminal".text_edit("planejamento.json com formato invalido.", \
			"erro", true, true)
		return

	# Remove qualquer camada de referencia (outros cursos) antes de carregar o proprio plano, para
	# nao deixar alocacoes de referencia orfas na grade (o clear() abaixo so limpa o _planejamento_csv).
	_remover_dados_referencia()
	# Converte o JSON para o formato _planejamento_csv.
	_dados._planejamento_csv.clear()
	var disciplinas: Array = dados["disciplinas"]
	for disc in disciplinas:
		if not disc is Dictionary:
			continue
		var codigo: String = str(disc.get("codigo", "")).to_lower()
		var semestre: String = str(disc.get("semestre", ""))
		if codigo.is_empty():
			continue
		var chave: String = codigo + "_" + semestre.to_lower()
		var professores: Array = disc.get("professores", [])
		var nomes: Array[String] = []
		var chs: Array[String] = []
		var ch_total: int = 0
		for p in professores:
			if p is Dictionary:
				var pn: String = str(p.get("nome", ""))
				var pc: int = int(p.get("ch", 0))
				if not pn.is_empty():
					nomes.append(pn)
					chs.append(str(pc))
					ch_total += pc
		# Se a chave ja existe, mescla professores (evita perda de dados).
		if _dados._planejamento_csv.has(chave):
			var existente: Dictionary = _dados._planejamento_csv[chave]
			for i in nomes.size():
				existente["professor"].append(nomes[i])
				existente["ch"].append(chs[i])
			var ch_antigo: int = int(existente.get("ch_disciplina", "0"))
			existente["ch_disciplina"] = str(ch_antigo + ch_total)
		else:
			_dados._planejamento_csv[chave] = {
				"codigo": codigo,
				"semestre": semestre,
				"professor": nomes,
				"ch": chs,
				# Espelha o caminho CSV (file_handling.gd): oferta = celula de semestre da
				# disciplina, preservando o compartilhamento entre cursos (ex.: "EM02;ECExtra").
				# JSONs antigos sem o campo caem no semestre (oferta == semestre = sem compartilhar).
				"oferta": str(disc.get("oferta", semestre)),
				"ch_disciplina": str(ch_total),
			}

	if _dados._planejamento_csv.is_empty():
		$"%Terminal".text_edit("Nenhuma disciplina valida encontrada no planejamento.json.", \
			"aviso", true, true)
		return

	_dados.adicionar_planejamento()
	var converted: Array = horarios_exe.exportar_horariostxt(_dados._horarios_txt_lista["planejamento"])
	_dados.imprimir_horarios_txt($"%Terminal", converted, "padrao")
	_sincronizar_referencias()
	$"%PainelDisciplinas".popular(_dados._planejamento_csv, $"%Terminal", false)

	# Aplica as alocações (alocacoes) do JSON na grade.
	var dias_json: Array[String] = analise_horarios.dias_da_semana(_dados._horarios_ini)
	var horas_json: Array[String] = analise_horarios.horas_das_aulas(_dados._horarios_ini)
	var painel_json := $"%PainelDisciplinas"
	var cont_aloc: int = 0
	for disc in disciplinas:
		if not disc is Dictionary:
			continue
		var codigo_json: String = str(disc.get("codigo", "")).to_lower()
		var semestre_json: String = str(disc.get("semestre", ""))
		if codigo_json.is_empty():
			continue
		var chave_json: String = codigo_json + "_" + semestre_json.to_lower()
		var alocacoes_json: Array = disc.get("alocacoes", [])
		if alocacoes_json.is_empty():
			continue
		for aloc_item in alocacoes_json:
			if not aloc_item is Dictionary:
				continue
			var horario_str: String = str(aloc_item.get("horario", ""))
			var dia_str: String = str(aloc_item.get("dia", ""))
			var col_idx: int = dias_json.find(dia_str) + 1
			var row_idx: int = horas_json.find(horario_str) + 1
			if col_idx <= 0 or row_idx <= 0:
				continue
			var aloc_data: Dictionary = {
				"chave": chave_json,
				"codigo": codigo_json,
				"professor": str(aloc_item.get("professor", "")),
				"semestre": semestre_json,
				"sala": str(aloc_item.get("sala", "")),
				"tipo": str(aloc_item.get("tipo", "")),
				"turma": str(aloc_item.get("turma", "")),
				"vagas": str(aloc_item.get("vagas", "Vagas")),
				"p": str(aloc_item.get("p", "1")),
				"s": str(aloc_item.get("s", "1")),
				"t": str(aloc_item.get("t", "1")),
			}
			_ger_alocacoes.alocar("%d_%d" % [row_idx, col_idx], aloc_data)
			var card_json: CardDisciplina = painel_json.cards_disciplinas.get(chave_json)
			if card_json:
				card_json.ch_alocada += 1
			cont_aloc += 1
	_sincronizar_referencias()
	_ger_alocacoes.reaplicar_todas()
	_detectar_choques()
	$"%Terminal".text_edit("Planejamento importado de planejamento.json (%d disciplinas, %d alocações, %s)." \
		% [_dados._planejamento_csv.size(), cont_aloc, caminho], "sucesso", true, false)

func _on_acoes_opcao_selecionada(retorno: String, _lista_selecionada: Array[String]) -> void:
	match retorno:
		"posicionar_automatico":
			_abrir_config_posicionamento()
		"limpar_preenchimento":
			_confirmar_limpar_grade()
		"atualizar_planejamento":
			_on_mesclar_csv_e_txt_button_up()

func _confirmar_limpar_grade() -> void:
	Dialogos.confirmar(self, "Limpar preenchimento", \
		"Você tem certeza? Todas as alocações na grade serão removidas.", \
		_nova_grade, "Sim, limpar")

func _nova_grade() -> void:
	for chave_celula in _ger_alocacoes.alocacoes:
		var partes: PackedStringArray = str(chave_celula).split("_")
		if partes.size() == 2:
			_ger_alocacoes.limpar_celula(int(partes[0]), int(partes[1]))
	_ger_alocacoes.limpar_alocacoes()
	for card in $"%PainelDisciplinas".cards_disciplinas.values():
		card.ch_alocada = 0
		card.ch_extra = 0
		card.permite_extra = false
	$"%GradeHorarios".larguras_colunas = []
	$"%GradeHorarios".dados = _dados.gerar_matriz_vazia()
	_ger_alocacoes.reaplicar_todas()
	_detectar_choques()
	$"%Terminal".text_edit("Grade limpa. Recomece as alocações.", \
		"sucesso", true, false)

# Cards a considerar no posicionamento automatico: todos quando nao ha filtro de curso ativo, ou
# apenas os do curso filtrado (ex.: so ECxx com Engenharia Civil selecionada). As alocacoes
# existentes de outros cursos seguem inteiras como restricao de ocupacao (passadas a parte ao
# posicionador), mas so as disciplinas do curso filtrado sao posicionadas.
func _cards_para_posicionar() -> Dictionary:
	var painel := $"%PainelDisciplinas"
	var fc: String = painel.filtro_curso
	if fc.is_empty():
		return painel.cards_disciplinas
	var resultado: Dictionary = {}
	for chave in painel.cards_disciplinas:
		var card: CardDisciplina = painel.cards_disciplinas[chave]
		if painel.semestre_pertence_ao_curso(card.semestre, fc):
			resultado[chave] = card
	return resultado

# Disciplinas pendentes compartilhadas entre cursos distintos (oferta reunindo semestres de mais de
# um curso, ex.: "EC01;EM01"). Cada código aparece uma única vez, com a oferta entre parênteses para
# contexto. Usada para avisar o usuário antes do posicionamento automático.
func _compartilhadas_entre_cursos_pendentes(cards_alvo: Dictionary) -> Array[String]:
	var achadas: Array[String] = []
	var vistos: Dictionary = {}
	for chave in cards_alvo:
		var card: CardDisciplina = cards_alvo[chave]
		if card.ch_total <= 0 or card.ch_alocada >= card.ch_total:
			continue
		if not _oferta_cruza_cursos(card.oferta):
			continue
		var cod: String = card.codigo.to_lower()
		if vistos.has(cod):
			continue
		vistos[cod] = true
		achadas.append("• %s — %s (%s)" % [card.codigo.to_upper(), card.nome, card.oferta.to_upper()])
	return achadas

# Verdadeiro quando a string de oferta reúne semestres de mais de um curso (ex.: "EC01;EM01").
# Espelha os separadores aceitos por CardDisciplina (";", "/", "-").
func _oferta_cruza_cursos(oferta: String) -> bool:
	var s: String = oferta.strip_edges()
	if s.is_empty():
		return false
	var partes: PackedStringArray = PackedStringArray([s])
	for delim in [";", "/", "-"]:
		if s.contains(delim):
			partes = s.split(delim)
			break
	var cursos_vistos: Dictionary = {}
	for parte in partes:
		var cod: String = _curso_de_semestre(parte.strip_edges())
		if not cod.is_empty():
			cursos_vistos[cod] = true
	return cursos_vistos.size() > 1

# Identifica o cod_curso de um rótulo de semestre (ex.: "EC01" → "alec") pelos prefixos em cursos.
# Retorna "" quando nenhum prefixo casa. Primeiro prefixo casado vence (como no painel).
func _curso_de_semestre(sem: String) -> String:
	var sem_upper: String = sem.to_upper().strip_edges()
	for cod in cursos.keys():
		for prefixo in cursos[cod].get("prefixos_semestre", []):
			if sem_upper.begins_with(str(prefixo).to_upper()):
				return cod
	return ""


# Compara, para cada disciplina compartilhada entre cursos, as células do SEU lado (editável) com as
# do lado de cada curso de REFERÊNCIA (somente-leitura). Quando os horários não coincidem, gera uma
# linha de divergência. Vazio quando não há referência ou quando todas estão alinhadas.
func _verificar_compartilhadas_divergentes() -> Array[String]:
	if not _ha_referencia():
		return []
	var dias: Array[String] = analise_horarios.dias_da_semana(_dados._horarios_ini)
	var horas: Array[String] = analise_horarios.horas_das_aulas(_dados._horarios_ini)
	# por_codigo[cod] = { "seu": {cel:true}, "ref": { curso_origem: {cel:true} } }
	var por_codigo: Dictionary = {}
	for chave_celula in _ger_alocacoes.alocacoes:
		for a in _ger_alocacoes.alocacoes[chave_celula]:
			var aloc: Dictionary = a
			var cod: String = str(aloc.get("codigo", "")).to_lower()
			if cod.is_empty():
				continue
			var oferta: String = _dados._planejamento_csv.get(aloc.get("chave", ""), {}).get("oferta", "")
			if not _oferta_cruza_cursos(oferta):
				continue
			if not por_codigo.has(cod):
				por_codigo[cod] = { "seu": {}, "ref": {} }
			if _aloc_e_referencia(aloc):
				var curso: String = str(aloc.get("curso_origem", "?"))
				if not por_codigo[cod]["ref"].has(curso):
					por_codigo[cod]["ref"][curso] = {}
				por_codigo[cod]["ref"][curso][chave_celula] = true
			else:
				por_codigo[cod]["seu"][chave_celula] = true
	var divergencias: Array[String] = []
	for cod in por_codigo:
		var seu: Dictionary = por_codigo[cod]["seu"]
		var refs: Dictionary = por_codigo[cod]["ref"]
		if seu.is_empty() or refs.is_empty():
			continue  # precisa dos dois lados para comparar
		for curso in refs:
			if not _mesmas_celulas(seu, refs[curso]):
				divergencias.append("• %s — você: %s · %s: %s" % [cod.to_upper(), \
					_descrever_celulas(seu, dias, horas), curso, \
					_descrever_celulas(refs[curso], dias, horas)])
	return divergencias


# Verdadeiro se os dois conjuntos de células ("linha_coluna") são exatamente iguais.
func _mesmas_celulas(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for chave in a:
		if not b.has(chave):
			return false
	return true


# Converte um conjunto de células ("linha_coluna") em texto legível "Dia HH:MM", ordenado.
func _descrever_celulas(celulas: Dictionary, dias: Array[String], horas: Array[String]) -> String:
	var partes: Array[String] = []
	for chave_celula in celulas:
		var p: PackedStringArray = chave_celula.split("_")
		if p.size() != 2:
			continue
		var linha: int = int(p[0])
		var coluna: int = int(p[1])
		var dia: String = dias[coluna - 1] if coluna > 0 and coluna <= dias.size() else "?"
		var hora: String = horas[linha - 1] if linha > 0 and linha <= horas.size() else "?"
		partes.append("%s %s" % [dia, hora])
	partes.sort()
	return ", ".join(partes) if not partes.is_empty() else "(não alocada)"

# Abre o diálogo de configuração do posicionamento automático, se houver disciplinas pendentes
# (restritas ao curso filtrado, quando há filtro ativo).
func _abrir_config_posicionamento() -> void:
	var cards_alvo: Dictionary = _cards_para_posicionar()
	# Cards não completos (com ou sem CH) — o que ainda precisa de horário. Cards sem CH entram aqui
	# para que o diagnóstico possa alertar (em vermelho) quando nenhum tem carga horária.
	var nao_completos: int = 0
	for chave in cards_alvo:
		var card: CardDisciplina = cards_alvo[chave]
		if not (card.ch_total > 0 and card.ch_alocada >= card.ch_total):
			nao_completos += 1
	var fc: String = $"%PainelDisciplinas".filtro_curso
	var nome_curso_filtro: String = cursos.get(fc, {}).get("nome", fc) if not fc.is_empty() else ""
	if nao_completos == 0:
		var sufixo: String = " do curso %s" % nome_curso_filtro if not nome_curso_filtro.is_empty() else ""
		$"%Terminal".text_edit("Nenhuma disciplina pendente%s para posicionar. Importe um planejamento primeiro." % sufixo, \
			"aviso", true, true)
		return
	var diagnostico: Array = _diagnostico_posicionamento(cards_alvo)
	# Disciplinas pendentes compartilhadas entre cursos: posicioná-las é uma decisão conjunta dos
	# cursos envolvidos, então avisamos e deixamos o usuário optar por fazê-lo manualmente antes
	# (incluindo a opção de posicionar só as não compartilhadas agora).
	var compartilhadas: Array[String] = _compartilhadas_entre_cursos_pendentes(cards_alvo)
	if compartilhadas.is_empty():
		_excluir_compartilhadas_posic = false
		_config_posic.abrir(_inicio_manha_posic, _permitir_sabado_posic, nome_curso_filtro, diagnostico)
		return
	_avisar_compartilhadas(compartilhadas, nome_curso_filtro, diagnostico)

# Aviso (3 saídas) exibido quando há disciplinas pendentes compartilhadas entre cursos: a lista pode
# ser longa, então usa Dialogos.escolha_lista (cabeçalho + lista rolável + ações), que não estoura a
# tela. OK = posicionar todas; ação extra = posicionar só as não compartilhadas; Cancelar = desistir.
func _avisar_compartilhadas(compartilhadas: Array[String], nome_curso_filtro: String, diagnostico: Array) -> void:
	var cabecalho: String = "As seguintes disciplinas pendentes são compartilhadas entre cursos:"
	var rodape: String = "Como o horário delas é uma decisão conjunta dos cursos envolvidos, você pode " \
		+ "preferir posicioná-las manualmente antes. O que deseja fazer?"
	var abrir_todas := func():
		_excluir_compartilhadas_posic = false
		_config_posic.abrir(_inicio_manha_posic, _permitir_sabado_posic, nome_curso_filtro, diagnostico)
	var abrir_nao_compartilhadas := func():
		_excluir_compartilhadas_posic = true
		_config_posic.abrir(_inicio_manha_posic, _permitir_sabado_posic, nome_curso_filtro, diagnostico)
	var acoes: Array = [
		{"texto": "Posicionar todas", "ao_acionar": abrir_todas},
		{"texto": "Apenas as não compartilhadas", "ao_acionar": abrir_nao_compartilhadas},
	]
	Dialogos.escolha_lista(self, "Disciplinas compartilhadas entre cursos", cabecalho, \
		compartilhadas, rodape, acoes, "Cancelar")

# Monta o diagnóstico de pré-requisitos do posicionamento para [param cards_alvo] (já restritos ao
# curso filtrado, quando há filtro). Cada item é { "texto": String, "token": String, "bloqueia": bool },
# com o token de cor: "erro" (vermelho — obrigatório ausente, bloqueia), "alerta" (laranja — presente
# mas incompleto), "aviso" (amarelo — opcional ausente) e "sucesso" (verde — ok). Só a carga horária
# do planejamento é obrigatória; grade, hist.csv e preferências são opcionais.
func _diagnostico_posicionamento(cards_alvo: Dictionary) -> Array:
	var itens: Array = []
	var com_ch: int = 0
	var sem_ch: int = 0
	var fora_grade: int = 0
	var profs: Dictionary = {}
	for chave in cards_alvo:
		var card: CardDisciplina = cards_alvo[chave]
		if card.ch_total > 0 and card.ch_alocada >= card.ch_total:
			continue  # já completa: não é pendente
		if card.ch_total > 0:
			com_ch += 1
		else:
			sem_ch += 1
		var nome_grade: String = analise_grades.info_grade(grades_disciplinas_curriculos, card.codigo, "nome", "", true)
		if nome_grade.begins_with("Codigo") or nome_grade.begins_with("Informa"):
			fora_grade += 1
		for p in card.professores:
			profs[str(p).to_lower()] = true
	var total_pend: int = com_ch + sem_ch

	# 1) Carga horária (planejamento) — OBRIGATÓRIO.
	if com_ch == 0:
		itens.append({"texto": "Carga horária ausente: nenhuma disciplina pendente tem CH definida — não há o que posicionar. Importe um planejamento com carga horária.", "token": "erro", "bloqueia": true})
	elif sem_ch > 0:
		itens.append({"texto": "Carga horária incompleta: %d de %d disciplinas pendentes sem CH (não serão posicionadas)." % [sem_ch, total_pend], "token": "alerta", "bloqueia": false})
	else:
		itens.append({"texto": "Carga horária: %d disciplina(s) pendente(s) com CH definida." % com_ch, "token": "sucesso", "bloqueia": false})

	# 2) Grade curricular — opcional (fornece nome/classificação; não impede o posicionamento).
	if total_pend > 0 and fora_grade == total_pend:
		itens.append({"texto": "Grade curricular não carregada: as disciplinas aparecem só pelo código (opcional; não impede posicionar).", "token": "aviso", "bloqueia": false})
	elif fora_grade > 0:
		itens.append({"texto": "Grade curricular incompleta: %d disciplina(s) pendente(s) sem correspondência na grade." % fora_grade, "token": "alerta", "bloqueia": false})
	else:
		itens.append({"texto": "Grade curricular: todas as disciplinas reconhecidas.", "token": "sucesso", "bloqueia": false})

	# 3) hist.csv — opcional (peso de choque entre alunos). Verde só quando o histórico cobre as
	# disciplinas deste escopo: um hist.csv de outro curso (sem alunos nas pendentes) não influencia
	# o choque de alunos aqui, então vira aviso (amarelo) em vez de sucesso.
	if _historico.is_empty():
		itens.append({"texto": "hist.csv não carregado: o choque entre alunos não será considerado (opcional).", "token": "aviso", "bloqueia": false})
	else:
		var presentes: Dictionary = _disciplinas_no_historico()
		var cods_pend: Dictionary = {}
		for chave in cards_alvo:
			var card: CardDisciplina = cards_alvo[chave]
			if card.ch_total <= 0 or card.ch_alocada >= card.ch_total:
				continue  # só as que serão de fato posicionadas (com CH e incompletas)
			cods_pend[card.codigo.to_lower()] = true
		var com_alunos: int = 0
		for cod in cods_pend:
			if presentes.has(cod):
				com_alunos += 1
		# Verde só acima de um limiar de cobertura (config; padrão 80%): basta um aluno numa turma
		# compartilhada para uma disciplina "contar", então exigir cobertura ampla evita o falso verde
		# de um histórico que mal toca o curso. Abaixo do limiar (ou zero), vira aviso (amarelo).
		var cobertura_min: float = float(config_posicionamento.get("diagnostico_hist_cobertura_min", 0.8))
		var cobertura: float = float(com_alunos) / float(cods_pend.size()) if not cods_pend.is_empty() else 0.0
		if com_alunos == 0:
			itens.append({"texto": "hist.csv carregado, mas sem alunos das disciplinas deste escopo (ex.: histórico de outro curso): o choque entre alunos não será considerado.", "token": "aviso", "bloqueia": false})
		elif cobertura < cobertura_min:
			itens.append({"texto": "hist.csv carregado, mas cobre só %d de %d disciplina(s) pendente(s) (%d%%, abaixo de %d%%): o choque entre alunos terá efeito parcial." % [com_alunos, cods_pend.size(), int(round(cobertura * 100.0)), int(round(cobertura_min * 100.0))], "token": "aviso", "bloqueia": false})
		else:
			itens.append({"texto": "hist.csv carregado: choque entre alunos considerado (%d de %d disciplina(s) pendente(s) com histórico)." % [com_alunos, cods_pend.size()], "token": "sucesso", "bloqueia": false})

	# 4) Preferências dos professores — opcional (sem arquivo = professor sem restrição de horário).
	var com_pref: int = 0
	for pl in profs:
		if not _arquivo_preferencias_de(pl).is_empty():
			com_pref += 1
	var total_profs: int = profs.size()
	if total_profs == 0:
		pass  # nenhuma pendente com professor: nada a relatar
	elif com_pref == 0:
		itens.append({"texto": "Preferências de horário: nenhum dos %d professores tem arquivo (opcional; sem restrição)." % total_profs, "token": "aviso", "bloqueia": false})
	elif com_pref < total_profs:
		itens.append({"texto": "Preferências de horário: %d de %d professores com arquivo." % [com_pref, total_profs], "token": "aviso", "bloqueia": false})
	else:
		itens.append({"texto": "Preferências de horário: todos os %d professores têm arquivo." % total_profs, "token": "sucesso", "bloqueia": false})

	return itens

# Conjunto (cod_disciplina minúsculo → true) das disciplinas presentes no histórico sob as condições
# de choque selecionadas. Usado pelo diagnóstico para saber se o hist.csv cobre o curso em questão —
# se nenhuma pendente do escopo aparecer aqui, o choque de alunos não terá efeito. Construído uma vez
# (varre matrículas × condições), em vez de consultar disciplina a disciplina.
func _disciplinas_no_historico() -> Dictionary:
	var presentes: Dictionary = {}
	var conds: Array = _condicoes_choque_selecionadas if not _condicoes_choque_selecionadas.is_empty() else condicoes
	for matricula in _condicoes_discentes:
		var cond_disc: Dictionary = _condicoes_discentes[matricula]
		for c in conds:
			for cod in cond_disc.get(c, []):
				presentes[str(cod).to_lower()] = true
	return presentes

# Roda o posicionador com a configuração escolhida (turno inicial e sábado) e aplica o plano na
# grade. As preferências de cada professor são lidas dos CSVs; o choque de alunos vem do Callable.
func _on_config_posicionamento_definida(cfg: Dictionary) -> void:
	_inicio_manha_posic = bool(cfg.get("inicio_manha", true))
	_permitir_sabado_posic = bool(cfg.get("permitir_sabado", false))
	var grade: GradeVisual = $"%GradeHorarios"
	var dias: Array[String] = analise_horarios.dias_da_semana(_dados._horarios_ini)
	var horas: Array[String] = analise_horarios.horas_das_aulas(_dados._horarios_ini)
	var config: Dictionary = config_posicionamento.duplicate(true)
	config["inicio_manha"] = _inicio_manha_posic
	config["permitir_sabado"] = _permitir_sabado_posic
	_posicionador.configurar([grade._linhas, grade._colunas], horas, dias, \
		_cards_alvo_posicionamento(), _ger_alocacoes.alocacoes, _dados._planejamento_csv, \
		_montar_preferencias_professores(), config, Callable(self, "_peso_choque_alunos"))
	_aplicar_plano_posicionamento(_posicionador.gerar_plano())

# Cards efetivamente posicionados: os do escopo (curso filtrado, via _cards_para_posicionar),
# removendo as disciplinas compartilhadas entre cursos quando o usuário optou por posicionar só as
# não compartilhadas. As alocações já existentes de qualquer card seguem como restrição de ocupação.
func _cards_alvo_posicionamento() -> Dictionary:
	var cards: Dictionary = _cards_para_posicionar()
	if not _excluir_compartilhadas_posic:
		return cards
	var resultado: Dictionary = {}
	for chave in cards:
		var card: CardDisciplina = cards[chave]
		if _oferta_cruza_cursos(card.oferta):
			continue
		resultado[chave] = card
	return resultado

# Monta { nome_professor_minúsculo: { "linha_coluna": valor 1..5 } } lendo os CSVs de preferências
# dos professores presentes no painel. Professores sem arquivo ficam de fora (o posicionador os
# trata como sem restrição de horário). Cada professor é resolvido uma única vez.
func _montar_preferencias_professores() -> Dictionary:
	var preferencias: Dictionary = {}
	var tentados: Dictionary = {}
	for chave in $"%PainelDisciplinas".cards_disciplinas:
		var profs: Array = _dados._planejamento_csv.get(chave, {}).get("professor", [])
		if profs.is_empty():
			profs = $"%PainelDisciplinas".cards_disciplinas[chave].professores
		for prof in profs:
			var pl: String = str(prof).to_lower()
			if tentados.has(pl):
				continue
			tentados[pl] = true
			var arquivo: String = _arquivo_preferencias_de(str(prof))
			if not arquivo.is_empty():
				preferencias[pl] = _dados.ler_preferencias_professor(arquivo)
	return preferencias

# Callable do posicionador: nº de discentes que cursariam ambas as disciplinas, nas condições
# selecionadas no SeletorCondicoesChoque. Retorna 0 quando não há hist.csv carregado.
func _peso_choque_alunos(cod_a: String, cod_b: String) -> int:
	if _condicoes_discentes.is_empty() or _condicoes_choque_selecionadas.is_empty():
		return 0
	return analise_historico.comparar_discentes_disciplina(cod_a, cod_b, \
		_condicoes_discentes, _condicoes_choque_selecionadas).size()

# Aplica o plano do posicionador: aloca cada slot, atualiza a CH dos cards, imprime o relatório do
# posicionamento (título + filtro de curso + não alocadas) e repinta a grade. Os choques resultantes
# são reportados em seguida por _refrescar_apos_alocacao (logo abaixo no terminal).
func _aplicar_plano_posicionamento(plano: Dictionary) -> void:
	for item in plano.get("alocacoes", []):
		_ger_alocacoes.alocar("%d_%d" % [item["linha"], item["coluna"]], item["aloc"])
		var card: CardDisciplina = $"%PainelDisciplinas".cards_disciplinas.get(item["chave"])
		if card:
			card.ch_alocada += 1
			# Disciplina compartilhada: atualiza cards irmãos (mesmo código).
			var cod_base: String = card.codigo.to_lower()
			for chave_irma in $"%PainelDisciplinas".cards_disciplinas:
				var irma: CardDisciplina = $"%PainelDisciplinas".cards_disciplinas[chave_irma]
				if irma.codigo.to_lower() == cod_base and chave_irma != item["chave"]:
					irma.ch_alocada += 1
	_sincronizar_referencias()
	var fc: String = $"%PainelDisciplinas".filtro_curso
	var nome_curso: String = cursos.get(fc, {}).get("nome", fc) if not fc.is_empty() else ""
	_relatorios.posicionamento(plano, nome_curso)
	_refrescar_apos_alocacao()

#endregion
