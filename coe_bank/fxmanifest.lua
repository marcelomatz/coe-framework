fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_bank'
description 'Banco básico do Coe: saldo, saque, depósito, transferência por ID de cidadão e extrato, em agências e caixas eletrônicos'

dependencies {
	'coe_core',
	'coe_database',
	'coe_economy',
	'coe_inventory',
	'coe_ui',
	'coetarget'
}

shared_scripts {
	'@coe_core/lib/init.lua',
	'config.lua',
	'locales/pt-br.lua',
	'locales/en-us.lua',
	'shared/rules.lua'
}

server_scripts {
	'@coe_core/lib/access.lua',
	'server/main.lua'
}

client_scripts {
	'@coe_ui/theme_bridge.lua',
	'client/main.lua'
}

ui_page 'html/index.html'

files {
	'html/index.html',
	'html/bank.css',
	'html/bank.js'
}
