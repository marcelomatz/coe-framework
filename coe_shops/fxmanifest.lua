fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_shops'
version '0.1.0-beta.7'
description 'Lojas do Coe: 24/7, LTD e Rob\'s Liquor como negócios (da staff com estoque automático ou de jogadores com estoque e preço próprios)'

dependencies {
	'coe_core',
	'coe_database',
	'coe_logging',
	'coe_inventory',
	'coe_businesses',
	'coetarget'
}

shared_scripts {
	'@coe_core/lib/init.lua',
	'config.lua',
	'shared/rules.lua'
}

server_scripts {
	'@coe_core/lib/access.lua',
	'@coe_core/lib/migrations.lua',
	'server/migrations.lua',
	'server/persistence.lua',
	'server/payments.lua',
	'server/main.lua'
}

client_scripts {
	'client/main.lua'
}

ui_page 'html/index.html'

files {
	'html/index.html',
	'html/shop.css',
	'html/shop.js',
	'html/business.js',
	'html/business.css'
}
