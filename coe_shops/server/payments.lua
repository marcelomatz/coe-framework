-- Meios de pagamento das lojas registrados em runtime por outros resources (cartão, carteira digital...). O dinheiro em
-- espécie é do próprio coe_shops. O framework não conhece os outros resources pelo nome: o resource vem do runtime.
-- Sem natives, para os testes.
ShopsPayments = {}

-- instant: paga direto; pin: escolhe uma opção (ex.: cartão) e digita a senha de 4 dígitos; device: o client chama o
-- export `client` do resource (ex.: abre o celular) e manda o token devolvido junto da compra.
ShopsPayments.Kinds = { instant = true, pin = true, device = true }

local MAX_METHODS = 8

local function exportName(value)
	return type(value) == 'string' and #value <= 64 and value:match('^[%a_][%w_]*$') ~= nil and value or nil
end

local function text(value, max)
	return type(value) == 'string' and #value > 0 and #value <= max and not value:find('[%c<>]') and value or nil
end

function ShopsPayments.New()
	return setmetatable({ methods = {} }, { __index = ShopsPayments })
end

---def: { id, label, kind, charge, refund, options?, client?, order? }. Retorna true ou nil + erro.
function ShopsPayments:Register(resource, def)
	if type(resource) ~= 'string' or resource == '' or type(def) ~= 'table' then
		return nil, 'invalid_method'
	end
	local id = type(def.id) == 'string' and #def.id <= 24 and def.id:match('^[a-z][a-z0-9_]*$') and def.id or nil
	if not id or id == 'cash' then
		return nil, 'invalid_method'
	end
	local current = self.methods[id]
	if current and current.resource ~= resource then
		return nil, 'method_taken'
	end
	local total = 0
	for _ in pairs(self.methods) do
		total = total + 1
	end
	if not current and total >= MAX_METHODS then
		return nil, 'too_many_methods'
	end
	local method = {
		id = id, resource = resource, label = text(def.label, 32), kind = ShopsPayments.Kinds[def.kind] and def.kind or nil,
		charge = exportName(def.charge), refund = exportName(def.refund), order = math.tointeger(tonumber(def.order)) or 50
	}
	if not method.label or not method.kind or not method.charge or not method.refund then
		return nil, 'invalid_method'
	end
	if def.options ~= nil then
		method.options = exportName(def.options)
		if not method.options then
			return nil, 'invalid_method'
		end
	end
	if method.kind == 'device' then
		method.client = exportName(def.client)
		if not method.client then
			return nil, 'invalid_method'
		end
	end
	self.methods[id] = method
	return true
end

function ShopsPayments:Drop(resource)
	for id, method in pairs(self.methods) do
		if method.resource == resource then
			self.methods[id] = nil
		end
	end
end

---Meio registrado e ligado no config (Payments[id] = false desliga), ou nil.
function ShopsPayments:Get(id, enabled)
	local method = type(id) == 'string' and self.methods[id] or nil
	if not method or (type(enabled) == 'table' and enabled[id] == false) then
		return nil
	end
	return method
end

---Lista para a vitrine. call(resource, export, ...) chama o export `options` do resource para o jogador.
---Cada item: { id, label, kind, detail, available, options = { { id, label } }, resource?, client? }.
function ShopsPayments:View(playerId, enabled, call)
	local list = {}
	for id in pairs(self.methods) do
		local method = self:Get(id, enabled)
		if method then
			local info = method.options and call(method.resource, method.options, playerId) or nil
			info = type(info) == 'table' and info or {}
			local options = {}
			for _, option in ipairs(type(info.options) == 'table' and info.options or {}) do
				local label = type(option) == 'table' and text(option.label, 48) or nil
				if label and (type(option.id) == 'number' or type(option.id) == 'string') and #options < 12 then
					options[#options + 1] = { id = option.id, label = label }
				end
			end
			local available = info.available ~= false and (method.kind ~= 'pin' or #options > 0)
			list[#list + 1] = {
				id = method.id, label = method.label, kind = method.kind, order = method.order, detail = text(info.detail, 96),
				available = available, options = options,
				resource = method.kind == 'device' and method.resource or nil, client = method.client
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

---Rótulo de cada meio (para o relatório de vendas), com o dinheiro em espécie.
function ShopsPayments:Labels()
	local labels = { cash = 'Dinheiro' }
	for id, method in pairs(self.methods) do
		labels[id] = method.label
	end
	return labels
end

return ShopsPayments
