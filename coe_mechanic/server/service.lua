MechanicService = {}

function MechanicService.New(deps)
	local persistence = deps.persistence
	local config = deps.config
	local audit = deps.audit or function() end

	local service = {}
	local cache = {}

	local function installedOf(vehicleId)
		local cached = cache[vehicleId]
		if cached then
			return cached
		end
		local installed, errorCode = persistence.ListParts(vehicleId)
		if not installed then
			return nil, errorCode
		end
		cache[vehicleId] = installed
		return installed
	end

	function service.Forget(vehicleId)
		cache[vehicleId] = nil
	end

	-- { mods, key, parts } para a quilometragem informada.
	function service.Inspect(vehicleId, mileage)
		local installed, errorCode = installedOf(vehicleId)
		if not installed then
			return nil, errorCode
		end
		local mods, key, details = MechanicParts.Evaluate(config, installed, mileage)
		return { mods = mods, key = key, parts = details }
	end

	function service.ReplacePart(vehicleId, part, mileage, actor)
		if type(part) ~= 'string' or not config.Parts[part] then
			return nil, 'unknown_part'
		end
		if type(mileage) ~= 'number' or mileage < 0 then
			return nil, 'invalid_mileage'
		end
		local installed, errorCode = installedOf(vehicleId)
		if not installed then
			return nil, errorCode
		end
		local saved, saveError = persistence.SavePart(vehicleId, part, mileage)
		if not saved then
			return nil, saveError
		end
		installed[part] = mileage
		audit('vehicle_part_replaced', { vehicle_id = vehicleId, item = part, operation = actor, mileage = mileage })
		return true
	end

	-- Desgaste extra (metros, negativo desconta) nas peças informadas. O cache é refeito na próxima leitura.
	function service.AddWear(vehicleId, meters, parts)
		meters = math.tointeger(tonumber(meters) and math.floor(tonumber(meters)) or nil)
		if not meters or meters == 0 or math.abs(meters) > 1000000 then
			return nil, 'invalid_meters'
		end
		if type(parts) ~= 'table' or #parts == 0 then
			return nil, 'invalid_parts'
		end
		for _, part in ipairs(parts) do
			if type(part) ~= 'string' or not config.Parts[part] then
				return nil, 'unknown_part'
			end
		end
		for _, part in ipairs(parts) do
			local saved, saveError = persistence.AddWear(vehicleId, part, meters)
			if not saved then
				return nil, saveError
			end
		end
		cache[vehicleId] = nil
		return true
	end

	-- Troca todas as peças que passaram do aviso; retorna quais foram trocadas.
	function service.ServiceAll(vehicleId, mileage, actor)
		local inspection, errorCode = service.Inspect(vehicleId, mileage)
		if not inspection then
			return nil, errorCode
		end
		local replaced = {}
		for _, detail in ipairs(inspection.parts) do
			if detail.condition ~= 'ok' then
				local done, replaceError = service.ReplacePart(vehicleId, detail.part, mileage, actor)
				if not done then
					return nil, replaceError
				end
				replaced[#replaced + 1] = detail.part
			end
		end
		return replaced
	end

	return service
end
