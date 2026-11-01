HandlingService = {}

local WEAR_STEPS = 100

function HandlingService.New(deps)
	local persistence = deps.persistence
	local config = deps.config
	local audit = deps.audit or function() end

	local service = {}
	local tyres = {}

	local function tyreRow(vehicleId)
		local cached = tyres[vehicleId]
		if cached then
			return cached
		end
		local row, errorCode = persistence.FindTyre(vehicleId)
		if errorCode then
			return nil, errorCode
		end
		row = row or {}
		cached = { compound = row.compound, fittedAt = row.fittedAt or 0 }
		tyres[vehicleId] = cached
		return cached
	end

	function service.Forget(vehicleId)
		tyres[vehicleId] = nil
	end

	-- Estado de pneu e multiplicadores do veículo para a quilometragem informada.
	-- `extra` = { mods = {campo = mult}, key = string } opcional (peças da mecânica).
	function service.Compute(vehicleId, model, mileage, extra)
		local info = deps.getVehicleInfo(model)
		local profile = HandlingEngine.ResolveProfile(config, info and info.class, info and info.category)
		if not profile then
			return nil, 'no_profile'
		end
		local row, errorCode = tyreRow(vehicleId)
		if not row then
			return nil, errorCode
		end
		local compound = row.compound or profile.defaultTyre or config.DefaultTyre
		local tyre = config.Tyres[compound]
		if not tyre then
			return nil, 'unknown_tyre'
		end
		local wear = HandlingEngine.WearFraction(mileage, row.fittedAt, tyre.life)
		-- Passos de 1% evitam republicar o state bag a cada 100 m.
		local step = math.floor(wear * WEAR_STEPS + 0.5)
		local mods = HandlingEngine.Compose(config, profile, compound, step / WEAR_STEPS, extra and extra.mods)
		return {
			mods = mods,
			compound = compound,
			wear = step / WEAR_STEPS,
			key = compound .. ':' .. step .. '|' .. tostring(extra and extra.key or '')
		}
	end

	function service.GetTyre(vehicleId, mileage)
		local row, errorCode = tyreRow(vehicleId)
		if not row then
			return nil, errorCode
		end
		local compound = row.compound or config.DefaultTyre
		local tyre = config.Tyres[compound]
		if not tyre then
			return nil, 'unknown_tyre'
		end
		return {
			compound = compound,
			fittedAtMeters = row.fittedAt,
			wear = HandlingEngine.WearFraction(mileage, row.fittedAt, tyre.life)
		}
	end

	-- Pneus novos: o desgaste recomeça da quilometragem atual.
	function service.SetTyre(vehicleId, compound, mileage, actor)
		if type(compound) ~= 'string' or not config.Tyres[compound] then
			return nil, 'unknown_tyre'
		end
		if type(mileage) ~= 'number' or mileage < 0 then
			return nil, 'invalid_mileage'
		end
		local saved, errorCode = persistence.SaveTyre(vehicleId, compound, mileage)
		if not saved then
			return nil, errorCode
		end
		tyres[vehicleId] = { compound = compound, fittedAt = mileage }
		audit('vehicle_tyre_set', { vehicle_id = vehicleId, item = compound, operation = actor })
		return true
	end

	return service
end
