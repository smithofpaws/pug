class_name PlanejamentoOferta extends ReferenceRect
## Relacionado ao planejamento da oferta de disciplinas.
## [br]
## Permite importar, visualizar e editar o planejamento de oferta do semestre.
## [br]
## Ao clicar em uma disciplina no painel, exibe o painel de atribuicoes com
## professores alocados, CH editavel e ranking de afinidade baseado no
## [code]historico_professores.json[/code].
## [br]
## Inclui verificador de carga horaria (limites min/ideal/max definidos em
## [code]base_config.json[/code]).

# Classes instanciadas.
var file_handling := FileHandling.new()
var analise_grades := AnaliseGrades.new()
var analise_historico := AnaliseHistorico.new()

# Motor de afinidade (indice reverso + scoring) e gerador dos relatorios das Acoes.
var _afinidade := AnaliseAfinidade.new()
var _relatorios := RelatoriosOferta.new()

# Referencia tipada ao script do terminal (que nao expoe class_name proprio).
const TerminalRef := preload("res://scenes/Complementares/Terminal/terminal.gd")

# Nos da cena, resolvidos uma unica vez.
@onready var _seletor_importar: SeletorAvancado = $"%SeletorImportar"
@onready var _seletor_acoes: SeletorAvancado = $"%SeletorAcoes"
@onready var _painel_disciplinas: PainelDisciplinas = $"%PainelDisciplinas"
@onready var _painel_atribuicoes: PainelAtribuicoes = $"%PainelAtribuicoes"
@onready var _terminal: TerminalRef = $"%Terminal"
@onready var _status_bar: StatusBar = $"%StatusBar"

## Grade curricular embutida (toggle via OnOffGrade): mostra a grade com celulas pintadas conforme a
## alocacao e a demanda (quantos discentes podem cursar) no rodape de cada celula.
@onready var _grade_curricular: GradeCurricular = $"%GradeCurricular"

#region Dados injetados pelo main

## Grades curriculares (chave: ano → dicionario codigo → dados).
var grades_disciplinas_curriculos: Dictionary = {}

## Equivalencias entre disciplinas de grades diferentes.
var equivalencias: Dictionary = {}

## Lista de condicoes de matricula (matriculavel, matriculado_agora, etc).
var condicoes: Array[String] = []

## Posicoes das colunas no arquivo [code]hist.csv[/code].
var posicoes_histcsv: Dictionary = {}

## Delimitadores padrao do programa.
var delimitadores: Dictionary = {}

## Posicoes das colunas no arquivo [code]planejamento.csv[/code], de [code]base_config.json[/code].
var posicoes_planejamento: Dictionary = {}

## Metadados de cursos da [code]base_config.json:cursos[/code]. [br]
## Formato: [code]{<cod_curso>: {nome, prefixos_semestre, turmas, grades}}[/code].
var cursos: Dictionary = {}

## Cores padrao do terminal.
var cores_terminal: Dictionary = {}

## Resposta corrente do dialogo de importar (mesclar/substituir/cancelar). Membro porque
## as lambdas dos sinais do dialogo nao conseguem escrever numa variavel local capturada.
var _resposta_dialogo: String = ""

## Configuracoes do modulo (janela de afinidade e limites de carga horaria),
## de [code]base_config.json[/code].
var config_oferta: Dictionary = {}

## Configuracoes globais de interface, de [code]base_config.json[/code].
var config_interface: Dictionary = {}

## Diretorio onde o planejamento exportado e salvo (ex.: [code]dados/saida/exportacoes[/code]).
var diretorio_exportacao: String = ""

## Historico de professores por disciplina, carregado de
## [code]arquivos/oferta/historico_professores.json[/code] pelo main e injetado aqui.
## Alimenta o motor de afinidade e o dropdown de professores do painel de atribuicoes.
var historico_professores: Dictionary = {}

## Lista de professores por curso, carregada de [code]arquivos/lista_professores.json[/code]
## pelo main. Formato: [code]{ <chave_curso>: [nome, ...] }[/code].
var lista_professores: Dictionary = {}

#endregion

# Dados do planejamento apos importacao (referencia do CSV original).
var _planejamento: Dictionary = {}

# Alocacoes editaveis em memoria: { chave → { codigo, nome, semestre, ch_total, professores: { nome: ch } } }.
var _alocacoes: Dictionary = {}

# Snapshot do estado de _alocacoes no momento da ultima importacao. Serve de baseline para
# o diff exportado em alteracoes.md (Arquivo > Exportar > alteracoes.md). E persistido dentro
# do planejamento.json (chave "estado_inicial") para sobreviver a fechar/reabrir o programa.
var _alocacoes_inicial: Dictionary = {}

# Hash de _alocacoes no ultimo carregamento/salvamento. Base do aviso de alteracoes nao salvas ao
# trocar de modulo (ver tem_alteracoes_nao_salvas / _marcar_estado_salvo).
var _hash_estado_salvo: int = hash({})

# Lista de todos os nomes de professores extraidos do CSV.
var _todos_professores: Array[String] = []

# Lista de professores por curso (normalizada): { <chave_curso>: { <nome_normalizado>: true } }.
# A chave de curso usa o mesmo identificador do arquivo (em minusculas; tipicamente o
# prefixo_semestre, ex. [code]"ec"[/code]). Cada nome ja vem normalizado por
# [method AnaliseAfinidade.normalizar_nome] para casar com as entradas do painel de afinidade.
var _lista_professores_por_curso: Dictionary = {}

# Dialogo de selecao de disciplinas de uma grade curricular.
var _seletor_grade: SeletorDisciplinasGrade

# Dialogo modal de selecao de cursos para a importacao do planejamento.csv.
var _seletor_cursos: SeletorCursos

# Ultimos cod_curso marcados no _seletor_cursos, reapresentados ao reabrir o dialogo.
var _cursos_marcados_planejamento: Array[String] = []

# Condicoes de cada discente, carregado sob demanda.
var _condicoes_discentes: Dictionary = {}

# Historico completo dos discentes (nomes e dados de matricula), carregado sob demanda.
# Usado para resolver nomes e PPC nos tooltips da sugestao de oferta.
var _historico_discentes: Dictionary = {}

# Disciplina atualmente selecionada no painel de atribuicoes.
var _disciplina_selecionada: String = ""

# Grade curricular atualmente desenhada na GradeCurricular (chave <cod_curso>_<versao>).
var _grade_oferta_ativa: String = ""

# Forma de apresentacao das celulas da GradeCurricular (espelha o default "nome_reduzido" do componente).
var _forma_apresentacao_grade: String = "nome_reduzido"

# Cache das contagens de demanda do rodape, por "<grade>|<curso>" (curso vazio = "*", demanda global).
# O hist.csv nao muda durante a sessao, entao a contagem so depende da grade exibida e do curso filtrado.
var _cache_contagens: Dictionary = {}


func _ready() -> void:
	var grades_ordenadas: Array = grades_disciplinas_curriculos.keys()
	grades_ordenadas.sort()
	_seletor_importar.lista_itens = {
		"Locais": ["Abrir planejamento.json", "Abrir planejamento.csv", "Salvar planejamento.json"],
		"Locais_retorno": ["abrir_json", "abrir_csv", "salvar_json"],
		"Grades": grades_ordenadas,
		"Importar": ["planejamento.csv"],
		"Importar_retorno": ["importar_csv"],
		"Exportar": ["planejamento.csv", "alteracoes.md", "oferta.txt"],
		"Exportar_retorno": ["exportar_csv", "exportar_alteracoes", "exportar_oferta_txt"],
	}
	_seletor_importar.opcao_selecionada.connect(_on_importar_opcao_selecionada)

	_seletor_acoes.lista_itens = {
		"Demanda": [
			"Determinar",
			"Determinar ignorando oferta",
		],
		"Demanda_retorno": [
			"determinar_demanda",
			"determinar_demanda_ignorar_oferta",
		],
		"Carga horária": [
			"Verificar",
		],
		"Carga horária_retorno": [
			"verificar_carga_horaria",
		],
		"Oferta": [
			"Sugerir",
			"Verificar erro de afinidade",
			"Detectar problemas",
		],
		"Oferta_retorno": [
			"sugerir_oferta",
			"verificar_erro_afinidade",
			"detectar_problema_oferta",
		],
	}
	# Dicas por item (indices contam separadores: 0 sep "Demanda", 3 sep "Carga horária", 5 sep "Oferta").
	_seletor_acoes.definir_dica_item(1, DicasPrograma.texto(["planejamento_oferta_acoes", "determinar_demanda"]))
	_seletor_acoes.definir_dica_item(2, DicasPrograma.texto(["planejamento_oferta_acoes", "determinar_demanda_ignorar_oferta"]))
	_seletor_acoes.definir_dica_item(4, DicasPrograma.texto(["planejamento_oferta_acoes", "verificar_carga_horaria"]))
	_seletor_acoes.definir_dica_item(6, DicasPrograma.texto(["planejamento_oferta_acoes", "sugerir_oferta"]))
	_seletor_acoes.definir_dica_item(7, DicasPrograma.texto(["planejamento_oferta_acoes", "verificar_erro_afinidade"]))
	_seletor_acoes.definir_dica_item(8, DicasPrograma.texto(["planejamento_oferta_acoes", "detectar_problema_oferta"]))
	_seletor_acoes.opcao_selecionada.connect(_on_acoes_opcao_selecionada)

	_status_bar.definir_segmentos({
		"carga": "Profs: --",
		"pendentes": "Pendentes: 0",
		"completas": "Completas: 0",
	})

	SeletorAvancado.dimensionar([_seletor_importar, _seletor_acoes, $"%FiltroSemestreEdicao"], config_interface)

	# Planejamento de Oferta opera em creditos (a coluna "CH" do planejamento.csv eh creditos);
	# passamos "cr" para os paineis para que os rotulos refleitam isto.
	_painel_disciplinas.configurar(analise_grades, grades_disciplinas_curriculos, cores_terminal, false, cursos, true, "cr")
	_painel_disciplinas.card_interagido.connect(_on_card_interagido)
	_painel_disciplinas.card_removido.connect(_on_card_removido)

	_painel_atribuicoes.atribuicao_alterada.connect(_on_atribuicao_alterada)
	_painel_atribuicoes.configurar([] as Array[String], "cr")

	# Re-renderiza o painel de atribuicoes quando o filtro de curso muda, para que o
	# destaque de "professores do curso atual" acompanhe a selecao.
	_painel_disciplinas.filtro_alterado.connect(_on_filtro_curso_alterado)
	_painel_disciplinas.filtro_limpo.connect(_on_filtro_curso_alterado.bind({}))

	# Configura o seletor de semestre de edicao no topo do modulo.
	$"%FiltroSemestreEdicao".popular("Semestre", ["Todos", "1° semestre", "2° semestre"], ["", "1", "2"])
	$"%FiltroSemestreEdicao".opcao_selecionada.connect(_on_semestre_edicao_selecionado)
	# Auto-define o semestre de edicao baseado na data: no primeiro semestre
	# (jan-jul), planejamos o segundo; no segundo (ago-dez), o primeiro.
	var sem_atual: String = GeneralFunctions.semestre_atual()
	$"%FiltroSemestreEdicao".selecionar_item(2 if sem_atual == "1" else 1)

	# Pre-seleciona o curso do PPC principal, se definido em Configuracoes.
	var ppc: String = GV.configuracao_base.get("ppc_principal", "")
	if not ppc.is_empty():
		var cod_curso: String = _curso_da_grade(ppc)
		if not cod_curso.is_empty():
			_painel_disciplinas.selecionar_filtro_curso(cod_curso)

	_seletor_grade = SeletorDisciplinasGrade.new(self)
	_seletor_grade.disciplinas_selecionadas.connect(_on_disciplinas_grade_selecionadas)

	_seletor_cursos = SeletorCursos.new(self)
	_seletor_cursos.cursos_selecionados.connect(_on_cursos_selecionados_planejamento)

	_inicializar_professores_historico()
	_inicializar_lista_professores()
	_afinidade.configurar(historico_professores, cursos, equivalencias,
		int(config_oferta.get("janela_afinidade", 15)),
		GV.configuracao_base.get("turmas_globais", []))
	_relatorios.configurar(_terminal, _afinidade, analise_historico, grades_disciplinas_curriculos, condicoes, config_oferta, cursos, equivalencias)

	# Grade curricular (toggle via OnOffGrade): seletor de grade embutido + forma de apresentacao.
	_grade_curricular.lista_grades = grades_ordenadas
	_grade_curricular.grade_alterada.connect(_on_grade_oferta_alterada)
	_grade_curricular.listaopcoes_alterada.connect(_on_grade_oferta_forma_alterada)
	# Pre-seleciona o PPC principal, se valido; senao a primeira grade disponivel.
	var grade_inicial: String = GV.configuracao_base.get("ppc_principal", "")
	if grade_inicial.is_empty() or not grades_disciplinas_curriculos.has(grade_inicial):
		grade_inicial = str(grades_ordenadas[0]) if grades_ordenadas.size() > 0 else ""
	if not grade_inicial.is_empty():
		_grade_oferta_ativa = grade_inicial
		_grade_curricular.selecionar_grade(grade_inicial)
	# Realce inicial dos botoes OnOff conforme a visibilidade dos paineis.
	TogglePaineis.sincronizar_botoes(_mapa_toggles())


# Escreve uma linha no terminal com o token de cor informado.
func _log(texto: String, token: String = "padrao", nl: bool = true, limpar: bool = false) -> void:
	_terminal.text_edit(texto, token, nl, limpar)


# Soma a carga horaria alocada por professor em todas as disciplinas.
func _calcular_carga_por_prof() -> Dictionary:
	var carga: Dictionary = {}
	var visto: Dictionary = {}
	for chave in _alocacoes:
		var codigo: String = _alocacoes[chave].get("codigo", "")
		var profs: Dictionary = _alocacoes[chave].get("professores", {})
		for nome in profs:
			var vk := "%s_%s" % [nome.to_lower(), codigo.to_lower()]
			if not visto.has(vk):
				visto[vk] = true
				carga[nome] = carga.get(nome, 0) + int(profs[nome])
	return carga


# Preenche a lista de professores do dropdown a partir do historico ja injetado pelo main.
func _inicializar_professores_historico() -> void:
	if historico_professores.is_empty():
		return
	for prof_nome in historico_professores:
		var normalizado := AnaliseAfinidade.normalizar_nome(prof_nome)
		if not normalizado in _todos_professores:
			_todos_professores.append(normalizado)
	_todos_professores.sort_custom(func(a, b): return a < b)
	_painel_atribuicoes.configurar(_todos_professores)


# Monta [member _lista_professores_por_curso] a partir da lista ja injetada pelo main: para
# cada chave de curso (ex. "ec"), normaliza cada nome e armazena num set (Dictionary com
# value=true) para lookup O(1) ao montar o destaque no painel de afinidade. Lista vazia
# segue silenciosa — o destaque simplesmente nao aparece.
func _inicializar_lista_professores() -> void:
	if lista_professores.is_empty():
		return
	for chave in lista_professores:
		var lista = lista_professores[chave]
		if not lista is Array:
			continue
		var nomes_normalizados: Dictionary = {}
		for nome in lista:
			var n: String = AnaliseAfinidade.normalizar_nome(str(nome))
			if not n.is_empty():
				nomes_normalizados[n] = true
		_lista_professores_por_curso[str(chave).to_lower()] = nomes_normalizados


# Monta o set de nomes a destacar com base no filtro de curso ativo no PainelDisciplinas.
# Mapeia [code]cod_curso[/code] → [code]prefixos_semestre[/code] (de base_config.json:cursos)
# e une as listas de [code]_lista_professores_por_curso[/code] correspondentes (case-insensitive).
# Retorna dict vazio quando nao ha filtro ativo ou quando a lista nao cobre o curso.
func _calcular_profs_destacar() -> Dictionary:
	var resultado: Dictionary = {}
	var cod_curso: String = _painel_disciplinas.filtro_curso
	if cod_curso.is_empty():
		return resultado
	var prefixos: Array = cursos.get(cod_curso, {}).get("prefixos_semestre", [])
	for prefixo in prefixos:
		var chave: String = str(prefixo).to_lower()
		if _lista_professores_por_curso.has(chave):
			for nome in _lista_professores_por_curso[chave]:
				resultado[nome] = true
	return resultado


# Re-renderiza a disciplina atualmente selecionada quando o filtro de curso muda, para
# Repassa a selecao do FiltroSemestreEdicao (no topo) para o painel de disciplinas.
func _on_semestre_edicao_selecionado(_retorno: String, lista_selecionada: Array[String]) -> void:
	var sem: String = lista_selecionada[0] if lista_selecionada.size() > 0 else ""
	var mapa_texto: Dictionary = {"": "Semestre", "1": "1° semestre", "2": "2° semestre"}
	$"%FiltroSemestreEdicao".texto_padrao = mapa_texto.get(sem, "Semestre")
	_painel_disciplinas.definir_semestre_edicao(sem)

# que o destaque acompanhe. O dict de filtros vem do sinal mas nao e usado — basta
# saber que algo mudou.
func _on_filtro_curso_alterado(_filtros: Dictionary) -> void:
	if not _disciplina_selecionada.is_empty():
		_exibir_disciplina_selecionada()
	_refresh_grade_se_visivel()


func _atualizar_status_bar() -> void:
	var ch_min: int = int(config_oferta.get("ch_minimo", 8))
	var ch_ideal: int = int(config_oferta.get("ch_ideal", 12))
	var ch_max: int = int(config_oferta.get("ch_maximo", 20))

	var profs_abaixo: int = 0
	var profs_acima_ideal: int = 0
	var profs_acima_max: int = 0

	var carga_por_prof: Dictionary = _calcular_carga_por_prof()
	for prof in carga_por_prof:
		var ch: int = int(carga_por_prof[prof])
		if ch < ch_min:
			profs_abaixo += 1
		elif ch > ch_max:
			profs_acima_max += 1
		elif ch > ch_ideal:
			profs_acima_ideal += 1

	var profs_ok: int = carga_por_prof.size() - profs_abaixo - profs_acima_ideal - profs_acima_max
	var texto_carga: String = "Profs OK: %d | <%d cr: %d | >%d cr: %d | >%d cr: %d" % \
		[profs_ok, ch_min, profs_abaixo, ch_ideal, profs_acima_ideal, ch_max, profs_acima_max]
	var token_carga: String = ""
	if profs_acima_max > 0:
		token_carga = "erro"
	elif profs_abaixo > 0 or profs_acima_ideal > 0:
		token_carga = "aviso"
	_status_bar.atualizar("carga", texto_carga, token_carga)

	var pendentes: int = 0
	var completas: int = 0
	for chave in _alocacoes:
		var profs: Dictionary = _alocacoes[chave].get("professores", {})
		var ch_total: int = int(_alocacoes[chave].get("ch_total", 0))
		var ch_alocada: int = 0
		for ch in profs.values():
			ch_alocada += int(ch)
		if ch_total <= 0:
			continue
		if ch_alocada >= ch_total:
			completas += 1
		else:
			pendentes += 1
	_status_bar.atualizar("pendentes", "Pendentes: %d" % pendentes)
	_status_bar.atualizar("completas", "Completas: %d" % completas)


func _popular_alocacoes_do_csv() -> void:
	_alocacoes.clear()
	_todos_professores.clear()
	# Acumula os codigos do planejamento sem grade carregada para um unico aviso agregado ao final,
	# em vez de um log por disciplina (que poluia o terminal). [param nomes_sem_grade] guarda, em
	# paralelo, o nome embutido no proprio planejamento.csv para exibir "codigo (Nome)".
	var codigos_sem_grade: Array[String] = []
	var nomes_sem_grade: Array[String] = []
	for chave in _planejamento:
		var entrada: Dictionary = _planejamento[chave]
		var codigo: String = str(entrada.get("codigo", "")).to_lower()
		if codigo.is_empty():
			_log("Disciplina ignorada no CSV: codigo vazio (chave: %s)." % chave, "aviso")
			continue
		var semestre: String = str(entrada.get("semestre", ""))
		var ch_total: int = int(entrada.get("ch_disciplina", 0))
		var nome: String = analise_grades.info_grade(grades_disciplinas_curriculos, codigo, "nome", "", true)
		if nome.begins_with("Codigo"):
			if not codigos_sem_grade.has(codigo):
				codigos_sem_grade.append(codigo)
				nomes_sem_grade.append(str(entrada.get("nome_csv", "")))
			nome = codigo.to_upper()
		var profs_array: Array = entrada.get("professor", [])
		var chs_array: Array = entrada.get("ch", [])
		var profs: Dictionary = {}
		for i in profs_array.size():
			var pn: String = AnaliseAfinidade.normalizar_nome(str(profs_array[i]))
			var ch: int = int(chs_array[i]) if i < chs_array.size() else 0
			profs[pn] = ch
		_alocacoes[chave] = {
			"codigo": codigo,
			"nome": nome,
			"semestre": semestre,
			# oferta = celula original do CSV (ex.: "EM02;ECExtra"), preservando o compartilhamento
			# entre cursos ao exportar/reimportar o planejamento.json. Sem isto, vira so o semestre.
			"oferta": str(entrada.get("oferta", semestre)),
			"ch_total": ch_total,
			"professores": profs,
		}
		# Coleta todos os professores.
		for pn in profs_array:
			var ps: String = AnaliseAfinidade.normalizar_nome(str(pn))
			if not ps.is_empty() and not ps in _todos_professores:
				_todos_professores.append(ps)
	_todos_professores.sort_custom(func(a, b): return a < b)
	if not codigos_sem_grade.is_empty():
		var itens: Array[String] = []
		for i in codigos_sem_grade.size():
			var nm: String = nomes_sem_grade[i].capitalize()
			itens.append(codigos_sem_grade[i] + (" (" + nm + ")" if nm != "" else ""))
		_log("Disciplinas sem grade carregada: " + ", ".join(itens) \
			+ " — confira se falta um arquivo de grade ou se o codigo esta correto.", "aviso", true, true)
	# Atualiza o dropdown do painel de atribuicoes.
	_painel_atribuicoes.configurar(_todos_professores)


# Sincroniza os cards do painel com as alocacoes em memoria. [br]
# No Planejamento de Oferta, ch_total e a CH da disciplina e ch_alocada e a soma
# das CHs dos professores — ao contrario do popular() generico, que usa a soma das
# CHs como ch_total. Por isso reescrevemos ambos aqui (alem do excedente).
func _sincronizar_cards_alocacoes() -> void:
	for chave in _alocacoes:
		var dados: Dictionary = _alocacoes[chave]
		var profs: Dictionary = dados.get("professores", {})
		var ch_alocada: int = 0
		for ch in profs.values():
			ch_alocada += int(ch)
		# Casa pela CHAVE UNICA da oferta (cards_disciplinas e _alocacoes compartilham a mesma chave).
		# Indexar por codigo|semestre sobrescrevia ofertas duplicadas, deixando a 2ª oferta sem
		# ch_total/ch_alocada (card cinza apos a importacao).
		var card: CardDisciplina = _painel_disciplinas.cards_disciplinas.get(chave, null)
		if card == null:
			continue
		var ch_total: int = int(dados.get("ch_total", 0))
		card.ch_total = ch_total
		# Define o excedente antes de ch_alocada (cujo setter recalcula o visual).
		card.ch_extra = maxi(0, ch_alocada - ch_total)
		card.ch_alocada = ch_alocada
	# Apos sincronizar os cards (import de CSV/JSON), atualiza o contorno de inseridas na grade.
	_refresh_grade_se_visivel()


# Retorna o cod_curso ao qual a [param grade_nome] pertence, conforme [code]cursos.<cod>.grades[/code].
# Vazio quando a grade nao esta cadastrada em nenhum curso.
func _curso_da_grade(grade_nome: String) -> String:
	return analise_historico.curso_da_grade(grade_nome, cursos)


# Restaura uma selecao de curso coerente com o dropdown apos popular o painel. Necessario porque
# popular() com limpar_antes=true chama limpar(), que zera filtro_curso sem limpar o texto exibido
# no dropdown — deixando-o desincronizado (mostra um curso, mas filtro_curso vazio) e fazendo as
# Acoes que leem filtro_curso reclamarem "Selecione um curso". [br]
# Prioridade: manter a selecao anterior ([param curso_anterior], pre-select do PPC ou escolha
# manual) quando o curso ainda esta presente; senao o curso do PPC principal; senao o unico curso
# disponivel; senao "Todos". [param cursos_retorno] vem de popular() (primeiro item = "" = Todos).
func _restaurar_filtro_curso_pos_importacao(curso_anterior: String, cursos_retorno: Array) -> void:
	if not curso_anterior.is_empty() and cursos_retorno.has(curso_anterior):
		_painel_disciplinas.selecionar_filtro_curso(curso_anterior)
		return
	var ppc: String = GV.configuracao_base.get("ppc_principal", "")
	var cod_ppc: String = _curso_da_grade(ppc) if not ppc.is_empty() else ""
	if not cod_ppc.is_empty() and cursos_retorno.has(cod_ppc):
		_painel_disciplinas.selecionar_filtro_curso(cod_ppc)
	elif cursos_retorno.size() == 2:
		_painel_disciplinas.selecionar_filtro_curso(cursos_retorno[1])
	else:
		# Nenhum curso preferido nem unico: ressincroniza dropdown e filtro_curso em "Todos".
		_painel_disciplinas.selecionar_filtro_curso("")


# Converte um semestre vindo da grade ("1", "2", "0", ...) para o formato "<prefixo><NN>"
# usando o primeiro prefixo do curso ao qual a grade pertence. Quando o curso nao puder ser
# determinado, devolve o semestre original (comportamento antigo). Para [code]sem_grade == "0"[/code]
# (complementares/optativas), devolve so o prefixo, mantendo a disciplina no filtro do curso
# sem fixar um semestre numerico.
func _semestre_com_prefixo_do_curso(grade_nome: String, sem_grade: String) -> String:
	var cod_curso: String = _curso_da_grade(grade_nome)
	if cod_curso.is_empty():
		return sem_grade
	var prefixos: Array = cursos[cod_curso].get("prefixos_semestre", [])
	if prefixos.is_empty():
		return sem_grade
	var prefixo: String = str(prefixos[0])
	var sem_int: int = int(sem_grade)
	if sem_int > 0:
		return "%s%02d" % [prefixo, sem_int]
	return prefixo


#region Importacao

func _on_importar_opcao_selecionada(retorno: String, _lista_selecionada: Array[String]) -> void:
	if retorno == "abrir_csv":
		_abrir_janela_selecao_cursos()
	elif retorno == "abrir_json":
		_importar_planejamento_json_salvo()
	elif retorno == "salvar_json":
		_exportar_planejamento_json()
	elif retorno == "importar_csv":
		_converter_planejamento_csv()
	elif retorno == "exportar_csv":
		_exportar_planejamento_csv()
	elif retorno == "exportar_alteracoes":
		_exportar_alteracoes()
	elif retorno == "exportar_oferta_txt":
		_exportar_oferta_txt()
	elif grades_disciplinas_curriculos.has(retorno):
		_abrir_janela_selecao_grade(retorno)


# Abre um dialogo para selecionar um arquivo CSV, converte-o para UTF-8
# e salva como planejamento.csv no diretorio de dados de saida, sobreescrevendo
# o arquivo existente. Util para quando o CSV do planejamento vem em encoding
# diferente de UTF-8 e precisa ser normalizado.
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
		_log("%s convertido e salvo como planejamento.csv em %s." % [file_name, GV.dir_saida], "sucesso", true, true)
		fd.queue_free()
		# Encadeia direto na selecao de cursos para importar o arquivo recem-convertido,
		# poupando o usuario de abrir manualmente "Arquivo > Abrir planejamento.csv".
		if FileAccess.file_exists(GV.dir_saida + "planejamento.csv"):
			_abrir_janela_selecao_cursos())
	fd.canceled.connect(fd.queue_free)
	add_child(fd)
	fd.popup_centered()
	Dialogos.limitar_a_tela(fd)


# Abre o dialogo modal de selecao de cursos antes da leitura do planejamento.csv. A leitura
# efetiva acontece em _on_cursos_selecionados_planejamento, ao confirmar a selecao.
func _abrir_janela_selecao_cursos() -> void:
	if cursos.is_empty():
		_log("Nenhum curso cadastrado em base_config.json:cursos.", "erro", true, true)
		return
	var pre: Array = _cursos_marcados_planejamento.duplicate()
	var ppc: String = GV.configuracao_base.get("ppc_principal", "")
	if not ppc.is_empty():
		var cod_ppc: String = _curso_da_grade(ppc)
		if not cod_ppc.is_empty() and not pre.has(cod_ppc):
			pre.append(cod_ppc)
	_seletor_cursos.abrir(cursos, pre)


# Reune os prefixos de semestre dos cursos selecionados e dispara a importacao.
func _on_cursos_selecionados_planejamento(cods: Array[String]) -> void:
	if cods.is_empty():
		_log("Nenhum curso selecionado — importacao cancelada.", "aviso", true, true)
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
		_log("Cursos selecionados nao possuem prefixos_semestre em base_config.json.", "erro", true, true)
		return
	_importar_planejamento_csv(prefixos)


# Le o planejamento.json salvo direto do diretorio de exportacoes. A importacao de qualquer
# .json arbitrario passa pelo VerificadorArquivos (FileSelector na tela inicial), nao por
# FileDialog proprio do modulo.
func _importar_planejamento_json_salvo() -> void:
	if diretorio_exportacao.is_empty():
		_log("Diretório de exportações não configurado.", "erro", true, true)
		return
	var caminho_json: String = diretorio_exportacao + "planejamento.json"
	if not FileAccess.file_exists(caminho_json):
		_log("Nenhum planejamento.json encontrado em " + diretorio_exportacao \
			+ ". Salve um planejamento antes de importar ou use o seletor de arquivos da tela inicial.", \
			"aviso", true, true)
		return
	_importar_planejamento_json(diretorio_exportacao, "planejamento.json")


func _importar_planejamento_csv(prefixos_semestre: Array[String]) -> void:
	var modo_mesclar: bool = false
	var backup_alocacoes: Dictionary = {}
	var backup_profs: Array[String] = []
	if _alocacoes.size() > 0:
		var acao: String = await _perguntar_mesclar_ou_substituir()
		match acao:
			"cancelar": return
			"substituir":
				_log("Substituindo planejamento existente pelo novo CSV.", "aviso", true, true)
			"mesclar":
				modo_mesclar = true
				_log("Mesclando CSV com planejamento existente.", "aviso", true, true)
				backup_alocacoes = _alocacoes.duplicate(true)
				backup_profs = _todos_professores.duplicate()

	_planejamento = file_handling.carregar_planejamento(
		GV.dir_saida, "planejamento.csv", prefixos_semestre, delimitadores.get("planejamento", []), posicoes_planejamento
	)
	if _planejamento.size() > 0:
		_popular_alocacoes_do_csv()
		if modo_mesclar:
			_mesclar_alocacoes(backup_alocacoes, backup_profs, _planejamento)
			# A mescla pode ter trazido professores que so existiam no plano antigo; re-ordena e
			# re-injeta no painel de atribuicoes (o _popular_alocacoes_do_csv ja configurou, mas
			# antes da mescla — sem isto os profs mesclados nao aparecem no dropdown de afinidade).
			_todos_professores.sort_custom(func(a, b): return a < b)
			_painel_atribuicoes.configurar(_todos_professores)
		_imprimir_planejamento()
		# Captura a selecao de curso antes de popular (que pode reseta-la) para preserva-la.
		var curso_anterior: String = _painel_disciplinas.filtro_curso
		var filtros := _painel_disciplinas.popular(_planejamento, _terminal, false)
		_restaurar_filtro_curso_pos_importacao(curso_anterior, filtros["cursos"]["_Curso_retorno"])
		_sincronizar_cards_alocacoes()
		_atualizar_status_bar()
		# Baseline para o diff de alteracoes.md: o estado recem-importado e o ponto de partida.
		# Deep copy obrigatorio — copia rasa compartilharia os sub-dicts "professores".
		_alocacoes_inicial = _alocacoes.duplicate(true)
		_marcar_estado_salvo()
		_log("planejamento.csv importado (%d disciplinas)." % _alocacoes.size(), "sucesso", true, false)
	else:
		_log("Arquivo \"planejamento.csv\" nao foi lido corretamente!", "erro", false, true)


func _importar_planejamento_json(caminho: String, arquivo: String) -> void:
	if not FileAccess.file_exists(caminho + arquivo):
		_log("planejamento.json nao encontrado em " + caminho, "erro", true, true)
		return
	var dados: Dictionary = file_handling.load_json(caminho, arquivo)
	if dados.is_empty() or not dados.has("disciplinas"):
		_log("planejamento.json com formato invalido.", "erro", true, true)
		return

	var modo_mesclar: bool = false
	var backup_alocacoes: Dictionary = {}
	var backup_profs: Array[String] = []
	if _alocacoes.size() > 0:
		_log("Aguardando escolha do usuario...", "aviso", true, true)
		var acao: String = await _perguntar_mesclar_ou_substituir()
		match acao:
			"cancelar": return
			"substituir":
				_log("Substituindo planejamento existente pelo novo JSON.", "aviso", true, true)
			"mesclar":
				modo_mesclar = true
				_log("Mesclando JSON com planejamento existente.", "aviso", true, true)
				backup_alocacoes = _alocacoes.duplicate(true)
				backup_profs = _todos_professores.duplicate()

	_alocacoes.clear()
	_todos_professores.clear()
	var planejamento_temp: Dictionary = {}
	var idx: int = 0
	for disciplina in dados["disciplinas"]:
		if not disciplina is Dictionary:
			continue
		var codigo: String = str(disciplina.get("codigo", "")).to_lower()
		if codigo.is_empty():
			_log("Disciplina ignorada no JSON: codigo vazio.", "aviso")
			continue
		var semestre: String = str(disciplina.get("semestre", ""))
		if semestre.is_empty():
			_log("Disciplina %s ignorada no JSON: semestre vazio." % codigo, "aviso")
			continue
		# oferta combinada entre cursos (ex.: "em02;ecextra"); cai no semestre para JSONs antigos.
		var oferta: String = str(disciplina.get("oferta", semestre))
		# [code]nome[/code] e [code]ch_total[/code] sao sempre derivados do codigo via grade —
		# o export omite os dois campos, entao a unica fonte de verdade e [code]info_grade[/code].
		var resolvido: Dictionary = _resolver_codigo_via_grade(codigo)
		var nome: String = resolvido["nome"]
		if nome.begins_with("Codigo") or nome.begins_with("Informa"):
			_log("Codigo %s nao encontrado em nenhuma grade curricular." % codigo, "aviso")
			nome = codigo.to_upper()
		var ch_total: int = resolvido["ch_creditos"]
		var profs_dict: Dictionary = {}
		var profs_dados = disciplina.get("professores", [])
		if profs_dados is Array:
			for p in profs_dados:
				if p is Dictionary:
					var pn: String = AnaliseAfinidade.normalizar_nome(str(p.get("nome", "")))
					var pc: int = int(p.get("ch", 0))
					if not pn.is_empty():
						profs_dict[pn] = pc
						if not pn in _todos_professores:
							_todos_professores.append(pn)
		var chave: String = codigo + "_" + semestre + "_" + str(idx)
		idx += 1
		_alocacoes[chave] = {
			"codigo": codigo,
			"nome": nome,
			"semestre": semestre,
			"oferta": oferta,
			"ch_total": ch_total,
			"professores": profs_dict,
		}
		# Constroi um planejamento_temp compativel com o formato do PainelDisciplinas.
		var profs_array: Array[String] = []
		var chs_array: Array = []
		for pn in profs_dict:
			profs_array.append(pn)
			chs_array.append(str(profs_dict[pn]))
		planejamento_temp[chave] = {
			"codigo": codigo,
			"semestre": semestre,
			"oferta": oferta,
			"ch_disciplina": str(ch_total),
			"professor": profs_array,
			"ch": chs_array,
		}
	if modo_mesclar:
		_mesclar_alocacoes(backup_alocacoes, backup_profs, planejamento_temp)
	_todos_professores.sort_custom(func(a, b): return a < b)
	_painel_atribuicoes.configurar(_todos_professores)
	# Captura a selecao de curso antes de popular: popular(..., true) chama limpar(), que zera
	# filtro_curso. Capturado aqui, o curso anterior (pre-select do PPC ou escolha manual) e
	# restaurado pelo helper quando ainda presente entre os importados.
	var curso_anterior: String = _painel_disciplinas.filtro_curso
	var filtros := _painel_disciplinas.popular(planejamento_temp, _terminal, true)
	_restaurar_filtro_curso_pos_importacao(curso_anterior, filtros["cursos"]["_Curso_retorno"])
	_sincronizar_cards_alocacoes()
	_atualizar_status_bar()
	# Baseline para o diff de alteracoes.md:
	# - Na mescla, o estado inicial do arquivo deixa de fazer sentido (mistura de dois planos),
	#   entao reinicia a partir do estado mesclado — diff vazio, coerente com o aviso do dialogo.
	# - Ao substituir/abrir, restaura o snapshot embutido no JSON quando presente, preservando o
	#   estado inicial original atraves de Salvar > fechar > Abrir. Arquivos antigos sem o campo
	#   caem no estado recem-carregado (diff vazio ate a proxima edicao).
	if modo_mesclar:
		_alocacoes_inicial = _alocacoes.duplicate(true)
	elif dados.has("estado_inicial") and dados["estado_inicial"] is Array:
		_alocacoes_inicial = _parsear_alocacoes_de_array(dados["estado_inicial"])
	else:
		_alocacoes_inicial = _alocacoes.duplicate(true)
	_marcar_estado_salvo()
	_log("Planejamento importado de %s (%d disciplinas)." % [arquivo, _alocacoes.size()],
		"sucesso", true, false)


# Pergunta ao usuario se deseja mesclar ou substituir o planejamento existente.
# Exibe um dialogo modal com botoes "Mesclar" e "Substituir". O usuario tambem pode
# fechar o dialogo (X), o que equivale a cancelar. Retorna "mesclar", "substituir"
# ou "cancelar".
func _perguntar_mesclar_ou_substituir() -> String:
	# A resposta vive num membro: lambdas em GDScript capturam variaveis locais por
	# copia, entao escrever numa local aqui dentro nao seria visto fora — o while
	# nunca sairia. Membro e acessado via self, portanto a escrita propaga.
	_resposta_dialogo = ""
	var dialogo := ConfirmationDialog.new()
	dialogo.title = "Importar planejamento"
	dialogo.dialog_text = "Já existe um planejamento carregado.\nDeseja mesclar as importações ou substituir o planejamento atual?\n\n⚠ Atenção: o registro de alterações usado na exportação\n\"alteracoes.md\" (a diferença em relação ao planejamento\nimportado) será redefinido. Exporte as alterações atuais\nantes, se ainda precisar delas."
	dialogo.min_size = Vector2i(440, 0)
	dialogo.get_ok_button().text = "Mesclar"
	dialogo.get_cancel_button().text = "Substituir"
	dialogo.confirmed.connect(func():
		_resposta_dialogo = "mesclar")
	dialogo.canceled.connect(func():
		_resposta_dialogo = "substituir")
	dialogo.close_requested.connect(func():
		_resposta_dialogo = "cancelar")
	add_child(dialogo)
	dialogo.popup_centered()
	Dialogos.limitar_a_tela(dialogo)
	while _resposta_dialogo.is_empty():
		await get_tree().process_frame
	var r: String = _resposta_dialogo
	dialogo.queue_free()
	return r


# Mescla dados de [param backup] (alocacoes pre-existentes) nas alocacoes atuais.
# Para disciplinas com mesmo codigo+semestre, combina os professores (sem duplicar).
# Para disciplinas novas (so no backup), adiciona a _alocacoes e cria cards.
# [param card_dict] e o dicionario usado para popular os cards (_planejamento para
# CSV, planejamento_temp para JSON). Novas disciplinas sao inseridas nele.
func _mesclar_alocacoes(backup: Dictionary, backup_profs: Array[String], card_dict: Dictionary) -> void:
	# 1. Mescla professores unicos.
	for pn in backup_profs:
		if not pn in _todos_professores:
			_todos_professores.append(pn)

	# 2. Indexa _alocacoes atuais por codigo+semestre (minusculo) para lookup O(1).
	var index_existente: Dictionary = {}
	for chave in _alocacoes:
		var dados: Dictionary = _alocacoes[chave]
		var chave_unica: String = dados["codigo"] + "_" + dados["semestre"].to_lower()
		if not index_existente.has(chave_unica):
			index_existente[chave_unica] = chave

	# 3. Coleta inconsistencias durante a mesclagem para exibir ao final.
	var avisos: Array[String] = []

	# 4. Percorre backup, mesclando ou adicionando.
	for chave in backup:
		var dados: Dictionary = backup[chave]
		var chave_unica: String = dados["codigo"] + "_" + dados["semestre"].to_lower()
		if index_existente.has(chave_unica):
			var chave_existente: String = index_existente[chave_unica]
			var aloc_existente: Dictionary = _alocacoes[chave_existente]

			# CH total divergente entre importacoes (usar o maior).
			var ch_atual: int = int(aloc_existente.get("ch_total", 0))
			var ch_backup: int = int(dados.get("ch_total", 0))
			if ch_atual > 0 and ch_backup > 0 and ch_atual != ch_backup:
				avisos.append("CH divergente em %s: %d (existente) vs %d (backup). Usando maior %d." \
					% [chave_unica, ch_atual, ch_backup, maxi(ch_atual, ch_backup)])
				aloc_existente["ch_total"] = maxi(ch_atual, ch_backup)

			# Professores: mescla e detecta CH divergente por professor.
			var profs_existentes: Dictionary = aloc_existente["professores"]
			for pn in dados["professores"]:
				var ch_prof_novo: int = dados["professores"][pn]
				if profs_existentes.has(pn):
					var ch_prof_exist: int = profs_existentes[pn]
					if ch_prof_novo != ch_prof_exist:
						avisos.append("CH do professor %s em %s: %d (existente) vs %d (backup). Usando maior %d." \
							% [pn, chave_unica, ch_prof_exist, ch_prof_novo, maxi(ch_prof_exist, ch_prof_novo)])
						profs_existentes[pn] = maxi(ch_prof_exist, ch_prof_novo)
				else:
					profs_existentes[pn] = ch_prof_novo
		else:
			# Disciplina nova: adiciona com chave unica.
			var nova_chave: String = chave
			while _alocacoes.has(nova_chave):
				nova_chave += "_bis"
			_alocacoes[nova_chave] = dados.duplicate(true)

			# Cria entrada em card_dict para gerar card no PainelDisciplinas.
			var profs_array: Array[String] = []
			var chs_array: Array = []
			for pn in dados["professores"]:
				profs_array.append(pn)
				chs_array.append(str(dados["professores"][pn]))
			card_dict[nova_chave] = {
				"codigo": dados["codigo"],
				"semestre": dados["semestre"],
				"ch_disciplina": str(dados["ch_total"]),
				"professor": profs_array,
				"ch": chs_array,
			}

	if avisos.size() > 0:
		_terminal.secao("Avisos durante a mesclagem")
		for aviso in avisos:
			_terminal.item(aviso, 0, "aviso")


# Resolve [code]nome[/code] e [code]ch_total[/code] em creditos a partir do [param codigo],
# consultando as grades carregadas em [member grades_disciplinas_curriculos]. Usado no
# import de planejamento.json (campos opcionais omitidos por serem derivaveis). [br]
# Se o codigo nao estiver em nenhuma grade: nome cai em [param codigo].to_upper(),
# [code]ch_creditos[/code] cai em 0 — o card mostrara "Sem CH definida".
func _resolver_codigo_via_grade(codigo: String) -> Dictionary:
	var nome: String = analise_grades.info_grade(grades_disciplinas_curriculos, codigo, "nome", "", true)
	# info_grade devolve strings com prefixo "Codigo" ou "Informa..." quando nao acha — caem para o codigo.
	if nome.begins_with("Codigo") or nome.begins_with("Informa"):
		nome = codigo.to_upper()
	var ch_str: String = analise_grades.info_grade(grades_disciplinas_curriculos, codigo, "ch", "", true)
	var ch_horas: int = int(ch_str) if ch_str.is_valid_int() else 0
	var horas_por_credito: int = int(config_oferta.get("horas_por_credito", 15))
	var ch_creditos: int = ch_horas / horas_por_credito if horas_por_credito > 0 else 0
	return {"nome": nome, "ch_creditos": ch_creditos}


func _abrir_janela_selecao_grade(grade_nome: String) -> void:
	var grade: Dictionary = grades_disciplinas_curriculos.get(grade_nome, {})
	if grade.is_empty():
		_log("Grade " + grade_nome + " vazia ou nao encontrada.", "aviso", true, true)
		return
	_seletor_grade.abrir(grade_nome, grade, _painel_disciplinas.codigos_presentes())


func _on_disciplinas_grade_selecionadas(grade_nome: String, codigos: Array) -> void:
	var inseridas: int = 0
	for cod in codigos:
		if _inserir_disciplina_da_grade(grade_nome, str(cod)):
			inseridas += 1
	_log("Inseridas %d disciplina(s) da grade %s." % [inseridas, grade_nome], "sucesso", true, true)
	_atualizar_status_bar()
	_refresh_grade_se_visivel()


func _inserir_disciplina_da_grade(grade_nome: String, codigo: String) -> bool:
	var disc: Dictionary = grades_disciplinas_curriculos.get(grade_nome, {}).get(codigo, {})
	if disc.is_empty():
		return false
	if _painel_disciplinas.tem_codigo(codigo):
		return false
	var chave: String = codigo + "_" + grade_nome
	var nome: String = str(disc.get("nome", codigo))
	# Reconstroi o semestre no formato "<prefixo><NN>" (ex. "EC01") usando o cod_curso
	# vinculado a esta grade em base_config.json:cursos. Sem essa conversao, o filtro de
	# curso nao reconhece a disciplina (o campo "semestre" da grade vem como "1", "2", ...).
	var sem: String = _semestre_com_prefixo_do_curso(grade_nome, str(disc.get("semestre", "")))
	# Grades em [code]arquivos/grades/*.json[/code] guardam [code]ch[/code] em horas reais
	# (ex.: "30"). O resto do modulo opera em creditos (1 credito = N horas, vindo de
	# [code]base_config.json:planejamento_oferta.horas_por_credito[/code], por padrao 15),
	# como faz o planejamento.csv. Convertemos aqui para manter a unidade interna unica:
	# assim "+ alocar" segue acrescentando 1 credito independente da origem da disciplina.
	var ch_horas: int = int(str(disc.get("ch", "0")))
	var horas_por_credito: int = int(config_oferta.get("horas_por_credito", 15))
	var ch_creditos: int = ch_horas / horas_por_credito if horas_por_credito > 0 else 0
	# Alerta para CH que nao bate em multiplo exato de [code]horas_por_credito[/code]: a divisao
	# inteira trunca, entao o usuario perde fracao de credito. Surfaceia no terminal para que
	# se corrija na grade ou se ajuste [code]horas_por_credito[/code] em base_config.json.
	if horas_por_credito > 0 and ch_horas > 0 and ch_horas % horas_por_credito != 0:
		_log("AVISO: %s tem %dh na grade %s, nao eh multiplo de %dh (1 credito). CH truncada para %d credito(s)." \
			% [codigo.to_upper(), ch_horas, grade_nome, horas_por_credito, ch_creditos], "aviso")
	var chs: Array = [str(ch_creditos)] if ch_creditos > 0 else []
	var profs: Array[String] = []
	var eh_complementar: bool = str(disc.get("semestre", "")) == "0"
	var prefixo: String = sem.substr(0, 2).to_upper()
	_painel_disciplinas.popular_card_extra(codigo, nome, profs, chs, sem, chave, eh_complementar, prefixo)
	_alocacoes[chave] = {
		"codigo": codigo.to_lower(),
		"nome": nome,
		"semestre": sem,
		# Disciplina avulsa de uma grade unica: nao ha compartilhamento, oferta = semestre.
		"oferta": sem,
		"ch_total": ch_creditos,
		"professores": {},
	}
	return true

#endregion

#region Exportacao

# Indexa um dicionario de alocacoes por "codigo|semestre" (ambos minusculos), a unidade
# canonica de identidade de disciplina usada no diff de alteracoes.md. Independe das chaves
# internas de _alocacoes (que podem diferir entre import de CSV, JSON e insercao por grade).
func _indexar_por_disciplina(alocacoes: Dictionary) -> Dictionary:
	var idx: Dictionary = {}
	for chave in alocacoes:
		var d: Dictionary = alocacoes[chave]
		var k: String = str(d.get("codigo", "")).to_lower() + "|" + str(d.get("semestre", "")).to_lower()
		idx[k] = d  # ultima entrada vence — basta para o diff (identidade unica por disciplina).
	return idx


# Serializa um dicionario de alocacoes para o formato de array usado no planejamento.json:
# [{codigo, semestre, professores:[{nome, ch}]}], ordenado por semestre+codigo. [code]nome[/code]
# e [code]ch_total[/code] sao omitidos por serem derivaveis do codigo via grade (ver import).
func _alocacoes_para_array(alocacoes: Dictionary) -> Array:
	var arr: Array = []
	for chave in alocacoes:
		var dados: Dictionary = alocacoes[chave]
		var profs_array: Array = []
		for pn in dados.get("professores", {}):
			profs_array.append({"nome": pn, "ch": int(dados["professores"][pn])})
		arr.append({
			"codigo": dados["codigo"],
			"semestre": (dados["semestre"] as String).to_lower(),
			# Preserva a oferta combinada entre cursos (ex.: "em02;ecextra"); cai no semestre quando
			# a disciplina nao e compartilhada.
			"oferta": str(dados.get("oferta", dados.get("semestre", ""))).to_lower(),
			"professores": profs_array,
		})
	arr.sort_custom(func(a, b): return str(a["semestre"]) + str(a["codigo"]) < \
		str(b["semestre"]) + str(b["codigo"]))
	return arr


# Parseia um array no formato [{codigo, semestre, professores:[{nome, ch}]}] (ex.: o campo
# "estado_inicial" do planejamento.json) de volta para o formato de _alocacoes. [code]nome[/code]
# e [code]ch_total[/code] sao re-derivados do codigo via grade, igual ao import principal.
func _parsear_alocacoes_de_array(arr: Array) -> Dictionary:
	var resultado: Dictionary = {}
	var idx: int = 0
	for disciplina in arr:
		if not disciplina is Dictionary:
			continue
		var codigo: String = str(disciplina.get("codigo", "")).to_lower()
		var semestre: String = str(disciplina.get("semestre", ""))
		if codigo.is_empty() or semestre.is_empty():
			continue
		var resolvido: Dictionary = _resolver_codigo_via_grade(codigo)
		var profs_dict: Dictionary = {}
		var profs_dados = disciplina.get("professores", [])
		if profs_dados is Array:
			for p in profs_dados:
				if p is Dictionary:
					var pn: String = AnaliseAfinidade.normalizar_nome(str(p.get("nome", "")))
					if not pn.is_empty():
						profs_dict[pn] = int(p.get("ch", 0))
		resultado[codigo + "_" + semestre + "_" + str(idx)] = {
			"codigo": codigo,
			"nome": resolvido["nome"],
			"semestre": semestre,
			"oferta": str(disciplina.get("oferta", semestre)),
			"ch_total": resolvido["ch_creditos"],
			"professores": profs_dict,
		}
		idx += 1
	return resultado


# Marca o planejamento atual como "salvo" (apos carregar/salvar). Zera o aviso de alteracoes.
func _marcar_estado_salvo() -> void:
	_hash_estado_salvo = hash(_alocacoes)

## True se as alocacoes mudaram desde o ultimo carregamento/salvamento. Consultado pelo main.gd antes
## de trocar de modulo / voltar ao inicio, para avisar sobre alteracoes nao salvas.
func tem_alteracoes_nao_salvas() -> bool:
	return hash(_alocacoes) != _hash_estado_salvo


func _exportar_planejamento_json() -> void:
	var tempo: Dictionary = Time.get_datetime_dict_from_system()
	var data_str: String = "%d-%02d-%02d %02d:%02d" % \
		[tempo["year"], tempo["month"], tempo["day"], tempo["hour"], tempo["minute"]]
	# [code]nome[/code] e [code]ch_total[/code] sao omitidos por serem derivaveis do [code]codigo[/code]
	# via [code]grades_disciplinas_curriculos[/code] (ver [method _resolver_codigo_via_grade], usado no
	# import). [code]total_professores[/code] tambem sai — pode ser recontado pelas entradas de
	# [code]disciplinas[][].professores[/code].
	var disciplinas: Array = _alocacoes_para_array(_alocacoes)
	# [code]estado_inicial[/code]: baseline para o diff de alteracoes.md, persistido para sobreviver
	# a Salvar > fechar > Abrir (mesmo formato do array [code]disciplinas[/code]).
	var saida: Dictionary = {
		"ano": tempo["year"],
		"exportado_em": data_str,
		"disciplinas": disciplinas,
		"estado_inicial": _alocacoes_para_array(_alocacoes_inicial),
	}
	file_handling.check_create_dir(diretorio_exportacao)
	file_handling.save_json(diretorio_exportacao, "planejamento.json", saida)
	_marcar_estado_salvo()
	_log("Planejamento exportado para %splanejamento.json (%d disciplinas)." % \
		[diretorio_exportacao, disciplinas.size()], "sucesso", true, true)


## Exporta o planejamento atual para [code]planejamento.csv[/code] no diretorio de exportacoes.
## Formato: uma linha por professor, com colunas [code]codigo, semestre, ch_total, professor, ch[/code].
func _exportar_planejamento_csv() -> void:
	if _alocacoes.is_empty():
		_log("Nenhuma disciplina no planejamento para exportar.", "erro", true, true)
		return

	var chaves: Array = _alocacoes.keys()
	chaves.sort_custom(func(a, b):
		var da: Dictionary = _alocacoes[a]
		var db: Dictionary = _alocacoes[b]
		return str(da["semestre"]) + str(da["codigo"]) < str(db["semestre"]) + str(db["codigo"]))

	var linhas: Array[String] = []
	linhas.append("codigo,semestre,ch_total,professor,ch")

	for chave in chaves:
		var dados: Dictionary = _alocacoes[chave]
		var codigo: String = str(dados["codigo"])
		var semestre: String = str(dados["semestre"])
		var ch_total: String = str(dados.get("ch_total", 0))
		var profs: Dictionary = dados.get("professores", {})
		if profs.is_empty():
			linhas.append("%s,%s,%s,," % [codigo, semestre, ch_total])
		else:
			for pn in profs:
				linhas.append("%s,%s,%s,%s,%s" % [codigo, semestre, ch_total, pn, str(profs[pn])])

	file_handling.check_create_dir(diretorio_exportacao)
	var caminho: String = diretorio_exportacao + "planejamento.csv"
	var file := FileAccess.open(caminho, FileAccess.WRITE)
	if file == null:
		_log("Erro ao criar planejamento.csv em " + caminho, "erro", true, true)
		return
	for linha in linhas:
		file.store_line(linha)
	_log("Planejamento exportado para %splanejamento.csv (%d linhas)." % \
		[diretorio_exportacao, linhas.size() - 1], "sucesso", true, true)


## Exporta para [code]oferta.txt[/code] uma linha por disciplina, no formato
## [code]Nome - Professor(es) - CODIGO - Turma[/code] (varios professores separados por " - ").
## Respeita o filtro de curso ativo no painel (todas as disciplinas se nao houver filtro);
## disciplinas sem professor alocado sao omitidas. Ordem alfabetica pelo nome da disciplina.
func _exportar_oferta_txt() -> void:
	if _alocacoes.is_empty():
		_log("Nenhuma disciplina no planejamento para exportar.", "erro", true, true)
		return

	var cod_filtro: String = _painel_disciplinas.filtro_curso
	var entradas: Array = []
	for chave in _alocacoes:
		var dados: Dictionary = _alocacoes[chave]
		var semestre: String = str(dados.get("semestre", ""))
		if not cod_filtro.is_empty() and not _painel_disciplinas.semestre_pertence_ao_curso(semestre, cod_filtro):
			continue
		var profs: Dictionary = dados.get("professores", {})
		if profs.is_empty():
			continue
		var nome: String = str(dados.get("nome", ""))
		var codigo: String = str(dados.get("codigo", "")).to_upper()
		var turma: String = _turma_da_disciplina(semestre)
		var professores: String = " - ".join(PackedStringArray(profs.keys()))
		entradas.append({"nome": nome, "linha": "%s - %s - %s - %s" % [nome, professores, codigo, turma]})

	if entradas.is_empty():
		_log("Nenhuma disciplina com professor alocado para exportar.", "aviso", true, true)
		return

	entradas.sort_custom(func(a, b): return a["nome"].naturalnocasecmp_to(b["nome"]) < 0)
	var linhas: Array[String] = []
	for e in entradas:
		linhas.append(e["linha"])

	file_handling.check_create_dir(diretorio_exportacao)
	file_handling.save_text_file(diretorio_exportacao, "oferta.txt", linhas)
	_log("Oferta exportada para %soferta.txt (%d disciplinas)." % \
		[diretorio_exportacao, linhas.size()], "sucesso", true, true)


# Retorna a turma da disciplina no formato [code]T<n>[/code] (ex.: "T20") a partir do prefixo do
# [param semestre]: identifica o curso por [code]cursos.<cod>.prefixos_semestre[/code] e usa a
# PRIMEIRA turma de [code]cursos.<cod>.turmas[/code]. Retorna "" se nenhum curso casar ou se o
# curso nao tiver turmas.
func _turma_da_disciplina(semestre: String) -> String:
	var sem_lower: String = semestre.to_lower()
	for cod_curso in cursos:
		var prefixos: Array = cursos[cod_curso].get("prefixos_semestre", [])
		for pref in prefixos:
			if sem_lower.begins_with(str(pref).to_lower()):
				var turmas: Array = cursos[cod_curso].get("turmas", [])
				if turmas.size() > 0:
					return "T%d" % int(turmas[0])
				return ""
	return ""


## Exporta para [code]alteracoes.md[/code] a diferenca entre o planejamento importado (baseline em
## [member _alocacoes_inicial]) e o estado atual editado. Nao e um log de edicoes: o que vale e o
## diff liquido entre os dois estados — editar a mesma disciplina varias vezes rende so o final.
## Serve de guia do que ajustar na planilha de planejamento online.
func _exportar_alteracoes() -> void:
	var ini: Dictionary = _indexar_por_disciplina(_alocacoes_inicial)
	var fim: Dictionary = _indexar_por_disciplina(_alocacoes)
	var md: Array[String] = _gerar_md_alteracoes(ini, fim)
	file_handling.check_create_dir(diretorio_exportacao)
	file_handling.save_text_file(diretorio_exportacao, "alteracoes.md", md)
	_log("Alterações exportadas para %salteracoes.md." % diretorio_exportacao, "sucesso", true, true)


# Retorna true se a disciplina mudou entre baseline e atual: CH total divergente ou conjunto de
# professores/CH por professor diferente. Dictionary == compara conteudo recursivamente no Godot 4.
func _disciplina_alterada(antes: Dictionary, depois: Dictionary) -> bool:
	if int(antes.get("ch_total", 0)) != int(depois.get("ch_total", 0)):
		return true
	return antes.get("professores", {}) != depois.get("professores", {})


# Monta o titulo de uma disciplina para o Markdown: "### COD — Nome (semestre)", opcionalmente
# com " · CH N cr". Texto formatado e OK aqui — e saida de apresentacao.
func _titulo_disciplina_md(dados: Dictionary, com_ch: bool) -> String:
	var titulo: String = "### %s — %s (%s)" % [
		str(dados.get("codigo", "")).to_upper(), str(dados.get("nome", "")), str(dados.get("semestre", ""))]
	if com_ch:
		titulo += " · CH %d cr" % int(dados.get("ch_total", 0))
	return titulo


# Gera as linhas do alteracoes.md a partir dos indices baseline (ini) e atual (fim),
# ambos por "codigo|semestre". Classifica em adicionadas / removidas / alteradas.
func _gerar_md_alteracoes(ini: Dictionary, fim: Dictionary) -> Array[String]:
	var tempo: Dictionary = Time.get_datetime_dict_from_system()
	var data_str: String = "%d-%02d-%02d %02d:%02d" % \
		[tempo["year"], tempo["month"], tempo["day"], tempo["hour"], tempo["minute"]]

	var md: Array[String] = []
	md.append("# Alterações no Planejamento de Oferta")
	md.append("")
	md.append("Exportado em: %s" % data_str)
	md.append("Diferença entre o planejamento importado (base) e o estado atual editado.")
	md.append("Aplique estas mudanças na planilha de planejamento online.")
	md.append("")

	# Uniao das chaves, ordenada por semestre depois codigo (mesma ordem do CSV/JSON export).
	var chaves: Dictionary = {}
	for k in ini:
		chaves[k] = true
	for k in fim:
		chaves[k] = true
	var lista_chaves: Array = chaves.keys()
	lista_chaves.sort_custom(func(a, b):
		var da: Dictionary = fim.get(a, ini.get(a, {}))
		var db: Dictionary = fim.get(b, ini.get(b, {}))
		return str(da.get("semestre", "")) + str(da.get("codigo", "")) < \
			str(db.get("semestre", "")) + str(db.get("codigo", "")))

	var adicionadas: Array[String] = []
	var removidas: Array[String] = []
	var alteradas: Array[String] = []
	for k in lista_chaves:
		if fim.has(k) and not ini.has(k):
			adicionadas.append(k)
		elif ini.has(k) and not fim.has(k):
			removidas.append(k)
		elif _disciplina_alterada(ini[k], fim[k]):
			alteradas.append(k)

	if adicionadas.is_empty() and removidas.is_empty() and alteradas.is_empty():
		md.append("**Nenhuma alteração desde a importação.**")
		return md

	if not adicionadas.is_empty():
		md.append("## Disciplinas adicionadas")
		md.append("")
		for k in adicionadas:
			var dados: Dictionary = fim[k]
			md.append(_titulo_disciplina_md(dados, true))
			var profs: Dictionary = dados.get("professores", {})
			if profs.is_empty():
				md.append("- (sem professor alocado)")
			else:
				for pn in profs:
					md.append("- %s (%d cr)" % [pn.capitalize(), int(profs[pn])])
			md.append("")

	if not removidas.is_empty():
		md.append("## Disciplinas removidas")
		md.append("")
		for k in removidas:
			md.append(_titulo_disciplina_md(ini[k], false))
		md.append("")

	if not alteradas.is_empty():
		md.append("## Disciplinas alteradas")
		md.append("")
		for k in alteradas:
			var antes: Dictionary = ini[k]
			var depois: Dictionary = fim[k]
			md.append(_titulo_disciplina_md(depois, false))
			var pi: Dictionary = antes.get("professores", {})
			var pf: Dictionary = depois.get("professores", {})
			for pn in pf:
				if not pi.has(pn):
					md.append("- Professor adicionado: %s (%d cr)" % [pn.capitalize(), int(pf[pn])])
				elif int(pi[pn]) != int(pf[pn]):
					md.append("- CH alterada: %s %d cr → %d cr" % [pn.capitalize(), int(pi[pn]), int(pf[pn])])
			for pn in pi:
				if not pf.has(pn):
					md.append("- Professor removido: %s (%d cr)" % [pn.capitalize(), int(pi[pn])])
			var ch_ini: int = int(antes.get("ch_total", 0))
			var ch_fim: int = int(depois.get("ch_total", 0))
			if ch_ini != ch_fim:
				md.append("- CH total da disciplina: %d cr → %d cr" % [ch_ini, ch_fim])
			md.append("")

	return md


#endregion

#region Acoes

func _on_acoes_opcao_selecionada(retorno: String, _lista_selecionada: Array[String]) -> void:
	match retorno:
		"determinar_demanda":
			if _carregar_dados_discentes():
				_relatorios.determinar_demanda(_condicoes_discentes,
					_painel_disciplinas.filtro_curso,
					_painel_disciplinas.filtro_semestre,
					_painel_disciplinas._semestre_edicao,
					[], _historico_discentes)
		"determinar_demanda_ignorar_oferta":
			if _carregar_dados_discentes():
				_relatorios.determinar_demanda(_condicoes_discentes,
					_painel_disciplinas.filtro_curso,
					_painel_disciplinas.filtro_semestre,
					_painel_disciplinas._semestre_edicao,
					_painel_disciplinas.codigos_presentes(), _historico_discentes)
		"verificar_carga_horaria":
			_relatorios.verificar_carga_horaria(_calcular_carga_por_prof(), _painel_disciplinas.filtro_curso)
			_atualizar_status_bar()
		"sugerir_oferta":
			# Carrega a demanda sem exigir (a sugestao degrada sem hist.csv) e sem limpar o terminal.
			var tem_demanda: bool = _carregar_dados_discentes(false)
			_relatorios.sugerir_oferta(_alocacoes, _todos_professores, _calcular_carga_por_prof(), \
				_condicoes_discentes, tem_demanda, _painel_disciplinas.filtro_curso, _historico_discentes)
			_atualizar_status_bar()
		"verificar_erro_afinidade":
			_relatorios.verificar_erro_afinidade(_alocacoes, _painel_disciplinas.filtro_curso)
			_atualizar_status_bar()
		"detectar_problema_oferta":
			_relatorios.detectar_problema_oferta(
				_painel_disciplinas.cards_disciplinas,
				_painel_disciplinas.filtro_curso,
				_painel_disciplinas._semestre_edicao)


# Carrega as condicoes de cada discente a partir do hist.csv, uma unica vez (cacheado em
# [member _condicoes_discentes]). Retorna true se os dados estao disponiveis. Quando hist.csv
# nao existe: loga um erro e retorna false se [param exigir] for true; caso contrario fica
# silencioso (usado pela sugestao de oferta, que degrada sem demanda).
func _carregar_dados_discentes(exigir: bool = true) -> bool:
	if not _condicoes_discentes.is_empty():
		return true
	# Consome o cache de dados discentes pre-computado pelo main (evita recalcular a cada troca de
	# modulo). Fallback (abaixo): se o cache estiver vazio, computa local.
	if not GV.dados_discentes.is_empty():
		_historico_discentes = GV.dados_discentes["historico"]
		_condicoes_discentes = GV.dados_discentes["condicoes_discentes"]
		return true
	if not FileAccess.file_exists(GV.dir_saida + "hist.csv"):
		if exigir:
			_log("hist.csv nao encontrado em " + GV.dir_saida + \
				" — nao e possivel determinar a demanda.", "erro", true, true)
		return false
	var historico: Dictionary = file_handling.ler_dados(GV.dir_saida, "hist.csv", posicoes_histcsv, false, grades_disciplinas_curriculos)
	_historico_discentes = historico
	analise_historico.simplificar_historico(historico, "situacao", ["aprovado", "dispensado", "matr"])
	var lista_alunos: Array[Array] = analise_historico.criar_lista_alunos(historico)
	_condicoes_discentes = analise_historico.condicoes_discentes(lista_alunos, historico, condicoes, \
		grades_disciplinas_curriculos, equivalencias)
	return true


#endregion

#region Interacao com cards e painel de atribuicoes

func _on_card_interagido(card: CardDisciplina) -> void:
	var codigo: String = card.codigo.to_lower()
	var semestre: String = card.semestre
	var chave_planejamento: String = card.chave_planejamento
	# Tenta pela chave de planejamento primeiro (correspondencia exata com o CSV).
	if _alocacoes.has(chave_planejamento):
		_disciplina_selecionada = chave_planejamento
	else:
		# Busca por codigo + semestre nas alocacoes (case-insensitive no semestre).
		var encontrado: bool = false
		for chave in _alocacoes:
			var dados: Dictionary = _alocacoes[chave]
			if dados["codigo"] == codigo and dados["semestre"].to_lower() == semestre.to_lower():
				_disciplina_selecionada = chave
				encontrado = true
				break
		if not encontrado:
			# Cria entrada se nao existir (ex.: disciplina inserida via grade sem alocacao).
			# Tenta extrair professores da entrada do planejamento CSV.
			var profs_dict: Dictionary = {}
			if _planejamento.has(chave_planejamento):
				var csv_profs: Array = _planejamento[chave_planejamento].get("professor", [])
				var csv_chs: Array = _planejamento[chave_planejamento].get("ch", [])
				for i in csv_profs.size():
					var pn: String = str(csv_profs[i])
					var ch: int = int(csv_chs[i]) if i < csv_chs.size() else 0
					if not pn.is_empty() and ch > 0:
						profs_dict[pn] = ch
			_disciplina_selecionada = chave_planejamento
			_alocacoes[chave_planejamento] = {
				"codigo": codigo,
				"nome": card.nome,
				"semestre": semestre,
				"oferta": card.oferta if not card.oferta.is_empty() else semestre,
				"ch_total": card.ch_total,
				"professores": profs_dict,
			}
	_exibir_disciplina_selecionada()


func _on_card_removido(chave: String) -> void:
	_alocacoes.erase(chave)
	if _disciplina_selecionada == chave:
		_disciplina_selecionada = ""
		_painel_atribuicoes.limpar()
	_atualizar_status_bar()
	_refresh_grade_se_visivel()


func _exibir_disciplina_selecionada() -> void:
	if _disciplina_selecionada.is_empty() or not _alocacoes.has(_disciplina_selecionada):
		_painel_atribuicoes.limpar()
		return
	var dados: Dictionary = _alocacoes[_disciplina_selecionada]
	var afinidade: Array[Dictionary] = _afinidade.obter_afinidade(dados["codigo"], dados["semestre"])

	# Indice reverso: disciplinas atualmente alocadas por professor.
	var alocacoes_por_prof: Dictionary = {}
	var visto_prof_cod: Dictionary = {}
	for chave in _alocacoes:
		var aloc: Dictionary = _alocacoes[chave]
		for pn in aloc.get("professores", {}):
			var vk := "%s_%s" % [pn.to_lower(), str(aloc["codigo"]).to_lower()]
			if visto_prof_cod.has(vk):
				continue
			visto_prof_cod[vk] = true
			if not alocacoes_por_prof.has(pn):
				alocacoes_por_prof[pn] = []
			alocacoes_por_prof[pn].append({
				"codigo": aloc["codigo"],
				"nome": aloc["nome"],
				"semestre": aloc["semestre"],
				"ch_prof": aloc["professores"][pn],
			})

	# Enriquece cada entrada com historico e alocacoes atuais para a dica flutuante.
	var detalhes: Dictionary = _afinidade.detalhes_historico(dados["codigo"])
	for entrada in afinidade:
		var nome_prof: String = str(entrada.get("nome", ""))
		var score: int = int(entrada.get("score", 0))
		var texto_detalhe: String = "[b]%s[/b]" % nome_prof.capitalize()
		if detalhes.has(nome_prof):
			texto_detalhe += "\n[b]Lecionado em:[/b]\n" + detalhes[nome_prof]
		if score > 0:
			texto_detalhe += "\n[b]Pontos de afinidade:[/b] %d" % score
		if alocacoes_por_prof.has(nome_prof):
			texto_detalhe += "\n[b]Alocado atualmente:[/b]"
			for disc in alocacoes_por_prof[nome_prof]:
				texto_detalhe += "\n  %s — %s (%d cr)" % [
					disc["codigo"].to_upper(), disc["nome"], disc["ch_prof"]]
		entrada["detalhe"] = texto_detalhe
	_painel_atribuicoes.exibir_disciplina(
		_disciplina_selecionada,
		dados["codigo"],
		dados["nome"],
		dados["semestre"],
		dados["ch_total"],
		dados["professores"],
		afinidade,
		_calcular_profs_destacar()
	)
	_painel_atribuicoes.definir_ch_por_prof(_calcular_carga_por_prof())
	_painel_atribuicoes.bloquear_edicao(false)


func _on_atribuicao_alterada() -> void:
	if _disciplina_selecionada.is_empty():
		return
	# Sincroniza as atribuicoes do painel de volta para as alocacoes.
	var profs: Dictionary = _painel_atribuicoes.obter_atribuicoes()
	_alocacoes[_disciplina_selecionada]["professores"] = profs
	# Atualiza o card correspondente no painel de disciplinas. Busca pela CHAVE UNICA da oferta
	# selecionada (a mesma que indexa cards_disciplinas e _alocacoes) — nunca por codigo+semestre, que
	# colide entre varias ofertas da mesma disciplina e atualizaria o card errado.
	var dados: Dictionary = _alocacoes[_disciplina_selecionada]
	var card: CardDisciplina = _painel_disciplinas.cards_disciplinas.get(_disciplina_selecionada, null)
	if card != null:
		var profs_array: Array[String] = []
		for pn in profs:
			profs_array.append(pn)
		card.professores = profs_array
		card.ch_total = dados["ch_total"]
		var total_alocada: int = 0
		for val in profs.values():
			total_alocada += int(val)
		# Define o excedente antes de ch_alocada (cujo setter recalcula o visual do card).
		card.ch_extra = maxi(0, total_alocada - int(dados["ch_total"]))
		card.ch_alocada = total_alocada
	# Atualiza o filtro de Professor para refletir mudanças nas atribuições (novos nomes
	# alocados ficam visíveis no dropdown; removidos somem dele).
	_painel_disciplinas.atualizar_filtros()
	_atualizar_status_bar()
	_painel_atribuicoes.definir_ch_por_prof(_calcular_carga_por_prof())


#endregion


#region Impressao e toggles

func _imprimir_planejamento() -> void:
	_terminal.titulo("Planejamento de oferta", true)
	_terminal.linha("Total de disciplinas: %d" % _planejamento.size())
	_terminal.espaco()
	for chave in _planejamento:
		var entrada: Dictionary = _planejamento[chave]
		var codigo: String = entrada.get("codigo", "?")
		var semestre: String = entrada.get("semestre", "?")
		var ch_disciplina: String = entrada.get("ch_disciplina", "?")
		var profs: Array = entrada.get("professor", [])
		var chs: Array = entrada.get("ch", [])
		var linha := codigo + " | " + semestre + " | CH: " + ch_disciplina
		if profs.size() > 0:
			linha += " | Professores: "
			for i in profs.size():
				var nome_prof: String = profs[i]
				var ch_prof: String = chs[i] if i < chs.size() else "?"
				linha += nome_prof + " (" + ch_prof + "h)"
				if i < profs.size() - 1:
					linha += ", "
		_terminal.item(linha)


# Mapa botao OnOff -> painel que ele controla. Base unica para alternar (Shift+clique isola/restaura)
# e para o realce: o botao fica "afundado" (toggle_mode) quando seu painel esta visivel.
func _mapa_toggles() -> Dictionary:
	return {
		$"%OnOffPainel": _painel_disciplinas,
		$"%OnOffAtribuicoes": _painel_atribuicoes,
		$"%OnOffTerminal": _terminal,
		$"%OnOffGrade": _grade_curricular,
	}


func _toggle_painel(alvo: Control) -> void:
	var mapa := _mapa_toggles()
	TogglePaineis.aplicar(mapa.values(), alvo, Input.is_key_pressed(KEY_SHIFT))
	TogglePaineis.sincronizar_botoes(mapa)
	_refresh_grade_se_visivel()


func _on_on_off_painel_button_up() -> void:
	_toggle_painel(_painel_disciplinas)


func _on_on_off_atribuicoes_button_up() -> void:
	_toggle_painel(_painel_atribuicoes)


func _on_on_off_terminal_button_up() -> void:
	_toggle_painel(_terminal)


func _on_on_off_grade_button_up() -> void:
	_toggle_painel(_grade_curricular)

#endregion


#region Grade curricular

# Handler do seletor de grade embutido na GradeCurricular: troca a grade desenhada.
func _on_grade_oferta_alterada(grade_nome: String) -> void:
	_grade_oferta_ativa = grade_nome
	if _grade_curricular.visible:
		_atualizar_grade_oferta()


# Handler da forma de apresentacao das celulas (SeletorOpcoes da GradeCurricular).
func _on_grade_oferta_forma_alterada(opcao: String) -> void:
	_forma_apresentacao_grade = opcao
	if _grade_curricular.visible:
		_atualizar_grade_oferta()


# Re-renderiza a grade quando ela esta visivel (chamado apos mudancas nos cards do painel).
func _refresh_grade_se_visivel() -> void:
	if _grade_curricular and _grade_curricular.is_visible_in_tree():
		_atualizar_grade_oferta()


# Monta e envia a matriz da grade curricular em analise. Colore o rodape de cada celula com a contagem
# de discentes por situacao (demanda, carregada sob demanda do hist.csv) e contorna as disciplinas ja
# inseridas no PainelDisciplinas, facilitando ver o que falta adicionar a oferta.
func _atualizar_grade_oferta() -> void:
	if _grade_oferta_ativa.is_empty() or not grades_disciplinas_curriculos.has(_grade_oferta_ativa):
		return
	var grade: Dictionary = grades_disciplinas_curriculos[_grade_oferta_ativa]
	# Normaliza para condicoes-base (cada base engloba sua variante "_aproveitamento" na contagem);
	# tambem absorve overrides antigos que tenham variantes salvas.
	var situacoes_rodape: Array = _normalizar_situacoes_rodape(config_oferta.get("situacoes_rodape", \
		["matriculado_agora", "matriculavel", "seaprovado"]))
	var contagens: Dictionary = _contagens_demanda(grade, situacoes_rodape, _painel_disciplinas.filtro_curso)
	var vazio_cursaveis: Dictionary = {}
	var vazio_cursadas: Array[String] = []
	var sem_destaque: Array[String] = []
	var codigos_inseridos: Array[String] = _painel_disciplinas.codigos_presentes()
	_grade_curricular.dados = analise_grades.montar_grade_curricular(
		grade, vazio_cursaveis, vazio_cursadas, {}, _forma_apresentacao_grade,
		sem_destaque, {}, contagens, situacoes_rodape, codigos_inseridos,
		PaletaSemantica.cor("selecao"))


# Contagem de discentes por situacao para cada disciplina da grade exibida.
# Com curso selecionado, considera todos os alunos do curso (de qualquer grade) reavaliados contra a
# grade exibida — assim quem e de outra grade entra desde que consiga cursar por aproveitamento.
# Sem curso, usa a demanda global (cada aluno avaliado contra a propria grade, casamento por codigo).
# Resultado cacheado por grade+curso (o hist.csv nao muda durante a sessao).
func _contagens_demanda(grade: Dictionary, situacoes_rodape: Array, filtro_curso: String) -> Dictionary:
	if situacoes_rodape.is_empty():
		return {}
	var chave_cache: String = _grade_oferta_ativa + "|" + (filtro_curso if not filtro_curso.is_empty() else "*")
	if _cache_contagens.has(chave_cache):
		return _cache_contagens[chave_cache]
	# Degrada silenciosamente sem hist.csv (a grade ainda mostra contorno de inseridas, sem numeros).
	if not _carregar_dados_discentes(false):
		return {}
	# Base de condicoes a contar: global (todos, grade propria) ou so o curso (reavaliado contra a grade exibida).
	var base_condicoes: Dictionary = _condicoes_discentes
	if not filtro_curso.is_empty():
		var lista_alunos_curso: Array[Array] = []
		for matricula in _historico_discentes.keys():
			var grade_aluno: String = analise_historico.detectar_versao_grade(matricula, _historico_discentes)
			if _curso_da_grade(grade_aluno) == filtro_curso:
				lista_alunos_curso.append([matricula, ""])
		base_condicoes = analise_historico.condicoes_discentes(lista_alunos_curso, _historico_discentes, \
			condicoes, grades_disciplinas_curriculos, equivalencias, _grade_oferta_ativa)
	var contagens: Dictionary = {}
	for codigo in grade.keys():
		var disc_cond: Dictionary = analise_historico.discentes_disciplina(codigo, base_condicoes, condicoes)
		var counts: Dictionary = {}
		for sit in situacoes_rodape:
			# Cada base engloba alunos com e sem aproveitamento (a variante "_aproveitamento" usa codigos
			# distintos, entao nao ha risco de contar o mesmo aluno duas vezes para a mesma celula).
			counts[sit] = (disc_cond.get(sit, []) as Array).size() \
				+ (disc_cond.get(sit + "_aproveitamento", []) as Array).size()
		contagens[str(codigo).to_lower()] = counts
	_cache_contagens[chave_cache] = contagens
	return contagens


# Reduz uma lista de situacoes do rodape as condicoes-base, removendo o sufixo "_aproveitamento" e
# deduplicando (preserva a ordem). A ordem resultante define a ordem dos numeros no rodape.
func _normalizar_situacoes_rodape(lista: Array) -> Array:
	var bases: Array = []
	for s in lista:
		var base: String = str(s).trim_suffix("_aproveitamento")
		if base not in bases:
			bases.append(base)
	return bases

#endregion
