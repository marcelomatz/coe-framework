fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_races'
version '0.1.0-beta.16'
description 'Corridas ilegais de rua do Coe: pistas com checkpoints, tablet de corridas, entrada em cripto, ranking e polícia'

-- Reinício pelo coe_supervisor (categoria no painel).
coe_supervisor 'gameplay'

dependencies {
	'coe_core',
	'coe_database',
	'coe_logging',
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
	'@coe_core/lib/migrations.lua',
	'server/migrations.lua',
	'server/persistence.lua',
	'server/main.lua'
}

client_scripts {
	'client/main.lua',
	'client/race.lua',
	'client/recorder.lua'
}

ui_page 'html/index.html'

files {
	'html/index.html',
	'html/pad.css',
	'html/pad.js',
	'html/app.css',
	'html/app.js',
	'html/hud.css',
	'html/hud.js'
}
