AmzgPersistence = {}

local function callDatabase(exportName, ...)
	if GetResourceState('coe_database') ~= 'started' then
		return nil, 'database_unavailable'
	end
	local response = promise.new()
	local databaseResource = exports['coe_database']
	local callArguments = { databaseResource, ... }
	callArguments[#callArguments + 1] = function(success, result, errorCode)
		response:resolve({ success = success == true, result = result, error = errorCode })
	end
	local dispatched = pcall(function()
		databaseResource[exportName](table.unpack(callArguments))
	end)
	if not dispatched then
		return nil, 'database_unavailable'
	end
	local result = Citizen.Await(response)
	if not result.success then
		return nil, result.error or 'database_error'
	end
	return result.result
end

local function query(sql, parameters)
	return callDatabase('Query', sql, parameters or {})
end

local function execute(sql, parameters)
	return callDatabase('Execute', sql, parameters or {})
end

function AmzgPersistence.Initialize()
	return CoeMigrations.Run({
		tableName = 'coe_amzg_schema_migrations',
		migrations = AmzgMigrations,
		execute = execute,
		query = query
	})
end

-- Catálogo ------------------------------------------------------------------------------------------

local function truthy(value)
	return value == true or tonumber(value) == 1
end

function AmzgPersistence.Products()
	local rows, errorCode = query('SELECT id, item, label, category, price, active, sort, promo_price, promo_until, featured, banner_text FROM coe_amzg_products ORDER BY sort, id')
	if not rows then
		return nil, errorCode
	end
	local list = {}
	for _, row in ipairs(rows) do
		list[#list + 1] = {
			id = tonumber(row.id), item = tostring(row.item), label = tostring(row.label), category = tostring(row.category),
			price = tonumber(row.price) or 0, active = truthy(row.active), sort = tonumber(row.sort) or 0,
			promoPrice = math.tointeger(tonumber(row.promo_price)) or 0, promoUntil = math.tointeger(tonumber(row.promo_until)) or 0,
			featured = truthy(row.featured), bannerText = row.banner_text and tostring(row.banner_text) or ''
		}
	end
	return list
end

function AmzgPersistence.InsertProduct(product)
	local result, errorCode = execute('INSERT INTO coe_amzg_products (item, label, category, price, active, sort, promo_price, promo_until, featured, banner_text) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
		product.item, product.label, product.category, product.price, product.active and 1 or 0, product.sort,
		product.promoPrice or 0, product.promoUntil or 0, product.featured and 1 or 0, product.bannerText or ''
	})
	if not result then
		return nil, errorCode
	end
	return tonumber(result.insertId)
end

function AmzgPersistence.UpdateProduct(id, product)
	return execute('UPDATE coe_amzg_products SET item = ?, label = ?, category = ?, price = ?, active = ?, sort = ?, promo_price = ?, promo_until = ?, featured = ?, banner_text = ? WHERE id = ?', {
		product.item, product.label, product.category, product.price, product.active and 1 or 0, product.sort,
		product.promoPrice or 0, product.promoUntil or 0, product.featured and 1 or 0, product.bannerText or '', id
	})
end

function AmzgPersistence.DeleteProduct(id)
	return execute('DELETE FROM coe_amzg_products WHERE id = ?', { id })
end

-- Pedidos -------------------------------------------------------------------------------------------

local COLUMNS = 'id, character_id, property_id, owner, address_label, items, total, shipping_fee, shipping, card_id, status, created_at, deliver_at, delivered_at'

local function orderFromRow(row)
	local items = type(row.items) == 'string' and json.decode(row.items) or nil
	return {
		id = tonumber(row.id), characterId = tostring(row.character_id), propertyId = tostring(row.property_id), owner = tostring(row.owner),
		addressLabel = tostring(row.address_label), items = type(items) == 'table' and items or {}, total = tonumber(row.total) or 0,
		fee = tonumber(row.shipping_fee) or 0, shipping = tostring(row.shipping), cardId = tonumber(row.card_id), status = tostring(row.status),
		createdAt = tonumber(row.created_at) or 0, deliverAt = tonumber(row.deliver_at) or 0, deliveredAt = tonumber(row.delivered_at)
	}
end

local function orders(sql, parameters)
	local rows, errorCode = query(sql, parameters)
	if not rows then
		return nil, errorCode
	end
	local list = {}
	for _, row in ipairs(rows) do
		list[#list + 1] = orderFromRow(row)
	end
	return list
end

function AmzgPersistence.InsertOrder(order)
	local result, errorCode = execute([[
		INSERT INTO coe_amzg_orders (character_id, property_id, owner, address_label, items, total, shipping_fee, shipping, card_id, status, created_at, deliver_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?, ?)
	]], {
		order.characterId, order.propertyId, order.owner, order.addressLabel, json.encode(order.items), order.total, order.fee,
		order.shipping, order.cardId, order.createdAt, order.deliverAt
	})
	if not result then
		return nil, errorCode
	end
	return tonumber(result.insertId)
end

function AmzgPersistence.Order(id)
	local list, errorCode = orders('SELECT ' .. COLUMNS .. ' FROM coe_amzg_orders WHERE id = ?', { id })
	if not list then
		return nil, errorCode
	end
	return list[1] or false
end

function AmzgPersistence.CharacterOrders(characterId, limit)
	return orders(('SELECT ' .. COLUMNS .. ' FROM coe_amzg_orders WHERE character_id = ? ORDER BY id DESC LIMIT %d'):format(math.floor(limit)), { characterId })
end

function AmzgPersistence.PendingCount(characterId)
	local rows, errorCode = query("SELECT COUNT(*) AS total FROM coe_amzg_orders WHERE character_id = ? AND status = 'pending'", { characterId })
	if not rows then
		return nil, errorCode
	end
	return rows[1] and tonumber(rows[1].total) or 0
end

function AmzgPersistence.DueOrders(now, limit)
	return orders(("SELECT " .. COLUMNS .. " FROM coe_amzg_orders WHERE status = 'pending' AND deliver_at <= ? ORDER BY deliver_at LIMIT %d"):format(math.floor(limit)), { now })
end

-- Caixas entregues e ainda não esvaziadas num espaço, na ordem da entrega (define a posição de cada uma).
function AmzgPersistence.DeliveredInSpace(propertyId, owner)
	return orders("SELECT " .. COLUMNS .. " FROM coe_amzg_orders WHERE property_id = ? AND owner = ? AND status = 'delivered' ORDER BY delivered_at, id", { propertyId, owner })
end

-- Troca o status só se ainda estiver em `from` (evita entregar ou estornar duas vezes). Devolve true se aplicou.
function AmzgPersistence.Transition(id, from, to, deliveredAt)
	local sql, parameters = 'UPDATE coe_amzg_orders SET status = ? WHERE id = ? AND status = ?', { to, id, from }
	if deliveredAt then
		sql, parameters = 'UPDATE coe_amzg_orders SET status = ?, delivered_at = ? WHERE id = ? AND status = ?', { to, deliveredAt, id, from }
	end
	local result, errorCode = execute(sql, parameters)
	if not result then
		return nil, errorCode
	end
	return (tonumber(result.affectedRows) or 0) > 0
end
