fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_fuel'
version '0.1.0-beta.18'
description 'Combustível do Coe: consumo nos veículos (comum, aditivada, etanol e diesel), postos com bandeira, bombas e galão'

-- Reinício pelo coe_supervisor (categoria no painel).
coe_supervisor 'business'
coe_platform 'hal'

dependencies {
	'coe_core',
	'coe_database',
	'coe_logging',
	'coe_inventory',
	'coe_businesses',
	'coetarget'
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
	'client/main.lua'
}

ui_page 'html/index.html'

files {
	'html/index.html',
	'html/pump.css',
	'html/pump.js',
	'html/refinery.js',
	'html/business.js',
	'html/business.css'
}
