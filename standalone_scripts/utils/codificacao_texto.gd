class_name CodificacaoTexto extends RefCounted
## Deteccao e conversao de codificacao de texto sobre bytes, sem I/O. Estatico e puro. [br]
## Guarda a unica tabela Windows-1252 de [code]0x80[/code]-[code]0x9F[/code], usada nos dois
## sentidos: [method cp1252_para_utf8] e [method texto_para_cp1252].

# Indice = byte - 0x80; -1 marca os cinco bytes sem caractere (0x81, 0x8D, 0x8F, 0x90, 0x9D).
const _CP1252_80_9F: Array[int] = [
	0x20AC, -1, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021,
	0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, -1, 0x017D, -1,
	-1, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
	0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, -1, 0x017E, 0x0178,
]

## Devolve [code]true[/code] se e somente se [param bytes] e UTF-8 bem formado (Tabela 3-7 do
## Unicode). Vazio, BOM e U+FFFD codificado sao validos. Nao usa decodificador do motor, entao
## nao registra [code]Unicode parsing error[/code]; sai no primeiro byte invalido.
static func eh_utf8_valido(bytes: PackedByteArray) -> bool:
	var n: int = bytes.size()
	var i: int = 0
	while i < n:
		var b: int = bytes[i]
		if b < 0x80:
			i += 1
			continue
		var extras: int
		var min2: int = 0x80
		var max2: int = 0xBF
		if b >= 0xC2 and b <= 0xDF:
			extras = 1
		elif b >= 0xE0 and b <= 0xEF:
			extras = 2
			if b == 0xE0:
				min2 = 0xA0
			elif b == 0xED:
				max2 = 0x9F
		elif b >= 0xF0 and b <= 0xF4:
			extras = 3
			if b == 0xF0:
				min2 = 0x90
			elif b == 0xF4:
				max2 = 0x8F
		else:
			return false
		if i + extras >= n:
			return false
		var b2: int = bytes[i + 1]
		if b2 < min2 or b2 > max2:
			return false
		for k in range(2, extras + 1):
			var c: int = bytes[i + k]
			if c < 0x80 or c > 0xBF:
				return false
		i += extras + 1
	return true

## Converte [param bytes] em Windows-1252 para os bytes UTF-8 do texto equivalente. ASCII sai
## igual (inclusive [code]00[/code], CR e LF); os cinco bytes sem caractere viram U+FFFD sem
## interromper. Nao acrescenta BOM.
static func cp1252_para_utf8(bytes: PackedByteArray) -> PackedByteArray:
	var n: int = bytes.size()
	var saida: PackedByteArray = PackedByteArray()
	saida.resize(n * 3)
	var j: int = 0
	for i in n:
		var b: int = bytes[i]
		if b < 0x80:
			saida[j] = b
			j += 1
			continue
		var cp: int = b
		if b < 0xA0:
			cp = _CP1252_80_9F[b - 0x80]
			if cp < 0:
				cp = 0xFFFD
		if cp < 0x800:
			saida[j] = 0xC0 | (cp >> 6)
			saida[j + 1] = 0x80 | (cp & 0x3F)
			j += 2
		else:
			saida[j] = 0xE0 | (cp >> 12)
			saida[j + 1] = 0x80 | ((cp >> 6) & 0x3F)
			saida[j + 2] = 0x80 | (cp & 0x3F)
			j += 3
	saida.resize(j)
	return saida

## Converte [param texto] para bytes Windows-1252, um byte por caractere. O que nao tem
## mapeamento (inclusive U+FFFD e os controles C1) vira [code]?[/code].
static func texto_para_cp1252(texto: String) -> PackedByteArray:
	var saida: PackedByteArray = PackedByteArray()
	saida.resize(texto.length())
	for i in texto.length():
		var cp: int = texto.unicode_at(i)
		if cp <= 0x7F or (cp >= 0xA0 and cp <= 0xFF):
			saida[i] = cp
			continue
		var indice: int = _CP1252_80_9F.find(cp)
		saida[i] = 0x80 + indice if indice >= 0 else 0x3F
	return saida
