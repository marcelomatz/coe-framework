-- coe_fuel (servidor): tanque de cada veículo (state bag `coe:fuel`), consumo reportado pelo motorista e validado
-- aqui, bombas dos postos (com pagamento), galão, tanques dos postos de jogador e efeitos da mistura no motor.
local config = FuelConfig
local catalog = assert(FuelRules.Catalog(config, function(name) return GetHashKey(name) end))

local ready = false
local vehicles = {}      -- entidade -> estado do tanque
local byVehicleId = {}   -- vehicleId -> entidade
local tanks = {}         -- negócio -> combustível -> litros (postos de jogador)
local tankLevels = {}    -- negócio -> combustível -> nível do tanque
local prices = {}        -- negócio -> combustível -> preço do dono
local fleet = {}         -- vehicleId -> { business, tier, cargo } (frota de abastecimento)
local fleetEntity = {}   -- vehicleId -> entidade na rua
local businessStation = {}
for _, station in ipairs(catalog.stations) do
	businessStation[station.business] = station
end
local lastCall = {}
local callLimiter = FuelRules.NewCallLimiter(config.CallCooldownMs or 250)
local lastReport = {}
local playerBusy = {}

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

local function notify(playerId, kind, message)
	pcall(function()
		exports.coe_notify:Notify(playerId, kind, message)
	end)
end

local _t = function(key, params)
	if Core and Core.Locale and Core.Locale.New then
		return Core.Locale.New({ default = Core.Locale.GetDefaultLang(), locales = Locales or {} })(key, params)
	end
	if Locales and Locales['pt-BR'] and Locales['pt-BR'][key] then
		return Locales['pt-BR'][key]
	end
	return key
end

local function remote(resource, name, ...)
	if GetResourceState(resource) ~= 'started' then
		return nil
	end
	local args = { ... }
	local ok, result = pcall(function()
		return exports[resource][name](exports[resource], table.unpack(args))
	end)
	if not ok then
		log('warn', 'system', 'fuel_remote_failed', { target = resource .. ':' .. name, error_code = tostring(result):sub(1, 96) })
		return nil
	end
	return result
end

local function money(value)
	local textValue = tostring(math.floor(value))
	return '$' .. textValue:reverse():gsub('(%d%d%d)', '%1.'):reverse():gsub('^%.', '')
end

local function characterOf(playerId)
	local snapshot = Core.Players.GetActiveCharacter(playerId)
	if type(snapshot) ~= 'table' or not snapshot.characterId then
		return nil
	end
	return { id = tostring(snapshot.characterId) }
end

local function coordsOf(entity)
	if not entity or entity == 0 or not Core.Platform.Entities.Exists(entity) then
		return nil
	end
	local c = Core.Platform.Entities.GetCoords(entity)
	return c and { x = c.x, y = c.y, z = c.z } or nil
end

local function distance(a, b)
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function inventoryOf(playerId)
	return remote('coe_inventory', 'GetPlayerInventory', playerId)
end

local function countOf(inventoryId, item)
	return tonumber(remote('coe_inventory', 'GetItemCount', inventoryId, item)) or 0
end

local function businessOf(businessId)
	local business = remote('coe_businesses', 'Get', businessId)
	return type(business) == 'table' and business.id and business or nil
end

-- Veículos ----------------------------------------------------------------------------------------------------

local function vehicleIdOf(entity)
	local id = Core.Platform.Entities.GetState(entity, 'coe:vehicleId')
	return id ~= nil and tostring(id) or nil
end

local function publish(state)
	if not Core.Platform.Entities.Exists(state.entity) then
		return
	end
	Core.Platform.Entities.SetState(state.entity, 'coe:fuel', FuelRules.Summary(config, catalog, state.tank, state.capacity, state.engine), true)
end

local function refreshEffects(state)
	if state.engine == 'none' then
		return
	end
	local effects = FuelRules.Effects(config, catalog, state.tank)
	state.effects = effects
	local key = FuelRules.EffectsKey(effects)
	if state.effectsKey ~= key then
		state.effectsKey = key
		if state.vehicleId then
			TriggerEvent('coe_fuel:effectsChanged', state.vehicleId)
		end
	end
end

local function saveVehicle(state)
	if not state.vehicleId or not state.dirty then
		return
	end
	state.dirty = false
	if not FuelPersistence.SaveVehicle(state.vehicleId, state.engine, state.capacity, state.tank) then
		state.dirty = true
		log('error', 'persistence', 'fuel_vehicle_save_failed', { vehicle_id = state.vehicleId })
	end
end

local function flushWear(state, force)
	if not state.vehicleId or state.wear == 0 then
		return
	end
	if not force and math.abs(state.wear) < config.WearFlushMeters then
		return
	end
	local meters = math.floor(state.wear)
	state.wear = state.wear - meters
	if meters ~= 0 then
		remote('coe_mechanic', 'AddWear', state.vehicleId, meters, config.WearParts)
	end
end

local function forget(entity)
	local state = vehicles[entity]
	if not state then
		return
	end
	flushWear(state, true)
	saveVehicle(state)
	vehicles[entity] = nil
	if state.vehicleId and byVehicleId[state.vehicleId] == entity then
		byVehicleId[state.vehicleId] = nil
	end
end

local function startTank(engine, capacity, level)
	local tank = FuelRules.Empty(config)
	if engine == 'none' then
		return tank
	end
	tank[engine == 'diesel' and 'diesel' or 'regular'] = math.floor(capacity * level * 100) / 100
	return tank
end

-- Estado do tanque de uma entidade; cria na primeira vez (registrado: banco; sem registro: nível aleatório).
local function stateOf(entity, classId, modelHash)
	local state = vehicles[entity]
	if state then
		return state
	end
	local vehicleId = vehicleIdOf(entity)
	if vehicleId and byVehicleId[vehicleId] and vehicles[byVehicleId[vehicleId]] then
		-- Mesma placa em outra entidade (reaparecida): reaproveita o tanque em memória.
		state = vehicles[byVehicleId[vehicleId]]
		vehicles[byVehicleId[vehicleId]] = nil
		state.entity = entity
		vehicles[entity] = state
		byVehicleId[vehicleId] = entity
		publish(state)
		return state
	end
	local spec = FuelRules.ClassSpec(config, classId)
	if vehicleId then
		local record = remote('coe_vehicles', 'Get', tonumber(vehicleId) or vehicleId)
		if type(record) == 'table' and type(record.model) == 'string' then
			modelHash = GetHashKey(record.model)
		end
		local row, loadError = FuelPersistence.LoadVehicle(vehicleId)
		if loadError then
			return nil, 'database_error'
		end
		if row then
			state = { engine = row.engine, capacity = row.capacity, tank = FuelRules.Clean(config, row.tank) }
		else
			local engine = FuelRules.Engine(config, catalog, classId, modelHash)
			state = { engine = engine, capacity = spec.tank, tank = startTank(engine, spec.tank, config.RegisteredStartLevel), dirty = true }
		end
		state.vehicleId = vehicleId
		byVehicleId[vehicleId] = entity
	else
		local engine = FuelRules.Engine(config, catalog, classId, modelHash)
		local range = config.UnregisteredLevel
		local level = range.min + math.random() * (range.max - range.min)
		state = { engine = engine, capacity = spec.tank, tank = startTank(engine, spec.tank, level) }
	end
	state.entity = entity
	state.classId = math.tointeger(tonumber(classId)) or -1
	state.wear = 0
	vehicles[entity] = state
	refreshEffects(state)
	saveVehicle(state)
	publish(state)
	return state
end

local function entityOf(netId)
	netId = math.tointeger(tonumber(netId))
	if not netId then
		return nil
	end
	local entity = Core.Platform.Entities.FromNetworkId(netId)
	if not entity or not Core.Platform.Entities.Exists(entity) then
		return nil
	end
	return entity
end

local function isDriver(playerId, entity)
	return GetPedInVehicleSeat(entity, -1) == GetPlayerPed(playerId)
end

-- O motorista pede o tanque ao entrar (classe e modelo vêm do client; o veículo registrado usa o modelo do registro).
RegisterNetEvent('coe_fuel:init', function(netId, classId, modelHash)
	local playerId = source
	if not ready then
		return
	end
	local entity = entityOf(netId)
	if not entity or not isDriver(playerId, entity) then
		return
	end
	local state = stateOf(entity, classId, math.tointeger(tonumber(modelHash)))
	if state then
		publish(state)
	end
end)

-- Consumo: o client manda distância, tempo com motor ligado e rotação média; o servidor limita e calcula os litros.
RegisterNetEvent('coe_fuel:report', function(netId, meters, seconds, load)
	local playerId = source
	if not ready then
		return
	end
	local now = GetGameTimer()
	if lastReport[playerId] and now - lastReport[playerId] < config.ReportSeconds * 500 then
		return
	end
	local elapsed = lastReport[playerId] and (now - lastReport[playerId]) / 1000 or config.ReportSeconds
	lastReport[playerId] = now
	local entity = entityOf(netId)
	if not entity or not isDriver(playerId, entity) then
		return
	end
	local state = vehicles[entity]
	if not state or state.engine == 'none' then
		return
	end
	local acceptedMeters, acceptedSeconds = FuelRules.ClampReport(config, meters, math.min(tonumber(seconds) or 0, elapsed + 1))
	local spec = FuelRules.ClassSpec(config, state.classId)
	local liters = FuelRules.Usage(config, spec, state.effects, acceptedMeters, acceptedSeconds, load)
	if liters <= 0 then
		return
	end
	local before = FuelRules.Total(state.tank)
	state.tank = FuelRules.Consume(config, state.tank, liters)
	state.dirty = state.vehicleId ~= nil
	if state.vehicleId and state.effects then
		state.wear = state.wear + FuelRules.WearMeters(state.effects, acceptedMeters)
		flushWear(state, false)
	end
	if before > 0 and FuelRules.Total(state.tank) <= 0 then
		notify(playerId, 'error', _t('fuel_empty'))
	end
	publish(state)
end)

AddEventHandler('entityRemoved', function(entity)
	if vehicles[entity] then
		forget(entity)
	end
end)

AddEventHandler('coe_vehicles:released', function(vehicleId)
	local entity = byVehicleId[tostring(vehicleId)]
	if entity then
		forget(entity)
	end
end)

-- Pagamento (mesmo fluxo das lojas) ------------------------------------------------------------------------

local function charge(playerId, payment, total, description)
	local method = type(payment) == 'table' and payment.method
	if not config.Payments[method or ''] then
		return nil, 'invalid_method'
	end
	if method == 'cash' then
		local inventoryId = inventoryOf(playerId)
		if not inventoryId or countOf(inventoryId, 'money') < total then
			return nil, 'insufficient_cash'
		end
		if remote('coe_inventory', 'RemoveItemByName', inventoryId, 'money', total) ~= true then
			return nil, 'payment_failed'
		end
		return { method = 'cash' }
	end
	if method == 'wallet' then
		local cardId = type(payment.token) == 'string' and remote('coe_phone', 'ConsumePayment', playerId, payment.token, total) or nil
		if not cardId then
			return nil, 'payment_expired'
		end
		local result = remote('coe_banking', 'CardPurchase', cardId, total, description)
		if type(result) ~= 'table' or not result.ok then
			return nil, type(result) == 'table' and result.error or 'payment_failed'
		end
		return { method = 'wallet', cardId = cardId }
	end
	local cardId = math.tointeger(tonumber(payment.cardId))
	local result = cardId and remote('coe_banking', 'PosPurchase', playerId, cardId, payment.pin, total, description) or nil
	if type(result) ~= 'table' or not result.ok then
		return nil, type(result) == 'table' and result.error or 'payment_failed', type(result) == 'table' and result.left or nil
	end
	return { method = 'card', cardId = cardId }
end

local function refund(playerId, paid, total, description)
	if paid.method == 'cash' then
		local inventoryId = inventoryOf(playerId)
		if not inventoryId or remote('coe_inventory', 'AddItem', inventoryId, 'money', total) ~= true then
			log('error', 'economy', 'fuel_refund_failed', { player_id = playerId, count = total, operation = 'cash' })
		end
		return
	end
	local result = remote('coe_banking', 'CardRefund', paid.cardId, total, description)
	if type(result) ~= 'table' or not result.ok then
		log('error', 'economy', 'fuel_refund_failed', { player_id = playerId, count = total, operation = paid.method })
	end
end

-- Galões no inventário do jogador: { slot, fuel, liters }.
local function cansOf(inventoryId)
	local list = {}
	local inventory = inventoryId and remote('coe_inventory', 'GetInventory', inventoryId)
	if type(inventory) ~= 'table' or type(inventory.items) ~= 'table' then
		return list
	end
	for slot, item in pairs(inventory.items) do
		if type(item) == 'table' and item.name == config.Can.item then
			local meta = type(item.metadata) == 'table' and item.metadata or {}
			list[#list + 1] = { slot = math.tointeger(tonumber(item.slot or slot)) or slot, fuel = catalog.fuels[meta.fuel or ''] and meta.fuel or nil, liters = tonumber(meta.liters) or 0 }
		end
	end
	table.sort(list, function(a, b) return a.slot < b.slot end)
	return list
end

-- Bombas ------------------------------------------------------------------------------------------------------

local function stationFor(playerId, payload)
	local station = type(payload) == 'table' and type(payload.stationId) == 'string' and catalog.byId[payload.stationId]
	if not station then
		return nil, 'unknown_station'
	end
	local coords = coordsOf(GetPlayerPed(playerId))
	if not coords or distance(coords, station) > station.radius + 2.0 then
		return nil, 'too_far'
	end
	return station, nil, coords
end

-- Veículo junto do jogador para a bomba (o client indica qual, o servidor confere a distância).
local function vehicleFor(payload, coords)
	local entity = entityOf(type(payload) == 'table' and payload.netId)
	if not entity then
		return nil
	end
	local position = coordsOf(entity)
	if not position or distance(position, coords) > config.VehicleRadius then
		return nil
	end
	return entity
end

local function stockOf(station, mode, fuelId)
	if mode == 'staff' then
		return nil
	end
	return (tanks[station.business] or {})[fuelId] or 0
end

-- Preço por litro: posto de jogador usa o do dono (se definido); o da staff, o de tabela.
local function priceOf(station, mode, fuelId)
	local own = mode == 'player' and (prices[station.business] or {})[fuelId]
	return own or catalog.fuels[fuelId].price
end

local function levelOf(businessId, fuelId)
	return FuelRules.TankLevel(config, (tankLevels[businessId] or {})[fuelId])
end

local function saveTank(businessId, fuelId)
	local liters = (tanks[businessId] or {})[fuelId] or 0
	if not FuelPersistence.SaveTank(businessId, fuelId, liters, levelOf(businessId, fuelId)) then
		log('error', 'persistence', 'fuel_tank_save_failed', { target = businessId .. ':' .. fuelId })
		return false
	end
	return true
end

local function pumpView(playerId, station, coords, payload)
	local business = businessOf(station.business)
	local mode = FuelRules.Mode(business)
	if business and business.enabled == false then
		return nil, 'station_closed'
	end
	local fuels = {}
	for _, id in ipairs(config.FuelOrder) do
		local fuel = catalog.fuels[id]
		fuels[#fuels + 1] = { id = id, label = fuel.label, short = fuel.short, price = priceOf(station, mode, id), color = fuel.color, engine = fuel.engine, stock = stockOf(station, mode, id) }
	end
	local view = {
		station = { id = station.id, label = station.label, brand = station.brand, brandLabel = config.Brands[station.brand].label, theme = config.Brands[station.brand].theme },
		mode = mode, owner = business and business.owner and business.owner.name or nil, fuels = fuels,
		payments = config.Payments, can = { capacity = config.Can.capacity, price = config.Can.price },
		maxLiters = config.MaxLitersPerSale
	}
	local entity = vehicleFor(payload, coords)
	if entity then
		local state = stateOf(entity, payload.classId, math.tointeger(tonumber(payload.modelHash)))
		if state then
			local total = FuelRules.Total(state.tank)
			view.vehicle = { netId = payload.netId, engine = state.engine, capacity = state.capacity, liters = total, space = math.max(0, state.capacity - total) }
		end
	end
	local inventoryId = inventoryOf(playerId)
	view.cash = inventoryId and countOf(inventoryId, 'money') or 0
	view.cans = cansOf(inventoryId)
	view.cards = {}
	if config.Payments.card then
		local result = remote('coe_banking', 'PosCards', playerId)
		view.cards = type(result) == 'table' and result.ok and result.cards or {}
	end
	return view
end

-- Monta a venda: destino (veículo ou galão), litros possíveis e total. Não cobra nada.
local function prepare(playerId, station, coords, payload)
	local business = businessOf(station.business)
	if business and business.enabled == false then
		return nil, 'station_closed'
	end
	local mode = FuelRules.Mode(business)
	local fuelId = type(payload.fuel) == 'string' and catalog.fuels[payload.fuel] and payload.fuel or nil
	if not fuelId then
		return nil, 'unknown_fuel'
	end
	local liters = FuelRules.CleanLiters(payload.liters, config.MaxLitersPerSale)
	if not liters then
		return nil, 'invalid_liters'
	end
	local sale = { station = station, mode = mode, fuel = fuelId, target = payload.target == 'can' and 'can' or 'vehicle', extra = 0 }
	if sale.target == 'vehicle' then
		local entity = vehicleFor(payload, coords)
		if not entity then
			return nil, 'no_vehicle'
		end
		local state = stateOf(entity, payload.classId, math.tointeger(tonumber(payload.modelHash)))
		if not state then
			return nil, 'database_error'
		end
		if state.engine == 'none' then
			return nil, 'no_tank'
		end
		if not FuelRules.Compatible(catalog, state.engine, fuelId) then
			return nil, 'wrong_fuel'
		end
		local space = math.floor((state.capacity - FuelRules.Total(state.tank)) * 10) / 10
		if space < 0.5 then
			return nil, 'tank_full'
		end
		liters = math.min(liters, space)
		sale.state = state
	else
		local inventoryId = inventoryOf(playerId)
		if not inventoryId then
			return nil, 'no_inventory'
		end
		local slot = math.tointeger(tonumber(payload.slot))
		local can
		if slot then
			for _, entry in ipairs(cansOf(inventoryId)) do
				if entry.slot == slot then
					can = entry
				end
			end
			if not can then
				return nil, 'no_can'
			end
			if can.liters > 0 and can.fuel ~= fuelId then
				return nil, 'can_other_fuel'
			end
			local space = math.floor((config.Can.capacity - can.liters) * 10) / 10
			if space < 0.5 then
				return nil, 'can_full'
			end
			liters = math.min(liters, space)
		else
			liters = math.min(liters, config.Can.capacity)
			sale.extra = config.Can.price
		end
		sale.inventoryId, sale.can = inventoryId, can
	end
	local stock = stockOf(station, mode, fuelId)
	if stock and stock < liters then
		return nil, 'out_of_stock'
	end
	sale.liters = liters
	sale.price = priceOf(station, mode, fuelId)
	sale.total = FuelRules.Price(sale.price, liters) + sale.extra
	sale.description = ('Posto %s (%.1f L %s)'):format(station.label, liters, catalog.fuels[fuelId].short):sub(1, 64)
	return sale
end

local function deliver(sale)
	if sale.target == 'vehicle' then
		local state = sale.state
		if not Core.Platform.Entities.Exists(state.entity) then
			return false
		end
		state.tank = FuelRules.Add(config, state.tank, sale.fuel, sale.liters, state.capacity)
		state.dirty = state.vehicleId ~= nil
		refreshEffects(state)
		saveVehicle(state)
		publish(state)
		return true
	end
	if sale.can then
		return remote('coe_inventory', 'SetItemMetadata', sale.inventoryId, sale.can.slot, { fuel = sale.fuel, liters = math.floor((sale.can.liters + sale.liters) * 10 + 0.5) / 10 }) == true
	end
	return remote('coe_inventory', 'AddItem', sale.inventoryId, config.Can.item, 1, { fuel = sale.fuel, liters = sale.liters }) == true
end

local function buy(playerId, character, station, coords, payload)
	local sale, prepareError = prepare(playerId, station, coords, payload)
	if not sale then
		return { ok = false, error = prepareError }
	end
	local paid, payError, left
	local sagaOk, _, sagaErr = FuelRules.ExecuteSaga({
		{
			name = 'charge',
			action = function()
				paid, payError, left = charge(playerId, payload.payment, sale.total, sale.description)
				if not paid then
					return false, payError
				end
				return paid
			end,
			compensate = function(_, paidState)
				if paidState then
					refund(playerId, paidState, sale.total, sale.description)
				end
			end
		},
		{
			name = 'deliver',
			action = function()
				if not deliver(sale) then
					return false, sale.target == 'can' and 'inventory_full' or 'no_vehicle'
				end
				return true
			end
		}
	}, {})
	if not sagaOk then
		return { ok = false, error = sagaErr or payError, left = left }
	end
	if sale.mode == 'player' then
		local own = tanks[station.business] or {}
		own[sale.fuel] = math.max(0, math.floor(((own[sale.fuel] or 0) - sale.liters) * 100 + 0.5) / 100)
		tanks[station.business] = own
		saveTank(station.business, sale.fuel)
	end
	local collected = remote('coe_economy', 'SocietyCollect', station.business, sale.total, 'fuel_sale')
	if type(collected) == 'table' and collected.error then
		log('error', 'economy', 'fuel_collect_failed', { target = station.business, count = sale.total, error_code = tostring(collected.error) })
	end
	FuelPersistence.RecordSale({
		businessId = station.business, stationId = station.id, characterId = character.id, fuel = sale.fuel, liters = sale.liters,
		total = sale.total, method = paid.method, target = sale.target, mode = sale.mode, at = os.time()
	})
	audit('fuel_sale', { character_id = character.id, target = station.business, item = sale.fuel, count = sale.total, operation = paid.method })
	notify(playerId, 'success', _t('refuel_success', {
		station = station.label,
		liters = string.format('%.1f', sale.liters),
		fuel = catalog.fuels[sale.fuel].short,
		total = money(sale.total)
	}))
	return { ok = true, total = sale.total, liters = sale.liters, target = sale.target, seconds = sale.liters / config.PumpRate, price = sale.price, fuel = sale.fuel }
end

-- Galão no veículo (fora do posto também). slot = galão no inventário.
local function pour(playerId, payload)
	local inventoryId = inventoryOf(playerId)
	if not inventoryId then
		return { ok = false, error = 'no_inventory' }
	end
	local slot = math.tointeger(tonumber(payload.slot))
	local can
	for _, entry in ipairs(cansOf(inventoryId)) do
		-- Sem slot (uso pelo inventário sem o slot): o primeiro galão com combustível.
		if (slot and entry.slot == slot) or (not slot and not can and entry.liters > 0) then
			can = entry
		end
	end
	if not can then
		return { ok = false, error = 'no_can' }
	end
	if can.liters <= 0 or not can.fuel then
		return { ok = false, error = 'can_empty' }
	end
	local coords = coordsOf(GetPlayerPed(playerId))
	local entity = coords and vehicleFor(payload, coords)
	if not entity then
		return { ok = false, error = 'no_vehicle' }
	end
	local state = stateOf(entity, payload.classId, math.tointeger(tonumber(payload.modelHash)))
	if not state or state.engine == 'none' then
		return { ok = false, error = 'no_tank' }
	end
	if not FuelRules.Compatible(catalog, state.engine, can.fuel) then
		return { ok = false, error = 'wrong_fuel' }
	end
	local space = math.floor((state.capacity - FuelRules.Total(state.tank)) * 10) / 10
	local amount = math.min(can.liters, space)
	if amount < 0.1 then
		return { ok = false, error = 'tank_full' }
	end
	local before = state.tank
	local added
	state.tank, added = FuelRules.Add(config, state.tank, can.fuel, amount, state.capacity)
	local rest = math.floor((can.liters - added) * 10 + 0.5) / 10
	if remote('coe_inventory', 'SetItemMetadata', inventoryId, can.slot, { fuel = rest > 0 and can.fuel or 'empty', liters = rest }) ~= true then
		state.tank = before
		return { ok = false, error = 'inventory_error' }
	end
	state.dirty = state.vehicleId ~= nil
	refreshEffects(state)
	saveVehicle(state)
	publish(state)
	return { ok = true, liters = added, seconds = added / config.Can.pourRate, fuel = can.fuel }
end

-- Abastecimento dos postos de jogador: frota, refinaria e descarga ---------------------------------------------

local refinery = {
	x = config.Refinery.center[1], y = config.Refinery.center[2], z = config.Refinery.center[3], radius = config.Refinery.radius
}

-- Caixa do posto (coe_economy). nil se indisponível.
local function balanceOf(businessId)
	local value = remote('coe_economy', 'SocietyBalance', businessId)
	return type(value) == 'number' and value or nil
end

-- Débito no caixa do posto. true ou nil + erro.
local function chargeBusiness(businessId, amount, reason, reference)
	local result = remote('coe_economy', 'SocietyCharge', businessId, amount, reason, reference)
	if result == true then
		return true
	end
	return nil, type(result) == 'table' and result.error or 'economy_unavailable'
end

local function cargoView(entry)
	local tier = FuelRules.FleetTier(config, entry.tier) or config.FleetTiers[1]
	local cargo = FuelRules.Clean(config, entry.cargo)
	return { business = entry.business, tier = entry.tier, label = tier.label, capacity = tier.capacity, cargo = cargo, liters = FuelRules.Total(cargo) }
end

local function publishCargo(vehicleId)
	local entry, entity = fleet[vehicleId], fleetEntity[vehicleId]
	if entry and entity and Core.Platform.Entities.Exists(entity) then
		Core.Platform.Entities.SetState(entity, 'coe:fuelCargo', cargoView(entry), true)
	end
end

local function saveFleet(vehicleId)
	if not FuelPersistence.SaveFleet(vehicleId, fleet[vehicleId]) then
		log('error', 'persistence', 'fuel_fleet_save_failed', { vehicle_id = vehicleId })
		return false
	end
	return true
end

AddEventHandler('coe_vehicles:spawned', function(vehicleId, entity)
	vehicleId = tostring(vehicleId)
	if fleet[vehicleId] then
		fleetEntity[vehicleId] = entity
		publishCargo(vehicleId)
	end
end)

-- Nível de frota do posto = maior nível dos veículos que ele tem.
local function fleetTierOf(businessId)
	local tier, list = 0, {}
	for vehicleId, entry in pairs(fleet) do
		if entry.business == businessId then
			tier = math.max(tier, entry.tier)
			list[#list + 1] = { vehicleId = vehicleId, tier = entry.tier, view = cargoView(entry) }
		end
	end
	table.sort(list, function(a, b) return a.tier < b.tier end)
	return tier, list
end

-- Quem trabalha no posto: dono, ou equipe de ponto com a permissão (fuel.supply para carregar, fuel.manage para gerir).
local function stationAccess(characterId, businessId)
	local access = remote('coe_businesses', 'Access', businessId, characterId)
	local owner = type(access) == 'table' and access.owner == true
	local work = type(access) == 'table' and access.canWork == true
	local function can(permission)
		return owner or (work and remote('coe_businesses', 'Can', businessId, characterId, permission) == true)
	end
	return { owner = owner, work = work or owner, supply = can('fuel.supply'), manage = can('fuel.manage') }
end

-- Veículo da frota junto do jogador (o client indica qual).
local function fleetVehicleFor(payload, coords)
	local entity = vehicleFor(payload, coords)
	if not entity then
		return nil, 'no_vehicle'
	end
	local vehicleId = vehicleIdOf(entity)
	local entry = vehicleId and fleet[vehicleId]
	if not entry then
		return nil, 'not_fleet'
	end
	fleetEntity[vehicleId] = entity
	return entity, nil, vehicleId, entry
end

local function nearRefinery(coords)
	local dx, dy = coords.x - refinery.x, coords.y - refinery.y
	return math.sqrt(dx * dx + dy * dy) <= refinery.radius and math.abs(coords.z - refinery.z) < 25
end

local function refineryView(vehicleId, entry)
	local business = businessOf(entry.business)
	local station = businessStation[entry.business]
	local fuels = {}
	for _, id in ipairs(config.FuelOrder) do
		local fuel = catalog.fuels[id]
		local tank = (tanks[entry.business] or {})[id] or 0
		fuels[#fuels + 1] = {
			id = id, label = fuel.label, short = fuel.short, color = fuel.color, wholesale = config.Refinery.prices[id],
			tank = tank, tankCapacity = FuelRules.TankCapacity(config, levelOf(entry.business, id))
		}
	end
	return {
		refinery = config.Refinery.label, vehicle = cargoView(entry), vehicleId = vehicleId, fuels = fuels,
		business = { id = entry.business, label = business and business.label or entry.business, balance = balanceOf(entry.business) },
		station = station and { id = station.id, label = station.label, brand = station.brand, theme = config.Brands[station.brand].theme } or nil
	}
end

local function supplyCheck(playerId, character, payload, where)
	local coords = coordsOf(GetPlayerPed(playerId))
	if not coords then
		return nil, 'too_far'
	end
	local entity, vehicleError, vehicleId, entry = fleetVehicleFor(payload, { x = coords.x, y = coords.y, z = coords.z })
	if not entity then
		return nil, vehicleError
	end
	local position = coordsOf(entity)
	if distance(position, coords) > config.CargoReach then
		return nil, 'no_vehicle'
	end
	if where == 'refinery' and (not nearRefinery(coords) or not nearRefinery(position)) then
		return nil, 'not_at_refinery'
	end
	local access = stationAccess(character.id, entry.business)
	if not access.supply then
		return nil, 'forbidden'
	end
	return { coords = coords, entity = entity, vehicleId = vehicleId, entry = entry, position = position }
end

local function refineryOpen(playerId, character, payload)
	local check, checkError = supplyCheck(playerId, character, payload, 'refinery')
	if not check then
		return { ok = false, error = checkError }
	end
	return { ok = true, view = refineryView(check.vehicleId, check.entry) }
end

local function refineryLoad(playerId, character, payload)
	local check, checkError = supplyCheck(playerId, character, payload, 'refinery')
	if not check then
		return { ok = false, error = checkError }
	end
	local entry = check.entry
	local tier = FuelRules.FleetTier(config, entry.tier)
	local order, orderError = FuelRules.LoadOrder(config, entry.cargo, tier.capacity, payload.load)
	if not order then
		return { ok = false, error = orderError }
	end
	local charged, chargeError = chargeBusiness(entry.business, order.cost, 'fuel_refinery', 'veiculo ' .. check.vehicleId)
	if not charged then
		return { ok = false, error = chargeError }
	end
	local cargo = FuelRules.Clean(config, entry.cargo)
	for id, liters in pairs(order.add) do
		cargo[id] = cargo[id] + liters
	end
	entry.cargo = cargo
	saveFleet(check.vehicleId)
	publishCargo(check.vehicleId)
	audit('fuel_refinery_load', { character_id = character.id, target = entry.business, vehicle_id = check.vehicleId, count = order.liters, result = tostring(order.cost) })
	return { ok = true, liters = order.liters, cost = order.cost, seconds = order.liters / config.LoadRate, cargo = cargoView(entry) }
end

local function unload(playerId, character, payload)
	local check, checkError = supplyCheck(playerId, character, payload, 'station')
	if not check then
		return { ok = false, error = checkError }
	end
	local entry = check.entry
	local station = businessStation[entry.business]
	local here = FuelRules.StationAt(catalog, check.position.x, check.position.y, check.position.z)
	if not station or not here or here.business ~= entry.business then
		return { ok = false, error = 'not_at_station' }
	end
	if FuelRules.Total(entry.cargo) <= 0 then
		return { ok = false, error = 'empty_cargo' }
	end
	local capacities = {}
	for _, id in ipairs(config.FuelOrder) do
		capacities[id] = FuelRules.TankCapacity(config, levelOf(entry.business, id))
	end
	local newCargo, newTanks, moved, total = FuelRules.Unload(config, entry.cargo, tanks[entry.business] or {}, capacities)
	if total <= 0 then
		return { ok = false, error = 'tanks_full' }
	end
	tanks[entry.business] = newTanks
	for id in pairs(moved) do
		saveTank(entry.business, id)
	end
	entry.cargo = newCargo
	saveFleet(check.vehicleId)
	publishCargo(check.vehicleId)
	audit('fuel_unload', { character_id = character.id, target = entry.business, vehicle_id = check.vehicleId, count = total })
	return { ok = true, liters = total, moved = moved, seconds = total / config.LoadRate, cargo = cargoView(entry), left = FuelRules.Total(newCargo) }
end

-- Aba Posto do app do negócio (coe_businesses) ----------------------------------------------------------------

local function stationStats(businessId)
	local now = os.time()
	return FuelPersistence.Stats(businessId, now - (now % 86400), now - 7 * 86400) or { sold = 0, today = 0, week = 0, weekLiters = 0 }
end

local function tabletView(characterId, station)
	local business = businessOf(station.business)
	if not business then
		return { ok = false, error = 'station_closed' }
	end
	local mode = FuelRules.Mode(business)
	local isOwner = type(business.owner) == 'table' and tostring(business.owner.characterId) == tostring(characterId)
	local canManage = isOwner or remote('coe_businesses', 'Can', station.business, characterId, 'fuel.manage') == true
	local stats = stationStats(station.business)
	local balance = balanceOf(station.business)
	local view = {
		ok = true, mode = mode, canManage = canManage and mode == 'player',
		station = { id = station.id, label = station.label, brand = station.brand, brandLabel = config.Brands[station.brand].label, theme = config.Brands[station.brand].theme },
		stats = stats, balance = balance,
		refinery = { label = config.Refinery.label, x = refinery.x, y = refinery.y }
	}
	view.fuels = {}
	for _, id in ipairs(config.FuelOrder) do
		local fuel = catalog.fuels[id]
		local level = levelOf(station.business, id)
		local low, high = FuelRules.PriceBounds(config, fuel.price)
		local nextSpec = config.TankLevels[level + 1]
		view.fuels[#view.fuels + 1] = {
			id = id, label = fuel.label, color = fuel.color, base = fuel.price, price = priceOf(station, mode, id),
			custom = mode == 'player' and (prices[station.business] or {})[id] ~= nil, min = low, max = high,
			wholesale = config.Refinery.prices[id], liters = (tanks[station.business] or {})[id] or 0,
			level = level, capacity = FuelRules.TankCapacity(config, level), maxLevel = #config.TankLevels,
			next = nextSpec and { level = level + 1, capacity = nextSpec.capacity, price = nextSpec.price, sold = nextSpec.sold } or nil
		}
	end
	local tier, vehicles = fleetTierOf(station.business)
	local nextTier = config.FleetTiers[tier + 1]
	view.fleet = {
		tier = tier, tiers = {}, vehicles = {},
		next = nextTier and { tier = tier + 1, label = nextTier.label, capacity = nextTier.capacity, price = nextTier.price, sold = nextTier.sold } or nil
	}
	for index, spec in ipairs(config.FleetTiers) do
		view.fleet.tiers[#view.fleet.tiers + 1] = { tier = index, label = spec.label, capacity = spec.capacity, price = spec.price, sold = spec.sold, owned = index <= tier }
	end
	for _, item in ipairs(vehicles) do
		local record = remote('coe_vehicles', 'Get', tonumber(item.vehicleId) or item.vehicleId)
		view.fleet.vehicles[#view.fleet.vehicles + 1] = {
			vehicleId = item.vehicleId, label = item.view.label, capacity = item.view.capacity, liters = item.view.liters, cargo = item.view.cargo,
			plate = type(record) == 'table' and record.plate or nil, state = type(record) == 'table' and record.state or nil
		}
	end
	return view
end

local function tabletPrice(characterId, station, payload)
	local fuelId = type(payload.fuel) == 'string' and catalog.fuels[payload.fuel] and payload.fuel or nil
	if not fuelId then
		return { ok = false, error = 'unknown_fuel' }
	end
	local price = nil
	if payload.price ~= nil and payload.price ~= false and tonumber(payload.price) ~= catalog.fuels[fuelId].price then
		price = FuelRules.ValidPrice(config, catalog.fuels[fuelId].price, payload.price)
		if not price then
			return { ok = false, error = 'invalid_price' }
		end
	end
	if not FuelPersistence.SavePrice(station.business, fuelId, price) then
		return { ok = false, error = 'database_error' }
	end
	prices[station.business] = prices[station.business] or {}
	prices[station.business][fuelId] = price
	audit('fuel_price', { character_id = characterId, target = station.business, item = fuelId, count = price or catalog.fuels[fuelId].price })
	return { ok = true }
end

local function tabletUpgradeTank(characterId, station, payload)
	local fuelId = type(payload.fuel) == 'string' and catalog.fuels[payload.fuel] and payload.fuel or nil
	if not fuelId then
		return { ok = false, error = 'unknown_fuel' }
	end
	local level = levelOf(station.business, fuelId)
	local spec, specError = FuelRules.NextTank(config, level, balanceOf(station.business), stationStats(station.business).sold)
	if not spec then
		return { ok = false, error = specError }
	end
	local charged, chargeError = chargeBusiness(station.business, spec.price, 'fuel_tank_upgrade', fuelId .. ':' .. (level + 1))
	if not charged then
		return { ok = false, error = chargeError }
	end
	tankLevels[station.business] = tankLevels[station.business] or {}
	tankLevels[station.business][fuelId] = level + 1
	saveTank(station.business, fuelId)
	audit('fuel_tank_upgrade', { character_id = characterId, target = station.business, item = fuelId, count = level + 1 })
	return { ok = true }
end

local function tabletUpgradeFleet(characterId, station)
	local tier = fleetTierOf(station.business)
	local spec, specError = FuelRules.NextFleet(config, tier, balanceOf(station.business), stationStats(station.business).sold)
	if not spec then
		return { ok = false, error = specError }
	end
	local record
	local sagaOk, _, sagaErr = FuelRules.ExecuteSaga({
		{
			name = 'charge_business',
			action = function()
				local charged, chargeError = chargeBusiness(station.business, spec.price, 'fuel_fleet_upgrade', spec.id)
				if not charged then
					return false, chargeError
				end
				return true
			end,
			compensate = function()
				remote('coe_economy', 'SocietyCollect', station.business, spec.price, 'fuel_fleet_refund')
			end
		},
		{
			name = 'add_fleet',
			action = function()
				record = remote('coe_garages', 'AddBusinessFleet', station.business, spec.model, true)
				if type(record) ~= 'table' or not record.id then
					return false, type(record) == 'table' and record.error or 'garages_unavailable'
				end
				return record
			end
		}
	}, {})
	if not sagaOk then
		return { ok = false, error = sagaErr }
	end
	local vehicleId = tostring(record.id)
	fleet[vehicleId] = { business = station.business, tier = tier + 1, cargo = FuelRules.Empty(config) }
	saveFleet(vehicleId)
	audit('fuel_fleet_upgrade', { character_id = characterId, target = station.business, vehicle_id = vehicleId, item = spec.id, plate = record.plate })
	return { ok = true, plate = record.plate }
end

-- Permissões de cargo e aba Posto no app do negócio. De novo sempre que o coe_businesses reiniciar.
local function registerInBusinesses()
	remote('coe_businesses', 'RegisterPermissions', {
		{ name = 'fuel.supply', label = 'Posto: carregamentos na refinaria' },
		{ name = 'fuel.manage', label = 'Posto: preços e melhorias' }
	})
	local result = remote('coe_businesses', 'RegisterTab', {
		id = 'fuel', label = 'Posto', order = 10, script = 'html/business.js', css = 'html/business.css',
		handler = 'BusinessTablet', visible = 'IsStation'
	})
	if type(result) == 'table' and result.error then
		log('warn', 'system', 'fuel_tab_register_failed', { error_code = tostring(result.error) })
	end
end

AddEventHandler('onResourceStart', function(resource)
	if resource == 'coe_businesses' and ready then
		registerInBusinesses()
	end
end)

exports('IsStation', function(businessId)
	return type(businessId) == 'string' and businessStation[businessId] ~= nil
end)

exports('BusinessTablet', function(playerId, characterId, businessId, payload)
	if GetInvokingResource() ~= 'coe_businesses' then
		return { ok = false, error = 'forbidden' }
	end
	if not ready then
		return { ok = false, error = 'not_ready' }
	end
	local station = type(businessId) == 'string' and businessStation[businessId]
	if not station then
		return { ok = false, error = 'not_a_station' }
	end
	characterId = tostring(characterId)
	payload = type(payload) == 'table' and payload or {}
	local op = payload.op or 'overview'
	if op == 'overview' then
		return tabletView(characterId, station)
	end
	local view = tabletView(characterId, station)
	if not view.ok then
		return view
	end
	if view.mode ~= 'player' then
		return { ok = false, error = 'staff_station' }
	end
	if not view.canManage then
		return { ok = false, error = 'forbidden' }
	end
	if playerBusy[playerId] then
		return { ok = false, error = 'busy' }
	end
	playerBusy[playerId] = true
	local handlers = { price = tabletPrice, upgradeTank = tabletUpgradeTank, upgradeFleet = tabletUpgradeFleet }
	local handler = handlers[op]
	local ok, result = true, { ok = false, error = 'unknown_action' }
	if handler then
		ok, result = pcall(handler, characterId, station, payload)
	end
	playerBusy[playerId] = nil
	if not ok then
		log('error', 'gameplay', 'fuel_tablet_failed', { player_id = playerId, target = station.business, error_code = tostring(result):sub(1, 96) })
		return { ok = false, error = 'internal_error' }
	end
	if not result.ok then
		return result
	end
	local fresh = tabletView(characterId, station)
	fresh.plate = result.plate
	return fresh
end)

-- Pedidos do client ------------------------------------------------------------------------------------------

local Actions = {}

function Actions.open(playerId, _, payload)
	local station, errorCode, coords = stationFor(playerId, payload)
	if not station then
		return { ok = false, error = errorCode }
	end
	local view, viewError = pumpView(playerId, station, coords, payload)
	if not view then
		return { ok = false, error = viewError }
	end
	return { ok = true, view = view }
end

function Actions.quote(playerId, _, payload)
	local station, errorCode, coords = stationFor(playerId, payload)
	if not station then
		return { ok = false, error = errorCode }
	end
	local sale, prepareError = prepare(playerId, station, coords, payload)
	if not sale then
		return { ok = false, error = prepareError }
	end
	return { ok = true, total = sale.total, liters = sale.liters, label = 'Posto ' .. station.label }
end

function Actions.buy(playerId, character, payload)
	local station, errorCode, coords = stationFor(playerId, payload)
	if not station then
		return { ok = false, error = errorCode }
	end
	if playerBusy[playerId] then
		return { ok = false, error = 'busy' }
	end
	playerBusy[playerId] = true
	local ok, result = pcall(buy, playerId, character, station, coords, payload)
	playerBusy[playerId] = nil
	if not ok then
		log('error', 'gameplay', 'fuel_buy_failed', { player_id = playerId, target = station.id, error_code = tostring(result):sub(1, 96) })
		return { ok = false, error = 'internal_error' }
	end
	return result
end

local function guarded(name, fn)
	return function(playerId, character, payload)
		if playerBusy[playerId] then
			return { ok = false, error = 'busy' }
		end
		playerBusy[playerId] = true
		local ok, result = pcall(fn, playerId, character, payload)
		playerBusy[playerId] = nil
		if not ok then
			log('error', 'gameplay', 'fuel_' .. name .. '_failed', { player_id = playerId, error_code = tostring(result):sub(1, 96) })
			return { ok = false, error = 'internal_error' }
		end
		return result
	end
end

Actions.refinery = guarded('refinery', refineryOpen)
Actions.load = guarded('load', refineryLoad)
Actions.unload = guarded('unload', unload)

function Actions.pour(playerId, _, payload)
	if playerBusy[playerId] then
		return { ok = false, error = 'busy' }
	end
	playerBusy[playerId] = true
	local ok, result = pcall(pour, playerId, payload)
	playerBusy[playerId] = nil
	if not ok then
		log('error', 'gameplay', 'fuel_pour_failed', { player_id = playerId, error_code = tostring(result):sub(1, 96) })
		return { ok = false, error = 'internal_error' }
	end
	return result
end

RegisterNetEvent('coe_fuel:request', function(requestId, action, payload)
	local playerId = source
	local function answer(result)
		TriggerClientEvent('coe_fuel:response', playerId, requestId, result)
	end
	if type(action) ~= 'string' or not rawget(Actions, action) then
		return answer({ ok = false, error = 'unknown_action' })
	end
	if not ready then
		return answer({ ok = false, error = 'not_ready' })
	end
	local now = GetGameTimer()
	if not callLimiter:allow(playerId, now, 1) then
		return answer({ ok = false, error = 'busy' })
	end
	lastCall[playerId] = now
	local character = characterOf(playerId)
	if not character then
		return answer({ ok = false, error = 'no_character' })
	end
	answer(Actions[action](playerId, character, type(payload) == 'table' and payload or {}))
end)

AddEventHandler('playerDropped', function()
	callLimiter:forget(source)
	lastCall[source], lastReport[source], playerBusy[source] = nil, nil, nil
end)

-- Exports ----------------------------------------------------------------------------------------------------

exports('IsReady', function()
	return ready
end)

-- Tanque de um veículo registrado em uso (ou nil).
exports('GetFuel', function(vehicleId)
	local entity = byVehicleId[tostring(vehicleId)]
	local state = entity and vehicles[entity]
	if not state then
		return nil
	end
	return FuelRules.Summary(config, catalog, state.tank, state.capacity, state.engine)
end)

-- Efeitos da mistura no motor para o coe_handling: { mods = { fInitialDriveForce }, key } ou nil.
exports('GetEffects', function(vehicleId)
	local entity = byVehicleId[tostring(vehicleId)]
	local state = entity and vehicles[entity]
	if not state or state.engine == 'none' or not state.effects then
		return nil
	end
	return { mods = { fInitialDriveForce = state.effects.power }, key = state.effectsKey }
end)

-- Tanques do posto (litros, nível e capacidade de cada combustível).
exports('GetStationTanks', function(stationId)
	local station = type(stationId) == 'string' and catalog.byId[stationId]
	if not station then
		return nil
	end
	local out, capacities, levels = {}, {}, {}
	for _, id in ipairs(config.FuelOrder) do
		out[id] = (tanks[station.business] or {})[id] or 0
		levels[id] = levelOf(station.business, id)
		capacities[id] = FuelRules.TankCapacity(config, levels[id])
	end
	return { business = station.business, capacities = capacities, levels = levels, tanks = out }
end)

-- Comandos de staff -------------------------------------------------------------------------------------------

local function allowed(playerId)
	return playerId == 0 or IsPlayerAceAllowed(playerId, config.ManageAce)
end

-- coe_fuel_tank <posto> <combustível> <litros>: define o tanque de um posto (testes e correções da staff).
RegisterCommand('coe_fuel_tank', function(playerId, args)
	if not allowed(playerId) then
		return
	end
	local station, fuelId, liters = catalog.byId[args[1] or ''], args[2], tonumber(args[3])
	if not station or not catalog.fuels[fuelId or ''] or not liters then
		print('uso: coe_fuel_tank <posto> <regular|premium|ethanol|diesel> <litros>')
		return
	end
	liters = math.max(0, math.min(FuelRules.TankCapacity(config, levelOf(station.business, fuelId)), liters))
	tanks[station.business] = tanks[station.business] or {}
	tanks[station.business][fuelId] = liters
	saveTank(station.business, fuelId)
	audit('fuel_tank_set', { character_id = playerId ~= 0 and (characterOf(playerId) or {}).id or nil, target = station.business, item = fuelId, count = liters })
	print(('[coe_fuel] %s: %s = %.0f L'):format(station.business, fuelId, liters))
end, false)

-- coe_fuel_fill [id do jogador] [combustível]: enche o tanque do veículo em que o jogador está.
RegisterCommand('coe_fuel_fill', function(playerId, args)
	if not allowed(playerId) then
		return
	end
	local target = tonumber(args[1]) or playerId
	local entity = target ~= 0 and GetVehiclePedIsIn(GetPlayerPed(target), false) or 0
	local state = entity ~= 0 and vehicles[entity]
	if not state or state.engine == 'none' then
		print('[coe_fuel] jogador fora de um veículo com tanque (entre como motorista primeiro)')
		return
	end
	local fuelId = catalog.fuels[args[2] or ''] and args[2] or (state.engine == 'diesel' and 'diesel' or 'regular')
	if not FuelRules.Compatible(catalog, state.engine, fuelId) then
		print('[coe_fuel] combustível errado para este motor')
		return
	end
	state.tank = FuelRules.Add(config, state.tank, fuelId, state.capacity, state.capacity)
	state.dirty = state.vehicleId ~= nil
	refreshEffects(state)
	saveVehicle(state)
	publish(state)
	print(('[coe_fuel] tanque cheio (%s)'):format(fuelId))
end, false)

-- Inicialização ----------------------------------------------------------------------------------------------

CreateThread(function()
	local waitingLogged = false
	while true do
		local initialized, errorCode = FuelPersistence.Initialize()
		if initialized then
			break
		end
		if errorCode == 'database_not_ready' or errorCode == 'database_unavailable' then
			if not waitingLogged then
				log('info', 'persistence', 'database_waiting', {})
				waitingLogged = true
			end
			Wait(1000)
		else
			log('error', 'persistence', 'fuel_migrations_failed', { error_code = tostring(errorCode) })
			Wait(15000)
		end
	end
	-- Tanques, níveis, preços e frota (tenta de novo até o banco responder).
	while true do
		local loadedTanks, _, loadedLevels = FuelPersistence.Tanks()
		local loadedPrices = FuelPersistence.Prices()
		local loadedFleet = FuelPersistence.Fleet()
		if loadedTanks and loadedPrices and loadedFleet then
			tanks, tankLevels, prices, fleet = loadedTanks, loadedLevels or {}, loadedPrices, loadedFleet
			break
		end
		log('error', 'persistence', 'fuel_tanks_load_failed', {})
		Wait(15000)
	end
	-- Veículos da frota que já estavam na rua.
	for vehicleId in pairs(fleet) do
		local entity = remote('coe_vehicles', 'GetEntity', tonumber(vehicleId) or vehicleId)
		if entity and entity ~= 0 then
			fleetEntity[vehicleId] = entity
			publishCargo(vehicleId)
		end
	end
	ready = true
	log('info', 'system', 'fuel_ready', { count = #catalog.stations })
	-- Negócios dos postos (os LTD já são das lojas do coe_shops).
	local deadline = GetGameTimer() + 120000
	while remote('coe_businesses', 'IsReady') ~= true and GetGameTimer() < deadline do
		Wait(1000)
	end
	registerInBusinesses()
	for _, station in ipairs(catalog.stations) do
		if station.business == 'posto_' .. station.id then
			local result = remote('coe_businesses', 'Seed', FuelRules.BusinessSeed(station))
			if type(result) == 'table' and result.error then
				log('warn', 'system', 'fuel_seed_failed', { target = station.business, error_code = tostring(result.error) })
			end
		end
	end
end)

CreateThread(function()
	while true do
		Wait(config.FlushSeconds * 1000)
		for entity, state in pairs(vehicles) do
			if not Core.Platform.Entities.Exists(entity) then
				forget(entity)
			else
				saveVehicle(state)
			end
		end
	end
end)

AddEventHandler('onResourceStop', function(resource)
	if resource ~= GetCurrentResourceName() then
		return
	end
	for _, state in pairs(vehicles) do
		flushWear(state, true)
		saveVehicle(state)
	end
end)
