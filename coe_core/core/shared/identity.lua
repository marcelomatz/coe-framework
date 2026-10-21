local MAX_NAME_LENGTH = 48
local MAX_LICENSE_LENGTH = 72
-- Alfabeto sem I, L, O, 0 e 1 para evitar confusão visual. 31 símbolos, 8 posições.
local STATE_ID_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'
local STATE_ID_LENGTH = 8

local function trim(value)
	return (value:gsub('^%s*(.-)%s*$', '%1'))
end

function Core.Identity.NormalizeLicense(identifier)
	if type(identifier) ~= 'string' or #identifier > MAX_LICENSE_LENGTH
		or not identifier:match('^license:[%w]+$') then
		return nil, 'license_unavailable'
	end

	return identifier
end

function Core.Identity.NormalizeCharacterName(value)
	if type(value) ~= 'string' then
		return nil, 'invalid_character_name'
	end

	local name = trim(value)
	if name == '' or name:find('%c') then
		return nil, 'invalid_character_name'
	end

	local length = utf8.len(name)
	if not length or length > MAX_NAME_LENGTH then
		return nil, 'invalid_character_name'
	end

	return name
end

function Core.Identity.IsValidCharacterId(characterId)
	return type(characterId) == 'string'
		and #characterId <= 20
		and characterId:match('^[1-9]%d*$') ~= nil
end

-- Identidade pública do personagem. Não é segredo; a unicidade é garantida pelo banco.
function Core.Identity.GenerateStateId()
	local characters = {}
	for index = 1, STATE_ID_LENGTH do
		local position = math.random(#STATE_ID_ALPHABET)
		characters[index] = STATE_ID_ALPHABET:sub(position, position)
	end
	return table.concat(characters)
end

function Core.Identity.IsValidStateId(stateId)
	if type(stateId) ~= 'string' or #stateId ~= STATE_ID_LENGTH then
		return false
	end
	for index = 1, #stateId do
		if not STATE_ID_ALPHABET:find(stateId:sub(index, index), 1, true) then
			return false
		end
	end
	return true
end
