fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_news'
version '0.1.0-beta.16'
description 'Portais de notícias do COE OS: Weazel News e Rebel News, com redação, linha editorial e anúncios'

-- Reinício pelo coe_supervisor (categoria no painel).
coe_supervisor 'business'

dependencies {
	'coe_core',
	'coe_database',
	'coe_logging'
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
	'server/main.lua',
	'server/admin.lua'
}

client_scripts {
	'client.lua'
}

files {
	'html/news.js',
	'html/news.css'
}
