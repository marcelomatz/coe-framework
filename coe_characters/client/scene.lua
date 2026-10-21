-- Cena da seleção de personagem: os personagens da conta aparecem lado a lado como peds locais (só este jogador vê),
-- num lugar escolhido no config (padrão: terraço do Observatório Galileo ao pôr do sol), com câmera cinematográfica,
-- interpolação entre eles e desfoque de profundidade. O jogador continua escondido onde estiver; o streaming segue a
-- cena via SetFocusPosAndVel.
CharacterScene = {}

local settings = CoeCharactersConfig.Scene
local scene = nil -- { peds = { [characterId] = ped }, order = {}, cam, focused, slots = {}, loaded, threadRunning }
local sceneToken = 0

local function isCurrent(token)
	return scene ~= nil and sceneToken == token
end

local function appearanceReady()
	return GetResourceState('coe_appearance') == 'started'
end

local function headingVectors(heading)
	local radians = math.rad(heading)
	local forward = vector3(-math.sin(radians), math.cos(radians), 0.0)
	local right = vector3(math.cos(radians), math.sin(radians), 0.0)
	return forward, right
end

local function groundAt(x, y, z, token)
	RequestCollisionAtCoord(x, y, z)
	for _ = 1, 50 do
		if token and not isCurrent(token) then
			return z
		end
		local found, groundZ = GetGroundZFor_3dCoord(x, y, z + 2.0, false)
		if found then
			return groundZ
		end
		Wait(20)
	end
	return z
end

local function fadeOut(ms, token)
	if IsScreenFadedOut() then
		return
	end
	DoScreenFadeOut(ms)
	local deadline = GetGameTimer() + ms + 1000
	while not IsScreenFadedOut() and GetGameTimer() < deadline do
		if token and not isCurrent(token) then
			return
		end
		Wait(0)
	end
end

local function loadScene(token)
	local anchor = settings.Anchor
	local forward = headingVectors(settings.Facing)
	SetFocusPosAndVel(anchor.x, anchor.y, anchor.z, 0.0, 0.0, 0.0)
	NewLoadSceneStart(anchor.x + forward.x * 6.0, anchor.y + forward.y * 6.0, anchor.z + 1.0, -forward.x, -forward.y, 0.0, 150.0, 0)
	local deadline = GetGameTimer() + settings.LoadTimeoutMs
	while not IsNewLoadSceneLoaded() and GetGameTimer() < deadline do
		if token and not isCurrent(token) then
			if not scene then
				NewLoadSceneStop()
			end
			return false
		end
		Wait(50)
	end
	if token and not isCurrent(token) then
		if not scene then
			NewLoadSceneStop()
		end
		return false
	end
	NewLoadSceneStop()
	RequestCollisionAtCoord(anchor.x, anchor.y, anchor.z)
	return true
end

local function applyAtmosphere()
	NetworkOverrideClockTime(settings.Clock.hour, settings.Clock.minute, 0)
	if settings.Weather then
		ClearOverrideWeather()
		SetWeatherTypeNowPersist(settings.Weather)
		SetOverrideWeather(settings.Weather)
	end
	if settings.Timecycle then
		SetTimecycleModifier(settings.Timecycle)
		SetTimecycleModifierStrength(settings.TimecycleStrength or 0.5)
	end
end

local function clearAtmosphere()
	NetworkClearClockTimeOverride()
	if settings.Weather then
		ClearOverrideWeather()
		ClearWeatherTypePersist()
	end
	if settings.Timecycle then
		ClearTimecycleModifier()
	end
end

-- Posição de cada vaga: centralizadas no Anchor, ao longo do eixo lateral.
local function slotPositions(count, token)
	local anchor = settings.Anchor
	local _, right = headingVectors(settings.Facing)
	local positions = {}
	for index = 1, count do
		if token and not isCurrent(token) then
			return nil
		end
		local offset = (index - (count + 1) / 2) * settings.Spacing
		local x, y = anchor.x + right.x * offset, anchor.y + right.y * offset
		positions[index] = vector3(x, y, groundAt(x, y, anchor.z, token))
	end
	return positions
end

local function playIdle(ped, index)
	local scenarios = settings.Idles
	if #scenarios == 0 then
		return
	end
	TaskStartScenarioInPlace(ped, scenarios[((index - 1) % #scenarios) + 1], 0, true)
end

local function deletePeds(target)
	local current = target or scene
	if not current then
		return
	end
	for _, ped in pairs(current.peds) do
		if DoesEntityExist(ped) then
			DeleteEntity(ped)
		end
	end
	current.peds, current.order, current.slots = {}, {}, {}
end

local function spawnPeds(characters, token)
	if not isCurrent(token) then
		return
	end
	deletePeds()
	if not appearanceReady() then
		return
	end
	local list = {}
	for index = 1, math.min(#characters, settings.MaxSlots) do
		list[index] = characters[index]
	end
	local positions = slotPositions(#list, token)
	if not positions or not isCurrent(token) then
		return
	end
	for index, character in ipairs(list) do
		if not isCurrent(token) then
			return
		end
		local position = positions[index]
		local ok, ped = pcall(function()
			return exports.coe_appearance:CreatePed(character.appearance, position.x, position.y, position.z, settings.Facing, character.gender)
		end)
		if not isCurrent(token) then
			if ok and ped and DoesEntityExist(ped) then
				DeleteEntity(ped)
			end
			return
		end
		if ok and ped then
			SetEntityHeading(ped, settings.Facing)
			-- Sempre opaco: o aviso de aparência pendente fica só na interface.
			ResetEntityAlpha(ped)
			playIdle(ped, index)
			scene.peds[character.characterId] = ped
			scene.slots[character.characterId] = position
			scene.order[#scene.order + 1] = character.characterId
		end
	end
end

local function makeCam(spec, origin, forward)
	local position = origin + forward * spec.distance + vector3(0.0, 0.0, spec.height)
	local target = origin + vector3(0.0, 0.0, spec.target)
	local cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', position.x, position.y, position.z, 0.0, 0.0, 0.0, spec.fov, false, 2)
	PointCamAtCoord(cam, target.x, target.y, target.z)
	if settings.DepthOfField then
		SetCamUseShallowDofMode(cam, true)
		SetCamNearDof(cam, math.max(0.1, spec.distance - 1.0))
		SetCamFarDof(cam, spec.distance + (spec.dofFar or 2.5))
		SetCamDofStrength(cam, spec.dofStrength or 0.8)
	end
	return cam
end

local function switchCam(cam, interpolate)
	if not scene then
		if cam and DoesCamExist(cam) then
			DestroyCam(cam, false)
		end
		return
	end
	local previous = scene.cam
	if previous and interpolate then
		SetCamActiveWithInterp(cam, previous, settings.InterpolationMs, 1, 1)
		SetTimeout(settings.InterpolationMs + 50, function()
			if DoesCamExist(previous) and (not scene or scene.cam ~= previous) then
				DestroyCam(previous, false)
			end
		end)
	else
		SetCamActive(cam, true)
		if previous and DoesCamExist(previous) then
			DestroyCam(previous, false)
		end
	end
	RenderScriptCams(true, false, 0, true, true)
	scene.cam = cam
end

local function overviewCam(interpolate, token)
	local activeToken = token or sceneToken
	local anchor = settings.Anchor
	local forward = headingVectors(settings.Facing)
	local groundZ = groundAt(anchor.x, anchor.y, anchor.z, activeToken)
	if not isCurrent(activeToken) then
		return
	end
	local origin = vector3(anchor.x, anchor.y, groundZ + 1.0)
	switchCam(makeCam(settings.Camera.overview, origin, forward), interpolate)
	scene.focused = nil
end

local function frameThread()
	CreateThread(function()
		while scene do
			HideHudAndRadarThisFrame()
			if settings.DepthOfField then
				SetUseHiDof()
			end
			Wait(0)
		end
	end)
end

-- Monta (ou remonta) a cena com a lista de personagens. A tela fica escura enquanto carrega.
function CharacterScene.Show(characters, focusId)
	if not settings.Enabled then
		return
	end
	sceneToken = sceneToken + 1
	local token = sceneToken
	local fresh = not scene or not scene.loaded
	if not scene then
		scene = { peds = {}, order = {}, slots = {}, loaded = false, threadRunning = false }
	end
	if not scene.threadRunning then
		scene.threadRunning = true
		frameThread()
	end
	if fresh then
		fadeOut(300, token)
		if not isCurrent(token) then
			return
		end
		if not loadScene(token) or not isCurrent(token) then
			return
		end
		applyAtmosphere()
		DisplayRadar(false)
		scene.loaded = true
	end
	spawnPeds(characters or {}, token)
	if not isCurrent(token) then
		return
	end
	local target = focusId and scene.peds[focusId] and focusId or scene.order[1]
	if target then
		CharacterScene.Focus(target, not fresh)
	else
		overviewCam(not fresh, token)
	end
	if not isCurrent(token) then
		return
	end
	if fresh or IsScreenFadedOut() then
		Wait(400)
		if not isCurrent(token) then
			return
		end
		DoScreenFadeIn(800)
	end
end

-- Câmera no personagem escolhido; ele se vira para a câmera.
function CharacterScene.Focus(characterId, interpolate)
	if not scene then
		return
	end
	local ped = scene.peds[characterId]
	if not ped or not DoesEntityExist(ped) then
		overviewCam(interpolate ~= false, sceneToken)
		return
	end
	if scene.focused and scene.peds[scene.focused] and scene.focused ~= characterId then
		local previous = scene.peds[scene.focused]
		for index, id in ipairs(scene.order) do
			if id == scene.focused then
				playIdle(previous, index)
			end
		end
	end
	local forward = headingVectors(settings.Facing)
	local origin = GetEntityCoords(ped)
	switchCam(makeCam(settings.Camera.focus, origin, forward), interpolate ~= false)
	ClearPedTasks(ped)
	TaskLookAtCoord(ped, origin.x + forward.x * 3.0, origin.y + forward.y * 3.0, origin.z + 0.6, -1, 0, 2)
	scene.focused = characterId
end

-- Desmonta a cena. Com keepFaded a tela fica escura (o próximo passo faz o fade in: spawn ou criador).
function CharacterScene.Destroy(keepFaded)
	sceneToken = sceneToken + 1
	if not scene then
		return
	end
	local current = scene
	scene = nil
	NewLoadSceneStop()
	if keepFaded then
		fadeOut(400)
	end
	deletePeds(current)
	if current.cam and DoesCamExist(current.cam) then
		DestroyCam(current.cam, false)
	end
	RenderScriptCams(false, false, 0, true, true)
	ClearFocus()
	clearAtmosphere()
	if not keepFaded then
		DisplayRadar(true)
	end
end

function CharacterScene.IsActive()
	return scene ~= nil
end

AddEventHandler('onResourceStop', function(resource)
	if resource == GetCurrentResourceName() and scene then
		CharacterScene.Destroy(false)
	end
end)
