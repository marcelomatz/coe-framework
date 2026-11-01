local config = DoorsConfig
local ready = false

-- places[id] = local (casa, prédio, sede) com várias portas; runtime["local:porta"] = { place, entry }.
local places = {}
local runtime = {}
-- Estado e token por porta (ID de execução): uma trava automática agendada só vale se ninguém mexeu na porta depois.
local lockState = {}
local autoTokens = {}
local lastAction = {}
local pinFailures = {}

local function log(level, category, event, context)
	pcall(function()
		return exports.coe_logging:Log(level, category, event, context)
	end)
end

local function audit(event, context)
	pcall(function()
		return exports.coe_audit:Record('info', 'audit', event, context)
	end)
end

local function notify(playerId, kind, message)
	pcall(function()
		exports.coe_notify:Notify(playerId, kind, message)
	end)
end

local MESSAGES = {
	not_ready = 'Fechaduras ainda iniciando.', no_door = 'Porta indisponível.', too_far = 'Chegue mais perto da porta.',
	no_access = 'Você não tem acesso a esta porta.', wrong_pin = 'Senha incorreta.', no_pin = 'Esta porta não tem senha.',
	pin_locked = 'Muitas tentativas. Aguarde para tentar de novo.', busy = 'Aguarde um instante.'
}

local function fail(playerId, errorCode)
	notify(playerId, 'error', MESSAGES[errorCode] or 'Não foi possível concluir.')
end

-- Exports de outros resources; nil se o resource não está de pé ou falhou.
local function remote(resource, name, ...)
	if GetResourceState(resource) ~= 'started' then
		return nil
	end
	local args = { ... }
	local ok, result = pcall(function()
		return exports[resource][name](exports[resource], table.unpack(args))
	end)
	return ok and result or nil
end

local function throttled(playerId)
	local now = GetGameTimer()
	if lastAction[playerId] and now - lastAction[playerId] < config.Limits.ActionIntervalMs then
		return true
	end
	lastAction[playerId] = now
	return false
end

local function newSalt()
	local parts = {}
	for index = 1, 4 do
		parts[index] = ('%08x'):format(math.random(0, 0x7fffffff))
	end
	return table.concat(parts)
end

local function lockOf(runtimeId)
	return lockState[runtimeId]
end

local function publicList()
	local list = {}
	for _, place in pairs(places) do
		if place.enabled then
			for _, entry in ipairs(DoorsRules.Public(place, lockOf)) do
				list[#list + 1] = entry
			end
		end
	end
	table.sort(list, function(a, b) return a.id < b.id end)
	return list
end

local function broadcastList(target)
	TriggerClientEvent('coe_doors:list', target or -1, publicList())
end

local function setLocked(runtimeId, locked, actor, via)
	local ref = runtime[runtimeId]
	if not ref then
		return false
	end
	lockState[runtimeId] = locked == true
	autoTokens[runtimeId] = (autoTokens[runtimeId] or 0) + 1
	TriggerClientEvent('coe_doors:state', -1, runtimeId, lockState[runtimeId], actor)
	if not lockState[runtimeId] and ref.entry.autoLock > 0 then
		local token = autoTokens[runtimeId]
		SetTimeout(ref.entry.autoLock * 1000, function()
			if autoTokens[runtimeId] == token and runtime[runtimeId] and lockState[runtimeId] == false then
				setLocked(runtimeId, true, nil, 'auto')
			end
		end)
	end
	log('debug', 'doors', 'door_state', { operation = runtimeId, action = lockState[runtimeId] and 'locked' or 'unlocked', source = actor, target = via })
	return true
end

-- Indexa as portas de um local; previous (versão anterior) define o que muda no estado atual.
local function indexPlace(place, previous)
	local oldDefaults = {}
	if previous then
		for _, entry in ipairs(previous.entries) do
			local runtimeId = DoorsRules.RuntimeId(previous, entry)
			oldDefaults[runtimeId] = entry.locked
			runtime[runtimeId] = nil
		end
	end
	for _, entry in ipairs(place.entries) do
		local runtimeId = DoorsRules.RuntimeId(place, entry)
		runtime[runtimeId] = { place = place, entry = entry }
		if lockState[runtimeId] == nil or oldDefaults[runtimeId] ~= entry.locked then
			lockState[runtimeId] = entry.locked
		end
		autoTokens[runtimeId] = (autoTokens[runtimeId] or 0) + 1
		oldDefaults[runtimeId] = nil
	end
	-- Portas removidas do local.
	for runtimeId in pairs(oldDefaults) do
		lockState[runtimeId] = nil
		autoTokens[runtimeId] = (autoTokens[runtimeId] or 0) + 1
	end
end

local function unindexPlace(place)
	for _, entry in ipairs(place.entries) do
		local runtimeId = DoorsRules.RuntimeId(place, entry)
		runtime[runtimeId], lockState[runtimeId] = nil, nil
		autoTokens[runtimeId] = (autoTokens[runtimeId] or 0) + 1
	end
end

-- Aceita o ID de uma porta ("local:porta") ou de um local (todas as portas dele).
local function resolve(id)
	if type(id) ~= 'string' then
		return nil
	end
	local ref = runtime[id]
	if ref then
		return ref.place, { DoorsRules.RuntimeId(ref.place, ref.entry) }
	end
	local place = places[id]
	if not place then
		return nil
	end
	local ids = {}
	for index, entry in ipairs(place.entries) do
		ids[index] = DoorsRules.RuntimeId(place, entry)
	end
	return place, ids
end
-- Fatos do jogador para DoorsRules.CanAccess; cada consulta externa só roda se a regra precisar.
local function factsOf(playerId, characterId)
	local memberships, inventoryId
	return {
		characterId = characterId,
		business = function(businessId)
			local access = remote('coe_businesses', 'Access', businessId, characterId)
			local member = type(access) == 'table' and (access.owner or access.partner or access.staff) == true
			return { member = member, onDuty = member and remote('coe_businesses', 'IsOnDuty', businessId, characterId) == true }
		end,
		factionGrade = function(factionId)
			if memberships == nil then
				memberships = {}
				for _, entry in ipairs(remote('coe_factions', 'Memberships', characterId) or {}) do
					if entry.enabled ~= false then
						memberships[entry.id] = tonumber(entry.grade)
					end
				end
			end
			return memberships[factionId]
		end,
		itemCount = function(name, metadata)
			if inventoryId == nil then
				inventoryId = remote('coe_inventory', 'GetPlayerInventory', playerId) or false
			end
			if not inventoryId then
				return 0
			end
			return tonumber(remote('coe_inventory', 'GetItemCount', inventoryId, name, metadata)) or 0
		end
	}
end

local function nearDoor(playerId, entry)
	local ped = GetPlayerPed(playerId)
	if not ped or ped == 0 then
		return false
	end
	local coords = GetEntityCoords(ped)
	local center = DoorsRules.Center(entry)
	local dx, dy, dz = coords.x - center.x, coords.y - center.y, coords.z - center.z
	return math.sqrt(dx * dx + dy * dy + dz * dz) <= entry.distance + config.ServerSlack
end

-- Validação comum de toggle e senha: retorna o local, a porta e o personagem, ou nil depois de avisar o jogador.
local function usable(playerId, runtimeId)
	if not ready then
		fail(playerId, 'not_ready')
		return nil
	end
	if throttled(playerId) then
		return nil
	end
	local ref = type(runtimeId) == 'string' and runtime[runtimeId] or nil
	if not ref or not ref.place.enabled then
		fail(playerId, 'no_door')
		return nil
	end
	if not nearDoor(playerId, ref.entry) then
		fail(playerId, 'too_far')
		return nil
	end
	local characterId = Core.Players.GetActiveCharacterId(playerId)
	if not characterId then
		fail(playerId, 'no_access')
		return nil
	end
	return ref.place, ref.entry, characterId
end

RegisterNetEvent('coe_doors:request', function()
	local playerId = source
	if ready then
		broadcastList(playerId)
	end
end)

-- Teclado aberto pelo servidor: o jogador só pode responder à etapa pedida (senha do local ou da porta).
local pinPending = {}

local function askPin(playerId, runtimeId, stage, place, entry)
	pinPending[playerId] = { runtimeId = runtimeId, stage = stage, expires = os.time() + 60 }
	local label = DoorsRules.EntryLabel(place, entry)
	if stage == 'entry' then
		label = label .. ' · senha da porta'
	end
	TriggerClientEvent('coe_doors:askPin', playerId, runtimeId, label, lockState[runtimeId])
end

-- Quem já tem acesso: a senha da porta ainda é exigida para destrancar (mesmo com chave ou sendo o dono).
local function proceed(playerId, runtimeId, place, entry, via)
	if lockState[runtimeId] and entry.pin then
		askPin(playerId, runtimeId, 'entry', place, entry)
		return
	end
	setLocked(runtimeId, not lockState[runtimeId], playerId, via)
end

RegisterNetEvent('coe_doors:toggle', function(runtimeId)
	local playerId = source
	local place, entry, characterId = usable(playerId, runtimeId)
	if not place then
		return
	end
	pinPending[playerId] = nil
	local allowed, via = DoorsRules.CanAccess(place, factsOf(playerId, characterId), config, entry)
	if allowed then
		proceed(playerId, runtimeId, place, entry, via)
		return
	end
	-- A senha do local não abre porta exclusiva.
	if place.pin and not entry.restricted then
		askPin(playerId, runtimeId, 'place', place, entry)
		return
	end
	fail(playerId, 'no_access')
end)

RegisterNetEvent('coe_doors:pin', function(runtimeId, pin)
	local playerId = source
	local place, entry = usable(playerId, runtimeId)
	if not place then
		return
	end
	local pending = pinPending[playerId]
	if not pending or pending.runtimeId ~= runtimeId or pending.expires < os.time() then
		pinPending[playerId] = nil
		TriggerClientEvent('coe_doors:pinResult', playerId, runtimeId, true)
		return
	end
	local secret = pending.stage == 'entry' and entry or place
	if not secret.pin then
		pinPending[playerId] = nil
		fail(playerId, 'no_pin')
		TriggerClientEvent('coe_doors:pinResult', playerId, runtimeId, true)
		return
	end
	-- Erros de senha contam por local: trocar de porta da mesma casa não zera as tentativas.
	local key = ('%d:%s'):format(playerId, place.id)
	local record = pinFailures[key]
	local now = os.time()
	if record and record.blockedUntil and record.blockedUntil > now then
		fail(playerId, 'pin_locked')
		return
	end
	if not DoorsRules.PinMatches(secret, pin, config) then
		record = record and not record.blockedUntil and record or { count = 0 }
		record.count = record.count + 1
		if record.count >= config.Pin.MaxAttempts then
			record.blockedUntil = now + config.Pin.LockoutSeconds
			audit('door_pin_lockout', { source = playerId, operation = place.id })
			fail(playerId, 'pin_locked')
		else
			fail(playerId, 'wrong_pin')
		end
		pinFailures[key] = record
		TriggerClientEvent('coe_doors:pinResult', playerId, runtimeId, false)
		return
	end
	pinFailures[key] = nil
	pinPending[playerId] = nil
	TriggerClientEvent('coe_doors:pinResult', playerId, runtimeId, true)
	if pending.stage == 'place' then
		proceed(playerId, runtimeId, place, entry, 'pin')
	else
		setLocked(runtimeId, not lockState[runtimeId], playerId, 'door_pin')
	end
end)
AddEventHandler('playerDropped', function()
	local playerId = source
	lastAction[playerId] = nil
	pinPending[playerId] = nil
	local prefix = tostring(playerId) .. ':'
	for key in pairs(pinFailures) do
		if key:sub(1, #prefix) == prefix then
			pinFailures[key] = nil
		end
	end
end)

-- Cadastro (só coe_admin) ------------------------------------------------------------------------------
local function adminOnly()
	return GetInvokingResource() == 'coe_admin'
end

local function count()
	local total = 0
	for _ in pairs(places) do
		total = total + 1
	end
	return total
end

-- Grava o local já normalizado e atualiza estado, índices e clientes.
local function commit(place, previous)
	local saved, saveError = DoorsPersistence.Save(place)
	if not saved then
		return false, saveError or 'database_error'
	end
	places[place.id] = place
	indexPlace(place, previous)
	broadcastList()
	return true
end

exports('List', function()
	if not adminOnly() then
		return { error = 'forbidden' }
	end
	local list = {}
	for _, place in pairs(places) do
		list[#list + 1] = DoorsRules.Admin(place, lockOf)
	end
	table.sort(list, function(a, b) return a.label < b.label end)
	return list
end)

exports('Save', function(raw)
	if not adminOnly() then
		return { error = 'forbidden' }
	end
	if not ready then
		return { error = 'not_ready' }
	end
	local previous = type(raw) == 'table' and type(raw.id) == 'string' and places[raw.id] or nil
	if raw and raw.isNew == true and previous then
		return { error = 'duplicate_id' }
	end
	if not previous and count() >= config.Limits.MaxDoors then
		return { error = 'door_limit' }
	end
	local place, errorCode = DoorsRules.Normalize(raw, config, previous, newSalt)
	if not place then
		return { error = errorCode }
	end
	local committed, commitError = commit(place, previous)
	if not committed then
		return { error = commitError }
	end
	audit('door_saved', { operation = place.id, action = previous and 'update' or 'create', count = #place.entries })
	return true
end)

exports('Delete', function(placeId)
	if not adminOnly() then
		return { error = 'forbidden' }
	end
	if not ready then
		return { error = 'not_ready' }
	end
	local place = type(placeId) == 'string' and places[placeId] or nil
	if not place then
		return { error = 'unknown_door' }
	end
	local deleted, errorCode = DoorsPersistence.Delete(placeId)
	if not deleted then
		return { error = errorCode or 'database_error' }
	end
	places[placeId] = nil
	unindexPlace(place)
	audit('door_deleted', { operation = placeId })
	broadcastList()
	return true
end)

-- API para outros resources (assaltos, eventos, scripts de negócio) -------------------------------------
-- id: "<local>:<porta>" para uma porta, ou "<local>" para todas as portas do local.
exports('IsLocked', function(id)
	local place, ids = resolve(id)
	if not place then
		return nil
	end
	for _, runtimeId in ipairs(ids) do
		if lockState[runtimeId] ~= true then
			return false
		end
	end
	return true
end)

exports('SetLocked', function(id, locked)
	local place, ids = nil, nil
	if ready then
		place, ids = resolve(id)
	end
	if not place then
		return false
	end
	for _, runtimeId in ipairs(ids) do
		setLocked(runtimeId, locked == true, nil, GetInvokingResource() or 'export')
	end
	return true
end)

exports('CanAccess', function(playerId, id)
	local place = ready and resolve(id) or nil
	local characterId = place and Core.Players.GetActiveCharacterId(playerId) or nil
	if not characterId then
		return false
	end
	local ref = runtime[id]
	return (DoorsRules.CanAccess(place, factsOf(playerId, characterId), config, ref and ref.entry or nil))
end)

exports('IsReady', function()
	return ready
end)

-- App Casa do tablet (só o coe_tablet chama): o dono gerencia acesso exclusivo e senha de cada porta.
local function ownedPlaces(characterId)
	local list = {}
	for _, place in pairs(places) do
		if DoorsRules.IsOwner(place, characterId) then
			list[#list + 1] = place
		end
	end
	table.sort(list, function(a, b) return a.label < b.label end)
	return list
end

exports('TabletVisible', function(playerId)
	if GetInvokingResource() ~= 'coe_tablet' or not ready then
		return false
	end
	local characterId = Core.Players.GetActiveCharacterId(playerId)
	return characterId ~= nil and #ownedPlaces(characterId) > 0
end)

local function resolveTarget(stateId)
	local character, errorCode = Core.Players.GetCharacterByStateId(stateId)
	if not character then
		return nil, errorCode == 'character_not_online' and 'target_not_online' or 'target_not_found'
	end
	local name = ((character.firstName or '') .. ' ' .. (character.lastName or '')):gsub('^%s+', ''):gsub('%s+$', '')
	return { characterId = tostring(character.characterId), name = name:sub(1, 48) }
end

-- Cada ação devolve a porta (cópia editável da visão do admin) para a função alterar; nil + erro recusa.
local TABLET_ACTIONS = {
	restrict = function(entry, payload)
		entry.restricted = payload.restricted == true
		return true
	end,
	allow = function(entry, payload, place)
		local stateId = tonumber(payload.stateId)
		if not stateId or stateId % 1 ~= 0 or stateId < 1 then
			return nil, 'target_not_found'
		end
		local target, errorCode = resolveTarget(stateId)
		if not target then
			return nil, errorCode
		end
		if DoorsRules.IsOwner(place, target.characterId) then
			return nil, 'is_owner'
		end
		for _, allowed in ipairs(entry.allowed) do
			if allowed.characterId == target.characterId then
				return nil, 'already_allowed'
			end
		end
		if #entry.allowed >= config.Limits.MaxEntryCharacters then
			return nil, 'allowed_limit'
		end
		entry.allowed[#entry.allowed + 1] = target
		return true
	end,
	revoke = function(entry, payload)
		for index, allowed in ipairs(entry.allowed) do
			if allowed.characterId == tostring(payload.characterId) then
				table.remove(entry.allowed, index)
				return true
			end
		end
		return nil, 'unknown_person'
	end,
	pin = function(entry, payload)
		if not DoorsRules.ValidPin(payload.pin, config) then
			return nil, 'invalid_pin'
		end
		entry.pin = payload.pin
		return true
	end,
	clearPin = function(entry)
		entry.clearPin = true
		return true
	end
}

exports('TabletCall', function(playerId, _, action, payload)
	if GetInvokingResource() ~= 'coe_tablet' then
		log('warn', 'security', 'doors_tablet_forbidden', { operation = GetInvokingResource() or 'unknown' })
		return { ok = false, error = 'forbidden' }
	end
	if not ready then
		return { ok = false, error = 'not_ready' }
	end
	local characterId = Core.Players.GetActiveCharacterId(playerId)
	if not characterId then
		return { ok = false, error = 'no_character' }
	end
	if action == 'list' then
		local list = {}
		for index, place in ipairs(ownedPlaces(characterId)) do
			list[index] = DoorsRules.OwnerView(place, lockOf)
		end
		return { ok = true, places = list, maxAllowed = config.Limits.MaxEntryCharacters }
	end
	local handler = TABLET_ACTIONS[action]
	if not handler then
		return { ok = false, error = 'unknown_action' }
	end
	if type(payload) ~= 'table' then
		payload = {}
	end
	local previous = type(payload.place) == 'string' and places[payload.place] or nil
	if not previous or not DoorsRules.IsOwner(previous, characterId) then
		return { ok = false, error = 'not_owner' }
	end
	local raw = DoorsRules.Admin(previous, lockOf)
	local target = nil
	for _, entry in ipairs(raw.entries) do
		if entry.key == payload.key then
			target = entry
		end
	end
	if not target then
		return { ok = false, error = 'unknown_entry' }
	end
	local copied = {}
	for index, allowed in ipairs(target.allowed) do
		copied[index] = { characterId = allowed.characterId, name = allowed.name }
	end
	target.allowed = copied
	local changed, changeError = handler(target, payload, previous)
	if not changed then
		return { ok = false, error = changeError }
	end
	local place, errorCode = DoorsRules.Normalize(raw, config, previous, newSalt)
	if not place then
		return { ok = false, error = errorCode }
	end
	local committed, commitError = commit(place, previous)
	if not committed then
		return { ok = false, error = commitError }
	end
	audit('door_owner_' .. action, { operation = previous.id, target = payload.key, character_id = characterId })
	return { ok = true }
end)
CreateThread(function()
	math.randomseed(os.time() + GetGameTimer())
	local waitingLogged = false
	while true do
		local initialized, errorCode = DoorsPersistence.Initialize()
		if initialized then
			break
		end
		if errorCode == 'database_not_ready' then
			if not waitingLogged then
				log('info', 'persistence', 'database_waiting', {})
				waitingLogged = true
			end
			Wait(1000)
		else
			log('error', 'persistence', 'database_initialization_failed', { error_code = errorCode or 'database_error', retry_ms = 5000 })
			Wait(5000)
		end
	end
	local list, errorCode = DoorsPersistence.List()
	if not list then
		log('error', 'persistence', 'doors_load_failed', { error_code = errorCode or 'database_error' })
		list = {}
	end
	for _, stored in ipairs(list) do
		local copy = {}
		for key, value in pairs(stored) do
			copy[key] = value
		end
		copy.pin = nil
		-- O cadastro gravado é a versão anterior: mantém as senhas (do local e de cada porta) já com hash.
		local place, normalizeError = DoorsRules.Normalize(copy, config, stored, newSalt)
		if place then
			places[place.id] = place
			indexPlace(place, nil)
		else
			log('warn', 'doors', 'door_invalid', { operation = tostring(stored.id), error_code = normalizeError })
		end
	end
	ready = true
	log('info', 'doors', 'doors_ready', { count = count() })
	broadcastList()
end)
