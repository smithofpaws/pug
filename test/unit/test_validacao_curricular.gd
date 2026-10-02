extends GutTest
## Prova as regras de coerencia entre grades, equivalencias e cargas exigidas
## (Cards/0005-validacao-coerencia-dados-curriculares). Fixtures inline e ficticias (cursos zz/yy,
## inexistentes); so o teste de snapshot le os arquivos curriculares versionados de arquivos/.

# Os 8 defeitos conhecidos dos arquivos versionados (fd2d2f8). Identidade sem "nome".
const SNAPSHOT: Array[String] = [
	"requisito_inexistente|alec_2010|al2106|prerequisito0|al0066",
	"requisito_inexistente|alec_2010|al2114|prerequisito2|al0149",
	"requisito_inexistente|alec_2010|al2128|prerequisito0|al0087",
	"requisito_inexistente|alec_2010|al2144|prerequisito0|al0149",
	"requisito_inexistente|alec_2010|al2146|prerequisito0|al0128",
	"requisito_inexistente|alec_2010|al2189|prerequisito0|al0062",
	"requisito_inexistente|alec_2010|al5022|prerequisito0|ch 50%",
	"requisito_inexistente|alec_2023|al5022|prerequisito0|ch 50%",
]


func test_prerequisito_inexistente_e_reportado() -> void:
	var zz := {"zz0001": _disc(1), "zz0002": _disc(2, 1, {"prerequisito0": "zz9999"})}
	var achados := _achados(zz)
	assert_eq(achados, [{
		"regra": "requisito_inexistente", "chave": "zz_2023", "codigo": "zz0002",
		"nome": "Disciplina Zeta", "campo": "prerequisito0", "valor": "zz9999",
	}])
	var texto := ValidacaoCurricular.formatar(achados[0])
	assert_string_contains(texto, "zz0002")
	assert_string_contains(texto, "Disciplina Zeta")
	assert_string_contains(texto, "zz9999")
	assert_true(texto.begins_with(ValidacaoCurricular.PREFIXO + ": "))


func test_corequisito_inexistente_e_reportado() -> void:
	var zz := {"zz0001": _disc(1, 1, {"corequisito0": "zz9998"})}
	var achados := _achados(zz)
	assert_eq(achados.size(), 1)
	assert_eq(achados[0]["regra"], "requisito_inexistente")
	assert_eq(achados[0]["campo"], "corequisito0")


func test_buraco_na_numeracao_de_prerequisito_e_reportado() -> void:
	var zz := {
		"zz0001": _disc(1, 1), "zz0002": _disc(1, 2), "zz0003": _disc(1, 3),
		"zz0005": _disc(2, 1, {"prerequisito0": "zz0001", "prerequisito1": "zz0002", "prerequisito3": "zz0003"}),
	}
	var achados := _achados(zz)
	assert_eq(achados.size(), 1)
	assert_eq(achados[0]["regra"], "requisito_numeracao")
	assert_eq(achados[0]["campo"], "prerequisito")
	assert_eq(achados[0]["indice_ausente"], "2")
	var zz_b := {"zz0001": _disc(1), "zz0005": _disc(2, 1, {"prerequisito1": "zz0001"})}
	var achados_b := _achados(zz_b)
	assert_eq(achados_b.size(), 1)
	assert_eq(achados_b[0]["indice_ausente"], "0")


func test_prerequisito_de_semestre_igual_ou_posterior_e_reportado() -> void:
	var zz := {
		"zz0001": _disc(1), "zz0002": _disc(3, 1), "zz0003": _disc(2, 1), "zz0004": _disc(4, 1),
		"zz0010": _disc(3, 2, {"prerequisito0": "zz0002"}),
		"zz0011": _disc(2, 2, {"prerequisito0": "zz0004"}),
		"zz0012": _disc(2, 3, {"prerequisito0": "zz0001"}),
	}
	var achados := _achados(zz)
	assert_eq(achados.size(), 2)
	assert_has(achados, {
		"regra": "requisito_fora_de_ordem", "chave": "zz_2023", "codigo": "zz0010", "nome": "Disciplina Zeta",
		"campo": "prerequisito0", "valor": "zz0002", "semestre": "3", "semestre_requisito": "3",
	})
	assert_has(achados, {
		"regra": "requisito_fora_de_ordem", "chave": "zz_2023", "codigo": "zz0011", "nome": "Disciplina Zeta",
		"campo": "prerequisito0", "valor": "zz0004", "semestre": "2", "semestre_requisito": "4",
	})


func test_par_prerequisito_corequisito_nao_e_fora_de_ordem() -> void:
	# Mesmo indice (como al0142) e indice cruzado (como al0385).
	var zz := {
		"zz0001": _disc(3, 1), "zz0002": _disc(3, 2),
		"zz0003": _disc(3, 3, {"prerequisito0": "zz0001", "corequisito0": "zz0001"}),
		"zz0004": _disc(3, 4, {"prerequisito0": "zz0002", "corequisito0": "zz0002"}),
		"zz0005": _disc(4, 1, {"prerequisito0": "zz0001", "prerequisito1": "zz0002", "corequisito0": "zz0002"}),
	}
	assert_eq(_achados(zz), [])
	var zz_b := {
		"zz0001": _disc(3, 1), "zz0002": _disc(3, 2),
		"zz0004": _disc(3, 4, {"prerequisito0": "zz0001", "prerequisito1": "zz0002", "corequisito0": "zz0002"}),
	}
	# Controle: o pre-requisito sem par continua sendo reportado.
	var achados := _achados(zz_b)
	assert_eq(achados.size(), 1)
	assert_eq(achados[0]["valor"], "zz0001")


func test_semestre_divergente_de_posicao_grade_e_reportado() -> void:
	var zz := {
		"zz0006": {"nome": "Disciplina Zeta", "semestre": "3", "posicao_grade": [4.0, 1.0]},
		"zz0007": {"nome": "Disciplina Zeta", "semestre": "2", "posicao_grade": [2.0, 5.0]},
	}
	assert_eq(_achados(zz), [{
		"regra": "semestre_posicao_divergente", "chave": "zz_2023", "codigo": "zz0006",
		"nome": "Disciplina Zeta", "semestre": "3", "posicao_grade": "4",
	}])


func test_disciplina_sem_posicao_grade_fica_fora_das_regras_de_semestre() -> void:
	var zz := {
		"zz0001": _disc(9),
		"zz0100": {"nome": "Complementar", "semestre": "0", "prerequisito0": "zz0001"},
		"zz0101": _disc(2, 1, {"prerequisito0": "zz0100"}),
		"zz0102": {"nome": "Complementar", "semestre": "0", "prerequisito0": "zz0100"},
		"zz0103": {"nome": "Sem posicao", "semestre": "1"},
		"zz0104": {"nome": "Sem posicao", "semestre": "1", "prerequisito0": "zz0103"},
	}
	assert_eq(_achados(zz), [])


func test_equivalencia_para_codigo_ausente_e_reportada() -> void:
	var grades := {
		"zz_2010": {"zz9001": _disc(1), "zz9002": _disc(1, 2)},
		"zz_2023": {"zz0001": _disc(1)},
	}
	var equivalencias := {"zz_2010-zz_2023": {
		"zz9001": "zz0404", "zz9404": "zz0001", "zz9002": ["zz0001", "zz0405"],
	}}
	var achados := ValidacaoCurricular.inconsistencias(grades, equivalencias, {})
	assert_eq(achados.size(), 3)
	assert_has(achados, {"regra": "equivalencia_inexistente", "chave": "zz_2010-zz_2023", "codigo": "zz9001",
		"campo": "destino", "valor": "zz0404", "grade": "zz_2023"})
	assert_has(achados, {"regra": "equivalencia_inexistente", "chave": "zz_2010-zz_2023", "codigo": "zz9404",
		"campo": "origem", "valor": "zz9404", "grade": "zz_2010"})
	assert_has(achados, {"regra": "equivalencia_inexistente", "chave": "zz_2010-zz_2023", "codigo": "zz9002",
		"campo": "destino", "valor": "zz0405", "grade": "zz_2023"})


func test_lado_placeholder_0000_nao_e_reportado() -> void:
	var grades := {"yy_0000": {"yy0001": _disc(1)}, "zz_2023": {"zz0001": _disc(1)}}
	var equivalencias := {
		"yy_0000-zz_2023": {"yy0999": "zz0001"},
		"zz_2023-yy_0000": {"zz0001": "yy0998"},
	}
	assert_eq(ValidacaoCurricular.inconsistencias(grades, equivalencias, {}), [])


func test_comentario_em_equivalencia_e_ignorado() -> void:
	var grades := {"zz_2010": {"zz9001": _disc(1)}, "zz_2023": {"zz0001": _disc(1)}}
	var equivalencias := {"zz_2010-zz_2023": {"//cod de zz_2010": "que equivale este cod de zz_2023"}}
	assert_eq(ValidacaoCurricular.inconsistencias(grades, equivalencias, {}), [])


func test_nucleo_sem_carga_exigida_e_reportado() -> void:
	var zz := {
		"zz0001": _disc(1, 1, {"nucleo": "basico"}),
		"zz0002": _disc(1, 2, {"nucleo": "basico"}),
		"zz0003": _disc(1, 3, {"nucleo": "cccg"}),
	}
	var achados := ValidacaoCurricular.inconsistencias(_grades(zz), {}, {"zz_2023": {"cccg": "100"}})
	assert_eq(achados, [{"regra": "nucleo_sem_carga", "chave": "zz_2023", "codigo": "basico", "disciplinas": "2"}])


func test_chave_de_carga_sem_nucleo_nao_e_reportada() -> void:
	var zz := {"zz0001": _disc(1, 1, {"nucleo": "cccg"})}
	var carga := {"zz_2023": {"cccg": "100", "estagio": "160", "tcc": "30", "praticas": "10", "acg": "90"}}
	assert_eq(ValidacaoCurricular.inconsistencias(_grades(zz), {}, carga), [])


func test_obrigatorias_sem_nucleo_nao_sao_reportadas() -> void:
	var zz := {"zz0001": _disc(1), "zz0002": _disc(1, 2), "zz0100": {"nome": "Compl", "semestre": "0", "nucleo": "cccg"}}
	assert_eq(ValidacaoCurricular.inconsistencias(_grades(zz), {}, {"zz_2023": {"cccg": "100"}}), [])


func test_arquivos_ausentes_sao_no_op_silencioso() -> void:
	assert_eq(ValidacaoCurricular.validar({}, {}, {}), 0)
	var zz := {"zz0001": _disc(1, 1, {"nucleo": "basico"})}
	assert_eq(ValidacaoCurricular.validar(_grades(zz), {}, {}), 0)
	assert_eq(ValidacaoCurricular.validar({}, {"zz_2010-zz_2023": {"zz9001": "zz0001"}}, {}), 0)
	assert_eq(ValidacaoCurricular.validar({}, {}, {"zz_2023": {"cccg": "100"}}), 0)
	assert_push_warning_count(0)


func test_dicionario_vazio_por_parse_falho_e_no_op() -> void:
	var zz := {"zz0001": _disc(1, 1, {"nucleo": "basico"})}
	assert_eq(ValidacaoCurricular.validar(_grades(zz), {}, {"zz_2023": {}}), 0)
	var equivalencias := {"zz_2010-zz_2023": {"zz9001": "zz0001"}}
	assert_eq(ValidacaoCurricular.validar({"zz_2010": {}, "zz_2023": {}}, equivalencias, {}), 0)
	assert_push_warning_count(0)


func test_validar_emite_um_push_warning_por_achado() -> void:
	var zz := {"zz0001": _disc(1, 1, {"prerequisito0": "zz9999", "corequisito0": "zz9998"})}
	assert_eq(ValidacaoCurricular.validar(_grades(zz), {}, {}), 2)
	assert_push_warning("VALIDACAO COERENCIA")
	assert_push_warning_count(2)


func test_entrada_malformada_nao_quebra() -> void:
	var zz := {"zz0001": "texto", "zz0002": {"nome": "Disciplina Zeta", "semestre": "1", "posicao_grade": []}}
	var achados := _achados(zz)
	assert_eq(achados.size(), 1)
	assert_eq(achados[0]["regra"], "semestre_posicao_divergente")
	var grades := {"zz_2010": {"zz9001": _disc(1)}, "zz_2023": {"zz0001": _disc(1)}}
	assert_eq(ValidacaoCurricular.inconsistencias(grades, {"zz_2010-zz_2023": {"zz9001": 7}}, {}), [])


func test_formatar_achado_desconhecido_nao_quebra() -> void:
	var texto := ValidacaoCurricular.formatar({"regra": "inventada"})
	assert_true(texto.begins_with(ValidacaoCurricular.PREFIXO + ": "))


func test_arquivos_reais_reportam_so_os_defeitos_conhecidos() -> void:
	var grades := _carregar_pasta("grades")
	var equivalencias := _carregar_pasta("equivalencias")
	var cargas := _carregar_pasta("cargaexigida")
	var obtidos: Array[String] = []
	for achado in ValidacaoCurricular.inconsistencias(grades, equivalencias, cargas):
		obtidos.append("|".join([achado["regra"], achado["chave"], achado["codigo"], achado.get("campo", ""), achado.get("valor", "")]))
	for esperado in SNAPSHOT:
		assert_has(obtidos, esperado, "defeito %s nao aparece mais: se foi corrigido no repositorio do curso e sincronizado, remova-o do snapshot" % esperado)
	for obtido in obtidos:
		assert_has(SNAPSHOT, obtido, "achado novo %s: triagem -- defeito real (some ao snapshot) ou falso positivo (corrija a regra)" % obtido)
	assert_eq(ValidacaoCurricular.validar(grades, equivalencias, cargas), SNAPSHOT.size())
	assert_push_warning("al5022")
	assert_push_warning_count(SNAPSHOT.size())


# Disciplina obrigatoria ficticia; posicao_grade como float, que e o tipo que o JSON entrega.
func _disc(semestre: int, pos: int = 1, extra: Dictionary = {}) -> Dictionary:
	var d: Dictionary = {"nome": "Disciplina Zeta", "semestre": str(semestre), "posicao_grade": [float(semestre), float(pos)]}
	d.merge(extra)
	return d


func _grades(zz: Dictionary) -> Dictionary:
	return {"zz_2023": zz}


func _achados(zz: Dictionary) -> Array[Dictionary]:
	return ValidacaoCurricular.inconsistencias(_grades(zz), {}, {})


func _carregar_pasta(subpasta: String) -> Dictionary:
	var resultado: Dictionary = {}
	var caminho := "res://arquivos/" + subpasta + "/"
	var fh := FileHandling.new()
	for arq in DirAccess.get_files_at(caminho):
		if arq.ends_with(".json"):
			resultado[arq.trim_suffix(".json")] = fh.load_json(caminho, arq)
	return resultado
