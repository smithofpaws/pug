class_name GradeVisual extends ReferenceRect
## Permite a apresentação de informações relacionadas a horários.
##
## Ao receber [param dados] cria uma grade contendo [param dados]. Suporta multiplos estilos 
## de formatação na grade.

signal celula_clicada(linha: int, coluna: int)
signal celula_clicada_direita(linha: int, coluna: int)
signal celula_clicada_meio(linha: int, coluna: int)
signal drop_realizado(linha: int, coluna: int, dados: Dictionary)
signal arraste_iniciado(linha: int, coluna: int)
signal arraste_terminado

# Classes instanciadas.
var analise_horarios := AnaliseHorarios.new()
# Pré-carregamento da cena da célula para evitar load() repetido em _criar_grade().
const _celula_scene := preload("res://scenes/Complementares/Grade/Celula.tscn")

## Contém os dados a serem apresentados na grade. 
## O formato a ser inserido é uma matriz de matrizes, isto é, uma matriz bidimensional. [br]
## Os dados devem ser inseridos em forma de String ou Dictionary, dependendo do nível de detalhe desejado. [br]
## - Caso for em forma de String, os textos serão posicionados centralizados as células; [br]
## - Caso for em forma de Dictionary, os dados podem ser posicionados com algum controle. Para controlar, basta [br]
## empregas as chaves abaixo: [br]
##   ~ [param texto_central]: Uma string que controla o texto central na célula; [br]
##   ~ [param cor_central]: ; [br]
##   ~ [param cor_fundo]: ; [br]
##   ~ [param cor_fundo]: ; [br]
##   ~ [param cor_barra_superior]: Atalho que define as quatro bordas de uma vez; [br]
##   ~ [param cor_barra_cima]: Cor da borda superior individual; [br]
##   ~ [param cor_barra_baixo]: Cor da borda inferior individual; [br]
##   ~ [param cor_barra_esquerda]: Cor da borda esquerda individual; [br]
##   ~ [param cor_barra_direita]: Cor da borda direita individual; [br]
var dados: Array[Array] = [] : set = _set_dados

## Larguras mínimas por coluna (px). [br]
## O índice do array corresponde ao número da coluna. [br]
## - 0 (ou índice inexistente) = sem mínimo, divide espaço igual com as demais; [br]
## - Valor > 0 = largura mínima fixa para aquela coluna. [br]
## Ex: [40.0] = coluna 0 com 40px, demais sem mínimo. [br]
## Ex: [100.0, 0.0, 50.0] = coluna 0 com 100px, coluna 1 sem mínimo, coluna 2 com 50px.
var larguras_colunas: Array = [80.0] : set = _set_larguras_colunas

## Conexões a desenhar sobre a grade (ex.: linhas de pré-requisito na grade curricular). [br]
## Cada item é um [Dictionary] com as chaves: [br]
## - [param origem]: posição [code][linha, coluna][/code] da célula de origem; [br]
## - [param destino]: posição [code][linha, coluna][/code] da célula de destino; [br]
## - [param cor]: cor da linha (String token ou [Color]). [br]
## Vazio (padrão) não desenha nada — assim a grade de horários permanece inalterada.
var conexoes: Array = [] : set = _set_conexoes

# Número de linhas na grade
var _linhas: int = 0

# Número de colunas na grade
var _colunas: int = 0

func _ready() -> void:
	# Adota o tema compartilhado das grades (controla o tamanho da fonte; cores vêm do tema global).
	theme = PaletaSemantica.tema_grades()
	# Redesenha as conexões quando as células são reposicionadas (reflow do GridContainer / resize).
	$GridContainer.sort_children.connect(func(): $Conexoes.queue_redraw())
	$Conexoes.resized.connect(func(): $Conexoes.queue_redraw())
	$Conexoes.draw.connect(_desenhar_conexoes)

# Cria a grade contendo [param dados].
func _criar_grade() -> void:
	var children := $GridContainer.get_children()
	for child in children:
		$GridContainer.remove_child(child)
		child.queue_free()
	$GridContainer.set_columns(_colunas)
	# Define os valores das células adicionadas a grade.
	var temp_lin: int = 0
	var temp_col: int = 0
	print_debug("Fornecendo informações a grade...")
	for a in _linhas*_colunas:
		var modulo: Celula = _celula_scene.instantiate()
		modulo.xpos = temp_col
		modulo.ypos = temp_lin
		modulo.clicado.connect(_on_celula_clicada.bind(temp_lin, temp_col))
		modulo.clicado_direito.connect(_on_celula_clicada_direita.bind(temp_lin, temp_col))
		modulo.clicado_meio.connect(_on_celula_clicada_meio.bind(temp_lin, temp_col))
		modulo.celula_dropada.connect(_on_celula_dropada)
		modulo.arraste_iniciado.connect(_on_celula_arraste_iniciado)
		modulo.arraste_terminado.connect(_on_celula_arraste_terminado)
		# Caso dados vazios, não faz nada.
		if dados.size() == 0:
			return
		# Caso os dados informados na Array sejam apenas Strings, altera só o texto central.
		if dados[temp_lin][temp_col] is String:
			modulo.texto_central = dados[temp_lin][temp_col]
			modulo.apenas_central = true
			$GridContainer.add_child(modulo)
		# Caso sejam Dictionary, atualiza a célula de forma mais detalhada.
		elif dados[temp_lin][temp_col] is Dictionary:
			if dados[temp_lin][temp_col].has("cor_barra_superior"):
				modulo.cor_barra_superior = dados[temp_lin][temp_col]["cor_barra_superior"]
			if dados[temp_lin][temp_col].has("cor_barra_cima"):
				modulo.cor_barra_cima = dados[temp_lin][temp_col]["cor_barra_cima"]
			if dados[temp_lin][temp_col].has("cor_barra_baixo"):
				modulo.cor_barra_baixo = dados[temp_lin][temp_col]["cor_barra_baixo"]
			if dados[temp_lin][temp_col].has("cor_barra_esquerda"):
				modulo.cor_barra_esquerda = dados[temp_lin][temp_col]["cor_barra_esquerda"]
			if dados[temp_lin][temp_col].has("cor_barra_direita"):
				modulo.cor_barra_direita = dados[temp_lin][temp_col]["cor_barra_direita"]
			if dados[temp_lin][temp_col].has("cor_central"):
				modulo.cor_central = dados[temp_lin][temp_col]["cor_central"]
			if dados[temp_lin][temp_col].has("cor_fundo"):
				modulo.cor_fundo = dados[temp_lin][temp_col]["cor_fundo"]
			if dados[temp_lin][temp_col].has("texto_central"):
				modulo.texto_central = dados[temp_lin][temp_col]["texto_central"]
			if dados[temp_lin][temp_col].has("faixa_alternada"):
				modulo.faixa_alternada = dados[temp_lin][temp_col]["faixa_alternada"]
			if dados[temp_lin][temp_col].has("texto_canto_superior_esquerdo"):
				modulo.texto_canto_superior_esquerdo = dados[temp_lin][temp_col]["texto_canto_superior_esquerdo"]
			if dados[temp_lin][temp_col].has("texto_canto_superior_direito"):
				modulo.texto_canto_superior_direito = dados[temp_lin][temp_col]["texto_canto_superior_direito"]
			if dados[temp_lin][temp_col].has("apenas_central"):
				modulo.apenas_central = dados[temp_lin][temp_col]["apenas_central"]
			if dados[temp_lin][temp_col].has("texto_rodape"):
				modulo.texto_rodape = dados[temp_lin][temp_col]["texto_rodape"]
			$GridContainer.add_child(modulo)
		else:
			print_debug("ERRO: Formato de dado inválido para apresentação na grade.")
			modulo.texto_central = "Invalid data format"
			modulo.apenas_central = true
			$GridContainer.add_child(modulo)
		# Aplica largura mínima configurada para cada coluna (0 ou índice inexistente = sem mínimo).
		if temp_col < larguras_colunas.size() and larguras_colunas[temp_col] > 0:
			modulo.custom_minimum_size.x = larguras_colunas[temp_col]
			modulo.size_flags_horizontal = Control.SIZE_FILL
		temp_col += 1
		if temp_col >= _colunas:
			temp_col = 0
			temp_lin += 1
			if temp_lin >= _linhas:
				print("Informações fornecidas!")
				return

#region Setgets
func _set_larguras_colunas(valor: Array) -> void:
	larguras_colunas = valor
	if _linhas > 0 and _colunas > 0:
		_criar_grade()

func _set_dados(new_state: Array[Array]) -> void:
	dados = new_state
	if dados.size() > 0:
		if _linhas != dados.size():
			_linhas = dados.size()
		if dados[0] is Array:
			if _colunas != dados[0].size():
				_colunas = dados[0].size()
	if _linhas > 0 and _colunas > 0:
		_criar_grade()

func _set_conexoes(novas: Array) -> void:
	conexoes = novas
	if is_inside_tree():
		$Conexoes.queue_redraw()
#endregion

#region Conexões
# Desenha cada conexão como uma curva da célula de origem até a de destino, com seta no destino.
func _desenhar_conexoes() -> void:
	if conexoes.is_empty():
		return
	var overlay: Control = $Conexoes
	# Faixas para linhas RETAS com salto (>1 célula): adjacentes ficam no centro (formam uma "espinha"
	# perfeitamente alinhada) e os saltos correm paralelos ao lado, com o MESMO deslocamento nas duas
	# pontas (evita o zigue-zague). Diagonais que compartilham célula são distribuídas lado a lado.
	var faixa_reta: Dictionary = {}   # índice da conexão -> deslocamento perpendicular (px)
	var saltos_vert: Dictionary = {}  # coluna -> [índices] de verticais com salto
	var saltos_horiz: Dictionary = {} # linha -> [índices] de horizontais com salto
	var saidas: Dictionary = {}       # chave da origem -> [índices] de diagonais
	var entradas: Dictionary = {}     # chave do destino -> [índices] de diagonais
	for i in conexoes.size():
		var c = conexoes[i]
		if not (c is Dictionary and c.has("origem") and c.has("destino")):
			continue
		var po: Array = c["origem"]
		var pd: Array = c["destino"]
		var dl: int = int(pd[0]) - int(po[0])
		var dc: int = int(pd[1]) - int(po[1])
		if dc == 0 and abs(dl) > 1:
			saltos_vert.get_or_add(int(po[1]), []).append(i)
		elif dl == 0 and abs(dc) > 1:
			saltos_horiz.get_or_add(int(po[0]), []).append(i)
		elif dc != 0 and dl != 0:
			saidas.get_or_add(_chave_pos(po), []).append(i)
			entradas.get_or_add(_chave_pos(pd), []).append(i)
	for grupo in saltos_vert.values() + saltos_horiz.values():
		for k in grupo.size():
			faixa_reta[grupo[k]] = _lane_alternada(k)
	for i in conexoes.size():
		var conexao = conexoes[i]
		if not (conexao is Dictionary and conexao.has("origem") and conexao.has("destino")):
			continue
		var pos_o: Array = conexao["origem"]
		var pos_d: Array = conexao["destino"]
		var c_o: Celula = get_celula(int(pos_o[0]), int(pos_o[1]))
		var c_d: Celula = get_celula(int(pos_d[0]), int(pos_d[1]))
		if c_o == null or c_d == null:
			continue
		var cor: Color = _cor_conexao(conexao.get("cor", Color.YELLOW))
		var centro_o: Vector2 = c_o.global_position + c_o.size * 0.5 - overlay.global_position
		var centro_d: Vector2 = c_d.global_position + c_d.size * 0.5 - overlay.global_position
		var off_reto: float = faixa_reta.get(i, 0.0)
		var desl_saida: float = _deslocamento_faixa(saidas.get(_chave_pos(pos_o), []), i)
		var desl_entrada: float = _deslocamento_faixa(entradas.get(_chave_pos(pos_d), []), i)
		var anc: Array = _ancoras_conexao(centro_o, c_o.size * 0.5, centro_d, c_d.size * 0.5, \
			pos_o, pos_d, off_reto, desl_saida, desl_entrada)
		_desenhar_curva(overlay, anc[0], anc[1], anc[2], cor)

# Chave de agrupamento "linha_coluna" para uma posição [linha, coluna].
func _chave_pos(pos: Array) -> String:
	return str(int(pos[0])) + "_" + str(int(pos[1]))

# Deslocamento perpendicular para o k-ésimo salto numa mesma coluna/linha, alternando os lados:
# k=0 -> +14, k=1 -> -14, k=2 -> +28, ... (mantém os saltos paralelos e separados da espinha central).
func _lane_alternada(k: int) -> float:
	var nivel: int = k / 2 + 1
	var sinal: float = -1.0 if k % 2 == 1 else 1.0
	return nivel * 14.0 * sinal

# Deslocamento (em px) desta conexão dentro do grupo que compartilha uma célula, distribuindo as
# linhas simetricamente em torno do centro da borda (ex.: 3 linhas -> -espac, 0, +espac).
func _deslocamento_faixa(grupo: Array, indice: int) -> float:
	if grupo.size() <= 1:
		return 0.0
	var pos_no_grupo: int = grupo.find(indice)
	var espacamento: float = 16.0
	return (pos_no_grupo - (grupo.size() - 1) / 2.0) * espacamento

# Define os pontos de saída (origem) e entrada (destino) da linha e o ponto de controle da curva: [br]
# - RETA VERTICAL (mesma coluna): mesmo deslocamento em x nas duas pontas -> linha perfeitamente
#   vertical; adjacentes no centro, saltos paralelos ao lado ([param off_reto]). [br]
# - RETA HORIZONTAL (mesma linha): análogo, deslocando em y. [br]
# - DIAGONAL: cotovelo (origem sai pela lateral perto do nome; destino entra pelo topo/base), com ponto
#   de controle no canto e faixas [param desl_saida]/[param desl_entrada] para múltiplas no mesmo lado. [br]
# Retorna [p0, p1, ctrl] em coordenadas locais do overlay.
func _ancoras_conexao(centro_o: Vector2, meio_o: Vector2, centro_d: Vector2, meio_d: Vector2, \
		pos_o: Array, pos_d: Array, off_reto: float, desl_saida: float, desl_entrada: float) -> Array:
	var d_lin: int = int(pos_d[0]) - int(pos_o[0])
	var d_col: int = int(pos_d[1]) - int(pos_o[1])
	# Penetração simétrica: a linha começa [code]inset[/code] px dentro da origem e a ponta da seta
	# termina [code]inset[/code] px dentro do destino (mesma quantia nas duas células).
	var inset: float = 16.0
	var p0: Vector2
	var p1: Vector2
	var ctrl: Vector2
	if d_col == 0:
		# Reta vertical: x idêntico nas duas pontas garante linha perfeitamente vertical.
		var dx: float = clampf(off_reto, -(meio_o.x - 12.0), meio_o.x - 12.0)
		p0 = Vector2(centro_o.x + dx, centro_o.y + signf(d_lin) * (meio_o.y - inset))
		p1 = Vector2(centro_d.x + dx, centro_d.y - signf(d_lin) * (meio_d.y - inset))
		ctrl = (p0 + p1) * 0.5
	elif d_lin == 0:
		# Reta horizontal: y idêntico nas duas pontas.
		var dy: float = clampf(off_reto, -(meio_o.y - 10.0), meio_o.y - 10.0)
		p0 = Vector2(centro_o.x + signf(d_col) * (meio_o.x - inset), centro_o.y + dy)
		p1 = Vector2(centro_d.x - signf(d_col) * (meio_d.x - inset), centro_d.y + dy)
		ctrl = (p0 + p1) * 0.5
	else:
		# Diagonal: cotovelo arredondado (tangente horizontal na origem, vertical no destino).
		var dyo: float = clampf(desl_saida, -(meio_o.y - 10.0), meio_o.y - 10.0)
		p0 = Vector2(centro_o.x + signf(d_col) * (meio_o.x - inset), centro_o.y + dyo)
		var dxd: float = clampf(desl_entrada, -(meio_d.x - 12.0), meio_d.x - 12.0)
		p1 = Vector2(centro_d.x + dxd, centro_d.y - signf(d_lin) * (meio_d.y - inset))
		ctrl = Vector2(p1.x, p0.y)
	return [p0, p1, ctrl]

# Desenha uma Bézier quadrática de [param p0] a [param p1] com ponto de controle [param ctrl] e seta no
# destino.
func _desenhar_curva(overlay: Control, p0: Vector2, p1: Vector2, ctrl: Vector2, cor: Color) -> void:
	var pontos: PackedVector2Array = PackedVector2Array()
	var amostras: int = 16
	for i in amostras + 1:
		var t: float = float(i) / float(amostras)
		var um_menos_t: float = 1.0 - t
		# Bézier quadrática: (1-t)^2*p0 + 2(1-t)t*ctrl + t^2*p1
		pontos.append(um_menos_t * um_menos_t * p0 + 2.0 * um_menos_t * t * ctrl + t * t * p1)
	overlay.draw_polyline(pontos, cor, 2.0, true)
	# Seta no destino, orientada pela tangente final (ctrl -> p1).
	var tangente: Vector2 = (p1 - ctrl).normalized()
	if tangente == Vector2.ZERO:
		tangente = (p1 - p0).normalized()
	var lado: Vector2 = tangente.orthogonal()
	var base: Vector2 = p1 - tangente * 9.0
	overlay.draw_polygon(
		PackedVector2Array([p1, base + lado * 5.0, base - lado * 5.0]),
		PackedColorArray([cor, cor, cor])
	)

# Resolve a cor da conexão a partir de um token String (via PaletaSemantica) ou de um Color.
func _cor_conexao(valor) -> Color:
	if valor is Color:
		return valor
	if valor is String:
		return PaletaSemantica.cor(valor)
	return Color.YELLOW
#endregion

#region Sinais
func _on_celula_clicada(linha: int, coluna: int) -> void:
	celula_clicada.emit(linha, coluna)

func _on_celula_clicada_direita(linha: int, coluna: int) -> void:
	celula_clicada_direita.emit(linha, coluna)

func _on_celula_clicada_meio(linha: int, coluna: int) -> void:
	celula_clicada_meio.emit(linha, coluna)

func _on_celula_dropada(linha: int, coluna: int, dados: Dictionary) -> void:
	drop_realizado.emit(linha, coluna, dados)

func _on_celula_arraste_iniciado(linha: int, coluna: int) -> void:
	arraste_iniciado.emit(linha, coluna)

func _on_celula_arraste_terminado() -> void:
	arraste_terminado.emit()

func _limpar_highlight_todas_celulas() -> void:
	for cell in $GridContainer.get_children():
		if cell is Celula:
			cell.limpar_highlight_drag()

## Remove as marcações de preferência (barra superior) de todas as células e dos [member dados],
## SEM reconstruir a grade. Preferir isto a reatribuir [member dados] com uma matriz vazia só para
## limpar as preferências de horário do professor: a reconstrução libera/recria todas as células de
## uma vez, o que (com a grade populada) dispara um crash do engine ("Object was deleted while
## awaiting a callback" → segfault). Resetar as barras in-place não toca na árvore de nós.
func limpar_preferencias() -> void:
	for cell in $GridContainer.get_children():
		if cell is Celula:
			cell.cor_barra_cima = Color(0, 0, 0, 0)
	# Mantém os dados coerentes para futuras reconstruções (ex.: trocar de professor).
	for lin in dados:
		if lin is Array:
			for cel in lin:
				if cel is Dictionary:
					cel.erase("cor_barra_cima")
					cel.erase("cor_barra_superior")


## Aplica as marcações de preferência (barra superior, chave [code]cor_barra_cima[/code]) de
## [param matriz] às células existentes, SEM reconstruir a grade (mesmo motivo de [method
## limpar_preferencias]: reatribuir [member dados] libera/recria todas as células e, com a grade
## populada, causa um crash do engine). [param matriz] deve ter as dimensões da grade atual; se não
## tiver, cai no caminho de reconstrução padrão (reatribui [member dados]).
func aplicar_preferencias(matriz: Array) -> void:
	if _linhas == 0 or matriz.size() != _linhas \
			or not (matriz[0] is Array) or matriz[0].size() != _colunas:
		dados = matriz
		return
	for lin in range(_linhas):
		for col in range(_colunas):
			var origem = matriz[lin][col]
			if not (origem is Dictionary) or not origem.has("cor_barra_cima"):
				continue
			var cor = origem["cor_barra_cima"]
			var cel := get_celula(lin, col)
			if cel:
				cel.cor_barra_cima = cor
			if lin < dados.size() and dados[lin] is Array and col < dados[lin].size() \
					and dados[lin][col] is Dictionary:
				dados[lin][col]["cor_barra_cima"] = cor

func get_celula(linha: int, coluna: int) -> Celula:
	if linha < 0 or coluna < 0 or linha >= _linhas or coluna >= _colunas:
		return null
	var indice: int = linha * _colunas + coluna
	if indice >= $GridContainer.get_child_count():
		return null
	return $GridContainer.get_child(indice)


## Retorna (linha, coluna) da celula que contem o [param ponto] (coords globais de canvas, ex.: de
## [method CanvasItem.get_global_mouse_position]), ou (-1, -1) se nenhuma. Inverso de [method get_celula]:
## indice = linha * colunas + coluna.
func celula_em_ponto_global(ponto: Vector2) -> Vector2i:
	var filhos: Array = $GridContainer.get_children()
	for i in filhos.size():
		var c: Control = filhos[i]
		if c.get_global_rect().has_point(ponto):
			@warning_ignore("integer_division")
			return Vector2i(i / _colunas, i % _colunas)
	return Vector2i(-1, -1)
#endregion
