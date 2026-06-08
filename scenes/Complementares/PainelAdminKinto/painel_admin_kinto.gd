class_name PainelAdminKinto extends AcceptDialog
## Painel de administracao do servidor Kinto, acessivel pelas Configuracoes.
##
## Permite ao administrador (autenticado com a senha de admin) gerenciar contas de coordenadores,
## o grupo [code]coordenadores[/code], os planos enviados (records) e as permissoes da collection —
## tudo pela interface, sem linha de comando. Usa um [SyncKintoAdmin] proprio (credenciais de admin),
## separado do [code]_sync[/code] do coordenador. [br]
## [br]
## I/O de credencial: a senha de admin so e gravada se "Lembrar nesta maquina" estiver marcado, e vai
## para [code]user://[/code] (fora do OneDrive) via [main.gd] (sinais [signal salvar_segredo_admin] /
## [signal apagar_segredo_admin]) — nunca em config_usuario.json.

## Emitido ao conectar com "Lembrar" marcado: o main grava o segredo em user://admin_kinto.json.
signal salvar_segredo_admin(usuario: String, senha: String)
## Emitido ao conectar com "Lembrar" desmarcado: o main apaga o user://admin_kinto.json (se existir).
signal apagar_segredo_admin()

## Emitido ao mesclar o campus: o main grava o plano agregado como planejamento.json em exportacoes/.
signal salvar_campus_local(plano: Dictionary)

var _admin: SyncKintoAdmin

# Campos da aba Autenticacao.
var _ed_url: LineEdit
var _ed_user: LineEdit
var _ed_senha: LineEdit
var _chk_lembrar: CheckBox
var _lbl_auth: Label

# Abas (desabilitadas ate autenticar).
var _abas: TabContainer

# Aba Usuarios.
var _lista_usuarios: ItemList
var _ed_novo_user: LineEdit
var _ed_nova_senha: LineEdit
var _lbl_user: Label

# Aba Planos.
var _lista_planos: ItemList
var _planos_ids: Array[String] = []
var _lbl_planos: Label

# Aba Permissoes.
var _lbl_perms: Label

# Aba Campus (mesclar).
var _lista_campus: ItemList
var _campus_registros: Array = []
var _lbl_campus: Label


func _ready() -> void:
	title = "Administração do servidor"
	get_ok_button().text = "Fechar"
	# Abre alto o suficiente para mostrar os botoes no fim das abas sem rolar (a aba Usuarios e a mais
	# alta). Em telas baixas, Dialogos.limitar_a_tela reduz e o ScrollContainer rola (ver _envolver_scroll).
	min_size = Vector2i(560, 620)
	_admin = SyncKintoAdmin.new()
	add_child(_admin)
	_construir()


## Injeta a URL do servidor (a mesma do coordenador) e o segredo lembrado ({usuario, senha} ou {}).
func configurar(url: String, segredo: Dictionary) -> void:
	if _ed_url == null:
		await ready
	_ed_url.text = url
	_ed_user.text = str(segredo.get("usuario", ""))
	_ed_senha.text = str(segredo.get("senha", ""))
	_chk_lembrar.button_pressed = not str(segredo.get("senha", "")).is_empty()


# ───────────────────────── Construcao da UI ─────────────────────────

func _construir() -> void:
	_abas = TabContainer.new()
	_abas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_abas)
	_abas.add_child(_envolver_scroll("Autenticação", _aba_autenticacao()))
	_abas.add_child(_envolver_scroll("Usuários", _aba_usuarios()))
	_abas.add_child(_envolver_scroll("Planos enviados", _aba_planos()))
	_abas.add_child(_envolver_scroll("Permissões", _aba_permissoes()))
	_abas.add_child(_envolver_scroll("Campus (mesclar)", _aba_campus()))
	_definir_abas_habilitadas(false)


# Envolve o conteudo de uma aba num ScrollContainer (rolagem vertical) para que, quando a janela
# encolher (Dialogos.limitar_a_tela em telas baixas), o conteudo role em vez de empurrar a janela
# para fora da tela — o problema recorrente de diálogos maiores que a janela do app. O nome do
# ScrollContainer vira o título da aba no TabContainer.
func _envolver_scroll(nome: String, conteudo: Control) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = nome
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	conteudo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(conteudo)
	return scroll


# Helper: cria um campo rotulado (Label + LineEdit) e devolve o LineEdit.
func _campo(pai: Control, rotulo: String, secreto: bool = false) -> LineEdit:
	var lbl := Label.new()
	lbl.text = rotulo
	pai.add_child(lbl)
	var ed := LineEdit.new()
	ed.secret = secreto
	pai.add_child(ed)
	return ed


func _aba_autenticacao() -> Control:
	var vbox := VBoxContainer.new()
	vbox.name = "Autenticação"
	_ed_url = _campo(vbox, "Servidor (URL):")
	_ed_user = _campo(vbox, "Usuário admin:")
	_ed_senha = _campo(vbox, "Senha admin:", true)
	_chk_lembrar = CheckBox.new()
	_chk_lembrar.text = "Lembrar senha"
	DicaFlutuante.vincular(_chk_lembrar, "Grava a senha de administrador nesta máquina, em %APPDATA% " \
		+ "(fora do OneDrive, portanto não sincroniza com os outros PCs).\n" \
		+ "[b]Atenção:[/b] a senha fica em texto puro no arquivo — só marque em um computador de sua confiança.")
	vbox.add_child(_chk_lembrar)
	var bt := Button.new()
	bt.text = "Conectar"
	bt.pressed.connect(_conectar)
	vbox.add_child(bt)
	_lbl_auth = Label.new()
	_lbl_auth.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_lbl_auth)
	return vbox


func _aba_usuarios() -> Control:
	var vbox := VBoxContainer.new()
	vbox.name = "Usuários"
	var lbl := Label.new()
	lbl.text = "Coordenadores (membros do grupo \"%s\"):" % SyncKintoAdmin.GRUPO_COORDENADORES
	vbox.add_child(lbl)
	_lista_usuarios = ItemList.new()
	_lista_usuarios.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lista_usuarios.custom_minimum_size = Vector2(0, 150)
	vbox.add_child(_lista_usuarios)
	_ed_novo_user = _campo(vbox, "Usuário:")
	_ed_nova_senha = _campo(vbox, "Senha:", true)
	var linha := HBoxContainer.new()
	vbox.add_child(linha)
	var bt_criar := Button.new()
	bt_criar.text = "Criar"
	bt_criar.pressed.connect(_criar_usuario)
	linha.add_child(bt_criar)
	var bt_redef := Button.new()
	bt_redef.text = "Redefinir senha"
	bt_redef.pressed.connect(_redefinir_senha)
	linha.add_child(bt_redef)
	var bt_apagar := Button.new()
	bt_apagar.text = "Apagar usuário"
	bt_apagar.pressed.connect(_apagar_usuario)
	linha.add_child(bt_apagar)
	_lbl_user = Label.new()
	_lbl_user.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_lbl_user)
	var aviso := Label.new()
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aviso.text = "Apagar o usuário NÃO apaga o plano enviado por ele (use a aba Planos)."
	vbox.add_child(aviso)
	return vbox


func _aba_planos() -> Control:
	var vbox := VBoxContainer.new()
	vbox.name = "Planos enviados"
	var lbl := Label.new()
	lbl.text = "Planos no servidor (1 por curso):"
	vbox.add_child(lbl)
	_lista_planos = ItemList.new()
	_lista_planos.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lista_planos.custom_minimum_size = Vector2(0, 200)
	vbox.add_child(_lista_planos)
	var linha := HBoxContainer.new()
	vbox.add_child(linha)
	var bt_atualizar := Button.new()
	bt_atualizar.text = "Atualizar lista"
	bt_atualizar.pressed.connect(_carregar_planos)
	linha.add_child(bt_atualizar)
	var bt_apagar := Button.new()
	bt_apagar.text = "Apagar plano selecionado"
	bt_apagar.pressed.connect(_apagar_plano)
	linha.add_child(bt_apagar)
	_lbl_planos = Label.new()
	_lbl_planos.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_lbl_planos)
	return vbox


func _aba_permissoes() -> Control:
	var vbox := VBoxContainer.new()
	vbox.name = "Permissões"
	var intro := Label.new()
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.text = "Quem pode fazer o quê com os planos no servidor. Normalmente não é preciso mexer " + \
		"aqui — só use o botão de liberar envio se algum coordenador receber erro de permissão ao enviar."
	vbox.add_child(intro)
	var titulo := Label.new()
	titulo.text = "Situação atual:"
	vbox.add_child(titulo)
	_lbl_perms = Label.new()
	_lbl_perms.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_lbl_perms)
	var linha := HBoxContainer.new()
	vbox.add_child(linha)
	var bt := Button.new()
	bt.text = "Liberar envio para os coordenadores"
	DicaFlutuante.vincular(bt, "Garante que todos os coordenadores (membros do grupo) possam enviar " \
		+ "o plano do próprio curso.\nUse só se algum receber erro de permissão ao enviar.")
	bt.pressed.connect(_garantir_create_grupo)
	linha.add_child(bt)
	var bt2 := Button.new()
	bt2.text = "Atualizar"
	DicaFlutuante.vincular(bt2, "Relê do servidor a lista de permissões mostrada acima.")
	bt2.pressed.connect(_carregar_permissoes)
	linha.add_child(bt2)
	return vbox


func _aba_campus() -> Control:
	var vbox := VBoxContainer.new()
	vbox.name = "Campus"
	var lbl := Label.new()
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.text = "Mescla os planos dos cursos escolhidos num plano único do campus. Segure Ctrl/Shift " + \
		"para selecionar vários:"
	vbox.add_child(lbl)
	_lista_campus = ItemList.new()
	_lista_campus.select_mode = ItemList.SELECT_MULTI
	_lista_campus.custom_minimum_size = Vector2(0, 160)
	vbox.add_child(_lista_campus)
	var linha := HBoxContainer.new()
	vbox.add_child(linha)
	var bt_atualizar := Button.new()
	bt_atualizar.text = "Atualizar lista"
	bt_atualizar.pressed.connect(_carregar_campus)
	linha.add_child(bt_atualizar)
	var bt_mesclar := Button.new()
	bt_mesclar.text = "Mesclar e publicar campus"
	bt_mesclar.pressed.connect(_mesclar)
	linha.add_child(bt_mesclar)
	_lbl_campus = Label.new()
	_lbl_campus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_lbl_campus)
	var aviso := Label.new()
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aviso.text = "O resultado é salvo como planejamento.json local e publicado como o plano 'campus' " + \
		"no servidor. Disciplinas compartilhadas iguais são unificadas; horários divergentes viram " + \
		"conflito para você resolver."
	vbox.add_child(aviso)
	return vbox


func _definir_abas_habilitadas(ligado: bool) -> void:
	# Mantem a aba 0 (Autenticacao) sempre ativa; liga/desliga as demais.
	for i in range(1, _abas.get_tab_count()):
		_abas.set_tab_disabled(i, not ligado)


# ───────────────────────── Autenticacao ─────────────────────────

func _conectar() -> void:
	_admin.configurar(_ed_url.text, _ed_user.text, _ed_senha.text)
	if not _admin.esta_configurado():
		_lbl_auth.text = "Preencha servidor, usuário e senha."
		return
	_lbl_auth.text = "Conectando..."
	var r: Dictionary = await _admin.testar_admin()
	if not r.get("ok", false):
		_definir_abas_habilitadas(false)
		_lbl_auth.text = "Falha: " + str(r.get("erro", ""))
		return
	_lbl_auth.text = "Conectado como administrador."
	_definir_abas_habilitadas(true)
	if _chk_lembrar.button_pressed:
		salvar_segredo_admin.emit(_ed_user.text, _ed_senha.text)
	else:
		apagar_segredo_admin.emit()
	# Sequencial (await): o cliente admin atende uma requisicao por vez (guarda _ocupado). Disparar as
	# tres de uma vez faria as duas ultimas falharem com "ja existe uma sincronizacao em andamento".
	await _carregar_usuarios()
	await _carregar_planos()
	await _carregar_permissoes()
	await _carregar_campus()


# ───────────────────────── Usuarios ─────────────────────────

func _carregar_usuarios() -> void:
	_lista_usuarios.clear()
	var r: Dictionary = await _admin.obter_grupo(SyncKintoAdmin.GRUPO_COORDENADORES)
	if not r.get("ok", false):
		# 404: o grupo ainda nao existe como objeto — sera criado ao adicionar o 1o coordenador.
		if int(r.get("codigo", 0)) == 404:
			_lbl_user.text = "Nenhum coordenador ainda. O grupo será criado ao adicionar o primeiro."
		else:
			_lbl_user.text = "Não foi possível ler o grupo: " + str(r.get("erro", ""))
		return
	var membros: Array = []
	if r.get("dados") is Dictionary:
		membros = r["dados"].get("data", {}).get("members", [])
	for m in membros:
		# Mostra o nome limpo, mas guarda o principal cru (account:x) em metadata para apagar/remover.
		var idx: int = _lista_usuarios.add_item(_principal_legivel(str(m)))
		_lista_usuarios.set_item_metadata(idx, str(m))


# Le os membros atuais do grupo (read-modify-write). Retorna o Array de principais ou [] em falha.
func _membros_grupo_atual() -> Array:
	var r: Dictionary = await _admin.obter_grupo(SyncKintoAdmin.GRUPO_COORDENADORES)
	if r.get("ok", false) and r.get("dados") is Dictionary:
		return r["dados"].get("data", {}).get("members", [])
	return []


# O Kinto rejeita ids de conta que nao comecem por letra/numero (ex.: "_teste" -> 400 Invalid object
# id). Valida antes de enviar para o admin nao tropecar nesse erro.
func _usuario_valido(u: String) -> bool:
	var re := RegEx.new()
	re.compile("^[a-zA-Z0-9][a-zA-Z0-9_-]*$")
	return re.search(u) != null


func _criar_usuario() -> void:
	var u: String = _ed_novo_user.text.strip_edges()
	# Senha SEM strip_edges(): preserva espaco no inicio/fim de proposito. O coordenador tambem nao
	# limpa o token no envio (sincronizacao.gd), entao a senha bate byte a byte com o servidor.
	var s: String = _ed_nova_senha.text
	if u.is_empty() or s.is_empty():
		_lbl_user.text = "Informe usuário e senha."
		return
	if not _usuario_valido(u):
		_lbl_user.text = "Usuário inválido: use só letras, números, '-' e '_', começando por letra ou número."
		return
	var r: Dictionary = await _admin.criar_ou_redefinir_conta(u, s)
	if not r.get("ok", false):
		_lbl_user.text = "Falha ao criar conta: " + str(r.get("erro", ""))
		return
	# Adiciona ao grupo coordenadores (read-modify-write).
	var membros: Array = await _membros_grupo_atual()
	var principal: String = "account:" + u
	if not membros.has(principal):
		membros.append(principal)
		var rg: Dictionary = await _admin.definir_membros_grupo(SyncKintoAdmin.GRUPO_COORDENADORES, membros)
		if not rg.get("ok", false):
			_lbl_user.text = "Conta criada, mas falhou ao adicionar ao grupo: " + str(rg.get("erro", ""))
			_carregar_usuarios()
			return
	_lbl_user.text = "Usuário '%s' criado e adicionado ao grupo." % u
	_ed_novo_user.text = ""
	_ed_nova_senha.text = ""
	_carregar_usuarios()


func _redefinir_senha() -> void:
	var u: String = _ed_novo_user.text.strip_edges()
	var s: String = _ed_nova_senha.text  # sem strip_edges(): ver _criar_usuario.
	if u.is_empty() or s.is_empty():
		_lbl_user.text = "Informe o usuário e a nova senha."
		return
	Dialogos.confirmar(self, "Redefinir senha", \
		"Redefinir a senha do usuário '%s'? A senha atual dele deixará de funcionar." % u, \
		_redefinir_senha_confirmado.bind(u, s), "Redefinir")


func _redefinir_senha_confirmado(u: String, s: String) -> void:
	var r: Dictionary = await _admin.criar_ou_redefinir_conta(u, s)
	if r.get("ok", false):
		_lbl_user.text = "Senha de '%s' redefinida." % u
		_ed_nova_senha.text = ""
	else:
		_lbl_user.text = "Falha: " + str(r.get("erro", ""))


func _apagar_usuario() -> void:
	var sel: PackedInt32Array = _lista_usuarios.get_selected_items()
	if sel.is_empty():
		_lbl_user.text = "Selecione um usuário na lista para apagar."
		return
	var principal: String = str(_lista_usuarios.get_item_metadata(sel[0]))
	var u: String = principal.trim_prefix("account:")
	Dialogos.confirmar(self, "Apagar usuário", \
		"Apagar a conta '%s' e removê-la do grupo? Isso NÃO apaga o plano que ela enviou." % u, \
		_apagar_usuario_confirmado.bind(u, principal), "Apagar")


func _apagar_usuario_confirmado(u: String, principal: String) -> void:
	var r: Dictionary = await _admin.apagar_conta(u)
	if not r.get("ok", false):
		_lbl_user.text = "Falha ao apagar conta: " + str(r.get("erro", ""))
		return
	var membros: Array = await _membros_grupo_atual()
	membros.erase(principal)
	await _admin.definir_membros_grupo(SyncKintoAdmin.GRUPO_COORDENADORES, membros)
	_lbl_user.text = "Usuário '%s' apagado." % u
	_carregar_usuarios()


# ───────────────────────── Planos enviados ─────────────────────────

func _carregar_planos() -> void:
	_lista_planos.clear()
	_planos_ids.clear()
	var r: Dictionary = await _admin.listar()
	if not r.get("ok", false):
		_lbl_planos.text = "Falha ao listar: " + str(r.get("erro", ""))
		return
	var registros: Array = []
	if r.get("dados") is Dictionary:
		registros = r["dados"].get("data", [])
	for rec in registros:
		if not rec is Dictionary:
			continue
		var id_rec: String = str(rec.get("id", ""))
		_lista_planos.add_item("%s — enviado por %s em %s" \
			% [id_rec, str(rec.get("enviado_por", "?")), str(rec.get("enviado_em", "?"))])
		_planos_ids.append(id_rec)
	if registros.is_empty():
		_lbl_planos.text = "Nenhum plano no servidor."


func _apagar_plano() -> void:
	var sel: PackedInt32Array = _lista_planos.get_selected_items()
	if sel.is_empty():
		_lbl_planos.text = "Selecione um plano para apagar."
		return
	var id_rec: String = _planos_ids[sel[0]]
	Dialogos.confirmar(self, "Apagar plano", \
		"Apagar o plano '%s' do servidor? Esta ação não pode ser desfeita." % id_rec, \
		_apagar_plano_confirmado.bind(id_rec), "Apagar")


func _apagar_plano_confirmado(id_rec: String) -> void:
	var r: Dictionary = await _admin.apagar_record(id_rec)
	if r.get("ok", false):
		_lbl_planos.text = "Plano '%s' apagado." % id_rec
		_carregar_planos()
	else:
		_lbl_planos.text = "Falha: " + str(r.get("erro", ""))


# ───────────────────────── Permissoes ─────────────────────────

func _carregar_permissoes() -> void:
	var r: Dictionary = await _admin.obter_collection()
	if not r.get("ok", false):
		_lbl_perms.text = "Falha ao ler permissões: " + str(r.get("erro", ""))
		return
	var perms: Dictionary = {}
	if r.get("dados") is Dictionary:
		perms = r["dados"].get("permissions", {})
	var linhas: Array[String] = []
	for chave in perms:
		var quem := PackedStringArray()
		for p in perms[chave]:
			quem.append(_principal_legivel(str(p)))
		linhas.append("• %s: %s" % [_acao_legivel(str(chave)), ", ".join(quem)])
	_lbl_perms.text = "\n".join(linhas) if not linhas.is_empty() else "(nenhuma permissão específica definida)"


# Traduz as chaves de permissao do Kinto (read/write/record:create) para algo legivel ao admin.
func _acao_legivel(acao: String) -> String:
	match acao:
		"read": return "Podem ver os planos"
		"write": return "Podem administrar (editar/apagar tudo)"
		"record:create": return "Podem enviar planos"
		_: return acao


# Traduz um principal do Kinto (account:x, grupo, system.*) para texto legivel ao admin.
func _principal_legivel(principal: String) -> String:
	if principal.begins_with("account:"):
		return principal.trim_prefix("account:")
	if principal.ends_with("/groups/" + SyncKintoAdmin.GRUPO_COORDENADORES):
		return "Coordenadores (grupo)"
	if principal.begins_with("/buckets/") and principal.contains("/groups/"):
		return "grupo " + principal.get_slice("/groups/", 1)
	match principal:
		"system.Authenticated": return "qualquer usuário autenticado"
		"system.Everyone": return "qualquer um (acesso público)"
		_: return principal


func _garantir_create_grupo() -> void:
	var grupo_principal: String = "/buckets/%s/groups/%s" % [_admin._BUCKET, SyncKintoAdmin.GRUPO_COORDENADORES]
	var r: Dictionary = await _admin.definir_permissoes_collection({ "record:create": [grupo_principal] })
	if r.get("ok", false):
		_carregar_permissoes()
	else:
		_lbl_perms.text = "Falha: " + str(r.get("erro", ""))


# ───────────────────────── Campus (mesclar) ─────────────────────────

func _carregar_campus() -> void:
	_lista_campus.clear()
	_campus_registros.clear()
	var r: Dictionary = await _admin.listar()
	if not r.get("ok", false):
		_lbl_campus.text = "Falha ao listar: " + str(r.get("erro", ""))
		return
	var registros: Array = []
	if r.get("dados") is Dictionary:
		registros = r["dados"].get("data", [])
	for rec in registros:
		if not rec is Dictionary:
			continue
		# O proprio campus nao entra na mescla (evita mesclar o agregado dentro de si).
		if str(rec.get("id", "")) == "campus":
			continue
		_lista_campus.add_item("%s — enviado por %s em %s" \
			% [str(rec.get("id", "")), str(rec.get("enviado_por", "?")), str(rec.get("enviado_em", "?"))])
		_campus_registros.append(rec)
	if _campus_registros.is_empty():
		_lbl_campus.text = "Nenhum curso disponível para mesclar."


func _mesclar() -> void:
	var sel: PackedInt32Array = _lista_campus.get_selected_items()
	if sel.size() < 2:
		_lbl_campus.text = "Selecione ao menos dois cursos para mesclar."
		return
	var subset: Array = []
	for i in sel:
		subset.append(_campus_registros[i])
	var res: Dictionary = ArquivosPlanejamento.mesclar_planejamentos(subset, false)
	var conflitos: Array = res.get("conflitos", [])
	if conflitos.is_empty():
		await _publicar_campus(res.get("plano", {}))
		return
	# Conflitos: nunca resolve em silencio. Lista para o admin e oferece manter o mais recente.
	var itens: Array = []
	for c in conflitos:
		itens.append("%s (%s): horário difere entre %s" \
			% [str(c.get("codigo", "")), str(c.get("oferta", "")), ", ".join(PackedStringArray(c.get("cursos", [])))])
	Dialogos.escolha_lista(self, "Conflitos de horário no merge", \
		"Estas disciplinas compartilhadas têm alocações divergentes entre cursos. Cancele e ajuste " + \
		"nos cursos de origem, ou mescle mantendo a versão enviada mais recentemente:", \
		itens, "", [{ "texto": "Manter a mais recente e mesclar", "ao_acionar": _mesclar_recente.bind(subset) }])


func _mesclar_recente(subset: Array) -> void:
	var res: Dictionary = ArquivosPlanejamento.mesclar_planejamentos(subset, true)
	await _publicar_campus(res.get("plano", {}))


func _publicar_campus(plano: Dictionary) -> void:
	var n: int = plano.get("disciplinas", []).size()
	# Salva local com nome proprio (planejamento_campus.json, via main) — nao toca no planejamento.json
	# de trabalho — e publica o record 'campus' no servidor.
	salvar_campus_local.emit(plano)
	var r: Dictionary = await _admin.enviar("campus", plano)
	if r.get("ok", false):
		_lbl_campus.text = "Campus mesclado (%d disciplinas): salvo em planejamento_campus.json e publicado no servidor." % n
		_carregar_planos()
	else:
		_lbl_campus.text = "Salvo em planejamento_campus.json, mas falhou ao publicar: " + str(r.get("erro", ""))
