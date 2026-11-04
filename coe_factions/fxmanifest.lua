fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_factions'
version '0.1.0-beta.17'
description 'Facções ilegais (gangues, máfias, desmanches): graus, membros e crafts liberados'

-- Reinício pelo coe_supervisor (categoria no painel).
coe_supervisor 'gameplay'

dependencies {
	'coe_core',
	'coe_database',
	'coe_logging'
}

shared_scripts {
	'@coe_core/lib/init.lua',
	'config.lua'
}

server_scripts {
	'@coe_core/lib/migrations.lua',
	'server/migrations.lua',
	'server/persistence.lua',
	'server/rules.lua',
	'server/tablet.lua',
	'server/main.lua'
}

files {
	'html/tablet_app.js'
}
