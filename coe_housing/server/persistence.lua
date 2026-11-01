HousingPersistence = {}

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

function HousingPersistence.Initialize()
	local migrated, errorCode = CoeMigrations.Run({
		tableName = 'coe_housing_schema_migrations',
		migrations = HousingMigrations,
		execute = function(sql, parameters)
			return callDatabase('Execute', sql, parameters)
		end,
		query = function(sql, parameters)
			return callDatabase('Query', sql, parameters)
		end
	})
	if not migrated then
		return false, errorCode
	end
	return true
end

local function run(sql, parameters)
	local result, errorCode = callDatabase('Execute', sql, parameters)
	if not result then
		return nil, errorCode or 'database_error'
	end
	return result
end

function HousingPersistence.ListProperties()
	local rows, errorCode = callDatabase('Query', 'SELECT property_id, config FROM coe_housing_registry ORDER BY property_id', {})
	if not rows then
		return nil, errorCode or 'database_error'
	end
	local list = {}
	for _, row in ipairs(rows) do
		local decoded = type(row.config) == 'string' and json.decode(row.config) or row.config
		if type(decoded) == 'table' then
			decoded.id = tostring(row.property_id)
			list[#list + 1] = decoded
		end
	end
	return list
end

function HousingPersistence.SaveProperty(property)
	local stored = {}
	for key, value in pairs(property) do
		if key ~= 'id' then
			stored[key] = value
		end
	end
	return run([[
		INSERT INTO coe_housing_registry (property_id, config) VALUES (?, ?)
		ON DUPLICATE KEY UPDATE config = VALUES(config)
	]], { property.id, json.encode(stored) })
end

function HousingPersistence.DeleteProperty(propertyId)
	return run('DELETE FROM coe_housing_registry WHERE property_id = ?', { propertyId })
end

function HousingPersistence.ListThumbs()
	local rows, errorCode = callDatabase('Query', 'SELECT interior_id, image FROM coe_housing_interior_thumbs', {})
	if not rows then
		return nil, errorCode or 'database_error'
	end
	local map = {}
	for _, row in ipairs(rows) do
		map[tostring(row.interior_id)] = tostring(row.image)
	end
	return map
end

function HousingPersistence.SaveThumb(interiorId, image)
	return run([[
		INSERT INTO coe_housing_interior_thumbs (interior_id, image) VALUES (?, ?)
		ON DUPLICATE KEY UPDATE image = VALUES(image)
	]], { interiorId, image })
end

function HousingPersistence.ListTenancies()
	local rows, errorCode = callDatabase('Query',
		'SELECT id, property_id, unit, character_id, cycle_days, daily_rate, paid_until FROM coe_housing_tenancies', {})
	if not rows then
		return nil, errorCode or 'database_error'
	end
	local list = {}
	for _, row in ipairs(rows) do
		list[#list + 1] = {
			id = tonumber(row.id), propertyId = tostring(row.property_id), unit = tonumber(row.unit),
			characterId = tostring(row.character_id), cycleDays = tonumber(row.cycle_days),
			dailyRate = tonumber(row.daily_rate), paidUntil = tonumber(row.paid_until)
		}
	end
	return list
end

-- Devolve o contrato criado ou nil, código (`ER_DUP_ENTRY` quando a unidade ou o morador já existe).
function HousingPersistence.InsertTenancy(propertyId, unit, characterId, cycleDays, dailyRate, paidUntil)
	local result, errorCode = run([[
		INSERT INTO coe_housing_tenancies (property_id, unit, character_id, cycle_days, daily_rate, paid_until)
		VALUES (?, ?, ?, ?, ?, ?)
	]], { propertyId, unit, characterId, cycleDays, dailyRate, paidUntil })
	if not result then
		return nil, errorCode
	end
	return {
		id = tonumber(result.insertId), propertyId = propertyId, unit = unit, characterId = characterId,
		cycleDays = cycleDays, dailyRate = dailyRate, paidUntil = paidUntil
	}
end

function HousingPersistence.UpdatePaidUntil(tenancyId, paidUntil)
	return run('UPDATE coe_housing_tenancies SET paid_until = ? WHERE id = ?', { paidUntil, tenancyId })
end

function HousingPersistence.DeleteTenancy(tenancyId)
	return run('DELETE FROM coe_housing_tenancies WHERE id = ?', { tenancyId })
end

-- Marca o personagem como já atendido pelo imóvel inicial; true só na primeira vez.
function HousingPersistence.ClaimGrant(characterId)
	local result, errorCode = run('INSERT IGNORE INTO coe_housing_grants (character_id) VALUES (?)', { characterId })
	if not result then
		return nil, errorCode
	end
	return (result.affectedRows or 0) == 1
end

-- Quem está dentro de um interior; sobrevive a logout e reinício para o retorno ao mesmo lugar.
-- `lease` = true quando o id é de um contrato comercial (coe_housing_leases).
function HousingPersistence.SetPresence(characterId, tenancyId, propertyId, lease)
	return run([[
		INSERT INTO coe_housing_presence (character_id, tenancy_id, property_id, lease) VALUES (?, ?, ?, ?)
		ON DUPLICATE KEY UPDATE tenancy_id = VALUES(tenancy_id), property_id = VALUES(property_id), lease = VALUES(lease)
	]], { characterId, tenancyId, propertyId, lease == true and 1 or 0 })
end

function HousingPersistence.ClearPresence(characterId)
	return run('DELETE FROM coe_housing_presence WHERE character_id = ?', { characterId })
end

function HousingPersistence.GetPresence(characterId)
	local rows, errorCode = callDatabase('Query',
		'SELECT tenancy_id, property_id, lease FROM coe_housing_presence WHERE character_id = ?', { characterId })
	if not rows then
		return nil, errorCode or 'database_error'
	end
	local row = rows[1]
	if not row then
		return false
	end
	return { tenancyId = tonumber(row.tenancy_id), propertyId = tostring(row.property_id), lease = tonumber(row.lease) == 1 or row.lease == true }
end

-- Contratos comerciais: o inquilino é um negócio (businessId), pago pelo caixa da sociedade. cycle_days 0 = cedido pelo admin.
function HousingPersistence.ListLeases()
	local rows, errorCode = callDatabase('Query',
		'SELECT id, property_id, unit, business_id, cycle_days, daily_rate, paid_until FROM coe_housing_leases', {})
	if not rows then
		return nil, errorCode or 'database_error'
	end
	local list = {}
	for _, row in ipairs(rows) do
		list[#list + 1] = {
			id = tonumber(row.id), propertyId = tostring(row.property_id), unit = tonumber(row.unit),
			businessId = tostring(row.business_id), cycleDays = tonumber(row.cycle_days),
			dailyRate = tonumber(row.daily_rate), paidUntil = tonumber(row.paid_until)
		}
	end
	return list
end

function HousingPersistence.InsertLease(propertyId, unit, businessId, cycleDays, dailyRate, paidUntil)
	local result, errorCode = run([[
		INSERT INTO coe_housing_leases (property_id, unit, business_id, cycle_days, daily_rate, paid_until)
		VALUES (?, ?, ?, ?, ?, ?)
	]], { propertyId, unit, businessId, cycleDays, dailyRate, paidUntil })
	if not result then
		return nil, errorCode
	end
	return {
		id = tonumber(result.insertId), propertyId = propertyId, unit = unit, businessId = businessId,
		cycleDays = cycleDays, dailyRate = dailyRate, paidUntil = paidUntil
	}
end

function HousingPersistence.UpdateLeasePaidUntil(leaseId, paidUntil)
	return run('UPDATE coe_housing_leases SET paid_until = ? WHERE id = ?', { paidUntil, leaseId })
end

function HousingPersistence.DeleteLease(leaseId)
	return run('DELETE FROM coe_housing_leases WHERE id = ?', { leaseId })
end

function HousingPersistence.ReleaseGrant(characterId)
	return run('DELETE FROM coe_housing_grants WHERE character_id = ?', { characterId })
end
