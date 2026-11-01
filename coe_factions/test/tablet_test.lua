dofile('../coe_factions/config.lua')
dofile('../coe_factions/server/rules.lua')
dofile('../coe_factions/server/tablet.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end

local vagos = assert(FactionsRules.Normalize({
	id = 'vagos', label = 'Vagos', category = 'gang',
	grades = { { grade = 0, label = 'Novato' }, { grade = 1, label = 'Soldado' }, { grade = 2, label = 'Líder' } },
	crafts = { { recipe = 'weapon_pistol', minGrade = 0 }, { recipe = 'drug_pack', minGrade = 1 } }
}, FactionsConfig))

local ballas = assert(FactionsRules.Normalize({
	id = 'ballas', label = 'Ballas', category = 'gang',
	grades = { { grade = 0, label = 'Membro' } },
	crafts = {}
}, FactionsConfig))

local inativa = assert(FactionsRules.Normalize({
	id = 'inativa', label = 'Inativa', category = 'mafia', enabled = false,
	grades = { { grade = 0, label = 'Membro' } },
	crafts = {}
}, FactionsConfig))

local factions = { vagos = vagos, ballas = ballas, inativa = inativa }
local callerName = 'coe_tablet'
local isReady = true
local characters = { [1] = '10', [2] = '11', [3] = '99' }
local memberships = {
	['10'] = { vagos = 0, ballas = 0, inativa = 0 },
	['11'] = { vagos = 2 },
	['99'] = {}
}
local members = {
	vagos = {
		{ characterId = '10', name = 'Fulano', grade = 0 },
		{ characterId = '11', name = 'Sicrano', grade = 2 }
	}
}

local deps = {
	config = FactionsConfig,
	caller = function() return callerName end,
	ready = function() return isReady end,
	characterOf = function(playerId) return characters[playerId] end,
	get = function(id) return factions[id] end,
	membershipsOf = function(characterId) return memberships[characterId] end,
	listMembers = function(factionId) return members[factionId] end
}

-- Caller restrito ao coe_tablet e estado ready
callerName = 'outro_resource'
eq(#FactionsTablet.Instances(deps, 1), 0, 'instances bloqueado fora do coe_tablet')
eq(FactionsTablet.Call(deps, 1, 'faction', 'overview', nil, 'vagos').error, 'forbidden', 'call bloqueado fora do coe_tablet')
callerName = 'coe_tablet'

isReady = false
eq(#FactionsTablet.Instances(deps, 1), 0, 'instances vazio antes do ready')
eq(FactionsTablet.Call(deps, 1, 'faction', 'overview', nil, 'vagos').error, 'forbidden', 'call bloqueado antes do ready')
isReady = true

-- Instâncias: apenas facções ativas do personagem, ordenadas por label
local list = FactionsTablet.Instances(deps, 1)
eq(#list, 2, 'duas faccoes ativas (inativa ignorada)')
eq(list[1].id, 'ballas', 'ordenada por label 1')
eq(list[2].id, 'vagos', 'ordenada por label 2')
eq(#FactionsTablet.Instances(deps, 3), 0, 'estranho sem faccao')
eq(#FactionsTablet.Instances(deps, 99), 0, 'sem personagem')

-- Validação de app, ação e vínculo
eq(FactionsTablet.Call(deps, 1, 'bank', 'overview', nil, 'vagos').error, 'forbidden', 'appId errado')
eq(FactionsTablet.Call(deps, 1, 'faction', 'kick', nil, 'vagos').error, 'unknown_action', 'acao desconhecida')
eq(FactionsTablet.Call(deps, 3, 'faction', 'overview', nil, 'vagos').error, 'forbidden', 'nao membro')
eq(FactionsTablet.Call(deps, 99, 'faction', 'overview', nil, 'vagos').error, 'forbidden', 'sem personagem ativo')
eq(FactionsTablet.Call(deps, 1, 'faction', 'overview', nil, 'inexistente').error, 'forbidden', 'faccao inexistente')
eq(FactionsTablet.Call(deps, 1, 'faction', 'overview', nil, 'inativa').error, 'forbidden', 'faccao inativa recusada')

-- Revalidação de grau, membros e receitas por grau
local novato = FactionsTablet.Call(deps, 1, 'faction', 'overview', nil, 'vagos')
eq(novato.ok, true, 'overview novato ok')
eq(novato.faction.label, 'Vagos', 'label')
eq(novato.faction.category, 'Gangue', 'categoria traduzida')
eq(novato.faction.grade, 'Novato', 'grau 0')
eq(#novato.faction.recipes, 1, 'novato ve 1 receita')
eq(novato.faction.recipes[1], 'weapon_pistol', 'receita de grau 0')
eq(#novato.faction.members, 2, 'lista de membros')
eq(novato.faction.members[1].me, true, 'marca o proprio membro')
eq(novato.faction.members[2].me, false, 'outro membro')

local lider = FactionsTablet.Call(deps, 2, 'faction', 'overview', nil, 'vagos')
eq(lider.ok, true, 'overview lider ok')
eq(lider.faction.grade, 'Líder', 'grau 2')
eq(#lider.faction.recipes, 2, 'lider ve 2 receitas')

-- Remoção de vínculo em tempo real bloqueia imediatamente a próxima chamada
memberships['10'].vagos = nil
eq(FactionsTablet.Call(deps, 1, 'faction', 'overview', nil, 'vagos').error, 'forbidden', 'vinculo removido revalidado')

print('factions tablet_test ok')
