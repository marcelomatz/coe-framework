-- Testes do server/main.lua do coe_rentals: estações do banco, cobrança fail-closed, distância, cooldown,
-- documento e chave no inventário, devolução na zona e no balcão, encerramento sem o veículo e painel.
-- Rodar a partir da pasta do resource: lua test/server_test.lua

local function eq(actual, expected, message)
	if actual ~= expected then
		error(('%s: esperado %s, veio %s'):format(message, tostring(expected), tostring(actual)), 2)
	end
end

local handlers, coreHandlers, netEvents, notices, ledger, clientEvents = {}, {}, {}, {}, {}, {}
local now = 0
local economyState = 'started'
local balance = 1000
local position = { x = 328.0, y = -218.0, z = 54.0 }
local inVehicle = 0
local nextEntity = 100
local existing = {}
local vehiclePos = {}
local occupants = {}
local invoking = 'coe_staff'
local inventoryItems = {} -- inventoryId -> lista de { name, metadata }
local dbRows = {}
local staffProvider = nil

Core = {
	Events = {
		OnNet = function(name, fn) handlers[name] = fn end,
		On = function(name, fn) coreHandlers[name] = fn end,
		ToClient = function(target, name, ...) clientEvents[#clientEvents + 1] = { target = target, name = name, args = { ... } } end
	},
	Locale = {
		Init = function() return function(key) return key end end,
		FormatMoney = function(value) return 'R$ ' .. tostring(value) end
	},
	Players = {
		GetActiveCharacterId = function(playerId) return 'char_' .. playerId end,
		GetActiveCharacter = function(playerId) return { characterId = 'char_' .. playerId, firstName = 'Ana', lastName = 'Silva', stateId = 'AB12CD34' } end
	}
}
local aceGranted = { painel_pacote = true } -- add_ace resource.painel_pacote coe.rentals.admin allow
CoeAccess = { Allowed = function(caller, _, list) return list[caller] == true or aceGranted[caller] == true end }
AddEventHandler = function(name, fn) netEvents[name] = fn end
RegisterNetEvent = function(name, fn) netEvents[name] = fn end
CreateThread = function(fn) fn() end
Wait = function() end
GetInvokingResource = function() return invoking end
GetCurrentResourceName = function() return 'coe_rentals' end
GetGameTimer = function() return now end
GetPlayerPed = function() return 1 end
GetPlayers = function() return { '1', '2', '3' } end
GetEntityCoords = function(entity)
	if entity == 1 then return position end
	return vehiclePos[entity] or { x = 0, y = 0, z = 0 }
end
GetVehiclePedIsIn = function() return inVehicle end
GetResourceState = function(name) return name == 'coe_economy' and economyState or 'started' end
GetAllVehicles = function()
	local list = {}
	for entity in pairs(existing) do list[#list + 1] = entity end
	return list
end
GetEntityHealth = function() return 1000 end
GetPedInVehicleSeat = function(entity, seat) return (occupants[entity] and seat == -1) and 5 or 0 end
joaat = function() return 1 end
CreateVehicle = function(_, x, y, z)
	nextEntity = nextEntity + 1
	existing[nextEntity] = true
	vehiclePos[nextEntity] = { x = x, y = y, z = z }
	return nextEntity
end
local spawnDelay = 0 -- quantas consultas a entidade recém-criada ainda "não existe" (criação assíncrona no servidor)
DoesEntityExist = function(entity)
	if entity == nextEntity and spawnDelay > 0 then
		spawnDelay = spawnDelay - 1
		return false
	end
	return existing[entity] == true
end
DeleteEntity = function(entity) existing[entity] = nil end
SetVehicleNumberPlateText = function() end
NetworkGetNetworkIdFromEntity = function(entity) return entity end
SetVehicleDoorsLocked = function() end
Entity = function() return { state = { set = function() end } } end
TriggerClientEvent = function(name, target, ...) clientEvents[#clientEvents + 1] = { target = target, name = name, args = { ... } } end
json = { encode = function(v) return v end, decode = function(v) return v end }

RentalsPersistence = {
	Initialize = function() return true end,
	ListStations = function()
		local list = {}
		for _, row in pairs(dbRows) do list[#list + 1] = row end
		return list
	end,
	SaveStation = function(station) dbRows[station.id] = station return true end,
	DeleteStation = function(id) dbRows[id] = nil return true end
}

local function matches(metadata, filter)
	for key, value in pairs(filter) do
		if metadata[key] ~= value then return false end
	end
	return true
end
local inventoryExports = {
	GetPlayerInventory = function(_, playerId) return 'character:char_' .. playerId end,
	AddItem = function(_, id, name, count, metadata)
		inventoryItems[id] = inventoryItems[id] or {}
		table.insert(inventoryItems[id], { name = name, metadata = metadata })
		return true
	end,
	RemoveItemsByMetadata = function(_, id, name, filter)
		local kept, removed = {}, 0
		for _, item in ipairs(inventoryItems[id] or {}) do
			if item.name == name and matches(item.metadata, filter) then removed = removed + 1 else kept[#kept + 1] = item end
		end
		inventoryItems[id] = kept
		return removed
	end,
	GetInventory = function(_, id)
		local items = {}
		for slot, item in ipairs(inventoryItems[id] or {}) do items[slot] = item end
		return { items = items }
	end
}
local function countItems(id, name)
	local n = 0
	for _, item in ipairs(inventoryItems[id] or {}) do
		if item.name == name then n = n + 1 end
	end
	return n
end

local economyExports = {
	Debit = function(_, characterId, amount, reason)
		if amount > balance then
			return nil, 'insufficient_funds'
		end
		balance = balance - amount
		ledger[#ledger + 1] = { 'debit', characterId, amount, reason }
		return true
	end,
	Credit = function(_, characterId, amount, reason)
		balance = balance + amount
		ledger[#ledger + 1] = { 'credit', characterId, amount, reason }
		return true
	end
}
exports = setmetatable({}, {
	__call = function(_, name, fn) handlers['export:' .. name] = fn end,
	__index = function(_, res)
		if res == 'coe_economy' then return economyExports end
		if res == 'coe_inventory' then return inventoryExports end
		if res == 'coe_notify' then
			return { Notify = function(_, playerId, kind, message) notices[#notices + 1] = message end }
		end
		if res == 'coe_staff' then
			return { RegisterRentalsProvider = function(_, provider) staffProvider = provider return true end }
		end
		return { Log = function() end }
	end
})

dofile('config.lua')
dofile('domain/rules.lua')
dofile('domain/stations.lua')
dofile('server/main.lua')

local function rent(playerId, station, model)
	source = playerId
	handlers['rentals.rent'](station, model)
end

local function lastNotice()
	return notices[#notices]
end

-- 0. Boot: estações semeadas do config.lua no banco, provedor no painel.
eq(dbRows.pink_cage ~= nil, true, 'estação semeada no banco')
eq(dbRows.pink_cage.ped.x, 328.0, 'balcão vira o atendente')
eq(#dbRows.pink_cage.spawns, 1, 'spawn antigo vira o primeiro ponto de retirada')
eq(staffProvider ~= nil, true, 'provedor registrado no coe_staff')

-- 1. Economia fora do ar: recusa em vez de entregar o veículo de graça.
economyState = 'stopped'
rent(1, 'pink_cage', 'faggio')
eq(lastNotice(), 'economy_unavailable', 'sem economia não aluga')
eq(#ledger, 0, 'nada cobrado nem entregue')

-- 2. Longe do balcão: recusa.
economyState = 'started'
now = now + 5000
position = { x = 0.0, y = 0.0, z = 0.0 }
rent(1, 'pink_cage', 'faggio')
eq(lastNotice(), 'too_far', 'longe do balcão é recusado')

-- 3. No balcão: cobra preço + caução e entrega contrato e chave.
now = now + 5000
position = { x = 328.0, y = -218.0, z = 54.0 }
rent(1, 'pink_cage', 'faggio')
eq(lastNotice(), 'rent_success', 'aluguel concluído')
eq(balance, 880, 'cobrou 70 + 50')
eq(countItems('character:char_1', 'rental_contract'), 1, 'contrato no inventário')
eq(countItems('character:char_1', 'carkey'), 1, 'chave no inventário')
eq(inventoryItems['character:char_1'][1].metadata.renter, 'Ana Silva', 'locatário no contrato')
local firstRental = handlers['export:GetActiveRental']('char_1')
eq(firstRental.stationId, 'pink_cage', 'aluguel ativo')

-- 4. Cooldown: segundo pedido imediato é ignorado.
rent(1, 'pink_cage', 'blista')
eq(lastNotice(), 'busy', 'pedido repetido dentro do cooldown')

-- 5. Saldo insuficiente (o carro do jogador 1 saiu do ponto de retirada).
local parkedAt = vehiclePos[firstRental.entity]
vehiclePos[firstRental.entity] = { x = 600.0, y = 600.0, z = 54.0 }
now = now + 5000
balance = 10
rent(2, 'pink_cage', 'blista')
eq(lastNotice(), 'not_enough_money', 'saldo insuficiente')

-- 5b. Ponto de retirada ocupado pelo carro do jogador 1: sem outro ponto, recusa sem cobrar.
vehiclePos[firstRental.entity] = parkedAt
now = now + 5000
balance = 1000
rent(2, 'pink_cage', 'blista')
eq(lastNotice(), 'spawn_blocked', 'ponto de retirada ocupado')
eq(balance, 1000, 'nada cobrado com o ponto ocupado')

-- 6. Devolução na zona: precisa estar nela e dentro do veículo; devolve a caução e tira os itens.
balance = 880
now = now + 5000
position = { x = 0.0, y = 0.0, z = 0.0 }
source = 1
handlers['rentals.return']('pink_cage')
eq(lastNotice(), 'too_far', 'devolução longe da zona é recusada')

now = now + 5000
position = { x = 323.5, y = -226.5, z = 54.0 }
inVehicle = firstRental.entity
handlers['rentals.return']('pink_cage')
eq(lastNotice(), 'return_success', 'devolução concluída')
eq(balance, 930, 'caução de 50 devolvida')
eq(countItems('character:char_1', 'rental_contract'), 0, 'contrato removido')
eq(countItems('character:char_1', 'carkey'), 0, 'chave removida')
inVehicle = 0

-- 7. Modelo escolhido no menu precisa ser oferecido na estação.
local function stationCopy(vehicles)
	local base = dbRows.pink_cage
	return { id = base.id, label = base.label, ped = base.ped, spawns = base.spawns, returnZone = base.returnZone, blip = base.blip, vehicles = vehicles }
end
staffProvider.Save(stationCopy({ 'tribike' }))
now = now + 5000
position = { x = 328.0, y = -218.0, z = 54.0 }
rent(3, 'pink_cage', 'blista')
eq(lastNotice(), 'vehicle_not_available', 'modelo fora da estação é recusado')
staffProvider.Save(stationCopy({}))

-- 8. Devolver no balcão: carro estacionado perto e vazio.
now = now + 5000
rent(3, 'pink_cage', 'faggio')
local rental3 = handlers['export:GetActiveRental']('char_3')
source = 3
handlers['rentals.menu']('pink_cage')
local menu = clientEvents[#clientEvents]
eq(menu.name, 'rentals.menu', 'menu enviado')
eq(menu.args[3].status, 'near', 'veículo perto da estação')
occupants[rental3.entity] = true
now = now + 5000
handlers['rentals.returnAtCounter']('pink_cage')
eq(lastNotice(), 'vehicle_occupied', 'veículo ocupado não é devolvido')
occupants[rental3.entity] = nil
now = now + 5000
handlers['rentals.endRental']('pink_cage')
eq(lastNotice(), 'vehicle_still_exists', 'não encerra com o veículo existindo')
now = now + 5000
handlers['rentals.returnAtCounter']('pink_cage')
eq(lastNotice(), 'return_success', 'devolvido no balcão')
eq(existing[rental3.entity], nil, 'veículo removido')

-- 9. Encerrar sem o veículo: caução retida, itens removidos, pode alugar de novo.
now = now + 5000
rent(3, 'pink_cage', 'faggio')
local rental3b = handlers['export:GetActiveRental']('char_3')
existing[rental3b.entity] = nil -- o carro sumiu (explodiu, foi apagado)
now = now + 5000
handlers['rentals.returnAtCounter']('pink_cage')
eq(lastNotice(), 'vehicle_lost_use_end', 'sem veículo não devolve')
local before = balance
now = now + 5000
handlers['rentals.endRental']('pink_cage')
eq(lastNotice(), 'rental_ended', 'aluguel encerrado')
eq(balance, before, 'caução retida')
eq(handlers['export:GetActiveRental']('char_3'), nil, 'sem aluguel ativo')
eq(countItems('character:char_3', 'carkey'), 0, 'chave removida ao encerrar')

-- 10. Documento: usar o contrato envia os dados para a tela.
now = now + 5000
rent(3, 'pink_cage', 'faggio')
local contract = inventoryItems['character:char_3'][#inventoryItems['character:char_3'] - 1]
eq(contract.name, 'rental_contract', 'contrato entregue')
coreHandlers['inventory.itemUsed']('character:char_3', 1, { name = 'rental_contract', metadata = contract.metadata })
local doc = clientEvents[#clientEvents]
eq(doc.name, 'coe_rentals:document', 'documento aberto')
eq(doc.args[1].active, true, 'contrato em vigor')

-- 11. Itens de aluguéis antigos saem ao carregar o personagem.
inventoryExports.AddItem(nil, 'character:char_2', 'rental_contract', 1, { plate = 'RENT0000' })
coreHandlers['player.characterLoaded']({ source = 2, character = { characterId = 'char_2' } })
eq(countItems('character:char_2', 'rental_contract'), 0, 'contrato antigo removido')

-- 12. Painel: salvar com vários pontos de retirada, validar e apagar.
local saved = staffProvider.Save({
	id = 'aluguel_teste', label = 'Teste', ped = { x = 1, y = 2, z = 3, h = 90 },
	spawns = { { x = 5, y = 5, z = 3, h = 0 }, { x = 9, y = 5, z = 3, h = 0 } },
	returnZone = { x = 5, y = 5, z = 3, radius = 6 }, vehicles = { 'panto' }
})
eq(saved.id, 'aluguel_teste', 'estação salva pelo painel')
eq(#dbRows.aluguel_teste.spawns, 2, 'dois pontos de retirada')
eq(staffProvider.Save({ id = 'x1', label = 'X', ped = { x = 1, y = 2, z = 3 }, spawns = {}, returnZone = { x = 1, y = 1, z = 1 } }).error, 'invalid_spawns', 'sem ponto de retirada é recusado')
eq(staffProvider.Save({ id = 'x2', label = 'X', ped = { x = 1, y = 2, z = 3 }, spawns = { { x = 1, y = 1, z = 1 } }, returnZone = { x = 1, y = 1, z = 1 }, vehicles = { 'tanque' } }).error, 'invalid_vehicles', 'modelo fora do catálogo é recusado')
invoking = 'intruso'
eq(handlers['export:SaveStation']({ id = 'z' }).error, 'forbidden', 'export protegido')
invoking = 'painel_pacote'
eq(handlers['export:DeleteStation']('aluguel_teste'), true, 'pacote com a ACE apaga estação')
eq(dbRows.aluguel_teste, nil, 'estação removida do banco')

-- 13. Entidade criada de forma assíncrona: não pode estornar nem avisar falha com o veículo na rua.
handlers['export:GetActiveRental']('char_3')
source = 3
now = now + 5000
handlers['rentals.endRental']('pink_cage') -- garante sem aluguel ativo (o veículo existe: recusado)
local active3 = handlers['export:GetActiveRental']('char_3')
if active3 then
	existing[active3.entity] = nil
	now = now + 5000
	handlers['rentals.endRental']('pink_cage')
end
spawnDelay = 5
now = now + 5000
rent(3, 'pink_cage', 'faggio')
eq(lastNotice(), 'rent_success', 'aluguel concluído mesmo com a entidade surgindo depois')
eq(handlers['export:GetActiveRental']('char_3') ~= nil, true, 'aluguel registrado')

print('rentals server_test: ok')
