dofile('config.lua')
dofile('shared/rules.lua')

local config = CryptoConfig
local failures = 0

local function eq(actual, expected, message)
	if actual ~= expected then
		failures = failures + 1
		print(('FAIL %s: esperado %s, obtido %s'):format(message, tostring(expected), tostring(actual)))
	end
end

-- Gerador determinístico para os testes.
local function sequence(values)
	local index = 0
	return function(n)
		index = index + 1
		local value = values[(index - 1) % #values + 1]
		return n and ((value - 1) % n) + 1 or value
	end
end

-- Endereços e chaves
local address = CryptoRules.NewAddress(config, sequence({ 1, 2, 3, 57 }))
eq(#address, config.Address.Length, 'tamanho do endereço')
eq(address:sub(1, 2), 'nx', 'prefixo do endereço')
eq(CryptoRules.Address(config, address), address, 'endereço gerado é válido')
eq(CryptoRules.Address(config, ' ' .. address .. ' '), address, 'endereço com espaços nas pontas')
eq(CryptoRules.Address(config, 'nx' .. string.rep('0', 28)), nil, 'zero não é base58')
eq(CryptoRules.Address(config, 'nx' .. string.rep('l', 28)), nil, 'l minúsculo não é base58')
eq(CryptoRules.Address(config, 'xx' .. string.rep('a', 28)), nil, 'prefixo errado')
eq(CryptoRules.Address(config, 'nxabc'), nil, 'curto')
eq(CryptoRules.Address(config, config.Exchange.ReserveAddress), config.Exchange.ReserveAddress, 'reserva da corretora é endereço válido')

local key = CryptoRules.NewKey(sequence({ 5, 9, 31, 2 }))
eq(#key, 33, 'tamanho da chave')
eq(CryptoRules.Key(key), key, 'chave gerada é válida')
eq(CryptoRules.Key(key:lower():gsub('%-', ' ')), key, 'chave digitada em minúsculas e com espaços')
eq(CryptoRules.Key((key:gsub('%-', ''))), key, 'chave sem hífens')
eq(CryptoRules.Key('NXK-AAAAA-AAAAA-AAAAA-AAAAA-AAAA'), nil, 'chave curta')
eq(CryptoRules.Key('NXK-AAAAA-AAAAA-AAAAA-AAAAA-AAAA0'), nil, 'zero não entra na chave')
eq(CryptoRules.Key('ABC-AAAAA-AAAAA-AAAAA-AAAAA-AAAAA'), nil, 'prefixo da chave')

-- Rótulo e memo
eq(CryptoRules.Label(config, '  Poupança <b> '), 'Poupança b', 'rótulo sem < >')
eq(CryptoRules.Label(config, string.rep('é', 30)), string.rep('é', 24), 'rótulo cortado por caractere')
eq(CryptoRules.Memo(config, nil), '', 'memo vazio')

-- Quantias
eq(CryptoRules.ParseAmount(config, '1,5'), 15000, 'vírgula decimal')
eq(CryptoRules.ParseAmount(config, '0.0001'), 1, 'menor unidade')
eq(CryptoRules.ParseAmount(config, '2'), 20000, 'inteiro')
eq(CryptoRules.ParseAmount(config, 0.25), 2500, 'número')
eq(select(2, CryptoRules.ParseAmount(config, '0,00001')), 'too_many_decimals', 'casas demais')
eq(CryptoRules.ParseAmount(config, '1,50000'), 15000, 'zeros extras no fim')
eq(CryptoRules.ParseAmount(config, '0'), nil, 'zero')
eq(CryptoRules.ParseAmount(config, '-1'), nil, 'negativo')
eq(CryptoRules.ParseAmount(config, '1e3'), nil, 'notação científica')
eq(CryptoRules.Format(config, 15000), '1,5000', 'formata')
eq(CryptoRules.Format(config, 7), '0,0007', 'formata fração')
eq(CryptoRules.Dollars('120'), 120, 'dólares')
eq(CryptoRules.Dollars('1.5'), nil, 'dólares sem centavos')

-- Envio
eq(CryptoRules.CanSend(config, 10000, 9990), true, 'cabe com a taxa')
eq(select(2, CryptoRules.CanSend(config, 10000, 9991)), 'insufficient_funds', 'taxa não cabe')
eq(select(2, CryptoRules.CanSend(config, 10000, 0)), 'invalid_amount', 'zero')

-- Corretora
eq(CryptoRules.BuyPrice(config, 2500), 2575, 'preço de compra com spread')
eq(CryptoRules.SellPrice(config, 2500), 2425, 'preço de venda com spread')
local buy = CryptoRules.BuyQuote(config, 2500, 1000)
eq(buy.units, 1000 * 10000 // 2575, 'unidades compradas')
eq(buy.cost <= 1000, true, 'custo não passa do pedido')
eq(buy.cost >= 999, true, 'custo perto do pedido')
eq(select(2, CryptoRules.BuyQuote(config, 2500, 10)), 'order_out_of_range', 'compra abaixo do mínimo')
eq(select(2, CryptoRules.BuyQuote(config, 2500, config.Exchange.MaxOrder + 1)), 'order_out_of_range', 'compra acima do máximo')
local sell = CryptoRules.SellQuote(config, 2500, 10000)
eq(sell.payout, 2425, 'venda de 1 moeda')
eq(select(2, CryptoRules.SellQuote(config, 2500, 100)), 'order_out_of_range', 'venda pequena demais')
eq(CryptoRules.WithinDailyLimit(config, 'buy', config.Exchange.DailyBuyLimit - 100, 100), true, 'no limite diário')
eq(CryptoRules.WithinDailyLimit(config, 'buy', config.Exchange.DailyBuyLimit - 100, 101), false, 'passa do limite diário')

-- Cotação
eq(CryptoRules.NextPrice(config, 2500, 0, 0), 2500, 'na âncora e sem ruído fica parada')
eq(CryptoRules.NextPrice(config, 5000, 0, 0) < 5000, true, 'acima da âncora tende a cair')
eq(CryptoRules.NextPrice(config, 1000, 0, 0) > 1000, true, 'abaixo da âncora tende a subir')
eq(CryptoRules.NextPrice(config, 2500, 1000000, 0) > 2500, true, 'compra líquida empurra para cima')
eq(CryptoRules.NextPrice(config, 2500, -1000000, 0) < 2500, true, 'venda líquida derruba')
eq(CryptoRules.NextPrice(config, 200, -1e12, 0), config.Exchange.MinPrice, 'piso')
eq(CryptoRules.NextPrice(config, 50000, 1e12, 0), config.Exchange.MaxPrice, 'teto')
eq(math.type(CryptoRules.NextPrice(config, 2500, 0, 1.3)), 'integer', 'preço inteiro')
local noise = CryptoRules.Gaussian(function() return 0.5 end)
eq(noise < 0, true, 'Box-Muller com u2 = 0,5 dá negativo')
eq(CryptoRules.Change(2000, 2100), 5, 'variação percentual')

-- Mineração
local payouts, emitted = CryptoRules.MiningPayouts(config, { { address = 'a', hash = 40 }, { address = 'b', hash = 10 } }, 0)
eq(#payouts, 2, 'duas máquinas recebem')
eq(payouts[1].units, config.Mining.EmissionPerTick * 40 // config.Mining.ReferenceHash, 'rede fraca: abaixo da referência')
eq(emitted < config.Mining.EmissionPerTick, true, 'rede fraca não emite tudo')
payouts, emitted = CryptoRules.MiningPayouts(config, { { address = 'a', hash = 300 }, { address = 'b', hash = 100 } }, 0)
eq(emitted, config.Mining.EmissionPerTick, 'rede forte emite tudo')
eq(payouts[1].units, config.Mining.EmissionPerTick * 3 // 4, 'proporcional ao poder')
payouts, emitted = CryptoRules.MiningPayouts(config, { { address = 'a', hash = 300 } }, config.Mining.MaxMined - 5)
eq(emitted, 5, 'respeita o teto')
payouts, emitted = CryptoRules.MiningPayouts(config, { { address = 'a', hash = 300 } }, config.Mining.MaxMined)
eq(emitted, 0, 'teto atingido')
local merged = CryptoRules.MergePayouts({ { address = 'a', units = 3 }, { address = 'b', units = 1 }, { address = 'a', units = 2 } })
eq(#merged, 2, 'agrupa por endereço')
eq(merged[1].units, 5, 'soma do mesmo endereço')

-- Bloqueio da importação
local state
for _ = 1, config.Wallets.ImportFailures - 1 do
	state = CryptoRules.Fail(config, state, 100)
end
eq(CryptoRules.Locked(state, 100), false, 'ainda não bloqueia')
state = CryptoRules.Fail(config, state, 100)
eq(CryptoRules.Locked(state, 100), true, 'bloqueia')
eq(CryptoRules.Locked(state, 100 + config.Wallets.ImportLockSeconds), false, 'libera depois')

-- Configurações administrativas
local view = CryptoRules.SettingsView(config)
eq(view.coin.name, 'Noxcoin', 'view nome da moeda')
eq(view.coin.symbol, 'NOX', 'view símbolo da moeda')
eq(view.exchange.anchorPrice, 2500, 'view âncora da corretora')
local clean, err = CryptoRules.ValidateSettings(view)
eq(err, nil, 'configuração padrão é válida')
eq(clean.coin.symbol, 'NOX', 'símbolo validado')

view.coin.symbol = 'nox2'
clean = CryptoRules.ValidateSettings(view)
eq(clean.coin.symbol, 'NOX2', 'símbolo normalizado em maiúsculas')

view.coin.symbol = 'N'
eq(select(2, CryptoRules.ValidateSettings(view)), 'invalid_coin', 'símbolo curto demais')
view.coin.symbol = 'NOX'

view.exchange.minPrice = 5000
view.exchange.maxPrice = 3000
eq(select(2, CryptoRules.ValidateSettings(view)), 'invalid_exchange_prices', 'piso maior que o teto')
view.exchange.minPrice = 150
view.exchange.maxPrice = 60000

view.transfer.minAmount = 100
view.transfer.maxAmount = 50
eq(select(2, CryptoRules.ValidateSettings(view)), 'invalid_transfer', 'envio mínimo maior que o máximo')
view.transfer.minAmount = 1
view.transfer.maxAmount = 1000000000000

view.exchange.anchorPrice = 4000
view.transfer.fee = 25
clean = CryptoRules.ValidateSettings(view)
CryptoRules.ApplySettings(config, clean)
eq(config.Exchange.AnchorPrice, 4000, 'aplica nova âncora em memória')
eq(config.Transfer.Fee, 25, 'aplica nova taxa em memória')

if failures > 0 then
	print(('%d falha(s)'):format(failures))
	os.exit(1)
end
print('crypto_test: ok')

