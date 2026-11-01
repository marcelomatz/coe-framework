local config = FactionsConfig
local factions, order = {}, {}
local ready = false

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

-- Vários retornos se perdem entre resources: devolvemos um valor só, ou { error = codigo }.
local function packResult(value, errorCode)
	if value then
		return value
	end
	return { error = errorCode or 'database_error' }
end

local function caller()
	return GetInvokingResource()
end

local function isAdmin()
	return config.AdminResources[caller()] == true
end

local function isReader()
	local resource = caller()
	return config.ReaderResources[resource] == true or config.AdminResources[resource] == true
end

local function rebuild(list)
	factions, order = {}, {}
	for _, faction in ipairs(list) do
		factions[faction.id] = faction
		order[#order + 1] = faction
	end
	table.sort(order, function(a, b)
		return a.id < b.id
	end)
end

local function reload()
	local list, errorCode = FactionsPersistence.ListFactions()
	if not list then
		return nil, errorCode
	end
	rebuild(list)
	return true
end

local function notifyChanged()
	TriggerEvent('coe_factions:changed')
end

local function saveFaction(raw)
	if not ready then
		return nil, 'not_ready'
	end
	local faction, errorCode = FactionsRules.Normalize(raw, config)
	if not faction then
		return nil, errorCode
	end
	if not factions[faction.id] and #order >= config.Limits.MaxFactions then
		return nil, 'faction_limit'
	end
	if factions[faction.id] then
		local used, usedError = FactionsPersistence.GradesInUse(faction.id)
		if not used then
			return nil, usedError
		end
		for grade in pairs(used) do
			if not FactionsRules.HasGrade(faction, grade) then
				return nil, 'grade_in_use'
			end
		end
	end
	local saved, saveError = FactionsPersistence.SaveFaction(faction)
	if not saved then
		return nil, saveError or 'database_error'
	end
	reload()
	notifyChanged()
	audit('faction_saved', { operation = faction.id })
	return factions[faction.id] or faction
end

local function deleteFaction(factionId)
	if not ready then
		return nil, 'not_ready'
	end
	if type(factionId) ~= 'string' or not factions[factionId] then
		return nil, 'unknown_faction'
	end
	local removed, errorCode = FactionsPersistence.DeleteFaction(factionId)
	if not removed then
		return nil, errorCode or 'database_error'
	end
	reload()
	notifyChanged()
	audit('faction_deleted', { operation = factionId })
	return true
end

local function validCharacterId(characterId)
	return type(characterId) == 'string' and characterId:match('^%d+$') ~= nil and #characterId <= 20
end

local function setMember(factionId, characterId, grade)
	if not ready then
		return nil, 'not_ready'
	end
	local faction = factions[tostring(factionId)]
	if not faction then
		return nil, 'unknown_faction'
	end
	if not validCharacterId(characterId) then
		return nil, 'invalid_character'
	end
	if type(grade) ~= 'number' or not FactionsRules.HasGrade(faction, grade) then
		return nil, 'invalid_grade'
	end
	if not FactionsPersistence.CharacterExists(characterId) then
		return nil, 'character_not_found'
	end
	if not FactionsPersistence.IsMember(faction.id, characterId)
		and FactionsPersistence.CountMembers(faction.id) >= config.Limits.MaxMembers then
		return nil, 'member_limit'
	end
	local saved, errorCode = FactionsPersistence.SetMember(faction.id, characterId, grade)
	if not saved then
		return nil, errorCode or 'database_error'
	end
	notifyChanged()
	audit('faction_member_set', { operation = faction.id, character_id = characterId, grade = grade })
	return { factionId = faction.id, characterId = characterId, grade = grade }
end

local function removeMember(factionId, characterId)
	if not ready then
		return nil, 'not_ready'
	end
	if type(factionId) ~= 'string' or not factions[factionId] then
		return nil, 'unknown_faction'
	end
	if not validCharacterId(characterId) then
		return nil, 'invalid_character'
	end
	local removed, errorCode = FactionsPersistence.RemoveMember(factionId, characterId)
	if not removed then
		return nil, errorCode or 'database_error'
	end
	notifyChanged()
	audit('faction_member_removed', { operation = factionId, character_id = characterId })
	return true
end

-- Receitas liberadas ao personagem por todas as facções ativas dele: { { recipe, factionId, grade } }.
local function recipesFor(characterId)
	local memberships = FactionsPersistence.MembershipsOf(characterId)
	local result, seen = {}, {}
	for factionId, grade in pairs(memberships or {}) do
		local faction = factions[factionId]
		for _, recipe in ipairs(FactionsRules.RecipesFor(faction, grade)) do
			if not seen[recipe] then
				seen[recipe] = true
				result[#result + 1] = { recipe = recipe, factionId = factionId, grade = grade }
			end
		end
	end
	table.sort(result, function(a, b)
		return a.recipe < b.recipe
	end)
	return result
end

exports('IsReady', function()
	return ready
end)

exports('Categories', function()
	local list = {}
	for id, label in pairs(config.Categories) do
		list[#list + 1] = { id = id, label = label }
	end
	table.sort(list, function(a, b)
		return a.id < b.id
	end)
	return list
end)

exports('List', function()
	if not isReader() or not ready then
		return {}
	end
	return order
end)

exports('Get', function(factionId)
	if not isReader() or not ready or type(factionId) ~= 'string' then
		return nil
	end
	return factions[factionId]
end)

exports('Save', function(raw)
	if not isAdmin() then
		return { error = 'forbidden' }
	end
	return packResult(saveFaction(raw))
end)

exports('Delete', function(factionId)
	if not isAdmin() then
		return { error = 'forbidden' }
	end
	return packResult(deleteFaction(factionId))
end)

exports('Members', function(factionId)
	if not isAdmin() or type(factionId) ~= 'string' or not factions[factionId] then
		return {}
	end
	return FactionsPersistence.ListMembers(factionId) or {}
end)

exports('SetMember', function(factionId, characterId, grade)
	if not isAdmin() then
		return { error = 'forbidden' }
	end
	return packResult(setMember(factionId, characterId, grade))
end)

exports('RemoveMember', function(factionId, characterId)
	if not isAdmin() then
		return { error = 'forbidden' }
	end
	return packResult(removeMember(factionId, characterId))
end)

-- Facções do personagem: { { id, label, category, grade, gradeLabel } }.
local function memberships(characterId)
	if not ready or not validCharacterId(characterId) then
		return {}
	end
	local result = {}
	for factionId, grade in pairs(FactionsPersistence.MembershipsOf(characterId) or {}) do
		local faction = factions[factionId]
		if faction then
			local gradeLabel = tostring(grade)
			for _, entry in ipairs(faction.grades) do
				if entry.grade == grade then
					gradeLabel = entry.label
				end
			end
			result[#result + 1] = {
				id = faction.id, label = faction.label, category = faction.category,
				enabled = faction.enabled, grade = grade, gradeLabel = gradeLabel
			}
		end
	end
	table.sort(result, function(a, b)
		return a.id < b.id
	end)
	return result
end

exports('Memberships', function(characterId)
	if not isReader() then
		return {}
	end
	return memberships(characterId)
end)

-- Facção no dossiê do menu de pausa (coe_pausemenu:RegisterFactionProvider): a primeira facção ativa do personagem.
exports('PauseMenuFaction', function(characterId)
	if GetInvokingResource() ~= 'coe_pausemenu' then
		return nil
	end
	for _, membership in ipairs(memberships(characterId)) do
		if membership.enabled ~= false then
			return { label = membership.label, grade = membership.gradeLabel }
		end
	end
	return nil
end)

local function registerPauseMenu()
	if GetResourceState('coe_pausemenu') ~= 'started' then
		return
	end
	local ok, result = pcall(function()
		return exports.coe_pausemenu:RegisterFactionProvider('PauseMenuFaction')
	end)
	if not ok or result ~= true then
		log('warn', 'system', 'factions_pausemenu_failed', { error_code = ok and type(result) == 'table' and tostring(result.error) or 'unavailable' })
	end
end

AddEventHandler('onResourceStart', function(resource)
	if resource == 'coe_pausemenu' then
		registerPauseMenu()
	end
end)
CreateThread(registerPauseMenu)

exports('RecipesFor', function(characterId)
	if not isReader() or not ready or not validCharacterId(characterId) then
		return {}
	end
	return recipesFor(characterId)
end)

exports('CanCraft', function(characterId, recipeId)
	if not isReader() or not ready or not validCharacterId(characterId) or type(recipeId) ~= 'string' then
		return false
	end
	for _, entry in ipairs(recipesFor(characterId)) do
		if entry.recipe == recipeId then
			return true
		end
	end
	return false
end)

-- Receitas liberadas especificamente numa facção para o membro; nil se não for membro ou facção inativa.
exports('RecipesForFaction', function(factionId, characterId)
	if not isReader() or not ready or type(factionId) ~= 'string' or not validCharacterId(characterId) then
		return nil
	end
	local faction = factions[factionId]
	if not faction or faction.enabled == false then
		return nil
	end
	local memberships = FactionsPersistence.MembershipsOf(characterId) or {}
	local grade = memberships[factionId]
	if grade == nil then
		return nil
	end
	return FactionsRules.RecipesFor(faction, grade)
end)

exports('CanCraftInFaction', function(factionId, characterId, recipeId)
	if not isReader() or not ready or type(factionId) ~= 'string' or not validCharacterId(characterId) or type(recipeId) ~= 'string' then
		return false
	end
	local faction = factions[factionId]
	if not faction or faction.enabled == false then
		return false
	end
	local memberships = FactionsPersistence.MembershipsOf(characterId) or {}
	local grade = memberships[factionId]
	if grade == nil then
		return false
	end
	return FactionsRules.CanCraft(faction, grade, recipeId)
end)

CreateThread(function()
	local waitingLogged = false
	while true do
		local initialized, errorCode = FactionsPersistence.Initialize()
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
	while true do
		local loaded, errorCode = reload()
		if loaded then
			break
		end
		log('error', 'persistence', 'factions_load_failed', { error_code = errorCode or 'database_error', retry_ms = 5000 })
		Wait(5000)
	end
	ready = true
	TriggerEvent('coe_factions:ready')
	log('info', 'system', 'started', { count = #order })
end)

-- COE OS (coe_tablet): um app por facção ativa do personagem. Só leitura: membros, cargos e crafts liberados.
local tabletDeps = {
	config = config,
	caller = caller,
	ready = function() return ready end,
	characterOf = function(playerId) return Core.Players.GetActiveCharacterId(playerId) end,
	get = function(factionId) return factions[factionId] end,
	membershipsOf = function(characterId) return FactionsPersistence.MembershipsOf(characterId) end,
	listMembers = function(factionId) return FactionsPersistence.ListMembers(factionId) end
}

exports('TabletInstances', function(playerId)
	return FactionsTablet.Instances(tabletDeps, playerId)
end)

exports('TabletCall', function(playerId, appId, action, payload, factionId)
	return FactionsTablet.Call(tabletDeps, playerId, appId, action, payload, factionId)
end)