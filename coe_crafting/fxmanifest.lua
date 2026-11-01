fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_crafting'
version '0.1.0-beta.15'
description 'Central de craft: receitas, bancadas e execução atômica para mecânica, comércio e craft ilegal'

-- Reinício pelo coe_supervisor (categoria no painel).
coe_supervisor 'business'

dependencies {
	'coe_core',
	'coe_database',
	'coe_businesses',
	'coe_factions',
	'coe_inventory',
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
	'server/migrations.lua',
	'server/persistence.lua',
	'server/rules.lua',
	'server/registry.lua',
	'server/service.lua',
	'server/business.lua',
	'server/catalog.lua',
	'server/main.lua',
	'server/bridge.lua'
}

client_scripts {
	'client/main.lua',
	'client/stations.lua',
	'@coe_ui/theme_bridge.lua'
}

files {
	'html/index.html',
	'html/style.css',
	'html/app.js'
}
