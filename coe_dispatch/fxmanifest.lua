fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_dispatch'
version '0.1.0-beta.19'
description 'Despacho de chamados e alertas para polícia e EMS, usado por heists e demais resources. Recebe quem está de ponto em negócio da categoria'

coe_platform 'hal'

dependencies {
	'coe_core',
	'coe_logging',
	'coe_businesses'
}

shared_scripts {
	'@coe_core/lib/init.lua',
	'locales/pt-br.lua',
	'locales/en-us.lua',
	'config.lua'
}

server_scripts {
	'server/rules.lua',
	'server/main.lua'
}

client_scripts {
	'client.lua'
}
