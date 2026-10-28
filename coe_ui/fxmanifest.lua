fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_ui'
version '0.1.0-beta.11'
description 'Biblioteca de UI do framework Coe: tokens, componentes e guia de estilos'

-- Sem dependências: as NUIs dos outros resources carregam estes arquivos via nui://coe_ui/...
ui_page 'html/styleguide.html'

files {
	'html/tokens.css',
	'html/components.css',
	'html/surfaces.css',
	'html/callout.css',
	'html/panel.css',
	'html/apps.css',
	'html/perspective.css',
	'html/prompt.css',
	'html/prompt.js',
	'html/components.js',
	'html/styleguide.html',
	'theme_bridge.lua'
}

shared_script 'config.lua'
client_scripts { 'client.lua', 'theme_bridge.lua' }
server_scripts { '@coe_core/lib/access.lua', 'server.lua' }
