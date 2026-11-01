fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_mdt'
version '0.1.0-beta.15'
description 'MDT da polícia: chamados, consulta de cidadãos e placas, mandados, boletins e relatórios, com registro de acessos'

dependencies {
	'coe_core',
	'coe_database',
	'coe_logging',
	'coe_businesses',
	'coe_police',
	'coe_dispatch',
	'coe_tablet'
}

shared_scripts {
	'@coe_core/lib/init.lua',
	'config.lua'
}

server_scripts {
	'@coe_core/lib/migrations.lua',
	'server/migrations.lua',
	'server/persistence.lua',
	'server/rules.lua',
	'server/main.lua'
}

files {
	'html/tablet_app.js'
}
