class_name GeneralFunctions extends Resource
## Funções gerais não necessariamente ligadas a funcionalidade deste programa.

## Verifica se o programa está rodando como exportado (standalone) ou direto do editor.
func is_exported() -> bool:
	if OS.has_feature("template"):
		return true
	else:
		return false

## Divide uma string de acordo com múltiplos delimitadores. [br]
## [param merge_quotations] quando verdadeiro, concatena elementos que possuem aspas. Use em situações onde 
## arquivos tenham nomes com vírgulas. Ex.: [primeiro_elemento, "um, dois e tres", terceiro_elemento]
func split(s: String, delimeters: String, allow_empty: bool = true, merge_quotations: bool = true) -> Array[String]:
	var parts: Array[String] = []
	var start := 0
	var i := 0
	while i < s.length():
		if s[i] in delimeters:
			if allow_empty or start < i:
				parts.append(s.substr(start, i - start))
			start = i + 1
		i += 1
	if allow_empty or start < i:
		parts.append(s.substr(start, i - start))
	if merge_quotations:
		var rebuilt_parts: Array[String] = []
		var merged_parts: String
		start = -1
		for a in parts.size():
			if start > -1:
				merged_parts += parts[a].trim_suffix("\"")
			if "\"" in parts[a]:
				if start == -1:
					merged_parts = parts[a].trim_prefix("\"")
					start = a
				else:
					rebuilt_parts.append(merged_parts)
					merged_parts = ""
					start = -1
			else:
				rebuilt_parts.append(parts[a])
		parts = rebuilt_parts
	return parts

## Adiciona zeros iniciais em um número (e.g. para [param number] = 1 e [param length] = 4, 
## a saída será "0001").
func int_string_fill(number: int, length: int) -> String:
	var string: String = str(number)
	while string.length() < length:
		string = "0" + string
	return string

## Retorna uma lista de caracteres especiais.
func special_charset() -> Array[String]:
	var special_characters: Array[String] =\
	[
	"á","a","à","a","ã","a","â","a",
	"é","e","è","e","ê","e",
	"í","i","ì","i","î","i",
	"ó","o","ò","o","õ","o","ô","o",
	"ú","u","ù","u","û","u",
	"ç","c",
	"Á","A","À","A","Ã","A","Â","A",
	"É","E","È","E","Ê","E",
	"Í","I","Ì","I","Î","I",
	"Ó","O","Ò","O","Õ","O","Ô","O",
	"Ú","U","Ù","U","Û","U",
	"Ç","C"
	]
	return special_characters

## Encurta uma frase para que contenha apenas as primeiras letras de cada palavra. Também capitaliza 
## a frase de forma que só palavras com no mínimo [param minimo_maiusc] letras sejam capitalizadas. [br]
## O máximo tamanho de cada palavra é [param letras]. A frase vem de [param texto].
func encurtar_texto(texto: String, letras: int, minimo_maiusc: int = 4, split_char: String = " ") -> String:
	var texto_arr: Array[String] = []
	texto_arr.assign(texto.split(split_char))
	var temp_texto: String = ""
	for n in texto_arr.size():
		if n < texto_arr.size()-1:
			if texto_arr[n].length() < minimo_maiusc:
				if texto_arr[n].left(letras) == "i" \
				or texto_arr[n].left(letras) == "ii" \
				or texto_arr[n].left(letras) == "iii" \
				or texto_arr[n].left(letras) == "iv":
					temp_texto = temp_texto + texto_arr[n].left(letras).capitalize() + " "
				else:
					temp_texto = temp_texto + texto_arr[n].left(letras) + " "
			else:
				temp_texto = temp_texto + texto_arr[n].left(letras).capitalize() + ". "
		else:
			temp_texto = temp_texto + texto_arr[n]
	
	return temp_texto

## Substitui uma lista de palavras contidas em [param find] pelas palavras em [param replace]. [br]
## A substituição ocorre na ordem dos arrays.
func replace_text(find: Array[String], replace: Array[String], data: Array[String]) -> Array[String]:
	if find.size() != replace.size():
		print_debug("ERRO: Matrizes de tamanhos diferentes. Não foi realizada nenhuma substituição.")
		return []
	for a in data.size():
		for b in replace.size():
			data[a] = data[a].replace(find[b], replace[b])
	return data

## Retorna o semestre letivo atual com base no mês do sistema: [code]"1"[/code] para
## janeiro–julho, [code]"2"[/code] para agosto–dezembro.
static func semestre_atual() -> String:
	return "2" if Time.get_date_dict_from_system()["month"] > 7 else "1"

## Remove acentos e converte para minusculas. Util para normalizar textos de busca
## (codigos, nomes de disciplina) onde "João" deve equivaler a "joao".
static func remover_acentos(s: String) -> String:
	var resultado: String = s.to_lower()
	var mapa: Dictionary = {
		"á": "a", "à": "a", "â": "a", "ã": "a", "ä": "a",
		"é": "e", "è": "e", "ê": "e", "ë": "e",
		"í": "i", "ì": "i", "î": "i", "ï": "i",
		"ó": "o", "ò": "o", "ô": "o", "õ": "o", "ö": "o",
		"ú": "u", "ù": "u", "û": "u", "ü": "u",
		"ç": "c", "ñ": "n",
	}
	for orig in mapa:
		resultado = resultado.replace(orig, mapa[orig])
	return resultado


## Ajusta [param cor] para atingir um contraste mínimo [param alvo] (razão WCAG) contra [param fundo],
## preservando matiz e saturação e variando apenas a luminosidade (valor HSV). [br]
## Quando a matiz, mesmo no extremo de luminosidade, não alcança o [param alvo], reduz a saturação
## progressivamente até conseguir (no limite, um tom de cinza, que sempre alcança). [br]
## Usado para garantir legibilidade das cores semânticas sobre o fundo de qualquer tema.
static func ajustar_contraste(cor: Color, fundo: Color, alvo: float = 4.5) -> Color:
	var fundo_claro: bool = _luminancia_relativa(fundo) > 0.3
	for tentativa in 4:
		var saturacao: float = cor.s * (1.0 - tentativa / 4.0)
		var resultado: Color = _buscar_valor_contraste(cor.h, saturacao, cor.a, fundo, alvo, fundo_claro)
		if _contraste(resultado, fundo) >= alvo - 0.05:
			return resultado
	# Tom de cinza puro: garante o maior alcance de luminosidade possível.
	return _buscar_valor_contraste(cor.h, 0.0, cor.a, fundo, alvo, fundo_claro)

# Busca binária no valor (HSV) que aproxima o contraste do alvo. O contraste é monotônico no valor
# para matiz e saturação fixos: cresce com o valor sobre fundo escuro, decresce sobre fundo claro.
static func _buscar_valor_contraste(matiz: float, saturacao: float, alfa: float, fundo: Color, alvo: float, fundo_claro: bool) -> Color:
	var lo: float = 0.0
	var hi: float = 1.0
	for _i in 24:
		var meio: float = (lo + hi) * 0.5
		var teste: Color = Color.from_hsv(matiz, saturacao, meio, alfa)
		var contraste: float = _contraste(teste, fundo)
		if fundo_claro:
			if contraste > alvo:
				lo = meio
			else:
				hi = meio
		else:
			if contraste < alvo:
				lo = meio
			else:
				hi = meio
	return Color.from_hsv(matiz, saturacao, (lo + hi) * 0.5, alfa)

# Razão de contraste WCAG entre duas cores: (L_claro + 0.05) / (L_escuro + 0.05).
static func _contraste(a: Color, b: Color) -> float:
	var la: float = _luminancia_relativa(a)
	var lb: float = _luminancia_relativa(b)
	return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)

# Luminância relativa (WCAG): soma ponderada dos canais sRGB linearizados.
static func _luminancia_relativa(c: Color) -> float:
	return 0.2126 * _canal_linear(c.r) + 0.7152 * _canal_linear(c.g) + 0.0722 * _canal_linear(c.b)

# Lineariza um canal sRGB (0..1) para cálculo de luminância.
static func _canal_linear(v: float) -> float:
	if v <= 0.03928:
		return v / 12.92
	return pow((v + 0.055) / 1.055, 2.4)


static func merge_profundo(base: Dictionary, over: Dictionary) -> Dictionary:
	var resultado: Dictionary = base.duplicate(true)
	for chave in over:
		if resultado.has(chave) and resultado[chave] is Dictionary and over[chave] is Dictionary:
			resultado[chave] = merge_profundo(resultado[chave], over[chave])
		else:
			resultado[chave] = over[chave]
	return resultado


static func definir_por_caminho(dict: Dictionary, caminho: Array, valor: Variant) -> void:
	var atual: Dictionary = dict
	for i in caminho.size() - 1:
		var chave: String = caminho[i]
		if not atual.has(chave) or not atual[chave] is Dictionary:
			atual[chave] = {}
		atual = atual[chave]
	atual[caminho[caminho.size() - 1]] = valor
