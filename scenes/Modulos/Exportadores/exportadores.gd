extends ReferenceRect
## Relacionado a exportação de arquivos úteis, como lista de disciplinas e prerequisitos, ementas,
## choques de horário, ou o que for necessário. [br]
##
## Os principais empregos são: [br]
## - Exportar lista de pré-requisitos das disciplinas para compartilhamento com os discentes; [br]
## - Gerar PDF formatado da ementa de disciplinas a partir de arquivo .txt estruturado; [br]
## - Exportar relatório de choques de horário entre disciplinas em Markdown; [br]
## - Permitir futuramente a exportação de outros arquivos conforme desejado.

# Classes instanciadas.
var file_handling := FileHandling.new()
var general_functions := GeneralFunctions.new()
var analise_historico := AnaliseHistorico.new()
var analise_horarios := AnaliseHorarios.new()
var horarios_exe := HorariosExe.new()
var ementa_parser := EmentaParser.new()
var analise_grades := AnaliseGrades.new()

## Recebido pelo main em sua criação e vem da pasta de grades. [br]
## Formato de [param grades_disciplinas_curriculos] deve conter múltiplas grades, com chave no padrão
## [code]<cod_curso>_<versao>[/code]. Exemplo: [br]
## { [br]
## "alec_2010": Dicionário copia de [code]/arquivos/grades/alec_2010.json[/code], [br]
## "alec_2023": Dicionário copia de [code]/arquivos/grades/alec_2023.json[/code] [br]
## }
var grades_disciplinas_curriculos: Dictionary

## Recebido pelo main em sua criação e vem do arquivo base_config.json.
var diretorio_exportacao: String = ""

## Recebido pelo main em sua criação e vem do arquivo [code]base_config.json[/code].
var posicoes_histcsv: Dictionary

## Recebido pelo main em sua criação e vem do arquivo [code]base_config.json[/code].
var posicoes_horarios_txt: Dictionary

## Recebido pelo main em sua criação e vem do arquivo [code]base_config.json[/code].
var condicoes: Array = []

## Recebido pelo main em sua criação e vem do arquivo [code]base_config.json[/code].
var lista_cores: Dictionary = {}

## Recebido pelo main em sua criação e vem da pasta de equivalencias.
var equivalencias: Dictionary = {}

## Recebido pelo main, contem as cores padrao do terminal.
var cores_terminal: Dictionary = {}

## Recebido pelo main, contem os efeitos de texto do terminal.
var efeitos: Dictionary = {}

## Configuracoes globais de interface, de [code]base_config.json[/code].
var config_interface: Dictionary = {}

# Contem os dados do historico, de todos os alunos.
var _historico: Dictionary

# Contem os dados do arquivo horarios.ini.
var _horarios_ini: Dictionary

# Contem os dados do arquivo horarios.txt.
var _horarios_txt: Array

# É uma array contendo em cada elemento a combinacao do nome do aluno e sua matricula.
var _lista_alunos: Array[Array] = []

# Contem as condicoes de todas as matriculas (resultado de condicoes_discentes).
var _condicoes_discentes: Dictionary = {}

# Condicoes selecionadas pelo usuario para analise de choques.
var _condicoes_choque_selecionadas: Array[String] = []

# Tipo de exportação selecionado (retorno do SeletorTipoExportacao).
var _tipo_exportacao: String = ""

# Versão da grade selecionada (retorno do SeletorVersaoGrade).
var _versao_grade: String = ""

# Retorno do SeletorAluno: "_todos" ou matrícula do aluno.
var _aluno_retorno: String = "_todos"

# Retorno do SeletorListaGrades: "_todas" ou chave de grade especifica.
var _grade_validacao: String = "_todas"


func _ready() -> void:
	file_handling.check_create_dir(diretorio_exportacao)

	# Popula as opcoes de tipo de exportacao
	$"%SeletorTipoExportacao".lista_itens = {
		"_tipo*": ["Lista de pré-requisitos", "Ementa de disciplina", "Choques de horário", "Validar cadastro com relatório GURI 5104", "Lista para planos de ensino"],
		"_tipo_retorno": ["lista", "ementa", "choques", "validacao", "planos"]
	}
	DicasPrograma.vincular_itens($"%SeletorTipoExportacao", ["lista", "ementa", "choques", "validacao", "planos"], ["exportadores_tipo"])
	$"%SeletorTipoExportacao".atualizar_texto_padrao = true
	$"%SeletorTipoExportacao".selecionar_item(0)
	_tipo_exportacao = "lista"
	
	# Popula as versoes de grade dinamicamente
	var versoes := grades_disciplinas_curriculos.keys()
	versoes.sort()
	$"%SeletorVersaoGrade".lista_itens = {
		"_versoes*": versoes
	}
	$"%SeletorVersaoGrade".atualizar_texto_padrao = true
	if versoes.size() > 0:
		var indice: int = 0
		var ppc: String = GV.configuracao_base.get("ppc_principal", "")
		if not ppc.is_empty():
			for i in versoes.size():
				if versoes[i] == ppc:
					indice = i
					break
		$"%SeletorVersaoGrade".selecionar_item(indice)
		_versao_grade = versoes[indice]
	
	# Popula o seletor de grades para validacao 5104
	var grades_validas: Array[String] = []
	for key in grades_disciplinas_curriculos.keys():
		if not str(key).ends_with("_0000"):
			grades_validas.append(str(key))
	grades_validas.sort()
	var grades_exibicao: Array[String] = ["Todas"]
	var grades_retorno: Array[String] = ["_todas"]
	for g in grades_validas:
		grades_exibicao.append(g)
		grades_retorno.append(g)
	$"%SeletorListaGrades".lista_itens = {
		"_grades*": grades_exibicao,
		"_grades_retorno": grades_retorno
	}
	$"%SeletorListaGrades".atualizar_texto_padrao = true
	$"%SeletorListaGrades".selecionar_item(0)
	
	# Popula o seletor de condicoes para choques de horario
	_popular_seletor_condicoes()
	
	# Carrega dados para analise de choques
	_carregar_dados_choques()
	
	# Estado inicial: lista de pré-requisitos visivel
	_atualizar_interface_exportacao("lista")
	
	$"%Validar5104FileDialog".current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
	$"%Terminal".text_edit("Módulo de exportação pronto. Selecione uma opção.", "white", true, true)

	var largura_seletor: int = int(config_interface.get("largura_padrao_seletor", 180))
	for seletor in [$"%SeletorTipoExportacao", $"%SeletorVersaoGrade", $"%SeletorListaGrades", $"%SeletorCondicoesChoque", $"%SeletorAluno"]:
		seletor.custom_minimum_size = Vector2(largura_seletor, 30)
	# Realce inicial do botao OnOff conforme a visibilidade do terminal.
	TogglePaineis.sincronizar_botoes(_mapa_toggles())

# Popula o SeletorCondicoesChoque com as condicoes do base_config.json.
func _popular_seletor_condicoes() -> void:
	var lista_itens: Dictionary = {}
	lista_itens["_condicoes_"] = []
	lista_itens["_condicoes_retorno"] = []
	for condicao in condicoes:
		var nome_exibicao: String = condicao.replacen("_", " ").capitalize()
		lista_itens["_condicoes_"].append(nome_exibicao)
		lista_itens["_condicoes_retorno"].append(condicao)
	$"%SeletorCondicoesChoque".lista_itens = lista_itens
	DicasPrograma.vincular_itens($"%SeletorCondicoesChoque", condicoes, ["condicoes_matricula"])
	# Marca matriculavel e matriculado_agora como padrao
	$"%SeletorCondicoesChoque".selecionar_item(4)  # matriculavel (indice 4 na lista original)
	$"%SeletorCondicoesChoque".selecionar_item(0)  # matriculado_agora (indice 0 na lista original)
	_condicoes_choque_selecionadas = ["matriculavel", "matriculado_agora"]


# Carrega historico e horarios, computa condicoes para todos os alunos.
func _carregar_dados_choques() -> void:
	# Consome o cache de dados discentes pre-computado pelo main (evita recalcular a cada troca de
	# modulo). Fallback: se o cache estiver vazio (ex.: cena aberta fora do fluxo), computa local.
	if not GV.dados_discentes.is_empty():
		_historico = GV.dados_discentes["historico"]
		_lista_alunos = GV.dados_discentes["lista_alunos"]
		_condicoes_discentes = GV.dados_discentes["condicoes_discentes"]
	else:
		_historico = file_handling.ler_dados(GV.dir_saida, "hist.csv", posicoes_histcsv, false, grades_disciplinas_curriculos)
		analise_historico.simplificar_historico(_historico, "situacao", ["aprovado", "dispensado", "matr"])
		_lista_alunos = analise_historico.criar_lista_alunos(_historico)
		_condicoes_discentes = analise_historico.condicoes_discentes(_lista_alunos, _historico, condicoes, \
			grades_disciplinas_curriculos, equivalencias)
	# Lê os horários (arquivos pequenos; mantidos locais ao módulo).
	_horarios_ini = horarios_exe.carregar_horarios_ini(GV.dir_saida, "horarios.ini")
	_horarios_txt = horarios_exe.carregar_horarios_txt(GV.dir_saida, "horarios.txt", posicoes_horarios_txt)
	
	# Popula SeletorAluno
	var alunos_itens: Array[String] = ["Todos os alunos"]
	var alunos_retorno: Array[String] = ["_todos"]
	for aluno in _lista_alunos:
		alunos_itens.append(aluno[1].capitalize())
		alunos_retorno.append(aluno[0])
	$"%SeletorAluno".lista_itens = {
		"_alunos*": alunos_itens,
		"_alunos_retorno": alunos_retorno
	}
	$"%SeletorAluno".atualizar_texto_padrao = true
	$"%SeletorAluno".selecionar_item(0)


func _atualizar_interface_exportacao(tipo: String) -> void:
	var is_lista := tipo == "lista"
	var is_ementa := tipo == "ementa"
	var is_choques := tipo == "choques"
	var is_validacao := tipo == "validacao"
	var is_planos := tipo == "planos"
	
	$"%SeletorVersaoGrade".visible = is_lista
	$"%ExportarButton".visible = is_lista or is_choques or is_planos
	$"%SelecionarEmentaButton".visible = is_ementa
	$"%LoteEmentasButton".visible = is_ementa
	$"%LabelGrade".visible = is_validacao
	$"%SeletorListaGrades".visible = is_validacao
	$"%Validar5104Button".visible = is_validacao
	$"%BaixarRelatorio5104Button".visible = is_validacao
	$"%SeletorCondicoesChoque".visible = is_choques
	$"%SeletorAluno".visible = is_choques


func _exportar_lista_disciplinas(versao_grade: String, nucleo: String = "") -> void:
	var tabela: Array[Array] = [["*Disciplina*","*Prerequisito*"]]
	for codigo in grades_disciplinas_curriculos[versao_grade].keys():
		if nucleo == "" or (nucleo == "cccg" and GV.grades[versao_grade][codigo].get("nucleo","") == "cccg"):
			var nome: String = GV.grades[versao_grade][codigo].get("nome","nome não encontrado")
			var a: int = 0
			var prerequisito: String = ""
			while GV.grades[versao_grade][codigo].has("prerequisito"+str(a)):
				var cod_prerequisito: String = GV.grades[versao_grade][codigo].get("prerequisito"+str(a),"")
				prerequisito += cod_prerequisito + ": " + GV.grades[versao_grade].get(cod_prerequisito, {}).get("nome", "nome não encontrado") + " \\ "
				a+=1
			tabela.append([codigo + ": " + nome, prerequisito])
	
	file_handling.typst_export(diretorio_exportacao, versao_grade + ".typ", tabela, "table", "Lista de pré-requisitos curriculares — Projeto Pedagógico " + versao_grade)
	
	# Exibe no Terminal
	if not file_handling.typst_disponivel():
		$"%Terminal".text_edit("ERRO: typst.exe não encontrado em externo/bin/. O arquivo .typ foi gerado mas o PDF não.", cores_terminal["erro"], true, true)
		return
	$"%Terminal".titulo("Lista de pré-requisitos — Versão " + versao_grade, true)
	for idx in tabela.size():
		var reqs: String = ""
		if tabela[idx].size() > 1 and tabela[idx][1] != "":
			reqs = tabela[idx][1].replace(" \\ ", " | ")
		if idx == 0:
			# Cabecalho de colunas da tabela.
			$"%Terminal".linha(tabela[idx][0] + ("  |  " + reqs if reqs != "" else ""), cores_terminal["alerta"])
		else:
			$"%Terminal".item(tabela[idx][0] + (" → " + reqs if reqs != "" else ""))
	$"%Terminal".espaco()
	$"%Terminal".linha("Lista de pré-requisitos exportada: " + versao_grade + ".pdf em exportacoes/", cores_terminal["sucesso"])


func _exportar_lista_planos() -> void:
	var caminho_json: String = diretorio_exportacao + "/planejamento.json"
	if not FileAccess.file_exists(caminho_json):
		$"%Terminal".text_edit("Arquivo planejamento.json não encontrado em " + caminho_json + \
			". Exporte o planejamento primeiro.", cores_terminal.get("erro", "red"), true, false)
		return
	var dados: Dictionary = file_handling.load_json(diretorio_exportacao + "/", "planejamento.json")
	if dados.is_empty() or not dados.has("disciplinas"):
		$"%Terminal".text_edit("planejamento.json vazio ou formato inválido.", \
			cores_terminal.get("erro", "red"), true, false)
		return
	var disc_ordenadas: Array = dados["disciplinas"].duplicate()
	disc_ordenadas.sort_custom(func(a, b): return a.get("semestre", "") < b.get("semestre", ""))
	var linhas: Array[String] = ["# Disciplinas na Oferta\n", "| Semestre | Código | Disciplina | Professor(es) |"]
	linhas.append("|---|---|---|---|")
	for disc in disc_ordenadas:
		var sem: String = disc.get("semestre", "")
		var cod: String = disc.get("codigo", "")
		var nome: String = analise_grades.info_grade(grades_disciplinas_curriculos, cod, "nome")
		if nome.begins_with("Codigo"):
			nome = cod
		var profs: Array[String] = []
		for p in disc.get("professores", []):
			var pn: String = p.get("nome", "")
			if not pn.is_empty():
				profs.append(pn)
		linhas.append("| %s | %s | %s | %s |" % [sem, cod.to_upper(), nome, "; ".join(profs)])
	var f := FileAccess.open(diretorio_exportacao + "/disciplinas_oferta.md", FileAccess.WRITE)
	if not f:
		$"%Terminal".text_edit("Erro ao criar arquivo: " + diretorio_exportacao + "/disciplinas_oferta.md", \
			cores_terminal.get("erro", "red"), true, false)
		return
	f.store_string("\n".join(linhas))
	f.close()
	$"%Terminal".text_edit("Exportado: " + diretorio_exportacao + "/disciplinas_oferta.md (" + \
		str(disc_ordenadas.size()) + " disciplinas).", cores_terminal.get("sucesso", "green"), true, false)


# Exporta uma ementa (.txt) individual para Typst/PDF.
func _exportar_ementa(diretorio: String, arquivo: String) -> void:
	_garantir_aux_typst_ementa()
	var ementa_txt: Array[String] = file_handling.read_txt_file(diretorio, arquivo)
	if ementa_txt.size() == 0:
		$"%Terminal".text_edit("Arquivo vazio ou não lido: " + arquivo, cores_terminal["erro"], true, true)
		return
	var dados: Dictionary = ementa_parser.parse(ementa_txt)
	if dados.get("cod_componente", "") == "" and dados.get("nome_componente", "") == "":
		$"%Terminal".text_edit("Arquivo sem código ou nome da disciplina: " + arquivo, cores_terminal["erro"], true, true)
		return
	var typ: Array[String] = _gerar_typ_ementa(dados)
	file_handling.typst_export(diretorio_exportacao, arquivo + ".typ", typ, "ementa")
	if file_handling.typst_disponivel():
		$"%Terminal".text_edit("Ementa exportada: " + dados["cod_componente"].to_upper() + " " + \
			dados["nome_componente"] + " → " + arquivo + ".pdf", cores_terminal["sucesso"])


# Garante que os arquivos auxiliares do Typst para ementa estejam no diretório de exportação.
func _garantir_aux_typst_ementa() -> void:
	var dir_aux: String = GV.dir_principal + "arquivos/typst/"
	for nome in ["ementa_fn.typ", "unipampa.svg"]:
		if FileAccess.file_exists(dir_aux + nome):
			file_handling.copy_file(dir_aux, nome, diretorio_exportacao)


func _on_selecionar_ementa_button_up() -> void:
	$"%EmentaFileDialog".show()


func _on_ementa_file_selected(path: String) -> void:
	_exportar_ementa(path.get_base_dir() + "/", path.get_file())


func _on_lote_ementas_button_up() -> void:
	$"%LoteEmentasFileDialog".show()


func _on_lote_ementas_dir_selected(path: String) -> void:
	_exportar_lote_ementas(path)


# Exporta todas as ementas (.txt) de um diretorio em lote.
func _exportar_lote_ementas(diretorio: String) -> void:
	if not diretorio.ends_with("/"):
		diretorio += "/"

	_garantir_aux_typst_ementa()

	var dir := DirAccess.open(diretorio)
	if dir == null:
		$"%Terminal".text_edit("ERRO: Não foi possível abrir o diretório: " + diretorio, cores_terminal["erro"], true, true)
		return
	
	dir.list_dir_begin()
	var arquivos: Array[String] = []
	var arquivo: String = dir.get_next()
	while arquivo != "":
		if not dir.current_is_dir() and arquivo.ends_with(".txt"):
			arquivos.append(arquivo)
		arquivo = dir.get_next()
	dir.list_dir_end()
	
	if arquivos.size() == 0:
		$"%Terminal".text_edit("Nenhum arquivo .txt encontrado em: " + diretorio, cores_terminal["aviso"], true, true)
		return
	
	$"%Terminal".titulo("Exportação de ementas em lote", true)
	$"%Terminal".linha("Processando " + str(arquivos.size()) + " ementa(s)...")
	
	var sucessos: int = 0
	var falhas: int = 0
	
	for nome_arquivo in arquivos:
		var ementa_txt: Array[String] = file_handling.read_txt_file(diretorio, nome_arquivo)
		if ementa_txt.size() == 0:
			$"%Terminal".item(nome_arquivo + ": arquivo vazio ou não lido.", 0, cores_terminal["erro"])
			falhas += 1
			continue
		
		var dados: Dictionary = ementa_parser.parse(ementa_txt)
		if dados.get("cod_componente", "") == "" and dados.get("nome_componente", "") == "":
			$"%Terminal".item(nome_arquivo + ": sem código ou nome da disciplina.", 0, cores_terminal["erro"])
			falhas += 1
			continue
		
		var typ: Array[String] = _gerar_typ_ementa(dados)
		file_handling.typst_export(diretorio_exportacao, nome_arquivo + ".typ", typ, "ementa")
		
		$"%Terminal".item(dados["cod_componente"].to_upper() + " " + dados["nome_componente"] + " → " + nome_arquivo + ".pdf", 0, cores_terminal["sucesso"])
		sucessos += 1

	$"%Terminal".espaco()
	if not file_handling.typst_disponivel():
		$"%Terminal".linha("AVISO: typst.exe não encontrado. Arquivos .typ gerados, mas PDFs não foram compilados.", cores_terminal["aviso"])
	$"%Terminal".separador()
	$"%Terminal".linha("Lote concluído: " + str(sucessos) + " sucesso(s), " + str(falhas) + " falha(s). PDFs em exportacoes/", cores_terminal["sucesso"])


# Gera o conteudo do arquivo .typ que invoca a funcao ementa() do template ementa_fn.typ.
func _gerar_typ_ementa(dados: Dictionary) -> Array[String]:
	var typ: Array[String] = []
	typ.append("#import \"ementa_fn.typ\": ementa")
	typ.append("")
	typ.append("#ementa(")

	for campo in EmentaParser.CAMPOS_VALOR_UNICO:
		typ.append("  " + campo + ": \"" + _escapar_typst(dados[campo]) + "\",")

	var obj_geral: String = dados.get("obj_esp_geral", "")
	if obj_geral == "":
		typ.append("  obj_esp_geral: none,")
	else:
		typ.append("  obj_esp_geral: \"" + _escapar_typst(obj_geral) + "\",")

	typ.append("  objetivos_especificos: (")
	for item in dados.get("objetivos_especificos", []):
		typ.append("    \"" + _escapar_typst(item) + "\",")
	typ.append("  ),")

	typ.append("  ref_basica: (")
	for ref in dados.get("ref_basica", []):
		typ.append("    \"" + _escapar_typst(ref) + "\",")
	typ.append("  ),")

	typ.append("  ref_complementar: (")
	for ref in dados.get("ref_complementar", []):
		typ.append("    \"" + _escapar_typst(ref) + "\",")
	typ.append("  ),")

	typ.append(")")
	return typ


# Escapa uma string para insercao segura em codigo Typst (aspas e barras invertidas).
func _escapar_typst(s: String) -> String:
	return s.replace("\\", "\\\\").replace("\"", "\\\"")


func _on_seletor_tipo_exportacao_opcao_selecionada(retorno: String, _lista_selecionada: Array) -> void:
	_tipo_exportacao = retorno
	_atualizar_interface_exportacao(retorno)


func _on_seletor_versao_grade_opcao_selecionada(retorno: String, _lista_selecionada: Array) -> void:
	_versao_grade = retorno


func _on_seletor_aluno_opcao_selecionada(retorno: String, _lista_selecionada: Array) -> void:
	_aluno_retorno = retorno


func _on_condicoes_choque_selecionada(_retorno: String, lista_selecionada: Array) -> void:
	_condicoes_choque_selecionadas = lista_selecionada


func _on_seletor_lista_grades_opcao_selecionada(retorno: String, _lista_selecionada: Array) -> void:
	_grade_validacao = retorno


# Dispatcher do botao Exportar: visivel para "lista", "choques" e "planos".
func _on_exportar_button_up() -> void:
	match _tipo_exportacao:
		"lista":
			$"%Terminal".text_edit("Exportando lista de pré-requisitos " + _versao_grade + "...", cores_terminal["padrao"])
			_exportar_lista_disciplinas(_versao_grade)
		"choques":
			_exportar_choques()
		"planos":
			_exportar_lista_planos()


func _on_baixar_relatorio_5104_button_up() -> void:
	OS.shell_open("https://guri.unipampa.edu.br/rpt/relatorios/gerar/5104/M")


func _on_validar_5104_button_up() -> void:
	$"%Validar5104FileDialog".show()


func _on_validar_5104_file_selected(path: String) -> void:
	var dir: String = path.get_base_dir() + "/"
	var arquivo: String = path.get_file()
	$"%Terminal".text_edit("Validando disciplinas contra relatório 5104...", cores_terminal["padrao"], true, true)
	var grades_para_validar: Dictionary
	if _grade_validacao == "_todas":
		grades_para_validar = grades_disciplinas_curriculos
	else:
		grades_para_validar = {}
		if grades_disciplinas_curriculos.has(_grade_validacao):
			grades_para_validar[_grade_validacao] = grades_disciplinas_curriculos[_grade_validacao]
	var resultado: Dictionary = analise_grades.validar_contra_cadastro(
		grades_para_validar, dir, arquivo)
	$"%Terminal".titulo("Validação contra cadastro 5104")
	$"%Terminal".espaco()

	var grade_sem_cadastro: Array = resultado.get("grade_sem_cadastro", [])
	if grade_sem_cadastro.size() > 0:
		var itens: Array[String] = []
		for item in grade_sem_cadastro:
			itens.append(item.get("codigo", "") + " " + item.get("nome", ""))
		_imprimir_secao_validacao("Disciplinas na grade sem cadastro:", itens, cores_terminal["erro"], "!")

	var inativas: Array = resultado.get("inativas_no_cadastro", [])
	if inativas.size() > 0:
		var itens: Array[String] = []
		for item in inativas:
			itens.append(item.get("codigo", "") + " " + item.get("nome", ""))
		_imprimir_secao_validacao("Disciplinas com situação inativa no cadastro:", itens, cores_terminal["erro"], "!")

	var ch_divergente: Array = resultado.get("ch_divergente", [])
	if ch_divergente.size() > 0:
		var itens: Array[String] = []
		for item in ch_divergente:
			itens.append(item.get("codigo", "") + " grade: " + str(item.get("ch_grade", "")) + \
				" cadastro: " + str(item.get("ch_cadastro", "")))
		_imprimir_secao_validacao("Disciplinas com carga horária divergente:", itens, cores_terminal["alerta"], "!")

	var nome_divergente: Array = resultado.get("nome_divergente", [])
	if nome_divergente.size() > 0:
		var itens: Array[String] = []
		for item in nome_divergente:
			itens.append(item.get("codigo", "") + " grade: \"" + str(item.get("nome_grade", "")) + \
				"\" cadastro: \"" + str(item.get("nome_cadastro", "")) + "\"")
		_imprimir_secao_validacao("Disciplinas com nome divergente:", itens, cores_terminal["alerta"], "!")

	var cadastro_sem_grade: Array = resultado.get("cadastro_sem_grade", [])
	if cadastro_sem_grade.size() > 0:
		var itens: Array[String] = []
		for item in cadastro_sem_grade:
			itens.append(item.get("codigo", "") + " " + item.get("nome", ""))
		_imprimir_secao_validacao("Disciplinas ativas no cadastro sem grade correspondente:", itens, cores_terminal["aviso"], "?")

	var total_divergencias: int = grade_sem_cadastro.size() + inativas.size() + ch_divergente.size() + nome_divergente.size()
	if total_divergencias > 0:
		$"%Terminal".text_edit("Validação concluída: " + str(total_divergencias) + " divergência(s).", \
			cores_terminal.get("aviso", "yellow"), true, false)
	else:
		$"%Terminal".text_edit("Validação concluída: todas as disciplinas conferem com o cadastro.", \
			cores_terminal.get("sucesso", "green"), true, false)


# Imprime no Terminal uma seção da validação 5104: cabeçalho de seção seguido dos itens,
# coloridos pela severidade ([param cor]: erro/alerta/aviso). [param _marcador] mantido por
# compatibilidade de chamada, mas a severidade agora é transmitida pela cor dos itens.
func _imprimir_secao_validacao(titulo: String, itens: Array[String], cor: String, _marcador: String = "") -> void:
	$"%Terminal".secao(titulo.trim_suffix(":"))
	for item in itens:
		$"%Terminal".item(item, 0, cor)
	$"%Terminal".espaco()


## Exporta relatorio de choques de horario em Markdown. [br]
## Para cada aluno selecionado, analisa os choques entre as condicoes escolhidas
## e gera um arquivo [code]choques.md[/code] em [member diretorio_exportacao].
func _exportar_choques() -> void:
	if _condicoes_choque_selecionadas.size() < 1:
		$"%Terminal".text_edit("Selecione ao menos uma condição para análise.", cores_terminal["erro"])
		return

	# Monta as regras: todos os pares das condicoes selecionadas (incluindo self)
	var regras: Array[Array] = []
	for i in _condicoes_choque_selecionadas.size():
		for j in range(i, _condicoes_choque_selecionadas.size()):
			regras.append([_condicoes_choque_selecionadas[i], _condicoes_choque_selecionadas[j]])

	# Determina quais alunos analisar
	var alunos_analisar: Array[Array] = []
	if _aluno_retorno == "_todos":
		alunos_analisar = _lista_alunos.duplicate()
	else:
		for aluno in _lista_alunos:
			if aluno[0] == _aluno_retorno:
				alunos_analisar.append(aluno)
				break

	$"%Terminal".text_edit("Analisando choques de horário para " + str(alunos_analisar.size()) + " aluno(s)...", cores_terminal["padrao"])

	# Gera o conteudo Markdown
	var md: Array[String] = _gerar_md_choques(alunos_analisar, regras)

	file_handling.save_text_file(diretorio_exportacao + "/", "choques.md", md)

	# Exibe no Terminal: o conteudo ja e markdown; cabecalhos (#/##) recebem o token de titulo.
	$"%Terminal".espaco()
	for linha in md:
		var cor: String = cores_terminal["padrao"]
		if linha.begins_with("#"):
			cor = cores_terminal["alerta"]
		$"%Terminal".linha(linha, cor)
	$"%Terminal".espaco()
	$"%Terminal".linha("Relatório de choques exportado: choques.md em exportacoes/", cores_terminal["sucesso"])


# Gera o conteudo Markdown do relatorio de choques, agrupado por par de disciplinas.
func _gerar_md_choques(alunos_analisar: Array, regras: Array[Array]) -> Array[String]:
	var md: Array[String] = []

	# Cabecalho
	md.append("# Choques de Horário")
	md.append("")

	# Lista as regras analisadas
	md.append("**Condições analisadas:** ")
	var nomes_regras: Array[String] = []
	for regra in regras:
		nomes_regras.append(_formatar_nome_condicao(regra[0]) + " × " + _formatar_nome_condicao(regra[1]))
	md.append(", ".join(nomes_regras))
	md.append("")
	md.append("**Disciplinas com sobreposição de horários e alunos afetados:**")
	md.append("")

	# Agrupa choques por par de disciplinas (disc_a-disc_b).
	# Formato: { "cod_a-cod_b": { "disc_a": ..., "disc_b": ..., "nome_a": ..., "nome_b": ..., "alunos": [...] } }
	var disc_pair_data: Dictionary = {}

	for aluno in alunos_analisar:
		var matricula: String = aluno[0]
		var nome_aluno: String = aluno[1]

		if not _condicoes_discentes.has(matricula) or not _historico.has(matricula):
			continue

		var disc_cursaveis: Dictionary = _condicoes_discentes[matricula]
		var historico_matricula: Dictionary = _historico[matricula]
		var matriculada_com_turma: Dictionary = analise_historico.matriculada_com_turma(disc_cursaveis, historico_matricula)
		var horarios_txt_condicao: Dictionary = analise_horarios.extrair_horarios_txt(_horarios_txt, matriculada_com_turma, disc_cursaveis)
		var choques: Dictionary = analise_horarios.detectar_choques(horarios_txt_condicao, regras)

		for chave_regra in choques.keys():
			for choque in choques[chave_regra]:
				var disc_a: String = choque["disc_a"]
				var disc_b: String = choque["disc_b"]
				var pair_key: String = disc_a + "-" + disc_b
				var nome_a: String = _obter_nome_disciplina(disc_a)
				var nome_b: String = _obter_nome_disciplina(disc_b)
				var cond_str: String = _formatar_condicao_par(chave_regra)

				if not disc_pair_data.has(pair_key):
					disc_pair_data[pair_key] = {
						"disc_a": disc_a,
						"disc_b": disc_b,
						"nome_a": nome_a,
						"nome_b": nome_b,
						"alunos": []
					}

				# Deduplica aluno + condicao para o mesmo par de disciplinas
				var ja_existe: bool = false
				for entry in disc_pair_data[pair_key]["alunos"]:
					if entry["nome"] == nome_aluno and entry["condicao"] == cond_str:
						ja_existe = true
						break

				if not ja_existe:
					disc_pair_data[pair_key]["alunos"].append({
						"nome": nome_aluno,
						"matricula": matricula,
						"condicao": cond_str
					})

	if disc_pair_data.keys().size() == 0:
		md.append("---")
		md.append("")
		md.append("## Nenhuma sobreposição encontrada.")
		return md

	# Ordena pares de disciplinas pelo código
	var sorted_keys: Array = disc_pair_data.keys()
	sorted_keys.sort()

	var total_sobreposicoes: int = sorted_keys.size()
	var alunos_unicos: Array[String] = []

	for pair_key in sorted_keys:
		var data: Dictionary = disc_pair_data[pair_key]

		md.append("---")
		md.append("")
		md.append("## " + data["disc_a"].to_upper() + " " + data["nome_a"] + " — " + data["disc_b"].to_upper() + " " + data["nome_b"])
		md.append("")

		# Ordena alunos por nome
		var alunos_ordenados: Array = data["alunos"].duplicate()
		alunos_ordenados.sort_custom(func(a, b): return a["nome"] < b["nome"])

		var idx: int = 1
		for entry in alunos_ordenados:
			md.append(str(idx) + ". " + entry["nome"].capitalize() + ": " + entry["condicao"])
			idx += 1
			if not alunos_unicos.has(entry["matricula"]):
				alunos_unicos.append(entry["matricula"])

		md.append("")

	md.append("---")
	md.append("")
	md.append("**Total: " + str(total_sobreposicoes) + " sobreposição(ões), " + str(alunos_unicos.size()) + " aluno(s) afetado(s)**")

	return md


# Formata um par de condicoes para exibicao (ex: "matriculavel x matriculado_agora" → "Matriculavel-Matriculado Agora").
func _formatar_condicao_par(cond_pair: String) -> String:
	var parts: Array = cond_pair.split(" x ")
	var formatted: Array[String] = []
	for part in parts:
		formatted.append(part.replacen("_", " ").capitalize())
	return "-".join(formatted)


# Obtem o nome de uma disciplina a partir do codigo.
func _obter_nome_disciplina(codigo: String) -> String:
	codigo = codigo.to_lower()
	for versao in grades_disciplinas_curriculos.keys():
		if grades_disciplinas_curriculos[versao].has(codigo):
			return grades_disciplinas_curriculos[versao][codigo].get("nome", "")
	return ""


# Formata o nome de uma condicao para exibicao (ex: "matriculado_agora" → "Matriculado Agora").
func _formatar_nome_condicao(condicao: String) -> String:
	return condicao.replacen("_", " ").capitalize()


# Mapa botao OnOff -> painel que ele controla. O botao fica "afundado" (toggle_mode) quando o painel
# esta visivel. Grupo de um unico painel: Shift+clique nao tem efeito pratico.
func _mapa_toggles() -> Dictionary:
	return {$"%OnOffTerminal": $"%Terminal"}

func _on_on_off_terminal_button_up() -> void:
	var mapa := _mapa_toggles()
	TogglePaineis.aplicar(mapa.values(), $"%Terminal", Input.is_key_pressed(KEY_SHIFT))
	TogglePaineis.sincronizar_botoes(mapa)
