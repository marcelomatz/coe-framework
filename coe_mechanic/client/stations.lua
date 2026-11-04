-- Interações da oficina: aviso no canto superior esquerdo (showroom, bancada de craft e baú). O painel de craft é do coe_crafting.
local config = CoeMechanicConfig
local PROMPT_KEY = 38
local ACCESS_TTL_MS = 5000

local access = {}
local shown = nil

local function point(station)
	return vector3(station.point.x, station.point.y, station.point.z)
end

local function setPrompt(key, data)
	if shown == key then
		return
	end
	shown = key
	SendNUIMessage({ action = 'prompt', data = data })
end

-- A equipe e o ponto são decididos no servidor; o cliente só pergunta (com cache curto) para não mostrar o aviso a quem não pode usar.
local function refreshAccess(shopId)
	local entry = access[shopId]
	if entry and GetGameTimer() - entry.at < ACCESS_TTL_MS then
		return entry
	end
	access[shopId] = {
		staff = entry and entry.staff or false, canClock = entry and entry.canClock or false,
		onDuty = entry and entry.onDuty or false, at = GetGameTimer()
	}
	TriggerServerEvent('coe_mechanic:checkAccess', shopId)
	return access[shopId]
end

RegisterNetEvent('coe_mechanic:access', function(shopId, staff, canClock, onDuty)
	if type(shopId) == 'string' then
		access[shopId] = { staff = staff == true, canClock = canClock == true, onDuty = onDuty == true, at = GetGameTimer() }
	end
end)

RegisterNetEvent('coe_mechanic:accessReset', function()
	access = {}
end)

RegisterNetEvent('coe_mechanic:stationFailed', function(_errorCode)
	-- Reseta aviso visual caso uma ação de bancada/baú seja rejeitada pelo servidor
	setPrompt(nil, nil)
end)

-- As oficinas vêm do servidor (negócios editados no admin); a tabela da config é só o valor inicial.
local shopsSynced = false

RegisterNetEvent('coe_mechanic:shops', function(shops)
	if type(shops) ~= 'table' then
		return
	end
	for id in pairs(config.Shops) do
		config.Shops[id] = nil
	end
	for id, shop in pairs(shops) do
		config.Shops[id] = shop
	end
	shopsSynced = true
	MechanicRefreshBlips()
end)

CreateThread(function()
	while not shopsSynced do
		TriggerServerEvent('coe_mechanic:requestShops')
		Wait(2000)
	end
end)

local function shopCenter(shop)
	if shop.area then
		local c = BusinessArea.Center(shop.area)
		return vector3(c.x, c.y, c.z), BusinessArea.Extent(shop.area)
	end
	local room = shop.showroom
	return vector3(room.x, room.y, room.z), config.ShopWorkRadius
end

local function shopNear(shop, at)
	if shop.area then
		return BusinessArea.Contains(shop.area, at.x, at.y, at.z)
	end
	local center, extent = shopCenter(shop)
	return #(at - center) <= extent
end

local function interactionAt(at, inVehicle)
	for shopId, shop in pairs(config.Shops) do
		local room = shop.showroom
		local roomDistance = #(at - vector3(room.x, room.y, room.z))
		if inVehicle then
			if roomDistance <= room.radius then
				return {
					key = 'showroom:' .. shopId, kind = 'showroom', shop = shopId, nearby = true,
					marker = { x = room.x, y = room.y, z = room.z, size = room.radius * 2.0 },
					prompt = { title = shop.label, subtitle = 'Showroom', options = { { key = 'E', label = 'Ver modificações do veículo' } } }
				}
			end
		elseif shopNear(shop, at) then
			local best, bestDistance, bestKind
			for _, kind in ipairs({ 'crafts', 'stashes', 'clocks' }) do
				for _, station in ipairs(shop[kind] or {}) do
					local distance = #(at - point(station))
					if distance <= station.point.radius + 2.0 and (not bestDistance or distance < bestDistance) then
						best, bestDistance, bestKind = station, distance, kind
					end
				end
			end
			-- Com pontos próximos, vale o mais perto do jogador (sem favorecer a ordem da lista).
			local entry = best and refreshAccess(shopId)
			if best and bestKind == 'clocks' and entry.canClock then
				return {
					key = 'clocks:' .. shopId .. ':' .. best.id, kind = 'clock', shop = shopId, station = best.id,
					prompt = {
						title = shop.label,
						subtitle = best.label,
						options = { { key = 'E', label = entry.onDuty and 'Bater ponto (sair)' or 'Bater ponto (entrar)' } }
					}
				}
			elseif best and bestKind ~= 'clocks' and entry.staff then
				local craft = bestKind == 'crafts'
				return {
					key = bestKind .. ':' .. shopId .. ':' .. best.id, kind = craft and 'craft' or 'stash',
					shop = shopId, station = best.id,
					prompt = {
						title = shop.label,
						subtitle = best.label,
						options = { { key = 'E', label = craft and 'Produzir peças e kits' or 'Abrir o baú' } }
					}
				}
			end
		end
	end
	return nil
end

local function nearAnyShop(at)
	for _, shop in pairs(config.Shops) do
		local center, extent = shopCenter(shop)
		if #(at - center) <= extent + 25.0 then
			return true
		end
	end
	return false
end

local function activate(current)
	if current.kind == 'showroom' then
		MechanicShowroom.Open(current.shop, config.Shops[current.shop])
	elseif current.kind == 'clock' then
		TriggerServerEvent('coe_mechanic:clock', current.shop, current.station)
	elseif current.kind == 'craft' then
		TriggerServerEvent('coe_mechanic:openCraft', current.shop, current.station)
	else
		TriggerServerEvent('coe_mechanic:openStash', current.shop, current.station)
	end
end

local activeInteraction = nil

if Core and Core.Zones then
	Core.Zones.OnInteract(function()
		if activeInteraction and not MechanicShowroom.IsOpen() and not IsNuiFocused() then
			activate(activeInteraction)
		end
	end)
end

CreateThread(function()
	while true do
		local wait = 1000
		local current
		if not MechanicShowroom.IsOpen() and not IsNuiFocused() then
			local ped = PlayerPedId()
			local at = Core.Platform.Entities.GetCoords(ped)
			if nearAnyShop(at) then
				wait = 250
				current = interactionAt(at, IsPedInAnyVehicle(ped, false))
			end
		end
		activeInteraction = current
		if current then
			setPrompt(current.key, current.prompt)
			local m = current.marker
			if m then
				-- Apenas o showroom em veículo desenha marcador 3D por quadro; estações a pé usam OnInteract sem Wait(0).
				local deadline = GetGameTimer() + 250
				while GetGameTimer() < deadline do
					if not (Core and Core.Zones) and IsControlJustReleased(0, PROMPT_KEY) then
						activate(current)
						break
					end
					DrawMarker(1, m.x, m.y, m.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, m.size, m.size, 0.6,
						196, 223, 155, 60, false, false, 2, false, nil, nil, false)
					Wait(0)
				end
				wait = 0
			elseif not (Core and Core.Zones) and IsControlJustReleased(0, PROMPT_KEY) then
				activate(current)
			end
		else
			setPrompt(nil, nil)
		end
		Wait(wait)
	end
end)
