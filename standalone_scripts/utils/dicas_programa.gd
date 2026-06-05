class_name DicasPrograma extends Resource
## API centralizada para dicas de funcionalidade do programa.
##
## Os textos das dicas ficam em [code]arquivos/dicas.json[/code], carregado pelo [code]main.gd[/code]
## em [code]GV.dicas[/code]. Modulos usam [method vincular] com o caminho aninhado ate a chave desejada.
##
## Dicas geradas em runtime (ex.: detalhes de professor/disciplina) devem continuar usando
## [code]DicaFlutuante.vincular()[/code] diretamente.


## Vincula uma dica estatica a [param control], exibida ao passar o mouse. [br]
## [param caminho] e a sequencia de chaves ate o texto no dicionario [code]GV.dicas[/code]. [br]
## [param args] permite inserir valores dinamicos no texto, substituindo marcadores [code]{chave}[/code].
static func vincular(control: Control, caminho: Array, args: Dictionary = {}) -> void:
	if not is_instance_valid(control):
		return
	var texto_dica: String = texto(caminho, args)
	if texto_dica.is_empty():
		return
	DicaFlutuante.vincular(control, texto_dica)


## Retorna o texto da dica em [param caminho] (sequencia de chaves em [code]GV.dicas[/code]), com
## [param args] substituindo marcadores [code]{chave}[/code]. Devolve "" se o caminho nao levar a uma
## String. Util quando a dica nao se prende a um [Control] (ex.: item de [PopupMenu], exibido via
## [method DicaFlutuante.mostrar_em]).
static func texto(caminho: Array, args: Dictionary = {}) -> String:
	var atual = GV.dicas
	for chave in caminho:
		if not (atual is Dictionary) or not atual.has(chave):
			return ""
		atual = atual[chave]

	if not (atual is String):
		return ""

	var resultado: String = atual
	for arg in args:
		resultado = resultado.replace("{" + arg + "}", str(args[arg]))
	return resultado
