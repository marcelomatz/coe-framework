-- coe_workpad (client): abre o tablet (tecla, comando ou uso do item), segura o tablet na mão e leva os pedidos dos
-- apps ao servidor. Quais apps aparecem e o que cada um pode fazer, o servidor decide.
local config = WorkpadConfig

local isOpen = false
local pending = {}
local nextRequest = 0

local function yielded()
	return GlobalState.coeWorkpadYielded and GlobalState.coeWorkpadYielded ~= false
end

-- Tablet na mão --------------------------------------------------------------------------------------------------

local anim = { prop = nil, token = 0 }

local function loadAsset(isModel, asset)
	if isModel then RequestModel(asset) else RequestAnimDict(asset) end
	local deadline = GetGameTimer() + 3000
	while GetGameTimer() < deadline do
		if (isModel and HasModelLoaded(asset)) or (not isModel and HasAnimDictLoaded(asset)) then
			return true
		end
		Wait(0)
	end
	return false
end

local function stopAnim()
	anim.token = anim.token + 1
	local ped = PlayerPedId()
	StopAnimTask(ped, config.Animation.Dict, config.Animation.Name, 1.5)
	if anim.prop and DoesEntityExist(anim.prop) then
		DetachEntity(anim.prop, true, true)
		DeleteEntity(anim.prop)
	end
	anim.prop = nil
end

local function startAnim()
	anim.token = anim.token + 1
	local mine = anim.token
	local settings = config.Animation
	CreateThread(function()
		local model = joaat(settings.Prop)
		if not loadAsset(false, settings.Dict) or not loadAsset(true, model) or mine ~= anim.token then
			SetModelAsNoLongerNeeded(model)
			return
		end
		local ped = PlayerPedId()
		local at = GetEntityCoords(ped)
		anim.prop = CreateObject(model, at.x, at.y, at.z, true, true, false)
		SetModelAsNoLongerNeeded(model)
		AttachEntityToEntity(anim.prop, ped, GetPedBoneIndex(ped, settings.Bone), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
			true, false, false, false, 2, true)
		TaskPlayAnim(ped, settings.Dict, settings.Name, 3.0, 3.0, -1, 49, 0, false, false, false)
		while mine == anim.token do
			Wait(500)
			local current = PlayerPedId()
			if mine == anim.token and not IsEntityPlayingAnim(current, settings.Dict, settings.Name, 3) then
				TaskPlayAnim(current, settings.Dict, settings.Name, 3.0, 3.0, -1, 49, 0, false, false, false)
			end
		end
	end)
end

-- Tela -----------------------------------------------------------------------------------------------------------

local function close()
	if not isOpen then
		return
	end
	isOpen = false
	SetNuiFocus(false, false)
	SendNUIMessage({ action = 'close' })
	stopAnim()
	for id, p in pairs(pending) do
		pending[id] = nil
		p:resolve({ ok = false, error = 'closed' })
	end
end

local function requestOpen()
	local ped = PlayerPedId()
	if isOpen or yielded() or IsPauseMenuActive() or IsPedInAnyVehicle(ped, true) or IsPedDeadOrDying(ped, true) then
		return
	end
	TriggerServerEvent('coe_workpad:open')
end

RegisterCommand(config.Command, requestOpen, false)

if config.OpenKey then
	RegisterCommand('+coe_workpad_open', requestOpen, false)
	RegisterCommand('-coe_workpad_open', function() end, false)
	RegisterKeyMapping('+coe_workpad_open', 'Abrir tablet de trabalho', 'keyboard', config.OpenKey)
end

RegisterNetEvent('coe_workpad:use', requestOpen)
RegisterNetEvent('coe_workpad:close', close)

RegisterNetEvent('coe_workpad:opened', function(profile)
	if isOpen or type(profile) ~= 'table' or yielded() then
		return
	end
	isOpen = true
	SetNuiFocus(true, true)
	startAnim()
	SendNUIMessage({ action = 'open', data = profile })
end)

-- Lista de apps recalculada (ex.: entrou na equipe de um negócio) com o tablet aberto.
RegisterNetEvent('coe_workpad:profile', function(profile)
	if isOpen and type(profile) == 'table' then
		SendNUIMessage({ action = 'profile', data = profile })
	end
end)

-- Ponto batido ou encerrado em qualquer lugar: a barra de status acompanha.
RegisterNetEvent('coe_workpad:duty', function(businessId)
	if isOpen then
		SendNUIMessage({ action = 'duty', data = businessId })
	end
end)

RegisterNetEvent('coe_workpad:result', function(requestId, result)
	local p = pending[requestId]
	if p then
		pending[requestId] = nil
		p:resolve(type(result) == 'table' and result or { ok = false })
	end
end)

AddStateBagChangeHandler('coeWorkpadYielded', 'global', function(_, _, value)
	if value then
		close()
	end
end)

-- NUI ------------------------------------------------------------------------------------------------------------

RegisterNUICallback('close', function(_, cb)
	close()
	cb({ ok = true })
end)

RegisterNUICallback('call', function(data, cb)
	if not isOpen or type(data) ~= 'table' then
		return cb({ ok = false, error = 'closed' })
	end
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
	TriggerServerEvent('coe_workpad:call', requestId, data.app, data.action, data.payload)
	cb(Citizen.Await(p))
end)

RegisterNUICallback('refresh', function(_, cb)
	if isOpen then
		TriggerServerEvent('coe_workpad:refresh')
	end
	cb({ ok = true })
end)

-- Marca um ponto no GPS (apps que listam locais: ponto, empregos, estrutura do negócio).
RegisterNUICallback('waypoint', function(data, cb)
	local x, y = type(data) == 'table' and tonumber(data.x), type(data) == 'table' and tonumber(data.y)
	if not isOpen or not x or not y or math.abs(x) > 10000 or math.abs(y) > 10000 then
		return cb({ ok = false })
	end
	SetNewWaypoint(x, y)
	cb({ ok = true })
end)

-- Entrou em veículo, morreu ou abriu o menu de pausa: guarda o tablet.
CreateThread(function()
	while true do
		Wait(isOpen and 500 or 1000)
		if isOpen then
			local ped = PlayerPedId()
			if IsPedInAnyVehicle(ped, true) or IsPedDeadOrDying(ped, true) or IsPauseMenuActive() then
				close()
			end
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
