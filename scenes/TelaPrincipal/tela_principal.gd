extends ReferenceRect

var modulos: Dictionary = {}: set = _modulos_atualizado

func _modulos_atualizado(new_value:Dictionary) -> void:
	modulos = new_value
	$VerificadordeArquivos.modulos = modulos

func _alterar_texto(texto: String) -> void:
	$Label.set_text("")
	$Label.set_text(texto)
