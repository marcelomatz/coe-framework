fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_rentals'
version '0.1.0-beta.13'
description 'Sistema de aluguel de veículos para cidadãos iniciantes com caução e devolução'

shared_scripts {
	'@coe_core/lib/init.lua',
	'config.lua',
	'locales/pt-br.lua',
	'locales/en-us.lua',
	'domain/rules.lua',
	'domain/stations.lua'
}

client_scripts {
	'client/main.lua',
	'@coe_ui/theme_bridge.lua'
}

ui_page 'html/index.html'

files {
	'html/index.html',
	'html/rentals.css',
	'html/rentals.js'
}

server_scripts {
	'@coe_core/lib/access.lua',
	'@coe_core/lib/migrations.lua',
	'server/migrations.lua',
	'server/persistence.lua',
	'server/main.lua'
}

dependencies {
	'coe_core',
	'coe_database',
	'coe_economy',
	'coe_ui',
	'coe_vehicles'
}
