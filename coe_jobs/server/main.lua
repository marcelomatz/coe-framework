-- coe_jobs (servidor): empregos livres do Coe. Carrega os empregos de jobs/*.lua (e de quem usar RegisterJob),
-- abre sessões de trabalho, valida cada ação, paga pelo coe_economy e mantém a carreira do personagem: XP por
-- emprego, nível de carreira, habilidades compartilhadas entre empregos e reputação (shared/career.lua).
local config = JobsConfig
local career = config.Career

local ready = false
local jobs = {}         -- id -> definição validada
local owners = {}       -- id -> resource que registrou
local sessions = {}     -- playerId -> sessão
local lastAction = {}   -- playerId -> GetGameTimer() da última ação
local records = {}      -- characterId -> { progress = { [jobId] = {xp,tasks,earned} }, reputation, completed, abandoned }

local knownSkills = {}
for id in pairs(career.skills) do
	knownSkills[id] = true
end

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

local rawLocales = (type(Locales) == 'table' and Locales) or {}
local _t_inst = (Core and Core.Locale and Core.Locale.New) and Core.Locale.New({
	default = (config and config.Locale) or (Core and Core.Locale and Core.Locale.GetDefaultLang()) or 'pt-BR',
	locales = rawLocales
})
local _t = function(k, params)
	local text
	if type(_t_inst) == 'table' then
		if _t_inst.T then
			return _t_inst:T(k, params)
		end
		local lang = _t_inst.lang or 'pt-BR'
		local dict = (_t_inst.locales and _t_inst.locales[lang]) or rawLocales[lang] or rawLocales['pt-BR']
		text = (dict and dict[k])
	elseif type(_t_inst) == 'function' then
		return _t_inst(k, params)
	end
	if not text then
		text = (rawLocales['pt-BR'] and rawLocales['pt-BR'][k]) or k
	end
	if text and params then
		for pk, pv in pairs(params) do
			text = text:gsub('%%{' .. pk .. '}', tostring(pv))
		end
	end
	return text
end

local function characterOf(playerId)
	local id = Core.Players.GetActiveCharacterId(playerId)
	return id and tostring(id) or nil
end

local function coordsOf(playerId)
	local ped = GetPlayerPed(playerId)
	if not ped or ped == 0 then
		return nil
	end
	local c = GetEntityCoords(ped)
	return { x = c.x, y = c.y, z = c.z }
end

local function money(value)
	local textValue = tostring(math.floor(value))
	return '$' .. textValue:reverse():gsub('(%d%d%d)', '%1.'):reverse():gsub('^%.', '')
end

local function percent(value)
	return math.floor(value * 100 + 0.5)
end

local function throttled(playerId)
	local now = GetGameTimer()
	if lastAction[playerId] and now - lastAction[playerId] < config.ActionCooldownMs then
		return true
	end
	lastAction[playerId] = now
	return false
end

local function reply(playerId, event, payload)
	TriggerClientEvent('coe_jobs:' .. event, playerId, payload)
end

local function publicCatalog()
	local list = {}
	for _, job in pairs(jobs) do
		list[#list + 1] = JobRules.Public(job)
	end
	table.sort(list, function(a, b) return a.label < b.label end)
	return list
end

local function broadcastCatalog()
	TriggerClientEvent('coe_jobs:catalog', -1, publicCatalog())
end

-- Carreira ------------------------------------------------------------------------------------------------

-- Histórico do personagem em memória (carregado do banco na primeira vez).
-- transient: consulta de quem pode estar offline (ex.: currículo no coe_elos); não fica guardado em memória.
local function recordOf(character, transient)
	local record = records[character]
	if record then
		return record
	end
	local progress = JobsPersistence.AllProgress(character)
	local profile = JobsPersistence.Profile(character)
	if not progress or not profile then
		return nil
	end
	-- Últimos trabalhos (só exibição: falha aqui não impede trabalhar).
	local recent = JobsPersistence.Sessions(character, config.RecentSessions) or {}
	record = {
		progress = progress, reputation = profile.reputation, completed = profile.completed, abandoned = profile.abandoned,
		sessions = recent
	}
	if not transient then
		records[character] = record
	end
	return record
end

local function profileOf(record)
	return JobCareer.Profile(career, jobs, record.progress, record.reputation)
end

local function progressOf(record, jobId)
	local progress = record.progress[jobId]
	if not progress then
		progress = { xp = 0, tasks = 0, earned = 0, seconds = 0 }
		record.progress[jobId] = progress
	end
	return progress
end

local function modifiersOf(job, record)
	return JobCareer.Modifiers(career, job, profileOf(record), progressOf(record, job.id).xp)
end

local function saveProfile(character, record)
	if not JobsPersistence.SaveProfile(character, record) then
		log('warn', 'persistence', 'jobs_profile_save_failed', { character_id = character })
	end
end

local function reputationEvent(character, record, event)
	record.reputation = JobCareer.Reputation(career, record.reputation, event)
	if event == 'complete' then
		record.completed = record.completed + 1
	elseif event == 'abandon' or event == 'lost_vehicle' then
		record.abandoned = record.abandoned + 1
	end
	saveProfile(character, record)
end

-- Avisa o que subiu: nível no emprego, carreira e habilidades.
local function announceGrowth(playerId, job, before, after, jobBefore, jobAfter)
	if jobAfter > jobBefore then
		notify(playerId, 'success', ('%s: nível %d no emprego.'):format(job.label, jobAfter))
	end
	if after.level > before.level then
		notify(playerId, 'success', ('Carreira nível %d: +%d%% de pagamento e +%d%% de XP em todos os empregos.'):format(
			after.level, percent((after.level - 1) * career.payPerLevel), percent((after.level - 1) * career.xpPerLevel)))
	end
	for id, skill in pairs(after.skills) do
		if skill.level > before.skills[id].level then
			notify(playerId, 'success', ('%s nível %d: vale em todos os empregos que usam %s.'):format(skill.label, skill.level, skill.label:lower()))
		end
	end
end

-- Soma XP (com o multiplicador da carreira), tarefa e ganhos; grava e avisa o que subiu.
local function grant(playerId, session, baseXp, earned)
	local job = jobs[session.jobId]
	local record = session.record
	local progress = progressOf(record, job.id)
	local before = profileOf(record)
	local jobBefore = JobRules.Level(job.levels, progress.xp)
	local xp = math.floor((baseXp or 0) * modifiersOf(job, record).xpMultiplier)
	progress.xp = progress.xp + xp
	progress.tasks = progress.tasks + 1
	progress.earned = progress.earned + (earned or 0)
	session.stats.xp = session.stats.xp + xp
	session.stats.tasks = session.stats.tasks + 1
	session.stats.earned = session.stats.earned + (earned or 0)
	if not JobsPersistence.Save(session.character, job.id, progress) then
		log('warn', 'persistence', 'jobs_progress_save_failed', { character_id = session.character, target = job.id })
	end
	announceGrowth(playerId, job, before, profileOf(record), jobBefore, JobRules.Level(job.levels, progress.xp))
	return xp
end

local function addEarned(session, amount)
	local progress = progressOf(session.record, session.jobId)
	progress.earned = progress.earned + amount
	session.stats.earned = session.stats.earned + amount
	JobsPersistence.Save(session.character, session.jobId, progress)
end

local function pay(session, base)
	local job = jobs[session.jobId]
	local amount = JobCareer.Apply(base, modifiersOf(job, session.record).payBonus)
	if amount <= 0 then
		return 0
	end
	local ok = exports.coe_economy:Credit(session.character, amount, config.LedgerPrefix .. job.id, job.id)
	if not ok then
		log('error', 'gameplay', 'jobs_payment_failed', { character_id = session.character, target = job.id, count = amount })
		return nil
	end
	return amount
end

local function sessionView(session)
	local job = jobs[session.jobId]
	local mods = modifiersOf(job, session.record)
	local profile = profileOf(session.record)
	local progress = progressOf(session.record, job.id)
	local view = {
		jobId = session.jobId, cargo = session.cargo, vehicle = session.vehicleNet, cooldowns = {},
		seconds = mods.seconds, capacity = mods.capacity, payBonus = mods.payBonus,
		progress = {
			xp = progress.xp, tasks = progress.tasks, earned = progress.earned, level = mods.jobLevel,
			maxLevel = #job.levels, nextXp = JobRules.NextLevelXp(job.levels, progress.xp)
		},
		career = { level = profile.level, xp = profile.xp, reputation = profile.reputation, tier = profile.tier.label }
	}
	if job.route and session.route then
		local route = session.route
		local stop = job.route.stops[route.stops[route.index]]
		view.route = { index = route.index, total = #route.stops, stop = stop, mode = job.route.mode, picked = route.picked == true }
		if job.route.mode == 'zone' then
			-- Zona atual: área para procurar lixeiras e quantos sacos faltam.
			local zone = job.route.zones[route.stops[route.index]]
			view.route.zone = { x = zone.x, y = zone.y, z = zone.z, radius = zone.radius, label = zone.label }
			view.route.collected, view.route.perZone = route.collected or 0, job.route.perZone
		end
		if job.route.mode == 'passenger' then
			-- Corrida n de N; a parada é o embarque (pickup) ou o destino (dropoff).
			view.route.index, view.route.total = math.ceil(route.index / 2), job.route.perRoute
			view.route.phase = route.index % 2 == 1 and 'pickup' or 'dropoff'
		end
	end
	local now = os.time()
	for node, untilAt in pairs(session.nodeCooldowns or {}) do
		if untilAt > now then
			view.cooldowns[#view.cooldowns + 1] = { node = node, seconds = untilAt - now }
		end
	end
	return view
end

-- Veículo do emprego --------------------------------------------------------------------------------

local function deleteVehicle(session)
	if session.vehicleNet then
		local entity = NetworkGetEntityFromNetworkId(session.vehicleNet)
		if entity and entity ~= 0 and DoesEntityExist(entity) then
			DeleteEntity(entity)
		end
	end
	session.vehicleNet = nil
end

local function vehicleCoords(session)
	if not session.vehicleNet then
		return nil
	end
	local entity = NetworkGetEntityFromNetworkId(session.vehicleNet)
	if not entity or entity == 0 or not DoesEntityExist(entity) then
		return nil
	end
	local c = GetEntityCoords(entity)
	return { x = c.x, y = c.y, z = c.z }
end

local function spawnVehicle(playerId, job)
	local spec = job.vehicle
	local entity = CreateVehicleServerSetter(joaat(spec.model), 'automobile', spec.spawn.x, spec.spawn.y, spec.spawn.z, spec.spawn.h)
	local deadline = GetGameTimer() + 3000
	while (not entity or entity == 0 or not DoesEntityExist(entity)) and GetGameTimer() < deadline do
		Wait(50)
	end
	if not entity or entity == 0 or not DoesEntityExist(entity) then
		return nil
	end
	SetVehicleNumberPlateText(entity, ('%s%04d'):format(spec.plate, math.random(0, 9999)))
	Entity(entity).state:set('coe:jobVehicle', job.id .. ':' .. playerId, true)
	return NetworkGetNetworkIdFromEntity(entity)
end

-- Sessões ---------------------------------------------------------------------------------------------

local function newRoute(job)
	return { stops = JobRules.PickStops(#job.route.stops, JobRules.RouteStops(job.route)), index = 1, picked = false, collected = 0 }
end

-- Resumo do trabalho encerrado: guarda nos últimos trabalhos do personagem (memória e banco) se algo foi feito.
local function recordSession(session, reason)
	local stats = session.stats
	local summary = {
		jobId = session.jobId, startedAt = session.openedAt, endedAt = os.time(), tasks = stats.tasks, xp = stats.xp,
		earned = stats.earned, discarded = session.cargo or 0, reason = reason
	}
	if stats.tasks == 0 and stats.earned == 0 and summary.discarded == 0 then
		return summary
	end
	-- Tempo trabalhado no emprego (currículo): soma da duração de cada trabalho com algo feito.
	local progress = progressOf(session.record, session.jobId)
	progress.seconds = (progress.seconds or 0) + math.max(0, summary.endedAt - (summary.startedAt or summary.endedAt))
	progress.firstAt = progress.firstAt or summary.startedAt
	progress.lastAt = summary.endedAt
	if not JobsPersistence.Save(session.character, session.jobId, progress) then
		log('warn', 'persistence', 'jobs_progress_save_failed', { character_id = session.character, target = session.jobId })
	end
	local list = session.record.sessions
	table.insert(list, 1, summary)
	while #list > config.RecentSessions do
		table.remove(list)
	end
	if not JobsPersistence.SaveSession(session.character, summary) then
		log('warn', 'persistence', 'jobs_session_save_failed', { character_id = session.character, target = session.jobId })
	end
	return summary
end

-- reason: stop (no centro), dropped, character, unavailable. Abandonar com o veículo da empresa custa reputação.
local function endSession(playerId, reason)
	local session = sessions[playerId]
	if not session then
		return
	end
	sessions[playerId] = nil
	local job = jobs[session.jobId]
	local refund = 0
	if job and job.vehicle then
		local coords = vehicleCoords(session)
		local returned = coords and JobRules.Near(coords, job.center, job.vehicle.returnRadius, 20.0)
		if reason == 'stop' and returned then
			if session.deposit > 0 and exports.coe_economy:Credit(session.character, session.deposit, config.LedgerPrefix .. 'deposit', job.id) then
				refund = session.deposit
			end
		elseif reason == 'stop' then
			reputationEvent(session.character, session.record, 'lost_vehicle')
		elseif reason == 'dropped' or reason == 'character' then
			reputationEvent(session.character, session.record, 'abandon')
		end
	end
	deleteVehicle(session)
	local summary = recordSession(session, reason)
	if reason ~= 'dropped' then
		reply(playerId, 'ended', { jobId = session.jobId, refund = refund, reason = reason, summary = summary })
	end
	return refund, summary
end

local function startSession(playerId, jobId)
	local job = jobs[jobId]
	if not job then
		return nil, 'unknown_job'
	end
	if sessions[playerId] then
		return nil, 'already_working'
	end
	local character = characterOf(playerId)
	if not character then
		return nil, 'no_character'
	end
	local coords = coordsOf(playerId)
	if not coords or not JobRules.Near(coords, job.center, config.CenterRadius, config.PointHeight) then
		return nil, 'too_far'
	end
	local record = recordOf(character)
	if not record then
		return nil, 'database_error'
	end
	local allowed, reason = JobCareer.Allowed(career, job, profileOf(record))
	if not allowed then
		return nil, 'locked', reason
	end
	local mods = modifiersOf(job, record)
	local session = {
		jobId = jobId, character = character, record = record, cargo = 0, deposit = 0,
		startedAt = GetGameTimer(), lastTaskAt = GetGameTimer(), nodeCooldowns = {},
		openedAt = os.time(), stats = { tasks = 0, xp = 0, earned = 0 }
	}
	if job.vehicle then
		local deposit = mods.deposit or 0
		if deposit > 0 then
			if not exports.coe_economy:Debit(character, deposit, config.LedgerPrefix .. 'deposit', job.id) then
				return nil, 'no_deposit'
			end
			session.deposit = deposit
		end
		session.vehicleNet = spawnVehicle(playerId, job)
		if not session.vehicleNet then
			if session.deposit > 0 then
				exports.coe_economy:Credit(character, session.deposit, config.LedgerPrefix .. 'deposit', job.id)
			end
			return nil, 'vehicle_failed'
		end
	end
	if job.route then
		session.route = newRoute(job)
		session.lastPoint = job.center
		session.previousStop = job.center
	end
	sessions[playerId] = session
	return session
end

-- Ações ---------------------------------------------------------------------------------------------------

local ERRORS = {
	unknown_job = 'err_unknown_job', already_working = 'err_already_working', no_character = 'err_no_character',
	too_far = 'err_too_far', database_error = 'err_database_error',
	no_deposit = 'err_no_deposit', vehicle_failed = 'err_vehicle_failed',
	not_working = 'err_not_working', cooldown = 'err_cooldown', too_fast = 'err_too_fast',
	full = 'err_full', empty = 'err_empty', vehicle_far = 'err_vehicle_far',
	payment_failed = 'err_payment_failed', wrong_step = 'err_wrong_step',
	outside_zone = 'err_outside_zone',
	bin_empty = 'err_bin_empty', locked = 'err_locked'
}

local function failure(playerId, code, detail)
	local errKey = ERRORS[code]
	local message = errKey and _t(errKey) or _t('generic_error')
	if detail then
		message = _t('needs_detail', { message = message, detail = detail })
	end
	notify(playerId, 'error', message)
	reply(playerId, 'result', { ok = false, error = code })
end

local function sessionFor(playerId, jobId, kind)
	local session = sessions[playerId]
	if not session or session.jobId ~= jobId then
		return nil
	end
	local job = jobs[jobId]
	if not job or job.kind ~= kind or characterOf(playerId) ~= session.character then
		return nil
	end
	return session, job
end

local function gather(playerId, jobId, nodeIndex)
	local session, job = sessionFor(playerId, jobId, 'gather')
	if not session then
		return failure(playerId, 'not_working')
	end
	local node = job.gather.nodes[math.tointeger(nodeIndex) or -1]
	local coords = coordsOf(playerId)
	if not node or not coords or not JobRules.Near(coords, node, config.PointRadius, config.PointHeight) then
		return failure(playerId, 'too_far')
	end
	local now = os.time()
	if (session.nodeCooldowns[nodeIndex] or 0) > now then
		return failure(playerId, 'cooldown')
	end
	local mods = modifiersOf(job, session.record)
	if GetGameTimer() - session.lastTaskAt < mods.seconds * 1000 * config.GatherTimeSlack then
		return failure(playerId, 'too_fast')
	end
	if session.cargo >= mods.capacity then
		return failure(playerId, 'full')
	end
	local amount = math.min(math.random(job.gather.yield[1], job.gather.yield[2]), mods.capacity - session.cargo)
	session.cargo = session.cargo + amount
	session.lastTaskAt = GetGameTimer()
	session.nodeCooldowns[nodeIndex] = now + job.gather.nodeCooldown
	grant(playerId, session, job.gather.xp, 0)
	notify(playerId, 'info', ('+%d %s (%d/%d).'):format(amount, amount == 1 and job.gather.unit or job.gather.units, session.cargo, mods.capacity))
	reply(playerId, 'session', sessionView(session))
end

local function sell(playerId, jobId, pointIndex)
	local session, job = sessionFor(playerId, jobId, 'gather')
	if not session then
		return failure(playerId, 'not_working')
	end
	local spot = job.gather.sell.points[math.tointeger(pointIndex) or -1]
	local coords = coordsOf(playerId)
	if not spot or not coords or not JobRules.Near(coords, spot, config.PointRadius, config.PointHeight) then
		return failure(playerId, 'too_far')
	end
	if session.cargo <= 0 then
		return failure(playerId, 'empty')
	end
	local units = session.cargo
	local amount = pay(session, units * job.gather.sell.price)
	if not amount then
		return failure(playerId, 'payment_failed')
	end
	session.cargo = 0
	addEarned(session, amount)
	reputationEvent(session.character, session.record, 'complete')
	notify(playerId, 'success', ('Vendeu %d %s por %s.'):format(units, units == 1 and job.gather.unit or job.gather.units, money(amount)))
	reply(playerId, 'session', sessionView(session))
end

-- Checagens comuns de uma parada: jogador perto (ou perto do veículo, no modo collect), veículo perto e tempo de
-- viagem plausível desde o último ponto. Devolve a parada ou nil + código.
local function checkStop(playerId, session, job, nearVehicle)
	local route = job.route
	local stop = route.stops[session.route.stops[session.route.index]]
	local coords = coordsOf(playerId)
	if not stop or not coords then
		return nil, 'too_far'
	end
	local vehicle = job.vehicle and vehicleCoords(session) or nil
	if nearVehicle then
		if not vehicle or not JobRules.Near(coords, vehicle, config.VehicleReach, config.PointHeight) then
			return nil, 'vehicle_far'
		end
	elseif not JobRules.Near(coords, stop, route.stopRadius or config.PointRadius, config.PointHeight) then
		return nil, 'too_far'
	end
	if job.vehicle and route.vehicleRange > 0 and (not vehicle or not JobRules.Near(vehicle, stop, route.vehicleRange, 30.0)) then
		return nil, 'vehicle_far'
	end
	if not nearVehicle then
		local elapsed = (GetGameTimer() - session.lastTaskAt) / 1000
		if elapsed < JobRules.MinTravelSeconds(session.lastPoint, stop, config.MaxTravelSpeed) then
			log('warn', 'gameplay', 'jobs_too_fast', { player_id = playerId, target = job.id })
			return nil, 'too_fast'
		end
	end
	return stop
end

-- Modo zona -----------------------------------------------------------------------------------------------

-- Lixeiras do mapa já recolhidas (por posição, de qualquer jogador): chave -> os.time() em que enchem de novo.
local usedBins, usedCount = {}, 0

local function binReady(key, now)
	local untilAt = usedBins[key]
	if untilAt and untilAt > now then
		return false
	end
	if usedCount > 2000 then
		for other, at in pairs(usedBins) do
			if at <= now then
				usedBins[other] = nil
				usedCount = usedCount - 1
			end
		end
	end
	return true
end

local function validSpot(spot)
	if type(spot) ~= 'table' then
		return nil
	end
	local x, y, z = tonumber(spot.x), tonumber(spot.y), tonumber(spot.z)
	if not x or not y or not z or x ~= x or y ~= y or z ~= z or math.abs(x) > 10000 or math.abs(y) > 10000 or math.abs(z) > 3000 then
		return nil
	end
	return { x = x, y = y, z = z }
end

-- Recolhe numa lixeira do mapa dentro da zona atual (o client manda a posição da lixeira mirada).
local function zonePickup(playerId, session, job, rawSpot)
	local route = job.route
	local zone = route.zones[session.route.stops[session.route.index]]
	local spot = validSpot(rawSpot)
	local coords = coordsOf(playerId)
	if not zone or not spot or not coords then
		return failure(playerId, 'too_far')
	end
	if not JobRules.Near(coords, zone, zone.radius, 60.0) then
		return failure(playerId, 'outside_zone')
	end
	if not JobRules.Near(coords, spot, 3.5, 4.0) then
		return failure(playerId, 'too_far')
	end
	if (session.route.collected or 0) == 0 then
		local elapsed = (GetGameTimer() - session.lastTaskAt) / 1000
		if elapsed < JobRules.MinTravelSeconds(session.lastPoint, coords, config.MaxTravelSpeed) then
			log('warn', 'gameplay', 'jobs_too_fast', { player_id = playerId, target = job.id })
			return failure(playerId, 'too_fast')
		end
	end
	local now = os.time()
	local key = JobRules.BinKey(spot)
	if not binReady(key, now) then
		return failure(playerId, 'bin_empty')
	end
	if not usedBins[key] then
		usedCount = usedCount + 1
	end
	usedBins[key] = now + route.binCooldown
	session.route.picked = true
	session.lastPoint = coords
	session.lastTaskAt = GetGameTimer()
	reply(playerId, 'session', sessionView(session))
end

-- Guarda o saco no veículo (perto do jogador e dentro da zona); completa a zona com `perZone` sacos.
local function zoneDeliver(playerId, session, job)
	local route = job.route
	local zone = route.zones[session.route.stops[session.route.index]]
	local coords = coordsOf(playerId)
	local vehicle = vehicleCoords(session)
	if not zone or not coords then
		return failure(playerId, 'too_far')
	end
	if not vehicle or not JobRules.Near(coords, vehicle, config.VehicleReach, config.PointHeight) then
		return failure(playerId, 'vehicle_far')
	end
	if not JobRules.Near(vehicle, zone, zone.radius + 40.0, 60.0) then
		return failure(playerId, 'outside_zone')
	end
	local amount = pay(session, route.pay)
	if not amount then
		return failure(playerId, 'payment_failed')
	end
	session.route.picked = false
	session.route.collected = (session.route.collected or 0) + 1
	session.lastTaskAt = GetGameTimer()
	grant(playerId, session, route.xp, amount)
	local message = ('Lixo no caminhão: %s (%d/%d em %s).'):format(money(amount), session.route.collected, route.perZone, zone.label)
	if session.route.collected >= route.perZone then
		session.lastPoint = zone
		if session.route.index >= #session.route.stops then
			local bonus = route.bonus > 0 and pay(session, route.bonus) or 0
			message = ('Lixo no caminhão: %s. Rota concluída'):format(money(amount))
			if bonus and bonus > 0 then
				addEarned(session, bonus)
				message = message .. (': bônus de %s'):format(money(bonus))
			end
			reputationEvent(session.character, session.record, 'complete')
			session.route = newRoute(job)
			message = message .. '. Nova área no GPS.'
		else
			session.route.index = session.route.index + 1
			session.route.collected = 0
			message = ('Lixo no caminhão: %s. %s concluída, siga para a próxima área.'):format(money(amount), zone.label)
		end
	end
	notify(playerId, 'success', message)
	reply(playerId, 'session', sessionView(session))
end

-- Primeira metade da parada: recolher na parada (collect) ou embarcar o passageiro (passenger).
local function pickup(playerId, jobId, spot)
	local session, job = sessionFor(playerId, jobId, 'route')
	if not session or not session.route then
		return failure(playerId, 'not_working')
	end
	local mode = job.route.mode
	if mode == 'deliver' or session.route.picked or (mode == 'passenger' and session.route.index % 2 == 0) then
		return failure(playerId, 'wrong_step')
	end
	if mode == 'zone' then
		return zonePickup(playerId, session, job, spot)
	end
	local stop, errorCode = checkStop(playerId, session, job, false)
	if not stop then
		return failure(playerId, errorCode)
	end
	session.lastTaskAt = GetGameTimer()
	if mode == 'collect' then
		session.route.picked = true
		session.lastPoint = stop
	else
		-- Passageiro a bordo: a próxima parada é o destino e a corrida paga pela distância do embarque.
		session.route.boarding = stop
		session.lastPoint = stop
		session.route.index = session.route.index + 1
		notify(playerId, 'info', _t('passenger_boarded'))
	end
	reply(playerId, 'session', sessionView(session))
end

local function deliver(playerId, jobId)
	local session, job = sessionFor(playerId, jobId, 'route')
	if not session or not session.route then
		return failure(playerId, 'not_working')
	end
	local route = job.route
	local mode = route.mode
	if mode == 'zone' then
		if not session.route.picked then
			return failure(playerId, 'wrong_step')
		end
		return zoneDeliver(playerId, session, job)
	end
	if (mode == 'collect' and not session.route.picked) or (mode == 'passenger' and session.route.index % 2 == 1) then
		return failure(playerId, 'wrong_step')
	end
	local stop, errorCode = checkStop(playerId, session, job, mode == 'collect')
	if not stop then
		return failure(playerId, errorCode)
	end
	local from = mode == 'passenger' and session.route.boarding or session.previousStop or job.center
	local amount = pay(session, JobRules.StopPay(route, from, stop))
	if not amount then
		return failure(playerId, 'payment_failed')
	end
	session.lastTaskAt = GetGameTimer()
	session.lastPoint = stop
	session.previousStop = stop
	session.route.picked = false
	session.route.boarding = nil
	grant(playerId, session, route.xp, amount)
	local done = mode == 'passenger' and 'Corrida paga' or mode == 'collect' and 'Coleta feita' or 'Entrega feita'
	local message = ('%s: %s.'):format(done, money(amount))
	if session.route.index >= #session.route.stops then
		local bonus = route.bonus > 0 and pay(session, route.bonus) or 0
		if bonus and bonus > 0 then
			addEarned(session, bonus)
			message = message .. (' Rota concluída: bônus de %s.'):format(money(bonus))
		end
		reputationEvent(session.character, session.record, 'complete')
		session.route = newRoute(job)
		message = message .. ' Nova rota no GPS.'
	else
		session.route.index = session.route.index + 1
	end
	notify(playerId, 'success', message)
	reply(playerId, 'session', sessionView(session))
end

-- Últimos trabalhos do personagem (opcionalmente só de um emprego), com o nome do emprego.
local function sessionsView(record, jobId)
	local list = {}
	for _, entry in ipairs(record.sessions or {}) do
		if not jobId or entry.jobId == jobId then
			local job = jobs[entry.jobId]
			list[#list + 1] = {
				jobId = entry.jobId, label = job and job.label or entry.jobId, unit = job and job.gather and job.gather.units or nil,
				startedAt = entry.startedAt, endedAt = entry.endedAt, tasks = entry.tasks, xp = entry.xp, earned = entry.earned,
				discarded = entry.discarded, reason = entry.reason
			}
		end
	end
	return list
end

-- Visão completa da carreira (app Carreira no tablet e NPC).
local function careerView(character, transient)
	local record = recordOf(character, transient)
	if not record then
		return nil
	end
	local profile = profileOf(record)
	local list = {}
	local worked = 0
	for _, job in pairs(jobs) do
		local progress = record.progress[job.id] or { xp = 0, tasks = 0, earned = 0, seconds = 0 }
		worked = worked + (progress.seconds or 0)
		local mods = JobCareer.Modifiers(career, job, profile, progress.xp)
		local allowed, reason = JobCareer.Allowed(career, job, profile)
		local skills = {}
		for _, id in ipairs(job.skills) do
			skills[#skills + 1] = career.skills[id] and career.skills[id].label or id
		end
		list[#list + 1] = {
			id = job.id, label = job.label, description = job.description, kind = job.kind, center = job.center,
			xp = progress.xp, tasks = progress.tasks, earned = progress.earned, level = mods.jobLevel, maxLevel = #job.levels,
			nextXp = JobRules.NextLevelXp(job.levels, progress.xp), payBonus = mods.payBonus, xpMultiplier = mods.xpMultiplier,
			deposit = mods.deposit, capacity = mods.capacity, seconds = mods.seconds, skills = skills,
			allowed = allowed, lockedReason = reason, kindLabel = JobGuide.KindLabel(job),
			workedSeconds = progress.seconds or 0, firstAt = progress.firstAt, lastAt = progress.lastAt
		}
	end
	table.sort(list, function(a, b) return a.label < b.label end)
	local skills = {}
	for id, skill in pairs(profile.skills) do
		local perks = {}
		for perk, value in pairs(career.skills[id].perks or {}) do
			perks[#perks + 1] = { perk = perk, value = value * (skill.level - 1), perLevel = value }
		end
		skills[#skills + 1] = { id = id, label = skill.label, xp = skill.xp, level = skill.level, maxLevel = skill.maxLevel, nextXp = skill.nextXp, perks = perks }
	end
	table.sort(skills, function(a, b) return a.label < b.label end)
	return {
		level = profile.level, maxLevel = profile.maxLevel, xp = profile.xp, nextXp = profile.nextXp,
		tasks = profile.tasks, earned = profile.earned,
		payBonus = (profile.level - 1) * career.payPerLevel, xpBonus = (profile.level - 1) * career.xpPerLevel,
		reputation = profile.reputation, tier = profile.tier.label, tierPay = profile.tier.pay or 0,
		depositWaived = profile.tier.depositWaived == true, completed = record.completed, abandoned = record.abandoned,
		skills = skills, jobs = list, sessions = sessionsView(record), workedSeconds = worked
	}
end

-- Guia "Como funciona" de um emprego com o histórico do jogador nele (NPC e app Carreira).
local function guideView(character, jobId)
	local job = jobs[jobId]
	local record = job and recordOf(character)
	if not record then
		return nil
	end
	local guide = JobGuide.Build(career, job)
	local profile = profileOf(record)
	local progress = record.progress[job.id] or { xp = 0, tasks = 0, earned = 0, seconds = 0 }
	local mods = JobCareer.Modifiers(career, job, profile, progress.xp)
	local allowed, reason = JobCareer.Allowed(career, job, profile)
	guide.player = {
		level = mods.jobLevel, maxLevel = #job.levels, xp = progress.xp, nextXp = JobRules.NextLevelXp(job.levels, progress.xp),
		tasks = progress.tasks, earned = progress.earned, payBonus = mods.payBonus, xpMultiplier = mods.xpMultiplier,
		capacity = mods.capacity, seconds = mods.seconds, deposit = mods.deposit, allowed = allowed, lockedReason = reason,
		careerLevel = profile.level, tier = profile.tier.label, sessions = sessionsView(record, job.id)
	}
	return guide
end

-- Eventos de rede (o client só pede; o servidor decide) ---------------------------------------------------

RegisterNetEvent('coe_jobs:catalog', function()
	local playerId = source
	if not throttled(playerId) then
		TriggerClientEvent('coe_jobs:catalog', playerId, publicCatalog())
	end
end)

RegisterNetEvent('coe_jobs:start', function(jobId)
	local playerId = source
	if not ready or type(jobId) ~= 'string' or throttled(playerId) then
		return
	end
	local session, errorCode, detail = startSession(playerId, jobId)
	if not session then
		return failure(playerId, errorCode, detail)
	end
	local job = jobs[jobId]
	log('info', 'gameplay', 'jobs_started', { character_id = session.character, target = jobId })
	local hint = job.kind == 'gather'
		and ('Vá até os pontos marcados (%s) e venda no comprador do mapa: só a venda paga.'):format(job.gather.actionLabel:lower())
		or (job.route.mode == 'zone' and 'Leve o caminhão até a área marcada no GPS e recolha o lixo das lixeiras de lá.')
		or 'Siga o GPS até a primeira parada.'
	local mods = modifiersOf(job, session.record)
	local extra = mods.payBonus > 0 and (' Seu histórico rende +%d%% de pagamento.'):format(percent(mods.payBonus)) or ''
	notify(playerId, 'success', ('%s: trabalho iniciado. %s%s Dúvidas? "Como funciona" no responsável.'):format(job.label, hint, extra))
	reply(playerId, 'session', sessionView(session))
end)

-- discard = true confirma encerrar com carga (a carga da coleta não vira item e se perde).
RegisterNetEvent('coe_jobs:stop', function(discard)
	local playerId = source
	if throttled(playerId) or not sessions[playerId] then
		return
	end
	local session = sessions[playerId]
	local job = jobs[session.jobId]
	local coords = coordsOf(playerId)
	if job and (not coords or not JobRules.Near(coords, job.center, config.CenterRadius * 2, config.PointHeight)) then
		return failure(playerId, 'too_far')
	end
	if job and job.gather and session.cargo > 0 and discard ~= true then
		notify(playerId, 'warning', ('Você ainda carrega %d %s. Venda no comprador marcado no mapa (%s) ou escolha "Descartar a carga e encerrar".'):format(
			session.cargo, session.cargo == 1 and job.gather.unit or job.gather.units, job.gather.sell.label))
		return reply(playerId, 'result', { ok = false, error = 'cargo_left' })
	end
	local label = job and job.label or session.jobId
	local refund, summary = endSession(playerId, 'stop')
	local text = ('%s encerrado: %d %s, +%d XP, %s ganhos.'):format(label, summary.tasks, summary.tasks == 1 and 'tarefa' or 'tarefas',
		summary.xp, money(summary.earned))
	if summary.discarded > 0 and job and job.gather then
		text = text .. (' %d %s descartados.'):format(summary.discarded, summary.discarded == 1 and job.gather.unit or job.gather.units)
	end
	if refund and refund > 0 then
		text = text .. (' Depósito de %s devolvido.'):format(money(refund))
	end
	notify(playerId, 'info', text .. ' Detalhes no app Carreira.')
end)

RegisterNetEvent('coe_jobs:gather', function(jobId, nodeIndex)
	local playerId = source
	if ready and type(jobId) == 'string' and not throttled(playerId) then
		gather(playerId, jobId, nodeIndex)
	end
end)

RegisterNetEvent('coe_jobs:sell', function(jobId, pointIndex)
	local playerId = source
	if ready and type(jobId) == 'string' and not throttled(playerId) then
		sell(playerId, jobId, pointIndex)
	end
end)

RegisterNetEvent('coe_jobs:deliver', function(jobId)
	local playerId = source
	if ready and type(jobId) == 'string' and not throttled(playerId) then
		deliver(playerId, jobId)
	end
end)

RegisterNetEvent('coe_jobs:pickup', function(jobId, spot)
	local playerId = source
	if ready and type(jobId) == 'string' and not throttled(playerId) then
		pickup(playerId, jobId, spot)
	end
end)

RegisterNetEvent('coe_jobs:guide', function(jobId)
	local playerId = source
	local character = characterOf(playerId)
	if not ready or type(jobId) ~= 'string' or not jobs[jobId] or not character or throttled(playerId) then
		return
	end
	local guide = guideView(character, jobId)
	if not guide then
		return failure(playerId, 'database_error')
	end
	guide.player.working = sessions[playerId] and sessions[playerId].jobId == jobId or false
	reply(playerId, 'guide', guide)
end)

AddEventHandler('playerDropped', function()
	local playerId = source
	local session = sessions[playerId]
	endSession(playerId, 'dropped')
	lastAction[playerId] = nil
	-- O histórico sai da memória quando o personagem não tem mais ninguém online usando.
	if session then
		local inUse = false
		for _, other in pairs(sessions) do
			if other.character == session.character then
				inUse = true
			end
		end
		if not inUse then
			records[session.character] = nil
		end
	end
end)

-- Personagem trocado (seleção): o trabalho acaba e conta como abandono se o veículo da empresa ficou para trás.
CreateThread(function()
	while true do
		Wait(15000)
		for playerId, session in pairs(sessions) do
			if characterOf(playerId) ~= session.character then
				endSession(playerId, 'character')
			end
		end
	end
end)

-- App Carreira no tablet (ex.: coe_tablet, com a ACE coe.jobs.tablet) ----------------------------------------------

exports('TabletVisible', function()
	return ready
end)

exports('TabletCall', function(playerId, appId, action, payload)
	if not CoeAccess.Allowed(GetInvokingResource(), 'coe.jobs.tablet') or appId ~= 'career' then
		return { ok = false, error = 'forbidden' }
	end
	if not ready then
		return { ok = false, error = 'not_ready' }
	end
	local character = characterOf(playerId)
	if not character then
		return { ok = false, error = 'forbidden' }
	end
	if action == 'profile' then
		local view = careerView(character)
		if not view then
			return { ok = false, error = 'database_error' }
		end
		local session = sessions[playerId]
		view.working = session and session.jobId or nil
		return { ok = true, data = view }
	end
	if action == 'guide' then
		local jobId = type(payload) == 'table' and payload.jobId
		if type(jobId) ~= 'string' or not jobs[jobId] then
			return { ok = false, error = 'invalid_payload' }
		end
		local guide = guideView(character, jobId)
		if not guide then
			return { ok = false, error = 'database_error' }
		end
		return { ok = true, data = guide }
	end
	return { ok = false, error = 'invalid_action' }
end)

-- Registro dos empregos (jobs/*.lua e RegisterJob) ----------------------------------------------------------

local function register(definition, owner)
	owner = owner or GetInvokingResource() or GetCurrentResourceName()
	local job, errorCode = JobRules.Validate(definition, knownSkills)
	if not job then
		log('warn', 'system', 'jobs_register_failed', { source = owner, error_code = errorCode })
		return errorCode
	end
	if owners[job.id] and owners[job.id] ~= owner then
		return 'id_taken'
	end
	if #(config.LedgerPrefix .. job.id) > 32 then
		return 'invalid_id'
	end
	jobs[job.id] = job
	owners[job.id] = owner
	log('info', 'system', 'jobs_registered', { source = owner, target = job.id })
	return true
end

local function unregister(jobId, owner)
	if not jobs[jobId] or (owner and owners[jobId] ~= owner) then
		return false
	end
	for playerId, session in pairs(sessions) do
		if session.jobId == jobId then
			endSession(playerId, 'unavailable')
		end
	end
	jobs[jobId] = nil
	owners[jobId] = nil
	broadcastCatalog()
	return true
end

exports('RegisterJob', function(definition)
	local result = register(definition)
	if result == true then
		broadcastCatalog()
	end
	return result
end)
exports('UnregisterJob', function(jobId)
	return unregister(jobId, GetInvokingResource())
end)
exports('ListJobs', publicCatalog)
exports('IsReady', function() return ready end)
exports('GetSession', function(playerId)
	local session = sessions[tonumber(playerId)]
	return session and sessionView(session) or nil
end)
exports('GetProgress', function(characterId, jobId)
	local job = jobs[jobId]
	local record = job and characterId and recordOf(tostring(characterId))
	if not record then
		return nil
	end
	local progress = progressOf(record, jobId)
	return {
		xp = progress.xp, tasks = progress.tasks, earned = progress.earned, level = JobRules.Level(job.levels, progress.xp),
		maxLevel = #job.levels, nextXp = JobRules.NextLevelXp(job.levels, progress.xp)
	}
end)
-- Carreira de qualquer personagem (online ou não): quem não está online não fica em memória.
exports('GetCareer', function(characterId)
	return characterId and careerView(tostring(characterId), true) or nil
end)

-- Resource externo parado: os empregos dele saem e as sessões acabam.
AddEventHandler('onResourceStop', function(resource)
	if resource == GetCurrentResourceName() then
		for playerId in pairs(sessions) do
			endSession(playerId, 'unavailable')
		end
		return
	end
	for jobId, owner in pairs(owners) do
		if owner == resource then
			unregister(jobId)
		end
	end
end)

CreateThread(function()
	local waitingLogged = false
	while true do
		local initialized, errorCode = JobsPersistence.Initialize()
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
	for _, definition in ipairs(JobsCatalog) do
		if config.Enabled[definition.id] then
			local result = register(definition, GetCurrentResourceName())
			if result ~= true then
				log('error', 'system', 'jobs_definition_invalid', { target = tostring(definition.id), error_code = tostring(result) })
			end
		end
	end
	ready = true
	broadcastCatalog()
	log('info', 'system', 'jobs_ready', {})
	-- Outros resources que somam empregos (RegisterJob) se registram ao ouvir isto.
	TriggerEvent('coe_jobs:ready')
end)
