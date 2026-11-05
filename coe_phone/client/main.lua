local config = CoePhoneConfig
local isOpen = false
local pending = {}
local nextRequest = 0
local capturing = false
local call = nil
local payRequests = {}
local nextPay = 0

local function syncAnim()
	if call and (call.state == 'outgoing' or call.state == 'active') then
		PhoneAnim.Set('call')
	elseif isOpen and not capturing then
		PhoneAnim.Set('text')
	else
		PhoneAnim.Set(nil)
	end
end

-- Sinal exibido: barras pela posição (as mesmas do servidor), com uma a menos em ambiente fechado (mínimo 1);
-- debaixo d'água fica sem sinal. `indoor` liga o Wi-Fi.
local lastSignal = nil

local function signalNow()
	local ped = PlayerPedId()
	local coords = Core.Platform.Entities.GetCoords(ped)
	local bars = PhoneRules.Signal(config, coords.x, coords.y)
	local indoor = GetInteriorFromEntity(ped) ~= 0
	if IsPedSwimmingUnderWater(ped) then
		bars = 0
	elseif indoor and bars > 1 then
		bars = bars - 1
	end
	return bars, indoor
end

local function pushSignal(force)
	local bars, indoor = signalNow()
	local key = bars .. (indoor and 'i' or 'o')
	if force or key ~= lastSignal then
		lastSignal = key
		SendNUIMessage({ action = 'signal', data = { bars = bars, indoor = indoor } })
	end
end

CreateThread(function()
	while true do
		if isOpen then
			pushSignal(false)
			Wait(2000)
		else
			Wait(1000)
		end
	end
end)

local function close()
	if not isOpen then
		return
	end
	isOpen = false
	SetNuiFocus(false, false)
	SendNUIMessage({ action = 'close' })
	for id, p in pairs(pending) do
		pending[id] = nil
		p:resolve({ ok = false, error = 'closed' })
	end
	-- Fechar o celular cancela um pagamento pedido por outro resource.
	for id, p in pairs(payRequests) do
		payRequests[id] = nil
		p:resolve({ error = 'cancelled' })
	end
	syncAnim()
end

local function request(appId, action, payload)
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
	TriggerServerEvent('coe_phone:call', requestId, appId, action, payload)
	return Citizen.Await(p)
end

local function requestOpen()
	if isOpen or capturing or IsPedDeadOrDying(PlayerPedId(), true) or IsPauseMenuActive() then
		return
	end
	TriggerServerEvent('coe_phone:open')
end

RegisterCommand(config.Command, requestOpen, false)
-- Comandos de quem vem do telefone básico (/telefone) continuam abrindo o celular.
for _, alias in ipairs(config.CommandAliases or {}) do
	RegisterCommand(alias, requestOpen, false)
end

if config.OpenKey then
	RegisterCommand('+coe_phone_open', requestOpen, false)
	RegisterCommand('-coe_phone_open', function() end, false)
	RegisterKeyMapping('+coe_phone_open', 'Abrir smartphone (COE OS)', 'keyboard', config.OpenKey)
end

RegisterNetEvent('coe_phone:opened', function(profile)
	if isOpen or type(profile) ~= 'table' then
		return
	end
	isOpen = true
	SetNuiFocus(true, true)
	SendNUIMessage({ action = 'open', data = profile })
	syncAnim()
	pushSignal(true)
end)

RegisterNetEvent('coe_phone:profile', function(profile)
	if isOpen and type(profile) == 'table' then
		SendNUIMessage({ action = 'profile', data = profile })
	end
end)

RegisterNetEvent('coe_phone:result', function(requestId, result)
	local p = pending[requestId]
	if p then
		pending[requestId] = nil
		p:resolve(result)
	end
end)

RegisterNetEvent('coe_phone:callState', function(state)
	if type(state) ~= 'table' then
		return
	end
	if state.state == 'ended' then
		if call and call.id ~= state.id then
			return
		end
		call = nil
	else
		call = state
	end
	SendNUIMessage({ action = 'call', data = state })
	syncAnim()
end)

RegisterNetEvent('coe_phone:message', function(message)
	if type(message) == 'table' then
		SendNUIMessage({ action = 'message', data = message })
	end
end)

RegisterNUICallback('close', function(_, cb)
	close()
	cb({ ok = true })
end)

RegisterNUICallback('call', function(data, cb)
	if not isOpen or type(data) ~= 'table' then
		cb({ ok = false, error = 'closed' })
		return
	end
	cb(request(data.app, data.action, data.payload))
end)

RegisterNUICallback('refresh', function(_, cb)
	if isOpen then
		TriggerServerEvent('coe_phone:refresh')
	end
	cb({ ok = true })
end)

-- Câmera (Insta): o celular sai da tela enquanto o jogador fotografa e volta com a foto.
RegisterNUICallback('camera', function(_, cb)
	if not isOpen or capturing or GetResourceState('coe_apps') ~= 'started' then
		cb({ ok = false, error = 'camera_unavailable' })
		return
	end
	capturing = true
	SetNuiFocus(false, false)
	SendNUIMessage({ action = 'suspend', data = true })
	syncAnim()
	local ok, result = pcall(function()
		return exports.coe_apps:TakePhoto()
	end)
	capturing = false
	if isOpen then
		SetNuiFocus(true, true)
	end
	SendNUIMessage({ action = 'suspend', data = false })
	syncAnim()
	cb(ok and type(result) == 'table' and result or { ok = false, error = 'camera_unavailable' })
end)

RegisterNUICallback('upload', function(data, cb)
	if not isOpen or type(data) ~= 'table' or type(data.image) ~= 'string' or GetResourceState('coe_apps') ~= 'started' then
		cb({ ok = false, error = 'app_unavailable' })
		return
	end
	local ok, result = pcall(function()
		return exports.coe_apps:StorePhoto(data.image)
	end)
	cb(ok and type(result) == 'table' and result or { ok = false, error = 'app_error' })
end)

-- Câmera do celular: grava a foto (e a miniatura) no aparelho. Evento latente por causa do tamanho.
RegisterNUICallback('savePhoto', function(data, cb)
	local photos = config.Photos
	if not isOpen or type(data) ~= 'table' or type(data.image) ~= 'string' or type(data.thumb) ~= 'string'
		or #data.image > photos.MaxBytes or #data.thumb > photos.ThumbMaxBytes then
		cb({ ok = false, error = 'invalid_photo' })
		return
	end
	nextRequest = nextRequest + 1
	local requestId = nextRequest
	local p = promise.new()
	pending[requestId] = p
	SetTimeout(30000, function()
		if pending[requestId] then
			pending[requestId] = nil
			p:resolve({ ok = false, error = 'timeout' })
		end
	end)
	TriggerLatentServerEvent('coe_phone:photo', photos.UploadBytesPerSecond, requestId, data.image, data.thumb)
	cb(Citizen.Await(p))
end)

RegisterNUICallback('waypoint', function(data, cb)
	local x, y = type(data) == 'table' and tonumber(data.x), type(data) == 'table' and tonumber(data.y)
	if not isOpen or not x or not y or math.abs(x) > 10000 or math.abs(y) > 10000 then
		cb({ ok = false })
		return
	end
	SetNewWaypoint(x, y)
	cb({ ok = true })
end)

-- Morreu: fecha o celular e desliga a ligação.
CreateThread(function()
	while true do
		if isOpen or call then
			if IsPedDeadOrDying(PlayerPedId(), true) then
				close()
				if call then
					TriggerServerEvent('coe_phone:call', 0, 'phone', 'hangup', {})
				end
				Wait(2000)
			end
			Wait(500)
		else
			Wait(1000)
		end
	end
end)

AddEventHandler('onResourceStop', function(resource)
	if resource == GetCurrentResourceName() then
		if isOpen then
			SetNuiFocus(false, false)
		end
		PhoneAnim.Stop()
	end
end)

-- Pagamento presencial pela Carteira (ex.: balcão de loja do coe_shops): abre o celular se preciso, mostra a folha de
-- pagamento com o valor e devolve a autorização. O resource que pediu entrega o token ao seu servidor, que o consome
-- com ConsumePayment (só os de Wallet.PaymentCallers). Bloqueia a thread de quem chama até o jogador decidir.
-- request: { amount, label, note }. Retorna { token, cardId } ou { error } (cancelled, phone_unavailable, invalid_amount).
exports('RequestPayment', function(request)
	local amount = type(request) == 'table' and math.tointeger(tonumber(request.amount)) or nil
	if not amount or amount < 1 or amount > config.Wallet.MaxAmount then
		return { error = 'invalid_amount' }
	end
	local openedHere = false
	if not isOpen then
		requestOpen()
		openedHere = true
		local deadline = GetGameTimer() + 8000
		while not isOpen and GetGameTimer() < deadline do
			Wait(50)
		end
		if not isOpen then
			return { error = 'phone_unavailable' }
		end
	end
	nextPay = nextPay + 1
	local id = nextPay
	local p = promise.new()
	payRequests[id] = p
	-- Watchdog de segurança estrito (20s) para evitar bloqueio indefinido de thread de pagamento
	local timeoutMs = 20000
	SetTimeout(timeoutMs, function()
		if payRequests[id] then
			payRequests[id] = nil
			p:resolve({ error = 'payment_timeout' })
		end
	end)
	SendNUIMessage({
		action = 'payRequest',
		data = {
			id = id, amount = amount,
			label = type(request.label) == 'string' and request.label:sub(1, 48) or nil,
			note = type(request.note) == 'string' and request.note:sub(1, 96) or nil
		}
	})
	local result = Citizen.Await(p)
	if openedHere then
		close()
	end
	if type(result) == 'table' and type(result.token) == 'string' then
		return { token = result.token, cardId = result.cardId }
	end
	return { error = type(result) == 'table' and result.error or 'cancelled' }
end)

RegisterNUICallback('payResult', function(data, cb)
	local id = type(data) == 'table' and math.tointeger(tonumber(data.id)) or nil
	local p = id and payRequests[id]
	if p then
		payRequests[id] = nil
		p:resolve({ token = type(data.token) == 'string' and data.token or nil, cardId = data.cardId, error = data.token and nil or 'cancelled' })
	end
	cb({ ok = true })
end)
