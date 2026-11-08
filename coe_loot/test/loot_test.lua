dofile('config.lua')
dofile('shared/rules.lua')

local config = LootConfig
local failures = 0

local function eq(actual, expected, message)
	if actual ~= expected then
		failures = failures + 1
		print(('FAIL %s: esperado %s, obtido %s'):format(message, tostring(expected), tostring(actual)))
	end
end

-- Todas as tabelas do config são válidas e o onion aparece nos roubos.
for id, definition in pairs(config.Tables) do
	eq(LootRules.Validate(id, definition), true, 'tabela válida: ' .. id)
	eq(LootRules.Chance(definition, 'onion_usb') > 0, true, 'onion pode cair em ' .. id)
end

-- Validação
eq(select(2, LootRules.Validate('Casa', { entries = { { item = 'x', weight = 1 } } })), 'invalid_id', 'id com maiúscula')
eq(select(2, LootRules.Validate('a', { entries = {} })), 'no_entries', 'sem entradas')
eq(select(2, LootRules.Validate('a', { rolls = { min = 3, max = 1 }, entries = { { item = 'x', weight = 1 } } })), 'invalid_rolls', 'sorteios invertidos')
eq(select(2, LootRules.Validate('a', { entries = { { item = 'x', weight = 0 } } })), 'invalid_weight', 'peso zero')
eq(select(2, LootRules.Validate('a', { entries = { { weight = 1 } } })), 'invalid_item', 'sem item')
eq(select(2, LootRules.Validate('a', { entries = { { item = 'x', weight = 1, min = 5, max = 2 } } })), 'invalid_count', 'quantidade invertida')
eq(select(2, LootRules.Validate('a', { entries = { { item = 'x', weight = 1, unique = true, max = 50 } } })), 'invalid_count', 'único em excesso')

-- Sorteio pelo peso (rand determinístico: devolve sempre o mínimo ou o máximo)
local entries = { { item = 'a', weight = 3 }, { item = 'b', weight = 1 }, { nothing = true, weight = 6 } }
eq(LootRules.Pick(entries, function(a) return a end).item, 'a', 'menor alvo cai na primeira')
eq(LootRules.Pick(entries, function(_, b) return b end).nothing, true, 'maior alvo cai na última')
eq(LootRules.Pick(entries, function() return 4 end).item, 'b', 'alvo no meio')

-- Roll soma por item e respeita sorteio vazio
local sequence = { 3, 1, 50, 1, 20, 10 }
local index = 0
local function scripted(a, b)
	index = index + 1
	local value = sequence[index]
	return math.max(a, math.min(b, value))
end
local definition = { rolls = { min = 1, max = 3 }, entries = { { item = 'money', weight = 5, min = 10, max = 100 }, { nothing = true, weight = 5 } } }
local list = LootRules.Roll(definition, scripted)
eq(#list, 1, 'um item somado')
eq(list[1].count, 50 + 20, 'dinheiro somado de dois sorteios')

-- Distribuição aproximada (semente fixa)
math.randomseed(42)
local hits, runs = 0, 20000
for _ = 1, runs do
	for _, entry in ipairs(LootRules.Roll(config.Tables.pedestrian_robbery, math.random)) do
		if entry.item == 'onion_usb' then
			hits = hits + 1
			break
		end
	end
end
local expected = LootRules.Chance(config.Tables.pedestrian_robbery, 'onion_usb')
eq(math.abs(hits / runs - expected) < 0.008, true, 'frequência do onion perto da chance calculada')
eq(hits > 0, true, 'onion sai em assalto a pedestre')

-- Amostrador O(1) de Vose (BuildAliasSampler) caches na tabela de entries e respeita proporções
local sampler = LootRules.BuildAliasSampler(config.Tables.pedestrian_robbery.entries)
eq(sampler ~= nil, true, 'BuildAliasSampler constrói tabela de alias O(1)')
eq(LootRules.BuildAliasSampler(config.Tables.pedestrian_robbery.entries), sampler, 'BuildAliasSampler reutiliza instância cacheada')
local picked = LootRules.Pick(config.Tables.pedestrian_robbery.entries)
eq(type(picked), 'table', 'Pick sem rand customizado usa Alias Table O(1)')

if failures > 0 then
	print(('%d falha(s)'):format(failures))
	os.exit(1)
end
print('loot_test: ok')
