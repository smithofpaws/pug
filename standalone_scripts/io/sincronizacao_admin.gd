class_name SyncKintoAdmin extends SyncKinto
## Cliente de [b]administracao[/b] do servidor [url=https://github.com/Kinto/kinto]Kinto[/url].
##
## Estende [SyncKinto] reusando [method SyncKinto.configurar], [method SyncKinto.esta_configurado] e o
## transporte ([code]_requisitar[/code], guard [code]_ocupado[/code], auth Basic). Diferenca: usa as
## credenciais do [b]administrador[/b] (nao as do coordenador) e fala com endpoints que estao [b]fora[/b]
## da collection de planejamentos: contas ([code]/accounts/<user>[/code]), grupos
## ([code]/buckets/<bucket>/groups/<grupo>[/code]) e permissoes da collection. [br]
## [br]
## Deve viver numa [b]instancia propria[/b] (separada do [code]_sync[/code] do coordenador) para nao
## sobrescrever as credenciais de cada um. Todos os metodos sao assincronos ([code]await[/code]) e
## retornam o mesmo [Dictionary] normalizado [code]{ "ok", "codigo", "dados", "erro" }[/code].

# Grupo padrao de coordenadores (recebe record:create na collection — ver AGENTS.md).
const GRUPO_COORDENADORES := "coordenadores"


# Caminhos fora da collection de planejamentos.
func _caminho_conta(usuario: String) -> String:
	return "/accounts/" + usuario


func _caminho_grupo(grupo: String) -> String:
	return "/buckets/%s/groups/%s" % [_BUCKET, grupo]


func _caminho_collection() -> String:
	return "/buckets/%s/collections/%s" % [_BUCKET, _COLLECTION]


## Confirma que as credenciais sao de administrador lendo o bucket (so o dono/admin consegue; um
## coordenador comum recebe 403). Use antes de habilitar as acoes do painel.
func testar_admin() -> Dictionary:
	return await _requisitar(HTTPClient.METHOD_GET, "/buckets/" + _BUCKET, null)


## Cria a conta [param usuario] ou, se ja existir, [b]redefine a senha[/b] dela (PUT em conta
## existente troca a senha). O chamador deve distinguir os dois casos na UI.
func criar_ou_redefinir_conta(usuario: String, senha: String) -> Dictionary:
	return await _requisitar(HTTPClient.METHOD_PUT, _caminho_conta(usuario), { "password": senha })


## Apaga a conta [param usuario]. NAO remove o record do curso dele nem o tira de grupos.
func apagar_conta(usuario: String) -> Dictionary:
	return await _requisitar(HTTPClient.METHOD_DELETE, _caminho_conta(usuario), null)


## Lista as contas visiveis ao admin (GET /accounts). Em [code]dados.data[/code] vem o Array de contas.
func listar_contas() -> Dictionary:
	return await _requisitar(HTTPClient.METHOD_GET, "/accounts", null)


## Le um grupo. Em [code]dados.data.members[/code] vem o Array de principais (ex.: [code]account:joao[/code]).
func obter_grupo(grupo: String) -> Dictionary:
	return await _requisitar(HTTPClient.METHOD_GET, _caminho_grupo(grupo), null)


## Define (substitui) a lista de [param membros] do [param grupo]. O Kinto faz PUT substituindo o
## array inteiro — para adicionar/remover, faca read-modify-write a partir de [method obter_grupo].
func definir_membros_grupo(grupo: String, membros: Array) -> Dictionary:
	return await _requisitar(HTTPClient.METHOD_PUT, _caminho_grupo(grupo), { "members": membros })


## Apaga o record (plano) de id [param id_record] na collection de planejamentos.
func apagar_record(id_record: String) -> Dictionary:
	return await _requisitar(HTTPClient.METHOD_DELETE, _caminho_record(id_record), null)


## Le a collection de planejamentos. Em [code]dados.permissions[/code] vem o mapa de permissoes atual.
func obter_collection() -> Dictionary:
	return await _requisitar(HTTPClient.METHOD_GET, _caminho_collection(), null)


## Concede/ajusta permissoes da collection. [param permissoes] e o mapa Kinto
## (ex.: [code]{"record:create": ["/buckets/pug/groups/coordenadores"]}[/code]). PATCH [b]soma[/b] os
## principais aos existentes; envia no topo do corpo (sem encapsular em "data").
func definir_permissoes_collection(permissoes: Dictionary) -> Dictionary:
	return await _requisitar(HTTPClient.METHOD_PATCH, _caminho_collection(), \
		{ "permissions": permissoes }, false)


# Mensagens de erro no contexto de administracao (o pai fala em "coordenador dono", que aqui confunde).
func _mensagem_erro(codigo: int, dados: Variant) -> String:
	var detalhe: String = ""
	if dados is Dictionary:
		detalhe = str(dados.get("message", ""))
	match codigo:
		401:
			return "Senha de administrador invalida (401). Verifique usuario e senha do admin."
		403:
			return "Sem permissao de administrador (403). Esta conta nao e dona do servidor/bucket."
		404:
			return "Nao encontrado no servidor (404)."
		_:
			return "Erro do servidor (HTTP %d)%s" % [codigo, (": " + detalhe) if not detalhe.is_empty() else "."]
