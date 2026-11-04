fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_housing'
version '0.1.0-beta.18'
description 'Moradias e imóveis comerciais: apartamento inicial, hotéis, casas e pontos de negócio com aluguel por ciclo e interior em mundo individual'

-- Reinício pelo coe_supervisor (categoria no painel).
coe_supervisor 'business'
coe_platform 'hal'

dependencies {
	'coe_core',
	'coe_database',
	'coe_logging',
	'coe_ui',
	'coe_economy',
	'coe_businesses',
	'coe_inventory'
}

ui_page 'html/index.html'

shared_scripts {
	'@coe_core/lib/init.lua',
	'locales/pt-br.lua',
	'locales/en-us.lua',
	'config.lua',
	'shared/interiors.lua'
}

server_scripts {
	'@coe_core/lib/migrations.lua',
	'server/migrations.lua',
	'server/persistence.lua',
	'server/rules.lua',
	'server/registry.lua',
	'server/main.lua',
	'server/contracts_admin.lua',
	'server/spaces.lua'
}

client_scripts {
	'client/interior_loader.lua',
	'client/main.lua',
	'@coe_ui/theme_bridge.lua'
}

files {
	'html/index.html',
	'html/housing.css',
	'html/housing.js',
	'html/tablet_app.js'
}
