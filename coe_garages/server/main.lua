local config = GaragesConfig
local _t = (Core and Core.Locale and Core.Locale.Bind) and Core.Locale.Bind(Locales) or function(k) return (Locales and Locales['pt-BR'] and Locales['pt-BR'][k]) or k end
local ready = false
local stations = {}
local lastAction = {}

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

local function notify(playerId, kind, message)
	pcall(function()
		exports.coe_notify:Notify(playerId, kind, message)
	end)
end

local MESSAGES = {
	not_ready = 'Serviço ainda iniciando.', no_station = 'Garagem indisponível.', too_far = 'Chegue mais perto da vaga.',
	vehicle_not_found = 'Veículo não encontrado.', not_registered = 'Este veículo não é registrado.', not_stored = 'O veículo não está guardado.',
	not_yours = 'Este veículo não é seu.', other_garage = 'Este veículo está guardado em outra garagem.', not_in_fleet = 'Este veículo não pertence a este negócio.', no_access = 'Você não tem acesso a este veículo.',
	garage_full = 'Sua garagem não tem vaga livre para este tipo de veículo.', not_owner = 'Só o dono do negócio faz isso.',
	invalid_state_id = 'ID inválido.', character_not_found = 'ID não encontrado.', access_limit = 'Limite de pessoas com acesso atingido.',
	already_spawned = 'O veículo já está na rua.', spawn_failed = 'Não foi possível retirar o veículo.', spawn_blocked = 'A vaga está ocupada.',
	vehicle_not_spawned = 'O veículo não pode ser guardado aqui.', database_error = 'Erro ao gravar. Tente novamente.',
	forbidden = 'Garagem sem permissão para guardar veículos (falta a ACE coe.vehicles.write do coe_garages).',
	store_expired = 'Tente guardar de novo.'
}

local function fail(playerId, errorCode, operation)
	TriggerClientEvent('coe_garages:failed', playerId, errorCode)
	notify(playerId, 'error', _t(errorCode) ~= errorCode and _t(errorCode) or _t('action_failed'))
	-- Sem isto a recusa só aparecia para o jogador; agora fica no console com o código.
	log('warn', 'gameplay', 'garage_action_refused', { player_id = playerId, error_code = tostring(errorCode), operation = operation or 'garage' })
end

local function throttled(playerId)
	local now = GetGameTimer()
	if lastAction[playerId] and now - lastAction[playerId] < config.Limits.ActionIntervalMs then
		return true
	end
	lastAction[playerId] = now
	return false
end

-- Garagens cadastradas no painel. Cada vaga ativa vira uma estação; o tipo decide quem usa e como.
local garages = {}

local function rebuild()
	stations = {}
	garages = {}
	local loaded = GaragesPersistence.ListGarages()
	local list = {}
	for _, garage in ipairs(loaded or {}) do
		garages[garage.id] = garage
		if garage.enabled then
			for index, spot in ipairs(garage.spots or {}) do
				local entry = {
					garageId = garage.id, spotId = spot.id, kind = garage.kind, businessId = garage.businessId, jobs = garage.jobs,
					title = garage.label, label = spot.label, blip = index == 1 and garage.blip and garage.blip.enabled and garage.blip or nil,
					x = spot.x, y = spot.y, z = spot.z, radius = spot.radius, heading = spot.heading or 0.0
				}
				stations[garage.id .. ':' .. spot.id] = entry
				list[#list + 1] = entry
			end
		end
	end
	return list
end

local function stationList()
	local list = {}
	for _, entry in pairs(stations) do
		list[#list + 1] = entry
	end
	return list
end

RegisterNetEvent('coe_garages:requestStations', function()
	if ready then
		TriggerClientEvent('coe_garages:stations', source, stationList())
	end
end)

local function actor(playerId)
	local characterId = Core.Players.GetActiveCharacterId(playerId)
	local ped = GetPlayerPed(playerId)
	if not characterId or not ped or ped == 0 then
		return nil
	end
	return { characterId = tostring(characterId), at = Core.Platform.Entities.GetCoords(ped) }
end

local function stationAt(playerId, garageId, spotId)
	if not ready or type(garageId) ~= 'string' or type(spotId) ~= 'string' then
		return nil, 'not_ready'
	end
	local station = stations[garageId .. ':' .. spotId]
	if not station then
		return nil, 'no_station'
	end
	local who = actor(playerId)
	if not who then
		return nil, 'not_ready'
	end
	if #(who.at - vector3(station.x, station.y, station.z)) > station.radius + config.Limits.StationReach then
		return nil, 'too_far'
	end
	return station, who
end

local function playerJob(playerId)
	local groups = exports.coe_core:GetPlayerGroups(playerId)
	return type(groups) == 'table' and groups.job and groups.job.name or nil
end

-- Quem é dono (só negócio) e quem é equipe: negócio = job do negócio em ponto batido; corporação = job da lista.
local function fleetRole(station, playerId, who)
	if station.kind == 'job' then
		local job = playerJob(playerId)
		for _, allowed in ipairs(station.jobs or {}) do
			if allowed == job then
				return false, true
			end
		end
		return false, false
	end
	local business = station.businessId and exports.coe_businesses:Get(station.businessId)
	if not business then
		return nil
	end
	local access = exports.coe_businesses:Access(business.id, who.characterId)
	return GaragesRules.IsOwner(business, who.characterId), GaragesRules.IsStaff(access)
end

-- Frota da garagem; em corporação toda a equipe usa os veículos (acesso da equipe sempre ligado).
local function loadFleet(station)
	local fleet, order = GaragesPersistence.ListFleet(station.garageId)
	if fleet and station.kind == 'job' then
		for _, entry in pairs(fleet) do
			entry.staff = true
		end
	end
	return fleet, order
end

local function catalogInfo(model)	local ok, info = pcall(function()
		return exports.coe_vehicle_catalog:GetVehicleInfo(model)
	end)
	return ok and type(info) == 'table' and info or nil
end

-- Veículo guardado numa garagem pública só sai dela. Sem vaga registrada (ou garagem removida), qualquer pública serve.
local function slotAllows(slotGarage, garageId)
	return slotGarage == nil or slotGarage == garageId or garages[slotGarage] == nil
end

local function vehicleView(record)
	local info = catalogInfo(record.model)
	return {
		id = record.id, model = record.model, name = info and info.name or record.model, plate = record.plate,
		state = record.state, class = GaragesRules.ClassOf(config, info)
	}
end

local function sendMenu(playerId, station, who)
	local menu = {
		garageId = station.garageId, spotId = station.spotId, kind = station.kind,
		title = station.title, subtitle = station.label, vehicles = {}, canManage = false
	}
	if station.kind == 'public' then
		local owned = exports.coe_vehicles:ListByOwner(who.characterId)
		local slots = GaragesPersistence.SlotsOf(who.characterId) or {}
		for _, record in ipairs(type(owned) == 'table' and owned or {}) do
			if record.state == 'stored' and slotAllows(slots[tostring(record.id)], station.garageId) then
				menu.vehicles[#menu.vehicles + 1] = vehicleView(record)
			end
		end
	else
		local isOwner, isStaff = fleetRole(station, playerId, who)
		menu.canManage = isOwner == true
		local fleet, order = loadFleet(station)
		for _, id in ipairs(order or {}) do
			local entry = fleet[id]
			if GaragesRules.CanUseFleet(entry, who.characterId, isOwner, isStaff) then
				local record = exports.coe_vehicles:Get(id)
				if type(record) == 'table' then
					local view = vehicleView(record)
					if isOwner then
						view.staff = entry.staff
						view.access = {}
						for characterId, name in pairs(entry.access) do
							view.access[#view.access + 1] = { characterId = characterId, name = name }
						end
						table.sort(view.access, function(a, b) return a.name < b.name end)
					end
					menu.vehicles[#menu.vehicles + 1] = view
				end
			end
		end
	end
	TriggerClientEvent('coe_garages:menu', playerId, menu)
end

RegisterNetEvent('coe_garages:open', function(garageId, spotId)
	local playerId = source
	if throttled(playerId) then
		return
	end
	local station, who = stationAt(playerId, garageId, spotId)
	if not station then
		return fail(playerId, who)
	end
	sendMenu(playerId, station, who)
end)

RegisterNetEvent('coe_garages:take', function(garageId, spotId, vehicleId)
	local playerId = source
	if throttled(playerId) or type(vehicleId) ~= 'string' then
		return
	end
	local station, who = stationAt(playerId, garageId, spotId)
	if not station then
		return fail(playerId, who)
	end
	local record = exports.coe_vehicles:Get(vehicleId)
	if type(record) ~= 'table' then
		return fail(playerId, 'vehicle_not_found')
	end
	if record.state ~= 'stored' then
		return fail(playerId, 'not_stored')
	end
	if station.kind == 'public' then
		if tostring(record.ownerCharacterId) ~= who.characterId then
			return fail(playerId, 'not_yours')
		end
		local slots = GaragesPersistence.SlotsOf(who.characterId)
		if not slots then
			return fail(playerId, 'database_error')
		end
		if not slotAllows(slots[vehicleId], garageId) then
			return fail(playerId, 'other_garage')
		end
	else
		local isOwner, isStaff = fleetRole(station, playerId, who)
		local fleet = loadFleet(station)
		local entry = fleet and fleet[vehicleId]
		if not entry then
			return fail(playerId, 'not_in_fleet')
		end
		if not GaragesRules.CanUseFleet(entry, who.characterId, isOwner, isStaff) then
			return fail(playerId, 'no_access')
		end
	end
	local info = catalogInfo(record.model)
	local netId = exports.coe_vehicles:Spawn(vehicleId, station.x, station.y, station.z, station.heading, info and info.type or 'automobile')
	if math.type(netId) ~= 'integer' then
		return fail(playerId, tostring(netId))
	end
	-- Pública: a vaga continua registrada nesta garagem; se o servidor reiniciar com o veículo na rua,
	-- o coe_vehicles volta o estado para 'stored' e ele reaparece na última garagem.
	if station.kind ~= 'public' then
		exports.coe_vehicles:GiveKey(vehicleId, who.characterId)
	end
	audit('garage_vehicle_taken', { operation = garageId, plate = record.plate, character_id = who.characterId })
	TriggerClientEvent('coe_garages:spawned', playerId, netId)
end)

-- Confere tudo o que guardar exige, sem mexer no veículo. Retorna dados ou nil, erro.
local function validateStore(playerId, garageId, spotId, netId)
	if math.type(netId) ~= 'integer' then
		return nil, 'vehicle_not_found'
	end
	local station, who = stationAt(playerId, garageId, spotId)
	if not station then
		return nil, who
	end
	local entity = Core.Platform.Entities.FromNetworkId(netId)
	if not entity or entity == 0 or not Core.Platform.Entities.Exists(entity) then
		return nil, 'vehicle_not_found'
	end
	local vehicleId = Entity(entity).state['coe:vehicleId']
	if vehicleId == nil then
		return nil, 'not_registered'
	end
	vehicleId = tostring(vehicleId)
	if #(Core.Platform.Entities.GetCoords(entity) - vector3(station.x, station.y, station.z)) > station.radius + config.Limits.StationReach then
		return nil, 'too_far'
	end
	local record = exports.coe_vehicles:Get(vehicleId)
	if type(record) ~= 'table' then
		return nil, 'vehicle_not_found'
	end
	if station.kind == 'public' then
		if tostring(record.ownerCharacterId) ~= who.characterId then
			return nil, 'not_yours'
		end
		-- Garagem pública não tem limite de vagas por jogador.
	else
		local isOwner, isStaff = fleetRole(station, playerId, who)
		local fleet = loadFleet(station)
		local entry = fleet and fleet[vehicleId]
		if not entry then
			return nil, 'not_in_fleet'
		end
		if not GaragesRules.CanUseFleet(entry, who.characterId, isOwner, isStaff) then
			return nil, 'no_access'
		end
	end
	return { station = station, who = who, vehicleId = vehicleId, record = record }
end

-- Pedido de guardar aprovado na conferência: o client tira o ped do veículo e confirma em seguida.
local pendingStore = {}
local STORE_CONFIRM_MS = 8000

-- 1ª etapa: o client pergunta antes de desembarcar. Se algo impede, o ped continua no veículo e vê o motivo.
RegisterNetEvent('coe_garages:storeCheck', function(garageId, spotId, netId)
	local playerId = source
	if throttled(playerId) then
		return
	end
	local data, errorCode = validateStore(playerId, garageId, spotId, netId)
	if not data then
		return fail(playerId, errorCode, 'store_check')
	end
	pendingStore[playerId] = { garageId = garageId, spotId = spotId, netId = netId, at = GetGameTimer() }
	TriggerClientEvent('coe_garages:storeApproved', playerId, netId)
end)

-- 2ª etapa: o ped já desembarcou. Confere de novo (o estado pode ter mudado) e guarda.
RegisterNetEvent('coe_garages:store', function(garageId, spotId, netId)
	local playerId = source
	local pending = pendingStore[playerId]
	pendingStore[playerId] = nil
	if not pending or pending.garageId ~= garageId or pending.spotId ~= spotId or pending.netId ~= netId
		or GetGameTimer() - pending.at > STORE_CONFIRM_MS then
		return fail(playerId, 'store_expired', 'store')
	end
	local data, errorCode = validateStore(playerId, garageId, spotId, netId)
	if not data then
		return fail(playerId, errorCode, 'store')
	end
	local vehicleId, record, who = data.vehicleId, data.record, data.who
	local class = GaragesRules.ClassOf(config, catalogInfo(record.model))
	local stored = exports.coe_vehicles:Store(vehicleId)
	if stored ~= true then
		return fail(playerId, tostring(stored), 'store')
	end
	if data.station.kind == 'public' then
		GaragesPersistence.SaveSlot(vehicleId, garageId, who.characterId, class)
	else
		for _, holder in ipairs(exports.coe_vehicles:ListKeyHolders(vehicleId) or {}) do
			exports.coe_vehicles:RevokeKey(vehicleId, holder)
		end
	end
	audit('garage_vehicle_stored', { operation = garageId, plate = record.plate, character_id = who.characterId })
	notify(playerId, 'success', _t('vehicle_stored', { plate = record.plate }))
end)

AddEventHandler('playerDropped', function()
	pendingStore[source] = nil
end)

-- O dono do negócio escolhe quem usa cada veículo da frota: pessoa a pessoa (por stateId) ou toda a equipe de ponto batido.
RegisterNetEvent('coe_garages:access', function(garageId, spotId, vehicleId, action, value)
	local playerId = source
	if throttled(playerId) or type(vehicleId) ~= 'string' or type(action) ~= 'string' then
		return
	end
	local station, who = stationAt(playerId, garageId, spotId)
	if not station then
		return fail(playerId, who)
	end
	if station.kind == 'public' then
		return fail(playerId, 'no_station')
	end
	if not fleetRole(station, playerId, who) then
		return fail(playerId, 'not_owner')
	end
	local fleet = loadFleet(station)
	local entry = fleet and fleet[vehicleId]
	if not entry then
		return fail(playerId, 'not_in_fleet')
	end
	local saved, errorCode = true, nil
	if action == 'staff' then
		saved, errorCode = GaragesPersistence.SetStaffAccess(vehicleId, value == true)
	elseif action == 'add' then
		local stateId = type(value) == 'string' and value:upper() or ''
		if not Core.Identity.IsValidStateId(stateId) then
			return fail(playerId, 'invalid_state_id')
		end
		local count = 0
		for _ in pairs(entry.access) do
			count = count + 1
		end
		if count >= config.Limits.MaxAccessPerVehicle then
			return fail(playerId, 'access_limit')
		end
		local character, findError = GaragesPersistence.FindCharacterByStateId(stateId)
		if not character then
			return fail(playerId, findError)
		end
		saved, errorCode = GaragesPersistence.AddAccess(vehicleId, character.characterId, character.name:sub(1, 48))
	elseif action == 'remove' then
		if type(value) ~= 'string' or not value:match('^%d+$') then
			return
		end
		saved, errorCode = GaragesPersistence.RemoveAccess(vehicleId, value)
		pcall(function()
			exports.coe_vehicles:RevokeKey(vehicleId, value)
		end)
	else
		return
	end
	if not saved then
		return fail(playerId, errorCode or 'database_error')
	end
	audit('garage_access_changed', { operation = garageId, action = action, character_id = who.characterId })
	sendMenu(playerId, station, who)
end)

local function reply(playerId, kind, message)
	if playerId > 0 then
		notify(playerId, kind, message)
	end
	print(('[coe_garages] %s'):format(message))
end

-- Adiciona um veículo (sem dono, "estoque") do catálogo à frota de uma garagem de negócio ou corporação.
local function addFleetVehicle(garageId, model, plate)
	if not ready then
		return nil, 'not_ready'
	end
	local garage = type(garageId) == 'string' and garages[garageId]
	if not garage or garage.kind == 'public' then
		return nil, 'no_fleet_garage'
	end
	if type(model) ~= 'string' or not catalogInfo(model) then
		return nil, 'unknown_model'
	end
	if GaragesPersistence.CountFleet(garageId) >= config.Limits.MaxFleetPerBusiness then
		return nil, 'fleet_full'
	end
	local record = exports.coe_vehicles:Create({ model = model, plate = plate })
	if type(record) ~= 'table' then
		return nil, tostring(record)
	end
	local added, errorCode = GaragesPersistence.AddFleet(record.id, garageId)
	if not added then
		return nil, errorCode or 'database_error'
	end
	audit('fleet_vehicle_added', { operation = garageId, plate = record.plate })
	return record
end

-- Só veículo guardado sai da frota; o registro dele continua existindo, sem dono.
local function removeFleetVehicle(garageId, vehicleId)
	if not ready then
		return nil, 'not_ready'
	end
	if GaragesPersistence.FleetOf(vehicleId) ~= garageId then
		return nil, 'not_in_fleet'
	end
	local record = exports.coe_vehicles:Get(vehicleId)
	if type(record) == 'table' and record.state ~= 'stored' then
		return nil, 'not_stored'
	end
	local removed, errorCode = GaragesPersistence.RemoveFleet(vehicleId)
	if not removed then
		return nil, errorCode or 'database_error'
	end
	audit('fleet_vehicle_removed', { operation = garageId, vehicle_id = vehicleId })
	return true
end

-- Painel admin: [{ vehicleId, model, plate, state }] da frota da garagem.
local function listFleet(garageId)
	local _, order = GaragesPersistence.ListFleet(garageId)
	local list = {}
	for _, id in ipairs(order or {}) do
		local record = exports.coe_vehicles:Get(id)
		if type(record) == 'table' then
			list[#list + 1] = { vehicleId = id, model = record.model, plate = record.plate, state = record.state }
		end
	end
	return list
end

-- Exports devolvem um único valor: o resultado, ou { error = codigo }.
local function packResult(value, errorCode)
	if value then
		return value
	end
	return { error = errorCode or 'database_error' }
end

local function adminOnly()
	return GetInvokingResource() == 'coe_admin'
end

local function broadcast()
	TriggerClientEvent('coe_garages:stations', -1, stationList())
end

-- Cadastro validado pelo painel admin. O negócio precisa existir em coe_businesses.
local function saveGarage(raw)
	if not ready then
		return nil, 'not_ready'
	end
	local garage, errorCode = GaragesRegistry.Normalize(raw, config)
	if not garage then
		return nil, errorCode
	end
	local count = 0
	for _ in pairs(garages) do
		count = count + 1
	end
	if not garages[garage.id] and count >= config.Limits.MaxGarages then
		return nil, 'garage_limit'
	end
	if garage.kind == 'business' and not exports.coe_businesses:Get(garage.businessId) then
		return nil, 'unknown_business'
	end
	local previous = garages[garage.id]
	if previous and previous.kind ~= garage.kind and #listFleet(garage.id) > 0 then
		return nil, 'kind_has_fleet'
	end
	local saved, saveError = GaragesPersistence.SaveGarage(garage)
	if not saved then
		return nil, saveError or 'database_error'
	end
	rebuild()
	broadcast()
	audit('garage_saved', { operation = garage.id })
	return garage
end

local function deleteGarage(garageId)
	if not ready then
		return nil, 'not_ready'
	end
	if type(garageId) ~= 'string' or not garages[garageId] then
		return nil, 'unknown_garage'
	end
	if #listFleet(garageId) > 0 then
		return nil, 'has_fleet'
	end
	local removed, errorCode = GaragesPersistence.DeleteGarage(garageId)
	if not removed then
		return nil, errorCode or 'database_error'
	end
	rebuild()
	broadcast()
	audit('garage_deleted', { operation = garageId })
	return true
end

exports('ListGarages', function()
	if not adminOnly() or not ready then
		return {}
	end
	local list = {}
	for _, garage in pairs(garages) do
		list[#list + 1] = garage
	end
	table.sort(list, function(a, b) return a.id < b.id end)
	return list
end)

exports('SaveGarage', function(raw)
	if not adminOnly() then
		return { error = 'forbidden' }
	end
	return packResult(saveGarage(raw))
end)

exports('DeleteGarage', function(garageId)
	if not adminOnly() then
		return { error = 'forbidden' }
	end
	return packResult(deleteGarage(garageId))
end)

exports('ListFleet', function(garageId)
	if not adminOnly() or type(garageId) ~= 'string' then
		return {}
	end
	return listFleet(garageId)
end)

exports('AddFleetVehicle', function(garageId, model)
	if not adminOnly() then
		return { error = 'forbidden' }
	end
	return packResult(addFleetVehicle(garageId, model))
end)

exports('RemoveFleetVehicle', function(garageId, vehicleId)
	if not adminOnly() or type(vehicleId) ~= 'string' then
		return { error = 'forbidden' }
	end
	return packResult(removeFleetVehicle(garageId, vehicleId))
end)

-- Tablet de negócios (só coe_businesses, que já conferiu ponto e permissão): garagens e frota de um negócio.
local function businessCaller()
	return config.BusinessResources[GetInvokingResource() or ''] == true
end

local function businessGarages(businessId)
	local list = {}
	for _, garage in pairs(garages) do
		if garage.kind == 'business' and garage.businessId == businessId then
			list[#list + 1] = garage
		end
	end
	table.sort(list, function(a, b) return a.id < b.id end)
	return list
end

exports('BusinessFleet', function(businessId)
	if not businessCaller() or not ready or type(businessId) ~= 'string' then
		return { error = ready and 'forbidden' or 'not_ready' }
	end
	local result = {}
	for _, garage in ipairs(businessGarages(businessId)) do
		local fleet, order = GaragesPersistence.ListFleet(garage.id)
		if not fleet then
			return { error = order or 'database_error' }
		end
		local vehicles = {}
		for _, id in ipairs(order) do
			local record = exports.coe_vehicles:Get(id)
			if type(record) == 'table' then
				local view = vehicleView(record)
				local count = 0
				for _ in pairs(fleet[id].access) do
					count = count + 1
				end
				view.staff, view.accessCount = fleet[id].staff, count
				vehicles[#vehicles + 1] = view
			end
		end
		local first = garage.spots and garage.spots[1]
		result[#result + 1] = {
			id = garage.id, label = garage.label, enabled = garage.enabled, spots = #(garage.spots or {}),
			x = first and first.x or nil, y = first and first.y or nil, vehicles = vehicles
		}
	end
	return result
end)

exports('SetFleetStaffAccess', function(businessId, vehicleId, enabled)
	if not businessCaller() or not ready then
		return { error = ready and 'forbidden' or 'not_ready' }
	end
	if type(businessId) ~= 'string' or type(vehicleId) ~= 'string' or #vehicleId > 32 or type(enabled) ~= 'boolean' then
		return { error = 'invalid_vehicle' }
	end
	local garage = garages[GaragesPersistence.FleetOf(vehicleId) or '']
	if not garage or garage.kind ~= 'business' or garage.businessId ~= businessId then
		return { error = 'not_in_fleet' }
	end
	local saved, errorCode = GaragesPersistence.SetStaffAccess(vehicleId, enabled)
	if not saved then
		return { error = errorCode or 'database_error' }
	end
	audit('garage_access_changed', { operation = garage.id, action = enabled and 'staff_on' or 'staff_off', vehicle_id = vehicleId })
	return true
end)

-- Frota comprada por um resource do negócio (FleetResources, ex.: coe_fuel): cria o veículo na primeira garagem de
-- negócio do negócio e, se `staff`, libera para a equipe. Devolve o registro ({ id, plate, ... }) ou { error }.
exports('AddBusinessFleet', function(businessId, model, staff)
	if config.FleetResources[GetInvokingResource() or ''] ~= true then
		return { error = 'forbidden' }
	end
	if not ready then
		return { error = 'not_ready' }
	end
	if type(businessId) ~= 'string' then
		return { error = 'invalid_business' }
	end
	local garage = businessGarages(businessId)[1]
	if not garage then
		return { error = 'no_fleet_garage' }
	end
	local record, errorCode = addFleetVehicle(garage.id, model)
	if not record then
		return { error = errorCode }
	end
	if staff == true then
		GaragesPersistence.SetStaffAccess(tostring(record.id), true)
	end
	audit('fleet_vehicle_bought', { operation = garage.id, plate = record.plate, action = GetInvokingResource() })
	return record
end)

-- ACE: command.coe_fleet_add.
RegisterCommand('coe_fleet_add', function(playerId, args)
	local record, errorCode = addFleetVehicle(args[1], args[2], args[3])
	if not record then
		return reply(playerId, 'error', _t('fleet_add_usage', { error = tostring(errorCode) }))
	end
	reply(playerId, 'success', _t('fleet_added', { model = record.model, plate = record.plate, garage = args[1] }))
end, true)

AddEventHandler('playerDropped', function()
	lastAction[source] = nil
end)

CreateThread(function()
	local waitingLogged = false
	while true do
		local initialized, errorCode = GaragesPersistence.Initialize()
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
			log('error', 'persistence', 'database_initialization_failed', { error_code = errorCode or 'database_error', retry_ms = 5000 })
			Wait(5000)
		end
	end
	local dependenciesLogged = false
	while not (GetResourceState('coe_businesses') == 'started' and exports.coe_businesses:IsReady()
		and GetResourceState('coe_vehicles') == 'started' and exports.coe_vehicles:IsReady()) do
		if not dependenciesLogged then
			log('info', 'system', 'garages_waiting', {})
			dependenciesLogged = true
		end
		Wait(1000)
	end
	rebuild()
	ready = true
	log('info', 'system', 'garages_ready', {})
	broadcast()
end)

-- App `vehicles` do COE OS (coe_tablet): os veículos do personagem, onde estão e a quilometragem. Só leitura;
-- retirar e guardar continuam na vaga da garagem.
local tabletDeps = {
	caller = function() return GetInvokingResource() end,
	ready = function() return ready end,
	characterOf = function(playerId) return Core.Players.GetActiveCharacterId(playerId) end,
	ownedVehicles = function(characterId) return exports.coe_vehicles:ListByOwner(characterId) end,
	slotsOf = function(characterId) return GaragesPersistence.SlotsOf(characterId) end,
	vehicleView = vehicleView,
	garage = function(garageId) return garages[garageId] end,
	entityCoords = function(vehicleId)
		local entity = exports.coe_vehicles:GetEntity(vehicleId)
		return entity and Core.Platform.Entities.GetCoords(entity) or nil
	end
}

exports('TabletCall', function(playerId, appId, action)
	return GaragesTablet.Call(tabletDeps, playerId, appId, action)
end)

-- Provedor da frota no app do negócio (coe_businesses:RegisterProvider 'fleet'): abas Frota e Propriedades.
-- De novo sempre que o coe_businesses reiniciar.
local function registerFleetProvider()
	if GetResourceState('coe_businesses') ~= 'started' then
		return
	end
	local ok, result = pcall(function()
		return exports.coe_businesses:RegisterProvider('fleet', { list = 'BusinessFleet', setStaff = 'SetFleetStaffAccess' })
	end)
	if not ok or result ~= true then
		log('warn', 'system', 'garages_provider_failed', { error_code = ok and type(result) == 'table' and tostring(result.error) or 'unavailable' })
	end
end

AddEventHandler('onResourceStart', function(resource)
	if resource == 'coe_businesses' then
		registerFleetProvider()
	end
end)
CreateThread(function()
	registerFleetProvider()
end)
