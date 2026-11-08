local config = CoePhoneConfig
local _t = (Core and Core.Locale and Core.Locale.Bind) and Core.Locale.Bind(Locales) or function(k, p) local s = (Locales and Locales['pt-BR'] and Locales['pt-BR'][k]) or k; if p then for pk, pv in pairs(p) do s = s:gsub('%%{' .. pk .. '}', tostring(pv)) end end; return s end

local ready = false
local lastCall = {}
local callLimiter = PhoneRules.NewRateLimiter and PhoneRules.NewRateLimiter(config.CallCooldownMs) or nil
local lastRefresh = {}
local refreshLimiter = PhoneRules.NewRateLimiter and PhoneRules.NewRateLimiter(1000) or nil
local lastMessage = {}
local messageLimiter = PhoneRules.NewRateLimiter and PhoneRules.NewRateLimiter(config.Messages.CooldownMs) or nil
local lastPhoto = {}
local photoLimiter = PhoneRules.NewRateLimiter and PhoneRules.NewRateLimiter(config.Photos.CooldownMs) or nil
local savingPhoto = {}
local calls = {}
local playerCall = {}
local nextCallId = 0
-- Aparelho que cada jogador está usando e o que ele desbloqueou (serial).
local active = {}
local unlocked = {}
-- Por serial: último jogador visto com o aparelho, dados do aparelho, chips e contatos.
local holderOf = {}
local deviceCache = {}
local simCache = {}
local contactCache = {}
-- Erros de senha por aparelho (passar o celular adiante não zera o bloqueio).
local unlockFails = {}
local binding = {}
local payments = {}
local walletBusy = {}
local upgradeReport = nil

local function log(level, category, event, context)
	pcall(function()
		return exports.coe_logging:Log(level, category, event, context)
	end)
end

local function notify(playerId, kind, message)
	pcall(function()
		exports.coe_notify:Notify(playerId, kind, message)
	end)
end

local function characterIdOf(playerId)
	local id = Core.Players.GetActiveCharacterId(playerId)
	return id and tostring(id) or nil
end

-- Operadora (coe_telecom) é opcional: sem ela, ligações e mensagens são grátis.
-- holder: titular do chip (nil em linha sem titular).
local function telecomAuthorize(number, kind, holder)
	if GetResourceState('coe_telecom') ~= 'started' then
		return { ok = true }
	end
	local called, result = pcall(function()
		return exports.coe_telecom:Authorize(number, kind, holder)
	end)
	if not called or type(result) ~= 'table' then
		return { ok = false, error = 'telecom_unavailable' }
	end
	return result
end

local function telecomCharge(number, kind, seconds, peer, holder)
	if GetResourceState('coe_telecom') ~= 'started' then
		return
	end
	local called, result = pcall(function()
		return exports.coe_telecom:Charge(number, kind, seconds, peer, holder)
	end)
	if not called or type(result) ~= 'table' or not result.ok then
		log('error', 'system', 'phone_charge_failed', { character_id = holder, operation = kind, error_code = type(result) == 'table' and tostring(result.error) or 'call_failed' })
	end
end

local function format(number)
	return PhoneRules.Format(config, number)
end

-- Jogador online com o personagem.
local function playerOfCharacter(characterId)
	for _, value in ipairs(GetPlayers()) do
		local playerId = tonumber(value)
		if characterIdOf(playerId) == characterId then
			return playerId
		end
	end
	return nil
end

-- Inventário ------------------------------------------------------------------------------------------

local function inventoryOf(characterId)
	return 'character:' .. characterId
end

local function inventoryReady()
	return GetResourceState('coe_inventory') == 'started'
end

-- Itens de aparelho do personagem: { { slot, name, metadata } }; nil se o inventário não respondeu.
local function deviceItems(characterId)
	if not inventoryReady() then
		return nil
	end
	local ok, snapshot = pcall(function()
		return exports.coe_inventory:GetInventory(inventoryOf(characterId))
	end)
	if not ok or type(snapshot) ~= 'table' or type(snapshot.items) ~= 'table' then
		return nil
	end
	local list = {}
	for slot, item in pairs(snapshot.items) do
		if type(item) == 'table' and config.Devices[item.name] then
			list[#list + 1] = { slot = tonumber(slot), name = item.name, metadata = item.metadata }
		end
	end
	return list
end

-- O personagem ainda carrega o aparelho com este serial?
local function holdsSerial(characterId, serial)
	if not inventoryReady() then
		return false
	end
	for name in pairs(config.Devices) do
		local ok, count = pcall(function()
			return exports.coe_inventory:GetItemCount(inventoryOf(characterId), name, { serial = serial }, false)
		end)
		if ok and type(count) == 'number' and count > 0 then
			return true
		end
	end
	return false
end

-- Aparelhos e chips ----------------------------------------------------------------------------------

local function decodePrefs(row)
	local raw = nil
	if type(row.data) == 'string' then
		local decoded, value = pcall(json.decode, row.data)
		raw = decoded and type(value) == 'table' and value or nil
	end
	local prefs = {
		settings = PhoneRules.Settings(config, raw),
		layout = raw and type(raw.layout) == 'table' and raw.layout or nil,
		passcode = type(row.passcode) == 'string' and row.passcode ~= '' and row.passcode or false
	}
	if not prefs.passcode then
		prefs.settings.faceId = false
	end
	return prefs
end

local function encodePrefs(prefs)
	local data = {}
	for key, value in pairs(prefs.settings) do
		data[key] = value
	end
	data.layout = prefs.layout
	return json.encode(data)
end

-- { serial, model, owner, face, bound, prefs } ou nil + erro.
local function deviceOf(serial)
	local cached = deviceCache[serial]
	if cached then
		return cached
	end
	local row, errorCode = PhonePersistence.Device(serial)
	if row == nil then
		return nil, errorCode or 'database_error'
	end
	if not row then
		return nil, 'no_device'
	end
	cached = {
		serial = serial,
		model = tostring(row.model),
		owner = row.owner_character ~= nil and tostring(row.owner_character) or nil,
		face = row.face_character ~= nil and tostring(row.face_character) or nil,
		bound = tonumber(row.bound) == 1 or row.bound == true,
		prefs = decodePrefs(row)
	}
	deviceCache[serial] = cached
	return cached
end

local function modelOf(device)
	return config.Models[device.model] or { label = device.model, sims = 1 }
end

-- Chips no aparelho, por slot.
local function simsOf(serial)
	local cached = simCache[serial]
	if cached then
		return cached
	end
	local list, errorCode = PhonePersistence.SimsIn(serial)
	if not list then
		return nil, errorCode or 'database_error'
	end
	simCache[serial] = list
	return list
end

-- Chip novo (número sorteado) no slot 1 do aparelho, com o personagem como titular.
local function issueSim(characterId, serial)
	for _ = 1, 25 do
		local created = PhonePersistence.CreateSim(PhoneRules.Iccid(math.random), PhoneRules.Generate(config, math.random), characterId, serial, 1)
		if created == nil then
			return nil, 'database_error'
		end
		if created then
			simCache[serial] = nil
			log('info', 'system', 'phone_number_assigned', { character_id = characterId })
			return true
		end
	end
	log('error', 'system', 'phone_number_exhausted', { character_id = characterId })
	return nil, 'number_unavailable'
end

-- Dá serial a um item de celular que ainda não tem: reaproveita o aparelho migrado do personagem ou cria um.
-- Quem ainda não é titular de nenhum chip recebe um chip novo junto.
local function bindDevice(characterId, item)
	if binding[characterId] then
		return nil, 'busy'
	end
	binding[characterId] = true
	local serial, errorCode = (function()
		local legacy, legacyError = PhonePersistence.LegacyDevice(characterId)
		if legacy == nil then
			return nil, legacyError or 'database_error'
		end
		local serial = legacy and tostring(legacy.serial) or nil
		for _ = 1, 10 do
			if serial then
				break
			end
			local candidate = PhoneRules.Serial(math.random)
			local created = PhonePersistence.CreateDevice(candidate, config.Devices[item.name], characterId)
			if created == nil then
				return nil, 'database_error'
			end
			serial = created and candidate or nil
		end
		if not serial then
			return nil, 'device_unavailable'
		end
		-- As consultas acima esperam o banco; o slot pode ter mudado. Confere e grava sem ceder (nada roda no meio).
		local ok, stored, storeError = pcall(function()
			local inventory = inventoryOf(characterId)
			local current = exports.coe_inventory:GetSlot(inventory, item.slot)
			if not current or current.name ~= item.name or (type(current.metadata) == 'table' and current.metadata.serial ~= nil) then
				return false, 'slot_changed'
			end
			return exports.coe_inventory:SetItemMetadata(inventory, item.slot, { serial = serial })
		end)
		if not ok or stored ~= true then
			log('error', 'system', 'phone_bind_failed', { character_id = characterId, error_code = tostring(ok and storeError or stored) })
			return nil, 'inventory_unavailable'
		end
		PhonePersistence.BindDevice(serial)
		deviceCache[serial] = nil
		local sims = simsOf(serial)
		if sims and #sims == 0 and PhonePersistence.HeldNumber(characterId) == false then
			issueSim(characterId, serial)
		end
		log('info', 'system', 'phone_device_bound', { character_id = characterId, result = legacy and 'legacy' or 'new' })
		return serial
	end)()
	binding[characterId] = nil
	return serial, errorCode
end

-- Serial do celular a usar: o do slot (item usado), o ativo ou o primeiro do inventário.
local function resolveDevice(playerId, characterId, slot)
	local items = deviceItems(characterId)
	if not items then
		return nil, 'inventory_unavailable'
	end
	local item = PhoneRules.PickDevice(items, active[playerId], slot)
	if not item then
		return nil, 'no_phone'
	end
	local serial = type(item.metadata) == 'table' and item.metadata.serial or nil
	if serial == nil then
		return bindDevice(characterId, item)
	end
	if not PhoneRules.IsSerial(serial) then
		return nil, 'no_device'
	end
	return serial
end

-- Quem está usando o aparelho agora. nil + erro se não pode usar.
local function useDevice(playerId, characterId, serial)
	local device, errorCode = deviceOf(serial)
	if not device then
		return nil, errorCode
	end
	local sims, simsError = simsOf(serial)
	if not sims then
		return nil, simsError
	end
	active[playerId] = serial
	holderOf[serial] = playerId
	local sim = sims[1]
	return {
		playerId = playerId,
		characterId = characterId,
		serial = serial,
		device = device,
		model = modelOf(device),
		sims = sims,
		sim = sim,
		number = sim and sim.number or nil,
		holder = sim and sim.holder or nil,
		prefs = device.prefs
	}
end

-- slot: item de celular usado agora (troca o aparelho ativo).
local function owner(playerId, slot)
	if not ready then
		return nil, 'not_ready'
	end
	local characterId = characterIdOf(playerId)
	if not characterId then
		return nil, 'no_character'
	end
	local serial = not slot and active[playerId] or nil
	if not serial or not holdsSerial(characterId, serial) then
		local errorCode
		serial, errorCode = resolveDevice(playerId, characterId, slot)
		if not serial then
			active[playerId] = nil
			return nil, errorCode
		end
	end
	return useDevice(playerId, characterId, serial)
end

-- Jogador online com o aparelho. Aparelho migrado ainda sem item é vinculado ao celular do dono.
local function playerOfSerial(serial)
	local cached = holderOf[serial]
	if cached then
		local characterId = characterIdOf(cached)
		if characterId and holdsSerial(characterId, serial) then
			return cached, characterId
		end
		holderOf[serial] = nil
	end
	local device = deviceOf(serial)
	if not device then
		return nil
	end
	if not device.bound then
		local playerId = device.owner and playerOfCharacter(device.owner)
		if playerId and resolveDevice(playerId, device.owner) == serial then
			holderOf[serial] = playerId
			return playerId, device.owner
		end
		return nil
	end
	for _, value in ipairs(GetPlayers()) do
		local playerId = tonumber(value)
		local characterId = characterIdOf(playerId)
		if characterId and holdsSerial(characterId, serial) then
			holderOf[serial] = playerId
			return playerId, characterId
		end
	end
	return nil
end

-- Destino de uma ligação ou mensagem: { number, holder, serial, playerId, characterId } (sem jogador se ninguém
-- online tem o aparelho). nil + erro se o número não existe.
local function routeNumber(number)
	local sim, errorCode = PhonePersistence.SimByNumber(number)
	if sim == nil then
		return nil, errorCode or 'database_error'
	end
	if not sim then
		return nil, 'number_not_found'
	end
	local target = { number = number, holder = sim.holder, serial = sim.serial }
	if sim.serial then
		target.playerId, target.characterId = playerOfSerial(sim.serial)
	end
	return target
end

local function contactsOf(serial)
	local cached = contactCache[serial]
	if cached then
		return cached
	end
	local rows = PhonePersistence.Contacts(serial)
	if not rows then
		return nil
	end
	local list, byNumber = {}, {}
	for _, row in ipairs(rows) do
		local entry = { id = tonumber(row.id), name = tostring(row.name), number = tostring(row.number) }
		entry.display = format(entry.number)
		list[#list + 1] = entry
		byNumber[entry.number] = entry.name
	end
	cached = { list = list, byNumber = byNumber }
	contactCache[serial] = cached
	return cached
end

-- Como o número aparece no aparelho: nome do contato ou o número formatado.
local function nameFor(serial, number)
	local contacts = serial and contactsOf(serial)
	return contacts and contacts.byNumber[number] or format(number)
end

local function prefsOf(serial)
	local device = serial and deviceOf(serial)
	return device and device.prefs or nil
end

-- Barras de sinal pela posição do jogador (o cliente ainda desconta ambientes fechados e água, só na exibição).
local function signalOf(playerId)
	local ok, coords = pcall(function()
		return Core.Platform.Entities.GetCoords(GetPlayerPed(playerId))
	end)
	if not ok or not coords then
		return 0
	end
	return PhoneRules.Signal(config, coords.x, coords.y)
end

-- Sem rede: modo avião ou sem sinal.
local function offline(playerId, prefs)
	if prefs and prefs.settings.airplane then
		return 'airplane_mode'
	end
	if signalOf(playerId) == 0 then
		return 'no_signal'
	end
	return nil
end

local function hashPasscode(code)
	local ok, hash = pcall(GetPasswordHash, code)
	return ok and type(hash) == 'string' and hash or nil
end

local function checkPasscode(code, hash)
	local ok, valid = pcall(VerifyPasswordHash, code, hash)
	return ok and valid == true
end

local function unreadTotal(number)
	if not number then
		return 0
	end
	local rows = PhonePersistence.Unread(number) or {}
	local total = 0
	for _, row in ipairs(rows) do
		total = total + (tonumber(row.total) or 0)
	end
	return total
end

local function appsOf(playerId)
	return PhoneRules.Apps(config, function(id, app)
		if GetResourceState(app.resource) ~= 'started' then
			return false
		end
		local ok, visible = pcall(function()
			return exports[app.resource]:TabletVisible(playerId, id)
		end)
		return ok and visible == true
	end)
end

local function profileOf(me)
	local apps = appsOf(me.playerId)
	local sims = {}
	for _, sim in ipairs(me.sims) do
		sims[#sims + 1] = { slot = sim.slot, display = format(sim.number), mine = sim.holder == me.characterId }
	end
	return {
		number = me.number,
		display = me.number and format(me.number) or nil,
		prefix = config.Number.Prefix,
		device = { serial = me.serial, label = me.model.label, simSlots = me.model.sims, myFace = me.device.face == me.characterId },
		sims = sims,
		apps = apps,
		layout = PhoneRules.Layout(config, me.prefs.layout, apps),
		home = config.Home,
		settings = me.prefs.settings,
		hasPasscode = me.prefs.passcode ~= false,
		passcode = config.Settings.Passcode,
		signal = signalOf(me.playerId),
		unread = unreadTotal(me.number),
		ringMax = config.RingVolume,
		openKey = config.OpenKey
	}
end

-- Como o aparelho toca (o cliente pode estar com o celular fechado, sem o perfil carregado).
local function soundOf(serial)
	local prefs = prefsOf(serial)
	if not prefs then
		return nil
	end
	local s = prefs.settings
	return { silent = s.silent, vibrate = s.vibrate, dnd = s.dnd, volume = s.volume, ringtone = s.ringtone, max = config.RingVolume }
end

-- Chamadas ---------------------------------------------------------------------------------------------


Phone = {
	config = config,
	log = log,
	notify = notify,
	characterIdOf = characterIdOf,
	telecomAuthorize = telecomAuthorize,
	telecomCharge = telecomCharge,
	format = format,
	playerOfCharacter = playerOfCharacter,
	playerOfSerial = playerOfSerial,
	routeNumber = routeNumber,
	contactsOf = contactsOf,
	contactCache = contactCache,
	nameFor = nameFor,
	prefsOf = prefsOf,
	signalOf = signalOf,
	offline = offline,
	soundOf = soundOf,
	calls = calls,
	playerCall = playerCall,
	active = active,
	payments = payments,
	walletBusy = walletBusy,
	verifyCurrent = function(...) return verifyCurrent(...) end,
	t = _t,
	CALL_DISPATCH = {},
	WALLET_DISPATCH = {},
	Native = {}
}

local function _loadSub(relPath)
	local f = io.open(relPath, "r")
	if f then f:close() return dofile(relPath) end
	local f2 = io.open("coe_phone/" .. relPath, "r")
	if f2 then f2:close() return dofile("coe_phone/" .. relPath) end
end

if not IsDuplicityVersion or not IsDuplicityVersion() then
	_loadSub("server/calls.lua")
	_loadSub("server/wallet.lua")
	_loadSub("server/payments.lua")
end

-- Calls logic extracted to server/calls.lua
local function sendState(...) return Phone.sendState(...) end
local function finish(...) return Phone.finish(...) end
local function dial(...) return Phone.dial(...) end
local function answer(...) return Phone.answer(...) end
local function hangup(...) return Phone.hangup(...) end
local CALL_DISPATCH = setmetatable({}, { __index = function(_, k) return Phone.CALL_DISPATCH[k] end })

local Native = setmetatable({
	calls = CALL_DISPATCH,
	wallet = setmetatable({}, { __index = function(_, k) return Phone.WALLET_DISPATCH[k] end }),
}, { __index = function(_, k) return Phone.Native[k] end })

Native.messages = {
	threads = function(me)
		if not me.number then
			return { ok = true, data = {} }
		end
		local rows = PhonePersistence.Threads(me.number, config.Messages.ThreadsLimit)
		if not rows then
			return { ok = false, error = 'database_error' }
		end
		local unread = {}
		for _, row in ipairs(PhonePersistence.Unread(me.number) or {}) do
			unread[tostring(row.sender)] = tonumber(row.total) or 0
		end
		local list = {}
		for _, row in ipairs(rows) do
			local mine = tostring(row.sender) == me.number
			local peer = tostring(mine and row.receiver or row.sender)
			list[#list + 1] = {
				number = format(peer), name = nameFor(me.serial, peer), last = tostring(row.body),
				mine = mine, at = tonumber(row.created_at), unread = unread[peer] or 0
			}
		end
		return { ok = true, data = list }
	end,
	open = function(me, payload)
		local other = PhoneRules.Normalize(config, payload.number)
		if not other then
			return { ok = false, error = 'invalid_number' }
		end
		if not me.number then
			return { ok = false, error = 'no_sim' }
		end
		local rows = PhonePersistence.Conversation(me.number, other, config.Messages.HistoryLimit)
		if not rows then
			return { ok = false, error = 'database_error' }
		end
		PhonePersistence.MarkRead(me.number, other, os.time())
		local list = {}
		for index = #rows, 1, -1 do
			local row = rows[index]
			list[#list + 1] = { id = tonumber(row.id), mine = tostring(row.sender) == me.number, body = tostring(row.body), at = tonumber(row.created_at) }
		end
		return { ok = true, data = { number = format(other), name = nameFor(me.serial, other), messages = list } }
	end,
	send = function(me, payload)
		if not me.number then
			return { ok = false, error = 'no_sim' }
		end
		local other = PhoneRules.Normalize(config, payload.number)
		local body = PhoneRules.Message(config, payload.body)
		if not other or other == me.number then
			return { ok = false, error = 'invalid_number' }
		end
		if not body then
			return { ok = false, error = 'invalid_message' }
		end
		local myNetwork = offline(me.playerId, me.prefs)
		if myNetwork then
			return { ok = false, error = myNetwork }
		end
		local now = GetGameTimer()
		if lastMessage[me.playerId] and now - lastMessage[me.playerId] < config.Messages.CooldownMs then
			return { ok = false, error = 'rate_limited' }
		end
		local receiver, routeError = routeNumber(other)
		if not receiver then
			return { ok = false, error = routeError }
		end
		local line = telecomAuthorize(me.number, 'sms', me.holder)
		if not line.ok then
			return { ok = false, error = line.error or 'telecom_unavailable' }
		end
		lastMessage[me.playerId] = now
		local at = os.time()
		local result = PhonePersistence.AddMessage(me.number, other, body, at)
		if not result then
			return { ok = false, error = 'database_error' }
		end
		telecomCharge(me.number, 'sms', 0, other, me.holder)
		-- Chip fora de aparelho, aparelho offline ou sem rede: a mensagem fica guardada para quando abrir o app.
		local receiverPrefs = receiver.playerId and prefsOf(receiver.serial)
		if receiverPrefs and not offline(receiver.playerId, receiverPrefs) then
			local name = nameFor(receiver.serial, me.number)
			TriggerClientEvent('coe_phone:message', receiver.playerId, { number = format(me.number), name = name, body = body, at = at, sound = soundOf(receiver.serial) })
			if not receiverPrefs.settings.dnd then
				notify(receiver.playerId, 'info', _t('new_message', { sender = name }))
			end
		end
		return { ok = true, data = { id = tonumber(result.insertId), mine = true, body = body, at = at } }
	end
}

-- Câmera e Galeria: as fotos ficam no aparelho (serial), limitadas pelo armazenamento do modelo.
local function storageOf(me)
	local usage = PhonePersistence.PhotoUsage(me.serial)
	if not usage then
		return nil
	end
	return { count = usage.count, used = usage.bytes, capacity = math.floor((tonumber(me.model.storage) or 0) * 1024 * 1024) }
end

Native.camera = {
	info = function(me)
		local storage = storageOf(me)
		if not storage then
			return { ok = false, error = 'database_error' }
		end
		local camera = me.model.camera or {}
		return { ok = true, data = {
			width = tonumber(camera.width) or 960, quality = tonumber(camera.quality) or 0.72,
			thumbWidth = config.Photos.ThumbWidth, maxBytes = config.Photos.MaxBytes, thumbMaxBytes = config.Photos.ThumbMaxBytes,
			storage = storage
		} }
	end
}

Native.gallery = {
	list = function(me, payload)
		local before = payload.before ~= nil and math.tointeger(tonumber(payload.before)) or nil
		if payload.before ~= nil and (not before or before < 1) then
			return { ok = false, error = 'invalid_request' }
		end
		local rows = PhonePersistence.Photos(me.serial, before, config.Photos.PageSize + 1)
		local storage = not before and storageOf(me) or nil
		if not rows or (not before and not storage) then
			return { ok = false, error = 'database_error' }
		end
		local photos = {}
		for index = 1, math.min(#rows, config.Photos.PageSize) do
			local row = rows[index]
			photos[#photos + 1] = { id = tonumber(row.id), thumb = tostring(row.thumb), at = tonumber(row.created_at) }
		end
		return { ok = true, data = { photos = photos, more = #rows > config.Photos.PageSize, storage = storage } }
	end,
	photo = function(me, payload)
		local id = math.tointeger(tonumber(payload.id))
		if not id then
			return { ok = false, error = 'invalid_request' }
		end
		local row = PhonePersistence.Photo(me.serial, id)
		if row == nil then
			return { ok = false, error = 'database_error' }
		end
		if not row then
			return { ok = false, error = 'photo_not_found' }
		end
		return { ok = true, data = {
			id = tonumber(row.id), image = tostring(row.image), at = tonumber(row.created_at),
			newer = tonumber(row.newer), older = tonumber(row.older)
		} }
	end,
	remove = function(me, payload)
		local id = math.tointeger(tonumber(payload.id))
		if not id then
			return { ok = false, error = 'invalid_request' }
		end
		local result = PhonePersistence.DeletePhoto(me.serial, id)
		if not result then
			return { ok = false, error = 'database_error' }
		end
		if (tonumber(result.affectedRows) or 0) < 1 then
			return { ok = false, error = 'photo_not_found' }
		end
		return { ok = true, data = { storage = storageOf(me) } }
	end
}

local function savePrefs(me, prefs)
	local result = PhonePersistence.SaveSettings(me.serial, encodePrefs(prefs), os.time())
	if not result then
		deviceCache[me.serial] = nil
		return false
	end
	me.device.prefs = prefs
	return true
end

local function copyPrefs(prefs)
	return { settings = prefs.settings, layout = prefs.layout, passcode = prefs.passcode }
end

-- Tentativas de senha (por aparelho): Attempts erros seguidos bloqueiam por LockoutSeconds.
local function passcodeAllowed(serial)
	local fails = unlockFails[serial]
	if fails and fails.blockedUntil and os.time() < fails.blockedUntil then
		return false, fails.blockedUntil - os.time()
	end
	return true
end

local function passcodeFailed(serial)
	local limits = config.Settings.Passcode
	local fails = unlockFails[serial] or { count = 0 }
	fails.count = fails.count + 1
	if fails.count >= limits.Attempts then
		fails.count = 0
		fails.blockedUntil = os.time() + limits.LockoutSeconds
	end
	unlockFails[serial] = fails
end

local function verifyCurrent(me, code)
	local allowed, wait = passcodeAllowed(me.serial)
	if not allowed then
		return { ok = false, error = 'locked_out', data = { wait = wait } }
	end
	if type(code) ~= 'string' or not checkPasscode(code, me.prefs.passcode) then
		passcodeFailed(me.serial)
		return { ok = false, error = 'wrong_passcode' }
	end
	unlockFails[me.serial] = nil
	return nil
end

-- Carteira digital ---------------------------------------------------------------------------------

-- Wallet logic extracted to server/wallet.lua
local function walletView(...) return Phone.walletView(...) end
local function inWallet(...) return Phone.inWallet(...) end
local function confirmOwner(...) return Phone.confirmOwner(...) end
local function newToken(...) return Phone.newToken(...) end
local function walletLocked(...) return Phone.walletLocked(...) end
local WALLET_DISPATCH = setmetatable({}, { __index = function(_, k) return Phone.WALLET_DISPATCH[k] end })

-- Chips (itens) no inventário do personagem: { { item, display } }.
local function simItems(characterId)
	if not inventoryReady() then
		return nil
	end
	local ok, snapshot = pcall(function()
		return exports.coe_inventory:GetInventory(inventoryOf(characterId))
	end)
	if not ok or type(snapshot) ~= 'table' or type(snapshot.items) ~= 'table' then
		return nil
	end
	local list = {}
	for slot, item in pairs(snapshot.items) do
		local iccid = type(item) == 'table' and item.name == config.SimItem and type(item.metadata) == 'table' and item.metadata.iccid or nil
		if PhoneRules.IsIccid(iccid) then
			local sim = PhonePersistence.Sim(iccid)
			if sim and not sim.serial then
				list[#list + 1] = { item = tonumber(slot), display = format(sim.number), mine = tostring(sim.holder) == tostring(characterId) }
			end
		end
	end
	table.sort(list, function(a, b) return a.item < b.item end)
	return list
end

-- Tira o chip do slot `slot` do inventário e coloca no primeiro slot livre do aparelho. Retorna o número formatado.
local function placeSim(me, slot)
	if playerCall[me.playerId] then
		return nil, 'in_call'
	end
	local free = PhoneRules.FreeSimSlot(me.model.sims, me.sims)
	if not free then
		return nil, 'no_free_sim_slot'
	end
	local inventory = inventoryOf(me.characterId)
	local okRead, item = pcall(function()
		return exports.coe_inventory:GetSlot(inventory, slot)
	end)
	if not okRead or type(item) ~= 'table' or item.name ~= config.SimItem then
		return nil, 'slot_changed'
	end
	local iccid = type(item.metadata) == 'table' and item.metadata.iccid or nil
	if not PhoneRules.IsIccid(iccid) then
		return nil, 'invalid_sim'
	end
	local sim = PhonePersistence.Sim(iccid)
	if not sim or sim.serial then
		return nil, 'invalid_sim'
	end
	-- A consulta acima espera o banco: confere o slot de novo e remove sem ceder.
	local ok, current = pcall(function()
		return exports.coe_inventory:GetSlot(inventory, slot)
	end)
	if not ok or type(current) ~= 'table' or current.name ~= config.SimItem or type(current.metadata) ~= 'table' or current.metadata.iccid ~= iccid then
		return nil, 'slot_changed'
	end
	local sagaCtx = { errorCode = nil }
	local sagaOk = PhoneRules.ExecuteSaga({
		{
			name = 'remove_sim_item',
			action = function()
				local removed, removedOk = pcall(function()
					return exports.coe_inventory:RemoveItem(inventory, slot, 1)
				end)
				if not removed or removedOk ~= true then
					sagaCtx.errorCode = 'inventory_unavailable'
					return false
				end
				return true
			end,
			compensate = function()
				pcall(function()
					exports.coe_inventory:AddItem(inventory, config.SimItem, 1, current.metadata)
				end)
			end
		},
		{
			name = 'insert_sim_db',
			action = function()
				simCache[me.serial] = nil
				if not PhonePersistence.InsertSim(iccid, me.serial, free) then
					sagaCtx.errorCode = 'database_error'
					return false
				end
				return true
			end
		}
	}, sagaCtx)
	if not sagaOk then
		return nil, sagaCtx.errorCode or 'database_error'
	end
	log('info', 'system', 'phone_sim_inserted', { character_id = me.characterId })
	local updated = useDevice(me.playerId, me.characterId, me.serial)
	if updated then
		TriggerClientEvent('coe_phone:profile', me.playerId, profileOf(updated))
	end
	return format(sim.number)
end

Native.settings = {
	-- Chips soltos no inventário, para colocar pelo app.
	simItems = function(me)
		local list = simItems(me.characterId)
		if not list then
			return { ok = false, error = 'inventory_unavailable' }
		end
		return { ok = true, data = list }
	end,
	-- payload.item: slot do chip no inventário.
	insertSim = function(me, payload)
		local slot = math.tointeger(tonumber(payload.item))
		if not slot then
			return { ok = false, error = 'slot_changed' }
		end
		local number, errorCode = placeSim(me, slot)
		if not number then
			return { ok = false, error = errorCode }
		end
		return { ok = true, data = { display = number } }
	end,
	-- payload.settings: alteração parcial; payload.layout: telas iniciais; payload.resetLayout: volta ao padrão.
	save = function(me, payload)
		local prefs = copyPrefs(me.prefs)
		if payload.settings ~= nil then
			local settings, errorCode = PhoneRules.Patch(config, prefs.settings, payload.settings)
			if not settings then
				return { ok = false, error = errorCode }
			end
			if settings.faceId and not prefs.passcode then
				return { ok = false, error = 'passcode_required' }
			end
			prefs.settings = settings
		end
		local apps = appsOf(me.playerId)
		if payload.resetLayout == true then
			prefs.layout = nil
		elseif payload.layout ~= nil then
			if type(payload.layout) ~= 'table' then
				return { ok = false, error = 'invalid_layout' }
			end
			prefs.layout = PhoneRules.Layout(config, payload.layout, apps)
		end
		local faceWas = me.prefs.settings.faceId
		if not savePrefs(me, prefs) then
			return { ok = false, error = 'database_error' }
		end
		-- Ligar o reconhecimento facial cadastra o rosto de quem está usando; desligar apaga.
		if prefs.settings.faceId ~= faceWas then
			local face = prefs.settings.faceId and me.characterId or nil
			PhonePersistence.SetFace(me.serial, face)
			me.device.face = face
		end
		return { ok = true, data = { settings = prefs.settings, layout = PhoneRules.Layout(config, prefs.layout, apps), myFace = me.device.face == me.characterId } }
	end,
	-- Define, troca ou remove (payload.code vazio) a senha. Se já existe senha, exige payload.current.
	passcode = function(me, payload)
		if me.prefs.passcode then
			local denied = verifyCurrent(me, payload.current)
			if denied then
				return denied
			end
		end
		local prefs = copyPrefs(me.prefs)
		if payload.code == nil or payload.code == '' then
			prefs.passcode = false
			local settings = {}
			for key, value in pairs(prefs.settings) do
				settings[key] = value
			end
			settings.faceId = false
			prefs.settings = settings
		else
			local code = PhoneRules.Passcode(config, payload.code)
			if not code then
				return { ok = false, error = 'invalid_passcode' }
			end
			prefs.passcode = hashPasscode(code)
			if not prefs.passcode then
				log('error', 'system', 'phone_passcode_hash_failed', {})
				return { ok = false, error = 'app_error' }
			end
		end
		local result = PhonePersistence.SavePasscode(me.serial, prefs.passcode, encodePrefs(prefs), os.time())
		if not result then
			deviceCache[me.serial] = nil
			return { ok = false, error = 'database_error' }
		end
		me.device.prefs = prefs
		if not prefs.passcode and me.device.face then
			PhonePersistence.SetFace(me.serial, nil)
			me.device.face = nil
		end
		unlocked[me.playerId] = me.serial
		log('info', 'system', 'phone_passcode_changed', { character_id = me.characterId, result = prefs.passcode and 'set' or 'removed' })
		return { ok = true, data = { hasPasscode = prefs.passcode ~= false, settings = prefs.settings } }
	end,
	-- Desbloqueio pela senha ou pelo rosto (só o rosto cadastrado; outro rosto não conta como erro de senha).
	unlock = function(me, payload)
		if not me.prefs.passcode then
			unlocked[me.playerId] = me.serial
			return { ok = true }
		end
		if payload.face == true then
			if not me.prefs.settings.faceId or me.device.face ~= me.characterId then
				return { ok = false, error = 'face_mismatch' }
			end
			unlocked[me.playerId] = me.serial
			return { ok = true }
		end
		local denied = verifyCurrent(me, payload.code)
		if denied then
			return denied
		end
		unlocked[me.playerId] = me.serial
		return { ok = true }
	end,
	-- Tira o chip do slot e devolve como item ao inventário.
	ejectSim = function(me, payload)
		local slot = math.tointeger(tonumber(payload.slot))
		local sim
		for _, entry in ipairs(me.sims) do
			if entry.slot == slot then
				sim = entry
			end
		end
		if not sim then
			return { ok = false, error = 'no_sim' }
		end
		if playerCall[me.playerId] then
			return { ok = false, error = 'in_call' }
		end
		local inventory = inventoryOf(me.characterId)
		local sagaCtx = { addedSlot = nil, errorCode = nil }
		local sagaOk = PhoneRules.ExecuteSaga({
			{
				name = 'add_sim_item',
				action = function()
					local ok, added, addedSlot = pcall(function()
						return exports.coe_inventory:AddItem(inventory, config.SimItem, 1, { iccid = sim.iccid, label = 'Chip ' .. format(sim.number) })
					end)
					if not ok then
						sagaCtx.errorCode = 'inventory_unavailable'
						return false
					end
					if added ~= true then
						sagaCtx.errorCode = 'inventory_full'
						return false
					end
					sagaCtx.addedSlot = addedSlot
					return true
				end,
				compensate = function()
					if sagaCtx.addedSlot then
						pcall(function()
							exports.coe_inventory:RemoveItem(inventory, sagaCtx.addedSlot, 1)
						end)
					end
				end
			},
			{
				name = 'eject_sim_db',
				action = function()
					simCache[me.serial] = nil
					if not PhonePersistence.EjectSim(sim.iccid, me.serial) then
						sagaCtx.errorCode = 'database_error'
						return false
					end
					return true
				end
			}
		}, sagaCtx)
		if not sagaOk then
			return { ok = false, error = sagaCtx.errorCode or 'database_error' }
		end
		log('info', 'system', 'phone_sim_ejected', { character_id = me.characterId })
		local updated = useDevice(me.playerId, me.characterId, me.serial)
		if updated then
			TriggerClientEvent('coe_phone:profile', me.playerId, profileOf(updated))
		end
		return { ok = true }
	end
}

-- Bloqueado, o aparelho só desbloqueia e atende/desliga ligações.
local function allowedWhileLocked(appId, action)
	return (appId == 'settings' and action == 'unlock') or (appId == 'phone' and (action == 'answer' or action == 'hangup'))
end

-- Eventos ----------------------------------------------------------------------------------------------

local function deny(playerId, errorCode)
	local messages = {
		no_phone = 'Você não tem um celular.',
		no_device = 'Este celular não funciona.',
		inventory_unavailable = 'O inventário não respondeu. Tente de novo.',
		number_unavailable = 'Não foi possível gerar um número agora.',
		no_character = 'Selecione um personagem primeiro.',
		not_ready = 'O celular ainda está iniciando.'
	}
	notify(playerId, 'info', _t(errorCode) ~= errorCode and _t(errorCode) or _t('phone_unavailable'))
end

-- slot: item de celular usado no inventário (nil = aparelho ativo ou o primeiro).
local function openPhone(playerId, slot)
	local me, errorCode = owner(playerId, slot)
	if not me then
		deny(playerId, errorCode)
		return
	end
	if unlocked[playerId] ~= me.serial then
		unlocked[playerId] = me.prefs.passcode == false and me.serial or nil
	end
	TriggerClientEvent('coe_phone:opened', playerId, profileOf(me))
end

RegisterNetEvent('coe_phone:open', function()
	openPhone(source)
end)

-- Usar o chip (item) coloca no primeiro slot livre do celular ativo.
local function insertSim(playerId, slot)
	local me, errorCode = owner(playerId)
	if not me then
		deny(playerId, errorCode)
		return
	end
	local number, placeError = placeSim(me, slot)
	if not number then
		notify(playerId, 'error', _t(placeError) ~= placeError and _t(placeError) or _t('sim_place_failed'))
		return
	end
	notify(playerId, 'success', _t('sim_placed', { number = number }))
end

Core.Events.On('inventory.itemUsed', function(inventoryId, slot, item)
	local characterId = type(inventoryId) == 'string' and inventoryId:match('^character:(.+)$')
	if not characterId or type(item) ~= 'table' or (not config.Devices[item.name] and item.name ~= config.SimItem) then
		return
	end
	CreateThread(function()
		local playerId = playerOfCharacter(characterId)
		if not playerId then
			return
		end
		if item.name == config.SimItem then
			insertSim(playerId, slot)
		else
			openPhone(playerId, slot)
		end
	end)
end)

RegisterNetEvent('coe_phone:refresh', function()
	local playerId = source
	local now = GetGameTimer()
	if lastRefresh[playerId] and now - lastRefresh[playerId] < 1000 then
		return
	end
	lastRefresh[playerId] = now
	local me = owner(playerId)
	if me then
		TriggerClientEvent('coe_phone:profile', playerId, profileOf(me))
	end
end)

local function reply(playerId, requestId, result)
	if type(result) == 'table' and type(result.data) ~= 'nil' then
		local encoded = json.encode(result.data)
		if encoded and #encoded > config.LatentReplyBytes then
			TriggerLatentClientEvent('coe_phone:result', playerId, config.LatentBytesPerSecond, requestId, result)
			return
		end
	end
	TriggerClientEvent('coe_phone:result', playerId, requestId, result)
end

local function forward(playerId, appId, action, payload)
	local app = config.Apps[appId]
	if not app or not app.resource or GetResourceState(app.resource) ~= 'started' then
		return { ok = false, error = 'app_unavailable' }
	end
	local called, result = pcall(function()
		if exports[app.resource]:TabletVisible(playerId, appId) ~= true then
			return { ok = false, error = 'forbidden' }
		end
		return exports[app.resource]:TabletCall(playerId, appId, action, payload)
	end)
	if not called or type(result) ~= 'table' then
		log('error', 'system', 'phone_app_failed', { operation = appId, action = action })
		return { ok = false, error = 'app_error' }
	end
	return result
end

RegisterNetEvent('coe_phone:call', function(requestId, appId, action, payload)
	local playerId = source
	if type(requestId) ~= 'number' or requestId % 1 ~= 0 then
		return
	end
	if type(appId) ~= 'string' or type(action) ~= 'string' or #appId > 32 or #action > 32 then
		reply(playerId, requestId, { ok = false, error = 'invalid_request' })
		return
	end
	if payload ~= nil and (type(payload) ~= 'table' or #json.encode(payload) > config.MaxPayloadBytes) then
		reply(playerId, requestId, { ok = false, error = 'invalid_payload' })
		return
	end
	local now = GetGameTimer()
	if callLimiter then
		if not callLimiter:allow(playerId, now) then
			reply(playerId, requestId, { ok = false, error = 'rate_limited' })
			return
		end
	elseif lastCall[playerId] and now - lastCall[playerId] < config.CallCooldownMs then
		reply(playerId, requestId, { ok = false, error = 'rate_limited' })
		return
	end
	lastCall[playerId] = now

	local me, errorCode = owner(playerId)
	if not me then
		reply(playerId, requestId, { ok = false, error = errorCode })
		return
	end
	payload = payload or {}
	if unlocked[playerId] ~= me.serial and not allowedWhileLocked(appId, action) then
		reply(playerId, requestId, { ok = false, error = 'locked' })
		return
	end

	local native = Native[appId]
	if native then
		local handler = rawget(native, action) or native[action]
		if type(handler) ~= 'function' then
			reply(playerId, requestId, { ok = false, error = 'unknown_action' })
			return
		end
		local called, result = pcall(handler, me, payload)
		if not called or type(result) ~= 'table' then
			log('error', 'system', 'phone_app_failed', { operation = appId, action = action, error_code = tostring(result):sub(1, 120) })
			result = { ok = false, error = 'app_error' }
		end
		reply(playerId, requestId, result)
		return
	end
	reply(playerId, requestId, forward(playerId, appId, action, payload))
end)

-- Foto da Câmera (evento latente: a imagem passa do limite de um evento comum). Responde como coe_phone:call.
RegisterNetEvent('coe_phone:photo', function(requestId, image, thumb)
	local playerId = source
	if type(requestId) ~= 'number' or requestId % 1 ~= 0 then
		return
	end
	local photos = config.Photos
	image = PhoneRules.Photo(image, photos.MaxBytes)
	thumb = PhoneRules.Photo(thumb, photos.ThumbMaxBytes)
	if not image or not thumb then
		reply(playerId, requestId, { ok = false, error = 'invalid_photo' })
		return
	end
	local now = GetGameTimer()
	if savingPhoto[playerId] or (lastPhoto[playerId] and now - lastPhoto[playerId] < photos.CooldownMs) then
		reply(playerId, requestId, { ok = false, error = 'rate_limited' })
		return
	end
	lastPhoto[playerId] = now
	local me, errorCode = owner(playerId)
	if not me then
		reply(playerId, requestId, { ok = false, error = errorCode })
		return
	end
	if unlocked[playerId] ~= me.serial then
		reply(playerId, requestId, { ok = false, error = 'locked' })
		return
	end
	savingPhoto[playerId] = true
	local ok, result = pcall(function()
		local usage = PhonePersistence.PhotoUsage(me.serial)
		if not usage then
			return { ok = false, error = 'database_error' }
		end
		if not PhoneRules.StorageFits(me.model.storage, usage.bytes, #image + #thumb) then
			return { ok = false, error = 'storage_full' }
		end
		local at = os.time()
		local inserted = PhonePersistence.AddPhoto(me.serial, me.characterId, image, thumb, at)
		if not inserted then
			return { ok = false, error = 'database_error' }
		end
		log('info', 'system', 'phone_photo_saved', { character_id = me.characterId, count = #image + #thumb })
		return { ok = true, data = { id = tonumber(inserted.insertId), at = at } }
	end)
	savingPhoto[playerId] = nil
	reply(playerId, requestId, ok and result or { ok = false, error = 'app_error' })
end)

AddEventHandler('playerDropped', function()
	local playerId = source
	local call = calls[playerCall[playerId]]
	if call then
		finish(call, call.state == 'active' and 'hangup' or (call.callee.playerId == playerId and 'unavailable' or 'missed'))
	end
	for serial, holder in pairs(holderOf) do
		if holder == playerId then
			holderOf[serial] = nil
			deviceCache[serial] = nil
			simCache[serial] = nil
			contactCache[serial] = nil
		end
	end
	active[playerId] = nil
	unlocked[playerId] = nil
	lastCall[playerId] = nil
	lastRefresh[playerId] = nil
	lastMessage[playerId] = nil
	lastPhoto[playerId] = nil
	if callLimiter then callLimiter:reset(playerId) end
	if refreshLimiter then refreshLimiter:reset(playerId) end
	if messageLimiter then messageLimiter:reset(playerId) end
	if photoLimiter then photoLimiter:reset(playerId) end
	savingPhoto[playerId] = nil
	walletBusy[playerId] = nil
	for token, payment in pairs(payments) do
		if payment.playerId == playerId then
			payments[token] = nil
		end
	end
end)

AddEventHandler('onResourceStop', function(resource)
	if resource ~= GetCurrentResourceName() then
		return
	end
	for _, call in pairs(calls) do
		calls[call.id] = nil
		PhoneVoice.Close(call.voice)
		TriggerClientEvent('coe_phone:callState', call.caller.playerId, { id = call.id, state = 'ended', reason = 'unavailable' })
		TriggerClientEvent('coe_phone:callState', call.callee.playerId, { id = call.id, state = 'ended', reason = 'unavailable' })
	end
end)

-- Consome (uma vez) a autorização de pagamento da Carteira. Só para resources de config.Wallet.PaymentCallers.
-- Retorna o cardId autorizado, ou nil + erro (payment_expired, payment_mismatch, forbidden).
exports('NumberOf', function(characterId)
	if not ready or characterId == nil then
		return nil
	end
	local number = PhonePersistence.HeldNumber(tostring(characterId))
	return number and format(number) or nil
end)

-- Linha do chip (slot 1) no celular que o jogador está usando: { number, display, holder } ou nil + erro.
exports('ActiveLine', function(playerId)
	local me, errorCode = owner(tonumber(playerId))
	if not me then
		return nil, errorCode
	end
	if not me.number then
		return nil, 'no_sim'
	end
	return { number = me.number, display = format(me.number), holder = me.holder }
end)

-- Aparelho que o jogador está usando: { serial } ou nil + erro. Apps que prendem a sessão ao aparelho (ex.: e-mail)
-- usam o número de série: quem pega o aparelho desbloqueado pega as sessões junto.
exports('ActiveDevice', function(playerId)
	local me, errorCode = owner(tonumber(playerId))
	if not me then
		return nil, errorCode
	end
	return { serial = me.serial }
end)

CreateThread(function()
	math.randomseed(os.time() + GetGameTimer())
	local waitingLogged = false
	while true do
		local initialized, errorCode = PhonePersistence.Initialize()
		if initialized then
			break
		end
		if errorCode == 'database_not_ready' or errorCode == 'database_unavailable' then
			if not waitingLogged then
				log('info', 'persistence', 'database_waiting', {})
				waitingLogged = true
			end
			Wait(1000)
		else
			log('error', 'persistence', 'migrations_failed', { error_code = tostring(errorCode) })
			return
		end
	end
	-- Quem vem do telefone básico mantém número, contatos, conversas, ligações e ajustes (server/upgrade.lua).
	local ok, report = pcall(PhoneUpgrade.Run, PhonePersistence.Database(), config)
	upgradeReport = ok and report or { ok = false, error = 'internal_error' }
	if not ok or not upgradeReport.ok then
		log('error', 'persistence', 'phone_upgrade_failed', { error_code = tostring(ok and upgradeReport.error or report):sub(1, 96) })
	elseif not upgradeReport.skipped then
		log('info', 'system', 'phone_upgrade_done', {
			count = upgradeReport.numbers, operation = ('kept=%d conflicts=%d contacts=%d messages=%d calls=%d'):format(
				upgradeReport.kept, upgradeReport.conflicts, upgradeReport.contacts, upgradeReport.messages, upgradeReport.calls)
		})
	end
	ready = true
	log('info', 'system', 'phone_ready', {})
end)

-- Relatório do último upgrade do básico (o coe_supervisor mostra no comando coe_upgrades).
exports('UpgradeStatus', function()
	return upgradeReport
end)
