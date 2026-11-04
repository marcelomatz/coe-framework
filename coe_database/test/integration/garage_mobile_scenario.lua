dofile([=[coe_database/test/integration/bridge.lua]=])
local assertEqual = Bridge.AssertEqual
Bridge.InstallFiveMStubs()

dofile([=[coe_core/lib/migrations.lua]=])
dofile([=[coe_rentals/server/migrations.lua]=])
dofile([=[coe_rentals/server/persistence.lua]=])

-- 1. Migrações idempotentes
for attempt = 1, 2 do
	local ok, err = RentalsPersistence.Initialize()
	assertEqual(ok, true, 'rentals initialize ' .. attempt .. ' ' .. tostring(err))
end

-- 2. Estações de aluguel (JSON) cadastradas pelo painel
local station = {
	id = 'pink_cage', label = 'Pink Cage', enabled = true,
	ped = { x = 328.0, y = -218.0, z = 54.0, h = 160.0 },
	spawns = { { x = 323.5, y = -226.5, z = 54.0, h = 160.0 }, { x = 320.1, y = -229.2, z = 54.0, h = 160.0 } },
	returnZone = { x = 323.5, y = -226.5, z = 54.0, radius = 5.0 },
	vehicles = { 'faggio' },
	blip = { enabled = true, sprite = 226, color = 3, scale = 0.7 }
}
assertEqual(RentalsPersistence.SaveStation(station), true, 'estação salva')
station.label = 'Pink Cage (Hotel)'
assertEqual(RentalsPersistence.SaveStation(station), true, 'estação atualizada (upsert)')
local stations = RentalsPersistence.ListStations()
assertEqual(#stations, 1, 'uma estação')
assertEqual(stations[1].id, 'pink_cage', 'id vem da coluna')
assertEqual(stations[1].label, 'Pink Cage (Hotel)', 'label atualizado')
assertEqual(#stations[1].spawns, 2, 'pontos de retirada preservados no JSON')
assertEqual(RentalsPersistence.DeleteStation('pink_cage'), true, 'estação removida')
assertEqual(#RentalsPersistence.ListStations(), 0, 'sem estações')

Bridge.Done()
