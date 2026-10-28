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

print('rentals_test: ok')
