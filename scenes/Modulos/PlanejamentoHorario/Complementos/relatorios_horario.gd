class_name RelatoriosHorario extends RefCounted
## Gera os relatórios do Planejamento de Horário no terminal, no padrão idiomático dos demais
## módulos (ver [RelatoriosOferta]): usa [code]titulo/secao/item/linha[/code] com tokens semânticos
## da [PaletaSemantica], em vez de [code]text_edit[/code] cru com cores legadas. [br]
## É puro de saída: recebe os dados por parâmetro e escreve no terminal injetado por [method configurar].

var _terminal: Node


## Injeta o terminal usado por todos os relatórios.
func configurar(terminal: Node) -> void:
	_terminal = terminal


## Resumo de choques de recurso e CH excedida (token [code]erro[/code]). [param res] vem de
## [method DetectorDeChoques.detectar].
func choques(res: Dictionary) -> void:
	if not res.has("resumo"):
		return
	for parte in res["resumo"]:
		_terminal.linha(str(parte), "erro")


## Relata apenas os choques presentes nas [param celulas] informadas (a ação corrente), em vez do
## resumo global. Usa os mapas por célula de [method DetectorDeChoques.detectar].
func choques_em(res: Dictionary, celulas: Array) -> void:
	var celulas_choque: Dictionary = res.get("celulas_choque", {})
	var celulas_exc: Dictionary = res.get("celulas_ch_excedida", {})
	var prof := false
	var sala := false
	var sem := false
	var exc := false
	for chave in celulas:
		var c: Dictionary = celulas_choque.get(chave, {})
		prof = prof or c.get("prof", false)
		sala = sala or c.get("sala", false)
		sem = sem or c.get("sem", false)
		exc = exc or celulas_exc.has(chave)
	var partes: Array[String] = []
	if prof:
		partes.append("choque de professor")
	if sala:
		partes.append("choque de sala")
	if sem:
		partes.append("choque de semestre")
	if exc:
		partes.append("CH excedida")
	if not partes.is_empty():
		_terminal.linha("Nesta alocação: %s." % ", ".join(partes), "erro")


## Avisos de sobrecarga do professor (carga ≥6h, noturna→manhã) e o status geral. [param res] vem de
## [method VerificadorCarga.verificar].
func carga(res: Dictionary) -> void:
	for aviso in res.get("avisos", []):
		_terminal.linha(str(aviso), "aviso")
	var info: String = res.get("info", "")
	if not info.is_empty():
		_terminal.linha(info, "padrao")


## Quantidade de células sem professor atribuído (token [code]aviso[/code]).
func sem_professor(quantidade: int) -> void:
	if quantidade > 0:
		_terminal.linha("%d célula(s) sem professor." % quantidade, "aviso")


## Relatório consolidado da ação "Verificar problemas" do menu Ações. [param secoes] é um Array de
## [code]{ "titulo": String, "token": String, "itens": Array[String] }[/code]; seções sem itens são
## puladas. Quando todas as seções vêm vazias, imprime "Nenhum problema encontrado." (token sucesso).
func verificacao_completa(secoes: Array) -> void:
	_terminal.titulo("Verificação de problemas", true)
	var houve: bool = false
	for s in secoes:
		var itens: Array = s.get("itens", [])
		if itens.is_empty():
			continue
		houve = true
		_terminal.espaco()
		_terminal.secao(str(s.get("titulo", "")))
		var token: String = str(s.get("token", "padrao"))
		for it in itens:
			_terminal.item(str(it), 0, token)
	if not houve:
		_terminal.linha("Nenhum problema encontrado.", "sucesso")


## Relatório do posicionamento automático: total alocado e disciplinas que não couberam. [br]
## [param nome_curso] (opcional) imprime o filtro de curso aplicado, como nas Ações de oferta.
func posicionamento(plano: Dictionary, nome_curso: String = "") -> void:
	_terminal.titulo("Posicionamento automático", true)
	if not nome_curso.is_empty():
		_terminal.linha("Filtro curso: %s" % nome_curso, "aviso")
	var alocadas: Array = plano.get("alocacoes", [])
	if alocadas.is_empty():
		_terminal.linha("Nenhuma alocação gerada.", "aviso")
	else:
		_terminal.linha("%d aula(s) alocada(s)." % alocadas.size(), "sucesso")
	var nao_alocadas: Array = plano.get("nao_alocadas", [])
	if not nao_alocadas.is_empty():
		_terminal.espaco()
		_terminal.secao("Não foi possível posicionar completamente")
		for msg in nao_alocadas:
			_terminal.item(str(msg), 0, "aviso")
