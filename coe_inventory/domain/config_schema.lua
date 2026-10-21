-- Padrões e validação da configuração do coe_inventory.
--
-- Carregado logo após `config.lua` (cliente e servidor). `Apply` combina o que o administrador
-- definiu em `Config` com os padrões abaixo e valida cada valor:
--   * chave omitida            -> usa o padrão;
--   * tipo errado / fora da faixa -> usa o padrão e registra o problema;
--   * chave desconhecida       -> ignorada e registrada (ajuda a achar erros de digitação).
-- Assim um valor errado nunca chega ao jogo: ele é corrigido na carga e avisado no console.
Inventory = Inventory or {}
Inventory.Settings = {}

local PREFIX = '[coe_inventory] config: '

-- Cada folha: { default, kind = 'number'|'integer'|'string', min, max }. Grupos: { fields = {...} }.
local function number(default, min, max) return { kind = 'number', default = default, min = min, max = max } end
local function integer(default, min, max) return { kind = 'integer', default = default, min = min, max = max } end
local function text(default) return { kind = 'string', default = default } end

local SCHEMA = {
	Locale = text('pt-BR'),
	Client = {
		openKey = text('F2'),
		hotbarSlots = integer(5, 1, 9),
		targetDistance = number(3.0, 0.5, 10.0),
		placementRange = number(4.0, 1.0, 15.0),
		placementPreviewAlpha = integer(150, 0, 255),
		streamTimeoutMs = integer(5000, 500, 30000),
		networkControlTimeoutMs = integer(500, 100, 5000)
	},
	Server = {
		defaultSlots = integer(30, 1, 1000),
		maxSlots = integer(200, 1, 1000),
		giveDistance = number(3.0, 0.5, 20.0),
		worldInteractDistance = number(3.0, 0.5, 20.0),
		adoptTimeoutMs = integer(2000, 200, 10000),
		cacheTtlMs = integer(600000, 0, 86400000),
		flushIntervalMs = integer(1500, 0, 60000),
		maxWorldContainers = integer(200, 1, 5000),
		maxWorldContainersPerPlayer = integer(10, 1, 500),
		rateLimits = {
			fields = {
				requestMs = integer(300, 0, 60000),
				swapMs = integer(100, 0, 60000),
				actionMs = integer(150, 0, 60000),
				dropMs = integer(300, 0, 60000),
				syncMs = integer(1000, 0, 60000)
			}
		}
	}
}

local DEFAULT_STARTER_ITEMS = {
	{ name = 'water', count = 2 },
	{ name = 'bread', count = 2 },
	{ name = 'bandage', count = 1 },
	{ name = 'phone', count = 1 }
}

local CARRY_BONE = 57005 -- mão direita
local DEFAULT_CONTAINERS = {
	paperbag = {
		model = 'prop_paper_bag_01', bone = CARRY_BONE,
		position = { x = 0.12, y = 0.02, z = -0.02 }, rotation = { x = -90.0, y = 0.0, z = 0.0 }
	},
	WEAPON_BRIEFCASE = {
		model = 'prop_ld_case_01', bone = CARRY_BONE,
		position = { x = 0.10, y = 0.0, z = 0.0 }, rotation = { x = 0.0, y = 280.0, z = 53.0 }
	},
	WEAPON_BRIEFCASE_02 = {
		model = 'prop_security_case_01', bone = CARRY_BONE,
		position = { x = 0.13, y = 0.0, z = -0.01 }, rotation = { x = 0.0, y = 280.0, z = 90.0 }
	},
	WEAPON_GARBAGEBAG = {
		model = 'prop_cs_rub_binbag_01', bone = 28422,
		position = { x = 0.0, y = 0.04, z = -0.02 }, rotation = { x = 0.0, y = 0.0, z = 0.0 }
	}
}

local function copy(value)
	if type(value) ~= 'table' then return value end
	local result = {}
	for key, inner in pairs(value) do result[key] = copy(inner) end
	return result
end

local function isValid(rule, value)
	if rule.kind == 'string' then
		return type(value) == 'string' and value ~= ''
	end
	if type(value) ~= 'number' or value ~= value or value == math.huge or value == -math.huge then
		return false
	end
	if rule.kind == 'integer' and value % 1 ~= 0 then
		return false
	end
	return (rule.min == nil or value >= rule.min) and (rule.max == nil or value <= rule.max)
end

local function describe(rule)
	if rule.kind == 'string' then return 'texto não vazio' end
	local range = rule.min and rule.max and (' entre %s e %s'):format(rule.min, rule.max) or ''
	return (rule.kind == 'integer' and 'inteiro' or 'número') .. range
end

local function warnUnknown(given, known, path, issues)
	for key in pairs(given) do
		if known[key] == nil then
			issues[#issues + 1] = ('%s.%s é desconhecida e foi ignorada'):format(path, tostring(key))
		end
	end
end

-- Resolve um grupo do schema (recursivo) contra os valores informados.
local function resolveGroup(schema, given, path, issues)
	if given ~= nil and type(given) ~= 'table' then
		issues[#issues + 1] = ('%s deve ser uma tabela; usando os padrões'):format(path)
		given = nil
	end
	given = given or {}
	warnUnknown(given, schema, path, issues)

	local resolved = {}
	for key, rule in pairs(schema) do
		local value = given[key]
		local fieldPath = path .. '.' .. key
		if rule.fields then
			resolved[key] = resolveGroup(rule.fields, value, fieldPath, issues)
		elseif value == nil then
			resolved[key] = rule.default
		elseif isValid(rule, value) then
			resolved[key] = value
		else
			issues[#issues + 1] = ('%s inválida (%s); usando %s'):format(
				fieldPath, describe(rule), tostring(rule.default))
			resolved[key] = rule.default
		end
	end
	return resolved
end

local function resolveStarterItems(given, issues)
	if given == nil then return copy(DEFAULT_STARTER_ITEMS) end
	if type(given) ~= 'table' then
		issues[#issues + 1] = 'Config.Server.starterItems deve ser uma lista; usando os padrões'
		return copy(DEFAULT_STARTER_ITEMS)
	end

	local resolved = {}
	for index, entry in ipairs(given) do
		if type(entry) == 'table' and type(entry.name) == 'string' and entry.name ~= ''
			and type(entry.count) == 'number' and entry.count >= 1 and entry.count % 1 == 0 then
			resolved[#resolved + 1] = { name = entry.name, count = entry.count }
		else
			issues[#issues + 1] = ('Config.Server.starterItems[%d] inválido (use { name = texto, count = inteiro >= 1 }); ignorado'):format(index)
		end
	end
	return resolved
end

local XYZ = {
	x = number(0.0, -10.0, 10.0),
	y = number(0.0, -360.0, 360.0),
	z = number(0.0, -360.0, 360.0)
}

local function resolveVector(given, fallback, path, limits, issues)
	if given ~= nil and type(given) ~= 'table' then
		issues[#issues + 1] = ('%s deve ser { x, y, z }; usando o padrão'):format(path)
		given = nil
	end
	given = given or {}
	warnUnknown(given, XYZ, path, issues)

	local resolved = {}
	for _, axis in ipairs({ 'x', 'y', 'z' }) do
		local value = given[axis]
		local limit = limits
		if value == nil then
			resolved[axis] = fallback[axis]
		elseif type(value) == 'number' and value == value and math.abs(value) <= limit then
			resolved[axis] = value
		else
			issues[#issues + 1] = ('%s.%s inválido (número, |valor| <= %s); usando %s'):format(
				path, axis, limit, tostring(fallback[axis]))
			resolved[axis] = fallback[axis]
		end
	end
	return resolved
end

local ZERO = { x = 0.0, y = 0.0, z = 0.0 }

-- Cada item de container é mesclado campo a campo com o padrão (se existir). Itens novos
-- exigem `model`; sem ele, o item é ignorado.
local function resolveContainers(given, issues)
	local result = {}
	if given ~= nil and type(given) ~= 'table' then
		issues[#issues + 1] = 'Config.Containers deve ser uma tabela; usando os padrões'
		given = nil
	end
	given = given or {}
	warnUnknown(given, { items = true }, 'Config.Containers', issues)

	local items = given.items
	if items ~= nil and type(items) ~= 'table' then
		issues[#issues + 1] = 'Config.Containers.items deve ser uma tabela; usando os padrões'
		items = nil
	end

	local names = {}
	for name in pairs(DEFAULT_CONTAINERS) do names[name] = true end
	for name in pairs(items or {}) do names[name] = true end

	for name in pairs(names) do
		local path = 'Config.Containers.items.' .. tostring(name)
		local base = DEFAULT_CONTAINERS[name]
		local entry = items and items[name]
		if entry ~= nil and type(entry) ~= 'table' then
			issues[#issues + 1] = path .. ' deve ser uma tabela; ignorado'
			entry = nil
		end
		entry = entry or {}
		warnUnknown(entry, { model = true, bone = true, position = true, rotation = true }, path, issues)

		local model = entry.model
		if model ~= nil and (type(model) ~= 'string' or model == '') then
			issues[#issues + 1] = path .. '.model inválido (texto não vazio)'
			model = nil
		end
		model = model or (base and base.model)

		if type(name) ~= 'string' or name == '' or not model then
			if base == nil then
				issues[#issues + 1] = path .. ' ignorado: informe `model`'
			end
		else
			local bone = entry.bone
			if bone ~= nil and not (type(bone) == 'number' and bone >= 0 and bone % 1 == 0) then
				issues[#issues + 1] = path .. '.bone inválido (inteiro >= 0); usando o padrão'
				bone = nil
			end
			result[name] = {
				model = model,
				bone = bone or (base and base.bone) or CARRY_BONE,
				position = resolveVector(entry.position, base and base.position or ZERO, path .. '.position', 10.0, issues),
				rotation = resolveVector(entry.rotation, base and base.rotation or ZERO, path .. '.rotation', 360.0, issues)
			}
		end
	end
	return result
end

--- Retorna `config, issues`: a configuração completa e validada e a lista de avisos (textos).
function Inventory.Settings.Apply(given)
	local issues = {}
	if given ~= nil and type(given) ~= 'table' then
		issues[#issues + 1] = 'Config deve ser uma tabela; usando todos os padrões'
		given = nil
	end
	given = given or {}
	warnUnknown(given, { Locale = true, Client = true, Server = true, Containers = true }, 'Config', issues)

	local serverGiven = type(given.Server) == 'table' and given.Server or nil
	local starterGiven = serverGiven and serverGiven.starterItems
	if serverGiven then
		-- starterItems tem validação própria; é retirado antes do schema genérico.
		serverGiven = copy(serverGiven)
		serverGiven.starterItems = nil
	end

	local config = {
		Locale = (type(given.Locale) == 'string' and given.Locale ~= '') and given.Locale or 'pt-BR',
		Client = resolveGroup(SCHEMA.Client, given.Client, 'Config.Client', issues),
		Server = resolveGroup(SCHEMA.Server, serverGiven or given.Server, 'Config.Server', issues),
		Containers = { items = resolveContainers(given.Containers, issues) }
	}
	config.Server.starterItems = resolveStarterItems(starterGiven, issues)

	if config.Server.defaultSlots > config.Server.maxSlots then
		issues[#issues + 1] = ('Config.Server.defaultSlots (%d) maior que maxSlots (%d); usando maxSlots'):format(
			config.Server.defaultSlots, config.Server.maxSlots)
		config.Server.defaultSlots = config.Server.maxSlots
	end
	return config, issues
end

local resolved, issues = Inventory.Settings.Apply(Config)
Config = resolved
Inventory.Settings.issues = issues
for _, issue in ipairs(issues) do
	print(PREFIX .. issue)
end
