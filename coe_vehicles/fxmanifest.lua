fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_vehicles'
version '0.1.0-beta.3'
description 'Registro persistente de veículos de jogador, placa, estado e quilometragem (Mileage)'

dependencies {
	'coe_core',
	'coe_database',
	'coe_logging'
}

shared_scripts {
	'@coe_core/lib/init.lua',
	'config.lua',
	'locales/pt-br.lua',
	'locales/en-us.lua',
	'shared/plate.lua',
	'shared/mileage.lua'
}

server_scripts {
	'@coe_core/lib/access.lua',
	'@coe_core/lib/migrations.lua',
	'server/migrations.lua',
	'server/persistence.lua',
	'server/registry.lua',
	'server/keys.lua',
	'server/main.lua'
}

client_scripts {
	'client/mileage.lua',
	'client/keys.lua'
}
