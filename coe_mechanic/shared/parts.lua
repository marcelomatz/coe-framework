MechanicParts = {}

local function clamp(value, minimum, maximum)
	return math.max(minimum, math.min(maximum, value))
end

function MechanicParts.Wear(mileage, installedAt, life)
	if type(mileage) ~= 'number' or type(installedAt) ~= 'number' or type(life) ~= 'number' or life <= 0 then
		return 0
	end
	return clamp((mileage - installedAt) / life, 0, 1)
end

function MechanicParts.Condition(config, wear)
	if wear >= config.CriticalAt then
		return 'critical'
	end
	if wear >= config.WarnAt then
		return 'warn'
	end
	return 'ok'
end

-- Interpola o efeito: sem efeito até o threshold, efeito total em desgaste 1.
local function strength(part, wear)
	if wear <= part.threshold then
		return 0
	end
	return (wear - part.threshold) / (1 - part.threshold)
end

-- installed = { [part] = installedAtMeters }. Retorna multiplicadores por campo, chave de estado e detalhes.
function MechanicParts.Evaluate(config, installed, mileage)
	local names = {}
	for name in pairs(config.Parts) do
		names[#names + 1] = name
	end
	table.sort(names)

	local mods, keyParts, details = {}, {}, {}
	for _, name in ipairs(names) do
		local part = config.Parts[name]
		local installedAt = installed[name] or 0
		local wear = MechanicParts.Wear(mileage, installedAt, part.life)
		-- Passos de 2% mantêm a chave (e a republicação do handling) estável.
		local step = math.floor(wear * 50 + 0.5)
		local stepWear = step / 50
		keyParts[#keyParts + 1] = step
		details[#details + 1] = {
			part = name,
			wear = wear,
			installedAtMeters = installedAt,
			condition = MechanicParts.Condition(config, wear)
		}
		local power = strength(part, stepWear)
		if power > 0 then
			for field, atWorn in pairs(part.effects) do
				mods[field] = (mods[field] or 1) * (1 + (atWorn - 1) * power)
			end
		end
	end
	return mods, table.concat(keyParts, ','), details
end
