fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_economy'
version '0.1.0-beta.7'
description 'Economia: saldo por personagem, extrato e operações atômicas de crédito, débito e transferência'

dependencies {
	'coe_core',
	'coe_database',
	'coe_logging',
	'coe_businesses'
}

shared_scripts {
	'@coe_core/lib/init.lua',
	'config.lua',
	'locales/pt-br.lua',
	'locales/en-us.lua'
}

server_scripts {
	'@coe_core/lib/access.lua',
	'@coe_core/lib/migrations.lua',
	'server/migrations.lua',
	'server/persistence.lua',
	'server/rules.lua',
	'server/main.lua'
}
