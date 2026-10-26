fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_workpad'
version '0.1.0-beta.2'
description 'Tablet de trabalho básico do Coe: ponto, empregos livres, carreira e um app por negócio'

-- Pacotes completos podem assumir este papel: declaram coe_supervisor_replaces 'coe_workpad' e o coe_supervisor não
-- inicia este resource enquanto o pacote roda (volta sozinho se o pacote parar).
coe_supervisor_replaceable 'yes'

dependencies {
	'coe_core',
	'coe_inventory',
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
	'client/main.lua'
}

ui_page 'html/index.html'

files {
	'html/index.html',
	'html/workpad.css',
	'html/workpad.js',
	'html/duty.js',
	'html/freejobs.js'
}
