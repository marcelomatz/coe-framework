local config = DeepwebConfig
local isOpen = false
local pending = {}
local nextRequest = 0

-- Digitação em pé enquanto o computador está aberto (só a parte de cima do corpo).
local ANIM = { dict = 'anim@heists@prison_heiststation@cop_reactions', name = 'cop_b_idle' }

local function startAnim()
	local ped = PlayerPedId()
	RequestAnimDict(ANIM.dict)
	local deadline = GetGameTimer() + 2000
	while not HasAnimDictLoaded(ANIM.dict) and GetGameTimer() < deadline do
		Wait(10)
	end
	if HasAnimDictLoaded(ANIM.dict) then
		TaskPlayAnim(ped, ANIM.dict, ANIM.name, 4.0, -4.0, -1, 49, 0.0, false, false, false)
	end
end

local function stopAnim()
	StopAnimTask(PlayerPedId(), ANIM.dict, ANIM.name, 2.0)
	RemoveAnimDict(ANIM.dict)
end

local function close(notifyServer)
	if not isOpen then
		return
	end
	isOpen = false
	SetNuiFocus(false, false)
	SendNUIMessage({ action = 'close' })
	stopAnim()
	for id, p in pairs(pending) do
		pending[id] = nil
		p:resolve({ ok = false, error = 'closed' })
	end
	if notifyServer then
		TriggerServerEvent('coe_deepweb:computer:close')
	end
end

RegisterCommand(config.Install.Command, function()
	local ped = PlayerPedId()
	if isOpen or IsPedInAnyVehicle(ped, true) or IsPedDeadOrDying(ped, true) then
		return
	end
	TriggerServerEvent('coe_deepweb:computer:nearby')
end, false)

RegisterNetEvent('coe_deepweb:computer:open', function(profile)
	if isOpen or type(profile) ~= 'table' then
		return
	end
	isOpen = true
	SetNuiFocus(true, true)
	SendNUIMessage({ action = 'open', data = profile })
	startAnim()
end)

RegisterNetEvent('coe_deepweb:computer:close', function()
	close(false)
end)

RegisterNetEvent('coe_deepweb:computer:result', function(requestId, result)
	local p = pending[requestId]
	if p then
		pending[requestId] = nil
		p:resolve(result)
	end
end)

RegisterNUICallback('close', function(_, cb)
	close(true)
	cb({ ok = true })
end)

RegisterNUICallback('call', function(data, cb)
	if not isOpen or type(data) ~= 'table' then
		cb({ ok = false, error = 'closed' })
		return
	end
	nextRequest = nextRequest + 1
	local requestId = nextRequest
	local p = promise.new()
	pending[requestId] = p
	SetTimeout(15000, function()
		if pending[requestId] then
			pending[requestId] = nil
			p:resolve({ ok = false, error = 'timeout' })
		end
	end)
	TriggerServerEvent('coe_deepweb:computer:call', requestId, data.app, data.action, data.payload)
	cb(Citizen.Await(p))
end)

-- Marca um ponto no GPS (apps que listam locais).
RegisterNUICallback('waypoint', function(data, cb)
	local x, y = type(data) == 'table' and tonumber(data.x), type(data) == 'table' and tonumber(data.y)
	if not isOpen or not x or not y or math.abs(x) > 10000 or math.abs(y) > 10000 then
		cb({ ok = false })
		return
	end
	SetNewWaypoint(x, y)
	cb({ ok = true })
end)

CreateThread(function()
	while true do
		if isOpen then
			local ped = PlayerPedId()
			if IsPedInAnyVehicle(ped, true) or IsPedDeadOrDying(ped, true) then
				close(true)
			end
			Wait(500)
		else
			Wait(1000)
		end
	end
end)

AddEventHandler('onResourceStop', function(resource)
	if resource == GetCurrentResourceName() and isOpen then
		SetNuiFocus(false, false)
		stopAnim()
	end
end)

-- Contato NPC do mercado negro ---------------------------------------------------------------------------
-- Ped local (não sincronizado) que só existe perto do lugar atual; a compra é validada no servidor.
local dealerSpot = nil
local dealerPed = nil

local function removeDealer()
	if dealerPed and Core.Platform.Entities.Exists(dealerPed) then
		pcall(function() exports.coetarget:RemoveTargetEntity(dealerPed) end)
		Core.Platform.Entities.Delete(dealerPed)
	end
	dealerPed = nil
end

local function spawnDealer(spot)
	local dealer = config.Dealer
	local model = joaat(dealer.Model)
	RequestModel(model)
	local deadline = GetGameTimer() + 5000
	while not HasModelLoaded(model) and GetGameTimer() < deadline do
		Wait(50)
	end
	if not HasModelLoaded(model) then
		return
	end
	local ped = CreatePed(4, model, spot.x, spot.y, spot.z - 1.0, spot.heading or 0.0, false, false)
	SetModelAsNoLongerNeeded(model)
	if not ped or ped == 0 then
		return
	end
	SetEntityInvincible(ped, true)
	SetBlockingOfNonTemporaryEvents(ped, true)
	SetPedCanRagdoll(ped, false)
	FreezeEntityPosition(ped, true)
	if dealer.Scenario then
		TaskStartScenarioInPlace(ped, dealer.Scenario, 0, true)
	end
	local options = {}
	for index, entry in ipairs(dealer.Stock) do
		options[#options + 1] = {
			label = ('Comprar %s ($%d em espécie)'):format(entry.label, entry.price),
			distance = dealer.UseDistance,
			onSelect = function()
				TriggerServerEvent('coe_deepweb:dealer:buy', index)
			end
		}
	end
	pcall(function() exports.coetarget:AddTargetEntity(ped, options) end)
	dealerPed = ped
end

RegisterNetEvent('coe_deepweb:dealer:spot', function(spot)
	removeDealer()
	dealerSpot = type(spot) == 'table' and spot or nil
end)

CreateThread(function()
	if not config.Dealer or not config.Dealer.Enabled then
		return
	end
	Wait(5000)
	TriggerServerEvent('coe_deepweb:dealer:where')
	while true do
		local wait = 2000
		if dealerSpot then
			local coords = Core.Platform.Entities.GetCoords(PlayerPedId())
			local distance = #(coords - vector3(dealerSpot.x, dealerSpot.y, dealerSpot.z))
			if distance < config.Dealer.SpawnDistance and not dealerPed then
				spawnDealer(dealerSpot)
			elseif distance > config.Dealer.SpawnDistance + 20.0 and dealerPed then
				removeDealer()
			end
			wait = distance < config.Dealer.SpawnDistance + 50.0 and 1000 or 4000
		end
		Wait(wait)
	end
end)

AddEventHandler('onResourceStop', function(resource)
	if resource == GetCurrentResourceName() then
		removeDealer()
	end
end)

-- Pontos de coleta do Deep Market ------------------------------------------------------------------------
-- O site arma o ponto (GPS); perto dele aparece um objeto local com alvo do coetarget para deixar ou coletar.
-- O servidor confere ponto armado, distância, estado do pedido e inventário.
local drops = {} -- orderId -> { spot, prop }

local function removeDropProp(drop)
	if drop.prop and Core.Platform.Entities.Exists(drop.prop) then
		pcall(function() exports.coetarget:RemoveTargetEntity(drop.prop) end)
		Core.Platform.Entities.Delete(drop.prop)
	end
	drop.prop = nil
end

local function spawnDropProp(orderId, drop)
	local market = config.Market
	local model = joaat(market.DropProp or 'prop_cs_cardbox_01')
	RequestModel(model)
	local deadline = GetGameTimer() + 5000
	while not HasModelLoaded(model) and GetGameTimer() < deadline do
		Wait(50)
	end
	if not HasModelLoaded(model) or not drops[orderId] or drop.prop then
		return
	end
	local spot = drop.spot
	RequestCollisionAtCoord(spot.x, spot.y, spot.z)
	local found, groundZ = GetGroundZFor_3dCoord(spot.x, spot.y, spot.z + 2.0, false)
	local prop = CreateObject(model, spot.x, spot.y, found and groundZ or spot.z, false, false, false)
	SetModelAsNoLongerNeeded(model)
	if not prop or prop == 0 then
		return
	end
	PlaceObjectOnGroundProperly(prop)
	FreezeEntityPosition(prop, true)
	SetEntityInvincible(prop, true)
	local label = spot.action == 'deliver' and 'Deixar entrega #%d' or 'Coletar entrega #%d'
	pcall(function()
		exports.coetarget:AddTargetEntity(prop, {
			{
				label = label:format(orderId),
				distance = 2.0,
				onSelect = function()
					TriggerServerEvent('coe_deepweb:drop:use', orderId)
				end
			}
		})
	end)
	drop.prop = prop
end

RegisterNetEvent('coe_deepweb:drop:arm', function(spot)
	if type(spot) ~= 'table' or not math.tointeger(spot.orderId) or not tonumber(spot.x) or not tonumber(spot.y) or not tonumber(spot.z) then
		return
	end
	local current = drops[spot.orderId]
	if current then
		removeDropProp(current)
	end
	drops[spot.orderId] = { spot = spot }
	SetNewWaypoint(spot.x + 0.0, spot.y + 0.0)
end)

RegisterNetEvent('coe_deepweb:drop:clear', function(orderId)
	local drop = drops[orderId]
	if drop then
		removeDropProp(drop)
		drops[orderId] = nil
	end
end)

CreateThread(function()
	while true do
		local wait = 2000
		if next(drops) then
			local coords = Core.Platform.Entities.GetCoords(PlayerPedId())
			local range = config.Market.DropSpawnDistance or 60.0
			for orderId, drop in pairs(drops) do
				local spot = drop.spot
				local distance = #(coords - vector3(spot.x, spot.y, spot.z))
				if distance < range and not drop.prop then
					spawnDropProp(orderId, drop)
				elseif distance > range + 20.0 and drop.prop then
					removeDropProp(drop)
				end
				if distance < range + 50.0 then
					wait = 1000
				end
			end
		end
		Wait(wait)
	end
end)

AddEventHandler('onResourceStop', function(resource)
	if resource == GetCurrentResourceName() then
		for _, drop in pairs(drops) do
			removeDropProp(drop)
		end
	end
end)
