fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_businesses'
description 'Registro de negócios (mecânicas, lojinhas, postos...): área, baús, mesas de craft e regras definidos pelo admin'

dependencies {
	'coe_core',
	'coe_database',
	'coe_logging',
	'coe_ui'
}

ui_page 'html/index.html'

shared_scripts {
	'@coe_core/lib/init.lua',
	'config.lua',
	'locales/pt-br.lua',
	'locales/en-us.lua',
	'shared/area.lua'
}

server_scripts {
	'@coe_core/lib/migrations.lua',
	'server/migrations.lua',
	'server/persistence.lua',
	'server/grades.lua',
	'server/registry.lua',
	'server/access.lua',
	'server/duty.lua',
	'server/tablet.lua',
	'server/main.lua'
}

client_scripts {
	'client/main.lua',
	'@coe_ui/theme_bridge.lua'
}

files {
	'html/index.html',
	'html/offer.js',
	'html/tablet_app.js'
}
