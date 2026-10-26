fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_audit'
version '0.1.0-beta.4'
description 'Trilha de auditoria durável (MariaDB) dos resources Coe'

dependencies {
	'coe_database',
	'coe_logging'
}

server_scripts {
	'@coe_core/lib/access.lua',
	'@coe_core/lib/migrations.lua',
	'config.lua',
	'server/migrations.lua',
	'server/entry.lua',
	'server/writer.lua',
	'server/persistence.lua',
	'server/main.lua'
}
