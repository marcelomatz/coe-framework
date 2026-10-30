fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_characters'
version '0.1.0-beta.14'
description 'Seleção de personagem com cena 3D e integração com o criador (coe_appearance)'

dependencies {
	'coe_core',
	'coe_spawn',
	'coe_notify',
	'coe_ui'
}

ui_page 'html/index.html'

files {
	'html/index.html',
	'html/style.css',
	'html/app.js'
}

shared_script '@coe_core/lib/init.lua'
client_scripts {
	'config.lua',
	'client/scene.lua',
	'client.lua',
	'@coe_ui/theme_bridge.lua'
}
