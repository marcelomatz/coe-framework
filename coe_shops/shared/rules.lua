-- Regras puras das lojas (sem natives): validação do catálogo e das lojas, quem manda na loja, preço, orçamento do
-- carrinho e estoque. Testáveis fora do jogo (test/rules_test.lua).
ShopsRules = {}

local function isId(value, max)
	return type(value) == 'string' and #value >= 2 and #value <= (max or 24) and value:match('^[a-z][a-z0-9_]*$') ~= nil
end

local function int(value, min, max)
	local n = tonumber(value)
	if not n or n ~= n or math.floor(n) ~= n or n < min or n > max then
		return nil
	end
	return math.tointeger(n)
end

local function num(value)
	local n = tonumber(value)
	return n and n == n and n ~= math.huge and n ~= -math.huge and n or nil
end

-- Valida o config (produtos, tipos e lojas). Devolve { products, types, stores (lista), byId } ou nil + erro.
function ShopsRules.Catalog(config)
	local categories = {}
	for _, category in ipairs(config.Categories or {}) do
		if not isId(category.id) then
			return nil, 'invalid_category'
		end
		categories[category.id] = category.label
	end
	local products = {}
	for id, product in pairs(config.Products or {}) do
		if not isId(id) or type(product) ~= 'table' or type(product.item) ~= 'string' or not categories[product.category]
			or not int(product.price, 1, 1000000) then
			return nil, 'invalid_product:' .. tostring(id)
		end
		products[id] = { id = id, item = product.item, category = product.category, price = product.price }
	end
	local types = {}
	for id, kind in pairs(config.Types or {}) do
		if not isId(id) or type(kind) ~= 'table' or type(kind.products) ~= 'table' or #kind.products == 0 then
			return nil, 'invalid_type:' .. tostring(id)
		end
		for _, productId in ipairs(kind.products) do
			if not products[productId] then
				return nil, 'invalid_type_product:' .. id .. ':' .. tostring(productId)
			end
		end
		types[id] = kind
	end
	local stores, byId = {}, {}
	for index, store in ipairs(config.Stores or {}) do
		local clerk = type(store) == 'table' and store.clerk
		local x, y, z, h = clerk and num(clerk[1]), clerk and num(clerk[2]), clerk and num(clerk[3]), clerk and num(clerk[4] or 0)
		if not isId(store and store.id) or byId[store.id] or not types[store.type] or type(store.label) ~= 'string'
			or not x or not y or not z or not h then
			return nil, 'invalid_store:' .. tostring(index)
		end
		local entry = { id = store.id, label = store.label, type = store.type, clerk = { x = x, y = y, z = z, h = h } }
		stores[#stores + 1] = entry
		byId[store.id] = entry
	end
	return { products = products, types = types, stores = stores, byId = byId, categories = categories }
end

-- Quem manda: `staff` (negócio sem dono: estoque infinito, preço de tabela) ou `player` (estoque e preço do dono).
function ShopsRules.Mode(business)
	return type(business) == 'table' and business.owner and business.owner.characterId and 'player' or 'staff'
end

-- Preço válido para o dono definir (inteiro dentro da faixa em relação ao de tabela).
function ShopsRules.PriceBounds(config, base)
	return math.max(1, math.floor(base * config.PriceBand.Min + 0.5)), math.floor(base * config.PriceBand.Max + 0.5)
end

function ShopsRules.ValidPrice(config, base, price)
	local value = int(price, 1, 100000000)
	if not value then
		return nil
	end
	local low, high = ShopsRules.PriceBounds(config, base)
	return value >= low and value <= high and value or nil
end

-- Preço de venda: na loja da staff o de tabela; na do jogador o que ele definiu (ou o de tabela).
function ShopsRules.Price(product, mode, shelf)
	if mode == 'player' and shelf and shelf.price then
		return shelf.price
	end
	return product.price
end

-- Disponível na prateleira: nil = infinito (staff).
function ShopsRules.Available(mode, shelf)
	if mode == 'staff' then
		return nil
	end
	return shelf and shelf.quantity or 0
end

-- Orçamento do carrinho ({ [produto] = quantidade } ou lista { { id, quantity } }) numa loja.
-- ctx: { mode, shelves = { [produto] = { quantity, price } } }. Devolve { lines, total, units } ou nil + erro.
function ShopsRules.Quote(config, catalog, store, cart, ctx)
	if type(cart) ~= 'table' then
		return nil, 'invalid_cart'
	end
	local kind = catalog.types[store.type]
	local sells = {}
	for _, productId in ipairs(kind.products) do
		sells[productId] = true
	end
	local wanted, count = {}, 0
	local function add(productId, quantity)
		if type(productId) ~= 'string' or not sells[productId] then
			return 'unknown_product'
		end
		local amount = int(quantity, 1, config.Cart.MaxQuantity)
		if not amount then
			return 'invalid_quantity'
		end
		if not wanted[productId] then
			count = count + 1
		end
		wanted[productId] = (wanted[productId] or 0) + amount
		if wanted[productId] > config.Cart.MaxQuantity then
			return 'invalid_quantity'
		end
	end
	if #cart > 0 then
		for _, line in ipairs(cart) do
			local errorCode = add(type(line) == 'table' and line.id, type(line) == 'table' and line.quantity)
			if errorCode then
				return nil, errorCode
			end
		end
	else
		for productId, quantity in pairs(cart) do
			local errorCode = add(productId, quantity)
			if errorCode then
				return nil, errorCode
			end
		end
	end
	if count == 0 then
		return nil, 'empty_cart'
	end
	if count > config.Cart.MaxLines then
		return nil, 'cart_too_big'
	end
	local lines, total, units = {}, 0, 0
	for _, productId in ipairs(kind.products) do
		local quantity = wanted[productId]
		if quantity then
			local product = catalog.products[productId]
			local shelf = ctx.shelves and ctx.shelves[productId]
			local available = ShopsRules.Available(ctx.mode, shelf)
			if available and available < quantity then
				return nil, 'out_of_stock', productId
			end
			local unit = ShopsRules.Price(product, ctx.mode, shelf)
			lines[#lines + 1] = { id = productId, item = product.item, quantity = quantity, unit = unit, total = unit * quantity }
			total = total + unit * quantity
			units = units + quantity
		end
	end
	if total > config.Cart.MaxTotal then
		return nil, 'cart_too_expensive'
	end
	return { lines = lines, total = total, units = units }
end

-- Prateleiras depois da venda (só loja de jogador). Não altera a tabela recebida.
function ShopsRules.AfterSale(shelves, lines)
	local out = {}
	for id, shelf in pairs(shelves or {}) do
		out[id] = { quantity = shelf.quantity, price = shelf.price }
	end
	for _, line in ipairs(lines) do
		local shelf = out[line.id] or { quantity = 0 }
		shelf.quantity = math.max(0, shelf.quantity - line.quantity)
		out[line.id] = shelf
	end
	return out
end

-- Abastecer a prateleira: nova quantidade ou nil + erro (respeita o estoque máximo).
function ShopsRules.Restock(config, shelf, quantity)
	local amount = int(quantity, 1, config.MaxStock)
	if not amount then
		return nil, 'invalid_quantity'
	end
	local current = shelf and shelf.quantity or 0
	if current + amount > config.MaxStock then
		return nil, 'stock_full'
	end
	return current + amount
end

-- Retirar da prateleira: nova quantidade ou nil + erro.
function ShopsRules.Withdraw(shelf, quantity, maxQuantity)
	local amount = int(quantity, 1, maxQuantity or 100000)
	if not amount then
		return nil, 'invalid_quantity'
	end
	local current = shelf and shelf.quantity or 0
	if amount > current then
		return nil, 'not_enough_stock'
	end
	return current - amount
end

-- Negócio do coe_businesses criado na primeira vez para a loja (sem dono = da staff).
function ShopsRules.BusinessSeed(catalog, store)
	local kind = catalog.types[store.type]
	local c = store.clerk
	return {
		id = store.id, category = kind.category, label = store.label, enabled = true,
		area = { kind = 'circle', x = c.x, y = c.y, z = c.z, radius = 18.0 },
		stations = {
			stashes = { { id = 'estoque', label = 'Estoque', x = c.x, y = c.y, z = c.z, radius = 2.0, slots = 60, maxWeight = 300000 } },
			clocks = { { id = 'ponto', label = 'Ponto', x = c.x, y = c.y, z = c.z, radius = 2.0 } }
		}
	}
end

-- Descrição curta da venda para o extrato do cartão.
function ShopsRules.Description(store, units)
	return ('%s (%d %s)'):format(store.label, units, units == 1 and 'item' or 'itens'):sub(1, 64)
end
