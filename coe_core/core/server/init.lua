exports('GetCoreObject', function()
	return Core
end)

-- Consulta por stateId entre jogadores online: (snapshot) ou (nil, erro).
exports('GetCharacterByStateId', function(stateId)
	return Core.Players.GetCharacterByStateId(stateId)
end)

-- Personagem ativo de um jogador online (snapshot) ou nil; usado pelos painéis para mostrar o nome do personagem.
exports('GetActiveCharacter', function(source)
	return (Core.Players.GetActiveCharacter(source))
end)

exports('GetPlayerByStateId', function(stateId)
	return Core.Players.GetPlayerByStateId(stateId)
end)

-- /id: mostra o ID público (stateId) do personagem ativo, o mesmo usado nos painéis e comandos administrativos.
local lastIdCommand = {}
local _t = Core.Locale.New({
	default = Core.Locale.GetDefaultLang(),
	locales = Locales or {}
})

RegisterCommand('id', function(source)
	if source <= 0 then
		return
	end
	local now = GetGameTimer()
	if lastIdCommand[source] and now - lastIdCommand[source] < 2000 then
		return
	end
	lastIdCommand[source] = now
	local character = Core.Players.GetActiveCharacter(source)
	local message = character and _t('id_command_active', { id = character.stateId }) or _t('id_command_no_character')
	pcall(function()
		exports.coe_notify:Notify(source, character and 'info' or 'error', message)
	end)
end, false)

AddEventHandler('playerDropped', function()
	lastIdCommand[source] = nil
end)

-- Administração de grupos por outro resource (ex.: painel de staff): ACE coe.groups.admin no principal do resource
-- (add_ace resource.<nome> coe.groups.admin allow). A autorização do operador é responsabilidade de quem chama.
local GROUP_ADMIN_ACE = 'coe.groups.admin'

local function groupAdminCaller()
	return CoeAccess.Allowed(GetInvokingResource(), GROUP_ADMIN_ACE)
end

exports('GetGroupDefinitions', function()
	return Core.Groups.List()
end)

exports('GetPlayerGroups', function(source)
	return Core.Groups.GetCharacterGroups(source)
end)

-- Callbacks vindos de outro resource chegam como objetos chamáveis, não como function.
local function toFunction(callback)
	if type(callback) == 'function' then
		return callback
	end
	local meta = type(callback) == 'table' and getmetatable(callback)
	if meta and meta.__call then
		return function(...)
			return callback(...)
		end
	end
	return nil
end

-- Exports entre resources devolvem só o primeiro valor: retornam true ou o código de erro.
exports('SetPlayerGroup', function(source, name, grade, callback)
	if not groupAdminCaller() then
		return 'forbidden'
	end
	local dispatched, errorCode = Core.Groups.SetForPlayer(source, name, grade, toFunction(callback))
	return dispatched == true or errorCode or 'unknown_error'
end)

exports('RemovePlayerGroup', function(source, name, callback)
	if not groupAdminCaller() then
		return 'forbidden'
	end
	local dispatched, errorCode = Core.Groups.RemoveForPlayer(source, name, toFunction(callback))
	return dispatched == true or errorCode or 'unknown_error'
end)

-- /grupo: administração de grupos sem painel (console ou staff com a ACE command.grupo).
--   grupo definir <stateId> <grupo> [grau]   grupo remover <stateId> <grupo>   grupo ver <stateId>   grupo lista
local function groupReply(source, kind, message)
	if source <= 0 then
		print(('[coe_core] %s'):format(message))
		return
	end
	pcall(function()
		exports.coe_notify:Notify(source, kind, message)
	end)
end

local function groupTarget(source, stateId)
	local character, lookupError = Core.Players.GetCharacterByStateId(type(stateId) == 'string' and stateId:upper() or stateId)
	if not character then
		groupReply(source, 'error', _t('group_command_target', { id = tostring(stateId), error = tostring(lookupError) }))
		return nil
	end
	return character
end

local function groupDone(source, character, action)
	return function(success, _, errorMessage)
		if success then
			groupReply(source, 'success', _t('group_command_' .. action, { id = character.stateId }))
		else
			groupReply(source, 'error', _t('group_command_failed', { error = tostring(errorMessage) }))
		end
	end
end

RegisterCommand('grupo', function(source, args)
	local action, stateId, name = args[1], args[2], args[3]
	if action == 'lista' then
		local names = {}
		for _, group in ipairs(Core.Groups.List()) do
			names[#names + 1] = group.name
		end
		groupReply(source, 'info', _t('group_command_list', { groups = table.concat(names, ', ') }))
		return
	end
	if action ~= 'definir' and action ~= 'remover' and action ~= 'ver' then
		groupReply(source, 'info', _t('group_command_usage'))
		return
	end
	local character = groupTarget(source, stateId)
	if not character then
		return
	end
	if action == 'ver' then
		local session = Core.Players.GetPlayerByStateId(character.stateId)
		local parts = {}
		for groupType, link in pairs(session and Core.Groups.GetCharacterGroups(session.source) or {}) do
			parts[#parts + 1] = ('%s=%s/%s'):format(groupType, link.name, tostring(link.grade))
		end
		groupReply(source, 'info', _t('group_command_show', { id = character.stateId, groups = #parts > 0 and table.concat(parts, ' ') or '-' }))
		return
	end
	local dispatched, errorCode
	if action == 'definir' then
		local grade = tonumber(args[4] or '0')
		dispatched, errorCode = Core.Groups.Set(character.characterId, name, grade and math.tointeger(grade), groupDone(source, character, 'set'))
	else
		dispatched, errorCode = Core.Groups.Remove(character.characterId, name, groupDone(source, character, 'removed'))
	end
	if not dispatched then
		groupReply(source, 'error', _t('group_command_failed', { error = tostring(errorCode) }))
	end
end, true)

local stopping = false
local waitingForDatabaseLogged = false
local initializeCore

local logger = CoeLogger.Create('coe_core')

local function log(level, event, context)
	logger.log(level, 'lifecycle', event, context)
end

local function finishStart()
	local groupsStarted, groupsStartError = Core.Groups.Start()
	if not groupsStarted then
		log('error', 'group_service_start_failed', {
			error_code = groupsStartError or 'unknown_error'
		})
		return
	end

	local playersStarted, playersError = Core.Players.Start()
	if not playersStarted then
		Core.Groups.Stop()
		log('error', 'player_lifecycle_start_failed', {
			error_code = playersError or 'unknown_error'
		})
		return
	end

	local stateSet, stateError = Core.States.Set('ready', true)
	if not stateSet then
		Core.Players.Stop()
		Core.Groups.Stop()
		log('error', 'ready_state_update_failed', {
			error_code = stateError or 'unknown_error'
		})
		return
	end
	waitingForDatabaseLogged = false

	local emitted, eventError = Core.Events.Emit('server.ready', Core)
	if not emitted then
		log('error', 'server_ready_event_failed', {
			error_code = eventError or 'unknown_error'
		})
	end
end

local function retryInitialization(delay)
	SetTimeout(delay, function()
		initializeCore()
	end)
end

initializeCore = function()
	if stopping then
		return
	end

	local databaseReady = Core.Database.IsReady()
	if not databaseReady then
		if not waitingForDatabaseLogged then
			log('info', 'database_waiting')
			waitingForDatabaseLogged = true
		end
		retryInitialization(1000)
		return
	end

	local dispatched, dispatchError = Core.Database.RunMigrations(function(success, errorMessage)
		if stopping then
			return
		end
		if not success then
			log('error', 'database_migration_failed', {
				error_code = errorMessage or 'unknown_error',
				retry_ms = 5000
			})
			retryInitialization(5000)
			return
		end

		local groupsConfigured, groupsError = Core.Groups.SetDefinitions(CoeGroupsConfig)
		if not groupsConfigured then
			log('error', 'group_definitions_invalid', {
				error_code = groupsError or 'unknown_error'
			})
			return
		end

		local syncDispatched, syncDispatchError = Core.Groups.Sync(function(synced, syncError)
			if stopping then
				return
			end
			if not synced then
				log('error', 'group_sync_failed', {
					error_code = syncError or 'unknown_error',
					retry_ms = syncError ~= 'group_type_changed' and 5000 or nil
				})
				-- Mudança de tipo não se resolve sozinha: exige corrigir o arquivo ou migrar.
				if syncError ~= 'group_type_changed' then
					retryInitialization(5000)
				end
				return
			end
			finishStart()
		end)
		if not syncDispatched then
			log('error', 'group_sync_failed', {
				error_code = syncDispatchError or 'unknown_error',
				retry_ms = 5000
			})
			retryInitialization(5000)
		end
	end)
	if not dispatched then
		log('error', 'database_migration_dispatch_failed', {
			error_code = dispatchError or 'unknown_error',
			retry_ms = 5000
		})
		retryInitialization(5000)
	end
end

CreateThread(function()
	initializeCore()
end)

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName == GetCurrentResourceName() then
		stopping = true
		Core.States.Set('ready', false)
		Core.Players.Stop()
		Core.Groups.Stop()
		local emitted, errorMessage = Core.Events.Emit('server.stopping', Core)
		if not emitted then
			log('error', 'server_stopping_event_failed', {
				error_code = errorMessage or 'unknown_error'
			})
		end
	end
end)
