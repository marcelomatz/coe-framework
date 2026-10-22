-- Servidor das lojas com natives e exports simulados: loja da staff, loja de jogador, três meios de pagamento,
-- estorno quando o item não cabe, gestão (preço, abastecer, retirar, relatório) e permissões.
local handlers, netHandlers, exported, responses, notices, audits = {}, {}, {}, {}, {}, {}
local now = 1000
local clock = 1792000000
os.time = function() return clock end
source = nil

function GetGameTimer() now = now + 1000; return now end
function GetResourceState() return 'started' end
function GetCurrentResourceName() return 'coe_shops' end
function CreateThread(fn) fn() end
function Wait() end
function RegisterNetEvent(name, fn) netHandlers[name] = fn end
function AddEventHandler(name, fn) handlers[name] = fn end
function TriggerClientEvent(name, target, a, b) if name == 'coe_shops:response' then responses[#responses + 1] = { target = target, id = a, result = b } end end
local aces = {}
local invoking = nil
function GetInvokingResource() return invoking end
-- Meios de pagamento de pacotes simulados: só recursos com a ACE coe.shops.payments registram.
function IsPrincipalAceAllowed(principal, ace)
	return ace == 'coe.shops.payments' and (principal == 'resource.pack_card' or principal == 'resource.pack_wallet')
end
function IsPlayerAceAllowed(id, ace) return aces[id] == true end
local positions = {}
function GetPlayerPed(id) return id end
function GetEntityCoords(id) local p = positions[id] or { x = 0, y = 0, z = 0 }; return p end

local characters = { [1] = 11, [2] = 22, [3] = 33 }
Core = { Players = { GetActiveCharacter = function(id) return characters[id] and { characterId = characters[id] } end } }

-- Negócios: as lojas começam sem dono; o teste dá dono a uma delas.
local businesses, seeds, permissions, tabs = {}, {}, nil, {}
local accessOf = {}
local can = {}
-- Inventários e banco
local inventories = { inv1 = { money = 100 }, inv2 = { money = 0, water = 10 }, inv3 = { money = 1000 } }
local fullInventory = {}
local purchases, refunds, collected = {}, {}, {}
local pins = { [501] = '1234' }

exports = setmetatable({}, {
	__call = function(_, name, fn) exported[name] = fn end,
	__index = function(_, resource)
		if resource == 'coe_businesses' then
			return {
				IsReady = function() return true end,
				RegisterPermissions = function(_, list) permissions = list; return true end,
				RegisterTab = function(_, def) tabs[#tabs + 1] = def; return true end,
				Seed = function(_, raw) seeds[#seeds + 1] = raw; businesses[raw.id] = businesses[raw.id] or raw; return businesses[raw.id] end,
				Get = function(_, id) return businesses[id] end,
				Access = function(_, id, characterId) return accessOf[id .. ':' .. characterId] or { owner = false, canWork = false } end,
				Can = function(_, id, characterId, permission) return can[id .. ':' .. characterId .. ':' .. permission] == true end
			}
		end
		if resource == 'coe_inventory' then
			return {
				GetPlayerInventory = function(_, id) return 'inv' .. id end,
				GetItemCount = function(_, inv, item) return inventories[inv][item] or 0 end,
				RemoveItemByName = function(_, inv, item, count)
					if (inventories[inv][item] or 0) < count then return false end
					inventories[inv][item] = inventories[inv][item] - count; return true
				end,
				AddItem = function(_, inv, item, count)
					if fullInventory[inv] and item ~= 'money' then return false end
					inventories[inv][item] = (inventories[inv][item] or 0) + count; return true
				end,
				Items = function(_, item) return { label = 'Item ' .. item, image = item .. '.png' } end
			}
		end
		if resource == 'pack_card' then
			return {
				ShopOptions = function(_, id) return { detail = 'Cartão com você', options = id == 3 and { { id = 501, label = '•••• 4321' } } or {} } end,
				ShopCharge = function(_, id, payment, amount, description)
					if pins[payment.option] ~= payment.pin then return { ok = false, error = 'wrong_pin', left = 2 } end
					purchases[#purchases + 1] = { cardId = payment.option, amount = amount, description = description }; return { ok = true, ref = payment.option }
				end,
				ShopRefund = function(_, id, ref, amount) refunds[#refunds + 1] = { cardId = ref, amount = amount }; return { ok = true } end
			}
		end
		if resource == 'pack_wallet' then
			return {
				ShopCharge = function(_, id, payment, amount, description)
					if payment.token ~= 'tok' then return { ok = false, error = 'payment_expired' } end
					purchases[#purchases + 1] = { cardId = 777, amount = amount, description = description }; return { ok = true, ref = 777 }
				end,
				ShopRefund = function(_, id, ref, amount) refunds[#refunds + 1] = { cardId = ref, amount = amount }; return { ok = true } end
			}
		end
		if resource == 'coe_economy' then
			return {
				SocietyCollect = function(_, id, amount, reason) collected[#collected + 1] = { id = id, amount = amount, reason = reason }; return { ok = true } end,
				SocietyBalance = function() return 1234 end
			}
		end
		if resource == 'coe_notify' then
			return { Notify = function(_, id, kind, message) notices[#notices + 1] = { id = id, message = message } end }
		end
		if resource == 'coe_audit' then
			return { Record = function(_, _, _, event, ctx) audits[#audits + 1] = { event = event, ctx = ctx } end }
		end
		return setmetatable({}, { __index = function() return function() return true end end })
	end
})

local shelvesDb, sales = {}, {}
ShopsPersistence = {
	Initialize = function() return true end,
	Shelves = function() return {} end,
	SaveShelf = function(b, p, shelf) shelvesDb[b .. ':' .. p] = { quantity = shelf.quantity, price = shelf.price }; return true end,
	RecordSale = function(sale) sales[#sales + 1] = sale; return true end,
	Report = function(b) local list = {} for _, s in ipairs(sales) do if s.businessId == b then list[#list + 1] = s end end return { sales = list, today = 0, week = 0, weekSales = #list } end
}

dofile('../coe_core/lib/access.lua')
dofile('config.lua')
dofile('shared/rules.lua')
dofile('server/payments.lua')
dofile('server/main.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end
local requestId = 0
local function call(playerId, action, payload)
	requestId = requestId + 1
	source = playerId
	now = now + 1000
	netHandlers['coe_shops:request'](requestId, action, payload)
	local last = responses[#responses]
	eq(last.id, requestId, 'resposta do pedido')
	return last.result
end

eq(exported.IsReady(), true, 'pronto')
eq(#seeds, #ShopsConfig.Stores, 'negocios semeados')
eq(seeds[1].owner, nil, 'semeado sem dono')
eq(permissions[1].name, 'shops.prices', 'permissao de preco registrada')
eq(tabs[1].id, 'shop', 'aba Loja registrada no app do negocio')
eq(tabs[1].visible, 'IsStore', 'aba so nas lojas')

-- meios de pagamento registrados por pacotes (ACE coe.shops.payments)
invoking = 'intruso'
eq(exported.RegisterPaymentMethod({ id = 'pix', label = 'Pix', kind = 'instant', charge = 'C', refund = 'R' }).error, 'forbidden', 'sem ACE nao registra')
invoking = 'pack_card'
eq(exported.RegisterPaymentMethod({ id = 'card', label = 'Cartão na maquininha', kind = 'pin', options = 'ShopOptions', charge = 'ShopCharge', refund = 'ShopRefund', order = 30 }), true, 'cartao registrado')
eq(exported.RegisterPaymentMethod({ id = 'cash', label = 'X', kind = 'instant', charge = 'C', refund = 'R' }).error, 'invalid_method', 'especie e da loja')
invoking = 'pack_wallet'
eq(exported.RegisterPaymentMethod({ id = 'card', label = 'Outro', kind = 'instant', charge = 'C', refund = 'R' }).error, 'method_taken', 'id de outro resource')
eq(exported.RegisterPaymentMethod({ id = 'wallet', label = 'Carteira', kind = 'device', charge = 'ShopCharge', refund = 'ShopRefund' }).error, 'invalid_method', 'device exige export client')
eq(exported.RegisterPaymentMethod({ id = 'wallet', label = 'Carteira do celular', kind = 'device', client = 'RequestPayment', charge = 'ShopCharge', refund = 'ShopRefund', order = 20 }), true, 'carteira registrada')
invoking = nil

local function methodIn(view, id)
	for _, m in ipairs(view.payments) do if m.id == id then return m end end
end

local store = ShopsConfig.Stores[1]
local clerk = { x = store.clerk[1], y = store.clerk[2], z = store.clerk[3] }
local function atCounter(id) positions[id] = { x = clerk.x + 1, y = clerk.y, z = clerk.z } end

-- lista e distancia
eq(#call(1, 'stores').stores, #ShopsConfig.Stores, 'lista de lojas')
positions[1] = { x = clerk.x + 20, y = clerk.y, z = clerk.z }
eq(call(1, 'open', { storeId = store.id }).error, 'too_far', 'longe do balcao')
atCounter(1)
local opened = call(1, 'open', { storeId = store.id })
eq(opened.ok, true, 'abre a loja')
eq(opened.view.mode, 'staff', 'loja da staff')
eq(opened.view.products[1].stock, nil, 'estoque infinito')
eq(opened.view.products[1].label, 'Item water', 'nome do item')
eq(opened.view.cash, 100, 'dinheiro do jogador')
eq(opened.view.access.report, false, 'sem gestao para cliente')
eq(call(1, 'open', { storeId = 'nada' }).error, 'unknown_store', 'loja desconhecida')

-- dinheiro
local result = call(1, 'buy', { storeId = store.id, cart = { { id = 'water', quantity = 2 }, { id = 'sandwich', quantity = 1 } }, payment = { method = 'cash' } })
eq(result.ok, true, 'compra em especie')
eq(result.total, 20, 'total')
eq(inventories.inv1.money, 80, 'dinheiro descontado')
eq(inventories.inv1.water, 2, 'agua entregue')
eq(collected[1].id, store.id, 'receita no caixa do negocio')
eq(collected[1].amount, 20, 'valor da receita')
eq(collected[1].reason, 'shop_sale', 'motivo')
eq(sales[1].method, 'cash', 'venda registrada')
eq(sales[1].lines, 'water:2:4,sandwich:1:12', 'itens da venda')
eq(audits[#audits].event, 'shop_sale', 'auditoria')
eq(call(1, 'buy', { storeId = store.id, cart = { { id = 'phone', quantity = 1 } }, payment = { method = 'cash' } }).error, 'insufficient_cash', 'sem dinheiro')
eq(call(1, 'buy', { storeId = store.id, cart = { { id = 'water', quantity = 1 } }, payment = { method = 'pix' } }).error, 'invalid_method', 'meio invalido')

-- carteira do celular
eq(call(1, 'quote', { storeId = store.id, cart = { { id = 'coffee', quantity = 2 } } }).total, 10, 'orcamento para a Carteira')
eq(call(1, 'buy', { storeId = store.id, cart = { { id = 'coffee', quantity = 2 } }, payment = { method = 'wallet', token = 'velho' } }).error, 'payment_expired', 'token invalido')
result = call(1, 'buy', { storeId = store.id, cart = { { id = 'coffee', quantity = 2 } }, payment = { method = 'wallet', token = 'tok' } })
eq(result.ok, true, 'compra pela Carteira')
eq(purchases[#purchases].cardId, 777, 'cartao autorizado no celular')
eq(purchases[#purchases].amount, 10, 'valor no credito')

-- maquininha
atCounter(3)
local view3 = call(3, 'open', { storeId = store.id }).view
eq(methodIn(view3, 'card').options[1].label, '•••• 4321', 'cartoes em maos')
eq(methodIn(view3, 'card').available, true, 'cartao disponivel')
eq(view3.payments[1].id, 'cash', 'especie primeiro')
eq(view3.payments[2].id, 'wallet', 'ordem dos meios')
eq(methodIn(view3, 'wallet').resource, 'pack_wallet', 'client sabe quem abre o aparelho')
eq(methodIn(call(1, 'open', { storeId = store.id }).view, 'card').available, false, 'sem cartao em maos')
result = call(3, 'buy', { storeId = store.id, cart = { { id = 'chips', quantity = 1 } }, payment = { method = 'card', option = 501, pin = '0000' } })
eq(result.error, 'wrong_pin', 'senha errada')
eq(result.left, 2, 'tentativas restantes')
fullInventory.inv3 = true
result = call(3, 'buy', { storeId = store.id, cart = { { id = 'chips', quantity = 1 } }, payment = { method = 'card', option = 501, pin = '1234' } })
eq(result.error, 'inventory_full', 'sem espaco')
eq(refunds[#refunds].amount, 5, 'estorno no cartao')
fullInventory.inv3 = nil
result = call(3, 'buy', { storeId = store.id, cart = { { id = 'chips', quantity = 1 } }, payment = { method = 'card', option = 501, pin = '1234' } })
eq(result.ok, true, 'compra na maquininha')

-- gestao da loja da staff: so relatorio para quem tem a ACE
eq(call(1, 'manage', { storeId = store.id, op = 'report' }).error, 'forbidden', 'cliente nao ve vendas')
aces[1] = true
local report = call(1, 'manage', { storeId = store.id, op = 'report' }).report
eq(#report.sales, 3, 'staff ve as vendas')
local labels = {}
for _, sale in ipairs(report.sales) do labels[sale.method] = sale.methodLabel end
eq(labels.wallet, 'Carteira do celular', 'rotulo do meio registrado no relatorio')
eq(labels.cash, 'Dinheiro', 'rotulo da especie')
eq(call(1, 'manage', { storeId = store.id, op = 'restock', args = { productId = 'water', quantity = 1 } }).error, 'staff_store', 'staff nao abastece')

-- passa para um jogador: prateleira vazia, dono define preco e a equipe abastece
businesses[store.id].owner = { characterId = '22', name = 'Bruno' }
accessOf[store.id .. ':22'] = { owner = true, canWork = true }
atCounter(2)
local view = call(2, 'open', { storeId = store.id }).view
eq(view.mode, 'player', 'loja de jogador')
eq(view.products[1].stock, 0, 'prateleira vazia')
eq(view.access.prices, true, 'dono define preco')
eq(call(1, 'buy', { storeId = store.id, cart = { { id = 'water', quantity = 1 } }, payment = { method = 'cash' } }).error, 'out_of_stock', 'sem estoque')
result = call(2, 'manage', { storeId = store.id, op = 'restock', args = { productId = 'water', quantity = 4 } })
eq(result.ok, true, 'abastece com o inventario')
eq(inventories.inv2.water, 6, 'itens saem do inventario')
eq(shelvesDb[store.id .. ':water'].quantity, 4, 'prateleira gravada')
eq(call(2, 'manage', { storeId = store.id, op = 'restock', args = { productId = 'water', quantity = 50 } }).error, 'missing_items', 'nao tem os itens')
eq(call(2, 'manage', { storeId = store.id, op = 'price', args = { productId = 'water', price = 100 } }).error, 'invalid_price', 'preco fora da faixa')
eq(call(2, 'manage', { storeId = store.id, op = 'price', args = { productId = 'water', price = 7 } }).ok, true, 'preco do dono')
eq(call(2, 'manage', { storeId = store.id, op = 'restock', args = { productId = 'whiskey', quantity = 1 } }).error, 'unknown_product', 'produto que a loja nao vende')
result = call(1, 'buy', { storeId = store.id, cart = { { id = 'water', quantity = 3 } }, payment = { method = 'cash' } })
eq(result.ok, true, 'compra na loja do jogador')
eq(result.total, 21, 'preco do dono')
eq(shelvesDb[store.id .. ':water'].quantity, 1, 'baixa na prateleira')
eq(collected[#collected].amount, 21, 'receita no caixa do dono')
eq(call(1, 'buy', { storeId = store.id, cart = { { id = 'water', quantity = 2 } }, payment = { method = 'cash' } }).error, 'out_of_stock', 'acabou')

-- funcionario de ponto abastece, mas so retira com permissao
accessOf[store.id .. ':11'] = { owner = false, canWork = true }
aces[1] = nil
eq(call(1, 'manage', { storeId = store.id, op = 'withdraw', args = { productId = 'water', quantity = 1 } }).error, 'forbidden', 'equipe sem permissao nao retira')
eq(call(1, 'manage', { storeId = store.id, op = 'price', args = { productId = 'water', price = 8 } }).error, 'forbidden', 'equipe sem permissao nao muda preco')
eq(call(1, 'manage', { storeId = store.id, op = 'restock', args = { productId = 'water', quantity = 1 } }).ok, true, 'equipe de ponto abastece')
can[store.id .. ':11:shops.stock'] = true
eq(call(1, 'manage', { storeId = store.id, op = 'withdraw', args = { productId = 'water', quantity = 2 } }).ok, true, 'com permissao retira')
eq(inventories.inv1.water, 6, 'volta para o inventario')
eq(call(2, 'manage', { storeId = store.id, op = 'report' }).report.balance, 1234, 'dono ve o caixa')

-- aba Loja do tablet (coe_businesses): resumo, preco a distancia; so o coe_businesses chama
local invoker = 'coe_admin'
function GetInvokingResource() return invoker end
eq(exported.IsStore(store.id), true, 'e loja')
eq(exported.IsStore('oficina'), false, 'nao e loja')
eq(exported.BusinessTablet(2, '22', store.id, { op = 'overview' }).error, 'forbidden', 'so o coe_businesses')
invoker = 'coe_businesses'
positions[2] = { x = clerk.x + 500, y = clerk.y, z = clerk.z }
local tab = exported.BusinessTablet(2, '22', store.id, { op = 'overview' })
eq(tab.mode, 'player', 'loja de jogador no tablet')
eq(tab.access.prices, true, 'dono muda preco a distancia')
eq(tab.report.balance, 1234, 'vendas e caixa no tablet')
local water
for _, product in ipairs(tab.products) do if product.id == 'water' then water = product end end
eq(water.custom, true, 'preco proprio marcado')
eq(water.stock, 0, 'estoque da prateleira')
tab = exported.BusinessTablet(2, '22', store.id, { op = 'price', productId = 'water', price = 5 })
eq(tab.ok, true, 'preco pelo tablet')
eq(shelvesDb[store.id .. ':water'].price, 5, 'preco gravado')
eq(exported.BusinessTablet(2, '22', store.id, { op = 'price', productId = 'water', price = 1000 }).error, 'invalid_price', 'faixa vale no tablet')
eq(exported.BusinessTablet(2, '22', store.id, { op = 'price', productId = 'water', price = false }).ok, true, 'volta ao preco de tabela')
eq(shelvesDb[store.id .. ':water'].price, nil, 'sem preco proprio')
eq(exported.BusinessTablet(1, '11', store.id, { op = 'price', productId = 'water', price = 6 }).error, 'forbidden', 'equipe sem shops.prices')
eq(exported.BusinessTablet(2, '22', store.id, { op = 'restock' }).error, 'unknown_action', 'abastecer so no balcao')
eq(exported.BusinessTablet(2, '22', 'oficina', {}).error, 'not_a_store', 'negocio que nao e loja')
local staffStore = ShopsConfig.Stores[2]
tab = exported.BusinessTablet(1, '11', staffStore.id, {})
eq(tab.mode, 'staff', 'loja da staff no tablet')
eq(tab.access.prices, false, 'staff nao tem preco proprio')
eq(tab.products[1].stock, nil, 'estoque infinito')
atCounter(2)

-- loja fechada
businesses[store.id].enabled = false
eq(call(2, 'open', { storeId = store.id }).error, 'store_closed', 'negocio desativado')

print('coe_shops server tests passed')
