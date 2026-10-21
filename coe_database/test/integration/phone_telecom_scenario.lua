dofile([=[coe_database/test/integration/bridge.lua]=])
local assertEqual = Bridge.AssertEqual
Bridge.InstallFiveMStubs()

dofile([=[coe_core/lib/migrations.lua]=])
dofile([=[coe_phone/server/migrations.lua]=])
dofile([=[coe_phone/server/persistence.lua]=])
dofile([=[coe_telecom/server/migrations.lua]=])
dofile([=[coe_telecom/server/persistence.lua]=])

local function rows(sql, parameters)
	local response = Bridge.Query(sql, parameters)
	assert(response.ok, tostring(response.error))
	return response.result
end

local function exec(sql, parameters)
	local response = Bridge.Execute(sql, parameters)
	assert(response.ok, tostring(response.error))
	return response.result
end

-- Schema antigo (antes dos aparelhos) com dados de dois personagens.
local allPhone, allTelecom = PhoneMigrations, TelecomMigrations
PhoneMigrations = { allPhone[1], allPhone[2], allPhone[3] }
TelecomMigrations = { allTelecom[1] }
assertEqual(PhonePersistence.Initialize(), true, 'phone v1-v3')
assertEqual(TelecomPersistence.Initialize(), true, 'telecom v1')
PhoneMigrations, TelecomMigrations = allPhone, allTelecom

exec("INSERT INTO coe_phone_numbers (character_id, number) VALUES (7, '5550007'), (8, '5550008')")
exec("INSERT INTO coe_phone_settings (character_id, data, passcode, updated_at) VALUES (7, '{\"silent\":true}', 'hash7', 100)")
exec("INSERT INTO coe_phone_contacts (character_id, name, number) VALUES (7, 'Oito', '5550008'), (8, 'Sete', '5550007')")
exec("INSERT INTO coe_telecom_lines (character_id, carrier, plan, balance, cycle_start, created_at) VALUES (7, 'coe', 'pre', 500, 1, 1)")
exec("INSERT INTO coe_telecom_invoices (character_id, carrier, plan, period_start, period_end, amount, details, due_at) VALUES (7, 'coe', 'pos', 1, 2, 90, 'x', 3)")
exec("INSERT INTO coe_telecom_usage (character_id, kind, units, cost, created_at) VALUES (7, 'sms', 1, 1, 1)")

for attempt = 1, 2 do
	local ok, errorCode = PhonePersistence.Initialize()
	assertEqual(ok, true, 'phone initialize ' .. attempt .. ' ' .. tostring(errorCode))
	ok, errorCode = TelecomPersistence.Initialize()
	assertEqual(ok, true, 'telecom initialize ' .. attempt .. ' ' .. tostring(errorCode))
end
assertEqual(#rows('SELECT version FROM coe_phone_schema_migrations'), 6, 'phone: 6 migrations')
assertEqual(#rows('SELECT version FROM coe_telecom_schema_migrations'), 2, 'telecom: 2 migrations')

-- Aparelhos legados: um por personagem, com ajustes, rosto e contatos.
local legacy = PhonePersistence.LegacyDevice('7')
assertEqual(legacy.serial, 'MG00000000000007', 'serial migrado')
assertEqual(legacy.passcode, 'hash7', 'senha migrada')
assertEqual(legacy.data, '{"silent":true}', 'ajustes migrados')
assertEqual(tostring(legacy.face_character), '7', 'rosto migrado')
local legacy8 = PhonePersistence.LegacyDevice('8')
assertEqual(legacy8.passcode, nil, 'sem senha')
local sims = PhonePersistence.SimsIn('MG00000000000007')
assertEqual(#sims, 1, 'chip migrado')
assertEqual(sims[1].number, '5550007', 'número do chip')
assertEqual(sims[1].holder, '7', 'titular do chip')
assertEqual(sims[1].slot, 1, 'slot do chip')
assertEqual(sims[1].iccid, '89550000000000000007', 'iccid migrado')
assertEqual(#PhonePersistence.Contacts('MG00000000000007'), 1, 'contatos migrados')
assertEqual(PhonePersistence.HeldNumber('7'), '5550007', 'número do titular')
assertEqual(PhonePersistence.HeldNumber('99'), false, 'sem chip')

-- Vincular ao item.
assertEqual(PhonePersistence.BindDevice('MG00000000000007'), true, 'vincula')
assertEqual(PhonePersistence.BindDevice('MG00000000000007'), false, 'não vincula duas vezes')
assertEqual(PhonePersistence.LegacyDevice('7'), false, 'sem legado depois de vincular')

-- Aparelho novo, chip novo sem titular (nil vira NULL) e troca de chip entre aparelhos.
assertEqual(PhonePersistence.CreateDevice('SNAAAAAAAAAA', 'coe_one', '9'), true, 'cria aparelho')
assertEqual(PhonePersistence.CreateDevice('SNAAAAAAAAAA', 'coe_one', '9'), false, 'serial repetido')
assertEqual(PhonePersistence.CreateSim('89560000000000000001', '5550999', nil, 'SNAAAAAAAAAA', 1), true, 'chip sem titular')
assertEqual(PhonePersistence.CreateSim('89560000000000000002', '5550999', '9', nil, nil), false, 'número repetido')
assertEqual(PhonePersistence.CreateSim('89560000000000000003', '5550998', '9', 'SNAAAAAAAAAA', 1), false, 'slot ocupado')
local anonymous = PhonePersistence.SimByNumber('5550999')
assertEqual(anonymous.holder, nil, 'titular NULL')
assertEqual(anonymous.serial, 'SNAAAAAAAAAA', 'chip no aparelho')
assertEqual(PhonePersistence.InsertSim('89560000000000000001', 'MG00000000000007', 2), false, 'chip já está em outro aparelho')
assertEqual(PhonePersistence.EjectSim('89560000000000000001', 'MG00000000000007'), false, 'não tira de aparelho errado')
assertEqual(PhonePersistence.EjectSim('89560000000000000001', 'SNAAAAAAAAAA'), true, 'tira o chip')
assertEqual(PhonePersistence.Sim('89560000000000000001').serial, nil, 'chip fora')
assertEqual(PhonePersistence.InsertSim('89550000000000000008', 'SNAAAAAAAAAA', 1), false, 'chip de outro aparelho')
assertEqual(PhonePersistence.InsertSim('89560000000000000001', 'MG00000000000007', 1), false, 'slot ocupado no destino')
assertEqual(PhonePersistence.InsertSim('89560000000000000001', 'SNAAAAAAAAAA', 1), true, 'coloca o chip')

-- Ajustes, senha e rosto por aparelho.
assertEqual(PhonePersistence.SavePasscode('SNAAAAAAAAAA', 'h', '{}', 5) ~= nil, true, 'grava senha')
assertEqual(PhonePersistence.SetFace('SNAAAAAAAAAA', '9') ~= nil, true, 'grava rosto')
local device = PhonePersistence.Device('SNAAAAAAAAAA')
assertEqual(device.passcode, 'h', 'senha')
assertEqual(tostring(device.face_character), '9', 'rosto')
assertEqual(PhonePersistence.SavePasscode('SNAAAAAAAAAA', false, '{}', 6) ~= nil, true, 'remove senha')
assertEqual(PhonePersistence.SetFace('SNAAAAAAAAAA', nil) ~= nil, true, 'remove rosto')
device = PhonePersistence.Device('SNAAAAAAAAAA')
assertEqual(device.passcode, nil, 'senha removida')
assertEqual(device.face_character, nil, 'rosto removido')
assertEqual(PhonePersistence.Device('SNZZZZZZZZZZ'), false, 'aparelho inexistente')

-- Contatos por aparelho.
assertEqual(PhonePersistence.AddContact('SNAAAAAAAAAA', 'Sete', '5550007') ~= nil, true, 'contato')
assertEqual(PhonePersistence.CountContacts('SNAAAAAAAAAA'), 1, 'conta contatos')
assertEqual(type(PhonePersistence.ContactByNumber('SNAAAAAAAAAA', '5550007')), 'number', 'contato por número')

-- Fotos por aparelho: uso, páginas, vizinhos e remoção só no próprio aparelho.
local image, thumb = 'data:image/jpeg;base64,' .. string.rep('A', 4000), 'data:image/jpeg;base64,AAAA'
local photoIds = {}
for index = 1, 3 do
	local inserted = PhonePersistence.AddPhoto('SNAAAAAAAAAA', '7', image, thumb, 100 + index)
	photoIds[index] = tonumber(inserted.insertId)
end
assertEqual(PhonePersistence.AddPhoto('SNBBBBBBBBBB', nil, image, thumb, 200) ~= nil, true, 'foto sem personagem')
local usage = PhonePersistence.PhotoUsage('SNAAAAAAAAAA')
assertEqual(usage.count, 3, 'fotos do aparelho')
assertEqual(usage.bytes, 3 * (#image + #thumb), 'bytes do aparelho')
local page = PhonePersistence.Photos('SNAAAAAAAAAA', nil, 2)
assertEqual(#page, 2, 'primeira página')
assertEqual(tonumber(page[1].id), photoIds[3], 'mais recente primeiro')
assertEqual(#PhonePersistence.Photos('SNAAAAAAAAAA', tonumber(page[2].id), 2), 1, 'segunda página')
local middle = PhonePersistence.Photo('SNAAAAAAAAAA', photoIds[2])
assertEqual(middle.image, image, 'foto inteira')
assertEqual(tonumber(middle.newer), photoIds[3], 'vizinha mais nova')
assertEqual(tonumber(middle.older), photoIds[1], 'vizinha mais antiga')
assertEqual(PhonePersistence.Photo('SNBBBBBBBBBB', photoIds[2]), false, 'foto de outro aparelho')
assertEqual(tonumber(PhonePersistence.DeletePhoto('SNBBBBBBBBBB', photoIds[2]).affectedRows), 0, 'não apaga de outro aparelho')
assertEqual(tonumber(PhonePersistence.DeletePhoto('SNAAAAAAAAAA', photoIds[2]).affectedRows), 1, 'apaga a foto')
assertEqual(PhonePersistence.PhotoUsage('SNAAAAAAAAAA').count, 2, 'uso após apagar')
assertEqual(PhonePersistence.PhotoUsage('SNZZZZZZZZZZ').bytes, 0, 'aparelho sem fotos')

-- Telecom: linha antiga adotada pelo número, com faturas e extrato.
assertEqual(TelecomPersistence.Line('5550007'), false, 'linha ainda sem número')
assertEqual(TelecomPersistence.Adopt('5550007', '7'), true, 'adota a linha antiga')
local line = TelecomPersistence.Line('5550007')
assertEqual(line.number, '5550007', 'linha pelo número')
assertEqual(line.holder, '7', 'titular da linha')
assertEqual(line.balance, 500, 'saldo preservado')
assertEqual(TelecomPersistence.OpenInvoices('5550007'), 1, 'fatura adotada')
assertEqual(#TelecomPersistence.Usage('5550007', 10), 1, 'extrato adotado')
assertEqual(TelecomPersistence.Adopt('5550008', '8'), false, 'nada para adotar')
assertEqual(TelecomPersistence.CreateLine('5550999', nil, 'coe', 'pre', 0, 10), true, 'linha sem titular')
assertEqual(TelecomPersistence.Line('5550999').holder, nil, 'titular NULL na linha')
assertEqual(TelecomPersistence.CreateLine('5550999', '9', 'coe', 'pre', 0, 10), false, 'número único')
assertEqual(TelecomPersistence.AddUsage('5550999', nil, 'sms', nil, 1, 0, 11) ~= nil, true, 'uso sem titular')
local anonymousLine = TelecomPersistence.Line('5550999')
assertEqual(type(TelecomPersistence.AddInvoice(anonymousLine, 20, 0, 'x', 30)), 'number', 'fatura sem titular')

Bridge.Done()
