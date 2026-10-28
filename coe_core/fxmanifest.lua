fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_core'
version '0.1.0-beta.11'
description 'Núcleo compartilhado e infraestrutura base do framework'

dependencies {
	'coe_database',
	'coe_logging',
	'coe_audit',
	'coe_notify'
}

files {
	'lib/init.lua',
	'lib/logger.lua',
	'lib/migrations.lua',
	'lib/platform.lua',
	'lib/locale.lua',
	'lib/semver.lua'
}

shared_scripts {
	'lib/platform.lua',
	'lib/locale.lua',
	'lib/semver.lua',
	'locales/pt-br.lua',
	'locales/en-us.lua',
	'core/shared/bootstrap.lua',
	'core/shared/functions.lua',
	'core/shared/identity.lua',
	'core/shared/character_profile.lua',
	'core/shared/classes.lua',
	'core/shared/events.lua',
	'core/shared/states.lua'
}

client_script 'core/client/init.lua'

server_scripts {
	'lib/access.lua',
	'lib/logger.lua',
	'core/server/database.lua',
	'core/server/migrations.lua',
	'core/server/session_registry.lua',
	'config/groups.lua',
	'core/server/group_definitions.lua',
	'core/server/group_repository.lua',
	'core/server/group_service.lua',
	'core/server/player_repository.lua',
	'core/application/player_service.lua',
	'core/server/player_lifecycle.lua',
	'core/server/init.lua'
}
