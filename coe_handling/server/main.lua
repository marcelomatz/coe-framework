local config = CoeHandlingConfig
local ready = false
local service

local function log(level, category, event, context)
	pcall(function()
		return exports.coe_logging:Log(level, category, event, context)
	end)
end

local function audit(event, context)
	pcall(function()
		return exports.coe_audit:Record('info', 'audit', event, context)
	end)
end

local function getVehicleInfo(model)
	local ok, info = pcall(function()
		return exports.coe_vehicle_catalog:GetVehicleInfo(model)
	end)
	return ok and info or nil
end

local published = {}

-- Efeitos de peças (coe_mechanic), se o resource estiver ativo.
local function partEffects(vehicleId, mileage)
	if GetResourceState('coe_mechanic') ~= 'started' then
		return nil
	end
	local ok, effects = pcall(function()
		return exports.coe_mechanic:GetEffects(vehicleId, mileage)
	end)
	return ok and type(effects) == 'table' and effects or nil
end

-- Efeitos da mistura de combustível (coe_fuel): força do motor com etanol e aditivada.
local function fuelEffects(vehicleId)
	if GetResourceState('coe_fuel') ~= 'started' then
		return nil
	end
	local ok, effects = pcall(function()
		return exports.coe_fuel:GetEffects(vehicleId)
	end)
	return ok and type(effects) == 'table' and effects or nil
end

-- Peças e combustível multiplicam os mesmos campos; a chave junta as duas para republicar só quando mudar.
local function extraEffects(vehicleId, mileage)
	local parts, fuel = partEffects(vehicleId, mileage), fuelEffects(vehicleId)
	if not parts and not fuel then
		return nil
	end
	local mods = {}
	for _, source in ipairs({ parts, fuel }) do
		for field, multiplier in pairs(source and source.mods or {}) do
			if type(multiplier) == 'number' then
				mods[field] = (mods[field] or 1) * multiplier
			end
		end
	end
	return { mods = mods, key = tostring(parts and parts.key or '') .. '/' .. tostring(fuel and fuel.key or '') }
end

local function publish(vehicleId, entity, model, mileage)
	if not ready or not entity or not Core.Platform.Entities.Exists(entity) then
		return
	end
	local computed = service.Compute(vehicleId, model, mileage, extraEffects(vehicleId, mileage))
	if not computed then
		return
	end
	if published[vehicleId] == computed.key then
		return
	end
	published[vehicleId] = computed.key
	local state = Entity(entity).state
	state:set('coe:tyre', { compound = computed.compound, wear = computed.wear }, true)
	state:set('coe:handling', computed.mods, true)
end

local function refresh(vehicleId, entity, mileage)
	local record = exports.coe_vehicles:Get(vehicleId)
	if not record then
		return
	end
	publish(vehicleId, entity, record.model, mileage or record.mileage)
end

AddEventHandler('coe_vehicles:spawned', function(vehicleId, entity)
	published[vehicleId] = nil
	refresh(vehicleId, entity)
end)

AddEventHandler('coe_vehicles:mileageChanged', function(vehicleId, entity, meters)
	refresh(vehicleId, entity, meters)
end)

AddEventHandler('coe_mechanic:partsChanged', function(vehicleId)
	local ok, entity = pcall(function()
		return exports.coe_vehicles:GetEntity(vehicleId)
	end)
	if ok and entity then
		refresh(vehicleId, entity)
	end
end)

-- Mistura de combustível mudou (abasteceu): recalcula a força.
AddEventHandler('coe_fuel:effectsChanged', function(vehicleId)
	local ok, entity = pcall(function()
		return exports.coe_vehicles:GetEntity(vehicleId)
	end)
	if ok and entity then
		refresh(vehicleId, entity)
	end
end)

AddEventHandler('coe_vehicles:released', function(vehicleId)
	published[vehicleId] = nil
	if service then
		service.Forget(vehicleId)
	end
end)

local function callerName()
	return GetInvokingResource() or GetCurrentResourceName()
end

local function isWriter()
	local resource = callerName()
	if CoeAccess and CoeAccess.Allowed then
		return CoeAccess.Allowed(resource, config.Ace, config.WriterResources)
	end
	return config.WriterResources[resource] == true
end

exports('GetTyre', function(vehicleId)
	if not ready then
		return nil
	end
	local mileage = exports.coe_vehicles:GetMileage(vehicleId)
	if not mileage then
		return nil
	end
	return service.GetTyre(vehicleId, mileage)
end)

exports('SetTyre', function(vehicleId, compound)
	if not isWriter() then
		log('warn', 'security', 'vehicle_tyre_forbidden', { operation = callerName() })
		return 'forbidden'
	end
	if not ready then
		return 'not_ready'
	end
	local record = exports.coe_vehicles:Get(vehicleId)
	if not record then
		return 'vehicle_not_found'
	end
	local saved, errorCode = service.SetTyre(vehicleId, compound, record.mileage, callerName())
	if not saved then
		return errorCode or 'unknown_error'
	end
	published[vehicleId] = nil
	local entity = nil
	local ok, found = pcall(function()
		return exports.coe_vehicles:GetEntity(vehicleId)
	end)
	if ok then
		entity = found
	end
	if entity then
		publish(vehicleId, entity, record.model, record.mileage)
	end
	return true
end)

exports('ListTyres', function()
	local names = {}
	for name in pairs(config.Tyres) do
		names[#names + 1] = name
	end
	table.sort(names)
	return names
end)

exports('ListClasses', function()
	local names = {}
	for name in pairs(config.ClassProfiles) do
		names[#names + 1] = name
	end
	table.sort(names)
	return names
end)

exports('GetModifiers', function(vehicleId)
	if not ready then
		return nil
	end
	local record = exports.coe_vehicles:Get(vehicleId)
	if not record then
		return nil
	end
	local computed = service.Compute(vehicleId, record.model, record.mileage, extraEffects(vehicleId, record.mileage))
	return computed and computed.mods or nil
end)

exports('IsReady', function()
	return ready
end)

RegisterCommand('coe_tyre', function(source, args)
	if source ~= 0 and not IsPlayerAceAllowed(source, 'command.coe_tyre') then
		return
	end
	local plate, compound = args[1], args[2]
	if not plate or not compound then
		print('uso: coe_tyre <placa> <composto>')
		return
	end
	local record = exports.coe_vehicles:GetByPlate(plate)
	if not record then
		print('veiculo nao encontrado')
		return
	end
	local result = exports.coe_handling:SetTyre(record.id, compound)
	print(result == true and 'pneus trocados' or ('falha: ' .. tostring(result)))
end, true)

CreateThread(function()
	local waitingLogged = false
	while true do
		local initialized, errorCode = HandlingPersistence.Initialize()
		if initialized then
			break
		end
		if errorCode == 'database_not_ready' then
			if not waitingLogged then
				log('info', 'persistence', 'database_waiting', {})
				waitingLogged = true
			end
			Wait(1000)
		else
			log('error', 'persistence', 'database_initialization_failed', {
				error_code = errorCode or 'database_error',
				retry_ms = 5000
			})
			Wait(5000)
		end
	end
	service = HandlingService.New({
		config = config,
		persistence = HandlingPersistence,
		getVehicleInfo = getVehicleInfo,
		audit = audit
	})
	ready = true
	log('info', 'system', 'handling_ready', {})
end)
