class_name AplicadorVisualGrade extends RefCounted
## Decide, num único ponto determinístico, a aparência de cada célula da grade de horários. [br]
##
## Substitui a pintura antes espalhada (gerenciador, detector de choques, verificador de carga e
## filtro), que se sobrescreviam em ordem frágil. Recebe por célula um dicionário de condições
## (ver [method aplicar]) e aplica as camadas semânticas: [br]
## - [b]fundo[/b] = foco do filtro; [br]
## - [b]barra de cima[/b] = preferência do professor (não é tocada aqui — vem do dado da grade); [br]
## - [b]barras esquerda/direita/baixo[/b] = alertas, com [b]cor = severidade[/b] (token da
##   [PaletaSemantica]) e [b]lado = categoria[/b] do problema; [br]
## - [b]cor do texto[/b] = estado da alocação (sem professor, hora extra, normal ou esmaecido). [br]
##
## O tipo exato de cada alerta (professor vs sala vs semestre, etc.) não é codificado na cor: vai
## no tooltip da célula (ver [method aplicar], chave [code]tooltip[/code]).

# Fundo de uma célula em foco (passa no filtro ativo) e fundo neutro padrão.
const FUNDO_FOCO := Color("#1a3a1a")
# Verde claro para as células da disciplina destacada (clique em um card), com precedência sobre o foco.
const FUNDO_DESTAQUE_DISCIPLINA := Color("#2f6b2f")
const FUNDO_PADRAO := Color(0.173, 0.173, 0.173, 1)
const SEM_BARRA := Color(0, 0, 0, 0)

var _grade: GradeVisual


## Injeta a grade visual onde as células são pintadas.
func configurar(grade: GradeVisual) -> void:
	_grade = grade


## Aplica todas as camadas visuais da célula em [param linha], [param coluna] a partir de
## [param cond]. Chaves reconhecidas (todas opcionais, default falso): [br]
## [code]tem_filtro[/code], [code]em_foco[/code] (foco do filtro); [code]sem_professor[/code],
## [code]hora_extra[/code] (estado); [code]choque_prof[/code], [code]choque_sala[/code],
## [code]choque_sem[/code], [code]ch_excedida[/code], [code]carga[/code], [code]noturna[/code]
## (alertas); [code]tooltip[/code] (BBCode da dica da célula, ver Fase 2). [br]
## Idempotente: limpa as barras de alerta ausentes. A barra de cima (preferência) é preservada.
func aplicar(linha: int, coluna: int, cond: Dictionary) -> void:
	if not _grade or linha < 0 or coluna < 0 or linha >= _grade._linhas or coluna >= _grade._colunas:
		return
	var celula: Celula = _grade.get_celula(linha, coluna)
	if not celula:
		return
	var tem_filtro: bool = cond.get("tem_filtro", false)
	var em_foco: bool = cond.get("em_foco", true)
	# Alertas só aparecem na célula em foco (ou quando não há filtro). Fora do foco a célula fica
	# esmaecida, sem barras — os problemas seguem contabilizados no terminal.
	var mostrar_alertas: bool = (not tem_filtro) or em_foco

	# --- Fundo: verde claro para a disciplina destacada (clique em card); senão, foco do filtro ---
	if cond.get("destaque_disciplina", false):
		celula.cor_fundo = FUNDO_DESTAQUE_DISCIPLINA
	elif tem_filtro and em_foco:
		celula.cor_fundo = FUNDO_FOCO
	else:
		celula.cor_fundo = FUNDO_PADRAO

	# --- Cor do texto: estado da alocação ---
	# Usa cor_central (token) e zera cor_texto_override, evitando que o override (precedência sobre
	# cor_central em celula.gd) apague a sinalização de estado — o bug do esquema antigo.
	celula.cor_texto_override = Color.TRANSPARENT
	if tem_filtro and not em_foco:
		celula.cor_central = "neutro"
	elif cond.get("sem_professor", false):
		celula.cor_central = "erro"
	elif cond.get("hora_extra", false):
		celula.cor_central = "ch_extra"
	else:
		celula.cor_central = "padrao"

	# --- Barras de alerta: cor = severidade, lado = categoria ---
	var baixo := SEM_BARRA
	var esquerda := SEM_BARRA
	var direita := SEM_BARRA
	if mostrar_alertas:
		# Baixo = choque de recurso. Erro se prof/semestre; aviso se só sala.
		if cond.get("choque_prof", false) or cond.get("choque_sem", false):
			baixo = PaletaSemantica.cor("erro")
		elif cond.get("choque_sala", false):
			baixo = PaletaSemantica.cor("aviso")
		# Esquerda = sobrecarga do professor (carga 6h / noturna→manhã).
		if cond.get("carga", false) or cond.get("noturna", false):
			esquerda = PaletaSemantica.cor("aviso")
		# Direita = problema da disciplina (CH excedida).
		if cond.get("ch_excedida", false):
			direita = PaletaSemantica.cor("aviso")
	celula.cor_barra_baixo = baixo
	celula.cor_barra_esquerda = esquerda
	celula.cor_barra_direita = direita
	# cor_barra_cima (preferência do professor) é preservada — não é tocada aqui.

	# --- Tooltip da célula (Fase 2) ---
	DicaFlutuante.vincular(celula, str(cond.get("tooltip", "")))
