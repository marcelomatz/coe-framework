-- coe_shops (client): balconistas e blips das lojas, vitrine (NUI) e pagamento. Preço, estoque e cobrança ficam no
-- servidor; o client só mostra e pede. Sem loops por quadro: os balconistas aparecem num laço de 1 s.
local config = ShopsConfig

local stores = {}
local blips = {}
local clerks = {}
local clerkInteriors = {}
local pending = {}
local nextRequest = 0
local uiStore = nil

local function request(action, payload)
	nextRequest = nextRequest + 1
	local requestId = nextRequest
	local p = promise.new()
	pending[requestId] = p
	SetTimeout(20000, function()
		if pending[requestId] then
			pending[requestId] = nil
			p:resolve({ ok = false, error = 'timeout' })
		end
	end)
	TriggerServerEvent('coe_shops:request', requestId, action, payload)
	return Citizen.Await(p)
end

RegisterNetEvent('coe_shops:response', function(requestId, result)
	local p = pending[requestId]
	if p then
		pending[requestId] = nil
		p:resolve(type(result) == 'table' and result or { ok = false })
	end
end)

local function show(kind, message)
	pcall(function() exports.coe_notify:Show(kind, message, 4000) end)
end

local ERRORS = {
	too_far = 'Chegue mais perto do balcão.', store_closed = 'Loja fechada.', not_ready = 'Loja ainda abrindo.',
	busy = 'Aguarde um instante.', no_character = 'Personagem não carregado.', timeout = 'Sem resposta da loja.'
}

-- Balconistas e blips ----------------------------------------------------------------------------------------

local function loadModel(name)
	local hash = joaat(name)
	if not IsModelInCdimage(hash) then
		return nil
	end
	RequestModel(hash)
	local deadline = GetGameTimer() + 5000
	while not HasModelLoaded(hash) and GetGameTimer() < deadline do
		Wait(25)
	end
	return HasModelLoaded(hash) and hash or nil
end

local function clearClerk(id)
	local ped = clerks[id]
	if ped and DoesEntityExist(ped) then
		pcall(function() exports.coetarget:RemoveTargetEntity(ped) end)
		DeleteEntity(ped)
	end
	clerks[id] = nil
	clerkInteriors[id] = nil
end

local function paintBlips()
	for id, blip in pairs(blips) do
		RemoveBlip(blip)
		blips[id] = nil
	end
	for _, store in ipairs(stores) do
		if store.blip == false then
			goto continue
		end
		local blip = AddBlipForCoord(store.clerk.x, store.clerk.y, store.clerk.z)
		SetBlipSprite(blip, store.blip and store.blip.sprite or 52)
		SetBlipColour(blip, store.blip and store.blip.color or 2)
		SetBlipDisplay(blip, 4)
		SetBlipScale(blip, 0.7)
		SetBlipAsShortRange(blip, true)
		BeginTextCommandSetBlipName('STRING')
		AddTextComponentSubstringPlayerName(store.label)
		EndTextCommandSetBlipName(blip)
		blips[store.id] = blip
		::continue::
	end
end

local function openStore(store)
	if uiStore then
		return
	end
	local result = request('open', { storeId = store.id })
	if not result.ok then
		show('error', ERRORS[result.error] or 'Não foi possível abrir a loja.')
		return
	end
	uiStore = store
	SendNUIMessage({ action = 'open', view = result.view })
	SetNuiFocus(true, true)
end

local function closeUi()
	if not uiStore then
		return
	end
	uiStore = nil
	SetNuiFocus(false, false)
	SendNUIMessage({ action = 'close' })
end

-- Interior das lojas (24/7, LTD e Rob's são interiores do mapa): o balconista criado com o interior ainda não
-- carregado fica fora da sala e não aparece para quem está lá dentro. Espera o interior e a colisão antes de criar.
local function prepareSpot(c)
	RequestCollisionAtCoord(c.x, c.y, c.z)
	local interior = GetInteriorAtCoords(c.x, c.y, c.z)
	if interior and interior ~= 0 then
		PinInteriorInMemory(interior)
		local deadline = GetGameTimer() + 5000
		while not IsInteriorReady(interior) and GetGameTimer() < deadline do
			Wait(50)
		end
	end
	-- Pés no chão: o config guarda a altura do corpo (como GetEntityCoords do jogador).
	local found, groundZ = GetGroundZFor_3dCoord(c.x, c.y, c.z + 0.5, false)
	if found and groundZ and math.abs(groundZ - (c.z - 1.0)) < 1.5 then
		return interior or 0, groundZ
	end
	return interior or 0, c.z - 1.0
end

local function spawnClerk(store)
	local hash = loadModel(store.clerkModel or 'mp_m_shopkeep_01') or loadModel('mp_m_shopkeep_01')
	if not hash then
		return
	end
	local c = store.clerk
	local interior, z = prepareSpot(c)
	local ped = CreatePed(4, hash, c.x, c.y, z, c.h, false, false)
	SetModelAsNoLongerNeeded(hash)
	if not ped or ped == 0 then
		return
	end
	SetEntityAsMissionEntity(ped, true, true)
	SetPedDefaultComponentVariation(ped)
	SetEntityHeading(ped, c.h)
	SetEntityInvincible(ped, true)
	SetBlockingOfNonTemporaryEvents(ped, true)
	SetPedCanRagdoll(ped, false)
	FreezeEntityPosition(ped, true)
	pcall(function()
		exports.coetarget:AddTargetEntity(ped, {
			{
				label = 'Comprar',
				distance = 3.0,
				canInteract = function() return uiStore == nil end,
				onSelect = function() openStore(store) end
			}
		})
	end)
	clerks[store.id] = ped
	clerkInteriors[store.id] = interior
end

-- Jogador dentro do mesmo interior e o balconista em outra sala (ou fora): põe o balconista na sala do jogador.
local function fixRoom(store, playerPed)
	local ped, interior = clerks[store.id], clerkInteriors[store.id]
	if not ped or not interior or interior == 0 or not DoesEntityExist(ped) then
		return
	end
	if GetInteriorFromEntity(playerPed) ~= interior then
		return
	end
	local room = GetRoomKeyFromEntity(playerPed)
	if room ~= 0 and GetRoomKeyFromEntity(ped) ~= room then
		ForceRoomForEntity(ped, interior, room)
	end
end

local function setStores(list)
	if type(list) ~= 'table' then
		return
	end
	for id in pairs(clerks) do
		clearClerk(id)
	end
	stores = list
	paintBlips()
end

-- Balconistas e blips saem do config compartilhado: aparecem mesmo antes do servidor terminar de abrir as lojas
-- (banco, negócios). Só a vitrine depende do servidor.
local function localStores()
	local catalog, catalogError = ShopsRules.Catalog(config)
	if not catalog then
		print(('[coe_shops] config inválido: %s'):format(tostring(catalogError)))
		return {}
	end
	local list = {}
	for _, store in ipairs(catalog.stores) do
		local kind = catalog.types[store.type]
		list[#list + 1] = { id = store.id, label = store.label, type = store.type, clerk = store.clerk, clerkModel = kind.clerk, blip = kind.blip }
	end
	return list
end

-- Diagnóstico no log do servidor (o F8 nem sempre está à mão): quantas lojas e blips este client montou,
-- balconistas criados e erros. Poucas mensagens por sessão.
local reported = 0
local function report(kind, info)
	if reported >= 12 then
		return
	end
	reported = reported + 1
	TriggerServerEvent('coe_shops:clientStatus', kind, info)
end

CreateThread(function()
	setStores(localStores())
	local count = 0
	for _ in pairs(blips) do
		count = count + 1
	end
	report('loaded', { stores = #stores, blips = count })
end)

CreateThread(function()
	while true do
		local playerPed = PlayerPedId()
		local coords = GetEntityCoords(playerPed)
		for _, store in ipairs(stores) do
			local distance = #(coords - vector3(store.clerk.x, store.clerk.y, store.clerk.z))
			if distance < config.SpawnDistance and not clerks[store.id] then
				local ok, spawnError = pcall(spawnClerk, store)
				if not ok then
					report('error', { store = store.id, message = tostring(spawnError) })
				elseif clerks[store.id] then
					local ped = clerks[store.id]
					local c = GetEntityCoords(ped)
					report('clerk', { store = store.id, interior = clerkInteriors[store.id], z = c.z, exists = DoesEntityExist(ped) })
				else
					report('error', { store = store.id, message = 'clerk_not_created' })
				end
			elseif distance > config.SpawnDistance + 20.0 and clerks[store.id] then
				clearClerk(store.id)
			elseif distance < 15.0 then
				fixRoom(store, playerPed)
			end
		end
		-- Afastou do balcão com a loja aberta: fecha.
		if uiStore then
			local c = uiStore.clerk
			if #(coords - vector3(c.x, c.y, c.z)) > config.CounterRadius + 3.0 then
				closeUi()
			end
		end
		Wait(1000)
	end
end)

-- Diagnóstico no F8: loja mais perto, distância, balconista e interior.
RegisterCommand('lojadebug', function()
	local playerPed = PlayerPedId()
	local coords = GetEntityCoords(playerPed)
	local nearest, best = nil, math.huge
	for _, store in ipairs(stores) do
		local distance = #(coords - vector3(store.clerk.x, store.clerk.y, store.clerk.z))
		if distance < best then
			nearest, best = store, distance
		end
	end
	if not nearest then
		print(('[coe_shops] nenhuma loja carregada (%d no config)'):format(#(config.Stores or {})))
		return
	end
	local ped = clerks[nearest.id]
	local pedCoords = ped and DoesEntityExist(ped) and GetEntityCoords(ped)
	print(('[coe_shops] %s a %.1f m | balconista=%s existe=%s pos=%s | interior loja=%s ped=%s jogador=%s | sala ped=%s jogador=%s'):format(
		nearest.id, best, tostring(ped), tostring(ped and DoesEntityExist(ped)),
		pedCoords and ('%.2f %.2f %.2f'):format(pedCoords.x, pedCoords.y, pedCoords.z) or '-',
		tostring(clerkInteriors[nearest.id]), tostring(ped and GetInteriorFromEntity(ped)), tostring(GetInteriorFromEntity(playerPed)),
		tostring(ped and GetRoomKeyFromEntity(ped)), tostring(GetRoomKeyFromEntity(playerPed))))
	print(('[coe_shops] jogador em %.2f %.2f %.2f'):format(coords.x, coords.y, coords.z))
end, false)

-- NUI ---------------------------------------------------------------------------------------------------------

RegisterNUICallback('close', function(_, cb)
	closeUi()
	cb({ ok = true })
end)

-- Compra. Carteira: pede o total ao servidor, esconde a loja e abre o pagamento no celular; o token vai junto da compra.
RegisterNUICallback('buy', function(data, cb)
	if not uiStore or type(data) ~= 'table' then
		return cb({ ok = false, error = 'closed' })
	end
	local storeId = uiStore.id
	local payment = { method = data.method, cardId = data.cardId, pin = data.pin }
	if data.method == 'wallet' then
		if GetResourceState('coe_phone') ~= 'started' then
			return cb({ ok = false, error = 'phone_unavailable' })
		end
		local quote = request('quote', { storeId = storeId, cart = data.cart })
		if not quote.ok then
			return cb(quote)
		end
		SetNuiFocus(false, false)
		SendNUIMessage({ action = 'suspend', value = true })
		local ok, paid = pcall(function()
			return exports.coe_phone:RequestPayment({ amount = quote.total, label = quote.label, note = ('%d %s'):format(quote.units, quote.units == 1 and 'item' or 'itens') })
		end)
		if uiStore then
			SendNUIMessage({ action = 'suspend', value = false })
			SetNuiFocus(true, true)
		end
		if not ok or type(paid) ~= 'table' or not paid.token then
			return cb({ ok = false, error = (ok and type(paid) == 'table' and paid.error) or 'cancelled' })
		end
		payment = { method = 'wallet', token = paid.token }
	end
	cb(request('buy', { storeId = storeId, cart = data.cart, payment = payment }))
end)

RegisterNUICallback('manage', function(data, cb)
	if not uiStore or type(data) ~= 'table' then
		return cb({ ok = false, error = 'closed' })
	end
	cb(request('manage', { storeId = uiStore.id, op = data.op, args = data.args }))
end)

AddEventHandler('onResourceStop', function(resource)
	if resource ~= GetCurrentResourceName() then
		return
	end
	if uiStore then
		SetNuiFocus(false, false)
	end
	for id in pairs(clerks) do
		clearClerk(id)
	end
	for _, blip in pairs(blips) do
		RemoveBlip(blip)
	end
end)
