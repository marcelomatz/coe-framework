dofile([=[coe_database/test/integration/bridge.lua]=])
local assertEqual = Bridge.AssertEqual
Bridge.InstallFiveMStubs()

dofile([=[coe_core/lib/migrations.lua]=])
dofile([=[coe_core/lib/logger.lua]=])
dofile([=[coe_economy/server/migrations.lua]=])
dofile([=[coe_economy/server/persistence.lua]=])
dofile([=[coe_banking/server/migrations.lua]=])
dofile([=[coe_banking/server/persistence.lua]=])
dofile([=[coe_shops/server/migrations.lua]=])
dofile([=[coe_shops/server/persistence.lua]=])

Inventory = {}
dofile([=[coe_inventory/adapters/migrations.lua]=])
dofile([=[coe_inventory/adapters/persistence.lua]=])

-- 1. Migrações idempotentes dos quatro recursos integrados
for attempt = 1, 2 do
	local ok, err = EconomyPersistence.Initialize()
	assertEqual(ok, true, 'economy initialize ' .. attempt .. ' ' .. tostring(err))
	ok, err = BankingPersistence.Initialize()
	assertEqual(ok, true, 'banking initialize ' .. attempt .. ' ' .. tostring(err))
	ok, err = ShopsPersistence.Initialize()
	assertEqual(ok, true, 'shops initialize ' .. attempt .. ' ' .. tostring(err))
	ok, err = Inventory.Persistence.Initialize()
	assertEqual(ok, true, 'inventory initialize ' .. attempt .. ' ' .. tostring(err))
end

local economyVersions = Bridge.Query('SELECT version, name FROM coe_economy_schema_migrations')
assertEqual(#economyVersions.result, 2, 'economy migrations count')
local bankingVersions = Bridge.Query('SELECT version, name FROM coe_banking_schema_migrations')
assertEqual(#bankingVersions.result, 6, 'banking migrations count')
local shopsVersions = Bridge.Query('SELECT version, name FROM coe_shops_schema_migrations')
assertEqual(#shopsVersions.result, 1, 'shops migrations count')
local inventoryVersions = Bridge.Query('SELECT version, name FROM coe_inventory_schema_migrations')
assertEqual(#inventoryVersions.result, 1, 'inventory migrations count')

-- 2. Setup de conta do comprador (saldo inicial de $2.000)
assertEqual(EconomyPersistence.EnsureAccount('50', 2000, 'coe_economy'), true, 'buyer account created')
assertEqual(EconomyPersistence.Balance('50'), 2000, 'initial buyer balance is $2000')

-- 3. Setup de empresa/loja e abastecimento de prateleira
assertEqual(EconomyPersistence.EnsureSociety('ltd_vinewood'), true, 'shop society created')
assertEqual(EconomyPersistence.SocietyBalance('ltd_vinewood'), 0, 'initial shop treasury is $0')

-- A loja cadastra estoque: 5 telefones a $500 cada
assert(ShopsPersistence.SaveShelf('ltd_vinewood', 'phone', { quantity = 5, price = 500 }), 'shelf item added')
local shelves = ShopsPersistence.Shelves()
assertEqual(shelves.ltd_vinewood ~= nil, true, 'ltd_vinewood shelf exists')
assertEqual(shelves.ltd_vinewood.phone.quantity, 5, '5 phones on shelf')
assertEqual(shelves.ltd_vinewood.phone.price, 500, 'phone price is $500')

-- 4. Fluxo de Compra: Comprador adquire 2 telefones ($1.000)
-- 4.1 Transação atômica de pagamento: debita comprador e credita sociedade
local paymentOk = EconomyPersistence.SocietyDeposit('ltd_vinewood', '50', 1000, 'shop_purchase', 'order:101', 'coe_shops')
assertEqual(paymentOk, true, 'payment transfer succeeds')
assertEqual(EconomyPersistence.Balance('50'), 1000, 'buyer balance reduced to $1000')
assertEqual(EconomyPersistence.SocietyBalance('ltd_vinewood'), 1000, 'shop treasury credited to $1000')

-- 4.2 Prateleira atualizada: 5 - 2 = 3 telefones restantes
assert(ShopsPersistence.SaveShelf('ltd_vinewood', 'phone', { quantity = 3, price = 500 }), 'shelf quantity updated')
shelves = ShopsPersistence.Shelves()
assertEqual(shelves.ltd_vinewood.phone.quantity, 3, '3 phones remain on shelf')

-- 4.3 Venda registrada na contabilidade da loja
assert(ShopsPersistence.RecordSale({
	businessId = 'ltd_vinewood',
	characterId = 50,
	mode = 'player',
	method = 'card',
	total = 1000,
	units = 2,
	lines = '{"items":[{"name":"phone","qty":2}]}',
	at = 1000
}), 'sale recorded in shop report')

local report = ShopsPersistence.Report('ltd_vinewood', 10, 0, 0)
assertEqual(report.today, 1000, 'shop report today total is $1000')
assertEqual(#report.sales, 1, '1 sale listed')
assertEqual(report.sales[1].units, 2, '2 units sold')

-- 4.4 Entrega física no inventário do comprador
assertEqual(Inventory.Persistence.Set('character:50', '{"items":[{"slot":1,"name":"phone","count":2,"metadata":{"serial":"PH1001"}}]}'), true, 'inventory saved')
local inv = Inventory.Persistence.Get('character:50')
assertEqual(inv:find('PH1001') ~= nil, true, 'purchased phone serial in player inventory')

-- 5. Proteção de Saldo Insuficiente (Comprador tenta comprar mais $1500 tendo apenas $1000)
local debitFail = EconomyPersistence.SocietyDeposit('ltd_vinewood', '50', 1500, 'shop_purchase', 'order:102', 'coe_shops')
assertEqual(debitFail, nil, 'insufficient funds transaction rejected')
assertEqual(EconomyPersistence.Balance('50'), 1000, 'buyer balance unchanged after failed purchase')
assertEqual(EconomyPersistence.SocietyBalance('ltd_vinewood'), 1000, 'shop treasury unchanged after failed purchase')

-- 6. Cartão Bancário Corporativo / PJ (coe_banking)
local cardId = BankingPersistence.InsertCard({
	accountType = 'business',
	accountRef = 'ltd_vinewood',
	holderId = '77',
	holderName = 'Gerente Joao',
	serial = '4000123456789010',
	pinHash = 'pin_hash_demo',
	pinSalt = 'salt_demo',
	kind = 'physical',
	dailyLimit = 2500
})
assertEqual(type(cardId), 'number', 'business card issued for shop')
local card = BankingPersistence.Card(cardId)
assertEqual(card.accountRef, 'ltd_vinewood', 'card account ref is the business')
assertEqual(card.holderId, '77', 'card holder is employee 77')
assertEqual(card.dailyLimit, 2500, 'card daily limit is $2500')

local businessCards = BankingPersistence.AccountCards('business', 'ltd_vinewood')
assertEqual(#businessCards, 1, '1 card registered to business account')

-- 7. Distribuição de Lucros / Pró-labore para o Dono da Loja
assertEqual(EconomyPersistence.EnsureAccount('88', 0, 'coe_economy'), true, 'owner account created')
assertEqual(EconomyPersistence.SocietyPay('ltd_vinewood', '88', 800, 'dividend', 'div:01', 'coe_banking'), true, 'dividend payout to owner')
assertEqual(EconomyPersistence.SocietyBalance('ltd_vinewood'), 200, 'shop treasury has $200 remaining')
assertEqual(EconomyPersistence.Balance('88'), 800, 'owner received $800 dividend')

-- 8. Auditoria de Livro-Razão (Ledger)
local buyerLedger = Bridge.Query('SELECT delta, reason FROM coe_economy_ledger WHERE character_id = 50 ORDER BY id')
assertEqual(#buyerLedger.result, 2, 'buyer has 2 ledger entries')
assertEqual(buyerLedger.result[1].delta, 2000, 'starting balance ledger')
assertEqual(buyerLedger.result[2].delta, -1000, 'shop purchase deduction ledger')

local societyLedger = Bridge.Query('SELECT delta, reason FROM coe_economy_society_ledger WHERE business_id = ? ORDER BY id', { 'ltd_vinewood' })
assertEqual(#societyLedger.result, 2, 'society has 2 ledger entries')
assertEqual(societyLedger.result[1].delta, 1000, 'shop purchase revenue ledger')
assertEqual(societyLedger.result[2].delta, -800, 'dividend payout deduction ledger')

Bridge.Done()
