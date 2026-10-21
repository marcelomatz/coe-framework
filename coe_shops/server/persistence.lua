ShopsPersistence = {}

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

local function int(value)
	return math.tointeger(tonumber(value))
end

function ShopsPersistence.Initialize()
	return CoeMigrations.Run({
		tableName = 'coe_shops_schema_migrations',
		migrations = ShopsMigrations,
		execute = execute,
		query = query
	})
end

-- Todas as prateleiras: { [negócio] = { [produto] = { quantity, price } } }; nil em erro.
function ShopsPersistence.Shelves()
	local rows, errorCode = query('SELECT business_id, product_id, quantity, price FROM coe_shops_shelves', {})
	if not rows then
		return nil, errorCode
	end
	local out = {}
	for _, row in ipairs(rows) do
		out[row.business_id] = out[row.business_id] or {}
		out[row.business_id][row.product_id] = { quantity = int(row.quantity) or 0, price = int(row.price) }
	end
	return out
end

function ShopsPersistence.SaveShelf(businessId, productId, shelf)
	return execute([[
		INSERT INTO coe_shops_shelves (business_id, product_id, quantity, price, updated_at) VALUES (?, ?, ?, ?, ?)
		ON DUPLICATE KEY UPDATE quantity = VALUES(quantity), price = VALUES(price), updated_at = VALUES(updated_at)
	]], { businessId, productId, shelf.quantity or 0, shelf.price, os.time() })
end

function ShopsPersistence.RecordSale(sale)
	return execute([[
		INSERT INTO coe_shops_sales (business_id, character_id, mode, method, total, units, lines_json, created_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?)
	]], { sale.businessId, sale.characterId, sale.mode, sale.method, sale.total, sale.units, sale.lines, sale.at })
end

-- Últimas vendas de uma loja e os totais de hoje (desde `dayStart`) e dos últimos 7 dias.
function ShopsPersistence.Report(businessId, limit, dayStart, weekStart)
	limit = math.max(1, math.min(100, math.floor(tonumber(limit) or 30)))
	local rows, errorCode = query(([[
		SELECT method, total, units, lines_json, created_at FROM coe_shops_sales
		WHERE business_id = ? ORDER BY created_at DESC, id DESC LIMIT %d
	]]):format(limit), { businessId })
	if not rows then
		return nil, errorCode
	end
	local totals, totalsError = query([[
		SELECT
			COALESCE(SUM(CASE WHEN created_at >= ? THEN total ELSE 0 END), 0) AS today,
			COALESCE(SUM(total), 0) AS week, COUNT(*) AS sales
		FROM coe_shops_sales WHERE business_id = ? AND created_at >= ?
	]], { dayStart, businessId, weekStart })
	if not totals then
		return nil, totalsError
	end
	local sales = {}
	for _, row in ipairs(rows) do
		sales[#sales + 1] = {
			method = row.method, total = int(row.total) or 0, units = int(row.units) or 0, lines = row.lines_json,
			at = int(row.created_at) or 0
		}
	end
	local t = totals[1] or {}
	return { sales = sales, today = int(t.today) or 0, week = int(t.week) or 0, weekSales = int(t.sales) or 0 }
end
