-- Voice Calls & Telecom Routing
local Phone = Phone
local config = Phone.config
local log = function(...) return Phone.log(...) end
local notify = function(...) return Phone.notify(...) end
local playerOfCharacter = function(...) return Phone.playerOfCharacter(...) end
local playerOfSerial = function(...) return Phone.playerOfSerial(...) end
local routeNumber = function(...) return Phone.routeNumber(...) end
local telecomAuthorize = function(...) return Phone.telecomAuthorize(...) end
local telecomCharge = function(...) return Phone.telecomCharge(...) end
local soundOf = function(...) return Phone.soundOf(...) end
local signalOf = function(...) return Phone.signalOf(...) end
local offline = function(...) return Phone.offline(...) end
local nameFor = function(...) return Phone.nameFor(...) end
local format = function(...) return Phone.format(...) end
local calls = Phone.calls
local playerCall = Phone.playerCall
local prefsOf = function(...) return Phone.prefsOf(...) end
local contactsOf = function(...) return Phone.contactsOf(...) end
local _t = function(...) return Phone.t(...) end

local function sendState(call, side, state, reason)
	local self = call[side]
	local other = call[side == 'caller' and 'callee' or 'caller']
	TriggerClientEvent('coe_phone:callState', self.playerId, {
		id = call.id,
		state = state,
		number = format(other.number),
		name = nameFor(self.serial, other.number),
		startedAt = call.startedAt,
		kind = call.kind,
		reason = reason,
		sound = state ~= 'ended' and soundOf(self.serial) or nil
	})
end

local function finish(call, reason)
	if not calls[call.id] then
		return
	end
	calls[call.id] = nil
	PhoneVoice.Close(call.voice)
	playerCall[call.caller.playerId] = nil
	playerCall[call.callee.playerId] = nil
	local now = os.time()
	local wasActive = call.state == 'active'
	local status = PhoneRules.CallStatus(reason, wasActive)
	local duration = wasActive and math.max(0, now - (call.startedAt or now)) or 0
	PhonePersistence.AddCall(call.caller.number, call.callee.number, status, duration, now, call.kind)
	if duration > 0 then
		CreateThread(function()
			telecomCharge(call.caller.number, call.kind, duration, call.callee.number, call.caller.holder)
		end)
	end
	-- Crédito esgotado aparece como motivo próprio na tela; no histórico fica como atendida.
	local shown = reason == 'no_credit' and reason or status
	sendState(call, 'caller', 'ended', shown)
	sendState(call, 'callee', 'ended', shown)
	local calleePrefs = prefsOf(call.callee.serial)
	if status == 'missed' and not (calleePrefs and calleePrefs.settings.dnd) then
		notify(call.callee.playerId, 'info', _t('missed_call', { caller = nameFor(call.callee.serial, call.caller.number) }))
	end
	log('info', 'system', 'phone_call_ended', { result = status, count = duration, operation = call.kind })
end

local CALL_KINDS = { voice = true, video = true }

local function dial(me, payload)
	local kind = payload.kind == nil and 'voice' or payload.kind
	if not CALL_KINDS[kind] then
		return { ok = false, error = 'invalid_request' }
	end
	if not me.number then
		return { ok = false, error = 'no_sim' }
	end
	local target = PhoneRules.Normalize(config, payload.number)
	if not target or target == me.number then
		return { ok = false, error = 'invalid_number' }
	end
	if playerCall[me.playerId] then
		return { ok = false, error = 'already_in_call' }
	end
	local myNetwork = offline(me.playerId, me.prefs)
	if myNetwork then
		return { ok = false, error = myNetwork }
	end
	local callee, routeError = routeNumber(target)
	if not callee then
		return { ok = false, error = routeError }
	end
	local targetPlayer = callee.playerId
	local now = os.time()
	if not targetPlayer or targetPlayer == me.playerId or offline(targetPlayer, prefsOf(callee.serial)) then
		PhonePersistence.AddCall(me.number, target, 'unavailable', 0, now, kind)
		return { ok = false, error = 'unavailable' }
	end
	if playerCall[targetPlayer] then
		PhonePersistence.AddCall(me.number, target, 'busy', 0, now, kind)
		return { ok = false, error = 'busy' }
	end
	-- Quem liga paga: a operadora diz se pode e por quanto tempo o crédito dura.
	local line = telecomAuthorize(me.number, kind, me.holder)
	if not line.ok then
		return { ok = false, error = line.error or 'telecom_unavailable' }
	end
	if playerCall[me.playerId] or playerCall[targetPlayer] then
		return { ok = false, error = playerCall[me.playerId] and 'already_in_call' or 'busy' }
	end

	nextCallId = nextCallId + 1
	local call = {
		id = nextCallId,
		state = 'ringing',
		kind = kind,
		maxSeconds = tonumber(line.maxSeconds),
		caller = me,
		callee = callee
	}
	calls[call.id] = call
	playerCall[me.playerId] = call.id
	playerCall[targetPlayer] = call.id
	sendState(call, 'caller', 'outgoing')
	sendState(call, 'callee', 'incoming')
	SetTimeout(config.Calls.RingSeconds * 1000, function()
		if calls[call.id] == call and call.state == 'ringing' then
			finish(call, 'missed')
		end
	end)
	log('info', 'system', 'phone_call_started', { player_id = me.playerId, target = targetPlayer })
	return { ok = true }
end

local function answer(playerId)
	local call = calls[playerCall[playerId]]
	if not call or call.state ~= 'ringing' or call.callee.playerId ~= playerId then
		return { ok = false, error = 'no_call' }
	end
	call.state = 'active'
	call.startedAt = os.time()
	call.voice = PhoneVoice.Open(call.caller.playerId, call.callee.playerId)
	sendState(call, 'caller', 'active')
	sendState(call, 'callee', 'active')
	if call.maxSeconds and call.maxSeconds > 0 then
		SetTimeout(math.floor(call.maxSeconds * 1000), function()
			if calls[call.id] == call and call.state == 'active' then
				finish(call, 'no_credit')
			end
		end)
	end
	return { ok = true }
end

local function hangup(playerId)
	local call = calls[playerCall[playerId]]
	if not call then
		return { ok = false, error = 'no_call' }
	end
	if call.state == 'ringing' then
		finish(call, call.callee.playerId == playerId and 'declined' or 'missed')
	else
		finish(call, 'hangup')
	end
	return { ok = true }
end

-- Apps nativos -----------------------------------------------------------------------------------------

local Native = {}

Native.phone = {
	recents = function(me)
		if not me.number then
			return { ok = true, data = { recents = {} } }
		end
		local rows = PhonePersistence.Recents(me.number, config.Calls.RecentsLimit)
		if not rows then
			return { ok = false, error = 'database_error' }
		end
		local list = {}
		for _, row in ipairs(rows) do
			local outgoing = tostring(row.caller) == me.number
			local peer = tostring(outgoing and row.callee or row.caller)
			list[#list + 1] = {
				id = tonumber(row.id), outgoing = outgoing, number = format(peer), name = nameFor(me.serial, peer),
				status = tostring(row.status), duration = tonumber(row.duration) or 0, at = tonumber(row.created_at),
				kind = row.kind == 'video' and 'video' or 'voice'
			}
		end
		return { ok = true, data = { number = format(me.number), recents = list } }
	end,
	dial = function(me, payload)
		return dial(me, payload)
	end,
	answer = function(me)
		return answer(me.playerId)
	end,
	hangup = function(me)
		return hangup(me.playerId)
	end
}

Native.contacts = {
	list = function(me)
		local contacts = contactsOf(me.serial)
		if not contacts then
			return { ok = false, error = 'database_error' }
		end
		return { ok = true, data = contacts.list }
	end,
	save = function(me, payload)
		local name = PhoneRules.ContactName(config, payload.name)
		local number = PhoneRules.Normalize(config, payload.number)
		if not name then
			return { ok = false, error = 'invalid_name' }
		end
		if not number then
			return { ok = false, error = 'invalid_number' }
		end
		local id = payload.id ~= nil and math.tointeger(tonumber(payload.id)) or nil
		if payload.id ~= nil and not id then
			return { ok = false, error = 'invalid_request' }
		end
		local existing = PhonePersistence.ContactByNumber(me.serial, number)
		if existing == nil then
			return { ok = false, error = 'database_error' }
		end
		if existing and existing ~= id then
			return { ok = false, error = 'contact_exists' }
		end
		local result
		if id then
			result = PhonePersistence.UpdateContact(me.serial, id, name, number)
		else
			local total = PhonePersistence.CountContacts(me.serial)
			if not total then
				return { ok = false, error = 'database_error' }
			end
			if total >= config.Contacts.Max then
				return { ok = false, error = 'contacts_full' }
			end
			result = PhonePersistence.AddContact(me.serial, name, number)
		end
		contactCache[me.serial] = nil
		if not result then
			return { ok = false, error = 'database_error' }
		end
		return { ok = true }
	end,
	delete = function(me, payload)
		local id = math.tointeger(tonumber(payload.id))
		if not id then
			return { ok = false, error = 'invalid_request' }
		end
		local result = PhonePersistence.DeleteContact(me.serial, id)
		contactCache[me.serial] = nil
		return result and { ok = true } or { ok = false, error = 'database_error' }
	end
}
Phone.sendState = sendState
Phone.finish = finish
Phone.dial = dial
Phone.answer = answer
Phone.hangup = hangup
Phone.CALL_DISPATCH = CALL_DISPATCH