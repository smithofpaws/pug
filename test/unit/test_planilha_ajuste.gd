extends GutTest
## Prova a mesclagem de multiplas respostas do mesmo aluno no Modo Ajuste
## (Cards/0002-mesclar-respostas-ajuste): PlanilhaAjuste.parse() deixa de ser
## last-wins por matricula e passa a unir incluir/excluir de todas as respostas,
## resolvendo conflito por disciplina pela mencao mais recente (linhas do CSV em
## ordem cronologica). Fixtures e matriculas sao ficticias.

const CABECALHO := "Carimbo de data/hora,Matrícula,Disciplinas a incluir,Disciplinas a excluir"

var _planilha: PlanilhaAjuste


func before_each() -> void:
	_planilha = autofree(PlanilhaAjuste.new())


func test_respostas_disjuntas_viram_uniao() -> void:
	var csv: String = _csv_respostas([
		"2026/08/10 8:00:00,2409990011,\"al0400\",",
		"2026/08/11 9:00:00,2409990011,\"al0401\",",
	])
	var resultado: Dictionary = _planilha.parse(csv)
	var resposta: Dictionary = resultado["respostas"][0]
	assert_eq(resposta["incluir"], ["al0400", "al0401"], "inclusoes disjuntas devem virar uniao")
	assert_eq(resposta["excluir"], [])


func test_codigo_troca_de_lado_vence_mencao_mais_recente() -> void:
	# Matricula A: al0300 so aparece incluido na 1a resposta (ancora que so sobrevive por
	# mesclagem — um last-wins pela ultima linha a perderia); al0400 comeca incluido na 1a e
	# vira excluido na 2a -> so deve aparecer em excluir.
	var csv_a: String = _csv_respostas([
		"2026/08/10 8:00:00,2409990011,\"al0300, al0400\",",
		"2026/08/11 9:00:00,2409990011,,\"al0400\"",
	])
	var resposta_a: Dictionary = _planilha.parse(csv_a)["respostas"][0]
	assert_eq(resposta_a["incluir"], ["al0300"])
	assert_eq(resposta_a["excluir"], ["al0400"])

	# Matricula B (sentido oposto): al0300 so aparece excluido na 1a (ancora); al0400 comeca
	# excluido na 1a e vira incluido na 2a -> so deve aparecer em incluir.
	var csv_b: String = _csv_respostas([
		"2026/08/10 8:00:00,2409990022,,\"al0300, al0400\"",
		"2026/08/11 9:00:00,2409990022,\"al0400\",",
	])
	var resposta_b: Dictionary = _planilha.parse(csv_b)["respostas"][0]
	assert_eq(resposta_b["incluir"], ["al0400"])
	assert_eq(resposta_b["excluir"], ["al0300"])


func test_mesmo_lado_uma_entrada_com_texto_mais_recente() -> void:
	var csv: String = _csv_respostas([
		"2026/08/10 8:00:00,2409990011,\"al0400 texto antigo\",",
		"2026/08/11 9:00:00,2409990011,\"al0401 texto b\",",
		"2026/08/12 10:00:00,2409990011,\"al0400 texto novo\",",
	])
	var resposta: Dictionary = _planilha.parse(csv)["respostas"][0]
	# Uma entrada so para al0400 (nao duas), com o texto da mencao mais recente. A ordem
	# (al0400 antes de al0401) prova que sobrescrever decisoes[al0400] na 3a linha nao move
	# a chave para o fim do Dictionary -- contrato do qual toda ordem de retorno depende.
	assert_eq(resposta["incluir"], ["al0400 texto novo", "al0401 texto b"])


func test_excluir_prevalece_na_mesma_resposta() -> void:
	var csv: String = _csv_respostas([
		"2026/08/10 8:00:00,2409990011,\"al0400\",\"al0400\"",
	])
	var resposta: Dictionary = _planilha.parse(csv)["respostas"][0]
	assert_eq(resposta["incluir"], [])
	assert_eq(resposta["excluir"], ["al0400"])


func test_entrada_sem_codigo_mantida_com_dedup_normalizado() -> void:
	var csv: String = _csv_respostas([
		"2026/08/10 8:00:00,2409990011,\"Cálculo Numérico\",",
		"2026/08/11 9:00:00,2409990011,\"calculo numerico\",",
	])
	var resposta: Dictionary = _planilha.parse(csv)["respostas"][0]
	assert_eq(resposta["incluir"], ["Cálculo Numérico"], "dedup por texto normalizado mantem o texto da 1a ocorrencia")


func test_celula_vazia_posterior_nao_apaga() -> void:
	var csv: String = _csv_respostas([
		"2026/08/10 8:00:00,2409990011,\"al0400\",",
		"2026/08/11 9:00:00,2409990011,,",
	])
	var resposta: Dictionary = _planilha.parse(csv)["respostas"][0]
	assert_eq(resposta["incluir"], ["al0400"], "celula vazia posterior nao pode apagar o que outra resposta pediu")
	assert_eq(resposta["excluir"], [])


func test_mencao_multi_codigo_decide_por_codigo() -> void:
	var csv: String = _csv_respostas([
		"2026/08/10 8:00:00,2409990011,\"al0400 e al0401\",",
	])
	var resposta: Dictionary = _planilha.parse(csv)["respostas"][0]
	# Mencao multi-codigo emite o codigo puro por codigo, nao a entrada inteira repetida.
	assert_eq(resposta["incluir"], ["al0400", "al0401"])


func test_extrair_codigos_ignora_fragmento_de_palavra_como_sala_ou_turma() -> void:
	# Sem fronteira de palavra antes das letras, "Sala 302"/"Turma 101" casariam um falso segundo
	# codigo em pleno meio da palavra anterior ("ala302", "rma101") -- ver Cards/0002, finding de
	# review. O \b do regex garante que so o codigo real no inicio da entrada e extraido.
	assert_eq(_planilha.extrair_codigos("AL0400 - Fundacoes - Sala 302"), ["al0400"])
	assert_eq(_planilha.extrair_codigos("AL0400 - Fundacoes - Turma 101"), ["al0400"])


func test_ruido_de_regex_em_sala_ou_turma_nao_vira_segundo_codigo() -> void:
	var csv: String = _csv_respostas([
		"2026/08/10 8:00:00,2409990011,\"AL0400 - Fundacoes - Sala 302\",",
	])
	var resposta: Dictionary = _planilha.parse(csv)["respostas"][0]
	# Uma unica mencao valida: nem vira duas entradas (codigo real + "problema" fantasma do ruido),
	# nem perde o texto descritivo (turma/professor) que o coordenador precisa ao investigar.
	assert_eq(resposta["incluir"], ["AL0400 - Fundacoes - Sala 302"])


func test_token_curto_isolado_antes_de_numero_ainda_vira_candidato() -> void:
	# Limitacao residual e aceita do \b (Cards/0002, finding de review): ele elimina o ruido em
	# MEIO de palavra ("sala"/"turma"/"predio" + numero), mas um token curto ISOLADO antes de um
	# numero ("Lab 101", "em 2026") ainda satisfaz a fronteira de palavra e ainda vira candidato.
	# Distinguir isso de um segundo codigo real exigiria a grade do aluno, que este parser nao tem
	# -- por isso o teste apenas fixa o comportamento atual, para nao virar "descoberta" de novo.
	assert_eq(_planilha.extrair_codigos("AL0400 - Fundacoes - Lab 101"), ["al0400", "lab101"])
	assert_eq(_planilha.extrair_codigos("incluir AL0400 em 2026"), ["al0400", "em2026"])


func test_token_curto_isolado_via_parse_ainda_gera_entrada_fantasma() -> void:
	# Mesmo residual acima, visto pela saida de parse() (o formato que o modulo realmente consome):
	# "lab101" sai como entrada propria, sem grade que bata nela vira "problema" no modulo -- o
	# mesmo formato de dano que o finding original descreveu, agora um limite deliberado e testado
	# em vez de comportamento latente. So ocorre com texto livre digitado (nao com a opcao padrao
	# do Forms, "codigo - ementa - turma - nome", onde a turma tem 1 letra e nunca casa o regex).
	var csv: String = _csv_respostas([
		"2026/08/10 8:00:00,2409990011,\"AL0400 - Fundacoes - Lab 101\",",
	])
	var resposta: Dictionary = _planilha.parse(csv)["respostas"][0]
	assert_eq(resposta["incluir"], ["al0400", "lab101"])


func test_matricula_com_espacos_mescla() -> void:
	var csv: String = _csv_respostas([
		"2026/08/10 8:00:00, 2409990011 ,\"al0400\",",
		"2026/08/11 9:00:00,2409990011,\"al0401\",",
	])
	var resultado: Dictionary = _planilha.parse(csv)
	assert_eq(resultado["respostas"].size(), 1, "matricula com espacos deve mesclar com a sem espacos")
	var resposta: Dictionary = resultado["respostas"][0]
	assert_eq(resposta["matricula"], "2409990011")
	assert_eq(resposta["incluir"], ["al0400", "al0401"])


func test_formato_de_retorno_inalterado() -> void:
	var arquivo: FileAccess = FileAccess.open("res://test/fixtures/ajuste_respostas.csv", FileAccess.READ)
	var csv: String = arquivo.get_as_text()
	arquivo.close()

	var resultado: Dictionary = _planilha.parse(csv)

	var chaves_topo: Array = resultado.keys()
	chaves_topo.sort()
	assert_eq(chaves_topo, ["erro", "ok", "respostas"], "conjunto exato de chaves do topo")
	assert_true(resultado["ok"])
	assert_eq(resultado["respostas"].size(), 2)

	for item: Variant in resultado["respostas"]:
		var resposta: Dictionary = item
		var chaves_item: Array = resposta.keys()
		chaves_item.sort()
		assert_eq(chaves_item, ["excluir", "incluir", "matricula"], "conjunto exato de chaves de cada resposta")
		assert_typeof(resposta["incluir"], TYPE_ARRAY)
		assert_typeof(resposta["excluir"], TYPE_ARRAY)

	# Resposta unica (matricula sem respostas repetidas) sai identica ao comportamento
	# atual: uma entrada, com o texto da celula original preservado.
	var unica: Dictionary = resultado["respostas"][0]
	assert_eq(unica["matricula"], "2409990011")
	assert_eq(unica["incluir"], ["AL0400 - Fundacoes - T20 - Maria da Silva Souza"])
	assert_eq(unica["excluir"], [])

	# Resposta multipla: mesclagem das duas respostas da mesma matricula.
	var multipla: Dictionary = resultado["respostas"][1]
	assert_eq(multipla["matricula"], "2409990022")
	assert_eq(multipla["incluir"], [
		"AL0401 - Estruturas de Concreto - T10 - Joao Pereira Lima",
		"AL0403 - Topografia - T10 - Joao Pereira Lima",
	])
	assert_eq(multipla["excluir"], [
		"AL0402 - Hidraulica - T10 - Joao Pereira Lima",
		"AL0400 - Fundacoes - T20 - Joao Pereira Lima",
	])


func test_rotulo_com_virgulas_vira_uma_mencao() -> void:
	# Cards/0003: o Forms junta as opcoes marcadas por virgula, entao um rotulo com virgulas
	# ("AL0394: Administracao, T40;60;80, Joao Pereira Lima;") estilhacava em 3 entradas falsas.
	var csv: String = _csv_respostas([
		"2026/08/10 8:00:00,2409990011,\"AL0394: Administração, T40;60;80, João Pereira Lima;\",",
	])
	var resposta: Dictionary = _planilha.parse(csv)["respostas"][0]
	assert_eq(resposta["incluir"], ["AL0394: Administração, T40;60;80, João Pereira Lima;"], \
		"rotulo inteiro deve ser reconstituido como uma unica mencao")
	assert_eq(resposta["excluir"], [], "coluna excluir vazia nesta linha do CSV (fragmento vazado da celula incluir cairia em incluir, nunca aqui)")
	assert_eq(_planilha.extrair_codigos(resposta["incluir"][0]), ["al0394"])


func test_duas_opcoes_com_virgulas_no_rotulo_viram_duas_mencoes() -> void:
	var csv: String = _csv_respostas([
		"2026/08/10 8:00:00,2409990011,\"AL0394: Administração, T40;60;80, João Pereira Lima, AL0401: Estruturas de Concreto, T10;20, Maria da Silva Souza\",",
	])
	var resposta: Dictionary = _planilha.parse(csv)["respostas"][0]
	assert_eq(resposta["incluir"], [
		"AL0394: Administração, T40;60;80, João Pereira Lima",
		"AL0401: Estruturas de Concreto, T10;20, Maria da Silva Souza",
	], "cada opcao marcada deve virar uma mencao, na ordem em que aparecem na celula")
	assert_eq(_planilha.extrair_codigos(resposta["incluir"][0]), ["al0394"])
	assert_eq(_planilha.extrair_codigos(resposta["incluir"][1]), ["al0401"])


func test_fragmento_sem_codigo_no_inicio_continua_problema() -> void:
	# Sem entrada anterior para reanexar, o 1o fragmento da celula abre entrada propria mesmo
	# sem codigo -- vira "problema" e continua visivel ao coordenador.
	var csv: String = _csv_respostas([
		"2026/08/10 8:00:00,2409990011,\"pedido sem codigo, AL0394: Administração, T40\",",
	])
	var resposta: Dictionary = _planilha.parse(csv)["respostas"][0]
	# Decisoes (com codigo) antes dos problemas -- ordem de _montar_resposta.
	assert_eq(resposta["incluir"], ["AL0394: Administração, T40", "pedido sem codigo"])


func test_celula_so_texto_livre_vira_um_problema_rejuntado() -> void:
	var csv: String = _csv_respostas([
		"2026/08/10 8:00:00,2409990011,,\"Desisti da disciplina, motivo pessoal, obrigado\"",
	])
	var resposta: Dictionary = _planilha.parse(csv)["respostas"][0]
	assert_eq(resposta["excluir"], ["Desisti da disciplina, motivo pessoal, obrigado"], \
		"texto livre com virgulas sem nenhum codigo deve virar UM problema re-juntado")


func test_texto_livre_apos_mencao_valida_e_absorvido() -> void:
	# Trade-off aceito na entrevista (AC5): pedido em texto livre escrito apos virgula numa
	# mencao com codigo passa a ser absorvido pela mencao -- deixa de gerar alerta de "codigo
	# invalido/ausente" separado. O coordenador ve o texto completo, so nao ve mais o alerta.
	var csv: String = _csv_respostas([
		"2026/08/10 8:00:00,2409990011,\"AL0400 Fundações, quero também a de concreto\",",
	])
	var resposta: Dictionary = _planilha.parse(csv)["respostas"][0]
	assert_eq(resposta["incluir"], ["AL0400 Fundações, quero também a de concreto"])


func test_reanexo_compoe_com_mesclagem_mais_recente() -> void:
	# O mesmo rotulo com virgulas (reconstituido pelo reanexo) e incluido na 1a resposta e
	# excluido na 2a -- a mencao mais recente vence, entao so sobra em excluir (0002 intacto).
	var csv: String = _csv_respostas([
		"2026/08/10 8:00:00,2409990011,\"AL0394: Administração, T40;60;80, João Pereira Lima\",",
		"2026/08/11 9:00:00,2409990011,,\"AL0394: Administração, T40;60;80, João Pereira Lima\"",
	])
	var resposta: Dictionary = _planilha.parse(csv)["respostas"][0]
	assert_eq(resposta["incluir"], [])
	assert_eq(resposta["excluir"], ["AL0394: Administração, T40;60;80, João Pereira Lima"])


func test_fragmento_reanexado_a_mencao_multi_codigo_perde_o_texto() -> void:
	# Amplificacao (nao-AC, mas real) de um limite ja existente do 0002: numa mencao com 2+
	# codigos, _mesclar_lado emite o codigo puro por codigo (nao a entrada inteira -- ver
	# comentario em _mesclar_lado). Antes do 0003, o fragmento apos a virgula virava entrada
	# propria e sobrava como "problema" visivel. Agora ele e reanexado ao rotulo multi-codigo e
	# desaparece do retorno por completo -- nem vira mencao nem problema. Travado aqui para nao
	# virar "descoberta" de novo; corrigir exige tocar _mesclar_lado, fora do escopo deste card.
	var csv: String = _csv_respostas([
		"2026/08/10 8:00:00,2409990011,\"al0400 e al0401, professor Fulano\",",
	])
	var resposta: Dictionary = _planilha.parse(csv)["respostas"][0]
	assert_eq(resposta["incluir"], ["al0400", "al0401"], \
		"'professor Fulano' some do retorno -- nem mencao nem problema")


func test_fragmento_residual_de_regex_inicia_mencao() -> void:
	# Limite deliberado herdado do 0002 (non-goal deste card): "Lab 101" contem candidato
	# ("lab101"), entao inicia mencao nova em vez de ser reanexado ao fragmento anterior.
	var csv: String = _csv_respostas([
		"2026/08/10 8:00:00,2409990011,\"AL0400 Fundacoes, Lab 101\",",
	])
	var resposta: Dictionary = _planilha.parse(csv)["respostas"][0]
	assert_eq(resposta["incluir"], ["AL0400 Fundacoes", "Lab 101"])


# Monta um CSV com o cabecalho realista do Forms a partir de [param linhas] de dados ja
# formatadas ("carimbo,matricula,incluir,excluir").
func _csv_respostas(linhas: Array[String]) -> String:
	return CABECALHO + "\n" + "\n".join(linhas)
