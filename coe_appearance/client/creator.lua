-- Criador de personagem: sala de lineup do GTA Online, ped local com a aparência sendo editada, câmeras por etapa
-- com interpolação e desfoque, e a NUI em etapas (html/). Quem abre (coe_characters) recebe o resultado pelos eventos
-- locais `coe_appearance:creatorSubmit` e `coe_appearance:creatorCancelled` e fecha com CloseCreator/CreatorError.
local S = AppearanceSchema
local A = AppearanceClient
local settings = AppearanceConfig.Creator

local creator = nil -- { mode, characterId, gender, ped, cam, appearance, identity, heading, preset }

AppearanceCreator = {
	IsOpen = function()
		return creator ~= nil
	end
}

local function fade(out, ms)
	if out then
		DoScreenFadeOut(ms)
		while not IsScreenFadedOut() do
			Wait(0)
		end
	else
		DoScreenFadeIn(ms)
	end
end

local function loadDict(dict)
	RequestAnimDict(dict)
	local deadline = GetGameTimer() + 3000
	while not HasAnimDictLoaded(dict) do
		if GetGameTimer() > deadline then
			return false
		end
		Wait(10)
	end
	return true
end

local function playIdle(ped, gender)
	local idle = settings.Idle[gender]
	if idle and loadDict(idle.dict) then
		TaskPlayAnim(ped, idle.dict, idle.anim, 8.0, -8.0, -1, 1, 0, false, false, false)
	end
end

local function cameraFor(preset)
	local ped = creator.ped
	local spec = settings.Cameras[preset] or settings.Cameras.body
	local origin = GetEntityCoords(ped)
	local forward = GetEntityForwardVector(ped)
	local position = origin + forward * spec.distance + vector3(0.0, 0.0, spec.height)
	local target = origin + vector3(0.0, 0.0, spec.target)
	local cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', position.x, position.y, position.z, 0.0, 0.0, 0.0, spec.fov, false, 2)
	PointCamAtCoord(cam, target.x, target.y, target.z)
	if settings.DepthOfField then
		SetCamUseShallowDofMode(cam, true)
		SetCamNearDof(cam, math.max(0.1, spec.distance - 0.6))
		SetCamFarDof(cam, spec.distance + 1.8)
		SetCamDofStrength(cam, 0.85)
	end
	return cam
end

local function setCamera(preset, instant)
	if not creator or not creator.ped then
		return
	end
	if creator.preset == preset and creator.cam and not instant then
		return
	end
	local previous = creator.cam
	local cam = cameraFor(preset)
	if previous and not instant then
		SetCamActiveWithInterp(cam, previous, settings.InterpolationMs, 1, 1)
		SetTimeout(settings.InterpolationMs + 50, function()
			if DoesCamExist(previous) and (not creator or creator.cam ~= previous) then
				DestroyCam(previous, false)
			end
		end)
	else
		SetCamActive(cam, true)
		if previous then
			DestroyCam(previous, false)
		end
	end
	RenderScriptCams(true, false, 0, true, true)
	creator.cam, creator.preset = cam, preset
end

local function deletePed()
	if creator and creator.ped and DoesEntityExist(creator.ped) then
		DeleteEntity(creator.ped)
	end
	if creator then
		creator.ped = nil
	end
end

-- (Re)cria o ped do gênero atual. Sem aparência, começa da roupa padrão do modelo.
local function spawnPed(appearance)
	deletePed()
	local spot = settings.Ped
	local ped = A.CreatePed(appearance, spot.x, spot.y, spot.z, creator.heading, creator.gender)
	if not ped then
		return false
	end
	creator.ped = ped
	SetEntityCoordsNoOffset(ped, spot.x, spot.y, spot.z, false, false, false)
	if not appearance then
		local components, props = A.ReadParts(ped)
		appearance = S.Default(creator.gender, components, props)
		A.Apply(ped, appearance)
	end
	creator.appearance = appearance
	playIdle(ped, creator.gender)
	return true
end

local function snapshot()
	return { appearance = creator.appearance, limits = A.Limits(creator.ped, creator.appearance) }
end

local function schemaForUi()
	local function parents(list)
		local result = {}
		for index, entry in ipairs(list) do
			result[index] = { id = entry[1], name = entry[2], portrait = S.Portrait(entry[1]) }
		end
		return result
	end
	return {
		featureGroups = S.FeatureGroups, overlays = S.Overlays, components = S.Components, props = S.Props,
		clothing = S.ClothingCategories,
		fathers = parents(S.Fathers), mothers = parents(S.Mothers)
	}
end

local function outfitsFor(gender)
	local list = {}
	for index, outfit in ipairs(AppearanceConfig.Outfits[gender] or {}) do
		list[index] = { id = outfit.id, label = outfit.label }
	end
	return list
end

local function sceneThread()
	CreateThread(function()
		while creator do
			HideHudAndRadarThisFrame()
			DisableAllControlActions(0)
			if settings.DepthOfField then
				SetUseHiDof()
			end
			if creator.ped and DoesEntityExist(creator.ped) then
				SetEntityHeading(creator.ped, creator.heading)
			end
			Wait(0)
		end
	end)
end

local function close(keepFaded)
	if not creator then
		return
	end
	if not keepFaded and not IsScreenFadedOut() then
		fade(true, 400)
	end
	deletePed()
	if creator.cam and DoesCamExist(creator.cam) then
		DestroyCam(creator.cam, false)
	end
	RenderScriptCams(false, false, 0, true, true)
	ClearFocus()
	NetworkClearClockTimeOverride()
	SetStreamedTextureDictAsNoLongerNeeded('char_creator_portraits')
	SetNuiFocus(false, false)
	SendNUIMessage({ action = 'close' })
	creator = nil
	TriggerEvent('coe_hud:setHidden', GetCurrentResourceName(), false)
end

-- options: { mode = 'create'|'appearance', characterId?, gender?, firstName?, lastName?, birthDate? }
local function open(options)
	if creator or type(options) ~= 'table' or (ThumbsClient and ThumbsClient.IsRunning()) then
		return false
	end
	local mode = options.mode == 'appearance' and 'appearance' or 'create'
	creator = {
		mode = mode,
		characterId = options.characterId,
		gender = options.gender == 'female' and 'female' or 'male',
		heading = settings.Ped.heading,
		identity = { firstName = options.firstName or '', lastName = options.lastName or '', birthDate = options.birthDate or '' }
	}
	-- HUD (coe_hud) escondido enquanto o criador estiver aberto.
	TriggerEvent('coe_hud:setHidden', GetCurrentResourceName(), true)
	if not IsScreenFadedOut() then
		fade(true, 400)
	end
	local spot = settings.Ped
	SetFocusPosAndVel(settings.Focus.x, settings.Focus.y, settings.Focus.z, 0.0, 0.0, 0.0)
	RequestCollisionAtCoord(spot.x, spot.y, spot.z)
	local interior = GetInteriorAtCoords(spot.x, spot.y, spot.z)
	if interior ~= 0 then
		PinInteriorInMemory(interior)
		local deadline = GetGameTimer() + 5000
		while not IsInteriorReady(interior) and GetGameTimer() < deadline do
			Wait(10)
		end
	end
	RequestStreamedTextureDict('char_creator_portraits', false)
	NetworkOverrideClockTime(settings.Clock.hour, settings.Clock.minute, 0)
	if not spawnPed(nil) then
		close(true)
		DoScreenFadeIn(300)
		return false
	end
	Wait(300)
	setCamera(settings.StepCamera[mode == 'create' and 'identity' or 'heritage'] or 'body', true)
	sceneThread()
	SetNuiFocus(true, true)
	local data = snapshot()
	SendNUIMessage({
		action = 'open',
		mode = mode,
		gender = creator.gender,
		identity = creator.identity,
		identityLimits = AppearanceConfig.Identity,
		appearance = data.appearance,
		limits = data.limits,
		palettes = A.Palettes(),
		schema = schemaForUi(),
		outfits = outfitsFor(creator.gender),
		cameras = settings.StepCamera,
		thumbs = AppearanceConfig.Thumbnails.Enabled and {
			base = AppearanceConfig.Thumbnails.Base, extension = AppearanceConfig.Thumbnails.Extension
		} or false
	})
	fade(false, 700)
	return true
end

-- NUI ------------------------------------------------------------------------------------------------------

local function guard(callback)
	if not creator then
		callback({ ok = false })
		return false
	end
	return true
end

RegisterNUICallback('update', function(data, callback)
	if not guard(callback) then
		return
	end
	local appearance = type(data) == 'table' and S.Normalize(data.appearance) or nil
	if not appearance or appearance.model ~= S.ModelFor(creator.gender) then
		callback({ ok = false })
		return
	end
	creator.appearance = appearance
	A.Apply(creator.ped, appearance)
	callback({ ok = true, limits = A.Limits(creator.ped, appearance) })
end)

RegisterNUICallback('gender', function(data, callback)
	if not guard(callback) then
		return
	end
	local gender = type(data) == 'table' and data.gender == 'female' and 'female' or 'male'
	if gender ~= creator.gender then
		creator.gender = gender
		spawnPed(nil)
		setCamera(creator.preset or 'body', true)
	end
	local result = snapshot()
	result.ok, result.outfits = true, outfitsFor(gender)
	callback(result)
end)

RegisterNUICallback('randomize', function(_, callback)
	if not guard(callback) then
		return
	end
	creator.appearance = S.Randomize(creator.appearance)
	A.Apply(creator.ped, creator.appearance)
	local result = snapshot()
	result.ok = true
	callback(result)
end)

RegisterNUICallback('outfit', function(data, callback)
	if not guard(callback) then
		return
	end
	for _, outfit in ipairs(AppearanceConfig.Outfits[creator.gender] or {}) do
		if type(data) == 'table' and outfit.id == data.id then
			for id, value in pairs(outfit.components) do
				creator.appearance.components[id] = { drawable = value[1], texture = value[2] }
			end
		end
	end
	creator.appearance = S.Normalize(creator.appearance)
	A.Apply(creator.ped, creator.appearance)
	local result = snapshot()
	result.ok = true
	callback(result)
end)

RegisterNUICallback('camera', function(data, callback)
	if not guard(callback) then
		return
	end
	setCamera(type(data) == 'table' and settings.Cameras[data.preset] and data.preset or 'body')
	callback({ ok = true })
end)

RegisterNUICallback('rotate', function(data, callback)
	if not guard(callback) then
		return
	end
	local delta = type(data) == 'table' and tonumber(data.delta) or 0
	creator.heading = (creator.heading + math.max(-45.0, math.min(45.0, delta))) % 360.0
	callback({ ok = true })
end)

RegisterNUICallback('resetRotation', function(_, callback)
	if not guard(callback) then
		return
	end
	creator.heading = settings.Ped.heading
	callback({ ok = true })
end)

RegisterNUICallback('submit', function(data, callback)
	if not guard(callback) then
		return
	end
	local appearance = type(data) == 'table' and S.Normalize(data.appearance) or nil
	if not appearance then
		callback({ ok = false })
		return
	end
	creator.appearance = appearance
	local identity = type(data.identity) == 'table' and data.identity or {}
	TriggerEvent('coe_appearance:creatorSubmit', {
		mode = creator.mode,
		characterId = creator.characterId,
		identity = {
			firstName = type(identity.firstName) == 'string' and identity.firstName or '',
			lastName = type(identity.lastName) == 'string' and identity.lastName or '',
			birthDate = type(identity.birthDate) == 'string' and identity.birthDate or '',
			gender = creator.gender
		},
		appearance = appearance,
		version = S.Version
	})
	callback({ ok = true })
end)

RegisterNUICallback('cancel', function(_, callback)
	if not guard(callback) then
		return
	end
	local mode, characterId = creator.mode, creator.characterId
	callback({ ok = true })
	close(false)
	TriggerEvent('coe_appearance:creatorCancelled', { mode = mode, characterId = characterId })
end)

-- Exports para quem abre o criador ----------------------------------------------------------------------------

exports('OpenCreator', function(options)
	return open(options)
end)

-- Fecha o criador e deixa a tela escura: quem chamou monta a próxima cena e faz o fade in.
exports('CloseCreator', function()
	close(false)
end)

exports('CreatorError', function(message)
	if creator then
		SendNUIMessage({ action = 'error', message = type(message) == 'string' and message or 'Não foi possível salvar.' })
	end
end)

exports('IsCreatorOpen', function()
	return creator ~= nil
end)

AddEventHandler('onClientResourceStart', function(resource)
	if resource == 'coe_hud' and creator then
		TriggerEvent('coe_hud:setHidden', GetCurrentResourceName(), true)
	end
end)

AddEventHandler('onResourceStop', function(resource)
	if resource == GetCurrentResourceName() and creator then
		close(true)
		DoScreenFadeIn(0)
	end
end)
