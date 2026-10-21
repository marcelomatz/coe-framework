dofile('../coe_vehicles/config.lua')
dofile('../coe_vehicles/shared/plate.lua')
dofile('../coe_vehicles/shared/mileage.lua')
dofile('../coe_vehicles/server/registry.lua')

local function assertEqual(actual, expected, message)
	if actual ~= expected then
		error(('%s: expected %s, got %s'):format(message, tostring(expected), tostring(actual)))
	end
end

-- placa
assertEqual(VehiclePlate.Normalize('  ab 12  '), 'AB 12', 'normaliza e remove bordas')
assertEqual(select(2, VehiclePlate.Normalize('')), 'invalid_plate', 'vazia')
assertEqual(select(2, VehiclePlate.Normalize('123456789')), 'invalid_plate', 'mais de 8')
assertEqual(select(2, VehiclePlate.Normalize('AB-12')), 'invalid_plate', 'caractere inválido')
assertEqual(select(2, VehiclePlate.Normalize(12)), 'invalid_plate', 'tipo inválido')
local generated = VehiclePlate.Generate('NNLLLNNN', function() return 1 end)
assertEqual(generated, '00AAA000', 'gera pelo padrão')
assertEqual(VehiclePlate.Generate('LL NN', function() return 2 end), 'BB 11', 'literais preservados')
assertEqual(select(2, VehiclePlate.Generate('NNNNNNNNN')), 'invalid_pattern', 'padrão longo')

-- metros
assertEqual(VehicleMileage.NormalizeMeters('1500.9'), 1500, 'trunca para metros inteiros')
assertEqual(select(2, VehicleMileage.NormalizeMeters(-1)), 'invalid_mileage', 'negativo')
assertEqual(select(2, VehicleMileage.NormalizeMeters(0 / 0)), 'invalid_mileage', 'NaN')
assertEqual(select(2, VehicleMileage.NormalizeMeters(math.huge)), 'invalid_mileage', 'infinito')
assertEqual(select(2, VehicleMileage.NormalizeMeters('x')), 'invalid_mileage', 'texto')
assertEqual(VehicleMileage.ToUnit(12345, 'km'), 12.3, 'km com uma casa')
assertEqual(VehicleMileage.ToUnit(1609, 'mph'), 1.0, 'milhas com uma casa')

-- amostrador
local sampler = VehicleMileage.NewSampler(0.5, 400)
sampler.Step(0, 0, 0)
sampler.Step(30, 40, 0)
assertEqual(sampler.Take(), 50, 'distância 3-4-5')
sampler.Step(30.1, 40, 0)
assertEqual(sampler.Take(), 0, 'jitter ignorado')
sampler.Step(5000, 0, 0)
assertEqual(sampler.Take(), 0, 'teleporte ignorado')
sampler.Step(5010.7, 0, 0)
assertEqual(sampler.Take(), 10, 'parte inteira')
sampler.Step(5011.4, 0, 0)
assertEqual(sampler.Take(), 1, 'fração anterior (0,7) somada a 0,7')

-- orçamento
local limits = { MaxSpeedMetersPerSecond = 100, InitialCreditSeconds = 10, MaxCreditSeconds = 20 }
local budget = VehicleMileage.NewBudget(limits)
assertEqual(budget.Consume(900, 0), 900, 'dentro do crédito inicial (1000)')
assertEqual(select(2, budget.Consume(500, 0)), 'implausible_delta', 'excede o crédito restante')
assertEqual(budget.Consume(500, 5000), 500, 'crédito cresce com o tempo')
assertEqual(select(2, budget.Consume(-1, 6000)), 'invalid_delta', 'negativo')
assertEqual(select(2, budget.Consume('x', 6000)), 'invalid_delta', 'texto')
assertEqual(select(2, budget.Consume(1900, 6000)), 'implausible_delta', 'spam não cria crédito')
assertEqual(select(2, budget.Consume(2100, 3600000)), 'implausible_delta', 'crédito tem teto')
assertEqual(budget.Consume(2000, 7200000), 2000, 'teto permite o máximo')

-- registro (persistência falsa)
local rows, nextId, nowValue = {}, 0, 0
local persistence
persistence = {
	Insert = function(record)
		for _, row in pairs(rows) do
			if row.plate == record.plate then
				return nil, 'plate_taken'
			end
		end
		nextId = nextId + 1
		local id = tostring(nextId)
		rows[id] = { id = id, ownerCharacterId = record.ownerCharacterId, model = record.model,
			plate = record.plate, mileage = record.mileage, state = record.state }
		return id
	end,
	FindById = function(id)
		local row = rows[id]
		if not row then return nil, 'vehicle_not_found' end
		return { id = row.id, ownerCharacterId = row.ownerCharacterId, model = row.model,
			plate = row.plate, mileage = row.mileage, state = row.state }
	end,
	FindByPlate = function(plate)
		for _, row in pairs(rows) do
			if row.plate == plate then return persistence.FindById(row.id) end
		end
		return nil, 'vehicle_not_found'
	end,
	CountByOwner = function(characterId)
		local count = 0
		for _, row in pairs(rows) do
			if row.ownerCharacterId == characterId then count = count + 1 end
		end
		return count
	end,
	ListByOwner = function() return {} end,
	SetMileage = function(id, meters) rows[id].mileage = meters return true end,
	SetState = function(id, state) rows[id].state = state return true end,
	UpdateMileageBatch = function(entries)
		for _, entry in ipairs(entries) do rows[entry.id].mileage = entry.mileage end
		return true
	end
}

local events = {}
local settings = { MaxVehiclesPerCharacter = 2, PlatePattern = 'NNLLLNNN', PlateGenerationAttempts = 3,
	FlushBatchSize = 2, Mileage = limits }
local registry = VehicleRegistry.New({
	persistence = persistence,
	config = settings,
	now = function() return nowValue end,
	random = function() return 1 end,
	cacheTtlMs = 1000,
	audit = function(name, context) events[#events + 1] = { name = name, context = context } end
})

local vehicle = registry.Create({ characterId = '7', model = 'Adder' })
assertEqual(vehicle.model, 'adder', 'modelo em minúsculas')
assertEqual(vehicle.plate, '00AAA000', 'placa gerada')
assertEqual(vehicle.mileage, 0, 'novo veículo começa em 0')
assertEqual(events[1].name, 'vehicle_created', 'criação auditada')

-- colisão de placa gerada esgota as tentativas
local _, err = registry.Create({ characterId = '7', model = 'adder' })
assertEqual(err, 'plate_generation_failed', 'placas colidindo')
_, err = registry.Create({ characterId = '7', model = 'adder', plate = '00AAA000' })
assertEqual(err, 'plate_taken', 'placa informada duplicada')
_, err = registry.Create({ characterId = '7', model = 'adder bad' })
assertEqual(err, 'invalid_model', 'modelo inválido')
_, err = registry.Create({ characterId = 'x', model = 'adder' })
assertEqual(err, 'invalid_character_id', 'dono inválido')
_, err = registry.Create({ characterId = '7', model = 'adder', mileage = -5 })
assertEqual(err, 'invalid_mileage', 'mileage inicial inválido')
local used = registry.Create({ characterId = '7', model = 'sultan', plate = 'USADO1', mileage = 85000 })
assertEqual(used.mileage, 85000, 'usado com quilometragem inicial')
_, err = registry.Create({ characterId = '7', model = 'sultan', plate = 'USADO2' })
assertEqual(err, 'vehicle_limit_reached', 'limite por personagem')
local stock = registry.Create({ model = 'sultan', plate = 'ESTOQUE' })
assertEqual(stock.ownerCharacterId, nil, 'veículo sem dono')

-- reportes e flush
assertEqual(registry.ReportMileage(vehicle.id, 500, 0), 500, 'reporte aceito')
assertEqual(select(2, registry.ReportMileage(vehicle.id, 5000, 1000)), 'implausible_delta', 'reporte implausível')
assertEqual(registry.PendingCount(), 1, 'pendente')
assertEqual(rows[vehicle.id].mileage, 0, 'ainda não gravado')
assertEqual(registry.Flush(), true, 'flush ok')
assertEqual(rows[vehicle.id].mileage, 500, 'gravado em lote')
assertEqual(registry.PendingCount(), 0, 'sem pendências')

-- correção administrativa grava na hora e audita
assertEqual(registry.SetMileage(vehicle.id, 123456, 'coe_admin'), 123456, 'SetMileage')
assertEqual(rows[vehicle.id].mileage, 123456, 'persistido na hora')
local last = events[#events]
assertEqual(last.name, 'vehicle_mileage_set', 'correção auditada')
assertEqual(last.context.previous_mileage, 500, 'valor anterior no log')
assertEqual(select(2, registry.SetMileage(vehicle.id, -1, 'x')), 'invalid_mileage', 'SetMileage inválido')
assertEqual(select(2, registry.SetMileage('99', 10, 'x')), 'vehicle_not_found', 'veículo inexistente')

-- cache: ocioso sai, fixado permanece
nowValue = 5000
registry.Pin(vehicle.id)
registry.Flush()
assertEqual(registry.Get(vehicle.id).mileage, 123456, 'fixado permanece')
assertEqual(registry.GetByPlate('uSaDo1').id, used.id, 'busca por placa normalizada')

-- estados
assertEqual(registry.SetState(vehicle.id, 'out'), true, 'estado válido')
assertEqual(select(2, registry.SetState(vehicle.id, 'lost')), 'invalid_state', 'estado inválido')

print('coe_vehicles: ok')
