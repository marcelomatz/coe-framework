-- Câmera do showroom: órbita suavizada em torno do veículo (presets, arrasto, zoom, giro automático)
-- e câmera livre limitada à área da oficina. Só roda enquanto está ativa.
ShowroomCamera = {}

local settings = CoeMechanicConfig.Camera
local cam, vehicle, center = nil, nil, nil
local active, free, auto = false, false, false
local dims = { l = 4.5, w = 2.0, h = 1.5 }
local goal, cur = nil, nil
local blend = nil
local interior = false
local lastPose = nil
local look = { cur = { yaw = 0.0, pitch = 0.0 }, goal = { yaw = 0.0, pitch = 0.0 } }
local fov = { cur = 45.0, goal = 45.0 }
local freePos, freeYaw, freePitch = nil, 0.0, 0.0
local onFreeExit = nil

local function clamp(value, low, high)
	return math.max(low, math.min(high, value))
end

local function angleDiff(target, from)
	return ((target - from + 180.0) % 360.0) - 180.0
end

local function presets()
	local l, w, h = dims.l, dims.w, dims.h
	return {
		front = { a = 25.0, p = 8.0, d = l * 1.5, tx = 0.0, ty = 0.0, tz = 0.0 },
		side = { a = 90.0, p = 6.0, d = l * 1.5, tx = 0.0, ty = 0.0, tz = 0.0 },
		rear = { a = 155.0, p = 8.0, d = l * 1.5, tx = 0.0, ty = 0.0, tz = 0.0 },
		top = { a = 90.0, p = 72.0, d = l * 1.7, tx = 0.0, ty = 0.0, tz = 0.0 },
		wheels = { a = 78.0, p = 4.0, d = l * 0.55, tx = w * 0.5, ty = l * 0.3, tz = -h * 0.25 },
		engine = { a = 10.0, p = 50.0, d = l * 0.85, tx = 0.0, ty = l * 0.38, tz = h * 0.1 },
		cabin = { a = 62.0, p = 12.0, d = l * 0.75, tx = 0.0, ty = -l * 0.05, tz = h * 0.15 }
	}
end

local function limits()
	return dims.l * 0.35, dims.l * 3.2
end

local function copy(source)
	local out = {}
	for key, value in pairs(source) do
		out[key] = value
	end
	return out
end

local function applyPose(position, target)
	if blend then
		local t = (GetGameTimer() - blend.start) / blend.duration
		if t >= 1.0 then
			blend = nil
		else
			local f = t * t * (3.0 - 2.0 * t)
			position = blend.position + (position - blend.position) * f
			target = blend.target + (target - blend.target) * f
		end
	end
	lastPose = { position = position, target = target }
	SetCamCoord(cam, position.x, position.y, position.z)
	PointCamAtCoord(cam, target.x, target.y, target.z)
end

local function orbitPose()
	local a, p = math.rad(cur.a), math.rad(cur.p)
	local reach = cur.d * math.cos(p)
	local position = GetOffsetFromEntityInWorldCoords(vehicle, cur.tx + reach * math.sin(a), cur.ty + reach * math.cos(a), cur.tz + cur.d * math.sin(p))
	local target = GetOffsetFromEntityInWorldCoords(vehicle, cur.tx, cur.ty, cur.tz)
	return position, target
end

-- Posição da cabeça do motorista, em coordenadas locais do veículo.
local function seatHead()
	local bone = GetEntityBoneIndexByName(vehicle, 'seat_dside_f')
	if bone ~= -1 then
		local world = GetWorldPositionOfEntityBone(vehicle, bone)
		local seat = GetOffsetFromEntityGivenWorldCoords(vehicle, world.x, world.y, world.z)
		return vector3(seat.x, seat.y - 0.05, seat.z + 0.62)
	end
	return vector3(-dims.w * 0.18, dims.l * 0.02, dims.h * 0.12)
end

local function interiorPose()
	local head = seatHead()
	local yaw, pitch = math.rad(look.cur.yaw), math.rad(look.cur.pitch)
	local reach = 5.0
	local position = GetOffsetFromEntityInWorldCoords(vehicle, head.x, head.y, head.z)
	local target = GetOffsetFromEntityInWorldCoords(vehicle,
		head.x + reach * math.sin(yaw) * math.cos(pitch),
		head.y + reach * math.cos(yaw) * math.cos(pitch),
		head.z + reach * math.sin(pitch))
	return position, target
end

local function currentPose()
	if interior then
		return interiorPose()
	end
	return orbitPose()
end

local function stepFov(k)
	fov.cur = fov.cur + (fov.goal - fov.cur) * k
	SetCamFov(cam, fov.cur)
end

local function stepOrbit(dt)
	if auto and not interior then
		goal.a = goal.a + 18.0 * dt
	end
	local k = 1.0 - math.exp(-dt * settings.Smoothing)
	cur.a = cur.a + angleDiff(goal.a, cur.a) * k
	for _, key in ipairs({ 'p', 'd', 'tx', 'ty', 'tz' }) do
		cur[key] = cur[key] + (goal[key] - cur[key]) * k
	end
	look.cur.yaw = look.cur.yaw + (look.goal.yaw - look.cur.yaw) * k
	look.cur.pitch = look.cur.pitch + (look.goal.pitch - look.cur.pitch) * k
	stepFov(k)
	applyPose(currentPose())
end

local function directionOf(yaw, pitch)
	local y, p = math.rad(yaw), math.rad(pitch)
	return vector3(-math.sin(y) * math.cos(p), math.cos(y) * math.cos(p), math.sin(p))
end

local function stepFree(dt)
	DisableAllControlActions(0)
	if IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 200) then
		ShowroomCamera.SetFree(false)
		return
	end
	freeYaw = freeYaw - GetDisabledControlNormal(0, 1) * settings.FreeLookSensitivity
	freePitch = clamp(freePitch - GetDisabledControlNormal(0, 2) * settings.FreeLookSensitivity, -85.0, 85.0)

	local speed = settings.FreeSpeed * dt
	if IsDisabledControlPressed(0, 21) then
		speed = speed * settings.FreeFastFactor
	elseif IsDisabledControlPressed(0, 36) then
		speed = speed * settings.FreeSlowFactor
	end
	local forward = directionOf(freeYaw, freePitch)
	local right = vector3(math.cos(math.rad(freeYaw)), math.sin(math.rad(freeYaw)), 0.0)
	local move = vector3(0.0, 0.0, 0.0)
	if IsDisabledControlPressed(0, 32) then move = move + forward end
	if IsDisabledControlPressed(0, 33) then move = move - forward end
	if IsDisabledControlPressed(0, 35) then move = move + right end
	if IsDisabledControlPressed(0, 34) then move = move - right end
	if IsDisabledControlPressed(0, 38) then move = move + vector3(0.0, 0.0, 1.0) end
	if IsDisabledControlPressed(0, 44) then move = move - vector3(0.0, 0.0, 1.0) end
	freePos = freePos + move * speed

	local flat = vector3(freePos.x - center.x, freePos.y - center.y, 0.0)
	local distance = #flat
	if distance > settings.FreeRadius then
		flat = flat * (settings.FreeRadius / distance)
		freePos = vector3(center.x + flat.x, center.y + flat.y, freePos.z)
	end
	local ground = GetEntityCoords(vehicle).z
	freePos = vector3(freePos.x, freePos.y, clamp(freePos.z, ground - 0.4, ground + settings.FreeMaxHeight))

	SetCamCoord(cam, freePos.x, freePos.y, freePos.z)
	SetCamRot(cam, freePitch, 0.0, freeYaw, 2)
end

local function loop()
	while active do
		HideHudAndRadarThisFrame()
		local dt = GetFrameTime()
		if not DoesEntityExist(vehicle) then
			break
		end
		if free then
			stepFree(dt)
		else
			DisableAllControlActions(0)
			stepOrbit(dt)
		end
		Wait(0)
	end
end

---@param entity integer
---@param room table centro da área da oficina ({x,y,z})
function ShowroomCamera.Start(entity, room)
	if active then
		return
	end
	vehicle = entity
	center = vector3(room.x, room.y, room.z)
	local minimum, maximum = GetModelDimensions(GetEntityModel(entity))
	dims = { l = math.max(2.5, maximum.y - minimum.y), w = math.max(1.2, maximum.x - minimum.x), h = math.max(1.0, maximum.z - minimum.z) }
	goal = presets().front
	cur = copy(goal)
	cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
	fov = { cur = settings.Fov, goal = settings.Fov }
	look = { cur = { yaw = 0.0, pitch = 0.0 }, goal = { yaw = 0.0, pitch = 0.0 } }
	interior, lastPose = false, nil
	SetCamFov(cam, settings.Fov)
	local position, target = orbitPose()
	SetCamCoord(cam, position.x, position.y, position.z)
	PointCamAtCoord(cam, target.x, target.y, target.z)
	SetCamActive(cam, true)
	RenderScriptCams(true, true, 900, true, true)
	active, free, auto, blend = true, false, false, nil
	CreateThread(loop)
end

---@param immediate boolean|nil
function ShowroomCamera.Stop(immediate)
	if not active then
		return
	end
	active, free, auto = false, false, false
	interior = false
	local handle = cam
	cam = nil
	RenderScriptCams(false, not immediate, immediate and 0 or 600, true, true)
	if immediate then
		DestroyCam(handle, false)
	else
		SetTimeout(700, function()
			DestroyCam(handle, false)
		end)
	end
	if vehicle and DoesEntityExist(vehicle) then
		SetVehicleDoorShut(vehicle, 4, false)
	end
end

function ShowroomCamera.IsActive()
	return active
end

function ShowroomCamera.IsFree()
	return free
end

---@param name string
function ShowroomCamera.Preset(name)
	if not active then
		return false
	end
	local wantsInterior = name == 'interior'
	local preset = presets()[name]
	if not preset and not wantsInterior then
		return false
	end
	if wantsInterior ~= interior then
		-- A troca entre a órbita e o banco do motorista é suavizada a partir da pose atual.
		if lastPose and not free then
			blend = { position = lastPose.position, target = lastPose.target, start = GetGameTimer(), duration = 800 }
		end
		interior = wantsInterior
		look.goal.yaw, look.goal.pitch = 0.0, 0.0
		look.cur.yaw, look.cur.pitch = 0.0, 0.0
		fov.goal = wantsInterior and settings.InteriorFov or settings.Fov
		auto = false
	end
	if preset then
		goal = preset
	end
	if vehicle and DoesEntityExist(vehicle) then
		if name == 'engine' then
			SetVehicleDoorOpen(vehicle, 4, false, false)
		else
			SetVehicleDoorShut(vehicle, 4, false)
		end
	end
	return true
end

function ShowroomCamera.Orbit(dx, dy)
	if not active or free then
		return
	end
	if interior then
		look.goal.yaw = clamp(look.goal.yaw - dx * 0.25, -120.0, 120.0)
		look.goal.pitch = clamp(look.goal.pitch + dy * 0.2, -50.0, 45.0)
		return
	end
	goal.a = goal.a - dx * 0.3
	goal.p = clamp(goal.p + dy * 0.2, 2.0, 80.0)
end

function ShowroomCamera.Zoom(direction)
	if not active or free then
		return
	end
	if interior then
		fov.goal = clamp(fov.goal * (direction > 0 and 1.08 or 0.92), 35.0, 95.0)
		return
	end
	local low, high = limits()
	goal.d = clamp(goal.d * (direction > 0 and 1.1 or 0.9), low, high)
end

function ShowroomCamera.IsInterior()
	return interior
end

function ShowroomCamera.SetAuto(enabled)
	auto = enabled == true and not interior
end

---@param enabled boolean
function ShowroomCamera.SetFree(enabled)
	if not active or free == (enabled == true) then
		return
	end
	local now = GetGameTimer()
	if enabled then
		local position, target = currentPose()
		local length = #direction
		freePos = position
		freeYaw = math.deg(math.atan(-direction.x, direction.y))
		freePitch = math.deg(math.asin(clamp(direction.z / length, -1.0, 1.0)))
		StopCamPointing(cam)
		free, auto = true, false
		blend = nil
	else
		local from = freePos
		free = false
		blend = { position = from, target = from + directionOf(freeYaw, freePitch) * 5.0, start = now, duration = 700 }
	end
	if onFreeExit then
		onFreeExit(free)
	end
end

---@param callback fun(free: boolean)
function ShowroomCamera.OnFreeChanged(callback)
	onFreeExit = callback
end
