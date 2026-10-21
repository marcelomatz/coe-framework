BusinessRegistry = {}

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

local function point(raw, limits)
	if type(raw) ~= 'table' then
		return nil
	end
	local c = limits.MaxCoordinate
	local x, y, z = number(raw.x, -c, c), number(raw.y, -c, c), number(raw.z, -1000.0, 3000.0)
	if not (x and y and z) then
		return nil
	end
	return { x = x, y = y, z = z }
end

local function normalizeArea(raw, limits)
	if type(raw) ~= 'table' then
		return nil, 'invalid_area'
	end
	if raw.kind == 'circle' then
		local p = point(raw, limits)
		local radius = number(raw.radius, 3.0, 300.0)
		if not p or not radius then
			return nil, 'invalid_area'
		end
		return { kind = 'circle', x = p.x, y = p.y, z = p.z, radius = radius }
	end
	if raw.kind == 'polygon' then
		if type(raw.points) ~= 'table' or #raw.points < 3 or #raw.points > limits.MaxPolygonPoints then
			return nil, 'invalid_area'
		end
		local points = {}
		for index, entry in ipairs(raw.points) do
			local p = type(entry) == 'table' and point({ x = entry.x, y = entry.y, z = 0.0 }, limits)
			if not p then
				return nil, 'invalid_area'
			end
			points[index] = { x = p.x, y = p.y }
		end
		local z = number(raw.z, -1000.0, 3000.0)
		local height = number(raw.height, 3.0, 200.0)
		if not z or not height then
			return nil, 'invalid_area'
		end
		return { kind = 'polygon', points = points, z = z, height = height }
	end
	return nil, 'invalid_area'
end

local function normalizeStation(kind, raw, limits)
	local p = point(raw, limits)
	local id = type(raw) == 'table' and type(raw.id) == 'string' and raw.id:match('^[a-z0-9_]+$') and #raw.id <= 24 and raw.id
	if not p or not id then
		return nil, 'invalid_station'
	end
	if kind == 'showroom' then
		local radius = number(raw.radius, 2.0, 20.0)
		if not radius then
			return nil, 'invalid_station'
		end
		return { x = p.x, y = p.y, z = p.z, radius = radius }
	end
	local radius = number(raw.radius, 0.5, 5.0)
	local label = raw.label == nil and id or text(raw.label, 32)
	if not radius or not label then
		return nil, 'invalid_station'
	end
	local station = { id = id, label = label, x = p.x, y = p.y, z = p.z, radius = radius }
	if kind == 'stashes' then
		station.slots = integer(raw.slots, 1, 200, 40)
		station.maxWeight = integer(raw.maxWeight, 1000, 1000000, 150000)
		if not station.slots or not station.maxWeight then
			return nil, 'invalid_station'
		end
	end
	return station
end

local function normalizeRules(category, raw, config)
	raw = type(raw) == 'table' and raw or {}
	local rules = {}
	for _, name in ipairs(category.rules) do
		local schema, value = config.Rules[name], raw[name]
		if value == nil then
			value = category.ruleDefaults and category.ruleDefaults[name]
			if value == nil then
				value = schema.default
			end
		else
			local valid
			if schema.type == 'string' then
				valid = type(value) == 'string' and #value <= schema.max and value:match('^[%w_]*$') ~= nil
			elseif schema.type == 'boolean' then
				valid = type(value) == 'boolean'
			else
				value = number(value, schema.min, schema.max)
				valid = value ~= nil
			end
			if not valid then
				return nil, 'invalid_rule'
			end
		end
		if value == '' then
			value = nil
		end
		rules[name] = value
	end
	return rules
end

-- Valida e normaliza uma definição vinda do admin ou de outro resource. Retorna a definição limpa ou nil,erro.
function BusinessRegistry.Normalize(config, raw)
	if type(raw) ~= 'table' then
		return nil, 'invalid_business'
	end
	local limits = config.Limits
	local id = type(raw.id) == 'string' and raw.id:match('^[a-z][a-z0-9_]+$')
	if not id or #id < 2 or #id > 32 then
		return nil, 'invalid_id'
	end
	local category = type(raw.category) == 'string' and config.Categories[raw.category]
	if not category then
		return nil, 'invalid_category'
	end
	local label = text(raw.label, 48)
	if not label then
		return nil, 'invalid_label'
	end
	local area, areaError = normalizeArea(raw.area, limits)
	if not area then
		return nil, areaError
	end

	local stations = {}
	local rawStations = type(raw.stations) == 'table' and raw.stations or {}
	for _, kind in ipairs(category.stations) do
		local entry = rawStations[kind]
		if kind == 'showroom' then
			if entry ~= nil then
				local station, stationError = normalizeStation(kind, type(entry) == 'table' and {
					id = 'showroom', x = entry.x, y = entry.y, z = entry.z, radius = entry.radius
				} or nil, limits)
				if not station then
					return nil, stationError
				end
				stations.showroom = station
			end
		else
			local list = {}
			if entry ~= nil and (type(entry) ~= 'table' or #entry > limits.MaxStationsPerKind) then
				return nil, 'invalid_station'
			end
			local seen = {}
			for index, item in ipairs(entry or {}) do
				local station, stationError = normalizeStation(kind, item, limits)
				if not station then
					return nil, stationError
				end
				if seen[station.id] then
					return nil, 'duplicate_station'
				end
				seen[station.id] = true
				list[index] = station
			end
			stations[kind] = list
		end
	end

	local rules, ruleError = normalizeRules(category, raw.rules, config)
	if not rules then
		return nil, ruleError
	end

	local owner
	if raw.owner ~= nil then
		local characterId = type(raw.owner) == 'table' and raw.owner.characterId
		local ownerName = type(raw.owner) == 'table' and (text(raw.owner.name, 48) or '') or nil
		if type(characterId) ~= 'string' or #characterId > 64 or not characterId:match('^[%w_%-]+$') or not ownerName then
			return nil, 'invalid_owner'
		end
		owner = { characterId = characterId, name = ownerName }
	end

	local staff, seenStaff = {}, {}
	if raw.staff ~= nil then
		if type(raw.staff) ~= 'table' or #raw.staff > limits.MaxStaff then
			return nil, 'invalid_staff'
		end
		for _, member in ipairs(raw.staff) do
			local characterId = type(member) == 'table' and member.characterId
			local memberName = type(member) == 'table' and (text(member.name, 48) or '') or nil
			if type(characterId) ~= 'string' or #characterId > 64 or not characterId:match('^[%w_%-]+$') or not memberName then
				return nil, 'invalid_staff'
			end
			if not seenStaff[characterId] then
				seenStaff[characterId] = true
				local grade = member.grade
				if grade ~= nil and (type(grade) ~= 'string' or #grade > 24) then
					return nil, 'invalid_staff_grade'
				end
				staff[#staff + 1] = { characterId = characterId, name = memberName, grade = grade }
			end
		end
	end

	-- Sócios: respondem pelas dívidas do negócio junto com o dono; não ganham acesso de trabalho.
	local partners, seenPartners = {}, {}
	if raw.partners ~= nil then
		if type(raw.partners) ~= 'table' or #raw.partners > (limits.MaxPartners or 10) then
			return nil, 'invalid_partners'
		end
		for _, partner in ipairs(raw.partners) do
			local characterId = type(partner) == 'table' and partner.characterId
			local partnerName = type(partner) == 'table' and (text(partner.name, 48) or '') or nil
			if type(characterId) ~= 'string' or #characterId > 64 or not characterId:match('^[%w_%-]+$') or not partnerName then
				return nil, 'invalid_partners'
			end
			if not seenPartners[characterId] and not (owner and owner.characterId == characterId) then
				seenPartners[characterId] = true
				partners[#partners + 1] = { characterId = characterId, name = partnerName }
			end
		end
	end

	local grades, gradesError = BusinessGrades.Normalize(raw.grades, limits)
	if not grades then
		return nil, gradesError
	end
	local assigned, assignError = BusinessGrades.Assign(grades, staff)
	if not assigned then
		return nil, assignError
	end

	return {
		id = id,
		category = raw.category,
		label = label,
		enabled = raw.enabled ~= false,
		owner = owner,
		staff = staff,
		partners = partners,
		grades = grades,
		area = area,
		stations = stations,
		rules = rules
	}
end

-- deps: config, persistence { List, Save, Delete }, audit(event, context), onChange(id|nil), onStaff(id, characterId, change, grade).
function BusinessRegistry.New(deps)
	local businesses = {}
	local audit = deps.audit or function() end
	local service = {}

	local function changed(id)
		if deps.onChange then
			deps.onChange(id)
		end
	end

	function service.Load()
		local list, errorCode = deps.persistence.List()
		if not list then
			return nil, errorCode or 'database_error'
		end
		businesses = {}
		for _, raw in ipairs(list) do
			local business = BusinessRegistry.Normalize(deps.config, raw)
			if business then
				businesses[business.id] = business
			end
		end
		changed(nil)
		return true
	end

	function service.Get(id)
		return businesses[id]
	end

	function service.List(category)
		local list = {}
		for _, business in pairs(businesses) do
			if not category or business.category == category then
				list[#list + 1] = business
			end
		end
		table.sort(list, function(a, b)
			return a.id < b.id
		end)
		return list
	end

	local function count()
		local n = 0
		for _ in pairs(businesses) do
			n = n + 1
		end
		return n
	end

	local function isStaff(business, characterId)
		for _, member in ipairs(business.staff) do
			if member.characterId == characterId then
				return true
			end
		end
		return false
	end

	-- Dedicação exclusiva (multiJob = false): quem é da equipe aqui não pode ser da equipe de outro negócio, e vice-versa.
	-- Só confere quem entra agora (ou todos, se a regra acabou de ficar exclusiva). O dono não conta como emprego.
	local function jobConflict(business, existing)
		local exclusive = business.rules.multiJob == false
		local tightened = exclusive and not (existing and existing.rules.multiJob == false)
		for _, member in ipairs(business.staff) do
			if tightened or not (existing and isStaff(existing, member.characterId)) then
				for id, other in pairs(businesses) do
					if id ~= business.id and other.enabled and (exclusive or other.rules.multiJob == false)
						and isStaff(other, member.characterId) then
						return true
					end
				end
			end
		end
		return false
	end

	local function store(raw, by, event)
		local business, errorCode = BusinessRegistry.Normalize(deps.config, raw)
		if not business then
			return nil, errorCode
		end
		local existing = businesses[business.id]
		if existing and existing.category ~= business.category then
			return nil, 'category_locked'
		end
		if jobConflict(business, existing) then
			return nil, 'multiple_jobs'
		end
		if not existing and count() >= deps.config.Limits.MaxBusinesses then
			return nil, 'limit_reached'
		end
		local saved, saveError = deps.persistence.Save(business)
		if not saved then
			return nil, saveError or 'database_error'
		end
		businesses[business.id] = business
		audit(event, { operation = business.id, category = business.category, by = by })
		if deps.onGrades and BusinessGrades.Differ(existing and existing.grades, business.grades) then
			deps.onGrades(business.id)
		end
		if deps.onStaff then
			for _, change in ipairs(BusinessGrades.Diff(existing, business)) do
				deps.onStaff(business.id, change.characterId, change.change, change.grade)
			end
		end
		changed(business.id)
		return business
	end

	function service.Save(raw, by)
		return store(raw, by, businesses[type(raw) == 'table' and raw.id or ''] and 'business_updated' or 'business_created')
	end

	-- Cria só se o id ainda não existe; devolve o que está gravado (o admin tem a palavra final).
	function service.Seed(raw)
		local id = type(raw) == 'table' and raw.id
		if businesses[id] then
			return businesses[id]
		end
		return store(raw, 'seed', 'business_seeded')
	end

	function service.Delete(id, by)
		if type(id) ~= 'string' or not businesses[id] then
			return nil, 'unknown_business'
		end
		local deleted, errorCode = deps.persistence.Delete(id)
		if not deleted then
			return nil, errorCode or 'database_error'
		end
		businesses[id] = nil
		audit('business_deleted', { operation = id, by = by })
		changed(id)
		return true
	end

	return service
end
