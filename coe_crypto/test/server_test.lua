-- Fluxos do servidor (server/main.lua) com natives, exports e persistência falsos em memória:
-- carteiras no aparelho e no inventário, envio, corretora (com estorno), mineração e restrição de chamadores.
dofile('config.lua')
dofile('shared/rules.lua')
local function loadFramework(path)
	local candidates = {
		'../' .. path,
		'../tools/compat/' .. path,
		'../[coe-framework]/' .. path,
		'../../coe-framework/' .. path
	}
	for _, c in ipairs(candidates) do
		local f = io.open(c, 'r')
		if f then f:close() return dofile(c) end
	end
	error('Cannot find framework file: ' .. path)
end

loadFramework('coe_core/lib/hash.lua')
loadFramework('coe_core/lib/algorithms/init.lua')

local config = CryptoConfig
local failures = 0

local function eq(actual, expected, message)
	if actual ~= expected then
		failures = failures + 1
		print(('FAIL %s: esperado %s, obtido %s'):format(message, tostring(expected), tostring(actual)))
	end
end

-- Ambiente FiveM falso ---------------------------------------------------------------------------------

local invoking = 'coe_phone'
local now = 1000000
local registered = {}
local threads = {}

function GetInvokingResource() return invoking end
local timer = 0
function GetGameTimer() timer = timer + 1000; return timer end
function GetResourceState() return 'started' end
-- O bcrypt do FXServer não confere (o defeito visto em jogo): o resource precisa funcionar sem ele.
function VerifyPasswordHash() return false end
function AddEventHandler() end
function Wait() coroutine.yield() end
function CreateThread(fn) local co = coroutine.create(fn); threads[#threads + 1] = co; assert(coroutine.resume(co)) end
os.time = function() return now end
function exports(name, fn) registered[name] = fn end

Core = {
	Algorithms = CoeAlgorithms,
	Players = { GetActiveCharacterId = function(playerId) return playerId == 1 and 11 or (playerId == 2 and 22 or nil) end }
}

-- Economia, inventário, aparelho e loja.
local bank = { ['11'] = 100000, ['22'] = 0 }
local creditFails = false
local inventory = { ['character:11'] = { items = {} }, ['character:22'] = { items = {} } }

local function resource(methods)
	return setmetatable({}, { __index = function(_, name)
		return function(_, ...) return methods[name](...) end
	end })
end

local economy = resource({
	GetBalance = function(id) return bank[tostring(id)] end,
	Debit = function(id, amount) id = tostring(id); if bank[id] < amount then return nil end; bank[id] = bank[id] - amount; return true end,
	Credit = function(id, amount) if creditFails then return nil end; id = tostring(id); bank[id] = bank[id] + amount; return true end
})
local inv = resource({
	GetInventory = function(id) return inventory[id] end,
	GetItemCount = function(id, name)
		local count = 0
		for _, item in pairs(inventory[id].items) do if item.name == name then count = count + 1 end end
		return count
	end,
	AddItem = function(id, name, count, metadata)
		local items = inventory[id].items
		local slot = #items + 1
		items[slot] = { name = name, count = count, metadata = metadata }
		return true, slot
	end,
	RemoveItemByName = function(id, name)
		for slot, item in pairs(inventory[id].items) do
			if item.name == name then inventory[id].items[slot] = nil; return true end
		end
		return false
	end
})
local phone = resource({ ActiveDevice = function(playerId) return { serial = 'SER' .. playerId } end })
local apps = resource({ HasApp = function() return true end })
local others = resource(setmetatable({}, { __index = function() return function() return true end end }))
exports = setmetatable({}, {
	__call = function(_, name, fn) registered[name] = fn end,
	__index = function(_, name)
		if name == 'coe_economy' then return economy end
		if name == 'coe_inventory' then return inv end
		if name == 'coe_phone' then return phone end
		if name == 'coe_apps' then return apps end
		return others
	end
})

-- Persistência em memória (mesmo contrato de server/persistence.lua).
local db = { wallets = {}, keystore = {}, tx = {}, prices = {}, minted = 0 }
CryptoPersistence = {}
function CryptoPersistence.Initialize(cfg)
	db.wallets[cfg.Exchange.ReserveAddress] = { address = cfg.Exchange.ReserveAddress, hash = '', balance = cfg.Exchange.Reserve }
	db.wallets[cfg.Escrow.Address] = { address = cfg.Escrow.Address, hash = '', balance = 0 }
	return true
end
function CryptoPersistence.Wallet(address)
	local wallet = db.wallets[address]
	return wallet and { address = wallet.address, hash = wallet.hash, balance = wallet.balance } or false
end
function CryptoPersistence.Balances(list)
	local map = {}
	for _, address in ipairs(list) do if db.wallets[address] then map[address] = db.wallets[address].balance end end
	return map
end
function CryptoPersistence.InsertWallet(address, hash, characterId, at)
	if db.wallets[address] then return nil, 'address_taken' end
	db.wallets[address] = { address = address, hash = hash, balance = 0, createdBy = characterId, createdAt = at }
	return true
end
function CryptoPersistence.UpdateWalletHash(address, keyHash) db.wallets[address].hash = keyHash; return true end
function CryptoPersistence.KeyKnown(address, key)
	for _, entry in ipairs(db.keystore) do if entry.address == address and entry.key == key then return true end end
	return false
end
function CryptoPersistence.CreatedSince(characterId, since)
	local count = 0
	for _, wallet in pairs(db.wallets) do if wallet.createdBy == characterId and wallet.createdAt >= since then count = count + 1 end end
	return count
end
function CryptoPersistence.Keystore(key)
	local list = {}
	for _, entry in ipairs(db.keystore) do if entry.device == key then list[#list + 1] = { address = entry.address, key = entry.key, label = entry.label } end end
	return list
end
function CryptoPersistence.AddKey(key, address, secret, label)
	for _, entry in ipairs(db.keystore) do if entry.device == key and entry.address == address then entry.label = label; return true end end
	db.keystore[#db.keystore + 1] = { device = key, address = address, key = secret, label = label }
	return true
end
function CryptoPersistence.RemoveKey(key, address)
	for index, entry in ipairs(db.keystore) do if entry.device == key and entry.address == address then table.remove(db.keystore, index); return true end end
	return true
end
function CryptoPersistence.RenameKey() return true end
function CryptoPersistence.Move(entry, at)
	local from = db.wallets[entry.from]
	local total = entry.amount + (entry.fee or 0)
	if not from or from.balance < total then return nil, 'transaction_failed' end
	from.balance = from.balance - total
	db.wallets[entry.to] = db.wallets[entry.to] or { address = entry.to, hash = '', balance = 0 }
	db.wallets[entry.to].balance = db.wallets[entry.to].balance + entry.amount
	entry.at = at
	db.tx[#db.tx + 1] = entry
	return #db.tx
end
function CryptoPersistence.Mint(payouts, total)
	for _, payout in ipairs(payouts) do
		db.wallets[payout.address] = db.wallets[payout.address] or { address = payout.address, hash = '', balance = 0 }
		db.wallets[payout.address].balance = db.wallets[payout.address].balance + payout.units
	end
	db.minted = db.minted + total
	return true
end
function CryptoPersistence.Minted() return db.minted end
function CryptoPersistence.History() return {}, false end
function CryptoPersistence.FiatUsed(characterId, kind, since)
	local total = 0
	for _, tx in ipairs(db.tx) do if tx.characterId == characterId and tx.kind == kind and tx.at >= since then total = total + (tx.fiat or 0) end end
	return total
end
function CryptoPersistence.Prices() return db.prices end
function CryptoPersistence.InsertPrice(price, at) db.prices[#db.prices + 1] = { price = price, at = at }; return true end
function CryptoPersistence.PurgePrices() return true end
function CryptoPersistence.Settings() return db.settings or false end
function CryptoPersistence.SaveSettings(text) db.settings = text; return true end
function CryptoPersistence.DeleteSettings() db.settings = nil; return true end
function CryptoPersistence.NetworkSummary(reserveAddress)
	local wallets, circulating = 0, 0
	for address, w in pairs(db.wallets) do
		if address ~= reserveAddress then
			wallets = wallets + 1
			circulating = circulating + (w.balance or 0)
		end
	end
	return { wallets = wallets, circulating = circulating, txCount = #db.tx }
end
function CryptoPersistence.TopWallets(reserveAddress)
	local list = {}
	for address, w in pairs(db.wallets) do
		if address ~= reserveAddress then
			list[#list + 1] = { address = address, balance = w.balance, createdBy = w.createdBy, createdAt = w.createdAt or 0 }
		end
	end
	return list
end
function CryptoPersistence.RecentTx() return db.tx end
function CryptoPersistence.AdminInspectAddress(address)
	local w = db.wallets[address]
	return {
		wallet = w and { address = w.address, balance = w.balance, createdBy = w.createdBy, createdAt = w.createdAt or 0 } or false,
		devices = {},
		history = {}
	}
end

json = {
	encode = function(value)
		CryptoPersistence._lastDecoded = value
		return '{"ok":true}'
	end,
	decode = function()
		return CryptoPersistence._lastDecoded
	end
}

dofile('server/main.lua')

local function call(playerId, action, payload)
	invoking = 'coe_phone'
	return registered.TabletCall(playerId, 'crypto', action, payload or {})
end

-- Pronto e visível
eq(registered.IsReady(), true, 'rede pronta')
eq(registered.Price(), config.Exchange.StartPrice, 'cotação inicial')
eq(registered.TabletVisible(1, 'crypto'), true, 'app visível no celular')
invoking = 'coe_admin'
eq(registered.TabletVisible(1, 'crypto'), false, 'só aparelhos veem o app')
eq(registered.TabletCall(1, 'crypto', 'state', {}).error, 'forbidden', 'chamador não autorizado')

-- Carteira nova no aparelho
local created = call(1, 'create', { label = 'Principal' })
eq(created.ok, true, 'cria carteira')
local mine = created.address
eq(CryptoRules.Address(config, mine), mine, 'endereço válido')
eq(CryptoRules.Key(created.key), created.key, 'chave válida')
local state = call(1, 'state')
eq(#state.wallets, 1, 'carteira no aparelho')
eq(state.wallets[1].source, 'device', 'origem: aparelho')

-- Compra na corretora
local buy = call(1, 'buy', { address = mine, dollars = 10000 })
eq(buy.ok, true, 'compra')
eq(bank['11'], 100000 - buy.cost, 'banco debitado')
eq(registered.Balance(mine), buy.units, 'moedas na carteira')
eq(call(1, 'buy', { address = mine, dollars = 10000 }).error, 'order_cooldown', 'intervalo entre ordens')
now = now + config.Exchange.OrderCooldownSeconds
eq(call(1, 'buy', { address = mine, dollars = 10 }).error, 'order_out_of_range', 'abaixo do mínimo')

-- Segunda carteira (outro personagem) e envio
local other = call(2, 'create', {}).address
eq(call(2, 'send', { from = mine, to = other, amount = '1' }).error, 'no_key', 'sem a chave não envia')
local amount = 10000
local before = registered.Balance(mine)
local sent = call(1, 'send', { from = mine, to = other, amount = '1', memo = 'pagamento' })
eq(sent.ok, true, 'envio')
eq(registered.Balance(other), amount, 'destino recebeu')
eq(registered.Balance(mine), before - amount - config.Transfer.Fee, 'origem pagou quantia + taxa')
eq(call(1, 'send', { from = mine, to = other, amount = '0,1' }).error, 'send_cooldown', 'intervalo entre envios')
now = now + config.Transfer.CooldownSeconds
eq(call(1, 'send', { from = mine, to = 'nx' .. string.rep('a', 28), amount = '0,1' }).error, 'unknown_recipient', 'destino inexistente')
eq(call(1, 'send', { from = mine, to = other, amount = '999999' }).error, 'insufficient_funds', 'saldo insuficiente')

-- Papel: a chave vai para o inventário; outro aparelho usa a carteira só com o papel
eq(call(1, 'exportPaper', { address = mine }).ok, true, 'anota em papel')
eq(call(1, 'exportUsb', { address = mine }).error, 'no_blank_usb', 'sem pen drive vazio')
local paper = inventory['character:11'].items[1]
eq(paper.name, config.Items.Paper, 'item de papel')
eq(paper.metadata.address, mine, 'papel com o endereço')
-- Entrega o papel ao personagem 2: ele vê a carteira e pode enviar.
inventory['character:22'].items[1] = paper
inventory['character:11'].items[1] = nil
local seen = call(2, 'state').wallets
local fromPaper
for _, wallet in ipairs(seen) do if wallet.address == mine then fromPaper = wallet end end
eq(fromPaper and fromPaper.source, 'paper', 'carteira do papel aparece para quem carrega')
now = now + config.Transfer.CooldownSeconds
eq(call(2, 'send', { from = mine, to = other, amount = '0,5' }).ok, true, 'quem tem o papel move os fundos')

-- Importação com chave errada bloqueia o aparelho
for _ = 1, config.Wallets.ImportFailures do
	call(1, 'import', { address = other, key = 'NXK-AAAAA-AAAAA-AAAAA-AAAAA-AAAAA' })
end
eq(call(1, 'import', { address = other, key = created.key }).error, 'import_locked', 'importação bloqueada')

-- Venda com o banco recusando: moedas voltam
now = now + 3600
local held = registered.Balance(other)
creditFails = true
eq(call(2, 'sell', { address = other, amount = '0,5' }).error, 'payment_failed', 'banco recusou a venda')
eq(registered.Balance(other), held, 'moedas devolvidas')
creditFails = false
now = now + config.Exchange.OrderCooldownSeconds
local sold = call(2, 'sell', { address = other, amount = '0,5' })
eq(sold.ok, true, 'venda')
eq(bank['22'], sold.payout, 'dinheiro no banco')

-- Esquecer a chave do aparelho
eq(call(1, 'forget', { address = mine }).ok, true, 'remove do aparelho')
eq(#call(1, 'state').wallets, 0, 'aparelho sem carteiras')

-- Mineração
invoking = 'coe_police'
eq(registered.MintMining({ { address = other, hash = 40 } }).error, 'forbidden', 'só o coe_deepweb minera')
invoking = 'coe_deepweb'
local mined = registered.MintMining({ { address = other, hash = 40 }, { address = other, hash = 10 }, { address = 'lixo', hash = 5 } })
eq(mined.ok, true, 'rodada de mineração')
eq(mined.payouts[other], config.Mining.EmissionPerTick * 40 // config.Mining.ReferenceHash + config.Mining.EmissionPerTick * 10 // config.Mining.ReferenceHash, 'soma por endereço')
eq(registered.MintMining({ { address = other, hash = 40 } }).error, 'too_soon', 'uma rodada por intervalo')

-- Computador
eq(registered.ComputerCall(1, 'laptop:LT-AAAAAAAA', 'state', {}).ok, true, 'computador do coe_deepweb')
invoking = 'coe_phone'
eq(registered.ComputerCall(1, 'laptop:LT-AAAAAAAA', 'state', {}).error, 'forbidden', 'só o coe_deepweb chama como computador')

-- Carteira criada num aparelho e importada em outro (o caso do celular -> notebook)
local phoneWallet = call(1, 'create', { label = 'Celular' })
eq(phoneWallet.ok, true, 'carteira criada no celular')
eq(CoeHash.IsCurrent(db.wallets[phoneWallet.address].hash), true, 'hash no formato próprio')
invoking = 'coe_deepweb'
local imported = registered.ComputerCall(1, 'laptop:LT-BBBBBBBB', 'import', { address = phoneWallet.address, key = phoneWallet.key:lower() })
eq(imported.ok, true, 'importa no notebook com a chave do celular')
eq(registered.ComputerCall(1, 'laptop:LT-BBBBBBBB', 'import', { address = 'nx123', key = phoneWallet.key }).error, 'invalid_address', 'endereço mal digitado')
eq(registered.ComputerCall(1, 'laptop:LT-BBBBBBBB', 'import', { address = phoneWallet.address, key = 'NXK-123' }).error, 'invalid_key_format', 'chave mal digitada')
eq(registered.ComputerCall(1, 'laptop:LT-BBBBBBBB', 'import', { address = 'nx' .. string.rep('z', 28), key = phoneWallet.key }).error, 'unknown_address', 'endereço inexistente')
eq(registered.ComputerCall(1, 'laptop:LT-BBBBBBBB', 'import', { address = phoneWallet.address, key = 'NXK-22222-22222-22222-22222-22222' }).error, 'key_mismatch', 'chave de outra carteira')

-- Carteira antiga (hash bcrypt que o servidor não confere): vale a chave guardada no celular e o hash é refeito
local legacyAddress = 'nx' .. string.rep('L', 28)
local legacyKey = 'NXK-ABCDE-FGHJK-LMNPQ-RSTUV-WXYZ2'
db.wallets[legacyAddress] = { address = legacyAddress, hash = '$2b$10$antigo', balance = 50000 }
db.keystore[#db.keystore + 1] = { device = 'phone:SER1', address = legacyAddress, key = legacyKey, label = 'Antiga' }
local legacyImport = registered.ComputerCall(1, 'laptop:LT-BBBBBBBB', 'import', { address = legacyAddress, key = legacyKey })
eq(legacyImport.ok, true, 'carteira antiga importa com a chave guardada no aparelho')
eq(CoeHash.IsCurrent(db.wallets[legacyAddress].hash), true, 'hash antigo refeito no formato novo')
eq(CoeHash.Verify(legacyKey, db.wallets[legacyAddress].hash), true, 'hash novo confere a chave')
invoking = 'coe_phone'

-- Admin (coe_admin)
eq(registered.AdminOverview().error, 'forbidden', 'só coe_admin lê AdminOverview')
eq(registered.AdminInspect(mine).error, 'forbidden', 'só coe_admin inspeciona endereço')
eq(registered.AdminSaveSettings({}).error, 'forbidden', 'só coe_admin salva configurações')
eq(registered.AdminResetSettings().error, 'forbidden', 'só coe_admin restaura configurações')
eq(registered.AdminSetPrice(3000).error, 'forbidden', 'só coe_admin altera cotação')

-- Custódia do mercado (coe_deepweb)
local escrowAddress = config.Escrow.Address
local PHONE_KEY = 'phone:SER1'
invoking = 'coe_police'
eq(registered.EscrowLock(1, 'phone:PHONE1', legacyAddress, 100).error, 'forbidden', 'só o coe_deepweb trava custódia')
eq(registered.EscrowRelease(legacyAddress, 100).error, 'forbidden', 'só o coe_deepweb libera custódia')
eq(registered.HeldWallets(1, 'phone:PHONE1'), nil, 'só o coe_deepweb lista carteiras à mão')
invoking = 'coe_deepweb'
local heldList = registered.HeldWallets(1, PHONE_KEY)
eq(type(heldList) == 'table' and #heldList >= 1, true, 'carteiras à mão no aparelho')
eq(heldList[1].balance, registered.Balance(heldList[1].address), 'carteira vem com saldo')
local beforeLock = registered.Balance(legacyAddress)
eq(registered.EscrowLock(2, 'phone:SER2', legacyAddress, 100).error ~= nil, true, 'outro personagem sem a chave não trava')
local locked = registered.EscrowLock(1, PHONE_KEY, legacyAddress, 5000, 'pedido #1')
eq(locked.ok, true, 'trava na custódia')
eq(registered.Balance(escrowAddress), 5000, 'custódia segura o valor')
eq(registered.Balance(legacyAddress), beforeLock - 5000 - config.Transfer.Fee, 'comprador paga valor + taxa da rede')
eq(registered.EscrowLock(1, PHONE_KEY, legacyAddress, 10 ^ 12).error, 'insufficient_funds', 'sem saldo não trava')
eq(registered.EscrowRelease(other, 4000, 'pedido #1').ok, true, 'libera para o vendedor')
eq(registered.EscrowRelease(other, 2000).error, 'database_error', 'não libera além do que está em custódia')
eq(registered.EscrowRelease('lixo', 10).error, 'invalid_address', 'destino inválido')
eq(registered.Balance(escrowAddress), 1000, 'sobra na custódia')
eq(registered.ReserveAddress(), config.Exchange.ReserveAddress, 'endereço da reserva')

invoking = 'coe_admin'
local overview = registered.AdminOverview()
eq(overview.available, true, 'AdminOverview disponível para coe_admin')
eq(overview.settings.coin.symbol, 'NOX', 'AdminOverview traz configurações atuais')
eq(overview.market.price, config.Exchange.StartPrice, 'AdminOverview traz cotação atual')
eq(overview.summary.wallets > 0, true, 'AdminOverview traz resumo de carteiras da rede')

local inspected = registered.AdminInspect(mine)
eq(inspected.wallet and inspected.wallet.address, mine, 'AdminInspect devolve carteira existente')
eq(registered.AdminInspect('invalido').error, 'invalid_address', 'AdminInspect valida endereço')
eq(registered.AdminInspect('nx' .. string.rep('9', 28)).error, 'unknown_address', 'AdminInspect avisa carteira inexistente')

local edited = CryptoRules.SettingsView(config)
edited.coin.name = 'Coecoin'
edited.coin.symbol = 'COE'
edited.transfer.fee = 50
edited.exchange.anchorPrice = 3200
eq(registered.AdminSaveSettings(edited), true, 'AdminSaveSettings grava e aplica')
eq(config.Coin.Name, 'Coecoin', 'nome atualizado em memória')
eq(config.Coin.Symbol, 'COE', 'símbolo atualizado em memória')
eq(config.Transfer.Fee, 50, 'taxa atualizada em memória')
eq(config.Exchange.AnchorPrice, 3200, 'âncora atualizada em memória')
eq(db.settings ~= nil, true, 'configuração persistida no banco')

eq(registered.AdminSetPrice(4100), true, 'AdminSetPrice fixa cotação')
eq(registered.Price(), 4100, 'cotação alterada pelo admin')
eq(registered.AdminSetPrice(99999999).error, 'invalid_price', 'AdminSetPrice respeita o teto')

eq(registered.AdminResetSettings(), true, 'AdminResetSettings restaura padrão')
eq(config.Coin.Symbol, 'NOX', 'símbolo restaurado ao padrão')
eq(config.Transfer.Fee, 10, 'taxa restaurada ao padrão')
eq(db.settings, nil, 'configuração customizada removida do banco')

if failures > 0 then
	print(('%d falha(s)'):format(failures))
	os.exit(1)
end
print('crypto server_test: ok')

