dofile([=[core/shared/bootstrap.lua]=])
dofile([=[core/shared/functions.lua]=])
dofile([=[core/shared/identity.lua]=])
dofile([=[core/server/group_definitions.lua]=])
dofile([=[core/server/group_repository.lua]=])

local logs = {}
CoeLogger = {
	Create = function()
		return { log = function(level, category, event, context) logs[#logs + 1] = { level = level, event = event, context = context } end }
	end
}

local commands = {}
function ExecuteCommand(command) commands[#commands + 1] = command end
local function hasCommand(command)
	for _, entry in ipairs(commands) do if entry == command then return true end end
	return false
end
local handlers, removed, emitted = {}, {}, {}
local sequence = 0
Core.Events = {
	On = function(name, callback)
		sequence = sequence + 1
		handlers[name] = callback
		return sequence
	end,
	Remove = function(handler) removed[#removed + 1] = handler return true end,
	Emit = function(name, payload) emitted[#emitted + 1] = { name = name, payload = payload } return true end
}
local currentGenerations = { [7] = 1 }
local sessions = { [7] = { state = 'character_loaded', character = { characterId = '9' } }, [6] = { state = 'character_selection' } }
Core.SessionRegistry = {
	IsCurrent = function(source, generation) return currentGenerations[source] == generation end,
	Get = function(source) return sessions[source] end
}

-- Banco em memória: vínculos por personagem.
local links = {}
local failNext
Core.Database = {
	Query = function(sql, parameters, callback)
		if failNext == 'query' then failNext = nil callback(false, nil, 'query_failed') return true end
		local rows = {}
		for _, link in ipairs(links[parameters[1]] or {}) do
			rows[#rows + 1] = { group_name = link.name, group_type = link.type, grade = link.grade, active = link.active and 1 or 0 }
		end
		callback(true, rows)
		return true
	end,
	Transaction = function(statements, callback)
		if failNext == 'write' then failNext = nil callback(false, nil, 'ER_NO_REFERENCED_ROW_2') return true end
		local characterId, groupName, groupType, grade = statements[2].parameters[1], statements[2].parameters[2], statements[2].parameters[3], statements[2].parameters[4]
		links[characterId] = links[characterId] or {}
		for _, link in ipairs(links[characterId]) do
			if link.type == groupType and link.name ~= groupName then link.active = false end
		end
		local found
		for _, link in ipairs(links[characterId]) do
			if link.name == groupName then found = link end
		end
		if found then found.grade, found.active = grade, true
		else links[characterId][#links[characterId] + 1] = { name = groupName, type = groupType, grade = grade, active = true } end
		callback(true, {})
		return true
	end,
	Execute = function(sql, parameters, callback)
		local list = links[parameters[1]] or {}
		for index, link in ipairs(list) do
			if link.name == parameters[2] then table.remove(list, index) break end
		end
		callback(true, {})
		return true
	end
}
dofile([=[core/server/group_service.lua]=])

local function assertEqual(actual, expected, message)
	if actual ~= expected then
		error(('%s: expected %s, got %s'):format(message or 'assertEqual', tostring(expected), tostring(actual)))
	end
end

Core.Groups.SetDefinitions({
	Types = { 'job', 'gang' },
	Groups = {
		police = { type = 'job', label = 'Polícia', grades = { [0] = { label = 'Cadete' }, [1] = { label = 'Oficial' }, [2] = { label = 'Chefe' } } },
		ambulance = { type = 'job', label = 'Hospital', grades = { [0] = { label = 'Estagiário' } } },
		ballas = { type = 'gang', label = 'Ballas', grades = { [0] = { label = 'Membro' } } }
	}
})

assertEqual(Core.Groups.Start(), true, 'start')
assertEqual(hasCommand('add_principal coe.group.police.2 coe.group.police.1'), true, 'grade inherits the lower grade')
assertEqual(hasCommand('add_principal coe.group.police.1 coe.group.police.0'), true, 'grade chain')
assertEqual(hasCommand('add_principal coe.group.ambulance.0 coe.group.ambulance.-1'), false, 'single grade has no chain')
assertEqual(handlers['player.characterLoaded'] ~= nil, true, 'loaded handler')
assertEqual(handlers['player.characterUnloaded'] ~= nil, true, 'unloaded handler')
assertEqual(handlers['player.sessionEnded'] ~= nil, true, 'ended handler')

local function call(fn, ...)
	local result
	local args = { ... }
	args[#args + 1] = function(success, value, errorMessage) result = { success = success, value = value, error = errorMessage } end
	local dispatched, dispatchError = fn(table.unpack(args))
	if dispatched == false then return { success = false, error = dispatchError, sync = true } end
	return result
end

-- Validação de entrada.
assertEqual(call(Core.Groups.Set, 'x', 'police', 0).error, 'invalid_character_id', 'bad character id')
assertEqual(call(Core.Groups.Set, '1', 'nope', 0).error, 'group_not_found', 'unknown group')
assertEqual(call(Core.Groups.Set, '1', 'police', 9).error, 'invalid_grade', 'unknown grade')
assertEqual(call(Core.Groups.Set, '1', 'police', 1.5).error, 'invalid_grade', 'fractional grade')
assertEqual(call(Core.Groups.Remove, '1', 'bad name').error, 'invalid_group_name', 'bad name on remove')

-- Offline: grava e emite com source nil.
local offline = call(Core.Groups.Set, '5', 'police', 1)
assertEqual(offline.success, true, 'offline set')
assertEqual(offline.value.previous, nil, 'no previous group')
assertEqual(emitted[#emitted].name, 'player.groupChanged', 'event emitted')
assertEqual(emitted[#emitted].payload.source, nil, 'offline has no source')
assertEqual(Core.Groups.Has(7, 'police'), false, 'no cache before load')
assertEqual(select(2, Core.Groups.GetCharacterGroups(7)), 'character_not_loaded', 'groups need a loaded character')

-- Carga ao selecionar o personagem; grupo removido do arquivo é ignorado.
links['9'] = {
	{ name = 'police', type = 'job', grade = 1, active = true },
	{ name = 'ambulance', type = 'job', grade = 0, active = false },
	{ name = 'ballas', type = 'gang', grade = 0, active = true }
}
handlers['player.characterLoaded']({ source = 7, generation = 1, character = { characterId = '9' } })
assertEqual(hasCommand('add_principal player.7 coe.group.police'), true, 'group principal granted')
assertEqual(hasCommand('add_principal player.7 coe.group.police.1'), true, 'grade principal granted')
assertEqual(hasCommand('add_principal player.7 coe.group.ballas'), true, 'gang principal granted')
assertEqual(hasCommand('add_principal player.7 coe.group.ambulance'), false, 'inactive group not granted')
local groups = Core.Groups.GetCharacterGroups(7)
assertEqual(groups.job.name, 'police', 'active job loaded')
assertEqual(groups.job.grade, 1, 'job grade loaded')
assertEqual(groups.gang.name, 'ballas', 'active gang loaded')
assertEqual(Core.Groups.Has(7, 'ambulance'), false, 'inactive group does not count')
assertEqual(Core.Groups.Has(7, 'police', 1), true, 'grade at minimum')
assertEqual(Core.Groups.Has(7, 'police', 2), false, 'grade below minimum')
assertEqual(Core.Groups.Has(7, 'police', 'x'), false, 'invalid minimum grade')
assertEqual(Core.Groups.Has(7, 'bad name'), false, 'invalid name')
assertEqual(Core.Groups.Has(8, 'police'), false, 'other source has nothing')
currentGenerations[8] = 1
links['10'] = { { name = 'ghost', type = 'job', grade = 0, active = true }, { name = 'police', type = 'job', grade = 9, active = false } }
handlers['player.characterLoaded']({ source = 8, generation = 1, character = { characterId = '10' } })
assertEqual(Core.Groups.Has(8, 'ghost'), false, 'group removed from the file is ignored')
assertEqual(logs[#logs].event, 'group_membership_ignored', 'ignored membership is logged')
handlers['player.sessionEnded']({ source = 8, generation = 1 })
groups.job.name = 'hacked'
assertEqual(Core.Groups.GetCharacterGroups(7).job.name, 'police', 'returned table is a copy')

-- Set troca o ativo do mesmo tipo e atualiza o cache online.
local switched = call(Core.Groups.Set, '9', 'ambulance', 0)
assertEqual(switched.success, true, 'switch job')
assertEqual(switched.value.previous.name, 'police', 'previous active job')
assertEqual(switched.value.previous.grade, 1, 'previous grade')
assertEqual(Core.Groups.Has(7, 'police'), false, 'old job inactive in cache')
assertEqual(Core.Groups.Has(7, 'ambulance'), true, 'new job active in cache')
assertEqual(Core.Groups.Has(7, 'ballas'), true, 'other type untouched')
assertEqual(hasCommand('remove_principal player.7 coe.group.police.1'), true, 'old grade principal revoked')
assertEqual(hasCommand('add_principal player.7 coe.group.ambulance.0'), true, 'new grade principal granted')
assertEqual(emitted[#emitted].payload.source, 7, 'event carries the online source')
assertEqual(emitted[#emitted].payload.group, 'ambulance', 'event group')

-- Falha de gravação não altera o cache nem emite.
local eventsBefore = #emitted
failNext = 'write'
local failed = call(Core.Groups.Set, '9', 'police', 2)
assertEqual(failed.success, false, 'write failure')
assertEqual(Core.Groups.Has(7, 'ambulance'), true, 'cache unchanged after failure')
assertEqual(#emitted, eventsBefore, 'no event after failure')

-- Variantes por source resolvem o personagem ativo.
assertEqual(select(2, Core.Groups.SetForPlayer(6, 'police', 0, function() end)), 'character_not_loaded', 'no character selected')
assertEqual(select(2, Core.Groups.SetForPlayer(99, 'police', 0, function() end)), 'character_not_loaded', 'unknown source')
assertEqual(select(2, Core.Groups.RemoveForPlayer(6, 'police', function() end)), 'character_not_loaded', 'remove without character')
local bySource = call(Core.Groups.SetForPlayer, 7, 'police', 1)
assertEqual(bySource.success, true, 'set by source')
assertEqual(Core.Groups.Has(7, 'police', 1), true, 'set by source updates the cache')
assertEqual(call(Core.Groups.SetForPlayer, 7, 'ambulance', 0).success, true, 'switch back by source')

-- Remove.
local removedResult = call(Core.Groups.Remove, '9', 'ballas')
assertEqual(removedResult.success, true, 'remove')
assertEqual(removedResult.value.removed, true, 'removed flag')
assertEqual(Core.Groups.Has(7, 'ballas'), false, 'removed from cache')
assertEqual(hasCommand('remove_principal player.7 coe.group.ballas'), true, 'principal revoked on remove')
assertEqual(emitted[#emitted].payload.group, nil, 'removal event has no group')
assertEqual(emitted[#emitted].payload.previous.name, 'ballas', 'removal event previous')
local again = call(Core.Groups.Remove, '9', 'ballas')
assertEqual(again.value.removed, false, 'remove is idempotent')

-- Descarregar o personagem revoga os principais.
handlers['player.characterLoaded']({ source = 7, generation = 1, character = { characterId = '9' } })
local beforeUnload = #commands
handlers['player.characterUnloaded']({ source = 7, generation = 1 })
assertEqual(#commands > beforeUnload, true, 'unload revokes principals')

-- Carga atrasada de uma sessão antiga não grava no cache novo.
local pending
Core.Database.Query = function(sql, parameters, callback) pending = callback return true end
handlers['player.characterLoaded']({ source = 7, generation = 1, character = { characterId = '9' } })
handlers['player.characterUnloaded']({ source = 7, generation = 1 })
pending(true, { { group_name = 'police', group_type = 'job', grade = 2, active = 1 } })
assertEqual(Core.Groups.Has(7, 'police'), false, 'late load after unload is dropped')
assertEqual(hasCommand('add_principal player.7 coe.group.police.2'), false, 'late load grants no principal')

-- Falha na carga: falha fechada com log.
Core.Database.Query = function(sql, parameters, callback) callback(false, nil, 'query_failed') return true end
handlers['player.characterLoaded']({ source = 7, generation = 1, character = { characterId = '9' } })
assertEqual(Core.Groups.Has(7, 'police'), false, 'load failure grants nothing')
assertEqual(logs[#logs].event, 'group_load_failed', 'load failure is logged')

-- Sessão obsoleta não carrega; fim de sessão limpa.
handlers['player.characterUnloaded']({ source = 7, generation = 1 })
handlers['player.characterLoaded']({ source = 7, generation = 99, character = { characterId = '9' } })
assertEqual(select(2, Core.Groups.GetCharacterGroups(7)) , 'character_not_loaded', 'stale generation ignored')
handlers['player.characterLoaded']({ source = 7, generation = 1, character = { characterId = '9' } })
handlers['player.sessionEnded']({ source = 7, generation = 1 })
assertEqual(select(2, Core.Groups.GetCharacterGroups(7)), 'character_not_loaded', 'session end clears')

-- Stop remove handlers e cache.
Core.Groups.Stop()
assertEqual(#removed >= 3, true, 'handlers removed')
assertEqual(hasCommand('remove_principal coe.group.police.2 coe.group.police.1'), true, 'hierarchy removed on stop')

print('group service tests passed')
