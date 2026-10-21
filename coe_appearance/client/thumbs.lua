-- Gerador das fotos de roupa (lado cliente). Disparado pelo servidor (/coe_fotos_roupas, ACE): monta a sala do criador,
-- veste cada peça de cada subcategoria num ped local com a roupa base, fotografa com o screenshot-basic, recorta e
-- reduz na NUI (canvas, webp) e manda ao servidor. Peças que já têm foto são puladas (a menos que peça "refazer").
-- Backspace ou repetir o comando interrompe.
local S = AppearanceSchema
local A = AppearanceClient
local cfg = AppearanceConfig.Thumbnails
local spot = AppearanceConfig.Creator.Ped
local resource = GetCurrentResourceName()

ThumbsClient = {}
local job = nil -- { stop, ped, cam, total, done, skipped }
local crops = {} -- [id] = promise
local cropId = 0

function ThumbsClient.IsRunning()
	return job ~= nil
end

local function waitFor(check, timeoutMs)
	local deadline = GetGameTimer() + timeoutMs
	while not check() do
		if GetGameTimer() > deadline then
			return false
		end
		Wait(0)
	end
	return true
end

local function progress(text)
	SendNUIMessage({ action = 'thumbsProgress', text = text })
end

-- Câmera da foto: à frente do ped (ou atrás em `back`), deslocada para o lado em `side` (pulso).
local function pointCamera(shot)
	local spec = cfg.Cameras[shot] or cfg.Cameras.torso
	local ped = job.ped
	local origin = GetEntityCoords(ped)
	local forward = GetEntityForwardVector(ped)
	if spec.back then
		forward = -forward
	end
	local right = vector3(forward.y, -forward.x, 0.0)
	local side = right * (spec.side or 0.0)
	local position = origin + forward * spec.distance + side + vector3(0.0, 0.0, spec.height)
	local target = origin + side + vector3(0.0, 0.0, spec.target)
	if not job.cam then
		job.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
		RenderScriptCams(true, false, 0, true, true)
	end
	SetCamCoord(job.cam, position.x, position.y, position.z)
	PointCamAtCoord(job.cam, target.x, target.y, target.z)
	SetCamFov(job.cam, spec.fov)
end

local function wearBase(gender)
	local ped = job.ped
	for _, prop in ipairs(S.Props) do
		ClearPedProp(ped, prop.id)
	end
	for id, value in pairs(cfg.BaseOutfit[gender] or {}) do
		local component = tonumber(id)
		if value[1] < GetNumberOfPedDrawableVariations(ped, component) then
			SetPedComponentVariation(ped, component, value[1], value[2], 0)
		end
	end
end

-- Veste a peça e espera o streaming da variação terminar.
local function wear(part, drawable)
	local ped = job.ped
	if part.kind == 'prop' then
		SetPedPreloadPropData(ped, part.id, drawable, 0)
		waitFor(function() return HasPedPreloadPropDataFinished(ped) end, 3000)
		ClearPedProp(ped, part.id)
		SetPedPropIndex(ped, part.id, drawable, 0, true)
		ReleasePedPreloadPropData(ped)
	else
		SetPedPreloadVariationData(ped, part.id, drawable, 0)
		waitFor(function() return HasPedPreloadVariationDataFinished(ped) end, 3000)
		SetPedComponentVariation(ped, part.id, drawable, 0, 0)
		ReleasePedPreloadVariationData(ped)
	end
	Wait(cfg.SettleMs)
end

local function capture()
	local shot = promise.new()
	exports['screenshot-basic']:requestScreenshot({ encoding = 'jpg', quality = 0.95 }, function(data)
		shot:resolve(data)
	end)
	local data = Citizen.Await(shot)
	if type(data) ~= 'string' or data == '' then
		return nil
	end
	cropId = cropId + 1
	local id = cropId
	crops[id] = promise.new()
	SendNUIMessage({ action = 'thumbCrop', id = id, data = data, size = cfg.Size, crop = cfg.Crop, quality = cfg.Quality, type = 'image/' .. cfg.Extension })
	SetTimeout(5000, function()
		if crops[id] then
			crops[id]:resolve(nil)
		end
	end)
	local cropped = Citizen.Await(crops[id])
	crops[id] = nil
	return cropped
end

RegisterNUICallback('thumbCropped', function(data, callback)
	callback({ ok = true })
	local id = type(data) == 'table' and tonumber(data.id)
	if id and crops[id] then
		crops[id]:resolve(type(data.data) == 'string' and data.data or nil)
	end
end)

local function exists(name)
	return LoadResourceFile(resource, 'thumbs/' .. name) ~= nil
end

local function countDrawables(part)
	if part.kind == 'prop' then
		return GetNumberOfPedPropDrawableVariations(job.ped, part.id)
	end
	return GetNumberOfPedDrawableVariations(job.ped, part.id)
end

local function spawnFor(gender)
	if job.ped and DoesEntityExist(job.ped) then
		DeleteEntity(job.ped)
	end
	job.ped = A.CreatePed(nil, spot.x, spot.y, spot.z, spot.heading, gender)
	if not job.ped then
		return false
	end
	SetEntityCoordsNoOffset(job.ped, spot.x, spot.y, spot.z, false, false, false)
	FreezeEntityPosition(job.ped, true)
	ClearPedTasksImmediately(job.ped)
	SetEntityHeading(job.ped, spot.heading)
	return true
end

local function shootGender(gender, redo)
	if not spawnFor(gender) then
		return
	end
	for _, category in ipairs(S.ClothingCategories) do
		for _, part in ipairs(category.parts) do
			wearBase(gender)
			pointCamera(part.shot)
			local count = countDrawables(part)
			for drawable = 0, count - 1 do
				if job.stop then
					return
				end
				local name = S.ThumbName(gender, part.kind, part.id, drawable, cfg.Extension)
				if not redo and exists(name) then
					job.skipped = job.skipped + 1
				else
					progress(('%s · %s %d/%d · %d fotos'):format(gender == 'female' and 'Feminino' or 'Masculino', part.label, drawable + 1, count, job.done))
					wear(part, drawable)
					local image = capture()
					if image then
						TriggerLatentServerEvent('coe_appearance:thumbSave', 250000, name, image)
						job.done = job.done + 1
					else
						job.failed = job.failed + 1
					end
				end
			end
			if part.kind == 'prop' then
				ClearPedProp(job.ped, part.id)
			end
		end
	end
end

local function cleanup()
	if job.ped and DoesEntityExist(job.ped) then
		DeleteEntity(job.ped)
	end
	if job.cam then
		DestroyCam(job.cam, false)
	end
	RenderScriptCams(false, false, 0, true, true)
	ClearFocus()
	NetworkClearClockTimeOverride()
	SendNUIMessage({ action = 'thumbsProgress', text = false })
	TriggerEvent('coe_hud:setHidden', resource, false)
end

local function run(options)
	job = { stop = false, done = 0, skipped = 0, failed = 0 }
	TriggerEvent('coe_hud:setHidden', resource, true)
	DoScreenFadeOut(300)
	waitFor(IsScreenFadedOut, 2000)
	SetFocusPosAndVel(spot.x, spot.y, spot.z, 0.0, 0.0, 0.0)
	RequestCollisionAtCoord(spot.x, spot.y, spot.z)
	local interior = GetInteriorAtCoords(spot.x, spot.y, spot.z)
	if interior ~= 0 then
		PinInteriorInMemory(interior)
		waitFor(function() return IsInteriorReady(interior) end, 5000)
	end
	local clock = AppearanceConfig.Creator.Clock
	NetworkOverrideClockTime(clock.hour, clock.minute, 0)
	CreateThread(function()
		while job do
			HideHudAndRadarThisFrame()
			DisableAllControlActions(0)
			if IsDisabledControlJustPressed(0, 177) then -- Backspace / Esc
				job.stop = true
			end
			Wait(0)
		end
	end)
	Wait(500)
	DoScreenFadeIn(300)
	for _, gender in ipairs(options.genders) do
		if job.stop then
			break
		end
		shootGender(gender, options.redo)
	end
	local cancelled = job.stop
	print(('[coe_appearance] fotos: %d tiradas, %d já existiam, %d falharam%s'):format(job.done, job.skipped, job.failed, cancelled and ' (interrompido)' or ''))
	DoScreenFadeOut(300)
	waitFor(IsScreenFadedOut, 2000)
	cleanup()
	job = nil
	TriggerLatentServerEvent('coe_appearance:thumbsDone', 250000, cancelled)
	DoScreenFadeIn(500)
end

RegisterNetEvent('coe_appearance:thumbsStart', function(options)
	if job or type(options) ~= 'table' or type(options.genders) ~= 'table' then
		return
	end
	if AppearanceCreator and AppearanceCreator.IsOpen() then
		print('[coe_appearance] feche o criador antes de gerar as fotos')
		TriggerLatentServerEvent('coe_appearance:thumbsDone', 250000, true)
		return
	end
	CreateThread(function()
		run(options)
	end)
end)

RegisterNetEvent('coe_appearance:thumbsStop', function()
	if job then
		job.stop = true
	end
end)

AddEventHandler('onResourceStop', function(name)
	if name == resource and job then
		cleanup()
		DoScreenFadeIn(0)
	end
end)
