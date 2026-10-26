-- Regras do telefone básico, sem natives (testáveis fora do jogo).
MobileRules = {}

-- Pedidos aceitos da tela. `writes` passam pelo intervalo mínimo entre operações.
MobileRules.Actions = {
	contacts = 'read', contact_save = 'write', contact_delete = 'write',
	threads = 'read', thread = 'read', thread_delete = 'write', message_send = 'message',
	recents = 'read', call_start = 'write', call_answer = 'call', call_decline = 'call', call_end = 'call',
	bank_info = 'read', bank_transfer = 'write',
	settings_save = 'write'
}

local function digitsOf(config)
	local number = config.Number
	return tostring(number.Prefix), math.tointeger(number.Digits)
end

---Número no formato de exibição (555-0123), aceitando espaços, traços, pontos e parênteses; nil + 'invalid_number'.
function MobileRules.Number(value, config)
	if type(value) ~= 'string' and type(value) ~= 'number' then
		return nil, 'invalid_number'
	end
	local clean = tostring(value):gsub('[%s%-%.%(%)]', '')
	local prefix, digits = digitsOf(config)
	if #clean ~= #prefix + digits or not clean:match('^%d+$') or clean:sub(1, #prefix) ~= prefix then
		return nil, 'invalid_number'
	end
	return prefix .. '-' .. clean:sub(#prefix + 1)
end

---Número novo e aleatório. `random(min, max)` é injetado (math.random no jogo).
function MobileRules.Generate(config, random)
	local prefix, digits = digitsOf(config)
	local parts = {}
	for index = 1, digits do
		parts[index] = tostring(random(0, 9))
	end
	return prefix .. '-' .. table.concat(parts)
end

-- Texto livre: remove caracteres de controle (mantém quebras de linha se `multiline`), apara as bordas e confere
-- o tamanho em caracteres (UTF-8). Retorna o texto ou nil.
local function cleanText(value, max, multiline)
	if type(value) ~= 'string' or #value > max * 4 then
		return nil
	end
	local text = value:gsub('\r\n?', '\n')
	if multiline then
		text = text:gsub('[\0-\9\11-\31\127]', ''):gsub('\n\n\n+', '\n\n')
	else
		text = text:gsub('[\0-\31\127]', ' '):gsub('  +', ' ')
	end
	text = text:gsub('^%s+', ''):gsub('%s+$', '')
	local length = utf8.len(text)
	if not length or length < 1 or length > max then
		return nil
	end
	return text
end

function MobileRules.ContactName(value, max)
	local name = cleanText(value, max, false)
	if not name then
		return nil, 'invalid_name'
	end
	return name
end

function MobileRules.Body(value, max)
	local body = cleanText(value, max, true)
	if not body then
		return nil, 'invalid_message'
	end
	return body
end

local function listHas(list, value)
	for _, item in ipairs(list) do
		if item == value then
			return true
		end
	end
	return false
end

---Ajustes válidos: parte de `current` (ou dos defaults) e aplica só os campos aceitos de `input`.
function MobileRules.Settings(input, config, current)
	local settings = config.Settings
	local out = {}
	for key, value in pairs(settings.Defaults) do
		out[key] = value
	end
	for _, source in ipairs({ current, input }) do
		if type(source) == 'table' then
			if type(source.silent) == 'boolean' then
				out.silent = source.silent
			end
			local volume = math.tointeger(tonumber(source.volume))
			if volume and volume >= 0 and volume <= 10 then
				out.volume = volume
			end
			if listHas(settings.Ringtones, source.ringtone) then
				out.ringtone = source.ringtone
			end
			if listHas(settings.Wallpapers, source.wallpaper) then
				out.wallpaper = source.wallpaper
			end
		end
	end
	return out
end

---Canal de voz da ligação: imprevisível, para ninguém entrar numa chamada adivinhando o id.
function MobileRules.CallId(random)
	local parts = {}
	for index = 1, 16 do
		parts[index] = string.format('%x', random(0, 15))
	end
	return 'coe_mobile:' .. table.concat(parts)
end

---Inteiro positivo (ids vindos da tela) ou nil.
function MobileRules.Id(value)
	local id = math.tointeger(tonumber(value))
	if not id or id < 1 then
		return nil
	end
	return id
end

---Nome de exibição do personagem.
function MobileRules.Name(firstName, lastName)
	local parts = {}
	for _, part in ipairs({ firstName, lastName }) do
		if type(part) == 'string' and part ~= '' then
			parts[#parts + 1] = part
		end
	end
	return #parts > 0 and table.concat(parts, ' ') or nil
end
