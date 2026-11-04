-- coe_races (client): o tablet de corridas (aparelho próprio), a corrida em si (grid, contagem, largada fantasma,
-- checkpoints com rota no GPS, HUD com posição, voltas e tempo) e o gravador de pistas dirigindo.
local config = RacesConfig

RacesClient = { pending = {}, nextRequest = 0 }
local Client = RacesClient

local locale = nil
Client.T = function(key, params)
	if Core and Core.Locale and Core.Locale.New then
		locale = locale or Core.Locale.New({ default = config.Locale or Core.Locale.GetDefaultLang(), locales = Locales or {} })
		return locale(key, params)
	end
	local text = (Locales and Locales['pt-BR'] and Locales['pt-BR'][key]) or key
	for name, value in pairs(params or {}) do
		text = text:gsub('%%{' .. name .. '}', (tostring(value):gsub('%%', '%%%%')))
	end
	return text
end

function Client.Notify(kind, message)
	pcall(function() exports.coe_notify:Show(kind, message, 5000) end)
end

function Client.Hud(kind, data)
	SendNUIMessage({ action = 'hud', type = kind, data = data })
end

-- Pedido ao servidor (mesmo canal do app): devolve o resultado ou { ok = false, error = 'timeout' }.
function Client.Request(action, payload)
	Client.nextRequest = Client.nextRequest + 1
	local requestId = Client.nextRequest
	local p = promise.new()
	Client.pending[requestId] = p
	SetTimeout(15000, function()
		if Client.pending[requestId] then
			Client.pending[requestId] = nil
			p:resolve({ ok = false, error = 'timeout' })
		end
	end)
	TriggerServerEvent('coe_races:call', requestId, action, payload or {})
	return Citizen.Await(p)
end

RegisterNetEvent('coe_races:result', function(requestId, result)
	local p = Client.pending[requestId]
	if p then
		Client.pending[requestId] = nil
		p:resolve(type(result) == 'table' and result or { ok = false, error = 'internal_error' })
	end
end)

-- Tablet de corridas (aparelho próprio) ------------------------------------------------------------------------------

local isOpen = false
local prop = nil
local animToken = 0

local function stopAnim()
	animToken = animToken + 1
	local ped = PlayerPedId()
	StopAnimTask(ped, config.Animation.Dict, config.Animation.Name, 1.5)
	if prop and Core.Platform.Entities.Exists(prop) then
		DetachEntity(prop, true, true)
		Core.Platform.Entities.Delete(prop)
	end
	prop = nil
end

local function startAnim()
	local ped = PlayerPedId()
	if IsPedInAnyVehicle(ped, false) then
		return
	end
	animToken = animToken + 1
	local mine = animToken
	CreateThread(function()
		local anim = config.Animation
		local model = joaat(anim.Prop)
		RequestAnimDict(anim.Dict)
		RequestModel(model)
		local deadline = GetGameTimer() + 3000
		while (not HasAnimDictLoaded(anim.Dict) or not HasModelLoaded(model)) and GetGameTimer() < deadline do
			Wait(0)
		end
		if mine ~= animToken or not HasAnimDictLoaded(anim.Dict) or not HasModelLoaded(model) then
			SetModelAsNoLongerNeeded(model)
			return
		end
		local coords = Core.Platform.Entities.GetCoords(ped)
		prop = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)
		SetModelAsNoLongerNeeded(model)
		AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, anim.Bone), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, false, false, false, 2, true)
		TaskPlayAnim(ped, anim.Dict, anim.Name, 3.0, 3.0, -1, 49, 0, false, false, false)
	end)
end

function Client.ClosePad()
	if not isOpen then
		return
	end
	isOpen = false
	SetNuiFocus(false, false)
	SendNUIMessage({ action = 'close' })
	stopAnim()
end

RegisterNetEvent('coe_races:opened', function()
	if isOpen or IsPedDeadOrDying(PlayerPedId(), true) then
		return
	end
	isOpen = true
	SetNuiFocus(true, true)
	SendNUIMessage({ action = 'open' })
	startAnim()
end)

RegisterCommand(config.Command, function()
	if not isOpen then
		TriggerServerEvent('coe_races:open')
	end
end, false)

RegisterNUICallback('close', function(_, cb)
	Client.ClosePad()
	cb({ ok = true })
end)

RegisterNUICallback('call', function(data, cb)
	if not isOpen or type(data) ~= 'table' or type(data.action) ~= 'string' then
		cb({ ok = false, error = 'closed' })
		return
	end
	cb(Client.Request(data.action, data.payload))
end)

RegisterNUICallback('waypoint', function(data, cb)
	local x, y = type(data) == 'table' and tonumber(data.x), type(data) == 'table' and tonumber(data.y)
	if not x or not y or math.abs(x) > 10000 or math.abs(y) > 10000 then
		cb({ ok = false })
		return
	end
	SetNewWaypoint(x, y)
	cb({ ok = true })
end)

CreateThread(function()
	while true do
		if isOpen and IsPedDeadOrDying(PlayerPedId(), true) then
			Client.ClosePad()
		end
		Wait(isOpen and 500 or 1500)
	end
end)

AddEventHandler('onResourceStop', function(resource)
	if resource ~= GetCurrentResourceName() then
		return
	end
	if isOpen then
		SetNuiFocus(false, false)
		stopAnim()
	end
	if Client.Cleanup then
		Client.Cleanup()
	end
end)
