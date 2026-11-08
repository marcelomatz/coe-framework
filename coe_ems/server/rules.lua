EmsRules = {}

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

function EmsRules.NewBleedoutWheel(tickResolutionMs)
	if Containers and type(Containers.newTimingWheel) == 'function' then
		return Containers.newTimingWheel(tickResolutionMs or 5000)
	end
	return nil
end

function EmsRules.NewReportLimiter(emissionIntervalMs, burstTolerance)
	if RateLimit and type(RateLimit.newGCRA) == 'function' then
		return RateLimit.newGCRA(emissionIntervalMs or 1000, burstTolerance or 0)
	end
	return nil
end

EmsRules.States = { healthy = true, injured = true, unconscious = true, dead = true }

-- O cliente só reporta o que o próprio jogo mostra; morrer e reviver são decisões do servidor.
local CLIENT_REPORTS = {
	healthy = { injured = true, unconscious = true },
	injured = { healthy = true, unconscious = true }
}

function EmsRules.CanReport(from, to)
	return CLIENT_REPORTS[from] ~= nil and CLIENT_REPORTS[from][to] == true
end

-- Pré-condição do estado do paciente para cada ação. Retorna true ou false, 'invalid_state'.
function EmsRules.CanApply(action, state, config)
	if action == 'revive' then
		if state == 'unconscious' or (state == 'dead' and config.ReviveDead == true) then
			return true
		end
	elseif action == 'treat' then
		if state == 'injured' then
			return true
		end
	elseif action == 'respawn' then
		if state == 'dead' then
			return true
		end
	end
	return false, 'invalid_state'
end

-- Resultado de cada ação no estado do paciente.
EmsRules.Outcome = { revive = 'healthy', treat = 'healthy', respawn = 'healthy' }

function EmsRules.Detail(value)
	if value == nil then
		return ''
	end
	if type(value) ~= 'string' or #value > 32 or not value:match('^[a-z0-9_]*$') then
		return nil, 'invalid_detail'
	end
	return value
end

function EmsRules.InRange(distance, config)
	return type(distance) == 'number' and distance <= config.ActionRange
end

-- Segundos inconsciente até o óbito; 0 desliga.
function EmsRules.BledOut(since, now, config)
	return config.BleedoutSeconds > 0 and now - since >= config.BleedoutSeconds
end
