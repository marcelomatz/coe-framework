EconomyPersistence = {}

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

-- Totais para o painel admin (contas e dinheiro em circulação); chamado com cache por quem consome.
function EconomyPersistence.Summary()
	local rows, errorCode = callDatabase('Query', 'SELECT COUNT(*) AS accounts, COALESCE(SUM(balance), 0) AS total FROM coe_economy_accounts', {})
	if not rows or not rows[1] then
		return nil, errorCode or 'database_error'
	end
	return { accounts = tonumber(rows[1].accounts) or 0, total = tonumber(rows[1].total) or 0 }
end

function EconomyPersistence.Initialize()
	local migrated, errorCode = CoeMigrations.Run({
		tableName = 'coe_economy_schema_migrations',
		migrations = EconomyMigrations,
		execute = function(sql, parameters)
			return callDatabase('Execute', sql, parameters)
		end,
		query = function(sql, parameters)
			return callDatabase('Query', sql, parameters)
		end
	})
	if not migrated then
		return false, errorCode
	end

	-- O saldo é BIGINT UNSIGNED: em modo estrito, um débito além do saldo falha e a transação inteira é desfeita.
	local rows = callDatabase('Query', 'SELECT @@SESSION.sql_mode AS mode', {})
	local mode = rows and rows[1] and rows[1].mode or ''
	if not tostring(mode):find('STRICT', 1, true) then
		callDatabase('Execute', "SET GLOBAL sql_mode = CONCAT_WS(',', @@GLOBAL.sql_mode, 'STRICT_TRANS_TABLES')", {})
		callDatabase('Execute', "SET SESSION sql_mode = CONCAT_WS(',', @@SESSION.sql_mode, 'STRICT_TRANS_TABLES')", {})
		rows = callDatabase('Query', 'SELECT @@SESSION.sql_mode AS mode', {})
		mode = rows and rows[1] and rows[1].mode or ''
	end
	if not tostring(mode):find('STRICT', 1, true) then
		return false, 'sql_mode_not_strict'
	end
	return true
end

function EconomyPersistence.EnsureAccount(characterId, startingBalance, sourceResource)
	local result, errorCode = callDatabase('Execute', 'INSERT IGNORE INTO coe_economy_accounts (character_id, balance) VALUES (?, ?)', { characterId, startingBalance })
	if not result then
		return nil, errorCode or 'database_error'
	end
	if (result.affectedRows or 0) == 1 and startingBalance > 0 then
		callDatabase('Execute', 'INSERT INTO coe_economy_ledger (character_id, delta, reason, reference, source_resource) VALUES (?, ?, ?, ?, ?)',
			{ characterId, startingBalance, 'starting_balance', '', sourceResource })
	end
	return true
end

function EconomyPersistence.Balance(characterId)
	local rows, errorCode = callDatabase('Query', 'SELECT balance FROM coe_economy_accounts WHERE character_id = ?', { characterId })
	if not rows then
		return nil, errorCode or 'database_error'
	end
	if not rows[1] then
		return nil, 'account_not_found'
	end
	return tonumber(rows[1].balance) or 0
end

local function ledgerStatement(characterId, delta, reason, reference, sourceResource)
	return {
		sql = 'INSERT INTO coe_economy_ledger (character_id, delta, reason, reference, source_resource) VALUES (?, ?, ?, ?, ?)',
		parameters = { characterId, delta, reason, reference, sourceResource }
	}
end

function EconomyPersistence.Credit(characterId, amount, reason, reference, sourceResource)
	local result, errorCode = callDatabase('Transaction', {
		{ sql = 'UPDATE coe_economy_accounts SET balance = balance + ? WHERE character_id = ?', parameters = { amount, characterId } },
		ledgerStatement(characterId, amount, reason, reference, sourceResource)
	})
	if not result then
		return nil, errorCode or 'database_error'
	end
	if (result[1].affectedRows or 0) ~= 1 then
		return nil, 'account_not_found'
	end
	return true
end

function EconomyPersistence.Debit(characterId, amount, reason, reference, sourceResource)
	local result, errorCode = callDatabase('Transaction', {
		{ sql = 'UPDATE coe_economy_accounts SET balance = balance - ? WHERE character_id = ?', parameters = { amount, characterId } },
		ledgerStatement(characterId, -amount, reason, reference, sourceResource)
	})
	if not result then
		return nil, errorCode or 'database_error'
	end
	if (result[1].affectedRows or 0) ~= 1 then
		return nil, 'account_not_found'
	end
	return true
end

function EconomyPersistence.Transfer(fromId, toId, amount, reason, reference, sourceResource)
	local result, errorCode = callDatabase('Transaction', {
		{ sql = 'UPDATE coe_economy_accounts SET balance = balance - ? WHERE character_id = ?', parameters = { amount, fromId } },
		{ sql = 'UPDATE coe_economy_accounts SET balance = balance + ? WHERE character_id = ?', parameters = { amount, toId } },
		ledgerStatement(fromId, -amount, reason, reference, sourceResource),
		ledgerStatement(toId, amount, reason, reference, sourceResource)
	})
	if not result then
		return nil, errorCode or 'database_error'
	end
	if (result[1].affectedRows or 0) ~= 1 or (result[2].affectedRows or 0) ~= 1 then
		return nil, 'account_not_found'
	end
	return true
end

-- Contas de sociedade (uma por negócio). Débitos usam o modo estrito: saldo insuficiente desfaz a transação.
local function societyLedger(businessId, characterId, delta, reason, reference, sourceResource)
	if characterId and characterId ~= '' then
		return {
			sql = 'INSERT INTO coe_economy_society_ledger (business_id, character_id, delta, reason, reference, source_resource) VALUES (?, ?, ?, ?, ?, ?)',
			parameters = { businessId, characterId, delta, reason, reference, sourceResource }
		}
	end
	return {
		sql = 'INSERT INTO coe_economy_society_ledger (business_id, character_id, delta, reason, reference, source_resource) VALUES (?, NULL, ?, ?, ?, ?)',
		parameters = { businessId, delta, reason, reference, sourceResource }
	}
end

function EconomyPersistence.EnsureSociety(businessId)
	local result, errorCode = callDatabase('Execute', 'INSERT IGNORE INTO coe_economy_societies (business_id, balance) VALUES (?, 0)', { businessId })
	if not result then
		return nil, errorCode or 'database_error'
	end
	return true
end

function EconomyPersistence.SocietyBalance(businessId)
	local rows, errorCode = callDatabase('Query', 'SELECT balance FROM coe_economy_societies WHERE business_id = ?', { businessId })
	if not rows then
		return nil, errorCode or 'database_error'
	end
	return rows[1] and tonumber(rows[1].balance) or 0
end

local function societyResult(result, errorCode, expected)
	if not result then
		return nil, errorCode or 'database_error'
	end
	for index = 1, expected do
		if (result[index].affectedRows or 0) ~= 1 then
			return nil, 'account_not_found'
		end
	end
	return true
end

-- Do personagem para a sociedade (depósito).
function EconomyPersistence.SocietyDeposit(businessId, characterId, amount, reason, reference, sourceResource)
	local result, errorCode = callDatabase('Transaction', {
		{ sql = 'UPDATE coe_economy_accounts SET balance = balance - ? WHERE character_id = ?', parameters = { amount, characterId } },
		{ sql = 'UPDATE coe_economy_societies SET balance = balance + ? WHERE business_id = ?', parameters = { amount, businessId } },
		ledgerStatement(characterId, -amount, reason, reference ~= '' and reference or ('society:' .. businessId), sourceResource),
		societyLedger(businessId, characterId, amount, reason, reference, sourceResource)
	})
	return societyResult(result, errorCode, 2)
end

-- Da sociedade para o personagem (saque e salário).
function EconomyPersistence.SocietyPay(businessId, characterId, amount, reason, reference, sourceResource)
	local result, errorCode = callDatabase('Transaction', {
		{ sql = 'UPDATE coe_economy_societies SET balance = balance - ? WHERE business_id = ?', parameters = { amount, businessId } },
		{ sql = 'UPDATE coe_economy_accounts SET balance = balance + ? WHERE character_id = ?', parameters = { amount, characterId } },
		societyLedger(businessId, characterId, -amount, reason, reference, sourceResource),
		ledgerStatement(characterId, amount, reason, reference ~= '' and reference or ('society:' .. businessId), sourceResource)
	})
	return societyResult(result, errorCode, 2)
end

-- Aporte sem personagem (ajuste administrativo).
function EconomyPersistence.SocietyCredit(businessId, amount, reason, reference, sourceResource)
	local result, errorCode = callDatabase('Transaction', {
		{ sql = 'UPDATE coe_economy_societies SET balance = balance + ? WHERE business_id = ?', parameters = { amount, businessId } },
		societyLedger(businessId, nil, amount, reason, reference, sourceResource)
	})
	return societyResult(result, errorCode, 1)
end

-- Despesa sem personagem (ex.: aluguel comercial). O saldo é UNSIGNED: sem saldo, a transação falha inteira.
function EconomyPersistence.SocietyDebit(businessId, amount, reason, reference, sourceResource)
	local result, errorCode = callDatabase('Transaction', {
		{ sql = 'UPDATE coe_economy_societies SET balance = balance - ? WHERE business_id = ?', parameters = { amount, businessId } },
		societyLedger(businessId, nil, -amount, reason, reference, sourceResource)
	})
	return societyResult(result, errorCode, 1)
end

-- Entre duas sociedades (conta empresarial para conta empresarial).
function EconomyPersistence.SocietyTransfer(fromId, toId, amount, reason, reference, sourceResource)
	local result, errorCode = callDatabase('Transaction', {
		{ sql = 'UPDATE coe_economy_societies SET balance = balance - ? WHERE business_id = ?', parameters = { amount, fromId } },
		{ sql = 'UPDATE coe_economy_societies SET balance = balance + ? WHERE business_id = ?', parameters = { amount, toId } },
		societyLedger(fromId, nil, -amount, reason, reference, sourceResource),
		societyLedger(toId, nil, amount, reason, reference, sourceResource)
	})
	return societyResult(result, errorCode, 2)
end

-- Extrato filtrado da sociedade: direção ('in' | 'out' | nil), motivos (lista ou nil), últimos `days` dias,
-- página antes de `beforeId`. Devolve { rows, totals = { inflow, outflow, count } } (totais do período e filtro).
function EconomyPersistence.SocietyLedgerPage(businessId, filter)
	local where, parameters = { 'business_id = ?' }, { businessId }
	if filter.days then
		where[#where + 1] = 'created_at >= NOW(3) - INTERVAL ? DAY'
		parameters[#parameters + 1] = filter.days
	end
	if filter.direction == 'in' then
		where[#where + 1] = 'delta > 0'
	elseif filter.direction == 'out' then
		where[#where + 1] = 'delta < 0'
	end
	if filter.reasons and #filter.reasons > 0 then
		local marks = {}
		for _, reason in ipairs(filter.reasons) do
			marks[#marks + 1] = '?'
			parameters[#parameters + 1] = reason
		end
		where[#where + 1] = 'reason IN (' .. table.concat(marks, ', ') .. ')'
	end
	local totalsParameters = { table.unpack(parameters) }
	local clause = table.concat(where, ' AND ')
	local pageClause = clause
	local pageParameters = { table.unpack(parameters) }
	if filter.beforeId then
		pageClause = pageClause .. ' AND id < ?'
		pageParameters[#pageParameters + 1] = filter.beforeId
	end
	local rows, errorCode = callDatabase('Query',
		'SELECT id, character_id, delta, reason, reference, UNIX_TIMESTAMP(created_at) AS at FROM coe_economy_society_ledger WHERE '
			.. pageClause .. ' ORDER BY id DESC LIMIT ' .. math.floor(filter.limit), pageParameters)
	if not rows then
		return nil, errorCode or 'database_error'
	end
	local totals, totalsError = callDatabase('Query',
		'SELECT COALESCE(SUM(CASE WHEN delta > 0 THEN delta ELSE 0 END), 0) AS inflow, COALESCE(SUM(CASE WHEN delta < 0 THEN -delta ELSE 0 END), 0) AS outflow, COUNT(*) AS total FROM coe_economy_society_ledger WHERE '
			.. clause, totalsParameters)
	if not totals then
		return nil, totalsError or 'database_error'
	end
	local list = {}
	for index, row in ipairs(rows) do
		list[index] = {
			id = math.tointeger(tonumber(row.id)), characterId = row.character_id and tostring(row.character_id) or nil,
			delta = math.tointeger(tonumber(row.delta)) or 0, reason = row.reason, reference = row.reference or '',
			at = math.floor(tonumber(row.at) or 0)
		}
	end
	local total = totals[1] or {}
	return {
		rows = list,
		totals = { inflow = math.floor(tonumber(total.inflow) or 0), outflow = math.floor(tonumber(total.outflow) or 0), count = math.floor(tonumber(total.total) or 0) }
	}
end

function EconomyPersistence.SocietyLedger(businessId, limit)
	local rows, errorCode = callDatabase('Query',
		'SELECT character_id, delta, reason, reference, created_at FROM coe_economy_society_ledger WHERE business_id = ? ORDER BY id DESC LIMIT ' .. math.floor(limit),
		{ businessId })
	if not rows then
		return nil, errorCode or 'database_error'
	end
	return rows
end

function EconomyPersistence.Ledger(characterId, limit)
	local rows, errorCode = callDatabase('Query',
		'SELECT delta, reason, reference, created_at, UNIX_TIMESTAMP(created_at) AS at FROM coe_economy_ledger WHERE character_id = ? ORDER BY id DESC LIMIT ' .. math.floor(limit),
		{ characterId })
	if not rows then
		return nil, errorCode or 'database_error'
	end
	return rows
end

-- Primeiro lançamento (epoch) e soma das entradas dos últimos `days` dias, ignorando os motivos dados.
function EconomyPersistence.LedgerStats(characterId, days, ignored)
	local placeholders, parameters = {}, { days }
	for _, reason in ipairs(ignored) do
		placeholders[#placeholders + 1] = '?'
		parameters[#parameters + 1] = reason
	end
	parameters[#parameters + 1] = characterId
	local exclude = #placeholders > 0 and (' AND reason NOT IN (' .. table.concat(placeholders, ', ') .. ')') or ''
	local rows, errorCode = callDatabase('Query',
		'SELECT UNIX_TIMESTAMP(MIN(created_at)) AS first_at, COALESCE(SUM(CASE WHEN delta > 0 AND created_at >= NOW(3) - INTERVAL ? DAY'
			.. exclude .. ' THEN delta ELSE 0 END), 0) AS inflow FROM coe_economy_ledger WHERE character_id = ?',
		parameters)
	if not rows then
		return nil, errorCode or 'database_error'
	end
	local row = rows[1] or {}
	return { firstAt = row.first_at and math.floor(tonumber(row.first_at) or 0) or nil, inflow = math.floor(tonumber(row.inflow) or 0) }
end
