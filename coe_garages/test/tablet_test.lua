dofile('../coe_garages/config.lua')
dofile('../coe_garages/server/rules.lua')
dofile('../coe_garages/server/tablet.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end

local callerName = 'coe_tablet'
local isReady = true
local characters = { [1] = '10', [2] = '11' }
local vehiclesByOwner = {
	['10'] = {
		{ id = 'v1', model = 'sultan', plate = 'ABC1D23', state = 'stored', mileage = 15800 },
		{ id = 'v2', model = 'bati', plate = 'MOTO123', state = 'out', mileage = 3200 },
		{ id = 'v3', model = 'adder', plate = 'PUB0001', state = 'stored', mileage = 500 }
	},
	['11'] = {
		{ id = 'v9', model = 'zentorno', plate = 'OUTRO99', state = 'stored', mileage = 90000 }
	}
}
local slotsByOwner = {
	['10'] = { v1 = 'legion' }
}
local garages = {
	legion = { id = 'legion', label = 'Praça da Legião', spots = { { x = 215.0, y = -810.0, z = 30.0 } } }
}
local coordsByVehicle = {
	v2 = { x = -42.5, y = -1100.0, z = 26.0 }
}
local catalog = {
	sultan = { name = 'Karin Sultan', type = 'automobile' },
	bati = { name = 'Pegassi Bati 801', type = 'bike' },
	adder = { name = 'Truffade Adder', type = 'automobile' }
}

local deps = {
	caller = function() return callerName end,
	ready = function() return isReady end,
	characterOf = function(playerId) return characters[playerId] end,
	ownedVehicles = function(characterId) return vehiclesByOwner[characterId] end,
	slotsOf = function(characterId) return slotsByOwner[characterId] end,
	vehicleView = function(record)
		local info = catalog[record.model]
		return {
			id = record.id, model = record.model, name = info and info.name or record.model,
			plate = record.plate, state = record.state, class = GaragesRules.ClassOf(GaragesConfig, info)
		}
	end,
	garage = function(id) return garages[id] end,
	entityCoords = function(id) return coordsByVehicle[id] end
}

-- Caller restrito ao coe_tablet, estado ready, appId, ação e personagem
callerName = 'coe_admin'
eq(GaragesTablet.Call(deps, 1, 'vehicles', 'list').error, 'forbidden', 'caller fora do coe_tablet')
callerName = 'coe_tablet'
eq(GaragesTablet.Call(deps, 1, 'bank', 'list').error, 'forbidden', 'appId errado')

isReady = false
eq(GaragesTablet.Call(deps, 1, 'vehicles', 'list').error, 'not_ready', 'antes do ready')
isReady = true

eq(GaragesTablet.Call(deps, 1, 'vehicles', 'spawn').error, 'unknown_action', 'acao desconhecida')
eq(GaragesTablet.Call(deps, 99, 'vehicles', 'list').error, 'no_character', 'sem personagem')

-- Apenas veículos do próprio personagem, ordenados por nome, com km, garagem e coordenadas
local res = GaragesTablet.Call(deps, 1, 'vehicles', 'list')
eq(res.ok, true, 'list ok')
eq(#res.vehicles, 3, 'apenas os 3 veiculos do personagem 10 (nao inclui v9 do 11)')

-- Ordem alfabética por name: Karin Sultan, Pegassi Bati 801, Truffade Adder
local sultan, bati, adder = res.vehicles[1], res.vehicles[2], res.vehicles[3]
eq(sultan.id, 'v1', 'primeiro: Karin Sultan')
eq(sultan.km, 15, 'km truncado em milhares')
eq(sultan.where, 'Praça da Legião', 'garagem onde esta guardado')
eq(sultan.x, 215.0, 'x da vaga da garagem')
eq(sultan.y, -810.0, 'y da vaga da garagem')

eq(bati.id, 'v2', 'segundo: Pegassi Bati 801')
eq(bati.class, 'bike', 'classe moto')
eq(bati.km, 3, 'km moto')
eq(bati.x, -42.5, 'x da entidade na rua')
eq(bati.y, -1100.0, 'y da entidade na rua')

eq(adder.id, 'v3', 'terceiro: Truffade Adder')
eq(adder.km, 0, 'menos de 1000m = 0 km')
eq(adder.where, 'Qualquer garagem pública', 'sem vaga fixa')
eq(adder.x, nil, 'sem coordenadas quando em qualquer publica')

local res2 = GaragesTablet.Call(deps, 2, 'vehicles', 'list')
eq(res2.ok, true, 'list dono 11 ok')
eq(#res2.vehicles, 1, 'dono 11 ve apenas seu veiculo')
eq(res2.vehicles[1].id, 'v9', 'veiculo do dono 11')

print('garages tablet_test ok')
