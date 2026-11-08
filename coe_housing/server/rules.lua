HousingRules = {}

local DAY = 86400

function HousingRules.ValidCycle(days, config)
	for _, allowed in ipairs(config.RentCycles) do
		if days == allowed then
			return true
		end
	end
	return false
end

function HousingRules.Total(dailyRate, cycleDays)
	return dailyRate * cycleDays
end

function HousingRules.NextPaidUntil(paidUntil, cycleDays)
	return paidUntil + cycleDays * DAY
end

-- ok: em dia (ou contrato gratuito); due: venceu e ainda dá para cobrar; expired: passou da tolerância.
function HousingRules.State(tenancy, now, config)
	if tenancy.cycleDays == 0 or now < tenancy.paidUntil then
		return 'ok'
	end
	if now >= tenancy.paidUntil + config.GraceDays * DAY then
		return 'expired'
	end
	return 'due'
end

-- Primeira unidade livre de 1..units; `used` é um conjunto de números.
function HousingRules.FirstFreeUnit(units, used)
	for unit = 1, units do
		if not used[unit] then
			return unit
		end
	end
	return nil
end

function HousingRules.ExecuteSaga(steps, context)
	local Concurrency = (Core and Core.Algorithms and Core.Algorithms.Concurrency) or (CoeAlgorithms and CoeAlgorithms.Concurrency)
	if Concurrency and Concurrency.executeSaga then
		local ok, failedStep, reason = Concurrency.executeSaga(steps, context)
		if not ok then
			return false, reason or failedStep
		end
		return true
	end
	local completed = {}
	for _, step in ipairs(steps) do
		local fn = step.action or step.forward
		local ok, err = fn(context)
		if not ok then
			for j = #completed, 1, -1 do
				if completed[j].compensate then
					pcall(completed[j].compensate, context)
				end
			end
			return false, err
		end
		completed[#completed + 1] = step
	end
	return true
end

function HousingRules.NewLockManager()
	local Concurrency = (Core and Core.Algorithms and Core.Algorithms.Concurrency) or (CoeAlgorithms and CoeAlgorithms.Concurrency)
	if Concurrency and Concurrency.newLockManager then
		return Concurrency.newLockManager()
	end
	return nil
end

function HousingRules.NewSpatialGrid(cellSize)
	local Spatial = (Core and Core.Algorithms and Core.Algorithms.Spatial) or (CoeAlgorithms and CoeAlgorithms.Spatial)
	if Spatial and Spatial.newGrid then
		return Spatial.newGrid(cellSize or 64.0)
	end
	return nil
end

function HousingRules.NewActionLimiter(cooldownMs)
	local RateLimit = (Core and Core.Algorithms and Core.Algorithms.RateLimit) or (CoeAlgorithms and CoeAlgorithms.RateLimit)
	if RateLimit and RateLimit.newGCRA then
		return RateLimit.newGCRA(math.max(1, tonumber(cooldownMs) or 300), 0)
	end
	return nil
end
