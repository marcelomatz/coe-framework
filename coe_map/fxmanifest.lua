fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_map'
version '0.1.0-beta.18'
description 'Controle do mapa: minimapa, minimapa estendido (tecla Z) e mapa completo, com destino'

coe_platform 'hal'

dependencies {
	'coe_core',
	'coe_ui'
}

ui_page 'html/index.html'

files {
	'html/index.html',
	'html/style.css',
	'html/app.js'
}

shared_scripts {
	'@coe_core/lib/platform.lua',
	'config.lua'
}
client_scripts { 'anchor.lua', 'client.lua', '@coe_ui/theme_bridge.lua' }
