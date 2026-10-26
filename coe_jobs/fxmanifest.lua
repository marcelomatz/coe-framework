fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_jobs'
version '0.1.0-beta.4'
description 'Empregos livres do Coe (coleta e rotas), com carreira (XP, habilidades e reputação compartilhadas entre empregos)'

dependencies {
	'coe_core',
	'coe_database',
	'coe_economy',
	'coe_logging',
	'coe_notify',
	'coetarget'
}

shared_scripts {
	'@coe_core/lib/init.lua',
	'locales/pt-br.lua',
	'locales/en-us.lua',
	'config.lua',
	'shared/rules.lua',
	'shared/career.lua'
}

server_scripts {
	'@coe_core/lib/access.lua',
	'@coe_core/lib/migrations.lua',
	'jobs/*.lua',
	'shared/guide.lua',
	'server/migrations.lua',
	'server/persistence.lua',
	'server/main.lua'
}

client_scripts {
	'client/main.lua'
}

ui_page 'html/guide.html'

files {
	'html/guide.html',
	'html/guide.css',
	'html/guide.js',
	'html/guide-view.js',
	'html/career.js'
}
