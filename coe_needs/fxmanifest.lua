fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_needs'
version '0.1.0-beta.8'
description 'Necessidades do personagem (fome, sede, estresse, alcool, drogas) com estado autoritativo no servidor'

dependencies {
	'coe_core',
	'coe_database',
	'coe_logging'
}

shared_scripts {
	'config.lua',
	'locales/pt-br.lua',
	'locales/en-us.lua',
	'domain/needs.lua'
}

client_scripts { 'client.lua' }

server_scripts {
	'@coe_core/lib/access.lua',
	'@coe_core/lib/init.lua',
	'@coe_core/lib/logger.lua',
	'@coe_core/lib/migrations.lua',
	'adapters/migrations.lua',
	'adapters/persistence.lua',
	'application/service.lua'
}
