fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_logging'
version '0.1.0-beta.18'
description 'Structured server-side logging for Coe resources'

coe_platform 'hal'

server_scripts {
	'@coe_core/lib/access.lua',
	'config.lua',
	'server.lua'
}
