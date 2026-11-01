-- Prompt das bancadas dos negócios, facções e bancadas ilegais livres (aviso padrão do coe_ui).
local stations, access, lastAsk = {}, {}, {}
local shown = nil

local function setPrompt(key, data)
	if shown == key then
		return
	end
	shown = key
	SendNUIMessage({ action = 'prompt', data = data })
end

RegisterNetEvent('coe_crafting:stations', function(list)
	stations = type(list) == 'table' and list or {}
end)

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
		local active = false
		if #stations > 0 and not IsNuiFocused() then
			local at = GetEntityCoords(PlayerPedId())
			for _, station in ipairs(stations) do
				if #(at - vector3(station.x, station.y, station.z)) <= station.radius then
					wait = 0
					local kind = station.kind or 'business'
					if kind == 'illegal' then
						active = true
						setPrompt('craft:illegal:' .. station.id, {
							title = station.label or 'Bancada clandestina',
							subtitle = 'Bancada clandestina',
							options = { { key = 'E', label = 'Produzir' } }
						})
						if IsControlJustReleased(0, 38) then
							TriggerServerEvent('coe_crafting:openIllegal', station.id)
						end
					elseif kind == 'faction' or kind == 'faction_stash' then
						local key = 'faction:' .. station.factionId .. ':' .. station.id
						local known = askAccess(key, kind, station.factionId, station.id)
						if known and known.allowed then
							active = true
							local isStash = kind == 'faction_stash'
							setPrompt('craft:' .. kind .. ':' .. key, {
								title = station.label or (isStash and 'Baú' or 'Bancada da facção'),
								subtitle = station.factionLabel or (isStash and 'Baú do grupo' or 'Bancada'),
								options = { { key = 'E', label = isStash and 'Abrir baú' or 'Produzir' } }
							})
							if IsControlJustReleased(0, 38) then
								TriggerServerEvent(isStash and 'coe_crafting:openFactionStash' or 'coe_crafting:openFaction', station.factionId, station.id)
							end
						end
					else
						local key = station.businessId .. ':' .. station.id
						local known = askAccess(key, 'business', station.businessId, station.id)
						-- Equipe sem ponto batido também vê a bancada: ao apertar E, o servidor explica o que falta.
						local offDuty = known and not known.allowed and known.reason == 'off_duty'
						if known and (known.allowed or offDuty) then
							active = true
							setPrompt('craft:' .. key .. (offDuty and ':off' or ''), {
								title = station.label or 'Bancada',
								subtitle = offDuty and 'Bata o ponto para produzir' or 'Bancada',
								options = { { key = 'E', label = 'Produzir' } }
							})
							if IsControlJustReleased(0, 38) then
								TriggerServerEvent('coe_crafting:openBusiness', station.businessId, station.id)
							end
						end
					end
					break
				end
			end
		end
		if not active then
			setPrompt(nil, nil)
		end
		Wait(wait)
	end
end)
