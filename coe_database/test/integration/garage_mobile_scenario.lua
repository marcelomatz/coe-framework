dofile([=[coe_database/test/integration/bridge.lua]=])
local assertEqual = Bridge.AssertEqual
Bridge.InstallFiveMStubs()

dofile([=[coe_core/lib/migrations.lua]=])
dofile([=[coe_garage/adapters/migrations.lua]=])
dofile([=[coe_garage/adapters/persistence.lua]=])
dofile([=[coe_mobile/server/migrations.lua]=])
dofile([=[coe_mobile/server/persistence.lua]=])
dofile([=[coe_rentals/server/migrations.lua]=])
dofile([=[coe_rentals/server/persistence.lua]=])

-- 1. Migrações idempotentes
for attempt = 1, 2 do
	local ok, err = GaragePersistence.Initialize()
	assertEqual(ok, true, 'garage initialize ' .. attempt .. ' ' .. tostring(err))
	ok, err = MobilePersistence.Initialize()
	assertEqual(ok, true, 'mobile initialize ' .. attempt .. ' ' .. tostring(err))
	ok, err = RentalsPersistence.Initialize()
	assertEqual(ok, true, 'rentals initialize ' .. attempt .. ' ' .. tostring(err))
end

-- 2. Garagens cadastradas pela staff (JSON) e vagas fixas por veículo
assertEqual(GaragePersistence.SaveGarage({ id = 'central', label = 'Central', spots = { { id = 'v1', x = 1, y = 2, z = 3 } } }), true, 'garagem salva')
assertEqual(GaragePersistence.SaveGarage({ id = 'central', label = 'Central Nova', spots = {} }), true, 'garagem atualizada (upsert)')
local central
for _, garage in ipairs(GaragePersistence.ListGarages()) do
	if garage.id == 'central' then
		central = garage
	end
end
assertEqual(central ~= nil, true, 'garagem central listada')
assertEqual(central.label, 'Central Nova', 'label atualizado (upsert)')

assertEqual(GaragePersistence.SaveSlot('101', 'central', '7', 'car'), true, 'vaga salva')
assertEqual(GaragePersistence.SaveSlot('101', 'norte', '7', 'car'), true, 'vaga movida (upsert por veículo)')
assertEqual(GaragePersistence.GetSlot('101'), 'norte', 'vaga atual')
assertEqual(GaragePersistence.SlotsOf('7')['101'], 'norte', 'vagas por personagem')
assertEqual(GaragePersistence.RemoveSlot('101'), true, 'vaga removida')
assertEqual(GaragePersistence.GetSlot('101'), nil, 'sem vaga')
assertEqual(GaragePersistence.DeleteGarage('central'), true, 'garagem removida')

-- 3. Telefone: número único por personagem, contatos e mensagens
local numberA = MobilePersistence.EnsureNumber('7', function() return '5550001' end)
local numberB = MobilePersistence.EnsureNumber('8', function() return '5550002' end)
assertEqual(numberA, '5550001', 'número do personagem 7')
assertEqual(MobilePersistence.EnsureNumber('7', function() return '5559999' end), '5550001', 'número é estável')
assertEqual(MobilePersistence.CharacterOf(numberB), '8', 'dono do número')

-- 4. PIX pelo ID de cidadão: personagem ativo pelo state_id (tabela do coe_core reduzida às colunas usadas).
assertEqual(Bridge.Execute([[
	CREATE TABLE IF NOT EXISTS coe_characters (
		character_id BIGINT UNSIGNED NOT NULL PRIMARY KEY,
		state_id VARCHAR(16) NULL,
		archived_at DATETIME(3) NULL
	)
]], {}).ok, true, 'tabela de personagens para o cenário')
assertEqual(Bridge.Execute('INSERT INTO coe_characters (character_id, state_id, archived_at) VALUES (?, ?, NULL), (?, ?, NOW(3))',
	{ 7, 'AB12CD34', 9, 'ZZ99ZZ99' }).ok, true, 'personagens inseridos')
assertEqual(MobilePersistence.CharacterByStateId('AB12CD34'), '7', 'personagem pelo ID de cidadão')
assertEqual(MobilePersistence.CharacterByStateId('ZZ99ZZ99'), false, 'personagem arquivado não recebe PIX')
assertEqual(MobilePersistence.CharacterByStateId('NAOEXISTE'), false, 'ID desconhecido')

-- 5. Estações de aluguel (JSON) cadastradas pelo painel
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
