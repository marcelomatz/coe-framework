-- coe_elos (servidor): rede profissional do COE OS. Perfil, currículo montado do histórico real do personagem
-- (empregos livres do coe_jobs e horas de ponto nos negócios do coe_businesses) e conexões entre personagens.
-- O app roda no smartphone e no tablet pelo export TabletCall (mesmo contrato do coe_mail).
local config = ElosConfig
local _t = (Core and Core.Locale and Core.Locale.Bind) and Core.Locale.Bind(Locales) or function(k, p) local s = (Locales and Locales['pt-BR'] and Locales['pt-BR'][k]) or k; if p then for pk, pv in pairs(p) do s = s:gsub('%%{' .. pk .. '}', tostring(pv)) end end; return s end

local ready = false
local locks = {}
local lastCall = {}
local shifts = {}   -- source -> { character, businessId, startedAt } (ponto aberto)

local HOSTS = { coe_tablet = 'tablet', coe_phone = 'phone' }
local App = {}

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

local function characterOf(playerId)
	local snapshot = Core.Players.GetActiveCharacter(playerId)
	if type(snapshot) ~= 'table' or not snapshot.characterId then
		return nil
	end
	local name = (((snapshot.firstName or '') .. ' ' .. (snapshot.lastName or '')):gsub('^%s+', ''):gsub('%s+$', ''))
	return { id = tostring(snapshot.characterId), name = name ~= '' and name or 'Sem nome', stateId = snapshot.stateId }
end

local function withLock(key, run)
	if locks[key] then
		return { ok = false, error = 'busy' }
	end
	locks[key] = true
	local ok, result = pcall(run)
	locks[key] = nil
	if not ok then
		log('error', 'gameplay', 'elos_action_failed', { error_code = tostring(result) })
		return { ok = false, error = 'database_error' }
	end
	return result
end

-- Jogador online de um personagem (pelo stateId), para avisos.
local function playerOfState(stateId)
	local ok, player = pcall(function()
		return Core.Players.GetPlayerByStateId(stateId)
	end)
	return ok and type(player) == 'table' and player.source or nil
end

-- Horas de ponto nos negócios ------------------------------------------------------------------------------

local function business(businessId)
	local ok, value = pcall(function()
		return exports.coe_businesses:Get(businessId)
	end)
	return ok and type(value) == 'table' and value or nil
end

local function roleIn(businessId, characterId, entry)
	local ok, grade = pcall(function()
		return exports.coe_businesses:GradeOf(businessId, characterId)
	end)
	if ok and type(grade) == 'table' and type(grade.label) == 'string' then
		return grade.label
	end
	if entry and entry.owner and tostring(entry.owner.characterId) == tostring(characterId) then
		return 'Dono'
	end
	return nil
end

local function openShift(source, businessId)
	local character = characterOf(source)
	if character then
		shifts[source] = { character = character.id, businessId = businessId, startedAt = os.time() }
	end
end

-- Fecha o ponto aberto e soma o turno (turnos curtos demais não contam).
local function closeShift(source)
	local shift = shifts[source]
	shifts[source] = nil
	if not shift or not ready then
		return
	end
	local now = os.time()
	local seconds = now - shift.startedAt
	if seconds < config.Resume.MinShiftSeconds then
		return
	end
	local entry = business(shift.businessId)
	local saved = ElosPersistence.AddShift(shift.character, {
		businessId = shift.businessId, label = entry and entry.label or shift.businessId, category = entry and entry.category or '',
		role = roleIn(shift.businessId, shift.character, entry) or '', seconds = seconds, startedAt = shift.startedAt, endedAt = now
	})
	if not saved then
		log('warn', 'persistence', 'elos_shift_save_failed', { character_id = shift.character, target = shift.businessId })
	end
end

AddEventHandler('coe_businesses:dutyChanged', function(source, businessId, onDuty)
	if type(businessId) ~= 'string' then
		return
	end
	closeShift(source)
	if onDuty then
		openShift(source, businessId)
	end
end)

-- Vínculos atuais com negócios: dono ou equipe.
local function memberships(characterId)
	local ok, list = pcall(function()
		return exports.coe_businesses:List()
	end)
	local out = {}
	for _, entry in ipairs(ok and type(list) == 'table' and list or {}) do
		local owner = entry.owner and tostring(entry.owner.characterId) == characterId
		local staff = false
		for _, member in ipairs(entry.staff or {}) do
			if tostring(member.characterId) == characterId then
				staff = true
			end
		end
		if entry.enabled ~= false and (owner or staff) then
			out[#out + 1] = {
				businessId = entry.id, label = entry.label, category = entry.category, owner = owner,
				role = roleIn(entry.id, characterId, entry) or (owner and 'Dono' or nil)
			}
		end
	end
	return out
end

-- Currículo -----------------------------------------------------------------------------------------------

local function career(characterId)
	if GetResourceState('coe_jobs') ~= 'started' then
		return nil
	end
	local ok, value = pcall(function()
		return exports.coe_jobs:GetCareer(characterId)
	end)
	return ok and type(value) == 'table' and value or nil
end

-- Todas as experiências do personagem (com o que está no currículo) e a carreira dos empregos livres.
local function experiences(characterId)
	local items = ElosPersistence.Items(characterId)
	local works = ElosPersistence.Works(characterId)
	if not items or not works then
		return nil
	end
	local jobs = career(characterId)
	return ElosRules.Experiences(config, jobs, works, memberships(characterId), items), jobs
end

-- Carreira resumida (nível, reputação e habilidades) para o perfil.
local function careerCard(jobs)
	if not jobs then
		return nil
	end
	local skills = {}
	for _, skill in ipairs(jobs.skills or {}) do
		if (skill.level or 1) > 1 then
			skills[#skills + 1] = { label = skill.label, level = skill.level, maxLevel = skill.maxLevel }
		end
	end
	return { level = jobs.level, maxLevel = jobs.maxLevel, tier = jobs.tier, completed = jobs.completed, skills = skills }
end

-- Perfil -------------------------------------------------------------------------------------------------

-- Perfil do personagem; cria no primeiro acesso e mantém nome e stateId atualizados.
local function ensureProfile(character)
	local profile = ElosPersistence.Profile(character.id)
	if profile == nil then
		return nil
	end
	if profile and profile.name == character.name and profile.stateId == character.stateId then
		return profile
	end
	if not character.stateId then
		return profile or nil
	end
	local defaults = config.Profile.Defaults
	profile = profile or {
		characterId = character.id, headline = '', about = '', visibility = defaults.visibility,
		showEarnings = defaults.showEarnings, showCareer = defaults.showCareer, createdAt = os.time()
	}
	profile.name, profile.stateId = character.name, character.stateId
	if not ElosPersistence.SaveProfile(profile) then
		return nil
	end
	return profile
end

local function network(characterId)
	local rows = ElosPersistence.Connections(characterId)
	if not rows then
		return nil
	end
	local out = { connections = {}, incoming = {}, outgoing = {} }
	for _, row in ipairs(rows) do
		local card = { stateId = row.stateId, name = row.name, headline = row.headline, since = row.acceptedAt or row.createdAt }
		if row.status == 'accepted' then
			out.connections[#out.connections + 1] = card
		elseif row.requester == characterId then
			out.outgoing[#out.outgoing + 1] = card
		else
			out.incoming[#out.incoming + 1] = card
		end
	end
	return out
end

-- Perfil como o visitante vê (o próprio dono também usa para a prévia "como os outros veem").
local function personView(viewerId, profile)
	local row = viewerId ~= profile.characterId and ElosPersistence.Connection(viewerId, profile.characterId) or false
	if row == nil then
		return nil
	end
	local relation = ElosRules.Relation(viewerId, profile.characterId, row or nil)
	local view = {
		stateId = profile.stateId, name = profile.name, headline = profile.headline, visibility = profile.visibility,
		relation = relation, full = ElosRules.CanSeeAll(profile, relation)
	}
	view.connections = ElosPersistence.Count(profile.characterId) or 0
	if not view.full then
		return view
	end
	local list, jobs = experiences(profile.characterId)
	if not list then
		return nil
	end
	view.about = profile.about
	view.resume = ElosRules.PublicResume(profile, list)
	view.summary = ElosRules.Summary(list, true)
	view.career = profile.showCareer and careerCard(jobs) or nil
	return view
end

-- Ações do app ------------------------------------------------------------------------------------------

function App.state(playerId, character)
	local profile = ensureProfile(character)
	if not profile then
		return { ok = false, error = character.stateId and 'database_error' or 'no_character' }
	end
	local list, jobs = experiences(character.id)
	local net = network(character.id)
	if not list or not net then
		return { ok = false, error = 'database_error' }
	end
	return {
		ok = true,
		me = {
			stateId = profile.stateId, name = profile.name, headline = profile.headline, about = profile.about,
			visibility = profile.visibility, showEarnings = profile.showEarnings, showCareer = profile.showCareer
		},
		resume = list, summary = ElosRules.Summary(list, true), totals = ElosRules.Summary(list, false),
		career = careerCard(jobs), network = net,
		limits = {
			headline = config.Profile.HeadlineMax, about = config.Profile.AboutMax, note = config.Profile.NoteMax,
			items = config.Resume.MaxItems, searchMin = config.Network.SearchMin
		}
	}
end

function App.saveProfile(_, character, payload)
	local patch, errorCode = ElosRules.ProfilePatch(config, payload)
	if not patch then
		return { ok = false, error = errorCode }
	end
	return withLock('profile:' .. character.id, function()
		local profile = ensureProfile(character)
		if not profile then
			return { ok = false, error = 'database_error' }
		end
		for key, value in pairs(patch) do
			profile[key] = value
		end
		if not ElosPersistence.SaveProfile(profile) then
			return { ok = false, error = 'database_error' }
		end
		return { ok = true }
	end)
end

-- Põe ou tira uma experiência do currículo (só experiências reais do personagem).
function App.setItem(_, character, payload)
	local key = ElosRules.ItemKey(payload.kind, payload.ref)
	if not key then
		return { ok = false, error = 'invalid_item' }
	end
	local note = ElosRules.Text(payload.note, config.Profile.NoteMax, false)
	if not note then
		return { ok = false, error = 'invalid_note' }
	end
	return withLock('profile:' .. character.id, function()
		local list = experiences(character.id)
		if not list then
			return { ok = false, error = 'database_error' }
		end
		local found, added = nil, 0
		for _, entry in ipairs(list) do
			if entry.key == key then
				found = entry
			end
			if entry.added then
				added = added + 1
			end
		end
		if not found then
			return { ok = false, error = 'unknown_item' }
		end
		if payload.added == false then
			return ElosPersistence.DeleteItem(character.id, payload.kind, payload.ref) and { ok = true } or { ok = false, error = 'database_error' }
		end
		if not found.added and added >= config.Resume.MaxItems then
			return { ok = false, error = 'item_limit' }
		end
		return ElosPersistence.SaveItem(character.id, payload.kind, payload.ref, note) and { ok = true } or { ok = false, error = 'database_error' }
	end)
end

function App.search(_, character, payload)
	local term = ElosRules.Text(payload.query, 64, false)
	if not term then
		return { ok = false, error = 'invalid_search' }
	end
	local stateId = ElosRules.StateId(term)
	local found = {}
	if stateId then
		local profile = ElosPersistence.ProfileByState(stateId)
		if profile == nil then
			return { ok = false, error = 'database_error' }
		end
		if profile and profile.characterId ~= character.id then
			found[1] = profile
		end
	end
	if #found == 0 then
		if utf8.len(term) < config.Network.SearchMin then
			return { ok = false, error = 'search_short' }
		end
		found = ElosPersistence.Search(term, character.id, config.Network.SearchLimit)
		if not found then
			return { ok = false, error = 'database_error' }
		end
	end
	local results = {}
	for _, profile in ipairs(found) do
		local row = ElosPersistence.Connection(character.id, profile.characterId)
		results[#results + 1] = {
			stateId = profile.stateId, name = profile.name, headline = profile.headline,
			relation = ElosRules.Relation(character.id, profile.characterId, row or nil)
		}
	end
	return { ok = true, results = results }
end

local function profileFor(payload)
	local stateId = ElosRules.StateId(payload.stateId)
	if not stateId then
		return nil, 'invalid_person'
	end
	local profile = ElosPersistence.ProfileByState(stateId)
	if profile == nil then
		return nil, 'database_error'
	end
	if not profile then
		return nil, 'unknown_person'
	end
	return profile
end

function App.person(_, character, payload)
	local profile, errorCode = profileFor(payload)
	if not profile then
		return { ok = false, error = errorCode }
	end
	local view = personView(character.id, profile)
	if not view then
		return { ok = false, error = 'database_error' }
	end
	return { ok = true, person = view }
end

-- Pede conexão (ou aceita, se a outra pessoa já tinha pedido).
function App.request(_, character, payload)
	local profile, errorCode = profileFor(payload)
	if not profile then
		return { ok = false, error = errorCode }
	end
	local pairKey = character.id < profile.characterId and character.id .. ':' .. profile.characterId or profile.characterId .. ':' .. character.id
	return withLock('pair:' .. pairKey, function()
		local me = ensureProfile(character)
		local row = ElosPersistence.Connection(character.id, profile.characterId)
		local net = network(character.id)
		if not me or row == nil or not net then
			return { ok = false, error = 'database_error' }
		end
		local relation = ElosRules.Relation(character.id, profile.characterId, row or nil)
		local allowed, refusal = ElosRules.CanRequest(config, relation, #net.connections, #net.outgoing)
		if not allowed then
			return { ok = false, error = refusal }
		end
		local target = playerOfState(profile.stateId)
		if relation == 'incoming' then
			if not ElosPersistence.Accept(profile.characterId, character.id) then
				return { ok = false, error = 'database_error' }
			end
			if target then
				notify(target, 'success', _t('connection_accepted', { name = me.name }))
			end
			return { ok = true, relation = 'connected' }
		end
		if not ElosPersistence.Request(character.id, profile.characterId) then
			return { ok = false, error = 'database_error' }
		end
		if target then
			notify(target, 'info', _t('connection_request', { name = me.name }))
		end
		return { ok = true, relation = 'outgoing' }
	end)
end

-- Responde a um pedido recebido: accept = true conecta; false recusa.
function App.respond(_, character, payload)
	local profile, errorCode = profileFor(payload)
	if not profile then
		return { ok = false, error = errorCode }
	end
	local row = ElosPersistence.Connection(character.id, profile.characterId)
	if row == nil then
		return { ok = false, error = 'database_error' }
	end
	if ElosRules.Relation(character.id, profile.characterId, row or nil) ~= 'incoming' then
		return { ok = false, error = 'no_request' }
	end
	if payload.accept == true then
		if not ElosPersistence.Accept(profile.characterId, character.id) then
			return { ok = false, error = 'database_error' }
		end
		local target = playerOfState(profile.stateId)
		if target then
			notify(target, 'success', _t('connection_accepted', { name = character.name }))
		end
		return { ok = true, relation = 'connected' }
	end
	return ElosPersistence.Remove(character.id, profile.characterId) ~= nil and { ok = true, relation = 'none' } or { ok = false, error = 'database_error' }
end

-- Cancela um pedido enviado ou desfaz uma conexão.
function App.remove(_, character, payload)
	local profile, errorCode = profileFor(payload)
	if not profile then
		return { ok = false, error = errorCode }
	end
	local removed = ElosPersistence.Remove(character.id, profile.characterId)
	if removed == nil then
		return { ok = false, error = 'database_error' }
	end
	return { ok = true, relation = 'none' }
end

-- Exports para o tablet e o smartphone ----------------------------------------------------------------

local function installed(playerId, device)
	if GetResourceState('coe_apps') ~= 'started' then
		return false
	end
	local ok, result = pcall(function()
		return exports.coe_apps:HasApp(playerId, 'elos', device)
	end)
	return ok and result == true
end

exports('TabletVisible', function(playerId, appId)
	local device = HOSTS[GetInvokingResource()]
	return device ~= nil and ready and appId == 'elos' and installed(playerId, device)
end)

exports('TabletCall', function(playerId, appId, action, payload)
	local device = HOSTS[GetInvokingResource()]
	if not device then
		return { ok = false, error = 'forbidden' }
	end
	if not ready then
		return { ok = false, error = 'not_ready' }
	end
	local character = characterOf(playerId)
	if not character then
		return { ok = false, error = 'no_character' }
	end
	local handler = appId == 'elos' and type(action) == 'string' and rawget(App, action)
	if type(handler) ~= 'function' then
		return { ok = false, error = 'unknown_action' }
	end
	if not installed(playerId, device) then
		return { ok = false, error = 'not_installed' }
	end
	local now = GetGameTimer()
	if action ~= 'state' and lastCall[playerId] and now - lastCall[playerId] < config.CallCooldownMs then
		return { ok = false, error = 'busy' }
	end
	lastCall[playerId] = now
	return handler(playerId, character, type(payload) == 'table' and payload or {})
end)

-- Perfil público para outros resources (fase 2: candidaturas). Mesmo recorte de quem visita sem conexão.
exports('GetProfile', function(characterId)
	if not ready or characterId == nil then
		return nil
	end
	local profile = ElosPersistence.Profile(tostring(characterId))
	if not profile then
		return nil
	end
	local list, jobs = experiences(profile.characterId)
	if not list then
		return nil
	end
	return {
		stateId = profile.stateId, name = profile.name, headline = profile.headline, about = profile.about,
		resume = ElosRules.PublicResume(profile, list), summary = ElosRules.Summary(list, true),
		career = profile.showCareer and careerCard(jobs) or nil
	}
end)

exports('IsReady', function()
	return ready
end)

-- Ciclo de vida --------------------------------------------------------------------------------------------

AddEventHandler('playerDropped', function()
	closeShift(source)
	lastCall[source] = nil
end)

AddEventHandler('onResourceStop', function(resource)
	if resource ~= GetCurrentResourceName() then
		return
	end
	for playerId in pairs(shifts) do
		closeShift(playerId)
	end
end)

CreateThread(function()
	-- Espera o coe_database conectar (no boot ele pode iniciar depois); outro erro é falha real da migração.
	local waitingLogged = false
	while true do
		local initialized, errorCode = ElosPersistence.Initialize()
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
			log('error', 'persistence', 'elos_migrations_failed', { error_code = tostring(errorCode) })
			return
		end
	end
	ready = true
	-- Quem já estava de ponto quando o Elos iniciou começa a contar agora.
	for _, id in ipairs(GetPlayers()) do
		local playerId = tonumber(id)
		local ok, businessId = pcall(function()
			return exports.coe_businesses:CurrentDuty(playerId)
		end)
		if ok and type(businessId) == 'string' then
			openShift(playerId, businessId)
		end
	end
	log('info', 'system', 'elos_ready', {})
end)
