fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_spawn'
version '0.1.0-beta.5'
description 'Adaptador de spawn condicionado ao carregamento do personagem, com retorno à última posição'

dependencies {
	'coe_core',
	'coe_database',
	'spawnmanager'
}

shared_scripts {
	'@coe_core/lib/init.lua',
	'config.lua',
	'shared/positions.lua'
}

server_scripts {
	'@coe_core/lib/migrations.lua',
	'server/migrations.lua',
	'server/persistence.lua',
	'server/main.lua'
}

client_scripts {
	'client.lua'
}