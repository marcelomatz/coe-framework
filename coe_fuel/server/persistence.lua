FuelPersistence = {}

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

function FuelPersistence.Initialize()
	return CoeMigrations.Run({
		tableName = 'coe_fuel_schema_migrations',
		migrations = FuelMigrations,
		execute = execute,
		query = query
	})
end

-- Tanque de um veículo registrado: { engine, capacity, tank } ou nil (sem linha); nil + erro em falha.
function FuelPersistence.LoadVehicle(vehicleId)
	local rows, errorCode = query('SELECT engine, capacity, regular, premium, ethanol, diesel FROM coe_fuel_vehicles WHERE vehicle_id = ? LIMIT 1', { vehicleId })
	if not rows then
		return nil, errorCode
	end
	local row = rows[1]
	if not row then
		return nil
	end
	return {
		engine = row.engine, capacity = tonumber(row.capacity) or 0,
		tank = { regular = tonumber(row.regular) or 0, premium = tonumber(row.premium) or 0, ethanol = tonumber(row.ethanol) or 0, diesel = tonumber(row.diesel) or 0 }
	}
end

function FuelPersistence.SaveVehicle(vehicleId, engine, capacity, tank)
	return execute([[
		INSERT INTO coe_fuel_vehicles (vehicle_id, engine, capacity, regular, premium, ethanol, diesel, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
		ON DUPLICATE KEY UPDATE engine = VALUES(engine), capacity = VALUES(capacity), regular = VALUES(regular), premium = VALUES(premium),
			ethanol = VALUES(ethanol), diesel = VALUES(diesel), updated_at = VALUES(updated_at)
	]], { vehicleId, engine, capacity, tank.regular or 0, tank.premium or 0, tank.ethanol or 0, tank.diesel or 0, os.time() })
end

-- Todos os tanques de posto: litros { [negócio] = { [combustível] = litros } } e níveis (mesma forma).
function FuelPersistence.Tanks()
	local rows, errorCode = query('SELECT business_id, fuel, liters, level FROM coe_fuel_tanks', {})
	if not rows then
		return nil, errorCode
	end
	local out, levels = {}, {}
	for _, row in ipairs(rows) do
		out[row.business_id] = out[row.business_id] or {}
		out[row.business_id][row.fuel] = tonumber(row.liters) or 0
		levels[row.business_id] = levels[row.business_id] or {}
		levels[row.business_id][row.fuel] = tonumber(row.level) or 1
	end
	return out, nil, levels
end

function FuelPersistence.SaveTank(businessId, fuel, liters, level)
	return execute([[
		INSERT INTO coe_fuel_tanks (business_id, fuel, liters, level, updated_at) VALUES (?, ?, ?, ?, ?)
		ON DUPLICATE KEY UPDATE liters = VALUES(liters), level = VALUES(level), updated_at = VALUES(updated_at)
	]], { businessId, fuel, liters, level or 1, os.time() })
end

-- Preços dos donos: { [negócio] = { [combustível] = preço } }.
function FuelPersistence.Prices()
	local rows, errorCode = query('SELECT business_id, fuel, price FROM coe_fuel_prices', {})
	if not rows then
		return nil, errorCode
	end
	local out = {}
	for _, row in ipairs(rows) do
		out[row.business_id] = out[row.business_id] or {}
		out[row.business_id][row.fuel] = math.tointeger(tonumber(row.price))
	end
	return out
end

function FuelPersistence.SavePrice(businessId, fuel, price)
	if price == nil then
		return execute('DELETE FROM coe_fuel_prices WHERE business_id = ? AND fuel = ?', { businessId, fuel })
	end
	return execute([[
		INSERT INTO coe_fuel_prices (business_id, fuel, price, updated_at) VALUES (?, ?, ?, ?)
		ON DUPLICATE KEY UPDATE price = VALUES(price), updated_at = VALUES(updated_at)
	]], { businessId, fuel, price, os.time() })
end

-- Frota: { [vehicleId] = { business, tier, cargo } }.
function FuelPersistence.Fleet()
	local rows, errorCode = query('SELECT vehicle_id, business_id, tier, regular, premium, ethanol, diesel FROM coe_fuel_fleet', {})
	if not rows then
		return nil, errorCode
	end
	local out = {}
	for _, row in ipairs(rows) do
		out[tostring(row.vehicle_id)] = {
			business = row.business_id, tier = tonumber(row.tier) or 1,
			cargo = { regular = tonumber(row.regular) or 0, premium = tonumber(row.premium) or 0, ethanol = tonumber(row.ethanol) or 0, diesel = tonumber(row.diesel) or 0 }
		}
	end
	return out
end

function FuelPersistence.SaveFleet(vehicleId, entry)
	local cargo = entry.cargo or {}
	return execute([[
		INSERT INTO coe_fuel_fleet (vehicle_id, business_id, tier, regular, premium, ethanol, diesel, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
		ON DUPLICATE KEY UPDATE regular = VALUES(regular), premium = VALUES(premium), ethanol = VALUES(ethanol), diesel = VALUES(diesel)
	]], { vehicleId, entry.business, entry.tier, cargo.regular or 0, cargo.premium or 0, cargo.ethanol or 0, cargo.diesel or 0, os.time() })
end

-- Histórico do posto: litros vendidos como posto de jogador (requisito dos upgrades) e faturamento de hoje e 7 dias.
function FuelPersistence.Stats(businessId, dayStart, weekStart)
	local rows, errorCode = query([[
		SELECT
			COALESCE(SUM(CASE WHEN mode = 'player' THEN liters ELSE 0 END), 0) AS sold,
			COALESCE(SUM(CASE WHEN created_at >= ? THEN total ELSE 0 END), 0) AS today,
			COALESCE(SUM(CASE WHEN created_at >= ? THEN total ELSE 0 END), 0) AS week,
			COALESCE(SUM(CASE WHEN created_at >= ? THEN liters ELSE 0 END), 0) AS week_liters
		FROM coe_fuel_sales WHERE business_id = ?
	]], { dayStart, weekStart, weekStart, businessId })
	if not rows then
		return nil, errorCode
	end
	local row = rows[1] or {}
	return { sold = tonumber(row.sold) or 0, today = tonumber(row.today) or 0, week = tonumber(row.week) or 0, weekLiters = tonumber(row.week_liters) or 0 }
end

function FuelPersistence.RecordSale(sale)
	return execute([[
		INSERT INTO coe_fuel_sales (business_id, station_id, character_id, fuel, liters, total, method, target, mode, created_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	]], { sale.businessId, sale.stationId, sale.characterId, sale.fuel, sale.liters, sale.total, sale.method, sale.target, sale.mode, sale.at })
end
