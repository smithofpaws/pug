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

	var atual = GV.dicas
	for chave in caminho:
		if not (atual is Dictionary) or not atual.has(chave):
			return
		atual = atual[chave]

	if not (atual is String):
		return

	var texto: String = atual
	for arg in args:
		texto = texto.replace("{" + arg + "}", str(args[arg]))

	DicaFlutuante.vincular(control, texto)
