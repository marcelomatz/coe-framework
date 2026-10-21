-- Regras puras das necessidades (sem natives nem banco), compartilhadas entre client e servidor.
Needs = {}

local function isNeed(name)
	for _, candidate in ipairs(Config.Needs.Names) do
		if candidate == name then
			return true
		end
	end
	return false
end

local function clamp(value)
	return math.max(0, math.min(100, value))
end

function Needs.IsNeed(name)
	return isNeed(name)
end

function Needs.IsActivity(name)
	return type(name) == 'string' and Config.Needs.Rates[name] ~= nil
end

function Needs.New(source)
	local state = {}
	local initial = Config.Needs.Initial
	local input = type(source) == 'table' and source or {}
	for _, name in ipairs(Config.Needs.Names) do
		local value = tonumber(input[name])
		if not value or value ~= value then
			value = initial[name]
		end
		state[name] = clamp(value)
	end
	return state
end

-- Aplica a atividade por `seconds` segundos e devolve o mesmo estado (alterado).
function Needs.Step(state, activity, seconds)
	local rates = Config.Needs.Rates[activity]
	if not rates or type(seconds) ~= 'number' or seconds <= 0 then
		return state
	end
	for _, name in ipairs(Config.Needs.Names) do
		state[name] = clamp(state[name] + (rates[name] or 0) * seconds / 60)
	end
	return state
end

function Needs.Add(state, name, delta)
	if not isNeed(name) or type(delta) ~= 'number' or delta ~= delta then
		return false, 'invalid_need'
	end
	state[name] = clamp(state[name] + delta)
	return true
end

function Needs.Set(state, name, value)
	if not isNeed(name) or type(value) ~= 'number' or value ~= value then
		return false, 'invalid_need'
	end
	state[name] = clamp(value)
	return true
end

-- Valores inteiros enviados ao client e ao HUD.
function Needs.Snapshot(state)
	local snapshot = {}
	for _, name in ipairs(Config.Needs.Names) do
		snapshot[name] = math.floor(state[name] + 0.5)
	end
	return snapshot
end

function Needs.SnapshotEquals(a, b)
	if not a or not b then
		return false
	end
	for _, name in ipairs(Config.Needs.Names) do
		if a[name] ~= b[name] then
			return false
		end
	end
	return true
end
