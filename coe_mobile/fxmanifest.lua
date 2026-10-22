fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_mobile'
description 'Telefone básico do Coe: número do personagem, ligações com voz, contatos, mensagens e ajustes simples'

dependencies {
	'coe_core',
	'coe_database',
	'coe_inventory',
	'coe_talk',
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
	'@coe_core/lib/migrations.lua',
	'server/migrations.lua',
	'server/persistence.lua',
	'server/main.lua'
}

client_scripts {
	'@coe_ui/theme_bridge.lua',
	'client/main.lua'
}

ui_page 'html/index.html'

files {
	'html/index.html',
	'html/mobile.css',
	'html/mobile.js'
}
