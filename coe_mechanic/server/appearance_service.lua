MechanicAppearanceService = {}

function MechanicAppearanceService.New(deps)
	local persistence = deps.persistence
	local config = deps.config
	local audit = deps.audit or function() end

	local service = {}
	local cache = {}

	function service.Get(vehicleId)
		local cached = cache[vehicleId]
		if cached then
			return cached
		end
		local stored, errorCode = persistence.FindAppearance(vehicleId)
		if errorCode then
			return nil, errorCode
		end
		cached = stored or {}
		cache[vehicleId] = cached
		return cached
	end

	function service.Forget(vehicleId)
		cache[vehicleId] = nil
	end

	-- Valida o patch, mescla sobre o atual e persiste. Retorna a aparência final.
	function service.Apply(vehicleId, patch, actor)
		local clean, invalid = MechanicAppearance.Sanitize(config, patch)
		if not clean then
			return nil, invalid
		end
		local current, errorCode = service.Get(vehicleId)
		if not current then
			return nil, errorCode
		end
		local merged = MechanicAppearance.Merge(current, clean)
		local saved, saveError = persistence.SaveAppearance(vehicleId, merged)
		if not saved then
			return nil, saveError
		end
		cache[vehicleId] = merged
		audit('vehicle_appearance_set', { vehicle_id = vehicleId, operation = actor })
		return merged
	end

	-- Orçamento do patch sem gravar nada.
	function service.Quote(vehicleId, patch, vehiclePrice, class)
		local clean, invalid = MechanicAppearance.Sanitize(config, patch)
		if not clean then
			return nil, invalid
		end
		local current, errorCode = service.Get(vehicleId)
		if not current then
			return nil, errorCode
		end
		return MechanicAppearance.Quote(config, current, clean, vehiclePrice, class)
	end

	return service
end
