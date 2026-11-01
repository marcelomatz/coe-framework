GaragesRules = {}

-- 'bike' para moto (tipo do catálogo em config.BikeTypes), 'car' para o resto.
function GaragesRules.ClassOf(config, info)
	return type(info) == 'table' and config.BikeTypes[info.type] and 'bike' or 'car'
end

function GaragesRules.Capacity(config, level)
	return config.Levels[level] or config.Levels[config.DefaultLevel]
end

-- used: { car = n, bike = n } já guardados. Devolve true ou nil,'garage_full'.
function GaragesRules.CanStore(config, level, used, class)
	local capacity = GaragesRules.Capacity(config, level)
	if (used[class] or 0) >= (capacity[class] or 0) then
		return nil, 'garage_full'
	end
	return true
end

-- Frota: o dono usa e gerencia tudo; os demais, só o que o dono liberou (pessoa a pessoa ou toda a equipe de ponto batido).
-- entry: { staff = bool, access = { [characterId] = true } }.
function GaragesRules.CanUseFleet(entry, characterId, isOwner, isStaffOnDuty)
	if isOwner then
		return true
	end
	characterId = tostring(characterId)
	if entry.access and entry.access[characterId] then
		return true
	end
	return entry.staff == true and isStaffOnDuty == true
end

-- Equipe do negócio: decidido pelo coe_businesses (Access): é da equipe e pode operar (ponto batido quando clockRequired).
function GaragesRules.IsStaff(access)
	return type(access) == 'table' and access.staff == true and access.canWork == true
end

function GaragesRules.IsOwner(business, characterId)
	return business.owner ~= nil and characterId ~= nil and business.owner.characterId == tostring(characterId)
end
