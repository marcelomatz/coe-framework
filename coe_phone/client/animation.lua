-- Celular na mão: 'text' com o aparelho aberto, 'call' em ligação (no ouvido), nil guarda o aparelho.
PhoneAnim = {}

local MODEL = joaat('prop_npc_phone_02')
local HAND_BONE = 28422
local DICTS = { foot = 'cellphone@', car = 'anim@cellphone@in_car@ps' }
local ANIMS = { text = 'cellphone_text_read_base', call = 'cellphone_call_listen_base' }

local mode = nil
local prop = nil
local playing = nil
local running = false

local function load(request, loaded, asset)
	request(asset)
	local deadline = GetGameTimer() + 3000
	while not loaded(asset) and GetGameTimer() < deadline do
		Wait(0)
	end
	return loaded(asset)
end

local function removeProp()
	if prop and DoesEntityExist(prop) then
		DetachEntity(prop, true, true)
		DeleteEntity(prop)
	end
	prop = nil
end

local function stopAnim(ped)
	if playing then
		StopAnimTask(ped, playing.dict, playing.anim, 2.0)
		playing = nil
	end
end

local function ensureProp(ped)
	if prop and DoesEntityExist(prop) then
		return
	end
	if not load(RequestModel, HasModelLoaded, MODEL) then
		return
	end
	local coords = GetEntityCoords(ped)
	prop = CreateObject(MODEL, coords.x, coords.y, coords.z, false, false, false)
	SetModelAsNoLongerNeeded(MODEL)
	AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, HAND_BONE), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, false, false, false, 2, true)
end

local function loop()
	running = true
	while mode do
		local ped = PlayerPedId()
		if IsPedDeadOrDying(ped, true) then
			break
		end
		local dict = IsPedInAnyVehicle(ped, false) and DICTS.car or DICTS.foot
		local anim = ANIMS[mode]
		if not playing or playing.dict ~= dict or playing.anim ~= anim or not IsEntityPlayingAnim(ped, dict, anim, 3) then
			if load(RequestAnimDict, HasAnimDictLoaded, dict) and mode then
				if playing and (playing.dict ~= dict or playing.anim ~= anim) then
					stopAnim(ped)
				end
				TaskPlayAnim(ped, dict, anim, 3.0, 3.0, -1, 50, 0, false, false, false)
				playing = { dict = dict, anim = anim }
			end
		end
		ensureProp(ped)
		Wait(300)
	end
	stopAnim(PlayerPedId())
	removeProp()
	running = false
end

function PhoneAnim.Set(next)
	mode = ANIMS[next] and next or nil
	if mode and not running then
		CreateThread(loop)
	end
end

function PhoneAnim.Stop()
	mode = nil
	stopAnim(PlayerPedId())
	removeProp()
end
