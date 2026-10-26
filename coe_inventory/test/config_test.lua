-- Testes da configuração: padrões, sobrescrita pelo administrador e valores inválidos.
Inventory = {}
Config = {}
local printed = {}
local realPrint = print
print = function(message) printed[#printed + 1] = message end
dofile('domain/config_schema.lua')
print = realPrint

local Apply = Inventory.Settings.Apply

local function assertEqual(actual, expected, message)
	assert(actual == expected, ('%s: esperado %s, recebido %s'):format(message, tostring(expected), tostring(actual)))
end

local function hasIssue(issues, fragment)
	for _, issue in ipairs(issues) do
		if issue:find(fragment, 1, true) then return true end
	end
	return false
end

-- Config vazio/ausente usa todos os padrões, sem avisos.
for _, given in ipairs({ {}, false }) do
	local config, issues = Apply(given or nil)
	assertEqual(#issues, 0, 'config vazio sem avisos')
	assertEqual(config.Client.openKey, 'I', 'padrão openKey')
	assertEqual(config.Client.hotbarKey, 'TAB', 'padrão hotbarKey')
	assertEqual(config.Client.cancelKey, 'X', 'padrão cancelKey')
	assertEqual(config.Client.hotbarSlots, 5, 'padrão hotbarSlots')
	assertEqual(config.Consumables.items.water, 2500, 'padrão tempo consumo water')
	assertEqual(config.Server.defaultSlots, 30, 'padrão defaultSlots')
	assertEqual(config.Server.rateLimits.syncMs, 1000, 'padrão rateLimits.syncMs')
	assertEqual(#config.Server.starterItems, 4, 'padrão starterItems')
	assertEqual(config.Containers.items.WEAPON_BRIEFCASE.model, 'prop_ld_case_01', 'padrão container')
	assertEqual(config.Containers.items.paperbag.bone, 57005, 'padrão bone')
end
assertEqual(#printed, 0, 'carga de Config vazio não imprime nada')

-- Valores válidos do administrador prevalecem; o restante segue o padrão.
local config, issues = Apply({
	Client = { openKey = 'F2', hotbarKey = 'TAB', cancelKey = 'X', targetDistance = 4 },
	Consumables = { items = { water = 1800 } },
	Server = { maxSlots = 80, defaultSlots = 20, rateLimits = { swapMs = 0 } }
})
assertEqual(#issues, 0, 'config válida sem avisos')
assertEqual(config.Client.openKey, 'F2', 'override openKey')
assertEqual(config.Consumables.items.water, 1800, 'override tempo consumo water')
assertEqual(config.Consumables.items.burger, 3000, 'padrão tempo consumo burger preservado')
assertEqual(config.Client.targetDistance, 4, 'override targetDistance')
assertEqual(config.Client.placementRange, 4.0, 'padrão preservado')
assertEqual(config.Server.maxSlots, 80, 'override maxSlots')
assertEqual(config.Server.rateLimits.swapMs, 0, 'override rateLimits.swapMs')
assertEqual(config.Server.rateLimits.actionMs, 150, 'padrão rateLimits.actionMs')

-- Valores inválidos voltam ao padrão e geram aviso.
config, issues = Apply({
	Client = { openKey = 42, hotbarSlots = 0, targetDistance = 'perto', placementPreviewAlpha = 300, streamTimeoutMs = 1.5 },
	Server = { giveDistance = -1, maxSlots = 0 / 0, rateLimits = { requestMs = '300' } }
})
assertEqual(config.Client.openKey, 'I', 'openKey inválida cai no padrão')
assertEqual(config.Client.hotbarSlots, 5, 'hotbarSlots fora da faixa')
assertEqual(config.Client.targetDistance, 3.0, 'tipo errado')
assertEqual(config.Client.placementPreviewAlpha, 150, 'alpha acima de 255')
assertEqual(config.Client.streamTimeoutMs, 5000, 'inteiro com fração')
assertEqual(config.Server.giveDistance, 3.0, 'distância negativa')
assertEqual(config.Server.maxSlots, 200, 'NaN')
assertEqual(config.Server.rateLimits.requestMs, 300, 'número como texto')
assert(hasIssue(issues, 'Config.Client.hotbarSlots'), 'aviso de hotbarSlots')
assert(hasIssue(issues, 'Config.Server.rateLimits.requestMs'), 'aviso de rateLimits')

-- Chaves desconhecidas e formatos errados.
config, issues = Apply({ OpenKey = 'F2', Client = { opnKey = 'I' }, Server = 'x', Containers = 7 })
assert(hasIssue(issues, 'Config.OpenKey'), 'chave legada sinalizada')
assert(hasIssue(issues, 'Config.Client.opnKey'), 'typo sinalizado')
assert(hasIssue(issues, 'Config.Server deve ser uma tabela'), 'seção com tipo errado')
assert(hasIssue(issues, 'Config.Containers deve ser uma tabela'), 'containers com tipo errado')
assertEqual(config.Server.maxSlots, 200, 'seção inválida usa padrões')
assertEqual(config.Containers.items.paperbag.model, 'prop_paper_bag_01', 'containers padrão mantidos')
config, issues = Apply(5)
assert(hasIssue(issues, 'Config deve ser uma tabela'), 'Config não tabela')
assertEqual(config.Server.defaultSlots, 30, 'Config não tabela usa padrões')

-- defaultSlots não pode passar de maxSlots.
config, issues = Apply({ Server = { defaultSlots = 100, maxSlots = 50 } })
assertEqual(config.Server.defaultSlots, 50, 'defaultSlots limitado a maxSlots')
assert(hasIssue(issues, 'defaultSlots'), 'aviso defaultSlots > maxSlots')

-- starterItems: entradas inválidas são descartadas; lista vazia é permitida.
config, issues = Apply({ Server = { starterItems = { { name = 'water', count = 3 }, { name = '', count = 1 }, { name = 'x', count = 0 }, 'a' } } })
assertEqual(#config.Server.starterItems, 1, 'só a entrada válida resta')
assertEqual(config.Server.starterItems[1].count, 3, 'entrada válida preservada')
assert(hasIssue(issues, 'starterItems[2]') and hasIssue(issues, 'starterItems[4]'), 'avisos das entradas inválidas')
config = Apply({ Server = { starterItems = {} } })
assertEqual(#config.Server.starterItems, 0, 'lista vazia respeitada')
config, issues = Apply({ Server = { starterItems = 'water' } })
assertEqual(#config.Server.starterItems, 4, 'starterItems inválido usa o padrão')

-- Containers: mescla por campo, aceita item novo e rejeita item sem modelo.
config, issues = Apply({
	Containers = { items = {
		WEAPON_BRIEFCASE = { position = { x = 0.5 } },
		backpack = { model = 'p_michael_backpack_s' },
		broken = { bone = 10 },
		paperbag = { bone = -1, rotation = { z = 'a' } }
	} }
})
assertEqual(config.Containers.items.WEAPON_BRIEFCASE.position.x, 0.5, 'override de campo')
assertEqual(config.Containers.items.WEAPON_BRIEFCASE.position.y, 0.0, 'campo restante do padrão')
assertEqual(config.Containers.items.WEAPON_BRIEFCASE.model, 'prop_ld_case_01', 'modelo preservado')
assertEqual(config.Containers.items.backpack.model, 'p_michael_backpack_s', 'item novo aceito')
assertEqual(config.Containers.items.backpack.bone, 57005, 'item novo recebe bone padrão')
assertEqual(config.Containers.items.broken, nil, 'item sem model ignorado')
assert(hasIssue(issues, 'items.broken'), 'aviso do item sem model')
assertEqual(config.Containers.items.paperbag.bone, 57005, 'bone inválido volta ao padrão')
assertEqual(config.Containers.items.paperbag.rotation.z, 0.0, 'eixo inválido volta ao padrão do eixo')
assert(hasIssue(issues, 'paperbag.bone') and hasIssue(issues, 'paperbag.rotation.z'), 'avisos do paperbag')

-- Entrada não é alterada (Apply é pura).
local input = { Client = { openKey = 'I' } }
Apply(input)
assertEqual(input.Client.openKey, 'I', 'entrada preservada')
assertEqual(input.Server, nil, 'entrada não recebe padrões')

-- A carga do módulo reescreve Config global com valores resolvidos e imprime os avisos.
Config = { Client = { hotbarSlots = 99 } }
printed = {}
print = function(message) printed[#printed + 1] = message end
dofile('domain/config_schema.lua')
print = realPrint
assertEqual(Config.Client.hotbarSlots, 5, 'Config global corrigida na carga')
assertEqual(#printed, 1, 'um aviso impresso')
assert(printed[1]:find('[coe_inventory] config:', 1, true), 'prefixo do aviso')

print('config_test: ok')
