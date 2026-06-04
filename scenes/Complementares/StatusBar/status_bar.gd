class_name StatusBar extends HBoxContainer
## Rodapé de status reutilizável, ancorado à base do módulo (altura padrão 24px). [br]
## [br]
## Apresenta uma sequência de segmentos textuais separados por [VSeparator]. Cada segmento é
## identificado por uma chave (snake_case) e atualizado individualmente via [method atualizar],
## que aceita um token semântico opcional resolvido por [PaletaSemantica] para colorir o texto. [br]
## [br]
## Uso típico: o módulo chama [method definir_segmentos] uma vez (no [code]_ready[/code]) e depois
## [method atualizar] sempre que o estado mudar.

# Mapa { chave: Label } dos segmentos atualmente exibidos.
var _segmentos: Dictionary = {}

## Cria os segmentos na ordem de inserção de [param textos_iniciais] (um [Dictionary] ordenado
## [code]{ chave: texto_inicial }[/code]), inserindo um [VSeparator] entre eles. Limpa quaisquer
## segmentos anteriores.
func definir_segmentos(textos_iniciais: Dictionary) -> void:
	for filho in get_children():
		filho.queue_free()
	_segmentos.clear()
	var primeiro: bool = true
	for chave in textos_iniciais:
		if not primeiro:
			add_child(VSeparator.new())
		primeiro = false
		var label := Label.new()
		label.text = str(textos_iniciais[chave])
		add_child(label)
		_segmentos[chave] = label

## Atualiza o texto do segmento [param chave]. [param token_cor] vazio remove qualquer override de
## cor; caso contrário aplica a cor semântica resolvida por [method PaletaSemantica.cor].
func atualizar(chave: String, texto: String, token_cor: String = "") -> void:
	if not _segmentos.has(chave):
		return
	var label: Label = _segmentos[chave]
	label.text = texto
	if token_cor.is_empty():
		label.remove_theme_color_override("font_color")
	else:
		label.add_theme_color_override("font_color", PaletaSemantica.cor(token_cor))
