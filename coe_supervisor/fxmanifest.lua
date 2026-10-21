fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'coe_supervisor'
description 'Reinício ordenado dos resources do framework Coe'

-- Sem dependências: precisa sobreviver ao reinício de qualquer resource gerenciado.
client_script 'client.lua'
server_scripts {
	'config.lua',
	'plan.lua',
	'server.lua'
}
