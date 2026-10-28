fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_garage'
version '0.1.0-beta.11'
description 'Garagens públicas básicas: guarda e retirada de veículos pessoais com blip e administração via coe_staff'

-- Categoria de reinicio no painel do coe_supervisor: administration | business | gameplay
coe_supervisor 'gameplay'

dependencies {
	'coe_core',
	'coe_database',
	'coe_logging',
	'coe_vehicles',
	'coe_notify',
	'coe_ui'
}

ui_page 'html/index.html'

shared_scripts {
	'@coe_core/lib/init.lua',
	'config.lua',
	'locales/pt-br.lua',
	'locales/en-us.lua',
	'domain/garage.lua'
}

client_scripts {
	'@coe_ui/theme_bridge.lua',
	'client.lua'
}

server_scripts {
	'@coe_core/lib/access.lua',
	'@coe_core/lib/logger.lua',
	'@coe_core/lib/migrations.lua',
	'adapters/migrations.lua',
	'adapters/persistence.lua',
	'application/service.lua'
}

files {
	'html/index.html',
	'html/garage.css',
	'html/garage.js'
}
