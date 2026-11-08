AdminProfile = {}

local LEDGER_LIMIT = 25
local ITEM_LIMIT = 200

local function trim(value)
	return (tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

local function fullName(row)
	return trim((row.first_name or '') .. ' ' .. (row.last_name or ''))
end

local function dateText(value)
	if value == nil or value == '' then
		return nil
	end
	if type(value) == 'number' then
		return os.date('%d/%m/%Y %H:%M', math.floor(value / 1000))
	end
	return tostring(value)
end

local function maskIdentifier(value)
	value = tostring(value or '')
	if #value <= 10 then
		return value
	end
	return value:sub(1, 6) .. '...' .. value:sub(-4)
end

-- Perfil somente leitura de um personagem. Cada seção é carregada de forma isolada:
-- uma fonte indisponível devolve { error = codigo } e não impede as demais.
-- deps: query(sql, params) -> linhas|nil,erro; inventory(characterId) -> snapshot|nil;
-- itemLabel(nome) -> texto; factions(characterId) -> lista; businesses(), properties(), doors(), garages() -> listas;
-- online(characterId) -> { serverId, ping }|nil.
function AdminProfile.Load(deps, characterId)
	local id = tostring(characterId or '')
	if not id:match('^%d+$') then
		return nil, 'invalid_character'
	end

	local rows, queryError = deps.query([[
		SELECT character_id, player_id, state_id, first_name, last_name, birth_date, gender,
			created_at, updated_at, archived_at
		FROM coe_characters WHERE character_id = ? LIMIT 1
	]], { id })
	if not rows then
		return nil, queryError or 'database_error'
	end
	local row = rows[1]
	if not row then
		return nil, 'character_not_found'
	end

	local profile = {
		characterId = id,
		identity = {
			name = fullName(row),
			stateId = row.state_id,
			birthDate = dateText(row.birth_date),
			gender = row.gender,
			createdAt = dateText(row.created_at),
			updatedAt = dateText(row.updated_at),
			archived = row.archived_at ~= nil and row.archived_at ~= ''
		}
	}

	local online = deps.online and deps.online(id) or nil
	profile.online = online and { serverId = online.serverId, ping = online.ping } or nil

	local function section(name, loader)
		local ok, value, errorCode = pcall(loader)
		if not ok then
			profile[name] = { error = 'section_failed' }
		elseif value == nil then
			profile[name] = { error = errorCode or 'database_error' }
		else
			profile[name] = value
		end
	end

	section('account', function()
		local owner = row.player_id
		local siblings, siblingsError = deps.query([[
			SELECT character_id, state_id, first_name, last_name, archived_at FROM coe_characters
			WHERE player_id = ? ORDER BY character_id LIMIT 10
		]], { owner })
		if not siblings then
			return nil, siblingsError
		end
		local identifiers = deps.query(
			'SELECT identifier_type, identifier_value FROM coe_player_identifiers WHERE player_id = ? ORDER BY identifier_type LIMIT 20',
			{ owner }) or {}
		local account = { playerId = tostring(owner), characters = {}, identifiers = {} }
		for _, sibling in ipairs(siblings) do
			account.characters[#account.characters + 1] = {
				characterId = tostring(sibling.character_id),
				stateId = sibling.state_id,
				name = fullName(sibling),
				archived = sibling.archived_at ~= nil and sibling.archived_at ~= '',
				current = tostring(sibling.character_id) == id
			}
		end
		for _, identifier in ipairs(identifiers) do
			account.identifiers[#account.identifiers + 1] = {
				type = identifier.identifier_type,
				value = maskIdentifier(identifier.identifier_value)
			}
		end
		return account
	end)

	section('groups', function()
		local groups, groupsError = deps.query([[
			SELECT cg.group_name, cg.group_type, cg.grade, cg.active, g.label
			FROM coe_character_groups cg LEFT JOIN coe_groups g ON g.name = cg.group_name
			WHERE cg.character_id = ? ORDER BY cg.group_type, cg.group_name
		]], { id })
		if not groups then
			return nil, groupsError
		end
		local list = {}
		for _, group in ipairs(groups) do
			list[#list + 1] = {
				name = group.group_name,
				label = group.label or group.group_name,
				type = group.group_type,
				grade = tonumber(group.grade) or 0,
				active = group.active == 1 or group.active == true
			}
		end
		return { list = list }
	end)

	section('factions', function()
		local list = deps.factions and deps.factions(id)
		if type(list) ~= 'table' then
			return nil, 'unavailable'
		end
		return { list = list }
	end)

	section('inventory', function()
		if not deps.inventory then
			return nil, 'unavailable'
		end
		local snapshot = deps.inventory(id)
		if not snapshot then
			return nil, 'inventory_not_found'
		end
		local items, total = {}, 0
		for slot = 1, tonumber(snapshot.slots) or 0 do
			local item = snapshot.items and snapshot.items[slot]
			if item then
				total = total + 1
				if #items < ITEM_LIMIT then
					items[#items + 1] = {
						slot = slot,
						name = item.name,
						label = deps.itemLabel and deps.itemLabel(item.name) or item.name,
						count = item.count,
						metadata = type(item.metadata) == 'table' and next(item.metadata) ~= nil and item.metadata or nil
					}
				end
			end
		end
		return { slots = snapshot.slots, used = total, weight = snapshot.weight, maxWeight = snapshot.maxWeight, items = items }
	end)

	section('vehicles', function()
		local owned, ownedError = deps.query([[
			SELECT v.vehicle_id, v.model, v.plate, v.mileage_m, v.state, s.garage_id
			FROM coe_vehicles v LEFT JOIN coe_garage_slots s ON s.vehicle_id = v.vehicle_id
			WHERE v.owner_character_id = ? ORDER BY v.vehicle_id LIMIT 100
		]], { id })
		if not owned then
			return nil, ownedError
		end
		local labels = {}
		for _, garage in ipairs(deps.garages and deps.garages() or {}) do
			labels[tostring(garage.id)] = garage.label or garage.id
		end
		local result = { owned = {}, keys = {} }
		for _, vehicle in ipairs(owned) do
			result.owned[#result.owned + 1] = {
				vehicleId = tostring(vehicle.vehicle_id),
				model = vehicle.model,
				plate = vehicle.plate,
				kilometers = math.floor((tonumber(vehicle.mileage_m) or 0) / 1000),
				state = vehicle.state,
				garage = vehicle.garage_id and (labels[tostring(vehicle.garage_id)] or tostring(vehicle.garage_id)) or nil
			}
		end
		local keys = deps.query([[
			SELECT v.model, v.plate FROM coe_vehicle_keys k JOIN coe_vehicles v ON v.vehicle_id = k.vehicle_id
			WHERE k.character_id = ? AND (v.owner_character_id IS NULL OR v.owner_character_id <> ?) LIMIT 50
		]], { id, id }) or {}
		for _, key in ipairs(keys) do
			result.keys[#result.keys + 1] = { model = key.model, plate = key.plate }
		end
		return result
	end)

	section('housing', function()
		local tenancies, tenancyError = deps.query([[
			SELECT property_id, unit, cycle_days, daily_rate, paid_until FROM coe_housing_tenancies
			WHERE character_id = ? ORDER BY property_id, unit LIMIT 50
		]], { id })
		if not tenancies then
			return nil, tenancyError
		end
		local propsById = {}
		local allProps = deps.properties and deps.properties() or {}
		local labels = {}
		for _, property in ipairs(allProps) do
			labels[tostring(property.id)] = property.label or property.id
			propsById[tostring(property.id)] = property
		end
		local list = {}
		for _, tenancy in ipairs(tenancies) do
			local pid = tostring(tenancy.property_id)
			local prop = propsById[pid]
			local cycleDays = tonumber(tenancy.cycle_days) or 0
			local dailyRate = tonumber(tenancy.daily_rate) or 0
			local isStarter = (cycleDays == 0 and dailyRate == 0)
			local modality = isStarter and 'starter' or 'rented'
			local modalityLabel = isStarter and 'CEDIDO (INICIAL)' or 'ALUGADO'
			list[#list + 1] = {
				propertyId = tenancy.property_id,
				label = labels[pid] or tenancy.property_id,
				kind = prop and prop.kind or 'apartment',
				modality = modality,
				modalityLabel = modalityLabel,
				unit = tonumber(tenancy.unit),
				cycleDays = cycleDays,
				dailyRate = dailyRate,
				paidUntil = tonumber(tenancy.paid_until) or 0
			}
		end

		-- Imóveis Comprados (Dono) ou Cedidos (Chave/Membro) no coe_housing (casas, esconderijos, comerciais)
		for _, property in ipairs(allProps) do
			local pid = tostring(property.id)
			if type(property.owner) == 'table' and tostring(property.owner.characterId) == id then
				list[#list + 1] = {
					propertyId = pid,
					label = property.label or pid,
					kind = property.kind or 'house',
					modality = 'owned',
					modalityLabel = 'COMPRADO (PROPRIETÁRIO)',
					unit = 1,
					cycleDays = 0,
					dailyRate = 0,
					paidUntil = 0
				}
			else
				for _, member in ipairs(property.members or {}) do
					if tostring(member.characterId) == id then
						list[#list + 1] = {
							propertyId = pid,
							label = property.label or pid,
							kind = property.kind or 'house',
							modality = 'shared',
							modalityLabel = 'CEDIDO (CHAVE / MEMBRO)',
							unit = 1,
							cycleDays = 0,
							dailyRate = 0,
							paidUntil = 0
						}
						break
					end
				end
			end
		end

		-- Imóveis de Portas (coe_doors: casas mapeadas, mansões, sedes)
		for _, place in ipairs(deps.doors and deps.doors() or {}) do
			local pid = tostring(place.id)
			if type(place.owner) == 'table' and tostring(place.owner.characterId) == id then
				list[#list + 1] = {
					propertyId = pid,
					label = place.label or pid,
					kind = 'door_place',
					modality = 'owned',
					modalityLabel = 'COMPRADO (IMÓVEL MLO)',
					unit = 1,
					cycleDays = 0,
					dailyRate = 0,
					paidUntil = 0
				}
			else
				for _, res in ipairs(place.residents or {}) do
					if tostring(res.characterId) == id then
						list[#list + 1] = {
							propertyId = pid,
							label = place.label or pid,
							kind = 'door_place',
							modality = 'shared',
							modalityLabel = 'CEDIDO (MORADOR MLO)',
							unit = 1,
							cycleDays = 0,
							dailyRate = 0,
							paidUntil = 0
						}
						break
					end
				end
			end
		end

		-- Imóveis Comerciais vinculados aos negócios do personagem (coe_housing_leases)
		local myBizLabels = {}
		local hasBiz = false
		for _, business in ipairs(deps.businesses and deps.businesses() or {}) do
			local isMyBiz = (type(business.owner) == 'table' and tostring(business.owner.characterId) == id)
			if not isMyBiz then
				for _, partner in ipairs(business.partners or {}) do
					if tostring(partner.characterId) == id then isMyBiz = true; break end
				end
			end
			if not isMyBiz then
				for _, member in ipairs(business.staff or {}) do
					if tostring(member.characterId) == id then isMyBiz = true; break end
				end
			end
			if isMyBiz then
				hasBiz = true
				myBizLabels[tostring(business.id)] = business.label or business.id
			end
		end
		if hasBiz then
			local leases = deps.query([[
				SELECT property_id, unit, business_id, cycle_days, daily_rate, paid_until
				FROM coe_housing_leases ORDER BY property_id, unit LIMIT 50
			]], {}) or {}
			for _, lease in ipairs(leases) do
				local bid = tostring(lease.business_id or '')
				if myBizLabels[bid] then
					local pid = tostring(lease.property_id)
					local cycleDays = tonumber(lease.cycle_days) or 0
					local dailyRate = tonumber(lease.daily_rate) or 0
					list[#list + 1] = {
						propertyId = pid,
						label = (labels[pid] or pid) .. ' (' .. myBizLabels[bid] .. ')',
						kind = 'commercial',
						modality = cycleDays == 0 and 'starter' or 'rented',
						modalityLabel = cycleDays == 0 and 'CEDIDO (SEDE COMERCIAL)' or 'ALUGADO (COMERCIAL)',
						unit = tonumber(lease.unit),
						cycleDays = cycleDays,
						dailyRate = dailyRate,
						paidUntil = tonumber(lease.paid_until) or 0
					}
				end
			end
		end

		local counts = { owned = 0, rented = 0, granted = 0, total = #list }
		for _, item in ipairs(list) do
			if item.modality == 'owned' then counts.owned = counts.owned + 1
			elseif item.modality == 'rented' then counts.rented = counts.rented + 1
			else counts.granted = counts.granted + 1 end
		end
		return { list = list, counts = counts }
	end)

	section('businesses', function()
		local result = { owned = {}, partners = {}, staff = {}, all = {} }
		for _, business in ipairs(deps.businesses and deps.businesses() or {}) do
			local gradesById = {}
			for _, g in ipairs(business.grades or {}) do
				gradesById[tostring(g.id)] = g
			end
			local isOwner = type(business.owner) == 'table' and tostring(business.owner.characterId) == id
			if isOwner then
				local entry = {
					id = business.id,
					label = business.label,
					category = business.category,
					role = 'Proprietário',
					gradeLabel = 'Dono / Titular',
					salary = 0
				}
				result.owned[#result.owned + 1] = entry
				result.all[#result.all + 1] = entry
			end
			for _, partner in ipairs(business.partners or {}) do
				if tostring(partner.characterId) == id then
					local entry = {
						id = business.id,
						label = business.label,
						category = business.category,
						role = 'Sócio',
						gradeLabel = 'Sócio Cotista',
						salary = 0
					}
					result.partners[#result.partners + 1] = entry
					result.all[#result.all + 1] = entry
					break
				end
			end
			for _, member in ipairs(business.staff or {}) do
				if tostring(member.characterId) == id then
					local gInfo = member.grade and gradesById[tostring(member.grade)] or nil
					local entry = {
						id = business.id,
						label = business.label,
						category = business.category,
						role = 'Equipe',
						grade = member.grade,
						gradeLabel = (gInfo and gInfo.label) or member.grade or 'Funcionário',
						salary = (gInfo and tonumber(gInfo.salary)) or 0
					}
					result.staff[#result.staff + 1] = entry
					result.all[#result.all + 1] = entry
					break
				end
			end
		end
		return result
	end)

	section('economy', function()
		local account, accountError = deps.query('SELECT balance FROM coe_economy_accounts WHERE character_id = ? LIMIT 1', { id })
		if not account then
			return nil, accountError
		end
		local ledger = deps.query(
			'SELECT delta, reason, reference, source_resource, created_at FROM coe_economy_ledger WHERE character_id = ? ORDER BY id DESC LIMIT '
				.. LEDGER_LIMIT, { id }) or {}
		local entries = {}
		for _, entry in ipairs(ledger) do
			entries[#entries + 1] = {
				delta = tonumber(entry.delta) or 0,
				reason = entry.reason,
				reference = entry.reference ~= '' and entry.reference or nil,
				source = entry.source_resource,
				at = dateText(entry.created_at)
			}
		end
		return { balance = account[1] and tonumber(account[1].balance) or nil, ledger = entries }
	end)

	section('crypto', function()
		local created, createdError = deps.query([[
			SELECT address, balance, created_at FROM coe_crypto_wallets
			WHERE created_by = ? ORDER BY balance DESC, created_at DESC LIMIT 25
		]], { id })
		if not created then
			return nil, createdError
		end
		local keystore = deps.query([[
			SELECT k.device_key, k.address, k.label, w.balance
			FROM coe_crypto_keystore k
			LEFT JOIN coe_crypto_wallets w ON w.address = k.address
			WHERE k.device_key = ? ORDER BY k.added_at DESC LIMIT 25
		]], { 'tablet:' .. id }) or {}
		local txRows = deps.query([[
			SELECT id, kind, from_address, to_address, amount, fee, fiat, memo, device_key, created_at
			FROM coe_crypto_tx WHERE character_id = ? ORDER BY id DESC LIMIT 25
		]], { id }) or {}
		local wallets, seen = {}, {}
		for _, entry in ipairs(keystore) do
			seen[entry.address] = true
			wallets[#wallets + 1] = {
				address = entry.address,
				label = entry.label ~= '' and entry.label or nil,
				source = entry.device_key,
				balance = tonumber(entry.balance) or 0
			}
		end
		for _, walletRow in ipairs(created) do
			if not seen[walletRow.address] then
				local epoch = tonumber(walletRow.created_at)
				wallets[#wallets + 1] = {
					address = walletRow.address,
					source = 'criada pelo personagem',
					balance = tonumber(walletRow.balance) or 0,
					at = epoch and epoch > 0 and os.date('%d/%m/%Y %H:%M', epoch) or nil
				}
			end
		end
		local tx = {}
		for _, txRow in ipairs(txRows) do
			local epoch = tonumber(txRow.created_at)
			tx[#tx + 1] = {
				id = tonumber(txRow.id) or 0,
				kind = txRow.kind,
				from = txRow.from_address,
				to = txRow.to_address,
				amount = tonumber(txRow.amount) or 0,
				fee = tonumber(txRow.fee) or 0,
				fiat = (txRow.fiat or txRow.fiat_amount) and tonumber(txRow.fiat or txRow.fiat_amount) or nil,
				memo = txRow.memo ~= '' and txRow.memo or nil,
				device = txRow.device_key,
				at = epoch and epoch > 0 and os.date('%d/%m/%Y %H:%M', epoch) or dateText(txRow.created_at)
			}
		end
		return { wallets = wallets, tx = tx }
	end)

	section('needs', function()
		local needs, needsError = deps.query('SELECT hunger, thirst, stress FROM coe_needs_state WHERE character_id = ? LIMIT 1', { id })
		if not needs then
			return nil, needsError
		end
		local state = needs[1]
		if not state then
			return { available = false }
		end
		return {
			available = true,
			hunger = math.floor((tonumber(state.hunger) or 0) + 0.5),
			thirst = math.floor((tonumber(state.thirst) or 0) + 0.5),
			stress = math.floor((tonumber(state.stress) or 0) + 0.5)
		}
	end)

	return profile
end
