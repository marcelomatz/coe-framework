fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_inventory'
version '0.1.0-beta.7'
description 'Inventário e catálogo como módulo independente do coe_core'

dependencies {
	'coe_core',
	'coe_database',
	'coe_logging',
	'coe_notify',
	'coetarget',
	'coe_ui'
}

ui_page 'html/index.html'

files {
	'lib/init.lua',
	'data/images/*.png',
	'data/images/*.webp',
	'data/images/*.svg',
	'html/index.html',
	'html/style.css',
	'html/app.js'
}

shared_scripts {
	'@coe_core/lib/init.lua',
	'config.lua',
	'locales/pt-br.lua',
	'locales/en-us.lua',
	'domain/items.lua',
	'data/coe_animations.lua',
	'data/coe_weapon_profiles.lua',
	'data/coe_base_items.lua',
	'data/coe_catalog.lua',
	'data/coe_weapons.lua',
	'data/coe_ammo.lua',
	'data/coe_attachments.lua',
	'data/coe_food.lua',
	'data/coe_consumables.lua',
	'data/coe_containers.lua',
	'data/coe_misc.lua',
	'data/coe_parts.lua',
	'data/coe_ingredients.lua',
	'data/coe_shop_items.lua',
	'domain/config_schema.lua'
}

client_scripts {
	'@coe_ui/theme_bridge.lua',
	'client/target_adapter.lua',
	'presentation/state.lua',
	'presentation/item_animation.lua',
	'presentation/container_props.lua',
	'presentation/container_placement.lua',
	'presentation/container_camera.lua',
	'presentation/world_targets.lua',
	'presentation/weapon_ammo.lua',
	'presentation/item_use.lua',
	'presentation/inventory_ui.lua',
	'presentation/nui_callbacks.lua',
	'presentation/server_events.lua',
	'presentation/bootstrap.lua'
}
server_scripts {
	'@coe_core/lib/logger.lua',
	'@coe_core/lib/migrations.lua',
	'adapters/migrations.lua',
	'adapters/persistence.lua',
	'application/state.lua',
	'application/storage.lua',
	'application/world_containers.lua',
	'application/opened_containers.lua',
	'application/inventory_ops.lua',
	'application/stashes.lua',
	'application/weapons.lua',
	'application/player_inventory.lua',
	'application/action_guard.lua',
	'application/handlers_inventory.lua',
	'application/handlers_containers.lua',
	'application/lifecycle.lua'
}
