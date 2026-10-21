VehicleMileage = {}

local METERS_PER_KM = 1000
local METERS_PER_MILE = 1609.344

-- Quilometragem sempre em metros inteiros; nunca negativa.
function VehicleMileage.NormalizeMeters(value)
	local number = tonumber(value)
	if not number or number ~= number or number < 0 or number == math.huge then
		return nil, 'invalid_mileage'
	end
	return math.floor(number)
end

-- Orçamento de distância por veículo: cresce com o tempo à velocidade máxima plausível
-- e é consumido a cada reporte, então reportes frequentes não burlam o limite.
function VehicleMileage.NewBudget(limits)
	local budget = {
		credit = limits.MaxSpeedMetersPerSecond * limits.InitialCreditSeconds,
		at = nil
	}
	local cap = limits.MaxSpeedMetersPerSecond * limits.MaxCreditSeconds

	function budget.Consume(deltaMeters, nowMs)
		local delta = tonumber(deltaMeters)
		if not delta or delta ~= delta or delta < 0 or delta == math.huge then
			return nil, 'invalid_delta'
		end
		if budget.at then
			local elapsed = math.max(nowMs - budget.at, 0)
			budget.credit = math.min(budget.credit + limits.MaxSpeedMetersPerSecond * (elapsed / 1000), cap)
		end
		budget.at = nowMs
		if delta > budget.credit then
			return nil, 'implausible_delta'
		end
		budget.credit = budget.credit - delta
		return math.floor(delta)
	end

	return budget
end

function VehicleMileage.ToUnit(meters, unit)
	local divisor = unit == 'mph' and METERS_PER_MILE or METERS_PER_KM
	return math.floor((meters / divisor) * 10 + 0.5) / 10
end

-- Acumula a distância percorrida a partir de posições amostradas.
-- Ignora jitter parado (`minStep`) e saltos de teleporte (`maxJump`).
function VehicleMileage.NewSampler(minStep, maxJump)
	local sampler = { lastX = nil, lastY = nil, lastZ = nil, pending = 0 }

	function sampler.Step(x, y, z)
		if sampler.lastX then
			local dx, dy, dz = x - sampler.lastX, y - sampler.lastY, z - sampler.lastZ
			local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
			if distance >= minStep and distance <= maxJump then
				sampler.pending = sampler.pending + distance
			end
		end
		sampler.lastX, sampler.lastY, sampler.lastZ = x, y, z
		return sampler.pending
	end

	-- Retorna os metros inteiros acumulados e mantém a fração restante.
	function sampler.Take()
		local whole = math.floor(sampler.pending)
		sampler.pending = sampler.pending - whole
		return whole
	end

	function sampler.Reset()
		sampler.lastX, sampler.lastY, sampler.lastZ = nil, nil, nil
	end

	return sampler
end
