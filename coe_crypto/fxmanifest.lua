fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_crypto'
version '0.1.0-beta.18'
description 'Criptomoeda do jogo: carteiras com chave, rede pública, corretora com cotação flutuante e mineração'

coe_platform 'hal'

-- Reinício pelo coe_supervisor (categoria no painel).
coe_supervisor 'business'

dependencies {
	'coe_core',
	'coe_database',
	'coe_logging'
}

shared_scripts {
	'@coe_core/lib/init.lua',
	'config.lua',
	'shared/rules.lua'
}

server_scripts {
	'@coe_core/lib/migrations.lua',
	'@coe_core/lib/hash.lua',
	'server/migrations.lua',
	'server/persistence.lua',
	'server/main.lua'
}

files {
	'html/crypto.js',
	'html/crypto.css'
}
