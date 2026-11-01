DispatchRules = {}

local function finite(value)
	return type(value) == 'number' and value == value and value > -1e6 and value < 1e6
end

-- Definição do código ou nil, codigo. citizenOnly restringe aos códigos abertos ao cidadão.
function DispatchRules.Code(config, code, citizenOnly)
	local definition = type(code) == 'string' and config.Codes[code] or nil
	if not definition or not config.Categories[definition.category] then
		return nil, 'invalid_code'
	end
	if citizenOnly and definition.citizen ~= true then
		return nil, 'invalid_code'
	end
	return definition
end

function DispatchRules.Coords(x, y, z)
	if not (finite(x) and finite(y) and finite(z)) then
		return nil, 'invalid_coords'
	end
	return { x = x + 0.0, y = y + 0.0, z = z + 0.0 }
end

function DispatchRules.Distance(a, b)
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Chamado aberto igual e recente por perto (para somar relatos em vez de duplicar).
function DispatchRules.Duplicate(calls, code, coords, now, config)
	for _, call in pairs(calls) do
		if call.code == code
			and now - call.createdAt <= config.DedupeSeconds
			and DispatchRules.Distance(call, coords) <= config.DedupeRadius then
			return call
		end
	end
	return nil
end

-- Remove chamados vencidos e retorna a lista de ids removidos.
function DispatchRules.Prune(calls, now, config)
	local removed = {}
	for id, call in pairs(calls) do
		if now - call.createdAt > config.TtlSeconds then
			removed[#removed + 1] = id
		end
	end
	table.sort(removed)
	for _, id in ipairs(removed) do
		calls[id] = nil
	end
	return removed
end

function DispatchRules.CountActive(calls, category)
	local total = 0
	for _, call in pairs(calls) do
		if call.category == category then
			total = total + 1
		end
	end
	return total
end

-- Cooldown do cidadão: true quando já pode abrir outro chamado.
function DispatchRules.CooldownReady(lastAt, now, config)
	return lastAt == nil or now - lastAt >= config.CitizenCooldownSeconds
end

-- Ordena por urgência e, a igualdade, pelo mais recente.
function DispatchRules.Sorted(calls, category)
	local list = {}
	for _, call in pairs(calls) do
		if call.category == category then
			list[#list + 1] = call
		end
	end
	table.sort(list, function(a, b)
		if a.priority ~= b.priority then
			return a.priority < b.priority
		end
		return a.id > b.id
	end)
	return list
end

function DispatchRules.CallId(value)
	if type(value) ~= 'number' or value ~= value or value % 1 ~= 0 or value < 1 then
		return nil, 'invalid_call'
	end
	return math.tointeger(value)
end
