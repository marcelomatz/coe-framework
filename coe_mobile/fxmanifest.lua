fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_mobile'
version '0.1.0-beta.12'
description 'Telefone básico do Coe: número do personagem, ligações com voz, contatos, mensagens e ajustes simples'

-- Pacotes completos podem assumir este papel: declaram coe_supervisor_replaces 'coe_mobile' e o coe_supervisor não
-- inicia este resource enquanto o pacote roda (volta sozinho se o pacote parar).
coe_supervisor_replaceable 'yes'

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
