-- Regras puras do coe_deepweb (sem natives), usadas pelo servidor e pelos testes.
DeepwebRules = {}

local SERIAL = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ'

local function trim(value)
	return (tostring(value):gsub('^%s+', ''):gsub('%s+$', ''))
end

-- Nível do equipamento (1 a 5), ou nil.
function DeepwebRules.Level(config, kind)
	local tier = config.Tiers[kind]
	return tier and tier.level or nil
end

-- Recursos com o estado para o nível: open, locked (nível insuficiente) ou soon (próxima fase).
function DeepwebRules.Features(config, level)
	local list = {}
	for _, feature in ipairs(config.Features) do
		local state = feature.soon and 'soon' or (level >= feature.level and 'open' or 'locked')
		list[#list + 1] = { id = feature.id, label = feature.label, level = feature.level, description = feature.description, state = state }
	end
	return list
end

function DeepwebRules.Allows(config, level, featureId)
	for _, feature in ipairs(config.Features) do
		if feature.id == featureId then
			return not feature.soon and level >= feature.level
		end
	end
	return false
end

-- Apelido: minúsculas, números e . _ - (sem começar/terminar com símbolo nem repetir). Devolve o nome ou nil + erro.
function DeepwebRules.Handle(config, value)
	if type(value) ~= 'string' then
		return nil, 'invalid_handle'
	end
	local name = trim(value):lower()
	local limits = config.Handles
	if #name < limits.Min or #name > limits.Max then
		return nil, 'invalid_handle'
	end
	if not name:match('^[a-z0-9][a-z0-9._%-]*[a-z0-9]$') or name:find('[._%-][._%-]') then
		return nil, 'invalid_handle'
	end
	if limits.Reserved[name] or limits.Reserved[(name:gsub('[._%-]', ''))] then
		return nil, 'handle_reserved'
	end
	return name
end

-- Senha entre min e max caracteres, sem espaços nas pontas.
function DeepwebRules.Password(min, max, value)
	if type(value) ~= 'string' then
		return nil, 'invalid_password'
	end
	local length = utf8.len(value)
	if not length or length < min or length > max or value ~= trim(value) then
		return nil, 'invalid_password'
	end
	return value
end

-- Número de série: prefixo + 8 caracteres (ex.: LT-7KQ2M9XA). rand(n) devolve 1..n.
function DeepwebRules.Serial(prefix, rand)
	local chars = {}
	for _ = 1, 8 do
		local index = rand(#SERIAL)
		chars[#chars + 1] = SERIAL:sub(index, index)
	end
	return prefix .. '-' .. table.concat(chars)
end

function DeepwebRules.IsSerial(value)
	return type(value) == 'string' and value:match('^%u%u%-[' .. SERIAL .. ']+$') ~= nil and #value == 11
end

-- Chave do aparelho (compartilhada com o coe_crypto): <tipo>:<serial ou personagem>.
function DeepwebRules.DeviceKey(kind, id)
	return kind .. ':' .. tostring(id)
end

-- Computador instalado mais próximo de (x, y, z) dentro de `maxDistance`. rigs: { { x, y, z, ... } }.
function DeepwebRules.Nearest(rigs, x, y, z, maxDistance)
	local best, bestDistance
	for _, rig in ipairs(rigs) do
		local dx, dy, dz = rig.x - x, rig.y - y, rig.z - z
		local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
		if distance <= maxDistance and (not bestDistance or distance < bestDistance) then
			best, bestDistance = rig, distance
		end
	end
	return best, bestDistance
end

-- Ponto no chão (coleta): distância horizontal e diferença de altura separadas, para o z do ponto não precisar ser exato.
function DeepwebRules.AtSpot(spot, x, y, z, maxDistance, maxHeight)
	local dx, dy = spot.x - x, spot.y - y
	return math.sqrt(dx * dx + dy * dy) <= maxDistance and math.abs(spot.z - z) <= maxHeight
end

-- Poder de mineração e energia por rodada do tipo de máquina (0 para quem não minera).
function DeepwebRules.Hash(config, kind)
	return config.Mining.Hash[kind] or 0
end

function DeepwebRules.PowerCost(config, kind)
	return config.Mining.PowerCost[kind] or 0
end

-- Máquina pronta para minerar nesta rodada? rig: { kind, mining, payout }. Devolve true ou false + motivo.
function DeepwebRules.CanMine(config, rig, contractActive)
	if DeepwebRules.Hash(config, rig.kind) <= 0 then
		return false, 'no_hash'
	end
	if not rig.mining then
		return false, 'off'
	end
	if not rig.payout or rig.payout == '' then
		return false, 'no_payout'
	end
	if not contractActive then
		return false, 'no_contract'
	end
	return true
end

-- Contato NPC: lugar atual (índice em Spots) e número da rodada, iguais para todos num mesmo momento.
function DeepwebRules.DealerRotation(config, now)
	local dealer = config.Dealer
	local count = #dealer.Spots
	if count == 0 then
		return nil, nil
	end
	local rotation = math.floor(now / (dealer.RotationMinutes * 60))
	return (rotation % count) + 1, rotation
end

-- Primeiro meio de pagamento (na ordem de Payment) com saldo suficiente. counts: [item] = quantidade.
function DeepwebRules.PickPayment(payments, counts, price)
	for _, item in ipairs(payments) do
		if (counts[item] or 0) >= price then
			return item
		end
	end
	return nil
end

-- Bloqueio por erros seguidos. state: { failures, lockedUntil }.
function DeepwebRules.Fail(limit, lockSeconds, state, now)
	state = state or { failures = 0, lockedUntil = 0 }
	state.failures = state.failures + 1
	if state.failures >= limit then
		state.failures = 0
		state.lockedUntil = now + lockSeconds
	end
	return state
end

function DeepwebRules.Locked(state, now)
	return state ~= nil and (state.lockedUntil or 0) > now
end

-- Navegador, sites, Rabbit e Deep Market------------------------------------------------------------------

local function ulen(value)
	return utf8.len(value) or #value
end

-- Texto limpo: sem caracteres de controle (quebras de linha só se `multiline`), espaços das pontas removidos e
-- no máximo `max` caracteres. Devolve o texto ou nil (vazio, inválido ou longo demais).
function DeepwebRules.Text(value, max, multiline, min)
	if type(value) ~= 'string' or not utf8.len(value) then
		return nil
	end
	local text = value:gsub('\r\n?', '\n')
	if multiline then
		text = text:gsub('[%z\1-\9\11-\31\127]', ''):gsub('\n\n\n+', '\n\n')
	else
		text = text:gsub('[%z\1-\31\127]', ' ')
	end
	text = trim(text)
	local length = ulen(text)
	if length < (min or 1) or length > max then
		return nil
	end
	return text
end

-- Endereço digitado na barra: `about:<página>`, `<nome>.onion[/caminho][?q=...]` ou, sem nada disso, uma busca.
-- Devolve { kind = 'about'|'site'|'search', page, domain, path = { ... }, query, href } ou nil.
function DeepwebRules.ParseAddress(value)
	if type(value) ~= 'string' then
		return nil
	end
	local text = trim(value)
	if text == '' or #text > 200 then
		return nil
	end
	local lower = text:lower():gsub('^https?://', ''):gsub('^onion://', '')
	local page = lower:match('^about:([a-z]+)$')
	if page then
		return { kind = 'about', page = page, href = 'about:' .. page }
	end
	local domain, rest = lower:match('^([a-z0-9%-]+%.onion)(.*)$')
	if not domain then
		return { kind = 'search', query = text, href = 'duckdark.onion/?q=' .. text }
	end
	local pathText, queryText = rest:match('^([^?]*)%??(.*)$')
	local path = {}
	for segment in (pathText or ''):gmatch('[^/]+') do
		path[#path + 1] = segment
	end
	local query = queryText and queryText:match('q=([^&]*)') or nil
	if query then
		-- A busca mantém maiúsculas e espaços do que foi digitado.
		query = text:match('[?&]q=([^&]*)') or query
		query = query:gsub('%+', ' ')
	end
	local href = domain .. (#path > 0 and ('/' .. table.concat(path, '/')) or '') .. (query and ('/?q=' .. query) or '')
	return { kind = 'site', domain = domain, path = path, query = query, href = href }
end

-- Domínio de site: `<nome>.onion`, nome com minúsculas, números e hífen (sem começar/terminar com hífen).
function DeepwebRules.Domain(config, value)
	if type(value) ~= 'string' then
		return nil, 'invalid_domain'
	end
	local domain = trim(value):lower()
	if not domain:find('%.onion$') then
		domain = domain .. '.onion'
	end
	local name = domain:match('^([a-z0-9%-]+)%.onion$')
	local limits = config.Sites
	if not name or #name < limits.DomainMin or #name > limits.DomainMax or not name:match('^[a-z0-9].*[a-z0-9]$') or name:find('%-%-') then
		return nil, 'invalid_domain'
	end
	if limits.Reserved[name] or limits.Reserved[(name:gsub('%-', ''))] then
		return nil, 'domain_reserved'
	end
	for _, site in ipairs(limits.System) do
		if site.domain == domain then
			return nil, 'domain_reserved'
		end
	end
	return domain
end

-- Comunidade do Rabbit: minúsculas, números e sublinhado.
function DeepwebRules.Slug(config, value)
	if type(value) ~= 'string' then
		return nil, 'invalid_slug'
	end
	local slug = trim(value):lower():gsub('^r/', '')
	local limits = config.Forum
	if #slug < limits.SlugMin or #slug > limits.SlugMax or not slug:match('^[a-z0-9][a-z0-9_]*$') then
		return nil, 'invalid_slug'
	end
	if config.Handles.Reserved[slug] or config.Handles.Reserved[(slug:gsub('_', ''))] then
		return nil, 'slug_reserved'
	end
	return slug
end

-- Ordenação "em alta": pontuação com peso que cai com a idade (horas).
function DeepwebRules.Hot(score, createdAt, now)
	local hours = math.max(0, (now - createdAt) / 3600)
	return (score + 1) / ((hours + 2) ^ 1.5)
end

-- Voto: 1, -1 ou 0 (tira o voto). Devolve o valor ou nil.
function DeepwebRules.VoteValue(value)
	value = math.tointeger(tonumber(value))
	if value == 1 or value == -1 or value == 0 then
		return value
	end
	return nil
end

-- Diferença na pontuação ao trocar o voto de `previous` para `value`.
function DeepwebRules.VoteDelta(previous, value)
	return (value or 0) - (previous or 0)
end

-- Comentários em árvore: { { id, parentId, ... } } -> lista com `depth` na ordem de leitura (pais antes dos filhos).
-- Filhos além de `maxDepth` ficam no último nível.
function DeepwebRules.Thread(comments, maxDepth)
	local children, roots = {}, {}
	local byId = {}
	for _, comment in ipairs(comments) do
		byId[comment.id] = comment
	end
	for _, comment in ipairs(comments) do
		local parent = comment.parentId and byId[comment.parentId]
		if parent then
			children[parent.id] = children[parent.id] or {}
			table.insert(children[parent.id], comment)
		else
			roots[#roots + 1] = comment
		end
	end
	local ordered = {}
	local function walk(list, depth)
		table.sort(list, function(a, b)
			if a.score ~= b.score then return (a.score or 0) > (b.score or 0) end
			return a.id < b.id
		end)
		for _, comment in ipairs(list) do
			comment.depth = math.min(depth, maxDepth)
			ordered[#ordered + 1] = comment
			if children[comment.id] then
				walk(children[comment.id], depth + 1)
			end
		end
	end
	walk(roots, 0)
	return ordered
end

-- Valor em moeda digitado ("1,25", "0.5", "3") -> unidades inteiras com `decimals` casas. nil se inválido.
function DeepwebRules.ParseCoin(value, decimals)
	if type(value) == 'number' then
		value = tostring(value)
	end
	if type(value) ~= 'string' then
		return nil
	end
	local text = trim(value):gsub(',', '.')
	local whole, fraction = text:match('^(%d+)%.?(%d*)$')
	if not whole or #whole > 12 or #fraction > decimals then
		return nil
	end
	fraction = fraction .. string.rep('0', decimals - #fraction)
	return math.tointeger(tonumber(whole) * (10 ^ decimals) + (tonumber(fraction) or 0))
end

-- Taxa do mercado em unidades (arredonda para baixo).
function DeepwebRules.Fee(total, bps)
	return (total * bps) // 10000
end

function DeepwebRules.Category(config, id)
	for _, category in ipairs(config.Market.Categories) do
		if category.id == id then
			return category
		end
	end
	return nil
end

-- Anúncio enviado pelo vendedor (ou pela staff). raw: { title, description, kind, category, item, count, price,
-- stock }. price em unidades. Devolve a tabela limpa ou nil + erro. O item é conferido no servidor.
function DeepwebRules.Listing(config, raw)
	local market = config.Market
	if type(raw) ~= 'table' then
		return nil, 'invalid_listing'
	end
	local title = DeepwebRules.Text(raw.title, market.TitleMax, false, market.TitleMin)
	if not title then
		return nil, 'invalid_title'
	end
	local description = raw.description == nil and '' or DeepwebRules.Text(raw.description, market.DescriptionMax, true, 0)
	if not description then
		return nil, 'invalid_description'
	end
	local kind = raw.kind == 'service' and 'service' or 'item'
	if not DeepwebRules.Category(config, raw.category) then
		return nil, 'invalid_category'
	end
	local price = math.tointeger(tonumber(raw.price))
	if not price or price < market.MinPrice or price > market.MaxPrice then
		return nil, 'invalid_price'
	end
	local stock = math.tointeger(tonumber(raw.stock))
	if not stock or stock < 0 or stock > market.MaxStock then
		return nil, 'invalid_stock'
	end
	local item, count = '', 0
	if kind == 'item' then
		item = type(raw.item) == 'string' and trim(raw.item):lower() or ''
		count = math.tointeger(tonumber(raw.count))
		if not item:match('^[a-z0-9_]+$') or #item > 48 then
			return nil, 'invalid_item'
		end
		if not count or count < 1 or count > market.MaxCountPerUnit then
			return nil, 'invalid_count'
		end
	end
	return { title = title, description = description, kind = kind, category = raw.category, item = item, count = count, price = price, stock = stock }
end

-- Pedidos ---------------------------------------------------------------------------------------------
-- Estados: paid (pago, em custódia, esperando entrega), dropped (item no ponto de coleta ou serviço marcado como
-- feito), completed (liberado ao vendedor), cancelled (devolvido ao comprador), disputed (comprador contestou o
-- serviço; a staff decide), refunded (staff devolveu) e released (staff pagou o vendedor).
-- role: buyer, seller ou system. Devolve o próximo estado ou nil + erro.
function DeepwebRules.OrderNext(config, order, action, role, now)
	local market = config.Market
	local status = order.status
	if action == 'deliver' then
		if role ~= 'seller' then return nil, 'not_seller' end
		if status ~= 'paid' then return nil, 'invalid_status' end
		return 'dropped'
	elseif action == 'collect' then
		if role ~= 'buyer' then return nil, 'not_buyer' end
		if order.kind ~= 'item' then return nil, 'invalid_status' end
		if status ~= 'dropped' then return nil, 'invalid_status' end
		return 'completed'
	elseif action == 'confirm' then
		if role ~= 'buyer' then return nil, 'not_buyer' end
		if order.kind ~= 'service' or status ~= 'dropped' then return nil, 'invalid_status' end
		return 'completed'
	elseif action == 'dispute' then
		if role ~= 'buyer' then return nil, 'not_buyer' end
		if order.kind ~= 'service' or status ~= 'dropped' then return nil, 'invalid_status' end
		return 'disputed'
	elseif action == 'cancel' then
		if status ~= 'paid' then return nil, 'invalid_status' end
		if role == 'seller' or role == 'system' then
			return 'cancelled'
		end
		if role == 'buyer' then
			if now < order.createdAt + market.DeliverHours * 3600 then
				return nil, 'too_early'
			end
			return 'cancelled'
		end
		return nil, 'forbidden'
	elseif action == 'release' then
		if role ~= 'system' then return nil, 'forbidden' end
		if status == 'dropped' and now >= (order.deliveredAt or 0) + market.AutoReleaseHours * 3600 then
			return 'completed'
		end
		return nil, 'invalid_status'
	elseif action == 'resolve_buyer' or action == 'resolve_seller' then
		if role ~= 'system' then return nil, 'forbidden' end
		if status ~= 'disputed' then return nil, 'invalid_status' end
		return action == 'resolve_buyer' and 'refunded' or 'released'
	end
	return nil, 'invalid_action'
end

-- Quem recebe a custódia ao chegar no estado: 'seller', 'buyer' ou nil (continua em custódia).
function DeepwebRules.Settlement(status)
	if status == 'completed' or status == 'released' then
		return 'seller'
	end
	if status == 'cancelled' or status == 'refunded' then
		return 'buyer'
	end
	return nil
end

-- Blocos de um site (renderizados pelo navegador, nunca HTML livre). Devolve a lista limpa ou nil + erro.
-- Tipos: heading { text }, text { text }, quote { text }, notice { text, tone }, list { items }, divider,
-- link { label, href } (endereço .onion ou about:), listing { id } (anúncio do Deep Market).
local TONES = { info = true, warn = true, danger = true, success = true }
function DeepwebRules.Blocks(config, list)
	local limits = config.Sites
	if type(list) ~= 'table' or #list > limits.MaxBlocks then
		return nil, 'invalid_blocks'
	end
	local clean = {}
	for index, block in ipairs(list) do
		if type(block) ~= 'table' then
			return nil, 'invalid_block', index
		end
		local kind = block.type
		local entry
		if kind == 'heading' then
			local text = DeepwebRules.Text(block.text, 80)
			entry = text and { type = kind, text = text }
		elseif kind == 'text' or kind == 'quote' then
			local text = DeepwebRules.Text(block.text, limits.BlockTextMax, true)
			entry = text and { type = kind, text = text }
		elseif kind == 'notice' then
			local text = DeepwebRules.Text(block.text, 300, true)
			entry = text and { type = kind, text = text, tone = TONES[block.tone] and block.tone or 'info' }
		elseif kind == 'list' then
			if type(block.items) == 'table' and #block.items >= 1 and #block.items <= limits.ListItemsMax then
				local items = {}
				for _, item in ipairs(block.items) do
					local text = DeepwebRules.Text(item, 160)
					if not text then
						items = nil
						break
					end
					items[#items + 1] = text
				end
				entry = items and { type = kind, items = items }
			end
		elseif kind == 'divider' then
			entry = { type = kind }
		elseif kind == 'link' then
			local label = DeepwebRules.Text(block.label, 60)
			local target = DeepwebRules.ParseAddress(block.href)
			entry = label and target and target.kind ~= 'search' and { type = kind, label = label, href = target.href }
		elseif kind == 'listing' then
			local id = math.tointeger(tonumber(block.id))
			entry = id and id > 0 and { type = kind, id = id }
		end
		if not entry then
			return nil, 'invalid_block', index
		end
		clean[#clean + 1] = entry
	end
	return clean
end

-- Termo de busca: 2 a 40 caracteres, para LIKE (com % e _ escapados).
function DeepwebRules.SearchTerm(value)
	local text = DeepwebRules.Text(value, 40, false, 2)
	if not text then
		return nil
	end
	return text, '%' .. text:lower():gsub('[\\%%_]', '\\%0') .. '%'
end
