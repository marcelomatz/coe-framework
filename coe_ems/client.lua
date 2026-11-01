local config = EmsConfig
local current = 'healthy'

local function desiredState(ped)
	if IsEntityDead(ped) then
		return 'unconscious'
	end
	local maxHealth = GetEntityMaxHealth(ped)
	local fraction = (GetEntityHealth(ped) - 100) / math.max(maxHealth - 100, 1)
	return fraction < config.InjuredBelow and 'injured' or 'healthy'
end

local function resurrect(x, y, z, heading, health)
	local ped = PlayerPedId()
	NetworkResurrectLocalPlayer(x, y, z, heading, true, false)
	ped = PlayerPedId()
	ClearPedBloodDamage(ped)
	SetEntityHealth(ped, health)
end

RegisterNetEvent('coe_ems:state', function(state)
	current = state
end)

RegisterNetEvent('coe_ems:revive', function()
	local ped = PlayerPedId()
	local coords = GetEntityCoords(ped)
	resurrect(coords.x, coords.y, coords.z, GetEntityHeading(ped), 140)
end)

RegisterNetEvent('coe_ems:heal', function()
	local ped = PlayerPedId()
	SetEntityHealth(ped, GetEntityMaxHealth(ped))
	ClearPedBloodDamage(ped)
end)

RegisterNetEvent('coe_ems:respawn', function(x, y, z, heading)
	resurrect(x + 0.0, y + 0.0, z + 0.0, heading + 0.0, 150)
end)

-- Reporta ao servidor só quando o estado do jogo difere do que o servidor conhece.
CreateThread(function()
	while true do
		Wait(1000)
		local ped = PlayerPedId()
		if ped ~= 0 and current ~= 'dead' then
			local desired = desiredState(ped)
			if desired ~= current and not (current == 'unconscious' and desired ~= 'unconscious') then
				TriggerServerEvent('coe_ems:report', desired)
			end
		end
	end
end)
