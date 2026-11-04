fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_mail'
version '0.1.0-beta.18'
description 'E-mail do COE OS: contas com senha, caixas de entrada e envio entre endereços'

coe_platform 'hal'

dependencies {
	'coe_core',
	'coe_database',
	'coe_logging'
}

shared_scripts {
	'@coe_core/lib/init.lua',
	'config.lua',
	'shared/rules.lua'
}

server_scripts {
	'@coe_core/lib/migrations.lua',
	'server/migrations.lua',
	'server/persistence.lua',
	'server/main.lua'
}

files {
	'html/mail.js',
	'html/mail.css'
}
