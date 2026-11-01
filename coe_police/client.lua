local config = PoliceConfig
local cuffed = false
local jail = nil

local function loadAnim(dict)
	RequestAnimDict(dict)
	local waited = 0
	while not HasAnimDictLoaded(dict) and waited < 50 do
		Wait(100)
		waited = waited + 1
	end
end

local function teleport(x, y, z, heading)
	local ped = PlayerPedId()
	SetEntityCoords(ped, x + 0.0, y + 0.0, z + 0.0, false, false, false, false)
	SetEntityHeading(ped, heading + 0.0)
end

RegisterNetEvent('coe_police:cuffed', function(value)
	cuffed = value == true
	local ped = PlayerPedId()
	if cuffed then
		SetEnableHandcuffs(ped, true)
		loadAnim('mp_arresting')
		TaskPlayAnim(ped, 'mp_arresting', 'idle', 8.0, -8.0, -1, 49, 0, false, false, false)
	else
		SetEnableHandcuffs(ped, false)
		ClearPedTasks(ped)
	end
end)

RegisterNetEvent('coe_police:jail', function(x, y, z, heading, radius)
	jail = { x = x + 0.0, y = y + 0.0, z = z + 0.0, radius = radius + 0.0 }
	teleport(x, y, z, heading)
end)

RegisterNetEvent('coe_police:release', function(x, y, z, heading)
	jail = nil
	teleport(x, y, z, heading)
end)

RegisterNetEvent('coe_police:escort', function(officerServerId)
	local ped = PlayerPedId()
	if not officerServerId then
		DetachEntity(ped, true, false)
		return
	end
	local copPed = 0
	for _ = 1, 20 do
		local player = GetPlayerFromServerId(officerServerId)
		copPed = player ~= -1 and GetPlayerPed(player) or 0
		if copPed ~= 0 then
			break
		end
		Wait(250)
	end
	if copPed ~= 0 then
		AttachEntityToEntity(ped, copPed, 11816, 0.45, 0.45, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
	end
end)

-- Algemado não atira, não luta e não corre; preso que se afasta da cela volta para ela.
CreateThread(function()
	while true do
		if cuffed then
			Wait(0)
			local player = PlayerId()
			DisablePlayerFiring(player, true)
			DisableControlAction(0, 21, true)
			DisableControlAction(0, 24, true)
			DisableControlAction(0, 25, true)
			DisableControlAction(0, 140, true)
			DisableControlAction(0, 141, true)
			DisableControlAction(0, 142, true)
			local ped = PlayerPedId()
			if not IsEntityPlayingAnim(ped, 'mp_arresting', 'idle', 3) and not IsPedInAnyVehicle(ped, false) then
				TaskPlayAnim(ped, 'mp_arresting', 'idle', 8.0, -8.0, -1, 49, 0, false, false, false)
			end
		else
			Wait(500)
		end
		if jail then
			local coords = GetEntityCoords(PlayerPedId())
			if #(coords - vector3(jail.x, jail.y, jail.z)) > jail.radius then
				teleport(jail.x, jail.y, jail.z, config.Jail.heading)
			end
		end
	end
end)
