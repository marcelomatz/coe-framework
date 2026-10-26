-- coe_staff (servidor): painel básico da staff para testar o servidor. Cada ação é autorizada aqui pela ACE do
-- módulo (ou coe.staff.all), validada e auditada; efeitos no mundo vão como eventos para o client certo.
-- Um pacote com painel completo assume pelo export Yield (ACE coe.staff.yield).
local config = StaffConfig

local yieldedBy = nil
local lastAction = {}
local frozen = {}

local rawLocales = (type(Locales) == 'table' and Locales) or {}
local _t_inst = (Core and Core.Locale and Core.Locale.New) and Core.Locale.New({
	default = (config and config.Locale) or (Core and Core.Locale and Core.Locale.GetDefaultLang()) or 'pt-BR',
	locales = rawLocales
})
local _t = function(k, params)
	if type(_t_inst) == 'table' and _t_inst.T then
		return _t_inst:T(k, params)
	elseif type(_t_inst) == 'function' then
		return _t_inst(k, params)
	end
	local text = (rawLocales['pt-BR'] and rawLocales['pt-BR'][k]) or k
	for name, value in pairs(params or {}) do
		text = text:gsub('%%{' .. name .. '}', (tostring(value):gsub('%%', '%%%%')))
	end
	return text
end

local function log(level, category, event, context)
	pcall(function()
		return exports.coe_logging:Log(level, category, event, context)
	end)
end

local function audit(event, context)
	pcall(function()
		return exports.coe_audit:Record('info', 'admin', event, context)
	end)
end

local function notify(playerId, kind, message)
	pcall(function()
		exports.coe_notify:Notify(playerId, kind, message)
	end)
end

local function started(resource)
	return GetResourceState(resource) == 'started'
end

-- Export de outro resource (só o primeiro retorno); nil se o resource não está de pé ou falhou.
local function remote(resource, name, ...)
	if not started(resource) then
		return nil
	end
	local args = table.pack(...)
	local ok, result = pcall(function()
		local target = exports[resource]
		local fn = target and target[name]
		if type(fn) ~= 'function' then
			error('export_not_found')
		end
		return fn(target, table.unpack(args, 1, args.n))
	end)
	if not ok then
		log('warn', 'system', 'staff_remote_failed', { action = resource .. ':' .. name, error_code = tostring(result):sub(1, 96) })
		return nil
	end
	return result
end

local function callDatabase(sql, params)
	if not started('coe_database') then
		return nil
	end
	local response = promise.new()
	local database = exports['coe_database']
	if not pcall(function()
		database:Query(sql, params, function(success, result)
			response:resolve({ success = success == true, result = result })
		end)
	end) then
		return nil
	end
	local result = Citizen.Await(response)
	return result.success and result.result or nil
end

local txAdmins = {}

AddEventHandler('txAdmin:events:adminAuth', function(eventData)
	if type(eventData) ~= 'table' then
		return
	end
	local netid = tonumber(eventData.netid)
	if not netid then
		return
	end
	if netid == -1 then
		txAdmins = {}
		return
	end
	if eventData.isAdmin == true then
		txAdmins[netid] = true
	else
		txAdmins[netid] = nil
	end
end)

local function isAllowed(playerId, ace)
	local numId = tonumber(playerId)
	if (numId and txAdmins[numId] == true) or txAdmins[playerId] == true then
		return true
	end
	return IsPlayerAceAllowed(playerId, ace) == 1 or IsPlayerAceAllowed(playerId, ace) == true
end

local function modulesOf(playerId)
	return StaffRules.Modules(config, function(ace)
		return isAllowed(playerId, ace)
	end)
end

local function coordsOf(playerId)
	local ped = GetPlayerPed(playerId)
	if not ped or ped == 0 then
		return nil
	end
	local c = GetEntityCoords(ped)
	return { x = c.x, y = c.y, z = c.z }
end

local function characterOf(playerId)
	local snapshot = Core.Players.GetActiveCharacter(playerId)
	if type(snapshot) ~= 'table' or not snapshot.characterId then
		return nil
	end
	local parts = {}
	for _, part in ipairs({ snapshot.firstName, snapshot.lastName }) do
		if type(part) == 'string' and part ~= '' then
			parts[#parts + 1] = part
		end
	end
	return {
		characterId = tostring(snapshot.characterId), stateId = snapshot.stateId,
		name = #parts > 0 and table.concat(parts, ' ') or tostring(snapshot.stateId or '')
	}
end

local function online(target)
	target = tonumber(target)
	return target and GetPlayerName(target) ~= nil and target or nil
end

-- Personagem pelo ID de cidadão: online pela sessão; offline pelo cadastro.
local function characterByStateId(value)
	local stateId = StaffRules.StateId(value)
	if not stateId then
		return nil, 'invalid_state_id'
	end
	local session = Core.Players.GetPlayerByStateId(stateId)
	if type(session) == 'table' and session.source then
		local who = characterOf(session.source)
		if who then
			return who
		end
	end
	local rows = callDatabase(
		'SELECT character_id, first_name, last_name FROM coe_characters WHERE state_id = ? AND archived_at IS NULL LIMIT 1',
		{ stateId })
	local row = rows and rows[1]
	if not row then
		return nil, 'character_not_found'
	end
	return { characterId = tostring(row.character_id), stateId = stateId, name = ((row.first_name or '') .. ' ' .. (row.last_name or '')):gsub('^%s+', ''):gsub('%s+$', '') }
end

local function effect(target, kind, data)
	TriggerClientEvent('coe_staff:effect', target, kind, data)
end

-- Ações ------------------------------------------------------------------------------------------------------

local A = {}

local function restorePlayerNeeds(target)
	if not started('coe_needs') then
		return
	end
	remote('coe_needs', 'SetNeed', target, 'hunger', 100)
	remote('coe_needs', 'SetNeed', target, 'thirst', 100)
	remote('coe_needs', 'SetNeed', target, 'stress', 0)
	remote('coe_needs', 'SetNeed', target, 'alcohol', 0)
	remote('coe_needs', 'SetNeed', target, 'drugs', 0)
end

-- Ferramentas pessoais: o servidor só autoriza (e audita as que importam); o client do admin aplica.
for _, name in ipairs({ 'noclip', 'invisible', 'godmode', 'heal', 'revive', 'tpWaypoint' }) do
	A[name] = function(admin, data)
		if name == 'noclip' or name == 'invisible' or name == 'godmode' then
			audit('staff_' .. name, { source = admin, result = data.on == true and 'on' or 'off' })
		elseif name == 'heal' or name == 'revive' then
			restorePlayerNeeds(admin)
		end
		return { ok = true }
	end
end

function A.tpCoords(_, data)
	local at = StaffRules.Coords(data)
	if not at then
		return { ok = false, error = 'invalid_coords' }
	end
	return { ok = true, data = at }
end

function A.updateStatus()
	return { ok = true, data = { update = remote('coe_supervisor', 'GetUpdateStatus') } }
end

function A.checkUpdate(admin)
	local status = remote('coe_supervisor', 'CheckForUpdates', admin)
	audit('staff_check_update', { source = admin })
	return { ok = true, data = { update = status } }
end

function A.applyUpdate(admin)
	if not started('coe_supervisor') then
		return { ok = false, error = 'unavailable' }
	end
	local callOk, applied, detail = pcall(function()
		return exports.coe_supervisor:ApplyUpdate(admin)
	end)
	if not callOk or not applied then
		return { ok = false, error = type(detail) == 'string' and detail or 'update_download_failed' }
	end
	audit('staff_apply_update', {
		source = admin,
		operation = type(detail) == 'table' and tostring(detail.version or '') or 'update'
	})
	if type(detail) == 'table' and detail.version then
		notify(admin, 'success', _t('update_applied_notify', {
			version = tostring(detail.version),
			files = tostring(detail.filesUpdated or 0)
		}))
	end
	return {
		ok = true,
		data = {
			result = detail,
			update = remote('coe_supervisor', 'GetUpdateStatus')
		}
	}
end

-- Jogadores ---------------------------------------------------------------------------------------------------

function A.players()
	local list = {}
	for _, id in ipairs(GetPlayers()) do
		local playerId = tonumber(id)
		local who = playerId and characterOf(playerId)
		list[#list + 1] = {
			id = playerId, name = GetPlayerName(playerId), ping = GetPlayerPing(playerId),
			character = who and who.name or nil, stateId = who and who.stateId or nil, frozen = frozen[playerId] == true
		}
	end
	table.sort(list, function(a, b) return a.id < b.id end)
	return { ok = true, data = { players = list } }
end

function A.items(_, data)
	return { ok = true, data = { items = StaffRules.ItemList(remote('coe_inventory', 'Items'), data.search, 120) } }
end

local function targetOf(data)
	local target = online(data.target)
	if not target then
		return nil, { ok = false, error = 'player_offline' }
	end
	return target
end

function A.gotoPlayer(admin, data)
	local target, err = targetOf(data)
	if not target then return err end
	local at = coordsOf(target)
	if not at then
		return { ok = false, error = 'player_offline' }
	end
	audit('staff_goto', { source = admin, target = target })
	return { ok = true, data = at }
end

function A.bringPlayer(admin, data)
	local target, err = targetOf(data)
	if not target then return err end
	local at = coordsOf(admin)
	effect(target, 'teleport', at)
	audit('staff_bring', { source = admin, target = target })
	return { ok = true }
end

function A.freezePlayer(admin, data)
	local target, err = targetOf(data)
	if not target then return err end
	local on = data.on == true
	frozen[target] = on or nil
	effect(target, 'freeze', { on = on })
	audit('staff_freeze', { source = admin, target = target, result = on and 'on' or 'off' })
	return { ok = true }
end

function A.kickPlayer(admin, data)
	local target, err = targetOf(data)
	if not target then return err end
	if target == admin then
		return { ok = false, error = 'self_target' }
	end
	local reason = StaffRules.Text(data.reason or '', config.Limits.MaxKickReason) or _t('kick_default')
	audit('staff_kick', { source = admin, target = target })
	DropPlayer(target, _t('kick_message', { reason = reason }))
	return { ok = true }
end

function A.healPlayer(admin, data)
	local target, err = targetOf(data)
	if not target then return err end
	restorePlayerNeeds(target)
	effect(target, 'heal')
	audit('staff_heal', { source = admin, target = target })
	return { ok = true }
end

function A.revivePlayer(admin, data)
	local target, err = targetOf(data)
	if not target then return err end
	restorePlayerNeeds(target)
	effect(target, 'revive')
	audit('staff_revive', { source = admin, target = target })
	return { ok = true }
end

function A.giveItem(admin, data)
	local target, err = targetOf(data)
	if not target then return err end
	local item = StaffRules.ItemName(data.item)
	local count = StaffRules.Integer(data.count or 1, 1, config.Limits.MaxItemCount)
	if not item or not count or not remote('coe_inventory', 'Items', item) then
		return { ok = false, error = 'invalid_item' }
	end
	local inventoryId = remote('coe_inventory', 'GetPlayerInventory', target)
	if not inventoryId then
		return { ok = false, error = 'no_character' }
	end
	if remote('coe_inventory', 'AddItem', inventoryId, item, count) ~= true then
		return { ok = false, error = 'inventory_full' }
	end
	audit('staff_give_item', { source = admin, target = target, item = item, count = count })
	notify(target, 'info', _t('item_received', { count = count, item = item }))
	return { ok = true }
end

function A.money(admin, data)
	local target, err = targetOf(data)
	if not target then return err end
	local amount = StaffRules.Integer(data.amount, 1, config.Limits.MaxMoney)
	if not amount then
		return { ok = false, error = 'invalid_amount' }
	end
	local take = data.op == 'take'
	local who = characterOf(target)
	if not who then
		return { ok = false, error = 'no_character' }
	end
	local done
	if data.kind == 'cash' then
		local inventoryId = remote('coe_inventory', 'GetPlayerInventory', target)
		if take then
			done = inventoryId and remote('coe_inventory', 'RemoveItemByName', inventoryId, 'money', amount) == true
		else
			done = inventoryId and remote('coe_inventory', 'AddItem', inventoryId, 'money', amount) == true
		end
	elseif data.kind == 'bank' then
		done = remote('coe_economy', take and 'Debit' or 'Credit', who.characterId, amount, config.MoneyReason, 'staff') == true
	else
		return { ok = false, error = 'invalid_kind' }
	end
	if not done then
		return { ok = false, error = take and 'insufficient_funds' or 'money_failed' }
	end
	audit(take and 'staff_money_take' or 'staff_money_give', { source = admin, target = target, count = amount, item = data.kind })
	return { ok = true }
end

function A.groups(_, data)
	local target, err = targetOf(data)
	if not target then return err end
	return { ok = true, data = {
		current = remote('coe_core', 'GetPlayerGroups', target) or {},
		definitions = remote('coe_core', 'GetGroupDefinitions') or {}
	} }
end

-- Grupos: o coe_core grava de forma assíncrona; a resposta vem pelo callback.
local function groupCall(admin, exportName, target, ...)
	local p = promise.new()
	local args = { ... }
	args[#args + 1] = function(ok, _, errorCode)
		p:resolve({ ok = ok == true, error = errorCode })
	end
	local dispatched = remote('coe_core', exportName, target, table.unpack(args))
	if dispatched ~= true then
		return { ok = false, error = type(dispatched) == 'string' and dispatched or 'group_failed' }
	end
	SetTimeout(10000, function() p:resolve({ ok = false, error = 'timeout' }) end)
	local result = Citizen.Await(p)
	if result.ok then
		audit('staff_' .. exportName:lower(), { source = admin, target = target })
	end
	return result.ok and { ok = true } or { ok = false, error = tostring(result.error or 'group_failed') }
end

function A.setGroup(admin, data)
	local target, err = targetOf(data)
	if not target then return err end
	local grade = StaffRules.Integer(data.grade or 0, 0, 255)
	if type(data.name) ~= 'string' or not data.name:match('^[a-z][a-z0-9_]*$') or not grade then
		return { ok = false, error = 'invalid_group' }
	end
	return groupCall(admin, 'SetPlayerGroup', target, data.name, grade)
end

function A.removeGroup(admin, data)
	local target, err = targetOf(data)
	if not target then return err end
	if type(data.name) ~= 'string' or not data.name:match('^[a-z][a-z0-9_]*$') then
		return { ok = false, error = 'invalid_group' }
	end
	return groupCall(admin, 'RemovePlayerGroup', target, data.name)
end

-- Veículos ----------------------------------------------------------------------------------------------------

function A.catalog(_, data)
	local search = type(data.search) == 'string' and data.search:sub(1, 32) or nil
	local list = remote('coe_vehicle_catalog', 'ListVehicles', { search = search ~= '' and search or nil, limit = config.Limits.VehicleSearch })
	local out = {}
	for _, vehicle in ipairs(type(list) == 'table' and list or {}) do
		out[#out + 1] = { model = vehicle.model, name = vehicle.name, brand = vehicle.brand, class = vehicle.class, type = vehicle.type }
	end
	return { ok = true, data = { vehicles = out, catalog = started('coe_vehicle_catalog') } }
end

-- temp: o client do admin cria o veículo (não fica registrado). owned: registrado no coe_vehicles, do admin, com chave.
function A.spawnVehicle(admin, data)
	local model = StaffRules.Model(data.model)
	if not model then
		return { ok = false, error = 'invalid_model' }
	end
	if data.mode ~= 'owned' then
		audit('staff_vehicle_temp', { source = admin, model = model })
		return { ok = true, data = { model = model } }
	end
	local who = characterOf(admin)
	if not who then
		return { ok = false, error = 'no_character' }
	end
	local info = remote('coe_vehicle_catalog', 'GetVehicleInfo', model)
	local record = remote('coe_vehicles', 'Create', { characterId = who.characterId, model = model })
	if type(record) ~= 'table' or not record.id then
		return { ok = false, error = type(record) == 'string' and record or 'vehicle_failed' }
	end
	local ped = GetPlayerPed(admin)
	local at = coordsOf(admin)
	local netId = remote('coe_vehicles', 'Spawn', record.id, at.x, at.y, at.z, GetEntityHeading(ped), type(info) == 'table' and info.type or nil)
	if type(netId) ~= 'number' then
		return { ok = false, error = type(netId) == 'string' and netId or 'spawn_failed' }
	end
	audit('staff_vehicle_owned', { source = admin, model = model, vehicle_id = record.id, plate = record.plate })
	return { ok = true, data = { netId = netId, plate = record.plate } }
end

-- Apaga o veículo (registrado: guardado pelo coe_vehicles; solto: removido).
function A.deleteVehicle(admin, data)
	local netId = StaffRules.Integer(data.netId, 1, 2 ^ 31)
	local entity = netId and NetworkGetEntityFromNetworkId(netId)
	if not entity or entity == 0 or not DoesEntityExist(entity) or GetEntityType(entity) ~= 2 then
		return { ok = false, error = 'no_vehicle' }
	end
	local vehicleId = Entity(entity).state['coe:vehicleId']
	if vehicleId then
		local stored = remote('coe_vehicles', 'Store', vehicleId)
		if stored ~= true then
			return { ok = false, error = type(stored) == 'string' and stored or 'vehicle_failed' }
		end
	else
		DeleteEntity(entity)
	end
	audit('staff_vehicle_delete', { source = admin, vehicle_id = vehicleId })
	return { ok = true }
end

-- Consertar, abastecer, limpar e desvirar acontecem no client de quem controla o veículo; aqui só a autorização.
function A.vehicleFix(admin, data)
	if data.op ~= 'repair' and data.op ~= 'refuel' and data.op ~= 'clean' and data.op ~= 'flip' then
		return { ok = false, error = 'invalid_action' }
	end
	audit('staff_vehicle_' .. data.op, { source = admin })
	return { ok = true }
end

-- Mundo -------------------------------------------------------------------------------------------------------

local world = { version = 0 }

local function publishWorld()
	world.version = world.version + 1
	GlobalState.coeStaffWorld = (world.time or world.weather) and {
		version = world.version, time = world.time, weather = world.weather
	} or false
end

function A.world()
	local hotel = nil
	if started('coe_spawn') then
		pcall(function()
			hotel = exports.coe_spawn:GetStarterHotel()
		end)
	end
	return { ok = true, data = { time = world.time, weather = world.weather, weathers = config.Weathers, hotel = hotel } }
end

function A.getMyCoords(admin)
	local ped = GetPlayerPed(admin)
	if not ped or ped == 0 then return { ok = false, error = 'player_ped_missing' } end
	local c = GetEntityCoords(ped)
	local h = GetEntityHeading(ped)
	return {
		ok = true,
		data = {
			x = math.floor(c.x * 100 + 0.5) / 100,
			y = math.floor(c.y * 100 + 0.5) / 100,
			z = math.floor(c.z * 100 + 0.5) / 100,
			h = math.floor(h * 100 + 0.5) / 100
		}
	}
end

function A.saveStarterHotel(admin, data)
	if not started('coe_spawn') then
		return { ok = false, error = 'spawn_unavailable' }
	end
	local ok, err = pcall(function()
		return exports.coe_spawn:SetStarterHotel(data)
	end)
	if not ok or not err then
		return { ok = false, error = 'hotel_save_failed' }
	end
	audit('staff_hotel_saved', { source = admin, name = data and data.name, enabled = data and data.enabled })
	return A.world()
end

function A.teleportToHotel(admin, data)
	local point = data and data.point
	local hotel = nil
	if started('coe_spawn') then
		pcall(function()
			hotel = exports.coe_spawn:GetStarterHotel()
		end)
	end
	if not hotel then return { ok = false, error = 'hotel_unavailable' } end
	local target = (point == 'room') and hotel.room or hotel.entrance
	effect(admin, 'teleport', { x = target.x, y = target.y, z = target.z, heading = target.h or 0.0 })
	audit('staff_hotel_teleport', { source = admin, point = point })
	return { ok = true }
end

function A.setTime(admin, data)
	local time = StaffRules.Time(data)
	if not time then
		return { ok = false, error = 'invalid_time' }
	end
	world.time = time
	publishWorld()
	audit('staff_world_time', { source = admin, result = ('%02d:%02d'):format(time.hour, time.minute) })
	return A.world()
end

function A.setWeather(admin, data)
	local weather = StaffRules.Weather(config, data.weather)
	if not weather then
		return { ok = false, error = 'invalid_weather' }
	end
	world.weather = weather
	publishWorld()
	audit('staff_world_weather', { source = admin, result = weather })
	return A.world()
end

function A.resetWorld(admin)
	world.time, world.weather = nil, nil
	publishWorld()
	audit('staff_world_reset', { source = admin })
	return A.world()
end

function A.announce(admin, data)
	local text = StaffRules.Text(data.text, config.Limits.MaxAnnouncement)
	if not text then
		return { ok = false, error = 'invalid_text' }
	end
	for _, id in ipairs(GetPlayers()) do
		notify(tonumber(id), 'info', _t('announcement', { text = text }))
	end
	audit('staff_announce', { source = admin })
	return { ok = true }
end

-- Negócios ----------------------------------------------------------------------------------------------------

local function businessesReady()
	return started('coe_businesses') and remote('coe_businesses', 'IsReady') == true
end

function A.businesses()
	if not businessesReady() then
		return { ok = false, error = 'businesses_unavailable' }
	end
	local list = {}
	for _, business in ipairs(remote('coe_businesses', 'List') or {}) do
		list[#list + 1] = StaffRules.BusinessSummary(business)
	end
	local categories = {}
	for id, category in pairs(remote('coe_businesses', 'Categories') or {}) do
		categories[#categories + 1] = { id = id, label = category.label, stations = category.stations, rules = category.rules }
	end
	table.sort(categories, function(a, b) return a.label < b.label end)
	return { ok = true, data = {
		businesses = list, categories = categories, rules = remote('coe_businesses', 'RuleSchema') or {},
		permissions = StaffRules.PermissionsList(remote('coe_businesses', 'Permissions'))
	} }
end

local function businessView(id)
	local business = remote('coe_businesses', 'Get', id)
	if type(business) ~= 'table' then
		return { ok = false, error = 'unknown_business' }
	end
	return { ok = true, data = { business = business } }
end

function A.business(_, data)
	if not businessesReady() then
		return { ok = false, error = 'businesses_unavailable' }
	end
	return businessView(data.id)
end

local function saveBusiness(admin, business, event)
	local result = remote('coe_businesses', 'Save', business, 'staff:' .. tostring(admin))
	if type(result) ~= 'table' or result.error then
		return { ok = false, error = type(result) == 'table' and tostring(result.error) or 'businesses_unavailable' }
	end
	audit(event, { source = admin, operation = business.id })
	return businessView(business.id)
end

function A.businessCreate(admin, data)
	if not businessesReady() then
		return { ok = false, error = 'businesses_unavailable' }
	end
	local business, errorCode = StaffRules.NewBusiness(config, remote('coe_businesses', 'Categories'), data, coordsOf(admin))
	if not business then
		return { ok = false, error = errorCode }
	end
	if remote('coe_businesses', 'Get', business.id) then
		return { ok = false, error = 'id_taken' }
	end
	return saveBusiness(admin, business, 'staff_business_create')
end

local NEEDS_CHARACTER = { businessOwner = true, staffAdd = true }

local function editBusiness(op)
	return function(admin, data)
		if not businessesReady() then
			return { ok = false, error = 'businesses_unavailable' }
		end
		local business = remote('coe_businesses', 'Get', data.id)
		if type(business) ~= 'table' then
			return { ok = false, error = 'unknown_business' }
		end
		local character = nil
		if NEEDS_CHARACTER[op] and not (op == 'businessOwner' and (data.stateId == nil or data.stateId == '')) then
			local errorCode
			character, errorCode = characterByStateId(data.stateId)
			if not character then
				return { ok = false, error = errorCode }
			end
		end
		local updated, editError = StaffRules.Edit(config, business, op, data, {
			at = coordsOf(admin), categories = remote('coe_businesses', 'Categories'),
			rules = remote('coe_businesses', 'RuleSchema'), character = character
		})
		if not updated then
			return { ok = false, error = editError }
		end
		return saveBusiness(admin, updated, 'staff_' .. op:gsub('%u', function(c) return '_' .. c:lower() end))
	end
end

for _, op in ipairs({ 'businessInfo', 'businessArea', 'stationAdd', 'stationRemove', 'businessOwner', 'staffAdd',
	'staffGrade', 'staffRemove', 'gradeAdd', 'gradeRemove' }) do
	A[op] = editBusiness(op)
end

function A.businessDelete(admin, data)
	if not businessesReady() then
		return { ok = false, error = 'businesses_unavailable' }
	end
	local result = remote('coe_businesses', 'Delete', data.id, 'staff:' .. tostring(admin))
	if result ~= true then
		return { ok = false, error = type(result) == 'table' and tostring(result.error) or 'unknown_business' }
	end
	audit('staff_business_delete', { source = admin, operation = tostring(data.id) })
	return A.businesses()
end

-- Ir até o negócio: o centro da área.
function A.businessGoto(_, data)
	local business = businessesReady() and remote('coe_businesses', 'Get', data.id)
	local area = type(business) == 'table' and business.area
	if type(area) ~= 'table' then
		return { ok = false, error = 'unknown_business' }
	end
	if area.kind == 'circle' then
		return { ok = true, data = { x = area.x, y = area.y, z = area.z } }
	end
	local sx, sy = 0, 0
	for _, p in ipairs(area.points or {}) do
		sx, sy = sx + p.x, sy + p.y
	end
	local n = math.max(1, #(area.points or {}))
	return { ok = true, data = { x = sx / n, y = sy / n, z = area.z or 0 } }
end

-- Pedidos -----------------------------------------------------------------------------------------------------

local function fail(errorCode)
	local message = _t(errorCode)
	return { ok = false, error = errorCode, message = message ~= errorCode and message or _t('generic_error') }
end

local function handle(admin, action, data)
	if yieldedBy then
		return fail('unavailable')
	end
	local modules, any = modulesOf(admin)
	if not any then
		notify(admin, 'error', _t('forbidden'))
		return fail('forbidden')
	end
	local allowed = StaffRules.Allowed(modules, action)
	if not allowed or not A[action] then
		notify(admin, 'error', _t('forbidden'))
		log('warn', 'security', 'staff_action_denied', { player_id = admin, action = tostring(action):sub(1, 32) })
		return fail('forbidden')
	end
	local now = GetGameTimer()
	local byAction = lastAction[admin]
	if not byAction then
		byAction = {}
		lastAction[admin] = byAction
	end
	if byAction[action] and now - byAction[action] < config.ActionIntervalMs then
		return fail('busy')
	end
	byAction[action] = now
	local result = A[action](admin, data)
	if type(result) ~= 'table' then
		return fail('generic_error')
	end
	if not result.ok and not result.message then
		local message = _t(tostring(result.error))
		result.message = message ~= result.error and message or nil
	end
	return result
end

RegisterNetEvent('coe_staff:request', function(requestId, action, data)
	local admin = source
	if type(requestId) ~= 'number' or type(action) ~= 'string' or #action > 32 then
		return
	end
	local result
	if data ~= nil and (type(data) ~= 'table' or #json.encode(data) > config.MaxPayloadBytes) then
		result = fail('invalid_payload')
	else
		local ok, value = pcall(handle, admin, action, data or {})
		if not ok then
			log('error', 'system', 'staff_action_failed', { player_id = admin, action = action, error_code = tostring(value):sub(1, 96) })
			value = fail('generic_error')
		end
		result = value
	end
	TriggerClientEvent('coe_staff:response', admin, requestId, result)
end)

-- Abrir: só quem tem algum módulo. A tela recebe os módulos liberados e o estado de atualização.
RegisterNetEvent('coe_staff:open', function()
	local admin = source
	if yieldedBy then
		return
	end
	local modules, any = modulesOf(admin)
	if not any then
		notify(admin, 'error', _t('forbidden'))
		return
	end
	log('info', 'security', 'staff_panel_opened', { player_id = admin })
	TriggerClientEvent('coe_staff:opened', admin, {
		modules = modules,
		limits = config.Limits,
		speeds = config.Noclip.Speeds,
		update = remote('coe_supervisor', 'GetUpdateStatus')
	})
end)

AddEventHandler('playerDropped', function()
	local src = tonumber(source) or source
	txAdmins[src] = nil
	if type(src) == 'number' then
		txAdmins[tostring(src)] = nil
	end
	lastAction[src] = nil
	frozen[src] = nil
end)

-- Pacote que assume o painel ------------------------------------------------------------------------------------

local function setYield(resource)
	yieldedBy = resource
	GlobalState.coeStaffYielded = resource or false
	if resource then
		TriggerClientEvent('coe_staff:close', -1)
	end
end

-- O painel básico fecha e para de abrir até o resource chamador parar. Valor único: true ou { error }.
exports('Yield', function()
	local caller = GetInvokingResource()
	if not caller or not CoeAccess.Allowed(caller, config.Ace.Yield) then
		return { error = 'forbidden' }
	end
	if yieldedBy ~= caller then
		setYield(caller)
		log('info', 'system', 'staff_yielded', { action = caller })
	end
	return true
end)

-- { active, yieldedBy }: se o painel básico está atendendo.
exports('Status', function()
	return { active = yieldedBy == nil, yieldedBy = yieldedBy }
end)

AddEventHandler('onResourceStop', function(resource)
	if yieldedBy and resource == yieldedBy then
		setYield(nil)
		log('info', 'system', 'staff_resumed', { action = resource })
	end
end)

GlobalState.coeStaffYielded = false
GlobalState.coeStaffWorld = false

local lastNotifiedVersion = nil

local function notifyAdminsOfUpdate(status)
	if yieldedBy or type(status) ~= 'table' or not status.available or type(status.remoteVersion) ~= 'string' then
		return
	end
	if lastNotifiedVersion == status.remoteVersion then
		return
	end
	lastNotifiedVersion = status.remoteVersion
	for _, id in ipairs(GetPlayers()) do
		local playerId = tonumber(id)
		if playerId then
			local _, any = modulesOf(playerId)
			if any then
				notify(playerId, 'info', _t('update_available_notify', { version = status.remoteVersion }))
			end
		end
	end
end

if type(AddStateBagChangeHandler) == 'function' then
	AddStateBagChangeHandler('coeFrameworkUpdate', 'global', function(_, _, value)
		notifyAdminsOfUpdate(value)
	end)
end
