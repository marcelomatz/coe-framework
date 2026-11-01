local config = CoeMechanicConfig
local ready = false
local service

local function syncShops()
	MechanicShops.Apply(config.Shops, exports.coe_businesses:List('mechanic'), config)
	TriggerClientEvent('coe_mechanic:shops', -1, config.Shops)
end

local lastShopsRequest = {}

RegisterNetEvent('coe_mechanic:requestShops', function()
	local playerId = source
	local now = GetGameTimer()
	if not ready or (lastShopsRequest[playerId] and now - lastShopsRequest[playerId] < 1000) then
		return
	end
	lastShopsRequest[playerId] = now
	TriggerClientEvent('coe_mechanic:shops', playerId, config.Shops)
end)

local function log(level, category, event, context)
	pcall(function()
		return exports.coe_logging:Log(level, category, event, context)
	end)
end

local function audit(event, context)
	pcall(function()
		return exports.coe_audit:Record('info', 'audit', event, context)
	end)
end

local function reply(playerId, kind, message)
	if playerId > 0 then
		pcall(function()
			exports.coe_notify:Notify(playerId, kind, message)
		end)
	end
	print(('[coe_mechanic] %s'):format(message))
end

local rawLocales = (type(Locales) == 'table' and Locales) or {}
local _t_inst = (Core and Core.Locale and Core.Locale.New) and Core.Locale.New({
	default = (config and config.Locale) or (Core and Core.Locale and Core.Locale.GetDefaultLang()) or 'pt-BR',
	locales = rawLocales
})
local _t = function(k, params)
	if type(_t_inst) == 'table' then
		if _t_inst.T then
			return _t_inst:T(k, params)
		end
		local lang = _t_inst.lang or 'pt-BR'
		local dict = (_t_inst.locales and _t_inst.locales[lang]) or rawLocales[lang] or rawLocales['pt-BR']
		if dict and dict[k] then
			return dict[k]
		end
	elseif type(_t_inst) == 'function' then
		return _t_inst(k, params)
	end
	return (rawLocales['pt-BR'] and rawLocales['pt-BR'][k]) or k
end

local function callerName()
	return GetInvokingResource() or GetCurrentResourceName()
end

local function isWriter()
	return config.WriterResources[callerName()] == true
end

local function notifyChanged(vehicleId)
	TriggerEvent('coe_mechanic:partsChanged', vehicleId)
end

local appearanceService
local ordersService
local business
local function vehicleEntity(vehicleId)
	local ok, entity = pcall(function()
		return exports.coe_vehicles:GetEntity(vehicleId)
	end)
	return ok and entity or nil
end

local function publishAppearance(vehicleId, entity, appearance)
	if entity and DoesEntityExist(entity) and appearance and next(appearance) ~= nil then
		Entity(entity).state:set('coe:appearance', appearance, true)
	end
end

AddEventHandler('coe_vehicles:spawned', function(vehicleId, entity)
	if not appearanceService then
		return
	end
	publishAppearance(vehicleId, entity, appearanceService.Get(vehicleId))
end)

AddEventHandler('coe_vehicles:released', function(vehicleId)
	if service then
		service.Forget(vehicleId)
	end
	if appearanceService then
		appearanceService.Forget(vehicleId)
	end
end)

local function vehiclePricing(record)
	local ok, info = pcall(function()
		return exports.coe_vehicle_catalog:GetVehicleInfo(record.model)
	end)
	info = ok and info or nil
	return info and info.price, info and info.class
end

exports('GetAppearance', function(vehicleId)
	if not ready then
		return nil
	end
	return appearanceService.Get(vehicleId)
end)

-- Orçamento de um patch de aparência (sem gravar). Retorna { total, lines } ou código de erro.
exports('QuoteAppearance', function(vehicleId, patch)
	if not ready then
		return 'not_ready'
	end
	local record = exports.coe_vehicles:Get(vehicleId)
	if not record then
		return 'vehicle_not_found'
	end
	local price, class = vehiclePricing(record)
	local quote, errorCode = appearanceService.Quote(vehicleId, patch, price, class)
	return quote or errorCode or 'unknown_error'
end)

-- Grava um patch (cores, mods, livery...) e republica no veículo. Apenas writers; a cobrança é do chamador.
exports('SetAppearance', function(vehicleId, patch)
	if not isWriter() then
		log('warn', 'security', 'vehicle_appearance_forbidden', { operation = callerName() })
		return 'forbidden'
	end
	if not ready then
		return 'not_ready'
	end
	if not exports.coe_vehicles:Get(vehicleId) then
		return 'vehicle_not_found'
	end
	local merged, errorCode = appearanceService.Apply(vehicleId, patch, callerName())
	if not merged then
		return errorCode or 'unknown_error'
	end
	publishAppearance(vehicleId, vehicleEntity(vehicleId), merged)
	return true
end)

-- Usado por coe_handling: { mods = {campo = mult}, key = string } do desgaste atual.
exports('GetEffects', function(vehicleId, mileage)
	if not ready then
		return nil
	end
	mileage = mileage or exports.coe_vehicles:GetMileage(vehicleId)
	if not mileage then
		return nil
	end
	local inspection = service.Inspect(vehicleId, mileage)
	return inspection and { mods = inspection.mods, key = inspection.key } or nil
end)

exports('Inspect', function(vehicleId)
	if not ready then
		return nil
	end
	local mileage = exports.coe_vehicles:GetMileage(vehicleId)
	if not mileage then
		return nil
	end
	local inspection = service.Inspect(vehicleId, mileage)
	return inspection and inspection.parts or nil
end)

exports('ReplacePart', function(vehicleId, part)
	if not isWriter() then
		log('warn', 'security', 'vehicle_part_forbidden', { operation = callerName() })
		return 'forbidden'
	end
	if not ready then
		return 'not_ready'
	end
	local mileage = exports.coe_vehicles:GetMileage(vehicleId)
	if not mileage then
		return 'vehicle_not_found'
	end
	local done, errorCode = service.ReplacePart(vehicleId, part, mileage, callerName())
	if not done then
		return errorCode or 'unknown_error'
	end
	notifyChanged(vehicleId)
	return true
end)

exports('ServiceVehicle', function(vehicleId)
	if not isWriter() then
		log('warn', 'security', 'vehicle_part_forbidden', { operation = callerName() })
		return 'forbidden'
	end
	if not ready then
		return 'not_ready'
	end
	local mileage = exports.coe_vehicles:GetMileage(vehicleId)
	if not mileage then
		return 'vehicle_not_found'
	end
	local replaced, errorCode = service.ServiceAll(vehicleId, mileage, callerName())
	if not replaced then
		return errorCode or 'unknown_error'
	end
	if #replaced > 0 then
		notifyChanged(vehicleId)
	end
	return true
end)

-- Desgaste extra vindo de outros resources (WearResources): o coe_fuel soma com gasolina comum e desconta com a
-- aditivada. meters > 0 envelhece as peças, < 0 desconta só o extra já acumulado. Zera na troca da peça.
exports('AddWear', function(vehicleId, meters, parts)
	if config.WearResources[callerName()] ~= true then
		log('warn', 'security', 'vehicle_wear_forbidden', { operation = callerName() })
		return 'forbidden'
	end
	if not ready then
		return 'not_ready'
	end
	local done, errorCode = service.AddWear(vehicleId, meters, parts)
	if not done then
		return errorCode or 'unknown_error'
	end
	notifyChanged(vehicleId)
	return true
end)

-- Corrige a quilometragem (coe_vehicles audita). Apenas writers.
exports('AdjustMileage', function(vehicleId, meters)
	if not isWriter() then
		log('warn', 'security', 'vehicle_mileage_forbidden', { operation = callerName() })
		return 'forbidden'
	end
	return exports.coe_vehicles:SetMileage(vehicleId, meters)
end)

exports('ListParts', function()
	local names = {}
	for name in pairs(config.Parts) do
		names[#names + 1] = name
	end
	table.sort(names)
	return names
end)

exports('IsReady', function()
	return ready
end)

local function tabletDistance(playerId, vehicleId)
	local entity = vehicleEntity(vehicleId)
	local ped = GetPlayerPed(playerId)
	if not entity or not DoesEntityExist(entity) or not ped or ped == 0 then
		return nil
	end
	return #(GetEntityCoords(ped) - GetEntityCoords(entity))
end

-- Equipe e ponto são do coe_businesses: dono ou funcionário cadastrado naquela oficina (nunca por emprego).
local function accessOf(shopId, characterId)
	local ok, access = pcall(function()
		return exports.coe_businesses:Access(shopId, characterId)
	end)
	return ok and type(access) == 'table' and access or {}
end

-- Oficina em que o mecânico está (perímetro de trabalho ao redor do showroom) e que o seu emprego atende, de ponto batido.
-- O dono da oficina também atende, mesmo sem o emprego nem o ponto.
local function shopOfMechanic(playerId)
	local ped = GetPlayerPed(playerId)
	if not ped or ped == 0 then
		return nil
	end
	local at = GetEntityCoords(ped)
	local characterId = Core.Players.GetActiveCharacterId(playerId)
	for shopId, shop in pairs(config.Shops) do
		local inside
		if shop.area then
			inside = BusinessArea.Contains(shop.area, at.x, at.y, at.z)
		else
			local room = shop.showroom
			inside = #(at - vector3(room.x, room.y, room.z)) <= config.ShopWorkRadius
		end
		if inside
			and (accessOf(shopId, characterId).canWork == true or IsPlayerAceAllowed(playerId, 'coe_tablet.all')) then
			return shopId
		end
	end
	return nil
end

local function pushOrder(order)
	local customer = order and ordersService.Customer(order.id)
	if customer then
		TriggerClientEvent('coe_mechanic:orderUpdated', customer.source, order)
	end
end

local function notifyShopMechanics(shopId, message)
	for _, id in ipairs(GetPlayers()) do
		local playerId = tonumber(id)
		if shopOfMechanic(playerId) == shopId then
			pcall(function()
				exports.coe_notify:Notify(playerId, 'info', message)
			end)
		end
	end
end

local function orderResult(order, errorCode)
	if not order then
		return { ok = false, error = errorCode or 'unknown_error' }
	end
	pushOrder(order)
	return { ok = true, order = order }
end

local function orderAction(playerId, action, payload)
	local shopId = shopOfMechanic(playerId)
	if not shopId then
		return { ok = false, error = 'not_in_shop' }
	end
	if action == 'orders' then
		return { ok = true, shop = shopId, orders = ordersService.ListForShop(shopId) }
	end
	local orderId = tonumber(payload.id)
	if not orderId then
		return { ok = false, error = 'order_not_found' }
	end
	if action == 'price' then
		local order, errorCode = ordersService.Price(orderId, shopId, tonumber(payload.total), payload.note)
		local result = orderResult(order, errorCode)
		if order then
			reply(ordersService.Customer(orderId).source, 'info', _t('quote_received'))
		end
		return result
	end
	if action == 'complete' then
		local vehicleId = ordersService.Vehicle(orderId)
		local distance = vehicleId and tabletDistance(playerId, vehicleId)
		if not distance or distance > config.TabletRadius then
			return { ok = false, error = 'vehicle_too_far' }
		end
		local order, errorCode = ordersService.Complete(orderId, shopId)
		return orderResult(order, errorCode)
	end
	return { ok = false, error = 'unknown_action' }
end

-- Ações do tablet de oficina (scan, replace, orders, price, complete). Só o coe_tablet chama, depois de validar o emprego.
exports('TabletCall', function(playerId, appId, action, payload)
	if config.TabletResources[callerName()] ~= true then
		log('warn', 'security', 'mechanic_tablet_forbidden', { operation = callerName() })
		return { ok = false, error = 'forbidden' }
	end
	if not ready then
		return { ok = false, error = 'not_ready' }
	end
	if action == 'orders' or action == 'price' or action == 'complete' then
		return orderAction(playerId, action, payload)
	end
	return MechanicTablet.Handle({
		byPlate = function(plate)
			return exports.coe_vehicles:GetByPlate(plate)
		end,
		inspect = function(vehicleId)
			return exports.coe_mechanic:Inspect(vehicleId)
		end,
		mileage = function(vehicleId)
			return exports.coe_vehicles:GetMileage(vehicleId)
		end,
		distance = tabletDistance,
		replacePart = function(vehicleId, part)
			return exports.coe_mechanic:ReplacePart(vehicleId, part)
		end,
		serviceAll = function(vehicleId)
			return exports.coe_mechanic:ServiceVehicle(vehicleId)
		end,
		radius = config.TabletRadius
	}, playerId, action, payload)
end)

local function allowed(playerId, command)
	return playerId == 0 or IsPlayerAceAllowed(playerId, 'command.' .. command)
end

local function findRecord(playerId, plate)
	if not plate then
		reply(playerId, 'error', _t('plate_required'))
		return nil
	end
	local record = exports.coe_vehicles:GetByPlate(plate)
	if not record then
		reply(playerId, 'error', _t('vehicle_not_found'))
	end
	return record
end

-- Ferramentas de teste/administração (ACE: command.coe_parts, coe_part_replace, coe_mechanic_mileage).
RegisterCommand('coe_parts', function(playerId, args)
	if not allowed(playerId, 'coe_parts') or not ready then
		return
	end
	local record = findRecord(playerId, args[1])
	if not record then
		return
	end
	local inspection = service.Inspect(record.id, record.mileage)
	if not inspection then
		reply(playerId, 'error', _t('inspection_failed'))
		return
	end
	for _, detail in ipairs(inspection.parts) do
		print(('[coe_mechanic] %s: %d%% (%s)'):format(detail.part, math.floor(detail.wear * 100), detail.condition))
	end
	reply(playerId, 'info', _t('inspection_printed', { plate = record.plate }))
end, true)

RegisterCommand('coe_part_replace', function(playerId, args)
	if not allowed(playerId, 'coe_part_replace') or not ready then
		return
	end
	local record = findRecord(playerId, args[1])
	if not record then
		return
	end
	local result
	if args[2] == 'all' then
		result = exports.coe_mechanic:ServiceVehicle(record.id)
	else
		result = exports.coe_mechanic:ReplacePart(record.id, args[2])
	end
	reply(playerId, result == true and 'success' or 'error',
		result == true and _t('service_completed') or _t('action_failed', { error = tostring(result) }))
end, true)

RegisterCommand('coe_mechanic_mileage', function(playerId, args)
	if not allowed(playerId, 'coe_mechanic_mileage') or not ready then
		return
	end
	local record = findRecord(playerId, args[1])
	local kilometers = tonumber(args[2])
	if not record or not kilometers or kilometers < 0 then
		return
	end
	local result = exports.coe_mechanic:AdjustMileage(record.id, math.floor(kilometers * 1000))
	reply(playerId, result == true and 'success' or 'error',
		result == true and _t('mileage_adjusted', { plate = record.plate }) or _t('action_failed', { error = tostring(result) }))
	if result == true then
		audit('vehicle_mileage_adjusted', { plate = record.plate, mileage = math.floor(kilometers * 1000), player_id = playerId })
	end
end, true)

-- Ferramentas de teste/administração: coe_paint <placa> <primaria> [secundaria], coe_livery <placa> <indice>,
-- coe_tune <placa> <tipoMod> <indice>, coe_appearance_quote <placa> <tipoMod> <indice>.
local function patchCommand(name, build)
	RegisterCommand(name, function(playerId, args)
		if not allowed(playerId, name) or not ready then
			return
		end
		local record = findRecord(playerId, args[1])
		if not record then
			return
		end
		local patch = build(args)
		if not patch then
			reply(playerId, 'error', _t('invalid_args'))
			return
		end
		local result = exports.coe_mechanic:SetAppearance(record.id, patch)
		reply(playerId, result == true and 'success' or 'error',
			result == true and _t('appearance_updated') or _t('action_failed', { error = tostring(result) }))
	end, true)
end

patchCommand('coe_paint', function(args)
	local primary, secondary = tonumber(args[2]), tonumber(args[3])
	if not primary then
		return nil
	end
	return { colors = { primary = primary, secondary = secondary or primary } }
end)

patchCommand('coe_livery', function(args)
	local index = tonumber(args[2])
	return index and { livery = index } or nil
end)

patchCommand('coe_tune', function(args)
	local modType, index = tonumber(args[2]), tonumber(args[3])
	if not modType or not index then
		return nil
	end
	return { mods = { [tostring(modType)] = index } }
end)

RegisterCommand('coe_appearance_quote', function(playerId, args)
	if not allowed(playerId, 'coe_appearance_quote') or not ready then
		return
	end
	local record = findRecord(playerId, args[1])
	local modType, index = tonumber(args[2]), tonumber(args[3])
	if not record or not modType or not index then
		return
	end
	local quote = exports.coe_mechanic:QuoteAppearance(record.id, { mods = { [tostring(modType)] = index } })
	if type(quote) == 'table' then
		reply(playerId, 'info', _t('quote_total', { total = quote.total }))
	else
		reply(playerId, 'error', _t('action_failed', { error = tostring(quote) }))
	end
end, true)

-- Cliente: monta a lista no showroom, pede o orçamento e aprova ou recusa.
local function customerOf(playerId)
	local characterId = Core.Players.GetActiveCharacterId(playerId)
	return characterId and { source = playerId, characterId = characterId } or nil
end

local function inShowroom(playerId, shop, vehicleId)
	local room = shop.showroom
	local center = vector3(room.x, room.y, room.z)
	local ped = GetPlayerPed(playerId)
	local entity = vehicleEntity(vehicleId)
	if not ped or ped == 0 or not entity or not DoesEntityExist(entity) then
		return false
	end
	return #(GetEntityCoords(ped) - center) <= room.radius and #(GetEntityCoords(entity) - center) <= room.radius
end

local function validateRequest(playerId, shopId, plate, patch)
	if not ready then
		return nil, 'not_ready'
	end
	local shop = type(shopId) == 'string' and config.Shops[shopId]
	if not shop or type(plate) ~= 'string' or #plate > 8 or type(patch) ~= 'table'
		or #json.encode(patch) > config.Orders.MaxPatchBytes then
		return nil, 'invalid_request'
	end
	local customer = customerOf(playerId)
	local record = exports.coe_vehicles:GetByPlate(plate)
	if not customer or type(record) ~= 'table' then
		return nil, 'vehicle_not_found'
	end
	if not exports.coe_vehicles:HasKey(customer.characterId, record.id) then
		return nil, 'no_key'
	end
	if not inShowroom(playerId, shop, record.id) then
		return nil, 'not_in_showroom'
	end
	return { customer = customer, record = record }
end

RegisterNetEvent('coe_mechanic:requestEstimate', function(shopId, plate, patch)
	local playerId = source
	local context, errorCode = validateRequest(playerId, shopId, plate, patch)
	if not context then
		TriggerClientEvent('coe_mechanic:orderFailed', playerId, errorCode)
		return
	end
	local price, class = vehiclePricing(context.record)
	local quote, quoteError = appearanceService.Quote(context.record.id, patch, price, class)
	if not quote then
		TriggerClientEvent('coe_mechanic:orderFailed', playerId, quoteError or 'invalid_appearance')
		return
	end
	TriggerClientEvent('coe_mechanic:estimate', playerId, quote)
end)

RegisterNetEvent('coe_mechanic:requestOrder', function(shopId, plate, patch)
	local playerId = source
	local context, errorCode = validateRequest(playerId, shopId, plate, patch)
	if not context then
		TriggerClientEvent('coe_mechanic:orderFailed', playerId, errorCode)
		return
	end
	local order, createError = ordersService.Create(shopId, context.customer, context.record, patch)
	if not order then
		TriggerClientEvent('coe_mechanic:orderFailed', playerId, createError)
		return
	end
	pushOrder(order)
	notifyShopMechanics(shopId, _t('quote_requested', { plate = context.record.plate }))
end)

RegisterNetEvent('coe_mechanic:respondOrder', function(orderId, approve)
	local playerId = source
	if type(orderId) ~= 'number' or type(approve) ~= 'boolean' or not ready then
		return
	end
	local order, errorCode = ordersService.Respond(orderId, playerId, approve)
	if not order then
		TriggerClientEvent('coe_mechanic:orderFailed', playerId, errorCode)
		return
	end
	pushOrder(order)
	if approve then
		for _, id in ipairs(GetPlayers()) do
			local mechanic = tonumber(id)
			if shopOfMechanic(mechanic) == order.shop then
				reply(mechanic, 'success', _t('quote_approved', { plate = order.plate }))
			end
		end
	end
end)

RegisterNetEvent('coe_mechanic:cancelOrder', function(orderId)
	local playerId = source
	if type(orderId) == 'number' and ready then
		pushOrder(ordersService.Cancel(orderId, playerId))
	end
end)

RegisterNetEvent('coe_mechanic:syncOrder', function()
	local playerId = source
	if ready then
		TriggerClientEvent('coe_mechanic:orderUpdated', playerId, ordersService.GetForCustomer(playerId))
	end
end)

local COOLDOWN_MS = 400
local lastAction = {}

-- Evita rajadas de eventos de um mesmo jogador nas ações da oficina.
local function throttled(playerId)
	local now = GetGameTimer()
	if lastAction[playerId] and now - lastAction[playerId] < COOLDOWN_MS then
		return true
	end
	lastAction[playerId] = now
	return false
end

local function nearPoint(playerId, point, tolerance)
	local ped = GetPlayerPed(playerId)
	if not ped or ped == 0 then
		return false
	end
	return #(GetEntityCoords(ped) - vector3(point.x, point.y, point.z)) <= point.radius + (tolerance or 0.0)
end

-- Valida jogador pronto, oficina existente, estação configurada, equipe e distância.
local function stationAccess(playerId, shopId, kind, stationId)
	if not ready or type(shopId) ~= 'string' or type(stationId) ~= 'string' then
		return nil, 'not_ready'
	end
	local shop = config.Shops[shopId]
	local station = MechanicShops.Station(shop, kind, stationId)
	if not station then
		return nil, 'no_station'
	end
	if shopOfMechanic(playerId) ~= shopId then
		return nil, 'not_staff'
	end
	if not nearPoint(playerId, station.point, 1.0) then
		return nil, 'too_far'
	end
	return station
end

local STATION_MESSAGES = {
	not_staff = 'err_not_staff', too_far = 'err_too_far', missing_items = 'err_missing_items',
	craft_busy = 'err_craft_busy', inventory_full = 'err_inventory_full',
	craft_interrupted = 'err_craft_interrupted', container_limit = 'err_container_limit',
	inventory_unavailable = 'err_inventory_unavailable', not_ready = 'err_not_ready',
	no_station = 'err_no_station'
}

local function stationFailed(playerId, errorCode)
	TriggerClientEvent('coe_mechanic:stationFailed', playerId, errorCode)
	local msgKey = STATION_MESSAGES[errorCode]
	if msgKey then
		pcall(function()
			exports.coe_notify:Notify(playerId, 'error', _t(msgKey))
		end)
	end
end

local lastCheck = {}

-- O cliente pergunta se é da equipe para só mostrar o aviso a quem pode usar; a validação real é em cada ação.
RegisterNetEvent('coe_mechanic:checkAccess', function(shopId)
	local playerId = source
	local now = GetGameTimer()
	if not ready or type(shopId) ~= 'string' or not config.Shops[shopId] or (lastCheck[playerId] and now - lastCheck[playerId] < 1000) then
		return
	end
	lastCheck[playerId] = now
	local characterId = Core.Players.GetActiveCharacterId(playerId)
	local access = accessOf(shopId, characterId)
	TriggerClientEvent('coe_mechanic:access', playerId, shopId, shopOfMechanic(playerId) == shopId,
		access.canClock == true, exports.coe_businesses:IsOnDuty(shopId, characterId) == true)
end)

-- O ponto é de todos os negócios e vive no coe_businesses; aqui só repassamos o que o jogador acionou no prompt da oficina.
AddEventHandler('coe_businesses:dutyChanged', function(playerId)
	TriggerClientEvent('coe_mechanic:accessReset', playerId)
end)

RegisterNetEvent('coe_mechanic:clock', function(shopId, stationId)
	local playerId = source
	if throttled(playerId) or type(shopId) ~= 'string' or type(stationId) ~= 'string' then
		return
	end
	pcall(function()
		exports.coe_businesses:Clock(playerId, shopId, stationId)
	end)
end)

-- A bancada e as receitas vivem no coe_crafting; registramos de novo se ele reiniciar.
local function registerCraft()
	if GetResourceState('coe_crafting') ~= 'started' then
		return
	end
	pcall(function()
		exports.coe_crafting:RegisterBench('mechanic', {
			label = 'Bancada', categories = { 'mechanic' }, source = 'player', output = 'player',
			animation = { dict = 'mini@repair', name = 'fixing_a_ped' }
		})
		for _, recipe in ipairs(config.Recipes.mechanic) do
			exports.coe_crafting:RegisterRecipe(recipe)
		end
	end)
end

AddEventHandler('coe_crafting:ready', registerCraft)
CreateThread(registerCraft)
RegisterNetEvent('coe_mechanic:openCraft', function(shopId, stationId)
	local playerId = source
	if throttled(playerId) then
		return
	end
	local station, errorCode = stationAccess(playerId, shopId, 'crafts', stationId)
	if not station then
		stationFailed(playerId, errorCode)
		return
	end
	local point = station.point
	local result = exports.coe_crafting:Open(playerId, 'mechanic', {
		label = _t('bench_label', { shop = config.Shops[shopId].label }),
		position = { x = point.x, y = point.y, z = point.z, radius = point.radius },
		access = function(pid)
			return stationAccess(pid, shopId, 'crafts', stationId) ~= nil
		end
	})
	if type(result) == 'table' and result.error then
		stationFailed(playerId, result.error)
	end
end)
RegisterNetEvent('coe_mechanic:openStash', function(shopId, stationId)
	local playerId = source
	if throttled(playerId) then
		return
	end
	local station, errorCode = stationAccess(playerId, shopId, 'stashes', stationId)
	if not station then
		stationFailed(playerId, errorCode)
		return
	end
	-- O baú "main" mantém o id antigo para não perder o conteúdo já guardado.
	local inventoryId = stationId == 'main' and ('stash:mechanic:' .. shopId) or ('stash:mechanic:%s:%s'):format(shopId, stationId)
	local ok, opened, openError = pcall(function()
		return exports.coe_inventory:OpenStash(playerId, inventoryId, {
			label = _t('stash_label', { station = station.label, shop = config.Shops[shopId].label }),
			slots = station.slots,
			maxWeight = station.maxWeight,
			position = { x = station.point.x, y = station.point.y, z = station.point.z },
			radius = station.point.radius + 1.0
		})
	end)
	if not ok or opened ~= true then
		stationFailed(playerId, ok and openError or 'inventory_unavailable')
	end
end)

AddEventHandler('playerDropped', function()
	local playerId = source
	lastAction[playerId] = nil
	lastCheck[playerId] = nil
	lastShopsRequest[playerId] = nil
	if ordersService then
		ordersService.Drop(playerId)
	end
end)

exports('GetShopOwner', function(shopId)
	return ready and business.Owner(shopId) or nil
end)

exports('GetShops', function()
	return config.Shops
end)

CreateThread(function()
	while true do
		Wait(60000)
		if ordersService then
			ordersService.Purge()
		end
	end
end)

CreateThread(function()
	local waitingLogged = false
	while true do
		local initialized, errorCode = MechanicPersistence.Initialize()
		if initialized then
			break
		end
		if errorCode == 'database_not_ready' then
			if not waitingLogged then
				log('info', 'persistence', 'database_waiting', {})
				waitingLogged = true
			end
			Wait(1000)
		else
			log('error', 'persistence', 'database_initialization_failed', {
				error_code = errorCode or 'database_error',
				retry_ms = 5000
			})
			Wait(5000)
		end
	end
	service = MechanicService.New({ config = config, persistence = MechanicPersistence, audit = audit })
	appearanceService = MechanicAppearanceService.New({ config = config, persistence = MechanicPersistence, audit = audit })
	local businessesLogged = false
	while not (GetResourceState('coe_businesses') == 'started' and exports.coe_businesses:IsReady()) do
		if not businessesLogged then
			log('info', 'system', 'businesses_waiting', { resource_state = GetResourceState('coe_businesses') })
			businessesLogged = true
		end
		Wait(1000)
	end
	syncShops()
	AddEventHandler('coe_businesses:changed', function()
		syncShops()
	end)
	business = MechanicBusiness.New({ config = config })
	ordersService = MechanicOrders.New({
		config = config,
		audit = audit,
		now = GetGameTimer,
		multiplier = function(shopId)
			local shop = config.Shops[shopId]
			return shop and shop.priceMultiplier or 1.0
		end,
		quote = function(vehicleId, patch)
			local record = exports.coe_vehicles:Get(vehicleId)
			if not record then
				return nil, 'vehicle_not_found'
			end
			local price, class = vehiclePricing(record)
			return appearanceService.Quote(vehicleId, patch, price, class)
		end,
		apply = function(vehicleId, patch)
			return exports.coe_mechanic:SetAppearance(vehicleId, patch)
		end
	})
	ready = true
	log('info', 'system', 'mechanic_ready', {})
end)
