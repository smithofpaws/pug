extends AcceptDialog
## Janela dedicada para o usuário liberar quais células (dia × hora) ficam disponíveis para o
## posicionamento automático de disciplinas.
##
## Componente de apresentação: não lê nem escreve arquivos. Emite [signal horarios_alterados] a cada
## alteração; a persistência (override em config_usuario.json) é feita pelo [code]main.gd[/code].
## Reaproveita o componente [GradeVisual] como seletor — o drag-drop fica inerte (sem alocacao_chave).

## Emitido a cada clique que altera a seleção. [param matriz] é a matriz booleana
## [code][[bool × dias] × horas][/code], alinhada a [code]base_config.json:horarios_aula[/code]
## (linhas) × [code]dias_semana[/code] (colunas).
signal horarios_alterados(matriz: Array)

# Estado atual da seleção (matriz booleana horas × dias).
var _liberados: Array = []
# Índices de hora (0-based) válidos: em algum período ou em emergência. Células de hora fora dessas
# ficam desabilitadas, pois a liberação "combina" com os períodos (interseção).
var _linhas_validas: Dictionary = {}
# Índices de hora (0-based) do período da manhã, e coluna (0-based) do sábado: no sábado só a manhã
# é válida (regra do posicionamento automático), então o resto do sábado fica desabilitado.
var _linhas_manha: Dictionary = {}
var _col_sabado: int = -1
var _n_horas: int = 0
var _n_dias: int = 0

# Token de cor para célula liberada; demais cores fixas (a grade usa fundo escuro em qualquer tema).
const _TOKEN_LIBERADA: String = "selecao"
const _COR_DISPONIVEL: Color = Color(0.20, 0.20, 0.20)
const _COR_INATIVA: Color = Color(0.11, 0.11, 0.11)
# Altura fixa (px lógicos) de cada linha da grade; define a altura de conteúdo dentro do ScrollContainer.
const _ALTURA_LINHA: int = 38

@onready var _grade: GradeVisual = $VBox/Scroll/Grade


## Abre a janela centralizada, com tamanho limitado ao viewport hospedeiro para não estourar a tela.
## A grade (e suas células) se distribui dentro dessa área, em vez de a janela crescer com o conteúdo.
func abrir() -> void:
	var hosp: Vector2 = get_tree().root.get_visible_rect().size
	var alvo := Vector2i(
		mini(560, int(hosp.x * 0.85)),
		mini(560, int(hosp.y * 0.85)))
	popup_centered(alvo)
	# Com wrap_controls desligado, o AcceptDialog só reposiciona os filhos num evento de resize.
	# Espera um quadro (janela já realizada) e dispara esse evento para a grade preencher na abertura.
	await get_tree().process_frame
	size = alvo + Vector2i(0, 1)
	size = alvo


## Popula a grade com [param dias] × [param horas], marca como desabilitadas as horas fora dos
## [param periodos]/[param emergencia] e pinta o estado inicial vindo de [param liberados].
func configurar(dias: Array, horas: Array, periodos: Dictionary, emergencia: Array, liberados: Array) -> void:
	_n_horas = horas.size()
	_n_dias = dias.size()
	_calcular_linhas_validas(dias, horas, periodos, emergencia)
	_normalizar_liberados(liberados)
	_montar_grade(dias, horas)
	# Altura de conteúdo = (cabeçalho + horas) × altura fixa. Dá ao ScrollContainer uma altura real
	# para rolar quando não couber, em vez de a grade esticar a janela.
	_grade.custom_minimum_size = Vector2(0, (_n_horas + 1) * _ALTURA_LINHA)
	_pintar_todas()
	if not _grade.celula_clicada.is_connected(_on_celula_clicada):
		_grade.celula_clicada.connect(_on_celula_clicada)


# Marca os índices de hora que estão em algum período ou em emergência (espelha _preparar_config
# do PosicionadorAutomatico, sem o índice +1 de cabeçalho). Também registra as linhas da manhã e a
# coluna do sábado, para tratar o caso especial do sábado (só manhã).
func _calcular_linhas_validas(dias: Array, horas: Array, periodos: Dictionary, emergencia: Array) -> void:
	_linhas_validas = {}
	_linhas_manha = {}
	for nome in periodos:
		var faixa: Array = periodos[nome]
		if faixa.size() < 2:
			continue
		var ini: int = horas.find(str(faixa[0]))
		var fim: int = horas.find(str(faixa[1]))
		if ini < 0 or fim < 0:
			continue
		for i in range(ini, fim + 1):
			_linhas_validas[i] = true
			if str(nome).to_lower() == "manha":
				_linhas_manha[i] = true
	for h in emergencia:
		var idx: int = horas.find(str(h))
		if idx >= 0:
			_linhas_validas[idx] = true
	_col_sabado = -1
	for j in dias.size():
		var d: String = str(dias[j]).to_lower()
		if d == "sábado" or d == "sabado":
			_col_sabado = j
			break


# Uma célula é válida (clicável/marcável) quando sua hora está em período/emergência; no sábado,
# apenas no período da manhã — espelhando a restrição do PosicionadorAutomatico.
func _celula_valida(i: int, j: int) -> bool:
	if not _linhas_validas.has(i):
		return false
	if j == _col_sabado and not _linhas_manha.has(i):
		return false
	return true


# Reconstrói a matriz interna nas dimensões atuais, copiando o que couber de [param liberados].
# Na primeira vez (sem seleção salva, [param liberados] vazio), pré-marca todas as células válidas
# (períodos + emergência), espelhando o padrão do base_config.json — o usuário ajusta a partir daí.
func _normalizar_liberados(liberados: Array) -> void:
	var usar_padrao: bool = liberados.is_empty()
	_liberados = []
	for i in _n_horas:
		var linha: Array = []
		for j in _n_dias:
			var v: bool = false
			if usar_padrao:
				v = _celula_valida(i, j)
			elif i < liberados.size() and liberados[i] is Array and j < liberados[i].size():
				v = bool(liberados[i][j])
			linha.append(v)
		_liberados.append(linha)


# Monta a matriz da GradeVisual: linha 0 = cabeçalho de dias; coluna 0 = cabeçalho de horas;
# corpo = células vazias (estilizadas depois por _pintar_celula).
func _montar_grade(dias: Array, horas: Array) -> void:
	var matriz: Array[Array] = []
	var cabecalho: Array = [{"texto_central": "", "apenas_central": true}]
	for dia in dias:
		cabecalho.append({"texto_central": str(dia), "apenas_central": true})
	matriz.append(cabecalho)
	for i in _n_horas:
		var linha: Array = [{"texto_central": str(horas[i]), "apenas_central": true}]
		for _j in _n_dias:
			linha.append({"apenas_central": true})
		matriz.append(linha)
	_grade.dados = matriz


func _pintar_todas() -> void:
	for i in _n_horas:
		for j in _n_dias:
			_pintar_celula(i + 1, j + 1)


# Aplica a cor de fundo conforme o estado da célula (inativa / disponível / liberada).
func _pintar_celula(linha: int, coluna: int) -> void:
	var celula: Celula = _grade.get_celula(linha, coluna)
	if celula == null:
		return
	var i: int = linha - 1
	var j: int = coluna - 1
	if not _celula_valida(i, j):
		celula.cor_fundo = _COR_INATIVA
	elif _liberados[i][j]:
		celula.cor_fundo = PaletaSemantica.cor(_TOKEN_LIBERADA)
	else:
		celula.cor_fundo = _COR_DISPONIVEL


func _on_celula_clicada(linha: int, coluna: int) -> void:
	# Ignora cabeçalhos e células fora dos períodos (desabilitadas).
	if linha < 1 or coluna < 1:
		return
	var i: int = linha - 1
	var j: int = coluna - 1
	if not _celula_valida(i, j):
		return
	_liberados[i][j] = not _liberados[i][j]
	_pintar_celula(linha, coluna)
	emit_signal("horarios_alterados", _liberados)
