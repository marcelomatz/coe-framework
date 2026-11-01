-- Upgrade do telefone básico do framework (coe_mobile) para este smartphone: quem já usava o básico mantém o número,
-- os contatos, as conversas, o histórico de ligações e os ajustes. Roda a cada inicialização e só traz o que é novo
-- (marca d'água por tabela em coe_phone_upgrades), então ir e voltar entre o básico e o smartphone não duplica nada.
--
-- DE coe_mobile                         PARA coe_phone
-- coe_mobile_numbers (555-0123)         chip (coe_phone_sims, 5550123) no slot 1 de um aparelho do personagem
-- coe_mobile_settings                   ajustes do aparelho (coe_phone_devices.data), só no aparelho criado aqui
-- coe_mobile_contacts                   contatos do aparelho (coe_phone_device_contacts)
-- coe_mobile_messages                   coe_phone_messages (conversa apagada pelos dois lados fica de fora)
-- coe_mobile_calls                      coe_phone_calls (unreachable vira unavailable; tipo voice)
--
-- O aparelho criado é o "legado" (serial MG + id do personagem, ainda sem item): o primeiro celular que o personagem
-- abrir assume esse aparelho, com chip, contatos e ajustes, como na migração dos aparelhos (v4).
PhoneUpgrade = {}

local SOURCE = 'coe_mobile'
local BATCH = 50
local STATUS = { answered = 'answered', missed = 'missed', declined = 'declined', busy = 'busy', unreachable = 'unavailable' }

local function digits(value)
	local clean = tostring(value or ''):gsub('%D', '')
	return clean ~= '' and clean or nil
end
PhoneUpgrade.Digits = digits

function PhoneUpgrade.LegacySerial(characterId)
	return 'MG' .. string.format('%014d', math.tointeger(tonumber(characterId)) or 0)
end

function PhoneUpgrade.LegacyIccid(characterId)
	return '8956' .. string.format('%016d', math.tointeger(tonumber(characterId)) or 0)
end

---Plano dos números (puro). rows = { { characterId, number } } do básico.
---held[characterId] = número de que já é titular aqui; devices[characterId] = { serial, bound } (o primeiro aparelho);
---taken[número] = titular aqui. Retorna { create = { { characterId, number (nil = sortear outro), serial, newDevice } },
---kept, conflicts }. Quem já tem linha aqui fica com ela (as conversas do número antigo passam para a linha atual).
function PhoneUpgrade.PlanNumbers(rows, held, devices, taken)
	local plan = { create = {}, kept = 0, conflicts = 0 }
	local claimed = {}
	for _, row in ipairs(rows) do
		local characterId = tostring(row.characterId)
		local number = digits(row.number)
		if number and not held[characterId] then
			if (taken[number] and tostring(taken[number]) ~= characterId) or claimed[number] then
				plan.conflicts = plan.conflicts + 1
				number = nil
			else
				claimed[number] = true
			end
			local device = devices[characterId]
			plan.create[#plan.create + 1] = {
				characterId = characterId, number = number,
				serial = device and device.serial or PhoneUpgrade.LegacySerial(characterId), newDevice = device == nil
			}
		elseif number then
			plan.kept = plan.kept + 1
		end
	end
	return plan
end

---Mapa final: número do básico -> linha do personagem aqui. known = todos os números do básico.
function PhoneUpgrade.Map(rows, heldNow)
	local map, known = {}, {}
	for _, row in ipairs(rows) do
		local number = digits(row.number)
		if number then
			known[number] = true
			map[number] = heldNow[tostring(row.characterId)]
		end
	end
	return map, known
end

---Número daqui para um número do básico: o de um personagem vira a linha dele (nil se ele ficou sem linha);
---número que nunca foi de ninguém no básico segue igual.
function PhoneUpgrade.Translate(map, known, number)
	local clean = digits(number)
	if not clean then
		return nil
	end
	if known[clean] then
		return map[clean]
	end
	return clean
end

---Mensagem do básico como linha daqui (ou nil se as duas pontas apagaram a conversa).
function PhoneUpgrade.Message(map, known, row)
	if tonumber(row.sender_deleted) == 1 and tonumber(row.receiver_deleted) == 1 then
		return nil
	end
	local sender, receiver = PhoneUpgrade.Translate(map, known, row.sender), PhoneUpgrade.Translate(map, known, row.receiver)
	if not sender or not receiver or type(row.body) ~= 'string' then
		return nil
	end
	return { sender = sender, receiver = receiver, body = row.body, createdAt = tonumber(row.created_at) or 0,
		readAt = tonumber(row.read_at) }
end

function PhoneUpgrade.Call(map, known, row)
	local caller, callee = PhoneUpgrade.Translate(map, known, row.caller), PhoneUpgrade.Translate(map, known, row.callee)
	if not caller or not callee then
		return nil
	end
	return { caller = caller, callee = callee, status = STATUS[row.status] or 'missed',
		duration = math.max(0, math.tointeger(tonumber(row.duration)) or 0), createdAt = tonumber(row.created_at) or 0 }
end

---Ajustes do básico ({ silent, volume, ringtone, wallpaper }) nos ajustes deste aparelho (o resto pelos padrões).
function PhoneUpgrade.Settings(config, data)
	local ok, raw = pcall(json.decode, data or '')
	return PhoneRules.Settings(config, ok and type(raw) == 'table' and raw or {})
end

-- Execução ------------------------------------------------------------------------------------------------------

local function marks(db)
	local rows = db.query('SELECT kind, last_id FROM coe_phone_upgrades WHERE source = ?', { SOURCE })
	local result = {}
	for _, row in ipairs(rows or {}) do
		result[row.kind] = math.tointeger(tonumber(row.last_id)) or 0
	end
	return result
end

local function markStatement(kind, lastId)
	return {
		sql = 'INSERT INTO coe_phone_upgrades (source, kind, last_id, updated_at) VALUES (?, ?, ?, ?) '
			.. 'ON DUPLICATE KEY UPDATE last_id = VALUES(last_id), updated_at = VALUES(updated_at)',
		parameters = { SOURCE, kind, lastId, os.time() }
	}
end

local function inList(count)
	local marks_ = {}
	for index = 1, count do marks_[index] = '?' end
	return table.concat(marks_, ',')
end

local function keyed(rows, key, value)
	local map = {}
	for _, row in ipairs(rows or {}) do
		local k = tostring(row[key])
		if map[k] == nil then
			map[k] = value and value(row) or row
		end
	end
	return map
end

---db = { query(sql, params), execute(sql, params), transaction(statements) } (resultado ou nil + erro).
---Retorna o relatório { ok, numbers, kept, conflicts, contacts, messages, calls } ou { ok = false, error }.
function PhoneUpgrade.Run(db, config)
	local report = { ok = true, source = SOURCE, numbers = 0, kept = 0, conflicts = 0, contacts = 0, messages = 0, calls = 0 }
	local present = db.query([[
		SELECT COUNT(*) AS n FROM information_schema.tables
		WHERE table_schema = DATABASE() AND table_name IN ('coe_mobile_numbers', 'coe_mobile_contacts', 'coe_mobile_messages', 'coe_mobile_calls')
	]], {})
	if not present then
		return { ok = false, error = 'database_error' }
	end
	if (tonumber(present[1] and present[1].n) or 0) < 4 then
		report.skipped = 'no_source'
		return report
	end
	local done = marks(db)

	-- Números: todos os do básico (o mapa traduz as conversas); cria chip e aparelho só para quem não tem linha aqui.
	local rows = db.query('SELECT character_id, number, created_at FROM coe_mobile_numbers ORDER BY character_id', {})
	if not rows then
		return { ok = false, error = 'database_error' }
	end
	local source, held, devices, taken = {}, {}, {}, {}
	for _, row in ipairs(rows) do
		source[#source + 1] = { characterId = tostring(row.character_id), number = row.number }
	end
	for first = 1, #source, 200 do
		local ids, numbers = {}, {}
		for index = first, math.min(#source, first + 199) do
			ids[#ids + 1] = source[index].characterId
			numbers[#numbers + 1] = digits(source[index].number) or ''
		end
		local heldRows = db.query('SELECT holder_character, number FROM coe_phone_sims WHERE holder_character IN (' .. inList(#ids) .. ') ORDER BY created_at, iccid', ids)
		local deviceRows = db.query('SELECT owner_character, serial, bound FROM coe_phone_devices WHERE owner_character IN (' .. inList(#ids) .. ') ORDER BY bound, updated_at DESC', ids)
		local takenRows = db.query('SELECT number, holder_character FROM coe_phone_sims WHERE number IN (' .. inList(#numbers) .. ')', numbers)
		if not heldRows or not deviceRows or not takenRows then
			return { ok = false, error = 'database_error' }
		end
		for k, v in pairs(keyed(heldRows, 'holder_character', function(row) return tostring(row.number) end)) do held[k] = v end
		for k, v in pairs(keyed(deviceRows, 'owner_character', function(row) return { serial = tostring(row.serial), bound = tonumber(row.bound) == 1 } end)) do devices[k] = v end
		for k, v in pairs(keyed(takenRows, 'number', function(row) return row.holder_character and tostring(row.holder_character) or '' end)) do taken[k] = v end
	end
	local plan = PhoneUpgrade.PlanNumbers(source, held, devices, taken)
	report.kept, report.conflicts = plan.kept, plan.conflicts

	local settingsRows = {}
	if #plan.create > 0 then
		local ids = {}
		for _, item in ipairs(plan.create) do ids[#ids + 1] = item.characterId end
		for first = 1, #ids, 200 do
			local slice = { table.unpack(ids, first, math.min(#ids, first + 199)) }
			local found = db.query('SELECT character_id, data FROM coe_mobile_settings WHERE character_id IN (' .. inList(#slice) .. ')', slice)
			for k, v in pairs(keyed(found, 'character_id', function(row) return row.data end)) do settingsRows[k] = v end
		end
	end
	local function holdsNumber(characterId)
		local found = db.query('SELECT number FROM coe_phone_sims WHERE holder_character = ? LIMIT 1', { characterId })
		return found and found[1] and tostring(found[1].number) or nil
	end
	for _, item in ipairs(plan.create) do
		if item.newDevice then
			db.execute('INSERT IGNORE INTO coe_phone_devices (serial, model, owner_character, face_character, data, bound, updated_at) VALUES (?, ?, ?, ?, ?, 0, ?)', {
				item.serial, config.LegacyModel or 'coe_one', item.characterId, item.characterId,
				json.encode(PhoneUpgrade.Settings(config, settingsRows[item.characterId])), os.time()
			})
		end
		-- Chip no slot 1 do aparelho (com o slot ocupado, o chip fica com o titular, fora do aparelho). Número já de
		-- outra pessoa: sorteia um novo (as conversas do número antigo vêm para ele).
		for attempt = 1, 25 do
			local number = item.number
			if not number or attempt > 1 then
				number = PhoneRules.Generate(config, math.random)
			end
			db.execute([[
				INSERT IGNORE INTO coe_phone_sims (iccid, number, carrier, holder_character, device_serial, slot)
				SELECT ?, ?, 'coe', ?,
					IF(EXISTS(SELECT 1 FROM coe_phone_sims s WHERE s.device_serial = ? AND s.slot = 1), NULL, ?),
					IF(EXISTS(SELECT 1 FROM coe_phone_sims s WHERE s.device_serial = ? AND s.slot = 1), NULL, 1)
			]], { PhoneUpgrade.LegacyIccid(item.characterId), number, item.characterId, item.serial, item.serial, item.serial })
			if holdsNumber(item.characterId) then
				report.numbers = report.numbers + 1
				break
			end
		end
	end

	-- Mapa final pelas linhas que cada personagem tem agora.
	local heldNow = {}
	for first = 1, #source, 200 do
		local ids = {}
		for index = first, math.min(#source, first + 199) do ids[#ids + 1] = source[index].characterId end
		local found = db.query('SELECT holder_character, number FROM coe_phone_sims WHERE holder_character IN (' .. inList(#ids) .. ') ORDER BY created_at, iccid', ids)
		if not found then
			return { ok = false, error = 'database_error' }
		end
		for k, v in pairs(keyed(found, 'holder_character', function(row) return tostring(row.number) end)) do heldNow[k] = v end
	end
	local map, known = PhoneUpgrade.Map(source, heldNow)

	-- Contatos novos do básico (marca d'água pelo id), no aparelho de cada personagem.
	local serialOf = {}
	for characterId, device in pairs(devices) do serialOf[characterId] = device.serial end
	for _, item in ipairs(plan.create) do serialOf[item.characterId] = item.serial end
	local lastContact = done.contacts or 0
	while true do
		local batch = db.query('SELECT id, character_id, number, name FROM coe_mobile_contacts WHERE id > ? ORDER BY id LIMIT ' .. BATCH, { lastContact })
		if not batch then
			return { ok = false, error = 'database_error' }
		end
		if #batch == 0 then
			break
		end
		local statements = {}
		for _, row in ipairs(batch) do
			lastContact = math.max(lastContact, math.tointeger(tonumber(row.id)) or 0)
			local serial = serialOf[tostring(row.character_id)]
			local number = PhoneUpgrade.Translate(map, known, row.number)
			if serial and number then
				statements[#statements + 1] = {
					sql = 'INSERT IGNORE INTO coe_phone_device_contacts (serial, name, number) VALUES (?, ?, ?)',
					parameters = { serial, tostring(row.name):sub(1, 64), number }
				}
			end
		end
		statements[#statements + 1] = markStatement('contacts', lastContact)
		if not db.transaction(statements) then
			return { ok = false, error = 'database_error' }
		end
		report.contacts = report.contacts + #statements - 1
	end

	-- Mensagens e ligações: em lotes, cada lote com a marca d'água na mesma transação.
	local function copy(kind, select, build, insert)
		local last = done[kind] or 0
		while true do
			local batch = db.query(select .. ' WHERE id > ? ORDER BY id LIMIT ' .. BATCH, { last })
			if not batch then
				return nil
			end
			if #batch == 0 then
				return true
			end
			local values, parameters, count = {}, {}, 0
			for _, row in ipairs(batch) do
				last = math.max(last, math.tointeger(tonumber(row.id)) or 0)
				local item = build(row)
				if item then
					count = count + 1
					local rowMarks, rowValues = insert.row(item)
					values[#values + 1] = rowMarks
					for _, value in ipairs(rowValues) do parameters[#parameters + 1] = value end
				end
			end
			local statements = {}
			if count > 0 then
				statements[1] = { sql = insert.sql .. table.concat(values, ', '), parameters = parameters }
			end
			statements[#statements + 1] = markStatement(kind, last)
			if not db.transaction(statements) then
				return nil
			end
			report[kind] = report[kind] + count
		end
	end

	local messagesOk = copy('messages', 'SELECT id, sender, receiver, body, created_at, read_at, sender_deleted, receiver_deleted FROM coe_mobile_messages',
		function(row) return PhoneUpgrade.Message(map, known, row) end, {
			sql = 'INSERT INTO coe_phone_messages (sender, receiver, body, created_at, read_at) VALUES ',
			-- Não lida continua não lida (read_at NULL).
			row = function(m)
				if m.readAt then
					return '(?, ?, ?, ?, ?)', { m.sender, m.receiver, m.body, m.createdAt, m.readAt }
				end
				return '(?, ?, ?, ?, NULL)', { m.sender, m.receiver, m.body, m.createdAt }
			end
		})
	local callsOk = messagesOk and copy('calls', 'SELECT id, caller, callee, status, duration, created_at FROM coe_mobile_calls',
		function(row) return PhoneUpgrade.Call(map, known, row) end, {
			sql = 'INSERT INTO coe_phone_calls (caller, callee, status, duration, created_at, kind) VALUES ',
			row = function(c) return "(?, ?, ?, ?, ?, 'voice')", { c.caller, c.callee, c.status, c.duration, c.createdAt } end
		})
	if not messagesOk or not callsOk then
		return { ok = false, error = 'database_error' }
	end
	return report
end
