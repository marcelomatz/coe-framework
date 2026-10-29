dofile([=[coe_database/test/integration/bridge.lua]=])
local assertEqual = Bridge.AssertEqual
Bridge.InstallFiveMStubs()

dofile([=[coe_core/lib/migrations.lua]=])
dofile([=[coe_core/lib/logger.lua]=])
dofile([=[coe_needs/adapters/migrations.lua]=])
dofile([=[coe_needs/adapters/persistence.lua]=])

-- 1. Migrações idempotentes (antes desta correção o Initialize nunca ficava pronto)
for attempt = 1, 2 do
	local ok, err = NeedsPersistence.Initialize()
	assertEqual(ok, true, 'needs initialize ' .. attempt .. ' ' .. tostring(err))
end
local versions = Bridge.Query('SELECT version FROM coe_needs_schema_migrations ORDER BY version')
assertEqual(#versions.result, 2, 'duas migrations registradas')

-- 2. Salvar e carregar estado de um personagem
assertEqual(NeedsPersistence.Load('char:1'), false, 'personagem sem estado salvo')
assertEqual(NeedsPersistence.Save('char:1', { hunger = 80, thirst = 70, stress = 10, alcohol = 1, drugs = 0 }), true, 'estado salvo')
local state = NeedsPersistence.Load('char:1')
assertEqual(state.hunger, 80, 'fome persistida')
assertEqual(state.alcohol, 1, 'álcool persistido')

-- 3. Salvamento periódico em transação
assertEqual(NeedsPersistence.SaveMany({
	{ 'char:1', { hunger = 50, thirst = 50, stress = 20 } },
	{ 'char:2', { hunger = 90, thirst = 95, stress = 0 } }
}), true, 'lote salvo')
assertEqual(NeedsPersistence.Load('char:1').hunger, 50, 'lote atualizou char:1')
assertEqual(NeedsPersistence.Load('char:2').thirst, 95, 'lote criou char:2')

Bridge.Done()
