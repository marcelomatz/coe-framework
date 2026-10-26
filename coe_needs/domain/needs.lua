Needs = {}

local cfg = Config.Needs
local validName = {}
for _, name in ipairs(cfg.Names) do
	validName[name] = true
end

local function clamp(value)
	local num = tonumber(value)
	if not num or num ~= num then
		return 0
	end
	if num < 0 then
		return 0
	end
	if num > 100 then
		return 100
	end
	return num
end

function Needs.New(raw)
	local state = {}
	for _, name in ipairs(cfg.Names) do
		local value = type(raw) == 'table' and raw[name] or nil
		if tonumber(value) == nil then
			value = cfg.Initial[name]
		end
		state[name] = clamp(value)
	end
	return state
end

function Needs.Copy(state)
	local copy = {}
	for _, name in ipairs(cfg.Names) do
		copy[name] = clamp(state and state[name] or cfg.Initial[name])
	end
	return copy
end

function Needs.IsActivity(activity)
	return type(activity) == 'string' and cfg.Rates[activity] ~= nil
end

-- Aplica a variacao dos segundos decorridos na atividade informada.
function Needs.Step(state, activity, seconds)
	local rate = cfg.Rates[activity]
	local dt = tonumber(seconds)
	if not rate or not dt or dt <= 0 then
		return state
	end
	local minutes = dt / 60
	for _, name in ipairs(cfg.Names) do
		local delta = (rate[name] or 0) * minutes
		state[name] = clamp(state[name] + delta)
	end
	return state
end

function Needs.Set(state, name, value)
	local num = tonumber(value)
	if not validName[name] or not num or num ~= num or math.abs(num) == math.huge then
		return false, 'invalid_need'
	end
	state[name] = clamp(num)
	return true
end

function Needs.Add(state, name, delta)
	local num = tonumber(delta)
	if not validName[name] or not num or num ~= num or math.abs(num) == math.huge then
		return false, 'invalid_need'
	end
	state[name] = clamp((state[name] or 0) + num)
	return true
end

-- Inteiros de 0 a 100 para envio ao client e ao HUD.
function Needs.Snapshot(state)
	local snap = {}
	for _, name in ipairs(cfg.Names) do
		snap[name] = math.floor((state[name] or 0) + 0.5)
	end
	return snap
end

function Needs.SnapshotEquals(a, b)
	if not a or not b then
		return false
	end
	for _, name in ipairs(cfg.Names) do
		if a[name] ~= b[name] then
			return false
		end
	end
	return true
end
