-- Regras puras do coe_crypto (sem natives), usadas pelo servidor e pelos testes.
-- Valores de moeda sempre em unidades inteiras; dólares sempre inteiros.
CryptoRules = {}

local BASE58 = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'
local BASE32 = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ'

local function trim(value)
	return (tostring(value):gsub('^%s+', ''):gsub('%s+$', ''))
end

local function pick(alphabet, rand)
	local index = rand(#alphabet)
	return alphabet:sub(index, index)
end

-- Fator de escala: unidades por moeda inteira.
function CryptoRules.Scale(config)
	return math.tointeger(10 ^ config.Coin.Decimals)
end

-- Endereço novo. rand(n) devolve um inteiro de 1 a n.
function CryptoRules.NewAddress(config, rand)
	local parts = { config.Address.Prefix }
	for _ = 1, config.Address.Length - #config.Address.Prefix do
		parts[#parts + 1] = pick(BASE58, rand)
	end
	return table.concat(parts)
end

-- Chave privada nova: NXK-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX.
function CryptoRules.NewKey(rand)
	local groups = {}
	for group = 1, 5 do
		local chars = {}
		for _ = 1, 5 do
			chars[#chars + 1] = pick(BASE32, rand)
		end
		groups[group] = table.concat(chars)
	end
	return 'NXK-' .. table.concat(groups, '-')
end

-- Endereço válido (formato), ou nil.
function CryptoRules.Address(config, value)
	if type(value) ~= 'string' then
		return nil
	end
	local address = trim(value)
	local prefix = config.Address.Prefix
	if #address ~= config.Address.Length or address:sub(1, #prefix) ~= prefix then
		return nil
	end
	local body = address:sub(#prefix + 1)
	if body:find('[^' .. BASE58 .. ']') then
		return nil
	end
	return address
end

-- Chave normalizada (maiúsculas, com hífens no lugar), ou nil. Aceita a chave digitada sem hífens ou com espaços.
function CryptoRules.Key(value)
	if type(value) ~= 'string' then
		return nil
	end
	local compact = value:upper():gsub('[%s%-]', '')
	if compact:sub(1, 3) ~= 'NXK' then
		return nil
	end
	compact = compact:sub(4)
	if #compact ~= 25 or compact:find('[^' .. BASE32 .. ']') then
		return nil
	end
	local groups = {}
	for index = 1, 25, 5 do
		groups[#groups + 1] = compact:sub(index, index + 4)
	end
	return 'NXK-' .. table.concat(groups, '-')
end

-- Rótulo curto da carteira (sem controle nem < >). Vazio devolve ''.
function CryptoRules.Label(config, value)
	if type(value) ~= 'string' then
		return ''
	end
	local text = trim(value:gsub('[%c<>]', ' '):gsub('%s+', ' '))
	if not utf8.len(text) then
		return ''
	end
	if utf8.len(text) > config.Wallets.LabelMax then
		text = text:sub(1, utf8.offset(text, config.Wallets.LabelMax + 1) - 1)
	end
	return text
end

function CryptoRules.Memo(config, value)
	if type(value) ~= 'string' then
		return ''
	end
	local text = trim(value:gsub('[%c<>]', ' '):gsub('%s+', ' '))
	if not utf8.len(text) then
		return ''
	end
	if utf8.len(text) > config.Transfer.MemoMax then
		text = text:sub(1, utf8.offset(text, config.Transfer.MemoMax + 1) - 1)
	end
	return text
end

-- Quantia digitada ("1,5", "0.25", 3) em unidades inteiras, ou nil + erro.
function CryptoRules.ParseAmount(config, value)
	local decimals = config.Coin.Decimals
	local text
	if type(value) == 'number' then
		if value ~= value or value <= 0 or value >= 1e15 then
			return nil, 'invalid_amount'
		end
		text = string.format('%.' .. decimals .. 'f', value)
	elseif type(value) == 'string' then
		text = trim(value):gsub(',', '.')
	else
		return nil, 'invalid_amount'
	end
	local whole, fraction = text:match('^(%d+)%.?(%d*)$')
	if not whole or #whole > 12 then
		return nil, 'invalid_amount'
	end
	if #fraction > decimals then
		if fraction:sub(decimals + 1):find('[1-9]') then
			return nil, 'too_many_decimals'
		end
		fraction = fraction:sub(1, decimals)
	end
	fraction = fraction .. string.rep('0', decimals - #fraction)
	local units = math.tointeger(tonumber(whole) * CryptoRules.Scale(config) + (tonumber(fraction) or 0))
	if not units or units <= 0 then
		return nil, 'invalid_amount'
	end
	return units
end

-- Unidades formatadas com vírgula decimal: 12345 -> "1,2345".
function CryptoRules.Format(config, units)
	local scale = CryptoRules.Scale(config)
	units = math.tointeger(units) or 0
	local sign = units < 0 and '-' or ''
	units = math.abs(units)
	local whole, fraction = units // scale, units % scale
	return ('%s%d,%0' .. config.Coin.Decimals .. 'd'):format(sign, whole, fraction)
end

-- Valor inteiro em $ (ordens da corretora), ou nil.
function CryptoRules.Dollars(value)
	local number = math.tointeger(tonumber(value))
	if not number or number <= 0 then
		return nil
	end
	return number
end

-- Envio: quantia + taxa cabem no saldo?
function CryptoRules.CanSend(config, balance, units)
	if units < config.Transfer.MinAmount or units > config.Transfer.MaxAmount then
		return false, 'invalid_amount'
	end
	if balance < units + config.Transfer.Fee then
		return false, 'insufficient_funds'
	end
	return true
end

-- Corretora ------------------------------------------------------------------------------------------

-- Preço unitário (por moeda inteira) de compra e de venda, com o spread.
function CryptoRules.BuyPrice(config, price)
	local bps = config.Exchange.SpreadBps
	return (price * (10000 + bps) + 9999) // 10000
end

function CryptoRules.SellPrice(config, price)
	local bps = config.Exchange.SpreadBps
	return math.max(1, (price * (10000 - bps)) // 10000)
end

-- Compra com até `dollars`: devolve { units, cost } (cost <= dollars) ou nil + erro.
function CryptoRules.BuyQuote(config, price, dollars)
	local exchange = config.Exchange
	if not dollars or dollars < exchange.MinOrder or dollars > exchange.MaxOrder then
		return nil, 'order_out_of_range'
	end
	local unitPrice = CryptoRules.BuyPrice(config, price)
	local scale = CryptoRules.Scale(config)
	local units = dollars * scale // unitPrice
	if units < 1 then
		return nil, 'order_out_of_range'
	end
	local cost = (units * unitPrice + scale - 1) // scale
	return { units = units, cost = cost, unitPrice = unitPrice }
end

-- Venda de `units`: devolve { units, payout } ou nil + erro.
function CryptoRules.SellQuote(config, price, units)
	local exchange = config.Exchange
	local unitPrice = CryptoRules.SellPrice(config, price)
	local payout = units * unitPrice // CryptoRules.Scale(config)
	if payout < exchange.MinOrder or payout > exchange.MaxOrder then
		return nil, 'order_out_of_range'
	end
	return { units = units, payout = payout, unitPrice = unitPrice }
end

-- Limite diário por personagem. kind: 'buy' | 'sell'; used: $ já movimentado nas últimas 24 h.
function CryptoRules.WithinDailyLimit(config, kind, used, dollars)
	local limit = kind == 'buy' and config.Exchange.DailyBuyLimit or config.Exchange.DailySellLimit
	return (used or 0) + dollars <= limit, math.max(0, limit - (used or 0))
end

-- Normal padrão (Box-Muller) a partir de rand() em [0, 1).
function CryptoRules.Gaussian(rand)
	local u1 = 1 - rand()
	local u2 = rand()
	return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
end

-- Próxima cotação: volta à âncora + ruído + impacto do fluxo líquido ($ comprados - $ vendidos no intervalo).
function CryptoRules.NextPrice(config, price, netFlow, noise)
	local exchange = config.Exchange
	local logPrice = math.log(math.max(1, price))
	local anchor = math.log(exchange.AnchorPrice)
	logPrice = logPrice + exchange.MeanReversion * (anchor - logPrice) + exchange.Volatility * (noise or 0)
		+ exchange.ImpactPerMillion * (netFlow or 0) / 1000000
	local nextPrice = math.floor(math.exp(logPrice) + 0.5)
	return math.tointeger(math.max(exchange.MinPrice, math.min(exchange.MaxPrice, nextPrice)))
end

-- Variação percentual (uma casa) entre dois preços.
function CryptoRules.Change(previous, current)
	if not previous or previous <= 0 then
		return 0
	end
	return math.floor((current - previous) * 1000 / previous + 0.5) / 10
end

-- Mineração ------------------------------------------------------------------------------------------

-- entries: { { address, hash } }. Devolve lista { address, units } e o total emitido.
-- Cada máquina leva EmissionPerTick * hash / max(hash total, ReferenceHash), limitado ao que falta do teto.
function CryptoRules.MiningPayouts(config, entries, minted)
	local mining = config.Mining
	local total = 0
	for _, entry in ipairs(entries) do
		total = total + entry.hash
	end
	local remaining = math.max(0, mining.MaxMined - (minted or 0))
	if total <= 0 or remaining == 0 then
		return {}, 0
	end
	local divisor = math.max(total, mining.ReferenceHash)
	local payouts, emitted = {}, 0
	for _, entry in ipairs(entries) do
		local units = mining.EmissionPerTick * entry.hash // divisor
		if units > 0 then
			payouts[#payouts + 1] = { address = entry.address, units = units }
			emitted = emitted + units
		end
	end
	if emitted > remaining then
		local scaled = 0
		for _, payout in ipairs(payouts) do
			payout.units = payout.units * remaining // emitted
			scaled = scaled + payout.units
		end
		emitted = scaled
	end
	local list = {}
	for _, payout in ipairs(payouts) do
		if payout.units > 0 then
			list[#list + 1] = payout
		end
	end
	return list, emitted
end

-- Junta pagamentos ao mesmo endereço (várias máquinas pagando a mesma carteira).
function CryptoRules.MergePayouts(list)
	local byAddress, order = {}, {}
	for _, payout in ipairs(list) do
		if not byAddress[payout.address] then
			byAddress[payout.address] = 0
			order[#order + 1] = payout.address
		end
		byAddress[payout.address] = byAddress[payout.address] + payout.units
	end
	local merged = {}
	for _, address in ipairs(order) do
		merged[#merged + 1] = { address = address, units = byAddress[address] }
	end
	return merged
end

-- Bloqueio por erros seguidos (importação de chave). state: { failures, lockedUntil }.
function CryptoRules.Fail(config, state, now)
	state = state or { failures = 0, lockedUntil = 0 }
	state.failures = state.failures + 1
	if state.failures >= config.Wallets.ImportFailures then
		state.failures = 0
		state.lockedUntil = now + config.Wallets.ImportLockSeconds
	end
	return state
end

function CryptoRules.Locked(state, now)
	return state ~= nil and (state.lockedUntil or 0) > now
end

-- Configurações administrativas ----------------------------------------------------------------------

local function wholeInt(value, low, high)
	local num = tonumber(value)
	if not num or num ~= num or num % 1 ~= 0 or num < low or num > high then
		return nil
	end
	return math.tointeger(num)
end

local function floatRange(value, low, high)
	local num = tonumber(value)
	if not num or num ~= num or num < low or num > high then
		return nil
	end
	return math.floor(num * 1000000 + 0.5) / 1000000
end

local function cleanText(value, minLen, maxLen)
	if type(value) ~= 'string' then
		return nil
	end
	local text = trim(value:gsub('[%c<>]', ' '):gsub('%s+', ' '))
	local len = utf8.len(text)
	if not len or len < minLen or len > maxLen then
		return nil
	end
	return text
end

-- Projeção serializável das configurações atuais do coe_crypto para o painel administrativo.
function CryptoRules.SettingsView(config)
	return {
		coin = {
			name = config.Coin.Name,
			symbol = config.Coin.Symbol,
			decimals = config.Coin.Decimals
		},
		address = {
			prefix = config.Address.Prefix,
			length = config.Address.Length
		},
		wallets = {
			maxPerDevice = config.Wallets.MaxPerDevice,
			maxCreatedPerDay = config.Wallets.MaxCreatedPerDay,
			labelMax = config.Wallets.LabelMax,
			importFailures = config.Wallets.ImportFailures,
			importLockSeconds = config.Wallets.ImportLockSeconds
		},
		transfer = {
			fee = config.Transfer.Fee,
			minAmount = config.Transfer.MinAmount,
			maxAmount = config.Transfer.MaxAmount,
			memoMax = config.Transfer.MemoMax,
			cooldownSeconds = config.Transfer.CooldownSeconds
		},
		exchange = {
			enabled = config.Exchange.Enabled == true,
			name = config.Exchange.Name,
			reserveAddress = config.Exchange.ReserveAddress,
			reserve = config.Exchange.Reserve,
			startPrice = config.Exchange.StartPrice,
			anchorPrice = config.Exchange.AnchorPrice,
			minPrice = config.Exchange.MinPrice,
			maxPrice = config.Exchange.MaxPrice,
			tickMinutes = config.Exchange.TickMinutes,
			volatility = config.Exchange.Volatility,
			meanReversion = config.Exchange.MeanReversion,
			impactPerMillion = config.Exchange.ImpactPerMillion,
			spreadBps = config.Exchange.SpreadBps,
			minOrder = config.Exchange.MinOrder,
			maxOrder = config.Exchange.MaxOrder,
			dailyBuyLimit = config.Exchange.DailyBuyLimit,
			dailySellLimit = config.Exchange.DailySellLimit,
			historyPoints = config.Exchange.HistoryPoints,
			orderCooldownSeconds = config.Exchange.OrderCooldownSeconds
		},
		mining = {
			tickMinutes = config.Mining.TickMinutes,
			emissionPerTick = config.Mining.EmissionPerTick,
			referenceHash = config.Mining.ReferenceHash,
			maxMined = config.Mining.MaxMined
		},
		network = {
			historyPageSize = config.HistoryPageSize,
			callCooldownMs = config.CallCooldownMs
		}
	}
end

-- Valida um pacote de configurações vindas do painel administrativo ou do banco.
function CryptoRules.ValidateSettings(raw)
	if type(raw) ~= 'table' then
		return nil, 'invalid_settings'
	end
	local coinRaw = type(raw.coin) == 'table' and raw.coin or {}
	local coinName = cleanText(coinRaw.name, 1, 24)
	local coinSymbol = type(coinRaw.symbol) == 'string' and trim(coinRaw.symbol):upper() or ''
	if not coinName or #coinSymbol < 2 or #coinSymbol > 6 or coinSymbol:find('[^A-Z0-9]') then
		return nil, 'invalid_coin'
	end

	local walletsRaw = type(raw.wallets) == 'table' and raw.wallets or {}
	local maxPerDevice = wholeInt(walletsRaw.maxPerDevice, 1, 32)
	local maxCreatedPerDay = wholeInt(walletsRaw.maxCreatedPerDay, 1, 100)
	local labelMax = wholeInt(walletsRaw.labelMax, 4, 48)
	local importFailures = wholeInt(walletsRaw.importFailures, 1, 50)
	local importLockSeconds = wholeInt(walletsRaw.importLockSeconds, 10, 86400)
	if not (maxPerDevice and maxCreatedPerDay and labelMax and importFailures and importLockSeconds) then
		return nil, 'invalid_wallets'
	end

	local transferRaw = type(raw.transfer) == 'table' and raw.transfer or {}
	local fee = wholeInt(transferRaw.fee, 0, 1000000000)
	local minAmount = wholeInt(transferRaw.minAmount, 1, 100000000000000)
	local maxAmount = minAmount and wholeInt(transferRaw.maxAmount, minAmount, 100000000000000) or nil
	local memoMax = wholeInt(transferRaw.memoMax, 0, 120)
	local cooldownSeconds = wholeInt(transferRaw.cooldownSeconds, 0, 3600)
	if not (fee and minAmount and maxAmount and memoMax and cooldownSeconds) then
		return nil, 'invalid_transfer'
	end

	local exRaw = type(raw.exchange) == 'table' and raw.exchange or {}
	local exName = cleanText(exRaw.name, 1, 24)
	if not exName then
		return nil, 'invalid_exchange'
	end
	local minPrice = wholeInt(exRaw.minPrice, 1, 100000000)
	local maxPrice = minPrice and wholeInt(exRaw.maxPrice, minPrice, 100000000) or nil
	local anchorPrice = (minPrice and maxPrice) and wholeInt(exRaw.anchorPrice, minPrice, maxPrice) or nil
	local startPrice = (minPrice and maxPrice) and wholeInt(exRaw.startPrice, minPrice, maxPrice) or nil
	if not (minPrice and maxPrice and anchorPrice and startPrice) then
		return nil, 'invalid_exchange_prices'
	end
	local exTickMinutes = wholeInt(exRaw.tickMinutes, 1, 1440)
	local volatility = floatRange(exRaw.volatility, 0, 1)
	local meanReversion = floatRange(exRaw.meanReversion, 0, 1)
	local impactPerMillion = floatRange(exRaw.impactPerMillion, 0, 5)
	local spreadBps = wholeInt(exRaw.spreadBps, 0, 5000)
	local historyPoints = wholeInt(exRaw.historyPoints, 12, 2880)
	local orderCooldownSeconds = wholeInt(exRaw.orderCooldownSeconds, 0, 3600)
	if not (exTickMinutes and volatility and meanReversion and impactPerMillion and spreadBps and historyPoints and orderCooldownSeconds) then
		return nil, 'invalid_exchange'
	end
	local minOrder = wholeInt(exRaw.minOrder, 1, 100000000)
	local maxOrder = minOrder and wholeInt(exRaw.maxOrder, minOrder, 100000000) or nil
	local dailyBuyLimit = minOrder and wholeInt(exRaw.dailyBuyLimit, minOrder, 1000000000) or nil
	local dailySellLimit = minOrder and wholeInt(exRaw.dailySellLimit, minOrder, 1000000000) or nil
	if not (minOrder and maxOrder and dailyBuyLimit and dailySellLimit) then
		return nil, 'invalid_exchange_orders'
	end

	local miningRaw = type(raw.mining) == 'table' and raw.mining or {}
	local miningTickMinutes = wholeInt(miningRaw.tickMinutes, 1, 1440)
	local emissionPerTick = wholeInt(miningRaw.emissionPerTick, 0, 100000000000)
	local referenceHash = wholeInt(miningRaw.referenceHash, 1, 1000000)
	local maxMined = wholeInt(miningRaw.maxMined, 0, 1000000000000000)
	if not (miningTickMinutes and emissionPerTick and referenceHash and maxMined) then
		return nil, 'invalid_mining'
	end

	local netRaw = type(raw.network) == 'table' and raw.network or {}
	local historyPageSize = wholeInt(netRaw.historyPageSize, 5, 100)
	local callCooldownMs = wholeInt(netRaw.callCooldownMs, 50, 5000)
	if not (historyPageSize and callCooldownMs) then
		return nil, 'invalid_network'
	end

	return {
		coin = { name = coinName, symbol = coinSymbol },
		wallets = {
			maxPerDevice = maxPerDevice,
			maxCreatedPerDay = maxCreatedPerDay,
			labelMax = labelMax,
			importFailures = importFailures,
			importLockSeconds = importLockSeconds
		},
		transfer = {
			fee = fee,
			minAmount = minAmount,
			maxAmount = maxAmount,
			memoMax = memoMax,
			cooldownSeconds = cooldownSeconds
		},
		exchange = {
			enabled = exRaw.enabled == true,
			name = exName,
			startPrice = startPrice,
			anchorPrice = anchorPrice,
			minPrice = minPrice,
			maxPrice = maxPrice,
			tickMinutes = exTickMinutes,
			volatility = volatility,
			meanReversion = meanReversion,
			impactPerMillion = impactPerMillion,
			spreadBps = spreadBps,
			minOrder = minOrder,
			maxOrder = maxOrder,
			dailyBuyLimit = dailyBuyLimit,
			dailySellLimit = dailySellLimit,
			historyPoints = historyPoints,
			orderCooldownSeconds = orderCooldownSeconds
		},
		mining = {
			tickMinutes = miningTickMinutes,
			emissionPerTick = emissionPerTick,
			referenceHash = referenceHash,
			maxMined = maxMined
		},
		network = {
			historyPageSize = historyPageSize,
			callCooldownMs = callCooldownMs
		}
	}
end

-- Aplica configurações já validadas sobre a tabela `config` em memória.
function CryptoRules.ApplySettings(config, clean)
	if type(config) ~= 'table' or type(clean) ~= 'table' then
		return
	end
	if clean.coin then
		config.Coin.Name = clean.coin.name
		config.Coin.Symbol = clean.coin.symbol
	end
	if clean.wallets then
		config.Wallets.MaxPerDevice = clean.wallets.maxPerDevice
		config.Wallets.MaxCreatedPerDay = clean.wallets.maxCreatedPerDay
		config.Wallets.LabelMax = clean.wallets.labelMax
		config.Wallets.ImportFailures = clean.wallets.importFailures
		config.Wallets.ImportLockSeconds = clean.wallets.importLockSeconds
	end
	if clean.transfer then
		config.Transfer.Fee = clean.transfer.fee
		config.Transfer.MinAmount = clean.transfer.minAmount
		config.Transfer.MaxAmount = clean.transfer.maxAmount
		config.Transfer.MemoMax = clean.transfer.memoMax
		config.Transfer.CooldownSeconds = clean.transfer.cooldownSeconds
	end
	if clean.exchange then
		config.Exchange.Enabled = clean.exchange.enabled == true
		config.Exchange.Name = clean.exchange.name
		config.Exchange.StartPrice = clean.exchange.startPrice
		config.Exchange.AnchorPrice = clean.exchange.anchorPrice
		config.Exchange.MinPrice = clean.exchange.minPrice
		config.Exchange.MaxPrice = clean.exchange.maxPrice
		config.Exchange.TickMinutes = clean.exchange.tickMinutes
		config.Exchange.Volatility = clean.exchange.volatility
		config.Exchange.MeanReversion = clean.exchange.meanReversion
		config.Exchange.ImpactPerMillion = clean.exchange.impactPerMillion
		config.Exchange.SpreadBps = clean.exchange.spreadBps
		config.Exchange.MinOrder = clean.exchange.minOrder
		config.Exchange.MaxOrder = clean.exchange.maxOrder
		config.Exchange.DailyBuyLimit = clean.exchange.dailyBuyLimit
		config.Exchange.DailySellLimit = clean.exchange.dailySellLimit
		config.Exchange.HistoryPoints = clean.exchange.historyPoints
		config.Exchange.OrderCooldownSeconds = clean.exchange.orderCooldownSeconds
	end
	if clean.mining then
		config.Mining.TickMinutes = clean.mining.tickMinutes
		config.Mining.EmissionPerTick = clean.mining.emissionPerTick
		config.Mining.ReferenceHash = clean.mining.referenceHash
		config.Mining.MaxMined = clean.mining.maxMined
	end
	if clean.network then
		config.HistoryPageSize = clean.network.historyPageSize
		config.CallCooldownMs = clean.network.callCooldownMs
	end
end

local function getAlgorithms()
	return (type(Core) == 'table' and Core.Algorithms) or CoeAlgorithms
end

-- Cria RingBuffer Zero-GC para histórico de cotações da corretora.
function CryptoRules.NewPriceHistoryRing(capacity)
	local alg = getAlgorithms()
	if alg and alg.Containers and alg.Containers.newRingBuffer then
		return alg.Containers.newRingBuffer(capacity or 48)
	end
	return nil
end

-- Executa uma Saga de múltiplos passos com compensação LIFO automática.
function CryptoRules.ExecuteSaga(steps, context)
	local alg = getAlgorithms()
	if alg and alg.Concurrency and alg.Concurrency.executeSaga then
		return alg.Concurrency.executeSaga(steps, context)
	end
	local completed = {}
	local ctx = context or {}
	for i = 1, #steps do
		local ok, res = pcall(steps[i].action, ctx)
		if not ok or res == false then
			for j = #completed, 1, -1 do
				if completed[j].compensate then
					pcall(completed[j].compensate, ctx)
				end
			end
			return false, not ok and res or 'step_failed'
		end
		completed[#completed + 1] = steps[i]
	end
	return true, ctx
end

-- Cria gerenciador de locks assíncronos com ordenação lexicográfica anti-deadlock.
function CryptoRules.NewLockManager()
	local alg = getAlgorithms()
	if alg and alg.Concurrency and alg.Concurrency.newLockManager then
		return alg.Concurrency.newLockManager()
	end
	return nil
end

-- Cria rate limiter GCRA O(1) para chamadas de dispositivos e ordens.
function CryptoRules.NewCallLimiter(cooldownMs)
	local alg = getAlgorithms()
	if alg and alg.RateLimit and alg.RateLimit.newGCRA then
		return alg.RateLimit.newGCRA(cooldownMs or 250, 0)
	end
	return nil
end


