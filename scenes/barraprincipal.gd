extends ReferenceRect

var general_functions := GeneralFunctions.new()
var file_handling := FileHandling.new()

signal modulo_selecionado
signal mensagem_texto

var lista: Array[String] : set = _lista_changed

## Versão do executável, injetada pelo [code]main.gd[/code] (vem de
## [code]application/config/version[/code], não de arquivo). Só é lida ao gerar o manual — o
## [code]_ready()[/code] dos filhos roda antes do [code]main._ready()[/code], então aqui ainda estaria vazia.
var versao_programa: String = ""

# Ids canonicos na MESMA ordem dos itens do seletor (inclui desabilitados), para reverter_seletor_para().
var _ids_modulos: Array[String] = []

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
	# Mesma ordem/conteudo de _retorno do seletor — usado por reverter_seletor_para().
	_ids_modulos = modulos_retorno.duplicate()
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

## Reseleciona visualmente o modulo [param id] no seletor. Usado pelo main ao reverter (cancelar a
## saida de um modulo com alteracoes nao salvas) ou ao confirmar (selecionar o destino). Dispara
## [signal modulo_selecionado] de novo — o main usa [code]_redirecionando[/code]/[code]_saida_confirmada[/code]
## para tratar a reentrada.
func reverter_seletor_para(id: String) -> void:
	var idx: int = _ids_modulos.find(id)
	if idx >= 0:
		$HBoxContainer/SeletorModulos.selecionar_item(idx)

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
	var md: String = _com_versao(arquivo.get_as_text())
	arquivo.close()

	var titulo: String = "Manual do Usuário — PUG"
	if not versao_programa.is_empty():
		titulo += " %s" % versao_programa
	var html: String = MarkdownHtml.documento(md, titulo, _css_tema())
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


# Acrescenta a versão do executável logo abaixo do título do manual. A versão NÃO fica escrita no
# MANUAL.md: ela é intrinseca ao binario (application/config/version, espelhada no
# export_presets.cfg pelo publicar_release.ps1), e uma terceira copia dentro do texto envelheceria
# em silêncio. Como o HTML é regerado a cada clique em Ajuda, a injeção em runtime nunca desatualiza.
func _com_versao(md: String) -> String:
	if versao_programa.is_empty():
		return md
	var linha_versao: String = "*Versão %s*" % versao_programa
	var linhas: PackedStringArray = md.replace("\r\n", "\n").replace("\r", "\n").split("\n")
	# Abaixo do H1 quando ele existe; senão no topo, para nunca perder a informação.
	if linhas.size() > 0 and linhas[0].begins_with("# "):
		linhas.insert(1, "")
		linhas.insert(2, linha_versao)
		return "\n".join(linhas)
	return linha_versao + "\n\n" + md


# Monta a folha de estilo do manual a partir das cores do tema vigente (via PaletaSemantica), para
# que o HTML gerado combine com o tema aplicado no momento.
func _css_tema() -> String:
	var fundo: Color = PaletaSemantica.fundo()
	var texto: Color = PaletaSemantica.cor("padrao")
	var realce: Color = PaletaSemantica.cor("selecao")
	# Cor de destaque das caixas de atencao (callouts), adaptada ao fundo/texto do tema.
	var alerta: Color = PaletaSemantica.cor_adaptada("alerta", fundo, texto)
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
blockquote {
	margin: 1em 0;
	padding: .4em 1em;
	border-left: 4px solid %s;
	background: %s;
	color: %s;
}
.callout {
	margin: 1.2em 0;
	padding: .8em 1em;
	border: 1px solid %s;
	border-left: 4px solid %s;
	border-radius: 6px;
	background: %s;
}
.callout-titulo { margin: 0 0 .4em; font-weight: bold; color: %s; }
.callout p { margin: .4em 0; }
.callout p:last-child { margin-bottom: 0; }
""" % [
		h.call(fundo), h.call(texto),
		h.call(realce), h.call(borda),
		h.call(realce), h.call(borda),
		h.call(fundo_codigo),
		h.call(borda), h.call(fundo_cabecalho), h.call(fundo_codigo),
		h.call(texto), h.call(sutil),
		h.call(borda), h.call(fundo_codigo), h.call(sutil),
		h.call(borda), h.call(alerta), h.call(fundo_codigo),
		h.call(alerta),
	]
