fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_amzg'
version '0.1.0-beta.16'
description 'Amzg: loja virtual do COE OS com entrega em caixas dentro dos imóveis'

-- Reinício pelo coe_supervisor (categoria no painel).
coe_supervisor 'business'

dependencies {
	'coe_core',
	'coe_database',
	'coe_logging',
	'coe_inventory'
}

shared_scripts {
	'@coe_core/lib/init.lua',
	'locales/pt-br.lua',
	'locales/en-us.lua',
	'config.lua',
	'shared/rules.lua'
}

server_scripts {
	'@coe_core/lib/migrations.lua',
	'server/migrations.lua',
	'server/persistence.lua',
	'server/main.lua'
}

client_scripts {
	'client/main.lua'
}

files {
	'html/amzg.js',
	'html/amzg.css'
}
