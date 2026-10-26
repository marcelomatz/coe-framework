fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coetarget'
version '0.1.0-beta.2'
description 'Configurable entity targeting system'

dependencies {
	'coe_ui'
}

ui_page 'html/index.html'

files {
	'html/index.html',
	'html/style.css',
	'html/app.js'
}

client_scripts {
	'config.lua',
	'client.lua',
	'@coe_ui/theme_bridge.lua'
}
