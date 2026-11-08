dofile('../coe_core/lib/algorithms/init.lua')
dofile('config.lua')
dofile('shared/rules.lua')

local config = DeepwebConfig
local failures = 0

local function eq(actual, expected, message)
	if actual ~= expected then
		failures = failures + 1
		print(('FAIL %s: esperado %s, obtido %s'):format(message, tostring(expected), tostring(actual)))
	end
end

-- Níveis
eq(DeepwebRules.Level(config, 'phone'), 1, 'celular é nível 1')
eq(DeepwebRules.Level(config, 'server'), 5, 'servidor é nível 5')
eq(DeepwebRules.Level(config, 'toaster'), nil, 'aparelho desconhecido')

-- Recursos por nível
local function stateOf(level, id)
	for _, feature in ipairs(DeepwebRules.Features(config, level)) do
		if feature.id == id then
			return feature.state
		end
	end
end
eq(stateOf(1, 'identity'), 'open', 'identidade no celular')
eq(stateOf(1, 'mining'), 'locked', 'mineração bloqueada no celular')
eq(stateOf(4, 'mining'), 'open', 'mineração no desktop')
eq(stateOf(5, 'contracts'), 'soon', 'contratos ficam para a próxima fase')
eq(DeepwebRules.Allows(config, 3, 'mining'), false, 'notebook não minera')
eq(DeepwebRules.Allows(config, 5, 'mining'), true, 'servidor minera')
eq(DeepwebRules.Allows(config, 5, 'contracts'), false, 'recurso em breve não libera')
eq(DeepwebRules.Allows(config, 2, 'market_buy'), true, 'tablet compra no Deep Market')
eq(DeepwebRules.Allows(config, 1, 'market_buy'), false, 'celular só vê a vitrine')
eq(DeepwebRules.Allows(config, 5, 'inexistente'), false, 'recurso inexistente')
local levels = {}
for _, feature in ipairs(config.Features) do
	levels[#levels + 1] = feature.level
end
for index = 2, #levels do
	eq(levels[index] >= levels[index - 1], true, 'recursos em ordem de nível (' .. index .. ')')
end

-- Apelidos
eq(DeepwebRules.Handle(config, '  Ghost_99 '), 'ghost_99', 'apelido normalizado')
eq(DeepwebRules.Handle(config, 'ab'), nil, 'apelido curto')
eq(DeepwebRules.Handle(config, string.rep('a', 21)), nil, 'apelido longo')
eq(DeepwebRules.Handle(config, '_ghost'), nil, 'começa com símbolo')
eq(DeepwebRules.Handle(config, 'gh..ost'), nil, 'símbolos seguidos')
eq(DeepwebRules.Handle(config, 'fantasma ruim'), nil, 'espaço no meio')
eq(select(2, DeepwebRules.Handle(config, 'policia')), 'handle_reserved', 'reservado')
eq(select(2, DeepwebRules.Handle(config, 'p.o.l.i.c.i.a')), 'handle_reserved', 'reservado disfarçado com pontos')

-- Senhas
eq(DeepwebRules.Password(6, 32, '12345'), nil, 'senha curta')
eq(DeepwebRules.Password(6, 32, ' segredo'), nil, 'espaço na ponta')
eq(DeepwebRules.Password(6, 32, 'segredo'), 'segredo', 'senha válida')

-- Séries e chaves de aparelho
local count = 0
local serial = DeepwebRules.Serial('LT', function(n) count = count + 1; return (count % n) + 1 end)
eq(#serial, 11, 'tamanho da série')
eq(DeepwebRules.IsSerial(serial), true, 'série gerada é válida')
eq(DeepwebRules.IsSerial('LT-0000AAAA'), false, 'zero não entra na série')
eq(DeepwebRules.IsSerial('lt-AAAAAAAA'), false, 'prefixo minúsculo')
eq(DeepwebRules.DeviceKey('laptop', serial), 'laptop:' .. serial, 'chave do aparelho')

-- Computador mais próximo
local rigs = { { id = 1, x = 0, y = 0, z = 0 }, { id = 2, x = 1, y = 0, z = 0 }, { id = 3, x = 10, y = 0, z = 0 } }
eq(DeepwebRules.Nearest(rigs, 0.9, 0, 0, 2.5).id, 2, 'pega o mais perto')
eq(DeepwebRules.Nearest(rigs, 5, 0, 0, 2.5), nil, 'nenhum no alcance')

-- Mineração
eq(DeepwebRules.Hash(config, 'server') > DeepwebRules.Hash(config, 'desktop'), true, 'servidor minera mais')
eq(DeepwebRules.Hash(config, 'laptop'), 0, 'notebook não minera')
eq(DeepwebRules.CanMine(config, { kind = 'desktop', mining = true, payout = 'nx1' }, true), true, 'pronto para minerar')
eq(select(2, DeepwebRules.CanMine(config, { kind = 'desktop', mining = false, payout = 'nx1' }, true)), 'off', 'desligado')
eq(select(2, DeepwebRules.CanMine(config, { kind = 'desktop', mining = true }, true)), 'no_payout', 'sem carteira')
eq(select(2, DeepwebRules.CanMine(config, { kind = 'server', mining = true, payout = 'nx1' }, false)), 'no_contract', 'contrato vencido')
eq(select(2, DeepwebRules.CanMine(config, { kind = 'laptop', mining = true, payout = 'nx1' }, true)), 'no_hash', 'notebook')

-- Bloqueio
local state
for _ = 1, 4 do
	state = DeepwebRules.Fail(5, 60, state, 10)
end
eq(DeepwebRules.Locked(state, 10), false, 'ainda livre')
state = DeepwebRules.Fail(5, 60, state, 10)
eq(DeepwebRules.Locked(state, 10), true, 'bloqueado')
eq(DeepwebRules.Locked(state, 70), false, 'liberado')

-- Contato NPC
local period = config.Dealer.RotationMinutes * 60
local spot, rotation = DeepwebRules.DealerRotation(config, 0)
eq(spot, 1, 'primeiro lugar no início')
eq(DeepwebRules.DealerRotation(config, period - 1), 1, 'mesmo lugar dentro do período')
eq(DeepwebRules.DealerRotation(config, period), 2, 'muda de lugar no período seguinte')
eq(DeepwebRules.DealerRotation(config, period * #config.Dealer.Spots), 1, 'volta ao primeiro lugar')
eq(select(2, DeepwebRules.DealerRotation(config, period * 3 + 5)), 3, 'número da rodada')
eq(DeepwebRules.PickPayment({ 'black_money', 'money' }, { black_money = 100, money = 5000 }, 2500), 'money', 'dinheiro sujo insuficiente: usa o limpo')
eq(DeepwebRules.PickPayment({ 'black_money', 'money' }, { black_money = 3000, money = 5000 }, 2500), 'black_money', 'prefere dinheiro sujo')
eq(DeepwebRules.PickPayment({ 'black_money', 'money' }, { money = 10 }, 2500), nil, 'sem dinheiro')

-- Endereços
local parsed = DeepwebRules.ParseAddress('  Rabbit.onion/r/Geral ')
eq(parsed.kind, 'site', 'endereço .onion')
eq(parsed.domain, 'rabbit.onion', 'domínio em minúsculas')
eq(parsed.path[2], 'geral', 'caminho')
eq(DeepwebRules.ParseAddress('duckdark.onion/?q=Pen Drive').query, 'Pen Drive', 'busca mantém o texto')
eq(DeepwebRules.ParseAddress('about:rede').href, 'about:rede', 'página interna')
eq(DeepwebRules.ParseAddress('onde comprar').kind, 'search', 'texto solto vira busca')
eq(DeepwebRules.ParseAddress(''), nil, 'vazio')

-- Domínios e comunidades
eq(DeepwebRules.Domain(config, 'Loja-Do-Ze'), 'loja-do-ze.onion', 'domínio normalizado')
eq(select(2, DeepwebRules.Domain(config, 'rabbit')), 'domain_reserved', 'domínio de sistema')
eq(select(2, DeepwebRules.Domain(config, 'po-li-cia')), 'domain_reserved', 'reservado disfarçado')
eq(DeepwebRules.Domain(config, '-ruim'), nil, 'hífen na ponta')
eq(DeepwebRules.Slug(config, 'r/Armas_BR'), 'armas_br', 'comunidade normalizada')
eq(DeepwebRules.Slug(config, 'ab'), nil, 'comunidade curta')

-- Texto
eq(DeepwebRules.Text('  oi\tmundo  ', 20), 'oi mundo', 'controle vira espaço')
eq(DeepwebRules.Text('a\n\n\n\nb', 20, true), 'a\n\nb', 'quebras repetidas reduzidas')
eq(DeepwebRules.Text('   ', 20), nil, 'só espaços')
eq(DeepwebRules.Text(string.rep('á', 21), 20), nil, 'conta caracteres, não bytes')

-- Votos, ordenação e árvore
eq(DeepwebRules.VoteValue('1'), 1, 'voto positivo')
eq(DeepwebRules.VoteValue(2), nil, 'voto inválido')
eq(DeepwebRules.VoteDelta(1, -1), -2, 'troca de voto')
eq(DeepwebRules.Hot(10, 0, 3600) > DeepwebRules.Hot(10, 0, 86400), true, 'post novo esquenta mais')
local tree = DeepwebRules.Thread({ { id = 1, score = 0 }, { id = 2, parentId = 1, score = 0 }, { id = 3, score = 5 }, { id = 4, parentId = 2, score = 0 } }, 1)
eq(tree[1].id, 3, 'raiz mais votada primeiro')
eq(tree[3].id, 2, 'filho logo depois do pai')
eq(tree[4].depth, 1, 'profundidade limitada')

-- Moeda e taxa
eq(DeepwebRules.ParseCoin('1,25', 4), 12500, 'vírgula decimal')
eq(DeepwebRules.ParseCoin('0.00001', 4), nil, 'casas demais')
eq(DeepwebRules.ParseCoin('-1', 4), nil, 'negativo')
eq(DeepwebRules.Fee(10000, 500), 500, 'taxa de 5%')

-- Anúncio
local listing = DeepwebRules.Listing(config, { title = 'Pen drive', category = 'tools', item = 'usb_black', count = 1, price = 100, stock = 2 })
eq(listing and listing.kind, 'item', 'anúncio de item')
eq(select(2, DeepwebRules.Listing(config, { title = 'Pen drive', category = 'x', item = 'usb_black', count = 1, price = 100, stock = 2 })), 'invalid_category', 'categoria inválida')
eq(DeepwebRules.Listing(config, { title = 'Rastreio', kind = 'service', category = 'services', price = 100, stock = 1 }).item, '', 'serviço sem item')

-- Pedidos
local order = { status = 'paid', kind = 'item', createdAt = 0 }
eq(DeepwebRules.OrderNext(config, order, 'deliver', 'seller', 0), 'dropped', 'vendedor entrega')
eq(select(2, DeepwebRules.OrderNext(config, order, 'deliver', 'buyer', 0)), 'not_seller', 'comprador não entrega')
eq(select(2, DeepwebRules.OrderNext(config, order, 'cancel', 'buyer', 10)), 'too_early', 'comprador espera o prazo')
eq(DeepwebRules.OrderNext(config, order, 'cancel', 'buyer', config.Market.DeliverHours * 3600), 'cancelled', 'cancela depois do prazo')
eq(DeepwebRules.OrderNext(config, { status = 'dropped', kind = 'item' }, 'collect', 'buyer', 0), 'completed', 'coleta conclui')
eq(select(2, DeepwebRules.OrderNext(config, { status = 'dropped', kind = 'item' }, 'dispute', 'buyer', 0)), 'invalid_status', 'item não se contesta')
eq(DeepwebRules.OrderNext(config, { status = 'dropped', kind = 'service' }, 'dispute', 'buyer', 0), 'disputed', 'serviço se contesta')
eq(select(2, DeepwebRules.OrderNext(config, { status = 'dropped', kind = 'service', deliveredAt = 0 }, 'release', 'system', 10)), 'invalid_status', 'não libera antes do prazo')
eq(DeepwebRules.OrderNext(config, { status = 'disputed', kind = 'service' }, 'resolve_seller', 'system', 0), 'released', 'staff paga o vendedor')
eq(DeepwebRules.Settlement('completed'), 'seller', 'concluído paga o vendedor')
eq(DeepwebRules.Settlement('refunded'), 'buyer', 'estorno devolve')
eq(DeepwebRules.Settlement('disputed'), nil, 'disputa segura')

-- Blocos
eq(#DeepwebRules.Blocks(config, { { type = 'heading', text = 'Oi' }, { type = 'divider' }, { type = 'link', label = 'Rabbit', href = 'rabbit.onion' } }), 3, 'blocos válidos')
eq(select(2, DeepwebRules.Blocks(config, { { type = 'link', label = 'x', href = 'texto solto' } })), 'invalid_block', 'link precisa ser endereço')
eq(select(3, DeepwebRules.Blocks(config, { { type = 'text', text = 'ok' }, { type = 'html', text = '<b>' } })), 2, 'índice do bloco ruim')

-- Busca
local term, pattern = DeepwebRules.SearchTerm('50%_off')
eq(term, '50%_off', 'termo')
eq(pattern, '%50\\%\\_off%', 'curingas escapados')

local sagaRollback = false
local sagaOk, sagaErr = DeepwebRules.ExecuteSaga({
	{ name = 'stock', forward = function() return true end, compensate = function() sagaRollback = true end },
	{ name = 'escrow', forward = function() return false, 'crypto_unavailable' end }
}, {})
eq(sagaOk, false, 'saga falha na custódia')
eq(sagaErr, 'crypto_unavailable', 'erro preservado')
eq(sagaRollback, true, 'estoque devolvido pela saga')

if failures > 0 then
	print(('%d falha(s)'):format(failures))
	os.exit(1)
end
print('deepweb_test: ok')
