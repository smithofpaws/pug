class_name Horarios extends VBoxContainer
## Controla a apresentação dos horários conforme [param condicoes] como "matriculado_agora", 
## "matriculável", etc.

signal listacondicoes_alterada
signal listaopcoes_alterada

## Dados a serem enviados para a [GradeVisual], formatados conforme requisitado pela classe. 
## Essencialmente uma matriz bidimensional de texto contendo os dados de cada célula.
var dados: Array[Array] = [] : set = _set_dados

## Recebido pelo nó pai em sua criação e vem do arquivo [code]base_config.json[/code]. Contém 
## condicoes como "matriculado_agora", "matriculável", etc.
var condicoes: Array[String] = [] : set = _set_condicoes

## Lista dos botões de condições que estão ligados (e.g. "matriculado_agora", "matriculável"). 
## Recebe estas informações do seletor de situações. [br]
var lista_condicoes_verdadeiras: Array[String] = []

## Recebido pelo nó pai e vem de [code]base_config.json:formatos_grade[/code]. Define os modos de
## exibição das células da grade (rótulos exibidos + valores de retorno). Ao ser atribuído, popula o
## SeletorOpcoes. É a lista canônica compartilhada com o módulo Planejamento de Horário.
var formatos_grade: Dictionary : set = _set_formatos_grade

# Valores (retorno) dos modos de exibição, na ordem do seletor. Usado por selecionar_opcao_por_valor.
var _valores_opcoes: Array = []

## Seleciona forçadamente uma condicao.
func selecionar_condicao(index: int) -> void:
	$"%SeletorCondicoes".selecionar_item(index)

## Seleciona forçadamente uma opção pelo índice.
func selecionar_opcao(index: int) -> void:
	$"%SeletorOpcoes".selecionar_item(index)

## Seleciona forçadamente a opção cujo valor de retorno é [param valor].
func selecionar_opcao_por_valor(valor: String) -> void:
	var idx: int = _valores_opcoes.find(valor)
	if idx >= 0:
		$"%SeletorOpcoes".selecionar_item(idx)

#region Setgets
func _set_formatos_grade(new_value: Dictionary) -> void:
	formatos_grade = new_value
	_valores_opcoes = new_value.get("valores", [])
	$"%SeletorOpcoes".lista_itens = {
		"_lista*": new_value.get("rotulos", []),
		"_lista_retorno": _valores_opcoes
	}

func _set_dados(new_state: Array[Array]) -> void:
	dados = new_state
	$GradeHorarios.larguras_colunas = []
	$GradeHorarios.dados = dados

func _set_condicoes(new_state: Array[String]) -> void:
	condicoes = new_state
	var lista_itens: Dictionary
	lista_itens["_condicoes_"] = []
	lista_itens["_condicoes_retorno"] = []
	for a in condicoes.size():
		var temp: String = condicoes[a]
		temp = temp.replacen("_", " ")
		temp = temp.capitalize()
		lista_itens["_condicoes_"].append(temp)
		lista_itens["_condicoes_retorno"].append(condicoes[a])
	$"%SeletorCondicoes".lista_itens = lista_itens
#endregion

#region Sinais
func _on_seletor_condicoes_opcao_selecionada(_retorno, lista_selecionada) -> void:
	lista_condicoes_verdadeiras = lista_selecionada
	emit_signal("listacondicoes_alterada")

func _on_seletor_opcoes_opcao_selecionada(_retorno, lista_selecionada) -> void:
	emit_signal("listaopcoes_alterada",_retorno)
#endregion
