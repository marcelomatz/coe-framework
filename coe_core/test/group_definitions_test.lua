dofile([=[core/shared/bootstrap.lua]=])
dofile([=[core/shared/functions.lua]=])
dofile([=[core/server/group_definitions.lua]=])
dofile([=[core/server/group_repository.lua]=])
dofile([=[config/groups.lua]=])

local function assertEqual(actual, expected, message)
	if actual ~= expected then
		error(('%s: expected %s, got %s'):format(message or 'assertEqual', tostring(expected), tostring(actual)))
	end
end

local function validConfig()
	return {
		Types = { 'job', 'gang' },
		Groups = {
			police = { type = 'job', label = 'Polícia', grades = { [0] = { label = 'Cadete' }, [2] = { label = 'Chefe' }, [1] = { label = 'Oficial' } } },
			ballas = { type = 'gang', label = 'Ballas', grades = { [0] = { label = 'Membro' } } }
		}
	}
end

-- O arquivo de configuração entregue é válido.
assertEqual(Core.Groups.SetDefinitions(CoeGroupsConfig), true, 'shipped config is valid')

assertEqual(Core.Groups.SetDefinitions(validConfig()), true, 'valid config accepted')
local list = Core.Groups.List()
assertEqual(#list, 2, 'groups listed')
assertEqual(list[1].name, 'ballas', 'list is sorted by name')
local police = Core.Groups.Get('police')
assertEqual(police.type, 'job', 'group type')
assertEqual(#police.grades, 3, 'grades kept')
assertEqual(police.grades[1].grade, 0, 'grades sorted ascending')
assertEqual(police.grades[3].label, 'Chefe', 'highest grade last')
assertEqual(Core.Groups.GetGradeLabel('police', 1), 'Oficial', 'grade label')
local _, missingGrade = Core.Groups.GetGradeLabel('police', 9)
assertEqual(missingGrade, 'grade_not_found', 'unknown grade')
local _, missingGroup = Core.Groups.Get('nope')
assertEqual(missingGroup, 'group_not_found', 'unknown group')

-- Retornos são cópias: alterá-las não muda as definições.
police.label = 'Hacked'
police.grades[1].label = 'Hacked'
assertEqual(Core.Groups.Get('police').label, 'Polícia', 'group copy is isolated')
assertEqual(Core.Groups.GetGradeLabel('police', 0), 'Cadete', 'grade copy is isolated')

-- Configuração inválida é recusada e mantém as definições anteriores.
local function reject(mutate, expected, label)
	local config = validConfig()
	mutate(config)
	local ok, errorCode = Core.Groups.SetDefinitions(config)
	assertEqual(ok, false, label .. ' rejected')
	assertEqual(errorCode, expected, label .. ' code')
	assertEqual(#Core.Groups.List(), 2, label .. ' keeps previous definitions')
end

reject(function(c) c.Types = {} end, 'invalid_group_type', 'no types')
reject(function(c) c.Types = { 'Job' } end, 'invalid_group_type', 'uppercase type')
reject(function(c) c.Groups.police.type = 'crew' end, 'invalid_group_type', 'unknown group type')
reject(function(c) c.Groups.Police = c.Groups.police end, 'invalid_group_name', 'uppercase group name')
reject(function(c) c.Groups['police;ensure x'] = c.Groups.police end, 'invalid_group_name', 'name with command characters')
reject(function(c) c.Groups[('a'):rep(33)] = c.Groups.police end, 'invalid_group_name', 'name too long')
reject(function(c) c.Groups.police.label = '' end, 'invalid_group_label', 'empty label')
reject(function(c) c.Groups.police.label = 'A\nB' end, 'invalid_group_label', 'label with control characters')
reject(function(c) c.Groups.police.grades = {} end, 'invalid_group_grades', 'no grades')
reject(function(c) c.Groups.police.grades[256] = { label = 'X' } end, 'invalid_group_grades', 'grade above 255')
reject(function(c) c.Groups.police.grades[-1] = { label = 'X' } end, 'invalid_group_grades', 'negative grade')
reject(function(c) c.Groups.police.grades[1.5] = { label = 'X' } end, 'invalid_group_grades', 'fractional grade')
reject(function(c) c.Groups.police.grades.boss = { label = 'X' } end, 'invalid_group_grades', 'non numeric grade')
reject(function(c) c.Groups.police.grades[1] = {} end, 'invalid_group_grades', 'grade without label')
reject(function(c) c.Groups.police.grades = 'x' end, 'invalid_group_grades', 'grades not a table')
reject(function(c)
	for index = 1, 101 do
		c.Groups['g' .. index] = { type = 'job', label = 'G', grades = { [0] = { label = 'X' } } }
	end
end, 'too_many_groups', 'too many groups')
assertEqual(Core.Groups.SetDefinitions(nil), false, 'nil config rejected')
assertEqual(Core.Groups.IsValidName('police'), true, 'valid name')
assertEqual(Core.Groups.IsValidName('1police'), false, 'name cannot start with digit')

-- Sync: um upsert idempotente, sem DELETE e sem trocar o tipo de um grupo existente.
local function runSync(existingRows, failQuery, failExecute)
	local executed = {}
	Core.Database = {
		Query = function(sql, _, callback)
			if failQuery then
				callback(false, nil, 'query_failed')
			else
				callback(true, existingRows)
			end
			return true
		end,
		Execute = function(sql, parameters, callback)
			executed[#executed + 1] = { sql = sql, parameters = parameters }
			if failExecute then
				callback(false, nil, 'execute_failed')
			else
				callback(true, {})
			end
			return true
		end
	}
	local outcome
	local dispatched = Core.Groups.Sync(function(success, errorMessage)
		outcome = { success = success, errorMessage = errorMessage }
	end)
	assertEqual(dispatched, true, 'sync dispatched')
	return executed, outcome
end

local executed, outcome = runSync({})
assertEqual(outcome.success, true, 'sync succeeds')
assertEqual(#executed, 1, 'one statement for all groups')
assertEqual(executed[1].sql:find('ON DUPLICATE KEY UPDATE label', 1, true) ~= nil, true, 'upsert is idempotent')
assertEqual(executed[1].sql:find('DELETE', 1, true), nil, 'sync never deletes')
assertEqual(#executed[1].parameters, 6, 'three parameters per group')
assertEqual(executed[1].parameters[1], 'ballas', 'groups are written in name order')
assertEqual(executed[1].parameters[2], 'gang', 'group type parameter')

local _, sameTypeOutcome = runSync({ { name = 'police', type = 'job' }, { name = 'retired', type = 'job' } })
assertEqual(sameTypeOutcome.success, true, 'existing groups and extra rows are accepted')

local changedExecuted, changedOutcome = runSync({ { name = 'police', type = 'gang' } })
assertEqual(changedOutcome.success, false, 'type change is refused')
assertEqual(changedOutcome.errorMessage, 'group_type_changed', 'type change code')
assertEqual(#changedExecuted, 0, 'nothing is written after a type change')

local _, queryFailure = runSync({}, true)
assertEqual(queryFailure.errorMessage, 'query_failed', 'query failure is propagated')
local _, executeFailure = runSync({}, false, true)
assertEqual(executeFailure.errorMessage, 'execute_failed', 'execute failure is propagated')

assertEqual(Core.Groups.Sync(nil), false, 'sync requires a callback')

print('group definition tests passed')
