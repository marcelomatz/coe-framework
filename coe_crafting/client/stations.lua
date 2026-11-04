-- Prompt das bancadas dos negócios, facções e bancadas ilegais livres (aviso padrão do coe_ui).
local stations, access, lastAsk = {}, {}, {}
local _t = (Core and Core.Locale and Core.Locale.Bind) and Core.Locale.Bind(Locales) or function(k) return (Locales and Locales['pt-BR'] and Locales['pt-BR'][k]) or k end
local shown = nil

local function setPrompt(key, data)
	if shown == key then
		return
	end
	shown = key
	SendNUIMessage({ action = 'prompt', data = data })
end

local activeAction = nil

local function rebuildStationZones()
	if not (Core and Core.Zones) then
		return
	end
	Core.Zones.Clear()
	for idx, station in ipairs(stations) do
		Core.Zones.AddSphere(('craft_station:%d:%s'):format(idx, tostring(station.id)), {
			x = station.x,
			y = station.y,
			z = station.z,
			radius = station.radius or 2.0,
			data = station
		})
	end
end

RegisterNetEvent('coe_crafting:stations', function(list)
	stations = type(list) == 'table' and list or {}
	activeAction = nil
	rebuildStationZones()
end)

if Core and Core.Zones then
	Core.Zones.OnInteract(function()
		if not activeAction or IsNuiFocused() then
			return
		end
		if activeAction.event then
			TriggerServerEvent(activeAction.event, activeAction.arg1, activeAction.arg2)
		end
	end)
end

RegisterNetEvent('coe_crafting:access', function(ownerKey, stationId, allowed, reason)
	access[ownerKey .. ':' .. stationId] = { allowed = allowed == true, reason = reason, at = GetGameTimer() }
end)

local function askAccess(key, kind, ownerId, stationId)
	local known, now = access[key], GetGameTimer()
	if (not known or now - known.at > 5000) and (not lastAsk[key] or now - lastAsk[key] > 1500) then
		lastAsk[key] = now
		TriggerServerEvent('coe_crafting:checkAccess', kind, ownerId, stationId)
	end
	return known
end

CreateThread(function()
	Wait(2000)
	TriggerServerEvent('coe_crafting:requestStations')
	while true do
		local wait = 750
		local nextAction = nil
		if #stations > 0 and not IsNuiFocused() then
			local at = Core.Platform.Entities.GetCoords(PlayerPedId())
			local zone, _, nearAny = Core and Core.Zones and Core.Zones.Nearest(at.x, at.y, at.z)
			if nearAny then
				wait = 250
			end
			local station = zone and zone.data
			if station then
				wait = 200
				local kind = station.kind or 'business'
				if kind == 'illegal' then
					nextAction = { event = 'coe_crafting:openIllegal', arg1 = station.id }
					setPrompt('craft:illegal:' .. station.id, {
						title = station.label or _t('prompt_illegal_title'),
						subtitle = _t('prompt_illegal_title'),
						options = { { key = 'E', label = _t('prompt_produce') } }
					})
				elseif kind == 'faction' or kind == 'faction_stash' then
					local key = 'faction:' .. station.factionId .. ':' .. station.id
					local known = askAccess(key, kind, station.factionId, station.id)
					if known and known.allowed then
						local isStash = kind == 'faction_stash'
						nextAction = {
							event = isStash and 'coe_crafting:openFactionStash' or 'coe_crafting:openFaction',
							arg1 = station.factionId,
							arg2 = station.id
						}
						setPrompt('craft:' .. kind .. ':' .. key, {
							title = station.label or (isStash and _t('prompt_stash_title') or _t('prompt_faction_title')),
							subtitle = station.factionLabel or (isStash and _t('prompt_stash_subtitle') or _t('prompt_faction_subtitle')),
							options = { { key = 'E', label = isStash and _t('prompt_open_stash') or _t('prompt_produce') } }
						})
					end
				else
					local key = station.businessId .. ':' .. station.id
					local known = askAccess(key, 'business', station.businessId, station.id)
					-- Equipe sem ponto batido também vê a bancada: ao apertar E, o servidor explica o que falta.
					local offDuty = known and not known.allowed and known.reason == 'off_duty'
					if known and (known.allowed or offDuty) then
						nextAction = { event = 'coe_crafting:openBusiness', arg1 = station.businessId, arg2 = station.id }
						setPrompt('craft:' .. key .. (offDuty and ':off' or ''), {
							title = station.label or _t('prompt_business_title'),
							subtitle = offDuty and _t('prompt_duty_subtitle') or _t('prompt_business_title'),
							options = { { key = 'E', label = _t('prompt_produce') } }
						})
					end
				end
			end
		end
		activeAction = nextAction
		if not nextAction then
			setPrompt(nil, nil)
		end
		Wait(wait)
	end
end)
