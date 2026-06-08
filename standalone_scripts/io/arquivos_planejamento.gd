class_name ArquivosPlanejamento extends RefCounted
## Responsável pela leitura, parsing e conversão de arquivos de dados do planejamento. [br]
## Gerencia [param _horarios_ini], [param _horarios_txt_lista], [param _planejamento_csv] e [param _horariosexe_txt].

# Classes instanciadas.
var _file_handling: FileHandling
var _analise_horarios: AnaliseHorarios
var _analise_grades: AnaliseGrades
var _horarios_exe: HorariosExe

# Dados do arquivo ini, organizados em forma de um dicionário.
var _horarios_ini: Dictionary

# Dicionário de horarios_txt indexado por chave nomeada. [br]
# Chaves padrão: [code]"horarios"[/code] (do [code]horarios.txt[/code]), [br]
# [code]"planejamento"[/code] (do [code]planejamento.csv[/code] convertido). [br]
# Novas chaves podem ser adicionadas dinamicamente para suportar N arquivos.
var _horarios_txt_lista: Dictionary = {}

# Contém os dados do arquivo txt, organizados em forma de uma array de arrays.
var _horariosexe_txt: Array

# Contém o arquivo planejamento.csv resumido em código da disciplina e professor.
var _planejamento_csv: Dictionary

# Dependências injetadas.
var _grades_disciplinas_curriculos: Dictionary
var _delimitadores: Dictionary
var _diretorio_regras: String
var _posicoes_horarios_txt: Dictionary
var _posicoes_planejamento: Dictionary = {}

# Matriz de cores de preferências de horários dos professores.
var _cores_preferencias: Array[Color] = [
	Color(0   , 1   , 0, 255),
	Color(0.25, 0.75, 0, 255),
	Color(0.5 , 0.5 , 0, 255),
	Color(0.75, 0.25, 0, 255),
	Color(1   , 0   , 0.0, 255),
]

## Configura as dependências injetadas e caminhos de dados.
func configurar(file_handling: FileHandling, analise_horarios: AnaliseHorarios, analise_grades: AnaliseGrades, horarios_exe: HorariosExe, grades_disciplinas_curriculos: Dictionary, delimitadores: Dictionary, diretorio_regras: String, posicoes_horarios_txt: Dictionary, posicoes_planejamento: Dictionary = {}) -> void:
	_file_handling = file_handling
	_analise_horarios = analise_horarios
	_analise_grades = analise_grades
	_horarios_exe = horarios_exe
	_grades_disciplinas_curriculos = grades_disciplinas_curriculos
	_delimitadores = delimitadores
	_diretorio_regras = diretorio_regras
	_posicoes_horarios_txt = posicoes_horarios_txt
	_posicoes_planejamento = posicoes_planejamento

## Carrega o arquivo [code]horarios.ini[/code] e retorna o dicionário resultante.
func carregar_horarios_ini(dir_saida: String, arquivo: String) -> Dictionary:
	_horarios_ini = _horarios_exe.carregar_horarios_ini(dir_saida, arquivo)
	return _horarios_ini

## Lê as preferências de horários do professor a partir do CSV [param arquivo_selecionado]. [br]
## Retorna uma array com [matriz_horario, comentarios].
func ler_regras_professores(arquivo_selecionado: String) -> Array[Array]:
	var ler_linhas: Array[int] = [6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21]
	var arquivo: Array = _file_handling.read_csvfile(_diretorio_regras+"/", arquivo_selecionado, [], ler_linhas, _delimitadores["csv_entrada"])
	ler_linhas = [24,25,26,27,28]
	var comentarios: Array = _file_handling.read_csvfile(_diretorio_regras+"/", arquivo_selecionado, [1], ler_linhas)
	var dias: Array[String] = _analise_horarios.dias_da_semana(_horarios_ini)
	var horas: Array[String] = _analise_horarios.horas_das_aulas(_horarios_ini)
	for a in range(1, dias.size()+1):
		arquivo[0][a] = dias[a-1]
	for a in range(1, horas.size()+1):
		arquivo[a][0] = horas[a-1]
	var matriz_horario: Array[Array]
	for a in arquivo.size():
		var temp_line: Array[Dictionary] = []
		var cor_barra_superior: Color
		for b in arquivo[a].size():
			var dados_celula: Dictionary = {}
			if a == 0 or b == 0:
				dados_celula["texto_central"] = arquivo[a][b]
				dados_celula["apenas_central"] = true
			else:
				if int(arquivo[a][b]) >= 1 and int(arquivo[a][b]) <= 5:
					cor_barra_superior = _cores_preferencias[int(arquivo[a][b])-1]
				else:
					cor_barra_superior = Color(0.173, 0.173, 0.173, 255)
				dados_celula["cor_barra_cima"] = cor_barra_superior
				dados_celula["apenas_central"] = true
			temp_line.append(dados_celula)
		matriz_horario.append(temp_line)
	return [matriz_horario, comentarios]

## Lê apenas os comentários textuais (linhas 24–28, coluna 1) do CSV de preferências
## do professor [param arquivo_selecionado]. [br]
## Diferente dos demais métodos, [b]não[/b] usa [method FileHandling.read_csvfile] —
## lê o arquivo como bytes, detecta se está em Windows-1252 e, se necessário, converte
## via [code]ansi_to_utf8.exe[/code] ([method FileHandling.convertto_utf8]) para um
## arquivo temporário em [code]GV.dir_temp[/code]. [br]
## Retorna [Array[String]] com cada comentário não-vazio, ou array vazia se o arquivo
## não existir ou não houver comentários.
func ler_comentarios_professor(arquivo_selecionado: String) -> Array[String]:
	var caminho: String = _diretorio_regras + "/" + arquivo_selecionado
	var f := FileAccess.open(caminho, FileAccess.READ)
	if f == null:
		return []
	var raw: PackedByteArray = f.get_buffer(f.get_length())
	f.close()

	var texto_utf8: String
	if _verifica_se_windows1252(raw):
		var temp_nome: String = "_comentarios_" + arquivo_selecionado
		_file_handling.convertto_utf8(_diretorio_regras + "/", arquivo_selecionado, GV.dir_temp, temp_nome)
		var temp_path: String = GV.dir_temp + temp_nome
		texto_utf8 = FileAccess.get_file_as_string(temp_path)
		DirAccess.remove_absolute(temp_path)
	else:
		texto_utf8 = raw.get_string_from_utf8()

	var linhas: PackedStringArray = texto_utf8.split("\n")
	var resultado: Array[String] = []
	for i in range(23, mini(28, linhas.size())):
		var linha: String = linhas[i].strip_edges()
		if linha.is_empty():
			continue
		var comentario: String = _extrair_primeira_coluna_csv(linha)
		if not comentario.is_empty() and comentario.to_lower() != "condições adicionais":
			resultado.append(comentario)
	return resultado


# Detecta se [param raw] está em Windows-1252: decodifica como UTF-8 e verifica se
# há caracteres de substituição (U+FFFD), que indicam bytes inválidos em UTF-8.
func _verifica_se_windows1252(raw: PackedByteArray) -> bool:
	var texto: String = raw.get_string_from_utf8()
	return "\uFFFD" in texto


# Extrai a primeira coluna de uma linha CSV, respeitando aspas duplas.
# Ex.: [code]"Se colocar aula na sexta, não colocar na segunda",,,,[/code] →
# [code]Se colocar aula na sexta, não colocar na segunda[/code].
func _extrair_primeira_coluna_csv(linha: String) -> String:
	var entre_aspas: bool = false
	var resultado: String = ""
	for c in linha:
		if c == '"':
			entre_aspas = not entre_aspas
		elif c == ',' and not entre_aspas:
			break
		else:
			resultado += c
	return resultado.strip_edges()

## Lê as preferências numéricas de horário de um professor do CSV [param arquivo_selecionado]. [br]
## Mesmo arquivo lido por [method ler_regras_professores], mas devolvido em forma crua para o
## posicionamento automático: dicionário [code]{ "linha_coluna": int(1..5) }[/code], onde
## [code]1[/code] é o horário mais desejado e [code]5[/code] o menos desejado. Células vazias
## (= "não darei aula neste horário") são [b]omitidas[/b] e, portanto, tratadas como proibidas
## pelo chamador. [br]
## A linha/coluna seguem a convenção da grade ([code]linha = índice da hora + 1[/code],
## [code]coluna = índice do dia + 1[/code]), por alinhamento posicional com as linhas 6–21 do CSV.
func ler_preferencias_professor(arquivo_selecionado: String) -> Dictionary:
	var ler_linhas: Array[int] = [6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21]
	var arquivo: Array = _file_handling.read_csvfile(_diretorio_regras+"/", arquivo_selecionado, [], ler_linhas, _delimitadores["csv_entrada"])
	var preferencias: Dictionary = {}
	# arquivo[0] é a linha de cabeçalho (dias); arquivo[a>=1] são as horas, na mesma ordem da grade.
	for a in range(1, arquivo.size()):
		for b in range(1, arquivo[a].size()):
			var valor_str: String = str(arquivo[a][b]).strip_edges()
			if valor_str.is_valid_int():
				var valor: int = int(valor_str)
				if valor >= 1 and valor <= 5:
					preferencias["%d_%d" % [a, b]] = valor
	return preferencias

## Gera uma matriz vazia com cabeçalhos de dias e horas conforme [param _horarios_ini].
func gerar_matriz_vazia() -> Array[Array]:
	var dias: Array[String] = _analise_horarios.dias_da_semana(_horarios_ini)
	var horas: Array[String] = _analise_horarios.horas_das_aulas(_horarios_ini)
	var matriz: Array[Array] = []
	var linha0: Array[Dictionary] = []
	linha0.append({"texto_central": "", "apenas_central": true})
	for dia in dias:
		linha0.append({"texto_central": dia, "apenas_central": true})
	matriz.append(linha0)
	for hora in horas:
		var linha: Array[Dictionary] = []
		linha.append({"texto_central": hora, "apenas_central": true})
		for _dia in dias:
			linha.append({"apenas_central": true})
		matriz.append(linha)
	return matriz

## Imprime no terminal os dados de [param horarios_txt] formatado conforme arquivo [code]horarios.txt[/code].
## Conteudo bruto (tabular): envolvido em bloco de codigo markdown ([code]```[/code]) para que,
## ao copiar do terminal, saia como bloco verbatim.
func imprimir_horarios_txt(terminal: Node, horarios_txt: Array, cor_padrao: String) -> void:
	terminal.text_edit("", cor_padrao, false, true)
	terminal.text_edit("```", cor_padrao, false)
	for a in horarios_txt.size():
		var temp_line: String = ""
		for b in horarios_txt[a].size():
			temp_line = temp_line + horarios_txt[a][b] + ","
		terminal.text_edit(temp_line, cor_padrao, true)
	terminal.text_edit("```", cor_padrao, true)

## Converte o planejamento para o formato de [param _horarios_txt_lista].
func planejamento_para_horarios_txt(numero_linha: int = 0) -> Array:
	var linhas: int = 0
	var localhorarios_txt: Array[Dictionary] = []
	for key in _planejamento_csv.keys():
		for b in _planejamento_csv[key]["professor"].size():
			for c in int(_planejamento_csv[key]["ch"][b]):
				localhorarios_txt.append({})
				localhorarios_txt[linhas]["linha"] = str(numero_linha)
				localhorarios_txt[linhas]["professor"] = _horarios_exe.info_formatada({"professor":_planejamento_csv[key]["professor"][b]},"professor")
				localhorarios_txt[linhas]["sala"] = _horarios_exe.info_formatada({}, "sala")
				localhorarios_txt[linhas]["semestre"] = _horarios_exe.info_formatada({"semestre":_planejamento_csv[key]["semestre"]},"semestre")
				localhorarios_txt[linhas]["horario"] = _horarios_exe.info_formatada({}, "horario")
				localhorarios_txt[linhas]["dia"] = _horarios_exe.info_formatada({}, "dia")
			var nome: String = _analise_grades.info_grade(_grades_disciplinas_curriculos, _planejamento_csv[key]["codigo"], "nome", "", true)
			var disciplina: String = nome + " (" + _planejamento_csv[key]["codigo"] + ")"
			localhorarios_txt[linhas]["disciplina"] = _horarios_exe.info_formatada({"disciplina": disciplina}, "disciplina")
			localhorarios_txt[linhas]["tipo"] = _horarios_exe.info_formatada({}, "tipo")
			localhorarios_txt[linhas]["turma"] = _horarios_exe.info_formatada({}, "turma")
			localhorarios_txt[linhas]["vagas"] = _horarios_exe.info_formatada({}, "vagas")
			localhorarios_txt[linhas]["p"] = _horarios_exe.info_formatada({}, "p")
			localhorarios_txt[linhas]["s"] = _horarios_exe.info_formatada({}, "s")
			localhorarios_txt[linhas]["t"] = _horarios_exe.info_formatada({}, "t")
			linhas += 1
			numero_linha += 1
	return localhorarios_txt

## Converte o planejamento para o formato horarios_txt e armazena em [param _horarios_txt_lista]. [br]
## [param chave] padrao [code]"planejamento"[/code]. Pode ser chamado com chave diferente para
## suportar multiplas fontes de planejamento.
func adicionar_planejamento(chave: String = "planejamento") -> void:
	_horarios_txt_lista[chave] = planejamento_para_horarios_txt()

## Mescla N arrays de horarios_txt em uma unica array.
func mesclar_horarios(h_lista: Array[Array]) -> Array:
	var resultado: Array = []
	for h in h_lista:
		for entry in h:
			resultado.append(entry)
	return resultado

## Faz o parse do arquivo [code]horarios.txt[/code] e retorna uma array de dicionários.
func parse_horarios_txt(caminho: String) -> Array[Dictionary]:
	var f := FileAccess.open(caminho, FileAccess.READ)
	if f == null:
		return []
	var resultado: Array[Dictionary] = []
	var campos: Array[String] = ["linha", "professor", "sala", "semestre", "horario", "dia", "disciplina", "tipo", "turma", "vagas", "p", "s", "t"]
	while not f.eof_reached():
		var linha: String = f.get_line().strip_edges()
		if linha.is_empty():
			continue
		var valores: Array[String] = dividir_csv(linha)
		if valores.size() < 13:
			continue
		var entry: Dictionary = {}
		for i in campos.size():
			entry[campos[i]] = valores[i]
		resultado.append(entry)
	return resultado

## Divide uma linha CSV respeitando aspas duplas.
static func dividir_csv(linha: String) -> Array[String]:
	var result: Array[String] = []
	var atual: String = ""
	var entre_aspas: bool = false
	for c in linha:
		if c == '"':
			entre_aspas = not entre_aspas
		elif c == ',' and not entre_aspas:
			result.append(atual)
			atual = ""
		else:
			atual += c
	result.append(atual)
	return result

## Lê [code]horarios.txt[/code] e monta o plano de alocações a aplicar na grade. [br]
## [param dias] e [param horas] são os cabeçalhos da grade; [param linhas_grade] e [param colunas_grade] [br]
## seus limites; [param chaves_existentes] são as chaves de cards já presentes no painel. [br]
## Retorna [code]{ "valido": bool, "cards_novos": Array, "alocacoes": Array, "ignoradas": int }[/code]. [br]
## Cada item de [param cards_novos] tem [code]codigo, nome, profs, ch_total, sem, chave[/code]; [br]
## cada item de [param alocacoes] tem [code]linha, coluna, chave, aloc[/code].
func preparar_alocacoes_do_txt(caminho: String, dias: Array[String], horas: Array[String], linhas_grade: int, colunas_grade: int, chaves_existentes: Array, prefixos: Array[String] = []) -> Dictionary:
	var dados_txt: Array[Dictionary] = parse_horarios_txt(caminho)
	if not prefixos.is_empty():
		var filtrada: Array[Dictionary] = []
		for entry in dados_txt:
			var sem: String = str(entry.get("semestre", "")).to_lower()
			for p in prefixos:
				if sem.begins_with(str(p).to_lower()):
					filtrada.append(entry)
					break
		dados_txt = filtrada
	if dados_txt.size() <= 1:
		return {"valido": false, "cards_novos": [], "alocacoes": [], "ignoradas": 0}
	var dia_para_col: Dictionary = {}
	for i in dias.size():
		dia_para_col[dias[i].to_lower()] = i + 1
	var hora_para_lin: Dictionary = {}
	for i in horas.size():
		hora_para_lin[horas[i]] = i + 1
	var ch_por_chave: Dictionary = _contar_ch_por_chave(dados_txt)
	var conhecidas: Dictionary = {}
	for c in chaves_existentes:
		conhecidas[c] = true
	var cards_novos: Array[Dictionary] = []
	var alocacoes: Array[Dictionary] = []
	var ignoradas: int = 0
	for entry in dados_txt:
		var disc_str: String = entry.get("disciplina", "")
		if disc_str == " ":
			continue
		var codigo: String = _horarios_exe.extrair_cod_horarios_txt(disc_str).to_lower()
		if codigo.is_empty():
			continue
		var coluna: int = dia_para_col.get(entry.get("dia", "").to_lower(), -1)
		var linha: int = hora_para_lin.get(entry.get("horario", ""), -1)
		if linha < 0 or coluna < 0 or linha >= linhas_grade or coluna >= colunas_grade:
			ignoradas += 1
			continue
		var sem: String = entry.get("semestre", "")
		var chave: String = codigo + "_" + sem.to_lower()
		if not conhecidas.has(chave):
			conhecidas[chave] = true
			cards_novos.append(_montar_card_novo(entry, codigo, sem, chave, disc_str, ch_por_chave))
		alocacoes.append({
			"linha": linha,
			"coluna": coluna,
			"chave": chave,
			"aloc": {
				"chave": chave,
				"codigo": codigo,
				"professor": entry.get("professor", ""),
				"semestre": sem,
				"sala": entry.get("sala", ""),
				"tipo": entry.get("tipo", ""),
				"turma": entry.get("turma", ""),
				"vagas": entry.get("vagas", "Vagas"),
				"p": entry.get("p", "1"),
				"s": entry.get("s", "1"),
				"t": entry.get("t", "1"),
			},
		})
	return {"valido": true, "cards_novos": cards_novos, "alocacoes": alocacoes, "ignoradas": ignoradas}

# Conta quantas linhas (horas) cada disciplina+semestre ocupa no [param dados_txt].
func _contar_ch_por_chave(dados_txt: Array[Dictionary]) -> Dictionary:
	var ch_por_chave: Dictionary = {}
	for entry in dados_txt:
		var disc_str: String = entry.get("disciplina", "")
		if disc_str == " ":
			continue
		var codigo: String = _horarios_exe.extrair_cod_horarios_txt(disc_str).to_lower()
		if codigo.is_empty():
			continue
		var chave: String = codigo + "_" + entry.get("semestre", "").to_lower()
		ch_por_chave[chave] = ch_por_chave.get(chave, 0) + 1
	return ch_por_chave

# Monta os dados de um card extra a partir de uma entrada do txt, usando o planejamento.csv quando disponível.
func _montar_card_novo(entry: Dictionary, codigo: String, sem: String, chave: String, disc_str: String, ch_por_chave: Dictionary) -> Dictionary:
	var dados_csv: Dictionary = _planejamento_csv.get(chave, {})
	var nome: String
	var profs: Array[String] = []
	var ch_total: int
	if dados_csv.size() > 0:
		nome = _analise_grades.info_grade(_grades_disciplinas_curriculos, codigo, "nome", "", true)
		if nome.begins_with("Codigo"):
			nome = codigo
		profs.assign(dados_csv.get("professor", []))
		ch_total = 0
		for c in dados_csv.get("ch", []):
			ch_total += int(c)
		if ch_total == 0:
			ch_total = int(dados_csv.get("ch_disciplina", "0"))
		if ch_total == 0:
			ch_total = ch_por_chave.get(chave, 1)
	else:
		nome = disc_str
		var idx_al: int = nome.to_lower().find(codigo)
		if idx_al > 0:
			nome = nome.substr(0, idx_al).strip_edges()
		var prof_str: String = entry.get("professor", "")
		if not prof_str.is_empty() and prof_str != " ":
			profs.append(prof_str)
		ch_total = ch_por_chave.get(chave, 1)
	return {"codigo": codigo, "nome": nome, "profs": profs, "ch_total": ch_total, "sem": sem, "chave": chave}

## Monta o [member _planejamento_csv] a partir dos cards extraidos do horarios.txt ([param cards] no
## formato de [method _montar_card_novo]). Usado ao importar um horarios.txt SEM um planejamento.csv/
## .json carregado, para que salvar/enviar tenham as disciplinas. A CH por professor fica menos
## detalhada que a do planejamento.csv (sem quebra por docente; toda a CH vai em [code]ch_disciplina[/code]).
## Substitui o conteudo atual de _planejamento_csv.
func montar_planejamento_csv_do_txt(cards: Array) -> void:
	_planejamento_csv = {}
	adicionar_planejamento_csv_do_txt(cards)

## Adiciona ao [member _planejamento_csv] as disciplinas dos [param cards] do txt, SEM limpar o
## existente. Usado para incorporar a um planejamento ja carregado as disciplinas que estao no
## horarios.txt mas faltavam nele (escolhidas pelo usuario). Mesma ressalva de CH por professor de
## [method montar_planejamento_csv_do_txt] (sem quebra por docente; CH vai em ch_disciplina).
func adicionar_planejamento_csv_do_txt(cards: Array) -> void:
	for c in cards:
		var chave: String = str(c.get("chave", ""))
		if chave.is_empty():
			continue
		var profs: Array = c.get("profs", [])
		var sem: String = str(c.get("sem", ""))
		_planejamento_csv[chave] = {
			"codigo": str(c.get("codigo", "")),
			"semestre": sem,
			"professor": profs.duplicate(),
			"ch": [],
			"oferta": sem,
			"ch_disciplina": str(c.get("ch_total", 0)),
			"nome_csv": str(c.get("nome", "")),
		}

## Carrega um arquivo de horarios_txt e armazena em [param _horarios_txt_lista][chave]. [br]
## [param nome_arquivo] padrao [code]"horarios.txt"[/code], [param chave] padrao [code]"horarios"[/code]. [br]
## Pode ser chamado varias vezes com arquivos e chaves diferentes. [br]
## Retorna [code]true[/code] se bem-sucedido.
func carregar_horarios_txt(dir_saida: String, nome_arquivo: String = "horarios.txt", chave: String = "horarios") -> bool:
	_horarios_txt_lista[chave] = _horarios_exe.carregar_horarios_txt(dir_saida, nome_arquivo, _posicoes_horarios_txt)
	return _horarios_txt_lista[chave].size() > 0

## Carrega [code]planejamento.csv[/code] e preenche [param _planejamento_csv], filtrando pelas
## linhas cujo semestre começa com algum dos prefixos em [param prefixos_semestre] (ex.
## [code]["EC", "EA"][/code], extraídos de [code]base_config.json:cursos[/code]). Retorna
## [code]true[/code] se bem-sucedido.
func carregar_planejamento(dir_saida: String, prefixos_semestre: Array[String]) -> bool:
	_planejamento_csv = _file_handling.carregar_planejamento(dir_saida, "planejamento.csv", prefixos_semestre, _delimitadores["planejamento"], _posicoes_planejamento)
	return _planejamento_csv.size() > 0

## Exporta as alocações para o arquivo [code]horarios.txt[/code] no formato Windows-1252.
func exportar_horarios(dir_exportacao: String, alocacoes: Dictionary, grades_disciplinas_curriculos: Dictionary, terminal: Node, cores_terminal: Dictionary) -> void:
	if alocacoes.size() == 0:
		terminal.text_edit("Nenhuma alocação para exportar.", cores_terminal.get("aviso", "yellow"), true, false)
		return
	var dias: Array[String] = _analise_horarios.dias_da_semana(_horarios_ini)
	var horas: Array[String] = _analise_horarios.horas_das_aulas(_horarios_ini)
	var linhas: Array[String] = _horarios_exe.exportar_horarios_ref(alocacoes, _planejamento_csv, _horarios_ini, grades_disciplinas_curriculos, dias, horas)
	DirAccess.make_dir_recursive_absolute(dir_exportacao)
	var caminho: String = dir_exportacao + "horarios.txt"
	var file := FileAccess.open(caminho, FileAccess.WRITE)
	if file == null:
		terminal.text_edit("Erro ao criar arquivo: " + caminho, cores_terminal.get("erro", "red"), true, false)
		return
	for linha in linhas:
		file.store_buffer(_horarios_exe._para_cp1252(linha + "\r\n"))
	terminal.text_edit("Exportado: " + caminho + " (" + str(linhas.size() - 1) + " linhas de dados).", cores_terminal.get("sucesso", "green"), true, false)
	for i in range(min(linhas.size(), 6)):
		terminal.text_edit(linhas[i], cores_terminal["padrao"], i > 0, false)

## Exporta o planejamento + alocações para JSON unificado. [br]
## [param alocacoes] é o dicionário de alocações da grade (key "linha_coluna" → Array[Dictionary]). [br]
## [param prefixos_semestre] (opcional): quando NÃO vazio, inclui apenas as disciplinas cujo campo
## [code]oferta[/code] casa com algum desses prefixos (via [method FileHandling.semestre_casa_prefixos]).
## Usado no envio ao servidor para mandar só as disciplinas do próprio curso (1 record por curso);
## o salvamento local chama sem prefixos e mantém o arquivo completo. [br]
## Retorna um dicionário no formato compatível com [method FileHandling.save_json]. [br]
func exportar_planejamento_json(alocacoes: Dictionary, prefixos_semestre: Array = []) -> Dictionary:
	var saida: Dictionary = {
		"ano": Time.get_datetime_dict_from_system()["year"],
		"exportado_em": Time.get_datetime_string_from_system(),
		"disciplinas": [],
	}
	var dias: Array[String] = _analise_horarios.dias_da_semana(_horarios_ini)
	var horas: Array[String] = _analise_horarios.horas_das_aulas(_horarios_ini)
	var chave_para_nomes: Dictionary = {}
	for chave in _planejamento_csv.keys():
		var dados: Dictionary = _planejamento_csv[chave]
		# Disciplinas de outro curso sobrepostas como referência (somente-leitura) nunca entram no
		# planejamento.json do usuário — não devem ser salvas nem enviadas ao servidor como se fossem dele.
		if dados.get("referencia", false):
			continue
		# Filtro de curso (só no envio): mantém apenas as disciplinas cuja oferta casa com os prefixos.
		# Compartilhadas (ex.: "EM02;ECExtra") casam por qualquer parte, então entram nos dois cursos.
		if not prefixos_semestre.is_empty():
			var oferta: String = dados.get("oferta", dados.get("semestre", ""))
			if not FileHandling.semestre_casa_prefixos(oferta, prefixos_semestre):
				continue
		var professores_json: Array[Dictionary] = []
		for i in dados.get("professor", []).size():
			professores_json.append({
				"nome": dados["professor"][i],
				"ch": int(dados["ch"][i]) if i < dados["ch"].size() else 0,
			})
		var disc: Dictionary = {
			"codigo": dados.get("codigo", ""),
			"semestre": dados.get("semestre", ""),
			# Preserva a oferta combinada entre cursos (ex.: "EM02;ECExtra") no round-trip; cai no
			# semestre quando a disciplina nao e compartilhada.
			"oferta": dados.get("oferta", dados.get("semestre", "")),
			"professores": professores_json,
			"ch_disciplina": int(dados.get("ch_disciplina", "0")),
			"alocacoes": [],
		}
		# Busca alocações da grade que correspondem a esta disciplina.
		for chave_celula in alocacoes.keys():
			var partes: PackedStringArray = chave_celula.split("_")
			if partes.size() != 2:
				continue
			var linha_idx: int = int(partes[0])
			var coluna_idx: int = int(partes[1])
			for aloc in alocacoes[chave_celula]:
				if aloc.get("referencia", false):
					continue
				if aloc.get("chave", "") == chave:
					disc["alocacoes"].append({
						"professor": professores_json[0]["nome"] if professores_json.size() > 0 else "",
						"sala": aloc.get("sala", ""),
						"horario": horas[linha_idx - 1] if linha_idx > 0 and linha_idx <= horas.size() else "",
						"dia": dias[coluna_idx - 1] if coluna_idx > 0 and coluna_idx <= dias.size() else "",
						"tipo": aloc.get("tipo", ""),
						"turma": aloc.get("turma", ""),
						"vagas": aloc.get("vagas", ""),
						"p": aloc.get("p", 1),
						"s": aloc.get("s", 1),
						"t": aloc.get("t", 1),
					})
		saida["disciplinas"].append(disc)
	return saida


## Mescla os planos de varios cursos num plano unico de campus (concatenacao do coordenador
## academico). [param registros] e um Array de records do servidor (cada um
## [code]{ id, enviado_em, planejamento: { disciplinas } }[/code]). [br]
## Reconciliacao (nao concatenacao cega): disciplinas sao identificadas por
## [code](codigo, oferta)[/code]. Uma compartilhada chega nos records de ambos os cursos (filtro de
## envio por curso) — se as [code]alocacoes[/code] forem [b]iguais[/b], dedup; se [b]divergirem[/b], e
## um CONFLITO. Com [param preferir_recente] = false, mantem a 1a vista e apenas REGISTRA o conflito
## (para o chamador decidir); com true, resolve mantendo a do record de [code]enviado_em[/code] mais
## recente. [br]
## Retorna [code]{ "plano": Dictionary, "conflitos": Array }[/code] — [code]plano[/code] no mesmo
## formato de [method exportar_planejamento_json]; cada conflito e
## [code]{ codigo, oferta, cursos }[/code].
static func mesclar_planejamentos(registros: Array, preferir_recente: bool) -> Dictionary:
	var por_chave: Dictionary = {}   # chave -> { "disc", "enviado_em", "curso" }
	var conflitos: Array = []
	var chaves_em_conflito: Dictionary = {}   # evita listar o mesmo conflito mais de uma vez
	for rec in registros:
		if not rec is Dictionary:
			continue
		var curso: String = str(rec.get("id", ""))
		var enviado_em: String = str(rec.get("enviado_em", ""))
		var plano: Dictionary = rec.get("planejamento", {}) if rec.get("planejamento") is Dictionary else {}
		for disc in plano.get("disciplinas", []):
			if not disc is Dictionary:
				continue
			var oferta: String = str(disc.get("oferta", disc.get("semestre", "")))
			var chave: String = str(disc.get("codigo", "")) + "|" + oferta
			if not por_chave.has(chave):
				por_chave[chave] = { "disc": disc, "enviado_em": enviado_em, "curso": curso }
				continue
			var atual: Dictionary = por_chave[chave]
			# Comparacao estavel das alocacoes (JSON), independente da ordem interna dos dicts.
			if JSON.stringify(atual["disc"].get("alocacoes", [])) == JSON.stringify(disc.get("alocacoes", [])):
				continue  # identica -> dedup silencioso
			if not chaves_em_conflito.has(chave):
				chaves_em_conflito[chave] = true
				conflitos.append({ "codigo": disc.get("codigo", ""), "oferta": oferta, \
					"cursos": [atual["curso"], curso] })
			# So sobrescreve quando o admin pediu para manter o mais recente (nunca em silencio).
			if preferir_recente and enviado_em > str(atual["enviado_em"]):
				por_chave[chave] = { "disc": disc, "enviado_em": enviado_em, "curso": curso }
	var disciplinas: Array = []
	for chave in por_chave:
		disciplinas.append(por_chave[chave]["disc"])
	var plano_final: Dictionary = {
		"ano": Time.get_datetime_dict_from_system()["year"],
		"exportado_em": Time.get_datetime_string_from_system(),
		"disciplinas": disciplinas,
	}
	return { "plano": plano_final, "conflitos": conflitos }

## Mescla o planejamento atual com um [code]horarios.txt[/code] existente. [br]
## Preserva dados de agendamento (sala, horário, dia, tipo, turma) de disciplinas [br]
## já alocadas que ainda constam no planejamento. Ajusta linhas conforme CH. [br]
## Retorna [code]{ "entries": Array[Dictionary], "removidas": Array[String], "entries_removidas": Array[Dictionary] }[/code]. [br]
## O caller deve usar [method escrever_horarios_txt] para salvar, e decidir [br]
## via diálogo o que fazer com as disciplinas em [param removidas].
func mesclar_planejamento_com_horarios_txt(caminho_horarios_txt: String) -> Dictionary:
	var dados_txt: Array[Dictionary] = parse_horarios_txt(caminho_horarios_txt)
	# Lookup: chave + professor_normalized → Array[Dictionary] (scheduling data).
	var lookup: Dictionary = {}
	var chaves_existentes: Dictionary = {}
	for entry in dados_txt:
		var disc_str: String = entry.get("disciplina", "")
		if disc_str == " " or disc_str.is_empty():
			continue
		var codigo: String = _horarios_exe.extrair_cod_horarios_txt(disc_str).to_lower()
		var sem: String = entry.get("semestre", "")
		var chave_txt: String = codigo + "_" + sem.to_lower()
		var prof: String = entry.get("professor", "").trim_prefix("\"").trim_suffix("\"").strip_edges()
		chaves_existentes[chave_txt] = true
		var key_lookup: String = chave_txt + "_" + prof.to_lower()
		if not lookup.has(key_lookup):
			lookup[key_lookup] = []
		lookup[key_lookup].append({
			"sala": entry.get("sala", ""),
			"horario": entry.get("horario", ""),
			"dia": entry.get("dia", ""),
			"tipo": entry.get("tipo", ""),
			"turma": entry.get("turma", ""),
			"vagas": entry.get("vagas", ""),
			"p": entry.get("p", "1"),
			"s": entry.get("s", "1"),
			"t": entry.get("t", "1"),
		})
	var novas_entries: Array[Dictionary] = []
	var chaves_novas: Dictionary = {}
	for chave in _planejamento_csv.keys():
		var dados: Dictionary = _planejamento_csv[chave]
		var codigo: String = dados.get("codigo", "")
		var sem: String = dados.get("semestre", "")
		var chave_base: String = codigo.to_lower() + "_" + sem.to_lower()
		chaves_novas[chave_base] = true
		var nome_disc: String = _analise_grades.info_grade(_grades_disciplinas_curriculos, codigo, "nome", "", true)
		if nome_disc.begins_with("Codigo"):
			nome_disc = codigo
		for b in dados.get("professor", []).size():
			var prof_raw: String = dados["professor"][b]
			var ch_prof: int = int(dados["ch"][b]) if b < dados["ch"].size() else 0
			var match_key: String = chave_base + "_" + prof_raw.to_lower()
			var existentes: Array = lookup.get(match_key, [])
			for c in ch_prof:
				var disciplina_str: String = nome_disc + " (" + codigo.to_upper() + ")"
				var entry: Dictionary = {
					"professor": prof_raw,
					"sala": "",
					"semestre": sem,
					"horario": "",
					"dia": "",
					"disciplina": disciplina_str,
					"tipo": "",
					"turma": "",
					"vagas": "",
					"p": "1",
					"s": "1",
					"t": "1",
				}
				if c < existentes.size():
					var old: Dictionary = existentes[c]
					entry["sala"] = old.get("sala", "")
					entry["horario"] = old.get("horario", "")
					entry["dia"] = old.get("dia", "")
					entry["tipo"] = old.get("tipo", "")
					entry["turma"] = old.get("turma", "")
					entry["vagas"] = old.get("vagas", "")
					entry["p"] = old.get("p", "1")
					entry["s"] = old.get("s", "1")
					entry["t"] = old.get("t", "1")
				novas_entries.append(entry)
	var removidas: Array[String] = []
	for chave_txt in chaves_existentes.keys():
		if not chaves_novas.has(chave_txt):
			removidas.append(chave_txt)
	var entries_removidas: Array[Dictionary] = []
	for entry in dados_txt:
		var disc_str: String = entry.get("disciplina", "")
		if disc_str == " " or disc_str.is_empty():
			continue
		var codigo: String = _horarios_exe.extrair_cod_horarios_txt(disc_str).to_lower()
		var chave_txt: String = codigo + "_" + entry.get("semestre", "").to_lower()
		if chave_txt in removidas:
			entries_removidas.append(entry)
	return {
		"entries": novas_entries,
		"removidas": removidas,
		"entries_removidas": entries_removidas,
	}

## Escreve [param entries] (Array[Dictionary] no formato horarios_txt) para [code]horarios.txt[/code].
func escrever_horarios_txt(entries: Array[Dictionary], dir_exportacao: String, terminal: Node, cores_terminal: Dictionary) -> void:
	var horariosexe: Array[Array] = _horarios_exe.exportar_horariostxt(entries)
	DirAccess.make_dir_recursive_absolute(dir_exportacao)
	var caminho: String = dir_exportacao + "horarios.txt"
	var file := FileAccess.open(caminho, FileAccess.WRITE)
	if file == null:
		terminal.text_edit("Erro ao criar arquivo: " + caminho, cores_terminal.get("erro", "red"), true, false)
		return
	for linha in horariosexe:
		var linha_str: String = ""
		for campo in linha.size():
			if campo > 0:
				linha_str += ","
			linha_str += str(linha[campo])
		file.store_buffer(_horarios_exe._para_cp1252(linha_str + "\r\n"))
	terminal.text_edit("Exportado: " + caminho + " (" + str(horariosexe.size() - 1) + " linhas de dados).", cores_terminal.get("sucesso", "green"), true, false)
