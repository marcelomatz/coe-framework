fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_banking'
version '0.1.0-beta.18'
description 'Sistema bancário: agências, caixas eletrônicos, dinheiro em espécie, cartões com senha e contas de negócio'

-- Reinício pelo coe_supervisor (categoria no painel).
coe_supervisor 'business'
coe_platform 'hal'

dependencies {
	'coe_core',
	'coe_database',
	'coe_logging',
	'coe_ui',
	'coe_economy',
	'coe_inventory',
	'coe_businesses',
	'coetarget'
}

ui_page 'html/index.html'

shared_scripts {
	'@coe_core/lib/init.lua',
	'config.lua',
	'locales/pt-br.lua',
	'locales/en-us.lua'
}

server_scripts {
	'@coe_core/lib/migrations.lua',
	'server/migrations.lua',
	'server/persistence.lua',
	'server/rules.lua',
	'server/credit_rules.lua',
	'server/loan_rules.lua',
	'server/tablet.lua',
	'server/business_rules.lua',
	'server/main.lua',
	'server/atm.lua',
	'server/admin_api.lua',
	'server/payment_api.lua',
	'server/business.lua'
}

client_scripts {
	'client/main.lua',
	'@coe_ui/theme_bridge.lua'
}

files {
	'html/index.html',
	'html/banking.css',
	'html/banking.js',
	'html/bank-ui.css',
	'html/business.js',
	'html/tablet_app.js'
}
