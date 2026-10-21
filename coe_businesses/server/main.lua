local config = BusinessesConfig
local registry
local duty
local ready = false

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

local function isWriter()
	return config.WriterResources[GetInvokingResource() or GetCurrentResourceName()] == true
end

-- Vários retornos se perdem entre resources: devolvemos um valor só, ou { error = codigo }.
local function packResult(value, errorCode)
	if value then
		return value
	end
	return { error = errorCode or 'database_error' }
end

exports('IsReady', function()
	return ready
end)

exports('Categories', function()
	return config.Categories
end)

exports('RuleSchema', function()
	return config.Rules
end)

exports('List', function(category)
	return ready and registry.List(type(category) == 'string' and category or nil) or {}
end)

exports('Get', function(id)
	return ready and registry.Get(id) or nil
end)

exports('Save', function(raw, by)
	if not ready or not isWriter() then
		return { error = ready and 'forbidden' or 'not_ready' }
	end
	return packResult(registry.Save(raw, by))
end)

exports('Seed', function(raw)
	if not ready or not isWriter() then
		return { error = ready and 'forbidden' or 'not_ready' }
	end
	return packResult(registry.Seed(raw))
end)

exports('Delete', function(id, by)
	if not ready or not isWriter() then
		return { error = ready and 'forbidden' or 'not_ready' }
	end
	return packResult(registry.Delete(id, by))
end)

-- Ponto da equipe. Todo negócio bate ponto por aqui (ClockIn/ClockOut são o estado; Clock é o fluxo completo).
exports('ClockIn', function(source, characterId, businessId, at, atStation)
	if not ready or not isWriter() then
		return { error = ready and 'forbidden' or 'not_ready' }
	end
	return packResult(duty.ClockIn(source, characterId, businessId, at, atStation == true))
end)

exports('ClockOut', function(source, reason)
	if not ready or not isWriter() then
		return { error = ready and 'forbidden' or 'not_ready' }
	end
	return packResult(duty.ClockOut(source, reason))
end)

local function accessOf(businessId, characterId)
	local business = ready and registry.Get(businessId) or nil
	return BusinessAccess.Evaluate(business, characterId, business ~= nil and duty.IsOnDuty(businessId, characterId))
end

-- Quem é o quê em um negócio: { owner, staff, partner, canClock, canWork }. Cada negócio é único: nada vaza entre negócios.
exports('Access', function(businessId, characterId)
	if type(businessId) ~= 'string' or characterId == nil then
		return BusinessAccess.Evaluate(nil, nil, false)
	end
	return accessOf(businessId, characterId)
end)

-- Sócios do negócio: { characterId, name }[].
exports('Partners', function(businessId)
	local business = ready and type(businessId) == 'string' and registry.Get(businessId) or nil
	local list = {}
	for _, partner in ipairs(business and business.partners or {}) do
		list[#list + 1] = { characterId = partner.characterId, name = partner.name }
	end
	return list
end)

-- Quem responde pelas dívidas do negócio: o dono primeiro, depois os sócios (ids de personagem). Vazio sem dono.
exports('Debtors', function(businessId)
	local business = ready and type(businessId) == 'string' and registry.Get(businessId) or nil
	if not business or not business.owner then
		return {}
	end
	local list = { business.owner.characterId }
	for _, partner in ipairs(business.partners or {}) do
		list[#list + 1] = partner.characterId
	end
	return list
end)

-- Cargos (grades). Definidos no negócio: nome, nível, salário e permissões. Nada vale entre negócios.
local permissions = {}
for name, label in pairs(config.Permissions) do
	permissions[name] = label
end

exports('Permissions', function()
	return permissions
end)

-- Pacotes (coe_police, coe_ems...) registram as permissões de cargo delas. O prefixo é o nome do resource sem "coe_".
-- Lista de { name = 'police.arrest', label = 'Prender' }. Retorna true ou { error = codigo }.
exports('RegisterPermissions', function(list)
	local invoking = GetInvokingResource()
	if not invoking or config.PermissionResources[invoking] ~= true then
		return { error = 'forbidden' }
	end
	if type(list) ~= 'table' or #list > 64 then
		return { error = 'invalid_permissions' }
	end
	local prefix = invoking:gsub('^coe_', '') .. '.'
	for _, entry in ipairs(list) do
		if type(entry) ~= 'table' or not BusinessGrades.IsPermission(entry.name) or entry.name:sub(1, #prefix) ~= prefix
			or type(entry.label) ~= 'string' or #entry.label == 0 or #entry.label > 64 or entry.label:find('[%c<>]') then
			return { error = 'invalid_permissions' }
		end
	end
	for _, entry in ipairs(list) do
		permissions[entry.name] = entry.label
	end
	return true
end)

exports('Grades', function(businessId)
	local business = ready and type(businessId) == 'string' and registry.Get(businessId) or nil
	return business and business.grades or {}
end)

-- Cargo do personagem naquele negócio (nil se não é da equipe ou o negócio não tem cargos).
exports('GradeOf', function(businessId, characterId)
	local business = ready and type(businessId) == 'string' and registry.Get(businessId) or nil
	return BusinessGrades.Of(business, characterId)
end)

-- O dono (com ownerAccess) tem tudo; a equipe tem as permissões do cargo.
-- Quem tem acesso sem ponto (dono, clockRequired=false ou cargo com business.remote) exerce suas permissões mesmo fora de serviço;
-- quando `remoteOnly == true`, exige especificamente esse acesso sem ponto batido.
exports('Can', function(businessId, characterId, permission, remoteOnly)
	local business = ready and type(businessId) == 'string' and registry.Get(businessId) or nil
	if not business or characterId == nil then
		return false
	end
	return BusinessAccess.Can(business, characterId, permission, duty.IsOnDuty(businessId, characterId), remoteOnly == true)
end)

local function payrollReader()
	return config.PayrollResources[GetInvokingResource() or ''] == true
end

exports('Salary', function(businessId, characterId)
	if not payrollReader() then
		return 0
	end
	local business = ready and type(businessId) == 'string' and registry.Get(businessId) or nil
	local grade = BusinessGrades.Of(business, characterId)
	return grade and grade.salary or 0
end)

-- Folha do negócio: { characterId, name, grade, salary } por funcionário.
exports('Payroll', function(businessId)
	if not payrollReader() then
		return {}
	end
	local business = ready and type(businessId) == 'string' and registry.Get(businessId) or nil
	local list = {}
	for _, member in ipairs(business and business.staff or {}) do
		local grade = BusinessGrades.Find(business.grades, member.grade)
		list[#list + 1] = { characterId = member.characterId, name = member.name, grade = member.grade, salary = grade and grade.salary or 0 }
	end
	return list
end)

local rawLocales = (type(Locales) == 'table' and Locales) or {}
local _t_inst = (Core and Core.Locale and Core.Locale.New) and Core.Locale.New({
	default = (config and config.Locale) or (Core and Core.Locale and Core.Locale.GetDefaultLang()) or 'pt-BR',
	locales = rawLocales
})
local _t = function(k, params)
	if type(_t_inst) == 'table' then
		if _t_inst.T then
			return _t_inst:T(k, params)
		end
		local lang = _t_inst.lang or 'pt-BR'
		local dict = (_t_inst.locales and _t_inst.locales[lang]) or rawLocales[lang] or rawLocales['pt-BR']
		if dict and dict[k] then
			return dict[k]
		end
	elseif type(_t_inst) == 'function' then
		return _t_inst(k, params)
	end
	return (rawLocales['pt-BR'] and rawLocales['pt-BR'][k]) or k
end

local CLOCK_MESSAGES = {
	not_staff = _t('not_staff'), too_far = _t('too_far'),
	outside_area = _t('outside_area'), on_duty_elsewhere = _t('on_duty_elsewhere'),
	already_on_duty = _t('already_on_duty'), not_on_duty = _t('not_on_duty'),
	use_station = _t('use_station'), no_business = _t('no_business')
}

local DUTY_TEXTS = {
	clock_in = 'Ponto batido: entrada em %s.', clock_out = 'Ponto batido: saída de %s.',
	left_area = 'Você saiu da área de %s e o ponto foi encerrado.', business_closed = '%s foi fechado e o ponto foi encerrado.',
	not_staff = 'Você não faz mais parte da equipe de %s e o ponto foi encerrado.'
}

local function notify(playerId, kind, message)
	pcall(function()
		exports.coe_notify:Notify(playerId, kind, message)
	end)
end

local function clockFailed(playerId, errorCode)
	notify(playerId, 'error', _t(errorCode, CLOCK_MESSAGES[errorCode] or _t('clock_failed')))
	return nil, errorCode
end

-- Bater ponto: no ponto marcado do negócio ou, se ele não tem nenhum, com /ponto dentro da área. Sair vale de qualquer lugar.
-- Equipe e local são conferidos aqui, no servidor.
local function clockToggle(source, businessId, stationId)
	local ped = GetPlayerPed(source)
	local characterId = Core.Players.GetActiveCharacterId(source)
	if not ready or not characterId or not ped or ped == 0 then
		return clockFailed(source, 'no_business')
	end
	local current = duty.Current(source)
	if current and (stationId == nil or current == businessId) then
		local ok, errorCode = duty.ClockOut(source, 'clock_out')
		if not ok then
			return clockFailed(source, errorCode)
		end
		return true
	end
	local business = registry.Get(businessId)
	if not business or not business.enabled then
		return clockFailed(source, 'no_business')
	end
	if not accessOf(businessId, characterId).canClock then
		return clockFailed(source, 'not_staff')
	end
	local at = GetEntityCoords(ped)
	local atStation = false
	local clocks = business.stations.clocks or {}
	if stationId ~= nil then
		local station
		for _, candidate in ipairs(clocks) do
			if candidate.id == stationId then
				station = candidate
			end
		end
		if not station then
			return clockFailed(source, 'no_business')
		end
		if #(at - vector3(station.x, station.y, station.z)) > station.radius + 1.0 then
			return clockFailed(source, 'too_far')
		end
		atStation = true
	elseif #clocks > 0 then
		return clockFailed(source, 'use_station')
	end
	local ok, errorCode = duty.ClockIn(source, characterId, businessId, { x = at.x, y = at.y, z = at.z }, atStation)
	if not ok then
		return clockFailed(source, errorCode)
	end
	return true
end

local lastClock = {}

local function clockThrottled(source)
	local now = GetGameTimer()
	if lastClock[source] and now - lastClock[source] < 500 then
		return true
	end
	lastClock[source] = now
	return false
end

exports('Clock', function(source, businessId, stationId)
	if not ready or not config.ClockResources[GetInvokingResource() or ''] then
		return { error = ready and 'forbidden' or 'not_ready' }
	end
	if type(source) ~= 'number' or type(businessId) ~= 'string' or type(stationId) ~= 'string' or clockThrottled(source) then
		return { error = 'invalid_request' }
	end
	local ok, errorCode = clockToggle(source, businessId, stationId)
	return ok and { ok = true } or { error = errorCode }
end)

RegisterNetEvent('coe_businesses:clock', function(businessId, stationId)
	if type(businessId) ~= 'string' or type(stationId) ~= 'string' or clockThrottled(source) then
		return
	end
	clockToggle(source, businessId, stationId)
end)

RegisterCommand('ponto', function(source)
	if source <= 0 or clockThrottled(source) or not ready then
		return
	end
	local ped = GetPlayerPed(source)
	if not ped or ped == 0 then
		return
	end
	local at = GetEntityCoords(ped)
	for _, business in ipairs(registry.List()) do
		if BusinessArea.Contains(business.area, at.x, at.y, at.z) then
			return clockToggle(source, business.id, nil)
		end
	end
	if duty.Current(source) then
		return clockToggle(source, nil, nil)
	end
	clockFailed(source, 'no_business')
end, false)

-- Prompt do ponto e dos baús para os negócios sem prompt próprio. O cliente só pergunta (cache curto); a validação real é em cada ação.
local function clockStations()
	local list = {}
	if not ready then
		return list
	end
	for _, business in ipairs(registry.List()) do
		if business.enabled and not config.ClockPromptElsewhere[business.category] then
			for _, station in ipairs(business.stations.clocks or {}) do
				list[#list + 1] = { kind = 'clock', businessId = business.id, businessLabel = business.label, id = station.id, label = station.label, x = station.x, y = station.y, z = station.z, radius = station.radius }
			end
			for _, station in ipairs(business.stations.stashes or {}) do
				list[#list + 1] = { kind = 'stash', businessId = business.id, businessLabel = business.label, id = station.id, label = station.label, x = station.x, y = station.y, z = station.z, radius = station.radius }
			end
		end
	end
	return list
end

RegisterNetEvent('coe_businesses:requestClocks', function()
	TriggerClientEvent('coe_businesses:clocks', source, clockStations())
end)

local lastCheck = {}

RegisterNetEvent('coe_businesses:checkClock', function(businessId)
	local playerId = source
	local now = GetGameTimer()
	if type(businessId) ~= 'string' or (lastCheck[playerId] and now - lastCheck[playerId] < 1000) then
		return
	end
	lastCheck[playerId] = now
	local characterId = Core.Players.GetActiveCharacterId(playerId)
	local access = characterId and accessOf(businessId, characterId) or nil
	TriggerClientEvent('coe_businesses:clockAccess', playerId, businessId, access ~= nil and access.canClock,
		access ~= nil and duty.IsOnDuty(businessId, characterId))
end)

local STASH_MESSAGES = {
	not_staff = _t('stash_not_staff'), too_far = _t('stash_too_far'),
	no_business = _t('stash_no_business'), container_limit = _t('stash_container_limit')
}

-- Baú do negócio (estação stashes): dono ou equipe, perto do ponto. Mesmo id usado pela bancada do coe_crafting.
RegisterNetEvent('coe_businesses:openStash', function(businessId, stationId)
	local playerId = source
	if type(businessId) ~= 'string' or type(stationId) ~= 'string' or clockThrottled(playerId) or not ready then
		return
	end
	local function failed(errorCode)
		local stashKey = 'stash_' .. tostring(errorCode)
		notify(playerId, 'error', _t(stashKey, STASH_MESSAGES[errorCode] or _t('stash_failed')))
	end
	local business = registry.Get(businessId)
	if not business or not business.enabled or config.ClockPromptElsewhere[business.category] then
		return failed('no_business')
	end
	local station
	for _, candidate in ipairs(business.stations.stashes or {}) do
		if candidate.id == stationId then
			station = candidate
		end
	end
	if not station then
		return failed('no_business')
	end
	local characterId = Core.Players.GetActiveCharacterId(playerId)
	if not characterId or not accessOf(businessId, characterId).canClock then
		return failed('not_staff')
	end
	local ped = GetPlayerPed(playerId)
	if not ped or ped == 0 or #(GetEntityCoords(ped) - vector3(station.x, station.y, station.z)) > station.radius + 1.0 then
		return failed('too_far')
	end
	local ok, opened, openError = pcall(function()
		return exports.coe_inventory:OpenStash(playerId, ('stash:business:%s:%s'):format(businessId, stationId), {
			label = ('%s · %s'):format(station.label, business.label),
			slots = station.slots, maxWeight = station.maxWeight,
			position = { x = station.x, y = station.y, z = station.z }, radius = station.radius + 1.0
		})
	end)
	if not ok or opened ~= true then
		failed(ok and openError or 'no_business')
	end
end)

AddEventHandler('coe_businesses:changed', function()
	if ready then
		TriggerClientEvent('coe_businesses:clocks', -1, clockStations())
	end
end)

exports('IsOnDuty', function(businessId, characterId)
	return ready and characterId ~= nil and duty.IsOnDuty(businessId, characterId) or false
end)

-- Resumo de quem está de ponto (só leitura, para o painel admin).
exports('DutySummary', function()
	if GetInvokingResource() ~= 'coe_admin' or not ready then
		return { total = 0, byBusiness = {} }
	end
	return duty.Counts()
end)

exports('CurrentDuty', function(source)
	return ready and duty.Current(source) or nil
end)

local function economy(name, ...)
	local args = { ... }
	local ok, result = pcall(function()
		return exports.coe_economy[name](exports.coe_economy, table.unpack(args))
	end)
	return ok and result or nil
end

local offerSequence = 0

local tabletDeps = {
	get = function(id)
		return registry.Get(id)
	end,
	currentDuty = function(source)
		return duty.Current(source)
	end,
	characterOf = function(source)
		local id = Core.Players.GetActiveCharacterId(source)
		return id and tostring(id) or nil
	end,
	can = function(businessId, characterId, permission)
		local business = registry.Get(businessId)
		return business ~= nil and BusinessAccess.Can(business, characterId, permission, duty.IsOnDuty(businessId, characterId), false) or false
	end,
	onDuty = function(businessId, characterId)
		return characterId ~= nil and duty.IsOnDuty(businessId, characterId) or false
	end,
	balance = function(businessId)
		local value = economy('SocietyBalance', businessId)
		return type(value) == 'number' and value or nil
	end,
	ledger = function(businessId, limit)
		local rows = economy('SocietyLedger', businessId, limit)
		return type(rows) == 'table' and rows.error == nil and rows or nil
	end,
	deposit = function(businessId, characterId, amount)
		return economy('SocietyDeposit', businessId, characterId, amount)
	end,
	withdraw = function(businessId, characterId, amount)
		return economy('SocietyWithdraw', businessId, characterId, amount)
	end,
	save = function(raw)
		return registry.Save(raw, 'tablet')
	end,
	-- Aba Banco do app do negócio: a conta empresarial é do coe_banking.
	bank = function(source, characterId, businessId, payload)
		if GetResourceState('coe_banking') ~= 'started' then
			return nil
		end
		local ok, result = pcall(function()
			return exports.coe_banking:BusinessTablet(source, characterId, businessId, payload)
		end)
		return ok and result or nil
	end,
	-- Aba Loja do app do negócio: lojas do coe_shops (prateleira, preços e vendas).
	isShop = function(businessId)
		if GetResourceState('coe_shops') ~= 'started' then
			return false
		end
		local ok, result = pcall(function()
			return exports.coe_shops:IsStore(businessId)
		end)
		return ok and result == true
	end,
	shop = function(source, characterId, businessId, payload)
		if GetResourceState('coe_shops') ~= 'started' then
			return nil
		end
		local ok, result = pcall(function()
			return exports.coe_shops:BusinessTablet(source, characterId, businessId, payload)
		end)
		return ok and result or nil
	end,
	resolve = function(stateId)
		local character, errorCode = Core.Players.GetCharacterByStateId(stateId)
		if not character then
			return nil, errorCode == 'character_not_online' and 'target_not_online' or 'target_not_found'
		end
		local player = Core.Players.GetPlayerByStateId(stateId)
		local name = ((character.firstName or '') .. ' ' .. (character.lastName or '')):sub(1, 48)
		return { characterId = tostring(character.characterId), name = name, source = player and tonumber(player.source) or nil }
	end,
	permissions = function()
		return permissions
	end,
	fleet = function(businessId)
		if GetResourceState('coe_garages') ~= 'started' then
			return nil
		end
		local ok, result = pcall(function()
			return exports.coe_garages:BusinessFleet(businessId)
		end)
		return ok and result or nil
	end,
	setFleetStaff = function(businessId, vehicleId, enabled)
		if GetResourceState('coe_garages') ~= 'started' then
			return nil
		end
		local ok, result = pcall(function()
			return exports.coe_garages:SetFleetStaffAccess(businessId, vehicleId, enabled)
		end)
		return ok and result or nil
	end,
	properties = function(businessId)
		if GetResourceState('coe_housing') ~= 'started' then
			return nil
		end
		local ok, result = pcall(function()
			return exports.coe_housing:BusinessProperties(businessId)
		end)
		return ok and result or nil
	end,
	offers = {},
	maxPartners = config.Limits.MaxPartners,
	now = function()
		return os.time()
	end,
	nextOfferId = function()
		offerSequence = offerSequence + 1
		return offerSequence
	end,
	sendOffer = function(offer)
		TriggerClientEvent('coe_businesses:offer', offer.source, {
			id = offer.id, kind = offer.kind or 'staff', business = offer.businessLabel, grade = offer.gradeLabel,
			seconds = BusinessTablet.OfferSeconds
		})
	end,
	audit = function(event, ctx, target, count)
		audit('tablet_action', { operation = ctx.businessId, action = event, character_id = ctx.characterId, target = target, count = count })
	end
}

local lastTablet = {}

local OFFER_MESSAGES = {
	no_offer = _t('no_offer'), offer_expired = _t('offer_expired'), no_business = _t('offer_no_business'),
	is_owner = _t('is_owner'), already_staff = _t('already_staff'), invalid_grade = _t('invalid_grade'),
	multiple_jobs = _t('multiple_jobs'),
	already_partner = _t('already_partner'), partner_limit = _t('partner_limit'),
	database_error = _t('database_error')
}
local lastAnswer = {}

-- O contratado responde à proposta enviada pelo tablet de quem contratou.
RegisterNetEvent('coe_businesses:answerOffer', function(offerId, accept)
	local source = source
	local now = GetGameTimer()
	if not ready or type(offerId) ~= 'number' or (lastAnswer[source] and now - lastAnswer[source] < 1000) then
		return
	end
	lastAnswer[source] = now
	local ok, result = pcall(BusinessTablet.Answer, tabletDeps, source, offerId, accept == true)
	if not ok then
		log('error', 'tablet', 'offer_failed', { error_code = tostring(result):sub(1, 96) })
		return
	end
	local offer = result.offer
	local employer = offer and offer.bySource and GetPlayerName(offer.bySource) and offer.bySource or nil
	local partner = offer and offer.kind == 'partner'
	if result.ok and result.declined then
		notify(source, 'info', _t('offer_declined'))
		if employer then
			notify(employer, 'warning', _t('offer_declined_employer', { name = offer.name }))
		end
	elseif result.ok then
		notify(source, 'success', partner and _t('offer_partner_accepted', { business = offer.businessLabel })
			or _t('offer_staff_accepted', { business = offer.businessLabel }))
		if employer then
			notify(employer, 'success', partner and _t('offer_partner_accepted_employer', { name = offer.name })
				or _t('offer_staff_accepted_employer', { name = offer.name }))
		end
	else
		notify(source, 'error', _t(result.error, OFFER_MESSAGES[result.error] or _t('offer_failed')))
		if employer and result.error ~= 'no_offer' then
			local errDetail = _t(result.error, OFFER_MESSAGES[result.error] or result.error)
			notify(employer, 'error', partner and _t('offer_not_completed_partner', { name = offer.name, error = errDetail })
				or _t('offer_not_completed_staff', { name = offer.name, error = errDetail }))
		end
	end
end)

-- Negócios do jogador para o coe_tablet: um app por negócio de que ele é dono ou da equipe.
exports('TabletInstances', function(playerId)
	if not ready or config.TabletResources[GetInvokingResource() or ''] ~= true then
		return {}
	end
	local characterId = tabletDeps.characterOf(tonumber(playerId))
	return BusinessTablet.Instances(registry.List(), characterId)
end)

-- Chamado só pelo coe_tablet (que já limita a taxa e confere que o negócio é um app do jogador).
-- instance: id do negócio do app; nunca vem do payload.
exports('TabletCall', function(playerId, appId, action, payload, instance)
	if not ready or config.TabletResources[GetInvokingResource() or ''] ~= true or appId ~= 'business' then
		return { ok = false, error = ready and 'forbidden' or 'not_ready' }
	end
	local source = tonumber(playerId)
	if not source then
		return { ok = false, error = 'forbidden' }
	end
	local ok, result = pcall(BusinessTablet.Handle, tabletDeps, source, action, payload, instance)
	if not ok then
		log('error', 'tablet', 'action_failed', { action = tostring(action):sub(1, 24), error_code = tostring(result):sub(1, 96) })
		return { ok = false, error = 'internal_error' }
	end
	return result
end)

AddEventHandler('playerDropped', function()
	if duty then
		duty.Drop(source)
	end
	lastClock[source], lastCheck[source], lastAnswer[source] = nil, nil, nil
end)

CreateThread(function()
	while true do
		Wait(config.Limits.DutySweepMs)
		if ready then
			duty.Sweep(function(source)
				local ped = GetPlayerPed(source)
				if not ped or ped == 0 then
					return nil
				end
				local at = GetEntityCoords(ped)
				return { x = at.x, y = at.y, z = at.z }
			end)
		end
	end
end)

CreateThread(function()
	local waitingLogged = false
	while true do
		local initialized, errorCode = BusinessesPersistence.Initialize()
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

	registry = BusinessRegistry.New({
		config = config,
		persistence = BusinessesPersistence,
		audit = audit,
		onChange = function(id)
			if ready then
				TriggerEvent('coe_businesses:changed', id)
			end
		end,
		onStaff = function(id, characterId, change, grade)
			TriggerEvent('coe_businesses:staffChanged', id, characterId, change, grade)
		end,
		onGrades = function(id)
			TriggerEvent('coe_businesses:gradesChanged', id)
		end
	})
	while true do
		local loaded, loadError = registry.Load()
		if loaded then
			break
		end
		log('error', 'persistence', 'businesses_load_failed', { error_code = loadError, retry_ms = 5000 })
		Wait(5000)
	end
	duty = BusinessDuty.New({
		get = registry.Get,
		member = function(business, characterId)
			return BusinessAccess.Evaluate(business, characterId, false).canClock
		end,
		changed = function(source, businessId, onDuty, reason)
			local business = registry.Get(businessId)
			local bLabel = business and business.label or businessId
			local msg = _t(reason, { business = bLabel })
			if msg == reason and DUTY_TEXTS[reason] then
				msg = (DUTY_TEXTS[reason]):format(bLabel)
			end
			if msg and GetPlayerName(source) then
				notify(source, onDuty and 'success' or 'info', msg)
			end
			TriggerEvent('coe_businesses:dutyChanged', source, businessId, onDuty, reason)
		end
	})
	ready = true
	TriggerClientEvent('coe_businesses:clocks', -1, clockStations())
	TriggerEvent('coe_businesses:ready')
	log('info', 'system', 'businesses_ready', {})
end)
