-- Testes unitários do coe_rentals (regras de domínio + boot de server/client)
dofile('config.lua')
dofile('domain/rules.lua')

local function eq(actual, expected, message)
	if actual ~= expected then
		error(('%s: esperado %s, veio %s'):format(message, tostring(expected), tostring(actual)), 2)
	end
end

-- 1. Busca de veículos no catálogo
local faggio = RentalsRules.FindVehicle(RentalsConfig, 'faggio')
eq(faggio ~= nil, true, 'encontra faggio')
eq(faggio.model, 'faggio', 'modelo correto')
eq(faggio.price, 70, 'preco faggio')
eq(faggio.deposit, 50, 'caucao faggio')

local inexistente = RentalsRules.FindVehicle(RentalsConfig, 'invalido')
eq(inexistente, nil, 'veiculo inexistente retorna nil')

-- 2. Busca de estações
local pinkCage = RentalsRules.FindStation(RentalsConfig, 'pink_cage')
eq(pinkCage ~= nil, true, 'encontra estacao pink_cage')
eq(pinkCage.label:find('Pink Cage') ~= nil, true, 'label pink cage')

local estacaoInvalida = RentalsRules.FindStation(RentalsConfig, 'estacao_inexistente')
eq(estacaoInvalida, nil, 'estacao invalida retorna nil')

-- 3. Cálculo de custos
local price, deposit, total = RentalsRules.CalculateTotal(faggio)
eq(price, 70, 'preco 70')
eq(deposit, 50, 'deposito 50')
eq(total, 120, 'total = preco + caucao (120)')

-- 4. Geração de placa
local plate = RentalsRules.GenerateRentalPlate()
eq(plate:sub(1, 4), 'RENT', 'placa comeca com RENT')
eq(#plate, 8, 'placa tem 8 caracteres')

-- 5. Regras de elegibilidade para alugar
local active = {}
eq(RentalsRules.CanRent('char_1', active), true, 'char_1 pode alugar sem aluguel ativo')
active['char_1'] = { plate = plate }
local canRentAgain, err = RentalsRules.CanRent('char_1', active)
eq(canRentAgain, false, 'char_1 nao pode alugar duas vezes')
eq(err, 'already_rented', 'erro already_rented')
eq(RentalsRules.CanRent('char_2', active), true, 'char_2 pode alugar')

-- 6. Boot e execução de server/main.lua
local events = {}
local clientEvents = {}
local registeredExports = {}

_G.source = 1
_G.Locales = {}
dofile('locales/pt-br.lua')
dofile('locales/en-us.lua')

_G.Core = {
	Events = {
		OnNet = function(name, handler)
			events[name] = handler
		end,
		ToServer = function(name, ...) end,
		ToClient = function(name, target, ...)
			clientEvents[#clientEvents + 1] = { name = name, target = target, args = { ... } }
		end
	},
	Players = {
		GetActiveCharacterId = function(src)
			return 'char_1'
		end
	},
	Locale = {
		New = function(opts)
			return function(k) return (opts.locales and opts.locales['pt-BR'] and opts.locales['pt-BR'][k]) or k end
		end,
		GetDefaultLang = function() return 'pt-BR' end
	}
}

_G.exports = setmetatable({
	coe_logging = { Log = function() end },
	coe_notify = { Notify = function() end },
	coe_economy = {
		Debit = function(charId, amount, reason)
			return true
		end,
		Credit = function(charId, amount, reason)
			return true
		end
	}
}, {
	__call = function(_, name, fn)
		registeredExports[name] = fn
	end
})

_G.AddEventHandler = function() end
_G.CreateThread = function() end
_G.GetPlayerPed = function() return 100 end
_G.GetEntityCoords = function() return vector3(318.0, -238.0, 54.0) end
_G.vector3 = function(x, y, z) return { x = x, y = y, z = z } end
_G.CreateVehicleServerSetter = function() return 200 end
_G.DoesEntityExist = function() return true end
_G.SetVehicleNumberPlateText = function() end
_G.SetVehicleDoorsLocked = function() end
_G.NetworkGetNetworkIdFromEntity = function() return 300 end
_G.NetworkGetEntityFromNetworkId = function() return 200 end
_G.DeleteEntity = function() end

dofile('server/main.lua')

eq(type(registeredExports['GetActiveRental']), 'function', 'export GetActiveRental registrado')
eq(registeredExports['GetActiveRental']('char_inexistente'), nil, 'sem aluguel ativo retorna nil')

-- Testa fluxo de aluguel no servidor
eq(type(events['rentals.rent']), 'function', 'handler rentals.rent registrado')
events['rentals.rent']('pink_cage', 'faggio')

local activeRental = registeredExports['GetActiveRental']('char_1')
eq(activeRental ~= nil, true, 'aluguel ativo criado no server')
eq(activeRental.model, 'faggio', 'modelo faggio no aluguel')

-- Testa fluxo de devolucao
eq(type(events['rentals.return']), 'function', 'handler rentals.return registrado')
events['rentals.return']('pink_cage')
eq(registeredExports['GetActiveRental']('char_1'), nil, 'apos devolucao aluguel finalizado')

-- 7. Boot de client/main.lua
_G.BeginTextCommandDisplayHelp = function() end
_G.AddTextComponentSubstringPlayerName = function() end
_G.EndTextCommandDisplayHelp = function() end
_G.AddBlipForCoord = function() return 1 end
_G.SetBlipSprite = function() end
_G.SetBlipDisplay = function() end
_G.SetBlipScale = function() end
_G.SetBlipColour = function() end
_G.SetBlipAsShortRange = function() end
_G.BeginTextCommandSetBlipName = function() end
_G.EndTextCommandSetBlipName = function() end
_G.PlayerPedId = function() return 100 end
_G.GetVehiclePedIsIn = function() return 0 end
_G.GetPedInVehicleSeat = function() return 100 end
_G.GetVehicleNumberPlateText = function() return activeRental.plate end
_G.IsControlJustReleased = function() return false end
_G.Wait = function() end

dofile('client/main.lua')

print('rentals_test: ok')
