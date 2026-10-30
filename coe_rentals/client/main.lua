-- Cliente do aluguel: estações vindas do servidor (cadastro no painel), atendente (NPC), blips, aviso de interação,
-- menu do balcão (alugar, devolver, encerrar) e o documento de locação. 0.00 ms em idle.
local _t = Core.Locale.Init('coe_rentals', RentalsConfig.Locale or 'pt-BR')
local stations = {}
local blips = {}
local peds = {} -- stationId -> ped do atendente
local activeRentalPlate = nil

-- Aviso de interação padrão do framework (exports.coe_notify:Prompt). Só reenvia quando muda.
local promptKey = nil
local menuOpen = false -- menu do balcão ou documento (NUI) aberto

local function setPrompt(key, title, label)
	if key == promptKey then
		return
	end
	promptKey = key
	pcall(function()
		exports.coe_notify:Prompt(key and {
			title = title or _t('prompt_title'),
			subtitle = _t('prompt_subtitle'),
			options = { { key = 'E', label = label } }
		} or nil)
	end)
end

local function money(amount)
	local ok, text = pcall(function()
		return Core.Locale.FormatMoney(amount, RentalsConfig.Locale)
	end)
	return ok and type(text) == 'string' and text or ('R$ ' .. tostring(amount))
end

-- Blips e atendentes -----------------------------------------------------------------------------------------

local function clearBlips()
	for _, blip in ipairs(blips) do
		if DoesBlipExist(blip) then
			RemoveBlip(blip)
		end
	end
	blips = {}
end

local function createBlips()
	clearBlips()
	for _, station in ipairs(stations) do
		local style = station.blip
		if type(style) == 'table' and style.enabled ~= false and station.ped then
			local b = AddBlipForCoord(station.ped.x + 0.0, station.ped.y + 0.0, station.ped.z + 0.0)
			SetBlipSprite(b, math.tointeger(tonumber(style.sprite)) or 226)
			SetBlipDisplay(b, 4)
			SetBlipScale(b, (tonumber(style.scale) or 0.7) + 0.0)
			SetBlipColour(b, math.tointeger(tonumber(style.color)) or 3)
			SetBlipAsShortRange(b, true)
			BeginTextCommandSetBlipName('STRING')
			AddTextComponentSubstringPlayerName(station.label or _t('prompt_title'))
			EndTextCommandSetBlipName(b)
			blips[#blips + 1] = b
		end
	end
end

local function spawnPed(station)
	local modelName = station.ped.model or (RentalsConfig.Ped and RentalsConfig.Ped.Model) or 'a_m_y_business_02'
	local model = joaat(modelName)
	if not IsModelInCdimage(model) then
		return nil
	end
	RequestModel(model)
	local deadline = GetGameTimer() + 5000
	while not HasModelLoaded(model) and GetGameTimer() < deadline do
		Wait(50)
	end
	if not HasModelLoaded(model) then
		return nil
	end
	local c = station.ped
	local found, groundZ = GetGroundZFor_3dCoord(c.x + 0.0, c.y + 0.0, c.z + 1.0, false)
	local z = (found and groundZ and groundZ ~= 0.0) and groundZ or (c.z - 1.0)
	local ped = CreatePed(4, model, c.x + 0.0, c.y + 0.0, z, (tonumber(c.h) or 0.0) + 0.0, false, true)
	SetModelAsNoLongerNeeded(model)
	if not ped or ped == 0 then
		return nil
	end
	SetEntityInvincible(ped, true)
	FreezeEntityPosition(ped, true)
	SetBlockingOfNonTemporaryEvents(ped, true)
	SetPedCanRagdoll(ped, false)
	SetPedFleeAttributes(ped, 0, false)
	TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_CLIPBOARD', 0, true)
	return ped
end

local function removePed(stationId)
	local ped = peds[stationId]
	peds[stationId] = nil
	if ped and DoesEntityExist(ped) then
		DeleteEntity(ped)
	end
end

local function removeAllPeds()
	for stationId in pairs(peds) do
		removePed(stationId)
	end
end

RegisterNetEvent('coe_rentals:stations', function(list)
	stations = type(list) == 'table' and list or {}
	removeAllPeds() -- recria com as posições novas na próxima volta do laço
	createBlips()
end)

CreateThread(function()
	Wait(1500)
	TriggerServerEvent('coe_rentals:requestStations')
end)

-- Atendentes: só existem perto da estação (verificação a cada 2 s).
CreateThread(function()
	local range = (RentalsConfig.Ped and tonumber(RentalsConfig.Ped.SpawnDistance)) or 60.0
	while true do
		local at = GetEntityCoords(PlayerPedId())
		local wanted = {}
		for _, station in ipairs(stations) do
			if station.ped then
				local isNear = #(at - vector3(station.ped.x, station.ped.y, station.ped.z)) <= range
				local ped = peds[station.id]
				wanted[station.id] = true
				if isNear and not (ped and DoesEntityExist(ped)) then
					peds[station.id] = spawnPed(station)
				elseif not isNear and ped then
					removePed(station.id)
				end
			end
		end
		for stationId in pairs(peds) do
			if not wanted[stationId] then
				removePed(stationId)
			end
		end
		Wait(2000)
	end
end)

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		return
	end
	clearBlips()
	removeAllPeds()
	if menuOpen then
		SetNuiFocus(false, false)
	end
end)

-- Interação -----------------------------------------------------------------------------------------------------

local function openCounter(station)
	if menuOpen then
		return
	end
	Core.Events.ToServer('rentals.menu', station.id)
end

-- Loop de proximidade (0.00 ms em idle)
CreateThread(function()
	while true do
		local sleep = 1000
		local prompting = false
		local ped = PlayerPedId()
		if ped > 0 and DoesEntityExist(ped) and not IsEntityDead(ped) and not menuOpen then
			local coords = GetEntityCoords(ped)
			local inVehicle = IsPedInAnyVehicle(ped, false)
			-- Veículo alugado: o servidor marca com o state bag 'coe:keyPlate' (a devolução confere o dono).
			local vehicle = inVehicle and GetVehiclePedIsIn(ped, false) or 0
			local rentalVehicle = vehicle ~= 0 and (activeRentalPlate ~= nil or Entity(vehicle).state['coe:keyPlate'] ~= nil)

			for _, station in ipairs(stations) do
				if station.ped then
					local dist = #(coords - vector3(station.ped.x, station.ped.y, station.ped.z))
					local zone = station.returnZone
					local distZone = zone and #(coords - vector3(zone.x, zone.y, zone.z)) or 9999.0
					if dist < 20.0 or distZone < 20.0 then
						sleep = 0
						if inVehicle then
							if rentalVehicle and zone and distZone <= (zone.radius or 5.0) then
								prompting = true
								setPrompt('return:' .. tostring(station.id), station.label, _t('press_to_return'))
								if IsControlJustReleased(0, 38) then -- Tecla E
									Core.Events.ToServer('rentals.return', station.id)
									Wait(500)
								end
							end
						elseif dist <= 2.5 then
							prompting = true
							setPrompt('rent:' .. tostring(station.id), station.label, _t('press_to_rent'))
							if IsControlJustReleased(0, 38) then -- Tecla E
								openCounter(station)
								Wait(500)
							end
						end
					end
				end
			end
		end
		if not prompting then
			setPrompt(nil)
		end
		Wait(sleep)
	end
end)

-- Menu do balcão (html/). O servidor confere tudo de novo antes de agir.
local function setMenuOpen(open)
	menuOpen = open
	SetNuiFocus(open, open)
	if open then
		setPrompt(nil)
	end
end

local function stationById(stationId)
	for _, station in ipairs(stations) do
		if station.id == stationId then
			return station
		end
	end
	return nil
end

Core.Events.OnNet('rentals.menu', function(stationId, vehicles, current)
	local station = stationById(stationId)
	if not station or menuOpen then
		return
	end
	local list = {}
	for _, vehicle in ipairs(type(vehicles) == 'table' and vehicles or {}) do
		local category = tostring(vehicle.category or '')
		local categoryLabel = _t('category_' .. category)
		list[#list + 1] = {
			model = vehicle.model,
			label = vehicle.label or vehicle.model,
			categoryLabel = categoryLabel ~= ('category_' .. category) and categoryLabel or category,
			priceText = money(vehicle.price or 0),
			depositText = money(vehicle.deposit or 0),
			totalText = money(vehicle.total or 0)
		}
	end
	local rental = nil
	if type(current) == 'table' then
		activeRentalPlate = current.plate
		rental = {
			title = _t('menu_current', { vehicle = current.label or '', plate = current.plate or '' }),
			status = current.status,
			statusText = _t('menu_status_' .. tostring(current.status)),
			depositText = money(current.deposit or 0)
		}
	else
		activeRentalPlate = nil
	end
	setMenuOpen(true)
	SendNUIMessage({
		action = 'open',
		stationId = station.id,
		title = station.label or _t('prompt_title'),
		subtitle = _t('menu_subtitle'),
		vehicles = list,
		rental = rental,
		texts = {
			total = _t('menu_total'),
			price = _t('menu_price'),
			deposit = _t('menu_deposit'),
			depositHint = _t('menu_deposit_hint', { deposit = '%{deposit}' }),
			chooseHint = _t('menu_choose'),
			empty = _t('menu_empty'),
			confirm = _t('menu_confirm'),
			close = _t('menu_close'),
			returnLabel = _t('menu_return'),
			hasRental = _t('menu_has_rental'),
			endLabel = _t('menu_end')
		}
	})
end)

RegisterNUICallback('rent', function(data, cb)
	setMenuOpen(false)
	if type(data) == 'table' and type(data.stationId) == 'string' and type(data.model) == 'string' then
		Core.Events.ToServer('rentals.rent', data.stationId, data.model)
	end
	cb({ ok = true })
end)

RegisterNUICallback('returnRental', function(data, cb)
	setMenuOpen(false)
	if type(data) == 'table' and type(data.stationId) == 'string' then
		Core.Events.ToServer('rentals.returnAtCounter', data.stationId)
	end
	cb({ ok = true })
end)

RegisterNUICallback('endRental', function(data, cb)
	setMenuOpen(false)
	if type(data) == 'table' and type(data.stationId) == 'string' then
		Core.Events.ToServer('rentals.endRental', data.stationId)
	end
	cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
	setMenuOpen(false)
	cb({ ok = true })
end)

-- Documento de locação (usar o item no inventário).
RegisterNetEvent('coe_rentals:document', function(doc)
	if type(doc) ~= 'table' or menuOpen then
		return
	end
	setMenuOpen(true)
	SendNUIMessage({
		action = 'document',
		doc = doc,
		texts = {
			title = _t('doc_title'), vehicle = _t('doc_vehicle'), plate = _t('doc_plate'), renter = _t('doc_renter'),
			stateId = _t('doc_state_id'), station = _t('doc_station'), date = _t('doc_date'), price = _t('doc_price'),
			deposit = _t('doc_deposit'), active = _t('doc_active'), closed = _t('doc_closed'), close = _t('doc_close')
		}
	})
end)

Core.Events.OnNet('rentals.spawned', function(netId, plate)
	activeRentalPlate = plate
	CreateThread(function()
		local timeout = 50
		while not NetworkDoesEntityExistWithNetworkId(netId) and timeout > 0 do
			Wait(100)
			timeout = timeout - 1
		end
		if NetworkDoesEntityExistWithNetworkId(netId) then
			local veh = NetworkGetEntityFromNetworkId(netId)
			TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
		end
	end)
end)

Core.Events.OnNet('rentals.returned', function()
	activeRentalPlate = nil
end)
