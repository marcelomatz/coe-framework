fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_vehicle_catalog'
version '0.1.0-beta.11'
description 'Catálogo de veículos nativos e addons, leitura de vehicles.meta/handling.meta e overrides'

dependencies {
	'coe_core',
	'coe_database',
	'coe_logging'
}

shared_scripts {
	'@coe_core/lib/init.lua',
	'config.lua',
	'shared/meta.lua'
}

server_scripts {
	'@coe_core/lib/access.lua',
	'@coe_core/lib/migrations.lua',
	'data/native_vehicles.lua',
	'server/migrations.lua',
	'server/persistence.lua',
	'server/catalog.lua',
	'server/main.lua'
}
