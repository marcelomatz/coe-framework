dofile('../coe_crafting/config.lua')
dofile('../coe_crafting/server/rules.lua')
dofile('../coe_crafting/server/registry.lua')
dofile('../coe_crafting/server/business.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end

local B = CraftingBusiness
local biz = { id = 'b1', enabled = true, category = 'restaurant', owner = { characterId = '7' },
	stations = { crafts = { { id = 'c1', label = 'Cozinha', x = 1, y = 2, z = 3, radius = 2 }, { id = 'bad' } } } }

biz.enabled = false
eq(#B.Stations(biz, CraftingConfig.BusinessBenches), 0, 'negócio desligado não expõe estações')
biz.enabled = true

local stations = B.Stations(biz, CraftingConfig.BusinessBenches)
eq(#stations, 1, 'só estações válidas')
eq(stations[1].radius, 2, 'raio')
eq(#B.Stations({ id = 'm', category = 'mechanic', stations = biz.stations }, CraftingConfig.BusinessBenches), 0, 'categoria sem bancada')
eq(B.StashId('b1', 'c1'), 'stash:business:b1:c1', 'stash id')
local craftAt = { id = 'c1', x = 0, y = 0, z = 0 }
eq(B.StashFor({ id = 'b1', stations = {} }, craftAt), 'stash:business:b1:c1', 'sem baú: baú da estação')
eq(B.StashFor({ id = 'b1', stations = { stashes = { { id = 'longe', x = 50, y = 0, z = 0 }, { id = 'perto', x = 2, y = 0, z = 0 } } } }, craftAt),
	'stash:business:b1:perto', 'usa o baú do negócio mais próximo')

-- Estações e baús de facção
local fac = {
	id = 'vagos', label = 'Vagos', enabled = true,
	stations = {
		crafts = { { id = 'mesa1', label = 'Mesa da quebrada', x = 10, y = 20, z = 30, radius = 2 } },
		stashes = { { id = 'bau1', label = 'Cofre', x = 12, y = 20, z = 30, radius = 1.5, slots = 60, maxWeight = 200000 } }
	}
}
fac.enabled = false
eq(#B.FactionStations(fac), 0, 'facção inativa não expõe estações')
fac.enabled = true
local facStations = B.FactionStations(fac)
eq(#facStations, 2, 'facção expõe craft e baú')
eq(facStations[1].kind, 'faction', 'tipo craft da facção')
eq(facStations[1].factionId, 'vagos', 'id da facção no craft')
eq(facStations[2].kind, 'faction_stash', 'tipo baú da facção')
eq(facStations[2].slots, 60, 'slots do baú da facção')
eq(B.FactionStashId('vagos', 'bau1'), 'stash:faction:vagos:bau1', 'stash id da facção')
eq(B.FactionStashFor(fac, fac.stations.crafts[1]), 'stash:faction:vagos:bau1', 'usa o baú da facção mais próximo')
eq(B.FactionStashFor({ id = 'vagos', stations = {} }, fac.stations.crafts[1]), 'stash:faction:vagos:mesa1', 'sem baú: cai na própria estação')

-- Bancadas ilegais livres
local illegalStations = B.IllegalStations({
	{ id = 'beco', label = 'Bancada do beco', enabled = true, x = 5, y = 6, z = 7, radius = 1.8 },
	{ id = 'off', label = 'Inativa', enabled = false, x = 1, y = 2, z = 3 }
})
eq(#illegalStations, 1, 'só bancadas ilegais ativas')
eq(illegalStations[1].kind, 'illegal', 'tipo illegal')
eq(illegalStations[1].id, 'beco', 'id da bancada ilegal')

local registry = CraftingRegistry.New(CraftingConfig)
for category, def in pairs(CraftingConfig.BusinessBenches) do
	local ok, err = registry.AddBench('business_' .. category, def, 'coe_crafting')
	eq(ok ~= nil, true, 'bancada ' .. category .. ': ' .. tostring(err))
end
eq(registry.AddBench('faction', CraftingConfig.FactionBench, 'coe_crafting') ~= nil, true, 'bancada faction')
eq(registry.AddBench('illegal', CraftingConfig.IllegalBench, 'coe_crafting') ~= nil, true, 'bancada illegal')
for _, recipe in ipairs(CraftingConfig.Recipes) do
	local ok, err = registry.AddRecipe(recipe, 'coe_crafting')
	eq(ok ~= nil, true, 'receita ' .. recipe.id .. ': ' .. tostring(err))
end
print('ok business')
