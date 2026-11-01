HousingRegistry = {}

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

local function point(raw, config, defaultRadius, minRadius, maxRadius)
	if type(raw) ~= 'table' then
		return nil
	end
	local c = config.Limits.MaxCoordinate
	local x, y, z = number(raw.x, -c, c), number(raw.y, -c, c), number(raw.z, -1000.0, 3000.0)
	local heading = number(raw.heading == nil and 0.0 or raw.heading, -360.0, 360.0)
	local radius = number(raw.radius == nil and defaultRadius or raw.radius, minRadius, maxRadius)
	if not (x and y and z and heading and radius) then
		return nil
	end
	return { x = x, y = y, z = z, heading = heading, radius = radius }
end

-- Miniatura de interior: só ids do catálogo e data URL JPEG em base64 dentro do limite.
function HousingRegistry.Thumb(interiorId, image, catalog, maxBytes)
	if type(interiorId) ~= 'string' or type(catalog) ~= 'table' or catalog[interiorId] == nil then
		return nil, 'invalid_interior_id'
	end
	local prefix = 'data:image/jpeg;base64,'
	if type(image) ~= 'string' or #image > maxBytes or #image <= #prefix or image:sub(1, #prefix) ~= prefix then
		return nil, 'invalid_thumb'
	end
	if image:find('[^A-Za-z0-9+/=]', #prefix + 1) then
		return nil, 'invalid_thumb'
	end
	return true
end

-- Valida um imóvel vindo do painel. Devolve o imóvel normalizado ou nil, código.
-- catalog: mapa id -> interior do catálogo (HousingInteriors.byId); interiorId é opcional.
function HousingRegistry.Normalize(raw, config, catalog)
	if type(raw) ~= 'table' then
		return nil, 'invalid_property'
	end
	if type(raw.id) ~= 'string' or not raw.id:match('^[a-z0-9_]+$') or #raw.id < 2 or #raw.id > 32 then
		return nil, 'invalid_id'
	end
	if config.Kinds[raw.kind] == nil then
		return nil, 'invalid_kind'
	end
	local label = text(raw.label, 48)
	if not label then
		return nil, 'invalid_label'
	end
	local door = point(raw.door, config, 2.0, 1.0, 5.0)
	if not door then
		return nil, 'invalid_door'
	end
	local interior = point(raw.interior, config, 1.5, 1.0, 4.0)
	if not interior then
		return nil, 'invalid_interior'
	end
	local interiorId
	if raw.interiorId ~= nil and raw.interiorId ~= '' then
		if type(raw.interiorId) ~= 'string' or type(catalog) ~= 'table' or catalog[raw.interiorId] == nil then
			return nil, 'invalid_interior_id'
		end
		interiorId = raw.interiorId
	end
	local units = integer(raw.units, 1, config.Limits.MaxUnits, 1)
	if not units then
		return nil, 'invalid_units'
	end

	local property = {
		id = raw.id, kind = raw.kind, label = label, enabled = raw.enabled ~= false,
		door = door, interior = interior, interiorId = interiorId, units = units, starter = raw.starter == true
	}

	-- Baú opcional: ponto dentro do mesmo interior e capacidade (padrão por tipo).
	if raw.stash ~= nil then
		local stash = point(raw.stash, config, 1.2, 0.5, 3.0)
		if not stash then
			return nil, 'invalid_stash'
		end
		local limits = config.Stash
		local defaults = limits.Defaults[raw.kind]
		local slots = integer(raw.stash.slots, 1, limits.MaxSlots, defaults.slots)
		local maxWeight = integer(raw.stash.maxWeight, 1000, limits.MaxWeight, defaults.maxWeight)
		local dx, dy, dz = stash.x - interior.x, stash.y - interior.y, stash.z - interior.z
		if not slots or not maxWeight or math.sqrt(dx * dx + dy * dy + dz * dz) > limits.MaxDistanceFromInterior then
			return nil, 'invalid_stash'
		end
		stash.slots, stash.maxWeight = slots, maxWeight
		property.stash = stash
	end

	-- Comercial: alugado por negócios (caixa da sociedade) ou cedido pelo admin a um negócio (businessId, sem aluguel).
	if raw.kind == 'commercial' then
		if property.starter then
			return nil, 'invalid_starter'
		end
		if raw.businessId ~= nil and raw.businessId ~= '' then
			if type(raw.businessId) ~= 'string' or #raw.businessId > 32 or not raw.businessId:match('^[a-z][a-z0-9_]*$') then
				return nil, 'invalid_business'
			end
			if raw.rent ~= nil then
				return nil, 'invalid_rent'
			end
			if units ~= 1 then
				return nil, 'invalid_units'
			end
			property.businessId = raw.businessId
		end
	end

	if property.starter and raw.rent ~= nil then
		return nil, 'invalid_rent'
	end
	if raw.rent ~= nil then
		local rent = raw.rent
		local daily = type(rent) == 'table' and integer(rent.daily, 1, config.Limits.MaxRentPerDay, nil) or nil
		if not daily or type(rent.cycles) ~= 'table' or #rent.cycles < 1 or #rent.cycles > #config.RentCycles then
			return nil, 'invalid_rent'
		end
		local cycles, seen = {}, {}
		for _, days in ipairs(rent.cycles) do
			if seen[days] then
				return nil, 'invalid_rent'
			end
			local allowed = false
			for _, option in ipairs(config.RentCycles) do
				allowed = allowed or option == days
			end
			if not allowed then
				return nil, 'invalid_rent'
			end
			seen[days] = true
			cycles[#cycles + 1] = days
		end
		table.sort(cycles)
		property.rent = { daily = daily, cycles = cycles }
	end

	local blip = type(raw.blip) == 'table' and raw.blip or {}
	local defaults = config.DefaultBlips[raw.kind]
	local sprite = integer(blip.sprite, 1, 900, defaults.sprite)
	local color = integer(blip.color, 0, 85, defaults.color)
	local scale = number(blip.scale == nil and defaults.scale or blip.scale, 0.5, 1.5)
	if not (sprite and color and scale) then
		return nil, 'invalid_blip'
	end
	local blipEnabled = blip.enabled
	if blipEnabled == nil then
		blipEnabled = not property.starter
	end
	property.blip = { enabled = blipEnabled == true, sprite = sprite, color = color, scale = scale }

	-- Imóvel ilegal: sem mapa, sem aluguel, uma unidade; acesso só do dono e dos membros.
	if raw.kind == 'hideout' then
		if property.starter then
			return nil, 'invalid_starter'
		end
		if property.rent or units ~= 1 then
			return nil, property.rent and 'invalid_rent' or 'invalid_units'
		end
		property.blip.enabled = false
		local owner
		if raw.owner ~= nil and raw.owner ~= '' then
			owner = HousingRegistry.Person(raw.owner)
			if not owner then
				return nil, 'invalid_owner'
			end
		end
		local members, seen = {}, {}
		if raw.members ~= nil then
			if type(raw.members) ~= 'table' then
				return nil, 'invalid_members'
			end
			for _, entry in ipairs(raw.members) do
				local person = HousingRegistry.Person(entry)
				if not person then
					return nil, 'invalid_members'
				end
				if not seen[person.characterId] and not (owner and owner.characterId == person.characterId) then
					seen[person.characterId] = true
					members[#members + 1] = person
				end
			end
		end
		if #members > config.Limits.MaxHideoutMembers then
			return nil, 'invalid_members'
		end
		property.owner, property.members = owner, members
	end
	return property
end

-- Pessoa vinculada a um imóvel ilegal: { characterId, name }.
function HousingRegistry.Person(raw)
	if type(raw) ~= 'table' then
		return nil
	end
	local characterId = integer(tonumber(raw.characterId), 1, 2 ^ 31, nil)
	local name = text(raw.name, 64)
	if not characterId or not name then
		return nil
	end
	return { characterId = math.tointeger(characterId) or characterId, name = name }
end

-- true se o personagem é dono ou membro do imóvel ilegal (characterId em número ou texto).
function HousingRegistry.HasAccess(property, characterId)
	characterId = tonumber(characterId)
	if type(property) ~= 'table' or property.kind ~= 'hideout' or not characterId then
		return false
	end
	if property.owner and tonumber(property.owner.characterId) == characterId then
		return true
	end
	for _, member in ipairs(property.members or {}) do
		if tonumber(member.characterId) == characterId then
			return true
		end
	end
	return false
end

-- Menor número de mundo livre entre os imóveis ilegais.
function HousingRegistry.FreeWorld(properties, exceptId)
	local used = {}
	for id, property in pairs(properties) do
		if id ~= exceptId and property.kind == 'hideout' and property.world then
			used[property.world] = true
		end
	end
	local world = 1
	while used[world] do
		world = world + 1
	end
	return world
end
