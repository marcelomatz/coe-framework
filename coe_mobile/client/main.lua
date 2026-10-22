-- coe_mobile (client): abre a tela (tecla, comando ou uso do item), segura o celular na mão e repassa ligações e
-- mensagens para a interface. Números, agenda, conversas e ligações ficam no servidor; o client só mostra e pede.
local config = MobileConfig

local isOpen = false
local peeking = false   -- tela visível sem foco: ligação chegando com o telefone fechado
local opening = false
local call = nil
local pending = {}
local nextRequest = 0

local function send(message)
	SendNUIMessage(message)
end

local function show(kind, message)
	if type(message) == 'string' and message ~= '' then
		pcall(function() exports.coe_notify:Show(kind, message, 5000) end)
	end
end

local function yielded()
	return GlobalState.coeMobileYielded and GlobalState.coeMobileYielded ~= false
end

local function request(kind, payload)
	nextRequest = nextRequest + 1
	local requestId = nextRequest
	local p = promise.new()
	pending[requestId] = p
	SetTimeout(15000, function()
		if pending[requestId] then
			pending[requestId] = nil
			p:resolve({ ok = false, error = 'timeout' })
		end
	end)
	TriggerServerEvent('coe_mobile:request', requestId, kind, payload)
	return Citizen.Await(p)
end

RegisterNetEvent('coe_mobile:response', function(requestId, result)
	local p = pending[requestId]
	if p then
		pending[requestId] = nil
		p:resolve(type(result) == 'table' and result or { ok = false })
	end
end)

-- Celular na mão ---------------------------------------------------------------------------------------------

local anim = { prop = nil, dict = nil, name = nil }

local function loadAsset(isModel, asset)
	if isModel then RequestModel(asset) else RequestAnimDict(asset) end
	local deadline = GetGameTimer() + 2000
	while GetGameTimer() < deadline do
		if (isModel and HasModelLoaded(asset)) or (not isModel and HasAnimDictLoaded(asset)) then
			return true
		end
		Wait(0)
	end
	return false
end

local function stopAnim()
	local ped = PlayerPedId()
	if anim.dict then
		StopAnimTask(ped, anim.dict, anim.name, 2.0)
	end
	if anim.prop and DoesEntityExist(anim.prop) then
		DeleteEntity(anim.prop)
	end
	anim.prop, anim.dict, anim.name = nil, nil, nil
end

local function wantedAnim()
	if call and call.state == 'active' then
		return config.Animation.Call
	end
	if isOpen then
		return config.Animation.Text
	end
	return nil
end

local function applyAnim()
	local name = wantedAnim()
	local ped = PlayerPedId()
	if not name or IsPedDeadOrDying(ped, true) then
		stopAnim()
		return
	end
	local settings = config.Animation
	local dict = GetVehiclePedIsIn(ped, false) ~= 0 and settings.VehicleDict or settings.Dict
	if anim.dict == dict and anim.name == name and IsEntityPlayingAnim(ped, dict, name, 3) then
		return
	end
	if not loadAsset(false, dict) then
		return
	end
	if not (anim.prop and DoesEntityExist(anim.prop)) then
		local model = joaat(settings.Prop)
		if loadAsset(true, model) then
			local at = GetEntityCoords(ped)
			anim.prop = CreateObject(model, at.x, at.y, at.z + 0.2, true, true, false)
			AttachEntityToEntity(anim.prop, ped, GetPedBoneIndex(ped, settings.Bone), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
				true, true, false, true, 1, true)
			SetModelAsNoLongerNeeded(model)
		end
	end
	TaskPlayAnim(ped, dict, name, 3.0, 3.0, -1, 50, 0, false, false, false)
	RemoveAnimDict(dict)
	anim.dict, anim.name = dict, name
end

-- Carregar modelo e animação espera alguns frames: um ajuste por vez (o laço abaixo corrige o que ficar para trás).
local animSyncing = false
local function syncAnim()
	if animSyncing then
		return
	end
	animSyncing = true
	local ok, err = pcall(applyAnim)
	animSyncing = false
	if not ok then
		print(('[coe_mobile] animação: %s'):format(tostring(err)))
	end
end

-- Tela -------------------------------------------------------------------------------------------------------

local function close()
	if not isOpen and not peeking then
		return
	end
	isOpen = false
	peeking = false
	SetNuiFocus(false, false)
	send({ type = 'close' })
	syncAnim()
end

local function open()
	if isOpen or opening or yielded() or IsPauseMenuActive() or IsPedDeadOrDying(PlayerPedId(), true) then
		return
	end
	opening = true
	local result = request('open', {})
	opening = false
	if not result.ok then
		show('error', result.message)
		return
	end
	isOpen = true
	peeking = false
	SetNuiFocus(true, true)
	call = result.data and result.data.call or call
	send({ type = 'open', data = result.data })
	syncAnim()
end

local function requestOpen()
	CreateThread(open)
end

RegisterCommand(config.Command, requestOpen, false)

if config.OpenKey then
	RegisterCommand('+coe_mobile_open', requestOpen, false)
	RegisterCommand('-coe_mobile_open', function() end, false)
	RegisterKeyMapping('+coe_mobile_open', 'Abrir telefone', 'keyboard', config.OpenKey)
end

RegisterNetEvent('coe_mobile:use', requestOpen)
RegisterNetEvent('coe_mobile:close', close)

-- Ligações: a tela acompanha o estado. Chegando com o telefone fechado, aparece sem foco até o jogador abrir.
RegisterNetEvent('coe_mobile:call', function(view)
	if type(view) ~= 'table' then
		return
	end
	if view.state == 'ended' then
		if call and call.key ~= view.key then
			return
		end
		call = nil
		send({ type = 'call', data = view })
		if peeking then
			SetTimeout(1500, function()
				if peeking and not call then
					peeking = false
					send({ type = 'close' })
				end
			end)
		end
	else
		call = view
		if not isOpen and not peeking and view.direction == 'incoming' and view.state == 'ringing' then
			peeking = true
			send({ type = 'peek', data = view, key = config.OpenKey or config.Command })
		else
			send({ type = 'call', data = view })
		end
	end
	syncAnim()
end)

RegisterNetEvent('coe_mobile:message', function(message)
	if type(message) ~= 'table' then
		return
	end
	send({ type = 'message', data = message })
	if not isOpen then
		local body = tostring(message.body or '')
		if #body > 60 then
			body = body:sub(1, 57) .. '...'
		end
		show('info', ('%s: %s'):format(message.name or message.number or '?', body))
	end
end)

AddStateBagChangeHandler('coeMobileYielded', 'global', function(_, _, value)
	if value then
		call = nil
		close()
	end
end)

-- Morreu, abriu o menu de pausa ou o telefone sumiu da mão: fecha. A animação volta se outra a interromper.
CreateThread(function()
	while true do
		Wait(500)
		if isOpen and (IsPedDeadOrDying(PlayerPedId(), true) or IsPauseMenuActive()) then
			close()
		end
		if wantedAnim() or anim.prop then
			syncAnim()
		end
	end
end)

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		return
	end
	stopAnim()
	if isOpen then
		SetNuiFocus(false, false)
	end
end)

-- NUI --------------------------------------------------------------------------------------------------------

RegisterNUICallback('close', function(_, cb)
	close()
	cb({})
end)

RegisterNUICallback('action', function(data, cb)
	if (not isOpen and not peeking) or type(data) ~= 'table' or type(data.action) ~= 'string' then
		return cb({ ok = false, error = 'unavailable' })
	end
	local result = request('action', { action = data.action, data = type(data.data) == 'table' and data.data or {} })
	if result.ok and type(result.data) == 'table' and type(result.data.call) == 'table' then
		call = result.data.call
		syncAnim()
	end
	cb(result)
end)
