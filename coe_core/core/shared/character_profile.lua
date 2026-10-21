-- Validação dos dados de criação de personagem (nascimento, gênero e aparência).
-- O servidor é a autoridade: o cliente apenas propõe valores. A aparência é opaca para
-- o core; só validamos forma e limites para o JSON guardado ser seguro e previsível.
Core.CharacterProfile = {}

local MAX_APPEARANCE_BYTES = 16384
local MAX_APPEARANCE_DEPTH = 8
local MAX_APPEARANCE_NODES = 1024
local MAX_APPEARANCE_KEY_LENGTH = 64
local MAX_APPEARANCE_STRING_LENGTH = 1024
local MAX_APPEARANCE_VERSION = 65535
local MAX_GENDER_LENGTH = 16

local PROFILE_KEYS = {
	birthDate = true,
	gender = true,
	appearance = true,
	appearanceVersion = true
}

local rules = {
	minAge = 18,
	maxAge = 90,
	genders = { male = true, female = true }
}

local function isInteger(value)
	return type(value) == 'number' and value == math.floor(value) and value > -math.huge and value < math.huge
end

-- Configura idade mínima/máxima e a lista de gêneros aceitos (identificadores em minúsculas).
function Core.CharacterProfile.SetRules(minAge, maxAge, genders)
	if not isInteger(minAge) or not isInteger(maxAge) or minAge < 0 or maxAge > 150 or minAge > maxAge then
		return false, 'invalid_profile_rules'
	end
	if type(genders) ~= 'table' or #genders == 0 then
		return false, 'invalid_profile_rules'
	end

	local allowed = {}
	for _, gender in ipairs(genders) do
		if type(gender) ~= 'string' or #gender > MAX_GENDER_LENGTH or not gender:match('^[a-z][a-z0-9_]*$') then
			return false, 'invalid_profile_rules'
		end
		allowed[gender] = true
	end

	rules = { minAge = minAge, maxAge = maxAge, genders = allowed }
	return true
end

local function isLeapYear(year)
	return (year % 4 == 0 and year % 100 ~= 0) or year % 400 == 0
end

local function daysInMonth(year, month)
	if month == 2 then
		return isLeapYear(year) and 29 or 28
	end
	if month == 4 or month == 6 or month == 9 or month == 11 then
		return 30
	end
	return 31
end

-- `today` é { year, month, day } (UTC); injetável para os testes.
function Core.CharacterProfile.NormalizeBirthDate(value, today)
	if type(value) ~= 'string' then
		return nil, 'invalid_birth_date'
	end
	local year, month, day = value:match('^(%d%d%d%d)-(%d%d)-(%d%d)$')
	if not year then
		return nil, 'invalid_birth_date'
	end
	year, month, day = tonumber(year), tonumber(month), tonumber(day)
	if month < 1 or month > 12 or day < 1 or day > daysInMonth(year, month) then
		return nil, 'invalid_birth_date'
	end

	today = today or os.date('!*t')
	local age = today.year - year
	if today.month < month or (today.month == month and today.day < day) then
		age = age - 1
	end
	if age < rules.minAge or age > rules.maxAge then
		return nil, 'birth_date_out_of_range'
	end

	return value
end

function Core.CharacterProfile.NormalizeGender(value)
	if type(value) ~= 'string' or #value > MAX_GENDER_LENGTH then
		return nil, 'invalid_gender'
	end
	local gender = value:lower()
	if not rules.genders[gender] then
		return nil, 'invalid_gender'
	end
	return gender
end

-- Aceita só tabelas (lista pura ou objeto com chaves string), strings, números finitos e
-- booleanos, com profundidade e quantidade de nós limitadas.
local function validateAppearanceNode(node, depth, counter)
	counter.nodes = counter.nodes + 1
	if counter.nodes > MAX_APPEARANCE_NODES then
		return false
	end

	local kind = type(node)
	if kind == 'boolean' then
		return true
	end
	if kind == 'number' then
		return node == node and node > -math.huge and node < math.huge
	end
	if kind == 'string' then
		return #node <= MAX_APPEARANCE_STRING_LENGTH
	end
	if kind ~= 'table' or depth > MAX_APPEARANCE_DEPTH then
		return false
	end

	local count, isList, isObject = 0, false, false
	for key, child in pairs(node) do
		count = count + 1
		if type(key) == 'string' then
			if #key == 0 or #key > MAX_APPEARANCE_KEY_LENGTH then
				return false
			end
			isObject = true
		elseif isInteger(key) and key >= 1 then
			isList = true
		else
			return false
		end
		if isList and isObject then
			return false
		end
		if not validateAppearanceNode(child, depth + 1, counter) then
			return false
		end
	end

	if isList then
		for index = 1, count do
			if node[index] == nil then
				return false
			end
		end
	end
	return true
end

-- `encode` serializa para JSON (json.encode no FiveM). Devolve o texto pronto para o banco.
function Core.CharacterProfile.NormalizeAppearance(value, version, encode)
	if type(value) ~= 'table' or not isInteger(version) or version < 1 or version > MAX_APPEARANCE_VERSION then
		return nil, nil, 'invalid_appearance'
	end
	if type(encode) ~= 'function' then
		return nil, nil, 'json_unavailable'
	end
	if not validateAppearanceNode(value, 1, { nodes = 0 }) then
		return nil, nil, 'invalid_appearance'
	end

	local ok, encoded = pcall(encode, value)
	if not ok or type(encoded) ~= 'string' or #encoded > MAX_APPEARANCE_BYTES then
		return nil, nil, 'invalid_appearance'
	end
	return encoded, version
end

-- Devolve { birthDate, gender, appearanceJson, appearanceVersion } (campos ausentes = nil).
-- Qualquer chave desconhecida é rejeitada: o cliente não decide o formato do perfil.
function Core.CharacterProfile.Normalize(profile, encode, today)
	if profile == nil then
		return {}
	end
	if type(profile) ~= 'table' then
		return nil, 'invalid_profile'
	end
	for key in pairs(profile) do
		if not PROFILE_KEYS[key] then
			return nil, 'invalid_profile'
		end
	end

	local result = {}
	if profile.birthDate ~= nil then
		local birthDate, birthError = Core.CharacterProfile.NormalizeBirthDate(profile.birthDate, today)
		if not birthDate then
			return nil, birthError
		end
		result.birthDate = birthDate
	end
	if profile.gender ~= nil then
		local gender, genderError = Core.CharacterProfile.NormalizeGender(profile.gender)
		if not gender then
			return nil, genderError
		end
		result.gender = gender
	end

	if (profile.appearance ~= nil) ~= (profile.appearanceVersion ~= nil) then
		return nil, 'invalid_appearance'
	end
	if profile.appearance ~= nil then
		local json, version, appearanceError = Core.CharacterProfile.NormalizeAppearance(
			profile.appearance, profile.appearanceVersion, encode)
		if not json then
			return nil, appearanceError
		end
		result.appearanceJson = json
		result.appearanceVersion = version
		result.appearance = profile.appearance
	end

	return result
end
