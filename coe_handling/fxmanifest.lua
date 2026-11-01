fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_handling'
version '0.1.0-beta.16'
description 'Handling estilo simulador por classe/categoria, com impacto do tipo e desgaste dos pneus'

-- Reinício pelo coe_supervisor (categoria no painel).
coe_supervisor 'gameplay'

dependencies {
	'coe_core',
	'coe_database',
	'coe_logging',
	'coe_vehicles',
	'coe_vehicle_catalog',
	'coe_mechanic'
}

shared_scripts {
	'@coe_core/lib/init.lua',
	'config.lua',
	'shared/engine.lua'
}

server_scripts {
	'@coe_core/lib/migrations.lua',
	'server/migrations.lua',
	'server/persistence.lua',
	'server/service.lua',
	'server/main.lua'
}

client_scripts {
	'client/apply.lua'
}
