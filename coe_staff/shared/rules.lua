-- Regras do painel da staff, sem natives (testáveis fora do jogo).
StaffRules = {}

StaffRules.ModuleOrder = { 'self', 'players', 'vehicles', 'hotel', 'garages', 'world', 'businesses' }

-- Ação -> módulo que precisa estar liberado para o admin.
StaffRules.Actions = {
	-- Ferramentas pessoais (o efeito acontece no client do próprio admin, depois da autorização)
	noclip = 'self', invisible = 'self', godmode = 'self', heal = 'self', revive = 'self',
	tpWaypoint = 'self', tpCoords = 'self', updateStatus = 'self', checkUpdate = 'self', applyUpdate = 'self',
	getMyCoords = 'self',
	-- Jogadores
	players = 'players', items = 'players', gotoPlayer = 'players', bringPlayer = 'players', freezePlayer = 'players',
	kickPlayer = 'players', healPlayer = 'players', revivePlayer = 'players', giveItem = 'players', money = 'players',
	groups = 'players', setGroup = 'players', removeGroup = 'players',
	-- Veículos
	catalog = 'vehicles', spawnVehicle = 'vehicles', deleteVehicle = 'vehicles', vehicleFix = 'vehicles',
	-- Hotel de Nascimento
	hotel = 'hotel', saveStarterHotel = 'hotel', teleportToHotel = 'hotel',
	-- Garagens Públicas e Corporativas
	garages = 'garages', garageSave = 'garages', garageDelete = 'garages', garageGoto = 'garages',
	-- Mundo
	world = 'world', setTime = 'world', setWeather = 'world', resetWorld = 'world', announce = 'world',
	-- Negócios
	businesses = 'businesses', business = 'businesses', businessCreate = 'businesses', businessInfo = 'businesses',
	businessArea = 'businesses', stationAdd = 'businesses', stationRemove = 'businesses', businessOwner = 'businesses',
	staffAdd = 'businesses', staffGrade = 'businesses', staffRemove = 'businesses', gradeAdd = 'businesses',
	gradeRemove = 'businesses', businessDelete = 'businesses', businessGoto = 'businesses'
}

---Módulos liberados: allowed(ace) -> bool (IsPlayerAceAllowed no jogo). A ACE `All` libera todos.
function StaffRules.Modules(config, allowed)
	local all = allowed(config.Ace.All) == true
	local modules, any = {}, false
	for _, name in ipairs(StaffRules.ModuleOrder) do
		if all or allowed(config.Ace.Modules[name]) == true then
			modules[name] = true
			any = true
		end
	end
	return modules, any
end

function StaffRules.Allowed(modules, action)
	local module = StaffRules.Actions[action]
	return module ~= nil and modules[module] == true, module
end

-- Validação de entradas --------------------------------------------------------------------------------------

function StaffRules.Integer(value, min, max)
	value = math.tointeger(tonumber(value))
	if not value or value < min or value > max then
		return nil
	end
	return value
end

function StaffRules.Number(value, min, max)
	value = tonumber(value)
	if not value or value ~= value or value < min or value > max then
		return nil
	end
	return value
end

---Texto de uma linha, sem caracteres de controle nem < >, com até max caracteres (UTF-8).
function StaffRules.Text(value, max)
	if type(value) ~= 'string' or #value > max * 4 then
		return nil
	end
	value = value:gsub('[%c<>]', ' '):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
	local length = utf8.len(value)
	if value == '' or not length or length > max then
		return nil
	end
	return value
end

function StaffRules.Coords(data)
	if type(data) ~= 'table' then
		return nil
	end
	local x, y = StaffRules.Number(data.x, -10000, 10000), StaffRules.Number(data.y, -10000, 10000)
	local z = StaffRules.Number(data.z == nil and 0 or data.z, -500, 3000)
	if not (x and y and z) then
		return nil
	end
	return { x = x, y = y, z = z }
end

local STATE_ID_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'

function StaffRules.StateId(value)
	if type(value) ~= 'string' then
		return nil
	end
	local clean = value:gsub('[%s%-]', ''):upper()
	if #clean ~= 8 then
		return nil
	end
	for index = 1, #clean do
		if not STATE_ID_ALPHABET:find(clean:sub(index, index), 1, true) then
			return nil
		end
	end
	return clean
end

function StaffRules.Model(value)
	return type(value) == 'string' and #value <= 32 and value:match('^[%w_%-]+$') and value:lower() or nil
end

function StaffRules.ItemName(value)
	return type(value) == 'string' and #value <= 64 and value:match('^[%w_%-]+$') and value or nil
end

function StaffRules.Weather(config, value)
	for _, weather in ipairs(config.Weathers) do
		if weather == value then
			return weather
		end
	end
	return nil
end

---Hora do mundo: { hour, minute, freeze }.
function StaffRules.Time(data)
	if type(data) ~= 'table' then
		return nil
	end
	local hour, minute = StaffRules.Integer(data.hour, 0, 23), StaffRules.Integer(data.minute or 0, 0, 59)
	if not hour or not minute then
		return nil
	end
	return { hour = hour, minute = minute, freeze = data.freeze == true }
end

-- Catálogo de itens para a tela (nome, rótulo, categoria, imagem), com busca e limite.
function StaffRules.ItemList(items, search, limit)
	local needle = type(search) == 'string' and search:lower() or ''
	local list = {}
	for name, item in pairs(type(items) == 'table' and items or {}) do
		local label = type(item) == 'table' and item.label or name
		if needle == '' or name:lower():find(needle, 1, true) or tostring(label):lower():find(needle, 1, true) then
			list[#list + 1] = { name = name, label = label, category = type(item) == 'table' and item.category or nil,
				image = type(item) == 'table' and item.image or nil, stack = type(item) == 'table' and item.stack ~= false }
		end
	end
	table.sort(list, function(a, b) return tostring(a.label) < tostring(b.label) end)
	while #list > limit do
		table.remove(list)
	end
	return list
end

-- Negócios ---------------------------------------------------------------------------------------------------

local function copy(value)
	if type(value) ~= 'table' then
		return value
	end
	local out = {}
	for key, item in pairs(value) do
		out[key] = copy(item)
	end
	return out
end
StaffRules.Copy = copy

-- Id livre para um ponto novo: clock_1, stash_2, craft_1...
local STATION_PREFIX = { clocks = 'clock', stashes = 'stash', crafts = 'craft' }
StaffRules.StationKinds = { 'clocks', 'stashes', 'crafts', 'showroom' }

local function nextStationId(list, kind)
	local prefix, used = STATION_PREFIX[kind] or kind, {}
	for _, station in ipairs(list or {}) do
		used[station.id] = true
	end
	local index = 1
	while used[prefix .. '_' .. index] do
		index = index + 1
	end
	return prefix .. '_' .. index
end

local function slug(text)
	local base = text:lower():gsub('[áàâã]', 'a'):gsub('[éê]', 'e'):gsub('í', 'i'):gsub('[óôõ]', 'o'):gsub('ú', 'u'):gsub('ç', 'c')
	base = base:gsub('[^a-z0-9]+', '_'):gsub('^_+', ''):gsub('_+$', '')
	if not base:match('^[a-z]') then
		base = 'g_' .. base
	end
	return base:sub(1, 24)
end
StaffRules.Slug = slug

local function categoryOf(categories, business)
	return type(categories) == 'table' and categories[business.category] or nil
end

local function hasStation(category, kind)
	for _, allowed in ipairs(category and category.stations or {}) do
		if allowed == kind then
			return true
		end
	end
	return false
end

---Negócio novo (círculo em volta da posição do admin). Valida o básico; o coe_businesses valida o resto.
function StaffRules.NewBusiness(config, categories, data, at)
	local id = type(data.id) == 'string' and data.id:lower():match('^[a-z][a-z0-9_]+$')
	if not id or #id < 2 or #id > 32 then
		return nil, 'invalid_id'
	end
	if type(categories) ~= 'table' or not categories[data.category] then
		return nil, 'invalid_category'
	end
	local label = StaffRules.Text(data.label, 48)
	if not label then
		return nil, 'invalid_label'
	end
	local radius = StaffRules.Number(data.radius or 25, config.Limits.MinAreaRadius, config.Limits.MaxAreaRadius)
	if not radius or not at then
		return nil, 'invalid_area'
	end
	return {
		id = id, category = data.category, label = label, enabled = true,
		area = { kind = 'circle', x = at.x, y = at.y, z = at.z, radius = radius },
		stations = {}, rules = {}, staff = {}, partners = {}, grades = {}
	}
end

---Aplica uma edição a uma cópia do negócio. Retorna o negócio novo (para o Save) ou nil + código.
---ctx: { at = posição do admin, categories, rules = RuleSchema, character = { characterId, name } (dono/equipe) }.
function StaffRules.Edit(config, business, op, data, ctx)
	local b = copy(business)
	b.stations = b.stations or {}
	b.staff = b.staff or {}
	b.grades = b.grades or {}
	local category = categoryOf(ctx.categories, b)
	if op == 'businessInfo' then
		if data.label ~= nil then
			local label = StaffRules.Text(data.label, 48)
			if not label then
				return nil, 'invalid_label'
			end
			b.label = label
		end
		if data.enabled ~= nil then
			b.enabled = data.enabled == true
		end
		if type(data.rules) == 'table' then
			b.rules = b.rules or {}
			for name, value in pairs(data.rules) do
				local schema = type(ctx.rules) == 'table' and ctx.rules[name]
				if not schema then
					return nil, 'invalid_rule'
				end
				if schema.type == 'boolean' then
					b.rules[name] = value == true
				elseif schema.type == 'number' then
					local number = StaffRules.Number(value, schema.min, schema.max)
					if not number then
						return nil, 'invalid_rule'
					end
					b.rules[name] = number
				end
			end
		end
		return b
	end
	if op == 'businessArea' then
		local radius = StaffRules.Number(data.radius, config.Limits.MinAreaRadius, config.Limits.MaxAreaRadius)
		if not radius or not ctx.at then
			return nil, 'invalid_area'
		end
		b.area = { kind = 'circle', x = ctx.at.x, y = ctx.at.y, z = ctx.at.z, radius = radius }
		return b
	end
	if op == 'stationAdd' then
		local kind = data.kind
		if not hasStation(category, kind) then
			return nil, 'invalid_station'
		end
		if not ctx.at then
			return nil, 'invalid_station'
		end
		if kind == 'showroom' then
			local radius = StaffRules.Number(data.radius or 6, 2, 20)
			if not radius then
				return nil, 'invalid_station'
			end
			b.stations.showroom = { x = ctx.at.x, y = ctx.at.y, z = ctx.at.z, radius = radius }
			return b
		end
		local list = b.stations[kind] or {}
		local id = nextStationId(list, kind)
		local label = data.label ~= nil and data.label ~= '' and StaffRules.Text(data.label, 32) or id
		local radius = StaffRules.Number(data.radius or 1.5, 0.5, config.Limits.MaxStationRadius)
		if not label or not radius then
			return nil, 'invalid_station'
		end
		local station = { id = id, label = label, x = ctx.at.x, y = ctx.at.y, z = ctx.at.z, radius = radius }
		if kind == 'stashes' then
			station.slots = StaffRules.Integer(data.slots or 40, 1, 200)
			station.maxWeight = StaffRules.Integer(data.maxWeight or 150000, 1000, 1000000)
			if not station.slots or not station.maxWeight then
				return nil, 'invalid_station'
			end
		end
		list[#list + 1] = station
		b.stations[kind] = list
		return b
	end
	if op == 'stationRemove' then
		if data.kind == 'showroom' then
			if not b.stations.showroom then
				return nil, 'unknown_station'
			end
			b.stations.showroom = nil
			return b
		end
		local list = b.stations[data.kind]
		for index, station in ipairs(type(list) == 'table' and list or {}) do
			if station.id == data.stationId then
				table.remove(list, index)
				return b
			end
		end
		return nil, 'unknown_station'
	end
	if op == 'businessOwner' then
		local previous = b.owner and b.owner.characterId or nil
		b.owner = ctx.character and { characterId = ctx.character.characterId, name = ctx.character.name } or nil
		-- Sócios respondem pelas dívidas junto com o dono: trocar ou remover o dono desfaz a sociedade.
		if (b.owner and b.owner.characterId or nil) ~= previous then
			b.partners = {}
		end
		if b.owner then
			-- O dono não fica também na equipe nem entre os sócios.
			for index = #b.staff, 1, -1 do
				if b.staff[index].characterId == b.owner.characterId then
					table.remove(b.staff, index)
				end
			end
			for index = #(b.partners or {}), 1, -1 do
				if b.partners[index].characterId == b.owner.characterId then
					table.remove(b.partners, index)
				end
			end
		end
		return b
	end
	if op == 'staffAdd' then
		local who = ctx.character
		if not who then
			return nil, 'character_not_found'
		end
		if b.owner and b.owner.characterId == who.characterId then
			return nil, 'is_owner'
		end
		for _, member in ipairs(b.staff) do
			if member.characterId == who.characterId then
				return nil, 'already_staff'
			end
		end
		local grade = data.grade
		if grade == '' then
			grade = nil
		end
		b.staff[#b.staff + 1] = { characterId = who.characterId, name = who.name, grade = grade }
		return b
	end
	if op == 'staffGrade' or op == 'staffRemove' then
		for index, member in ipairs(b.staff) do
			if member.characterId == tostring(data.characterId) then
				if op == 'staffRemove' then
					table.remove(b.staff, index)
				else
					member.grade = data.grade
				end
				return b
			end
		end
		return nil, 'unknown_member'
	end
	if op == 'gradeAdd' then
		local label = StaffRules.Text(data.label, 32)
		local level = StaffRules.Integer(data.level, 0, 99)
		local salary = StaffRules.Integer(data.salary or 0, 0, 1000000)
		if not label or not level or not salary then
			return nil, 'invalid_grade'
		end
		local id = slug(label)
		if #id < 2 then
			return nil, 'invalid_grade'
		end
		for _, grade in ipairs(b.grades) do
			if grade.id == id or grade.level == level then
				return nil, 'duplicate_grade'
			end
		end
		local permissions = {}
		for _, permission in ipairs(type(data.permissions) == 'table' and data.permissions or {}) do
			if type(permission) == 'string' then
				permissions[#permissions + 1] = permission
			end
		end
		b.grades[#b.grades + 1] = { id = id, label = label, level = level, salary = salary, permissions = permissions }
		table.sort(b.grades, function(x, y) return x.level < y.level end)
		return b
	end
	if op == 'gradeRemove' then
		for index, grade in ipairs(b.grades) do
			if grade.id == data.gradeId then
				for _, member in ipairs(b.staff) do
					if member.grade == grade.id then
						return nil, 'grade_in_use'
					end
				end
				table.remove(b.grades, index)
				return b
			end
		end
		return nil, 'unknown_grade'
	end
	return nil, 'invalid_action'
end

---Resumo de um negócio para a lista da tela.
function StaffRules.BusinessSummary(business)
	return {
		id = business.id, label = business.label, category = business.category, enabled = business.enabled ~= false,
		owner = business.owner and business.owner.name or nil, staff = #(business.staff or {})
	}
end

---Normaliza permissões de negócio ({ [name] = label } ou { { name, label } }) em lista ordenada { name, label }[].
function StaffRules.PermissionsList(raw)
	local list = {}
	if type(raw) ~= 'table' then
		return list
	end
	if #raw > 0 then
		for _, entry in ipairs(raw) do
			if type(entry) == 'table' and type(entry.name) == 'string' then
				list[#list + 1] = { name = entry.name, label = tostring(entry.label or entry.name) }
			end
		end
	else
		for name, label in pairs(raw) do
			if type(name) == 'string' then
				list[#list + 1] = { name = name, label = tostring(label or name) }
			end
		end
	end
	table.sort(list, function(a, b) return a.name < b.name end)
	return list
end
