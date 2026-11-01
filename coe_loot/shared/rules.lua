-- Regras puras do coe_loot (sem natives), usadas pelo servidor e pelos testes.
LootRules = {}

local function int(value)
	return math.tointeger(tonumber(value))
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

-- Escolhe uma entrada pelo peso. rand(a, b) devolve um inteiro de a a b (como math.random).
function LootRules.Pick(entries, rand)
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
