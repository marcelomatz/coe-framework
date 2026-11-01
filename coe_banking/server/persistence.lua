BankingPersistence = {}

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

function BankingPersistence.Initialize()
	return CoeMigrations.Run({
		tableName = 'coe_banking_schema_migrations',
		migrations = BankingMigrations,
		execute = function(sql, parameters)
			return callDatabase('Execute', sql, parameters)
		end,
		query = function(sql, parameters)
			return callDatabase('Query', sql, parameters)
		end
	})
end

local CARD_COLUMNS = 'id, account_type, account_ref, holder_id, holder_name, serial, pin_hash, pin_salt, attempts, blocked_reason, created_at, expires_at, kind, '
	.. 'daily_limit, spent_amount, spent_day'

local function toCard(row)
	return {
		id = math.tointeger(tonumber(row.id)),
		accountType = row.account_type,
		accountRef = tostring(row.account_ref),
		holderId = tostring(row.holder_id),
		holderName = row.holder_name or '',
		serial = row.serial,
		pinHash = row.pin_hash,
		pinSalt = row.pin_salt,
		attempts = tonumber(row.attempts) or 0,
		blockedReason = row.blocked_reason,
		createdAt = row.created_at,
		expiresAt = row.expires_at and math.tointeger(tonumber(row.expires_at)) or nil,
		kind = row.kind == 'virtual' and 'virtual' or 'physical',
		dailyLimit = row.daily_limit and math.tointeger(tonumber(row.daily_limit)) or nil,
		spentAmount = math.tointeger(tonumber(row.spent_amount)) or 0,
		spentDay = row.spent_day and math.tointeger(tonumber(row.spent_day)) or nil
	}
end

function BankingPersistence.Card(cardId)
	local rows, errorCode = callDatabase('Query', 'SELECT ' .. CARD_COLUMNS .. ' FROM coe_banking_cards WHERE id = ?', { cardId })
	if not rows then
		return nil, errorCode or 'database_error'
	end
	if not rows[1] then
		return nil, 'card_not_found'
	end
	return toCard(rows[1])
end

function BankingPersistence.AccountCards(accountType, accountRef)
	local rows, errorCode = callDatabase('Query',
		'SELECT ' .. CARD_COLUMNS .. ' FROM coe_banking_cards WHERE account_type = ? AND account_ref = ? ORDER BY id DESC LIMIT 20',
		{ accountType, accountRef })
	if not rows then
		return nil, errorCode or 'database_error'
	end
	local cards = {}
	for _, row in ipairs(rows) do
		cards[#cards + 1] = toCard(row)
	end
	return cards
end

-- Vários cartões pelo id (ids inteiros já validados): { [id] = card }.
function BankingPersistence.Cards(ids)
	if #ids == 0 then
		return {}
	end
	local rows, errorCode = callDatabase('Query',
		'SELECT ' .. CARD_COLUMNS .. ' FROM coe_banking_cards WHERE id IN (' .. string.rep('?', #ids, ', ') .. ')', ids)
	if not rows then
		return nil, errorCode or 'database_error'
	end
	local cards = {}
	for _, row in ipairs(rows) do
		local card = toCard(row)
		cards[card.id] = card
	end
	return cards
end

-- Novo cartão; `duplicate` quando o número já existe (quem chama sorteia outro).
function BankingPersistence.InsertCard(card)
	local result, errorCode = callDatabase('Execute', [[
		INSERT INTO coe_banking_cards (account_type, account_ref, holder_id, holder_name, serial, pin_hash, pin_salt, expires_at, kind, daily_limit)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NULLIF(?, 0))
	]], { card.accountType, card.accountRef, card.holderId, card.holderName, card.serial, card.pinHash, card.pinSalt, card.expiresAt, card.kind or 'physical', card.dailyLimit or 0 })
	if not result then
		if (tostring(errorCode):upper():find('DUP', 1, true)) then
			return nil, 'duplicate'
		end
		return nil, errorCode or 'database_error'
	end
	return math.tointeger(tonumber(result.insertId))
end

function BankingPersistence.Block(cardId, reason)
	local result, errorCode = callDatabase('Execute',
		'UPDATE coe_banking_cards SET blocked_reason = ?, blocked_at = CURRENT_TIMESTAMP(3) WHERE id = ? AND blocked_reason IS NULL',
		{ reason, cardId })
	if not result then
		return nil, errorCode or 'database_error'
	end
	return true
end

-- Substituição: bloqueia os demais cartões ativos do mesmo tipo (físico ou virtual) e titular na conta.
function BankingPersistence.ReplaceOthers(accountType, accountRef, holderId, keepId, kind)
	local result, errorCode = callDatabase('Execute', [[
		UPDATE coe_banking_cards SET blocked_reason = 'replaced', blocked_at = CURRENT_TIMESTAMP(3)
		WHERE account_type = ? AND account_ref = ? AND holder_id = ? AND id <> ? AND kind = ? AND blocked_reason IS NULL
	]], { accountType, accountRef, holderId, keepId, kind or 'physical' })
	if not result then
		return nil, errorCode or 'database_error'
	end
	return true
end

function BankingPersistence.SetAttempts(cardId, attempts, blockReason)
	local result, errorCode
	if blockReason then
		result, errorCode = callDatabase('Execute',
			'UPDATE coe_banking_cards SET attempts = ?, blocked_reason = ?, blocked_at = CURRENT_TIMESTAMP(3) WHERE id = ?',
			{ attempts, blockReason, cardId })
	else
		result, errorCode = callDatabase('Execute', 'UPDATE coe_banking_cards SET attempts = ? WHERE id = ?', { attempts, cardId })
	end
	if not result then
		return nil, errorCode or 'database_error'
	end
	return true
end

-- Nova senha: zera tentativas e desfaz só o bloqueio por senha.
function BankingPersistence.SetPin(cardId, pinHash, pinSalt)
	local result, errorCode = callDatabase('Execute', [[
		UPDATE coe_banking_cards SET pin_hash = ?, pin_salt = ?, attempts = 0,
			blocked_reason = IF(blocked_reason = 'pin', NULL, blocked_reason),
			blocked_at = IF(blocked_reason IS NULL, NULL, blocked_at)
		WHERE id = ?
	]], { pinHash, pinSalt, cardId })
	if not result then
		return nil, errorCode or 'database_error'
	end
	return true
end

-- Personagem ativo (não arquivado) pelo stateId, mesmo offline.
function BankingPersistence.FindCharacterByStateId(stateId)
	local rows, errorCode = callDatabase('Query',
		'SELECT character_id, first_name, last_name FROM coe_characters WHERE state_id = ? AND archived_at IS NULL LIMIT 1',
		{ stateId })
	if not rows then
		return nil, errorCode or 'database_error'
	end
	local row = rows[1]
	if not row then
		return nil, 'character_not_found'
	end
	return { characterId = tostring(row.character_id), name = ((row.first_name or '') .. ' ' .. (row.last_name or '')):gsub('^%s+', ''):gsub('%s+$', '') }
end

-- Crédito ------------------------------------------------------------------------------------------

local CREDIT_COLUMNS = 'character_id, tier, credit_limit, open_amount, invoice_amount, invoice_min, invoice_paid, due_at, closes_at, '
	.. 'late, late_since, interest_at, on_time, late_count, points, version, custom_limit, tier_locked'

local function int(value)
	return math.tointeger(tonumber(value) or 0) or 0
end

local function optional(value)
	if value == nil then
		return nil
	end
	return math.tointeger(tonumber(value))
end

local function toCredit(row)
	return {
		characterId = tostring(row.character_id),
		tier = row.tier,
		limit = int(row.credit_limit),
		open = int(row.open_amount),
		invoice = int(row.invoice_amount),
		invoiceMin = int(row.invoice_min),
		invoicePaid = int(row.invoice_paid),
		dueAt = optional(row.due_at),
		closesAt = int(row.closes_at),
		late = int(row.late) == 1,
		lateSince = optional(row.late_since),
		interestAt = optional(row.interest_at),
		onTime = int(row.on_time),
		lateCount = int(row.late_count),
		points = int(row.points),
		version = int(row.version),
		customLimit = optional(row.custom_limit),
		tierLocked = int(row.tier_locked) == 1
	}
end

function BankingPersistence.Credit(characterId)
	local rows, errorCode = callDatabase('Query', 'SELECT ' .. CREDIT_COLUMNS .. ' FROM coe_banking_credit WHERE character_id = ?', { characterId })
	if not rows then
		return nil, errorCode or 'database_error'
	end
	return rows[1] and toCredit(rows[1]) or false
end

-- Lançamentos só entram se a conta estiver na versão esperada (o UPDATE otimista aplicou).
local function entryStatements(characterId, entries, version)
	local statements = {}
	for _, entry in ipairs(entries or {}) do
		statements[#statements + 1] = {
			sql = [[INSERT INTO coe_banking_credit_entries (character_id, kind, amount, description, created_at)
				SELECT character_id, ?, ?, ?, ? FROM coe_banking_credit WHERE character_id = ? AND version = ?]],
			parameters = { entry.kind, entry.amount, (entry.description or ''):sub(1, 64), entry.at, characterId, version }
		}
	end
	return statements
end

function BankingPersistence.InsertCredit(state, now, entries)
	local statements = { {
		sql = [[INSERT INTO coe_banking_credit (character_id, tier, credit_limit, closes_at, created_at, custom_limit, tier_locked)
			VALUES (?, ?, ?, ?, ?, NULLIF(?, -1), ?)]],
		parameters = { state.characterId, state.tier, state.limit, state.closesAt, now, state.customLimit or -1, state.tierLocked and 1 or 0 }
	} }
	for _, statement in ipairs(entryStatements(state.characterId, entries, 0)) do
		statements[#statements + 1] = statement
	end
	local result, errorCode = callDatabase('Transaction', statements)
	if not result then
		if tostring(errorCode):upper():find('DUP', 1, true) then
			return nil, 'conflict'
		end
		return nil, errorCode or 'database_error'
	end
	state.version = 0
	return true
end

-- Grava o estado só se ninguém gravou antes (`version`); lançamentos na mesma transação.
function BankingPersistence.SaveCredit(state, entries)
	local statements = { {
		sql = [[
			UPDATE coe_banking_credit SET tier = ?, credit_limit = ?, open_amount = ?, invoice_amount = ?, invoice_min = ?,
				invoice_paid = ?, due_at = NULLIF(?, 0), closes_at = ?, late = ?, late_since = NULLIF(?, 0), interest_at = NULLIF(?, 0), on_time = ?,
				late_count = ?, points = ?, custom_limit = NULLIF(?, -1), tier_locked = ?, version = version + 1
			WHERE character_id = ? AND version = ?
		]],
		parameters = {
			state.tier, state.limit, state.open, state.invoice, state.invoiceMin, state.invoicePaid, state.dueAt or 0, state.closesAt,
			state.late and 1 or 0, state.lateSince or 0, state.interestAt or 0, state.onTime, state.lateCount, state.points,
			state.customLimit or -1, state.tierLocked and 1 or 0,
			state.characterId, state.version
		}
	} }
	for _, statement in ipairs(entryStatements(state.characterId, entries, state.version + 1)) do
		statements[#statements + 1] = statement
	end
	local result, errorCode = callDatabase('Transaction', statements)
	if not result then
		return nil, errorCode or 'database_error'
	end
	if (tonumber(result[1] and result[1].affectedRows) or 0) ~= 1 then
		return nil, 'conflict'
	end
	state.version = state.version + 1
	return true
end

-- Contas com fechamento, vencimento ou juros pendentes até `now`.
function BankingPersistence.CreditPending(now, autoDebitBefore, limit)
	local rows, errorCode = callDatabase('Query', [[
		SELECT character_id FROM coe_banking_credit
		WHERE closes_at <= ? OR due_at <= ? OR (late = 1 AND (interest_at <= ? OR (late_since <= ? AND invoice_amount > 0)))
		LIMIT ]] .. math.floor(limit), { now, now, now, autoDebitBefore })
	if not rows then
		return nil, errorCode or 'database_error'
	end
	local ids = {}
	for _, row in ipairs(rows) do
		ids[#ids + 1] = tostring(row.character_id)
	end
	return ids
end

function BankingPersistence.CreditEntries(characterId, limit)
	local rows, errorCode = callDatabase('Query',
		'SELECT kind, amount, description, created_at FROM coe_banking_credit_entries WHERE character_id = ? ORDER BY id DESC LIMIT ' .. math.floor(limit),
		{ characterId })
	if not rows then
		return nil, errorCode or 'database_error'
	end
	local list = {}
	for _, row in ipairs(rows) do
		list[#list + 1] = { kind = row.kind, amount = int(row.amount), description = row.description or '', at = int(row.created_at) }
	end
	return list
end
-- Admin: cartões ---------------------------------------------------------------------------------

-- Novo prazo de validade; também desfaz bloqueio por senha (staff liberando o cartão).
function BankingPersistence.Extend(cardId, expiresAt)
	local result, errorCode = callDatabase('Execute', 'UPDATE coe_banking_cards SET expires_at = ? WHERE id = ?', { expiresAt, cardId })
	if not result then
		return nil, errorCode or 'database_error'
	end
	return true
end

-- Desbloqueio pela staff: só bloqueios por senha ou manuais da staff; substituídos continuam fora.
function BankingPersistence.Unblock(cardId)
	local result, errorCode = callDatabase('Execute', [[
		UPDATE coe_banking_cards SET blocked_reason = NULL, blocked_at = NULL, attempts = 0
		WHERE id = ? AND blocked_reason IN ('pin', 'staff')
	]], { cardId })
	if not result then
		return nil, errorCode or 'database_error'
	end
	return (tonumber(result.affectedRows) or 0) == 1
end

function BankingPersistence.CharacterCards(characterId)
	local rows, errorCode = callDatabase('Query',
		'SELECT ' .. CARD_COLUMNS .. ' FROM coe_banking_cards WHERE account_type = ? AND account_ref = ? ORDER BY id DESC LIMIT 20',
		{ 'personal', characterId })
	if not rows then
		return nil, errorCode or 'database_error'
	end
	local cards = {}
	for _, row in ipairs(rows) do
		cards[#cards + 1] = toCard(row)
	end
	return cards
end

-- Níveis -------------------------------------------------------------------------------------------

function BankingPersistence.Tiers()
	local rows, errorCode = callDatabase('Query',
		'SELECT id, label, min_score, credit_limit, points_per_100, fee, free_atm FROM coe_banking_tiers', {})
	if not rows then
		return nil, errorCode or 'database_error'
	end
	local list = {}
	for _, row in ipairs(rows) do
		list[row.id] = {
			id = row.id, label = row.label, minScore = int(row.min_score), limit = int(row.credit_limit),
			pointsPer100 = tonumber(row.points_per_100) or 0, fee = int(row.fee), freeAtm = int(row.free_atm) == 1
		}
	end
	return list
end

function BankingPersistence.SaveTiers(tiers, now)
	local statements = {}
	for _, tier in ipairs(tiers) do
		statements[#statements + 1] = {
			sql = [[INSERT INTO coe_banking_tiers (id, label, min_score, credit_limit, points_per_100, fee, free_atm, updated_at)
				VALUES (?, ?, ?, ?, ?, ?, ?, ?)
				ON DUPLICATE KEY UPDATE label = VALUES(label), min_score = VALUES(min_score), credit_limit = VALUES(credit_limit),
					points_per_100 = VALUES(points_per_100), fee = VALUES(fee), free_atm = VALUES(free_atm), updated_at = VALUES(updated_at)]],
			parameters = { tier.id, tier.label, tier.minScore, tier.limit, tier.pointsPer100, tier.fee, tier.freeAtm and 1 or 0, now }
		}
	end
	local result, errorCode = callDatabase('Transaction', statements)
	if not result then
		return nil, errorCode or 'database_error'
	end
	return true
end

-- Lançamento avulso no extrato de crédito (sem conta de crédito exigida; ex.: empréstimos).
function BankingPersistence.CreditNote(characterId, entry)
	local result, errorCode = callDatabase('Execute', [[
		INSERT INTO coe_banking_credit_entries (character_id, kind, amount, description, created_at) VALUES (?, ?, ?, ?, ?)
	]], { characterId, entry.kind, entry.amount, (entry.description or ''):sub(1, 64), entry.at })
	if not result then
		return nil, errorCode or 'database_error'
	end
	return true
end

-- Empréstimos --------------------------------------------------------------------------------------

local LOAN_COLUMNS = 'l.id, l.character_id, l.principal, l.rate, l.total, l.installments, l.paid_count, l.paid_amount, l.remaining, '
	.. 'l.due_at, l.late, l.on_time, l.late_count, l.status, l.note, l.version, l.created_at, l.closed_at, l.late_rate, l.interest, '
	.. 'l.interest_at, l.business_id, l.business_label'

local function toLoan(row)
	return {
		id = int(row.id),
		characterId = tostring(row.character_id),
		principal = int(row.principal),
		rate = tonumber(row.rate) or 0,
		total = int(row.total),
		installments = int(row.installments),
		paidCount = int(row.paid_count),
		paidAmount = int(row.paid_amount),
		remaining = int(row.remaining),
		dueAt = optional(row.due_at),
		late = int(row.late) == 1,
		onTime = int(row.on_time),
		lateCount = int(row.late_count),
		status = row.status,
		note = row.note or '',
		version = int(row.version),
		createdAt = int(row.created_at),
		closedAt = optional(row.closed_at),
		lateRate = tonumber(row.late_rate) or 0,
		interest = int(row.interest),
		interestAt = optional(row.interest_at),
		businessId = type(row.business_id) == 'string' and row.business_id ~= '' and row.business_id or nil,
		businessLabel = row.business_label or ''
	}
end

local function loanList(rows)
	local list = {}
	for _, row in ipairs(rows) do
		list[#list + 1] = toLoan(row)
	end
	return list
end

-- Empréstimos em que o personagem é devedor (pessoais e empresariais).
function BankingPersistence.Loans(characterId, limit)
	local rows, errorCode = callDatabase('Query',
		'SELECT ' .. LOAN_COLUMNS .. ' FROM coe_banking_loans l JOIN coe_banking_loan_debtors d ON d.loan_id = l.id '
		.. 'WHERE d.character_id = ? ORDER BY (l.status = \'active\') DESC, l.id DESC LIMIT ' .. math.floor(limit or 10), { characterId })
	if not rows then
		return nil, errorCode or 'database_error'
	end
	return loanList(rows)
end

function BankingPersistence.BusinessLoans(businessId, limit)
	local rows, errorCode = callDatabase('Query',
		'SELECT ' .. LOAN_COLUMNS .. ' FROM coe_banking_loans l WHERE l.business_id = ? '
		.. 'ORDER BY (l.status = \'active\') DESC, l.id DESC LIMIT ' .. math.floor(limit or 10), { businessId })
	if not rows then
		return nil, errorCode or 'database_error'
	end
	return loanList(rows)
end

function BankingPersistence.Loan(loanId)
	local rows, errorCode = callDatabase('Query', 'SELECT ' .. LOAN_COLUMNS .. ' FROM coe_banking_loans l WHERE l.id = ?', { loanId })
	if not rows then
		return nil, errorCode or 'database_error'
	end
	if not rows[1] then
		return nil, 'loan_not_found'
	end
	return toLoan(rows[1])
end

function BankingPersistence.Debtors(loanId)
	local rows, errorCode = callDatabase('Query', 'SELECT character_id FROM coe_banking_loan_debtors WHERE loan_id = ?', { loanId })
	if not rows then
		return nil, errorCode or 'database_error'
	end
	local list = {}
	for _, row in ipairs(rows) do
		list[#list + 1] = tostring(row.character_id)
	end
	return list
end

-- Empréstimos pessoais ativos do personagem.
function BankingPersistence.ActiveLoans(characterId)
	local rows, errorCode = callDatabase('Query',
		'SELECT COUNT(*) AS total FROM coe_banking_loans WHERE character_id = ? AND business_id IS NULL AND status = \'active\'',
		{ characterId })
	if not rows then
		return nil, errorCode or 'database_error'
	end
	return int(rows[1] and rows[1].total)
end

function BankingPersistence.ActiveBusinessLoans(businessId)
	local rows, errorCode = callDatabase('Query',
		'SELECT COUNT(*) AS total FROM coe_banking_loans WHERE business_id = ? AND status = \'active\'', { businessId })
	if not rows then
		return nil, errorCode or 'database_error'
	end
	return int(rows[1] and rows[1].total)
end

-- `debtors`: personagens que respondem pela dívida (o titular entra sempre). `business`: { id, label } ou nil.
function BankingPersistence.InsertLoan(characterId, loan, now, debtors, business)
	local statements = { {
		sql = [[
			INSERT INTO coe_banking_loans (character_id, principal, rate, total, installments, remaining, due_at, note, created_at,
				late_rate, business_id, business_label)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULLIF(?, ''), ?)
		]],
		parameters = {
			characterId, loan.principal, loan.rate, loan.total, loan.installments, loan.remaining, loan.dueAt, loan.note, now,
			loan.lateRate or 0, business and business.id or '', business and business.label or ''
		}
	} }
	local seen = {}
	for _, debtor in ipairs({ characterId, table.unpack(debtors or {}) }) do
		debtor = tostring(debtor)
		if not seen[debtor] then
			seen[debtor] = true
			statements[#statements + 1] = {
				sql = 'INSERT INTO coe_banking_loan_debtors (loan_id, character_id) VALUES (LAST_INSERT_ID(), ?)',
				parameters = { debtor }
			}
		end
	end
	local result, errorCode = callDatabase('Transaction', statements)
	if not result then
		return nil, errorCode or 'database_error'
	end
	loan.id = int(result[1] and result[1].insertId)
	loan.characterId = characterId
	loan.businessId = business and business.id or nil
	loan.businessLabel = business and business.label or ''
	loan.version = 0
	loan.createdAt = now
	return loan.id
end

function BankingPersistence.DeleteLoan(loanId)
	return callDatabase('Transaction', {
		{ sql = 'DELETE FROM coe_banking_loan_debtors WHERE loan_id = ? AND EXISTS (SELECT 1 FROM coe_banking_loans WHERE id = ? AND paid_amount = 0)',
			parameters = { loanId, loanId } },
		{ sql = 'DELETE FROM coe_banking_loans WHERE id = ? AND paid_amount = 0', parameters = { loanId } }
	})
end

-- Grava o empréstimo só na versão esperada; lançamentos no extrato de crédito de cada devedor, na mesma transação.
function BankingPersistence.SaveLoan(loan, entries, now)
	local closed = loan.status ~= 'active'
	local statements = { {
		sql = [[
			UPDATE coe_banking_loans SET paid_count = ?, paid_amount = ?, remaining = ?, due_at = NULLIF(?, 0), late = ?, on_time = ?,
				late_count = ?, status = ?, closed_at = NULLIF(?, 0), interest = ?, interest_at = NULLIF(?, 0), version = version + 1
			WHERE id = ? AND version = ?
		]],
		parameters = {
			loan.paidCount, loan.paidAmount, loan.remaining, loan.dueAt or 0, loan.late and 1 or 0, loan.onTime, loan.lateCount,
			loan.status, closed and now or 0, loan.interest or 0, loan.interestAt or 0, loan.id, loan.version
		}
	} }
	for _, entry in ipairs(entries or {}) do
		statements[#statements + 1] = {
			sql = [[INSERT INTO coe_banking_credit_entries (character_id, kind, amount, description, created_at)
				SELECT d.character_id, ?, ?, ?, ? FROM coe_banking_loan_debtors d JOIN coe_banking_loans l ON l.id = d.loan_id
				WHERE l.id = ? AND l.version = ?]],
			parameters = { entry.kind, entry.amount, (entry.description or ''):sub(1, 64), entry.at, loan.id, loan.version + 1 }
		}
	end
	local result, errorCode = callDatabase('Transaction', statements)
	if not result then
		return nil, errorCode or 'database_error'
	end
	if (tonumber(result[1] and result[1].affectedRows) or 0) ~= 1 then
		return nil, 'conflict'
	end
	loan.version = loan.version + 1
	if closed then
		loan.closedAt = now
	end
	return true
end

-- Ids dos empréstimos com parcela vencida (ainda não marcada em atraso, ou em atraso aguardando débito e juros).
function BankingPersistence.LoansDue(now, limit)
	local rows, errorCode = callDatabase('Query',
		'SELECT id FROM coe_banking_loans WHERE status = \'active\' AND due_at <= ? ORDER BY due_at LIMIT ' .. math.floor(limit), { now })
	if not rows then
		return nil, errorCode or 'database_error'
	end
	local ids = {}
	for _, row in ipairs(rows) do
		ids[#ids + 1] = int(row.id)
	end
	return ids
end

-- Pedidos de empréstimo empresarial -----------------------------------------------------------------

local REQUEST_COLUMNS = 'id, business_id, business_label, character_id, principal, installments, note, score, rate, late_rate, '
	.. 'status, reason, loan_id, created_at, decided_at'

local function toRequest(row)
	return {
		id = int(row.id),
		businessId = row.business_id,
		businessLabel = row.business_label or '',
		characterId = tostring(row.character_id),
		principal = int(row.principal),
		installments = int(row.installments),
		note = row.note or '',
		score = int(row.score),
		rate = tonumber(row.rate) or 0,
		lateRate = tonumber(row.late_rate) or 0,
		status = row.status,
		reason = row.reason or '',
		loanId = optional(row.loan_id),
		createdAt = int(row.created_at),
		decidedAt = optional(row.decided_at)
	}
end

function BankingPersistence.InsertRequest(request, now)
	local result, errorCode = callDatabase('Execute', [[
		INSERT INTO coe_banking_loan_requests (business_id, business_label, character_id, principal, installments, note, score, rate,
			late_rate, created_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	]], {
		request.businessId, request.businessLabel, request.characterId, request.principal, request.installments, request.note,
		request.score, request.rate, request.lateRate, now
	})
	if not result then
		return nil, errorCode or 'database_error'
	end
	return int(result.insertId)
end

function BankingPersistence.Request(requestId)
	local rows, errorCode = callDatabase('Query', 'SELECT ' .. REQUEST_COLUMNS .. ' FROM coe_banking_loan_requests WHERE id = ?', { requestId })
	if not rows then
		return nil, errorCode or 'database_error'
	end
	if not rows[1] then
		return nil, 'request_not_found'
	end
	return toRequest(rows[1])
end

-- status: 'pending' (fila da staff) ou nil (todos, mais recentes primeiro). businessId opcional.
function BankingPersistence.Requests(status, businessId, limit)
	local where, parameters = {}, {}
	if status then
		where[#where + 1] = 'status = ?'
		parameters[#parameters + 1] = status
	end
	if businessId then
		where[#where + 1] = 'business_id = ?'
		parameters[#parameters + 1] = businessId
	end
	local rows, errorCode = callDatabase('Query', 'SELECT ' .. REQUEST_COLUMNS .. ' FROM coe_banking_loan_requests'
		.. (#where > 0 and (' WHERE ' .. table.concat(where, ' AND ')) or '') .. ' ORDER BY id DESC LIMIT ' .. math.floor(limit or 20),
		parameters)
	if not rows then
		return nil, errorCode or 'database_error'
	end
	local list = {}
	for _, row in ipairs(rows) do
		list[#list + 1] = toRequest(row)
	end
	return list
end

-- Muda o status só se ainda estiver em `from`. Devolve true se mudou.
function BankingPersistence.DecideRequest(requestId, from, to, reason, loanId, now)
	local result, errorCode = callDatabase('Execute', [[
		UPDATE coe_banking_loan_requests SET status = ?, reason = ?, loan_id = NULLIF(?, 0), decided_at = NULLIF(?, 0)
		WHERE id = ? AND status = ?
	]], { to, (reason or ''):sub(1, 64), loanId or 0, now or 0, requestId, from })
	if not result then
		return nil, errorCode or 'database_error'
	end
	return (tonumber(result.affectedRows) or 0) == 1
end
-- Conta empresarial ---------------------------------------------------------------------------------

-- Cartões empresariais do negócio (os mais novos primeiro).
function BankingPersistence.BusinessCards(businessId, limit)
	local rows, errorCode = callDatabase('Query',
		'SELECT ' .. CARD_COLUMNS .. ' FROM coe_banking_cards WHERE account_type = ? AND account_ref = ? ORDER BY id DESC LIMIT ' .. math.floor(limit or 50),
		{ 'business', businessId })
	if not rows then
		return nil, errorCode or 'database_error'
	end
	local cards = {}
	for _, row in ipairs(rows) do
		cards[#cards + 1] = toCard(row)
	end
	return cards
end

-- Cartões empresariais ativos (não bloqueados) do negócio, para o teto de cartões.
function BankingPersistence.CountBusinessCards(businessId, now)
	local rows, errorCode = callDatabase('Query',
		'SELECT COUNT(*) AS total FROM coe_banking_cards WHERE account_type = ? AND account_ref = ? AND blocked_reason IS NULL AND (expires_at IS NULL OR expires_at > ?)',
		{ 'business', businessId, now })
	if not rows then
		return nil, errorCode or 'database_error'
	end
	return math.tointeger(tonumber(rows[1] and rows[1].total)) or 0
end

-- Limite diário (0 = sem limite).
function BankingPersistence.SetDailyLimit(cardId, limit)
	local result, errorCode = callDatabase('Execute', 'UPDATE coe_banking_cards SET daily_limit = NULLIF(?, 0) WHERE id = ?', { limit or 0, cardId })
	if not result then
		return nil, errorCode or 'database_error'
	end
	return (tonumber(result.affectedRows) or 0) == 1
end

-- Reserva `amount` no limite do dia do cartão (atômico): false quando passaria do limite.
function BankingPersistence.Spend(cardId, amount, day)
	local result, errorCode = callDatabase('Execute', [[
		UPDATE coe_banking_cards SET spent_amount = IF(spent_day = ?, spent_amount, 0) + ?, spent_day = ?
		WHERE id = ? AND (daily_limit IS NULL OR IF(spent_day = ?, spent_amount, 0) + ? <= daily_limit)
	]], { day, amount, day, cardId, day, amount })
	if not result then
		return nil, errorCode or 'database_error'
	end
	return (tonumber(result.affectedRows) or 0) == 1
end

-- Devolve ao limite do dia (operação desfeita ou estorno no mesmo dia).
function BankingPersistence.Unspend(cardId, amount, day)
	local result, errorCode = callDatabase('Execute',
		'UPDATE coe_banking_cards SET spent_amount = GREATEST(CAST(spent_amount AS SIGNED) - ?, 0) WHERE id = ? AND spent_day = ?',
		{ amount, cardId, day })
	if not result then
		return nil, errorCode or 'database_error'
	end
	return true
end

-- Operação da conta empresarial (pendente até o dinheiro mover): devolve o id para a referência `bop:<id>`.
function BankingPersistence.InsertBusinessOp(op, now)
	local result, errorCode = callDatabase('Execute', [[
		INSERT INTO coe_banking_business_ops (business_id, character_id, actor_name, kind, amount, counterparty, counterparty_label, memo, status, created_at)
		VALUES (?, NULLIF(?, 0), ?, ?, ?, ?, ?, ?, 'pending', ?)
	]], { op.businessId, tonumber(op.characterId) or 0, (op.actorName or ''):sub(1, 64), op.kind, op.amount, (op.counterparty or ''):sub(1, 64),
		(op.counterpartyLabel or ''):sub(1, 64), (op.memo or ''):sub(1, 96), now })
	if not result then
		return nil, errorCode or 'database_error'
	end
	return math.tointeger(tonumber(result.insertId))
end

function BankingPersistence.FinishBusinessOp(opId, status)
	return callDatabase('Execute', 'UPDATE coe_banking_business_ops SET status = ? WHERE id = ?', { status, opId }) ~= nil
end

-- Operações pelo id (ids inteiros validados): { [id] = op }.
function BankingPersistence.BusinessOps(ids)
	if #ids == 0 then
		return {}
	end
	local rows, errorCode = callDatabase('Query',
		'SELECT id, character_id, actor_name, kind, amount, counterparty, counterparty_label, memo FROM coe_banking_business_ops WHERE id IN ('
			.. string.rep('?', #ids, ', ') .. ')', ids)
	if not rows then
		return nil, errorCode or 'database_error'
	end
	local ops = {}
	for _, row in ipairs(rows) do
		local id = math.tointeger(tonumber(row.id))
		ops[id] = {
			id = id, characterId = row.character_id and tostring(row.character_id) or nil, actorName = row.actor_name or '',
			kind = row.kind, amount = math.tointeger(tonumber(row.amount)) or 0, counterparty = row.counterparty or '',
			counterpartyLabel = row.counterparty_label or '', memo = row.memo or ''
		}
	end
	return ops
end

-- Nomes de personagens pelo id (para o extrato: quem recebeu salário, quem depositou).
function BankingPersistence.CharacterNames(ids)
	if #ids == 0 then
		return {}
	end
	local rows, errorCode = callDatabase('Query',
		'SELECT character_id, first_name, last_name FROM coe_characters WHERE character_id IN (' .. string.rep('?', #ids, ', ') .. ')', ids)
	if not rows then
		return nil, errorCode or 'database_error'
	end
	local names = {}
	for _, row in ipairs(rows) do
		names[tostring(row.character_id)] = ((row.first_name or '') .. ' ' .. (row.last_name or '')):gsub('^%s+', ''):gsub('%s+$', '')
	end
	return names
end
