extends GutTest
## Prova a expansao de "cursadas" por equivalencia (Cards/0004-cor-concluida-por-equivalencia):
## disciplina concluida sob o codigo de outra grade entra na lista de concluidas do alvo, respeitando
## a regra de disciplina dividida de [method AnaliseGrades.alvo_completo], e a grade curricular pinta
## esse alvo com a cor de "cursada". Fixtures ficticias: grade zz_2023 e equivalencias sinteticas dos
## cursos inexistentes zz/yy -- nenhum dado real.

# Grade ficticia com tres disciplinas obrigatorias, usada tambem para provar a cor da celula.
const GRADE_ZZ: Dictionary = {
	"zz0001": {"nome": "Disciplina Zeta Um", "posicao_grade": [1, 1]},
	"zz0002": {"nome": "Disciplina Zeta Dois", "posicao_grade": [1, 2]},
	"zz0003": {"nome": "Disciplina Zeta Tres", "posicao_grade": [2, 1]},
}

# Cobre 1:1 (zz9001), valor em Array/1:N (zz9002), disciplina dividida (zz9003+zz9004 -> zz0003) e
# equivalencia entre cursos (yy_0000-zz_2023).
const EQUIVALENCIAS: Dictionary = {
	"zz_2010-zz_2023": {
		"zz9001": "zz0001",
		"zz9002": ["zz0002"],
		"zz9003": "zz0003",
		"zz9004": "zz0003",
	},
	"yy_0000-zz_2023": {
		"yy0001": "zz0002",
	},
}

var _analise := AnaliseGrades.new()


func test_fonte_cursada_gera_alvo_concluido() -> void:
	var cursadas: Array[String] = ["zz9001"]
	assert_eq(_analise.concluidas_por_equivalencia(cursadas, EQUIVALENCIAS, "zz_2023"), ["zz0001"])
	# Fonte em maiusculas prova a normalizacao to_lower antes do lookup.
	var cursadas_maiusculas: Array[String] = ["ZZ9001"]
	assert_eq(_analise.concluidas_por_equivalencia(cursadas_maiusculas, EQUIVALENCIAS, "zz_2023"), ["zz0001"])


func test_disciplina_dividida_exige_todas_as_fontes() -> void:
	var so_uma_fonte: Array[String] = ["zz9003"]
	assert_eq(_analise.concluidas_por_equivalencia(so_uma_fonte, EQUIVALENCIAS, "zz_2023"), [], \
	"so uma das duas partes cursada nao pode liberar o alvo dividido")
	var as_duas_fontes: Array[String] = ["zz9003", "zz9004"]
	assert_eq(_analise.concluidas_por_equivalencia(as_duas_fontes, EQUIVALENCIAS, "zz_2023"), ["zz0003"])


func test_sem_equivalencia_retorna_vazio() -> void:
	var cursadas: Array[String] = ["zz9001"]
	assert_eq(_analise.concluidas_por_equivalencia(cursadas, {}, "zz_2023"), [], \
	"grade sem arquivo de equivalencia -- no-op silencioso")
	var equivalencia_de_outro_destino: Dictionary = {"zz_2010-yy_2020": {"zz9001": "zz0001"}}
	assert_eq(_analise.concluidas_por_equivalencia(cursadas, equivalencia_de_outro_destino, "zz_2023"), [], \
	"equivalencia que nao aponta para a grade ativa nao pode vazar")


func test_grade_pinta_alvo_expandido_de_cursada() -> void:
	# zz0001 tambem aparece como matriculavel -- prova que cursada tem precedencia sobre condicao.
	var disc_cursaveis: Dictionary = {"matriculavel": ["zz0001"]}
	var cursadas: Array[String] = ["zz9001"]
	cursadas.append_array(_analise.concluidas_por_equivalencia(cursadas, EQUIVALENCIAS, "zz_2023"))
	var lista_cores: Dictionary = {"cursada": "COR_CURSADA_TESTE", "matriculavel": "COR_MATRICULAVEL_TESTE"}
	var matriz: Array = _analise.montar_grade_curricular(GRADE_ZZ, disc_cursaveis, cursadas, lista_cores)
	assert_eq(matriz[0][1]["cor_central"], "COR_CURSADA_TESTE")


func test_alvo_ja_cursado_nao_duplica() -> void:
	# zz0001 ja esta em cursadas (direto); zz9001 tambem mapeia para ele -- nao pode duplicar/rebaixar.
	var cursadas: Array[String] = ["zz9001", "zz0001"]
	assert_eq(_analise.concluidas_por_equivalencia(cursadas, EQUIVALENCIAS, "zz_2023"), [])


func test_alvo_dourado_nunca_hachurado() -> void:
	var cursadas: Array[String] = ["zz9003", "zz9004"]
	var expansao: Array[String] = _analise.concluidas_por_equivalencia(cursadas, EQUIVALENCIAS, "zz_2023")
	assert_true(expansao.has("zz0003"), "grupo dividido completo deve gerar o alvo")
	# codigos_historico superset: as duas fontes cursadas + um codigo qualquer em curso (zz0002).
	var codigos_historico: Dictionary = {"zz9003": true, "zz9004": true, "zz0002": true}
	var distantes: Array[String] = _analise.disciplinas_distantes(GRADE_ZZ, {}, cursadas, EQUIVALENCIAS, \
	"zz_2023", codigos_historico)
	assert_false(distantes.has("zz0003"), "alvo dourado nao pode aparecer hachurado como distante")


func test_equivalencia_entre_cursos() -> void:
	var cursadas: Array[String] = ["yy0001"]
	assert_eq(_analise.concluidas_por_equivalencia(cursadas, EQUIVALENCIAS, "zz_2023"), ["zz0002"], \
	"equivalencia entre cursos (yy_0000-zz_2023) segue o mesmo caminho da intracurso")
	# Valor em Array (zz9002 -> ["zz0002"]) prova de passagem o suporte 1:N.
	var cursadas_1n: Array[String] = ["zz9002"]
	assert_eq(_analise.concluidas_por_equivalencia(cursadas_1n, EQUIVALENCIAS, "zz_2023"), ["zz0002"])
