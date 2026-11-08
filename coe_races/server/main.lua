-- coe_races (servidor): corridas ilegais de rua. Pistas com checkpoints, corridas organizadas pelo tablet de corridas,
-- entrada em cripto na custódia do coe_crypto, largada no grid com contagem, checkpoints conferidos aqui (posição,
-- ordem, velocidade e o mesmo veículo da largada), chegada, pote, ranking, recordes e risco de a polícia aparecer.
local config = RacesConfig
local Rules = RacesRules
local Store = RacesPersistence

local ready = false
local tracks = {}          -- id -> pista
local races = {}           -- id -> corrida em memória (lobby, countdown, running)
local racerOf = {}         -- characterId -> raceId
local lastCall = {}
local callLimiter = Rules.NewCallLimiter and Rules.NewCallLimiter(config.CallCooldownMs) or nil

local _t = (Core and Core.Locale and Core.Locale.Bind) and Core.Locale.Bind(Locales) or function(k) return (Locales and Locales['pt-BR'] and Locales['pt-BR'][k]) or k end

local function log(level, category, event, context)
	pcall(function() return exports.coe_logging:Log(level, category, event, context) end)
end

local function audit(event, context)
	pcall(function() return exports.coe_audit:Record('info', 'audit', event, context) end)
end

local function notify(playerId, kind, message)
	pcall(function() exports.coe_notify:Notify(playerId, kind, message) end)
end

local function started(resource)
	return GetResourceState(resource) == 'started'
end

local function remote(resource, name, ...)
	if not started(resource) then
		return nil
	end
	local args = table.pack(...)
	local ok, result = pcall(function()
		return exports[resource][name](exports[resource], table.unpack(args, 1, args.n))
	end)
	if not ok then
		log('warn', 'system', 'races_remote_failed', { action = resource .. ':' .. name, error_code = tostring(result):sub(1, 96) })
		return nil
	end
	return result
end

local function now() return GetGameTimer() end

local function characterOf(playerId)
	local id = Core.Players.GetActiveCharacterId(playerId)
	return id and tostring(id) or nil
end

local function coordsOf(playerId)
	local ped = GetPlayerPed(playerId)
	if not ped or ped == 0 then
		return nil
	end
	local c = Core.Platform.Entities.GetCoords(ped)
	return { x = c.x, y = c.y, z = c.z }
end

local function hasTablet(playerId)
	local characterId = characterOf(playerId)
	return characterId ~= nil and (tonumber(remote('coe_inventory', 'GetItemCount', 'character:' .. characterId, config.Item)) or 0) > 0
end

-- Admins do txAdmin (login no painel do txAdmin) contam como staff, como nas ferramentas da staff.
local txAdmins = {}
AddEventHandler('txAdmin:events:adminAuth', function(data)
	if type(data) ~= 'table' then
		return
	end
	local netId = tonumber(data.netid)
	if netId == -1 then
		txAdmins = {}
	elseif netId then
		txAdmins[netId] = data.isAdmin == true or nil
	end
end)

-- Staff: ACE coe_races.admin no principal do jogador (ex.: add_ace group.admin coe_races.admin allow).
-- O runtime pode devolver 1 em vez de true, como em Core.Platform.Players.IsAceAllowed.
local function isAdmin(playerId)
	playerId = tonumber(playerId)
	if not playerId then
		return false
	end
	if txAdmins[playerId] then
		return true
	end
	local ok, allowed = pcall(IsPlayerAceAllowed, playerId, config.AdminAce)
	return ok and (allowed == true or allowed == 1)
end

local function format(units)
	return remote('coe_crypto', 'Format', units) or tostring(units)
end

-- Chave do aparelho para a cripto: as carteiras do celular que o piloto carrega (e as de papel/pen drive no
-- inventário). Sem celular, só as do inventário.
local function walletKey(playerId, characterId)
	local device = remote('coe_phone', 'ActiveDevice', playerId)
	if type(device) == 'table' and type(device.serial) == 'string' and device.serial:match('^[%w%-_]+$') then
		return 'phone:' .. device.serial
	end
	return 'racepad:' .. characterId
end

-- Pistas -----------------------------------------------------------------------------------------------------------

local function trackSummary(track)
	return {
		id = track.id, name = track.name, description = track.description, kind = track.kind, length = track.length,
		checkpoints = #track.checkpoints, creator = track.creatorName, status = track.status, races = track.races,
		start = { x = track.start.x, y = track.start.y }
	}
end

-- Corridas: visões ---------------------------------------------------------------------------------------------------

local function entryList(race)
	local list = {}
	for _, characterId in ipairs(race.order) do
		local entry = race.racers[characterId]
		if entry then
			list[#list + 1] = entry
		end
	end
	return list
end

local function raceSummary(race, characterId)
	local racers = {}
	for _, entry in ipairs(entryList(race)) do
		racers[#racers + 1] = { nickname = entry.nickname, rating = entry.rating }
	end
	return {
		id = race.id, status = race.status, track = trackSummary(race.track), laps = race.laps, buyIn = race.buyIn,
		buyInText = format(race.buyIn), class = race.class, classLabel = config.Classes[race.class].label,
		maxRacers = race.maxRacers, racers = racers, pot = race.buyIn * #racers, potText = format(race.buyIn * #racers),
		organizer = race.organizer.nickname, mine = race.organizer.characterId == characterId,
		joined = characterId ~= nil and race.racers[characterId] ~= nil, startAt = race.startAt
	}
end

-- O que o client do corredor precisa para a corrida (checkpoints, voltas, fase).
local function hudPayload(race)
	return {
		id = race.id, status = race.status, name = race.track.name, kind = race.track.kind, laps = race.laps,
		start = race.track.start, checkpoints = race.track.checkpoints, racers = #race.order,
		ghostSeconds = config.Races.GhostSeconds, countdown = config.Races.CountdownSeconds, gridRadius = config.Races.GridRadius,
		startsIn = race.startAt and math.max(0, race.startAt - os.time()) or 0
	}
end

local function sendRacers(race, event, payload)
	for _, entry in ipairs(entryList(race)) do
		if entry.playerId then
			TriggerClientEvent(event, entry.playerId, payload)
		end
	end
end

-- Dinheiro ------------------------------------------------------------------------------------------------------------

local function refund(race, entry, reason)
	if entry.amount > 0 and not entry.settled then
		local result = remote('coe_crypto', 'EscrowRelease', entry.payAddress, entry.amount, 'corrida #' .. race.id .. ' estorno')
		if type(result) ~= 'table' or not result.ok then
			log('error', 'gameplay', 'races_refund_failed', { target = 'race:' .. race.id, character_id = entry.characterId })
			return false
		end
	end
	entry.settled = true
	Store.SettleEntry(race.id, entry.characterId)
	log('info', 'gameplay', 'races_refund', { target = 'race:' .. race.id, character_id = entry.characterId, result = reason })
	return true
end

local function release(to, amount, memo)
	if amount <= 0 then
		return true
	end
	local result = remote('coe_crypto', 'EscrowRelease', to, amount, memo)
	return type(result) == 'table' and result.ok == true
end

-- Sair e cancelar -----------------------------------------------------------------------------------------------------

local function removeRacer(race, characterId, reason)
	local entry = race.racers[characterId]
	if not entry then
		return
	end
	refund(race, entry, reason)
	Store.DeleteEntry(race.id, characterId)
	race.racers[characterId] = nil
	for index, id in ipairs(race.order) do
		if id == characterId then
			table.remove(race.order, index)
			break
		end
	end
	racerOf[characterId] = nil
	if entry.playerId then
		TriggerClientEvent('coe_races:left', entry.playerId, race.id, reason)
	end
end

local function cancelRace(race, reason)
	for _, entry in ipairs(entryList(race)) do
		refund(race, entry, reason)
		racerOf[entry.characterId] = nil
		if entry.playerId then
			TriggerClientEvent('coe_races:left', entry.playerId, race.id, reason)
			notify(entry.playerId, 'info', _t('race_cancelled', { track = race.track.name }))
		end
	end
	race.status = 'cancelled'
	races[race.id] = nil
	Store.SetRaceStatus(race.id, 'cancelled')
	log('info', 'gameplay', 'races_cancelled', { target = 'race:' .. race.id, result = reason })
end

-- Fim da corrida: posições, pote, rating, resultados ------------------------------------------------------------------

local function standings(race)
	local list = {}
	for _, entry in ipairs(entryList(race)) do
		list[#list + 1] = entry
	end
	return Rules.Standings(list)
end

local function finishRace(race)
	race.status = 'finished'
	races[race.id] = nil
	local order = standings(race)
	local finishers = 0
	for _, entry in ipairs(order) do
		if entry.finishedAt then finishers = finishers + 1 end
	end
	local pot = race.buyIn * #order
	local split = Rules.Payouts(config, pot, #order, finishers)
	local ids = {}
	for _, entry in ipairs(order) do ids[#ids + 1] = entry.characterId end
	local profiles = Store.Profiles(ids) or {}
	local ratingInput = {}
	for _, entry in ipairs(order) do
		local profile = profiles[entry.characterId]
		ratingInput[#ratingInput + 1] = { id = entry.characterId, rating = profile and profile.rating or config.Rating.Start, place = entry.position }
	end
	local deltas = Rules.Rating(config, ratingInput)

	if split then
		-- Prêmios: cada colocado recebe na carteira que escolheu; a parte do organizador vai para a dele.
		for _, entry in ipairs(order) do
			local prize = entry.finishedAt and split.prizes[entry.position] or 0
			if prize and prize > 0 then
				if release(entry.payoutAddress, prize, 'corrida #' .. race.id .. ' ' .. entry.position .. 'º lugar') then
					entry.prize = prize
				else
					log('error', 'gameplay', 'races_prize_failed', { target = 'race:' .. race.id, character_id = entry.characterId, count = prize })
				end
			end
		end
		if split.fee > 0 then
			local feeTo = race.payoutAddress or (order[1] and order[1].payoutAddress)
			if not release(feeTo, split.fee, 'corrida #' .. race.id .. ' organizador') then
				log('error', 'gameplay', 'races_fee_failed', { target = 'race:' .. race.id, count = split.fee })
			end
		end
		for _, entry in ipairs(order) do
			entry.settled = true
			Store.SettleEntry(race.id, entry.characterId)
		end
	else
		-- Ninguém terminou: cada um recebe a entrada de volta.
		for _, entry in ipairs(order) do
			refund(race, entry, 'no_finishers')
		end
	end

	local results = {}
	for _, entry in ipairs(order) do
		local delta = deltas[entry.characterId] or 0
		Store.ApplyResult(entry.characterId, {
			delta = delta, win = entry.position == 1 and entry.finishedAt ~= nil, podium = entry.position <= 3 and entry.finishedAt ~= nil,
			dnf = entry.finishedAt == nil, prize = entry.prize or 0
		}, config.Rating.Min)
		Store.InsertResult({
			raceId = race.id, trackId = race.track.id, characterId = entry.characterId, nickname = entry.nickname,
			position = entry.position, racers = #order, timeMs = entry.timeMs, bestLapMs = entry.bestLap, laps = race.laps,
			class = race.class, vehicle = entry.vehicleLabel, dnf = entry.finishedAt == nil, ratingDelta = delta, prize = entry.prize or 0
		})
		results[#results + 1] = {
			position = entry.position, nickname = entry.nickname, timeMs = entry.timeMs, bestLapMs = entry.bestLap,
			dnf = entry.finishedAt == nil, ratingDelta = delta, prize = entry.prize or 0, prizeText = format(entry.prize or 0),
			vehicle = entry.vehicleLabel
		}
		racerOf[entry.characterId] = nil
	end
	Store.SetRaceStatus(race.id, 'finished')
	Store.CountRace(race.track.id)
	race.track.races = race.track.races + 1
	local payload = { id = race.id, track = race.track.name, results = results, potText = format(pot) }
	sendRacers(race, 'coe_races:results', payload)
	audit('races_finished', { target = 'race:' .. race.id, count = #order })
end

-- Largada -----------------------------------------------------------------------------------------------------------------

local function alertPolice(race, at)
	if not started('coe_dispatch') then
		return
	end
	local result = remote('coe_dispatch', 'Alert', config.Police.Code, at.x, at.y, at.z)
	if type(result) == 'table' and result.error then
		log('warn', 'gameplay', 'races_police_alert_failed', { target = 'race:' .. race.id, error_code = tostring(result.error) })
	else
		log('info', 'gameplay', 'races_police_alert', { target = 'race:' .. race.id })
	end
end

-- Confere o grid: cada corredor no carro, perto da largada, com a classe certa. Quem não está sai (com estorno).
local function checkGrid(race)
	for _, entry in ipairs(entryList(race)) do
		local reason = nil
		local ready_ = race.ready[entry.characterId]
		local ped = entry.playerId and GetPlayerPed(entry.playerId)
		local vehicle = ped and ped ~= 0 and GetVehiclePedIsIn(ped, false) or 0
		local at = entry.playerId and coordsOf(entry.playerId)
		if not entry.playerId or not at then
			reason = 'offline'
		elseif vehicle == 0 or not ready_ then
			reason = 'not_in_vehicle'
		elseif Rules.Distance(at, race.track.start) > config.Races.GridRadius then
			reason = 'not_on_grid'
		elseif Core.Platform.Entities.GetNetworkId(vehicle) ~= ready_.netId or GetPedInVehicleSeat(vehicle, -1) ~= ped then
			reason = 'not_driver'
		elseif not Rules.ClassAllowed(config, race.class, ready_.classId) then
			reason = 'wrong_class'
		end
		if reason then
			if entry.playerId then
				notify(entry.playerId, 'error', _t('removed_' .. reason))
			end
			removeRacer(race, entry.characterId, reason)
		else
			entry.vehicleNet = ready_.netId
			entry.vehicleLabel = ready_.label or ''
		end
	end
	return #race.order >= config.Races.MinRacers
end

local function beginCountdown(race)
	race.status = 'countdown'
	race.ready = {}
	sendRacers(race, 'coe_races:prepare', { id = race.id })
	SetTimeout(3000, function()
		if races[race.id] ~= race or race.status ~= 'countdown' then
			return
		end
		if not checkGrid(race) then
			for _, entry in ipairs(entryList(race)) do
				if entry.playerId then notify(entry.playerId, 'error', _t('not_enough_racers')) end
			end
			cancelRace(race, 'not_enough_racers')
			return
		end
		local seconds = config.Races.CountdownSeconds
		race.goAt = now() + seconds * 1000
		race.ghostUntil = race.goAt + config.Races.GhostSeconds * 1000
		for _, entry in ipairs(entryList(race)) do
			entry.progress = 0
			entry.lastCp = nil
		end
		local payload = hudPayload(race)
		payload.goIn = seconds * 1000
		-- Veículos do grid: o client desliga a colisão entre eles na largada (fantasma).
		payload.vehicles = {}
		for _, entry in ipairs(entryList(race)) do
			payload.vehicles[#payload.vehicles + 1] = entry.vehicleNet
		end
		payload.status = 'countdown'
		sendRacers(race, 'coe_races:race', payload)
		SetTimeout(seconds * 1000, function()
			if races[race.id] ~= race then
				return
			end
			race.status = 'running'
			race.startTime = now()
			race.deadline = race.startTime + Rules.MaxDuration(config, race.track.length, race.laps) * 1000
			race.nextPoliceTick = race.startTime + config.Police.TickSeconds * 1000
			for _, entry in ipairs(entryList(race)) do
				entry.lapStart = race.startTime
			end
			Store.SetRaceStatus(race.id, 'running')
			local sirens = false
			for _, info in pairs(race.ready) do
				if info.sirens then sirens = true end
			end
			if math.random() < Rules.PoliceChance(config, #race.order, sirens) then
				alertPolice(race, race.track.start)
			end
			sendRacers(race, 'coe_races:go', { id = race.id })
			log('info', 'gameplay', 'races_started', { target = 'race:' .. race.id, count = #race.order })
		end)
	end)
end

-- Ações do app -------------------------------------------------------------------------------------------------------------

local App = {}

local function profileOf(characterId)
	local profile = Store.Profile(characterId)
	return profile or nil
end

local function requireProfile(characterId)
	local profile = Store.Profile(characterId)
	if profile == nil then
		return nil, 'database_error'
	end
	if not profile then
		return nil, 'no_nickname'
	end
	return profile
end

local function myRaceView(characterId)
	local raceId = racerOf[characterId]
	local race = raceId and races[raceId]
	return race and raceSummary(race, characterId) or nil
end

function App.state(ctx)
	local open = {}
	for _, race in pairs(races) do
		if race.status == 'lobby' then
			open[#open + 1] = raceSummary(race, ctx.characterId)
		end
	end
	table.sort(open, function(a, b) return a.startAt < b.startAt end)
	local classes = {}
	for id, class in pairs(config.Classes) do
		classes[#classes + 1] = { id = id, label = class.label }
	end
	table.sort(classes, function(a, b) return a.id == 'any' or (b.id ~= 'any' and a.label < b.label) end)
	return { ok = true, data = {
		profile = profileOf(ctx.characterId), admin = isAdmin(ctx.playerId), races = open, myRace = myRaceView(ctx.characterId),
		organizing = (function()
			for _, race in pairs(races) do
				if race.organizer.characterId == ctx.characterId then return raceSummary(race, ctx.characterId) end
			end
		end)(),
		classes = classes, now = os.time(), quitCommand = config.QuitCommand,
		limits = {
			buyInMax = config.BuyIn.Max, maxRacers = config.Races.MaxRacers, minRacers = config.Races.MinRacers,
			maxLaps = config.Tracks.MaxLaps, minStart = config.Races.MinStartMinutes, maxStart = config.Races.MaxStartMinutes,
			minRacesToCreate = config.Tracks.MinRacesToCreate, feeBps = config.BuyIn.OrganizerFeeBps,
			nicknameMin = config.Nickname.Min, nicknameMax = config.Nickname.Max, minSpacing = config.Tracks.MinSpacing,
			minCheckpoints = config.Tracks.MinCheckpoints, maxCheckpoints = config.Tracks.MaxCheckpoints
		}
	} }
end

function App.setNickname(ctx, payload)
	local nickname, err = Rules.Nickname(payload.nickname, config)
	if not nickname then
		return { ok = false, error = err }
	end
	if racerOf[ctx.characterId] then
		return { ok = false, error = 'in_race' }
	end
	local saved, saveErr = Store.SaveNickname(ctx.characterId, nickname, config.Rating.Start)
	if not saved then
		return { ok = false, error = saveErr }
	end
	return App.state(ctx)
end

function App.tracks(ctx)
	local list = {}
	local admin = isAdmin(ctx.playerId)
	for _, track in pairs(tracks) do
		if track.status ~= 'hidden' or admin or track.creatorId == ctx.characterId then
			local summary = trackSummary(track)
			summary.mine = track.creatorId == ctx.characterId
			list[#list + 1] = summary
		end
	end
	table.sort(list, function(a, b)
		if (a.status == 'featured') ~= (b.status == 'featured') then return a.status == 'featured' end
		if a.races ~= b.races then return a.races > b.races end
		return a.name < b.name
	end)
	return { ok = true, data = { tracks = list } }
end

function App.track(ctx, payload)
	local track = tracks[Rules.Integer(payload.id, 1, 2 ^ 40) or 0]
	if not track or (track.status == 'hidden' and not isAdmin(ctx.playerId) and track.creatorId ~= ctx.characterId) then
		return { ok = false, error = 'unknown_track' }
	end
	local laps = track.kind == 'circuit' and (Rules.Integer(payload.laps, 1, config.Tracks.MaxLaps) or 3) or 1
	local records = Store.Records(track.id, laps, 10)
	local summary = trackSummary(track)
	summary.mine = track.creatorId == ctx.characterId
	summary.points = track.checkpoints
	summary.startFull = track.start
	return { ok = true, data = { track = summary, records = records or { laps = {}, total = {} }, recordLaps = laps } }
end

function App.wallets(ctx)
	if not started('coe_crypto') then
		return { ok = false, error = 'crypto_unavailable' }
	end
	local list = remote('coe_crypto', 'HeldWallets', ctx.playerId, walletKey(ctx.playerId, ctx.characterId))
	if type(list) ~= 'table' then
		return { ok = false, error = 'crypto_unavailable' }
	end
	for _, wallet in ipairs(list) do
		wallet.balanceText = format(wallet.balance)
	end
	return { ok = true, data = { wallets = list } }
end

local function validAddress(address)
	return type(address) == 'string' and remote('coe_crypto', 'IsAddress', address) == true
end

-- Inscreve: trava a entrada na custódia (se houver) e guarda para onde vai o prêmio.
local function join(ctx, race, profile, payload)
	if race.status ~= 'lobby' then
		return nil, 'race_started'
	end
	if racerOf[ctx.characterId] then
		return nil, 'already_racing'
	end
	if #race.order >= race.maxRacers then
		return nil, 'race_full'
	end
	local payAddress, payoutAddress = nil, nil
	if race.buyIn > 0 then
		if not validAddress(payload.from) then
			return nil, 'invalid_wallet'
		end
		payoutAddress = (payload.payout == nil or payload.payout == '') and payload.from or payload.payout
		if not validAddress(payoutAddress) then
			return nil, 'invalid_payout'
		end
	end
	local sagaCtx = { errorCode = nil }
	local sagaOk = Rules.ExecuteSaga({
		{
			name = 'escrow_lock',
			action = function()
				if race.buyIn <= 0 then
					return true
				end
				local locked = remote('coe_crypto', 'EscrowLock', ctx.playerId, walletKey(ctx.playerId, ctx.characterId), payload.from,
					race.buyIn, 'corrida #' .. race.id .. ' entrada')
				if type(locked) ~= 'table' or not locked.ok then
					sagaCtx.errorCode = type(locked) == 'table' and locked.error or 'crypto_unavailable'
					return false
				end
				payAddress = payload.from
				return true
			end,
			compensate = function()
				if race.buyIn > 0 and payAddress then
					release(payAddress, race.buyIn, 'corrida #' .. race.id .. ' estorno')
				end
			end
		},
		{
			name = 'insert_entry',
			action = function()
				local saved = Store.InsertEntry(race.id, ctx.characterId, payAddress, payoutAddress, race.buyIn)
				if not saved then
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
	local entry = {
		characterId = ctx.characterId, playerId = ctx.playerId, nickname = profile.nickname, rating = profile.rating,
		payAddress = payAddress, payoutAddress = payoutAddress, amount = race.buyIn, progress = 0, settled = false
	}
	race.racers[ctx.characterId] = entry
	race.order[#race.order + 1] = ctx.characterId
	racerOf[ctx.characterId] = race.id
	TriggerClientEvent('coe_races:joined', ctx.playerId, hudPayload(race))
	log('info', 'gameplay', 'races_joined', { target = 'race:' .. race.id, character_id = ctx.characterId, count = race.buyIn })
	return true
end

function App.createRace(ctx, payload)
	local profile, err = requireProfile(ctx.characterId)
	if not profile then
		return { ok = false, error = err }
	end
	local track = tracks[Rules.Integer(payload.trackId, 1, 2 ^ 40) or 0]
	if not track or track.status == 'hidden' then
		return { ok = false, error = 'unknown_track' }
	end
	local options, optionsErr = Rules.RaceOptions(config, track, payload)
	if not options then
		return { ok = false, error = optionsErr }
	end
	local open, mine = 0, 0
	for _, race in pairs(races) do
		open = open + 1
		if race.organizer.characterId == ctx.characterId then mine = mine + 1 end
	end
	if open >= config.Races.MaxOpen then
		return { ok = false, error = 'too_many_races' }
	end
	if mine >= config.Races.MaxOpenPerOrganizer then
		return { ok = false, error = 'already_organizing' }
	end
	local payoutAddress = nil
	if options.buyIn > 0 then
		if not started('coe_crypto') then
			return { ok = false, error = 'crypto_unavailable' }
		end
		payoutAddress = payload.feeAddress
		if not validAddress(payoutAddress) then
			return { ok = false, error = 'invalid_payout' }
		end
	end
	local raceId = Store.InsertRace({ trackId = track.id, organizerId = ctx.characterId, laps = options.laps, buyIn = options.buyIn,
		class = options.class, payoutAddress = payoutAddress })
	if not raceId then
		return { ok = false, error = 'database_error' }
	end
	local race = {
		id = raceId, track = track, laps = options.laps, buyIn = options.buyIn, class = options.class, maxRacers = options.maxRacers,
		organizer = { characterId = ctx.characterId, playerId = ctx.playerId, nickname = profile.nickname },
		payoutAddress = payoutAddress, status = 'lobby', startAt = os.time() + options.startIn * 60, racers = {}, order = {}, ready = {}
	}
	races[raceId] = race
	audit('races_created', { target = 'race:' .. raceId, character_id = ctx.characterId, count = options.buyIn })
	if payload.join == true then
		local joined, joinErr = join(ctx, race, profile, payload)
		if not joined then
			races[raceId] = nil
			Store.SetRaceStatus(raceId, 'cancelled')
			return { ok = false, error = joinErr }
		end
	end
	return App.state(ctx)
end

local function raceOf(payload)
	local race = races[Rules.Integer(payload.raceId, 1, 2 ^ 40) or 0]
	return race
end

function App.join(ctx, payload)
	local profile, err = requireProfile(ctx.characterId)
	if not profile then
		return { ok = false, error = err }
	end
	local race = raceOf(payload)
	if not race then
		return { ok = false, error = 'unknown_race' }
	end
	local joined, joinErr = join(ctx, race, profile, payload)
	if not joined then
		return { ok = false, error = joinErr }
	end
	return App.state(ctx)
end

function App.leave(ctx, payload)
	local race = raceOf(payload)
	if not race or not race.racers[ctx.characterId] then
		return { ok = false, error = 'not_in_race' }
	end
	if race.status ~= 'lobby' then
		return { ok = false, error = 'race_started' }
	end
	removeRacer(race, ctx.characterId, 'left')
	return App.state(ctx)
end

function App.startNow(ctx, payload)
	local race = raceOf(payload)
	if not race or race.organizer.characterId ~= ctx.characterId then
		return { ok = false, error = 'not_organizer' }
	end
	if race.status ~= 'lobby' then
		return { ok = false, error = 'race_started' }
	end
	if #race.order < config.Races.MinRacers then
		return { ok = false, error = 'not_enough_racers' }
	end
	beginCountdown(race)
	return App.state(ctx)
end

function App.cancelRace(ctx, payload)
	local race = raceOf(payload)
	if not race then
		return { ok = false, error = 'unknown_race' }
	end
	local admin = isAdmin(ctx.playerId)
	if race.organizer.characterId ~= ctx.characterId and not admin then
		return { ok = false, error = 'not_organizer' }
	end
	if race.status ~= 'lobby' and not admin then
		return { ok = false, error = 'race_started' }
	end
	cancelRace(race, admin and 'staff' or 'organizer')
	audit('races_cancel', { target = 'race:' .. race.id, character_id = ctx.characterId })
	return App.state(ctx)
end

function App.leaderboard(ctx)
	return { ok = true, data = { leaders = Store.Leaderboard(config.LeaderboardSize) or {}, me = profileOf(ctx.characterId) } }
end

function App.history(ctx)
	return { ok = true, data = { history = Store.History(ctx.characterId, config.HistorySize) or {} } }
end

-- Quem pode criar pista agora, com nome e descrição já validados.
local function canCreateTrack(ctx, payload)
	local profile, err = requireProfile(ctx.characterId)
	if not profile then
		return nil, err
	end
	local admin = isAdmin(ctx.playerId)
	if not admin and profile.races < config.Tracks.MinRacesToCreate then
		return nil, 'not_enough_races'
	end
	local mine = 0
	for _, track in pairs(tracks) do
		if track.creatorId == ctx.characterId then mine = mine + 1 end
	end
	if not admin and mine >= config.Tracks.MaxPerCreator then
		return nil, 'too_many_tracks'
	end
	local name = Rules.Text(payload.name, 3, config.Tracks.NameMax)
	if not name then
		return nil, 'invalid_name'
	end
	local description = ''
	if payload.description ~= nil and payload.description ~= '' then
		description = Rules.Text(payload.description, 1, config.Tracks.DescriptionMax)
		if not description then
			return nil, 'invalid_description'
		end
	end
	if payload.kind ~= 'sprint' and payload.kind ~= 'circuit' then
		return nil, 'invalid_kind'
	end
	return { profile = profile, admin = admin, name = name, description = description }
end

-- Começa a gravar: o client do piloto passa a marcar checkpoints dirigindo e manda tudo em saveTrack.
function App.startRecording(ctx, payload)
	local info, err = canCreateTrack(ctx, payload)
	if not info then
		return { ok = false, error = err }
	end
	if racerOf[ctx.characterId] then
		return { ok = false, error = 'in_race' }
	end
	TriggerClientEvent('coe_races:record', ctx.playerId, {
		name = info.name, description = info.description, kind = payload.kind, featured = info.admin and payload.featured == true,
		minSpacing = config.Tracks.MinSpacing, maxCheckpoints = config.Tracks.MaxCheckpoints, minCheckpoints = config.Tracks.MinCheckpoints,
		radius = config.Tracks.CheckpointRadius
	})
	return { ok = true, data = { recording = true } }
end

-- Pista nova, gravada dirigindo (o client manda largada e checkpoints).
function App.saveTrack(ctx, payload)
	local info, err = canCreateTrack(ctx, payload)
	if not info then
		return { ok = false, error = err }
	end
	local profile, admin, name, description = info.profile, info.admin, info.name, info.description
	local track, trackErr = Rules.Track(config, payload)
	if not track then
		return { ok = false, error = trackErr }
	end
	track.name, track.description = name, description
	track.creatorId, track.creatorName = ctx.characterId, profile.nickname
	track.status = admin and payload.featured == true and 'featured' or 'active'
	local id, saveErr = Store.InsertTrack(track)
	if not id then
		return { ok = false, error = saveErr }
	end
	track.id, track.races, track.createdAt = id, 0, os.time()
	tracks[id] = track
	audit('races_track_created', { target = 'track:' .. id, character_id = ctx.characterId, count = #track.checkpoints })
	return { ok = true, data = { track = trackSummary(track) } }
end

-- Staff: destacar, ocultar ou reativar. O criador só oculta ou reativa a própria.
function App.trackStatus(ctx, payload)
	local track = tracks[Rules.Integer(payload.id, 1, 2 ^ 40) or 0]
	if not track then
		return { ok = false, error = 'unknown_track' }
	end
	local admin = isAdmin(ctx.playerId)
	local status = payload.status
	if status ~= 'active' and status ~= 'hidden' and status ~= 'featured' then
		return { ok = false, error = 'invalid_status' }
	end
	if not admin and (track.creatorId ~= ctx.characterId or status == 'featured') then
		return { ok = false, error = 'forbidden' }
	end
	if not Store.SetTrackStatus(track.id, status) then
		return { ok = false, error = 'database_error' }
	end
	track.status = status
	audit('races_track_status', { target = 'track:' .. track.id, character_id = ctx.characterId, result = status })
	return App.tracks(ctx)
end

-- Staff: corridas em andamento (para cancelar).
function App.adminRaces(ctx)
	if not isAdmin(ctx.playerId) then
		return { ok = false, error = 'forbidden' }
	end
	local list = {}
	for _, race in pairs(races) do
		list[#list + 1] = raceSummary(race, ctx.characterId)
	end
	return { ok = true, data = { races = list } }
end

local READ_ACTIONS = { state = true, tracks = true, track = true, leaderboard = true, history = true, wallets = true }

local function handle(playerId, action, payload)
	if not ready then
		return { ok = false, error = 'not_ready' }
	end
	local handler = type(action) == 'string' and rawget(App, action)
	if type(handler) ~= 'function' then
		return { ok = false, error = 'unknown_action' }
	end
	if payload ~= nil and (type(payload) ~= 'table' or #json.encode(payload) > config.MaxPayloadBytes) then
		return { ok = false, error = 'invalid_payload' }
	end
	local characterId = characterOf(playerId)
	if not characterId then
		return { ok = false, error = 'no_character' }
	end
	if not hasTablet(playerId) then
		return { ok = false, error = 'no_tablet' }
	end
	local t = now()
	if not READ_ACTIONS[action] then
		if callLimiter then
			if not callLimiter:allow(playerId, t) then
				return { ok = false, error = 'rate_limited' }
			end
		elseif lastCall[playerId] and t - lastCall[playerId] < config.CallCooldownMs then
			return { ok = false, error = 'rate_limited' }
		end
		lastCall[playerId] = t
	end
	return handler({ playerId = playerId, characterId = characterId }, payload or {})
end

local function safeHandle(playerId, action, payload)
	local ok, result = pcall(handle, playerId, action, payload)
	if not ok then
		log('error', 'system', 'races_action_failed', { player_id = playerId, action = tostring(action):sub(1, 32), error_code = tostring(result):sub(1, 96) })
		return { ok = false, error = 'internal_error' }
	end
	return result
end

-- Tablet de corridas (aparelho próprio) e app no COE OS (coe_tablet).
RegisterNetEvent('coe_races:call', function(requestId, action, payload)
	local playerId = source
	if type(requestId) ~= 'number' then
		return
	end
	TriggerClientEvent('coe_races:result', playerId, requestId, safeHandle(playerId, action, payload))
end)

RegisterNetEvent('coe_races:open', function()
	local playerId = source
	if not ready or not characterOf(playerId) then
		return
	end
	if not hasTablet(playerId) then
		return notify(playerId, 'error', _t('no_tablet'))
	end
	TriggerClientEvent('coe_races:opened', playerId)
end)

exports('TabletVisible', function(playerId, appId)
	return GetInvokingResource() == 'coe_tablet' and appId == 'races' and ready and hasTablet(playerId)
end)

exports('TabletCall', function(playerId, appId, action, payload)
	if GetInvokingResource() ~= 'coe_tablet' or appId ~= 'races' then
		return { ok = false, error = 'forbidden' }
	end
	return safeHandle(tonumber(playerId), action, payload)
end)

-- Usar o item abre o tablet de corridas.
Core.Events.On('inventory.itemUsed', function(inventoryId, _slot, item)
	local characterId = type(inventoryId) == 'string' and inventoryId:match('^character:(.+)$')
	if not characterId or type(item) ~= 'table' or item.name ~= config.Item then
		return
	end
	for _, id in ipairs(GetPlayers()) do
		local playerId = tonumber(id)
		if playerId and characterOf(playerId) == characterId then
			TriggerClientEvent('coe_races:opened', playerId)
			return
		end
	end
end)

-- Corrida em andamento: grid, checkpoints e abandono ---------------------------------------------------------------

RegisterNetEvent('coe_races:ready', function(raceId, info)
	local playerId = source
	local characterId = characterOf(playerId)
	local race = races[raceId]
	if not race or race.status ~= 'countdown' or not characterId or not race.racers[characterId] or type(info) ~= 'table' then
		return
	end
	race.ready[characterId] = {
		netId = math.tointeger(tonumber(info.netId)), classId = math.tointeger(tonumber(info.classId)),
		label = type(info.label) == 'string' and info.label:sub(1, 32):gsub('[%c<>]', '') or '', sirens = info.sirens == true
	}
end)

local function entryOf(playerId, raceId)
	local characterId = characterOf(playerId)
	local race = races[raceId]
	if not race or not characterId then
		return nil
	end
	local entry = race.racers[characterId]
	if not entry or entry.playerId ~= playerId then
		return nil
	end
	return race, entry
end

local function inRaceVehicle(entry)
	local ped = GetPlayerPed(entry.playerId)
	if not ped or ped == 0 or not entry.vehicleNet then
		return false
	end
	local vehicle = GetVehiclePedIsIn(ped, false)
	return vehicle ~= 0 and Core.Platform.Entities.GetNetworkId(vehicle) == entry.vehicleNet
end

local function maybeFinish(race)
	for _, entry in ipairs(entryList(race)) do
		if not entry.finishedAt and not entry.dnf then
			return
		end
	end
	finishRace(race)
end

local function setDnf(race, entry, reason)
	if entry.finishedAt or entry.dnf then
		return
	end
	entry.dnf = true
	if entry.playerId then
		TriggerClientEvent('coe_races:dnf', entry.playerId, race.id, reason)
	end
	log('info', 'gameplay', 'races_dnf', { target = 'race:' .. race.id, character_id = entry.characterId, result = reason })
end

-- O client avisa que cruzou o próximo checkpoint; o servidor confere e registra a hora (a dele, não a do client).
RegisterNetEvent('coe_races:checkpoint', function(raceId, index)
	local playerId = source
	local race, entry = entryOf(playerId, raceId)
	if not race or race.status ~= 'running' or entry.finishedAt or entry.dnf then
		return
	end
	local total = #race.track.checkpoints * race.laps
	if type(index) ~= 'number' or math.tointeger(index) ~= entry.progress + 1 or index > total then
		return
	end
	if not inRaceVehicle(entry) then
		return
	end
	local cp = race.track.checkpoints[((index - 1) % #race.track.checkpoints) + 1]
	local at = coordsOf(playerId)
	local t = now()
	local ok, reason = Rules.CheckpointOk(config, cp, at, entry.lastCp, t)
	if not ok then
		if reason == 'too_fast' then
			log('warn', 'security', 'races_checkpoint_rejected', { target = 'race:' .. race.id, character_id = entry.characterId, result = reason })
		end
		return
	end
	entry.progress = index
	entry.lastCp = { at = { x = cp.x, y = cp.y, z = cp.z }, time = t }
	TriggerClientEvent('coe_races:checkpointOk', playerId, race.id, index)
	local perLap = #race.track.checkpoints
	if index % perLap == 0 then
		local lapTime = t - entry.lapStart
		entry.bestLap = (entry.bestLap and math.min(entry.bestLap, lapTime)) or lapTime
		entry.lapStart = t
		TriggerClientEvent('coe_races:lap', playerId, race.id, index // perLap, lapTime, entry.bestLap)
	end
	if index == total then
		entry.finishedAt = t
		entry.timeMs = t - race.startTime
		if not race.firstFinishAt then
			race.firstFinishAt = t
			race.finishDeadline = t + config.Races.FinishWindowSeconds * 1000
			sendRacers(race, 'coe_races:leaderFinished', { id = race.id, nickname = entry.nickname, seconds = config.Races.FinishWindowSeconds })
		end
		TriggerClientEvent('coe_races:finished', playerId, race.id, entry.timeMs)
		maybeFinish(race)
	end
end)

RegisterNetEvent('coe_races:quit', function(raceId)
	local playerId = source
	local race, entry = entryOf(playerId, raceId)
	if not race then
		return
	end
	if race.status == 'lobby' then
		removeRacer(race, entry.characterId, 'left')
	elseif race.status == 'running' then
		setDnf(race, entry, 'quit')
		maybeFinish(race)
	end
end)

-- Relógio das corridas: largada agendada, posições, abandono, prazo e polícia.
local function tick()
	local t = now()
	for _, race in pairs(races) do
		if race.status == 'lobby' and os.time() >= race.startAt then
			if #race.order >= config.Races.MinRacers then
				beginCountdown(race)
			else
				for _, entry in ipairs(entryList(race)) do
					if entry.playerId then notify(entry.playerId, 'error', _t('not_enough_racers')) end
				end
				if race.organizer.playerId then notify(race.organizer.playerId, 'error', _t('not_enough_racers')) end
				cancelRace(race, 'not_enough_racers')
			end
		elseif race.status == 'running' then
			local perLap = #race.track.checkpoints
			for _, entry in ipairs(entryList(race)) do
				if not entry.finishedAt and not entry.dnf then
					if not entry.playerId or not GetPlayerName(entry.playerId) then
						setDnf(race, entry, 'offline')
					elseif inRaceVehicle(entry) then
						entry.outSince = nil
					else
						entry.outSince = entry.outSince or t
						if t - entry.outSince > config.Races.OutOfVehicleSeconds * 1000 then
							setDnf(race, entry, 'left_vehicle')
						end
					end
					local at = entry.playerId and coordsOf(entry.playerId)
					local nextCp = race.track.checkpoints[(entry.progress % perLap) + 1]
					entry.distance = (at and nextCp) and Rules.Distance(at, nextCp) or 999999
				end
			end
			if t >= race.deadline or (race.finishDeadline and t >= race.finishDeadline) then
				for _, entry in ipairs(entryList(race)) do
					setDnf(race, entry, 'time')
				end
			end
			if races[race.id] == race then
				local order = standings(race)
				local view = {}
				for _, entry in ipairs(order) do
					view[#view + 1] = {
						nickname = entry.nickname, position = entry.position, progress = entry.progress,
						finished = entry.finishedAt ~= nil, dnf = entry.dnf == true, timeMs = entry.timeMs
					}
				end
				for _, entry in ipairs(order) do
					if entry.playerId then
						TriggerClientEvent('coe_races:standings', entry.playerId, {
							id = race.id, position = entry.position, racers = #order, elapsed = t - race.startTime, list = view
						})
					end
				end
				if t >= race.nextPoliceTick then
					race.nextPoliceTick = t + config.Police.TickSeconds * 1000
					local leader = order[1]
					local at = leader and leader.playerId and not leader.finishedAt and coordsOf(leader.playerId)
					if at and math.random() < config.Police.TickChance then
						alertPolice(race, at)
					end
				end
				maybeFinish(race)
			end
		end
	end
end

CreateThread(function()
	while true do
		Wait(config.Races.StandingsMs)
		if ready then
			local ok, err = pcall(tick)
			if not ok then
				log('error', 'system', 'races_tick_failed', { error_code = tostring(err):sub(1, 96) })
			end
		end
	end
end)

AddEventHandler('playerDropped', function()
	local playerId = source
	lastCall[playerId] = nil
	if callLimiter then
		callLimiter:reset(playerId)
	end
	txAdmins[tonumber(playerId) or playerId] = nil
	for _, race in pairs(races) do
		for _, entry in ipairs(entryList(race)) do
			if entry.playerId == playerId then
				if race.status == 'lobby' or race.status == 'countdown' then
					entry.playerId = nil
					removeRacer(race, entry.characterId, 'offline')
				else
					setDnf(race, entry, 'offline')
					entry.playerId = nil
				end
			end
		end
		if race.organizer.playerId == playerId then
			race.organizer.playerId = nil
		end
	end
end)

-- Inicialização: migrações, pistas e estorno do que ficou na custódia se o resource caiu no meio de uma corrida.
CreateThread(function()
	math.randomseed(os.time() + GetGameTimer())
	while true do
		local initialized, errorCode = Store.Initialize()
		if initialized then
			break
		end
		log(errorCode == 'database_not_ready' and 'info' or 'error', 'persistence', 'races_migrations_waiting', { error_code = tostring(errorCode) })
		Wait(errorCode == 'database_not_ready' and 1000 or 15000)
	end
	local list = Store.Tracks()
	while not list do
		Wait(5000)
		list = Store.Tracks()
	end
	for _, track in ipairs(list) do
		tracks[track.id] = track
	end
	local pending = Store.Unsettled() or {}
	for _, entry in ipairs(pending) do
		local deadline = GetGameTimer() + 60000
		while not started('coe_crypto') and GetGameTimer() < deadline do Wait(1000) end
		if release(entry.payAddress, entry.amount, 'corrida #' .. entry.raceId .. ' estorno') then
			Store.SettleEntry(entry.raceId, entry.characterId)
		else
			log('error', 'gameplay', 'races_refund_failed', { target = 'race:' .. entry.raceId, character_id = entry.characterId })
		end
	end
	Store.CancelStale()
	ready = true
	log('info', 'system', 'races_ready', { count = #list })
end)

-- Parar o resource no meio: devolve as entradas das corridas abertas.
AddEventHandler('onResourceStop', function(resource)
	if resource ~= GetCurrentResourceName() then
		return
	end
	for _, race in pairs(races) do
		cancelRace(race, 'resource_stop')
	end
end)
