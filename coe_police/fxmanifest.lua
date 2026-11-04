fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_police'
version '0.1.0-beta.17'
description 'Polícia: algemar, multar, prender e ficha criminal. Equipe, cargos e salários vêm do negócio da categoria police'

coe_platform 'hal'

dependencies {
	'coe_core',
	'coe_database',
	'coe_logging',
	'coe_businesses',
	'coe_economy',
	'coe_inventory'
}

shared_scripts {
	'@coe_core/lib/init.lua',
	'locales/pt-br.lua',
	'locales/en-us.lua',
	'config.lua'
}

server_scripts {
	'@coe_core/lib/migrations.lua',
	'server/migrations.lua',
	'server/persistence.lua',
	'server/rules.lua',
	'server/main.lua'
}

client_scripts {
	'client.lua'
}
