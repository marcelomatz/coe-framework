-- Regras puras das facções: validação, graus e acesso a crafts. Sem acesso a banco ou a outros resources.
FactionsRules = {}

local function text(value, max)
	if type(value) ~= 'string' then
		return nil
	end
	value = value:gsub('^%s+', ''):gsub('%s+$', '')
	if value == '' or #value > max or value:find('[%c<>]') then
		return nil
	end
	return value
end

local function identifier(value, min, max)
	return type(value) == 'string' and #value >= min and #value <= max and value:match('^[a-z0-9_]+$') ~= nil
end

FactionsRules.IsIdentifier = identifier

local function number(value, min, max)
	if type(value) ~= 'number' or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	if value < min or value > max then
		return nil
	end
	return math.floor(value * 100 + 0.5) / 100
end

local function integer(value, min, max, default)
	if value == nil then
		return default
	end
	if type(value) ~= 'number' or value % 1 ~= 0 or value < min or value > max then
		return nil
	end
	return value
end

local function normalizeStationList(kind, list, limits)
	if list == nil then
		return {}
	end
	local maxCount = limits.MaxStationsPerKind or 8
	local maxCoord = limits.MaxCoordinate or 10000.0
	if type(list) ~= 'table' or #list > maxCount then
		return nil, 'invalid_station'
	end
	local out, seen = {}, {}
	for _, raw in ipairs(list) do
		local id = type(raw) == 'table' and identifier(raw.id, 1, 24) and raw.id or nil
		local x = type(raw) == 'table' and number(raw.x, -maxCoord, maxCoord) or nil
		local y = type(raw) == 'table' and number(raw.y, -maxCoord, maxCoord) or nil
		local z = type(raw) == 'table' and number(raw.z, -1000.0, 3000.0) or nil
		local radius = type(raw) == 'table' and number(raw.radius or 1.5, 0.5, 5.0) or nil
		local label = type(raw) == 'table' and (raw.label == nil and id or text(raw.label, 32)) or nil
		if not (id and x and y and z and radius and label) then
			return nil, 'invalid_station'
		end
		if seen[id] then
			return nil, 'duplicate_station'
		end
		seen[id] = true
		local entry = { id = id, label = label, x = x, y = y, z = z, radius = radius }
		if kind == 'stashes' then
			local slots = integer(raw.slots, 1, 200, 40)
			local maxWeight = integer(raw.maxWeight, 1000, 1000000, 150000)
			if not slots or not maxWeight then
				return nil, 'invalid_station'
			end
			entry.slots, entry.maxWeight = slots, maxWeight
		end
		out[#out + 1] = entry
	end
	return out
end

-- Valida uma facção vinda do painel. Devolve a facção normalizada ou nil, código.
function FactionsRules.Normalize(raw, config)
	if type(raw) ~= 'table' then
		return nil, 'invalid_faction'
	end
	if not identifier(raw.id, 2, 32) then
		return nil, 'invalid_id'
	end
	if config.Categories[raw.category] == nil then
		return nil, 'invalid_category'
	end
	local label = text(raw.label, 48)
	if not label then
		return nil, 'invalid_label'
	end
	local limits = config.Limits

	if type(raw.grades) ~= 'table' or #raw.grades < 1 or #raw.grades > limits.MaxGrades then
		return nil, 'invalid_grades'
	end
	local grades, seenGrade = {}, {}
	for _, grade in ipairs(raw.grades) do
		local value = type(grade) == 'table' and grade.grade or nil
		local gradeLabel = type(grade) == 'table' and text(grade.label, 32) or nil
		if type(value) ~= 'number' or value % 1 ~= 0 or value < 0 or value > limits.MaxGrade
			or seenGrade[value] or not gradeLabel then
			return nil, 'invalid_grades'
		end
		seenGrade[value] = true
		grades[#grades + 1] = { grade = value, label = gradeLabel }
	end
	table.sort(grades, function(a, b)
		return a.grade < b.grade
	end)

	local crafts = {}
	if raw.crafts ~= nil then
		if type(raw.crafts) ~= 'table' or #raw.crafts > limits.MaxCrafts then
			return nil, 'invalid_crafts'
		end
		local seenCraft = {}
		for _, craft in ipairs(raw.crafts) do
			local recipe = type(craft) == 'table' and craft.recipe or nil
			local minGrade = type(craft) == 'table' and craft.minGrade
			if minGrade == nil then
				minGrade = grades[1].grade
			end
			if not identifier(recipe, 1, 64) or seenCraft[recipe]
				or type(minGrade) ~= 'number' or not seenGrade[minGrade] then
				return nil, 'invalid_crafts'
			end
			seenCraft[recipe] = true
			crafts[#crafts + 1] = { recipe = recipe, minGrade = minGrade }
		end
	end

	local rawStations = raw.stations
	if rawStations ~= nil and type(rawStations) ~= 'table' then
		return nil, 'invalid_station'
	end
	local craftStations, craftErr = normalizeStationList('crafts', rawStations and rawStations.crafts, limits)
	if not craftStations then
		return nil, craftErr
	end
	local stashStations, stashErr = normalizeStationList('stashes', rawStations and rawStations.stashes, limits)
	if not stashStations then
		return nil, stashErr
	end

	return {
		id = raw.id,
		label = label,
		category = raw.category,
		enabled = raw.enabled ~= false,
		grades = grades,
		crafts = crafts,
		stations = {
			crafts = craftStations,
			stashes = stashStations
		}
	}
end

function FactionsRules.HasGrade(faction, grade)
	for _, entry in ipairs(faction.grades) do
		if entry.grade == grade then
			return true
		end
	end
	return false
end

-- Receitas que o membro pode usar: facção ativa e grau mínimo de cada receita.
function FactionsRules.RecipesFor(faction, memberGrade)
	local recipes = {}
	if type(faction) ~= 'table' or faction.enabled == false or type(memberGrade) ~= 'number' then
		return recipes
	end
	for _, craft in ipairs(faction.crafts or {}) do
		if memberGrade >= craft.minGrade then
			recipes[#recipes + 1] = craft.recipe
		end
	end
	return recipes
end

function FactionsRules.CanCraft(faction, memberGrade, recipeId)
	for _, recipe in ipairs(FactionsRules.RecipesFor(faction, memberGrade)) do
		if recipe == recipeId then
			return true
		end
	end
	return false
end

local function algo(name)
	local alg = (type(Core) == 'table' and Core.Algorithms) or CoeAlgorithms
	return alg and alg[name]
end

function FactionsRules.NewCache(capacity)
	local Containers = algo('Containers')
	if Containers and Containers.newLRUCache then
		return Containers.newLRUCache(capacity or 128)
	end
	return nil
end

function FactionsRules.NewRateLimiter(cooldownMs)
	local RateLimit = algo('RateLimit')
	local interval = math.max(1, tonumber(cooldownMs) or 250)
	if RateLimit and RateLimit.newGCRA then
		return RateLimit.newGCRA(interval, 0)
	end
	return nil
end

