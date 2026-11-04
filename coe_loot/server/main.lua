local config = LootConfig
local tables = {}

local function log(level, category, event, context)
	pcall(function()
		return exports.coe_logging:Log(level, category, event, context)
	end)
end

local function audit(event, context)
	pcall(function()
		return exports.coe_audit:Record('info', 'audit', event, context)
	end)
end

local function notify(playerId, kind, message)
	pcall(function()
		exports.coe_notify:Notify(playerId, kind, message)
	end)
end

local _t = (Core and Core.Locale and Core.Locale.Bind) and Core.Locale.Bind(Locales) or function(k) return (Locales and Locales['pt-BR'] and Locales['pt-BR'][k]) or k end

-- Tabelas válidas do config; as inválidas ficam de fora com aviso no log.
for id, definition in pairs(config.Tables) do
	local ok, reason = LootRules.Validate(id, definition)
	if ok then
		tables[id] = definition
	else
		log('error', 'system', 'loot_table_invalid', { operation = id, error_code = reason })
	end
end

local function allowed()
	local resource = GetInvokingResource()
	if CoeAccess and CoeAccess.Allowed then
		return CoeAccess.Allowed(resource, config.Ace, config.Callers)
	end
	return config.Callers[resource or ''] == true
end

local function random(a, b)
	return math.random(a, b)
end

local function addItems(characterId, list)
	local inventory = 'character:' .. characterId
	local given, lost = {}, {}
	for _, entry in ipairs(list) do
		local units = entry.unique and entry.count or 1
		local amount = entry.unique and 1 or entry.count
		local delivered = 0
		for _ = 1, units do
			local ok, added = pcall(function()
				return exports.coe_inventory:AddItem(inventory, entry.item, amount)
			end)
			if ok and added == true then
				delivered = delivered + amount
			end
		end
		if delivered > 0 then
			given[#given + 1] = { item = entry.item, count = delivered }
		end
		if delivered < entry.count then
			lost[#lost + 1] = { item = entry.item, count = entry.count - delivered }
		end
	end
	return given, lost
end

local function give(playerId, tableId, source)
	local definition = type(tableId) == 'string' and tables[tableId]
	if not definition then
		return { ok = false, error = 'unknown_table' }
	end
	local characterId = Core.Players.GetActiveCharacterId(playerId)
	if not characterId then
		return { ok = false, error = 'no_character' }
	end
	characterId = tostring(characterId)
	local list = LootRules.Roll(definition, random)
	local given, lost = addItems(characterId, list)
	for _, entry in ipairs(given) do
		audit('loot_given', { character_id = characterId, item = entry.item, count = entry.count, operation = tableId, source = source })
	end
	return { ok = true, given = given, lost = lost }
end

-- Sorteia sem entregar: { ok, items = { { item, count } } }. Para quem quer pôr o saque num baú ou no chão.
exports('Roll', function(tableId)
	if not allowed() then
		return { ok = false, error = 'forbidden' }
	end
	local definition = type(tableId) == 'string' and tables[tableId]
	if not definition then
		return { ok = false, error = 'unknown_table' }
	end
	local items = {}
	for _, entry in ipairs(LootRules.Roll(definition, random)) do
		items[#items + 1] = { item = entry.item, count = entry.count, unique = entry.unique }
	end
	return { ok = true, items = items }
end)

-- Sorteia e entrega no inventário do personagem: { ok, given, lost } (lost: o que não coube).
exports('Give', function(playerId, tableId)
	if not allowed() then
		return { ok = false, error = 'forbidden' }
	end
	return give(tonumber(playerId), tableId, GetInvokingResource())
end)

-- Tabelas disponíveis: { id, label }.
exports('Tables', function()
	local list = {}
	for id, definition in pairs(tables) do
		list[#list + 1] = { id = id, label = definition.label or id }
	end
	table.sort(list, function(a, b) return a.id < b.id end)
	return list
end)

RegisterCommand(config.TestCommand, function(playerId, args)
	if playerId == 0 then
		print('Use em jogo: /' .. config.TestCommand .. ' <tabela>')
		return
	end
	local result = give(playerId, args[1], 'test_command')
	if not result.ok then
		notify(playerId, 'error', _t('invalid_table', { table = tostring(args[1]) }))
		return
	end
	local parts = {}
	for _, entry in ipairs(result.given) do
		parts[#parts + 1] = entry.count .. 'x ' .. entry.item
	end
	notify(playerId, 'info', #parts > 0 and _t('loot_result', { items = table.concat(parts, ', ') }) or _t('loot_empty'))
end, true)
