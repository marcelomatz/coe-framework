dofile([=[coe_database/test/integration/bridge.lua]=])
local assertEqual = Bridge.AssertEqual
Bridge.InstallFiveMStubs()

dofile([=[coe_core/lib/migrations.lua]=])
dofile([=[coe_garage/adapters/migrations.lua]=])
dofile([=[coe_garage/adapters/persistence.lua]=])
dofile([=[coe_mobile/server/migrations.lua]=])
dofile([=[coe_mobile/server/persistence.lua]=])

-- 1. Migrações idempotentes
for attempt = 1, 2 do
	local ok, err = GaragePersistence.Initialize()
	assertEqual(ok, true, 'garage initialize ' .. attempt .. ' ' .. tostring(err))
	ok, err = MobilePersistence.Initialize()
	assertEqual(ok, true, 'mobile initialize ' .. attempt .. ' ' .. tostring(err))
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

Bridge.Done()
