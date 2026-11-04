-- Animação do tablet na mão enquanto a interface está aberta.
TabletAnim = {}

local DICT = 'amb@code_human_in_bus_passenger_idles@female@tablet@base'
local ANIM = 'base'
local MODEL = joaat('prop_cs_tablet')
local HAND_BONE = 28422

local prop = nil
local active = false
local token = 0

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

function TabletAnim.Stop()
	token = token + 1
	active = false
	local ped = PlayerPedId()
	if Core.Platform.Entities.Exists(ped) then
		StopAnimTask(ped, DICT, ANIM, 1.5)
		ClearPedTasks(ped)
	end
	if prop and Core.Platform.Entities.Exists(prop) then
		DetachEntity(prop, true, true)
		Core.Platform.Entities.Delete(prop)
	end
	prop = nil
end

function TabletAnim.Start()
	if active then
		return
	end
	active = true
	token = token + 1
	local mine = token

	CreateThread(function()
		if not loadDict() or not loadModel() or mine ~= token then
			if mine == token then
				active = false
			end
			SetModelAsNoLongerNeeded(MODEL)
			return
		end
		local ped = PlayerPedId()
		local coords = Core.Platform.Entities.GetCoords(ped)
		prop = CreateObject(MODEL, coords.x, coords.y, coords.z, false, false, false)
		SetModelAsNoLongerNeeded(MODEL)
		AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, HAND_BONE),
			0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, false, false, false, 2, true)
		TaskPlayAnim(ped, DICT, ANIM, 3.0, 3.0, -1, 49, 0, false, false, false)

		while active and mine == token do
			Wait(500)
			if not active or mine ~= token then
				break
			end
			local p = PlayerPedId()
			if IsPedDeadOrDying(p, true) then
				TabletAnim.Stop()
				break
			end
			if not IsEntityPlayingAnim(p, DICT, ANIM, 3) then
				TaskPlayAnim(p, DICT, ANIM, 3.0, 3.0, -1, 49, 0, false, false, false)
			end
		end
	end)
end
