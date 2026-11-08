-- Regras puras do coe_loot (sem natives), usadas pelo servidor e pelos testes.
LootRules = {}

local function resolveSampling()
	if type(Core) == 'table' and type(Core.Algorithms) == 'table' and type(Core.Algorithms.Sampling) == 'table' then
		return Core.Algorithms.Sampling
	end
	if type(CoeAlgorithms) == 'table' and type(CoeAlgorithms.Sampling) == 'table' then
		return CoeAlgorithms.Sampling
	end
	if type(LoadResourceFile) == 'function' and type(load) == 'function' then
		local src = LoadResourceFile('coe_core', 'lib/algorithms/sampling.lua')
		if type(src) == 'string' and src ~= '' then
			local fn = load(src, '@@coe_core/lib/algorithms/sampling.lua', 't', _G)
			if fn then
				local ok, mod = pcall(fn)
				if ok and type(mod) == 'table' then
					return mod
				end
			end
		end
		return nil
	end
	if type(loadfile) == 'function' then
		local candidates = {
			'../coe_core/lib/algorithms/sampling.lua',
			'coe-framework/coe_core/lib/algorithms/sampling.lua',
			'dev/coe_core/lib/algorithms/sampling.lua',
		}
		for i = 1, #candidates do
			local chunk = loadfile(candidates[i])
			if chunk then
				local ok, mod = pcall(chunk)
				if ok and type(mod) == 'table' then
					return mod
				end
			end
		end
	end
	return nil
end

local Sampling = resolveSampling()

local function int(value)
	return math.tointeger(tonumber(value))
end

-- Constrói (e memoriza) o amostrador O(1) pelo Método de Alias de Vose para uma lista de entries.
function LootRules.BuildAliasSampler(entries)
	if type(entries) ~= 'table' or #entries == 0 or not Sampling then
		return nil
	end
	local cached = rawget(entries, '_aliasSampler')
	if cached and rawget(entries, '_aliasCount') == #entries then
		return cached
	end
	local items = {}
	for index = 1, #entries do
		local entry = entries[index]
		local weight = tonumber(entry and entry.weight) or 0
		if weight <= 0 then
			return nil
		end
		items[index] = {
			item = entry,
			value = entry,
			weight = weight,
		}
	end
	local ok, sampler = pcall(Sampling.newAliasTable, items)
	if not ok or not sampler then
		return nil
	end
	rawset(entries, '_aliasSampler', sampler)
	rawset(entries, '_aliasCount', #entries)
	return sampler
end

-- Valida uma tabela. Devolve true ou nil + motivo.
function LootRules.Validate(id, definition)
	if type(id) ~= 'string' or not id:match('^[a-z][a-z0-9_]*$') or #id > 32 then
		return nil, 'invalid_id'
	end
	if type(definition) ~= 'table' or type(definition.entries) ~= 'table' or #definition.entries == 0 then
		return nil, 'no_entries'
	end
	local rolls = definition.rolls or {}
	local minRolls, maxRolls = int(rolls.min or 1), int(rolls.max or rolls.min or 1)
	if not minRolls or not maxRolls or minRolls < 0 or maxRolls < minRolls or maxRolls > 20 then
		return nil, 'invalid_rolls'
	end
	for index, entry in ipairs(definition.entries) do
		local weight = int(entry.weight)
		if not weight or weight <= 0 then
			return nil, 'invalid_weight', index
		end
		if not entry.nothing then
			if type(entry.item) ~= 'string' or entry.item == '' then
				return nil, 'invalid_item', index
			end
			local low, high = int(entry.min or 1), int(entry.max or entry.min or 1)
			if not low or not high or low < 1 or high < low or high > 100000 then
				return nil, 'invalid_count', index
			end
			if entry.unique and high > 10 then
				return nil, 'invalid_count', index
			end
		end
	end
	return true
end

-- Escolhe uma entrada pelo peso.
-- Quando rand é nil ou math.random, utiliza o Método de Alias de Vose em O(1).
-- Quando rand é uma função determinística injetada em testes, preserva a busca acumulada exata.
function LootRules.Pick(entries, rand)
	if rand == nil or rand == math.random then
		local sampler = LootRules.BuildAliasSampler(entries)
		if sampler then
			return sampler:sample()
		end
		rand = rand or math.random
	end
	local total = 0
	for _, entry in ipairs(entries) do
		total = total + entry.weight
	end
	local target = rand(1, total)
	for _, entry in ipairs(entries) do
		target = target - entry.weight
		if target <= 0 then
			return entry
		end
	end
	return entries[#entries]
end

-- Sorteia uma tabela: lista { item, count, unique } somada por item, na ordem em que apareceu.
function LootRules.Roll(definition, rand)
	local rolls = definition.rolls or {}
	local minRolls = int(rolls.min or 1)
	local maxRolls = int(rolls.max or rolls.min or 1)
	local count = rand(minRolls, maxRolls)
	local byItem, order = {}, {}
	for _ = 1, count do
		local entry = LootRules.Pick(definition.entries, rand)
		if not entry.nothing then
			local amount = rand(int(entry.min or 1), int(entry.max or entry.min or 1))
			if not byItem[entry.item] then
				byItem[entry.item] = { item = entry.item, count = 0, unique = entry.unique == true }
				order[#order + 1] = entry.item
			end
			byItem[entry.item].count = byItem[entry.item].count + amount
		end
	end
	local list = {}
	for _, item in ipairs(order) do
		list[#list + 1] = byItem[item]
	end
	return list
end

-- Chance (0 a 1) de uma entrada sair pelo menos uma vez, considerando o número de sorteios uniforme entre min e max.
function LootRules.Chance(definition, item)
	local total, weight = 0, 0
	for _, entry in ipairs(definition.entries) do
		total = total + entry.weight
		if entry.item == item then
			weight = weight + entry.weight
		end
	end
	local rolls = definition.rolls or {}
	local minRolls = int(rolls.min or 1)
	local maxRolls = int(rolls.max or rolls.min or 1)
	local sum = 0
	for count = minRolls, maxRolls do
		sum = sum + (1 - (1 - weight / total) ^ count)
	end
	return sum / (maxRolls - minRolls + 1)
end
