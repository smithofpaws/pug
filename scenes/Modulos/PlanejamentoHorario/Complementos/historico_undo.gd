class_name HistoricoUndo extends RefCounted
## Pilha de desfazer (Ctrl+Z) do Planejamento de Horário. [br]
## Cada item é um snapshot do estado da grade ANTES de uma ação mutadora:
## [code]{ "alocacoes": <cópia profunda>, "restricoes": <cópia>, "cards": { <chave>:
## { ch_alocada, ch_extra, permite_extra } } }[/code]. Em memória e por sessão — não é persistida;
## loads (abrir/baixar/horarios.txt) a esvaziam via [method limpar], pois desfazer através de uma
## troca de plano seria confuso. Tamanho limitado por [constant _UNDO_MAX] (descarta o mais antigo).

const _UNDO_MAX := 50
var _pilha: Array = []

var _ger_alocacoes: GerenciadorAlocacoes
var _restricoes_mgr: GerenciadorRestricoes
var _painel_disciplinas: Node
var _grade: Node
var _dados: ArquivosPlanejamento
var _recalcular: Callable
var _terminal: Node

## Configura as referências do módulo-pai. [param recalcular] é o [code]_recalcular_grade[/code]
## do módulo (chamado com [code]false[/code] após restaurar um snapshot); [param terminal] recebe
## as mensagens de feedback.
func configurar(ger_alocacoes: GerenciadorAlocacoes, restricoes_mgr: GerenciadorRestricoes, \
		painel_disciplinas: Node, grade: Node, dados: ArquivosPlanejamento, \
		recalcular: Callable, terminal: Node) -> void:
	_ger_alocacoes = ger_alocacoes
	_restricoes_mgr = restricoes_mgr
	_painel_disciplinas = painel_disciplinas
	_grade = grade
	_dados = dados
	_recalcular = recalcular
	_terminal = terminal

## Empilha um snapshot do estado atual da grade ANTES de uma ação mutadora. Chamar no início de
## cada ação (drop, mover, remover, posicionar, limpar). Descartável via [method descartar] quando
## a ação acaba não mudando nada (ex.: clique do meio numa célula só de referência).
func snapshot() -> void:
	var cards_estado: Dictionary = {}
	for chave in _painel_disciplinas.cards_disciplinas:
		var c: CardDisciplina = _painel_disciplinas.cards_disciplinas[chave]
		cards_estado[chave] = {"ch_alocada": c.ch_alocada, "ch_extra": c.ch_extra, "permite_extra": c.permite_extra}
	_pilha.append({
		"alocacoes": _ger_alocacoes.alocacoes.duplicate(true),
		"restricoes": _restricoes_mgr.restricoes.duplicate(true),
		"cards": cards_estado,
	})
	if _pilha.size() > _UNDO_MAX:
		_pilha.pop_front()

## Remove o último snapshot (quando a ação que o empilhou não chegou a mutar nada).
func descartar() -> void:
	if not _pilha.is_empty():
		_pilha.pop_back()

## Esvazia a pilha (ao carregar um plano novo: desfazer através de uma troca de plano seria confuso).
func limpar() -> void:
	_pilha.clear()

## Desfaz a última ação: restaura o snapshot do topo da pilha.
func desfazer() -> void:
	if _pilha.is_empty():
		_terminal.text_edit("Nada para desfazer.", "aviso", true, false)
		return
	_restaurar_estado(_pilha.pop_back())
	_terminal.text_edit("Ação desfeita.", "sucesso", true, false)

# Restaura a grade ao estado de um snapshot: limpa a grade atual, reinjeta alocações/restrições e os
# contadores dos cards, e repinta. Espelha a sequência de _nova_grade, mas com os dados do snapshot.
func _restaurar_estado(snap: Dictionary) -> void:
	for chave_celula in _ger_alocacoes.alocacoes.keys():
		var p: PackedStringArray = str(chave_celula).split("_")
		if p.size() == 2:
			_ger_alocacoes.limpar_celula(int(p[0]), int(p[1]))
	_ger_alocacoes.limpar_alocacoes()
	for chave_celula in snap["alocacoes"]:
		_ger_alocacoes.alocacoes[chave_celula] = (snap["alocacoes"][chave_celula] as Array).duplicate(true)
	_restricoes_mgr.restricoes = (snap["restricoes"] as Dictionary).duplicate(true)
	var cards: Dictionary = _painel_disciplinas.cards_disciplinas
	var cards_snap: Dictionary = snap["cards"]
	for chave in cards:
		var c: CardDisciplina = cards[chave]
		var e: Dictionary = cards_snap.get(chave, {"ch_alocada": 0, "ch_extra": 0, "permite_extra": false})
		# permite_extra/ch_extra antes de ch_alocada: o setter de ch_alocada recalcula o visual do card.
		c.permite_extra = e["permite_extra"]
		c.ch_extra = e["ch_extra"]
		c.ch_alocada = e["ch_alocada"]
	_grade.dados = _dados.gerar_matriz_vazia()
	_ger_alocacoes.reaplicar_todas()
	_recalcular.call(false)
