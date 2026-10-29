fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_supervisor'
version '0.1.0-beta.13'
description 'Reinício ordenado dos resources do framework Coe'

files {
	'version.json'
}

-- Sem dependências: precisa sobreviver ao reinício de qualquer resource gerenciado.
client_script 'client.lua'
server_scripts {
	'@coe_core/lib/access.lua',
	'config.lua',
	'fs_writer.js',
	'plan.lua',
	'replace.lua',
	'ansi.lua',
	'updater.lua',
	'server.lua'
}
