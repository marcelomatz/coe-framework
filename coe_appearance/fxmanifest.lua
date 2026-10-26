fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_appearance'
version '0.1.0-beta.2'
description 'Aparência de personagem: formato, aplicação no ped e criador de personagem'

dependencies {
	'coe_core',
	'coe_ui'
}

ui_page 'html/index.html'

files {
	'html/index.html',
	'html/style.css',
	'html/app.js',
	-- Fotos das peças geradas por /coe_fotos_roupas (reinicie o recurso depois de gerar).
	'thumbs/*.webp'
}

shared_scripts {
	'@coe_core/lib/init.lua',
	'config.lua',
	'shared/schema.lua'
}

server_scripts {
	'server/thumbs.lua'
}

client_scripts {
	'client/apply.lua',
	'client/creator.lua',
	'client/thumbs.lua',
	'@coe_ui/theme_bridge.lua'
}
