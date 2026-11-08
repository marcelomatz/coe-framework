-- Limitação de taxa exata em memória O(1) via Generic Cell Rate Algorithm (GCRA) em inteiros de 64 bits.
local math_max = math.max

local RateLimit = {}
RateLimit.__index = RateLimit

---@param emissionIntervalMs integer Intervalo T entre requisições sustentadas (ex.: 200 ms = 5 req/s)
---@param burstToleranceMs? integer Tolerância de rajada tau (ex.: 600 ms permite burst imediato de 4 reqs)
---@return CoeGCRALimiter
function RateLimit.newGCRA(emissionIntervalMs, burstToleranceMs)
	assert(emissionIntervalMs and emissionIntervalMs > 0, 'Intervalo de emissao T deve ser > 0')
	return setmetatable({
		T = emissionIntervalMs,
		tau = burstToleranceMs or 0,
		tats = {},        -- key -> integer TAT (ms)
		violations = {}   -- key -> integer contagem consecutiva para telemetria coe_shield
	}, RateLimit)
end

function RateLimit:allow(key, nowMs, cost)
	local increment = self.T * (cost or 1)
	local tat = self.tats[key] or nowMs
	local baseTime = math_max(tat, nowMs)
	local diff = baseTime - nowMs

	if diff <= self.tau then
		self.tats[key] = baseTime + increment
		self.violations[key] = nil
		return true, 0, 0
	else
		local retryAfterMs = diff - self.tau
		local vCount = (self.violations[key] or 0) + 1
		self.violations[key] = vCount
		return false, retryAfterMs, vCount
	end
end

function RateLimit:reset(key)
	self.tats[key] = nil
	self.violations[key] = nil
end

RateLimit.forget = RateLimit.reset

function RateLimit:sweep(nowMs)
	local removed = 0
	local cutoff = nowMs - self.tau
	for k, tat in pairs(self.tats) do
		if tat <= cutoff then
			self.tats[k] = nil
			self.violations[k] = nil
			removed = removed + 1
		end
	end
	return removed
end

return RateLimit
