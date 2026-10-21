VehicleRegistry = {}

local MODEL_PATTERN = '^[%w_]+$'
local MAX_MODEL_LENGTH = 48
local STATES = { stored = true, out = true, impounded = true }

function VehicleRegistry.New(deps)
	local persistence = deps.persistence
	local config = deps.config
	local now = deps.now
	local audit = deps.audit or function() end

	local byId = {}
	local dirty = {}
	local pinned = {}
	local budgets = {}
	local registry = {}

	local function remember(record)
		record.touched = now()
		byId[record.id] = record
		return record
	end

	local function validCharacterId(value)
		return value == nil or (type(value) == 'string' and value:match('^[1-9]%d*$') ~= nil and #value <= 20)
	end

	function registry.Create(input)
		if type(input) ~= 'table' then
			return nil, 'invalid_input'
		end
		local model = input.model
		if type(model) ~= 'string' or #model == 0 or #model > MAX_MODEL_LENGTH or not model:match(MODEL_PATTERN) then
			return nil, 'invalid_model'
		end
		if not validCharacterId(input.characterId) then
			return nil, 'invalid_character_id'
		end
		local mileage = 0
		if input.mileage ~= nil then
			local normalized, mileageError = VehicleMileage.NormalizeMeters(input.mileage)
			if not normalized then
				return nil, mileageError
			end
			mileage = normalized
		end

		if input.characterId then
			local owned, countError = persistence.CountByOwner(input.characterId)
			if not owned then
				return nil, countError
			end
			if owned >= config.MaxVehiclesPerCharacter then
				return nil, 'vehicle_limit_reached'
			end
		end

		local record = {
			ownerCharacterId = input.characterId,
			model = model:lower(),
			mileage = mileage,
			state = 'stored'
		}

		if input.plate ~= nil then
			local plate, plateError = VehiclePlate.Normalize(input.plate)
			if not plate then
				return nil, plateError
			end
			record.plate = plate
			local id, insertError = persistence.Insert(record)
			if not id then
				return nil, insertError
			end
			record.id = id
		else
			for _ = 1, config.PlateGenerationAttempts do
				local plate, plateError = VehiclePlate.Generate(config.PlatePattern, deps.random)
				if not plate then
					return nil, plateError
				end
				record.plate = plate
				local id, insertError = persistence.Insert(record)
				if id then
					record.id = id
					break
				end
				if insertError ~= 'plate_taken' then
					return nil, insertError
				end
			end
			if not record.id then
				return nil, 'plate_generation_failed'
			end
		end

		remember(record)
		audit('vehicle_created', {
			vehicle_id = record.id,
			plate = record.plate,
			model = record.model,
			character_id = record.ownerCharacterId,
			mileage = record.mileage
		})
		return record
	end

	function registry.Get(id)
		if type(id) ~= 'string' or not id:match('^[1-9]%d*$') then
			return nil, 'invalid_vehicle_id'
		end
		local cached = byId[id]
		if cached then
			cached.touched = now()
			return cached
		end
		local record, errorCode = persistence.FindById(id)
		if not record then
			return nil, errorCode
		end
		return remember(record)
	end

	function registry.GetByPlate(value)
		local plate, plateError = VehiclePlate.Normalize(value)
		if not plate then
			return nil, plateError
		end
		for _, cached in pairs(byId) do
			if cached.plate == plate then
				cached.touched = now()
				return cached
			end
		end
		local record, errorCode = persistence.FindByPlate(plate)
		if not record then
			return nil, errorCode
		end
		return remember(record)
	end

	function registry.ListByOwner(characterId)
		if not characterId or not validCharacterId(characterId) then
			return nil, 'invalid_character_id'
		end
		return persistence.ListByOwner(characterId, config.MaxVehiclesPerCharacter)
	end

	function registry.Pin(id)
		pinned[id] = true
	end

	function registry.Unpin(id)
		pinned[id] = nil
		budgets[id] = nil
	end

	-- Soma ao contador em memória; o banco recebe em lote (ver Flush).
	function registry.AddMileage(id, meters)
		local record, errorCode = registry.Get(id)
		if not record then
			return nil, errorCode
		end
		local delta, deltaError = VehicleMileage.NormalizeMeters(meters)
		if not delta then
			return nil, deltaError
		end
		record.mileage = record.mileage + delta
		dirty[id] = true
		return record.mileage
	end

	-- Reporte do client: consome o orçamento de distância do veículo antes de somar.
	function registry.ReportMileage(id, meters, nowMs)
		local budget = budgets[id]
		if not budget then
			budget = VehicleMileage.NewBudget(config.Mileage)
			budgets[id] = budget
		end
		local accepted, validationError = budget.Consume(meters, nowMs)
		if not accepted then
			return nil, validationError
		end
		return registry.AddMileage(id, accepted)
	end

	-- Correção administrativa/mecânica: grava na hora e audita.
	function registry.SetMileage(id, meters, actor)
		local normalized, mileageError = VehicleMileage.NormalizeMeters(meters)
		if not normalized then
			return nil, mileageError
		end
		local record, errorCode = registry.Get(id)
		if not record then
			return nil, errorCode
		end
		local saved, saveError = persistence.SetMileage(id, normalized)
		if not saved then
			return nil, saveError
		end
		local previous = record.mileage
		record.mileage = normalized
		dirty[id] = nil
		audit('vehicle_mileage_set', {
			vehicle_id = id,
			plate = record.plate,
			mileage = normalized,
			previous_mileage = previous,
			action = actor
		})
		return normalized
	end

	function registry.SetState(id, state)
		if not STATES[state] then
			return nil, 'invalid_state'
		end
		local record, errorCode = registry.Get(id)
		if not record then
			return nil, errorCode
		end
		local saved, saveError = persistence.SetState(id, state)
		if not saved then
			return nil, saveError
		end
		record.state = state
		return true
	end

	function registry.PendingCount()
		local count = 0
		for _ in pairs(dirty) do
			count = count + 1
		end
		return count
	end

	-- Grava a quilometragem pendente em lotes e descarta do cache o que está ocioso.
	function registry.Flush(onlyId)
		local batch = {}
		for id in pairs(dirty) do
			if not onlyId or id == onlyId then
				batch[#batch + 1] = { id = id, mileage = byId[id].mileage }
				if #batch >= config.FlushBatchSize then
					break
				end
			end
		end

		if #batch > 0 then
			local saved, saveError = persistence.UpdateMileageBatch(batch)
			if not saved then
				return false, saveError
			end
			for _, entry in ipairs(batch) do
				local record = byId[entry.id]
				-- Se somou mais enquanto gravava, continua pendente.
				if record and record.mileage == entry.mileage then
					dirty[entry.id] = nil
				end
			end
		end

		local ttl = deps.cacheTtlMs or 0
		if ttl > 0 then
			local limit = now() - ttl
			for id, record in pairs(byId) do
				if not dirty[id] and not pinned[id] and record.touched < limit then
					byId[id] = nil
				end
			end
		end
		return true
	end

	return registry
end
