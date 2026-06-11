extends AcceptDialog
## Janela de configurações editáveis (parâmetros de módulos).
##
## Componente puramente de apresentação: não lê nem escreve arquivos. Recebe os dados via
## [method configurar] e comunica as alterações do usuário ao [code]main.gd[/code] através
## do sinal [signal parametro_alterado], que centraliza a persistência via overrides.

## Emitido quando o usuário altera um parâmetro. [param caminho] é o caminho canônico da
## chave no dicionário de configuração; [param valor] é o novo valor já convertido.
signal parametro_alterado(caminho: Array, valor: Variant)

## Emitido quando o usuário pede para restaurar os padrões. A I/O (apagar overrides, recarregar
## o base) fica a cargo do [code]main.gd[/code].
signal restauracao_solicitada

## Emitido quando o usuário pede para abrir o painel de administração do servidor Kinto. O painel
## (que faz I/O de rede) é instanciado pelo [code]main.gd[/code]; esta janela só dispara o pedido.
signal abrir_admin_servidor

var _carregando: bool = false

var _escala_atual: float = 1.0
var _escala_min: float = 0.5
var _escala_max: float = 3.0
var _escala_passo: float = 0.1

var _fonte_atual: int = 16
var _fonte_min: int = 10
var _fonte_max: int = 32
var _fonte_passo: int = 1

var _fonte_grade_offset: int = 0
var _fonte_grade_min: int = 8
var _fonte_grade_max: int = 32

var _transp_atual: float = 0.0
var _transp_min: float = 0.0
var _transp_max: float = 0.8
var _transp_passo: float = 0.05

# Dados repassados ao seletor de horários liberados (aba Posicionamento). Atualizados em configurar.
var _dias_semana: Array = []
var _horas_aula: Array = []
var _periodos: Dictionary = {}
var _emergencia: Array = []
var _liberados: Array = []


func _ready() -> void:
	# Títulos das abas: o TabContainer os deriva do nome do nó, e set_tab_title não é serializado
	# no .tscn — por isso são definidos aqui (uma vez), e não a cada chamada de configurar().
	$TabContainer.set_tab_title(0, "Planejamento de oferta")
	$TabContainer.set_tab_title(1, "Limites e choque")
	$TabContainer.set_tab_title(2, "Geral")
	$TabContainer.set_tab_title(3, "Interface")
	$TabContainer.set_tab_title(4, "Posicionamento")
	# Botão extra (ao lado do OK) que dispara a restauração dos padrões; a confirmação e a I/O
	# acontecem no main.gd via o sinal restauracao_solicitada.
	add_button("Restaurar padrões", true, "restaurar_padroes")
	custom_action.connect(_on_custom_action)
	$SeletorHorariosLiberados.horarios_alterados.connect(_on_horarios_liberados_alterado)
	# Botão (aba Geral) que abre o painel de administração do servidor Kinto. O painel em si vive no
	# main.gd (faz I/O de rede); aqui só sinalizamos o pedido.
	var bt_admin := Button.new()
	bt_admin.text = "Administração do servidor…"
	$TabContainer/Geral.add_child(bt_admin)
	bt_admin.pressed.connect(func() -> void: emit_signal("abrir_admin_servidor"))


func _on_custom_action(acao: StringName) -> void:
	if acao == "restaurar_padroes":
		hide()
		emit_signal("restauracao_solicitada")


## Abre a janela centralizada, garantindo largura suficiente para exibir todas as abas (as setas
## de navegação só aparecem se ainda assim faltar espaço). A altura é dada pelo conteúdo da aba
## mais alta (graças a [code]use_hidden_tabs_for_min_size[/code]), evitando o "pulo" ao trocar de aba.
func abrir() -> void:
	_estilizar_setas_abas()
	min_size.x = _largura_minima_abas()
	popup_centered()
	Dialogos.limitar_a_tela(self)


# Largura (px lógicos) necessária para o cabeçalho com todas as abas visíveis, estimada a partir da
# fonte e do estilo do tema atual mais as margens laterais do TabContainer no .tscn.
func _largura_minima_abas() -> int:
	var tab_bar: TabBar = $TabContainer.get_tab_bar()
	var fonte: Font = tab_bar.get_theme_font("font")
	if fonte == null:
		fonte = ThemeDB.fallback_font
	var tam_fonte: int = tab_bar.get_theme_font_size("font_size")
	if tam_fonte <= 0:
		tam_fonte = ThemeDB.fallback_font_size
	var estilo: StyleBox = tab_bar.get_theme_stylebox("tab_selected")
	var margem_aba: float = 24.0
	if estilo != null:
		margem_aba = estilo.get_margin(SIDE_LEFT) + estilo.get_margin(SIDE_RIGHT)
	var total: float = 0.0
	for i in $TabContainer.get_tab_count():
		var largura_texto: float = fonte.get_string_size(
			$TabContainer.get_tab_title(i), HORIZONTAL_ALIGNMENT_LEFT, -1, tam_fonte).x
		total += largura_texto + margem_aba
	# Soma as margens laterais do TabContainer (8 + 8 no .tscn) e uma pequena folga.
	return int(ceil(total)) + 16 + 8


# Substitui as setas de incremento/decremento do cabeçalho por triângulos quadrados da altura da
# aba, mais fáceis de clicar. Regenerado a cada abertura para acompanhar a cor do tema vigente.
func _estilizar_setas_abas() -> void:
	var tab_bar: TabBar = $TabContainer.get_tab_bar()
	var altura: int = maxi(int(tab_bar.get_minimum_size().y), 18)
	var cor: Color = PaletaSemantica.cor("padrao")
	var direita: ImageTexture = _criar_seta(altura, cor, true)
	var esquerda: ImageTexture = _criar_seta(altura, cor, false)
	tab_bar.add_theme_icon_override("increment", direita)
	tab_bar.add_theme_icon_override("increment_highlight", direita)
	tab_bar.add_theme_icon_override("decrement", esquerda)
	tab_bar.add_theme_icon_override("decrement_highlight", esquerda)


# Desenha um triângulo cheio (seta) [param tamanho]x[param tamanho] apontando para a direita
# (">") ou esquerda ("<"), na cor [param cor], com fundo transparente.
func _criar_seta(tamanho: int, cor: Color, direita: bool) -> ImageTexture:
	var img := Image.create(tamanho, tamanho, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var inset: int = maxi(int(round(tamanho * 0.28)), 1)
	var largura := float(tamanho - 2 * inset)
	var centro := tamanho / 2.0
	var meia_altura_max := largura / 2.0
	for x in range(inset, tamanho - inset):
		var t: float = float(x - inset) / maxf(largura, 1.0)
		# ">" afina da esquerda (base) para a direita (ponta); "<" o contrário.
		var meia_altura := meia_altura_max * (1.0 - t) if direita else meia_altura_max * t
		for y in range(tamanho):
			if absf(y - centro) <= meia_altura:
				img.set_pixel(x, y, cor)
	return ImageTexture.create_from_image(img)


func configurar(cfg: Dictionary, temas_internos: Array[String] = [], tema_atual: String = "") -> void:
	_carregando = true

	_popular_ppc(cfg)
	_popular_interface(cfg, temas_internos, tema_atual)

	var oferta: Dictionary = cfg.get("planejamento_oferta", {})
	$TabContainer/PlanejamentoOferta/JanelaAfinidade/SpinBox.value = int(oferta.get("janela_afinidade", 12))
	$TabContainer/PlanejamentoOferta/ChMinimo/SpinBox.value = int(oferta.get("ch_minimo", 8))
	$TabContainer/PlanejamentoOferta/ChIdeal/SpinBox.value = int(oferta.get("ch_ideal", 12))
	$TabContainer/PlanejamentoOferta/ChMaximo/SpinBox.value = int(oferta.get("ch_maximo", 20))
	$TabContainer/PlanejamentoOferta/HorasPorCredito/SpinBox.value = int(oferta.get("horas_por_credito", 15))
	_popular_situacoes_rodape(cfg)

	var limites: Dictionary = cfg.get("modulos", {}).get("trancamento", {}).get("limites", {})
	$TabContainer/LimitesChoque/TrancamentoTotal/SpinBox.value = int(limites.get("total", 6))
	$TabContainer/LimitesChoque/TrancamentoConsecutivo/SpinBox.value = int(limites.get("consecutivo", 3))

	var limiar: float = cfg.get("choque", {}).get("limiar_presenca", 0.75) as float
	$TabContainer/LimitesChoque/LimiarChoque/SpinBox.value = int(roundi(limiar * 100.0))

	var posic: Dictionary = cfg.get("posicionamento_auto", {})
	var pesos: Dictionary = posic.get("pesos", {})
	$TabContainer/Posicionamento/PesoPreferencia/SpinBox.value = float(pesos.get("preferencia", 1.0))
	$TabContainer/Posicionamento/ExpoentePreferencia/SpinBox.value = float(pesos.get("preferencia_expoente", 2.0))
	$TabContainer/Posicionamento/PesoForaPeriodo/SpinBox.value = float(pesos.get("fora_periodo", 8.0))
	$TabContainer/Posicionamento/PesoEmergencia/SpinBox.value = float(pesos.get("emergencia", 20.0))
	$TabContainer/Posicionamento/PesoChoqueProfessor/SpinBox.value = float(pesos.get("choque_professor", 50.0))
	$TabContainer/Posicionamento/PesoChoqueSala/SpinBox.value = float(pesos.get("choque_sala", 10.0))
	$TabContainer/Posicionamento/PesoChoqueAluno/SpinBox.value = float(pesos.get("choque_aluno", 2.0))
	$TabContainer/Posicionamento/BonusMesmoHorario/SpinBox.value = float(pesos.get("bonus_mesmo_horario", 15.0))
	$TabContainer/Posicionamento/TamanhoBloco/SpinBox.value = int(posic.get("tamanho_bloco", 2))
	$TabContainer/Posicionamento/ProfessorRigido/CheckButton.button_pressed = bool(posic.get("choque_professor_rigido", true))

	# Dados para o seletor de horários liberados (aberto sob demanda pelo botão Configurar).
	_dias_semana = cfg.get("dias_semana", [])
	_horas_aula = cfg.get("horarios_aula", [])
	_periodos = posic.get("periodos", {})
	_emergencia = posic.get("horarios_emergencia", [])
	_liberados = posic.get("horarios_liberados", [])

	_carregando = false

	DicasPrograma.vincular($TabContainer/PlanejamentoOferta/JanelaAfinidade/SpinBox, ["planejamento_oferta","janela_afinidade"])
	DicasPrograma.vincular($TabContainer/PlanejamentoOferta/ChMinimo/SpinBox, ["planejamento_oferta","ch_minimo"])
	DicasPrograma.vincular($TabContainer/PlanejamentoOferta/ChIdeal/SpinBox, ["planejamento_oferta","ch_ideal"])
	DicasPrograma.vincular($TabContainer/PlanejamentoOferta/ChMaximo/SpinBox, ["planejamento_oferta","ch_maximo"])
	DicasPrograma.vincular($TabContainer/PlanejamentoOferta/HorasPorCredito/SpinBox, ["planejamento_oferta","horas_por_credito"])
	DicasPrograma.vincular($TabContainer/PlanejamentoOferta/CondicoesRodape/Seletor, ["planejamento_oferta","situacoes_rodape"])
	DicasPrograma.vincular($TabContainer/LimitesChoque/TrancamentoTotal/SpinBox, ["trancamento","limite_total"])
	DicasPrograma.vincular($TabContainer/LimitesChoque/TrancamentoConsecutivo/SpinBox, ["trancamento","limite_consecutivo"])
	DicasPrograma.vincular($TabContainer/LimitesChoque/LimiarChoque/SpinBox, ["choque","limiar_presenca"])
	DicasPrograma.vincular($TabContainer/Geral/PPCPrincipal/OptionButton, ["geral","ppc_principal"])
	DicasPrograma.vincular($TabContainer/Posicionamento/PesoPreferencia/SpinBox, ["posicionamento","preferencia"])
	DicasPrograma.vincular($TabContainer/Posicionamento/ExpoentePreferencia/SpinBox, ["posicionamento","preferencia_expoente"])
	DicasPrograma.vincular($TabContainer/Posicionamento/PesoForaPeriodo/SpinBox, ["posicionamento","fora_periodo"])
	DicasPrograma.vincular($TabContainer/Posicionamento/PesoEmergencia/SpinBox, ["posicionamento","emergencia"])
	DicasPrograma.vincular($TabContainer/Posicionamento/PesoChoqueProfessor/SpinBox, ["posicionamento","choque_professor"])
	DicasPrograma.vincular($TabContainer/Posicionamento/PesoChoqueSala/SpinBox, ["posicionamento","choque_sala"])
	DicasPrograma.vincular($TabContainer/Posicionamento/PesoChoqueAluno/SpinBox, ["posicionamento","choque_aluno"])
	DicasPrograma.vincular($TabContainer/Posicionamento/BonusMesmoHorario/SpinBox, ["posicionamento","bonus_mesmo_horario"])
	DicasPrograma.vincular($TabContainer/Posicionamento/TamanhoBloco/SpinBox, ["posicionamento","tamanho_bloco"])
	DicasPrograma.vincular($TabContainer/Posicionamento/ProfessorRigido/CheckButton, ["posicionamento","professor_rigido"])
	DicasPrograma.vincular($TabContainer/Posicionamento/HorariosLiberados/Botao, ["posicionamento","horarios_liberados"])


# Abre o seletor de horários liberados com os dados atuais (dias, horas, períodos e seleção).
func _on_horarios_liberados_button_up() -> void:
	$SeletorHorariosLiberados.configurar(_dias_semana, _horas_aula, _periodos, _emergencia, _liberados)
	$SeletorHorariosLiberados.abrir()


# Propaga a nova seleção como override e atualiza a cópia local (para reaberturas na mesma sessão).
# Emite uma cópia profunda para a matriz de trabalho do diálogo não ficar aliased com a config.
func _on_horarios_liberados_alterado(matriz: Array) -> void:
	_liberados = matriz.duplicate(true)
	emit_signal("parametro_alterado", ["posicionamento_auto", "horarios_liberados"], _liberados)


# Popula o seletor de condicoes do rodape da grade com as condicoes-base disponiveis
# (planejamento_oferta.condicoes_rodape_disponiveis; rotulos amigaveis, retorno canonico) e marca as
# que estao em planejamento_oferta.situacoes_rodape. Cada base engloba sua variante "_aproveitamento"
# na contagem do modulo. Marca direto no popup (sem disparar opcao_selecionada), espelhando _popular_temas.
func _popular_situacoes_rodape(cfg: Dictionary) -> void:
	var oferta: Dictionary = cfg.get("planejamento_oferta", {})
	var bases: Array = oferta.get("condicoes_rodape_disponiveis", \
		["matriculado_agora", "matriculavel", "corequisito_matriculavel", "seaprovado", "corequisito_seaprovado"])
	var exibicao: Array[String] = []
	var retorno: Array[String] = []
	for base in bases:
		exibicao.append(str(base).replacen("_", " ").capitalize())
		retorno.append(str(base))
	var seletor = $TabContainer/PlanejamentoOferta/CondicoesRodape/Seletor
	seletor.popular("situacoes", exibicao, retorno, true)
	# Normaliza as marcadas para condicoes-base, absorvendo overrides antigos com "_aproveitamento".
	var selecionadas: Array = []
	for s in oferta.get("situacoes_rodape", ["matriculado_agora", "matriculavel", "seaprovado"]):
		selecionadas.append(str(s).trim_suffix("_aproveitamento"))
	# Como a chave comeca com "_", o separador e suprimido: os indices 0..n-1 batem com [param bases].
	var popup: PopupMenu = seletor.get_node("MenuButton").get_popup()
	for i in retorno.size():
		if retorno[i] in selecionadas:
			popup.set_item_checked(i, true)
	seletor.aplicar_contorno_popup()


func _popular_ppc(cfg: Dictionary) -> void:
	var opt: OptionButton = $TabContainer/Geral/PPCPrincipal/OptionButton
	opt.clear()
	opt.add_item("Nenhum (padrão)")
	var ppc_atual: String = cfg.get("ppc_principal", "")
	var cursos: Dictionary = cfg.get("cursos", {})
	var indice_selecionado: int = 0
	for cod_curso in cursos:
		for grade in cursos[cod_curso].get("grades", []):
			var nome_curso: String = cursos[cod_curso].get("nome", cod_curso)
			opt.add_item("%s (%s)" % [grade, nome_curso])
			if grade == ppc_atual:
				indice_selecionado = opt.item_count - 1
	opt.select(indice_selecionado)


func _on_ppc_principal_changed(indice: int) -> void:
	if _carregando:
		return
	var opt: OptionButton = $TabContainer/Geral/PPCPrincipal/OptionButton
	var valor: String = "" if indice == 0 else opt.get_item_text(indice).split(" (")[0]
	emit_signal("parametro_alterado", ["ppc_principal"], valor)


func _popular_interface(cfg: Dictionary, temas_internos: Array[String], tema_atual: String) -> void:
	var iface: Dictionary = cfg.get("interface", {})

	_escala_min = iface.get("escala_min", 0.5) as float
	_escala_max = iface.get("escala_max", 3.0) as float
	_escala_passo = iface.get("escala_passo", 0.1) as float
	_escala_atual = iface.get("escala", 1.0) as float
	$TabContainer/Interface/EscalaContainer/ValorEscala.text = str(_escala_atual)

	_fonte_min = iface.get("tamanho_fonte_min", 10) as int
	_fonte_max = iface.get("tamanho_fonte_max", 32) as int
	_fonte_passo = iface.get("tamanho_fonte_passo", 1) as int
	_fonte_atual = iface.get("tamanho_fonte", 16) as int
	$TabContainer/Interface/FonteContainer/ValorFonte.text = str(_fonte_atual)

	_fonte_grade_min = iface.get("tamanho_fonte_grade_min", 8) as int
	_fonte_grade_max = iface.get("tamanho_fonte_grade_max", 32) as int
	_fonte_grade_offset = iface.get("tamanho_fonte_grade_offset", 0) as int
	_atualizar_label_fonte_grade()

	_transp_atual = clampf(iface.get("transparencia_fundo", 0.0) as float, _transp_min, _transp_max)
	_atualizar_label_transparencia()

	_popular_temas(temas_internos, tema_atual)


func _atualizar_label_transparencia() -> void:
	$TabContainer/Interface/TransparenciaContainer/ValorTransparencia.text = "%d%%" % int(round(_transp_atual * 100.0))


func _atualizar_label_fonte_grade() -> void:
	var resolvido := clampi(_fonte_atual + _fonte_grade_offset, _fonte_grade_min, _fonte_grade_max)
	$TabContainer/Interface/FonteGradeContainer/ValorFonteGrade.text = str(resolvido)


func _popular_temas(temas_internos: Array[String], tema_atual: String) -> void:
	var exibicao: Array[String] = []
	for nome in temas_internos:
		exibicao.append(nome.replace("_", " ").capitalize())
	var tema_node = $TabContainer/Interface/TemaContainer/Tema
	tema_node.popular("tema", exibicao, temas_internos)
	tema_node.atualizar_texto_padrao = true
	var menu: MenuButton = tema_node.get_node("MenuButton")
	menu.text = tema_atual.replace("_", " ").capitalize()
	var popup: PopupMenu = menu.get_popup()
	for i in popup.get_item_count():
		if popup.get_item_text(i) == tema_atual.replace("_", " ").capitalize():
			popup.set_item_checked(i, true)
			break
	tema_node.aplicar_contorno_popup()


func _on_escala_menos_button_up() -> void:
	_alterar_escala(-_escala_passo)

func _on_escala_mais_button_up() -> void:
	_alterar_escala(_escala_passo)

func _alterar_escala(valor: float) -> void:
	if _carregando:
		return
	var nova_escala: float = snapped(_escala_atual + valor, _escala_passo)
	nova_escala = clamp(nova_escala, _escala_min, _escala_max)
	if nova_escala != _escala_atual:
		_escala_atual = nova_escala
		$TabContainer/Interface/EscalaContainer/ValorEscala.text = str(nova_escala)
		var mouse_antes := get_viewport().get_mouse_position()
		emit_signal("parametro_alterado", ["interface","escala"], nova_escala)
		position += Vector2i(get_viewport().get_mouse_position() - mouse_antes)


func _on_fonte_menos_button_up() -> void:
	_alterar_fonte(-_fonte_passo)

func _on_fonte_mais_button_up() -> void:
	_alterar_fonte(_fonte_passo)

func _alterar_fonte(delta: int) -> void:
	if _carregando:
		return
	var novo_tamanho: int = clampi(_fonte_atual + delta, _fonte_min, _fonte_max)
	if novo_tamanho != _fonte_atual:
		_fonte_atual = novo_tamanho
		$TabContainer/Interface/FonteContainer/ValorFonte.text = str(novo_tamanho)
		emit_signal("parametro_alterado", ["interface","tamanho_fonte"], novo_tamanho)
		_atualizar_label_fonte_grade()


func _on_fonte_grade_menos_button_up() -> void:
	_alterar_fonte_grade(-1)

func _on_fonte_grade_mais_button_up() -> void:
	_alterar_fonte_grade(1)

func _alterar_fonte_grade(delta: int) -> void:
	if _carregando:
		return
	var resolvido_atual := clampi(_fonte_atual + _fonte_grade_offset, _fonte_grade_min, _fonte_grade_max)
	var resolvido_novo := clampi(resolvido_atual + delta, _fonte_grade_min, _fonte_grade_max)
	if resolvido_novo != resolvido_atual:
		_fonte_grade_offset = resolvido_novo - _fonte_atual
		$TabContainer/Interface/FonteGradeContainer/ValorFonteGrade.text = str(resolvido_novo)
		emit_signal("parametro_alterado", ["interface","tamanho_fonte_grade_offset"], _fonte_grade_offset)


func _on_tema_selecionado(nome_interno: String, _lista_selecionada: Array) -> void:
	if _carregando:
		return
	emit_signal("parametro_alterado", ["interface","tema"], nome_interno)


func _on_transp_menos_button_up() -> void:
	_alterar_transparencia(-_transp_passo)

func _on_transp_mais_button_up() -> void:
	_alterar_transparencia(_transp_passo)

func _alterar_transparencia(delta: float) -> void:
	if _carregando:
		return
	var novo: float = snappedf(clampf(_transp_atual + delta, _transp_min, _transp_max), _transp_passo)
	if not is_equal_approx(novo, _transp_atual):
		_transp_atual = novo
		_atualizar_label_transparencia()
		emit_signal("parametro_alterado", ["interface","transparencia_fundo"], novo)


func _on_janela_afinidade_changed(valor: float) -> void:
	if _carregando:
		return
	emit_signal("parametro_alterado", ["planejamento_oferta","janela_afinidade"], int(valor))

func _on_ch_minimo_changed(valor: float) -> void:
	if _carregando:
		return
	emit_signal("parametro_alterado", ["planejamento_oferta","ch_minimo"], int(valor))

func _on_ch_ideal_changed(valor: float) -> void:
	if _carregando:
		return
	emit_signal("parametro_alterado", ["planejamento_oferta","ch_ideal"], int(valor))

func _on_ch_maximo_changed(valor: float) -> void:
	if _carregando:
		return
	emit_signal("parametro_alterado", ["planejamento_oferta","ch_maximo"], int(valor))

func _on_horas_por_credito_changed(valor: float) -> void:
	if _carregando:
		return
	emit_signal("parametro_alterado", ["planejamento_oferta","horas_por_credito"], int(valor))

func _on_situacoes_rodape_alterado(_retorno: String, lista_selecionada: Array[String]) -> void:
	if _carregando:
		return
	# A ordem segue a ordem das condicoes no popup (base_config.json), estavel — nao a ordem de clique.
	emit_signal("parametro_alterado", ["planejamento_oferta","situacoes_rodape"], lista_selecionada)

func _on_trancamento_total_changed(valor: float) -> void:
	if _carregando:
		return
	emit_signal("parametro_alterado", ["modulos","trancamento","limites","total"], int(valor))

func _on_trancamento_consecutivo_changed(valor: float) -> void:
	if _carregando:
		return
	emit_signal("parametro_alterado", ["modulos","trancamento","limites","consecutivo"], int(valor))

func _on_limiar_choque_changed(valor: float) -> void:
	if _carregando:
		return
	emit_signal("parametro_alterado", ["choque","limiar_presenca"], valor / 100.0)


func _on_peso_changed(valor: float, chave: String) -> void:
	if _carregando:
		return
	emit_signal("parametro_alterado", ["posicionamento_auto","pesos", chave], valor)

func _on_tamanho_bloco_changed(valor: float) -> void:
	if _carregando:
		return
	emit_signal("parametro_alterado", ["posicionamento_auto","tamanho_bloco"], int(valor))

func _on_professor_rigido_toggled(pressed: bool) -> void:
	if _carregando:
		return
	emit_signal("parametro_alterado", ["posicionamento_auto","choque_professor_rigido"], pressed)
