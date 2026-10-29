-- Testes do server/main.lua do coe_rentals: cobrança fail-closed, distância, cooldown e devolução.
-- Rodar a partir da pasta do resource: lua test/server_test.lua

local function eq(actual, expected, message)
	if actual ~= expected then
		error(('%s: esperado %s, veio %s'):format(message, tostring(expected), tostring(actual)), 2)
	end
end

local handlers, notices, ledger = {}, {}, {}
local now = 0
local economyState = 'started'
local balance = 1000
local position = { x = 328.0, y = -218.0, z = 54.0 }
local inVehicle = 0
local nextEntity = 100

Core = {
	Events = {
		OnNet = function(name, fn) handlers[name] = fn end,
		ToClient = function() end
	},
	Locale = { Init = function() return function(key) return key end end },
	Players = { GetActiveCharacterId = function(playerId) return 'char_' .. playerId end }
}
AddEventHandler = function() end
GetGameTimer = function() return now end
GetPlayerPed = function() return 1 end
GetEntityCoords = function() return position end
GetVehiclePedIsIn = function() return inVehicle end
GetResourceState = function(name) return name == 'coe_economy' and economyState or 'started' end
joaat = function() return 1 end
CreateVehicle = function() nextEntity = nextEntity + 1 return nextEntity end
DoesEntityExist = function(entity) return entity ~= 0 end
DeleteEntity = function() end
SetVehicleNumberPlateText = function() end
NetworkGetNetworkIdFromEntity = function(entity) return entity end
SetVehicleDoorsLocked = function() end

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
	__call = function() end,
	__index = function(_, res)
		if res == 'coe_economy' then
			return economyExports
		end
		if res == 'coe_notify' then
			return { Notify = function(_, playerId, kind, message) notices[#notices + 1] = message end }
		end
		return { Log = function() end }
	end
})

dofile('config.lua')
dofile('domain/rules.lua')
dofile('server/main.lua')

local function rent(playerId, station, model)
	source = playerId
	handlers['rentals.rent'](station, model)
end

local function lastNotice()
	return notices[#notices]
end

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

-- 3. No balcão: cobra preço + caução.
now = now + 5000
position = { x = 328.0, y = -218.0, z = 54.0 }
rent(1, 'pink_cage', 'faggio')
eq(lastNotice(), 'rent_success', 'aluguel concluído')
eq(balance, 880, 'cobrou 70 + 50')

-- 4. Cooldown: segundo pedido imediato é ignorado.
rent(1, 'pink_cage', 'blista')
eq(lastNotice(), 'busy', 'pedido repetido dentro do cooldown')

-- 5. Saldo insuficiente.
now = now + 5000
balance = 10
rent(2, 'pink_cage', 'blista')
eq(lastNotice(), 'not_enough_money', 'saldo insuficiente')

-- 6. Devolução: precisa estar na returnZone e no veículo alugado; devolve a caução.
balance = 880
now = now + 5000
position = { x = 0.0, y = 0.0, z = 0.0 }
source = 1
handlers['rentals.return']('pink_cage')
eq(lastNotice(), 'too_far', 'devolução longe da zona é recusada')

now = now + 5000
position = { x = 323.5, y = -226.5, z = 54.0 }
inVehicle = nextEntity
handlers['rentals.return']('pink_cage')
eq(lastNotice(), 'return_success', 'devolução concluída')
eq(balance, 930, 'caução de 50 devolvida')

print('rentals server_test: ok')
