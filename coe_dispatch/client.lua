local blips = {}
local routeBlip = nil

local function removeBlip(id)
	local entry = blips[id]
	if entry then
		if DoesBlipExist(entry) then
			RemoveBlip(entry)
		end
		blips[id] = nil
	end
end

local function addBlip(call)
	removeBlip(call.id)
	local blip = AddBlipForCoord(call.x + 0.0, call.y + 0.0, call.z + 0.0)
	SetBlipSprite(blip, 161)
	SetBlipColour(blip, call.priority == 1 and 1 or (call.priority == 2 and 17 or 5))
	SetBlipScale(blip, 1.0)
	SetBlipFlashes(blip, call.priority == 1)
	BeginTextCommandSetBlipName('STRING')
	AddTextComponentSubstringPlayerName(('#%d %s'):format(call.id, call.label))
	EndTextCommandSetBlipName(blip)
	blips[call.id] = blip
end

RegisterNetEvent('coe_dispatch:call', function(call)
	if type(call) ~= 'table' or type(call.id) ~= 'number' then
		return
	end
	addBlip(call)
	PlaySoundFrontend(-1, 'Beep_Red', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true)
end)

RegisterNetEvent('coe_dispatch:clear', function(id)
	removeBlip(id)
end)

RegisterNetEvent('coe_dispatch:route', function(call)
	if type(call) ~= 'table' then
		return
	end
	if routeBlip and DoesBlipExist(routeBlip) then
		RemoveBlip(routeBlip)
	end
	routeBlip = AddBlipForCoord(call.x + 0.0, call.y + 0.0, call.z + 0.0)
	SetBlipRoute(routeBlip, true)
	SetBlipRouteColour(routeBlip, 3)
	SetNewWaypoint(call.x + 0.0, call.y + 0.0)
end)

-- Fim de serviço ou queda de conexão não deixam blips para trás.
AddEventHandler('onResourceStop', function(name)
	if name ~= GetCurrentResourceName() then
		return
	end
	for id in pairs(blips) do
		removeBlip(id)
	end
	if routeBlip and DoesBlipExist(routeBlip) then
		RemoveBlip(routeBlip)
	end
end)
