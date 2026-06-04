class_name PainelAtribuicoes extends VBoxContainer
## Painel de atribuicao de professores a uma disciplina selecionada.
## [br]
## Exibe os professores alocados com CH editavel, botao remover e ranking de
## afinidade baseado no historico de oferta.
## [br]
## Emite [signal atribuicao_alterada] quando professores/alocacoes mudam, e
## [signal curso_alterado] quando o usuario escolhe outro curso para a disciplina.

signal atribuicao_alterada()
signal curso_alterado(cod_curso: String)

var _disciplina_chave: String = ""
var _disciplina_codigo: String = ""
var _disciplina_ch_total: int = 0
var _professores_alocados: Dictionary = {}
var _todos_professores: Array[String] = []

# Unidade de carga horária exibida nos rótulos (default [code]"h"[/code]; o Planejamento
# de Oferta passa [code]"cr"[/code] em [method configurar] porque opera em créditos).
var _unidade_ch: String = "h"

# Afinidade atualmente exibida, guardada para re-renderizar (cores) ao alocar/desalocar.
var _afinidade_atual: Array[Dictionary] = []

# Texto da dica flutuante por professor (historico de oferta), montado pelo modulo.
var _detalhes_por_prof: Dictionary = {}

# Set (Dict com value=true) de nomes de professor normalizados que recebem destaque
# adicional na lista de afinidade (ex.: docentes do curso atualmente filtrado). Renovado
# a cada [method exibir_disciplina].
var _profs_destacar: Dictionary = {}

# Carga horaria total alocada a cada professor (nome normalizado → creditos/horas),
# usada para exibir no lugar da pontuacao na lista de afinidade.
var _ch_por_prof: Dictionary = {}

# Metadados de cursos (formato [code]base_config.json:cursos[/code]), usados para popular
# o seletor de curso. Injetado via [method configurar].
var _cursos: Dictionary = {}

var _bloqueado: bool = false


func _ready() -> void:
	$"%SeletorCurso".opcao_selecionada.connect(_on_seletor_curso_opcao_selecionada)
	_limpar_exibicao()


## Configura o painel com dados iniciais. [br]
## [param unidade_ch] é o rótulo da unidade de CH; passe [code]"h"[/code] (default no campo) ou
## [code]"cr"[/code] em módulos que operam em créditos (Planejamento de Oferta). Quando vazio,
## preserva o valor previamente configurado — útil em chamadas subsequentes que só atualizam
## a lista de professores sem querer redefinir a unidade. [br]
## [param cursos] é o dicionário [code]base_config.json:cursos[/code], usado para popular o
## OptionButton de curso. Quando vazio, preserva o que ja estiver configurado.
func configurar(todos_professores: Array[String], unidade_ch: String = "", cursos: Dictionary = {}) -> void:
	_todos_professores = todos_professores.duplicate()
	_todos_professores.sort_custom(func(a, b): return a < b)
	if not unidade_ch.is_empty():
		_unidade_ch = unidade_ch
	if not cursos.is_empty():
		_cursos = cursos
		_popular_opt_curso()


## Define a carga horaria total alocada a cada professor (nome normalizado → creditos/horas).
## Usado para exibir [code](N cr)[/code] no lugar da pontuacao na lista de afinidade.
func definir_ch_por_prof(ch: Dictionary) -> void:
	_ch_por_prof = ch
	_atualizar_afinidade()


# Preenche o seletor de curso com os itens de [member _cursos] (ordem alfabetica por
# cod_curso para previsibilidade), usando cod_curso como retorno.
func _popular_opt_curso() -> void:
	var cods: Array = _cursos.keys()
	cods.sort()
	var cursos_itens: Array[String] = []
	var cursos_retorno: Array[String] = []
	for cod in cods:
		var nome: String = str(_cursos[cod].get("nome", cod))
		cursos_itens.append(nome)
		cursos_retorno.append(str(cod))
	$"%SeletorCurso".lista_itens = {
		"_cursos*": cursos_itens,
		"_cursos_retorno": cursos_retorno
	}
	$"%SeletorCurso".atualizar_texto_padrao = true


## Exibe os dados de uma disciplina para edicao de atribuicoes.
## [param afinidade] e uma lista ordenada de dicionarios { "nome": str, "score": int }. [br]
## [param profs_destacar] e um set (Dict com value=true) de nomes ja normalizados; cada entry
## da lista de afinidade cujo nome estiver nele recebe um marcador adicional. Vazio = sem
## destaque extra. [br]
## [param cod_curso_atual] sincroniza o OptionButton de curso ([code]""[/code] = sem selecao).
func exibir_disciplina(chave: String, codigo: String, nome: String, semestre: String, \
		ch_total: int, professores: Dictionary, afinidade: Array[Dictionary], \
		profs_destacar: Dictionary = {}, cod_curso_atual: String = "") -> void:
	_disciplina_chave = chave
	_disciplina_codigo = codigo
	_disciplina_ch_total = ch_total
	_professores_alocados = professores.duplicate()
	_profs_destacar = profs_destacar.duplicate()
	$"%InfoDisciplina".text = "%s  %s" % [codigo.to_upper(), nome]
	$"%InfoSemestre".text = "Semestre: %s    CH total: %d %s" % [semestre, ch_total, _unidade_ch]
	$"%InfoDisciplina".visible = true
	$"%InfoSemestre".visible = true
	$"%LinhaCurso".visible = true
	$"%Placeholder".visible = false
	_selecionar_curso_no_opt(cod_curso_atual)
	_afinidade_atual = _completar_afinidade(afinidade)
	_detalhes_por_prof.clear()
	for e in afinidade:
		var detalhe: String = str(e.get("detalhe", ""))
		if not detalhe.is_empty():
			_detalhes_por_prof[str(e.get("nome", ""))] = detalhe
	_atualizar_linhas_professores()
	_atualizar_afinidade()
	_atualizar_ch_alocada()


## Limpa o painel para o estado vazio.
func limpar() -> void:
	_disciplina_chave = ""
	_disciplina_codigo = ""
	_disciplina_ch_total = 0
	_professores_alocados.clear()
	_afinidade_atual = []
	_profs_destacar.clear()
	_limpar_exibicao()


## Retorna as atribuicoes atuais da disciplina selecionada.
func obter_atribuicoes() -> Dictionary:
	return _professores_alocados.duplicate()


## Bloqueia/desbloqueia a edicao (usado quando nenhuma disciplina esta selecionada).
func bloquear_edicao(bloquear: bool) -> void:
	_bloqueado = bloquear


func _limpar_exibicao() -> void:
	$"%InfoDisciplina".text = ""
	$"%InfoDisciplina".visible = false
	$"%InfoSemestre".text = ""
	$"%InfoSemestre".visible = false
	$"%LinhaCurso".visible = false
	$"%Placeholder".visible = true
	$"%CHLabel".text = ""
	for filho in $"%PainelProfessores".get_children():
		filho.queue_free()
	for filho in $"%PainelAfinidade".get_children():
		filho.queue_free()
	bloquear_edicao(true)


# Encontra o item do seletor de curso cujo cod_curso bate com [param cod_curso] e o seleciona.
# Quando [param cod_curso] e vazio ou nao tem item correspondente, nao faz nada.
func _selecionar_curso_no_opt(cod_curso: String) -> void:
	if cod_curso.is_empty() or _cursos.is_empty():
		return
	var cods: Array = _cursos.keys()
	cods.sort()
	for i in cods.size():
		if str(cods[i]) == cod_curso:
			$"%SeletorCurso".selecionar_item(i)
			return


# Reage a escolha do usuario no seletor de curso.
func _on_seletor_curso_opcao_selecionada(retorno: String, _lista_selecionada: Array) -> void:
	curso_alterado.emit(retorno)


func _on_remover_professor_pressed(prof_nome: String) -> void:
	if _bloqueado:
		return
	_professores_alocados.erase(prof_nome)
	_atualizar_linhas_professores()
	_atualizar_afinidade()
	_atualizar_ch_alocada()
	atribuicao_alterada.emit()


func _on_ch_professor_changed(valor: float, prof_nome: String) -> void:
	if _bloqueado:
		return
	# Minimo 1h: a remocao do professor e feita apenas pelo botao "✕".
	# Sem teto no total da disciplina — horas acima sao permitidas (hora extra).
	_professores_alocados[prof_nome] = maxi(1, int(valor))
	_atualizar_linhas_professores()
	_atualizar_afinidade()
	_atualizar_ch_alocada()
	atribuicao_alterada.emit()


# Cada clique em "+ alocar" acresce 1h ao professor (1h no primeiro clique).
# Segurando Shift, aloca o restante da CH total da disciplina de uma so vez.
# Permite ultrapassar a CH total da disciplina (hora extra), sinalizada no rodape.
func _on_clicar_afinidade(prof_nome: String) -> void:
	if _bloqueado or _disciplina_chave.is_empty():
		return
	var ch_atual: int = int(_professores_alocados.get(prof_nome, 0))
	var incremento: int = 1
	if Input.is_key_pressed(KEY_SHIFT):
		var ch_alocada: int = 0
		for ch in _professores_alocados.values():
			ch_alocada += int(ch)
		var restante: int = _disciplina_ch_total - ch_alocada
		if restante > 0:
			incremento = restante
	_professores_alocados[prof_nome] = ch_atual + incremento
	_atualizar_linhas_professores()
	_atualizar_afinidade()
	_atualizar_ch_alocada()
	atribuicao_alterada.emit()


func _atualizar_linhas_professores() -> void:
	for filho in $"%PainelProfessores".get_children():
		filho.queue_free()
	if _professores_alocados.is_empty():
		var label_vazio := Label.new()
		label_vazio.text = "Nenhum professor alocado."
		label_vazio.add_theme_color_override("font_color", PaletaSemantica.cor("neutro"))
		$"%PainelProfessores".add_child(label_vazio)
		return
	for prof_nome in _professores_alocados:
		var ch: int = int(_professores_alocados[prof_nome])
		var linha := HBoxContainer.new()
		linha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Nome do professor (ocupa espaco disponivel)
		var label := Label.new()
		label.text = prof_nome.capitalize()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		DicaFlutuante.vincular(label, str(_detalhes_por_prof.get(prof_nome, "")))
		linha.add_child(label)
		# SpinBox para CH
		var spin := SpinBox.new()
		spin.custom_minimum_size = Vector2(60, 0)
		spin.min_value = 1
		# Teto folgado para permitir hora extra acima da CH total da disciplina.
		spin.max_value = maxi(99, _disciplina_ch_total + 12)
		spin.value = ch
		spin.step = 1
		# Espaco no inicio para que o SpinBox renderize "4 cr" e nao "4cr".
		spin.suffix = " " + _unidade_ch
		spin.value_changed.connect(_on_ch_professor_changed.bind(prof_nome))
		linha.add_child(spin)
		# Botao remover
		var btn := Button.new()
		btn.text = "✕"
		btn.custom_minimum_size = Vector2(30, 0)
		btn.pressed.connect(_on_remover_professor_pressed.bind(prof_nome))
		linha.add_child(btn)
		$"%PainelProfessores".add_child(linha)


# Completa a afinidade com todos os professores conhecidos: os que tem historico
# vem primeiro (ordenados por score); os demais sao anexados ao fim (score 0), em
# ordem alfabetica, indicando baixa afinidade.
func _completar_afinidade(afinidade: Array[Dictionary]) -> Array[Dictionary]:
	var completa: Array[Dictionary] = []
	completa.assign(afinidade)
	var presentes: Dictionary = {}
	for e in afinidade:
		presentes[str(e.get("nome", "")).to_lower()] = true
	var faltantes: Array[String] = []
	for prof in _todos_professores:
		if not presentes.has(prof.to_lower()):
			faltantes.append(prof)
	faltantes.sort()
	for prof in faltantes:
		completa.append({"nome": prof, "score": 0})
	return completa


func _atualizar_afinidade() -> void:
	for filho in $"%PainelAfinidade".get_children():
		filho.queue_free()
	if _afinidade_atual.is_empty():
		var label_vazio := Label.new()
		label_vazio.text = "Sem histórico de oferta."
		label_vazio.add_theme_color_override("font_color", PaletaSemantica.cor("neutro"))
		$"%PainelAfinidade".add_child(label_vazio)
		return
	for entrada in _afinidade_atual:
		var nome: String = str(entrada.get("nome", ""))
		var score: int = int(entrada.get("score", 0))
		if nome.is_empty():
			continue
		var ja_alocado: bool = _professores_alocados.has(nome)
		var linha := HBoxContainer.new()
		linha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var estrelas: String
		if score >= 46:
			estrelas = " ⭐⭐⭐⭐⭐"
		elif score >= 31:
			estrelas = " ⭐⭐⭐⭐"
		elif score >= 18:
			estrelas = " ⭐⭐⭐"
		elif score >= 9:
			estrelas = " ⭐⭐"
		elif score >= 3:
			estrelas = " ⭐"
		else:
			estrelas = ""
		var label := Label.new()
		# Marcador "● " quando o professor pertence ao set de destaque (ex.: docente do curso
		# atualmente filtrado). Funciona como sinal independente da cor — se o prof tambem
		# estiver alocado, o nome ainda fica verde e ganha o marcador a esquerda.
		var prefixo_destaque: String = "● " if _profs_destacar.has(nome) else ""
		var ch_texto: String = ""
		if not _ch_por_prof.is_empty():
			ch_texto = " (%d %s)" % [_ch_por_prof.get(nome, 0), _unidade_ch]
		label.text = "%s%s%s%s" % [prefixo_destaque, nome.capitalize(), ch_texto, estrelas]
		if ja_alocado:
			label.add_theme_color_override("font_color", PaletaSemantica.cor("ch_completo"))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		DicaFlutuante.vincular(label, str(entrada.get("detalhe", "")))
		linha.add_child(label)
		# O botao permanece disponivel mesmo apos alocar: cada clique acresce 1h.
		var btn := Button.new()
		btn.text = "+ alocar"
		btn.custom_minimum_size = Vector2(70, 0)
		btn.pressed.connect(_on_clicar_afinidade.bind(nome))
		linha.add_child(btn)
		$"%PainelAfinidade".add_child(linha)


func _atualizar_ch_alocada() -> void:
	var alocada: int = 0
	for ch in _professores_alocados.values():
		alocada += int(ch)
	if alocada == _disciplina_ch_total and _disciplina_ch_total > 0:
		$"%CHLabel".text = "CH alocada: %d/%d %s  ✓" % [alocada, _disciplina_ch_total, _unidade_ch]
		$"%CHLabel".add_theme_color_override("font_color", PaletaSemantica.cor("ch_completo"))
	elif alocada > _disciplina_ch_total:
		$"%CHLabel".text = "CH alocada: %d/%d %s  ⚠ (excedente!)" % [alocada, _disciplina_ch_total, _unidade_ch]
		$"%CHLabel".add_theme_color_override("font_color", PaletaSemantica.cor("excedente"))
	else:
		$"%CHLabel".text = "CH alocada: %d/%d %s" % [alocada, _disciplina_ch_total, _unidade_ch]
		$"%CHLabel".remove_theme_color_override("font_color")
