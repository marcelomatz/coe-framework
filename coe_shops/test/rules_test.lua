-- Regras das lojas: catálogo, quem manda, preço, carrinho e prateleira.
dofile('config.lua')
dofile('shared/rules.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end
local config = ShopsConfig
local catalog, err = ShopsRules.Catalog(config)
eq(err, nil, 'config valido')
eq(#catalog.stores, #config.Stores, 'todas as lojas')
eq(catalog.byId.ltd_grove.type, 'ltd', 'loja por id')
eq(catalog.products.cigarettes.item, 'cigarettes_redwood', 'produto aponta para o item')

-- ids de negocio cabem no coe_businesses (24, [a-z0-9_])
for _, store in ipairs(catalog.stores) do
	eq(#store.id <= 24 and store.id:match('^[a-z0-9_]+$') ~= nil, true, store.id .. ' id valido')
end

-- config invalido
local bad = { Categories = config.Categories, Products = { x = { item = 'water', category = 'nada', price = 1 } }, Types = {}, Stores = {} }
eq(select(2, ShopsRules.Catalog(bad)), 'invalid_product:x', 'categoria desconhecida')
bad = { Categories = config.Categories, Products = config.Products, Types = { tt = { products = { 'nada' } } }, Stores = {} }
eq(select(2, ShopsRules.Catalog(bad)), 'invalid_type_product:tt:nada', 'tipo com produto inexistente')
bad = { Categories = config.Categories, Products = config.Products, Types = config.Types,
	Stores = { { id = 'a1', label = 'A', type = 'convenience', clerk = { 1, 2, 3, 0 } }, { id = 'a1', label = 'B', type = 'convenience', clerk = { 1, 2, 3, 0 } } } }
eq(select(2, ShopsRules.Catalog(bad)), 'invalid_store:2', 'id repetido')

-- quem manda
eq(ShopsRules.Mode(nil), 'staff', 'sem negocio e da staff')
eq(ShopsRules.Mode({ id = 'x' }), 'staff', 'sem dono e da staff')
eq(ShopsRules.Mode({ id = 'x', owner = { characterId = '7' } }), 'player', 'com dono e de jogador')

-- preco
local low, high = ShopsRules.PriceBounds(config, 10)
eq(low, 5, 'minimo metade')
eq(high, 30, 'maximo triplo')
eq(ShopsRules.ValidPrice(config, 10, 12), 12, 'preco valido')
eq(ShopsRules.ValidPrice(config, 10, 31), nil, 'acima do teto')
eq(ShopsRules.ValidPrice(config, 10, 4), nil, 'abaixo do piso')
eq(ShopsRules.ValidPrice(config, 10, 7.5), nil, 'precisa ser inteiro')
eq(ShopsRules.Price({ price = 10 }, 'staff', { price = 20 }), 10, 'staff usa tabela')
eq(ShopsRules.Price({ price = 10 }, 'player', { price = 20 }), 20, 'dono define')
eq(ShopsRules.Price({ price = 10 }, 'player', { quantity = 3 }), 10, 'sem preco proprio usa tabela')
eq(ShopsRules.Available('staff', nil), nil, 'staff infinito')
eq(ShopsRules.Available('player', nil), 0, 'prateleira vazia')

-- carrinho
local store = catalog.byId.shop_247_strawberry
local quote = ShopsRules.Quote(config, catalog, store, { { id = 'water', quantity = 2 }, { id = 'sandwich', quantity = 1 } }, { mode = 'staff' })
eq(quote.total, 2 * 4 + 12, 'total da staff')
eq(quote.units, 3, 'unidades')
eq(quote.lines[1].item, 'water', 'item da linha')
quote = ShopsRules.Quote(config, catalog, store, { water = 1, chips = 2 }, { mode = 'staff' })
eq(quote.total, 4 + 10, 'carrinho como mapa')
eq(select(2, ShopsRules.Quote(config, catalog, store, { { id = 'whiskey', quantity = 1 } }, { mode = 'staff' })), 'unknown_product', '24/7 nao vende uisque')
eq(select(2, ShopsRules.Quote(config, catalog, store, {}, { mode = 'staff' })), 'empty_cart', 'carrinho vazio')
eq(select(2, ShopsRules.Quote(config, catalog, store, { { id = 'water', quantity = 0 } }, { mode = 'staff' })), 'invalid_quantity', 'quantidade zero')
eq(select(2, ShopsRules.Quote(config, catalog, store, { { id = 'water', quantity = 30 }, { id = 'water', quantity = 30 } }, { mode = 'staff' })), 'invalid_quantity', 'soma acima do limite por linha')
local small = { Cart = { MaxLines = 20, MaxQuantity = 50, MaxTotal = 1000 } }
eq(select(2, ShopsRules.Quote(small, catalog, store, { { id = 'phone', quantity = 3 } }, { mode = 'staff' })), 'cart_too_expensive', 'total acima do limite')
local narrow = { Cart = { MaxLines = 1, MaxQuantity = 50, MaxTotal = 50000 } }
eq(select(2, ShopsRules.Quote(narrow, catalog, store, { { id = 'water', quantity = 1 }, { id = 'chips', quantity = 1 } }, { mode = 'staff' })), 'cart_too_big', 'linhas demais')
local shelves = { water = { quantity = 1, price = 7 }, sandwich = { quantity = 5 } }
local _, stockError, product = ShopsRules.Quote(config, catalog, store, { { id = 'water', quantity = 2 } }, { mode = 'player', shelves = shelves })
eq(stockError, 'out_of_stock', 'sem estoque na loja do jogador')
eq(product, 'water', 'produto sem estoque')
quote = ShopsRules.Quote(config, catalog, store, { { id = 'water', quantity = 1 }, { id = 'sandwich', quantity = 2 } }, { mode = 'player', shelves = shelves })
eq(quote.total, 7 + 24, 'preco do dono e de tabela')
local after = ShopsRules.AfterSale(shelves, quote.lines)
eq(after.water.quantity, 0, 'baixa no estoque')
eq(after.sandwich.quantity, 3, 'baixa no estoque 2')
eq(shelves.water.quantity, 1, 'nao altera a original')
eq(after.water.price, 7, 'mantem o preco')

-- prateleira
eq(ShopsRules.Restock(config, { quantity = 10 }, 5), 15, 'abastece')
eq(select(2, ShopsRules.Restock(config, { quantity = config.MaxStock }, 1)), 'stock_full', 'prateleira cheia')
eq(select(2, ShopsRules.Restock(config, nil, 0)), 'invalid_quantity', 'quantidade invalida')
eq(ShopsRules.Withdraw({ quantity = 10 }, 4), 6, 'retira')
eq(select(2, ShopsRules.Withdraw({ quantity = 2 }, 4)), 'not_enough_stock', 'nao tira mais do que tem')

-- negocio semeado
local seed = ShopsRules.BusinessSeed(catalog, catalog.byId.ltd_grove)
eq(seed.category, 'gas_station', 'LTD e posto')
eq(seed.owner, nil, 'sem dono: da staff')
eq(seed.stations.stashes[1].id, 'estoque', 'bau de estoque')
eq(ShopsRules.BusinessSeed(catalog, store).category, 'shop', '24/7 e lojinha')
eq(ShopsRules.Description(store, 1), '24/7 Strawberry (1 item)', 'descricao do extrato')

print('coe_shops rules tests passed')
