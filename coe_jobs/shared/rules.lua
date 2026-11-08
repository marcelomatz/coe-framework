-- Regras puras do coe_jobs (sem natives): validação das definições de emprego, níveis, pagamento e checagens de
-- posição/tempo usadas pelo servidor. Testáveis fora do jogo (test/rules_test.lua).
JobRules = {}

local KINDS = { gather = true, route = true }
-- deliver: leva do veículo até o destinatário; collect: recolhe na parada e guarda no veículo;
-- passenger: embarca na parada e desembarca na seguinte (táxi).
-- zone: vai até uma área e recolhe em qualquer lixeira/objeto do mapa (`binModels`) até completar a zona.
local ROUTE_MODES = { deliver = true, collect = true, passenger = true, zone = true }
local MAX_POINTS = 200
local MAX_LEVELS = 20

local function isId(value)
	return type(value) == 'string' and #value >= 2 and #value <= 24 and value:match('^[a-z][a-z0-9_]*$') ~= nil
end

local function text(value, max)
	return type(value) == 'string' and #value > 0 and #value <= (max or 64)
end

local function num(value, min, max)
	local n = tonumber(value)
	if not n or n ~= n or n == math.huge or n == -math.huge then
		return nil
	end
	if (min and n < min) or (max and n > max) then
		return nil
	end
	return n
end

local function int(value, min, max)
	local n = num(value, min, max)
	return n and math.floor(n) == n and n or nil
end

local function model(value)
	return type(value) == 'string' and #value >= 2 and #value <= 48 and value:match('^[%w_]+$') ~= nil
end

-- Ponto {x, y, z, h?}; devolve uma cópia limpa.
local function point(raw)
	if type(raw) ~= 'table' then
		return nil
	end
	local x, y, z = num(raw.x or raw[1], -10000, 10000), num(raw.y or raw[2], -10000, 10000), num(raw.z or raw[3], -500, 3000)
	if not x or not y or not z then
		return nil
	end
	local heading = num(raw.h or raw.heading or raw[4], -360, 360) or 0.0
	return { x = x, y = y, z = z, h = heading }
end

local function points(raw, min)
	if type(raw) ~= 'table' or #raw < (min or 1) or #raw > MAX_POINTS then
		return nil
	end
	local out = {}
	for index, entry in ipairs(raw) do
		local clean = point(entry)
		if not clean then
			return nil, index
		end
		out[index] = clean
	end
	return out
end

-- Animação: { dict, name, flag? } ou { scenario }.
local function anim(raw)
	if raw == nil then
		return nil, true
	end
	if type(raw) ~= 'table' then
		return nil, false
	end
	if raw.scenario then
		return model(raw.scenario) and { scenario = raw.scenario } or nil, model(raw.scenario)
	end
	if not text(raw.dict, 96) or not text(raw.name, 96) then
		return nil, false
	end
	return { dict = raw.dict, name = raw.name, flag = int(raw.flag, 0, 1023) or 1 }, true
end

-- Animação curta com duração (pegar o saco, jogar na caçamba): { dict, name, flag?, ms? }.
local function shortAnim(raw)
	local clean, ok = anim(raw)
	if not ok or not clean or clean.scenario then
		return nil, raw == nil
	end
	clean.ms = int(raw.ms, 100, 10000) or 1200
	return clean, true
end

-- Prop segurado na mão: { model, bone?, offset?, rotation? }.
local function prop(raw)
	if raw == nil then
		return nil, true
	end
	if type(raw) ~= 'table' or not model(raw.model) then
		return nil, false
	end
	local function vec(v)
		if type(v) ~= 'table' then
			return { 0.0, 0.0, 0.0 }
		end
		return { num(v[1], -10, 10) or 0.0, num(v[2], -10, 10) or 0.0, num(v[3], -360, 360) or 0.0 }
	end
	return {
		model = raw.model,
		-- Modelo reserva se o principal não existir no jogo (o client tenta na ordem).
		fallback = model(raw.fallback) and raw.fallback or nil,
		bone = int(raw.bone, 0, 65535) or 57005,
		offset = vec(raw.offset),
		rotation = (function()
			if type(raw.rotation) ~= 'table' then return { 0.0, 0.0, 0.0 } end
			return { num(raw.rotation[1], -360, 360) or 0.0, num(raw.rotation[2], -360, 360) or 0.0, num(raw.rotation[3], -360, 360) or 0.0 }
		end)()
	}, true
end

local function fail(code, detail)
	return nil, detail and (code .. ':' .. detail) or code
end

-- Modelo de prop: um nome ou uma lista de candidatos (o client usa o primeiro que existir nesta versão do jogo).
local function models(raw)
	if raw == nil then
		return nil, true
	end
	if type(raw) == 'string' then
		return model(raw) and { raw } or nil, model(raw)
	end
	if type(raw) ~= 'table' or #raw < 1 or #raw > 8 then
		return nil, false
	end
	local out = {}
	for index, name in ipairs(raw) do
		if not model(name) then
			return nil, false
		end
		out[index] = name
	end
	return out, true
end

local function yieldOf(raw, default)
	local y = type(raw) == 'table' and raw or default
	local low, high = int(y[1], 1, 100), int(y[2], 1, 100)
	if not low or not high or high < low then
		return nil
	end
	return { low, high }
end

-- Uniforme opcional (só visual): { male = { components = { [id] = { drawable, texture } }, props = { ... } }, female = ... }.
-- Normaliza para listas { { id, drawable, texture } } (seguras no msgpack, sem chave 0).
local function outfit(raw)
	if type(raw) ~= 'table' then
		return nil
	end
	local function parts(list, maxId)
		local out = {}
		if list == nil then
			return out
		end
		if type(list) ~= 'table' then
			return nil
		end
		for id, value in pairs(list) do
			local slot = int(id, 0, maxId)
			if not slot or type(value) ~= 'table' then
				return nil
			end
			local drawable, texture = int(value[1], -1, 1000), int(value[2] or 0, 0, 100)
			if not drawable or not texture then
				return nil
			end
			out[#out + 1] = { slot, drawable, texture }
		end
		table.sort(out, function(a, b) return a[1] < b[1] end)
		return out
	end
	local components, props = parts(raw.components, 11), parts(raw.props, 9)
	if not components or not props or (#components == 0 and #props == 0) then
		return nil
	end
	return { components = components, props = props }
end

local function uniform(raw)
	if raw == nil then
		return nil, true
	end
	if type(raw) ~= 'table' then
		return nil, false
	end
	local male, female = raw.male ~= nil and outfit(raw.male), raw.female ~= nil and outfit(raw.female)
	if (raw.male ~= nil and not male) or (raw.female ~= nil and not female) or (not male and not female) then
		return nil, false
	end
	return { label = text(raw.label, 40) and raw.label or 'Uniforme', male = male or nil, female = female or nil }, true
end

-- Campo de plantio em grade: origem (primeiro pé), direção das fileiras, fileiras x pés e espaçamento. Gera os
-- pontos igual no servidor e no client: mudar o campo é mexer em poucos números em vez de dezenas de coordenadas.
local function fieldNodes(raw)
	local origin = type(raw) == 'table' and point(raw.origin)
	local rows, cols = type(raw) == 'table' and int(raw.rows, 1, 30), type(raw) == 'table' and int(raw.cols, 1, 30)
	if not origin or not rows or not cols then
		return nil
	end
	local spacing = num(raw.spacing, 1, 30) or 4.0
	local rowSpacing = num(raw.rowSpacing, 1, 30) or spacing
	local heading = math.rad(num(raw.heading, -360, 360) or 0.0)
	-- Eixo da fileira (para onde o heading do GTA aponta) e eixo entre fileiras (à direita dele).
	local ax, ay = -math.sin(heading), math.cos(heading)
	local bx, by = math.cos(heading), math.sin(heading)
	local out = {}
	for row = 0, rows - 1 do
		for col = 0, cols - 1 do
			out[#out + 1] = {
				x = math.floor((origin.x + ax * col * spacing + bx * row * rowSpacing) * 100 + 0.5) / 100,
				y = math.floor((origin.y + ay * col * spacing + by * row * rowSpacing) * 100 + 0.5) / 100,
				z = origin.z, h = math.deg(heading)
			}
		end
	end
	return out
end

-- Área circular { x, y, z, radius, label? }.
local function area(raw, minRadius, maxRadius)
	local center = point(raw)
	local radius = type(raw) == 'table' and num(raw.radius, minRadius or 5, maxRadius or 500)
	if not center or not radius then
		return nil
	end
	return { x = center.x, y = center.y, z = center.z, radius = radius, label = text(raw.label, 40) and raw.label or nil }
end

local TIERS = { common = true, uncommon = true, rare = true }
local TIER_SPEED = { common = 0.7, uncommon = 0.95, rare = 1.25 }
-- Peso extra de cada raridade por ponto de bônus (vara + isca): comuns ficam iguais, raros sobem mais.
local TIER_BOOST = { common = 0, uncommon = 1.5, rare = 3 }

-- Loja do emprego (varas, iscas...): itens do coe_inventory com preço e nível do emprego para desbloquear.
local function shopOf(raw, maxLevel)
	if raw == nil then
		return nil, true
	end
	if type(raw) ~= 'table' or type(raw.items) ~= 'table' or #raw.items < 1 or #raw.items > 40 then
		return nil, false
	end
	local spots = points(raw.points)
	if not spots then
		return nil, false
	end
	local items = {}
	for index, entry in ipairs(raw.items) do
		local price = type(entry) == 'table' and int(entry.price, 1, 1000000)
		if not price or not model(entry.item) or not text(entry.label, 40) then
			return nil, false
		end
		items[index] = {
			item = entry.item, label = entry.label, price = price,
			description = text(entry.description, 160) and entry.description or '',
			level = math.min(int(entry.level, 1, 100) or 1, maxLevel),
			-- Quantidade máxima por compra (varas: 1).
			max = int(entry.max, 1, 100) or 1,
			kind = text(entry.kind, 16) and entry.kind or 'item',
			stats = type(entry.stats) == 'table' and entry.stats or nil
		}
	end
	return {
		label = text(raw.label, 40) and raw.label or 'Loja',
		ped = model(raw.ped) and raw.ped or 's_m_m_cntrybar_01',
		points = spots, items = items
	}, true
end

-- Pesca livre: áreas com espécies (produtos) e pesos, varas e iscas (itens do coe_inventory) com nível e bônus.
local function fishingOf(raw, products, maxLevel)
	if raw == nil then
		return nil, true
	end
	if type(raw) ~= 'table' then
		return nil, false
	end
	local fishing = { areas = {}, rods = {}, baits = {}, rodOrder = {}, baitOrder = {} }
	local bite = yieldOf(raw.biteSeconds, { 6, 14 })
	if not bite then
		return nil, false
	end
	fishing.biteSeconds = bite
	fishing.castSeconds = num(raw.castSeconds, 0, 10) or 2.5
	-- Tempo para reagir à mordida (fisgar) e duração máxima da briga com o peixe.
	fishing.hookSeconds = num(raw.hookSeconds, 0.5, 5) or 1.6
	fishing.fightSeconds = num(raw.fightSeconds, 10, 90) or 35
	fishing.actionLabel = text(raw.actionLabel, 40) and raw.actionLabel or 'Pescar'
	-- Vara na mão (prop próprio: o do cenário de pesca caía no chão a cada lance). Padrão: mão esquerda.
	local rodProp, rodPropOk = prop(raw.rodProp or {
		model = 'prop_fishing_rod_01', bone = 18905, offset = { 0.1, 0.05, 0.0 }, rotation = { 80.0, 120.0, 160.0 }
	})
	if not rodPropOk or not rodProp then
		return nil, false, 'rodProp'
	end
	fishing.rodProp = rodProp
	for index, entry in ipairs(type(raw.areas) == 'table' and raw.areas or {}) do
		local zone = area(entry, 10, 600)
		if not zone or type(entry.species) ~= 'table' then
			return nil, false, 'area:' .. index
		end
		zone.label = zone.label or ('Área ' .. index)
		zone.water = (entry.water == 'fresh') and 'fresh' or 'sea'
		zone.species = {}
		local ids = {}
		for id in pairs(entry.species) do
			ids[#ids + 1] = id
		end
		table.sort(ids)
		for _, id in ipairs(ids) do
			local weight = num(entry.species[id], 0.01, 1000)
			if not products[id] or not weight then
				return nil, false, 'area:' .. index
			end
			zone.species[#zone.species + 1] = { id = id, weight = weight }
		end
		if #zone.species == 0 then
			return nil, false, 'area:' .. index
		end
		fishing.areas[index] = zone
	end
	if #fishing.areas == 0 then
		return nil, false, 'areas'
	end
	local function gear(list, order, out, kind)
		if type(list) ~= 'table' or #list == 0 then
			return false
		end
		for _, entry in ipairs(list) do
			if type(entry) ~= 'table' or not model(entry.item) or out[entry.item] then
				return false
			end
			out[entry.item] = {
				item = entry.item, kind = kind,
				label = text(entry.label, 40) and entry.label or entry.item,
				level = math.min(int(entry.level, 1, 100) or 1, maxLevel),
				-- speed: multiplica a espera até a mordida; window: largura da faixa do minigame (0-1).
				speed = num(entry.speed, 0.2, 3) or 1.0,
				window = num(entry.window, 0.02, 0.8) or 0,
				rarity = num(entry.rarity, 0, 5) or 0,
				-- keep: chance de a isca não se perder no lance (isca artificial).
				keep = num(entry.keep, 0, 0.95) or 0
			}
			order[#order + 1] = entry.item
		end
		return true
	end
	if not gear(raw.rods, fishing.rodOrder, fishing.rods, 'rod') or not gear(raw.baits, fishing.baitOrder, fishing.baits, 'bait') then
		return nil, false, 'gear'
	end
	for _, id in ipairs(fishing.rodOrder) do
		if fishing.rods[id].window <= 0 then
			fishing.rods[id].window = 0.16
		end
	end
	return fishing, true
end

-- Produto de uma coleta: o que se colhe e quanto vale. Campos faltando herdam da coleta (`base`).
local function product(id, raw, base)
	if not isId(id) or type(raw) ~= 'table' then
		return nil
	end
	local animation, animOk = anim(raw.animation)
	local prop, propOk = models(raw.prop)
	local yield = raw.yield ~= nil and yieldOf(raw.yield) or base.yield
	local price = int(raw.price == nil and base.price or raw.price, 0, 100000)
	if not animOk or not propOk or not yield or not price then
		return nil
	end
	return {
		id = id,
		label = text(raw.label, 40) and raw.label or (text(raw.units, 24) and raw.units or base.units),
		unit = text(raw.unit, 24) and raw.unit or base.unit,
		units = text(raw.units, 24) and raw.units or base.units,
		price = price,
		prop = prop or base.prop,
		animation = animation or base.animation,
		seconds = num(raw.seconds, 1, 120) or base.seconds,
		yield = yield,
		xp = int(raw.xp, 0, 10000) or base.xp,
		actionLabel = text(raw.actionLabel, 40) and raw.actionLabel or base.actionLabel,
		cooldown = int(raw.cooldown, 0, 3600) or base.nodeCooldown,
		-- Pesca: raridade (common/uncommon/rare) e velocidade do marcador no minigame (voltas por segundo).
		tier = TIERS[raw.tier] and raw.tier or 'common',
		difficulty = num(raw.difficulty, 0.2, 4) or TIER_SPEED[TIERS[raw.tier] and raw.tier or 'common']
	}
end

function JobRules.IsId(value)
	return isId(value)
end

-- Valida e normaliza a definição de um emprego. Devolve a definição limpa ou nil + código.
-- knownSkills (opcional): id -> true das habilidades da carreira; habilidade desconhecida é erro.
function JobRules.Validate(raw, knownSkills)
	if type(raw) ~= 'table' then
		return fail('invalid_definition')
	end
	-- `deposit` e `shop` são motivos do extrato (job_deposit, job_shop).
	if not isId(raw.id) or raw.id == 'deposit' or raw.id == 'shop' then
		return fail('invalid_id')
	end
	if not text(raw.label, 40) then
		return fail('invalid_label')
	end
	if not KINDS[raw.kind] then
		return fail('invalid_kind')
	end
	local center = point(raw.center)
	if not center then
		return fail('invalid_center')
	end
	local job = {
		id = raw.id, label = raw.label, kind = raw.kind,
		description = text(raw.description, 240) and raw.description or '',
		center = center,
		centerPed = model(raw.centerPed) and raw.centerPed or 's_m_m_gentransport',
		blip = {
			sprite = int(type(raw.blip) == 'table' and raw.blip.sprite, 1, 900) or 408,
			color = int(type(raw.blip) == 'table' and raw.blip.color, 0, 85) or 2
		},
		-- Limites de XP por nível (crescentes, começando em 0).
		levels = {},
		levelBonus = num(raw.levelBonus, 0, 1) or 0.05,
		tool = nil, vehicle = nil
	}
	local levels = raw.levels or { 0 }
	if type(levels) ~= 'table' or #levels < 1 or #levels > MAX_LEVELS or levels[1] ~= 0 then
		return fail('invalid_levels')
	end
	for index, value in ipairs(levels) do
		local xp = int(value, 0, 10000000)
		if not xp or (index > 1 and xp <= job.levels[index - 1]) then
			return fail('invalid_levels')
		end
		job.levels[index] = xp
	end
	local shop, shopOk = shopOf(raw.shop, #job.levels)
	if not shopOk then
		return fail('invalid_shop')
	end
	job.shop = shop
	-- Habilidades que o emprego treina (o XP dele soma nelas) e requisitos de carreira para começar.
	job.skills = {}
	for _, skill in ipairs(type(raw.skills) == 'table' and raw.skills or {}) do
		if not isId(skill) or (knownSkills and not knownSkills[skill]) then
			return fail('invalid_skill', tostring(skill))
		end
		job.skills[#job.skills + 1] = skill
	end
	if raw.requires ~= nil then
		local r = raw.requires
		if type(r) ~= 'table' then
			return fail('invalid_requires')
		end
		job.requires = { career = int(r.career, 1, 100), reputation = int(r.reputation, -1000, 1000), skills = {} }
		for skill, level in pairs(type(r.skills) == 'table' and r.skills or {}) do
			if not isId(skill) or (knownSkills and not knownSkills[skill]) or not int(level, 1, 100) then
				return fail('invalid_requires')
			end
			job.requires.skills[skill] = level
		end
	end
	-- Dicas extras do guia "Como funciona" (até 6 frases).
	job.tips = {}
	if raw.tips ~= nil then
		if type(raw.tips) ~= 'table' or #raw.tips > 6 then
			return fail('invalid_tips')
		end
		for _, tip in ipairs(raw.tips) do
			if not text(tip, 160) then
				return fail('invalid_tips')
			end
			job.tips[#job.tips + 1] = tip
		end
	end
	local tool, toolOk = prop(raw.tool)
	if not toolOk then
		return fail('invalid_tool')
	end
	job.tool = tool
	local outfitDef, outfitOk = uniform(raw.uniform)
	if not outfitOk then
		return fail('invalid_uniform')
	end
	job.uniform = outfitDef
	if raw.vehicle ~= nil then
		local v = raw.vehicle
		local spawn = type(v) == 'table' and point(v.spawn)
		if type(v) ~= 'table' or not model(v.model) or not spawn then
			return fail('invalid_vehicle')
		end
		local plate = type(v.plate) == 'string' and v.plate:upper():gsub('[^A-Z0-9]', ''):sub(1, 4) or 'JOB'
		job.vehicle = {
			model = v.model, spawn = spawn, plate = plate ~= '' and plate or 'JOB',
			deposit = int(v.deposit, 0, 100000) or 0,
			-- Distância do centro para devolver o veículo e reaver o depósito.
			returnRadius = num(v.returnRadius, 5, 200) or 35.0
		}
	end
	if raw.kind == 'gather' then
		local g = raw.gather
		if type(g) ~= 'table' then
			return fail('invalid_gather')
		end
		local sell, badSell = points(g.sell and g.sell.points)
		if not sell then
			return fail('invalid_sell_points', badSell and tostring(badSell) or nil)
		end
		local animation, animOk = anim(g.animation)
		if not animOk then
			return fail('invalid_animation')
		end
		local yield = yieldOf(g.yield, { 1, 1 })
		if not yield then
			return fail('invalid_yield')
		end
		local nodeProp, nodePropOk = models(g.nodeProp)
		if not nodePropOk then
			return fail('invalid_node_prop')
		end
		local gather = {
			nodes = {},
			nodeProp = nodeProp,
			actionLabel = text(g.actionLabel, 40) and g.actionLabel or 'Coletar',
			seconds = num(g.seconds, 1, 120) or 6,
			yield = yield,
			capacity = int(g.capacity, 1, 1000) or 20,
			nodeCooldown = int(g.nodeCooldown, 0, 3600) or 60,
			xp = int(g.xp, 0, 10000) or 1,
			unit = text(g.unit, 24) and g.unit or 'unidade',
			units = text(g.units, 24) and g.units or 'unidades',
			animation = animation,
			-- Pontos de plantio só nascem em chão de terra (o client confere o material do chão).
			soil = g.soil == true,
			products = {}, productOrder = {},
			sell = {
				points = sell,
				ped = model(g.sell.ped) and g.sell.ped or 's_m_m_gentransport',
				label = text(g.sell.label, 40) and g.sell.label or 'Vender'
			}
		}
		-- Produtos: sem `products`, a coleta tem um só (`main`) com unit/units/sell.price da própria coleta.
		local base = {
			unit = gather.unit, units = gather.units, prop = nodeProp, animation = animation, seconds = gather.seconds,
			yield = yield, xp = gather.xp, actionLabel = gather.actionLabel, nodeCooldown = gather.nodeCooldown
		}
		if g.products ~= nil then
			if type(g.products) ~= 'table' then
				return fail('invalid_products')
			end
			local ids = {}
			for id in pairs(g.products) do
				ids[#ids + 1] = id
			end
			table.sort(ids, function(a, b) return tostring(a) < tostring(b) end)
			if #ids == 0 or #ids > 12 then
				return fail('invalid_products')
			end
			for _, id in ipairs(ids) do
				local clean = product(id, g.products[id], base)
				if not clean then
					return fail('invalid_products', tostring(id))
				end
				gather.products[id] = clean
			end
			-- Ordem de exibição: a de `order`, se houver, senão alfabética.
			local order = type(g.order) == 'table' and g.order or ids
			for _, id in ipairs(order) do
				if gather.products[id] then
					gather.productOrder[#gather.productOrder + 1] = id
				end
			end
			for _, id in ipairs(ids) do
				local listed = false
				for _, other in ipairs(gather.productOrder) do
					listed = listed or other == id
				end
				if not listed then
					gather.productOrder[#gather.productOrder + 1] = id
				end
			end
		else
			base.price = g.sell.price
			local clean = product('main', {}, base)
			if not clean or clean.price < 1 then
				return fail('invalid_price')
			end
			gather.products.main = clean
			gather.productOrder = { 'main' }
		end
		local defaultProduct = gather.productOrder[1]
		gather.defaultProduct = defaultProduct
		local function productOf(id)
			if id == nil then
				return defaultProduct
			end
			return gather.products[id] and id or nil
		end
		-- Pontos soltos (`nodes`) e campos em grade (`fields`), cada um com o seu produto.
		if g.nodes ~= nil then
			local nodes, badNode = points(g.nodes)
			if not nodes then
				return fail('invalid_nodes', badNode and tostring(badNode) or nil)
			end
			for index, node in ipairs(nodes) do
				node.product = productOf(g.nodes[index].product)
				if not node.product then
					return fail('invalid_nodes', tostring(index))
				end
				gather.nodes[#gather.nodes + 1] = node
			end
		end
		gather.fields = {}
		for index, rawField in ipairs(type(g.fields) == 'table' and g.fields or {}) do
			local generated = fieldNodes(rawField)
			local productId = generated and productOf(rawField.product)
			if not generated or not productId then
				return fail('invalid_fields', tostring(index))
			end
			gather.fields[index] = {
				label = text(rawField.label, 40) and rawField.label or gather.products[productId].label,
				product = productId, first = #gather.nodes + 1, count = #generated,
				-- Filtro de chão de terra por campo (padrão: o `soil` da coleta; pomar em gramado usa false).
				soil = rawField.soil == nil and gather.soil or rawField.soil == true
			}
			for _, node in ipairs(generated) do
				node.product = productId
				node.field = index
				gather.nodes[#gather.nodes + 1] = node
			end
		end
		if #gather.nodes > MAX_POINTS then
			return fail('invalid_nodes')
		end
		-- Objetos do próprio mapa numa área (árvores do lenhador): qualquer um dos modelos dentro do raio serve.
		gather.world = {}
		for index, rawWorld in ipairs(type(g.world) == 'table' and g.world or {}) do
			local zone = type(rawWorld) == 'table' and area(rawWorld.area, 10, 800)
			local list = type(rawWorld) == 'table' and type(rawWorld.models) == 'table' and #rawWorld.models > 0
			local productId = zone and productOf(rawWorld.product)
			if not zone or not list or not productId then
				return fail('invalid_world', tostring(index))
			end
			-- Até 32 modelos por área (o coetarget registra cada um).
			if type(rawWorld.models) == 'table' and #rawWorld.models > 32 then
				return fail('invalid_world', tostring(index))
			end
			local all = {}
			for i, name in ipairs(rawWorld.models) do
				if not model(name) or i > 32 then
					return fail('invalid_world', tostring(index))
				end
				all[i] = name
			end
			gather.world[index] = {
				product = productId, models = all, area = zone,
				label = zone.label or gather.products[productId].label,
				-- fell: a árvore tomba e some para todos até `cooldown` (segundos) passar.
				fell = rawWorld.fell == true,
				cooldown = int(rawWorld.cooldown, 0, 86400) or gather.products[productId].cooldown
			}
		end
		local fishing, fishingOk, fishingDetail = fishingOf(g.fishing, gather.products, #job.levels)
		if not fishingOk then
			return fail('invalid_fishing', fishingDetail)
		end
		gather.fishing = fishing
		if #gather.nodes == 0 and #gather.world == 0 and not gather.fishing then
			return fail('invalid_nodes')
		end
		-- Transporte: a coleta cai no chão, o jogador carrega uma por vez e guarda no veículo do emprego.
		if g.haul ~= nil then
			local h = g.haul
			if type(h) ~= 'table' or not job.vehicle then
				return fail('invalid_haul')
			end
			local carry, carryOk = prop(h.carry)
			local carryAnim, carryAnimOk = anim(h.carryAnimation)
			local ground, groundOk = models(h.groundProp)
			local rackModel, rackOk = models(h.rack and h.rack.model)
			if not carry or not carryOk or not carryAnimOk or not groundOk or not rackOk then
				return fail('invalid_haul')
			end
			local slots = {}
			for index, slot in ipairs(type(h.rack) == 'table' and type(h.rack.slots) == 'table' and h.rack.slots or {}) do
				if type(slot) ~= 'table' or index > 24 then
					return fail('invalid_haul')
				end
				local values = {}
				for i = 1, 6 do
					values[i] = num(slot[i] or 0, -360, 360)
					if not values[i] then
						return fail('invalid_haul')
					end
				end
				slots[index] = values
			end
			gather.haul = {
				-- Produto que vai no veículo (o da primeira área do mapa ou do primeiro ponto).
				product = (gather.world[1] or gather.nodes[1]).product,
				capacity = int(h.capacity, 1, 100) or 6,
				carry = carry, carryAnimation = carryAnim, groundProp = ground or { carry.model },
				takeLabel = text(h.takeLabel, 40) and h.takeLabel or 'Pegar',
				loadLabel = text(h.loadLabel, 40) and h.loadLabel or 'Guardar no veículo',
				rack = rackModel and { model = rackModel, slots = slots } or nil
			}
			-- A capacidade da coleta passa a ser a do veículo (o bônus de Força soma nela).
			gather.capacity = gather.haul.capacity
		end
		-- Beneficiamento: no ponto, a carga do veículo vira outro produto (toras -> tábuas) antes da venda.
		if g.process ~= nil then
			local p = g.process
			local processPoints, badProcess = type(p) == 'table' and points(p.points)
			local output = type(p) == 'table' and gather.products[p.product]
			local processAnim, processAnimOk = anim(type(p) == 'table' and p.animation or nil)
			local processProp, processPropOk = models(type(p) == 'table' and p.prop or nil)
			if not gather.haul or not processPoints or not output or not processAnimOk or not processPropOk then
				return fail('invalid_process', badProcess and tostring(badProcess) or nil)
			end
			gather.process = {
				points = processPoints, product = p.product,
				label = text(p.label, 40) and p.label or 'Beneficiar',
				ratio = int(p.ratio, 1, 100) or 1,
				seconds = num(p.seconds, 1, 60) or 4,
				maxSeconds = num(p.maxSeconds, 1, 120) or 24,
				vehicleRange = num(p.vehicleRange, 5, 100) or 25.0,
				animation = processAnim, prop = processProp
			}
		end
		-- Algo precisa ter preço na venda.
		local sellable = false
		for _, item in pairs(gather.products) do
			sellable = sellable or item.price > 0
		end
		if not sellable then
			return fail('invalid_price')
		end
		gather.sell.price = gather.products[gather.process and gather.process.product or defaultProduct].price
		job.gather = gather
	else
		local r = raw.route
		if type(r) ~= 'table' then
			return fail('invalid_route')
		end
		local mode = r.mode or 'deliver'
		if not ROUTE_MODES[mode] then
			return fail('invalid_mode')
		end
		-- Zonas: cada uma é um centro com raio; as rotas sorteiam zonas como sorteiam paradas.
		local zones
		if mode == 'zone' then
			if type(r.zones) ~= 'table' or #r.zones < 2 or #r.zones > MAX_POINTS then
				return fail('invalid_zones')
			end
			zones = {}
			for index, raw_zone in ipairs(r.zones) do
				local center = point(raw_zone)
				local radius = type(raw_zone) == 'table' and num(raw_zone.radius, 10, 400)
				if not center or not radius then
					return fail('invalid_zones', tostring(index))
				end
				zones[index] = {
					x = center.x, y = center.y, z = center.z, radius = radius,
					label = text(raw_zone.label, 40) and raw_zone.label or ('Zona ' .. index)
				}
			end
		end
		local stops, badStop
		if zones then
			stops = {}
			for index, zone in ipairs(zones) do
				stops[index] = { x = zone.x, y = zone.y, z = zone.z, h = 0.0 }
			end
		else
			stops, badStop = points(r.stops, 2)
			if not stops then
				return fail('invalid_stops', badStop and tostring(badStop) or nil)
			end
		end
		local perRoute = int(r.perRoute, 1, 50) or 5
		-- Passageiro: cada corrida usa duas paradas (embarque e destino).
		if perRoute * (mode == 'passenger' and 2 or 1) > #stops then
			return fail('invalid_per_route')
		end
		local pay = int(r.pay, 1, 100000)
		if not pay then
			return fail('invalid_pay')
		end
		local carry, carryOk = prop(r.carry)
		if not carryOk then
			return fail('invalid_carry')
		end
		local carryAnim, carryAnimOk = anim(r.carryAnimation)
		if not carryAnimOk then
			return fail('invalid_animation')
		end
		local peds = {}
		for _, ped in ipairs(type(r.recipients) == 'table' and r.recipients or {}) do
			if model(ped) then
				peds[#peds + 1] = ped
			end
		end
		local pickAnim, pickOk = shortAnim(r.pickAnimation)
		local dropAnim, dropOk = shortAnim(r.dropAnimation)
		if not pickOk or not dropOk then
			return fail('invalid_animation')
		end
		if (mode == 'collect' or mode == 'zone') and not carry then
			return fail('invalid_carry')
		end
		local bins = {}
		if mode == 'zone' then
			for _, name in ipairs(type(r.binModels) == 'table' and r.binModels or {}) do
				if not model(name) then
					return fail('invalid_bins')
				end
				bins[#bins + 1] = name
			end
			if #bins == 0 or #bins > 64 then
				return fail('invalid_bins')
			end
		end
		job.route = {
			mode = mode, stops = stops, perRoute = perRoute, pay = pay,
			-- Valor extra por km entre a parada anterior (ou o embarque) e esta.
			payPerKm = int(r.payPerKm, 0, 100000) or 0,
			-- Distância do jogador até a parada (passageiro: do táxi até o ponto).
			stopRadius = num(r.stopRadius, 2, 30) or nil,
			stopProp = model(r.stopProp) and r.stopProp or nil,
			dropLabel = text(r.dropLabel, 40) and r.dropLabel or 'Guardar no veículo',
			bonus = int(r.bonus, 0, 1000000) or 0,
			xp = int(r.xp, 0, 10000) or 5,
			actionLabel = text(r.actionLabel, 40) and r.actionLabel or 'Entregar',
			pickupLabel = text(r.pickupLabel, 40) and r.pickupLabel or 'Pegar a carga',
			-- O veículo do emprego precisa estar a esta distância da parada (0 = não exige).
			vehicleRange = num(r.vehicleRange, 0, 500) or 40.0,
			carry = carry, carryAnimation = carryAnim, pickAnimation = pickAnim, dropAnimation = dropAnim,
			recipients = #peds > 0 and peds or { 'a_m_y_business_01', 'a_f_y_business_02', 'a_m_m_bevhills_01' }
		}
		if zones then
			local route = job.route
			route.zones = zones
			-- Sacos a recolher em cada zona antes de seguir para a próxima.
			route.perZone = int(r.perZone, 1, 50) or 5
			-- Objetos do mapa onde dá para recolher (lixeiras, caçambas, sacos) e o tempo até a mesma lixeira encher de novo.
			route.binModels = bins
			route.binCooldown = int(r.binCooldown, 0, 86400) or 600
			-- Porta da caçamba do veículo (traseira) que precisa estar aberta para guardar.
			route.rearDoor = int(r.rearDoor, 0, 7) or 5
			route.openLabel = text(r.openLabel, 40) and r.openLabel or 'Abrir a caçamba'
			route.closeLabel = text(r.closeLabel, 40) and r.closeLabel or 'Fechar a caçamba'
		end
	end
	return job
end

-- Nível (1..#levels) para um total de XP.
function JobRules.Level(levels, xp)
	local level = 1
	for index, threshold in ipairs(levels) do
		if (xp or 0) >= threshold then
			level = index
		end
	end
	return level
end

-- XP que falta para o próximo nível (nil no último).
function JobRules.NextLevelXp(levels, xp)
	local level = JobRules.Level(levels, xp)
	return levels[level + 1]
end

-- Valor com o bônus de nível: +levelBonus por nível acima do 1, arredondado para baixo.
function JobRules.Pay(base, level, levelBonus)
	local multiplier = 1 + math.max(0, (level or 1) - 1) * (levelBonus or 0)
	return math.floor(base * multiplier)
end

function JobRules.Distance(a, b)
	local dx, dy, dz = a.x - b.x, a.y - b.y, (a.z or 0) - (b.z or 0)
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Horizontal com tolerância de altura (pontos de config têm z aproximado).
function JobRules.Near(a, b, radius, height)
	local dx, dy = a.x - b.x, a.y - b.y
	return math.sqrt(dx * dx + dy * dy) <= radius and math.abs((a.z or 0) - (b.z or 0)) <= (height or 5.0)
end

-- Tempo mínimo plausível entre dois pontos (anti-teleporte) a uma velocidade máxima em m/s.
function JobRules.MinTravelSeconds(from, to, maxSpeed)
	return JobRules.Distance(from, to) / (maxSpeed or 60.0)
end

-- Sorteia `count` paradas distintas (índices) com o gerador `random(n)` (math.random por padrão).
function JobRules.PickStops(total, count, random)
	random = random or math.random
	local pool = {}
	for index = 1, total do
		pool[index] = index
	end
	for index = total, 2, -1 do
		local swap = random(index)
		pool[index], pool[swap] = pool[swap], pool[index]
	end
	local picked = {}
	for index = 1, math.min(count, total) do
		picked[index] = pool[index]
	end
	return picked
end

-- Posição mandada pelo client (objeto do mapa mirado): números finitos dentro do mapa, ou nil.
function JobRules.ValidSpot(spot)
	if type(spot) ~= 'table' then
		return nil
	end
	local x, y, z = tonumber(spot.x), tonumber(spot.y), tonumber(spot.z)
	if not x or not y or not z or x ~= x or y ~= y or z ~= z or math.abs(x) > 10000 or math.abs(y) > 10000 or math.abs(z) > 3000 then
		return nil
	end
	return { x = x, y = y, z = z }
end

-- Sorteia a espécie de uma área de pesca: o bônus (vara + isca) aumenta o peso das raras. random() em [0, 1).
local function resolveAlgorithms()
	if type(Core) == 'table' and type(Core.Algorithms) == 'table' then
		return Core.Algorithms
	end
	if type(CoeAlgorithms) == 'table' then
		return CoeAlgorithms
	end
	if type(LoadResourceFile) == 'function' then
		local src = LoadResourceFile('coe_core', 'lib/algorithms/init.lua')
		if type(src) == 'string' and src ~= '' then
			local fn = load(src, '@@coe_core/lib/algorithms/init.lua', 't', _G)
			if fn then pcall(fn) end
		end
	elseif type(io) == 'table' and type(io.open) == 'function' then
		local candidates = {
			'../coe_core/lib/algorithms/init.lua',
			'../../coe-framework/coe_core/lib/algorithms/init.lua'
		}
		for i = 1, #candidates do
			local f = io.open(candidates[i], 'r')
			if f then
				f:close()
				pcall(dofile, candidates[i])
				break
			end
		end
	end
	return CoeAlgorithms
end

-- Constroi (ou recupera do cache por bonus) uma Tabela de Alias de Vose O(1) para as especies da zona.
function JobRules.BuildSpeciesSampler(zone, products, bonus)
	local alg = resolveAlgorithms()
	if not (alg and alg.Sampling and type(alg.Sampling.newAliasTable) == 'function') then
		return nil
	end
	zone._aliasCache = zone._aliasCache or {}
	local bonusKey = math.floor(((bonus or 0) * 1000) + 0.5)
	if zone._aliasCache[bonusKey] then
		return zone._aliasCache[bonusKey]
	end
	local items = {}
	for index, entry in ipairs(zone.species) do
		local tier = products and products[entry.id] and products[entry.id].tier or 'common'
		local weight = entry.weight * (1 + (bonus or 0) * (TIER_BOOST[tier] or 0))
		items[index] = { item = entry.id, weight = weight }
	end
	local sampler = alg.Sampling.newAliasTable(items)
	zone._aliasCache[bonusKey] = sampler
	return sampler
end

-- Calcula a rota otima em grafo 3D de paradas usando A* (A-Star) de @coe_core/lib/algorithms/graph.lua.
function JobRules.OptimalRoutePath(nodes, startId, goalId)
	local alg = resolveAlgorithms()
	if alg and alg.Graph and type(alg.Graph.astar) == 'function' then
		return alg.Graph.astar(nodes, startId, goalId)
	end
	return nil, nil
end

function JobRules.RollSpecies(zone, products, bonus, random)
	if random == nil then
		local sampler = JobRules.BuildSpeciesSampler(zone, products, bonus)
		if sampler then
			local picked = sampler:sample()
			if picked then
				return picked
			end
		end
	end
	random = random or math.random
	local total, weights = 0, {}
	for index, entry in ipairs(zone.species) do
		local tier = products[entry.id] and products[entry.id].tier or 'common'
		local weight = entry.weight * (1 + (bonus or 0) * (TIER_BOOST[tier] or 0))
		weights[index] = weight
		total = total + weight
	end
	local roll = random() * total
	for index, entry in ipairs(zone.species) do
		roll = roll - weights[index]
		if roll < 0 then
			return entry.id
		end
	end
	return zone.species[#zone.species].id
end

-- Área de pesca (índice) em que um ponto está, ou nil.
function JobRules.FishingArea(fishing, spot)
	for index, zone in ipairs(fishing and fishing.areas or {}) do
		if JobRules.Near(spot, zone, zone.radius, 120.0) then
			return index, zone
		end
	end
	return nil
end

-- Briga com o peixe (minigame): o peixe nada pela barra (0-1) e o jogador segura E para subir a faixa da vara;
-- com o peixe dentro da faixa o progresso enche, fora esvazia. Cheio fisga, vazio escapa.
-- bar: tamanho da faixa (vem da vara); fill/drain: progresso por segundo; speed: agitação do peixe (raridade).
local FIGHT = {
	common = { fill = 0.11, drain = 0.10, speed = 0.30 },
	uncommon = { fill = 0.085, drain = 0.12, speed = 0.42 },
	rare = { fill = 0.065, drain = 0.14, speed = 0.58 }
}

function JobRules.FightParams(fishing, rod, product)
	local tier = FIGHT[product and product.tier or 'common'] or FIGHT.common
	local start = 0.3
	local speed = tier.speed * ((product and product.difficulty or 0.7) / 0.7)
	local fight = {
		bar = math.min(0.6, math.max(0.2, (rod and rod.window or 0.16) * 2.2)),
		fill = tier.fill, drain = tier.drain, speed = speed, start = start,
		hookMs = math.floor((fishing and fishing.hookSeconds or 1.6) * 1000),
		maxMs = math.floor((fishing and fishing.fightSeconds or 35) * 1000)
	}
	-- Menor tempo possível de briga (peixe sempre dentro da faixa): o servidor recusa fisgadas mais rápidas.
	fight.minMs = math.floor((1 - start) / fight.fill * 1000)
	return fight
end

-- Posição do marcador do minigame (0-1, vai e volta) depois de `ms` com `speed` voltas por segundo.
function JobRules.MarkerAt(ms, speed)
	local phase = (ms / 1000 * speed) % 1
	return phase < 0.5 and phase * 2 or 2 - phase * 2
end

-- Chave de uma lixeira do mapa pela posição (arredondada a 1 m), para o cooldown entre recolhas.
function JobRules.BinKey(spot)
	return ('%d:%d:%d'):format(math.floor(spot.x + 0.5), math.floor(spot.y + 0.5), math.floor(spot.z + 0.5))
end

-- Paradas sorteadas por rota (passageiro usa duas por corrida).
function JobRules.RouteStops(route)
	return route.perRoute * (route.mode == 'passenger' and 2 or 1)
end

-- Valor base de uma parada: fixo + km percorridos desde o ponto anterior (embarque, parada ou centro).
function JobRules.StopPay(route, from, to)
	local km = (from and to) and JobRules.Distance(from, to) / 1000 or 0
	return route.pay + math.floor((route.payPerKm or 0) * km)
end

-- Parte pública da definição, enviada aos clients (sem nada que o servidor precise esconder).
function JobRules.Public(job)
	return {
		id = job.id, label = job.label, kind = job.kind, description = job.description,
		center = job.center, centerPed = job.centerPed, blip = job.blip, levels = job.levels, skills = job.skills, requires = job.requires,
		tool = job.tool, uniform = job.uniform, shop = job.shop, vehicle = job.vehicle and { model = job.vehicle.model, deposit = job.vehicle.deposit } or nil,
		gather = job.gather and {
			nodes = job.gather.nodes, nodeProp = job.gather.nodeProp, actionLabel = job.gather.actionLabel,
			seconds = job.gather.seconds, capacity = job.gather.capacity, unit = job.gather.unit, units = job.gather.units,
			animation = job.gather.animation, soil = job.gather.soil,
			products = job.gather.products, productOrder = job.gather.productOrder, defaultProduct = job.gather.defaultProduct,
			fields = job.gather.fields, world = job.gather.world, haul = job.gather.haul, process = job.gather.process,
			fishing = job.gather.fishing,
			sell = { points = job.gather.sell.points, price = job.gather.sell.price, ped = job.gather.sell.ped, label = job.gather.sell.label }
		} or nil,
		route = job.route and {
			mode = job.route.mode, perRoute = job.route.perRoute, pay = job.route.pay, payPerKm = job.route.payPerKm,
			bonus = job.route.bonus, stopRadius = job.route.stopRadius, stopProp = job.route.stopProp, dropLabel = job.route.dropLabel,
			perZone = job.route.perZone, binModels = job.route.binModels, binCooldown = job.route.binCooldown,
			rearDoor = job.route.rearDoor, openLabel = job.route.openLabel, closeLabel = job.route.closeLabel,
			actionLabel = job.route.actionLabel, pickupLabel = job.route.pickupLabel,
			carry = job.route.carry, carryAnimation = job.route.carryAnimation,
			pickAnimation = job.route.pickAnimation, dropAnimation = job.route.dropAnimation, recipients = job.route.recipients
		} or nil
	}
end
