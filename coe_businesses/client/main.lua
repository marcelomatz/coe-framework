-- Prompt do ponto e dos baús dos negócios que não têm prompt próprio (a oficina tem o seu, no coe_mechanic).
-- Usa o aviso padrão do coe_ui (mesmo das bancadas e da oficina).
local stations, access, lastAsk = {}, {}, {}
local shown = nil

local function setPrompt(key, data)
	if shown == key then
		return
	end
	shown = key
	SendNUIMessage({ action = 'prompt', data = data })
end

local activeStation = nil

local function rebuildZones()
	if not (Core and Core.Zones) then
		return
	end
	Core.Zones.Clear()
	for idx, station in ipairs(stations) do
		Core.Zones.AddSphere(('station:%d:%s:%s'):format(idx, tostring(station.businessId), tostring(station.id)), {
			x = station.x,
			y = station.y,
			z = station.z,
			radius = (station.radius or 1.5) + 1.0,
			data = station
		})
	end
end

RegisterNetEvent('coe_businesses:clocks', function(list)
	stations = type(list) == 'table' and list or {}
	activeStation = nil
	rebuildZones()
end)

if Core and Core.Zones then
	Core.Zones.OnInteract(function()
		local station = activeStation
		if not station or IsNuiFocused() then
			return
		end
		local known = access[station.businessId]
		if not (known and known.canClock) then
			return
		end
		if station.kind == 'stash' then
			TriggerServerEvent('coe_businesses:openStash', station.businessId, station.id)
		else
			access[station.businessId] = nil
			TriggerServerEvent('coe_businesses:clock', station.businessId, station.id)
		end
	end)
end

RegisterNetEvent('coe_businesses:clockAccess', function(businessId, canClock, onDuty)
	if type(businessId) == 'string' then
		access[businessId] = { canClock = canClock == true, onDuty = onDuty == true, at = GetGameTimer() }
	end
end)

-- Proposta de emprego enviada pelo tablet de outro jogador: o diálogo padrão do coe_ui pede o aceite.
RegisterNetEvent('coe_businesses:offer', function(offer)
	if type(offer) ~= 'table' or type(offer.id) ~= 'number' then
		return
	end
	SetNuiFocus(true, true)
	SendNUIMessage({ action = 'offer', data = offer })
end)

RegisterNUICallback('answerOffer', function(data, cb)
	SetNuiFocus(false, false)
	if type(data) == 'table' and type(data.id) == 'number' then
		TriggerServerEvent('coe_businesses:answerOffer', data.id, data.accept == true)
	end
	cb({ ok = true })
end)

CreateThread(function()
	Wait(2500)
	TriggerServerEvent('coe_businesses:requestClocks')
	while true do
		local wait = 750
		local active = nil
		if #stations > 0 and not IsNuiFocused() then
			local at = Core.Platform.Entities.GetCoords(PlayerPedId())
			local zone, _, nearAny = Core and Core.Zones and Core.Zones.Nearest(at.x, at.y, at.z)
			if nearAny then
				wait = 250
			end
			local station = zone and zone.data
			if station then
				wait = 200
				local known, now = access[station.businessId], GetGameTimer()
				if (not known or now - known.at > 5000) and (not lastAsk[station.businessId] or now - lastAsk[station.businessId] > 1500) then
					lastAsk[station.businessId] = now
					TriggerServerEvent('coe_businesses:checkClock', station.businessId)
				end
				if known and known.canClock and station.kind == 'stash' then
					active = station
					setPrompt('stash:' .. station.businessId .. ':' .. station.id, {
						title = station.businessLabel or 'Negócio',
						subtitle = station.label or 'Baú',
						options = { { key = 'E', label = 'Abrir baú' } }
					})
				elseif known and known.canClock then
					active = station
					setPrompt('clock:' .. station.businessId .. ':' .. station.id .. ':' .. tostring(known.onDuty), {
						title = station.businessLabel or station.label or 'Negócio',
						subtitle = station.label or 'Ponto',
						options = { { key = 'E', label = known.onDuty and 'Bater ponto (sair)' or 'Bater ponto (entrar)' } }
					})
				end
			end
		end
		activeStation = active
		if not active then
			setPrompt(nil, nil)
		end
		Wait(wait)
	end
end)
