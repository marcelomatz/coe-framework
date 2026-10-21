fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_pausemenu'
description 'Menu de Pausa customizado (ESC) com identidade visual COE, dashboard e estatisticas'

dependencies {
	'coe_ui',
	'coe_core'
}

ui_page 'html/index.html'

files {
	'html/index.html',
	'html/style.css',
	'html/app.js',
	'html/img/*'
}

shared_scripts {
	'config.lua',
	'shared/rules.lua'
}

client_scripts {
	'client/main.lua',
	'@coe_ui/theme_bridge.lua'
}

server_scripts {
	'server/main.lua'
}
