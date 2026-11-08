-- Regras puras do coe_phone (sem natives), usadas pelo servidor e pelos testes.
PhoneRules = {}

local function trim(value)
	return (tostring(value):gsub('^%s+', ''):gsub('%s+$', ''))
end

-- Número digitado (555-0123, 555 0123, (555)0123...) para só dígitos; nil se não tiver o formato do servidor.
function PhoneRules.Normalize(config, value)
	if type(value) ~= 'string' and type(value) ~= 'number' then
		return nil
	end
	local digits = tostring(value):gsub('[%s%-%(%)%.]', '')
	local size = #config.Number.Prefix + config.Number.Digits
	if #digits ~= size or not digits:match('^%d+$') or digits:sub(1, #config.Number.Prefix) ~= config.Number.Prefix then
		return nil
	end
	return digits
end

function PhoneRules.Format(config, digits)
	local prefix = #config.Number.Prefix
	return digits:sub(1, prefix) .. '-' .. digits:sub(prefix + 1)
end

-- Número novo aleatório. random(min, max) é injetado (math.random no servidor).
function PhoneRules.Generate(config, random)
	local parts = { config.Number.Prefix }
	for index = 1, config.Number.Digits do
		parts[index + 1] = tostring(random(0, 9))
	end
	return table.concat(parts)
end

-- Aparelhos e chips ------------------------------------------------------------------------------------

local SERIAL_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'

-- Serial de aparelho novo: SN + 10 caracteres sem ambiguidade (os migrados começam com MG).
function PhoneRules.Serial(random)
	local parts = { 'SN' }
	for index = 1, 10 do
		local position = random(1, #SERIAL_ALPHABET)
		parts[index + 1] = SERIAL_ALPHABET:sub(position, position)
	end
	return table.concat(parts)
end

-- ICCID de chip novo: 8956 + 16 dígitos (os migrados começam com 8955).
function PhoneRules.Iccid(random)
	local parts = { '8956' }
	for index = 1, 16 do
		parts[index + 1] = tostring(random(0, 9))
	end
	return table.concat(parts)
end

function PhoneRules.IsSerial(value)
	return type(value) == 'string' and #value <= 16 and value:match('^[A-Z0-9]+$') ~= nil
end

function PhoneRules.IsIccid(value)
	return type(value) == 'string' and #value <= 20 and value:match('^%d+$') ~= nil
end

-- Qual celular do inventário abrir. items: { { slot, name, metadata } } só com itens de aparelho.
-- slot (item usado) tem prioridade; depois o aparelho ativo (serial); depois o de menor slot.
function PhoneRules.PickDevice(items, activeSerial, slot)
	local first
	for _, item in ipairs(items) do
		if slot and item.slot == slot then
			return item
		end
		if not slot and activeSerial and type(item.metadata) == 'table' and item.metadata.serial == activeSerial then
			return item
		end
		if not first or item.slot < first.slot then
			first = item
		end
	end
	if slot then
		return nil
	end
	return first
end

-- Primeiro slot livre de chip no aparelho (capacity = chips do modelo); nil se cheio.
function PhoneRules.FreeSimSlot(capacity, sims)
	local used = {}
	for _, sim in ipairs(sims or {}) do
		used[sim.slot] = true
	end
	for slot = 1, capacity do
		if not used[slot] then
			return slot
		end
	end
	return nil
end

local function text(value, max, multiline)
	if type(value) ~= 'string' then
		return nil
	end
	local clean = value:gsub('\r\n?', '\n')
	if multiline then
		clean = clean:gsub('[\0-\8\11-\31\127]', ''):gsub('\n\n\n+', '\n\n')
	else
		clean = clean:gsub('[\0-\31\127]', ' ')
	end
	clean = trim(clean:gsub('[ \t]+', ' '))
	if clean == '' or not utf8.len(clean) then
		return nil
	end
	if utf8.len(clean) > max then
		clean = clean:sub(1, utf8.offset(clean, max + 1) - 1)
	end
	return clean
end

function PhoneRules.ContactName(config, value)
	return text(value, config.Contacts.NameMax, false)
end

function PhoneRules.Message(config, value)
	return text(value, config.Messages.BodyMax, true)
end

local JPEG_PREFIX = 'data:image/jpeg;base64,'

-- Foto (data URI JPEG em base64) de até maxBytes; nil se inválida.
function PhoneRules.Photo(value, maxBytes)
	if type(value) ~= 'string' or #value > maxBytes or value:sub(1, #JPEG_PREFIX) ~= JPEG_PREFIX then
		return nil
	end
	local body = value:sub(#JPEG_PREFIX + 1)
	if #body < 8 or #body % 4 ~= 0 or body:find('[^%w%+/=]') or body:find('=[^=]') or body:find('===', 1, true) then
		return nil
	end
	return value
end

-- Cabe mais `extra` bytes no aparelho? storage em MB.
function PhoneRules.StorageFits(storage, used, extra)
	local capacity = math.floor((tonumber(storage) or 0) * 1024 * 1024)
	return capacity > 0 and (tonumber(used) or 0) + (tonumber(extra) or 0) <= capacity
end

-- Como a chamada fica no histórico. reason: hangup, missed, declined, busy, unavailable.
function PhoneRules.CallStatus(reason, wasActive)
	if wasActive then
		return 'answered'
	end
	if reason == 'declined' or reason == 'busy' or reason == 'unavailable' then
		return reason
	end
	return 'missed'
end

-- Lista de apps do aparelho. canSee(id, app) decide os apps de outros resources (instalados na loja).
function PhoneRules.Apps(config, canSee)
	local list = {}
	for id, app in pairs(config.Apps) do
		if app.native or (app.resource and PhoneRules.IsValidScript(app.script) and canSee(id, app)) then
			list[#list + 1] = {
				id = id, label = app.label, order = app.order or 99, icon = app.icon, color = app.color,
				dock = app.dock == true, native = app.native == true, script = app.script
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

function PhoneRules.IsValidScript(path)
	return type(path) == 'string' and path:match('^nui://[a-z0-9_]+/html/[a-z0-9_]+%.js$') ~= nil
end

-- Ajustes ---------------------------------------------------------------------------------------------

local function contains(list, value)
	for _, item in ipairs(list) do
		if item == value then
			return true
		end
	end
	return false
end

local function integerIn(value, min, max)
	local number = math.tointeger(tonumber(value))
	if not number or number < min or number > max then
		return nil
	end
	return number
end

-- Valor válido de um ajuste ou nil (chave desconhecida ou valor fora do permitido).
function PhoneRules.SettingValue(config, key, value)
	local settings = config.Settings
	local default = settings.Defaults[key]
	if default == nil then
		return nil
	end
	if type(default) == 'boolean' then
		return type(value) == 'boolean' and value or nil
	end
	if key == 'volume' then
		return integerIn(value, 0, 10)
	end
	if key == 'brightness' then
		return integerIn(value, settings.Brightness.Min, settings.Brightness.Max)
	end
	if key == 'ringtone' then
		return contains(settings.Ringtones, value) and value or nil
	end
	if key == 'wallpaper' then
		return contains(settings.Wallpapers, value) and value or nil
	end
	return nil
end

-- Ajustes completos: o que foi salvo e é válido, o resto pelos defaults.
function PhoneRules.Settings(config, raw)
	local result = {}
	for key, default in pairs(config.Settings.Defaults) do
		local value = type(raw) == 'table' and PhoneRules.SettingValue(config, key, raw[key]) or nil
		if value == nil then
			value = default
		end
		result[key] = value
	end
	return result
end

-- Aplica uma alteração parcial. Ligar o modo avião desliga Wi-Fi e Bluetooth (que podem ser religados depois).
function PhoneRules.Patch(config, current, patch)
	if type(patch) ~= 'table' then
		return nil, 'invalid_setting'
	end
	local result = {}
	for key, value in pairs(current) do
		result[key] = value
	end
	for key, value in pairs(patch) do
		local clean = PhoneRules.SettingValue(config, key, value)
		if clean == nil then
			return nil, 'invalid_setting'
		end
		result[key] = clean
	end
	if patch.airplane == true and current.airplane ~= true then
		if patch.wifi == nil then
			result.wifi = false
		end
		if patch.bluetooth == nil then
			result.bluetooth = false
		end
	end
	return result
end

function PhoneRules.Passcode(config, value)
	local limits = config.Settings.Passcode
	if type(value) ~= 'string' or not value:match('^%d+$') or #value < limits.MinLength or #value > limits.MaxLength then
		return nil
	end
	return value
end

-- Telas iniciais ----------------------------------------------------------------------------------------

-- Layout salvo ({ pages = {{ids}}, dock = {ids} }) ajustado aos apps visíveis: cada app aparece uma vez, sem ids
-- desconhecidos, respeitando os limites. Apps sem lugar (recém-instalados) vão para a primeira tela com espaço.
-- Sem layout salvo, usa `dock` e a ordem dos apps.
function PhoneRules.Layout(config, layout, apps)
	local home = config.Home
	local visible, seen = {}, {}
	for _, app in ipairs(apps) do
		visible[app.id] = true
	end
	local function take(id)
		if type(id) == 'string' and visible[id] and not seen[id] then
			seen[id] = true
			return true
		end
		return false
	end
	local saved = type(layout) == 'table' and type(layout.pages) == 'table'
	local dock, pages = {}, {}
	if saved and type(layout.dock) == 'table' then
		for _, id in ipairs(layout.dock) do
			if #dock < home.DockSize and take(id) then
				dock[#dock + 1] = id
			end
		end
	elseif not saved then
		for _, app in ipairs(apps) do
			if app.dock and #dock < home.DockSize and take(app.id) then
				dock[#dock + 1] = app.id
			end
		end
	end
	if saved then
		for _, page in ipairs(layout.pages) do
			if #pages >= home.MaxPages then
				break
			end
			local list = {}
			if type(page) == 'table' then
				for _, id in ipairs(page) do
					if #list < home.PageSize and take(id) then
						list[#list + 1] = id
					end
				end
			end
			pages[#pages + 1] = list
		end
	end
	if #pages == 0 then
		pages[1] = {}
	end
	for _, app in ipairs(apps) do
		if not seen[app.id] then
			seen[app.id] = true
			local target
			for _, page in ipairs(pages) do
				if #page < home.PageSize then
					target = page
					break
				end
			end
			if not target and #pages < home.MaxPages then
				target = {}
				pages[#pages + 1] = target
			end
			target = target or pages[#pages]
			target[#target + 1] = app.id
		end
	end
	return { pages = pages, dock = dock }
end

-- Sinal ------------------------------------------------------------------------------------------------

-- Barras (0 a 4) pela distância até a antena mais próxima.
function PhoneRules.Signal(config, x, y)
	if type(x) ~= 'number' or type(y) ~= 'number' then
		return 0
	end
	local best = math.huge
	for _, tower in ipairs(config.Signal.Towers) do
		local dx, dy = x - tower[1], y - tower[2]
		best = math.min(best, dx * dx + dy * dy)
	end
	best = math.sqrt(best)
	for index, range in ipairs(config.Signal.Ranges) do
		if best <= range then
			return 5 - index
		end
	end
	return 0
end

local function getAlgorithms()
	return (type(Core) == 'table' and Core.Algorithms) or CoeAlgorithms
end

-- Executa uma Saga transacional com compensação LIFO (ex.: inserir/ejetar chip entre inventário e banco).
function PhoneRules.ExecuteSaga(steps, context)
	local alg = getAlgorithms()
	if alg and alg.Concurrency and alg.Concurrency.executeSaga then
		return alg.Concurrency.executeSaga(steps, context)
	end
	local completed = {}
	local ctx = context or {}
	for i = 1, #steps do
		local ok, res = pcall(steps[i].action, ctx)
		if not ok or res == false then
			for j = #completed, 1, -1 do
				if completed[j].compensate then
					pcall(completed[j].compensate, ctx)
				end
			end
			return false, not ok and res or 'step_failed'
		end
		completed[#completed + 1] = steps[i]
	end
	return true, ctx
end

-- Cria rate limiter GCRA O(1) para chamadas de aplicativos, mensagens e fotos.
function PhoneRules.NewRateLimiter(cooldownMs)
	local alg = getAlgorithms()
	if alg and alg.RateLimit and alg.RateLimit.newGCRA then
		return alg.RateLimit.newGCRA(cooldownMs or 250, 0)
	end
	return nil
end

-- Cria cache LRU Intrusivo Zero-GC para dispositivos e contatos.
function PhoneRules.NewCache(capacity)
	local alg = getAlgorithms()
	if alg and alg.Containers and alg.Containers.newLRUCache then
		return alg.Containers.newLRUCache(capacity or 128)
	end
	return nil
end
