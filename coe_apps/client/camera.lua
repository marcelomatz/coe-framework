-- Câmera do COE OS: o aparelho (tablet ou smartphone) chama TakePhoto, que assume a câmera do jogo até o jogador
-- fotografar ou cancelar, e StorePhoto, que envia a foto já reduzida ao servidor (evento latente) e devolve um token.
local busy = false
local nextRequest = 0
local pending = {}

local HEAD_BONE = 31086
local CONTROLS = { look_x = 1, look_y = 2, shoot = 24, aim = 25, enter = 191, back = 194, esc = 200, zoom_in = 241, zoom_out = 242, flip = 38 }

local function forward(heading)
	local rad = math.rad(heading)
	return vector3(-math.sin(rad), math.cos(rad), 0.0)
end

local function clamp(value, low, high)
	return math.max(low, math.min(high, value))
end

-- Instruções no aviso de interação padrão do framework (exports.coe_notify:Prompt). Só reenvia quando muda.
local shownMode = nil

local function help(selfie)
	local mode = selfie == nil and nil or (selfie and 'selfie' or 'rear')
	if mode == shownMode then
		return
	end
	shownMode = mode
	pcall(function()
		exports.coe_notify:Prompt(mode and {
			title = 'Câmera',
			subtitle = selfie and 'Selfie' or 'Câmera traseira',
			badge = 'CAM',
			options = {
				{ key = 'Clique', label = 'Fotografar' },
				{ key = 'E', label = selfie and 'Câmera traseira' or 'Selfie' },
				{ key = 'Roda', label = 'Zoom' },
				{ key = 'Botão direito', label = 'Cancelar' }
			}
		} or nil)
	end)
end

-- Diagnóstico no F8: a tela só mostra o código do erro.
local function diag(message)
	print(('^3[coe_apps] câmera: %s^7'):format(message))
end

-- Devolve a foto (data URL) ou nil e o código do erro: camera_unavailable (screenshot-basic não respondeu à chamada),
-- camera_timeout (a página de captura não devolveu a foto) ou camera_empty (devolveu algo que não é JPEG).
local function screenshot(quality)
	local result = promise.new()
	local ok, err = pcall(function()
		exports['screenshot-basic']:requestScreenshot({ encoding = 'jpg', quality = quality }, function(data)
			result:resolve(data or false)
		end)
	end)
	if not ok then
		diag('requestScreenshot falhou: ' .. tostring(err))
		return nil, 'camera_unavailable'
	end
	SetTimeout(10000, function()
		result:resolve(nil)
	end)
	local data = Citizen.Await(result)
	if data == nil then
		diag('o screenshot-basic não devolveu a foto em 10 s (a página de captura não chamou screenshot_created)')
		return nil, 'camera_timeout'
	end
	if type(data) ~= 'string' or data:sub(1, 23) ~= 'data:image/jpeg;base64,' then
		diag(('o screenshot-basic devolveu um formato inesperado (%s, %d bytes: %s)'):format(
			type(data), type(data) == 'string' and #data or 0, type(data) == 'string' and data:sub(1, 30) or '-'))
		return nil, 'camera_empty'
	end
	return data
end

exports('TakePhoto', function()
	if busy then
		return { ok = false, error = 'camera_unavailable' }
	end
	if GetResourceState('screenshot-basic') ~= 'started' then
		diag('o resource screenshot-basic não está iniciado (' .. GetResourceState('screenshot-basic') .. ')')
		return { ok = false, error = 'camera_unavailable' }
	end
	busy = true
	local ped = PlayerPedId()
	local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
	local heading, pitch, yaw, fov = GetEntityHeading(ped), 0.0, 0.0, 55.0
	local selfie = false
	RenderScriptCams(true, false, 0, true, true)

	local action
	while not action do
		Wait(0)
		DisableAllControlActions(0)
		HideHudAndRadarThisFrame()
		if IsPedDeadOrDying(ped, true) or IsPedInAnyVehicle(ped, true) then
			action = 'cancel'
			break
		end
		local dx, dy = GetDisabledControlNormal(0, CONTROLS.look_x), GetDisabledControlNormal(0, CONTROLS.look_y)
		if IsDisabledControlJustPressed(0, CONTROLS.zoom_in) then
			fov = clamp(fov - 5.0, 20.0, 80.0)
		elseif IsDisabledControlJustPressed(0, CONTROLS.zoom_out) then
			fov = clamp(fov + 5.0, 20.0, 80.0)
		end
		if IsDisabledControlJustPressed(0, CONTROLS.flip) then
			selfie, yaw, pitch = not selfie, 0.0, 0.0
		end

		local head = GetPedBoneCoords(ped, HEAD_BONE, 0.0, 0.0, 0.0)
		if selfie then
			-- Selfie: a câmera fica na frente do rosto, olhando para o personagem; o mouse gira em volta.
			yaw = clamp(yaw - dx * 6.0, -60.0, 60.0)
			pitch = clamp(pitch - dy * 4.0, -25.0, 25.0)
			local around = heading + yaw
			local position = head + forward(around) * 0.75 + vector3(0.0, 0.0, 0.05)
			SetCamCoord(cam, position.x, position.y, position.z)
			SetCamRot(cam, pitch - 4.0, 0.0, around + 180.0, 2)
		else
			-- Câmera traseira: o personagem gira junto com a mira.
			heading = (heading - dx * 8.0) % 360.0
			pitch = clamp(pitch - dy * 6.0, -70.0, 70.0)
			SetEntityHeading(ped, heading)
			local position = head + forward(heading) * 0.3
			SetCamCoord(cam, position.x, position.y, position.z)
			SetCamRot(cam, pitch, 0.0, heading, 2)
		end
		SetCamFov(cam, fov)
		help(selfie)

		if IsDisabledControlJustPressed(0, CONTROLS.shoot) or IsDisabledControlJustPressed(0, CONTROLS.enter) then
			action = 'shoot'
		elseif IsDisabledControlJustPressed(0, CONTROLS.aim) or IsDisabledControlJustPressed(0, CONTROLS.back)
			or IsDisabledControlJustPressed(0, CONTROLS.esc) then
			action = 'cancel'
		end
	end

	local image, imageError
	help(nil)
	if action == 'shoot' then
		-- Alguns quadros sem HUD nem texto de ajuda antes da captura.
		local hide = true
		CreateThread(function()
			while hide do
				HideHudAndRadarThisFrame()
				DisableAllControlActions(0)
				Wait(0)
			end
		end)
		Wait(80)
		image, imageError = screenshot(0.9)
		hide = false
		PlaySoundFrontend(-1, 'Camera_Shoot', 'Phone_Soundset_Franklin', true)
	end

	RenderScriptCams(false, false, 0, true, true)
	DestroyCam(cam, false)
	busy = false
	if action ~= 'shoot' then
		return { ok = false, error = 'cancelled' }
	end
	if not image then
		return { ok = false, error = imageError or 'camera_unavailable' }
	end
	return { ok = true, image = image }
end)

exports('StorePhoto', function(image)
	if type(image) ~= 'string' or #image > CoeAppsConfig.Photos.MaxBytes then
		return { ok = false, error = 'invalid_photo' }
	end
	nextRequest = nextRequest + 1
	local requestId = nextRequest
	local result = promise.new()
	pending[requestId] = result
	TriggerLatentServerEvent('coe_apps:photo', 200000, requestId, image)
	SetTimeout(30000, function()
		if pending[requestId] then
			pending[requestId] = nil
			result:resolve({ ok = false, error = 'timeout' })
		end
	end)
	return Citizen.Await(result)
end)

RegisterNetEvent('coe_apps:photoResult', function(requestId, response)
	local result = pending[requestId]
	if result then
		pending[requestId] = nil
		result:resolve(type(response) == 'table' and response or { ok = false, error = 'app_error' })
	end
end)

AddEventHandler('onResourceStop', function(resource)
	if resource == GetCurrentResourceName() and busy then
		RenderScriptCams(false, false, 0, true, true)
	end
end)
