MechanicTablet = {}

local PLATE_PATTERN = '^[%w ]+$'

local function validPlate(plate)
	return type(plate) == 'string' and #plate >= 1 and #plate <= 8 and plate:match(PLATE_PATTERN) ~= nil
end

local function partsOf(deps, record)
	local parts = deps.inspect(record.id)
	return type(parts) == 'table' and parts or {}
end

local function vehicleView(deps, record)
	return {
		plate = record.plate,
		model = record.model,
		mileage = deps.mileage(record.id) or record.mileage or 0,
		parts = partsOf(deps, record)
	}
end

-- Localiza o veículo pela placa e exige que o mecânico esteja ao lado dele.
local function locate(deps, playerId, payload)
	if type(payload) ~= 'table' or not validPlate(payload.plate) then
		return nil, 'invalid_plate'
	end
	local record = deps.byPlate(payload.plate)
	if type(record) ~= 'table' then
		return nil, 'vehicle_not_found'
	end
	local distance = deps.distance(playerId, record.id)
	if not distance or distance > deps.radius then
		return nil, 'vehicle_too_far'
	end
	return record
end

-- deps: byPlate, inspect, mileage, distance(playerId, vehicleId), replacePart, serviceAll, radius.
function MechanicTablet.Handle(deps, playerId, action, payload)
	local record, errorCode = locate(deps, playerId, payload)
	if not record then
		return { ok = false, error = errorCode }
	end

	if action == 'scan' then
		return { ok = true, vehicle = vehicleView(deps, record) }
	end

	if action == 'replace' then
		local part = payload.part
		if type(part) ~= 'string' or #part > 32 then
			return { ok = false, error = 'invalid_part' }
		end
		local result
		if part == 'all' then
			result = deps.serviceAll(record.id)
		else
			result = deps.replacePart(record.id, part)
		end
		if result ~= true then
			return { ok = false, error = tostring(result) }
		end
		return { ok = true, vehicle = vehicleView(deps, record) }
	end

	return { ok = false, error = 'unknown_action' }
end
