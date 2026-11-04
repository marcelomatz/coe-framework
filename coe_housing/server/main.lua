local config = HousingConfig
local ready = false
local DAY = 86400

local properties = {}
local tenancies = {}
local lastAction = {}
local inside = {}
local locked = {}
local warned = {}
-- Contratos comerciais (inquilino = negócio, pago pelo caixa da sociedade).
local leases = {}
local leaseWarned = {}
-- Admins visitando interiores do catálogo (mundo próprio, fora de qualquer contrato).
local previewing = {}

local function log(level, category, event, context)
	pcall(function()
		return exports.coe_logging:Log(level, category, event, context)
	end)
end

local function audit(event, context)
	pcall(function()
		return exports.coe_audit:Record('info', 'audit', event, context)
	end)
end

local function notify(playerId, kind, message)
	pcall(function()
		exports.coe_notify:Notify(playerId, kind, message)
	end)
end

local _t = (Core and Core.Locale and Core.Locale.Bind) and Core.Locale.Bind(Locales) or function(k) return (Locales and Locales['pt-BR'] and Locales['pt-BR'][k]) or k end

local MESSAGES = {
	not_ready = 'err_not_ready', no_property = 'err_no_property', too_far = 'err_too_far',
	not_rentable = 'err_not_rentable', invalid_cycle = 'err_invalid_cycle',
	already_tenant = 'err_already_tenant', tenancy_limit = 'err_tenancy_limit',
	no_vacancy = 'err_no_vacancy', insufficient_funds = 'err_insufficient_funds', no_tenancy = 'err_no_tenancy',
	overdue = 'err_overdue', starter_locked = 'err_starter_locked',
	busy = 'err_busy', database_error = 'err_database_error', economy_unavailable = 'err_economy_unavailable',
	no_duty = 'err_no_duty', not_allowed = 'err_not_allowed',
	already_leased = 'err_already_leased', lease_limit = 'err_lease_limit',
	no_lease = 'err_no_lease', granted_locked = 'err_granted_locked',
	society_funds = 'err_society_funds', no_stash = 'err_no_stash',
	stash_unavailable = 'err_stash_unavailable'
}

local function fail(playerId, errorCode)
	TriggerClientEvent('coe_housing:failed', playerId, errorCode)
	local msgKey = MESSAGES[errorCode]
	notify(playerId, 'error', msgKey and _t(msgKey) or _t('generic_error'))
end

local function throttled(playerId)
	local now = GetGameTimer()
	if lastAction[playerId] and now - lastAction[playerId] < config.Limits.ActionIntervalMs then
		return true
	end
	lastAction[playerId] = now
	return false
end

local function bucketOf(entry, isLease)
	return (isLease and config.CommercialBucketBase or config.BucketBase) + entry.id
end

-- Exports de outros resources; nil se o resource não está de pé ou falhou.
local function remote(resource, name, ...)
	if GetResourceState(resource) ~= 'started' then
		return nil
	end
	local args = { ... }
	local ok, result = pcall(function()
		return exports[resource][name](exports[resource], table.unpack(args))
	end)
	return ok and result or nil
end

local function isMember(businessId, characterId)
	local access = remote('coe_businesses', 'Access', businessId, characterId)
	return type(access) == 'table' and (access.owner or access.staff) == true
end

local function canFunds(businessId, characterId)
	return remote('coe_businesses', 'Can', businessId, characterId, 'business.funds') == true
end

local function businessLabel(businessId)
	local business = remote('coe_businesses', 'Get', businessId)
	return type(business) == 'table' and business.label or businessId
end

local function societyBalance(businessId)
	local balance = remote('coe_economy', 'SocietyBalance', businessId)
	return type(balance) == 'number' and balance or nil
end

-- Avisa quem está de ponto no negócio (ex.: aluguel comercial vencido).
local function notifyBusiness(businessId, kind, message)
	for _, playerId in ipairs(GetPlayers()) do
		playerId = tonumber(playerId)
		if remote('coe_businesses', 'CurrentDuty', playerId) == businessId then
			notify(playerId, kind, message)
		end
	end
end

local function actor(playerId)
	local characterId = Core.Players.GetActiveCharacterId(playerId)
	local ped = GetPlayerPed(playerId)
	if not characterId or not ped or ped == 0 then
		return nil
	end
	return { characterId = tostring(characterId), at = Core.Platform.Entities.GetCoords(ped) }
end

local function playerOf(characterId)
	for _, playerId in ipairs(GetPlayers()) do
		local id = Core.Players.GetActiveCharacterId(tonumber(playerId))
		if id and tostring(id) == characterId then
			return tonumber(playerId)
		end
	end
	return nil
end

local function within(at, point, extra)
	return #(at - vector3(point.x, point.y, point.z)) <= point.radius + extra
end

local function tenancyOf(characterId, propertyId)
	for _, tenancy in pairs(tenancies) do
		if tenancy.characterId == characterId and tenancy.propertyId == propertyId then
			return tenancy
		end
	end
	return nil
end

local function tenancyCount(characterId)
	local count = 0
	for _, tenancy in pairs(tenancies) do
		if tenancy.characterId == characterId then
			count = count + 1
		end
	end
	return count
end

local function usedUnits(propertyId)
	local used, count = {}, 0
	for _, list in ipairs({ tenancies, leases }) do
		for _, entry in pairs(list) do
			if entry.propertyId == propertyId then
				used[entry.unit] = true
				count = count + 1
			end
		end
	end
	return used, count
end

local function leaseOf(businessId, propertyId)
	for _, lease in pairs(leases) do
		if lease.businessId == businessId and lease.propertyId == propertyId then
			return lease
		end
	end
	return nil
end

-- Só os alugados contam; os cedidos pelo admin ficam fora do limite.
local function leaseCount(businessId)
	local count = 0
	for _, lease in pairs(leases) do
		if lease.businessId == businessId and lease.cycleDays > 0 then
			count = count + 1
		end
	end
	return count
end

-- Contrato comercial deste imóvel de algum negócio do qual o personagem é dono ou equipe.
local function memberLease(characterId, propertyId)
	for _, lease in pairs(leases) do
		if lease.propertyId == propertyId and isMember(lease.businessId, characterId) then
			return lease
		end
	end
	return nil
end

local function rebuild()
	properties = {}
	for _, property in ipairs(HousingPersistence.ListProperties() or {}) do
		properties[property.id] = property
	end
	tenancies = {}
	for _, tenancy in ipairs(HousingPersistence.ListTenancies() or {}) do
		tenancies[tenancy.id] = tenancy
	end
	leases = {}
	for _, lease in ipairs(HousingPersistence.ListLeases() or {}) do
		leases[lease.id] = lease
	end
end

local function sorted()
	local list = {}
	for _, property in pairs(properties) do
		list[#list + 1] = property
	end
	table.sort(list, function(a, b) return a.id < b.id end)
	return list
end

-- Só a porta e o blip vão para o cliente; o interior só é enviado a quem entra.
-- Imóveis ilegais só aparecem para o dono e os membros, e nunca com blip.
local function doorList(characterId)
	local list = {}
	for _, property in ipairs(sorted()) do
		local hideout = property.kind == 'hideout'
		if property.enabled and (not hideout or HousingRegistry.HasAccess(property, characterId)) then
			list[#list + 1] = {
				id = property.id, kind = property.kind, title = property.label, hideout = hideout or nil,
				x = property.door.x, y = property.door.y, z = property.door.z, radius = property.door.radius,
				blip = not hideout and property.blip and property.blip.enabled and property.blip or nil
			}
		end
	end
	return list
end

local function sendDoors(playerId)
	TriggerClientEvent('coe_housing:doors', playerId, doorList(Core.Players.GetActiveCharacterId(playerId)))
end

local function broadcast()
	for _, playerId in ipairs(GetPlayers()) do
		sendDoors(tonumber(playerId))
	end
end

RegisterNetEvent('coe_housing:requestDoors', function()
	if ready then
		sendDoors(source)
	end
end)

local function balanceOf(characterId)
	local ok, balance = pcall(function()
		return exports.coe_economy:GetBalance(characterId)
	end)
	return ok and balance or nil
end

local function rentOffer(property)
	local _, count = usedUnits(property.id)
	local rent = { daily = property.rent.daily, vacancies = property.units - count, cycles = {} }
	for _, days in ipairs(property.rent.cycles) do
		rent.cycles[#rent.cycles + 1] = { days = days, total = HousingRules.Total(property.rent.daily, days) }
	end
	return rent
end

local function contractView(entry)
	return {
		unit = entry.unit, cycleDays = entry.cycleDays, dailyRate = entry.dailyRate,
		paidUntil = entry.paidUntil, overdue = HousingRules.State(entry, os.time(), config) ~= 'ok', starter = entry.cycleDays == 0
	}
end

-- Comercial: quem é do negócio inquilino entra; quem está de ponto com business.funds aluga para o negócio de ponto.
local function commercialMenu(playerId, who, property, menu)
	menu.commercial = true
	local lease = memberLease(who.characterId, property.id)
	if lease then
		local funds = canFunds(lease.businessId, who.characterId)
		menu.payer = businessLabel(lease.businessId)
		menu.balance = funds and societyBalance(lease.businessId) or nil
		menu.tenancy = contractView(lease)
		menu.canCancel = funds and lease.cycleDays > 0
		return menu
	end
	if not property.rent or property.businessId then
		return menu
	end
	local businessId = remote('coe_businesses', 'CurrentDuty', playerId)
	if not businessId then
		menu.hint = 'Bata o ponto no seu negócio para alugar este imóvel.'
	elseif not canFunds(businessId, who.characterId) then
		menu.hint = 'Seu cargo não pode movimentar o caixa do negócio.'
	else
		menu.payer = businessLabel(businessId)
		menu.balance = societyBalance(businessId)
		menu.rent = rentOffer(property)
	end
	return menu
end

local function menuFor(playerId, who, property)
	local menu = { propertyId = property.id, title = property.label, subtitle = config.Kinds[property.kind] }
	if property.kind == 'commercial' then
		return commercialMenu(playerId, who, property, menu)
	end
	menu.balance = balanceOf(who.characterId)
	local tenancy = tenancyOf(who.characterId, property.id)
	if tenancy then
		menu.tenancy = contractView(tenancy)
	elseif property.rent then
		menu.rent = rentOffer(property)
	end
	return menu
end

local function sendMenu(playerId, who, property)
	TriggerClientEvent('coe_housing:menu', playerId, menuFor(playerId, who, property))
end

-- Marcado como dentro, mas o ped está na porta, longe do interior (o teleporte de volta falhou):
-- a presença é desfeita para o jogador poder entrar de novo.
local function clearStalePresence(playerId, who, property)
	local state = inside[playerId]
	if not state or previewing[playerId] or not within(who.at, property.door, 3.0) then
		return
	end
	local current = properties[state.propertyId]
	if current and current.interior and within(who.at, current.interior, 30.0) then
		return
	end
	inside[playerId] = nil
	HousingPersistence.ClearPresence(state.characterId)
	Core.Platform.Routing.SetPlayerBucket(playerId, 0)
	TriggerClientEvent('coe_housing:left', playerId, nil)
	audit('housing_presence_recovered', { operation = state.propertyId, character_id = state.characterId })
end

local function propertyAt(playerId, propertyId)
	if not ready or type(propertyId) ~= 'string' then
		return nil, nil, 'not_ready'
	end
	local property = properties[propertyId]
	if not property or not property.enabled then
		return nil, nil, 'no_property'
	end
	local who = actor(playerId)
	if not who then
		return nil, nil, 'no_property'
	end
	clearStalePresence(playerId, who, property)
	if inside[playerId] or not within(who.at, property.door, 3.0) then
		return nil, nil, 'too_far'
	end
	return property, who
end

-- O que o cliente precisa saber dentro do imóvel: interior, saída e baú.
local function enteredInfo(property)
	local stash = property.stash
	return {
		propertyId = property.id, title = property.label, interior = property.interior, interiorId = property.interiorId,
		stash = stash and { x = stash.x, y = stash.y, z = stash.z, radius = stash.radius } or nil
	}
end

-- Imóvel ilegal: um mundo compartilhado por imóvel; quem não tem acesso recebe a mesma resposta de imóvel inexistente.
local function hideoutBucket(property)
	return config.HideoutBucketBase + (property.world or 0)
end

local function placeInHideout(playerId, characterId, property)
	inside[playerId] = { hideout = true, propertyId = property.id, characterId = characterId }
	local bucket = hideoutBucket(property)
	Core.Platform.Routing.SetPlayerBucket(playerId, bucket)
	Core.Platform.Routing.SetPopulationEnabled(bucket, false)
	TriggerClientEvent('coe_housing:entered', playerId, enteredInfo(property))
end

local function enterHideout(playerId, who, property)
	if not property.world or not HousingRegistry.HasAccess(property, who.characterId) then
		return fail(playerId, 'no_property')
	end
	HousingPersistence.SetPresence(who.characterId, 0, property.id, false)
	placeInHideout(playerId, who.characterId, property)
	audit('housing_hideout_entered', { operation = property.id, character_id = who.characterId })
end

RegisterNetEvent('coe_housing:open', function(propertyId)
	local playerId = source
	if throttled(playerId) then
		return
	end
	local property, who, errorCode = propertyAt(playerId, propertyId)
	if not property then
		return fail(playerId, errorCode)
	end
	if property.kind == 'hideout' then
		return enterHideout(playerId, who, property)
	end
	sendMenu(playerId, who, property)
end)

RegisterNetEvent('coe_housing:enter', function(propertyId)
	local playerId = source
	if throttled(playerId) then
		return
	end
	local property, who, errorCode = propertyAt(playerId, propertyId)
	if not property then
		return fail(playerId, errorCode)
	end
	if property.kind == 'hideout' then
		return enterHideout(playerId, who, property)
	end
	local isLease = property.kind == 'commercial'
	local entry
	if isLease then
		entry = memberLease(who.characterId, property.id)
	else
		entry = tenancyOf(who.characterId, property.id)
	end
	if not entry then
		return fail(playerId, isLease and 'no_lease' or 'no_tenancy')
	end
	if HousingRules.State(entry, os.time(), config) ~= 'ok' then
		return fail(playerId, 'overdue')
	end
	inside[playerId] = {
		tenancyId = not isLease and entry.id or nil, leaseId = isLease and entry.id or nil,
		propertyId = property.id, characterId = who.characterId
	}
	HousingPersistence.SetPresence(who.characterId, entry.id, property.id, isLease)
	Core.Platform.Routing.SetPlayerBucket(playerId, bucketOf(entry, isLease))
	Core.Platform.Routing.SetPopulationEnabled(bucketOf(entry, isLease), false)
	TriggerClientEvent('coe_housing:entered', playerId, enteredInfo(property))
	audit('housing_entered', { operation = property.id, character_id = who.characterId })
end)

local function exitPlayer(playerId)
	local state = inside[playerId]
	if not state then
		return
	end
	inside[playerId] = nil
	HousingPersistence.ClearPresence(state.characterId)
	local property = properties[state.propertyId]
	local door = property and property.door or nil
	-- Admin visitando outro interior: continua no mundo isolado; ao fim da visita vai para a porta.
	local preview = previewing[playerId]
	if preview then
		preview.bucket = 0
		preview.door = door
		return
	end
	Core.Platform.Routing.SetPlayerBucket(playerId, 0)
	TriggerClientEvent('coe_housing:left', playerId, door)
end

-- Tira de um imóvel ilegal quem perdeu o acesso (membro removido, imóvel desativado ou trocado de tipo).
local function expelWithoutAccess(propertyId)
	local property = properties[propertyId]
	for playerId, state in pairs(inside) do
		if state.hideout and state.propertyId == propertyId
			and not (property and property.enabled and HousingRegistry.HasAccess(property, state.characterId)) then
			exitPlayer(playerId)
			notify(playerId, 'warning', _t('lost_access'))
		end
	end
end

RegisterNetEvent('coe_housing:leave', function()
	local playerId = source
	local state = inside[playerId]
	if not state or throttled(playerId) then
		return
	end
	local property = properties[state.propertyId]
	local who = actor(playerId)
	if property and who and not within(who.at, property.interior, 5.0) then
		return fail(playerId, 'too_far')
	end
	exitPlayer(playerId)
end)

-- Dono do espaço em que o jogador está: 'c<personagem>' (moradia), 'b<negócio>' (comercial) ou 'shared' (ilegal).
-- Separa o baú e as entregas de cada morador ou negócio dentro do mesmo imóvel.
local function spaceOwner(state, property, characterId)
	if state.hideout then
		if not HousingRegistry.HasAccess(property, characterId) then
			return nil, 'no_property'
		end
		return 'shared'
	end
	if state.leaseId then
		local lease = leases[state.leaseId]
		if not lease or not isMember(lease.businessId, characterId) then
			return nil, 'no_lease'
		end
		return 'b' .. lease.businessId
	end
	local tenancy = tenancies[state.tenancyId]
	if not tenancy or tenancy.characterId ~= characterId then
		return nil, 'no_tenancy'
	end
	return 'c' .. characterId
end

-- Baú do imóvel: um por morador (personagem) ou, em comerciais, um por negócio. O conteúdo fica
-- preso ao imóvel, não ao contrato: quem volta a alugar o mesmo imóvel reencontra o que guardou.
RegisterNetEvent('coe_housing:openStash', function()
	local playerId = source
	local state = inside[playerId]
	if not state or throttled(playerId) then
		return
	end
	local property = properties[state.propertyId]
	local stash = property and property.stash
	local who = actor(playerId)
	if not stash or not who then
		return fail(playerId, 'no_stash')
	end
	if not within(who.at, stash, 1.5) then
		return fail(playerId, 'too_far')
	end
	local owner, ownerError = spaceOwner(state, property, who.characterId)
	if not owner then
		return fail(playerId, ownerError)
	end
	local ok, opened, openError = pcall(function()
		return exports.coe_inventory:OpenStash(playerId, ('stash:housing:%s:%s'):format(property.id, owner), {
			label = ('Baú · %s'):format(property.label),
			slots = stash.slots,
			maxWeight = stash.maxWeight,
			position = { x = stash.x, y = stash.y, z = stash.z },
			radius = stash.radius + 1.0
		})
	end)
	if not ok or opened ~= true then
		return fail(playerId, 'stash_unavailable')
	end
	audit('housing_stash_opened', { operation = property.id, character_id = who.characterId })
end)

local function evict(tenancy, reason)
	local removed = HousingPersistence.DeleteTenancy(tenancy.id)
	if not removed then
		return false
	end
	tenancies[tenancy.id] = nil
	warned[tenancy.id] = nil
	local playerId = playerOf(tenancy.characterId)
	if playerId then
		if inside[playerId] and inside[playerId].tenancyId == tenancy.id then
			exitPlayer(playerId)
		end
		if reason == 'expired' then
			notify(playerId, 'warning', _t('lease_expired'))
		elseif reason == 'admin' then
			notify(playerId, 'warning', _t('lease_admin_ended'))
		end
	end
	audit('housing_ended', { operation = tenancy.propertyId, character_id = tenancy.characterId, action = reason })
	return true
end

-- Encerra um contrato comercial e tira quem estiver dentro dele.
local function endLease(lease, reason)
	local removed = HousingPersistence.DeleteLease(lease.id)
	if not removed then
		return false
	end
	leases[lease.id] = nil
	leaseWarned[lease.id] = nil
	for playerId, state in pairs(inside) do
		if state.leaseId == lease.id then
			exitPlayer(playerId)
		end
	end
	if reason == 'expired' then
		notifyBusiness(lease.businessId, 'warning', _t('business_lease_expired'))
	elseif reason == 'admin' then
		notifyBusiness(lease.businessId, 'warning', _t('business_lease_admin_ended'))
	end
	audit('housing_lease_ended', { operation = lease.propertyId, target = lease.businessId, action = reason })
	return true
end

-- Primeira unidade livre do imóvel comercial; a chave única do banco decide a corrida.
local function createLease(property, businessId, cycleDays, dailyRate, paidUntil)
	for _ = 1, 3 do
		local unit = HousingRules.FirstFreeUnit(property.units, (usedUnits(property.id)))
		if not unit then
			return nil, 'no_vacancy'
		end
		local lease, errorCode = HousingPersistence.InsertLease(property.id, unit, businessId, cycleDays, dailyRate, paidUntil)
		if lease then
			leases[lease.id] = lease
			return lease
		end
		if errorCode ~= 'ER_DUP_ENTRY' then
			return nil, 'database_error'
		end
		rebuild()
		if leaseOf(businessId, property.id) then
			return nil, 'already_leased'
		end
	end
	return nil, 'database_error'
end

-- Primeira unidade livre; a chave única do banco decide a corrida entre dois pedidos.
local function createTenancy(property, characterId, cycleDays, dailyRate, paidUntil)
	for _ = 1, 3 do
		local used = usedUnits(property.id)
		local unit = HousingRules.FirstFreeUnit(property.units, used)
		if not unit then
			return nil, 'no_vacancy'
		end
		local tenancy, errorCode = HousingPersistence.InsertTenancy(property.id, unit, characterId, cycleDays, dailyRate, paidUntil)
		if tenancy then
			tenancies[tenancy.id] = tenancy
			return tenancy
		end
		if errorCode ~= 'ER_DUP_ENTRY' then
			return nil, 'database_error'
		end
		rebuild()
		if tenancyOf(characterId, property.id) then
			return nil, 'already_tenant'
		end
	end
	return nil, 'database_error'
end

-- Aluguel comercial: o negócio de ponto paga pelo caixa da sociedade; exige business.funds.
local function rentCommercial(playerId, who, property, cycleDays)
	if property.businessId then
		return fail(playerId, 'not_rentable')
	end
	local businessId = remote('coe_businesses', 'CurrentDuty', playerId)
	if not businessId then
		return fail(playerId, 'no_duty')
	end
	if not canFunds(businessId, who.characterId) then
		return fail(playerId, 'not_allowed')
	end
	local key = 'business:' .. businessId
	if locked[key] then
		return fail(playerId, 'busy')
	end
	locked[key] = true
	local function finish(code)
		locked[key] = nil
		if code then
			fail(playerId, code)
		end
	end

	if leaseOf(businessId, property.id) then
		return finish('already_leased')
	end
	if leaseCount(businessId) >= config.Limits.MaxLeasesPerBusiness then
		return finish('lease_limit')
	end
	local _, occupied = usedUnits(property.id)
	if occupied >= property.units then
		return finish('no_vacancy')
	end

	local total = HousingRules.Total(property.rent.daily, cycleDays)
	local charged = remote('coe_economy', 'SocietyCharge', businessId, total, 'rent_payment', 'prop_' .. property.id)
	if charged ~= true then
		local code = type(charged) == 'table' and charged.error
		return finish(code == 'insufficient_funds' and 'society_funds' or 'economy_unavailable')
	end
	local lease, createError = createLease(property, businessId, cycleDays, property.rent.daily, os.time() + cycleDays * DAY)
	if not lease then
		remote('coe_economy', 'SocietyCollect', businessId, total, 'rent_refund')
		return finish(createError)
	end
	locked[key] = nil
	notify(playerId, 'success', _t('commercial_leased', { business = businessLabel(businessId), property = property.label }))
	audit('housing_leased', { operation = property.id, character_id = who.characterId, target = businessId, count = total })
	sendMenu(playerId, who, property)
end

RegisterNetEvent('coe_housing:rent', function(propertyId, cycleDays)
	local playerId = source
	if throttled(playerId) then
		return
	end
	local property, who, errorCode = propertyAt(playerId, propertyId)
	if not property then
		return fail(playerId, errorCode)
	end
	if not property.rent then
		return fail(playerId, 'not_rentable')
	end
	if type(cycleDays) ~= 'number' or not HousingRules.ValidCycle(cycleDays, config) then
		return fail(playerId, 'invalid_cycle')
	end
	local allowed = false
	for _, days in ipairs(property.rent.cycles) do
		allowed = allowed or days == cycleDays
	end
	if not allowed then
		return fail(playerId, 'invalid_cycle')
	end
	if property.kind == 'commercial' then
		return rentCommercial(playerId, who, property, cycleDays)
	end
	if locked[who.characterId] then
		return fail(playerId, 'busy')
	end
	locked[who.characterId] = true
	local function finish(code)
		locked[who.characterId] = nil
		if code then
			fail(playerId, code)
		end
	end

	if tenancyOf(who.characterId, property.id) then
		return finish('already_tenant')
	end
	if tenancyCount(who.characterId) >= config.Limits.MaxTenancies then
		return finish('tenancy_limit')
	end
	local _, occupied = usedUnits(property.id)
	if occupied >= property.units then
		return finish('no_vacancy')
	end

	local total = HousingRules.Total(property.rent.daily, cycleDays)
	local ok, debited, debitError = pcall(function()
		return exports.coe_economy:Debit(who.characterId, total, 'rent_payment', 'prop_' .. property.id)
	end)
	if not ok then
		return finish('economy_unavailable')
	end
	if not debited then
		return finish(debitError == 'insufficient_funds' and 'insufficient_funds' or 'economy_unavailable')
	end
	local tenancy, createError = createTenancy(property, who.characterId, cycleDays, property.rent.daily, os.time() + cycleDays * DAY)
	if not tenancy then
		pcall(function()
			return exports.coe_economy:Credit(who.characterId, total, 'rent_refund', 'prop_' .. property.id)
		end)
		return finish(createError)
	end
	locked[who.characterId] = nil
	notify(playerId, 'success', _t('residential_rented', { property = property.label, unit = tenancy.unit }))
	audit('housing_rented', { operation = property.id, character_id = who.characterId, count = total })
	sendMenu(playerId, who, property)
end)

RegisterNetEvent('coe_housing:cancel', function(propertyId)
	local playerId = source
	if throttled(playerId) then
		return
	end
	local property, who, errorCode = propertyAt(playerId, propertyId)
	if not property then
		return fail(playerId, errorCode)
	end
	if property.kind == 'commercial' then
		local lease = memberLease(who.characterId, property.id)
		if not lease then
			return fail(playerId, 'no_lease')
		end
		if lease.cycleDays == 0 then
			return fail(playerId, 'granted_locked')
		end
		if not canFunds(lease.businessId, who.characterId) then
			return fail(playerId, 'not_allowed')
		end
		if not endLease(lease, 'cancelled') then
			return fail(playerId, 'database_error')
		end
		notify(playerId, 'info', _t('commercial_cancelled'))
		return sendMenu(playerId, who, property)
	end
	local tenancy = tenancyOf(who.characterId, property.id)
	if not tenancy then
		return fail(playerId, 'no_tenancy')
	end
	if tenancy.cycleDays == 0 then
		return fail(playerId, 'starter_locked')
	end
	if not evict(tenancy, 'cancelled') then
		return fail(playerId, 'database_error')
	end
	notify(playerId, 'info', _t('residential_cancelled'))
	sendMenu(playerId, who, property)
end)

RegisterNetEvent('coe_housing:close', function() end)

-- Cobra os contratos vencidos; sem saldo, avisa e encerra ao fim da tolerância.
local function tick()
	local now = os.time()
	local snapshot = {}
	for _, tenancy in pairs(tenancies) do
		snapshot[#snapshot + 1] = tenancy
	end
	for _, tenancy in ipairs(snapshot) do
		if tenancies[tenancy.id] then
			local state = HousingRules.State(tenancy, now, config)
			if state == 'expired' then
				evict(tenancy, 'expired')
			elseif state == 'due' then
				local ok, debited = pcall(function()
					return exports.coe_economy:Debit(tenancy.characterId, HousingRules.Total(tenancy.dailyRate, tenancy.cycleDays), 'rent_payment', 'prop_' .. tenancy.propertyId)
				end)
				if ok and debited then
					local paidUntil = HousingRules.NextPaidUntil(tenancy.paidUntil, tenancy.cycleDays)
					if HousingPersistence.UpdatePaidUntil(tenancy.id, paidUntil) then
						tenancy.paidUntil = paidUntil
						warned[tenancy.id] = nil
						local playerId = playerOf(tenancy.characterId)
						if playerId then
							notify(playerId, 'info', _t('rent_renewed'))
						end
					end
				elseif not warned[tenancy.id] then
					warned[tenancy.id] = true
					local playerId = playerOf(tenancy.characterId)
					if playerId then
						notify(playerId, 'warning', _t('rent_overdue_warning'))
					end
				end
			end
		end
	end
	local leaseSnapshot = {}
	for _, lease in pairs(leases) do
		leaseSnapshot[#leaseSnapshot + 1] = lease
	end
	for _, lease in ipairs(leaseSnapshot) do
		if leases[lease.id] then
			local state = HousingRules.State(lease, now, config)
			if state == 'expired' then
				endLease(lease, 'expired')
			elseif state == 'due' then
				local charged = remote('coe_economy', 'SocietyCharge', lease.businessId,
					HousingRules.Total(lease.dailyRate, lease.cycleDays), 'rent_payment', 'prop_' .. lease.propertyId)
				if charged == true then
					local paidUntil = HousingRules.NextPaidUntil(lease.paidUntil, lease.cycleDays)
					if HousingPersistence.UpdateLeasePaidUntil(lease.id, paidUntil) then
						lease.paidUntil = paidUntil
						leaseWarned[lease.id] = nil
					end
				elseif not leaseWarned[lease.id] then
					leaseWarned[lease.id] = true
					notifyBusiness(lease.businessId, 'warning', _t('business_rent_overdue_warning'))
				end
			end
		end
	end
end

-- Imóvel inicial: cada personagem recebe um uma única vez, sem cobrança.
local function grantStarter(playerId, characterId)
	characterId = tostring(characterId)
	local claimed = HousingPersistence.ClaimGrant(characterId)
	if not claimed then
		return
	end
	local starter
	for _, property in ipairs(sorted()) do
		if property.starter and property.enabled then
			local _, count = usedUnits(property.id)
			if count < property.units then
				starter = property
				break
			end
		end
	end
	if not starter then
		HousingPersistence.ReleaseGrant(characterId)
		return
	end
	local tenancy = createTenancy(starter, characterId, 0, 0, 0)
	if not tenancy then
		HousingPersistence.ReleaseGrant(characterId)
		return
	end
	notify(playerId, 'success', _t('starter_granted', { property = starter.label }))
	audit('housing_starter_granted', { operation = starter.id, character_id = characterId })
end

-- Quem desconectou dentro do interior volta para dentro; se o contrato acabou nesse meio tempo, vai para a porta.
local function resumePresence(playerId, characterId)
	local presence = HousingPersistence.GetPresence(characterId)
	if not presence then
		return
	end
	characterId = tostring(characterId)
	-- Imóvel ilegal (presença sem contrato): volta para dentro só se ainda tiver acesso.
	if (presence.tenancyId or 0) == 0 and presence.lease ~= true then
		local hideout = properties[presence.propertyId]
		if hideout and hideout.kind == 'hideout' and hideout.enabled and hideout.world
			and HousingRegistry.HasAccess(hideout, characterId) then
			if GetPlayerName(playerId) then
				placeInHideout(playerId, characterId, hideout)
				audit('housing_resumed', { operation = hideout.id, character_id = characterId })
			end
			return
		end
		HousingPersistence.ClearPresence(characterId)
		if hideout then
			TriggerClientEvent('coe_housing:left', playerId, hideout.door)
		end
		return
	end
	local isLease = presence.lease == true
	local entry, property, member
	if isLease then
		entry = leases[presence.tenancyId]
		member = entry and isMember(entry.businessId, characterId)
	else
		entry = tenancies[presence.tenancyId]
		member = entry and entry.characterId == characterId
	end
	property = entry and properties[entry.propertyId]
	local valid = entry and property and property.enabled and property.interior and member
		and HousingRules.State(entry, os.time(), config) == 'ok'
	if not valid then
		HousingPersistence.ClearPresence(characterId)
		local door = (property or properties[presence.propertyId] or {}).door
		if door then
			TriggerClientEvent('coe_housing:left', playerId, door)
		end
		return
	end
	if not GetPlayerName(playerId) then
		return
	end
	inside[playerId] = {
		tenancyId = not isLease and entry.id or nil, leaseId = isLease and entry.id or nil,
		propertyId = property.id, characterId = characterId
	}
	Core.Platform.Routing.SetPlayerBucket(playerId, bucketOf(entry, isLease))
	Core.Platform.Routing.SetPopulationEnabled(bucketOf(entry, isLease), false)
	TriggerClientEvent('coe_housing:entered', playerId, enteredInfo(property))
	audit('housing_resumed', { operation = property.id, character_id = characterId })
end

AddEventHandler('coe_core:characterLoaded', function(playerId, characterId)
	local deadline = GetGameTimer() + 60000
	while not ready and GetGameTimer() < deadline do
		Wait(500)
	end
	if ready then
		sendDoors(playerId)
		resumePresence(playerId, characterId)
		grantStarter(playerId, characterId)
	end
end)

AddEventHandler('playerDropped', function()
	local playerId = source
	lastAction[playerId] = nil
	inside[playerId] = nil
	previewing[playerId] = nil
end)

-- Exports devolvem um único valor: o resultado, ou { error = codigo }.
local function packResult(value, errorCode)
	if value then
		return value
	end
	return { error = errorCode or 'database_error' }
end

local function adminOnly()
	return GetInvokingResource() == 'coe_admin'
end

local function saveProperty(raw)
	if not ready then
		return nil, 'not_ready'
	end
	local property, errorCode = HousingRegistry.Normalize(raw, config, HousingInteriors.byId)
	if not property then
		return nil, errorCode
	end
	local count = 0
	for _ in pairs(properties) do
		count = count + 1
	end
	if not properties[property.id] and count >= config.Limits.MaxProperties then
		return nil, 'property_limit'
	end
	local used = usedUnits(property.id)
	for unit in pairs(used) do
		if unit > property.units then
			return nil, 'units_in_use'
		end
	end
	-- Comercial só tem contratos de negócio; os demais tipos, só de personagem.
	local hasTenancy = false
	for _, tenancy in pairs(tenancies) do
		hasTenancy = hasTenancy or tenancy.propertyId == property.id
	end
	local stale = {}
	for _, lease in pairs(leases) do
		if lease.propertyId == property.id then
			if property.kind ~= 'commercial' or (property.businessId and lease.cycleDays > 0) then
				return nil, 'units_in_use'
			end
			if lease.cycleDays == 0 and lease.businessId ~= property.businessId then
				stale[#stale + 1] = lease
			end
		end
	end
	if property.kind == 'commercial' and hasTenancy then
		return nil, 'units_in_use'
	end
	if property.kind == 'hideout' then
		if hasTenancy then
			return nil, 'units_in_use'
		end
		-- O número do mundo nasce no primeiro save e acompanha o imóvel; o painel não o define.
		local previous = properties[property.id]
		property.world = previous and previous.kind == 'hideout' and previous.world or HousingRegistry.FreeWorld(properties, property.id)
	end
	if property.businessId and type(remote('coe_businesses', 'Get', property.businessId)) ~= 'table' then
		return nil, 'unknown_business'
	end
	local saved, saveError = HousingPersistence.SaveProperty(property)
	if not saved then
		return nil, saveError or 'database_error'
	end
	properties[property.id] = property
	expelWithoutAccess(property.id)
	for _, lease in ipairs(stale) do
		endLease(lease, 'unlinked')
	end
	-- Vínculo do admin: contrato gratuito (cycleDays 0) do negócio neste imóvel.
	if property.businessId and not leaseOf(property.businessId, property.id) then
		local lease, leaseError = createLease(property, property.businessId, 0, 0, 0)
		if not lease then
			broadcast()
			return nil, leaseError
		end
		audit('housing_lease_granted', { operation = property.id, target = property.businessId })
	end
	broadcast()
	audit('property_saved', { operation = property.id })
	return property
end

local function deleteProperty(propertyId)
	if not ready then
		return nil, 'not_ready'
	end
	if type(propertyId) ~= 'string' or not properties[propertyId] then
		return nil, 'unknown_property'
	end
	local _, count = usedUnits(propertyId)
	if count > 0 then
		return nil, 'has_tenants'
	end
	local removed, errorCode = HousingPersistence.DeleteProperty(propertyId)
	if not removed then
		return nil, errorCode or 'database_error'
	end
	for playerId, state in pairs(inside) do
		if state.hideout and state.propertyId == propertyId then
			exitPlayer(playerId)
		end
	end
	properties[propertyId] = nil
	broadcast()
	audit('property_deleted', { operation = propertyId })
	return true
end

exports('ListProperties', function()
	if not adminOnly() or not ready then
		return {}
	end
	local list = {}
	for _, property in ipairs(sorted()) do
		local _, count = usedUnits(property.id)
		local entry = {}
		for key, value in pairs(property) do
			entry[key] = value
		end
		entry.occupied = count
		list[#list + 1] = entry
	end
	return list
end)

exports('SaveProperty', function(raw)
	if not adminOnly() then
		return { error = 'forbidden' }
	end
	return packResult(saveProperty(raw))
end)

exports('DeleteProperty', function(propertyId)
	if not adminOnly() then
		return { error = 'forbidden' }
	end
	return packResult(deleteProperty(propertyId))
end)

-- Imobiliária (admin): contratos de um imóvel, com quem está dentro agora.
exports('PropertyContracts', function(propertyId)
	if not adminOnly() then
		return { error = 'forbidden' }
	end
	if not ready then
		return { error = 'not_ready' }
	end
	if type(propertyId) ~= 'string' or not properties[propertyId] then
		return { error = 'unknown_property' }
	end
	local present = {}
	for _, state in pairs(inside) do
		local key = state.leaseId and ('lease:' .. state.leaseId) or ('tenancy:' .. tostring(state.tenancyId))
		present[key] = (present[key] or 0) + 1
	end
	local now, list = os.time(), {}
	for _, tenancy in pairs(tenancies) do
		if tenancy.propertyId == propertyId then
			list[#list + 1] = {
				kind = 'tenancy', id = tenancy.id, unit = tenancy.unit, characterId = tenancy.characterId,
				cycleDays = tenancy.cycleDays, dailyRate = tenancy.dailyRate, paidUntil = tenancy.paidUntil,
				state = HousingRules.State(tenancy, now, config), starter = tenancy.cycleDays == 0,
				present = present['tenancy:' .. tenancy.id] or 0
			}
		end
	end
	for _, lease in pairs(leases) do
		if lease.propertyId == propertyId then
			list[#list + 1] = {
				kind = 'lease', id = lease.id, unit = lease.unit, businessId = lease.businessId, businessLabel = businessLabel(lease.businessId),
				cycleDays = lease.cycleDays, dailyRate = lease.dailyRate, paidUntil = lease.paidUntil,
				state = HousingRules.State(lease, now, config), granted = lease.cycleDays == 0,
				present = present['lease:' .. lease.id] or 0
			}
		end
	end
	table.sort(list, function(a, b) return a.unit < b.unit end)
	return list
end)

-- Imobiliária (admin): encerra um contrato. O inicial e o cedido a um negócio não são encerrados por aqui.
exports('EndContract', function(kind, contractId)
	if not adminOnly() then
		return { error = 'forbidden' }
	end
	if not ready then
		return { error = 'not_ready' }
	end
	contractId = tonumber(contractId)
	if kind == 'tenancy' then
		local tenancy = contractId and tenancies[contractId]
		if not tenancy then
			return { error = 'unknown_contract' }
		end
		if tenancy.cycleDays == 0 then
			return { error = 'starter_locked' }
		end
		return evict(tenancy, 'admin') and true or { error = 'database_error' }
	elseif kind == 'lease' then
		local lease = contractId and leases[contractId]
		if not lease then
			return { error = 'unknown_contract' }
		end
		if lease.cycleDays == 0 then
			return { error = 'granted_locked' }
		end
		return endLease(lease, 'admin') and true or { error = 'database_error' }
	end
	return { error = 'unknown_contract' }
end)

exports('IsReady', function()
	return ready
end)

-- Tablet (/casa, app Esconderijo): o dono de um imóvel ilegal escolhe quem mais tem acesso.
local function ownedHideouts(characterId)
	local list = {}
	characterId = tonumber(characterId)
	for _, property in ipairs(sorted()) do
		if property.kind == 'hideout' and property.owner and tonumber(property.owner.characterId) == characterId then
			list[#list + 1] = property
		end
	end
	return list
end

-- App Aluguéis: contratos pessoais do personagem e os comerciais dos negócios de que ele é dono ou da equipe.
local function rentalsOf(characterId)
	local list, now = {}, os.time()
	local function add(entry, payer)
		local property = properties[entry.propertyId]
		if not property then
			return
		end
		list[#list + 1] = {
			label = property.label, kind = config.Kinds[property.kind] or property.kind, unit = entry.unit, payer = payer,
			dailyRate = entry.dailyRate, cycleDays = entry.cycleDays,
			cycleTotal = entry.cycleDays > 0 and HousingRules.Total(entry.dailyRate, entry.cycleDays) or 0,
			paidUntil = entry.paidUntil, graceUntil = entry.paidUntil + config.GraceDays * DAY,
			state = HousingRules.State(entry, now, config), starter = entry.cycleDays == 0,
			x = property.door.x, y = property.door.y
		}
	end
	for _, tenancy in pairs(tenancies) do
		if tenancy.characterId == characterId then
			add(tenancy, nil)
		end
	end
	for _, lease in pairs(leases) do
		if isMember(lease.businessId, characterId) then
			add(lease, businessLabel(lease.businessId))
		end
	end
	table.sort(list, function(a, b)
		if (a.payer == nil) ~= (b.payer == nil) then
			return a.payer == nil
		end
		return a.label < b.label
	end)
	return list
end

local function hasRental(characterId)
	for _, tenancy in pairs(tenancies) do
		if tenancy.characterId == characterId then
			return true
		end
	end
	for _, lease in pairs(leases) do
		if isMember(lease.businessId, characterId) then
			return true
		end
	end
	return false
end

exports('TabletVisible', function(playerId, appId)
	if GetInvokingResource() ~= 'coe_tablet' or not ready then
		return false
	end
	local characterId = Core.Players.GetActiveCharacterId(playerId)
	if characterId == nil then
		return false
	end
	if appId == 'rentals' then
		return hasRental(tostring(characterId))
	end
	return #ownedHideouts(characterId) > 0
end)

local function hideoutTarget(stateId)
	stateId = tonumber(stateId)
	if not stateId or stateId % 1 ~= 0 or stateId < 1 then
		return nil, 'target_not_found'
	end
	local character, errorCode = Core.Players.GetCharacterByStateId(stateId)
	if not character then
		return nil, errorCode == 'character_not_online' and 'target_not_online' or 'target_not_found'
	end
	local name = ((character.firstName or '') .. ' ' .. (character.lastName or '')):gsub('^%s+', ''):gsub('%s+$', '')
	return HousingRegistry.Person({ characterId = character.characterId, name = name:sub(1, 64) }) or nil, 'target_not_found'
end

exports('TabletCall', function(playerId, appId, action, payload)
	if GetInvokingResource() ~= 'coe_tablet' then
		log('warn', 'security', 'housing_tablet_forbidden', { operation = GetInvokingResource() or 'unknown' })
		return { ok = false, error = 'forbidden' }
	end
	if not ready then
		return { ok = false, error = 'not_ready' }
	end
	local characterId = Core.Players.GetActiveCharacterId(playerId)
	if not characterId then
		return { ok = false, error = 'no_character' }
	end
	if appId == 'rentals' then
		if action ~= 'list' then
			return { ok = false, error = 'unknown_action' }
		end
		return { ok = true, rentals = rentalsOf(tostring(characterId)) }
	end
	if action == 'list' then
		local present = {}
		for _, state in pairs(inside) do
			if state.hideout then
				present[state.propertyId] = (present[state.propertyId] or 0) + 1
			end
		end
		local list = {}
		for _, property in ipairs(ownedHideouts(characterId)) do
			local members = {}
			for index, member in ipairs(property.members or {}) do
				members[index] = { characterId = member.characterId, name = member.name }
			end
			list[#list + 1] = {
				id = property.id, label = property.label, enabled = property.enabled,
				members = members, present = present[property.id] or 0
			}
		end
		return { ok = true, hideouts = list, maxMembers = config.Limits.MaxHideoutMembers }
	end
	if action ~= 'allow' and action ~= 'revoke' then
		return { ok = false, error = 'unknown_action' }
	end
	if type(payload) ~= 'table' then
		payload = {}
	end
	local property = type(payload.property) == 'string' and properties[payload.property] or nil
	if not property or property.kind ~= 'hideout' or not property.owner
		or tonumber(property.owner.characterId) ~= tonumber(characterId) then
		return { ok = false, error = 'not_owner' }
	end
	local members = {}
	for index, member in ipairs(property.members or {}) do
		members[index] = { characterId = member.characterId, name = member.name }
	end
	if action == 'allow' then
		local target, targetError = hideoutTarget(payload.stateId)
		if not target then
			return { ok = false, error = targetError }
		end
		if HousingRegistry.HasAccess(property, target.characterId) then
			return { ok = false, error = tonumber(property.owner.characterId) == target.characterId and 'is_owner' or 'already_allowed' }
		end
		if #members >= config.Limits.MaxHideoutMembers then
			return { ok = false, error = 'members_limit' }
		end
		members[#members + 1] = target
	else
		local found = false
		for index, member in ipairs(members) do
			if not found and tonumber(member.characterId) == tonumber(payload.characterId) then
				table.remove(members, index)
				found = true
			end
		end
		if not found then
			return { ok = false, error = 'unknown_person' }
		end
	end
	local raw = {}
	for key, value in pairs(property) do
		raw[key] = value
	end
	raw.members = members
	local saved, saveError = saveProperty(raw)
	if not saved then
		return { ok = false, error = saveError }
	end
	audit('housing_hideout_' .. action, { operation = property.id, character_id = tostring(characterId) })
	return { ok = true }
end)

-- Catálogo de interiores nativos (shared/interiors.lua), para o admin escolher o interior de cada imóvel.
exports('Interiors', function()
	if not adminOnly() then
		return { categories = {}, list = {} }
	end
	return { categories = HousingInteriors.categories, list = HousingInteriors.list }
end)

-- Miniaturas capturadas no jogo: mapa id do interior -> data URL JPEG.
exports('InteriorThumbs', function()
	if not adminOnly() then
		return { error = 'forbidden' }
	end
	if not ready then
		return { error = 'not_ready' }
	end
	local map, errorCode = HousingPersistence.ListThumbs()
	return packResult(map, errorCode)
end)

exports('SaveInteriorThumb', function(interiorId, image)
	if not adminOnly() then
		return { error = 'forbidden' }
	end
	if not ready then
		return { error = 'not_ready' }
	end
	local valid, errorCode = HousingRegistry.Thumb(interiorId, image, HousingInteriors.byId, config.Limits.MaxThumbBytes)
	if not valid then
		return { error = errorCode }
	end
	local saved, saveError = HousingPersistence.SaveThumb(interiorId, image)
	return packResult(saved and true or nil, saveError)
end)

-- Prévia: o admin vai para um mundo só dele enquanto visita interiores; EndPreview o devolve ao mundo comum.
exports('BeginPreview', function(playerId)
	if not adminOnly() then
		return { error = 'forbidden' }
	end
	playerId = tonumber(playerId)
	if not playerId or not GetPlayerName(playerId) then
		return { error = 'invalid_player' }
	end
	-- Quem está dentro de um imóvel também visita: ao voltar, retorna ao mundo do próprio imóvel.
	local bucket = config.PreviewBucketBase + playerId
	local current = Core.Platform.Routing.GetPlayerBucket(playerId)
	if not previewing[playerId] then
		previewing[playerId] = { bucket = current ~= bucket and current or 0 }
	end
	Core.Platform.Routing.SetPlayerBucket(playerId, bucket)
	Core.Platform.Routing.SetPopulationEnabled(bucket, false)
	return true
end)

exports('EndPreview', function(playerId)
	if not adminOnly() then
		return { error = 'forbidden' }
	end
	playerId = tonumber(playerId)
	if playerId and (previewing[playerId] or Core.Platform.Routing.GetPlayerBucket(playerId) == config.PreviewBucketBase + playerId) then
		local preview = previewing[playerId] or {}
		previewing[playerId] = nil
		Core.Platform.Routing.SetPlayerBucket(playerId, inside[playerId] and preview.bucket or 0)
		if preview.door then
			TriggerClientEvent('coe_housing:left', playerId, preview.door)
		end
	end
	return true
end)

-- Visita interrompida (admin ou este resource parou): devolve quem estava visitando ao mundo normal.
AddEventHandler('onResourceStop', function(resourceName)
	if resourceName ~= GetCurrentResourceName() and resourceName ~= 'coe_admin' then
		return
	end
	for playerId, preview in pairs(previewing) do
		previewing[playerId] = nil
		if GetPlayerName(playerId) then
			Core.Platform.Routing.SetPlayerBucket(playerId, inside[playerId] and preview.bucket or 0)
		end
	end
end)

-- Imóveis comerciais de um negócio (alugados ou cedidos), para o tablet de negócios.
exports('BusinessProperties', function(businessId)
	if config.BusinessResources[GetInvokingResource() or ''] ~= true or not ready or type(businessId) ~= 'string' then
		return {}
	end
	local now = os.time()
	local list = {}
	for _, lease in pairs(leases) do
		local property = lease.businessId == businessId and properties[lease.propertyId]
		if property then
			list[#list + 1] = {
				id = property.id, label = property.label, enabled = property.enabled, leased = lease.cycleDays > 0,
				paidUntil = lease.paidUntil, overdue = HousingRules.State(lease, now, config) ~= 'ok',
				x = property.door.x, y = property.door.y
			}
		end
	end
	table.sort(list, function(a, b) return a.label < b.label end)
	return list
end)

-- Entregas (coe_amzg) -----------------------------------------------------------------------------------
-- Endereço = imóvel + dono do espaço (o mesmo do baú). Só resources de config.DeliveryCallers.

local function deliveryCaller()
	return config.DeliveryCallers[GetInvokingResource() or ''] == true and ready
end

-- Endereços em que o personagem pode receber: moradias, comerciais dos negócios em que trabalha e imóveis ilegais
-- com acesso. Contratos vencidos (fora da carência) ficam de fora.
exports('DeliveryAddresses', function(playerId)
	local characterId = deliveryCaller() and Core.Players.GetActiveCharacterId(playerId)
	if not characterId then
		return {}
	end
	characterId = tostring(characterId)
	local list, now = {}, os.time()
	local function add(property, owner, detail)
		if property and property.enabled then
			list[#list + 1] = {
				propertyId = property.id, owner = owner, label = property.label, kind = property.kind,
				kindLabel = config.Kinds[property.kind] or property.kind, detail = detail, x = property.door.x, y = property.door.y
			}
		end
	end
	for _, tenancy in pairs(tenancies) do
		if tenancy.characterId == characterId and HousingRules.State(tenancy, now, config) == 'ok' then
			add(properties[tenancy.propertyId], 'c' .. characterId)
		end
	end
	for _, lease in pairs(leases) do
		if isMember(lease.businessId, characterId) and HousingRules.State(lease, now, config) == 'ok' then
			add(properties[lease.propertyId], 'b' .. lease.businessId, businessLabel(lease.businessId))
		end
	end
	for _, property in pairs(properties) do
		if property.kind == 'hideout' and property.world and HousingRegistry.HasAccess(property, characterId) then
			add(property, 'shared')
		end
	end
	table.sort(list, function(a, b) return a.label < b.label end)
	return list
end)

-- O endereço ainda existe (contrato ativo ou imóvel ilegal com mundo)? Devolve o interior para posicionar a entrega.
exports('AddressActive', function(propertyId, owner)
	local property = deliveryCaller() and type(propertyId) == 'string' and properties[propertyId]
	if not property or not property.enabled or type(owner) ~= 'string' then
		return false
	end
	local active
	if owner == 'shared' then
		active = property.kind == 'hideout' and property.world ~= nil
	elseif owner:sub(1, 1) == 'b' then
		active = leaseOf(owner:sub(2), propertyId) ~= nil
	elseif owner:sub(1, 1) == 'c' then
		active = tenancyOf(owner:sub(2), propertyId) ~= nil
	end
	return active == true
end)

-- Espaço em que o jogador está agora: { propertyId, owner, interior }, ou nil fora de um imóvel.
exports('CurrentSpace', function(playerId)
	local state = deliveryCaller() and inside[playerId]
	local property = state and properties[state.propertyId]
	if not property then
		return nil
	end
	local owner = spaceOwner(state, property, state.characterId)
	if not owner then
		return nil
	end
	local interior = property.interior
	return { propertyId = property.id, owner = owner, interior = { x = interior.x, y = interior.y, z = interior.z, heading = interior.heading or 0.0 } }
end)

-- Jogadores dentro de um espaço (para mostrar entregas a quem já está lá).
exports('PlayersInSpace', function(propertyId, owner)
	local list = {}
	if not deliveryCaller() then
		return list
	end
	for playerId, state in pairs(inside) do
		local property = state.propertyId == propertyId and properties[propertyId]
		if property and spaceOwner(state, property, state.characterId) == owner then
			list[#list + 1] = playerId
		end
	end
	return list
end)

CreateThread(function()
	local waitingLogged = false
	while true do
		local initialized, errorCode = HousingPersistence.Initialize()
		if initialized then
			break
		end
		if errorCode == 'database_not_ready' then
			if not waitingLogged then
				log('info', 'persistence', 'database_waiting', {})
				waitingLogged = true
			end
			Wait(1000)
		else
			log('error', 'persistence', 'database_initialization_failed', { error_code = errorCode or 'database_error', retry_ms = 5000 })
			Wait(5000)
		end
	end
	local dependenciesLogged = false
	while not (GetResourceState('coe_economy') == 'started' and exports.coe_economy:IsReady()) do
		if not dependenciesLogged then
			log('info', 'system', 'housing_waiting', {})
			dependenciesLogged = true
		end
		Wait(1000)
	end
	rebuild()
	ready = true
	log('info', 'system', 'housing_ready', {})
	broadcast()
	while true do
		Wait(config.TickMs)
		tick()
	end
end)

-- Provedor dos imóveis comerciais no app do negócio (coe_businesses:RegisterProvider 'properties'): aba Propriedades.
-- De novo sempre que o coe_businesses reiniciar.
local function registerPropertiesProvider()
	if GetResourceState('coe_businesses') ~= 'started' then
		return
	end
	local ok, result = pcall(function()
		return exports.coe_businesses:RegisterProvider('properties', { list = 'BusinessProperties' })
	end)
	if not ok or result ~= true then
		log('warn', 'system', 'housing_provider_failed', { error_code = ok and type(result) == 'table' and tostring(result.error) or 'unavailable' })
	end
end

AddEventHandler('onResourceStart', function(resource)
	if resource == 'coe_businesses' then
		registerPropertiesProvider()
	end
end)
CreateThread(registerPropertiesProvider)
