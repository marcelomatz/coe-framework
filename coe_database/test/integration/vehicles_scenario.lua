dofile([=[coe_database/test/integration/bridge.lua]=])
local assertEqual = Bridge.AssertEqual
Bridge.InstallFiveMStubs()

dofile([=[coe_core/lib/migrations.lua]=])
dofile([=[coe_vehicle_catalog/server/migrations.lua]=])
dofile([=[coe_vehicle_catalog/server/persistence.lua]=])
dofile([=[coe_vehicles/server/migrations.lua]=])
dofile([=[coe_vehicles/server/persistence.lua]=])

-- 1. Migrações idempotentes dos dois recursos
for attempt = 1, 2 do
	local ok, err = VehicleCatalogPersistence.Initialize()
	assertEqual(ok, true, 'catalog initialize ' .. attempt .. ' ' .. tostring(err))
	ok, err = VehiclesPersistence.Initialize()
	assertEqual(ok, true, 'vehicles initialize ' .. attempt .. ' ' .. tostring(err))
end

local catalogVersions = Bridge.Query('SELECT version, name FROM coe_vehicle_catalog_schema_migrations')
assertEqual(#catalogVersions.result, 1, 'catalog migrations recorded')
local vehicleVersions = Bridge.Query('SELECT version, name FROM coe_vehicles_schema_migrations')
assertEqual(#vehicleVersions.result, 2, 'vehicles migrations recorded')

-- 2. Catálogo: overrides de veículos da concessionária
assertEqual(VehicleCatalogPersistence.SaveOverride('sultan', { price = 45000, stock = 3, category = 'sedans' }), true, 'catalog override saved')
local overrides = VehicleCatalogPersistence.LoadOverrides()
assertEqual(overrides.sultan ~= nil, true, 'sultan override loaded')
assertEqual(overrides.sultan.price, 45000, 'sultan price matches')
assertEqual(overrides.sultan.stock, 3, 'sultan stock matches')

-- 3. Criação de veículo no banco e integridade de placa única
local vehicleId, err = VehiclesPersistence.Insert({
	ownerCharacterId = '10',
	model = 'sultan',
	plate = 'COE9901',
	mileage = 0,
	state = 'stored'
})
assertEqual(type(vehicleId), 'string', 'vehicle inserted with id ' .. tostring(vehicleId))

local duplicateId, duplicateErr = VehiclesPersistence.Insert({
	ownerCharacterId = '11',
	model = 'banshee',
	plate = 'COE9901',
	mileage = 0,
	state = 'stored'
})
assertEqual(duplicateId, nil, 'duplicate plate insertion rejected')
assertEqual(duplicateErr, 'plate_taken', 'duplicate plate error code')

-- 4. Buscas por ID, placa e lista por dono
local vehicle = VehiclesPersistence.FindById(vehicleId)
assertEqual(vehicle.model, 'sultan', 'model matches')
assertEqual(vehicle.plate, 'COE9901', 'plate matches')
assertEqual(vehicle.ownerCharacterId, '10', 'owner matches')
assertEqual(vehicle.mileage, 0, 'initial mileage is 0')
assertEqual(vehicle.state, 'stored', 'initial state is stored')

local byPlate = VehiclesPersistence.FindByPlate('COE9901')
assertEqual(byPlate.id, vehicleId, 'find by plate returns same vehicle')

local ownerList = VehiclesPersistence.ListByOwner('10', 10)
assertEqual(#ownerList, 1, 'owner has 1 vehicle')
assertEqual(ownerList[1].id, vehicleId, 'vehicle id in list matches')
assertEqual(VehiclesPersistence.CountByOwner('10'), 1, 'count by owner matches')

-- 5. Gestão cruzada de chaves de veículos
assertEqual(VehiclesPersistence.AddKey(vehicleId, '10', 'admin'), true, 'owner key added')
assertEqual(VehiclesPersistence.AddKey(vehicleId, '20', '10'), true, 'friend key added')

local vehicleKeys = VehiclesPersistence.ListKeysByVehicle(vehicleId)
assertEqual(#vehicleKeys, 2, 'two keys exist for vehicle')

local charKeys = VehiclesPersistence.ListKeysByCharacter('20')
assertEqual(#charKeys, 1, 'character 20 has 1 key')
assertEqual(charKeys[1], vehicleId, 'key corresponds to vehicleId')

assertEqual(VehiclesPersistence.RemoveKey(vehicleId, '20'), true, 'friend key removed')
vehicleKeys = VehiclesPersistence.ListKeysByVehicle(vehicleId)
assertEqual(#vehicleKeys, 1, 'only owner key remains after removal')

-- 6. Rodagem e Atualização de Odômetro (mileage_m)
assertEqual(VehiclesPersistence.SetMileage(vehicleId, 15000), true, 'mileage updated to 15km')
vehicle = VehiclesPersistence.FindById(vehicleId)
assertEqual(vehicle.mileage, 15000, 'persisted mileage matches')

assertEqual(VehiclesPersistence.SetState(vehicleId, 'out'), true, 'state set to out')
assertEqual(VehiclesPersistence.FindById(vehicleId).state, 'out', 'state is out')

assertEqual(VehiclesPersistence.ResetOutState(), true, 'server reboot resets out vehicles to stored')
assertEqual(VehiclesPersistence.FindById(vehicleId).state, 'stored', 'state reset to stored')

Bridge.Done()
