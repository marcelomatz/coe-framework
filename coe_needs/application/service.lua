local logger = CoeLogger.Create('coe_needs')
local settings = Config.Needs

local entries = {}
local byCharacter = {}
local loading = {}

local function advance(entry, timestamp)
	local seconds = math.min((timestamp - entry.at) / 1000, settings.MaxAdvanceSeconds)
	entry.at = timestamp
	if seconds > 0 then
		Needs.Step(entry.state, entry.activity, seconds)
		entry.dirty = true
	end
end

local function push(source, entry, force)
	local snapshot = Needs.Snapshot(entry.state)
	if force or not Needs.SnapshotEquals(entry.sent, snapshot) then
		entry.sent = snapshot
		TriggerClientEvent('coe_needs:state', source, snapshot)
	end
end

local function save(entry)
	if not entry.loaded or not NeedsPersistence.IsReady() then
		return
	end
	local saved, errorCode = NeedsPersistence.Save(entry.characterId, entry.state)
	if saved then
		entry.dirty = false
	else
		logger.log('error', 'needs', 'needs_save_failed', { error_code = errorCode or 'unknown_error' })
	end
end

local SAVE_BATCH = 50

-- Salva todos os personagens sujos em lotes (uma instrucao por lote, nao uma por jogador).
local function saveDirty()
	if not NeedsPersistence.IsReady() then
		return
	end
	local pending = {}
	for _, entry in pairs(entries) do
		if entry.dirty and entry.loaded then
			pending[#pending + 1] = entry
		end
	end
	for first = 1, #pending, SAVE_BATCH do
		local rows, chunk = {}, {}
		for index = first, math.min(first + SAVE_BATCH - 1, #pending) do
			local entry = pending[index]
			chunk[#chunk + 1] = entry
			rows[#rows + 1] = { entry.characterId, entry.state }
		end
		local saved, errorCode = NeedsPersistence.SaveMany(rows)
		if saved then
			for _, entry in ipairs(chunk) do
				entry.dirty = false
			end
		else
			logger.log('error', 'needs', 'needs_save_failed', { error_code = errorCode or 'unknown_error', count = #chunk })
		end
	end
end

local function release(source)
	local entry = entries[source]
	if not entry then
		return
	end
	advance(entry, GetGameTimer())
	entries[source] = nil
	if byCharacter[entry.characterId] == source then
		byCharacter[entry.characterId] = nil
	end
	save(entry)
end

local function load(source, characterId)
	release(source)
	local state, errorCode = nil, nil
	local loaded = false
	if not NeedsPersistence.IsReady() then
		local initialized, initError = NeedsPersistence.Initialize()
		if not initialized then
			errorCode = initError or 'unknown_error'
		end
	end
	if NeedsPersistence.IsReady() then
		local stored, loadError = NeedsPersistence.Load(characterId)
		if stored == nil then
			errorCode = loadError
		else
			state = stored or nil
			loaded = true
		end
	end
	if errorCode or not NeedsPersistence.IsReady() then
		logger.log('warn', 'needs', 'needs_load_failed', { error_code = errorCode or 'unknown_error' })
	end

	-- Troca de personagem/saida durante a leitura invalida este carregamento.
	local active = Core.Players.GetActiveCharacterId(source)
	if active ~= characterId then
		return
	end

	local entry = {
		characterId = characterId,
		state = Needs.New(state),
		activity = 'idle',
		at = GetGameTimer(),
		lastReport = 0,
		loaded = loaded,
		dirty = not state
	}
	entries[source] = entry
	byCharacter[characterId] = source
	push(source, entry, true)
end

local function entryFor(source)
	local entry = entries[source]
	if entry then
		advance(entry, GetGameTimer())
	end
	return entry
end

local function callerAllowed()
	local caller = GetInvokingResource()
	return caller == nil or CoeAccess.Allowed(caller, settings.Ace, settings.AllowedResources)
end

exports('GetNeeds', function(source)
	local entry = entryFor(source)
	if not entry then
		return nil
	end
	return Needs.Snapshot(entry.state)
end)

exports('AddNeed', function(source, name, delta)
	if not callerAllowed() then
		return 'caller_not_allowed'
	end
	local entry = entryFor(source)
	if not entry then
		return 'needs_not_loaded'
	end
	local changed, errorCode = Needs.Add(entry.state, name, delta)
	if not changed then
		return errorCode
	end
	entry.dirty = true
	push(source, entry)
	return true
end)

exports('SetNeed', function(source, name, value)
	if not callerAllowed() then
		return 'caller_not_allowed'
	end
	local entry = entryFor(source)
	if not entry then
		return 'needs_not_loaded'
	end
	local changed, errorCode = Needs.Set(entry.state, name, value)
	if not changed then
		return errorCode
	end
	entry.dirty = true
	push(source, entry)
	return true
end)

RegisterNetEvent('coe_needs:activity')
AddEventHandler('coe_needs:activity', function(activity)
	local source = source
	local entry = entries[source]
	if not entry or not Needs.IsActivity(activity) then
		return
	end
	local timestamp = GetGameTimer()
	if timestamp - entry.lastReport < settings.ActivityMinIntervalMs then
		return
	end
	entry.lastReport = timestamp
	advance(entry, timestamp)
	entry.activity = activity
	push(source, entry)
end)

RegisterNetEvent('coe_needs:request')
AddEventHandler('coe_needs:request', function()
	local source = source
	local entry = entryFor(source)
	if entry then
		push(source, entry, true)
		return
	end
	-- Resource iniciado com o personagem ja em jogo: carrega sob demanda.
	local characterId = Core.Players.GetActiveCharacterId(source)
	if characterId and not loading[source] then
		loading[source] = true
		CreateThread(function()
			load(source, characterId)
			loading[source] = nil
		end)
	end
end)

Core.Events.On('player.characterLoaded', function(event)
	if type(event) ~= 'table' or type(event.character) ~= 'table' then
		return
	end
	local source, characterId = event.source, event.character.characterId
	CreateThread(function()
		load(source, characterId)
	end)
end)

Core.Events.On('player.characterUnloaded', function(event)
	if type(event) == 'table' and event.source then
		local source = event.source
		CreateThread(function()
			release(source)
		end)
	end
end)

Core.Events.On('inventory.itemUsed', function(inventoryId, _, item)
	local characterId = type(inventoryId) == 'string' and inventoryId:match('^character:(.+)$')
	local source = characterId and byCharacter[characterId]
	local effects = type(item) == 'table' and settings.ItemEffects[item.name]
	local entry = source and effects and entryFor(source)
	if not entry then
		return
	end
	for name, delta in pairs(effects) do
		Needs.Add(entry.state, name, delta)
	end
	entry.dirty = true
	push(source, entry)
end)

AddEventHandler('playerDropped', function()
	local source = source
	CreateThread(function()
		release(source)
	end)
end)

CreateThread(function()
	while true do
		Wait(settings.TickMs)
		local timestamp = GetGameTimer()
		for source, entry in pairs(entries) do
			advance(entry, timestamp)
			push(source, entry)
		end
	end
end)

CreateThread(function()
	while true do
		Wait(settings.SaveIntervalMs)
		saveDirty()
	end
end)

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		return
	end
	for _, entry in pairs(entries) do
		advance(entry, GetGameTimer())
		save(entry)
	end
end)
