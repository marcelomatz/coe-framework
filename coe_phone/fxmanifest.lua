fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_phone'
version '0.1.0-beta.17'
description 'Smartphone do COE OS: Telefone, Contatos, Mensagens e os apps da loja (coe_apps)'

-- Reinício pelo coe_supervisor (categoria no painel).
coe_supervisor 'gameplay'

dependencies {
	'coe_core',
	'coe_database',
	'coe_inventory',
	'coe_logging',
	'coe_notify',
	'coe_ui'
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
	'server/upgrade.lua',
	'server/voice.lua',
	'server/main.lua'
}

client_scripts {
	'client/animation.lua',
	'client/main.lua',
	'@coe_ui/theme_bridge.lua'
}

ui_page 'html/index.html'

files {
	'html/index.html',
	'html/style.css',
	'html/app.js',
	'html/native.js',
	'html/settings.js',
	'html/gallery.js',
	'html/wallet.js'
}
