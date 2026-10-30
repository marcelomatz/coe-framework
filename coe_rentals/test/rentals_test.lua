-- Testes unitários puros do coe_rentals
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

-- IsNear aceita vetores do FiveM (no CfxLua o tipo é 'vector3', não 'table'/'userdata'): simulado com metatable.
local function fakeVector(x, y, z)
	return setmetatable({}, { __index = { x = x, y = y, z = z } })
end
eq(RentalsRules.IsNear(fakeVector(328.5, -218.0, 54.2), { x = 328.0, y = -218.0, z = 54.0 }, 6.0), true, 'vetor perto do balcão')
eq(RentalsRules.IsNear(fakeVector(340.0, -218.0, 54.0), { x = 328.0, y = -218.0, z = 54.0 }, 6.0), false, 'vetor longe do balcão')
eq(RentalsRules.IsNear('texto', { x = 0, y = 0, z = 0 }, 6.0), false, 'valor inválido é recusado')
eq(RentalsRules.IsNear(nil, { x = 0, y = 0, z = 0 }, 6.0), false, 'sem coordenadas é recusado')

-- Catálogo por estação
local catalog = { Vehicles = { { model = 'tribike' }, { model = 'faggio' }, { model = 'panto' } } }
eq(#RentalsRules.VehiclesFor(catalog, { id = 'a' }), 3, 'sem lista na estação: catálogo inteiro')
local limited = { id = 'b', vehicles = { 'TriBike', 'panto' } }
eq(#RentalsRules.VehiclesFor(catalog, limited), 2, 'estação limita o catálogo')
eq(RentalsRules.FindVehicleAt(catalog, limited, 'panto') ~= nil, true, 'modelo oferecido na estação')
eq(RentalsRules.FindVehicleAt(catalog, limited, 'faggio'), nil, 'modelo fora da estação é recusado')
eq(RentalsRules.FindVehicleAt(catalog, limited, nil), nil, 'modelo inválido')

-- Estações (cadastro do painel)
dofile('domain/stations.lua')
local station, stationError = RentalsStations.Normalize({
	id = 'centro', label = 'Centro', ped = { x = 1, y = 2, z = 3, heading = 400, model = 'A_M_Y_Business_02' },
	spawns = { { x = 5, y = 5, z = 3, h = 10 }, { x = 9, y = 5, z = 3, h = 10 } },
	returnZone = { x = 5, y = 5, z = 3 }, vehicles = { 'Panto', 'panto' }
})
eq(stationError, nil, 'estação válida')
eq(station.ped.h, 40.0, 'heading normalizado')
eq(station.ped.model, 'a_m_y_business_02', 'modelo do NPC em minúsculas')
eq(#station.vehicles, 1, 'modelos sem repetição')
eq(station.returnZone.radius, 5.0, 'raio padrão da devolução')
eq(select(2, RentalsStations.Normalize({ id = 'A B', label = 'x' })), 'invalid_id', 'id inválido')
eq(select(2, RentalsStations.Normalize({ id = 'ok', label = 'x', ped = { x = 1, y = 2, z = 3 }, spawns = {}, returnZone = { x = 1, y = 1, z = 1 } })), 'invalid_spawns', 'sem ponto de retirada')
local legacy = RentalsStations.FromConfig({ id = 'old', label = 'Antiga', coords = { x = 1, y = 2, z = 3 }, spawn = { x = 4, y = 5, z = 6, h = 90 }, returnZone = { x = 4, y = 5, z = 6, radius = 5 } })
eq(legacy.ped.x, 1, 'config antigo: balcão vira atendente')
eq(legacy.spawns[1].h, 90, 'config antigo: spawn vira ponto de retirada')
local free = RentalsStations.FreeSpawn(station, function(point) return point.x == 5 end)
eq(free.x, 9, 'pula o ponto ocupado')
eq(RentalsStations.FreeSpawn(station, function() return true end), nil, 'todos ocupados')

print('rentals_test: ok')
