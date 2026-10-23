fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_staff'
description 'Painel básico da staff do Coe: ferramentas pessoais, jogadores, veículos, mundo e negócios'

dependencies {
	'coe_core',
	'coe_ui'
}

shared_scripts {
	'@coe_core/lib/init.lua',
	'config.lua',
	'locales/pt-br.lua',
	'locales/en-us.lua',
	'shared/rules.lua'
}

server_scripts {
	'@coe_core/lib/access.lua',
	'server/main.lua'
}

client_scripts {
	'@coe_ui/theme_bridge.lua',
	'client/noclip.lua',
	'client/main.lua'
}

ui_page 'html/index.html'

files {
	'html/index.html',
	'html/staff.css',
	'html/staff.js'
}
