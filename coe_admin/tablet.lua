-- Animação de tablet enquanto o painel está aberto: prop na mão e idle de tablet.
Tablet = {}

local DICT = 'amb@code_human_in_bus_passenger_idles@female@tablet@base'
local ANIM = 'base'
local MODEL = joaat('prop_cs_tablet')
local HAND_BONE = 28422

local prop = nil
local active = false
local token = 0
local cam = nil

local function loadDict()
	RequestAnimDict(DICT)
	local deadline = GetGameTimer() + 3000
	while not HasAnimDictLoaded(DICT) and GetGameTimer() < deadline do
		Wait(0)
	end
	return HasAnimDictLoaded(DICT)
end

local function loadModel()
	RequestModel(MODEL)
	local deadline = GetGameTimer() + 3000
	while not HasModelLoaded(MODEL) and GetGameTimer() < deadline do
		Wait(0)
	end
	return HasModelLoaded(MODEL)
end

local function canPlay(ped)
	return not IsPedInAnyVehicle(ped, true)
		and not IsPedDeadOrDying(ped, true)
		and not IsPedRagdoll(ped)
		and not IsEntityPlayingAnim(ped, DICT, ANIM, 3)
end

local function startCam(ped)
	if cam then return end
	local target = GetOffsetFromEntityInWorldCoords(ped, 0.1, 0.35, 0.35)
	local from = GetOffsetFromEntityInWorldCoords(ped, 0.28, -0.55, 0.78)
	cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
	SetCamCoord(cam, from.x, from.y, from.z)
	PointCamAtCoord(cam, target.x, target.y, target.z)
	SetCamFov(cam, 38.0)
	SetCamActive(cam, true)
	RenderScriptCams(true, true, 900, true, false)
end

local function stopCam()
	if not cam then return end
	RenderScriptCams(false, true, 600, true, false)
	local old = cam
	cam = nil
	SetTimeout(700, function()
		DestroyCam(old, false)
	end)
end

function Tablet.Stop()
	token = token + 1
	stopCam()
	active = false

	local ped = PlayerPedId()
	if Core.Platform.Entities.Exists(ped) then
		StopAnimTask(ped, DICT, ANIM, 1.5)
		ClearPedSecondaryTask(ped)
	end
	if prop and Core.Platform.Entities.Exists(prop) then
		DetachEntity(prop, true, true)
		Core.Platform.Entities.Delete(prop)
	end
	prop = nil
end

function Tablet.Start()
	if active then return end
	local ped = PlayerPedId()
	if not canPlay(ped) then return end

	active = true
	token = token + 1
	local mine = token

	CreateThread(function()
		if not loadDict() or not loadModel() or mine ~= token then
			if mine == token then active = false end
			SetModelAsNoLongerNeeded(MODEL)
			return
		end

		local current = PlayerPedId()
		local coords = Core.Platform.Entities.GetCoords(current)
		prop = CreateObject(MODEL, coords.x, coords.y, coords.z, false, false, false)
		SetModelAsNoLongerNeeded(MODEL)
		AttachEntityToEntity(prop, current, GetPedBoneIndex(current, HAND_BONE),
			0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, false, false, false, 2, true)
		TaskPlayAnim(current, DICT, ANIM, 3.0, 3.0, -1, 49, 0, false, false, false)
		startCam(current)

		-- Se a animação for interrompida (queda, veículo, morte), solta o prop sem fechar o painel.
		while active and mine == token do
			Wait(500)
			if not active or mine ~= token then break end
			local p = PlayerPedId()
			if IsPedInAnyVehicle(p, true) or IsPedDeadOrDying(p, true) then
				Tablet.Stop()
				break
			end
			if not IsEntityPlayingAnim(p, DICT, ANIM, 3) then
				TaskPlayAnim(p, DICT, ANIM, 3.0, 3.0, -1, 49, 0, false, false, false)
			end
		end
	end)
end
