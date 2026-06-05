class_name FileSelector extends ReferenceRect
## Utilizado para selecionar os arquivos necessários para o programa.

signal filepath_selected(file_path,id)
signal folderpath_selected(folder_path,id)
signal multiplefiles_selected(multiple_file_paths,id)

## Identificador único para uso ao instanciar.
var id: String = ""

## O endereço que será aberto no navegador ao clicar no botão.
var site_link: String = ""

## Status de cor do indicador do seletor.
var status: String = "white" : set = _status_changed

## Texto do botão.
var button_text: String = "": set = _buttontext_changed

## Texto que aparece ao lado direito.
var right_text: String = "" : set = _text_changed

## Path to the last selected file.
var file_path: String = ""

## Path to multiple selected files.
var multiple_file_paths: PackedStringArray = []

## Path to the last selected folder.
var folder_path: String = ""

## See [enum FileDialog.FileMode].
var file_mode: int = 0 : set = _filemode_changed

## Filtros para o FileDialog, no formato Godot ("*.txt : Descricao").
var filters: PackedStringArray = [] : set = _set_filters

func _ready() -> void:
	$FileDialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)

#region Setgets
func _status_changed(new_value: String) -> void:
	status = new_value
	if status == "green":
		$Status.set_color(PaletaSemantica.cor("sucesso"))
	if status == "red":
		$Status.set_color(PaletaSemantica.cor("erro"))
	if status == "gray":
		# Cor neutra para arquivos opcionais ausentes (não bloqueia, só indica).
		$Status.set_color(PaletaSemantica.cor("neutro"))

func _buttontext_changed(new_value: String) -> void:
	button_text = new_value
	$ReferenceRect/BotaoSite.set_text(button_text)

func _text_changed(new_value: String) -> void:
	right_text = new_value
	$ReferenceRect/Text.set_text(right_text)

func _filemode_changed(new_value: int) -> void:
	file_mode = new_value
	$FileDialog.set_file_mode(file_mode)

func _set_filters(new_value: PackedStringArray) -> void:
	filters = new_value
	$FileDialog.clear_filters()
	for f in filters:
		$FileDialog.add_filter(f)
#endregion

#region botões e sinais
func _on_botao_pasta_button_up() -> void:
	$FileDialog.popup_centered()
	Dialogos.limitar_a_tela($FileDialog)

func _on_botao_site_button_up() -> void:
	if site_link.begins_with("http"):
		OS.shell_open(site_link)
	else:
		print_debug(site_link)

func _on_file_dialog_file_selected(path: String) -> void:
	file_path = path
	emit_signal("filepath_selected", file_path, id)

func _on_file_dialog_dir_selected(dir: String) -> void:
	folder_path = dir
	emit_signal("folderpath_selected",folder_path, id)

func _on_file_dialog_files_selected(paths: PackedStringArray) -> void:
	multiple_file_paths = paths
	emit_signal("multiplefiles_selected",multiple_file_paths, id)
#endregion
