-- Regras puras do Elos (sem natives): validação do perfil, montagem do currículo a partir dos empregos livres
-- (coe_jobs) e dos negócios (coe_businesses), o que cada visitante pode ver e o estado das conexões.
-- Testáveis fora do jogo (test/rules_test.lua).
ElosRules = {}

local VISIBILITY = { open = true, closed = true }
local KINDS = { job = true, business = true }

-- Texto livre: tira caracteres de controle (mantém quebras de linha no "Sobre"), espaços nas pontas e limita o tamanho.
function ElosRules.Text(value, max, multiline)
	if value == nil then
		return ''
	end
	if type(value) ~= 'string' then
		return nil
	end
	local clean = value:gsub('\r\n', '\n')
	clean = multiline and clean:gsub('[\0-\9\11-\31\127]', '') or clean:gsub('[\0-\31\127]', ' ')
	clean = clean:gsub('\n\n\n+', '\n\n'):gsub('^%s+', ''):gsub('%s+$', '')
	if not multiline then
		clean = clean:gsub('%s%s+', ' ')
	end
	if utf8.len(clean) == nil or utf8.len(clean) > max then
		return nil
	end
	return clean
end

-- Alterações do perfil: só os campos enviados. Devolve a tabela limpa ou nil + código.
function ElosRules.ProfilePatch(config, raw)
	if type(raw) ~= 'table' then
		return nil, 'invalid_profile'
	end
	local patch = {}
	if raw.headline ~= nil then
		patch.headline = ElosRules.Text(raw.headline, config.Profile.HeadlineMax, false)
		if not patch.headline then
			return nil, 'invalid_headline'
		end
	end
	if raw.about ~= nil then
		patch.about = ElosRules.Text(raw.about, config.Profile.AboutMax, true)
		if not patch.about then
			return nil, 'invalid_about'
		end
	end
	if raw.visibility ~= nil then
		if not VISIBILITY[raw.visibility] then
			return nil, 'invalid_visibility'
		end
		patch.visibility = raw.visibility
	end
	for _, flag in ipairs({ 'showEarnings', 'showCareer' }) do
		if raw[flag] ~= nil then
			if type(raw[flag]) ~= 'boolean' then
				return nil, 'invalid_profile'
			end
			patch[flag] = raw[flag]
		end
	end
	if next(patch) == nil then
		return nil, 'invalid_profile'
	end
	return patch
end

-- Identifica uma experiência: `job` (id do emprego livre) ou `business` (id do negócio).
function ElosRules.ItemKey(kind, ref)
	if not KINDS[kind] or type(ref) ~= 'string' or #ref < 2 or #ref > 48 or not ref:match('^[%w_%-]+$') then
		return nil
	end
	return kind .. ':' .. ref
end

function ElosRules.StateId(value)
	if type(value) ~= 'string' then
		return nil
	end
	local id = value:upper():gsub('%s', '')
	return #id == 8 and id:match('^[A-Z2-9]+$') and id or nil
end

local function laterFirst(a, b)
	if a.current ~= b.current then
		return a.current
	end
	if (a.lastAt or 0) ~= (b.lastAt or 0) then
		return (a.lastAt or 0) > (b.lastAt or 0)
	end
	return a.title < b.title
end

-- Todas as experiências do personagem (as que ele pode pôr no currículo):
--   career: GetCareer do coe_jobs (ou nil); works: horas de ponto por negócio ({ businessId, label, category,
--   role, seconds, shifts, firstAt, lastAt }); memberships: vínculos atuais ({ businessId, label, category, role,
--   owner }); items: chave -> { note, sort } do que está no currículo.
function ElosRules.Experiences(config, career, works, memberships, items)
	items = items or {}
	local list = {}
	for _, job in ipairs(career and career.jobs or {}) do
		if (job.tasks or 0) > 0 then
			local key = 'job:' .. job.id
			list[#list + 1] = {
				key = key, kind = 'job', ref = job.id, title = job.label, org = 'Empregos livres', subtitle = job.kindLabel,
				level = job.level, maxLevel = job.maxLevel, xp = job.xp, tasks = job.tasks, earned = job.earned,
				seconds = job.workedSeconds or 0, firstAt = job.firstAt, lastAt = job.lastAt, current = false,
				added = items[key] ~= nil, note = items[key] and items[key].note or ''
			}
		end
	end
	local businesses = {}
	for _, work in ipairs(works or {}) do
		businesses[work.businessId] = {
			businessId = work.businessId, label = work.label, category = work.category, role = work.role,
			seconds = work.seconds or 0, shifts = work.shifts or 0, firstAt = work.firstAt, lastAt = work.lastAt
		}
	end
	for _, member in ipairs(memberships or {}) do
		local entry = businesses[member.businessId] or { businessId = member.businessId, seconds = 0, shifts = 0 }
		entry.label = member.label or entry.label
		entry.category = member.category or entry.category
		entry.role = member.role or entry.role
		entry.owner = member.owner == true
		entry.current = true
		businesses[member.businessId] = entry
	end
	for id, entry in pairs(businesses) do
		local key = 'business:' .. id
		list[#list + 1] = {
			key = key, kind = 'business', ref = id, title = entry.role or (entry.owner and 'Dono' or 'Equipe'),
			org = entry.label or id, subtitle = config.BusinessCategories[entry.category or ''] or entry.category,
			seconds = entry.seconds, shifts = entry.shifts, firstAt = entry.firstAt, lastAt = entry.lastAt,
			current = entry.current == true, owner = entry.owner == true,
			added = items[key] ~= nil, note = items[key] and items[key].note or ''
		}
	end
	table.sort(list, laterFirst)
	return list
end

-- Resumo das experiências (horas e quantas), contando só as do currículo quando `onlyAdded`.
function ElosRules.Summary(list, onlyAdded)
	local seconds, count, current = 0, 0, 0
	for _, entry in ipairs(list) do
		if not onlyAdded or entry.added then
			seconds = seconds + (entry.seconds or 0)
			count = count + 1
			if entry.current then
				current = current + 1
			end
		end
	end
	return { seconds = seconds, count = count, current = current }
end

-- Relação entre o visitante e o dono do perfil: self, connected, incoming (pediu para mim), outgoing (eu pedi), none.
-- row: linha de coe_elos_connections entre os dois ({ requester, target, status }) ou nil.
function ElosRules.Relation(viewerId, ownerId, row)
	if viewerId == ownerId then
		return 'self'
	end
	if not row then
		return 'none'
	end
	if row.status == 'accepted' then
		return 'connected'
	end
	return row.requester == viewerId and 'outgoing' or 'incoming'
end

-- Perfil aberto: todos veem tudo. Fechado: só o próprio e as conexões; os outros veem nome e apresentação.
function ElosRules.CanSeeAll(profile, relation)
	return relation == 'self' or relation == 'connected' or profile.visibility == 'open'
end

-- Currículo como o visitante vê: só as experiências adicionadas, sem ganhos quando o dono esconde, sem chave interna.
function ElosRules.PublicResume(profile, list)
	local out = {}
	for _, entry in ipairs(list) do
		if entry.added then
			out[#out + 1] = {
				kind = entry.kind, title = entry.title, org = entry.org, subtitle = entry.subtitle, level = entry.level,
				maxLevel = entry.maxLevel, xp = entry.xp, tasks = entry.tasks, shifts = entry.shifts, seconds = entry.seconds,
				earned = profile.showEarnings and entry.earned or nil, firstAt = entry.firstAt, lastAt = entry.lastAt,
				current = entry.current, owner = entry.owner, note = entry.note ~= '' and entry.note or nil
			}
		end
	end
	return out
end

-- Pode pedir conexão? Devolve true ou nil + código.
function ElosRules.CanRequest(config, relation, myConnections, myPendingOut)
	if relation == 'self' then
		return nil, 'self'
	end
	if relation == 'connected' then
		return nil, 'already_connected'
	end
	if relation == 'outgoing' then
		return nil, 'already_requested'
	end
	if myConnections >= config.Network.MaxConnections then
		return nil, 'connection_limit'
	end
	if relation ~= 'incoming' and myPendingOut >= config.Network.MaxPendingOut then
		return nil, 'pending_limit'
	end
	return true
end
