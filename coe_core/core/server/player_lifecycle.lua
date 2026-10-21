local started = false
local requestRates = {}
local requestCaches = {}
local registeredHandlers = {}
local MAX_REQUEST_ID = 2147483647
local MAX_CACHED_REQUESTS = 64

local log = CoeLogger.Create('coe_core').log
local _t_inst = nil
local function _t(key, params)
	if Core and Core.Locale and Core.Locale.New then
		if not _t_inst then
			_t_inst = Core.Locale.New({
				default = Core.Locale.GetDefaultLang(),
				locales = Locales or {}
			})
		end
		return _t_inst(key, params)
	end
	if Locales and Locales['pt-BR'] and Locales['pt-BR'][key] then
		return Locales['pt-BR'][key]
	end
	return key
end

local function notifyPlayer(playerSource, kind, message)
	local ok = pcall(function()
		exports.coe_notify:Notify(playerSource, kind, message)
	end)
	if not ok then
		log('warn', 'notification', 'player_notification_failed', {
			player_id = playerSource
		})
	end
end

-- Único dado do personagem replicado aos clients; characterId permanece só no servidor.
local STATE_ID_KEY = 'coe:stateId'

local function setStateIdBag(source, value)
	if type(Player) ~= 'function' then
		return
	end
	local ok = pcall(function()
		Player(source).state:set(STATE_ID_KEY, value, true)
	end)
	if not ok then
		log('warn', 'lifecycle', 'state_id_statebag_failed', {
			player_id = source
		})
	end
end

local function removeRegisteredHandlers()
	for _, handler in ipairs(registeredHandlers) do
		Core.Events.Remove(handler)
	end
	registeredHandlers = {}
end

local function rememberHandler(handler)
	registeredHandlers[#registeredHandlers + 1] = handler
	return handler
end

local function getLicense(source)
	for _, identifier in ipairs(GetPlayerIdentifiers(source)) do
		if identifier:sub(1, 8) == 'license:' then
			return Core.Identity.NormalizeLicense(identifier)
		end
	end

	return nil, 'license_unavailable'
end

local function publicCharacter(character)
	return {
		characterId = character.characterId,
		stateId = character.stateId,
		firstName = character.firstName,
		lastName = character.lastName,
		birthDate = character.birthDate,
		gender = character.gender,
		appearance = character.appearance,
		appearanceVersion = character.appearanceVersion,
		createdAt = character.createdAt
	}
end

local function publicCharacterList(characters)
	local result = {}
	for _, character in ipairs(characters) do
		result[#result + 1] = publicCharacter(character)
	end
	return result
end

local function sendClientEvent(source, name, ...)
	local sent, errorMessage = Core.Events.ToClient(source, name, ...)
	if not sent then
		log('error', 'lifecycle', 'client_event_dispatch_failed', {
			action = name,
			error_code = errorMessage or 'unknown_error',
			player_id = source
		})
	end
end

local function validRequestId(requestId)
	return Core.Functions.IsInteger(requestId)
		and requestId > 0
		and requestId <= MAX_REQUEST_ID
end

local function getRequestCache(source, generation)
	local cache = requestCaches[source]
	if not cache or cache.generation ~= generation then
		cache = {
			generation = generation,
			entries = {},
			order = {}
		}
		requestCaches[source] = cache
	end
	return cache
end

local function reserveRequest(cache, key)
	local existing = cache.entries[key]
	if existing then
		return nil, existing
	end

	if #cache.order >= MAX_CACHED_REQUESTS then
		local removableIndex
		for index, queuedKey in ipairs(cache.order) do
			local entry = cache.entries[queuedKey]
			if entry and not entry.pending then
				removableIndex = index
				cache.entries[queuedKey] = nil
				break
			end
		end
		if not removableIndex then
			return nil, nil
		end
		table.remove(cache.order, removableIndex)
	end

	local entry = { pending = true }
	cache.entries[key] = entry
	cache.order[#cache.order + 1] = key
	return entry
end

local function allowAction(source, generation, action, interval)
	local state = requestRates[source]
	if not state or state.generation ~= generation then
		state = { generation = generation, last = {} }
		requestRates[source] = state
	end

	local now = GetGameTimer()
	local previous = state.last[action]
	if previous and now - previous < interval then
		return false
	end
	state.last[action] = now
	return true
end

local function sendResponse(source, generation, eventName, requestId, success, result)
	if not Core.SessionRegistry.IsCurrent(source, generation) then
		return
	end
	sendClientEvent(source, eventName, requestId, success, result)
end

local function processRequest(source, action, requestId, interval, resultEvent, operation)
	if not validRequestId(requestId) then
		return
	end

	local session = Core.SessionRegistry.Get(source)
	if not session then
		sendClientEvent(source, resultEvent, requestId, false, 'player_not_loaded')
		return
	end

	local generation = session.generation
	local cache = getRequestCache(source, generation)
	local key = action .. ':' .. tostring(requestId)
	local request, previous = reserveRequest(cache, key)
	if not request then
		if previous and not previous.pending then
			sendClientEvent(source, previous.event, requestId, previous.success, previous.result)
		elseif not previous then
			sendResponse(source, generation, resultEvent, requestId, false, 'request_capacity')
		end
		return
	end

	local function finish(success, result, errorMessage)
		if not Core.SessionRegistry.IsCurrent(source, generation) then
			return
		end
		if not success then
			result = errorMessage or result
		end
		log('debug', 'lifecycle', 'character_request_completed', {
			action = action,
			error_code = not success and type(result) == 'string' and result or nil,
			player_id = source,
			request_id = requestId,
			result = success
		})
		request.pending = false
		request.event = resultEvent
		request.success = success
		request.result = result
		sendResponse(source, generation, resultEvent, requestId, success, result)
	end

	if not allowAction(source, generation, action, interval) then
		finish(false, 'rate_limited')
		return
	end

	local dispatched, errorMessage = operation(finish)
	if not dispatched then
		finish(false, errorMessage)
	end
end

local function notifyCharacterList(source, generation)
	local dispatched, errorMessage = Core.Players.ListCharacters(source, function(success, characters, listError)
		if not Core.SessionRegistry.IsCurrent(source, generation) then
			return
		end
		if not success then
			log('error', 'lifecycle', 'character_list_refresh_failed', {
				error_code = listError or 'unknown_error',
				player_id = source
			})
			return
		end
		sendClientEvent(source, 'character.listUpdated', publicCharacterList(characters))
	end)
	if not dispatched then
		log('error', 'lifecycle', 'character_list_refresh_dispatch_failed', {
			error_code = errorMessage or 'unknown_error',
			player_id = source
		})
	end
end

-- Reenvia o estado de seleção; o envio feito em playerJoining pode chegar antes de o client registrar seus handlers.
local function resyncSelection(source)
	local session = Core.SessionRegistry.Get(source)
	if not session or session.state ~= 'character_selection' then
		return
	end

	local generation = session.generation
	if not allowAction(source, generation, 'clientReady', 1000) then
		return
	end
	log('info', 'lifecycle', 'client_ready_received', {
		player_id = source
	})

	local dispatched, errorMessage = Core.Players.ListCharacters(source, function(success, characters, listError)
		if not Core.SessionRegistry.IsCurrent(source, generation) then
			return
		end
		if not success then
			log('error', 'lifecycle', 'selection_resync_failed', {
				error_code = listError or 'unknown_error',
				player_id = source
			})
			return
		end
		sendClientEvent(source, 'player.loaded')
		sendClientEvent(source, 'character.selectionRequired', publicCharacterList(characters))
		log('info', 'lifecycle', 'selection_resync_sent', {
			player_id = source
		})
	end)
	if not dispatched then
		log('error', 'lifecycle', 'selection_resync_dispatch_failed', {
			error_code = errorMessage or 'unknown_error',
			player_id = source
		})
	end
end

local function beginSession(source)
	if not started or not GetPlayerName(source) or Core.SessionRegistry.Get(source) then
		return
	end

	local license, identifierError = getLicense(source)
	if not license then
		log('warn', 'security', 'player_identity_unavailable', {
			error_code = identifierError or 'unknown_error',
			player_id = source
		})
		DropPlayer(source, 'Unable to verify your player identity.')
		return
	end

	local loaded, errorMessage = Core.Players.LoadSession(source, license, function(success, session, charactersOrError)
		if not success then
			if charactersOrError ~= 'stale_session' and GetPlayerName(source) then
				log('error', 'lifecycle', 'player_session_load_failed', {
					error_code = charactersOrError or 'unknown_error',
					player_id = source
				})
				DropPlayer(source, 'Unable to load your player data.')
			end
			return
		end

		log('info', 'lifecycle', 'player_session_loaded', {
			player_id = source
		})
		sendClientEvent(source, 'player.loaded')
		sendClientEvent(source, 'character.selectionRequired', publicCharacterList(charactersOrError))
	end)
	if not loaded then
		log('error', 'lifecycle', 'player_session_start_failed', {
			error_code = errorMessage or 'unknown_error',
			player_id = source
		})
		if GetPlayerName(source) then
			DropPlayer(source, 'Unable to load your player data.')
		end
	end
end

local function configureCharacterLimit()
	local value = GetConvar('coe_max_characters', '5')
	if not value:match('^[1-9]%d*$') then
		return false, 'invalid_character_limit'
	end

	local hardValue = GetConvar('coe_max_characters_hard', '10')
	if not hardValue:match('^[1-9]%d*$') then
		return false, 'invalid_character_limit'
	end
	local hardConfigured, hardError = Core.Players.SetCharacterHardLimit(tonumber(hardValue))
	if not hardConfigured then
		return false, hardError
	end

	return Core.Players.SetCharacterLimit(tonumber(value))
end

-- Regras de criação: coe_character_min_age, coe_character_max_age e coe_character_genders
-- (lista separada por vírgula). Valores inválidos impedem o start em vez de cair em padrão silencioso.
local function configureCharacterProfile()
	local minAge = GetConvar('coe_character_min_age', '18')
	local maxAge = GetConvar('coe_character_max_age', '90')
	if not minAge:match('^%d+$') or not maxAge:match('^%d+$') then
		return false, 'invalid_profile_rules'
	end

	local genders = {}
	for gender in GetConvar('coe_character_genders', 'male,female'):gmatch('[^,%s]+') do
		genders[#genders + 1] = gender
	end
	return Core.CharacterProfile.SetRules(tonumber(minAge), tonumber(maxAge), genders)
end

local function registerClientHandlers()
	removeRegisteredHandlers()

	local loadedHandler, loadedError = Core.Events.On('player.characterLoaded', function(event)
		if type(event) ~= 'table' or not Core.Functions.IsInteger(event.source) or type(event.character) ~= 'table' then
			return
		end
		if Core.SessionRegistry.IsCurrent(event.source, event.generation) then
			setStateIdBag(event.source, event.character.stateId)
		end
	end)
	if not loadedHandler then
		return false, loadedError or 'event_registration_failed'
	end
	rememberHandler(loadedHandler)

	local unloadedHandler, unloadedError = Core.Events.On('player.characterUnloaded', function(event)
		if type(event) ~= 'table' or not Core.Functions.IsInteger(event.source) then
			return
		end
		local session = Core.SessionRegistry.Get(event.source)
		if session and session.generation == event.generation then
			setStateIdBag(event.source, nil)
			sendClientEvent(event.source, 'player.characterUnloaded')
		end
	end)
	if not unloadedHandler then
		removeRegisteredHandlers()
		return false, unloadedError or 'event_registration_failed'
	end
	rememberHandler(unloadedHandler)

	local readyHandler, readyError = Core.Events.OnNet('player.clientReady', function()
		resyncSelection(source)
	end)
	if not readyHandler then
		removeRegisteredHandlers()
		return false, readyError or 'event_registration_failed'
	end
	rememberHandler(readyHandler)

	local listHandler, listError = Core.Events.OnNet('character.listRequest', function(requestId)
		local playerSource = source
		processRequest(playerSource, 'list', requestId, 500, 'character.listResult', function(callback)
			return Core.Players.ListCharacters(playerSource, function(success, characters, errorMessage)
				callback(success, success and publicCharacterList(characters) or nil, errorMessage)
			end)
		end)
	end)
	if not listHandler then
		removeRegisteredHandlers()
		return false, listError or 'event_registration_failed'
	end
	rememberHandler(listHandler)

	local createHandler, createError = Core.Events.OnNet('character.createRequest', function(requestId, firstName, lastName, profile)
		local playerSource = source
		local session = Core.SessionRegistry.Get(playerSource)
		processRequest(playerSource, 'create', requestId, 2000, 'character.createResult', function(callback)
			return Core.Players.CreateCharacter(playerSource, firstName, lastName, profile, function(success, character, errorMessage)
				callback(success, success and publicCharacter(character) or nil, errorMessage)
				if success then
					log('info', 'audit', 'character_created', {
						character_id = character.characterId,
						player_id = playerSource
					})
					notifyPlayer(playerSource, 'success', _t('character_created'))
				end
				if success and session then
					notifyCharacterList(playerSource, session.generation)
				end
			end)
		end)
	end)
	if not createHandler then
		removeRegisteredHandlers()
		return false, createError or 'event_registration_failed'
	end
	rememberHandler(createHandler)

	local selectHandler, selectError = Core.Events.OnNet('character.selectRequest', function(requestId, characterId)
		local playerSource = source
		processRequest(playerSource, 'select', requestId, 500, 'character.selectResult', function(callback)
			return Core.Players.SelectCharacter(playerSource, characterId, function(success, character, errorMessage)
				callback(success, success and publicCharacter(character) or nil, errorMessage)
				if success then
					log('info', 'audit', 'character_selected', {
						character_id = character.characterId,
						player_id = playerSource
					})
					TriggerEvent('coe_core:characterLoaded', playerSource, character.characterId)
					notifyPlayer(playerSource, 'success', _t('character_loaded'))
					sendClientEvent(playerSource, 'player.characterLoaded', publicCharacter(character))
				end
			end)
		end)
	end)
	if not selectHandler then
		removeRegisteredHandlers()
		return false, selectError or 'event_registration_failed'
	end
	rememberHandler(selectHandler)

	local changeHandler, changeError = Core.Events.OnNet('character.changeRequest', function(requestId)
		local playerSource = source
		processRequest(playerSource, 'change', requestId, 500, 'character.changeResult', function(callback)
			return Core.Players.ReturnToSelection(playerSource, function(success, characters, errorMessage)
				callback(success, success and publicCharacterList(characters) or nil, errorMessage)
			end)
		end)
	end)
	if not changeHandler then
		removeRegisteredHandlers()
		return false, changeError or 'event_registration_failed'
	end
	rememberHandler(changeHandler)

	local archiveHandler, archiveError = Core.Events.OnNet('character.archiveRequest', function(requestId, characterId)
		local playerSource = source
		local session = Core.SessionRegistry.Get(playerSource)
		processRequest(playerSource, 'archive', requestId, 2000, 'character.archiveResult', function(callback)
			return Core.Players.ArchiveCharacter(playerSource, characterId, function(success, result, errorMessage)
				callback(success, result or errorMessage)
				if success then
					log('info', 'audit', 'character_archived', {
						character_id = characterId,
						player_id = playerSource
					})
					notifyPlayer(playerSource, 'success', _t('character_archived'))
				end
				if success and session then
					notifyCharacterList(playerSource, session.generation)
				end
			end)
		end)
	end)
	if not archiveHandler then
		removeRegisteredHandlers()
		return false, archiveError or 'event_registration_failed'
	end
	rememberHandler(archiveHandler)

	local appearanceHandler, appearanceError = Core.Events.OnNet('character.appearanceRequest', function(requestId, characterId, appearance, version)
		local playerSource = source
		local session = Core.SessionRegistry.Get(playerSource)
		processRequest(playerSource, 'appearance', requestId, 2000, 'character.appearanceResult', function(callback)
			return Core.Players.SetInitialAppearance(playerSource, characterId, appearance, version, function(success, _, errorMessage)
				callback(success, success and characterId or errorMessage, errorMessage)
				if success then
					log('info', 'audit', 'character_appearance_set', {
						character_id = characterId,
						player_id = playerSource
					})
				end
				if success and session then
					notifyCharacterList(playerSource, session.generation)
				end
			end)
		end)
	end)
	if not appearanceHandler then
		removeRegisteredHandlers()
		return false, appearanceError or 'event_registration_failed'
	end
	rememberHandler(appearanceHandler)

	return true
end

function Core.Players.Start()
	if started then
		return true
	end

	local configured, configError = configureCharacterLimit()
	if configured then
		configured, configError = configureCharacterProfile()
	end
	if not configured then
		return false, configError
	end
	local registered, registerError = registerClientHandlers()
	if not registered then
		return false, registerError
	end

	started = true
	for _, serverId in ipairs(GetPlayers()) do
		local playerSource = tonumber(serverId)
		if playerSource then
			beginSession(playerSource)
		end
	end
	return true
end

function Core.Players.Stop()
	started = false
	removeRegisteredHandlers()
	for _, session in ipairs(Core.SessionRegistry.List()) do
		if session.state == 'character_loaded' then
			setStateIdBag(session.source, nil)
		end
		requestRates[session.source] = nil
		requestCaches[session.source] = nil
	end
	Core.Players.StopSessions()
end

function Core.Players.StopSessions()
	for _, session in ipairs(Core.SessionRegistry.List()) do
		Core.Players.Disconnect(session.source)
	end
end

AddEventHandler('playerJoining', function()
	beginSession(source)
end)

AddEventHandler('playerDropped', function()
	local playerSource = source
	requestRates[playerSource] = nil
	requestCaches[playerSource] = nil
	Core.Players.Disconnect(playerSource)
end)
