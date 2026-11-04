fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_doors'
version '0.1.0-beta.17'
description 'Portas e fechaduras do mapa e de MLOs: trancamento, senha, trava automática e acesso por negócio, facção, personagem ou chave'

-- Reinício pelo coe_supervisor (categoria no painel).
coe_supervisor 'gameplay'
coe_platform 'hal'

dependencies {
	'coe_core',
	'coe_database',
	'coe_logging',
	'coe_ui'
}

ui_page 'html/index.html'

shared_scripts {
	'@coe_core/lib/init.lua',
	'config.lua'
}

server_scripts {
	'@coe_core/lib/migrations.lua',
	'server/sha256.lua',
	'server/migrations.lua',
	'server/persistence.lua',
	'server/rules.lua',
	'server/main.lua'
}

client_scripts {
	'client/main.lua',
	'@coe_ui/theme_bridge.lua'
}

files {
	'html/index.html',
	'html/doors.css',
	'html/doors.js',
	'html/tablet_app.js'
}
