-- Noclip da staff: voa atravessando paredes, na direção da câmera. W/S frente e trás, A/D lados, Q/E desce e sobe,
-- Shift acelera, roda do mouse troca a velocidade. Em veículo, move o veículo junto.
StaffNoclip = { active = false, speed = 2 }

local CONTROLS = {
	forward = 32, back = 33, left = 34, right = 35, up = 38, down = 44, fast = 21, wheelUp = 241, wheelDown = 242
}

local function entityOf()
	local ped = PlayerPedId()
	local vehicle = GetVehiclePedIsIn(ped, false)
	if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
		return vehicle
	end
	return ped
end

local function setGhost(entity, on)
	SetEntityCollision(entity, not on, not on)
	FreezeEntityPosition(entity, on)
	SetEntityInvincible(entity, on)
	SetEntityVelocity(entity, 0.0, 0.0, 0.0)
end

local function direction()
	local rot = GetGameplayCamRot(2)
	local pitch, yaw = math.rad(rot.x), math.rad(rot.z)
	local cosPitch = math.abs(math.cos(pitch))
	return vector3(-math.sin(yaw) * cosPitch, math.cos(yaw) * cosPitch, math.sin(pitch)), vector3(math.cos(yaw), math.sin(yaw), 0.0)
end

function StaffNoclip.Set(on, speeds)
	if on == StaffNoclip.active then
		return
	end
	StaffNoclip.active = on
	local entity = entityOf()
	setGhost(entity, on)
	if not on then
		local ped = PlayerPedId()
		setGhost(ped, false)
		return
	end
	CreateThread(function()
		local current = entity
		while StaffNoclip.active do
			Wait(0)
			local now = entityOf()
			if now ~= current then
				setGhost(current, false)
				setGhost(now, true)
				current = now
			end
			if IsDisabledControlJustPressed(0, CONTROLS.wheelUp) then
				StaffNoclip.speed = math.min(#speeds, StaffNoclip.speed + 1)
			elseif IsDisabledControlJustPressed(0, CONTROLS.wheelDown) then
				StaffNoclip.speed = math.max(1, StaffNoclip.speed - 1)
			end
			DisableControlAction(0, CONTROLS.wheelUp, true)
			DisableControlAction(0, CONTROLS.wheelDown, true)
			local forward, right = direction()
			local step = speeds[StaffNoclip.speed] * (IsControlPressed(0, CONTROLS.fast) and 3.0 or 1.0)
			local move = vector3(0.0, 0.0, 0.0)
			if IsControlPressed(0, CONTROLS.forward) then move = move + forward end
			if IsControlPressed(0, CONTROLS.back) then move = move - forward end
			if IsControlPressed(0, CONTROLS.right) then move = move + right end
			if IsControlPressed(0, CONTROLS.left) then move = move - right end
			if IsControlPressed(0, CONTROLS.up) then move = move + vector3(0.0, 0.0, 1.0) end
			if IsControlPressed(0, CONTROLS.down) then move = move - vector3(0.0, 0.0, 1.0) end
			local at = GetEntityCoords(current)
			local target = at + move * step
			SetEntityCoordsNoOffset(current, target.x, target.y, target.z, true, true, true)
			SetEntityHeading(current, GetGameplayCamRot(2).z)
			BeginTextCommandDisplayHelp('STRING')
			AddTextComponentSubstringPlayerName(('Noclip · velocidade %d/%d · Q/E desce/sobe · Shift rápido · roda do mouse muda'):format(StaffNoclip.speed, #speeds))
			EndTextCommandDisplayHelp(0, false, false, -1)
		end
		setGhost(current, false)
	end)
end
