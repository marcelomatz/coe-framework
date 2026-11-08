MdtRules = {}

local CODE_PATTERN = '^[a-z0-9_]+$'

-- Texto livre: remove controles (exceto \n quando multiline), apara e limita por caracteres UTF-8.
-- Retorna o texto limpo ou nil, codigo.
function MdtRules.Text(value, minLength, maxLength, multiline)
	if type(value) ~= 'string' or #value > maxLength * 4 then
		return nil, 'invalid_text'
	end
	local cleaned = value:gsub('\r', '')
	if multiline then
		cleaned = cleaned:gsub('[\0-\9\11-\31\127]', '')
	else
		cleaned = cleaned:gsub('[\0-\31\127]', ' ')
	end
	cleaned = cleaned:gsub('^%s+', ''):gsub('%s+$', '')
	local length = utf8.len(cleaned)
	if not length or length < minLength or length > maxLength then
		return nil, 'invalid_text'
	end
	return cleaned
end

-- Motivo curto (código), como na polícia: [a-z0-9_]{2,32}.
function MdtRules.Charge(value)
	if type(value) ~= 'string' or #value < 2 or #value > 32 or not value:match(CODE_PATTERN) then
		return nil, 'invalid_charge'
	end
	return value
end

function MdtRules.Plate(value)
	if type(value) ~= 'string' then
		return nil, 'invalid_plate'
	end
	local plate = value:gsub('^%s+', ''):gsub('%s+$', ''):upper()
	if #plate < 1 or #plate > 8 or not plate:match('^[A-Z0-9 ]+$') then
		return nil, 'invalid_plate'
	end
	return plate
end

function MdtRules.StateId(value)
	if type(value) ~= 'string' then
		return nil
	end
	local id = value:gsub('^%s+', ''):gsub('%s+$', ''):upper()
	if #id == 8 and id:match('^[A-Z0-9]+$') then
		return id
	end
	return nil
end

-- Termos de busca por nome: até 3 palavras de 2..24 bytes, só letras (inclui acentuadas), hífen e apóstrofo.
function MdtRules.Tokens(term)
	if type(term) ~= 'string' or #term > 96 then
		return nil, 'invalid_term'
	end
	local tokens = {}
	for word in term:gmatch('%S+') do
		local clean = word:gsub("[^%a\128-\255%-']", '')
		if #clean >= 2 and #clean <= 24 then
			tokens[#tokens + 1] = clean
			if #tokens > 3 then
				return nil, 'invalid_term'
			end
		end
	end
	if #tokens == 0 then
		return nil, 'term_too_short'
	end
	return tokens
end

function MdtRules.CharacterId(value)
	local text = tostring(value or '')
	if not text:match('^%d+$') or #text > 18 then
		return nil, 'invalid_character'
	end
	return text
end

function MdtRules.Id(value)
	if type(value) ~= 'number' or value ~= value or value % 1 ~= 0 or value < 1 or value > 2 ^ 53 then
		return nil, 'invalid_id'
	end
	return math.tointeger(value)
end

-- Mandado: active -> served | revoked; nada sai de um estado final.
function MdtRules.CanCloseWarrant(from, to)
	return from == 'active' and (to == 'served' or to == 'revoked')
end

-- Boletim: horas de validade entre 1 e max (padrão 24).
function MdtRules.BulletinHours(value, config)
	if value == nil then
		return config.BulletinDefaultHours
	end
	if type(value) ~= 'number' or value ~= value or value % 1 ~= 0 or value < 1 or value > config.BulletinMaxHours then
		return nil, 'invalid_hours'
	end
	return math.tointeger(value)
end

function MdtRules.Limit(value, default, max)
	if type(value) ~= 'number' or value ~= value or value % 1 ~= 0 or value < 1 then
		return default
	end
	return math.min(math.tointeger(value), max)
end

-- Janela deslizante por policial: true se pode agir agora (registra o carimbo).
function MdtRules.Allow(stamps, now, maxPerWindow, windowSeconds)
	local kept = {}
	for _, stamp in ipairs(stamps) do
		if now - stamp < windowSeconds then
			kept[#kept + 1] = stamp
		end
	end
	for index = #stamps, 1, -1 do
		stamps[index] = nil
	end
	for index, stamp in ipairs(kept) do
		stamps[index] = stamp
	end
	if #stamps >= maxPerWindow then
		return false
	end
	stamps[#stamps + 1] = now
	return true
end

-- Cache intrusivo Zero-GC (LRU) para fichas e nomes de personagens no MDT
function MdtRules.NewCache(capacity)
	local alg = (type(Core) == 'table' and Core.Algorithms) or CoeAlgorithms
	local Containers = (type(alg) == 'table' and alg.Containers) or nil
	if Containers and Containers.newLRUCache then
		return Containers.newLRUCache(capacity or 128)
	end
	local map = {}
	return {
		get = function(_, key) return map[key] end,
		put = function(_, key, val) map[key] = val end,
		remove = function(_, key) map[key] = nil end,
		clear = function(_) map = {} end
	}
end

-- Rate Limiter GCRA O(1) para buscas e escritas no MDT
function MdtRules.NewRateLimiter(maxPerWindow, windowSeconds)
	local alg = (type(Core) == 'table' and Core.Algorithms) or CoeAlgorithms
	local RateLimit = (type(alg) == 'table' and alg.RateLimit) or nil
	local emissionMs = math.max(1, math.floor((windowSeconds * 1000) / math.max(1, maxPerWindow)))
	local burstMs = math.max(0, (maxPerWindow - 1) * emissionMs)
	if RateLimit and RateLimit.newGCRA then
		return RateLimit.newGCRA(emissionMs, burstMs)
	end
	local stampsByKey = {}
	return {
		allow = function(_, key, nowMs)
			stampsByKey[key] = stampsByKey[key] or {}
			return MdtRules.Allow(stampsByKey[key], math.floor(nowMs / 1000), maxPerWindow, windowSeconds), 0
		end,
		forget = function(_, key)
			stampsByKey[key] = nil
		end
	}
end
