fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_elos'
version '0.1.0'
description 'Elos: rede profissional do COE OS (perfil, currículo com empregos livres e negócios, conexões)'

-- Reinício pelo coe_supervisor (categoria no painel).
coe_supervisor 'gameplay'

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
	'server/migrations.lua',
	'server/persistence.lua',
	'server/main.lua'
}

files {
	'html/elos.js',
	'html/elos.css'
}
