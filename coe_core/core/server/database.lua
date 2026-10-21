local function invoke(exportName, arguments)
	if GetResourceState('coe_database') ~= 'started' then
		return false, 'database_unavailable'
	end

	local databaseResource = exports['coe_database']
	local export = databaseResource[exportName]
	local ok, errorMessage = pcall(function()
		export(databaseResource, table.unpack(arguments))
	end)
	if not ok then
		return false, 'database_unavailable'
	end

	return true
end

local function run(exportName, sql, parameters, callback)
	if not IsDuplicityVersion() then
		return false, 'server_only'
	end
	if type(sql) ~= 'string' or type(parameters) ~= 'table' then
		return false, 'invalid_arguments'
	end
	if type(callback) ~= 'function' then
		return false, 'invalid_callback'
	end

	return invoke(exportName, {
		sql,
		parameters,
		function(success, result, errorCode)
			if success ~= true then
				callback(false, nil, type(errorCode) == 'string' and errorCode or 'database_error')
				return
			end
			callback(true, result)
		end
	})
end

function Core.Database.Query(sql, parameters, callback)
	return run('Query', sql, parameters, callback)
end

function Core.Database.Execute(sql, parameters, callback)
	return run('Execute', sql, parameters, callback)
end

function Core.Database.Transaction(statements, callback)
	if not IsDuplicityVersion() then
		return false, 'server_only'
	end
	if type(statements) ~= 'table' then
		return false, 'invalid_arguments'
	end
	if type(callback) ~= 'function' then
		return false, 'invalid_callback'
	end

	return invoke('Transaction', {
		statements,
		function(success, result, errorCode)
			if success ~= true then
				callback(false, nil, type(errorCode) == 'string' and errorCode or 'database_error')
				return
			end
			callback(true, result)
		end
	})
end

function Core.Database.IsReady()
	if not IsDuplicityVersion() or GetResourceState('coe_database') ~= 'started' then
		return false, 'database_unavailable'
	end

	local databaseResource = exports['coe_database']
	local ok, ready = pcall(function()
		return databaseResource:IsReady()
	end)
	if not ok then
		return false, 'database_unavailable'
	end

	return ready == true
end
