# Pacote de Utilidades para Graduação (PUG)
# Copyright (C) 2026 DIEGO ARTHUR HARTMANN
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

extends ReferenceRect
## Janela principal do programa. Usada para controlar todas as demais.
# Para encontrar coisas a serem adicionadas, pesquisar por '# TODO'
# Para encontrar coisas a serem corrigidas, pesquisar por '# FIXME'

# Classes instanciadas
var file_handling := FileHandling.new()
## Flag para evitar loop ao redirecionar para o módulo Principal
var _redirecionando := false
var _ajustando_janela := false
# Timer de debounce: adia a gravacao de base_config.json para evitar I/O em disco a cada frame
# durante o arraste da janela ou do controle de escala.
var _timer_salvar_config: Timer

func _ready() -> void:
	# Configura o diretório base do programa
	file_handling.configurar_diretoriobase()
	# Carrega o arquivo de configuração base
	GV.configuracao_base = file_handling.load_json(GV.dir_principal, "base_config.json")
	JsonValidator.validar_base_config(GV.configuracao_base)
	GV.config_usuario = file_handling.load_json(GV.dir_principal, "config_usuario.json")
	GV.configuracao_base = GeneralFunctions.merge_profundo(GV.configuracao_base, GV.config_usuario)
	# Carrega arquivos adicionais, como lista de disciplinas
	_carregar_arquivos()
	# Carrega dicas de funcionalidade (tooltips do programa)
	GV.dicas = file_handling.load_json(GV.dir_principal + "arquivos/", "dicas.json")
	# Timer de debounce: agrupa gravacoes de config_usuario.json disparadas por resize/escala.
	_timer_salvar_config = Timer.new()
	_timer_salvar_config.one_shot = true
	_timer_salvar_config.wait_time = 0.3
	_timer_salvar_config.timeout.connect(_salvar_config)
	add_child(_timer_salvar_config)
	# Aplica escala, tamanho da janela e tema a partir da configuração efetiva.
	_aplicar_interface_completa()
	get_window().size_changed.connect(_on_janela_redimensionada)
	# Configura a janela de configurações (parâmetros de módulos + interface)
	var janela_config := $BarraPrincipal/JanelaConfiguracoes
	janela_config.configurar(GV.configuracao_base, _descobrir_temas(),
		GV.configuracao_base.get("interface", {}).get("tema", "nord"))
	janela_config.parametro_alterado.connect(_on_config_parametro_alterado)
	janela_config.restauracao_solicitada.connect(_on_restaurar_padroes)
	# Configura os diretórios de dados
	file_handling.configurar_dirdados()
	# Envia dados necessários aos nós
	var chaves: Array[String] = []
	chaves.assign(GV.configuracao_base["modulos"].keys())
	$BarraPrincipal.lista = chaves
	_on_barra_principal_modulo_selecionado("principal")

## Aplica escala (DPI × multiplicador manual), tamanho da janela, oversampling de fonte e tema
## visual a partir de [member GV.configuracao_base]. Reutilizado no startup e ao restaurar padrões.
func _aplicar_interface_completa() -> void:
	# Calcula escala automatica com base no DPI do monitor (96 DPI = referencia padrao)
	var tela := DisplayServer.window_get_current_screen()
	var dpi := DisplayServer.screen_get_dpi(tela)
	GV.escala_dpi = dpi / 96.0 if dpi > 0 else 1.0
	# Multiplicador manual do usuario (1.0 = sem ajuste extra)
	var escala_usuario := GV.configuracao_base.get("interface", {}).get("escala", 1.0) as float
	# Fator de escala efetivo: DPI do monitor x multiplicador manual.
	var fator := GV.escala_dpi * escala_usuario
	# O zoom e aplicado via content_scale_size (e nao content_scale_factor): e a razao de stretch
	# (tamanho fisico / base) que dispara o oversampling das fontes no modo canvas_items, mantendo
	# o texto nitido. O fator de escala fica fixo em 1.0.
	get_window().content_scale_factor = 1.0
	# Carrega o tamanho logico da janela (independente de DPI)
	var interface_cfg: Dictionary = GV.configuracao_base.get("interface", {})
	var janela_dict: Dictionary = interface_cfg.get("tamanho_janela", {})
	GV.tamanho_janela_base = Vector2i(
		janela_dict.get("largura", 1366),
		janela_dict.get("altura", 768)
	)
	# Calcula tamanho fisico proporcional a escala e limita a 90% da tela se necessario
	var largura_fisica := int(GV.tamanho_janela_base.x * fator)
	var altura_fisica := int(GV.tamanho_janela_base.y * fator)
	var tamanho_tela := DisplayServer.screen_get_size(tela)
	var limite_x := int(tamanho_tela.x * 0.9)
	var limite_y := int(tamanho_tela.y * 0.9)
	if largura_fisica > limite_x or altura_fisica > limite_y:
		largura_fisica = mini(largura_fisica, limite_x)
		altura_fisica = mini(altura_fisica, limite_y)
	_ajustando_janela = true
	get_window().size = Vector2i(largura_fisica, altura_fisica)
	_ajustando_janela = false
	# Centraliza a janela na area utilizavel da tela (exclui a barra de tarefas). Sem isto,
	# alterar o size ancora o canto superior-esquerdo e o crescimento por escala/DPI empurra
	# a janela para fora da tela (canto inferior direito).
	var area := DisplayServer.screen_get_usable_rect(tela)
	get_window().position = area.position + (area.size - get_window().size) / 2
	# Define a base logica como o tamanho fisico dividido pelo fator. A razao de stretch resultante
	# (fisico / base = fator) escala a interface e dispara o oversampling das fontes. Como a base
	# preserva o aspecto da janela, a escala fica uniforme e nao surgem barras pretas.
	get_window().content_scale_size = Vector2i(
		roundi(get_window().size.x / fator),
		roundi(get_window().size.y / fator)
	)
	# Forca o oversampling das fontes no fator de escala: garante que os glifos sejam
	# re-rasterizados no tamanho final (em vez de esticar o bitmap), mantendo o texto nitido
	# mesmo em escalas fracionarias.
	get_window().oversampling_override = fator
	# Aplica o tema salvo na configuração (o tamanho de fonte global é reaplicado pelo tema).
	_aplicar_tema(interface_cfg.get("tema", "nord"))

## Pede confirmação antes de restaurar todas as configurações aos padrões do [code]base_config.json[/code].
func _on_restaurar_padroes() -> void:
	Dialogos.confirmar(self, "Restaurar padrões",
		"Isso descarta todas as suas configurações personalizadas e volta aos valores padrão. Continuar?",
		_restaurar_padroes_confirmado, "Restaurar", "Cancelar")

# Apaga os overrides, recarrega o base limpo e reaplica a interface ao vivo. Parametros de modulos
# (oferta, limites, posicionamento, PPC) refletem ao reabrir o modulo, como os demais ajustes.
func _restaurar_padroes_confirmado() -> void:
	DirAccess.remove_absolute(GV.dir_principal + "config_usuario.json")
	GV.configuracao_base = file_handling.load_json(GV.dir_principal, "base_config.json")
	JsonValidator.validar_base_config(GV.configuracao_base)
	GV.config_usuario = {}
	_aplicar_interface_completa()
	_aplicar_fonte_grades()
	var janela_config := $BarraPrincipal/JanelaConfiguracoes
	janela_config.configurar(GV.configuracao_base, _descobrir_temas(),
		GV.configuracao_base.get("interface", {}).get("tema", "nord"))

func _aplicar_cor_fundo() -> void:
	var tema: Theme = get_window().theme
	if tema != null and tema.has_stylebox("panel", "PanelContainer"):
		var estilo: StyleBox = tema.get_stylebox("panel", "PanelContainer")
		if estilo is StyleBoxFlat:
			RenderingServer.set_default_clear_color(estilo.bg_color)

## Lista os temas disponíveis em [code]res://scenes/Themes/[/code], retornando os nomes internos
## (nome do arquivo sem extensão) em ordem alfabética.
func _descobrir_temas() -> Array[String]:
	var nomes: Array[String] = []
	var dir := DirAccess.open("res://scenes/Themes/")
	if dir == null:
		print_debug("CRITICO: Diretorio de temas nao encontrado!")
		return nomes
	dir.list_dir_begin()
	var arquivo := dir.get_next()
	while arquivo != "":
		if not dir.current_is_dir():
			if arquivo.ends_with(".tres") or arquivo.ends_with(".tres.remap"):
				var nome := arquivo.trim_suffix(".remap").trim_suffix(".tres")
				if not nome in nomes:
					nomes.append(nome)
		arquivo = dir.get_next()
	dir.list_dir_end()
	nomes.sort()
	return nomes

## Aplica um tema visual à janela e à paleta semântica. A persistência da escolha é feita
## separadamente em [method _on_config_parametro_alterado] via override.
func _aplicar_tema(nome: String) -> void:
	var recurso_tema: Theme = load("res://scenes/Themes/" + nome + ".tres")
	# Aplica o tamanho de fonte salvo ao tema. Como cada troca de tema carrega um recurso novo,
	# reaplicar aqui garante que a escolha de fonte do usuário persista ao alternar temas.
	recurso_tema.default_font_size = GV.configuracao_base.get("interface", {}).get("tamanho_fonte", 16) as int
	# Informa o tema à paleta antes de aplicá-lo, para que a repintura já use o fundo correto.
	PaletaSemantica.atualizar_tema(recurso_tema, nome)
	get_window().theme = recurso_tema
	_aplicar_cor_fundo()

## Resolve o tamanho da fonte das grades (fonte global + offset, limitado ao piso/teto de
## legibilidade) e o aplica ao tema compartilhado das grades via [PaletaSemantica].
func _aplicar_fonte_grades() -> void:
	var interface_cfg: Dictionary = GV.configuracao_base.get("interface", {})
	var global := int(interface_cfg.get("tamanho_fonte", 16))
	var offset := int(interface_cfg.get("tamanho_fonte_grade_offset", 0))
	var minimo := int(interface_cfg.get("tamanho_fonte_grade_min", 8))
	var maximo := int(interface_cfg.get("tamanho_fonte_grade_max", 32))
	PaletaSemantica.atualizar_fonte_grades(clampi(global + offset, minimo, maximo))

func _on_janela_redimensionada() -> void:
	if _ajustando_janela:
		return
	var tamanho_fisico := get_window().size
	# Fator de escala efetivo (DPI x multiplicador manual) usado como razao de stretch.
	var fator := GV.escala_dpi * (GV.configuracao_base.get("interface", {}).get("escala", 1.0) as float)
	# Recalcula a base logica (fisico / fator) para manter a razao de stretch igual ao fator,
	# preservando o zoom e o oversampling das fontes apos o redimensionamento.
	var tamanho_logico := Vector2i(
		roundi(tamanho_fisico.x / fator),
		roundi(tamanho_fisico.y / fator)
	)
	get_window().content_scale_size = tamanho_logico
	_gravar_override(["interface","tamanho_janela","largura"], int(tamanho_logico.x))
	_gravar_override(["interface","tamanho_janela","altura"], int(tamanho_logico.y))

# Agenda a gravacao de config_usuario.json apos um curto intervalo sem novos eventos, evitando
# gravar em disco a cada frame durante o arraste da janela ou do controle de escala.
func _agendar_salvar_config() -> void:
	_timer_salvar_config.start()

# Grava config_usuario.json em disco. Disparado pelo timeout do timer de debounce.
func _salvar_config() -> void:
	file_handling.save_json(GV.dir_principal, "config_usuario.json", GV.config_usuario)

func _gravar_override(caminho: Array, valor: Variant) -> void:
	GeneralFunctions.definir_por_caminho(GV.configuracao_base, caminho, valor)
	GeneralFunctions.definir_por_caminho(GV.config_usuario, caminho, valor)
	_agendar_salvar_config()

func _carregar_arquivos() -> void:
	# Carregar grades
	var dir = DirAccess.open(GV.dir_principal + "arquivos/grades/")
	if dir == null:
		print_debug("CRITICO: Diretorio arquivos/grades/ nao encontrado!")
	else:
		var files: PackedStringArray = dir.get_files()
		for a in files.size():
			var nome: String = files[a].trim_suffix(".json")
			var dados: Dictionary = file_handling.load_json(GV.dir_principal + "arquivos/grades/", files[a])
			JsonValidator.validar_grade(dados)
			GV.grades[nome] = dados
	# Carregar equivalencias
	dir = DirAccess.open(GV.dir_principal + "arquivos/equivalencias/")
	if dir == null:
		print_debug("CRITICO: Diretorio arquivos/equivalencias/ nao encontrado!")
	else:
		var files: PackedStringArray = dir.get_files()
		for a in files.size():
			var nome: String = files[a].trim_suffix(".json")
			var dados: Dictionary = file_handling.load_json(GV.dir_principal + "arquivos/equivalencias/", files[a])
			JsonValidator.validar_equivalencia(dados)
			GV.equivalencias[nome] = dados
	# Carregar cargas exigidas
	dir = DirAccess.open(GV.dir_principal + "arquivos/cargaexigida/")
	if dir == null:
		print_debug("CRITICO: Diretorio arquivos/cargaexigida/ nao encontrado!")
	else:
		var files: PackedStringArray = dir.get_files()
		for a in files.size():
			var nome: String = files[a].trim_suffix(".json")
			var dados: Dictionary = file_handling.load_json(GV.dir_principal + "arquivos/cargaexigida/", files[a])
			JsonValidator.validar_carga_exigida(dados)
			GV.ch_exigida[nome] = dados

func _limpar_modulo() -> void:
	for child in $Modulo.get_children():
		child.queue_free()

## Verifica se todos os arquivos e diretórios necessários para o módulo existem no diretório de dados. [br]
## Retorna um [Dictionary] com [code]ok[/code] ([bool]) e [code]mensagem[/code] ([String]).
func _verificar_arquivos(modulo_nome: String) -> Dictionary:
	var resultado := { "ok": true, "mensagem": "" }
	var dados_modulo: Dictionary = GV.configuracao_base["modulos"].get(modulo_nome, {})
	var arquivos: Array = dados_modulo.get("arquivos", [])
	var diretorios: Array = dados_modulo.get("diretorios", [])

	var faltando: Array[String] = []
	for arquivo in arquivos:
		if not FileAccess.file_exists(GV.dir_saida + arquivo):
			faltando.append(arquivo)
	for diretorio in diretorios:
		if not DirAccess.dir_exists_absolute(GV.dir_saida + diretorio):
			faltando.append(diretorio + "/")

	if faltando.size() > 0:
		var nome_modulo: String = dados_modulo.get("nome", modulo_nome)
		resultado["ok"] = false
		resultado["mensagem"] = "Módulo '" + nome_modulo + "' não pode ser aberto. Faltam: " + ", ".join(faltando)

	return resultado

func _on_barra_principal_modulo_selecionado(modulo_selecionado) -> void:
	if _redirecionando:
		_redirecionando = false
		return

	_limpar_modulo()

	var mensagem_erro := ""
	if modulo_selecionado != "principal":
		var verificacao := _verificar_arquivos(modulo_selecionado)
		if not verificacao["ok"]:
			mensagem_erro = verificacao["mensagem"]
			print_debug(mensagem_erro)
			modulo_selecionado = "principal"
			_redirecionando = true
			$BarraPrincipal/HBoxContainer/SeletorModulos.selecionar_item(0)

	match modulo_selecionado:
		"principal":
			var modulo = load("res://scenes/TelaPrincipal/TelaPrincipal.tscn").instantiate()
			modulo.modulos = GV.configuracao_base["modulos"]
			$Modulo.add_child(modulo)
			if mensagem_erro != "":
				modulo._alterar_texto(mensagem_erro)
		"calculador_cr":
			var modulo = load("res://scenes/Modulos/CalculadorCR/CalculadorCR.tscn").instantiate()
			modulo.posicoes_histcsv = GV.configuracao_base["histfile"]
			modulo.grupos_complementares = GV.configuracao_base["grupos_complementares"]
			modulo.cores_terminal = PaletaSemantica.tokens_terminal()
			modulo.config_interface = GV.configuracao_base["interface"]
			$Modulo.add_child(modulo)
		"situacao_alunos":
			var modulo = load("res://scenes/Modulos/SituacaoAlunos/SituacaoAlunos.tscn").instantiate()
			modulo.condicoes.assign(GV.configuracao_base["condicoes"])
			modulo.equivalencias = GV.equivalencias
			modulo.grades_disciplinas_curriculos = GV.grades
			modulo.cargas_exigidas = GV.ch_exigida
			modulo.lista_cores = PaletaSemantica.tokens_lista()
			modulo.posicoes_histcsv = GV.configuracao_base["histfile"]
			modulo.posicoes_horarios_txt = GV.configuracao_base["horarios_txt"]
			modulo.cores_terminal = PaletaSemantica.tokens_terminal()
			modulo.efeitos = GV.configuracao_base["efeitos"]
			modulo.diretorio_exportacao = GV.dir_exportacoes
			modulo.config_interface = GV.configuracao_base["interface"]
			modulo.formatos_grade = GV.configuracao_base.get("formatos_grade", {})
			$Modulo.add_child(modulo)
		"situacao_disciplinas":
			var modulo = load("res://scenes/Modulos/SituacaoDisciplinas/SituacaoDisciplinas.tscn").instantiate()
			modulo.condicoes.assign(GV.configuracao_base["condicoes"])
			modulo.equivalencias = GV.equivalencias
			modulo.grades_disciplinas_curriculos = GV.grades
			modulo.lista_cores = PaletaSemantica.tokens_lista()
			modulo.posicoes_histcsv = GV.configuracao_base["histfile"]
			modulo.posicoes_horarios_txt = GV.configuracao_base["horarios_txt"]
			modulo.cores_terminal = PaletaSemantica.tokens_terminal()
			modulo.efeitos = GV.configuracao_base["efeitos"]
			modulo.config_interface = GV.configuracao_base["interface"]
			modulo.formatos_grade = GV.configuracao_base.get("formatos_grade", {})
			$Modulo.add_child(modulo)
		"trancamento":
			var modulo = load("res://scenes/Modulos/Trancamentos/Trancamentos.tscn").instantiate()
			modulo.limites = GV.configuracao_base["modulos"]["trancamento"].get("limites", {})
			modulo.posicoes_histcsv = GV.configuracao_base["histfile"]
			modulo.cores_terminal = PaletaSemantica.tokens_terminal()
			modulo.efeitos = GV.configuracao_base["efeitos"]
			$Modulo.add_child(modulo)
		"matricula_irregular":
			var modulo = load("res://scenes/Modulos/MatriculaIrregular/MatriculaIrregular.tscn").instantiate()
			modulo.posicoes_histcsv = GV.configuracao_base["histfile"]
			modulo.condicoes.assign(GV.configuracao_base["condicoes"])
			modulo.grades_disciplinas_curriculos = GV.grades
			modulo.equivalencias = GV.equivalencias
			modulo.cores_terminal = PaletaSemantica.tokens_terminal()
			modulo.efeitos = GV.configuracao_base["efeitos"]
			$Modulo.add_child(modulo)
		"avaliacao_limesurvey":
			var modulo = load("res://scenes/Modulos/LimeSurvey/LimeSurvey.tscn").instantiate()
			modulo.posicoes_histcsv = GV.configuracao_base["histfile"]
			modulo.posicoes_mailfile = GV.configuracao_base["mailfile"]
			modulo.diretorio_surveys = GV.dir_saida + GV.configuracao_base["modulos"]["avaliacao_limesurvey"].get("diretorios", ["surveys"])[0] + "/"
			modulo.config_interface = GV.configuracao_base["interface"]
			$Modulo.add_child(modulo)
		"planejamento_horario":
			var modulo = load("res://scenes/Modulos/PlanejamentoHorario/PlanejamentoHorario.tscn").instantiate()
			modulo.grades_disciplinas_curriculos = GV.grades
			# O diretorio de preferencias nao e mais requisito de abertura (diretorios pode estar
			# vazio em base_config.json), entao caímos no nome padrao quando a lista nao o informa.
			var dirs_ph: Array = GV.configuracao_base["modulos"]["planejamento_horario"].get("diretorios", [])
			var nome_dir_regras: String = str(dirs_ph[0]) if not dirs_ph.is_empty() else "preferenciashorarios"
			modulo.diretorio_regras = GV.dir_saida + nome_dir_regras
			modulo.posicoes_horarios_txt = GV.configuracao_base["horarios_txt"]
			modulo.posicoes_histcsv = GV.configuracao_base["histfile"]
			modulo.condicoes.assign(GV.configuracao_base["condicoes"])
			modulo.equivalencias = GV.equivalencias
			modulo.delimitadores = GV.configuracao_base["delimitadores"]
			modulo.posicoes_planejamento = GV.configuracao_base.get("planejamento", {})
			modulo.cores_terminal = PaletaSemantica.tokens_terminal()
			modulo.cursos = GV.configuracao_base.get("cursos", {})
			modulo.diretorio_exportacao = GV.dir_exportacoes
			modulo.config_interface = GV.configuracao_base["interface"]
			modulo.formatos_grade = GV.configuracao_base.get("formatos_grade", {})
			modulo.config_posicionamento = GV.configuracao_base.get("posicionamento_auto", {})
			$Modulo.add_child(modulo)
		"exportadores":
			var modulo = load("res://scenes/Modulos/Exportadores/Exportadores.tscn").instantiate()
			modulo.grades_disciplinas_curriculos = GV.grades
			modulo.diretorio_exportacao = GV.dir_exportacoes
			modulo.posicoes_histcsv = GV.configuracao_base["histfile"]
			modulo.posicoes_horarios_txt = GV.configuracao_base["horarios_txt"]
			modulo.condicoes = GV.configuracao_base["condicoes"]
			modulo.lista_cores = PaletaSemantica.tokens_lista()
			modulo.equivalencias = GV.equivalencias
			modulo.cores_terminal = PaletaSemantica.tokens_terminal()
			modulo.efeitos = GV.configuracao_base["efeitos"]
			modulo.config_interface = GV.configuracao_base["interface"]
			$Modulo.add_child(modulo)
		"planejamento_oferta":
			var modulo = load("res://scenes/Modulos/PlanejamentoOferta/PlanejamentoOferta.tscn").instantiate()
			modulo.grades_disciplinas_curriculos = GV.grades
			modulo.equivalencias = GV.equivalencias
			modulo.condicoes.assign(GV.configuracao_base["condicoes"])
			modulo.posicoes_histcsv = GV.configuracao_base["histfile"]
			modulo.delimitadores = GV.configuracao_base["delimitadores"]
			modulo.posicoes_planejamento = GV.configuracao_base.get("planejamento", {})
			modulo.cursos = GV.configuracao_base.get("cursos", {})
			modulo.cores_terminal = PaletaSemantica.tokens_terminal()
			modulo.config_oferta = GV.configuracao_base["planejamento_oferta"]
			modulo.config_interface = GV.configuracao_base["interface"]
			modulo.diretorio_exportacao = GV.dir_exportacoes
			# Leitura concentrada no main: os JSONs de oferta sao injetados (os guards de
			# existencia reproduzem o comportamento antigo, que checava o arquivo antes de ler).
			var dir_oferta: String = GV.dir_principal + "arquivos/oferta/"
			var dir_arquivos: String = GV.dir_principal + "arquivos/"
			modulo.historico_professores = file_handling.load_json(dir_oferta, "historico_professores.json") \
				if FileAccess.file_exists(dir_oferta + "historico_professores.json") else {}
			modulo.lista_professores = file_handling.load_json(dir_arquivos, "lista_professores.json") \
				if FileAccess.file_exists(dir_arquivos + "lista_professores.json") else {}
			$Modulo.add_child(modulo)

func _on_config_parametro_alterado(caminho: Array, valor: Variant) -> void:
	_gravar_override(caminho, valor)
	if caminho.size() >= 2 and caminho[0] == "interface":
		match caminho[1]:
			"escala":
				var fator := GV.escala_dpi * (valor as float)
				get_window().content_scale_size = Vector2i(
					roundi(get_window().size.x / fator),
					roundi(get_window().size.y / fator))
				get_window().oversampling_override = fator
			"tamanho_fonte":
				var tema: Theme = get_window().theme
				if tema != null:
					tema.default_font_size = int(valor)
				_aplicar_fonte_grades()
			"tamanho_fonte_grade_offset":
				_aplicar_fonte_grades()
			"tema":
				_aplicar_tema(str(valor))

func _on_barra_principal_mensagem_texto(value) -> void:
	for child in $Modulo.get_children():
		if child.has_method("_alterar_texto"):
			child._alterar_texto(value)
