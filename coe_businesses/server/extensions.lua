-- Extensões do app do negócio: abas e provedores registrados em runtime por outros resources (pacotes e scripts de
-- terceiros). O framework não conhece nenhum deles pelo nome: o resource vem do runtime, na hora do registro.
-- Sem dependência de natives (o chamador do export é injetado), para os testes.
BusinessExtensions = {}

-- Abas próprias do app (não podem ser registradas por outro resource).
BusinessExtensions.BuiltIn = {
	overview = true, finance = true, staff = true, partners = true, access = true, structure = true, fleet = true,
	properties = true
}

-- Provedores de dados das abas próprias: tipo -> exports exigidos (opcionais entre colchetes no README).
BusinessExtensions.Providers = {
	fleet = { required = { 'list' }, optional = { 'setStaff' } },
	properties = { required = { 'list' }, optional = {} }
}

local MAX_TABS = 16

local function exportName(value)
	return type(value) == 'string' and #value <= 64 and value:match('^[%a_][%w_]*$') ~= nil and value or nil
end

local function assetPath(value)
	if type(value) ~= 'string' or #value > 128 or value:find('..', 1, true) or value:sub(1, 1) == '/' then
		return nil
	end
	return value:match('^[%w_%-/]+%.%a+$') ~= nil and value or nil
end

local function label(value)
	return type(value) == 'string' and #value > 0 and #value <= 32 and not value:find('[%c<>]') and value or nil
end

function BusinessExtensions.New()
	return setmetatable({ tabs = {}, providers = {} }, { __index = BusinessExtensions })
end

local function count(map)
	local total = 0
	for _ in pairs(map) do
		total = total + 1
	end
	return total
end

---Registra (ou atualiza) uma aba do resource. def: { id, label, script, css?, handler, visible?, order?, replaces? }.
---@return boolean|nil ok
---@return string|nil error
function BusinessExtensions:RegisterTab(resource, def)
	if type(resource) ~= 'string' or resource == '' or type(def) ~= 'table' then
		return nil, 'invalid_tab'
	end
	local id = type(def.id) == 'string' and #def.id <= 24 and def.id:match('^[a-z][a-z0-9_]*$') and def.id or nil
	if not id or BusinessExtensions.BuiltIn[id] then
		return nil, 'invalid_tab'
	end
	local current = self.tabs[id]
	if current and current.resource ~= resource then
		return nil, 'tab_taken'
	end
	if not current and count(self.tabs) >= MAX_TABS then
		return nil, 'too_many_tabs'
	end
	local tab = {
		id = id, resource = resource, label = label(def.label), script = assetPath(def.script),
		handler = exportName(def.handler), order = math.tointeger(tonumber(def.order)) or 50
	}
	if not tab.label or not tab.script or not tab.handler then
		return nil, 'invalid_tab'
	end
	if def.css ~= nil then
		tab.css = assetPath(def.css)
		if not tab.css then
			return nil, 'invalid_tab'
		end
	end
	if def.visible ~= nil then
		tab.visible = exportName(def.visible)
		if not tab.visible then
			return nil, 'invalid_tab'
		end
	end
	if def.replaces ~= nil then
		if not BusinessExtensions.BuiltIn[def.replaces] or def.replaces == 'overview' then
			return nil, 'invalid_tab'
		end
		tab.replaces = def.replaces
	end
	self.tabs[id] = tab
	return true
end

---Registra o provedor de um tipo (fleet, properties). O último registro vale.
function BusinessExtensions:RegisterProvider(resource, kind, def)
	local spec = type(kind) == 'string' and BusinessExtensions.Providers[kind] or nil
	if type(resource) ~= 'string' or resource == '' or not spec or type(def) ~= 'table' then
		return nil, 'invalid_provider'
	end
	local provider = { resource = resource }
	for _, key in ipairs(spec.required) do
		provider[key] = exportName(def[key])
		if not provider[key] then
			return nil, 'invalid_provider'
		end
	end
	for _, key in ipairs(spec.optional) do
		if def[key] ~= nil then
			provider[key] = exportName(def[key])
			if not provider[key] then
				return nil, 'invalid_provider'
			end
		end
	end
	self.providers[kind] = provider
	return true
end

---Remove tudo o que o resource registrou (ao parar).
function BusinessExtensions:Drop(resource)
	for id, tab in pairs(self.tabs) do
		if tab.resource == resource then
			self.tabs[id] = nil
		end
	end
	for kind, provider in pairs(self.providers) do
		if provider.resource == resource then
			self.providers[kind] = nil
		end
	end
end

---Aba registrada visível para o negócio, ou nil. call(resource, export, ...) chama o export do outro resource.
function BusinessExtensions:Tab(id, businessId, call)
	local tab = type(id) == 'string' and self.tabs[id] or nil
	if not tab then
		return nil
	end
	if tab.visible and call(tab.resource, tab.visible, businessId) ~= true then
		return nil
	end
	return tab
end

---Abas visíveis para o negócio, em ordem, no formato que o app recebe (com o caminho nui:// do resource).
function BusinessExtensions:VisibleTabs(businessId, call)
	local list = {}
	for id in pairs(self.tabs) do
		local tab = self:Tab(id, businessId, call)
		if tab then
			list[#list + 1] = {
				id = tab.id, label = tab.label, order = tab.order, replaces = tab.replaces,
				script = ('nui://%s/%s'):format(tab.resource, tab.script),
				css = tab.css and ('nui://%s/%s'):format(tab.resource, tab.css) or nil
			}
		end
	end
	table.sort(list, function(a, b)
		if a.order ~= b.order then
			return a.order < b.order
		end
		return a.id < b.id
	end)
	return list
end

---Provedor registrado do tipo, ou nil.
function BusinessExtensions:Provider(kind)
	return self.providers[kind]
end

return BusinessExtensions
