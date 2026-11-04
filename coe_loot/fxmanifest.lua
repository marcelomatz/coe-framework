fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_loot'
version '0.1.0-beta.17'
description 'Tabelas de saque para roubos (residência, pedestre, veículo, comércio): o que cai e com que chance'

coe_platform 'hal'

dependencies {
	'coe_core',
	'coe_logging'
}

shared_scripts {
	'@coe_core/lib/init.lua',
	'locales/pt-br.lua',
	'locales/en-us.lua',
	'config.lua',
	'shared/rules.lua'
}

server_scripts {
	'server/main.lua'
}
