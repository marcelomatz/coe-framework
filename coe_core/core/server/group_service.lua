-- Grupos do personagem ativo: cache por sessão, consulta e atribuição.
-- A autorização de quem atribui é responsabilidade do chamador (ex.: coe_admin).
Core.Groups = Core.Groups or {}

local log = CoeLogger.Create('coe_core').log
local cache = {}
local handlers = {}

local function resolveActive(characterId, links)
	local groups = {}
	for _, link in ipairs(links) do
		if link.active then
			local definition = Core.Groups.Get(link.name)
			if definition and definition.type == link.type and Core.Groups.GetGradeLabel(link.name, link.grade) then
				groups[link.type] = { name = link.name, grade = link.grade }
			else
				-- Grupo ou grau removido do arquivo: o vínculo é preservado, mas não vale nada.
				log('warn', 'lifecycle', 'group_membership_ignored', {
					character_id = characterId,
					group = link.name
				})
			end
		end
	end
	return groups
end

-- ACE: o jogador herda coe.group.<grupo> e coe.group.<grupo>.<grau>; cada grau herda os inferiores
-- (montado em Start). Só nomes e graus já validados chegam ao ExecuteCommand.
local function revokePrincipals(source, entry)
	for _, principal in ipairs(entry.principals or {}) do
		ExecuteCommand(('remove_principal player.%d %s'):format(source, principal))
	end
	entry.principals = {}
end

local function grantPrincipals(source, entry)
	revokePrincipals(source, entry)
	for _, membership in pairs(entry.groups) do
		for _, principal in ipairs({
			('coe.group.%s'):format(membership.name),
			('coe.group.%s.%d'):format(membership.name, membership.grade)
		}) do
			ExecuteCommand(('add_principal player.%d %s'):format(source, principal))
			entry.principals[#entry.principals + 1] = principal
		end
	end
end

local function dropEntry(source)
	local entry = cache[source]
	if entry then
		revokePrincipals(source, entry)
		cache[source] = nil
	end
end

local hierarchy = {}

local function buildHierarchy()
	for _, group in ipairs(Core.Groups.List()) do
		for index = 2, #group.grades do
			local child = ('coe.group.%s.%d'):format(group.name, group.grades[index].grade)
			local parent = ('coe.group.%s.%d'):format(group.name, group.grades[index - 1].grade)
			ExecuteCommand(('add_principal %s %s'):format(child, parent))
			hierarchy[#hierarchy + 1] = { child = child, parent = parent }
		end
	end
end

local function entryFor(source, generation, characterId)
	local entry = cache[source]
	if entry and entry.generation == generation and entry.characterId == characterId then
		return entry
	end
	return nil
end

local function findOnlineEntry(characterId)
	for source, entry in pairs(cache) do
		if entry.characterId == characterId then
			return source, entry
		end
	end
	return nil
end

local function onCharacterLoaded(event)
	if type(event) ~= 'table' or not Core.Functions.IsInteger(event.source) or type(event.character) ~= 'table' then
		return
	end
	local source, generation = event.source, event.generation
	local characterId = event.character.characterId
	if not Core.SessionRegistry.IsCurrent(source, generation) then
		return
	end

	-- Sem grupos até a carga terminar (falha fechada).
	dropEntry(source)
	cache[source] = { generation = generation, characterId = characterId, groups = {}, principals = {} }
	local dispatched, dispatchError = Core.Groups.LoadLinks(characterId, function(success, links, errorMessage)
		local entry = entryFor(source, generation, characterId)
		if not entry then
			return
		end
		if not success then
			log('error', 'lifecycle', 'group_load_failed', {
				player_id = source,
				error_code = errorMessage or 'unknown_error'
			})
			return
		end
		entry.groups = resolveActive(characterId, links)
		grantPrincipals(source, entry)
	end)
	if not dispatched then
		log('error', 'lifecycle', 'group_load_failed', {
			player_id = source,
			error_code = dispatchError or 'unknown_error'
		})
	end
end

local function onSessionEnd(event)
	if type(event) ~= 'table' or not Core.Functions.IsInteger(event.source) then
		return
	end
	local entry = cache[event.source]
	if entry and (event.generation == nil or entry.generation == event.generation) then
		dropEntry(event.source)
	end
end

function Core.Groups.Start()
	Core.Groups.Stop()
	buildHierarchy()
	for eventName, callback in pairs({
		['player.characterLoaded'] = onCharacterLoaded,
		['player.characterUnloaded'] = onSessionEnd,
		['player.sessionEnded'] = onSessionEnd
	}) do
		local handler, errorMessage = Core.Events.On(eventName, callback)
		if not handler then
			Core.Groups.Stop()
			return false, errorMessage or 'event_registration_failed'
		end
		handlers[#handlers + 1] = handler
	end
	return true
end

function Core.Groups.Stop()
	for _, handler in ipairs(handlers) do
		Core.Events.Remove(handler)
	end
	handlers = {}
	for source in pairs(cache) do
		dropEntry(source)
	end
	for _, link in ipairs(hierarchy) do
		ExecuteCommand(('remove_principal %s %s'):format(link.child, link.parent))
	end
	hierarchy = {}
end

-- { [type] = { name, grade } } do personagem ativo.
function Core.Groups.GetCharacterGroups(source)
	local entry = Core.Functions.IsInteger(source) and cache[source]
	if not entry then
		return nil, 'character_not_loaded'
	end

	local groups = {}
	for groupType, membership in pairs(entry.groups) do
		groups[groupType] = { name = membership.name, grade = membership.grade }
	end
	return groups
end

function Core.Groups.Has(source, name, minGrade)
	if not Core.Groups.IsValidName(name) then
		return false
	end
	if minGrade == nil then
		minGrade = 0
	elseif not Core.Functions.IsInteger(minGrade) then
		return false
	end

	local entry = Core.Functions.IsInteger(source) and cache[source]
	if not entry then
		return false
	end
	for _, membership in pairs(entry.groups) do
		if membership.name == name then
			return membership.grade >= minGrade
		end
	end
	return false
end

local function emitChanged(characterId, source, groupType, group, grade, previous)
	Core.Events.Emit('player.groupChanged', {
		source = source,
		characterId = characterId,
		type = groupType,
		group = group,
		grade = grade,
		previous = previous
	})
end

-- Torna o grupo ativo no seu tipo, com o grau dado. O grupo ativo anterior do mesmo tipo fica inativo.
function Core.Groups.Set(characterId, name, grade, callback)
	if type(callback) ~= 'function' then
		return false, 'invalid_callback'
	end
	if not Core.Identity.IsValidCharacterId(characterId) then
		return false, 'invalid_character_id'
	end
	local group, groupError = Core.Groups.Get(name)
	if not group then
		return false, groupError
	end
	if not Core.Functions.IsInteger(grade) or not Core.Groups.GetGradeLabel(name, grade) then
		return false, 'invalid_grade'
	end

	return Core.Groups.LoadLinks(characterId, function(loaded, links, loadError)
		if not loaded then
			callback(false, nil, loadError)
			return
		end

		local previous
		for _, link in ipairs(links) do
			if link.active and link.type == group.type then
				previous = { name = link.name, grade = link.grade }
			end
		end

		local written, writeError = Core.Groups.WriteLink(characterId, group, grade, function(success, errorMessage)
			if not success then
				callback(false, nil, errorMessage)
				return
			end

			local source, entry = findOnlineEntry(characterId)
			if entry then
				entry.groups[group.type] = { name = group.name, grade = grade }
				grantPrincipals(source, entry)
			end
			emitChanged(characterId, source, group.type, group.name, grade, previous)
			callback(true, { type = group.type, group = group.name, grade = grade, previous = previous })
		end)
		if not written then
			callback(false, nil, writeError)
		end
	end)
end

-- Remove o vínculo do personagem com o grupo (idempotente).
function Core.Groups.Remove(characterId, name, callback)
	if type(callback) ~= 'function' then
		return false, 'invalid_callback'
	end
	if not Core.Identity.IsValidCharacterId(characterId) then
		return false, 'invalid_character_id'
	end
	if not Core.Groups.IsValidName(name) then
		return false, 'invalid_group_name'
	end

	return Core.Groups.LoadLinks(characterId, function(loaded, links, loadError)
		if not loaded then
			callback(false, nil, loadError)
			return
		end

		local existing
		for _, link in ipairs(links) do
			if link.name == name then
				existing = link
			end
		end
		if not existing then
			callback(true, { removed = false })
			return
		end

		local deleted, deleteError = Core.Groups.DeleteLink(characterId, name, function(success, errorMessage)
			if not success then
				callback(false, nil, errorMessage)
				return
			end

			local source, entry = findOnlineEntry(characterId)
			local previous
			if existing.active then
				previous = { name = existing.name, grade = existing.grade }
				if entry and entry.groups[existing.type] and entry.groups[existing.type].name == name then
					entry.groups[existing.type] = nil
					grantPrincipals(source, entry)
				end
				emitChanged(characterId, source, existing.type, nil, nil, previous)
			end
			callback(true, { removed = true, type = existing.type, previous = previous })
		end)
		if not deleted then
			callback(false, nil, deleteError)
		end
	end)
end

-- Variantes por source (personagem ativo), usadas pela administração.
local function activeCharacterId(source)
	local session = Core.Functions.IsInteger(source) and Core.SessionRegistry.Get(source)
	if not session or session.state ~= 'character_loaded' or not session.character then
		return nil, 'character_not_loaded'
	end
	return session.character.characterId
end

function Core.Groups.SetForPlayer(source, name, grade, callback)
	local characterId, errorMessage = activeCharacterId(source)
	if not characterId then
		return false, errorMessage
	end
	return Core.Groups.Set(characterId, name, grade, callback)
end

function Core.Groups.RemoveForPlayer(source, name, callback)
	local characterId, errorMessage = activeCharacterId(source)
	if not characterId then
		return false, errorMessage
	end
	return Core.Groups.Remove(characterId, name, callback)
end
