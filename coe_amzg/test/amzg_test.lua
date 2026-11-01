dofile('config.lua')
dofile('shared/rules.lua')

local config = AmzgConfig
local failures = 0

local function eq(actual, expected, message)
	if actual ~= expected then
		failures = failures + 1
		print(('FAIL %s: esperado %s, obtido %s'):format(message, tostring(expected), tostring(actual)))
	end
end

local function near(actual, expected, message)
	if math.abs(actual - expected) > 1e-6 then
		failures = failures + 1
		print(('FAIL %s: esperado %s, obtido %s'):format(message, tostring(expected), tostring(actual)))
	end
end

-- Produto do painel
local water = { label = 'Água', maxStack = 10 }
local product, errorCode = AmzgRules.Product(config, { item = 'water', label = '  ', category = 'drinks', price = 12 }, water)
eq(product and product.label, 'Água', 'nome vazio usa o do item')
eq(product and product.active, true, 'ativo por padrão')
eq(select(2, AmzgRules.Product(config, { item = 'water', category = 'drinks', price = 12 }, nil)), 'unknown_item', 'item inexistente')
eq(select(2, AmzgRules.Product(config, { item = 'wa ter', category = 'drinks', price = 12 }, water)), 'invalid_item', 'nome de item inválido')
eq(select(2, AmzgRules.Product(config, { item = 'water', category = 'xx', price = 12 }, water)), 'invalid_category', 'categoria inválida')
eq(select(2, AmzgRules.Product(config, { item = 'water', category = 'drinks', price = 0 }, water)), 'invalid_price', 'preço zero')
eq(select(2, AmzgRules.Product(config, { item = 'water', category = 'drinks', price = 1.5 }, water)), 'invalid_price', 'preço fracionado')
eq(select(2, AmzgRules.Product(config, { item = 'water', category = 'drinks', price = config.Products.PriceMax + 1 }, water)), 'invalid_price', 'preço acima do teto')
eq(errorCode, nil, 'produto válido sem erro')

-- Espaços e pilhas
eq(AmzgRules.Slots(10, 25), 3, '25 unidades em pilhas de 10')
eq(AmzgRules.Slots(nil, 3), 3, 'item sem pilha ocupa um espaço por unidade')
local stacks = AmzgRules.Stacks(10, 25)
eq(#stacks, 3, 'três pilhas')
eq(stacks[3], 5, 'última pilha com o resto')

-- Checkout
local products = {
	[1] = { id = 1, item = 'water', label = 'Água', price = 10, active = true },
	[2] = { id = 2, item = 'radio', label = 'Rádio', price = 500, active = true },
	[3] = { id = 3, item = 'old', label = 'Velho', price = 5, active = false }
}
local definitions = { water = { maxStack = 10 }, radio = { maxStack = 1 } }
local priced = AmzgRules.Checkout(config, { { id = 1, qty = 12 }, { id = 2, qty = 2 } }, products, definitions, 'express')
eq(priced and priced.subtotal, 1120, 'subtotal recalculado no servidor')
eq(priced and priced.fee, 150, 'taxa do frete expresso')
eq(priced and priced.total, 1270, 'total com frete')
eq(priced and priced.slots, 4, 'espaços: 2 pilhas de água + 2 rádios')
eq(priced and #priced.lines, 2, 'duas linhas')
eq(select(2, AmzgRules.Checkout(config, {}, products, definitions, 'standard')), 'empty_cart', 'carrinho vazio')
eq(select(2, AmzgRules.Checkout(config, { { id = 1, qty = 1 } }, products, definitions, 'drone')), 'invalid_shipping', 'frete inexistente')
eq(select(2, AmzgRules.Checkout(config, { { id = 3, qty = 1 } }, products, definitions, 'standard')), 'product_unavailable', 'produto inativo')
eq(select(2, AmzgRules.Checkout(config, { { id = 9, qty = 1 } }, products, definitions, 'standard')), 'product_unavailable', 'produto inexistente')
eq(select(2, AmzgRules.Checkout(config, { { id = 1, qty = 0 } }, products, definitions, 'standard')), 'invalid_cart', 'quantidade zero')
eq(select(2, AmzgRules.Checkout(config, { { id = 1, qty = 1.5 } }, products, definitions, 'standard')), 'invalid_cart', 'quantidade fracionada')
eq(select(2, AmzgRules.Checkout(config, { { id = 1, qty = 1 }, { id = 1, qty = 2 } }, products, definitions, 'standard')), 'invalid_cart', 'produto repetido')
eq(select(2, AmzgRules.Checkout(config, { { id = 1, qty = config.Cart.MaxQuantity + 1 } }, products, definitions, 'standard')), 'invalid_cart', 'quantidade acima do máximo')
eq(select(2, AmzgRules.Checkout(config, { { id = 2, qty = config.Cart.MaxSlots + 1 } }, products, definitions, 'standard')), 'box_full', 'itens sem pilha acima da caixa')
local many = {}
for index = 1, 11 do
	many[index] = { id = index, qty = 1 }
end
eq(select(2, AmzgRules.Checkout(config, many, products, definitions, 'standard')), 'cart_too_large', 'produtos demais')
local full = AmzgRules.Checkout(config, { { id = 2, qty = config.Cart.MaxSlots } }, products, definitions, 'standard')
eq(full and full.slots, config.Cart.MaxSlots, 'caixa cheia ainda cabe')
local overflow = { [2] = { id = 2, item = 'radio', label = 'Rádio', price = 500, active = true }, [4] = { id = 4, item = 'radio', label = 'Rádio 2', price = 1, active = true } }
eq(select(2, AmzgRules.Checkout(config, { { id = 2, qty = 15 }, { id = 4, qty = 6 } }, overflow, definitions, 'standard')), 'box_full', 'não cabe na caixa')
local pricey = { [1] = { id = 1, item = 'radio', label = 'Joia', price = 9000, active = true } }
eq(select(2, AmzgRules.Checkout(config, { { id = 1, qty = 12 } }, pricey, definitions, 'standard')), 'amount_too_high', 'acima do teto da compra')

-- Posição das caixas: heading 0 olha para o norte (+y)
local interior = { x = 100, y = 200, z = 30, heading = 0 }
local x, y, z = AmzgRules.BoxPosition(config.Box, interior, 2)
near(x, 100, 'caixa do meio centrada')
near(y, 200 + config.Box.Forward, 'à frente do ponto')
eq(z, 30, 'mesma altura do ponto')
x = AmzgRules.BoxPosition(config.Box, interior, 1)
near(x, 100 - config.Box.Spacing, 'primeira caixa à esquerda')
local _, rowY = AmzgRules.BoxPosition(config.Box, interior, config.Box.Columns + 1)
near(rowY, 200 + config.Box.Forward + config.Box.Spacing, 'segunda fileira mais à frente')
local eastX, eastY = AmzgRules.BoxPosition(config.Box, { x = 0, y = 0, z = 0, heading = 270 }, 2)
near(eastX, config.Box.Forward, 'heading 270 olha para o leste')
near(eastY, 0, 'sem desvio lateral')

-- Resumo
local summary = AmzgRules.Summary(priced.lines)
eq(summary[1].qty, 12, 'resumo guarda a quantidade')
eq(summary[2].item, 'radio', 'resumo guarda o item')

-- Promoções
local promo = AmzgRules.Product(config, { item = 'water', category = 'drinks', price = 100, promoPrice = 99, promoUntil = 2000, featured = true, bannerText = '  Oferta  relâmpago ' }, water, 1000)
eq(promo and promo.promoPrice, 99, 'preço promocional')
eq(promo and promo.bannerText, 'Oferta relâmpago', 'selo limpo')
eq(promo and promo.featured, true, 'destaque no banner')
eq(select(2, AmzgRules.Product(config, { item = 'water', category = 'drinks', price = 100, promoPrice = 100 }, water, 1000)), 'invalid_promo_price', 'promoção igual ao preço cheio')
eq(select(2, AmzgRules.Product(config, { item = 'water', category = 'drinks', price = 100, promoPrice = -1 }, water, 1000)), 'invalid_promo_price', 'promoção negativa')
eq(select(2, AmzgRules.Product(config, { item = 'water', category = 'drinks', price = 100, promoPrice = 90, promoUntil = 999 }, water, 1000)), 'invalid_promo_until', 'prazo no passado')
eq(select(2, AmzgRules.Product(config, { item = 'water', category = 'drinks', price = 100, bannerText = string.rep('x', 25) }, water, 1000)), 'invalid_banner_text', 'selo comprido')
eq(AmzgRules.Product(config, { item = 'water', category = 'drinks', price = 100, promoPrice = 0, promoUntil = 5000 }, water, 1000).promoUntil, 0, 'sem promoção não guarda prazo')
eq(AmzgRules.PromoActive({ price = 100, promoPrice = 99, promoUntil = 0 }, 10), true, 'promoção sem prazo')
eq(AmzgRules.PromoActive({ price = 100, promoPrice = 99, promoUntil = 2000 }, 1999), true, 'promoção dentro do prazo')
eq(AmzgRules.PromoActive({ price = 100, promoPrice = 99, promoUntil = 2000 }, 2000), false, 'promoção vencida')
eq(AmzgRules.PromoActive({ price = 100, promoPrice = 0 }, 10), false, 'sem promoção')
eq(AmzgRules.UnitPrice({ price = 100, promoPrice = 99, promoUntil = 2000 }, 2500), 100, 'vencida volta ao preço cheio')
eq(AmzgRules.Discount(100, 99), 1, 'desconto de 1%')
eq(AmzgRules.Discount(4500, 3600), 20, 'desconto de 20%')
eq(AmzgRules.Discount(1000, 999), 1, 'desconto mínimo de 1%')
products[4] = { id = 4, item = 'radio', label = 'Rádio em oferta', price = 100, promoPrice = 99, promoUntil = 2000, active = true }
local promoPriced = AmzgRules.Checkout(config, { { id = 4, qty = 2 } }, products, definitions, 'standard', 1500)
eq(promoPriced and promoPriced.total, 198, 'checkout cobra o preço promocional')
eq(promoPriced and promoPriced.lines[1].listPrice, 100, 'linha guarda o preço cheio')
eq(AmzgRules.Checkout(config, { { id = 4, qty = 2 } }, products, definitions, 'standard', 2500).total, 200, 'promoção vencida no checkout')

if failures > 0 then
	error(('%d falha(s)'):format(failures))
end
print('amzg_test: ok')
