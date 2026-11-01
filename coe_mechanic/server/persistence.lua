MechanicPersistence = {}

local function callDatabase(exportName, ...)
	if GetResourceState('coe_database') ~= 'started' then
		return nil, 'database_unavailable'
	end

	local response = promise.new()
	local databaseResource = exports['coe_database']
	local callArguments = { databaseResource, ... }
	callArguments[#callArguments + 1] = function(success, result, errorCode)
		response:resolve({
			success = success == true,
			result = result,
			error = errorCode
		})
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

function MechanicPersistence.Initialize()
	local migrated, errorCode = CoeMigrations.Run({
		tableName = 'coe_mechanic_schema_migrations',
		migrations = MechanicMigrations,
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

-- Retorna { [part] = installedAtMeters } já descontado o desgaste extra (pode ficar negativo: peça "mais
-- rodada" do que a quilometragem diz); peças sem linha usam a fábrica (0).
function MechanicPersistence.ListParts(vehicleId)
	local rows, errorCode = callDatabase(
		'Query',
		'SELECT part, installed_at_m, extra_wear_m FROM coe_vehicle_parts WHERE vehicle_id = ?',
		{ vehicleId }
	)
	if not rows then
		return nil, errorCode or 'database_error'
	end
	local installed = {}
	for _, row in ipairs(rows) do
		installed[row.part] = (tonumber(row.installed_at_m) or 0) - (tonumber(row.extra_wear_m) or 0)
	end
	return installed
end

-- Soma (ou desconta, nunca abaixo de zero) desgaste extra nas peças. Peça sem linha ganha a linha de fábrica.
function MechanicPersistence.AddWear(vehicleId, part, meters)
	local result, errorCode = callDatabase(
		'Execute',
		[[INSERT INTO coe_vehicle_parts (vehicle_id, part, installed_at_m, extra_wear_m) VALUES (?, ?, 0, ?)
			ON DUPLICATE KEY UPDATE extra_wear_m = GREATEST(0, CAST(extra_wear_m AS SIGNED) + ?)]],
		{ vehicleId, part, math.max(0, math.floor(meters)), math.floor(meters) }
	)
	if not result then
		return nil, errorCode or 'database_error'
	end
	return true
end

function MechanicPersistence.SavePart(vehicleId, part, installedAt)
	local result, errorCode = callDatabase(
		'Execute',
		[[INSERT INTO coe_vehicle_parts (vehicle_id, part, installed_at_m, extra_wear_m) VALUES (?, ?, ?, 0)
			ON DUPLICATE KEY UPDATE installed_at_m = VALUES(installed_at_m), extra_wear_m = 0]],
		{ vehicleId, part, math.floor(installedAt) }
	)
	if not result then
		return nil, errorCode or 'database_error'
	end
	return true
end

-- Sem linha: nil, nil. JSON inválido é tratado como erro para não sobrescrever dados.
function MechanicPersistence.FindAppearance(vehicleId)
	local rows, errorCode = callDatabase(
		'Query',
		'SELECT data FROM coe_vehicle_appearance WHERE vehicle_id = ? LIMIT 1',
		{ vehicleId }
	)
	if not rows then
		return nil, errorCode or 'database_error'
	end
	if not rows[1] then
		return nil, nil
	end
	local ok, decoded = pcall(json.decode, rows[1].data)
	if not ok or type(decoded) ~= 'table' then
		return nil, 'appearance_corrupt'
	end
	return decoded
end

function MechanicPersistence.SaveAppearance(vehicleId, appearance)
	local result, errorCode = callDatabase(
		'Execute',
		[[INSERT INTO coe_vehicle_appearance (vehicle_id, data) VALUES (?, ?)
			ON DUPLICATE KEY UPDATE data = VALUES(data)]],
		{ vehicleId, json.encode(appearance) }
	)
	if not result then
		return nil, errorCode or 'database_error'
	end
	return true
end
