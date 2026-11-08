dofile('../coe_core/lib/algorithms/init.lua')
dofile('config.lua')
dofile('server/sha256.lua')
dofile('server/rules.lua')

local config = DoorsConfig
local failures = 0

local function eq(actual, expected, message)
	if actual ~= expected then
		failures = failures + 1
		print(('FAIL %s: esperado %s, obtido %s'):format(message, tostring(expected), tostring(actual)))
	end
end

local function salt()
	return 'abcd1234'
end

eq(DoorsHash.Sha256('abc'), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad', 'sha256 abc')
eq(DoorsHash.Sha256(''), 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', 'sha256 vazio')
eq(DoorsHash.Sha256(string.rep('a', 64)), 'ffe054fe7ae0cb6dc65c3af9b61d5209f439851db43d0ba5997337df154668eb', 'sha256 64 bytes')

local function base()
	return {
		id = 'pd_front', label = ' Recepção DP ', doors = { { model = 1234.0, x = 10.12345, y = 20, z = 30 } },
		access = { businesses = { { id = 'lspd', duty = true } }, factions = { { id = 'gang', minGrade = 2.0 } },
			characters = { { characterId = 42, name = 'Ana<b>' } }, items = { 'lockpick' }, key = true }
	}
end

local door, err = DoorsRules.Normalize(base(), config, nil, salt)
eq(err, nil, 'cadastro válido')
eq(door.label, 'Recepção DP', 'label sem espaços')
eq(#door.entries, 1, 'cadastro antigo vira local com uma porta')
eq(door.entries[1].key, 'principal', 'porta principal')
eq(door.entries[1].kind, 'single', 'tipo inferido')
eq(door.entries[1].doors[1].x, 10.123, 'arredonda coordenada')
eq(math.type(door.entries[1].doors[1].model), 'integer', 'modelo vira inteiro')
eq(door.entries[1].locked, true, 'trancada por padrão')
eq(door.entries[1].distance, config.Distance.Default, 'distância padrão')
eq(door.access.characters[1].characterId, '42', 'personagem como texto')
eq(door.access.characters[1].name, 'Anab', 'nome limpo')
eq(door.access.factions[1].minGrade, 2, 'grau mínimo inteiro')
eq(door.pin, nil, 'sem senha')

local function invalid(mutate, expected)
	local raw = base()
	mutate(raw)
	local _, code = DoorsRules.Normalize(raw, config, nil, salt)
	eq(code, expected, 'inválido ' .. expected)
end

invalid(function(raw) raw.id = 'A b' end, 'invalid_id')
invalid(function(raw) raw.label = '<x>' end, 'invalid_label')
invalid(function(raw) raw.doors = {} end, 'invalid_doors')
invalid(function(raw) raw.doors[1].model = 1.5 end, 'invalid_doors')
invalid(function(raw) raw.doors[2] = { model = 1, x = 10.12, y = 20, z = 30 } end, 'invalid_doors')
invalid(function(raw) raw.doors[2] = { model = 1, x = 30, y = 20, z = 30 } end, 'invalid_doors')
invalid(function(raw) raw.distance = 99 end, 'invalid_distance')
invalid(function(raw) raw.autoLock = 2.5 end, 'invalid_autolock')
invalid(function(raw) raw.access.factions[1].minGrade = -1 end, 'invalid_access')
invalid(function(raw) raw.access.businesses[2] = { id = 'lspd' } end, 'invalid_access')
invalid(function(raw) raw.access.items = { 'a', 'b', 'c', 'd', 'e' } end, 'invalid_access')
invalid(function(raw) raw.pin = '12a4' end, 'invalid_pin')
invalid(function(raw) raw.pin = '123' end, 'invalid_pin')

local double = base()
double.doors[2] = { model = 99, x = 11.5, y = 20, z = 30 }
local pair = DoorsRules.Normalize(double, config, nil, salt)
eq(#pair.entries[1].doors, 2, 'porta dupla')
eq(pair.entries[1].kind, 'double', 'tipo dupla inferido')
eq(DoorsRules.Center(pair.entries[1]).x, (10.123 + 11.5) / 2, 'centro da porta dupla')

-- Local com várias portas: entrada, fundos e garagem com as mesmas regras.
local function house()
	local raw = base()
	raw.id, raw.label, raw.doors = 'casa_1', 'Casa 1', nil
	raw.entries = {
		{ key = 'frente', label = 'Frente', kind = 'single', doors = { { model = 1, x = 0, y = 0, z = 0 } } },
		{ key = 'fundos', label = '', doors = { { model = 2, x = 5, y = 0, z = 0 } }, locked = false, autoLock = 30 },
		{ key = 'garagem', label = 'Garagem', kind = 'garage', distance = 10, doors = { { model = 3, x = 0, y = 10, z = 0 }, { model = 3, x = 10, y = 10, z = 0 } } }
	}
	return raw
end
local home, homeErr = DoorsRules.Normalize(house(), config, nil, salt)
eq(homeErr, nil, 'local com várias portas')
eq(#home.entries, 3, 'três portas')
eq(home.entries[2].label, 'Porta 2', 'nome padrão da porta')
eq(home.entries[2].locked, false, 'estado padrão por porta')
eq(home.entries[2].autoLock, 30, 'trava automática por porta')
eq(home.entries[3].distance, 10, 'garagem aceita distância maior')
eq(DoorsRules.RuntimeId(home, home.entries[3]), 'casa_1:garagem', 'ID de execução')
local states = { ['casa_1:frente'] = true, ['casa_1:fundos'] = false, ['casa_1:garagem'] = true }
local function lockOf(id) return states[id] end
local view = DoorsRules.Public(home, lockOf)
eq(#view, 3, 'público: uma linha por porta')
eq(view[3].label, 'Casa 1 · Garagem', 'rótulo com local e porta')
eq(view[3].kind, 'garage', 'público com tipo')
eq(view[2].locked, false, 'público com estado da porta')
eq(view[1].access, nil, 'público sem regras')
eq(DoorsRules.Public(door, lockOf)[1].label, door.label, 'porta única usa o nome do local')
local adminView = DoorsRules.Admin(home, lockOf)
eq(adminView.entries[2].current, false, 'admin com estado atual')
eq(adminView.entries[3].kind, 'garage', 'admin com tipo')
local function invalidHouse(mutate, expected)
	local raw = house()
	mutate(raw)
	local _, code = DoorsRules.Normalize(raw, config, nil, salt)
	eq(code, expected, 'local inválido ' .. expected)
end
invalidHouse(function(raw) raw.entries[2].key = 'frente' end, 'duplicate_entry')
invalidHouse(function(raw) raw.entries[2].key = 'Fundos!' end, 'invalid_entry')
invalidHouse(function(raw) raw.entries[2].kind = 'janela' end, 'invalid_entry')
invalidHouse(function(raw) raw.entries[1].distance = 10 end, 'invalid_distance')
invalidHouse(function(raw) raw.entries[1].kind = 'double' end, 'invalid_doors')
invalidHouse(function(raw) raw.entries = {} end, 'invalid_doors')
invalidHouse(function(raw)
	for index = 4, config.Limits.MaxEntries + 1 do
		raw.entries[index] = { key = 'p' .. index, doors = { { model = 9, x = index, y = 0, z = 0 } } }
	end
end, 'entry_limit')
local wideGate = house()
wideGate.entries[3].doors[2].x = 12
eq(select(2, DoorsRules.Normalize(wideGate, config, nil, salt)), nil, 'portão aceita folhas mais distantes')

-- Senha: define, mantém, troca e remove.
local withPin = base()
withPin.pin = '4321'
local pinned = DoorsRules.Normalize(withPin, config, nil, salt)
eq(pinned.pin.salt, 'abcd1234', 'salt aplicado')
eq(DoorsRules.PinMatches(pinned, '4321', config), true, 'senha correta')
eq(DoorsRules.PinMatches(pinned, '4320', config), false, 'senha errada')
eq(DoorsRules.PinMatches(pinned, 4321, config), false, 'senha não-texto')
local kept = DoorsRules.Normalize(base(), config, pinned, salt)
eq(kept.pin.hash, pinned.pin.hash, 'mantém senha')
local cleared = base()
cleared.clearPin = true
eq(DoorsRules.Normalize(cleared, config, pinned, salt).pin, nil, 'remove senha')
eq(DoorsRules.Public(pinned, function() return true end)[1].hasPin, true, 'público indica senha')
eq(DoorsRules.Public(pinned, function() return true end)[1].access, nil, 'público sem regras')
eq(DoorsRules.Admin(pinned, function() return false end).pin, nil, 'admin sem hash')

-- Acesso.
local function facts(overrides)
	local result = {
		characterId = 7,
		business = function() return { member = false, onDuty = false } end,
		factionGrade = function() return nil end,
		itemCount = function() return 0 end
	}
	for key, value in pairs(overrides or {}) do
		result[key] = value
	end
	return result
end

eq(DoorsRules.CanAccess(door, facts(), config), false, 'sem acesso')
eq(select(2, DoorsRules.CanAccess(door, facts({ characterId = 42 }), config)), 'character', 'por personagem')
eq(DoorsRules.CanAccess(door, facts({ business = function() return { member = true, onDuty = false } end }), config), false, 'negócio exige ponto')
eq(select(2, DoorsRules.CanAccess(door, facts({ business = function() return { member = true, onDuty = true } end }), config)), 'business', 'negócio em serviço')
eq(DoorsRules.CanAccess(door, facts({ factionGrade = function() return 1 end }), config), false, 'grau baixo')
eq(select(2, DoorsRules.CanAccess(door, facts({ factionGrade = function() return 3 end }), config)), 'faction', 'grau suficiente')
eq(select(2, DoorsRules.CanAccess(door, facts({ itemCount = function(name) return name == 'lockpick' and 1 or 0 end }), config)), 'item', 'por item')
local keyFacts = facts({ itemCount = function(name, metadata)
	return name == config.KeyItem and metadata and metadata.door == 'pd_front' and 1 or 0
end })
eq(select(2, DoorsRules.CanAccess(door, keyFacts, config)), 'key', 'por chave da porta')
eq(DoorsRules.CanAccess(door, facts({ characterId = nil }), config), false, 'sem personagem')
local homeKey = facts({ itemCount = function(name, metadata)
	return name == config.KeyItem and metadata and metadata.door == 'casa_1' and 1 or 0
end })
eq(select(2, DoorsRules.CanAccess(home, homeKey, config)), 'key', 'uma chave abre todas as portas do local')

-- Dono, porta exclusiva e senha por porta.
local function ownedRaw()
	return {
		id = 'casa_dono', label = 'Casa', owner = { characterId = 9, name = 'Dono' },
		access = { key = true, characters = { { characterId = 42 } } },
		entries = {
			{ key = 'frente', doors = { { model = 1, x = 0, y = 0, z = 0 } } },
			{ key = 'cofre', doors = { { model = 2, x = 5, y = 0, z = 0 } }, restricted = true,
				allowed = { { characterId = 11, name = 'Bia' } }, pin = '4321' }
		}
	}
end
local owned, ownedErr = DoorsRules.Normalize(ownedRaw(), config, nil, salt)
eq(ownedErr, nil, 'local com dono válido')
eq(owned.owner.characterId, '9', 'dono como texto')
eq(DoorsRules.IsOwner(owned, 9), true, 'reconhece o dono')
eq(DoorsRules.IsOwner(owned, 42), false, 'morador não é dono')
local front, vault = owned.entries[1], owned.entries[2]
eq(front.restricted, false, 'porta comum não exclusiva')
eq(vault.restricted, true, 'porta exclusiva')
eq(vault.allowed[1].characterId, '11', 'pessoa liberada')
eq(vault.pin ~= nil and vault.pin.hash == DoorsRules.HashPin(salt(), '4321'), true, 'senha da porta em hash')
eq(select(2, DoorsRules.CanAccess(owned, facts({ characterId = 9 }), config, vault)), 'owner', 'dono abre porta exclusiva')
eq(select(2, DoorsRules.CanAccess(owned, facts({ characterId = 11 }), config, vault)), 'allowed', 'liberado abre porta exclusiva')
eq(DoorsRules.CanAccess(owned, facts({ characterId = 42 }), config, vault), false, 'morador não abre porta exclusiva')
eq(DoorsRules.CanAccess(owned, facts({ characterId = 11 }), config, front), false, 'liberado só na porta exclusiva')
eq(select(2, DoorsRules.CanAccess(owned, facts({ characterId = 42 }), config, front)), 'character', 'morador abre porta comum')
local vaultKey = facts({ itemCount = function(name, metadata)
	return name == config.KeyItem and metadata and metadata.door == 'casa_dono' and 1 or 0
end })
eq(DoorsRules.CanAccess(owned, vaultKey, config, vault), false, 'chave não abre porta exclusiva')

local kept = ownedRaw()
kept.entries[2].pin = nil
eq(DoorsRules.Normalize(kept, config, owned, salt).entries[2].pin, vault.pin, 'mantém senha da porta')
kept.entries[2].pin = { salt = 'x', hash = 'y' }
eq(DoorsRules.Normalize(kept, config, owned, salt).entries[2].pin, vault.pin, 'ignora hash vindo de fora')
kept.entries[2].pin = nil
kept.entries[2].clearPin = true
eq(DoorsRules.Normalize(kept, config, owned, salt).entries[2].pin, nil, 'remove senha da porta')

local function invalidOwned(mutate, expected)
	local raw = ownedRaw()
	mutate(raw)
	local _, code = DoorsRules.Normalize(raw, config, nil, salt)
	eq(code, expected, 'inválido ' .. expected)
end
invalidOwned(function(raw) raw.owner = { characterId = 'abc' } end, 'invalid_owner')
invalidOwned(function(raw) raw.entries[2].pin = '12' end, 'invalid_pin')
invalidOwned(function(raw) raw.entries[2].allowed[2] = { characterId = 11 } end, 'invalid_access')
invalidOwned(function(raw)
	for i = 1, config.Limits.MaxEntryCharacters + 1 do raw.entries[2].allowed[i] = { characterId = 100 + i } end
end, 'invalid_access')

local adminView = DoorsRules.Admin(owned, function() return true end)
eq(adminView.owner.characterId, '9', 'admin vê o dono')
eq(adminView.entries[2].hasPin, true, 'admin vê que a porta tem senha')
eq(adminView.entries[2].pin, nil, 'admin sem hash da porta')
local ownerView = DoorsRules.OwnerView(owned, function() return true end)
eq(ownerView.entries[2].restricted, true, 'tablet vê exclusividade')
eq(ownerView.entries[2].hasPin, true, 'tablet vê senha')
eq(ownerView.entries[2].pin, nil, 'tablet sem hash')
eq(ownerView.access, nil, 'tablet sem regras do local')
local reloaded = DoorsRules.Normalize(adminView, config, owned, salt)
eq(reloaded.entries[2].pin, vault.pin, 'salvar pela visão admin mantém a senha')
eq(reloaded.owner.characterId, '9', 'salvar pela visão admin mantém o dono')

eq(DoorsHash.ConstantTimeEquals('abc', 'abc'), true, 'constantTimeEquals igual')
eq(DoorsHash.ConstantTimeEquals('abc', 'abd'), false, 'constantTimeEquals diferente')
local grid = DoorsRules.NewSpatialGrid(32.0)
grid:insert('casa_1:frente', 0, 0, 0)
eq(#grid:queryRadius(1, 1, 0, 10), 1, 'grid espacial encontra porta')

-- Testes da Fechadura Inteligente 3-em-1 (Biometria Facial, Keycard keyEpoch, 2FA e Contingência Blackout)
local smartRaw = ownedRaw()
smartRaw.entries[2].smartLock = { enabled = true, biometric = true, keycard = true, require2FA = true, keyEpoch = 3 }
local smartPlace = DoorsRules.Normalize(smartRaw, config, nil, salt)
local smartVault = smartPlace.entries[2]
eq(smartVault.smartLock.keyEpoch, 3, 'keyEpoch preservado')

-- 1. Biometria negada por máscara (biometric_occluded)
local maskedOwner = facts({ characterId = 9 })
maskedOwner.isMasked = function() return true end
local okBioMask, reasonBioMask = DoorsRules.EvaluateSmartLock(smartPlace, smartVault, maskedOwner, config, false, 'sec')
eq(okBioMask, false, 'máscara bloqueia biometria facial')
eq(reasonBioMask, 'biometric_occluded', 'motivo biometric_occluded')

-- 2. Biometria sem máscara + exigência 2FA
local unmaskedOwner = facts({ characterId = 9 })
unmaskedOwner.isMasked = function() return false end
local okBio, viaBio, needPinBio = DoorsRules.EvaluateSmartLock(smartPlace, smartVault, unmaskedOwner, config, false, 'sec')
eq(okBio, true, 'dono sem máscara passa na biometria')
eq(viaBio, 'biometric', 'via biometric')
eq(needPinBio, true, 'exige 2FA (PIN) após biometria')

-- 3. Keycard HMAC-SHA256 válido vs revogado (keyEpoch antigo)
local validSig = DoorsRules.SignKeycard('casa_dono:cofre', 3, 'sec')
local cardHolder = facts({ characterId = 999 })
cardHolder.hasKeycard = function()
	return { doorId = 'casa_dono:cofre', keyEpoch = 3, signature = validSig }
end
local okCard, viaCard, needPinCard = DoorsRules.EvaluateSmartLock(smartPlace, smartVault, cardHolder, config, false, 'sec')
eq(okCard, true, 'portador de keycard válido autentica')
eq(viaCard, 'keycard', 'via keycard')
eq(needPinCard, true, 'keycard em sala 2FA pede PIN')

-- Keycard em Blackout: dispensa 2FA (contingência 1FA)
local okCardBlk, viaCardBlk, needPinBlk = DoorsRules.EvaluateSmartLock(smartPlace, smartVault, cardHolder, config, true, 'sec')
eq(okCardBlk, true, 'keycard abre no blackout')
eq(viaCardBlk, 'keycard_contingency', 'contingência 1FA no blackout')
eq(needPinBlk, false, 'dispensa 2FA no blackout')

-- Keycard revogado após incremento de keyEpoch (3 -> 4)
smartVault.smartLock.keyEpoch = 4
local okRevoked, reasonRevoked = DoorsRules.EvaluateSmartLock(smartPlace, smartVault, cardHolder, config, false, 'sec')
eq(okRevoked, false, 'keycard com epoch antigo é recusado')
eq(reasonRevoked, 'keycard_revoked', 'motivo keycard_revoked')

if failures > 0 then
	error(('%d falha(s)'):format(failures))
end
print('doors_test: ok')
