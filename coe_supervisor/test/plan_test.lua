dofile('plan.lua')

local function assertEqual(actual, expected, message)
	if actual ~= expected then
		error(('%s: expected %s, got %s'):format(message, tostring(expected), tostring(actual)))
	end
end

local catalog = { coe_core = { category = 'core', critical = true }, coe_admin = { category = 'administration' } }
local category, critical = SupervisorPlan.Meta('coe_core', catalog, 1, 6)
assertEqual(category, 'core', 'categoria do catalogo')
assertEqual(critical, true, 'critico do catalogo')
category, critical = SupervisorPlan.Meta('coe_admin', catalog, 5, 6)
assertEqual(critical, false, 'abaixo do limite nao e critico')
category, critical = SupervisorPlan.Meta('coe_admin', catalog, 6, 6)
assertEqual(critical, true, 'reinicio grande e critico')
category = SupervisorPlan.Meta('x', catalog, 1, 6)
assertEqual(category, 'other', 'fora do catalogo')

local function join(list)
	return table.concat(list, ',')
end

local managed = { 'coe_logging', 'coe_database', 'coe_core', 'coe_inventory', 'coe_admin', 'coe_notify' }
local function graph()
	return {
		coe_logging = { state = 'started', dependencies = {} },
		coe_notify = { state = 'started', dependencies = {} },
		coe_database = { state = 'started', dependencies = { 'coe_logging' } },
		coe_core = { state = 'started', dependencies = { 'coe_database', 'coe_logging', 'coe_notify' } },
		coe_inventory = { state = 'started', dependencies = { 'coe_core', 'coe_database', 'spawnmanager' } },
		coe_admin = { state = 'started', dependencies = { 'coe_core', 'coe_inventory' } },
		docs = { state = 'started', dependencies = { 'coe_core' } },
		spawnmanager = { state = 'started', dependencies = {} },
		idle = { state = 'stopped', dependencies = { 'coe_core' } }
	}
end

local plan = SupervisorPlan.Build('coe_inventory', graph(), managed)
assertEqual(join(plan.start), 'coe_inventory,coe_admin', 'inventory restarts with its dependents')
assertEqual(join(plan.stop), 'coe_admin,coe_inventory', 'stop is the reverse order')

plan = SupervisorPlan.Build('coe_core', graph(), managed)
assertEqual(join(plan.start), 'coe_core,coe_inventory,coe_admin,docs', 'core cascades in dependency order')
assertEqual(join(plan.stop), 'docs,coe_admin,coe_inventory,coe_core', 'core stop order')
assertEqual(join(plan.unmanaged), 'docs', 'unmanaged dependents are reported')

plan = SupervisorPlan.Build('coe_logging', graph(), managed)
assertEqual(plan.start[1], 'coe_logging', 'base starts first')
assertEqual(plan.start[2], 'coe_database', 'then its direct dependent')
assertEqual(#plan.start, 6, 'every started dependent is included, stopped ones are not')

plan = SupervisorPlan.Build('coe_admin', graph(), managed)
assertEqual(join(plan.start), 'coe_admin', 'leaf restarts alone')

local stopped = graph()
stopped.coe_inventory.state = 'stopped'
plan = SupervisorPlan.Build('coe_inventory', stopped, managed)
assertEqual(join(plan.start), 'coe_inventory,coe_admin', 'stopped target is started again')
assertEqual(join(plan.stop), 'coe_admin', 'only started resources are stopped')

local missing, err = SupervisorPlan.Build('docs', graph(), managed)
assertEqual(missing, nil, 'unmanaged target refused')
assertEqual(err, 'resource_not_managed', 'unmanaged target error')
missing, err = SupervisorPlan.Build('nope', graph(), managed)
assertEqual(err, 'resource_not_managed', 'unknown target error')
missing, err = SupervisorPlan.Build(nil, graph(), managed)
assertEqual(err, 'resource_not_managed', 'invalid target error')

local cyclic = graph()
cyclic.coe_logging.dependencies = { 'coe_database' }
missing, err = SupervisorPlan.Build('coe_logging', cyclic, managed)
assertEqual(err, 'dependency_cycle', 'cycle detected')

print('supervisor plan tests passed')
