-- Regras puras (sem natives): validação do cadastro, senha e avaliação de acesso. Testadas em test/doors_test.lua.
DoorsRules = {}

local ID_PATTERN = '^[a-z0-9_]+$'

local function finite(value)
	return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

-- JSON (NUI e banco) pode trazer inteiros como float: aceita só valores inteiros de fato.
local function int(value)
	return type(value) == 'number' and math.tointeger(value) or nil
end

local function round(value, places)
	local factor = 10 ^ places
	return math.floor(value * factor + 0.5) / factor
end

local function validId(value)
	return type(value) == 'string' and #value >= 2 and #value <= 32 and value:match(ID_PATTERN) ~= nil
end

local function cleanLabel(value)
	if type(value) ~= 'string' then
		return nil
	end
	value = value:gsub('^%s+', ''):gsub('%s+$', '')
	if #value < 1 or #value > 48 or value:find('[<>]') then
		return nil
	end
	return value
end

local function normalizeLeaves(raw, maxLeaves, maxGap)
	if type(raw) ~= 'table' or #raw < 1 or #raw > maxLeaves then
		return nil
	end
	local leaves = {}
	for index = 1, #raw do
		local leaf = raw[index]
		local model = type(leaf) == 'table' and int(leaf.model) or nil
		if not model or model < -2147483648 or model > 4294967295 or model == 0
			or not finite(leaf.x) or not finite(leaf.y) or not finite(leaf.z) then
			return nil
		end
		leaves[index] = { model = model, x = round(leaf.x, 3), y = round(leaf.y, 3), z = round(leaf.z, 3) }
	end
	if #leaves == 2 then
		local a, b = leaves[1], leaves[2]
		local gap = math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2)
		if gap < 0.05 or gap > maxGap then
			return nil
		end
	end
	return leaves
end

local ENTRY_KEY_PATTERN = '^[a-z0-9_]+$'

local function normalizeCharacter(entry)
	local characterId = type(entry) == 'table' and tostring(entry.characterId or '') or ''
	if not characterId:match('^%d+$') or #characterId > 20 then
		return nil
	end
	local name = type(entry.name) == 'string' and entry.name:gsub('[<>%c]', ''):sub(1, 48) or ''
	return { characterId = characterId, name = name }
end

-- Lista de personagens sem repetição; nil se inválida.
local function normalizeCharacters(raw, max)
	if raw == nil then
		return {}
	end
	if type(raw) ~= 'table' or #raw > max then
		return nil
	end
	local list, seen = {}, {}
	for _, entry in ipairs(raw) do
		local character = normalizeCharacter(entry)
		if not character or seen[character.characterId] then
			return nil
		end
		seen[character.characterId] = true
		list[#list + 1] = character
	end
	return list
end

-- Uma porta do local: folhas, tipo, distância, trava automática e estado padrão próprios, além de acesso
-- exclusivo (só o dono e `allowed`) e senha da porta (exigida para destrancar mesmo de quem tem acesso).
local function normalizeEntry(raw, index, config, previousEntry, newSalt)
	if type(raw) ~= 'table' then
		return nil, 'invalid_entry'
	end
	local key = raw.key
	if type(key) ~= 'string' or #key < 1 or #key > 16 or not key:match(ENTRY_KEY_PATTERN) then
		return nil, 'invalid_entry'
	end
	local label = raw.label
	if label == nil or (type(label) == 'string' and label:match('^%s*$')) then
		label = ('Porta %d'):format(index)
	end
	label = cleanLabel(label)
	if not label then
		return nil, 'invalid_label'
	end
	local count = type(raw.doors) == 'table' and #raw.doors or 0
	local kindName = raw.kind
	if kindName == nil then
		kindName = count == 2 and 'double' or 'single'
	end
	local kind = type(kindName) == 'string' and config.Kinds[kindName] or nil
	if not kind then
		return nil, 'invalid_entry'
	end
	local limits = config.Limits
	local leaves = normalizeLeaves(raw.doors, math.min(kind.maxLeaves, limits.MaxLeaves), kind.wide and limits.WideLeafGap or limits.MaxLeafGap)
	if not leaves or #leaves < kind.minLeaves then
		return nil, 'invalid_doors'
	end
	local distance = raw.distance == nil and config.Distance.Default or raw.distance
	local maxDistance = kind.wide and config.Distance.WideMax or config.Distance.Max
	if not finite(distance) or distance < config.Distance.Min or distance > maxDistance then
		return nil, 'invalid_distance'
	end
	local autoLock = int(raw.autoLock == nil and 0 or raw.autoLock)
	if not autoLock or autoLock < 0 or autoLock > config.AutoLock.Max then
		return nil, 'invalid_autolock'
	end
	local allowed = normalizeCharacters(raw.allowed, limits.MaxEntryCharacters)
	if not allowed then
		return nil, 'invalid_access'
	end
	local pin = previousEntry and previousEntry.pin or nil
	if raw.clearPin == true then
		pin = nil
	elseif type(raw.pin) == 'string' and raw.pin ~= '' then
		if not DoorsRules.ValidPin(raw.pin, config) then
			return nil, 'invalid_pin'
		end
		local salt = newSalt()
		pin = { salt = salt, hash = DoorsRules.HashPin(salt, raw.pin) }
	end
	return {
		key = key, label = label, kind = kindName, doors = leaves, distance = round(distance, 1),
		autoLock = autoLock, locked = raw.locked ~= false, restricted = raw.restricted == true, allowed = allowed, pin = pin
	}
end
local function normalizeAccess(raw, limits)
	raw = type(raw) == 'table' and raw or {}
	local access = { businesses = {}, factions = {}, characters = {}, items = {}, key = raw.key == true }
	local lists = { { 'businesses', limits.MaxBusinesses }, { 'factions', limits.MaxFactions }, { 'characters', limits.MaxCharacters }, { 'items', limits.MaxItems } }
	for _, spec in ipairs(lists) do
		local source = raw[spec[1]]
		if source ~= nil and (type(source) ~= 'table' or #source > spec[2]) then
			return nil
		end
	end
	local seen = {}
	for _, entry in ipairs(raw.businesses or {}) do
		if type(entry) ~= 'table' or not validId(entry.id) or seen['b' .. entry.id] then
			return nil
		end
		seen['b' .. entry.id] = true
		access.businesses[#access.businesses + 1] = { id = entry.id, duty = entry.duty == true }
	end
	for _, entry in ipairs(raw.factions or {}) do
		local minGrade = type(entry) == 'table' and int(entry.minGrade or 0) or nil
		if type(entry) ~= 'table' or not validId(entry.id) or seen['f' .. entry.id] or not minGrade or minGrade < 0 or minGrade > 100 then
			return nil
		end
		seen['f' .. entry.id] = true
		access.factions[#access.factions + 1] = { id = entry.id, minGrade = minGrade }
	end
	local characters = normalizeCharacters(raw.characters, limits.MaxCharacters)
	if not characters then
		return nil
	end
	access.characters = characters
	for _, name in ipairs(raw.items or {}) do
		if not validId(name) or seen['i' .. name] then
			return nil
		end
		seen['i' .. name] = true
		access.items[#access.items + 1] = name
	end
	return access
end

function DoorsRules.ValidPin(pin, config)
	return type(pin) == 'string' and #pin >= config.Pin.MinLength and #pin <= config.Pin.MaxLength and pin:match('^%d+$') ~= nil
end

function DoorsRules.HashPin(salt, pin)
	return DoorsHash.Sha256(salt .. ':' .. pin)
end

function DoorsRules.PinMatches(door, pin, config)
	if type(door.pin) ~= 'table' or not DoorsRules.ValidPin(pin, config) then
		return false
	end
	return DoorsRules.HashPin(door.pin.salt, pin) == door.pin.hash
end

-- Cadastro antigo (uma porta por registro): vira um local com uma porta "Principal".
local function legacyEntries(raw)
	return { {
		key = 'principal', label = 'Principal', doors = raw.doors, distance = raw.distance,
		autoLock = raw.autoLock, locked = raw.locked
	} }
end

-- raw vem do admin; previous é o cadastro atual (mantém a senha quando não muda); newSalt() gera o salt de uma senha nova.
-- O cadastro é um local (casa, prédio, sede): acesso, senha e chave valem para todas as portas de entries.
function DoorsRules.Normalize(raw, config, previous, newSalt)
	if type(raw) ~= 'table' then
		return nil, 'invalid_door'
	end
	if not validId(raw.id) then
		return nil, 'invalid_id'
	end
	local label = cleanLabel(raw.label)
	if not label then
		return nil, 'invalid_label'
	end
	local rawEntries = raw.entries
	if rawEntries == nil and raw.doors ~= nil then
		rawEntries = legacyEntries(raw)
	end
	if type(rawEntries) ~= 'table' or #rawEntries < 1 then
		return nil, 'invalid_doors'
	end
	if #rawEntries > config.Limits.MaxEntries then
		return nil, 'entry_limit'
	end
	local previousEntries = {}
	for _, entry in ipairs(previous and type(previous.entries) == 'table' and previous.entries or {}) do
		if type(entry) == 'table' and type(entry.key) == 'string' then
			previousEntries[entry.key] = entry
		end
	end
	local entries, seen = {}, {}
	for index = 1, #rawEntries do
		local rawEntry = rawEntries[index]
		local entry, errorCode = normalizeEntry(rawEntry, index, config, type(rawEntry) == 'table' and previousEntries[rawEntry.key] or nil, newSalt)
		if not entry then
			return nil, errorCode
		end
		if seen[entry.key] then
			return nil, 'duplicate_entry'
		end
		seen[entry.key] = true
		entries[index] = entry
	end
	local access = normalizeAccess(raw.access, config.Limits)
	if not access then
		return nil, 'invalid_access'
	end
	local owner = nil
	if raw.owner ~= nil then
		owner = normalizeCharacter(raw.owner)
		if not owner then
			return nil, 'invalid_owner'
		end
	end

	local pin = previous and previous.pin or nil
	if raw.clearPin == true then
		pin = nil
	elseif raw.pin ~= nil and raw.pin ~= '' then
		if not DoorsRules.ValidPin(raw.pin, config) then
			return nil, 'invalid_pin'
		end
		local salt = newSalt()
		pin = { salt = salt, hash = DoorsRules.HashPin(salt, raw.pin) }
	end

	return { id = raw.id, label = label, enabled = raw.enabled ~= false, entries = entries, access = access, pin = pin, owner = owner }
end

function DoorsRules.IsOwner(place, characterId)
	return place.owner ~= nil and characterId ~= nil and place.owner.characterId == tostring(characterId)
end

-- ID de uma porta em tempo de execução (estado, eventos de rede e exports): "<local>:<porta>".
function DoorsRules.RuntimeId(place, entry)
	return place.id .. ':' .. entry.key
end

-- Centro das folhas de uma porta (entry).
function DoorsRules.Center(entry)
	local x, y, z = 0, 0, 0
	for _, leaf in ipairs(entry.doors) do
		x, y, z = x + leaf.x, y + leaf.y, z + leaf.z
	end
	local count = #entry.doors
	return { x = x / count, y = y / count, z = z / count }
end

function DoorsRules.EntryLabel(place, entry)
	if #place.entries == 1 then
		return place.label
	end
	return place.label .. ' · ' .. entry.label
end
-- facts: characterId e funções preguiçosas business(id) -> { member, onDuty }, factionGrade(id) -> grade|nil,
-- itemCount(name, metadata) -> número. Retorna true e o motivo do acesso, ou false.
-- doorEntry (opcional): a porta usada; se for exclusiva, só o dono e os personagens dela passam.
function DoorsRules.CanAccess(door, facts, config, doorEntry)
	local access = door.access
	if not access or not facts.characterId then
		return false
	end
	if DoorsRules.IsOwner(door, facts.characterId) then
		return true, 'owner'
	end
	if doorEntry and doorEntry.restricted then
		for _, entry in ipairs(doorEntry.allowed or {}) do
			if entry.characterId == tostring(facts.characterId) then
				return true, 'allowed'
			end
		end
		return false
	end
	for _, entry in ipairs(access.characters) do
		if entry.characterId == tostring(facts.characterId) then
			return true, 'character'
		end
	end
	for _, rule in ipairs(access.businesses) do
		local info = facts.business(rule.id)
		if info and info.member and (not rule.duty or info.onDuty) then
			return true, 'business'
		end
	end
	for _, rule in ipairs(access.factions) do
		local grade = facts.factionGrade(rule.id)
		if grade and grade >= rule.minGrade then
			return true, 'faction'
		end
	end
	for _, name in ipairs(access.items) do
		if (facts.itemCount(name) or 0) > 0 then
			return true, 'item'
		end
	end
	if access.key and (facts.itemCount(config.KeyItem, { door = door.id }) or 0) > 0 then
		return true, 'key'
	end
	return false
end

-- Visão pública (clientes): uma linha por porta do local, sem regras de acesso nem dados da senha.
-- lockOf(runtimeId) -> trancada.
function DoorsRules.Public(place, lockOf)
	local list = {}
	for index, entry in ipairs(place.entries) do
		local runtimeId = DoorsRules.RuntimeId(place, entry)
		list[index] = {
			id = runtimeId, place = place.id, label = DoorsRules.EntryLabel(place, entry), kind = entry.kind,
			distance = entry.distance, doors = entry.doors, center = DoorsRules.Center(entry),
			locked = lockOf(runtimeId), hasPin = place.pin ~= nil
		}
	end
	return list
end

-- Visão do admin: tudo menos o hash/salt da senha; current = estado atual de cada porta.
function DoorsRules.Admin(place, lockOf)
	local entries = {}
	for index, entry in ipairs(place.entries) do
		entries[index] = {
			key = entry.key, label = entry.label, kind = entry.kind, doors = entry.doors, distance = entry.distance,
			autoLock = entry.autoLock, locked = entry.locked, current = lockOf(DoorsRules.RuntimeId(place, entry)),
			restricted = entry.restricted == true, allowed = entry.allowed or {}, hasPin = entry.pin ~= nil
		}
	end
	return {
		id = place.id, label = place.label, enabled = place.enabled, entries = entries, access = place.access,
		hasPin = place.pin ~= nil, owner = place.owner
	}
end

-- Visão do dono (app Casa do tablet): só o que ele gerencia, sem regras do admin nem dados das senhas.
function DoorsRules.OwnerView(place, lockOf)
	local entries = {}
	for index, entry in ipairs(place.entries) do
		entries[index] = {
			key = entry.key, label = entry.label, kind = entry.kind, locked = lockOf(DoorsRules.RuntimeId(place, entry)),
			restricted = entry.restricted == true, allowed = entry.allowed or {}, hasPin = entry.pin ~= nil
		}
	end
	return { id = place.id, label = place.label, enabled = place.enabled, entries = entries }
end