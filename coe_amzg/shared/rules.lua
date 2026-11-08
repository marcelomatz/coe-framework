-- Regras puras do Amzg (sem natives): validação do carrinho, preço no servidor e posição das caixas.
AmzgRules = {}

local function integer(value)
	local number = tonumber(value)
	return number and math.tointeger(number) or nil
end

function AmzgRules.Category(config, id)
	for _, category in ipairs(config.Categories) do
		if category.id == id then
			return category
		end
	end
	return nil
end

function AmzgRules.Shipping(config, id)
	for _, option in ipairs(config.Shipping) do
		if option.id == id then
			return option
		end
	end
	return nil
end

-- Espaços que `quantity` unidades ocupam na caixa (cada pilha cheia ocupa um).
function AmzgRules.Slots(maxStack, quantity)
	local stack = math.max(1, integer(maxStack) or 1)
	return math.ceil(quantity / stack)
end

-- Promoção ativa agora? Preço promocional entre 1 e o preço cheio - 1 e, se tiver prazo, ainda dentro dele.
function AmzgRules.PromoActive(product, now)
	local promo = integer(product.promoPrice) or 0
	if promo < 1 or promo >= (integer(product.price) or 0) then
		return false
	end
	local untilAt = integer(product.promoUntil) or 0
	return untilAt == 0 or (now ~= nil and untilAt > now)
end

-- Preço por unidade cobrado agora (promocional, se ativo).
function AmzgRules.UnitPrice(product, now)
	if AmzgRules.PromoActive(product, now) then
		return integer(product.promoPrice)
	end
	return product.price
end

-- Desconto em % (inteiro, arredondado para baixo; mínimo 1 quando há promoção).
function AmzgRules.Discount(price, promoPrice)
	if not promoPrice or promoPrice < 1 or promoPrice >= price then
		return 0
	end
	return math.max(1, (price - promoPrice) * 100 // price)
end

local function cleanText(value, max)
	if type(value) ~= 'string' then
		return ''
	end
	local text = value:gsub('[%c<>]', ' '):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
	if not utf8.len(text) then
		return nil
	end
	if utf8.len(text) > max then
		return nil
	end
	return text
end

-- Valida um produto vindo do painel admin. `definition` é a definição do item no inventário (ou nil).
-- Promoção opcional: promoPrice (0 = sem), promoUntil (epoch; 0 = sem prazo; não pode estar no passado),
-- featured (aparece nos banners) e bannerText (selo curto do banner). Devolve a tabela normalizada ou nil + erro.
function AmzgRules.Product(config, input, definition, now)
	if type(input) ~= 'table' then
		return nil, 'invalid_product'
	end
	local item = input.item
	if type(item) ~= 'string' or item == '' or #item > 64 or not item:match('^[%w_%-%.]+$') then
		return nil, 'invalid_item'
	end
	if type(definition) ~= 'table' then
		return nil, 'unknown_item'
	end
	local label = type(input.label) == 'string' and input.label:gsub('^%s+', ''):gsub('%s+$', '') or ''
	if label == '' then
		label = tostring(definition.label or item)
	end
	if #label > config.Products.LabelMax then
		return nil, 'invalid_label'
	end
	if not AmzgRules.Category(config, input.category) then
		return nil, 'invalid_category'
	end
	local price = integer(input.price)
	if not price or price < 1 or price > config.Products.PriceMax then
		return nil, 'invalid_price'
	end
	local sort = integer(input.sort) or 0
	if sort < 0 or sort > 9999 then
		return nil, 'invalid_sort'
	end
	local promoPrice = integer(input.promoPrice or 0)
	if not promoPrice or promoPrice < 0 or (promoPrice > 0 and promoPrice >= price) then
		return nil, 'invalid_promo_price'
	end
	local promoUntil = integer(input.promoUntil or 0)
	if not promoUntil or promoUntil < 0 or (promoUntil > 0 and now and promoUntil <= now) then
		return nil, 'invalid_promo_until'
	end
	local bannerText = cleanText(input.bannerText, config.Promo.BannerTextMax)
	if not bannerText then
		return nil, 'invalid_banner_text'
	end
	if promoPrice == 0 then
		promoUntil = 0
	end
	return {
		item = item, label = label, category = input.category, price = price, active = input.active ~= false, sort = sort,
		promoPrice = promoPrice, promoUntil = promoUntil, featured = input.featured == true, bannerText = bannerText
	}
end

-- Confere o carrinho `[{id, qty}]` contra o catálogo (mapa id -> produto ativo) e os itens do inventário
-- (`definitions[item]` com maxStack). Recalcula tudo no servidor: o preço do cliente nunca é usado.
-- Devolve { lines = {{productId, item, label, price, quantity, subtotal}}, subtotal, fee, total, slots } ou nil + erro.
-- `now` decide se a promoção ainda vale (o preço promocional vencido volta ao cheio).
function AmzgRules.Checkout(config, cart, products, definitions, shippingId, now)
	if type(cart) ~= 'table' or #cart == 0 then
		return nil, 'empty_cart'
	end
	if #cart > config.Cart.MaxLines then
		return nil, 'cart_too_large'
	end
	local shipping = AmzgRules.Shipping(config, shippingId)
	if not shipping then
		return nil, 'invalid_shipping'
	end
	local lines, seen, subtotal, slots = {}, {}, 0, 0
	for _, entry in ipairs(cart) do
		if type(entry) ~= 'table' then
			return nil, 'invalid_cart'
		end
		local id, quantity = integer(entry.id), integer(entry.qty)
		if not id or not quantity or quantity < 1 or quantity > config.Cart.MaxQuantity then
			return nil, 'invalid_cart'
		end
		if seen[id] then
			return nil, 'invalid_cart'
		end
		seen[id] = true
		local product = products[id]
		if not product or not product.active then
			return nil, 'product_unavailable'
		end
		local definition = definitions[product.item]
		if not definition then
			return nil, 'product_unavailable'
		end
		local unit = AmzgRules.UnitPrice(product, now)
		local lineTotal = unit * quantity
		subtotal = subtotal + lineTotal
		slots = slots + AmzgRules.Slots(definition.maxStack, quantity)
		lines[#lines + 1] = { productId = id, item = product.item, label = product.label, price = unit, listPrice = product.price, quantity = quantity, subtotal = lineTotal }
	end
	if slots > config.Cart.MaxSlots then
		return nil, 'box_full'
	end
	local total = subtotal + shipping.fee
	if total > config.Cart.MaxTotal then
		return nil, 'amount_too_high'
	end
	return { lines = lines, subtotal = subtotal, fee = shipping.fee, total = total, slots = slots, shipping = shipping }
end

-- Divide `quantity` em pilhas de até `maxStack` (AddItem recusa acima disso).
function AmzgRules.Stacks(maxStack, quantity)
	local stack = math.max(1, integer(maxStack) or 1)
	local list = {}
	local remaining = quantity
	while remaining > 0 do
		local take = math.min(stack, remaining)
		list[#list + 1] = take
		remaining = remaining - take
	end
	return list
end

-- Posição da caixa `index` (1..n): fileiras de `Columns` à frente do ponto interior, centradas.
-- Devolve x, y, z (z do ponto; o cliente acomoda no chão).
function AmzgRules.BoxPosition(box, interior, index)
	local columns = math.max(1, box.Columns)
	local slot = index - 1
	local column = slot % columns
	local row = math.floor(slot / columns)
	local side = (column - (columns - 1) / 2) * box.Spacing
	local ahead = box.Forward + row * box.Spacing
	local heading = math.rad(tonumber(interior.heading) or 0)
	-- Heading do GTA: 0 = norte (+y), cresce no sentido anti-horário.
	local forwardX, forwardY = -math.sin(heading), math.cos(heading)
	local rightX, rightY = forwardY, -forwardX
	return interior.x + forwardX * ahead + rightX * side, interior.y + forwardY * ahead + rightY * side, interior.z
end

-- Resumo das linhas guardado no pedido (cabe numa coluna TEXT e no histórico do app).
function AmzgRules.Summary(lines)
	local list = {}
	for _, line in ipairs(lines) do
		list[#list + 1] = { item = line.item, label = line.label, qty = line.quantity, price = line.price }
	end
	return list
end

function AmzgRules.ExecuteSaga(steps, context)
	local Concurrency = (Core and Core.Algorithms and Core.Algorithms.Concurrency) or (CoeAlgorithms and CoeAlgorithms.Concurrency)
	if Concurrency and Concurrency.executeSaga then
		local ok, failedStep, reason = Concurrency.executeSaga(steps, context)
		if not ok then
			return false, reason or failedStep
		end
		return true
	end
	local completed = {}
	for _, step in ipairs(steps) do
		local fn = step.action or step.forward
		local ok, err = fn(context)
		if not ok then
			for j = #completed, 1, -1 do
				if completed[j].compensate then
					pcall(completed[j].compensate, context)
				end
			end
			return false, err
		end
		completed[#completed + 1] = step
	end
	return true
end

function AmzgRules.NewLockManager()
	local alg = (type(Core) == 'table' and Core.Algorithms) or CoeAlgorithms
	local Concurrency = alg and alg.Concurrency
	if Concurrency and Concurrency.newLockManager then
		return Concurrency.newLockManager()
	end
	return nil
end

function AmzgRules.NewRateLimiter(cooldownMs)
	local alg = (type(Core) == 'table' and Core.Algorithms) or CoeAlgorithms
	local RateLimit = alg and alg.RateLimit
	if RateLimit and RateLimit.newGCRA then
		return RateLimit.newGCRA(math.max(1, tonumber(cooldownMs) or 500), 0)
	end
	return nil
end
