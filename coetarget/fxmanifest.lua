fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coetarget'
version '0.1.0-beta.17'
description 'Configurable entity targeting system'

coe_platform 'hal'

dependencies {
	'coe_core',
	'coe_ui'
}

ui_page 'html/index.html'

files {
	'html/index.html',
	'html/style.css',
	'html/app.js'
}

shared_script '@coe_core/lib/platform.lua'
client_scripts {
	'config.lua',
	'client.lua',
	'@coe_ui/theme_bridge.lua'
}
