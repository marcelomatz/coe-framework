fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_talk'
description 'Sistema de comunicação e voz nativo do FiveM Enhanced (proximidade, rádio tático e telefonia)'

dependencies {
	'coe_core',
	'coe_ui',
	'coe_notify'
}

ui_page 'html/index.html'

files {
	'html/index.html',
	'html/style.css',
	'html/app.js'
}

shared_scripts {
	'@coe_core/lib/init.lua',
	'config.lua',
	'locales/pt-br.lua',
	'locales/en-us.lua',
	'shared/rules.lua'
}

client_scripts {
	'client/submix.lua',
	'client/radio.lua',
	'client/phone.lua',
	'client/main.lua',
	'@coe_ui/theme_bridge.lua'
}

server_scripts {
	'server/routing.lua',
	'server/main.lua'
}
