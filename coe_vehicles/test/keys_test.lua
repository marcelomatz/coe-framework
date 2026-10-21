dofile('../coe_vehicles/config.lua')
dofile('../coe_vehicles/server/keys.lua')

local function assertEqual(actual, expected, message)
	if actual ~= expected then
		error(('%s: expected %s, got %s'):format(message, tostring(expected), tostring(actual)))
	end
end

local vehicles = {
	['1'] = { id = '1', ownerCharacterId = '10', plate = 'AAA111' },
	['2'] = { id = '2', ownerCharacterId = nil, plate = 'ESTOQUE' }
}
local stored = {}
local persistenceCalls = 0

local persistence = {
	ListKeysByCharacter = function(characterId)
		persistenceCalls = persistenceCalls + 1
		local list = {}
		for _, row in ipairs(stored) do
			if row.character == characterId then list[#list + 1] = row.vehicle end
		end
		return list
	end,
	ListKeysByVehicle = function(vehicleId)
		local list = {}
		for _, row in ipairs(stored) do
			if row.vehicle == vehicleId then list[#list + 1] = row.character end
		end
		return list
	end,
	AddKey = function(vehicleId, characterId)
		stored[#stored + 1] = { vehicle = vehicleId, character = characterId }
		return true
	end,
	RemoveKey = function(vehicleId, characterId)
		for index, row in ipairs(stored) do
			if row.vehicle == vehicleId and row.character == characterId then
				table.remove(stored, index)
				break
			end
		end
		return true
	end
}

local events = {}
local keys = VehicleKeys.New({
	persistence = persistence,
	registry = { Get = function(id) return vehicles[id], 'vehicle_not_found' end },
	config = { MaxLoanedKeysPerVehicle = 2 },
	audit = function(name) events[#events + 1] = name end
})

assertEqual(keys.HasKey('10', '1'), true, 'dono tem a chave sem registro')
assertEqual(keys.HasKey('11', '1'), false, 'outro jogador não tem')
assertEqual(keys.HasKey('x', '1'), false, 'personagem inválido')
assertEqual(keys.HasKey('10', '99'), false, 'veículo inexistente')
assertEqual(keys.HasKey('10', 1), false, 'id de tipo inválido')

assertEqual(keys.Lend('10', '1', '11'), true, 'dono empresta')
assertEqual(keys.HasKey('11', '1'), true, 'quem recebeu dirige')
assertEqual(events[#events], 'vehicle_key_granted', 'empréstimo auditado')
assertEqual(keys.Lend('10', '1', '11'), true, 'empréstimo repetido é idempotente')
assertEqual(#stored, 1, 'sem duplicata')
assertEqual(select(2, keys.Lend('11', '1', '12')), 'not_owner', 'quem recebeu não reempresta')
assertEqual(select(2, keys.Lend('10', '1', '10')), 'already_owner', 'dono não empresta a si mesmo')
assertEqual(select(2, keys.Lend('10', '1', 'abc')), 'invalid_character_id', 'alvo inválido')
assertEqual(keys.Lend('10', '1', '12'), true, 'segunda chave')
assertEqual(select(2, keys.Lend('10', '1', '13')), 'key_limit_reached', 'limite de chaves')
assertEqual(select(2, keys.Lend('10', '99', '13')), 'vehicle_not_found', 'veículo inexistente')

local before = persistenceCalls
keys.HasKey('11', '1')
keys.HasKey('11', '1')
assertEqual(persistenceCalls <= before + 1, true, 'cache por personagem')

assertEqual(select(2, keys.Take('11', '1', '12')), 'not_owner', 'só o dono retira')
assertEqual(keys.Take('10', '1', '11'), true, 'dono retira')
assertEqual(keys.HasKey('11', '1'), false, 'chave retirada some do cache')
assertEqual(events[#events], 'vehicle_key_revoked', 'retirada auditada')

assertEqual(keys.Grant('2', '14', nil), true, 'concessão direta em veículo sem dono')
assertEqual(keys.HasKey('14', '2'), true, 'chave concedida')
assertEqual(#keys.ListHolders('2'), 1, 'lista de portadores')

print('coe_vehicles keys: ok')
