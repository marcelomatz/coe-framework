dofile('../coe_mechanic/config.lua')
dofile('../coe_mechanic/server/orders.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end

local clock, applied, charged, chargeResult = 0, {}, {}, true
local orders = MechanicOrders.New({
	config = CoeMechanicConfig,
	now = function() return clock end,
	quote = function(vehicleId, patch)
		if patch.bad then return nil, 'invalid_mod' end
		if patch.none then return { total = 0, lines = {} } end
		return { total = 1000, lines = { { kind = 'mod', key = '11', price = 1000 } } }
	end,
	apply = function(vehicleId, patch) applied[#applied + 1] = vehicleId; return true end,
	charge = function(source, amount) charged[#charged + 1] = amount; return chargeResult end
})

local customer = { source = 5, characterId = '9' }
local vehicle = { id = 'v1', plate = 'ABC123', model = 'adder' }

eq(select(2, orders.Create('bennys', customer, vehicle, { bad = true })), 'invalid_mod', 'patch inválido')
eq(select(2, orders.Create('bennys', customer, vehicle, { none = true })), 'nothing_to_change', 'sem mudança')
local order = orders.Create('bennys', customer, vehicle, { mods = { ['11'] = 3 } })
eq(order.status, 'requested', 'criado')
eq(order.total, 1000, 'total = estimativa')
eq(select(2, orders.Create('bennys', customer, vehicle, { mods = {} })), 'order_already_open', 'um pedido por veículo')
eq(#orders.ListForShop('bennys'), 1, 'lista da oficina')
eq(#orders.ListForShop('outra'), 0, 'outra oficina não vê')
eq(orders.GetForCustomer(5).id, order.id, 'cliente vê o seu')
eq(orders.GetForCustomer(6), nil, 'outro cliente não vê')

-- Cliente não aprova antes do orçamento; mecânico limitado à faixa.
eq(select(2, orders.Respond(order.id, 5, true)), 'invalid_status', 'aprovar sem orçamento')
eq(select(2, orders.Price(order.id, 'bennys', 5000)), 'total_out_of_range', 'acima da faixa')
eq(select(2, orders.Price(order.id, 'bennys', 100)), 'total_out_of_range', 'abaixo da faixa')
eq(select(2, orders.Price(order.id, 'bennys', 1.5)), 'invalid_total', 'fração')
eq(select(2, orders.Price(order.id, 'outra', 1000)), 'order_not_found', 'outra oficina não precifica')
local quoted = orders.Price(order.id, 'bennys', 1200, 'Mão de obra inclusa')
eq(quoted.status, 'quoted', 'orçado')
eq(quoted.total, 1200, 'total do mecânico')

-- Só o cliente dono aprova; mecânico não conclui antes da aprovação.
eq(select(2, orders.Respond(order.id, 6, true)), 'order_not_found', 'outro jogador não aprova')
eq(select(2, orders.Complete(order.id, 'bennys')), 'invalid_status', 'concluir sem aprovação')
eq(orders.Respond(order.id, 5, true).status, 'approved', 'aprovado')

-- Cobrança que falha mantém o pedido aprovado.
chargeResult = 'insufficient_funds'
eq(select(2, orders.Complete(order.id, 'bennys')), 'payment_failed', 'pagamento falhou')
eq(#applied, 0, 'nada aplicado sem pagar')
chargeResult = true
eq(orders.Complete(order.id, 'bennys').status, 'done', 'concluído')
eq(charged[#charged], 1200, 'cobrou o valor final')
eq(applied[1], 'v1', 'aplicou')
eq(orders.GetForCustomer(5), nil, 'pedido fechado')

-- Recusa, cancelamento, expiração e saída do jogador.
local second = orders.Create('bennys', customer, vehicle, { mods = {} })
orders.Price(second.id, 'bennys', 1000)
eq(orders.Respond(second.id, 5, false).status, 'declined', 'recusado')
local third = orders.Create('bennys', customer, vehicle, { mods = {} })
eq(orders.Cancel(third.id, 5).status, 'cancelled', 'cancelado')
local fourth = orders.Create('bennys', customer, vehicle, { mods = {} })
clock = clock + CoeMechanicConfig.Orders.TtlMs + 1
eq(select(2, orders.Price(fourth.id, 'bennys', 1000)), 'invalid_status', 'expirado')
orders.Purge()
local fifth = orders.Create('bennys', customer, vehicle, { mods = {} })
orders.Drop(5)
eq(orders.GetForCustomer(5), nil, 'saída cancela pedidos')
eq(fifth ~= nil, true, 'criado de novo após expirar')

print('orders_test: todos os testes passaram')
