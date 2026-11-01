-- COE OS (coe_tablet): um app por facção ativa do personagem. Só leitura: membros, cargos e crafts liberados.
FactionsTablet = {}

local function fail(code)
	return { ok = false, error = code }
end

local function allowed(deps)
	local config = deps.config or FactionsConfig
	local caller = deps.caller and deps.caller() or ''
	return config.TabletResources[caller] == true and (deps.ready == nil or deps.ready())
end

function FactionsTablet.Instances(deps, playerId)
	if not allowed(deps) then
		return {}
	end
	local characterId = deps.characterOf and deps.characterOf(tonumber(playerId)) or nil
	local result = {}
	for factionId in pairs(characterId and deps.membershipsOf(tostring(characterId)) or {}) do
		local faction = deps.get(factionId)
		if faction and faction.enabled ~= false then
			result[#result + 1] = { id = faction.id, label = faction.label }
		end
	end
	table.sort(result, function(a, b) return a.label < b.label end)
	return result
end

function FactionsTablet.Call(deps, playerId, appId, action, _, factionId)
	if not allowed(deps) or appId ~= 'faction' then
		return fail('forbidden')
	end
	if action ~= 'overview' then
		return fail('unknown_action')
	end
	local characterId = deps.characterOf and deps.characterOf(tonumber(playerId)) or nil
	characterId = characterId and tostring(characterId) or nil
	local faction = type(factionId) == 'string' and deps.get(factionId) or nil
	if not faction or faction.enabled == false then
		return fail('forbidden')
	end
	local memberships = characterId and deps.membershipsOf(characterId) or nil
	local grade = memberships and memberships[faction.id] or nil
	if not grade then
		return fail('forbidden')
	end
	local labels = {}
	for _, entry in ipairs(faction.grades or {}) do
		labels[entry.grade] = entry.label
	end
	local members = {}
	for _, member in ipairs(deps.listMembers(faction.id) or {}) do
		members[#members + 1] = {
			name = member.name,
			grade = labels[member.grade] or tostring(member.grade),
			me = tostring(member.characterId) == characterId
		}
	end
	local config = deps.config or FactionsConfig
	return {
		ok = true,
		faction = {
			label = faction.label,
			category = config.Categories[faction.category] or faction.category,
			grade = labels[grade] or tostring(grade),
			members = members,
			recipes = FactionsRules.RecipesFor(faction, grade)
		}
	}
end
