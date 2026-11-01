dofile('server/profile.lua')

local function eq(actual, expected, message)
	if actual ~= expected then
		error(('%s: esperado %s, recebido %s'):format(message, tostring(expected), tostring(actual)), 2)
	end
end

local function fakeQuery(failing)
	return function(sql, params)
		if failing and sql:find(failing, 1, true) then
			return nil, 'database_error'
		end
		if sql:find('FROM coe_characters WHERE character_id', 1, true) then
			if params[1] ~= '7' then return {} end
			return { { character_id = 7, player_id = 3, state_id = 'AB12CD34', first_name = 'Ana', last_name = 'Souza', gender = 'f' } }
		elseif sql:find('FROM coe_characters', 1, true) and sql:find('WHERE player_id', 1, true) then
			return { { character_id = 7, state_id = 'AB12CD34', first_name = 'Ana', last_name = 'Souza' }, { character_id = 8, state_id = 'ZZ99ZZ99', first_name = 'Bia', last_name = 'Lima', archived_at = 'x' } }
		elseif sql:find('coe_player_identifiers', 1, true) then
			return { { identifier_type = 'license', identifier_value = 'abcdef0123456789abcdef' } }
		elseif sql:find('coe_character_groups', 1, true) then
			return { { group_name = 'police', group_type = 'job', grade = 2, active = 1, label = 'Polícia' } }
		elseif sql:find('FROM coe_vehicles v', 1, true) then
			return { { vehicle_id = 1, model = 'sultan', plate = 'AAA1111', mileage_m = 12500, state = 'stored', garage_id = 'g1' } }
		elseif sql:find('coe_vehicle_keys', 1, true) then
			return { { model = 'faggio', plate = 'BBB2222' } }
		elseif sql:find('coe_housing_tenancies', 1, true) then
			return { { property_id = 'p1', unit = 2, cycle_days = 7, daily_rate = 100, paid_until = 5 } }
		elseif sql:find('coe_economy_accounts', 1, true) then
			return { { balance = 900 } }
		elseif sql:find('coe_economy_ledger', 1, true) then
			return { { delta = -50, reason = 'shop', reference = '', source_resource = 'coe_x', created_at = 'd' } }
		elseif sql:find('FROM coe_crypto_wallets', 1, true) then
			return { { address = 'nx1111111111111111111111111111', balance = 25000, created_at = 1700000000 } }
		elseif sql:find('FROM coe_crypto_tx', 1, true) then
			return { { id = 9, kind = 'buy', from_address = 'nxreserve', to_address = 'nx1111111111111111111111111111', amount = 25000, fee = 0, fiat_amount = 6500, memo = 'NoxSwap', device_key = 'phone:S1', created_at = 1700000000 } }
		elseif sql:find('coe_needs_state', 1, true) then
			return {}
		end
		return {}
	end
end

local deps = {
	query = fakeQuery(),
	inventory = function() return { slots = 3, weight = 4, maxWeight = 10, items = { { name = 'water', count = 2, metadata = {} }, false, { name = 'gun', count = 1, metadata = { serial = 'X' } } } } end,
	itemLabel = function(name) return name:upper() end,
	factions = function() return { { id = 'vagos', label = 'Vagos', grade = 1, gradeLabel = 'Líder' } } end,
	businesses = function() return {
		{ id = 'b1', label = 'Mec', category = 'mechanic', owner = { characterId = '7' }, staff = {} },
		{ id = 'b2', label = 'Bar', category = 'restaurant', staff = { { characterId = 7 } } },
		{ id = 'b3', label = 'Outro', category = 'shop', owner = { characterId = '9' }, staff = {} } } end,
	properties = function() return { { id = 'p1', label = 'Prédio' } } end,
	garages = function() return { { id = 'g1', label = 'Central' } } end,
	online = function(id) return id == '7' and { serverId = 12, ping = 40 } or nil end
}

local profile = AdminProfile.Load(deps, '7')
eq(profile.identity.name, 'Ana Souza', 'nome')
eq(profile.online.serverId, 12, 'online')
eq(#profile.account.characters, 2, 'personagens da conta')
eq(profile.account.identifiers[1].value, 'abcdef...cdef', 'identificador mascarado')
eq(profile.groups.list[1].label, 'Polícia', 'grupo')
eq(profile.factions.list[1].gradeLabel, 'Líder', 'facção')
eq(profile.inventory.used, 2, 'itens usados')
eq(profile.inventory.items[2].slot, 3, 'slot do item')
eq(profile.inventory.items[1].metadata, nil, 'metadata vazio omitido')
eq(profile.vehicles.owned[1].garage, 'Central', 'garagem do veículo')
eq(profile.vehicles.owned[1].kilometers, 12, 'km')
eq(profile.vehicles.keys[1].plate, 'BBB2222', 'chave emprestada')
eq(profile.housing.list[1].label, 'Prédio', 'imóvel')
eq(#profile.businesses.owned, 1, 'negócio como dono')
eq(#profile.businesses.staff, 1, 'negócio como funcionário')
eq(profile.economy.balance, 900, 'saldo')
eq(profile.economy.ledger[1].reference, nil, 'referência vazia omitida')
eq(profile.crypto.wallets[1].balance, 25000, 'carteira cripto do personagem')
eq(profile.crypto.tx[1].kind, 'buy', 'transação cripto do personagem')
eq(profile.needs.available, false, 'sem necessidades')

local _, notFound = AdminProfile.Load(deps, '99')
eq(notFound, 'character_not_found', 'personagem inexistente')
local _, invalid = AdminProfile.Load(deps, "7'; DROP")
eq(invalid, 'invalid_character', 'id inválido')

deps.query = fakeQuery('coe_economy_accounts')
local partial = AdminProfile.Load(deps, '7')
eq(partial.economy.error, 'database_error', 'falha isolada na economia')
eq(partial.inventory.used, 2, 'demais seções seguem')

deps.query = fakeQuery()
deps.inventory = function() error('boom') end
eq(AdminProfile.Load(deps, '7').inventory.error, 'section_failed', 'erro de seção capturado')
print('profile_test ok')
