fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_loadscreen'
version '0.1.0-beta.8'
description 'Tela de carregamento do Coe, no visual da seleção e do criador de personagem'

loadscreen 'html/index.html'
-- Fica na tela até a seleção de personagem (coe_characters) estar pronta; client.lua fecha por segurança.
loadscreen_manual_shutdown 'yes'

client_script 'client.lua'

files {
	'html/index.html',
	'html/style.css',
	'html/app.js',
	'html/backgrounds/*.jpg',
	'html/backgrounds/*.png',
	'html/backgrounds/*.webp'
}
