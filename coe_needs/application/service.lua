local settings = Config.Needs
local logger = CoeLogger.Create('coe_needs')

-- characterId -> { source, state, activity, lastStepAt, lastActivityEventAt, sentSnapshot, dirty, persistable, lastConsume }
local byCharacter = {}
-- playerSource -> characterId
local bySource = {}

local function isAllowed()
	local caller = GetInvokingResource() or GetCurrentResourceName()
	return CoeAccess.Allowed(caller, settings.Ace, settings.AllowedResources)
end

local function log(level, category, event, fields)
	logger.log(level, category, event, fields)
end

local function normalizeCharacterId(value)
	if type(value) == 'number' and value % 1 == 0 and value > 0 then
		return tostring(value)
	end
	if type(value) == 'string' and #value >= 1 and #value <= 64 then
		return value
	end
	return nil
end

local function advance(entry, now)
	local elapsed = (now - entry.lastStepAt) / 1000
	entry.lastStepAt = now
	if elapsed <= 0 then
		return
	end
	if elapsed > settings.MaxElapsedSeconds then
		elapsed = settings.MaxElapsedSeconds
	end
	Needs.Step(entry.state, entry.activity, elapsed)
	entry.dirty = true
end

local function sendIfChanged(entry, force)
	local snap = Needs.Snapshot(entry.state)
	if not force and Needs.SnapshotEquals(snap, entry.sentSnapshot) then
		return
	end
	entry.sentSnapshot = snap
	TriggerClientEvent('coe_needs:state', entry.source, snap)
end

local function hasPhysicalBuff(effect)
	return type(effect) == 'table' and (
		(tonumber(effect.health) or 0) ~= 0
		or (tonumber(effect.armor) or 0) ~= 0
		or (tonumber(effect.energy) or 0) ~= 0
	)
end

local function getEntryBySource(playerSource)
	local characterId = bySource[playerSource]
	local entry = characterId and byCharacter[characterId] or nil
	if not entry then
		local active = normalizeCharacterId(Core.Players.GetActiveCharacterId(playerSource))
		entry = active and byCharacter[active] or nil
		if entry then
			bySource[playerSource] = active
		end
	end
	return entry, characterId
end

local function loadForPlayer(playerSource, characterId)
	if not NeedsPersistence.IsReady() then
		NeedsPersistence.Initialize()
	end
	local stored, loadErr = NeedsPersistence.Load(characterId)
	local persistable = stored ~= nil
	if stored == nil then
		log('warn', 'database', 'needs_load_failed', { character_id = characterId, error = loadErr })
	end
	if Core.Players.GetActiveCharacterId(playerSource) ~= nil
		and normalizeCharacterId(Core.Players.GetActiveCharacterId(playerSource)) ~= characterId then
		return
	end
	local now = GetGameTimer()
	local entry = {
		source = playerSource,
		state = Needs.New(stored or nil),
		activity = 'idle',
		lastStepAt = now,
		lastActivityEventAt = 0,
		sentSnapshot = nil,
		dirty = stored == false,
		persistable = persistable,
		lastConsume = nil
	}
	byCharacter[characterId] = entry
	bySource[playerSource] = characterId
	sendIfChanged(entry, true)
end

local function unloadSource(playerSource)
	local characterId = bySource[playerSource]
	bySource[playerSource] = nil
	if not characterId then
		return
	end
	local entry = byCharacter[characterId]
	if not entry or entry.source ~= playerSource then
		return
	end
	advance(entry, GetGameTimer())
	byCharacter[characterId] = nil
	if entry.persistable and entry.dirty then
		local state = entry.state
		CreateThread(function()
			NeedsPersistence.Save(characterId, state)
		end)
	end
end

-- Exports (server) -------------------------------------------------------------

local function getNeeds(playerSource)
	local entry = getEntryBySource(playerSource)
	if not entry then
		return nil
	end
	advance(entry, GetGameTimer())
	return Needs.Snapshot(entry.state)
end

local function mutateNeed(op, playerSource, needName, value)
	if not isAllowed() then
		log('warn', 'security', 'needs_unauthorized_call', { caller = tostring(GetInvokingResource()) })
		return false, 'caller_not_allowed'
	end
	local entry = getEntryBySource(playerSource)
	if not entry then
		return false, 'character_not_loaded'
	end
	advance(entry, GetGameTimer())
	local ok, err = op(entry.state, needName, value)
	if not ok then
		return false, err
	end
	entry.dirty = true
	sendIfChanged(entry, false)
	return true
end

exports('GetNeeds', getNeeds)
exports('SetNeed', function(playerSource, needName, value)
	local ok, err = mutateNeed(Needs.Set, playerSource, needName, value)
	return ok or err
end)
exports('AddNeed', function(playerSource, needName, delta)
	local ok, err = mutateNeed(Needs.Add, playerSource, needName, delta)
	return ok or err
end)

-- Eventos ----------------------------------------------------------------------

RegisterNetEvent('coe_needs:activity')
AddEventHandler('coe_needs:activity', function(activity)
	local playerSource = source
	if not Needs.IsActivity(activity) then
		return
	end
	local entry = getEntryBySource(playerSource)
	if not entry then
		return
	end
	local now = GetGameTimer()
	if now - entry.lastActivityEventAt < settings.ActivityMinIntervalMs then
		return
	end
	entry.lastActivityEventAt = now
	advance(entry, now)
	entry.activity = activity
end)

Core.Events.On('player.characterLoaded', function(payload)
	if type(payload) ~= 'table' then
		return
	end
	local playerSource = tonumber(payload.source)
	local character = type(payload.character) == 'table' and payload.character or nil
	local characterId = character and normalizeCharacterId(character.characterId or character.id) or nil
	if not playerSource or not characterId then
		return
	end
	unloadSource(playerSource)
	CreateThread(function()
		loadForPlayer(playerSource, characterId)
	end)
end)

Core.Events.On('player.characterUnloaded', function(payload)
	local playerSource = type(payload) == 'table' and tonumber(payload.source) or nil
	if playerSource then
		unloadSource(playerSource)
	end
end)

AddEventHandler('playerDropped', function()
	unloadSource(source)
end)

-- Consumo de item pelo coe_inventory (mesmo padrao de id: 'character:<id>').
Core.Events.On('inventory.itemUsed', function(inventoryId, _, item)
	if type(inventoryId) ~= 'string' or type(item) ~= 'table' then
		return
	end
	local effect = settings.ItemEffects[item.name]
	if not effect then
		return
	end
	local characterId = inventoryId:match('^character:(.+)$')
	local entry = characterId and byCharacter[characterId] or nil
	if not entry then
		return
	end
	advance(entry, GetGameTimer())
	entry.lastConsume = {
		itemName = item.name,
		beforeState = Needs.Copy(entry.state),
		effect = effect
	}
	for _, needName in ipairs(settings.Names) do
		local delta = effect[needName]
		if delta ~= nil then
			Needs.Add(entry.state, needName, delta)
		end
	end
	entry.dirty = true
	sendIfChanged(entry, false)
	if hasPhysicalBuff(effect) then
		TriggerClientEvent('coe_needs:effect', entry.source, {
			item = item.name,
			health = tonumber(effect.health) or 0,
			armor = tonumber(effect.armor) or 0,
			energy = tonumber(effect.energy) or 0
		})
	end
end)

-- Cancelamento de consumo pelo jogador (tecla X no coe_inventory): reverte os status aplicados.
Core.Events.On('inventory.itemUseCancelled', function(inventoryId, _, item)
	if type(inventoryId) ~= 'string' or type(item) ~= 'table' then
		return
	end
	local characterId = inventoryId:match('^character:(.+)$')
	local entry = characterId and byCharacter[characterId] or nil
	if not entry or not entry.lastConsume or entry.lastConsume.itemName ~= item.name then
		return
	end
	local snapshotBefore = entry.lastConsume.beforeState
	local effect = entry.lastConsume.effect
	entry.lastConsume = nil
	entry.state = Needs.Copy(snapshotBefore)
	entry.lastStepAt = GetGameTimer()
	entry.dirty = true
	sendIfChanged(entry, true)
	if hasPhysicalBuff(effect) then
		TriggerClientEvent('coe_needs:cancelEffect', entry.source, {
			item = item.name,
			health = tonumber(effect.health) or 0,
			armor = tonumber(effect.armor) or 0,
			energy = tonumber(effect.energy) or 0
		})
	end
end)

-- Loops de progressao e persistencia ------------------------------------------

CreateThread(function()
	NeedsPersistence.Initialize()
	while true do
		Wait(settings.TickIntervalMs)
		local now = GetGameTimer()
		for _, entry in pairs(byCharacter) do
			advance(entry, now)
			sendIfChanged(entry, false)
		end
	end
end)

CreateThread(function()
	while true do
		Wait(settings.SaveIntervalMs)
		if NeedsPersistence.IsReady() then
			local now = GetGameTimer()
			local batch = {}
			for characterId, entry in pairs(byCharacter) do
				advance(entry, now)
				if entry.persistable and entry.dirty then
					batch[#batch + 1] = { characterId, Needs.Snapshot(entry.state), entry }
				end
			end
			if #batch > 0 and NeedsPersistence.SaveMany(batch) then
				for i = 1, #batch do
					batch[i][3].dirty = false
				end
			end
		end
	end
end)
