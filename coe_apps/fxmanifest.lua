fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_apps'
version '0.1.0'
description 'Loja de aplicativos do COE OS (tablet e smartphone): Empregos, Classificados, Insta e Estúdio'

-- Reinício pelo coe_supervisor (categoria no painel).
coe_supervisor 'gameplay'

dependencies {
	'coe_core',
	'coe_database',
	'coe_logging',
	'screenshot-basic'
}

shared_scripts {
	'@coe_core/lib/init.lua',
	'config.lua',
	'shared/rules.lua'
}

server_scripts {
	'@coe_core/lib/migrations.lua',
	'server/migrations.lua',
	'server/persistence.lua',
	'server/photos.lua',
	'server/main.lua'
}

client_scripts {
	'client/camera.lua'
}

files {
	'html/apps.js',
	'html/editor.js',
	'html/editor.css'
}
