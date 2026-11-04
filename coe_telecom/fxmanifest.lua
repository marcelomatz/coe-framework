fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_telecom'
version '0.1.0-beta.18'
description 'Operadora do COE OS: linhas pré-pago e pós-pago, tarifação de voz, vídeo e SMS e o app Minha linha'

coe_platform 'hal'

dependencies {
	'coe_core',
	'coe_database',
	'coe_logging',
	'coe_notify',
	'coe_economy'
}

shared_scripts {
	'@coe_core/lib/init.lua',
	'config.lua',
	'locales/pt-br.lua',
	'locales/en-us.lua',
	'shared/rules.lua'
}

server_scripts {
	'@coe_core/lib/migrations.lua',
	'server/migrations.lua',
	'server/persistence.lua',
	'server/main.lua'
}

files {
	'html/line.js'
}
