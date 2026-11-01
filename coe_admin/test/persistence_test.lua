local queryRows = {}
local queryError
local executeError
local calls = {}

local function newPromise()
	local response = {}
	function response:resolve(value)
		self.value = value
	end
	return response
end

promise = { new = newPromise }
Citizen = {
	Await = function(response)
		return response.value
	end
}

local databaseResource = {
	Execute = function(_, sql, parameters, callback)
		calls[#calls + 1] = { operation = 'Execute', sql = sql, parameters = parameters }
		callback(not executeError, executeError and nil or {}, executeError)
	end,
	Query = function(_, sql, parameters, callback)
		calls[#calls + 1] = { operation = 'Query', sql = sql, parameters = parameters }
		callback(not queryError, queryRows, queryError)
	end
}

exports = {
	coe_database = databaseResource
}

GetResourceState = function(resourceName)
	return resourceName == 'coe_database' and 'started' or 'stopped'
end

local function loadFramework(path)
	local candidates = {
		'../' .. path,
		'../tools/compat/' .. path,
		'../[coe-framework]/' .. path,
		'../../coe-framework/' .. path
	}
	for _, c in ipairs(candidates) do
		local f = io.open(c, 'r')
		if f then f:close() return dofile(c) end
	end
	error('Cannot find framework file: ' .. path)
end

loadFramework('coe_core/lib/migrations.lua')
dofile('server/migrations.lua')
dofile('server/persistence.lua')

local function assertEqual(actual, expected, message)
	if actual ~= expected then
		error(('%s: expected %s, got %s'):format(message, tostring(expected), tostring(actual)))
	end
end

local initialized, initializeError = AdminPersistence.Initialize()
assertEqual(initialized, true, 'initialize staff schema')
assertEqual(initializeError, nil, 'successful initialization has no error')
assertEqual(calls[1].operation, 'Execute', 'schema uses execute')
assertEqual(calls[1].sql:find('coe_admin_schema_migrations', 1, true) ~= nil, true,
	'initialization creates the migration table first')
local createdStaffTable = false
for _, call in ipairs(calls) do
	if call.sql:find('CREATE TABLE IF NOT EXISTS coe_admin_staff', 1, true) then
		createdStaffTable = true
	end
end
assertEqual(createdStaffTable, true, 'initialization creates staff table')

queryRows = {
	{ identifier_value = 'license:abc123', role_name = 'admin' },
	{ identifier_value = 'license:def456', role_name = 'moderator' }
}
local staff, loadError = AdminPersistence.Load()
assertEqual(loadError, nil, 'successful load has no error')
assertEqual(staff['license:abc123'].role, 'admin', 'load maps the role')
assertEqual(staff['license:def456'].role, 'moderator', 'load returns every role')

local saved, saveError = AdminPersistence.SetRole('license:abc123', 'moderator')
assertEqual(saved, true, 'save staff role')
assertEqual(saveError, nil, 'successful save has no error')
assertEqual(calls[#calls].parameters[1], 'license:abc123', 'save binds the identifier')
assertEqual(calls[#calls].parameters[2], 'moderator', 'save binds the role')

local removed, removeError = AdminPersistence.RemoveRole('license:abc123')
assertEqual(removed, true, 'remove staff role')
assertEqual(removeError, nil, 'successful removal has no error')
assertEqual(calls[#calls].parameters[1], 'license:abc123', 'remove binds the identifier')

queryError = 'database_not_ready'
local failedLoad, failedLoadError = AdminPersistence.Load()
assertEqual(failedLoad, nil, 'failed query returns no staff data')
assertEqual(failedLoadError, queryError, 'failed query exposes its error')

queryError = nil
executeError = 'database_not_ready'
local failedSave, failedSaveError = AdminPersistence.SetRole('license:abc123', 'admin')
assertEqual(failedSave, false, 'failed write is rejected')
assertEqual(failedSaveError, executeError, 'failed write exposes its error')

print('admin persistence tests passed')
