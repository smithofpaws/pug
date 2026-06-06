# Auxiliar Coordenacao
# Copyright (C) 2026 DIEGO ARTHUR HARTMANN
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

extends Node

## Diretorio raiz do projeto. Definido em [method FileHandling.configurar_dirdados].
var dir_principal: String
## Diretorio de dados de entrada ([code]/dados/entrada/[/code]).
var dir_dados: String
## Diretorio de dados processados ([code]/dados/saida/[/code]).
var dir_saida: String
## Diretorio temporario para conversao de arquivos ([code]/dados/entrada/[/code]).
var dir_temp: String
## Diretorio raiz para arquivos exportados pelo programa (saidas geradas pelos modulos).
## Configuravel em [code]base_config.json:diretorios.exportacoes[/code].
var dir_exportacoes: String

var escala_dpi: float
var tamanho_janela_base: Vector2i
## Configuracao completa carregada de [code]base_config.json[/code], mesclada com [member config_usuario].
var configuracao_base: Dictionary
## Sobrescritas do usuario (diferenca em relacao ao [code]base_config.json[/code]).
## Persistido em [code]config_usuario.json[/code]; vazio se o arquivo nao existir.
var config_usuario: Dictionary = {}

## Todas as grades curriculares carregadas de [code]/arquivos/grades/[/code].
## Chave no padrao [code]<cod_curso>_<versao>[/code].
var grades: Dictionary
## Todas as equivalencias carregadas de [code]/arquivos/equivalencias/[/code].
## Chave no padrao [code]<origem>-<destino>[/code].
var equivalencias: Dictionary
## Cargas horarias exigidas por nucleo, carregadas de [code]/arquivos/cargaexigida/[/code].
var ch_exigida: Dictionary
## Dicas de funcionalidade do programa, carregadas de [code]arquivos/dicas.json[/code].
## Chaves aninhadas por modulo. Usado por [DicasPrograma].
var dicas: Dictionary = {}

## Cache compartilhado dos dados discentes pre-computados, para que a troca de modulo nao
## recalcule o pipeline caro (ler hist.csv -> reprovacoes -> simplificar -> condicoes_discentes).
## Preenchido por [code]main.gd:_garantir_dados_discentes[/code] e consumido pelos modulos que
## fazem analise de historico/aproveitamento. Conteudo: [br]
## [code]{ historico, lista_alunos, condicoes_discentes, reprovacoes }[/code].
var dados_discentes: Dictionary = {}
## Assinatura que valida o cache [member dados_discentes] (timestamp de modificacao do hist.csv).
## Quando o hist.csv muda, a assinatura difere e o cache e recomputado.
var dados_discentes_assinatura: String = ""
