Needs = {}

local function resolveAlgorithms()
	if type(Core) == 'table' and type(Core.Algorithms) == 'table' then
		return Core.Algorithms
	end
	if type(CoeAlgorithms) == 'table' then
		return CoeAlgorithms
	end
	if type(LoadResourceFile) == 'function' and type(load) == 'function' then
		local src = LoadResourceFile('coe_core', 'lib/algorithms/init.lua')
		if type(src) == 'string' and src ~= '' then
			local fn = load(src, '@@coe_core/lib/algorithms/init.lua', 't', _G)
			if fn then
				local ok, mod = pcall(fn)
				if ok and type(mod) == 'table' then
					return mod
				end
			end
		end
		return CoeAlgorithms
	end
	if type(loadfile) == 'function' then
		local candidates = {
			'../coe_core/lib/algorithms/init.lua',
			'coe-framework/coe_core/lib/algorithms/init.lua',
			'dev/coe_core/lib/algorithms/init.lua',
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

local Algorithms = resolveAlgorithms()
local Containers = Algorithms and Algorithms.Containers or nil
local RateLimit = Algorithms and Algorithms.RateLimit or nil

function Needs.NewTimingWheel(tickResolutionMs)
	if Containers and type(Containers.newTimingWheel) == 'function' then
		return Containers.newTimingWheel(tickResolutionMs or 1000)
	end
	return nil
end

function Needs.NewActivityLimiter(emissionIntervalMs, burstTolerance)
	if RateLimit and type(RateLimit.newGCRA) == 'function' then
		return RateLimit.newGCRA(emissionIntervalMs or 1000, burstTolerance or 0)
	end
	return nil
end

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
