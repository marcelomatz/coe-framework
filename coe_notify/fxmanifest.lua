fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_notify'
version '0.1.0-beta.5'
description 'Client notification library for Coe resources'

dependencies {
	'coe_ui'
}

ui_page 'html/index.html'

files {
	'html/index.html',
	'html/style.css',
	'html/app.js'
}

client_scripts { 'client.lua', '@coe_ui/theme_bridge.lua' }
server_scripts { '@coe_core/lib/access.lua', 'server.lua' }
