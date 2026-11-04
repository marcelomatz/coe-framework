fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_garages'
version '0.1.0-beta.17'
description 'Garagens: veículos do jogador por vaga e frota dos negócios, com acesso definido pelo dono'

-- Reinício pelo coe_supervisor (categoria no painel).
coe_supervisor 'business'

dependencies {
	'coe_core',
	'coe_database',
	'coe_logging',
	'coe_ui',
	'coe_vehicles',
	'coe_businesses',
	'coe_vehicle_catalog'
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
	'server/tablet.lua',
	'server/main.lua'
}

client_scripts {
	'client/main.lua',
	'@coe_ui/theme_bridge.lua'
}

files {
	'html/index.html',
	'html/garage.css',
	'html/garage.js',
	'html/tablet_app.js'
}
