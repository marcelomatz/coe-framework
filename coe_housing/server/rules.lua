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
