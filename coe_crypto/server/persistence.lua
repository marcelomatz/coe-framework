CryptoPersistence = {}

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

local function transaction(statements)
	return callDatabase('Transaction', statements)
end

local function int(value)
	return math.tointeger(tonumber(value))
end

local function str(value)
	return value ~= nil and tostring(value) or ''
end

local function placeholders(count)
	return ('?'):rep(count, ', ')
end

-- Linha do livro. Colunas opcionais (nil) ficam fora do INSERT e caem no NULL padrão: a lista de parâmetros
-- nunca tem buracos (nil no meio de uma tabela Lua não atravessa o export).
local function txStatement(entry, now)
	local columns = { 'kind', 'amount', 'fee', 'fiat', 'memo', 'created_at' }
	local parameters = { entry.kind, entry.amount, entry.fee or 0, entry.fiat or 0, entry.memo or '', now }
	local optional = { from_address = entry.from, to_address = entry.to, character_id = entry.characterId, device_key = entry.deviceKey }
	for _, column in ipairs({ 'from_address', 'to_address', 'character_id', 'device_key' }) do
		if optional[column] ~= nil then
			columns[#columns + 1] = column
			parameters[#parameters + 1] = optional[column]
		end
	end
	return {
		sql = ('INSERT INTO coe_crypto_tx (%s) VALUES (%s)'):format(table.concat(columns, ', '), placeholders(#columns)),
		parameters = parameters
	}
end

-- Crédito que nunca perde moeda: se o endereço não existir, nasce sem chave (moeda "queimada", como na vida real).
-- O servidor confere o destino antes; isto só garante a consistência numa corrida.
local function creditStatement(address, units, now)
	return {
		sql = 'INSERT INTO coe_crypto_wallets (address, key_hash, balance, created_at) VALUES (?, \'\', ?, ?) ON DUPLICATE KEY UPDATE balance = balance + VALUES(balance)',
		parameters = { address, units, now }
	}
end

local function debitStatement(address, units)
	return { sql = 'UPDATE coe_crypto_wallets SET balance = balance - ? WHERE address = ?', parameters = { units, address } }
end

-- Migrações, modo estrito (saldo UNSIGNED), carteira de reserva da corretora e contadores.
function CryptoPersistence.Initialize(config, now)
	local migrated, errorCode = CoeMigrations.Run({
		tableName = 'coe_crypto_schema_migrations',
		migrations = CryptoMigrations,
		execute = execute,
		query = query
	})
	if not migrated then
		return false, errorCode
	end
	local rows = query('SELECT @@SESSION.sql_mode AS mode', {})
	local mode = rows and rows[1] and rows[1].mode or ''
	if not tostring(mode):find('STRICT', 1, true) then
		return false, 'sql_mode_not_strict'
	end
	local reserve = config.Exchange.ReserveAddress
	local created, createError = execute('INSERT IGNORE INTO coe_crypto_wallets (address, key_hash, balance, created_at) VALUES (?, \'\', ?, ?)',
		{ reserve, config.Exchange.Reserve, now })
	if not created then
		return false, createError
	end
	if (int(created.affectedRows) or 0) == 1 then
		local genesis = txStatement({ kind = 'genesis', to = reserve, amount = config.Exchange.Reserve }, now)
		execute(genesis.sql, genesis.parameters)
	end
	execute('INSERT IGNORE INTO coe_crypto_state (name, value) VALUES (\'minted\', 0)', {})
	-- Custódia do mercado: carteira sem chave, começa vazia.
	if config.Escrow and config.Escrow.Address then
		execute('INSERT IGNORE INTO coe_crypto_wallets (address, key_hash, balance, created_at) VALUES (?, \'\', 0, ?)', { config.Escrow.Address, now })
	end
	return true
end

-- Carteiras ------------------------------------------------------------------------------------------

-- { address, hash, balance } ou false (não existe) ou nil + erro.
function CryptoPersistence.Wallet(address)
	local rows, errorCode = query('SELECT address, key_hash, balance FROM coe_crypto_wallets WHERE address = ?', { address })
	if not rows then
		return nil, errorCode
	end
	local row = rows[1]
	if not row then
		return false
	end
	return { address = str(row.address), hash = str(row.key_hash), balance = int(row.balance) or 0 }
end

-- [address] = saldo, só dos que existem.
function CryptoPersistence.Balances(addresses)
	if #addresses == 0 then
		return {}
	end
	local rows, errorCode = query('SELECT address, balance FROM coe_crypto_wallets WHERE address IN (' .. placeholders(#addresses) .. ')', addresses)
	if not rows then
		return nil, errorCode
	end
	local map = {}
	for _, row in ipairs(rows) do
		map[str(row.address)] = int(row.balance) or 0
	end
	return map
end

-- Endereço em uso devolve nil, 'address_taken'.
function CryptoPersistence.InsertWallet(address, hash, characterId, now)
	local result, errorCode = execute('INSERT INTO coe_crypto_wallets (address, key_hash, balance, created_by, created_at) VALUES (?, ?, 0, ?, ?)',
		{ address, hash, characterId, now })
	if not result then
		if tostring(errorCode):upper():find('DUP', 1, true) then
			return nil, 'address_taken'
		end
		return nil, errorCode
	end
	return true
end

-- Troca o hash da chave (carteiras antigas passam para o formato novo).
function CryptoPersistence.UpdateWalletHash(address, keyHash)
	return execute('UPDATE coe_crypto_wallets SET key_hash = ? WHERE address = ?', { keyHash, address })
end

-- A chave desta carteira está guardada em algum aparelho? (confere carteiras de hash antigo)
function CryptoPersistence.KeyKnown(address, key)
	local rows = query('SELECT 1 AS ok FROM coe_crypto_keystore WHERE address = ? AND secret = ? LIMIT 1', { address, key })
	return rows ~= nil and rows[1] ~= nil
end

function CryptoPersistence.CreatedSince(characterId, since)
	local rows, errorCode = query('SELECT COUNT(*) AS total FROM coe_crypto_wallets WHERE created_by = ? AND created_at >= ?', { characterId, since })
	if not rows then
		return nil, errorCode
	end
	return int(rows[1] and rows[1].total) or 0
end

-- Chaves nos aparelhos -------------------------------------------------------------------------------

function CryptoPersistence.Keystore(deviceKey)
	local rows, errorCode = query('SELECT address, secret, label, added_at FROM coe_crypto_keystore WHERE device_key = ? ORDER BY added_at, address', { deviceKey })
	if not rows then
		return nil, errorCode
	end
	local list = {}
	for _, row in ipairs(rows) do
		list[#list + 1] = { address = str(row.address), key = str(row.secret), label = str(row.label), addedAt = int(row.added_at) }
	end
	return list
end

function CryptoPersistence.AddKey(deviceKey, address, key, label, now)
	return execute('INSERT INTO coe_crypto_keystore (device_key, address, secret, label, added_at) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE label = VALUES(label)',
		{ deviceKey, address, key, label, now })
end

function CryptoPersistence.RemoveKey(deviceKey, address)
	return execute('DELETE FROM coe_crypto_keystore WHERE device_key = ? AND address = ?', { deviceKey, address })
end

function CryptoPersistence.RenameKey(deviceKey, address, label)
	return execute('UPDATE coe_crypto_keystore SET label = ? WHERE device_key = ? AND address = ?', { label, deviceKey, address })
end

-- Movimentos ------------------------------------------------------------------------------------------

-- Debita `amount + fee` de `from`, credita `amount` em `to` e registra no livro, numa transação.
-- entry: { kind, from, to, amount, fee, fiat, memo, characterId, deviceKey }.
function CryptoPersistence.Move(entry, now)
	local result, errorCode = transaction({
		debitStatement(entry.from, entry.amount + (entry.fee or 0)),
		creditStatement(entry.to, entry.amount, now),
		txStatement(entry, now)
	})
	if not result then
		return nil, errorCode or 'database_error'
	end
	if (int(result[1] and result[1].affectedRows) or 0) ~= 1 then
		return nil, 'wallet_not_found'
	end
	return int(result[3] and result[3].insertId) or true
end

-- Emissão da mineração: credita cada carteira, registra e soma no contador, numa transação.
function CryptoPersistence.Mint(payouts, total, now)
	local statements = {}
	for _, payout in ipairs(payouts) do
		statements[#statements + 1] = creditStatement(payout.address, payout.units, now)
		statements[#statements + 1] = txStatement({ kind = 'mint', to = payout.address, amount = payout.units, memo = payout.memo or '' }, now)
	end
	statements[#statements + 1] = { sql = 'UPDATE coe_crypto_state SET value = value + ? WHERE name = \'minted\'', parameters = { total } }
	local result, errorCode = transaction(statements)
	if not result then
		return nil, errorCode or 'database_error'
	end
	return true
end

function CryptoPersistence.Minted()
	local rows, errorCode = query('SELECT value FROM coe_crypto_state WHERE name = \'minted\'', {})
	if not rows then
		return nil, errorCode
	end
	return int(rows[1] and rows[1].value) or 0
end

-- Livro público de um endereço (mais recentes primeiro). before: id da última linha já mostrada.
function CryptoPersistence.History(address, before, limit)
	local parameters = { address, address }
	local filter = ''
	if before then
		filter = ' AND id < ?'
		parameters[#parameters + 1] = before
	end
	local rows, errorCode = query('SELECT id, kind, from_address, to_address, amount, fee, memo, created_at FROM coe_crypto_tx WHERE (from_address = ? OR to_address = ?)'
		.. filter .. (' ORDER BY id DESC LIMIT %d'):format(math.floor(limit) + 1), parameters)
	if not rows then
		return nil, errorCode
	end
	local list = {}
	for index, row in ipairs(rows) do
		if index > limit then
			break
		end
		list[#list + 1] = {
			id = int(row.id), kind = str(row.kind), from = row.from_address and str(row.from_address) or nil,
			to = row.to_address and str(row.to_address) or nil, amount = int(row.amount) or 0, fee = int(row.fee) or 0,
			memo = str(row.memo), at = int(row.created_at)
		}
	end
	return list, #rows > limit
end

-- $ movimentado na corretora pelo personagem desde `since` (kind: buy | sell).
function CryptoPersistence.FiatUsed(characterId, kind, since)
	local rows, errorCode = query('SELECT COALESCE(SUM(fiat), 0) AS total FROM coe_crypto_tx WHERE character_id = ? AND kind = ? AND created_at >= ?',
		{ characterId, kind, since })
	if not rows then
		return nil, errorCode
	end
	return int(tonumber(rows[1] and rows[1].total)) or 0
end

-- Cotações --------------------------------------------------------------------------------------------

-- Últimas `limit` cotações, da mais antiga para a mais nova: { { price, at } }.
function CryptoPersistence.Prices(limit)
	local rows, errorCode = query(('SELECT price, created_at FROM coe_crypto_prices ORDER BY id DESC LIMIT %d'):format(math.floor(limit)), {})
	if not rows then
		return nil, errorCode
	end
	local list = {}
	for index = #rows, 1, -1 do
		list[#list + 1] = { price = int(rows[index].price) or 0, at = int(rows[index].created_at) or 0 }
	end
	return list
end

function CryptoPersistence.InsertPrice(price, now)
	return execute('INSERT INTO coe_crypto_prices (price, created_at) VALUES (?, ?)', { price, now })
end

function CryptoPersistence.PurgePrices(before)
	return execute('DELETE FROM coe_crypto_prices WHERE created_at < ?', { before })
end

-- Configurações administrativas ----------------------------------------------------------------------

function CryptoPersistence.Settings()
	local rows, errorCode = query('SELECT config_json FROM coe_crypto_settings WHERE id = 1', {})
	if not rows then
		return nil, errorCode
	end
	local row = rows[1]
	if not row then
		return false
	end
	return str(row.config_json)
end

function CryptoPersistence.SaveSettings(jsonText, now)
	return execute([[
		INSERT INTO coe_crypto_settings (id, config_json, updated_at)
		VALUES (1, ?, ?)
		ON DUPLICATE KEY UPDATE config_json = VALUES(config_json), updated_at = VALUES(updated_at)
	]], { jsonText, now })
end

function CryptoPersistence.DeleteSettings()
	return execute('DELETE FROM coe_crypto_settings WHERE id = 1', {})
end

function CryptoPersistence.NetworkSummary(reserveAddress)
	local wRows = query(
		'SELECT COUNT(*) AS wallets, COALESCE(SUM(CASE WHEN address <> ? THEN balance ELSE 0 END), 0) AS circulating FROM coe_crypto_wallets',
		{ reserveAddress or '' }
	)
	local tRows = query('SELECT COUNT(*) AS total FROM coe_crypto_tx', {})
	local wRow = wRows and wRows[1] or {}
	local tRow = tRows and tRows[1] or {}
	return {
		wallets = int(wRow.wallets) or 0,
		circulating = int(tonumber(wRow.circulating)) or 0,
		txCount = int(tRow.total) or 0
	}
end

function CryptoPersistence.TopWallets(reserveAddress, limit)
	local rows, errorCode = query(
		('SELECT address, balance, created_by, created_at FROM coe_crypto_wallets WHERE address <> ? ORDER BY balance DESC, created_at DESC LIMIT %d'):format(math.floor(limit or 20)),
		{ reserveAddress or '' }
	)
	if not rows then
		return nil, errorCode
	end
	local list = {}
	for _, row in ipairs(rows) do
		list[#list + 1] = {
			address = str(row.address),
			balance = int(row.balance) or 0,
			createdBy = row.created_by and str(row.created_by) or nil,
			createdAt = int(row.created_at) or 0
		}
	end
	return list
end

local function toAuditTx(row)
	return {
		id = int(row.id),
		kind = str(row.kind),
		from = row.from_address and str(row.from_address) or nil,
		to = row.to_address and str(row.to_address) or nil,
		amount = int(row.amount) or 0,
		fee = int(row.fee) or 0,
		fiat = int(row.fiat) or 0,
		memo = str(row.memo),
		characterId = row.character_id and str(row.character_id) or nil,
		deviceKey = row.device_key and str(row.device_key) or nil,
		at = int(row.created_at) or 0
	}
end

function CryptoPersistence.RecentTx(limit)
	local rows, errorCode = query(
		('SELECT id, kind, from_address, to_address, amount, fee, fiat, memo, character_id, device_key, created_at FROM coe_crypto_tx ORDER BY id DESC LIMIT %d'):format(math.floor(limit or 25)),
		{}
	)
	if not rows then
		return nil, errorCode
	end
	local list = {}
	for _, row in ipairs(rows) do
		list[#list + 1] = toAuditTx(row)
	end
	return list
end

function CryptoPersistence.AdminInspectAddress(address)
	local rows, errorCode = query('SELECT address, balance, created_by, created_at FROM coe_crypto_wallets WHERE address = ?', { address })
	if not rows then
		return nil, errorCode
	end
	local row = rows[1]
	if not row then
		return nil, 'unknown_address'
	end
	local devices = {}
	for _, dRow in ipairs(query('SELECT device_key, label, added_at FROM coe_crypto_keystore WHERE address = ? ORDER BY added_at DESC LIMIT 20', { address }) or {}) do
		devices[#devices + 1] = {
			deviceKey = str(dRow.device_key),
			label = str(dRow.label),
			addedAt = int(dRow.added_at) or 0
		}
	end
	local history = {}
	for _, tRow in ipairs(query('SELECT id, kind, from_address, to_address, amount, fee, fiat, memo, character_id, device_key, created_at FROM coe_crypto_tx WHERE from_address = ? OR to_address = ? ORDER BY id DESC LIMIT 30', { address, address }) or {}) do
		history[#history + 1] = toAuditTx(tRow)
	end
	return {
		address = str(row.address),
		balance = int(row.balance) or 0,
		createdBy = row.created_by and str(row.created_by) or nil,
		createdAt = int(row.created_at) or 0,
		devices = devices,
		history = history
	}
end


