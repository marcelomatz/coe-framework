fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_admin'
version '0.1.0-beta.17'
description 'Painel administrativo para o framework Coe'

-- Reinício pelo coe_supervisor (categoria no painel).
coe_supervisor 'administration'
coe_platform 'hal'

dependencies {
	'coe_core',
	'coe_inventory',
	'coe_database',
	'coe_logging',
	'coe_notify',
	'coe_ui',
	'coe_businesses',
	'coe_economy',
	'coe_factions',
	'coe_crafting',
	'coe_housing',
	'coe_vehicle_catalog',
	'coe_banking'
}

ui_page 'html/index.html'

files {
	'html/index.html',
	'html/style.css',
	'html/app.js',
	'html/garages.js',
	'html/rentals.js',
	'html/doors.js',
	'html/crafting.js',
	'html/housing.js',
	'html/realty.js',
	'html/banking.js',
	'html/crypto.js',
	'html/amzg.js',
	'html/deepweb.js',
	'html/news.js',
	'html/tools.css',
	'html/tools.js'
}

shared_scripts {
	'@coe_core/lib/init.lua',
	'config.lua',
	'tools/config.lua',
	'tools/locales/pt-br.lua',
	'tools/locales/en-us.lua',
	'tools/rules.lua'
}
client_scripts {
	'@coe_housing/shared/interiors.lua',
	'@coe_housing/client/interior_loader.lua',
	'tablet.lua',
	'tools/noclip.lua',
	'tools/client.lua',
	'client.lua',
	'@coe_ui/theme_bridge.lua'
}
server_scripts {
	'@coe_core/lib/logger.lua',
	'@coe_core/lib/migrations.lua',
	'server/migrations.lua',
	'server/persistence.lua',
	'server/directory.lua',
	'server/analytics.lua',
	'server/profile.lua',
	'server/staff.lua',
	'tools/server.lua',
	'server.lua'
}
