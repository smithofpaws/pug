class_name TogglePaineis extends RefCounted
## Logica compartilhada dos botoes "OnOff" que mostram/ocultam paineis de um modulo.
##
## Sem estado e sem dependencia de [Input] (recebe [param isolar] pronto), para ser testavel.

## Alterna a visibilidade de [param alvo] dentro do conjunto [param grupo]. [br]
## - [param isolar] falso (clique normal): apenas inverte a visibilidade de [param alvo]. [br]
## - [param isolar] verdadeiro (Shift+clique): deixa visivel somente [param alvo], ocultando os
##   demais; porem, se [param alvo] ja for o unico visivel do grupo, torna todos visiveis (restaura).
static func aplicar(grupo: Array, alvo: Control, isolar: bool) -> void:
	if not is_instance_valid(alvo):
		return
	if not isolar:
		alvo.visible = not alvo.visible
		return
	# Conta quantos do grupo estao visiveis para detectar o caso "ja isolado".
	var visiveis: int = 0
	for n in grupo:
		if is_instance_valid(n) and n.visible:
			visiveis += 1
	var ja_isolado: bool = alvo.visible and visiveis == 1
	for n in grupo:
		if is_instance_valid(n):
			n.visible = true if ja_isolado else (n == alvo)


## Sincroniza o estado "pressionado" dos botoes OnOff (toggle_mode) com a visibilidade dos paineis,
## para que o botao indique se o painel que ele controla esta aberto. [br]
## [param mapa]: [code]{ Button: Control }[/code] — cada botao mapeado ao painel que ele controla.
## Usa [method BaseButton.set_pressed_no_signal] para nao reentrar nos handlers de clique.
static func sincronizar_botoes(mapa: Dictionary) -> void:
	for botao in mapa:
		var painel: Control = mapa[botao]
		if is_instance_valid(botao) and is_instance_valid(painel):
			botao.set_pressed_no_signal(painel.visible)
