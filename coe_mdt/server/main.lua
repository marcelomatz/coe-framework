local config = MdtConfig
local ready = false
-- Janelas deslizantes por policial (characterId).
local lookupStamps, writeStamps = {}, {}

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

local function failure(code)
	return { ok = false, error = code }
end

local function businessCall(name, ...)
	if GetResourceState('coe_businesses') ~= 'started' then
		return nil
	end
	local args = { ... }
	local ok, result = pcall(function()
		return exports.coe_businesses[name](exports.coe_businesses, table.unpack(args))
	end)
	return ok and result or nil
end

local function resourceCall(resource, name, ...)
	if GetResourceState(resource) ~= 'started' then
		return nil
	end
	local args = { ... }
	local ok, result = pcall(function()
		return exports[resource][name](exports[resource], table.unpack(args))
	end)
	return ok and result or nil
end

local function characterOf(source)
	local id = Core.Players.GetActiveCharacterId(source)
	return id and tostring(id) or nil
end

-- Policial: personagem ativo, de ponto em um negócio police e com a permissão de cargo.
-- Revalidado a cada ação: sair de serviço ou perder o cargo corta o acesso na hora.
local function officer(source, permission)
	if not ready then
		return nil, 'not_ready'
	end
	local characterId = source and characterOf(source)
	if not characterId then
		return nil, 'no_character'
	end
	local businessId = businessCall('CurrentDuty', source)
	local business = type(businessId) == 'string' and businessCall('Get', businessId) or nil
	if type(business) ~= 'table' then
		return nil, 'not_on_duty'
	end
	if business.category ~= 'police' then
		return nil, 'not_police'
	end
	if businessCall('Can', businessId, characterId, 'mdt.access') ~= true or businessCall('Can', businessId, characterId, permission) ~= true then
		return nil, 'forbidden'
	end
	return { source = source, characterId = characterId, businessId = businessId }
end

local function throttled(cop, stamps, perWindow, window)
	stamps[cop.characterId] = stamps[cop.characterId] or {}
	return not MdtRules.Allow(stamps[cop.characterId], os.time(), perWindow, window)
end

-- Consulta a dado de cidadão/placa: limita, GRAVA o acesso e só então libera (falha fechada).
local function guardLookup(cop, action, subject)
	if throttled(cop, lookupStamps, config.LookupsPerWindow, config.LookupWindowSeconds) then
		return 'rate_limited'
	end
	local logged = MdtPersistence.LogAccess(cop.characterId, cop.businessId, action, subject)
	if not logged then
		return 'database_error'
	end
	return nil
end

local function guardWrite(cop)
	if throttled(cop, writeStamps, config.WritesPerWindow, config.WriteWindowSeconds) then
		return 'rate_limited'
	end
	return nil
end

local function fullName(row)
	return ((row.first_name or '') .. ' ' .. (row.last_name or '')):gsub('^%s+', ''):gsub('%s+$', '')
end

local function nameMap(rowsList, fields)
	local seen, ids = {}, {}
	for _, rows in ipairs(rowsList) do
		for _, row in ipairs(rows) do
			for _, field in ipairs(fields) do
				local value = row[field] and tostring(row[field])
				if value and not seen[value] then
					seen[value] = true
					ids[#ids + 1] = value
				end
			end
		end
	end
	return MdtPersistence.CharacterNames(ids) or {}
end

local function stamp(value)
	return value ~= nil and tostring(value) or ''
end

-- ===== Ações =====
local actions = {}

actions.calls = function(cop)
	local list = resourceCall('coe_dispatch', 'Active', cop.source)
	if type(list) ~= 'table' or list.error then
		return failure(type(list) == 'table' and list.error or 'dispatch_unavailable')
	end
	return { ok = true, calls = list }
end

local function callAction(exportName)
	return function(cop, payload)
		local id = MdtRules.Id(payload.id)
		if not id then
			return failure('invalid_call')
		end
		local result = resourceCall('coe_dispatch', exportName, cop.source, id)
		if type(result) == 'table' and result.error then
			return failure(result.error)
		end
		if result == nil then
			return failure('dispatch_unavailable')
		end
		return { ok = true }
	end
end
actions.accept = callAction('Accept')
actions.close = callAction('Close')

actions.lookup = function(cop, payload)
	local term = type(payload.term) == 'string' and payload.term or ''
	local stateId = MdtRules.StateId(term)
	local tokens
	if not stateId then
		local tokenError
		tokens, tokenError = MdtRules.Tokens(term)
		if not tokens then
			return failure(tokenError)
		end
	end
	local blocked = guardLookup(cop, 'search', stateId or table.concat(tokens, ' '):sub(1, 24))
	if blocked then
		return failure(blocked)
	end
	local rows, rowsError = MdtPersistence.FindCharacters(stateId, tokens, config.Limits.SearchResults)
	if not rows then
		return failure(rowsError)
	end
	local results = {}
	for _, row in ipairs(rows) do
		results[#results + 1] = { id = tostring(row.character_id), name = fullName(row), stateId = row.state_id }
	end
	return { ok = true, results = results }
end

actions.person = function(cop, payload)
	local subjectId, idError = MdtRules.CharacterId(payload.id)
	if not subjectId then
		return failure(idError)
	end
	local blocked = guardLookup(cop, 'person', subjectId)
	if blocked then
		return failure(blocked)
	end
	local character = MdtPersistence.Character(subjectId)
	if not character then
		return failure(character == false and 'unknown_character' or 'database_error')
	end

	local records = resourceCall('coe_police', 'Records', cop.source, subjectId, config.Limits.PersonRecords)
	if type(records) ~= 'table' or records.error then
		records = {}
	end
	local warrants = MdtPersistence.Warrants(subjectId, 'active', config.Limits.PersonWarrants) or {}
	local reports = MdtPersistence.Reports(subjectId, config.Limits.PersonReports) or {}
	local names = nameMap({ warrants, reports, records }, { 'issued_by', 'author_id', 'officer_id' })

	local vehicles = {}
	local owned = resourceCall('coe_vehicles', 'ListByOwner', subjectId)
	if type(owned) == 'table' and not owned.error then
		for _, vehicle in ipairs(owned) do
			vehicles[#vehicles + 1] = { plate = vehicle.plate, model = vehicle.model }
		end
	end

	local out = { ok = true, person = { id = subjectId, name = fullName(character), stateId = character.state_id } }
	out.records = {}
	for _, row in ipairs(records) do
		out.records[#out.records + 1] = {
			kind = row.kind, detail = row.detail, amount = tonumber(row.amount) or 0, minutes = tonumber(row.minutes) or 0,
			officer = names[tostring(row.officer_id)] or '?', at = stamp(row.created_at)
		}
	end
	out.warrants = {}
	for _, row in ipairs(warrants) do
		out.warrants[#out.warrants + 1] = {
			id = tonumber(row.id), charge = row.charge, note = row.note, officer = names[tostring(row.issued_by)] or '?', at = stamp(row.created_at)
		}
	end
	out.reports = {}
	for _, row in ipairs(reports) do
		out.reports[#out.reports + 1] = { id = tonumber(row.id), title = row.title, author = names[tostring(row.author_id)] or '?', at = stamp(row.created_at) }
	end
	out.vehicles = vehicles
	return out
end

actions.plate = function(cop, payload)
	local plate, plateError = MdtRules.Plate(payload.plate)
	if not plate then
		return failure(plateError)
	end
	local blocked = guardLookup(cop, 'plate', plate)
	if blocked then
		return failure(blocked)
	end
	local vehicle = resourceCall('coe_vehicles', 'GetByPlate', plate)
	if type(vehicle) ~= 'table' or vehicle.error then
		return failure('unknown_plate')
	end
	local owner = vehicle.ownerCharacterId and MdtPersistence.Character(tostring(vehicle.ownerCharacterId))
	local bulletins = MdtPersistence.Bulletins(plate, os.time(), config.Limits.Bulletins) or {}
	local list = {}
	for _, row in ipairs(bulletins) do
		list[#list + 1] = { id = tonumber(row.id), title = row.title, body = row.body }
	end
	return {
		ok = true,
		vehicle = { plate = vehicle.plate, model = vehicle.model },
		owner = owner and { id = tostring(owner.character_id), name = fullName(owner), stateId = owner.state_id } or nil,
		bulletins = list
	}
end

actions.warrants = function(cop)
	local rows, rowsError = MdtPersistence.Warrants(nil, 'active', config.Limits.Warrants)
	if not rows then
		return failure(rowsError)
	end
	local blocked = guardLookup(cop, 'warrants', '')
	if blocked then
		return failure(blocked)
	end
	local names = nameMap({ rows }, { 'subject_id', 'issued_by' })
	local list = {}
	for _, row in ipairs(rows) do
		list[#list + 1] = {
			id = tonumber(row.id), subjectId = tostring(row.subject_id), subject = names[tostring(row.subject_id)] or '?',
			charge = row.charge, note = row.note, officer = names[tostring(row.issued_by)] or '?', at = stamp(row.created_at)
		}
	end
	return { ok = true, warrants = list }
end

actions.warrant_issue = function(cop, payload)
	local subjectId, idError = MdtRules.CharacterId(payload.subjectId)
	local charge, chargeError = MdtRules.Charge(payload.charge)
	local note, noteError = MdtRules.Text(payload.note == nil and '' or payload.note, 0, 200, false)
	if not subjectId or not charge or not note then
		return failure(idError or chargeError or noteError)
	end
	if subjectId == cop.characterId then
		return failure('same_character')
	end
	local blocked = guardWrite(cop)
	if blocked then
		return failure(blocked)
	end
	local character = MdtPersistence.Character(subjectId)
	if not character then
		return failure(character == false and 'unknown_character' or 'database_error')
	end
	local active, countError = MdtPersistence.CountActiveWarrants(subjectId)
	if not active then
		return failure(countError)
	end
	if active >= config.MaxActiveWarrantsPerCharacter then
		return failure('too_many_warrants')
	end
	local saved, saveError = MdtPersistence.IssueWarrant(subjectId, cop.characterId, cop.businessId, charge, note)
	if not saved then
		return failure(saveError)
	end
	audit('mdt.warrant_issued', { action = 'warrant_issue', character_id = cop.characterId, target = subjectId, result = charge })
	TriggerEvent('coe_mdt:warrantIssued', cop.source, subjectId, charge)
	return { ok = true }
end

actions.warrant_close = function(cop, payload)
	local id, idError = MdtRules.Id(payload.id)
	local status = payload.status
	if not id or not MdtRules.CanCloseWarrant('active', status) then
		return failure(idError or 'invalid_status')
	end
	local blocked = guardWrite(cop)
	if blocked then
		return failure(blocked)
	end
	local warrant = MdtPersistence.Warrant(id)
	if not warrant then
		return failure(warrant == false and 'unknown_warrant' or 'database_error')
	end
	local closed, closeError = MdtPersistence.CloseWarrant(id, status, cop.characterId)
	if closed == nil then
		return failure(closeError)
	end
	if not closed then
		return failure('already_closed')
	end
	audit('mdt.warrant_' .. status, { action = 'warrant_close', character_id = cop.characterId, target = tostring(warrant.subject_id), result = status })
	TriggerEvent('coe_mdt:warrantClosed', cop.source, tostring(warrant.subject_id), status)
	return { ok = true }
end

actions.bulletins = function()
	local rows, rowsError = MdtPersistence.Bulletins(nil, os.time(), config.Limits.Bulletins)
	if not rows then
		return failure(rowsError)
	end
	local names = nameMap({ rows }, { 'issued_by' })
	local list = {}
	for _, row in ipairs(rows) do
		list[#list + 1] = {
			id = tonumber(row.id), title = row.title, body = row.body, plate = row.plate,
			officer = names[tostring(row.issued_by)] or '?', expiresAt = tonumber(row.expires_at) or 0
		}
	end
	return { ok = true, bulletins = list }
end

actions.bulletin_issue = function(cop, payload)
	local title, titleError = MdtRules.Text(payload.title, 3, 60, false)
	local body, bodyError = MdtRules.Text(payload.body, 3, 300, false)
	local hours, hoursError = MdtRules.BulletinHours(payload.hours, config)
	if not title or not body or not hours then
		return failure(titleError or bodyError or hoursError)
	end
	local plate
	if payload.plate ~= nil and payload.plate ~= '' then
		local plateError
		plate, plateError = MdtRules.Plate(payload.plate)
		if not plate then
			return failure(plateError)
		end
	end
	local blocked = guardWrite(cop)
	if blocked then
		return failure(blocked)
	end
	local saved, saveError = MdtPersistence.IssueBulletin(cop.characterId, cop.businessId, title, body, plate, os.time() + hours * 3600)
	if not saved then
		return failure(saveError)
	end
	audit('mdt.bulletin_issued', { action = 'bulletin_issue', character_id = cop.characterId, plate = plate })
	return { ok = true }
end

actions.bulletin_close = function(cop, payload)
	local id, idError = MdtRules.Id(payload.id)
	if not id then
		return failure(idError)
	end
	local blocked = guardWrite(cop)
	if blocked then
		return failure(blocked)
	end
	local closed, closeError = MdtPersistence.CloseBulletin(id)
	if closed == nil then
		return failure(closeError)
	end
	if not closed then
		return failure('unknown_bulletin')
	end
	audit('mdt.bulletin_closed', { action = 'bulletin_close', character_id = cop.characterId, result = tostring(id) })
	return { ok = true }
end

actions.reports = function(cop, payload)
	local subjectId
	if payload.subjectId ~= nil and payload.subjectId ~= '' then
		local idError
		subjectId, idError = MdtRules.CharacterId(payload.subjectId)
		if not subjectId then
			return failure(idError)
		end
	end
	local blocked = guardLookup(cop, 'reports', subjectId or '')
	if blocked then
		return failure(blocked)
	end
	local rows, rowsError = MdtPersistence.Reports(subjectId, config.Limits.Reports)
	if not rows then
		return failure(rowsError)
	end
	local names = nameMap({ rows }, { 'author_id', 'subject_id' })
	local list = {}
	for _, row in ipairs(rows) do
		list[#list + 1] = {
			id = tonumber(row.id), title = row.title, body = row.body, author = names[tostring(row.author_id)] or '?',
			subject = row.subject_id and (names[tostring(row.subject_id)] or '?') or nil, at = stamp(row.created_at)
		}
	end
	return { ok = true, reports = list }
end

actions.report_create = function(cop, payload)
	local title, titleError = MdtRules.Text(payload.title, 3, 80, false)
	local body, bodyError = MdtRules.Text(payload.body, 3, 1000, true)
	if not title or not body then
		return failure(titleError or bodyError)
	end
	local subjectId
	if payload.subjectId ~= nil and payload.subjectId ~= '' then
		local idError
		subjectId, idError = MdtRules.CharacterId(payload.subjectId)
		if not subjectId then
			return failure(idError)
		end
	end
	local blocked = guardWrite(cop)
	if blocked then
		return failure(blocked)
	end
	if subjectId then
		local character = MdtPersistence.Character(subjectId)
		if not character then
			return failure(character == false and 'unknown_character' or 'database_error')
		end
	end
	local saved, saveError = MdtPersistence.AddReport(cop.characterId, cop.businessId, subjectId, title, body)
	if not saved then
		return failure(saveError)
	end
	audit('mdt.report_created', { action = 'report_create', character_id = cop.characterId, target = subjectId })
	return { ok = true }
end

local PERMISSION = {
	calls = 'mdt.access', accept = 'mdt.access', close = 'mdt.access',
	lookup = 'mdt.lookup', person = 'mdt.lookup', plate = 'mdt.lookup',
	warrants = 'mdt.access', warrant_issue = 'mdt.warrant_issue', warrant_close = 'mdt.warrant_close',
	bulletins = 'mdt.access', bulletin_issue = 'mdt.bulletins', bulletin_close = 'mdt.bulletins',
	reports = 'mdt.reports', report_create = 'mdt.reports'
}

-- Ponto único de entrada: coe_tablet:call -> TabletCall(playerId, appId, action, payload).
exports('TabletCall', function(playerId, appId, action, payload)
	if config.TabletResources[GetInvokingResource() or ''] ~= true or appId ~= 'mdt' then
		return failure('forbidden')
	end
	local handler = type(action) == 'string' and actions[action] or nil
	if not handler then
		return failure('unknown_action')
	end
	local cop, copError = officer(tonumber(playerId), PERMISSION[action])
	if not cop then
		return failure(copError)
	end
	local ok, result = pcall(handler, cop, type(payload) == 'table' and payload or {})
	if not ok then
		log('error', 'mdt', 'action_failed', { action = action, error_code = tostring(result):sub(1, 96) })
		return failure('internal_error')
	end
	return result
end)

-- Registro de acessos para a corregedoria (somente resources autorizados).
exports('AccessLog', function(subject, limit)
	if config.AuditResources[GetInvokingResource() or ''] ~= true then
		return { error = 'forbidden' }
	end
	local cleanSubject = type(subject) == 'string' and #subject <= 24 and subject or nil
	local rows, rowsError = MdtPersistence.AccessLog(cleanSubject, MdtRules.Limit(limit, 50, config.Limits.AccessLog))
	return rows or { error = rowsError }
end)

AddEventHandler('playerDropped', function()
	local characterId = characterOf(source)
	if characterId then
		lookupStamps[characterId], writeStamps[characterId] = nil, nil
	end
end)

local function registerPermissions()
	return businessCall('RegisterPermissions', config.Permissions) == true
end

AddEventHandler('onResourceStart', function(name)
	if name == 'coe_businesses' then
		SetTimeout(2000, registerPermissions)
	end
end)

CreateThread(function()
	local waitingLogged = false
	while true do
		local initialized, errorCode = MdtPersistence.Initialize()
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
	ready = true
	for _ = 1, 30 do
		if registerPermissions() then
			break
		end
		Wait(2000)
	end
	log('info', 'system', 'mdt_ready', {})
end)
