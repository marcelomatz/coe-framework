fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_deepweb'
version '0.1.0'
description 'DeepWeb: navegador onion por nível de equipamento, identidade anônima, DuckDark, Rabbit, Deep Market, computadores e mineração'

-- Reinício pelo coe_supervisor (categoria no painel).
coe_supervisor 'gameplay'

dependencies {
	'coe_core',
	'coe_database',
	'coe_logging',
	'coe_ui'
}

ui_page 'html/index.html'

files {
	'html/index.html',
	'html/computer.css',
	'html/computer.js',
	'html/deepweb.js',
	'html/deepweb.css',
	'html/browser.css',
	'html/sites.js',
	'html/sites.css'
}

shared_scripts {
	'@coe_core/lib/init.lua',
	'locales/pt-br.lua',
	'locales/en-us.lua',
	'config.lua',
	'shared/rules.lua'
}

client_scripts {
	'client/main.lua'
}

server_scripts {
	'@coe_core/lib/migrations.lua',
	'@coe_core/lib/hash.lua',
	'server/migrations.lua',
	'server/persistence.lua',
	'server/main.lua',
	'server/sites.lua',
	'server/forum.lua',
	'server/market.lua',
	'server/admin.lua'
}
