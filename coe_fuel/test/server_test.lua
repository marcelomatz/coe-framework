-- Servidor do combustível com natives e exports simulados: tanque registrado e sem registro, consumo validado,
-- desgaste e efeitos, bomba (veículo e galão, três pagamentos, combustível errado, tanque cheio), posto de jogador
-- com estoque, galão no veículo e comandos de staff.
local netHandlers, handlers, exported, responses, notices, audits, events = {}, {}, {}, {}, {}, {}, {}
local commands = {}
local now = 100000
local clock = 1792000000
os.time = function() return clock end
source = nil
math.randomseed(1)

local function hash(name) local h = 0 for i = 1, #name do h = (h * 31 + name:byte(i)) % 4294967296 end return h end
function GetHashKey(name) return hash(name) end
function GetGameTimer() return now end
function GetResourceState() return 'started' end
function GetCurrentResourceName() return 'coe_fuel' end
function CreateThread(fn) local co = coroutine.create(fn); local ok, err = coroutine.resume(co); if not ok then error(err) end end
function Wait() coroutine.yield() end
function RegisterNetEvent(name, fn) netHandlers[name] = fn end
function AddEventHandler(name, fn) handlers[name] = fn end
function TriggerEvent(name, ...) events[#events + 1] = { name = name, args = { ... } } end
function TriggerClientEvent(name, target, a, b) if name == 'coe_fuel:response' then responses[#responses + 1] = { target = target, id = a, result = b } end end
function RegisterCommand(name, fn) commands[name] = fn end
local aces = {}
function IsPlayerAceAllowed(id, ace) return aces[id] == true end

-- Entidades: posições, estado e assentos
local positions, states, drivers, removed = {}, {}, {}, {}
function DoesEntityExist(entity) return entity ~= nil and entity ~= 0 and not removed[entity] and positions[entity] ~= nil end
function GetEntityCoords(entity) return positions[entity] end
function GetPlayerPed(id) return 1000 + id end
function NetworkGetEntityFromNetworkId(netId) return netId end
function GetPedInVehicleSeat(entity) return drivers[entity] end
function GetVehiclePedIsIn(ped) for entity, driver in pairs(drivers) do if driver == ped then return entity end end return 0 end
function Entity(entity)
	states[entity] = states[entity] or {}
	local bag = states[entity]
	return { state = setmetatable({ set = function(_, key, value) bag[key] = value end }, { __index = bag }) }
end

local characters = { [1] = 11, [2] = 22 }
local function loadFramework(path)
	local candidates = {
		'../' .. path,
		'../tools/compat/' .. path,
		'../[coe-framework]/' .. path,
		'../../coe-framework/' .. path
	}
	for _, c in ipairs(candidates) do
		local f = io.open(c, 'r')
		if f then f:close() return dofile(c) end
	end
	error('Cannot find framework file: ' .. path)
end

loadFramework('coe_core/lib/platform.lua')
Core = {
	Platform = CoePlatform,
	Players = { GetActiveCharacter = function(id) return characters[id] and { characterId = characters[id] } end }
}

-- Exports simulados
balances, charges, fleetAdds, accessMap, canMap = {}, {}, {}, {}, {}
nextVehicle, garageFails, permissionsRegistered = 900, false, nil
local businesses, seeds = {}, {}
local inventories = { inv1 = { money = 500, items = {} }, inv2 = { money = 40, items = {} } }
local invOf = { [1] = 'inv1', [2] = 'inv2' }
local purchases, refunds, collected, wear = {}, {}, {}, {}
local pins = { [7] = '1234' }
local walletTokens = { tok = 9 }
local addFails = false

local function itemsOf(id)
	local list = {}
	for slot, item in pairs(inventories[id].items) do list[slot] = { name = item.name, count = 1, metadata = item.metadata, slot = slot } end
	return list
end

exports = setmetatable({}, {
	__call = function(_, name, fn) exported[name] = fn end,
	__index = function(_, resource)
		if resource == 'coe_logging' then return { Log = function() end } end
		if resource == 'coe_audit' then return { Record = function(_, _, _, event, ctx) audits[#audits + 1] = { event = event, ctx = ctx } end } end
		if resource == 'coe_notify' then return { Notify = function(_, id, kind, message) notices[#notices + 1] = { id = id, kind = kind, message = message } end } end
		if resource == 'coe_vehicles' then return { Get = function(_, id) return { id = id, model = 'asea', plate = 'PL' .. tostring(id), state = 'out' } end, GetEntity = function() return nil end } end
		if resource == 'coe_garages' then
			return { AddBusinessFleet = function(_, businessId, model, staff)
				if garageFails then return { error = 'no_fleet_garage' } end
				nextVehicle = nextVehicle + 1
				fleetAdds[#fleetAdds + 1] = { business = businessId, model = model, staff = staff, id = nextVehicle }
				return { id = nextVehicle, plate = 'FL' .. nextVehicle }
			end }
		end
		if resource == 'coe_mechanic' then return { AddWear = function(_, vehicleId, meters, parts) wear[#wear + 1] = { id = vehicleId, meters = meters, parts = parts } return true end } end
		if resource == 'coe_businesses' then
			return {
				IsReady = function() return true end,
				Get = function(_, id) return businesses[id] end,
				Seed = function(_, seed) seeds[#seeds + 1] = seed; businesses[seed.id] = businesses[seed.id] or { id = seed.id, enabled = true } return { id = seed.id } end,
				RegisterPermissions = function(_, list) permissionsRegistered = list end,
				RegisterTab = function(_, def) tabRegistered = def; return true end,
				Access = function(_, businessId, characterId) return accessMap[businessId .. ':' .. characterId] end,
				Can = function(_, businessId, characterId, permission) return canMap[businessId .. ':' .. characterId .. ':' .. permission] == true end
			}
		end
		if resource == 'coe_economy' then
			return {
				SocietyCollect = function(_, id, amount, reason) collected[#collected + 1] = { id = id, amount = amount, reason = reason } balances[id] = (balances[id] or 0) + amount return true end,
				SocietyBalance = function(_, id) return balances[id] or 0 end,
				SocietyCharge = function(_, id, amount, reason)
					if (balances[id] or 0) < amount then return { error = 'insufficient_funds' } end
					balances[id] = balances[id] - amount
					charges[#charges + 1] = { id = id, amount = amount, reason = reason }
					return true
				end
			}
		end
		if resource == 'coe_phone' then
			return { ConsumePayment = function(_, _, token) local card = walletTokens[token]; walletTokens[token] = nil return card end }
		end
		if resource == 'coe_banking' then
			return {
				PosCards = function() return { ok = true, cards = { { id = 7, last4 = '1234' } } } end,
				PosPurchase = function(_, _, cardId, pin, amount)
					if pins[cardId] ~= pin then return { ok = false, error = 'wrong_pin', left = 2 } end
					purchases[#purchases + 1] = { cardId = cardId, amount = amount } return { ok = true }
				end,
				CardPurchase = function(_, cardId, amount) purchases[#purchases + 1] = { cardId = cardId, amount = amount } return { ok = true } end,
				CardRefund = function(_, cardId, amount) refunds[#refunds + 1] = { cardId = cardId, amount = amount } return { ok = true } end
			}
		end
		if resource == 'coe_inventory' then
			return {
				GetPlayerInventory = function(_, id) return invOf[id] end,
				GetItemCount = function(_, id, item) return item == 'money' and inventories[id].money or 0 end,
				RemoveItemByName = function(_, id, item, count) if item == 'money' then inventories[id].money = inventories[id].money - count end return true end,
				AddItem = function(_, id, item, count, metadata)
					if item == 'money' then inventories[id].money = inventories[id].money + count return true end
					if addFails then return false end
					local slot = #inventories[id].items + 1
					inventories[id].items[slot] = { name = item, metadata = metadata }
					return true
				end,
				GetInventory = function(_, id) return { id = id, items = itemsOf(id) } end,
				SetItemMetadata = function(_, id, slot, patch)
					local item = inventories[id].items[slot]
					if not item then return false end
					for k, v in pairs(patch) do item.metadata[k] = v end
					return true
				end
			}
		end
		return setmetatable({}, { __index = function() return function() return nil end end })
	end
})

local savedVehicles, savedTanks, sales = {}, {}, {}

local savedLevels, savedPrices, savedFleet = {}, {}, {}
local soldLiters = 0
FuelPersistence = {
	Initialize = function() return true end,
	Tanks = function() return {}, nil, {} end,
	Prices = function() return {} end,
	Fleet = function() return {} end,
	SavePrice = function(b, f, price) savedPrices[b .. ':' .. f] = price or false return true end,
	SaveFleet = function(id, entry) savedFleet[id] = { business = entry.business, tier = entry.tier, cargo = { regular = entry.cargo.regular, premium = entry.cargo.premium, ethanol = entry.cargo.ethanol, diesel = entry.cargo.diesel } } return true end,
	Stats = function() return { sold = soldLiters, today = 0, week = 0, weekLiters = 0 } end,
	LoadVehicle = function(id) local row = savedVehicles[id] if not row then return nil end return { engine = row.engine, capacity = row.capacity, tank = row.tank } end,
	SaveVehicle = function(id, engine, capacity, tank) savedVehicles[id] = { engine = engine, capacity = capacity, tank = { regular = tank.regular, premium = tank.premium, ethanol = tank.ethanol, diesel = tank.diesel } } return true end,
	SaveTank = function(b, f, l, level) savedTanks[b .. ':' .. f] = l savedLevels[b .. ':' .. f] = level return true end,
	RecordSale = function(sale) sales[#sales + 1] = sale return true end
}

dofile('config.lua')
dofile('shared/rules.lua')
dofile('server/main.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end
local function near(a, b, m) if math.abs(a - b) > 0.011 then error(('%s: esperado %s, veio %s'):format(m, b, a), 2) end end

local requestId = 0
local function call(playerId, action, payload)
	requestId = requestId + 1
	now = now + 1000
	source = playerId
	netHandlers['coe_fuel:request'](requestId, action, payload)
	local last = responses[#responses]
	eq(last.id, requestId, 'resposta do pedido')
	return last.result
end

eq(exported.IsReady(), true, 'pronto')
local ownSeeds = 0
for _, station in ipairs(FuelConfig.Stations) do if not station.business then ownSeeds = ownSeeds + 1 end end
eq(#seeds, ownSeeds, 'postos sem negocio semeados (LTD fica com as lojas)')
eq(seeds[1].category, 'gas_station', 'categoria posto')

local station = FuelConfig.Stations[20] -- Davis (Ron)
eq(station.id, 'davis', 'posto do teste')
local sx, sy, sz = station.center[1], station.center[2], station.center[3]

-- Veiculo registrado (sedan) com motorista 1
local car = 501
positions[car] = { x = sx + 2, y = sy, z = sz }
states[car] = { ['coe:vehicleId'] = 77 }
drivers[car] = GetPlayerPed(1)
positions[GetPlayerPed(1)] = { x = sx + 1, y = sy, z = sz }
source = 1
netHandlers['coe_fuel:init'](car, 1, hash('asea'))
local fuel = states[car]['coe:fuel']
eq(fuel.engine, 'flex', 'sedan flex')
eq(fuel.capacity, 55, 'tanque do sedan')
near(fuel.liters, 55 * FuelConfig.RegisteredStartLevel, 'comeca na metade')
eq(savedVehicles['77'] ~= nil, true, 'tanque gravado')

-- consumo validado
now = now + 5000
netHandlers['coe_fuel:report'](car, 400, 5, 0.5)
local afterKm = states[car]['coe:fuel'].liters
near(afterKm, 27.5 - 9 * FuelConfig.ConsumptionScale / 100 * 0.4 - FuelConfig.IdlePerHour * 5 / 3600, '400 m com comum')
now = now + 5000
netHandlers['coe_fuel:report'](car, 999999, 5, 0.5)
near(states[car]['coe:fuel'].liters, afterKm - 9 * FuelConfig.ConsumptionScale / 100 * 0.475 - FuelConfig.IdlePerHour * 5 / 3600, 'distancia limitada pela velocidade')
local beforeSpam = states[car]['coe:fuel'].liters
now = now + 100
netHandlers['coe_fuel:report'](car, 400, 5, 0.5)
eq(states[car]['coe:fuel'].liters, beforeSpam, 'relatorio rapido demais e ignorado')
source = 2
now = now + 5000
netHandlers['coe_fuel:report'](car, 1000, 5, 0.5)
eq(states[car]['coe:fuel'].liters, beforeSpam, 'so o motorista reporta')
source = 1
now = now + 5000
netHandlers['coe_fuel:report'](car, 400, 5, 0.5)
eq(#wear >= 1, true, 'comum manda desgaste para a mecanica')
eq(wear[1].id, '77', 'desgaste do veiculo')
eq(wear[1].meters > 0, true, 'desgaste positivo')
eq(wear[1].parts[1], 'spark_plugs', 'pecas do motor')
eq(exported.GetEffects(77).mods.fInitialDriveForce, 1, 'comum sem ganho de forca')

-- bomba: abrir
local pay = { method = 'cash' }
local view = call(1, 'open', { stationId = 'davis', netId = car, classId = 1 })
eq(view.ok, true, 'abre a bomba')
eq(view.view.mode, 'staff', 'posto da staff')
eq(view.view.vehicle.engine, 'flex', 'veiculo na bomba')
eq(view.view.station.brandLabel, 'Ron', 'bandeira')
eq(view.view.station.theme.primary, FuelConfig.Brands.ron.theme.primary, 'cores da bandeira na bomba')
eq(view.view.fuels[1].stock, nil, 'estoque infinito')
eq(call(1, 'open', { stationId = 'grove' }).error, 'too_far', 'longe do posto')

-- comprar etanol (dinheiro) e mistura
local space = 55 - states[car]['coe:fuel'].liters
local result = call(1, 'buy', { stationId = 'davis', netId = car, fuel = 'ethanol', liters = 100, target = 'vehicle', payment = pay })
eq(result.ok, true, 'abastece')
near(result.liters, math.floor(space * 10) / 10, 'so o espaco do tanque')
eq(result.total, FuelRules.Price(4, result.liters), 'preco do etanol')
near(result.seconds, result.liters / FuelConfig.PumpRate, 'tempo proporcional aos litros')
eq(result.price, 4, 'preco por litro para o mostrador')
eq(result.fuel, 'ethanol', 'combustivel para o mostrador')
eq(inventories.inv1.money, 500 - result.total, 'cobra em dinheiro')
eq(collected[#collected].id, 'posto_davis', 'receita no caixa do posto')
eq(collected[#collected].reason, 'fuel_sale', 'motivo da receita')
eq(sales[#sales].fuel, 'ethanol', 'venda registrada')
eq(events[#events].name, 'coe_fuel:effectsChanged', 'avisa o handling')
eq(exported.GetEffects(77).mods.fInitialDriveForce > 1, true, 'etanol da forca')
eq(call(1, 'buy', { stationId = 'davis', netId = car, fuel = 'regular', liters = 5, target = 'vehicle', payment = pay }).error, 'tank_full', 'tanque cheio')
eq(call(1, 'buy', { stationId = 'davis', netId = car, fuel = 'diesel', liters = 5, target = 'vehicle', payment = pay }).error, 'wrong_fuel', 'diesel no flex bloqueado')
eq(call(1, 'buy', { stationId = 'davis', netId = car, fuel = 'nitro', liters = 5, target = 'vehicle', payment = pay }).error, 'unknown_fuel', 'combustivel desconhecido')
eq(call(1, 'buy', { stationId = 'davis', netId = car, fuel = 'regular', liters = 0.1, target = 'vehicle', payment = pay }).error, 'invalid_liters', 'litros invalidos')

-- caminhao diesel sem registro, cartao com senha e carteira
local truck = 502
positions[truck] = { x = sx - 2, y = sy, z = sz }
drivers[truck] = GetPlayerPed(2)
positions[GetPlayerPed(2)] = { x = sx - 1, y = sy, z = sz }
source = 2
netHandlers['coe_fuel:init'](truck, 20, hash('phantom'))
eq(states[truck]['coe:fuel'].engine, 'diesel', 'comercial diesel')
eq(states[truck]['coe:fuel'].capacity, 300, 'tanque grande')
eq(call(2, 'buy', { stationId = 'davis', netId = truck, fuel = 'regular', liters = 10, target = 'vehicle', payment = pay }).error, 'wrong_fuel', 'gasolina no diesel bloqueada')
eq(call(2, 'buy', { stationId = 'davis', netId = truck, fuel = 'diesel', liters = 10, target = 'vehicle', payment = pay }).error, 'insufficient_cash', 'sem dinheiro')
eq(call(2, 'buy', { stationId = 'davis', netId = truck, fuel = 'diesel', liters = 10, target = 'vehicle', payment = { method = 'card', cardId = 7, pin = '0000' } }).error, 'wrong_pin', 'senha errada')
result = call(2, 'buy', { stationId = 'davis', netId = truck, fuel = 'diesel', liters = 10, target = 'vehicle', payment = { method = 'card', cardId = 7, pin = '1234' } })
eq(result.ok, true, 'cartao na maquininha')
eq(purchases[#purchases].amount, 50, 'cobranca no cartao')
local quote = call(2, 'quote', { stationId = 'davis', netId = truck, fuel = 'diesel', liters = 20, target = 'vehicle' })
eq(quote.total, 100, 'orcamento para a carteira')
eq(call(2, 'buy', { stationId = 'davis', netId = truck, fuel = 'diesel', liters = 20, target = 'vehicle', payment = { method = 'wallet', token = 'tok' } }).ok, true, 'carteira do celular')
eq(call(2, 'buy', { stationId = 'davis', netId = truck, fuel = 'diesel', liters = 20, target = 'vehicle', payment = { method = 'wallet', token = 'tok' } }).error, 'payment_expired', 'token de uso unico')
eq(savedVehicles['502'], nil, 'sem registro nao grava')

-- galao: comprar novo, encher, despejar
inventories.inv1.money = 500
result = call(1, 'buy', { stationId = 'davis', fuel = 'regular', liters = 50, target = 'can', payment = pay })
eq(result.ok, true, 'galao novo')
eq(result.liters, FuelConfig.Can.capacity, 'galao limitado')
eq(result.total, FuelRules.Price(6, 20) + FuelConfig.Can.price, 'galao + combustivel')
eq(inventories.inv1.items[1].metadata.liters, 20, 'galao cheio')
eq(call(1, 'buy', { stationId = 'davis', fuel = 'regular', liters = 5, target = 'can', slot = 1, payment = pay }).error, 'can_full', 'galao cheio nao enche')
eq(call(1, 'buy', { stationId = 'davis', fuel = 'regular', liters = 5, target = 'can', slot = 9, payment = pay }).error, 'no_can', 'galao inexistente')
addFails = true
local money = inventories.inv1.money
eq(call(1, 'buy', { stationId = 'davis', fuel = 'regular', liters = 5, target = 'can', payment = pay }).error, 'inventory_full', 'sem espaco para o galao')
eq(inventories.inv1.money, money, 'estorno')
addFails = false
-- esvazia um pouco o tanque do carro e despeja o galao
now = now + 6000
netHandlers['coe_fuel:report'](car, 3000, 5, 1)
local beforePour = states[car]['coe:fuel'].liters
result = call(1, 'pour', { slot = 1, netId = car })
eq(result.ok, true, 'despeja o galao')
near(result.seconds, result.liters / FuelConfig.Can.pourRate, 'tempo do galao proporcional')
near(states[car]['coe:fuel'].liters, beforePour + result.liters, 'entrou no tanque')
near(inventories.inv1.items[1].metadata.liters, 20 - result.liters, 'galao baixa')
eq(call(2, 'pour', { slot = 1, netId = truck }).error, 'no_can', 'galao de outro jogador')
inventories.inv2.items[1] = { name = 'fuel_can', metadata = { fuel = 'regular', liters = 10 } }
eq(call(2, 'pour', { slot = 1, netId = truck }).error, 'wrong_fuel', 'gasolina do galao no diesel')
inventories.inv1.items[1].metadata.liters = 0
eq(call(1, 'pour', { slot = 1, netId = car }).error, 'can_empty', 'galao vazio')
eq(call(1, 'buy', { stationId = 'davis', fuel = 'diesel', liters = 5, target = 'can', slot = 1, payment = pay }).ok, true, 'galao vazio aceita outro combustivel')

-- posto de jogador: estoque nos tanques
businesses.posto_davis = { id = 'posto_davis', enabled = true, owner = { characterId = '22', name = 'Bruno' } }
view = call(1, 'open', { stationId = 'davis', netId = car })
eq(view.view.mode, 'player', 'posto de jogador')
eq(view.view.fuels[1].stock, 0, 'tanque vazio')
now = now + 6000
netHandlers['coe_fuel:report'](car, 3000, 5, 1)
eq(call(1, 'buy', { stationId = 'davis', netId = car, fuel = 'regular', liters = 2, target = 'vehicle', payment = pay }).error, 'out_of_stock', 'sem estoque no posto')
commands.coe_fuel_tank(0, { 'davis', 'regular', '100' })
eq(savedTanks['posto_davis:regular'], 100, 'tanque do posto pela staff')
result = call(1, 'buy', { stationId = 'davis', netId = car, fuel = 'regular', liters = 2, target = 'vehicle', payment = pay })
eq(result.ok, true, 'vende do tanque')
near(savedTanks['posto_davis:regular'], 100 - result.liters, 'baixa no tanque do posto')
near(exported.GetStationTanks('davis').tanks.regular, 100 - result.liters, 'export do tanque')
businesses.posto_davis.enabled = false
eq(call(1, 'open', { stationId = 'davis' }).error, 'station_closed', 'posto desativado')
businesses.posto_davis.enabled = true

-- comando de encher e remocao da entidade grava
commands.coe_fuel_fill(0, { '1' })
eq(states[car]['coe:fuel'].level, 1, 'tanque cheio pela staff')
handlers.entityRemoved(car)
eq(exported.GetFuel(77), nil, 'esquece ao remover')
eq(savedVehicles['77'].tank.regular > 0, true, 'gravou ao remover')
-- reaparece: carrega do banco
positions[503] = positions[car]
states[503] = { ['coe:vehicleId'] = 77 }
drivers[503] = GetPlayerPed(1)
source = 1
netHandlers['coe_fuel:init'](503, 1, 0)
eq(states[503]['coe:fuel'].level, 1, 'tanque volta do banco')
-- Etapa B: permissoes, aba Posto, upgrades, refinaria e descarga ------------------------------------------
eq(permissionsRegistered[1].name, 'fuel.supply', 'permissao de carregamento registrada')
eq(tabRegistered.id, 'fuel', 'aba Posto registrada no app do negocio')
eq(tabRegistered.visible, 'IsStation', 'so nos postos')
eq(tabRegistered.handler, 'BusinessTablet', 'handler da aba')
eq(permissionsRegistered[2].name, 'fuel.manage', 'permissao de gestao registrada')
eq(exported.IsStation('posto_davis'), true, 'posto no tablet')
eq(exported.IsStation('ltd_grove'), true, 'LTD tambem e posto')
eq(exported.IsStation('oficina'), false, 'nao e posto')
local function tablet(playerId, characterId, payload, invoker)
	GetInvokingResource = function() return invoker or 'coe_businesses' end
	return exported.BusinessTablet(playerId, characterId, 'posto_davis', payload)
end
eq(tablet(2, '22', {}, 'coe_admin').error, 'forbidden', 'so o coe_businesses')
local tab = tablet(2, '22', { op = 'overview' })
eq(tab.mode, 'player', 'posto de jogador no tablet')
eq(tab.canManage, true, 'dono gerencia')
eq(tab.fleet.tier, 0, 'sem frota')
eq(tab.fleet.next.label, 'Van pequena', 'proxima e a van')
eq(tab.fuels[1].level, 1, 'tanque nivel 1')
eq(tab.fuels[1].capacity, FuelConfig.TankLevels[1].capacity, 'capacidade do nivel 1')
eq(tablet(1, '11', { op = 'price', fuel = 'regular', price = 8 }).error, 'forbidden', 'sem fuel.manage nao muda preco')
eq(tablet(2, '22', { op = 'price', fuel = 'regular', price = 100 }).error, 'invalid_price', 'faixa de preco')
eq(tablet(2, '22', { op = 'price', fuel = 'regular', price = 8 }).ok, true, 'dono muda o preco')
eq(savedPrices['posto_davis:regular'], 8, 'preco gravado')
commands.coe_fuel_tank(0, { 'davis', 'regular', '100' })
positions[GetPlayerPed(1)] = { x = sx + 1, y = sy, z = sz }
local carState = states[503]['coe:fuel']
result = call(1, 'buy', { stationId = 'davis', netId = 503, fuel = 'regular', liters = 1, target = 'vehicle', payment = pay })
eq(result.error, 'tank_full', 'carro cheio')
local open = call(1, 'open', { stationId = 'davis' })
eq(open.view.fuels[1].price, 8, 'bomba usa o preco do dono')

-- frota: precisa de dinheiro no caixa
eq(tablet(2, '22', { op = 'upgradeFleet' }).error, 'insufficient_funds', 'van sem caixa')
balances.posto_davis = 1000000
garageFails = true
eq(tablet(2, '22', { op = 'upgradeFleet' }).error, 'no_fleet_garage', 'sem garagem de frota')
eq(balances.posto_davis, 1000000, 'estorno sem garagem')
garageFails = false
tab = tablet(2, '22', { op = 'upgradeFleet' })
eq(tab.ok, true, 'compra a van')
eq(tab.plate, 'FL' .. nextVehicle, 'placa da van')
eq(fleetAdds[#fleetAdds].model, FuelConfig.FleetTiers[1].model, 'modelo da van')
eq(fleetAdds[#fleetAdds].staff, true, 'equipe pode usar')
eq(balances.posto_davis, 1000000 - FuelConfig.FleetTiers[1].price, 'cobra do caixa')
eq(tab.fleet.tier, 1, 'nivel 1 de frota')
eq(tablet(2, '22', { op = 'upgradeFleet' }).error, 'not_enough_sales', 'caminhao exige vendas')
eq(tablet(2, '22', { op = 'upgradeTank', fuel = 'regular' }).error, 'not_enough_sales', 'tanque exige vendas')
soldLiters = FuelConfig.TankLevels[2].sold
eq(tablet(2, '22', { op = 'upgradeTank', fuel = 'regular' }).ok, true, 'upgrade do tanque')
eq(savedLevels['posto_davis:regular'], 2, 'nivel gravado')
eq(exported.GetStationTanks('davis').capacities.regular, FuelConfig.TankLevels[2].capacity, 'capacidade nova')

-- refinaria: van na rua, motorista com acesso
local vanId = tostring(nextVehicle)
local van = 600
local rx, ry, rz = FuelConfig.Refinery.center[1], FuelConfig.Refinery.center[2], FuelConfig.Refinery.center[3]
positions[van] = { x = rx + 2, y = ry, z = rz }
states[van] = { ['coe:vehicleId'] = tonumber(vanId) }
handlers['coe_vehicles:spawned'](tonumber(vanId), van)
eq(states[van]['coe:fuelCargo'].capacity, FuelConfig.FleetTiers[1].capacity, 'carga no state bag')
positions[GetPlayerPed(1)] = { x = rx + 1, y = ry, z = rz }
eq(call(1, 'refinery', { netId = van }).error, 'forbidden', 'sem permissao de carregamento')
accessMap['posto_davis:11'] = { owner = false, canWork = true }
canMap['posto_davis:11:fuel.supply'] = true
local refineryView = call(1, 'refinery', { netId = van })
eq(refineryView.ok, true, 'abre a refinaria')
eq(refineryView.view.fuels[1].wholesale, FuelConfig.Refinery.prices.regular, 'preco de atacado')
eq(call(1, 'load', { netId = van, load = { regular = 900 } }).error, 'over_capacity', 'acima da capacidade da van')
local before = balances.posto_davis
local loaded = call(1, 'load', { netId = van, load = { regular = 500, diesel = 200 } })
eq(loaded.ok, true, 'carrega')
eq(loaded.liters, 700, 'litros carregados')
eq(balances.posto_davis, before - loaded.cost, 'atacado sai do caixa')
near(loaded.seconds, 700 / FuelConfig.LoadRate, 'tempo proporcional')
eq(savedFleet[vanId].cargo.regular, 500, 'carga gravada')
eq(states[van]['coe:fuelCargo'].liters, 700, 'carga publicada')
eq(call(1, 'unload', { netId = van }).error, 'not_at_station', 'descarrega so no posto')
-- descarga no proprio posto
positions[van] = { x = sx + 3, y = sy, z = sz }
positions[GetPlayerPed(1)] = { x = sx + 2, y = sy, z = sz }
eq(call(1, 'load', { netId = van, load = { regular = 10 } }).error, 'not_at_refinery', 'carrega so na refinaria')
local tanksBefore = exported.GetStationTanks('davis').tanks.regular
local unloaded = call(1, 'unload', { netId = van })
eq(unloaded.ok, true, 'descarrega')
near(exported.GetStationTanks('davis').tanks.regular, tanksBefore + 500, 'gasolina no tanque')
near(exported.GetStationTanks('davis').tanks.diesel, 200, 'diesel no tanque')
eq(unloaded.left, 0, 'van vazia')
eq(call(1, 'unload', { netId = van }).error, 'empty_cargo', 'nada para descarregar')
-- veiculo que nao e da frota
eq(call(1, 'unload', { netId = 503 }).error, 'not_fleet', 'carro comum nao descarrega')
print('coe_fuel server tests passed')
