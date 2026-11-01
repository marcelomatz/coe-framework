TelecomPersistence = {}

local function callDatabase(exportName, ...)
	if GetResourceState('coe_database') ~= 'started' then
		return nil, 'database_unavailable'
	end
	local response = promise.new()
	local databaseResource = exports['coe_database']
	local callArguments = { databaseResource, ... }
	callArguments[#callArguments + 1] = function(success, result, errorCode)
		response:resolve({ success = success == true, result = result, error = errorCode })
	end
	local dispatched = pcall(function()
		databaseResource[exportName](table.unpack(callArguments))
	end)
	if not dispatched then
		return nil, 'database_unavailable'
	end
	local result = Citizen.Await(response)
	if not result.success then
		return nil, result.error or 'database_error'
	end
	return result.result
end

local function query(sql, parameters)
	return callDatabase('Query', sql, parameters or {})
end

local function execute(sql, parameters)
	return callDatabase('Execute', sql, parameters or {})
end

-- Troca cada `?` cujo valor é nil por NULL: tabela com nil no meio não chega inteira ao coe_database.
-- Só para valores de INSERT/SET (em WHERE, `= NULL` nunca casa).
local function bind(sql, ...)
	local values, count = { ... }, select('#', ...)
	local parameters, index = {}, 0
	local text = sql:gsub('%?', function()
		index = index + 1
		local value = values[index]
		if value == nil then
			return 'NULL'
		end
		parameters[#parameters + 1] = value
		return '?'
	end)
	assert(index == count, 'bind: quantidade de parâmetros')
	return text, parameters
end

local function limit(value)
	return math.max(1, math.min(200, math.floor(tonumber(value) or 1)))
end

local function affected(result)
	return result ~= nil and (tonumber(result.affectedRows) or 0) > 0
end

-- holder: personagem titular do chip (nil = linha anônima).
local function toLine(row)
	return {
		number = tostring(row.number),
		holder = row.character_id ~= nil and tostring(row.character_id) or nil,
		carrier = tostring(row.carrier),
		plan = tostring(row.plan),
		balance = tonumber(row.balance) or 0,
		status = tostring(row.status),
		cycleStart = tonumber(row.cycle_start) or 0,
		voiceUsed = tonumber(row.voice_used) or 0,
		videoUsed = tonumber(row.video_used) or 0,
		planChangedAt = tonumber(row.plan_changed_at) or 0
	}
end

local LINE_COLUMNS = 'number, character_id, carrier, plan, balance, status, cycle_start, voice_used, video_used, plan_changed_at'

function TelecomPersistence.Initialize()
	return CoeMigrations.Run({
		tableName = 'coe_telecom_schema_migrations',
		migrations = TelecomMigrations,
		execute = execute,
		query = query
	})
end

-- Linhas ----------------------------------------------------------------------------------------------

-- Linha do número; false se ainda não existe.
function TelecomPersistence.Line(number)
	local rows, errorCode = query('SELECT ' .. LINE_COLUMNS .. ' FROM coe_telecom_lines WHERE number = ?', { number })
	if not rows then
		return nil, errorCode
	end
	return rows[1] and toLine(rows[1]) or false
end

-- Linha anterior aos chips (por personagem, sem número): passa a ser do número, com faturas e extrato.
-- true se havia linha antiga do titular.
function TelecomPersistence.Adopt(number, holder)
	local result, errorCode = execute('UPDATE coe_telecom_lines SET number = ? WHERE character_id = ? AND number IS NULL LIMIT 1', { number, holder })
	if not result then
		return nil, errorCode
	end
	if not affected(result) then
		return false
	end
	execute('UPDATE coe_telecom_invoices SET number = ? WHERE character_id = ? AND number IS NULL', { number, holder })
	execute('UPDATE coe_telecom_usage SET number = ? WHERE character_id = ? AND number IS NULL', { number, holder })
	return true
end

function TelecomPersistence.CreateLine(number, holder, carrier, plan, balance, now)
	local result, errorCode = execute(bind([[
		INSERT IGNORE INTO coe_telecom_lines (number, character_id, carrier, plan, balance, status, cycle_start, created_at)
		VALUES (?, ?, ?, ?, ?, 'active', ?, ?)
	]], number, holder, carrier, plan, balance, now, now))
	if not result then
		return nil, errorCode
	end
	return affected(result)
end

-- Desconta crédito sem deixar negativo.
function TelecomPersistence.Spend(number, cost)
	return execute('UPDATE coe_telecom_lines SET balance = GREATEST(0, CAST(balance AS SIGNED) - ?) WHERE number = ?', { cost, number })
end

-- Soma minutos na franquia do ciclo (field vem das regras: voice_used ou video_used).
function TelecomPersistence.AddUsed(number, field, units)
	if field ~= 'voice_used' and field ~= 'video_used' then
		return nil, 'invalid_field'
	end
	return execute(('UPDATE coe_telecom_lines SET %s = %s + ? WHERE number = ?'):format(field, field), { units, number })
end

-- true se o crédito coube abaixo do teto.
function TelecomPersistence.AddBalance(number, amount, max)
	local result = execute('UPDATE coe_telecom_lines SET balance = balance + ? WHERE number = ? AND balance + ? <= ?', { amount, number, amount, max })
	return affected(result)
end

-- Fecha o ciclo lido em `line`: zera a franquia (descontando só o que foi lido) e começa um novo.
-- Retorna true se este processo fechou (evita fatura duplicada).
function TelecomPersistence.ResetCycle(line, now)
	local result = execute([[
		UPDATE coe_telecom_lines
		SET cycle_start = ?, voice_used = GREATEST(0, CAST(voice_used AS SIGNED) - ?), video_used = GREATEST(0, CAST(video_used AS SIGNED) - ?)
		WHERE number = ? AND cycle_start = ? AND plan = ?
	]], { now, line.voiceUsed, line.videoUsed, line.number, line.cycleStart, line.plan })
	return affected(result)
end

function TelecomPersistence.SetPlan(number, plan, now)
	local result = execute([[
		UPDATE coe_telecom_lines SET plan = ?, cycle_start = ?, voice_used = 0, video_used = 0, plan_changed_at = ?
		WHERE number = ?
	]], { plan, now, now, number })
	return affected(result)
end

function TelecomPersistence.SetStatus(number, status)
	return execute('UPDATE coe_telecom_lines SET status = ? WHERE number = ?', { status, number })
end

-- Pós-pagos com o ciclo vencido (só linhas já associadas a um número).
function TelecomPersistence.DueLines(plans, cycleSeconds, now, max)
	if #plans == 0 then
		return {}
	end
	local marks = string.rep('?, ', #plans):sub(1, -3)
	local parameters = {}
	for index, plan in ipairs(plans) do
		parameters[index] = plan
	end
	parameters[#parameters + 1] = now - cycleSeconds
	local rows, errorCode = query(([[
		SELECT %s FROM coe_telecom_lines
		WHERE number IS NOT NULL AND plan IN (%s) AND cycle_start <= ? ORDER BY cycle_start LIMIT %d
	]]):format(LINE_COLUMNS, marks, limit(max)), parameters)
	if not rows then
		return nil, errorCode
	end
	local list = {}
	for _, row in ipairs(rows) do
		list[#list + 1] = toLine(row)
	end
	return list
end

-- Suspende linhas com fatura vencida. Retorna { number, holder } de cada linha suspensa.
function TelecomPersistence.SuspendOverdue(now)
	local rows, errorCode = query([[
		SELECT DISTINCT l.number, l.character_id FROM coe_telecom_lines l
		JOIN coe_telecom_invoices i ON i.number = l.number
		WHERE l.status = 'active' AND i.status = 'open' AND i.due_at < ?
		LIMIT 200
	]], { now })
	if not rows then
		return nil, errorCode
	end
	local list = {}
	for _, row in ipairs(rows) do
		local number = tostring(row.number)
		if affected(execute("UPDATE coe_telecom_lines SET status = 'suspended' WHERE number = ? AND status = 'active'", { number })) then
			list[#list + 1] = { number = number, holder = row.character_id ~= nil and tostring(row.character_id) or nil }
		end
	end
	return list
end

-- Faturas ---------------------------------------------------------------------------------------------

function TelecomPersistence.AddInvoice(line, periodEnd, amount, details, dueAt)
	local result, errorCode = execute(bind([[
		INSERT INTO coe_telecom_invoices (number, character_id, carrier, plan, period_start, period_end, amount, details, status, due_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'open', ?)
	]], line.number, line.holder, line.carrier, line.plan, line.cycleStart, periodEnd, amount, details, dueAt))
	if not result then
		return nil, errorCode
	end
	return math.tointeger(tonumber(result.insertId))
end

function TelecomPersistence.Invoice(number, id)
	local rows, errorCode = query([[
		SELECT id, plan, amount, status FROM coe_telecom_invoices WHERE id = ? AND number = ?
	]], { id, number })
	if not rows then
		return nil, errorCode
	end
	local row = rows[1]
	if not row then
		return false
	end
	return { id = math.tointeger(tonumber(row.id)), plan = tostring(row.plan), amount = tonumber(row.amount) or 0, status = tostring(row.status) }
end

-- true se esta chamada marcou como paga (a fatura ainda estava em aberto).
function TelecomPersistence.MarkPaid(id, now)
	return affected(execute("UPDATE coe_telecom_invoices SET status = 'paid', paid_at = ? WHERE id = ? AND status = 'open'", { now, id }))
end

-- Volta a fatura para aberta (o débito falhou depois de marcar).
function TelecomPersistence.Reopen(id)
	return execute("UPDATE coe_telecom_invoices SET status = 'open', paid_at = NULL WHERE id = ?", { id })
end

function TelecomPersistence.OpenInvoices(number)
	local rows, errorCode = query("SELECT COUNT(*) AS total FROM coe_telecom_invoices WHERE number = ? AND status = 'open'", { number })
	if not rows then
		return nil, errorCode
	end
	return tonumber(rows[1] and rows[1].total) or 0
end

function TelecomPersistence.Invoices(number, max)
	local rows = query(([[
		SELECT id, plan, period_start, period_end, amount, details, status, due_at, paid_at
		FROM coe_telecom_invoices WHERE number = ? ORDER BY id DESC LIMIT %d
	]]):format(limit(max)), { number })
	if not rows then
		return nil
	end
	local list = {}
	for _, row in ipairs(rows) do
		list[#list + 1] = {
			id = math.tointeger(tonumber(row.id)), plan = tostring(row.plan), from = tonumber(row.period_start),
			to = tonumber(row.period_end), amount = tonumber(row.amount) or 0, details = tostring(row.details),
			status = tostring(row.status), dueAt = tonumber(row.due_at), paidAt = tonumber(row.paid_at)
		}
	end
	return list
end

-- Histórico -------------------------------------------------------------------------------------------

-- characterId: quem fez a operação (pagou a recarga, ligou); nil em lançamentos automáticos sem titular.
function TelecomPersistence.AddUsage(number, characterId, kind, peer, units, cost, now)
	return execute(bind([[
		INSERT INTO coe_telecom_usage (number, character_id, kind, peer, units, cost, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)
	]], number, characterId, kind, peer, units, cost, now))
end

function TelecomPersistence.Usage(number, max)
	local rows = query(([[
		SELECT kind, peer, units, cost, created_at FROM coe_telecom_usage WHERE number = ? ORDER BY id DESC LIMIT %d
	]]):format(limit(max)), { number })
	if not rows then
		return nil
	end
	local list = {}
	for _, row in ipairs(rows) do
		list[#list + 1] = {
			kind = tostring(row.kind), peer = row.peer and tostring(row.peer) or nil,
			units = tonumber(row.units) or 0, cost = tonumber(row.cost) or 0, at = tonumber(row.created_at)
		}
	end
	return list
end

function TelecomPersistence.PurgeUsage(before)
	return execute('DELETE FROM coe_telecom_usage WHERE created_at < ? LIMIT 5000', { before })
end