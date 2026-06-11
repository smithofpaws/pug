class_name GradeCurricular extends VBoxContainer
## Apresenta a grade curricular do discente selecionado, colorindo cada disciplina obrigatória
## conforme sua situação.
##
## Recebe [param dados] (matriz bidimensional no formato de [Grade]) e repassa ao componente interno.

signal listaopcoes_alterada(opcao: String)
signal celula_selecionada(codigo: String)
signal celula_selecionada_direita(codigo: String)
## Emitido quando o usuário escolhe outra grade no [code]SeletorGrade[/code] (só relevante quando
## [member lista_grades] foi preenchida, ex.: no Planejamento de Oferta).
signal grade_alterada(grade_nome: String)

## Referência ao nó Grade, obtida via [code]get_node_or_null[/code] para evitar erro caso a cena esteja mal configurada.
@onready var _grade := get_node_or_null("Grade")

## Opções de exibição da grade: rótulos visíveis e valores internos.
var _lista_opcoes: Dictionary = {
	"_lista*": ["Somente Código", "Nome da Disciplina", "Nome Reduzido", "Código + Nome", "Código + Nome Reduzido"],
	"_lista_retorno": ["somente_codigo", "nome_completo", "nome_reduzido", "codigo_e_nome", "codigo_e_nome_reduzido"]
}

## Matriz bidimensional a ser apresentada, no formato esperado por [Grade]. [br]
## Geralmente vem de [method AnaliseGrades.montar_grade_curricular].
var dados: Array[Array] = [] : set = _set_dados

## Linhas de pré-requisito a desenhar sobre a grade. Repassada a [member Grade.conexoes]. [br]
## Geralmente vem de [method AnaliseGrades.montar_conexoes].
var conexoes: Array = [] : set = _set_conexoes

## Lista de grades selecionáveis (chaves no padrão [code]<cod_curso>_<versao>[/code]). Quando preenchida,
## exibe o [code]SeletorGrade[/code] e permite escolher qual grade desenhar (ex.: Planejamento de Oferta).
## Vazia (padrão) mantém o seletor oculto — comportamento usado por SituacaoAlunos, onde a grade é derivada
## do discente.
var lista_grades: Array = [] : set = _set_lista_grades

#region Inicialização
func _ready() -> void:
	$Grade/GridContainer.add_theme_constant_override("h_separation", 10)
	$Grade/GridContainer.add_theme_constant_override("v_separation", 10)
	if _grade:
		_grade.larguras_colunas = [40.0]
	$"%SeletorOpcoes".lista_itens = _lista_opcoes
	# Marca a primeira opção visualmente sem disparar sinal.
	$"%SeletorOpcoes".get_node("MenuButton").get_popup().set_item_checked(2, true)
	$"%SeletorGrade".opcao_selecionada.connect(_on_seletor_grade_opcao_selecionada)
	# Aplica a lista de grades caso tenha sido definida antes de [method _ready].
	_aplicar_lista_grades()
	if _grade:
		_grade.celula_clicada.connect(_on_grade_celula_clicada)
		_grade.celula_clicada_direita.connect(_on_grade_celula_clicada_direita)
#endregion

#region Seletor de grade
# Aplica [member lista_grades] ao SeletorGrade, mostrando-o quando há grades e ocultando quando vazio.
func _aplicar_lista_grades() -> void:
	var sg := get_node_or_null("%SeletorGrade")
	if sg == null:
		return
	if lista_grades.is_empty():
		sg.visible = false
		return
	sg.popular("grades", lista_grades.duplicate(), lista_grades.duplicate())
	sg.visible = true

## Seleciona uma grade no SeletorGrade pelo nome (dispara [signal grade_alterada]).
func selecionar_grade(grade_nome: String) -> void:
	var idx: int = lista_grades.find(grade_nome)
	if idx < 0:
		return
	$"%SeletorGrade".selecionar_item(idx)

func _on_seletor_grade_opcao_selecionada(retorno: String, _lista_selecionada: Array) -> void:
	emit_signal("grade_alterada", retorno)
#endregion

#region Sinais
func _on_seletor_opcoes_opcao_selecionada(_retorno: String, _lista_selecionada: Array) -> void:
	emit_signal("listaopcoes_alterada", _retorno)

func _on_grade_celula_clicada(linha: int, coluna: int) -> void:
	var codigo: String = _codigo_na_posicao(linha, coluna)
	if codigo != "":
		celula_selecionada.emit(codigo)

func _on_grade_celula_clicada_direita(linha: int, coluna: int) -> void:
	var codigo: String = _codigo_na_posicao(linha, coluna)
	if codigo != "":
		celula_selecionada_direita.emit(codigo)

## Extrai o código da disciplina na posição [param linha],[param coluna] da matriz [member dados].
func _codigo_na_posicao(linha: int, coluna: int) -> String:
	if linha >= dados.size() or coluna >= dados[linha].size():
		return ""
	var celula = dados[linha][coluna]
	if celula is Dictionary and celula.has("codigo"):
		return str(celula["codigo"])
	return ""
#endregion

#region Setgets
func _set_dados(new_state: Array[Array]) -> void:
	dados = new_state
	if _grade:
		_grade.dados = dados

func _set_conexoes(new_state: Array) -> void:
	conexoes = new_state
	if _grade:
		_grade.conexoes = conexoes

func _set_lista_grades(new_state: Array) -> void:
	lista_grades = new_state
	_aplicar_lista_grades()
#endregion
