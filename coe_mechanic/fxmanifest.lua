fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_mechanic'
version '0.1.0-beta.15'
description 'Mecânica de veículos: peças com desgaste por quilometragem, inspeção, troca e ajuste de Mileage'

-- Reinício pelo coe_supervisor (categoria no painel).
coe_supervisor 'business'

dependencies {
	'coe_core',
	'coe_database',
	'coe_logging',
	'coe_ui',
	'coe_vehicles',
	'coe_inventory',
	'coe_businesses',
	'coe_crafting',
	'coe_vehicle_catalog'
}

ui_page 'html/showroom.html'

shared_scripts {
	'@coe_core/lib/init.lua',
	'locales/pt-br.lua',
	'locales/en-us.lua',
	'config.lua',
	'@coe_businesses/shared/area.lua',
	'shared/parts.lua',
	'shared/appearance.lua'
}

server_scripts {
	'@coe_core/lib/migrations.lua',
	'server/migrations.lua',
	'server/persistence.lua',
	'server/service.lua',
	'server/appearance_service.lua',
	'server/orders.lua',
	'server/business.lua',
	'server/shops.lua',
	'server/tablet.lua',
	'server/main.lua'
}

client_scripts {
	'client/appearance.lua',
	'client/showroom_camera.lua',
	'client/showroom.lua',
	'client/stations.lua',
	'@coe_ui/theme_bridge.lua'
}

files {
	'html/showroom.html',
	'html/showroom.css',
	'html/showroom.js',
	'html/labels.js',
	'html/tablet_app.js'
}
