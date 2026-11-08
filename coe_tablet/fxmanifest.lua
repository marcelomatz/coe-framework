fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_tablet'
version '0.1.0-beta.19'
description 'COE OS no tablet: tela inicial, dock, multitarefa e central de controle; os apps mudam conforme o personagem'

-- Reinício pelo coe_supervisor (categoria no painel).
coe_supervisor 'gameplay'
coe_platform 'hal'

dependencies {
	'coe_core',
	'coe_logging',
	'coe_notify',
	'coe_ui',
	'coe_businesses'
}

ui_page 'html/index.html'

files {
	'html/index.html',
	'html/style.css',
	'html/app.js',
	'html/duty.js',
	'html/freejobs.js'
}

shared_scripts {
	'@coe_core/lib/init.lua',
	'locales/pt-br.lua',
	'locales/en-us.lua',
	'config.lua',
	'shared/profile.lua',
	'shared/prefs.lua',
	'shared/work_rules.lua'
}

client_scripts {
	'client/animation.lua',
	'client/main.lua',
	'@coe_ui/theme_bridge.lua'
}

server_scripts {
	'server/main.lua',
	'server/work.lua'
}
