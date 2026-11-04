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

local _t = (Core and Core.Locale and Core.Locale.Bind) and Core.Locale.Bind(Locales) or function(k) return (Locales and Locales['pt-BR'] and Locales['pt-BR'][k]) or k end

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
	if job.gather then
		-- Carga por produto e, no transporte, o que está no chão, na mão e no veículo.
		view.goods = {}
		for id, amount in pairs(session.goods or {}) do
			if amount > 0 then
				view.goods[id] = amount
			end
		end
		view.speed = mods.seconds / job.gather.seconds
		if job.gather.haul then
			local haul = session.haul
			view.haul = { ground = haul.ground, spot = haul.spot, carrying = haul.carrying, loaded = haul.loaded, capacity = mods.capacity }
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
		local entity = Core.Platform.Entities.FromNetworkId(session.vehicleNet)
		if entity and entity ~= 0 and Core.Platform.Entities.Exists(entity) then
			Core.Platform.Entities.Delete(entity)
		end
	end
	session.vehicleNet = nil
end

local function vehicleCoords(session)
	if not session.vehicleNet then
		return nil
	end
	local entity = Core.Platform.Entities.FromNetworkId(session.vehicleNet)
	if not entity or entity == 0 or not Core.Platform.Entities.Exists(entity) then
		return nil
	end
	local c = Core.Platform.Entities.GetCoords(entity)
	return { x = c.x, y = c.y, z = c.z }
end

-- Toras (ou outra carga) visíveis na caçamba: todos os clients perto desenham pela state bag.
local function setVehicleLoad(session, count)
	if not session.vehicleNet then
		return
	end
	local entity = Core.Platform.Entities.FromNetworkId(session.vehicleNet)
	if entity and entity ~= 0 and Core.Platform.Entities.Exists(entity) then
		Entity(entity).state:set('coe:jobLoad', count, true)
	end
end

local function spawnVehicle(playerId, job)
	local spec = job.vehicle
	local entity = CreateVehicleServerSetter(joaat(spec.model), 'automobile', spec.spawn.x, spec.spawn.y, spec.spawn.z, spec.spawn.h)
	local deadline = GetGameTimer() + 3000
	while (not entity or entity == 0 or not Core.Platform.Entities.Exists(entity)) and GetGameTimer() < deadline do
		Wait(50)
	end
	if not entity or entity == 0 or not Core.Platform.Entities.Exists(entity) then
		return nil
	end
	Core.Platform.Vehicles.SetPlate(entity, ('%s%04d'):format(spec.plate, math.random(0, 9999)))
	Entity(entity).state:set('coe:jobVehicle', job.id .. ':' .. playerId, true)
	return Core.Platform.Entities.GetNetworkId(entity)
end

-- Sessões ---------------------------------------------------------------------------------------------

-- Carga total da sessão (a que se perde ao encerrar sem vender): produtos + chão + mão + veículo.
local function refreshCargo(session)
	local total = 0
	for _, amount in pairs(session.goods or {}) do
		total = total + amount
	end
	local haul = session.haul
	if haul then
		total = total + haul.ground + haul.loaded + (haul.carrying and 1 or 0)
	end
	session.cargo = total
	return total
end

local function goodsTotal(session)
	local total = 0
	for _, amount in pairs(session.goods or {}) do
		total = total + amount
	end
	return total
end

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

-- anywhere: abre sem estar no NPC (pesca livre: usar a vara numa área de pesca já começa o trabalho).
local function startSession(playerId, jobId, anywhere)
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
	if not coords or (not anywhere and not JobRules.Near(coords, job.center, config.CenterRadius, config.PointHeight)) then
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
		openedAt = os.time(), stats = { tasks = 0, xp = 0, earned = 0 }, goods = {}
	}
	if job.gather and job.gather.haul then
		session.haul = { ground = 0, spot = nil, carrying = false, loaded = 0 }
	end
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
	bin_empty = 'err_bin_empty', locked = 'err_locked',
	ground_left = 'err_ground_left', vehicle_full = 'err_vehicle_full',
	no_inventory = 'err_no_inventory', no_money = 'err_no_money', inventory_full = 'err_inventory_full',
	shop_locked = 'err_shop_locked', no_rod = 'err_no_rod', no_bait = 'err_no_bait', gear_locked = 'err_gear_locked',
	no_fishing_area = 'err_no_fishing_area', casting = 'err_casting'
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

local function unitName(item, amount)
	return amount == 1 and item.unit or item.units
end

-- Tempo da ação de um produto já com o bônus de Campo (mesma proporção do tempo base da coleta).
local function actionSeconds(job, mods, item)
	return math.max(1, (item.seconds or job.gather.seconds) * mods.seconds / job.gather.seconds)
end

-- Soma o que foi colhido: na coleta comum vai para a carga do jogador; no transporte cai no chão ao lado.
local function harvest(playerId, session, job, item, mods, spot)
	local haul = session.haul
	local room = mods.capacity - (haul and (haul.loaded + haul.ground + (haul.carrying and 1 or 0)) or goodsTotal(session))
	local amount = math.min(math.random(item.yield[1], item.yield[2]), room)
	if haul then
		haul.ground = amount
		haul.spot = { x = spot.x, y = spot.y, z = spot.z }
	else
		session.goods[item.id] = (session.goods[item.id] or 0) + amount
	end
	refreshCargo(session)
	session.lastTaskAt = GetGameTimer()
	grant(playerId, session, item.xp, 0)
	if haul then
		notify(playerId, 'info', ('%d %s no chão: leve uma por vez até o veículo (%d/%d na caçamba).'):format(
			amount, unitName(item, amount), haul.loaded, mods.capacity))
	else
		notify(playerId, 'info', ('+%d %s (%d/%d).'):format(amount, unitName(item, amount), goodsTotal(session), mods.capacity))
	end
	reply(playerId, 'session', sessionView(session))
end

-- Pode colher agora? Confere tempo da ação, espaço e (no transporte) se o chão e a mão estão livres.
local function canHarvest(session, job, mods, item)
	if GetGameTimer() - session.lastTaskAt < actionSeconds(job, mods, item) * 1000 * config.GatherTimeSlack then
		return 'too_fast'
	end
	local haul = session.haul
	if haul then
		if haul.ground > 0 or haul.carrying then
			return 'ground_left'
		end
		if haul.loaded >= mods.capacity then
			return 'vehicle_full'
		end
	elseif goodsTotal(session) >= mods.capacity then
		return 'full'
	end
	return nil
end

local function gather(playerId, jobId, nodeIndex)
	local session, job = sessionFor(playerId, jobId, 'gather')
	if not session then
		return failure(playerId, 'not_working')
	end
	nodeIndex = math.tointeger(nodeIndex) or -1
	local node = job.gather.nodes[nodeIndex]
	local coords = coordsOf(playerId)
	if not node or not coords or not JobRules.Near(coords, node, config.PointRadius, config.PointHeight) then
		return failure(playerId, 'too_far')
	end
	local now = os.time()
	if (session.nodeCooldowns[nodeIndex] or 0) > now then
		return failure(playerId, 'cooldown')
	end
	local item = job.gather.products[node.product]
	local mods = modifiersOf(job, session.record)
	local blocked = canHarvest(session, job, mods, item)
	if blocked then
		return failure(playerId, blocked)
	end
	session.nodeCooldowns[nodeIndex] = now + item.cooldown
	harvest(playerId, session, job, item, mods, node)
end

-- Objetos do mapa já usados (árvores cortadas, por posição): chave -> { until, x, y, z, model }.
local worldUsed, worldCount = {}, 0

local function felledList()
	local list, now = {}, os.time()
	for _, entry in pairs(worldUsed) do
		if entry.fell and entry.untilAt > now then
			list[#list + 1] = { x = entry.x, y = entry.y, z = entry.z, model = entry.model, seconds = entry.untilAt - now }
		end
	end
	return list
end

-- Colheita num objeto do mapa (árvore) dentro da área: o client manda a posição e o modelo mirados.
local function gatherWorld(playerId, jobId, worldIndex, rawSpot, modelHash)
	local session, job = sessionFor(playerId, jobId, 'gather')
	if not session then
		return failure(playerId, 'not_working')
	end
	local origin = job.gather.world[math.tointeger(worldIndex) or -1]
	local spot = JobRules.ValidSpot(rawSpot)
	local coords = coordsOf(playerId)
	if not origin or not spot or not coords then
		return failure(playerId, 'too_far')
	end
	local known = false
	for _, name in ipairs(origin.models) do
		known = known or GetHashKey(name) == modelHash
	end
	if not known then
		return failure(playerId, 'too_far')
	end
	if not JobRules.Near(coords, origin.area, origin.area.radius, 120.0) or not JobRules.Near(spot, origin.area, origin.area.radius, 120.0) then
		return failure(playerId, 'outside_zone')
	end
	if not JobRules.Near(coords, spot, 4.0, 6.0) then
		return failure(playerId, 'too_far')
	end
	local now = os.time()
	local key = JobRules.BinKey(spot)
	local used = worldUsed[key]
	if used and used.untilAt > now then
		return failure(playerId, 'cooldown')
	end
	local item = job.gather.products[origin.product]
	local mods = modifiersOf(job, session.record)
	local blocked = canHarvest(session, job, mods, item)
	if blocked then
		return failure(playerId, blocked)
	end
	if worldCount > 2000 then
		for other, entry in pairs(worldUsed) do
			if entry.untilAt <= now then
				worldUsed[other] = nil
				worldCount = worldCount - 1
			end
		end
	end
	if not used then
		worldCount = worldCount + 1
	end
	worldUsed[key] = { untilAt = now + origin.cooldown, x = spot.x, y = spot.y, z = spot.z, model = modelHash, fell = origin.fell }
	if origin.fell then
		-- Todos os clients escondem a árvore (e quem estiver perto a vê tombar) até o cooldown passar.
		TriggerClientEvent('coe_jobs:felled', -1, { x = spot.x, y = spot.y, z = spot.z, model = modelHash, seconds = origin.cooldown, by = playerId })
	end
	harvest(playerId, session, job, item, mods, spot)
end

-- Transporte: pega uma unidade do chão (perto de onde caiu).
local function take(playerId, jobId)
	local session, job = sessionFor(playerId, jobId, 'gather')
	if not session or not session.haul then
		return failure(playerId, 'not_working')
	end
	local haul = session.haul
	local coords = coordsOf(playerId)
	if haul.ground <= 0 or haul.carrying then
		return failure(playerId, 'wrong_step')
	end
	if not coords or not haul.spot or not JobRules.Near(coords, haul.spot, 10.0, config.PointHeight) then
		return failure(playerId, 'too_far')
	end
	haul.ground = haul.ground - 1
	haul.carrying = true
	refreshCargo(session)
	reply(playerId, 'session', sessionView(session))
end

-- Transporte: guarda a unidade da mão no veículo do emprego.
local function loadHaul(playerId, jobId)
	local session, job = sessionFor(playerId, jobId, 'gather')
	if not session or not session.haul then
		return failure(playerId, 'not_working')
	end
	local haul = session.haul
	if not haul.carrying then
		return failure(playerId, 'wrong_step')
	end
	local coords, vehicle = coordsOf(playerId), vehicleCoords(session)
	if not coords or not vehicle or not JobRules.Near(coords, vehicle, config.VehicleReach, config.PointHeight) then
		return failure(playerId, 'vehicle_far')
	end
	local mods = modifiersOf(job, session.record)
	if haul.loaded >= mods.capacity then
		return failure(playerId, 'vehicle_full')
	end
	haul.carrying = false
	haul.loaded = haul.loaded + 1
	refreshCargo(session)
	setVehicleLoad(session, haul.loaded)
	if haul.ground == 0 then
		if haul.loaded >= mods.capacity then
			notify(playerId, 'success', ('Caçamba cheia (%d/%d). Leve até "%s" no mapa.'):format(haul.loaded, mods.capacity, job.gather.process and job.gather.process.label or job.gather.sell.label))
		else
			notify(playerId, 'info', ('Caçamba: %d/%d. Corte outra árvore ou leve para a madeireira.'):format(haul.loaded, mods.capacity))
		end
	end
	reply(playerId, 'session', sessionView(session))
end

-- Duração do beneficiamento de `count` unidades (o client anima; o servidor exige a fração do tempo).
local function processSeconds(process, count)
	return math.min(process.maxSeconds, process.seconds * count)
end

-- Beneficiamento: a carga do veículo (perto do ponto) vira o produto de saída.
local function processLoad(playerId, jobId, pointIndex)
	local session, job = sessionFor(playerId, jobId, 'gather')
	local process = job and job.gather.process
	if not session or not session.haul or not process then
		return failure(playerId, 'not_working')
	end
	local spot = process.points[math.tointeger(pointIndex) or -1]
	local coords, vehicle = coordsOf(playerId), vehicleCoords(session)
	if not spot or not coords or not JobRules.Near(coords, spot, config.PointRadius, config.PointHeight) then
		return failure(playerId, 'too_far')
	end
	if not vehicle or not JobRules.Near(vehicle, spot, process.vehicleRange, 20.0) then
		return failure(playerId, 'vehicle_far')
	end
	local haul = session.haul
	if haul.loaded <= 0 then
		return failure(playerId, 'empty')
	end
	if GetGameTimer() - session.lastTaskAt < processSeconds(process, haul.loaded) * 1000 * config.GatherTimeSlack then
		return failure(playerId, 'too_fast')
	end
	local input = haul.loaded
	local output = input * process.ratio
	local item = job.gather.products[process.product]
	haul.loaded = 0
	session.goods[item.id] = (session.goods[item.id] or 0) + output
	session.lastTaskAt = GetGameTimer()
	refreshCargo(session)
	setVehicleLoad(session, 0)
	grant(playerId, session, item.xp, 0)
	notify(playerId, 'success', ('%s: %d %s viraram %d %s. Venda no comprador.'):format(process.label, input,
		unitName(job.gather.products[job.gather.haul.product], input), output, unitName(item, output)))
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
	-- Só o que tem preço sai na venda (no lenhador, as toras precisam virar tábuas antes).
	local base, parts, sold = 0, {}, {}
	for _, id in ipairs(job.gather.productOrder) do
		local item = job.gather.products[id]
		local amount = session.goods[id] or 0
		if amount > 0 and item.price > 0 then
			base = base + amount * item.price
			sold[id] = amount
			parts[#parts + 1] = ('%d %s'):format(amount, unitName(item, amount))
		end
	end
	if base <= 0 then
		return failure(playerId, 'empty')
	end
	local amount = pay(session, base)
	if not amount then
		return failure(playerId, 'payment_failed')
	end
	for id in pairs(sold) do
		session.goods[id] = nil
	end
	refreshCargo(session)
	addEarned(session, amount)
	reputationEvent(session.character, session.record, 'complete')
	notify(playerId, 'success', ('Vendeu %s por %s.'):format(table.concat(parts, ', '), money(amount)))
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

local validSpot = JobRules.ValidSpot

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

-- Inventário (opcional: sem o coe_inventory a loja e a pesca com vara respondem `no_inventory`) -------------------


JobsServer = {
	config = config,
	jobs = jobs,
	sessions = sessions,
	records = records,
	characterOf = characterOf,
	coordsOf = coordsOf,
	throttled = throttled,
	failure = failure,
	sessionFor = sessionFor,
	unitName = unitName,
	grant = grant,
	recordOf = recordOf,
	profileOf = profileOf,
	progressOf = progressOf,
	modifiersOf = modifiersOf,
	saveProfile = saveProfile,
	reputationEvent = reputationEvent,
	log = log,
	notify = notify,
	reply = reply,
	money = money,
	startSession = startSession,
	refreshCargo = refreshCargo,
	goodsTotal = goodsTotal,
	sessionView = sessionView,
	isReady = function() return ready end
}

local function _loadSub(relPath)
	local f = io.open(relPath, "r")
	if f then f:close() return dofile(relPath) end
	local f2 = io.open("coe_jobs/" .. relPath, "r")
	if f2 then f2:close() return dofile("coe_jobs/" .. relPath) end
end

if not IsDuplicityVersion or not IsDuplicityVersion() then
	_loadSub("server/fishing_shop.lua")
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
		-- Árvores já cortadas por outros jogadores continuam escondidas para quem acabou de entrar.
		TriggerClientEvent('coe_jobs:felledList', playerId, felledList())
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
	local hint = job.kind == 'gather' and job.gather.haul
		and ('Leve o veículo até a área marcada, %s, carregue a caçamba e leve até "%s".'):format(job.gather.actionLabel:lower(),
			job.gather.process and job.gather.process.label or job.gather.sell.label)
		or job.kind == 'gather'
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
	-- Sem veículo da empresa, também dá para encerrar num comprador ou na loja (a pesca não volta ao NPC).
	local nearOther = false
	if job and not job.vehicle and coords then
		for _, spot in ipairs(job.gather and job.gather.sell.points or {}) do
			nearOther = nearOther or JobRules.Near(coords, spot, config.CenterRadius, config.PointHeight)
		end
		for _, spot in ipairs(job.shop and job.shop.points or {}) do
			nearOther = nearOther or JobRules.Near(coords, spot, config.CenterRadius, config.PointHeight)
		end
	end
	if job and not nearOther and (not coords or not JobRules.Near(coords, job.center, config.CenterRadius * 2, config.PointHeight)) then
		return failure(playerId, 'too_far')
	end
	if job and job.gather and session.cargo > 0 and discard ~= true then
		notify(playerId, 'warning', ('Você ainda tem %d %s na carga. Venda no comprador marcado no mapa (%s) ou escolha "Descartar a carga e encerrar".'):format(
			session.cargo, session.cargo == 1 and 'unidade' or 'unidades', job.gather.sell.label))
		return reply(playerId, 'result', { ok = false, error = 'cargo_left' })
	end
	local label = job and job.label or session.jobId
	local refund, summary = endSession(playerId, 'stop')
	local text = ('%s encerrado: %d %s, +%d XP, %s ganhos.'):format(label, summary.tasks, summary.tasks == 1 and 'tarefa' or 'tarefas',
		summary.xp, money(summary.earned))
	if summary.discarded > 0 and job and job.gather then
		local single = #job.gather.productOrder == 1 and not job.gather.haul and job.gather.products[job.gather.defaultProduct]
		local noun = single and (summary.discarded == 1 and single.unit or single.units) or (summary.discarded == 1 and 'item' or 'itens')
		text = text .. (' %d %s descartados.'):format(summary.discarded, noun)
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

RegisterNetEvent('coe_jobs:gatherWorld', function(jobId, worldIndex, spot, modelHash)
	local playerId = source
	if ready and type(jobId) == 'string' and type(modelHash) == 'number' and not throttled(playerId) then
		gatherWorld(playerId, jobId, worldIndex, spot, modelHash)
	end
end)

RegisterNetEvent('coe_jobs:take', function(jobId)
	local playerId = source
	if ready and type(jobId) == 'string' and not throttled(playerId) then
		take(playerId, jobId)
	end
end)

RegisterNetEvent('coe_jobs:load', function(jobId)
	local playerId = source
	if ready and type(jobId) == 'string' and not throttled(playerId) then
		loadHaul(playerId, jobId)
	end
end)

RegisterNetEvent('coe_jobs:process', function(jobId, pointIndex)
	local playerId = source
	if ready and type(jobId) == 'string' and not throttled(playerId) then
		processLoad(playerId, jobId, pointIndex)
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

-- App Carreira no tablet (coe_workpad, ou um pacote com a ACE coe.jobs.tablet) -------------------------------------

exports('TabletVisible', function()
	return ready
end)

exports('TabletCall', function(playerId, appId, action, payload)
	if not CoeAccess.Allowed(GetInvokingResource(), 'coe.jobs.tablet', config.TabletResources) or appId ~= 'career' then
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
