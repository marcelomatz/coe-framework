-- Upgrade do telefone básico (coe_mobile) para o smartphone: regras puras e a execução contra um banco simulado
-- (só as consultas do upgrade). Número mantido, número já de outra pessoa (sorteia outro), personagem que já tinha
-- linha aqui, contatos, conversas, ligações, ajustes e a segunda rodada sem duplicar.
dofile('config.lua')
dofile('shared/rules.lua')
json = {
	encode = function(value)
		local parts = {}
		local keys = {}
		for key in pairs(value) do keys[#keys + 1] = key end
		table.sort(keys)
		for _, key in ipairs(keys) do parts[#parts + 1] = ('"%s":%s'):format(key, tostring(value[key])) end
		return '{' .. table.concat(parts, ',') .. '}'
	end,
	decode = function(text)
		local result = {}
		for key, value in tostring(text):gmatch('"(%w+)":"?([%w%.]+)"?') do
			if value == 'true' then result[key] = true
			elseif value == 'false' then result[key] = false
			elseif tonumber(value) then result[key] = tonumber(value)
			else result[key] = value end
		end
		return result
	end
}
dofile('server/upgrade.lua')
local config = CoePhoneConfig
local U = PhoneUpgrade

local failures = 0
local function eq(actual, expected, label)
	if actual ~= expected then
		failures = failures + 1
		print(('FAIL %s: esperado %s, veio %s'):format(label, tostring(expected), tostring(actual)))
	end
end

-- Regras puras ------------------------------------------------------------------------------------------------

eq(U.Digits('555-0123'), '5550123', 'tira o traco')
eq(U.LegacySerial(7), 'MG00000000000007', 'serial legado')
local plan = U.PlanNumbers({
	{ characterId = 1, number = '555-0001' },
	{ characterId = 2, number = '555-0002' },
	{ characterId = 3, number = '555-0003' },
	{ characterId = 4, number = '555-0004' }
}, { ['2'] = '5559999' }, { ['4'] = { serial = 'SNX', bound = true } }, { ['5550003'] = '99' })
eq(#plan.create, 3, 'cria para quem nao tem linha')
eq(plan.kept, 1, 'quem ja tem linha mantem')
eq(plan.conflicts, 1, 'numero de outra pessoa')
eq(plan.create[1].number, '5550001', 'mesmo numero')
eq(plan.create[1].newDevice, true, 'aparelho legado novo')
eq(plan.create[2].number, nil, 'conflito sorteia outro')
eq(plan.create[3].serial, 'SNX', 'usa o aparelho que ja tem')
local map, known = U.Map({ { characterId = 1, number = '555-0001' }, { characterId = 3, number = '555-0003' } }, { ['1'] = '5550001' })
eq(U.Translate(map, known, '555-0001'), '5550001', 'traduz')
eq(U.Translate(map, known, '555-0003'), nil, 'personagem sem linha: fica de fora')
eq(U.Translate(map, known, '555-7777'), '5557777', 'numero de fora segue igual')
eq(U.Message(map, known, { sender = '555-0001', receiver = '555-7777', body = 'oi', sender_deleted = 1, receiver_deleted = 1 }), nil, 'apagada dos dois lados')
eq(U.Message(map, known, { sender = '555-0001', receiver = '555-7777', body = 'oi', sender_deleted = 1 }).receiver, '5557777', 'apagada de um lado vem')
eq(U.Call(map, known, { caller = '555-0001', callee = '555-7777', status = 'unreachable', duration = 0 }).status, 'unavailable', 'status traduzido')
eq(U.Settings(config, '{"silent":true,"volume":8,"ringtone":"digital","wallpaper":"noite"}').volume, 8, 'ajustes vem')
eq(U.Settings(config, '{"ringtone":"nao_existe"}').ringtone, config.Settings.Defaults.ringtone, 'ajuste invalido vira padrao')

-- Banco simulado -----------------------------------------------------------------------------------------------

local T = {
	mobile_numbers = {
		{ character_id = 1, number = '555-0001', created_at = 1 },
		{ character_id = 2, number = '555-0002', created_at = 1 },
		{ character_id = 3, number = '555-0003', created_at = 1 }
	},
	mobile_settings = { { character_id = 1, data = '{"silent":true,"volume":8}' } },
	mobile_contacts = {
		{ id = 1, character_id = 1, number = '555-0002', name = 'Bia' },
		{ id = 2, character_id = 1, number = '555-0003', name = 'Caio' },
		{ id = 3, character_id = 2, number = '555-0001', name = 'Ana' }
	},
	mobile_messages = {
		{ id = 1, sender = '555-0001', receiver = '555-0002', body = 'oi bia', created_at = 10, read_at = 11, sender_deleted = 0, receiver_deleted = 0 },
		{ id = 2, sender = '555-0002', receiver = '555-0001', body = 'oi ana', created_at = 12, sender_deleted = 0, receiver_deleted = 0 },
		{ id = 3, sender = '555-0001', receiver = '555-0002', body = 'apagada', created_at = 13, sender_deleted = 1, receiver_deleted = 1 },
		{ id = 4, sender = '555-0003', receiver = '555-0001', body = 'do caio', created_at = 14, sender_deleted = 0, receiver_deleted = 0 }
	},
	mobile_calls = { { id = 1, caller = '555-0002', callee = '555-0001', status = 'unreachable', duration = 0, created_at = 15 } },
	-- Já no smartphone: o personagem 2 tem linha própria; o número 5550003 já é de outra pessoa (99).
	sims = {
		{ iccid = 'A', number = '5559999', holder_character = 2, device_serial = 'SN2', slot = 1, created_at = 1 },
		{ iccid = 'B', number = '5550003', holder_character = 99, device_serial = 'SN99', slot = 1, created_at = 1 }
	},
	devices = { { serial = 'SN2', owner_character = 2, bound = 1, updated_at = 5 } },
	device_contacts = {}, messages = {}, calls = {}, upgrades = {}
}

local function list(text)
	local values = {}
	for value in text:gmatch('[^,]+') do values[#values + 1] = value end
	return values
end
local function has(values, value)
	for _, item in ipairs(values) do if tostring(item) == tostring(value) then return true end end
	return false
end
local function slice(params, from, to) return { table.unpack(params, from, to) } end

local db = {}
function db.query(sql, params)
	if sql:find('information_schema') then return { { n = 4 } } end
	if sql:find('FROM coe_phone_upgrades') then
		local rows = {}
		for _, row in ipairs(T.upgrades) do rows[#rows + 1] = { kind = row.kind, last_id = row.last_id } end
		return rows
	end
	if sql:find('FROM coe_mobile_numbers') then return T.mobile_numbers end
	if sql:find('FROM coe_mobile_settings') then
		local rows = {}
		for _, row in ipairs(T.mobile_settings) do if has(params, row.character_id) then rows[#rows + 1] = row end end
		return rows
	end
	if sql:find('FROM coe_phone_sims WHERE holder_character IN') or sql:find('FROM coe_phone_sims WHERE holder_character = %?') then
		local rows = {}
		for _, row in ipairs(T.sims) do if has(params, row.holder_character) then rows[#rows + 1] = row end end
		return rows
	end
	if sql:find('FROM coe_phone_sims WHERE number IN') then
		local rows = {}
		for _, row in ipairs(T.sims) do if has(params, row.number) then rows[#rows + 1] = row end end
		return rows
	end
	if sql:find('FROM coe_phone_devices WHERE owner_character IN') then
		local rows = {}
		for _, row in ipairs(T.devices) do if has(params, row.owner_character) then rows[#rows + 1] = row end end
		return rows
	end
	for name, key in pairs({ coe_mobile_contacts = 'mobile_contacts', coe_mobile_messages = 'mobile_messages', coe_mobile_calls = 'mobile_calls' }) do
		if sql:find('FROM ' .. name .. ' ') then
			local rows = {}
			for _, row in ipairs(T[key]) do if row.id > params[1] and #rows < 50 then rows[#rows + 1] = row end end
			return rows
		end
	end
	error('consulta inesperada: ' .. sql)
end

local function run(sql, params)
	if sql:find('INSERT IGNORE INTO coe_phone_devices') then
		for _, row in ipairs(T.devices) do if row.serial == params[1] then return { affectedRows = 0 } end end
		T.devices[#T.devices + 1] = { serial = params[1], owner_character = params[3], data = params[5], bound = 0, updated_at = params[6] }
		return { affectedRows = 1 }
	end
	if sql:find('INSERT IGNORE INTO coe_phone_sims') then
		for _, row in ipairs(T.sims) do
			if row.iccid == params[1] or row.number == params[2] then return { affectedRows = 0 } end
		end
		local busy = false
		for _, row in ipairs(T.sims) do if row.device_serial == params[4] and row.slot == 1 then busy = true end end
		T.sims[#T.sims + 1] = { iccid = params[1], number = params[2], holder_character = params[3], device_serial = not busy and params[5] or nil,
			slot = not busy and 1 or nil, created_at = 2 }
		return { affectedRows = 1 }
	end
	if sql:find('INSERT IGNORE INTO coe_phone_device_contacts') then
		for _, row in ipairs(T.device_contacts) do if row.serial == params[1] and row.number == params[3] then return { affectedRows = 0 } end end
		T.device_contacts[#T.device_contacts + 1] = { serial = params[1], name = params[2], number = params[3] }
		return { affectedRows = 1 }
	end
	if sql:find('INSERT INTO coe_phone_upgrades') then
		for _, row in ipairs(T.upgrades) do if row.kind == params[2] then row.last_id = params[3] return { affectedRows = 2 } end end
		T.upgrades[#T.upgrades + 1] = { kind = params[2], last_id = params[3] }
		return { affectedRows = 1 }
	end
	if sql:find('INSERT INTO coe_phone_messages') then
		local index = 1
		for marks in sql:gmatch('%(([^%)]*)%)') do
			if marks:find('%?') and not marks:find('sender') then
				local nulls = select(2, marks:gsub('NULL', ''))
				local take = 5 - nulls
				local p = slice(params, index, index + take - 1)
				index = index + take
				T.messages[#T.messages + 1] = { sender = p[1], receiver = p[2], body = p[3], created_at = p[4], read_at = p[5] }
			end
		end
		return { affectedRows = 1 }
	end
	if sql:find('INSERT INTO coe_phone_calls') then
		local index = 1
		for marks in sql:gmatch("%(([^%)]*'voice')%)") do
			local p = slice(params, index, index + 4)
			index = index + 5
			T.calls[#T.calls + 1] = { caller = p[1], callee = p[2], status = p[3], duration = p[4], created_at = p[5] }
		end
		return { affectedRows = 1 }
	end
	error('execucao inesperada: ' .. sql)
end
db.execute = run
function db.transaction(statements)
	for _, statement in ipairs(statements) do run(statement.sql, statement.parameters) end
	return { ok = true }
end

math.randomseed(1)
local report = U.Run(db, config)
eq(report.ok, true, 'upgrade ok')
eq(report.numbers, 2, 'duas linhas criadas (mesmo numero e sorteado)')
eq(report.kept, 1, 'uma mantida')
eq(report.conflicts, 1, 'um conflito')
local function holder(id) for _, row in ipairs(T.sims) do if tostring(row.holder_character) == tostring(id) then return row end end end
eq(holder(1).number, '5550001', 'personagem 1 mantem o numero')
eq(holder(1).device_serial, 'MG00000000000001', 'chip no aparelho legado')
local caio = holder(3)
eq(caio ~= nil and caio.number ~= '5550003', true, 'personagem 3 ganha numero novo')
local legacy
for _, row in ipairs(T.devices) do if row.serial == 'MG00000000000001' then legacy = row end end
eq(legacy.bound, 0, 'aparelho legado sem item ainda')
eq(legacy.data:find('"silent":true') ~= nil, true, 'ajustes do basico no aparelho')
eq(#T.device_contacts, 3, 'contatos importados')
local contactOf = {}
for _, row in ipairs(T.device_contacts) do contactOf[row.serial .. ':' .. row.name] = row.number end
eq(contactOf['MG00000000000001:Bia'], '5559999', 'contato da Bia aponta para a linha atual dela')
eq(contactOf['MG00000000000001:Caio'], caio.number, 'contato do Caio aponta para o numero novo')
eq(contactOf['SN2:Ana'], '5550001', 'contato no aparelho que a Bia ja tinha')
eq(#T.messages, 3, 'conversas (sem a apagada pelos dois)')
eq(T.messages[1].receiver, '5559999', 'mensagem para a linha atual')
eq(T.messages[1].read_at, 11, 'lida continua lida')
eq(T.messages[2].read_at, nil, 'nao lida continua nao lida')
eq(T.messages[3].sender, caio.number, 'mensagem do Caio pelo numero novo')
eq(#T.calls, 1, 'ligacao importada')
eq(T.calls[1].status, 'unavailable', 'fora de area')

-- Segunda rodada: nada duplica; o que o básico criou depois vem.
T.mobile_messages[#T.mobile_messages + 1] = { id = 5, sender = '555-0002', receiver = '555-0001', body = 'nova', created_at = 20, sender_deleted = 0, receiver_deleted = 0 }
local again = U.Run(db, config)
eq(again.numbers, 0, 'sem linhas novas')
eq(again.contacts, 0, 'sem contatos repetidos')
eq(again.messages, 1, 'so a mensagem nova')
eq(#T.messages, 4, 'total sem duplicar')
eq(#T.calls, 1, 'ligacoes sem duplicar')

-- Sem as tabelas do básico: nada a fazer.
local empty = U.Run({ query = function(sql) if sql:find('information_schema') then return { { n = 0 } } end end }, config)
eq(empty.skipped, 'no_source', 'sem basico instalado')

if failures > 0 then
	error(failures .. ' falha(s)')
end
print('coe_phone upgrade_test: ok')
