fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_ems'
version '0.1.0'
description 'Saúde e EMS: estados do paciente, reanimação, tratamento e prontuário. Equipe, cargos e salários vêm do negócio da categoria ems'

dependencies {
	'coe_core',
	'coe_database',
	'coe_logging',
	'coe_businesses',
	'coe_dispatch'
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
