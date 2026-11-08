local config = CryptoConfig
local defaultSettings = CryptoRules.SettingsView(config)

local ready = false
local locks = {}
local lockManager = CryptoRules.NewLockManager and CryptoRules.NewLockManager() or nil
local lastCall = {}
local callLimiter = CryptoRules.NewCallLimiter and CryptoRules.NewCallLimiter(config.CallCooldownMs) or nil
local lastSend = {}
local lastOrder = {}
local importFails = {}
local verified = {}

-- Cotação em memória (a última também fica no banco). netFlow: $ comprados - $ vendidos desde a última rodada.
local market = {
	price = config.Exchange.StartPrice,
	history = {},
	ring = CryptoRules.NewPriceHistoryRing and CryptoRules.NewPriceHistoryRing(config.Exchange.HistoryPoints) or nil,
	netFlow = 0,
	minted = 0
}
local lastMint = {}

local App = {}

local function log(level, category, event, context)
	pcall(function()
		return exports.coe_logging:Log(level, category, event, context)
	end)
end

local function audit(event, context)
	pcall(function()
		return exports.coe_audit:Record('info', 'audit', event, context)
	end)
end

local function notify(playerId, kind, message)
	pcall(function()
		exports.coe_notify:Notify(playerId, kind, message)
	end)
end

local function characterOf(playerId)
	local characterId = Core.Players.GetActiveCharacterId(playerId)
	return characterId and tostring(characterId) or nil
end

-- Chaves com o hash próprio do framework (coe_core/lib/hash.lua): não dependem do bcrypt do FXServer.
local function hash(secret)
	return CoeHash.Secret(secret)
end

-- Confere a chave com o hash da carteira. Acertos ficam em memória para não refazer o hash a cada envio.
-- Carteiras antigas (hash bcrypt que o servidor não confere): vale se a mesma chave está guardada num aparelho, e o
-- hash é refeito no formato novo.
local function keyMatches(wallet, key)
	local cacheKey = wallet.address .. '|' .. key
	if verified[cacheKey] then
		return true
	end
	if wallet.hash == '' then
		return false
	end
	local valid = CoeHash.Verify(key, wallet.hash)
	if not valid and not CoeHash.IsCurrent(wallet.hash) then
		valid = CryptoPersistence.KeyKnown(wallet.address, key) == true
	end
	if not valid then
		return false
	end
	if not CoeHash.IsCurrent(wallet.hash) then
		local digest = hash(key)
		if digest and CryptoPersistence.UpdateWalletHash(wallet.address, digest) then
			wallet.hash = digest
			log('info', 'persistence', 'crypto_wallet_rehashed', { target = wallet.address })
		end
	end
	verified[cacheKey] = true
	return true
end

local function withLock(keys, run)
	if lockManager then
		local guard <close>, err = lockManager:acquireMulti(keys, 3000)
		if not guard then
			return { ok = false, error = err == 'lock_timeout' and 'busy' or 'busy' }
		end
		local ok, result = pcall(run)
		if not ok then
			log('error', 'gameplay', 'crypto_action_failed', { error_code = tostring(result):sub(1, 120) })
			return { ok = false, error = 'database_error' }
		end
		return result
	end
	for _, key in ipairs(keys) do
		if locks[key] then
			return { ok = false, error = 'busy' }
		end
	end
	for _, key in ipairs(keys) do
		locks[key] = true
	end
	local ok, result = pcall(run)
	for _, key in ipairs(keys) do
		locks[key] = nil
	end
	if not ok then
		log('error', 'gameplay', 'crypto_action_failed', { error_code = tostring(result):sub(1, 120) })
		return { ok = false, error = 'database_error' }
	end
	return result
end

local function random(n)
	return math.random(n)
end

local function format(units)
	return CryptoRules.Format(config, units) .. ' ' .. config.Coin.Symbol
end

-- Inventário ------------------------------------------------------------------------------------------

local function inventoryOf(characterId)
	return 'character:' .. characterId
end

local function inventoryCall(name, ...)
	if GetResourceState('coe_inventory') ~= 'started' then
		return nil
	end
	local arguments = { ... }
	local ok, first, second = pcall(function()
		return exports.coe_inventory[name](exports.coe_inventory, table.unpack(arguments))
	end)
	if not ok then
		return nil
	end
	return first, second
end

local KEY_ITEMS = { [config.Items.Paper] = 'paper', [config.Items.Usb] = 'usb' }

-- Chaves gravadas em papel ou pen drive no inventário do personagem: { address, key, label, source, slot }.
local function itemKeys(characterId)
	local snapshot = inventoryCall('GetInventory', inventoryOf(characterId))
	local list = {}
	if type(snapshot) ~= 'table' or type(snapshot.items) ~= 'table' then
		return list
	end
	for slot, item in pairs(snapshot.items) do
		local source = type(item) == 'table' and KEY_ITEMS[item.name]
		local metadata = source and type(item.metadata) == 'table' and item.metadata
		if metadata then
			local address = CryptoRules.Address(config, metadata.address)
			local key = CryptoRules.Key(metadata.key)
			if address and key then
				list[#list + 1] = {
					address = address, key = key, label = CryptoRules.Label(config, metadata.label), source = source,
					slot = math.tointeger(tonumber(slot))
				}
			end
		end
	end
	table.sort(list, function(a, b) return (a.slot or 0) < (b.slot or 0) end)
	return list
end

-- Chaves à mão agora: as do aparelho e as do inventário. Mapa por endereço (o aparelho tem prioridade).
local function availableKeys(context)
	local list = CryptoPersistence.Keystore(context.key)
	if not list then
		return nil
	end
	local map, ordered = {}, {}
	for _, entry in ipairs(list) do
		entry.source = 'device'
		map[entry.address] = entry
		ordered[#ordered + 1] = entry
	end
	for _, entry in ipairs(itemKeys(context.character)) do
		if not map[entry.address] then
			map[entry.address] = entry
			ordered[#ordered + 1] = entry
		end
	end
	return ordered, map
end

-- Carteira com chave à mão (e válida). Devolve { address, key, wallet } ou nil + erro.
local function heldWallet(context, address)
	address = CryptoRules.Address(config, address)
	if not address then
		return nil, 'invalid_address'
	end
	local _, map = availableKeys(context)
	if not map then
		return nil, 'database_error'
	end
	local entry = map[address]
	if not entry then
		return nil, 'no_key'
	end
	local wallet = CryptoPersistence.Wallet(address)
	if wallet == nil then
		return nil, 'database_error'
	end
	if not wallet or not keyMatches(wallet, entry.key) then
		return nil, 'invalid_key'
	end
	return { address = address, key = entry.key, wallet = wallet, entry = entry }
end

-- Estado ----------------------------------------------------------------------------------------------

local function marketView()
	local history = {}
	for _, point in ipairs(market.history) do
		history[#history + 1] = point.price
	end
	local first = market.history[1]
	return {
		price = market.price,
		buy = CryptoRules.BuyPrice(config, market.price),
		sell = CryptoRules.SellPrice(config, market.price),
		change = CryptoRules.Change(first and first.price or market.price, market.price),
		history = history,
		tickMinutes = config.Exchange.TickMinutes
	}
end

function App.state(context)
	local keys = availableKeys(context)
	if not keys then
		return { ok = false, error = 'database_error' }
	end
	local addresses = {}
	for _, entry in ipairs(keys) do
		addresses[#addresses + 1] = entry.address
	end
	local balances = CryptoPersistence.Balances(addresses)
	if not balances then
		return { ok = false, error = 'database_error' }
	end
	local wallets = {}
	for _, entry in ipairs(keys) do
		wallets[#wallets + 1] = {
			address = entry.address, label = entry.label, source = entry.source,
			balance = balances[entry.address] or 0, known = balances[entry.address] ~= nil
		}
	end
	local since = os.time() - 86400
	local bought = CryptoPersistence.FiatUsed(context.character, 'buy', since) or 0
	local sold = CryptoPersistence.FiatUsed(context.character, 'sell', since) or 0
	return {
		ok = true,
		coin = { name = config.Coin.Name, symbol = config.Coin.Symbol, decimals = config.Coin.Decimals },
		device = context.device,
		wallets = wallets,
		deviceSlots = config.Wallets.MaxPerDevice,
		hasBlankUsb = (inventoryCall('GetItemCount', inventoryOf(context.character), config.Items.BlankUsb) or 0) > 0,
		fee = config.Transfer.Fee,
		exchange = config.Exchange.Enabled and {
			name = config.Exchange.Name, minOrder = config.Exchange.MinOrder, maxOrder = config.Exchange.MaxOrder,
			buyLeft = math.max(0, config.Exchange.DailyBuyLimit - bought), sellLeft = math.max(0, config.Exchange.DailySellLimit - sold)
		} or nil,
		market = marketView()
	}
end

function App.market()
	return { ok = true, market = marketView() }
end

-- Carteiras ------------------------------------------------------------------------------------------

local function deviceKeyCount(context)
	local list = CryptoPersistence.Keystore(context.key)
	return list and #list or nil
end

function App.create(context, payload)
	return withLock({ 'character:' .. context.character, 'device:' .. context.key }, function()
		local count = deviceKeyCount(context)
		if not count then
			return { ok = false, error = 'database_error' }
		end
		if count >= config.Wallets.MaxPerDevice then
			return { ok = false, error = 'device_full' }
		end
		local created = CryptoPersistence.CreatedSince(context.character, os.time() - 86400)
		if not created then
			return { ok = false, error = 'database_error' }
		end
		if created >= config.Wallets.MaxCreatedPerDay then
			return { ok = false, error = 'create_limit' }
		end
		local key = CryptoRules.NewKey(random)
		local digest = hash(key)
		if not digest then
			return { ok = false, error = 'database_error' }
		end
		local now = os.time()
		for _ = 1, 5 do
			local address = CryptoRules.NewAddress(config, random)
			local inserted, errorCode = CryptoPersistence.InsertWallet(address, digest, context.character, now)
			if inserted then
				if not CryptoPersistence.AddKey(context.key, address, key, CryptoRules.Label(config, payload.label), now) then
					return { ok = false, error = 'database_error' }
				end
				verified[address .. '|' .. key] = true
				log('info', 'gameplay', 'crypto_wallet_created', { character_id = context.character, operation = context.device })
				return { ok = true, address = address, key = key }
			elseif errorCode ~= 'address_taken' then
				return { ok = false, error = 'database_error' }
			end
		end
		return { ok = false, error = 'database_error' }
	end)
end

-- Importa uma carteira para o aparelho: endereço + chave (ex.: lidos de um papel).
function App.import(context, payload)
	local address = CryptoRules.Address(config, payload.address)
	local key = CryptoRules.Key(payload.key)
	local now = os.time()
	if CryptoRules.Locked(importFails[context.key], now) then
		return { ok = false, error = 'import_locked', seconds = importFails[context.key].lockedUntil - now }
	end
	-- Formato errado não conta como tentativa: é erro de digitação, não chute de chave.
	if not address then
		return { ok = false, error = 'invalid_address' }
	end
	if not key then
		return { ok = false, error = 'invalid_key_format' }
	end
	return withLock({ 'device:' .. context.key }, function()
		local wallet = CryptoPersistence.Wallet(address)
		if wallet == nil then
			return { ok = false, error = 'database_error' }
		end
		if not wallet then
			return { ok = false, error = 'unknown_address' }
		end
		if not keyMatches(wallet, key) then
			importFails[context.key] = CryptoRules.Fail(config, importFails[context.key], now)
			if CryptoRules.Locked(importFails[context.key], now) then
				log('warn', 'security', 'crypto_import_locked', { character_id = context.character, operation = context.device })
			end
			return { ok = false, error = 'key_mismatch' }
		end
		importFails[context.key] = nil
		local list = CryptoPersistence.Keystore(context.key)
		if not list then
			return { ok = false, error = 'database_error' }
		end
		local present = false
		for _, entry in ipairs(list) do
			present = present or entry.address == address
		end
		if not present and #list >= config.Wallets.MaxPerDevice then
			return { ok = false, error = 'device_full' }
		end
		if not CryptoPersistence.AddKey(context.key, address, key, CryptoRules.Label(config, payload.label), now) then
			return { ok = false, error = 'database_error' }
		end
		return { ok = true, address = address }
	end)
end

-- Tira a chave do aparelho (os fundos continuam na rede; sem outra cópia da chave, ficam inacessíveis).
function App.forget(context, payload)
	local address = CryptoRules.Address(config, payload.address)
	if not address then
		return { ok = false, error = 'invalid_address' }
	end
	if not CryptoPersistence.RemoveKey(context.key, address) then
		return { ok = false, error = 'database_error' }
	end
	return { ok = true }
end

function App.rename(context, payload)
	local address = CryptoRules.Address(config, payload.address)
	if not address then
		return { ok = false, error = 'invalid_address' }
	end
	if not CryptoPersistence.RenameKey(context.key, address, CryptoRules.Label(config, payload.label)) then
		return { ok = false, error = 'database_error' }
	end
	return { ok = true }
end

-- Mostra a chave de uma carteira que está à mão (para copiar num papel, no RP).
function App.reveal(context, payload)
	local held, errorCode = heldWallet(context, payload.address)
	if not held then
		return { ok = false, error = errorCode }
	end
	return { ok = true, address = held.address, key = held.key }
end

local function giveKeyItem(context, item, held, label)
	local metadata = { address = held.address, key = held.key, label = label ~= '' and label or nil }
	local added, slotOrError = inventoryCall('AddItem', inventoryOf(context.character), item, 1, metadata)
	if not added then
		return nil, slotOrError == 'inventory_full' and 'inventory_full' or 'inventory_error'
	end
	return true
end

-- Anota a chave num papel (item crypto_paper).
function App.exportPaper(context, payload)
	local held, errorCode = heldWallet(context, payload.address)
	if not held then
		return { ok = false, error = errorCode }
	end
	local done
	done, errorCode = giveKeyItem(context, config.Items.Paper, held, held.entry.label or '')
	if not done then
		return { ok = false, error = errorCode }
	end
	audit('crypto_key_exported', { character_id = context.character, item = config.Items.Paper })
	return { ok = true }
end

-- Grava a chave num pen drive vazio (usb_black vira crypto_usb).
function App.exportUsb(context, payload)
	local held, errorCode = heldWallet(context, payload.address)
	if not held then
		return { ok = false, error = errorCode }
	end
	return withLock({ 'character:' .. context.character }, function()
		local inventory = inventoryOf(context.character)
		local sagaCtx = { errorCode = nil }
		local ok = CryptoRules.ExecuteSaga({
			{
				name = 'remove_blank_usb',
				action = function()
					local removed = inventoryCall('RemoveItemByName', inventory, config.Items.BlankUsb, 1)
					if not removed then
						sagaCtx.errorCode = 'no_blank_usb'
						return false
					end
					return true
				end,
				compensate = function()
					inventoryCall('AddItem', inventory, config.Items.BlankUsb, 1)
				end
			},
			{
				name = 'give_crypto_usb',
				action = function()
					local done, giveError = giveKeyItem(context, config.Items.Usb, held, held.entry.label or '')
					if not done then
						sagaCtx.errorCode = giveError
						return false
					end
					return true
				end
			}
		}, sagaCtx)
		if not ok then
			return { ok = false, error = sagaCtx.errorCode or 'inventory_error' }
		end
		audit('crypto_key_exported', { character_id = context.character, item = config.Items.Usb })
		return { ok = true }
	end)
end

-- Rede ------------------------------------------------------------------------------------------------

-- Explorador público: saldo e movimentações de qualquer endereço.
function App.explore(context, payload)
	local address = CryptoRules.Address(config, payload.address)
	if not address then
		return { ok = false, error = 'invalid_address' }
	end
	local wallet = CryptoPersistence.Wallet(address)
	if wallet == nil then
		return { ok = false, error = 'database_error' }
	end
	if not wallet then
		return { ok = false, error = 'unknown_address' }
	end
	local before = math.tointeger(tonumber(payload.before))
	local list, more = CryptoPersistence.History(address, before, config.HistoryPageSize)
	if not list then
		return { ok = false, error = 'database_error' }
	end
	return { ok = true, address = address, balance = wallet.balance, history = list, more = more == true }
end

function App.send(context, payload)
	local held, errorCode = heldWallet(context, payload.from)
	if not held then
		return { ok = false, error = errorCode }
	end
	local to = CryptoRules.Address(config, payload.to)
	if not to then
		return { ok = false, error = 'invalid_recipient' }
	end
	if to == held.address then
		return { ok = false, error = 'same_address' }
	end
	local units
	units, errorCode = CryptoRules.ParseAmount(config, payload.amount)
	if not units then
		return { ok = false, error = errorCode }
	end
	local memo = CryptoRules.Memo(config, payload.memo)
	return withLock({ 'address:' .. held.address }, function()
		local now = os.time()
		if lastSend[held.address] and now - lastSend[held.address] < config.Transfer.CooldownSeconds then
			return { ok = false, error = 'send_cooldown' }
		end
		local wallet = CryptoPersistence.Wallet(held.address)
		local target = CryptoPersistence.Wallet(to)
		if wallet == nil or target == nil then
			return { ok = false, error = 'database_error' }
		end
		if not target then
			return { ok = false, error = 'unknown_recipient' }
		end
		local allowed, denied = CryptoRules.CanSend(config, wallet.balance, units)
		if not allowed then
			return { ok = false, error = denied }
		end
		local moved = CryptoPersistence.Move({
			kind = 'transfer', from = held.address, to = to, amount = units, fee = config.Transfer.Fee, memo = memo,
			characterId = context.character, deviceKey = context.key
		}, now)
		if not moved then
			local current = CryptoPersistence.Wallet(held.address)
			return { ok = false, error = (current and current.balance < units + config.Transfer.Fee) and 'insufficient_funds' or 'database_error' }
		end
		lastSend[held.address] = now
		log('info', 'gameplay', 'crypto_sent', { character_id = context.character, count = units })
		return { ok = true, txId = moved }
	end)
end

-- Corretora -------------------------------------------------------------------------------------------

local function economy(name, ...)
	if GetResourceState('coe_economy') ~= 'started' then
		return nil
	end
	local arguments = { ... }
	local ok, result = pcall(function()
		return exports.coe_economy[name](exports.coe_economy, table.unpack(arguments))
	end)
	return ok and result or nil
end

local function orderGuard(context)
	if not config.Exchange.Enabled then
		return 'exchange_closed'
	end
	local now = os.time()
	if lastOrder[context.character] and now - lastOrder[context.character] < config.Exchange.OrderCooldownSeconds then
		return 'order_cooldown'
	end
	return nil
end

function App.buy(context, payload)
	local blocked = orderGuard(context)
	if blocked then
		return { ok = false, error = blocked }
	end
	local address = CryptoRules.Address(config, payload.address)
	if not address or address == config.Exchange.ReserveAddress then
		return { ok = false, error = 'invalid_address' }
	end
	local quote, errorCode = CryptoRules.BuyQuote(config, market.price, CryptoRules.Dollars(payload.dollars))
	if not quote then
		return { ok = false, error = errorCode }
	end
	return withLock({ 'character:' .. context.character }, function()
		local now = os.time()
		local target = CryptoPersistence.Wallet(address)
		local used = CryptoPersistence.FiatUsed(context.character, 'buy', now - 86400)
		if target == nil or not used then
			return { ok = false, error = 'database_error' }
		end
		if not target then
			return { ok = false, error = 'unknown_address' }
		end
		if not CryptoRules.WithinDailyLimit(config, 'buy', used, quote.cost) then
			return { ok = false, error = 'daily_limit' }
		end
		local reserve = CryptoPersistence.Wallet(config.Exchange.ReserveAddress)
		if not reserve or reserve.balance < quote.units then
			return { ok = false, error = 'no_liquidity' }
		end
		local balance = economy('GetBalance', context.character)
		if type(balance) ~= 'number' then
			return { ok = false, error = 'bank_unavailable' }
		end
		if balance < quote.cost then
			return { ok = false, error = 'insufficient_funds' }
		end
		local sagaCtx = { errorCode = nil }
		local ok = CryptoRules.ExecuteSaga({
			{
				name = 'debit_fiat',
				action = function()
					if economy('Debit', context.character, quote.cost, 'crypto_buy', 'nox:' .. address) ~= true then
						sagaCtx.errorCode = 'payment_failed'
						return false
					end
					return true
				end,
				compensate = function()
					economy('Credit', context.character, quote.cost, 'crypto_refund', 'nox:' .. address)
				end
			},
			{
				name = 'move_crypto',
				action = function()
					local moved = CryptoPersistence.Move({
						kind = 'buy', from = config.Exchange.ReserveAddress, to = address, amount = quote.units, fiat = quote.cost,
						memo = config.Exchange.Name, characterId = context.character, deviceKey = context.key
					}, now)
					if not moved then
						sagaCtx.errorCode = 'no_liquidity'
						return false
					end
					return true
				end
			}
		}, sagaCtx)
		if not ok then
			return { ok = false, error = sagaCtx.errorCode or 'no_liquidity' }
		end
		lastOrder[context.character] = now
		market.netFlow = market.netFlow + quote.cost
		audit('crypto_bought', { character_id = context.character, count = quote.cost, target = address })
		return { ok = true, units = quote.units, cost = quote.cost }
	end)
end

function App.sell(context, payload)
	local blocked = orderGuard(context)
	if blocked then
		return { ok = false, error = blocked }
	end
	local held, errorCode = heldWallet(context, payload.address)
	if not held then
		return { ok = false, error = errorCode }
	end
	local units
	units, errorCode = CryptoRules.ParseAmount(config, payload.amount)
	if not units then
		return { ok = false, error = errorCode }
	end
	local quote
	quote, errorCode = CryptoRules.SellQuote(config, market.price, units)
	if not quote then
		return { ok = false, error = errorCode }
	end
	return withLock({ 'character:' .. context.character, 'address:' .. held.address }, function()
		local now = os.time()
		local used = CryptoPersistence.FiatUsed(context.character, 'sell', now - 86400)
		local wallet = CryptoPersistence.Wallet(held.address)
		if not used or not wallet then
			return { ok = false, error = 'database_error' }
		end
		if not CryptoRules.WithinDailyLimit(config, 'sell', used, quote.payout) then
			return { ok = false, error = 'daily_limit' }
		end
		if wallet.balance < units then
			return { ok = false, error = 'insufficient_funds' }
		end
		if GetResourceState('coe_economy') ~= 'started' then
			return { ok = false, error = 'bank_unavailable' }
		end
		local sagaCtx = { errorCode = nil }
		local ok = CryptoRules.ExecuteSaga({
			{
				name = 'move_crypto',
				action = function()
					local moved = CryptoPersistence.Move({
						kind = 'sell', from = held.address, to = config.Exchange.ReserveAddress, amount = units, fiat = quote.payout,
						memo = config.Exchange.Name, characterId = context.character, deviceKey = context.key
					}, now)
					if not moved then
						sagaCtx.errorCode = 'insufficient_funds'
						return false
					end
					return true
				end,
				compensate = function()
					CryptoPersistence.Move({
						kind = 'refund', from = config.Exchange.ReserveAddress, to = held.address, amount = units,
						memo = config.Exchange.Name, characterId = context.character, deviceKey = context.key
					}, now)
				end
			},
			{
				name = 'credit_fiat',
				action = function()
					if economy('Credit', context.character, quote.payout, 'crypto_sell', 'nox:' .. held.address) ~= true then
						sagaCtx.errorCode = 'payment_failed'
						return false
					end
					return true
				end
			}
		}, sagaCtx)
		if not ok then
			return { ok = false, error = sagaCtx.errorCode or 'payment_failed' }
		end
		lastOrder[context.character] = now
		market.netFlow = market.netFlow - quote.payout
		audit('crypto_sold', { character_id = context.character, count = quote.payout, target = held.address })
		return { ok = true, units = units, payout = quote.payout }
	end)
end

-- Despacho --------------------------------------------------------------------------------------------

local function dispatch(playerId, character, device, key, action, payload)
	local handler = type(action) == 'string' and rawget(App, action)
	if type(handler) ~= 'function' then
		return { ok = false, error = 'unknown_action' }
	end
	local now = GetGameTimer()
	if action ~= 'state' and action ~= 'market' then
		if callLimiter then
			if not callLimiter:allow(playerId, now) then
				return { ok = false, error = 'rate_limited' }
			end
		elseif lastCall[playerId] and now - lastCall[playerId] < config.CallCooldownMs then
			return { ok = false, error = 'rate_limited' }
		end
		lastCall[playerId] = now
	end
	return handler({ playerId = playerId, character = character, device = device, key = key }, type(payload) == 'table' and payload or {})
end

-- Chave do aparelho: smartphone pelo número de série (quem pega o aparelho pega as carteiras); tablet pelo personagem.
local function deviceKey(playerId, device, character)
	if device == 'tablet' then
		return 'tablet:' .. character
	end
	local ok, info = pcall(function()
		return exports.coe_phone:ActiveDevice(playerId)
	end)
	if not ok or type(info) ~= 'table' or type(info.serial) ~= 'string' then
		return nil
	end
	return 'phone:' .. info.serial
end

local function installed(playerId, device)
	if GetResourceState('coe_apps') ~= 'started' then
		return false
	end
	local ok, result = pcall(function()
		return exports.coe_apps:HasApp(playerId, 'crypto', device)
	end)
	return ok and result == true
end

exports('TabletVisible', function(playerId, appId)
	local device = config.Hosts[GetInvokingResource() or '']
	return device ~= nil and ready and appId == 'crypto' and installed(playerId, device)
end)

exports('TabletCall', function(playerId, appId, action, payload)
	local device = config.Hosts[GetInvokingResource() or '']
	if not device then
		return { ok = false, error = 'forbidden' }
	end
	if not ready then
		return { ok = false, error = 'not_ready' }
	end
	local character = characterOf(playerId)
	if not character then
		return { ok = false, error = 'no_character' }
	end
	if appId ~= 'crypto' then
		return { ok = false, error = 'unknown_action' }
	end
	if not installed(playerId, device) then
		return { ok = false, error = 'not_installed' }
	end
	local key = deviceKey(playerId, device, character)
	if not key then
		return { ok = false, error = 'no_device' }
	end
	return dispatch(playerId, character, device, key, action, payload)
end)

-- Computadores do coe_deepweb (notebook, desktop, servidor): o host já validou o aparelho e passa a chave dele.
exports('ComputerCall', function(playerId, key, action, payload)
	if not config.ComputerHosts[GetInvokingResource() or ''] then
		return { ok = false, error = 'forbidden' }
	end
	if not ready then
		return { ok = false, error = 'not_ready' }
	end
	local character = characterOf(playerId)
	if not character then
		return { ok = false, error = 'no_character' }
	end
	if type(key) ~= 'string' or #key > 64 or not key:match('^[a-z]+:[%w%-_]+$') then
		return { ok = false, error = 'no_device' }
	end
	return dispatch(playerId, character, 'computer', key, action, payload)
end)

-- Custódia do mercado (coe_deepweb) ------------------------------------------------------------------

local function escrowCaller()
	return config.Escrow and config.Escrow.Callers[GetInvokingResource() or ''] == true
end

local function validKey(key)
	return type(key) == 'string' and #key <= 64 and key:match('^[a-z]+:[%w%-_]+$') ~= nil
end

-- Carteiras com chave à mão no aparelho (e no inventário) com saldo, para escolher de onde pagar.
exports('HeldWallets', function(playerId, key)
	if not escrowCaller() then
		return nil
	end
	local character = characterOf(playerId)
	if not ready or not character or not validKey(key) then
		return nil
	end
	local list = availableKeys({ character = character, key = key })
	if not list then
		return nil
	end
	local addresses = {}
	for _, entry in ipairs(list) do
		addresses[#addresses + 1] = entry.address
	end
	local balances = CryptoPersistence.Balances(addresses) or {}
	local wallets = {}
	for _, entry in ipairs(list) do
		wallets[#wallets + 1] = { address = entry.address, label = entry.label, source = entry.source, balance = balances[entry.address] or 0 }
	end
	return wallets
end)

-- Trava `amount` + taxa da rede da carteira `from` (com chave à mão no aparelho `key`) na custódia.
-- Devolve { ok, txId } ou { ok = false, error }.
exports('EscrowLock', function(playerId, key, from, amount, memo)
	if not escrowCaller() then
		return { ok = false, error = 'forbidden' }
	end
	local character = characterOf(playerId)
	if not ready then
		return { ok = false, error = 'not_ready' }
	end
	if not character then
		return { ok = false, error = 'no_character' }
	end
	if not validKey(key) then
		return { ok = false, error = 'no_device' }
	end
	local units = math.tointeger(amount)
	if not units or units < config.Transfer.MinAmount or units > config.Transfer.MaxAmount then
		return { ok = false, error = 'invalid_amount' }
	end
	local context = { playerId = playerId, character = character, key = key }
	local held, errorCode = heldWallet(context, from)
	if not held then
		return { ok = false, error = errorCode }
	end
	return withLock({ 'address:' .. held.address }, function()
		local wallet = CryptoPersistence.Wallet(held.address)
		if not wallet then
			return { ok = false, error = 'database_error' }
		end
		local allowed, denied = CryptoRules.CanSend(config, wallet.balance, units)
		if not allowed then
			return { ok = false, error = denied }
		end
		local moved = CryptoPersistence.Move({
			kind = 'escrow_lock', from = held.address, to = config.Escrow.Address, amount = units, fee = config.Transfer.Fee,
			memo = CryptoRules.Memo(config, memo), characterId = character, deviceKey = key
		}, os.time())
		if not moved then
			local current = CryptoPersistence.Wallet(held.address)
			return { ok = false, error = (current and current.balance < units + config.Transfer.Fee) and 'insufficient_funds' or 'database_error' }
		end
		log('info', 'gameplay', 'crypto_escrow_locked', { character_id = character, count = units })
		return { ok = true, txId = moved }
	end)
end)

-- Libera `amount` da custódia para `to` (vendedor, comprador no estorno, ou a reserva na taxa). Sem taxa da rede.
exports('EscrowRelease', function(to, amount, memo)
	if not escrowCaller() then
		return { ok = false, error = 'forbidden' }
	end
	if not ready then
		return { ok = false, error = 'not_ready' }
	end
	local address = CryptoRules.Address(config, to)
	local units = math.tointeger(amount)
	if not address then
		return { ok = false, error = 'invalid_address' }
	end
	if not units or units <= 0 then
		return { ok = false, error = 'invalid_amount' }
	end
	return withLock({ 'address:' .. config.Escrow.Address }, function()
		local moved = CryptoPersistence.Move({
			kind = 'escrow_out', from = config.Escrow.Address, to = address, amount = units, fee = 0, memo = CryptoRules.Memo(config, memo)
		}, os.time())
		if not moved then
			return { ok = false, error = 'database_error' }
		end
		return { ok = true, txId = moved }
	end)
end)

-- Endereço da reserva da corretora (destino das taxas e dos pagamentos a fornecedores NPC).
exports('ReserveAddress', function()
	return config.Exchange.ReserveAddress
end)

-- Leitura livre ---------------------------------------------------------------------------------------

exports('IsReady', function()
	return ready
end)

-- Cotação atual em $ por moeda inteira.
exports('Price', function()
	return market.price
end)

-- Saldo (unidades) de um endereço, ou nil se não existe.
exports('Balance', function(address)
	address = ready and CryptoRules.Address(config, address)
	if not address then
		return nil
	end
	local wallet = CryptoPersistence.Wallet(address)
	return wallet and wallet.balance or nil
end)

exports('IsAddress', function(address)
	return CryptoRules.Address(config, address) ~= nil
end)

exports('Format', function(units)
	return format(units)
end)

-- Mineração -------------------------------------------------------------------------------------------

-- entries: { { address, hash } }. Só `Mining.Callers`, no máximo uma rodada por intervalo. Devolve
-- { ok, total, payouts = { [address] = unidades } } ou { ok = false, error }.
exports('MintMining', function(entries)
	local caller = GetInvokingResource() or ''
	if not config.Mining.Callers[caller] then
		return { ok = false, error = 'forbidden' }
	end
	if not ready then
		return { ok = false, error = 'not_ready' }
	end
	local now = os.time()
	local interval = config.Mining.TickMinutes * 60
	if lastMint[caller] and now - lastMint[caller] < interval - 5 then
		return { ok = false, error = 'too_soon' }
	end
	if type(entries) ~= 'table' then
		return { ok = false, error = 'invalid_entries' }
	end
	local clean = {}
	for _, entry in ipairs(entries) do
		local address = type(entry) == 'table' and CryptoRules.Address(config, entry.address)
		local power = type(entry) == 'table' and math.tointeger(tonumber(entry.hash))
		if address and address ~= config.Exchange.ReserveAddress and power and power > 0 and power <= 100000 then
			clean[#clean + 1] = { address = address, hash = power }
		end
	end
	lastMint[caller] = now
	local minted = CryptoPersistence.Minted()
	if not minted then
		return { ok = false, error = 'database_error' }
	end
	local payouts, total = CryptoRules.MiningPayouts(config, clean, minted)
	payouts = CryptoRules.MergePayouts(payouts)
	local result = {}
	-- Transações de até 30 pagamentos (o provider aceita 64 instruções por transação).
	for first = 1, #payouts, 30 do
		local batch, batchTotal = {}, 0
		for index = first, math.min(#payouts, first + 29) do
			batch[#batch + 1] = payouts[index]
			batchTotal = batchTotal + payouts[index].units
		end
		if CryptoPersistence.Mint(batch, batchTotal, now) then
			for _, payout in ipairs(batch) do
				result[payout.address] = payout.units
			end
		else
			total = total - batchTotal
			log('error', 'persistence', 'crypto_mint_failed', { count = #batch })
		end
	end
	market.minted = minted + total
	log('info', 'gameplay', 'crypto_mined', { count = total, target = tostring(#payouts) })
	return { ok = true, total = total, payouts = result }
end)

-- Cotação ---------------------------------------------------------------------------------------------

local function loadSettings()
	if type(CryptoPersistence.Settings) ~= 'function' then
		return
	end
	local stored = CryptoPersistence.Settings()
	if type(stored) ~= 'string' or stored == '' then
		return
	end
	local ok, decoded = pcall(function()
		return json.decode(stored)
	end)
	if not ok or type(decoded) ~= 'table' then
		return
	end
	local clean = CryptoRules.ValidateSettings(decoded)
	if clean then
		CryptoRules.ApplySettings(config, clean)
	end
end

local function appendHistoryPoint(point)
	if market.ring then
		if market.ring.capacity ~= config.Exchange.HistoryPoints and CryptoRules.NewPriceHistoryRing then
			local nextRing = CryptoRules.NewPriceHistoryRing(config.Exchange.HistoryPoints)
			local arr = market.ring:toArray()
			for i = 1, #arr do
				nextRing:push(arr[i])
			end
			market.ring = nextRing
		end
		market.ring:push(point)
		market.history = market.ring:toArray(market.history)
		return
	end
	market.history[#market.history + 1] = point
	while #market.history > config.Exchange.HistoryPoints do
		table.remove(market.history, 1)
	end
end

local function clampMarketPrice(now)
	local clamped = math.max(config.Exchange.MinPrice, math.min(config.Exchange.MaxPrice, market.price))
	if clamped ~= market.price then
		market.price = clamped
		appendHistoryPoint({ price = clamped, at = now })
		CryptoPersistence.InsertPrice(clamped, now)
	elseif market.ring then
		appendHistoryPoint(market.ring:peekNewest(0) or { price = market.price, at = now })
	else
		while #market.history > config.Exchange.HistoryPoints do
			table.remove(market.history, 1)
		end
	end
end

local function loadMarket()
	local points = CryptoPersistence.Prices(config.Exchange.HistoryPoints)
	if market.ring then
		market.ring:clear()
	end
	if points and #points > 0 then
		if market.ring then
			for i = 1, #points do
				market.ring:push(points[i])
			end
			market.history = market.ring:toArray(market.history)
		else
			market.history = points
		end
		market.price = math.max(config.Exchange.MinPrice, math.min(config.Exchange.MaxPrice, points[#points].price))
	else
		market.price = config.Exchange.StartPrice
		local initial = { price = market.price, at = os.time() }
		if market.ring then
			market.ring:push(initial)
			market.history = market.ring:toArray(market.history)
		else
			market.history = { initial }
		end
		CryptoPersistence.InsertPrice(market.price, os.time())
	end
	market.minted = CryptoPersistence.Minted() or 0
end

local function tickMarket()
	local noise = CryptoRules.Gaussian(math.random)
	local nextPrice = CryptoRules.NextPrice(config, market.price, market.netFlow, noise)
	market.netFlow = 0
	market.price = nextPrice
	local now = os.time()
	appendHistoryPoint({ price = nextPrice, at = now })
	CryptoPersistence.InsertPrice(nextPrice, now)
	CryptoPersistence.PurgePrices(now - config.Exchange.TickMinutes * 60 * config.Exchange.HistoryPoints * 2)
end

-- Admin (só coe_admin) --------------------------------------------------------------------------------

local function adminOnly()
	return GetInvokingResource() == 'coe_admin'
end

exports('AdminOverview', function()
	if not adminOnly() then
		return { error = 'forbidden' }
	end
	local reserve = ready and CryptoPersistence.Wallet(config.Exchange.ReserveAddress) or nil
	local first = market.history[1]
	local currentPrice = market.price > 0 and market.price or config.Exchange.StartPrice
	local summary = ready and type(CryptoPersistence.NetworkSummary) == 'function'
		and CryptoPersistence.NetworkSummary(config.Exchange.ReserveAddress)
		or { wallets = 0, circulating = 0, txCount = 0 }
	local topWallets = ready and type(CryptoPersistence.TopWallets) == 'function'
		and CryptoPersistence.TopWallets(config.Exchange.ReserveAddress, 20)
		or {}
	local recentTx = ready and type(CryptoPersistence.RecentTx) == 'function'
		and CryptoPersistence.RecentTx(25)
		or {}
	return {
		available = true,
		ready = ready,
		settings = CryptoRules.SettingsView(config),
		defaults = defaultSettings,
		market = {
			price = currentPrice,
			buy = CryptoRules.BuyPrice(config, currentPrice),
			sell = CryptoRules.SellPrice(config, currentPrice),
			change = CryptoRules.Change(first and first.price or currentPrice, currentPrice),
			netFlow = market.netFlow,
			minted = market.minted,
			reserveBalance = type(reserve) == 'table' and reserve.balance or config.Exchange.Reserve
		},
		summary = summary or { wallets = 0, circulating = 0, txCount = 0 },
		topWallets = topWallets or {},
		recentTx = recentTx or {}
	}
end)

exports('AdminInspect', function(rawAddress)
	if not adminOnly() then
		return { error = 'forbidden' }
	end
	if not ready then
		return { error = 'not_ready' }
	end
	local address = CryptoRules.Address(config, rawAddress)
	if not address then
		return { error = 'invalid_address' }
	end
	if type(CryptoPersistence.AdminInspectAddress) ~= 'function' then
		return { error = 'database_error' }
	end
	local result = CryptoPersistence.AdminInspectAddress(address)
	if not result then
		return { error = 'database_error' }
	end
	if not result.wallet then
		return { error = 'unknown_address' }
	end
	return result
end)

exports('AdminSaveSettings', function(raw)
	if not adminOnly() then
		return { error = 'forbidden' }
	end
	if not ready then
		return { error = 'not_ready' }
	end
	local clean, errorCode = CryptoRules.ValidateSettings(raw)
	if not clean then
		return { error = errorCode }
	end
	local now = os.time()
	local encoded = json.encode(clean)
	if not CryptoPersistence.SaveSettings(encoded, now) then
		return { error = 'database_error' }
	end
	CryptoRules.ApplySettings(config, clean)
	clampMarketPrice(now)
	audit('crypto_settings_saved', { operation = clean.coin.symbol, count = clean.exchange.anchorPrice })
	return true
end)

exports('AdminResetSettings', function()
	if not adminOnly() then
		return { error = 'forbidden' }
	end
	if not ready then
		return { error = 'not_ready' }
	end
	if not CryptoPersistence.DeleteSettings() then
		return { error = 'database_error' }
	end
	CryptoRules.ApplySettings(config, defaultSettings)
	clampMarketPrice(os.time())
	audit('crypto_settings_reset', { operation = config.Coin.Symbol })
	return true
end)

exports('AdminSetPrice', function(value)
	if not adminOnly() then
		return { error = 'forbidden' }
	end
	if not ready then
		return { error = 'not_ready' }
	end
	local price = CryptoRules.Dollars(value)
	if not price or price < config.Exchange.MinPrice or price > config.Exchange.MaxPrice then
		return { error = 'invalid_price' }
	end
	local now = os.time()
	if not CryptoPersistence.InsertPrice(price, now) then
		return { error = 'database_error' }
	end
	market.price = price
	market.netFlow = 0
	appendHistoryPoint({ price = price, at = now })
	audit('crypto_price_set', { count = price })
	return true
end)

AddEventHandler('playerDropped', function()
	lastCall[source] = nil
	if callLimiter then
		callLimiter:reset(source)
	end
end)

CreateThread(function()
	math.randomseed(os.time() + GetGameTimer())
	local waitingLogged = false
	while true do
		local initialized, errorCode = CryptoPersistence.Initialize(config, os.time())
		if initialized then
			break
		end
		if errorCode == 'database_not_ready' or errorCode == 'database_unavailable' then
			if not waitingLogged then
				log('info', 'persistence', 'database_waiting', {})
				waitingLogged = true
			end
			Wait(1000)
		else
			log('error', 'persistence', 'migrations_failed', { error_code = tostring(errorCode) })
			return
		end
	end
	loadSettings()
	loadMarket()
	ready = true
	log('info', 'system', 'crypto_ready', {})
	while true do
		Wait(math.max(1, config.Exchange.TickMinutes) * 60000)
		local ok, failure = pcall(tickMarket)
		if not ok then
			log('error', 'gameplay', 'crypto_tick_failed', { error_code = tostring(failure):sub(1, 120) })
		end
	end
end)

