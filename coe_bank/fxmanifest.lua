fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_bank'
version '0.1.0-beta.8'
description 'Banco básico do Coe: saldo, saque, depósito, transferência por ID de cidadão e extrato, em agências e caixas eletrônicos'

-- Pacotes completos podem assumir este papel: declaram coe_supervisor_replaces 'coe_bank' e o coe_supervisor não
-- inicia este resource enquanto o pacote roda (volta sozinho se o pacote parar).
coe_supervisor_replaceable 'yes'

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
