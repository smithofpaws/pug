extends ReferenceRect

var general_functions := GeneralFunctions.new()
var file_handling := FileHandling.new()

signal modulo_selecionado
signal mensagem_texto

var lista: Array[String] : set = _lista_changed

func _ready() -> void:
	pass

func _lista_changed(new_value: Array[String]) -> void:
	lista = new_value
	var modulos_visiveis: Array[String] = []
	var modulos_retorno: Array[String] = []
	var modulos_disabled: Array[bool] = []
	var modulos_config = GV.configuracao_base.get("modulos", {})
	for id_modulo in lista:
		var habilitado: bool = true
		var nome_exibicao: String = id_modulo
		if modulos_config.has(id_modulo):
			var modulo_data = modulos_config[id_modulo]
			nome_exibicao = modulo_data.get("nome", id_modulo)
			if modulo_data.has("enabled") and modulo_data["enabled"] == false:
				habilitado = false
		# O rótulo exibido usa o nome formatado; o retorno mantém o id canônico (snake_case).
		modulos_visiveis.append(nome_exibicao)
		modulos_retorno.append(id_modulo)
		modulos_disabled.append(not habilitado)
	$HBoxContainer/SeletorModulos.lista_itens = {
		"_modulos*": modulos_visiveis,
		"_modulos_retorno": modulos_retorno,
		"_modulos_disabled": modulos_disabled
	}
	$HBoxContainer/SeletorModulos.atualizar_texto_padrao = true
	if modulos_visiveis.size() > 0:
		$HBoxContainer/SeletorModulos.texto_padrao = modulos_visiveis[0]
	# Mantém em [member lista] apenas os ids canônicos dos módulos habilitados.
	var filtrados: Array[String] = []
	for i in modulos_retorno.size():
		if not modulos_disabled[i]:
			filtrados.append(modulos_retorno[i])
	lista = filtrados

func _on_seletor_modulos_opcao_selecionada(retorno: String, _lista_selecionada: Array) -> void:
	emit_signal("modulo_selecionado", retorno)

func _on_dir_saida_button_up() -> void:
	if OS.has_feature("pc"):
		OS.shell_open(GV.dir_saida)
	else:
		emit_signal("mensagem_texto", GV.dir_saida)

func _on_dir_exportacoes_button_up() -> void:
	if OS.has_feature("pc"):
		OS.shell_open(GV.dir_exportacoes)
	else:
		emit_signal("mensagem_texto", GV.dir_exportacoes)

func _on_button_button_up() -> void:
	if lista.size() > 0:
		$HBoxContainer/SeletorModulos.selecionar_item(0)

func _on_botao_configuracoes_button_up() -> void:
	$JanelaConfiguracoes.abrir()


# Gera o MANUAL.md como HTML estilizado com o tema atual e o abre no navegador padrao.
func _on_botao_ajuda_button_up() -> void:
	var arquivo := FileAccess.open("res://MANUAL.md", FileAccess.READ)
	if arquivo == null:
		emit_signal("mensagem_texto", "Não foi possível abrir o manual (MANUAL.md não encontrado).")
		return
	var md: String = arquivo.get_as_text()
	arquivo.close()

	var html: String = MarkdownHtml.documento(md, "Manual do Usuário — PUG", _css_tema())
	var saida := FileAccess.open("user://manual.html", FileAccess.WRITE)
	if saida == null:
		emit_signal("mensagem_texto", "Não foi possível gerar o manual em HTML.")
		return
	saida.store_string(html)
	saida.close()

	if OS.has_feature("pc"):
		OS.shell_open(ProjectSettings.globalize_path("user://manual.html"))
	else:
		emit_signal("mensagem_texto", ProjectSettings.globalize_path("user://manual.html"))


# Monta a folha de estilo do manual a partir das cores do tema vigente (via PaletaSemantica), para
# que o HTML gerado combine com o tema aplicado no momento.
func _css_tema() -> String:
	var fundo: Color = PaletaSemantica.fundo()
	var texto: Color = PaletaSemantica.cor("padrao")
	var realce: Color = PaletaSemantica.cor("selecao")
	# Tons derivados do par fundo/texto, garantindo contraste em qualquer tema (claro ou escuro).
	var borda: Color = fundo.lerp(texto, 0.30)
	var fundo_codigo: Color = fundo.lerp(texto, 0.10)
	var fundo_cabecalho: Color = fundo.lerp(texto, 0.16)
	var sutil: Color = fundo.lerp(texto, 0.65)
	var h := func(c: Color) -> String: return "#" + c.to_html(false)
	return """
* { box-sizing: border-box; }
body {
	margin: 0;
	background: %s;
	color: %s;
	font-family: "Segoe UI", system-ui, -apple-system, sans-serif;
	line-height: 1.6;
}
.conteudo { max-width: 860px; margin: 0 auto; padding: 32px 24px 96px; }
h1, h2, h3, h4 { line-height: 1.25; margin: 1.6em 0 0.6em; }
h1 { font-size: 2em; border-bottom: 2px solid %s; padding-bottom: .3em; }
h2 { font-size: 1.5em; border-bottom: 1px solid %s; padding-bottom: .2em; }
h3 { font-size: 1.25em; }
h4 { font-size: 1.05em; }
a { color: %s; text-decoration: none; }
a:hover { text-decoration: underline; }
p { margin: .7em 0; }
ul, ol { padding-left: 1.6em; margin: .6em 0; }
li { margin: .25em 0; }
hr { border: none; border-top: 1px solid %s; margin: 2em 0; }
code {
	background: %s;
	padding: .12em .4em;
	border-radius: 4px;
	font-family: "Cascadia Code", Consolas, monospace;
	font-size: .92em;
}
table { border-collapse: collapse; width: 100%%; margin: 1em 0; }
th, td { border: 1px solid %s; padding: .5em .7em; text-align: left; }
th { background: %s; }
tr:nth-child(even) td { background: %s; }
strong { color: %s; }
em { color: %s; }
""" % [
		h.call(fundo), h.call(texto),
		h.call(realce), h.call(borda),
		h.call(realce), h.call(borda),
		h.call(fundo_codigo),
		h.call(borda), h.call(fundo_cabecalho), h.call(fundo_codigo),
		h.call(texto), h.call(sutil),
	]
