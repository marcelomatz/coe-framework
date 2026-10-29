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
	'domain/rules.lua'
}

client_scripts {
	'client/main.lua'
}

server_scripts {
	'server/main.lua'
}

dependencies {
	'coe_core',
	'coe_economy',
	'coe_vehicles'
}
