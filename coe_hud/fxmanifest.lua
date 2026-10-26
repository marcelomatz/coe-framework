fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_hud'
version '0.1.0-beta.5'
description 'HUD do jogador (vida, veiculos) com preferencias e layout pessoais via /hud'

dependencies {
	'coe_ui',
	'coe_notify',
	'coe_needs'
}

ui_page 'html/index.html'

files {
	'html/index.html',
	'html/style.css',
	'html/speedo.css',
	'html/speedo.js',
	'html/editor.css',
	'html/editor.js',
	'html/app.js'
}

shared_script 'config.lua'
client_scripts { 'prefs.lua', 'route.lua', 'minimap.lua', 'location.lua',
	'vehicle.lua', 'logo.lua', 'client.lua', '@coe_ui/theme_bridge.lua' }
