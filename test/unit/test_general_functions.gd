extends GutTest
## Primeiro teste da suite: prova o harness (GUT headless) e fixa o contrato das
## funcoes puras de [GeneralFunctions] mais usadas pelas analises.

var _gf := GeneralFunctions.new()


func test_int_string_fill_preenche_com_zeros() -> void:
	assert_eq(_gf.int_string_fill(7, 3), "007")
	assert_eq(_gf.int_string_fill(1234, 3), "1234")


func test_avancar_semestre_projeta_meios_anos() -> void:
	assert_eq(GeneralFunctions.avancar_semestre(2026, 1, 4), {"ano": 2028, "semestre": 1})
	assert_eq(GeneralFunctions.avancar_semestre(2026, 1, 1), {"ano": 2026, "semestre": 2})
	assert_eq(GeneralFunctions.avancar_semestre(2026, 2, 1), {"ano": 2027, "semestre": 1})
	assert_eq(GeneralFunctions.avancar_semestre(2026, 2, 0), {"ano": 2026, "semestre": 2})


func test_remover_acentos_normaliza_busca() -> void:
	assert_eq(GeneralFunctions.remover_acentos("João"), "joao")
	assert_eq(GeneralFunctions.remover_acentos("METODOLOGIA CIENTÍFICA"), "metodologia cientifica")
	assert_eq(GeneralFunctions.remover_acentos("sem acento"), "sem acento")


func test_merge_profundo_sobrepoe_sem_mutar_a_base() -> void:
	var base: Dictionary = {"a": 1, "sub": {"x": 1, "y": 2}}
	var over: Dictionary = {"sub": {"y": 3}, "b": 4}
	var resultado: Dictionary = GeneralFunctions.merge_profundo(base, over)
	assert_eq(resultado, {"a": 1, "sub": {"x": 1, "y": 3}, "b": 4})
	assert_eq(base["sub"], {"x": 1, "y": 2}, "merge_profundo nao pode mutar a base")


func test_definir_por_caminho_cria_niveis_intermediarios() -> void:
	var dict: Dictionary = {}
	GeneralFunctions.definir_por_caminho(dict, ["a", "b", "c"], 42)
	assert_eq(dict, {"a": {"b": {"c": 42}}})
