-- Carreira do jogador nos empregos livres (pura, testável): o histórico em um emprego vale nos outros.
--
-- - Carreira: soma do XP de todos os empregos -> nível de carreira (bônus geral de pagamento e de XP).
-- - Habilidades: cada emprego treina habilidades (`skills`); o XP de uma habilidade é a soma do XP dos empregos que a
--   treinam. Os bônus da habilidade valem em qualquer emprego que a use (ex.: Força do lenhador ajuda o mineiro).
-- - Reputação: confiabilidade (concluir soma, abandonar com o veículo da empresa tira). Boa reputação dispensa
--   depósito e paga mais; ruim encarece o depósito e trava empregos que exigem reputação.
JobCareer = {}

local function levelOf(levels, xp)
	local level = 1
	for index, threshold in ipairs(levels) do
		if (xp or 0) >= threshold then
			level = index
		end
	end
	return level
end

JobCareer.LevelOf = levelOf

local function tierOf(career, reputation)
	local best = nil
	for _, tier in ipairs(career.reputation.tiers) do
		if reputation >= tier.min and (not best or tier.min > best.min) then
			best = tier
		end
	end
	return best or { min = -math.huge, label = 'Regular' }
end

-- jobs: id -> definição validada; progress: id -> { xp, tasks, earned }; reputation: número.
-- Devolve o perfil: carreira, habilidades (xp/nível) e faixa de reputação.
function JobCareer.Profile(career, jobs, progress, reputation)
	progress = progress or {}
	reputation = math.max(career.reputation.min, math.min(career.reputation.max, reputation or career.reputation.start or 0))
	local total, tasks, earned = 0, 0, 0
	local skills = {}
	for id, skill in pairs(career.skills) do
		skills[id] = { id = id, label = skill.label, xp = 0, level = 1, maxLevel = #skill.levels }
	end
	for jobId, entry in pairs(progress) do
		local xp = tonumber(entry.xp) or 0
		total = total + xp
		tasks = tasks + (tonumber(entry.tasks) or 0)
		earned = earned + (tonumber(entry.earned) or 0)
		local job = jobs[jobId]
		for _, skillId in ipairs(job and job.skills or {}) do
			if skills[skillId] then
				skills[skillId].xp = skills[skillId].xp + xp
			end
		end
	end
	for id, skill in pairs(skills) do
		skill.level = levelOf(career.skills[id].levels, skill.xp)
		skill.nextXp = career.skills[id].levels[skill.level + 1]
	end
	local level = levelOf(career.levels, total)
	return {
		xp = total, tasks = tasks, earned = earned, level = level, maxLevel = #career.levels, nextXp = career.levels[level + 1],
		skills = skills, reputation = reputation, tier = tierOf(career, reputation)
	}
end

-- Soma de um bônus (`perk`) das habilidades que o emprego usa: valor por nível acima do 1.
local function perkSum(career, job, profile, perk)
	local sum = 0
	for _, skillId in ipairs(job.skills or {}) do
		local skill = career.skills[skillId]
		local state = profile.skills[skillId]
		if skill and state and skill.perks and skill.perks[perk] then
			sum = sum + skill.perks[perk] * (state.level - 1)
		end
	end
	return sum
end

-- Requisitos do emprego (`requires = { career, reputation, skills = { id = nível } }`). Devolve true ou false + motivo.
function JobCareer.Allowed(career, job, profile)
	local req = job.requires
	if not req then
		return true
	end
	if req.career and profile.level < req.career then
		return false, ('carreira nível %d'):format(req.career)
	end
	if req.reputation and profile.reputation < req.reputation then
		return false, ('reputação %d'):format(req.reputation)
	end
	for skillId, needed in pairs(req.skills or {}) do
		local state = profile.skills[skillId]
		if not state or state.level < needed then
			local label = career.skills[skillId] and career.skills[skillId].label or skillId
			return false, ('%s nível %d'):format(label, needed)
		end
	end
	return true
end

-- Tudo que o histórico muda neste emprego: bônus de pagamento, multiplicador de XP, carga, tempo da ação e depósito.
function JobCareer.Modifiers(career, job, profile, jobXp)
	local jobLevel = levelOf(job.levels, jobXp or 0)
	local tier = profile.tier or {}
	local payBonus = (jobLevel - 1) * (job.levelBonus or 0)
		+ (profile.level - 1) * career.payPerLevel
		+ perkSum(career, job, profile, 'pay')
		+ (tier.pay or 0)
	payBonus = math.max(0, math.min(career.maxPayBonus, payBonus))
	local speed = math.min(career.maxSpeedBonus, perkSum(career, job, profile, 'speed'))
	local capacity = perkSum(career, job, profile, 'capacity')
	local depositCut = math.min(1, perkSum(career, job, profile, 'deposit'))
	local depositFactor = tier.depositWaived and 0 or (1 - depositCut) * (tier.deposit or 1)
	local result = {
		jobLevel = jobLevel,
		payBonus = payBonus,
		xpMultiplier = 1 + (profile.level - 1) * career.xpPerLevel,
		depositFactor = depositFactor
	}
	if job.gather then
		result.seconds = math.max(1, job.gather.seconds * (1 - speed))
		result.capacity = math.floor(job.gather.capacity * (1 + capacity))
	end
	if job.vehicle then
		result.deposit = math.floor(job.vehicle.deposit * depositFactor)
	end
	return result
end

function JobCareer.Apply(base, payBonus)
	return math.floor(base * (1 + (payBonus or 0)))
end

-- Reputação depois de um evento (`complete`, `abandon`, `lost_vehicle`), dentro dos limites.
function JobCareer.Reputation(career, current, event)
	local delta = career.reputation.events[event] or 0
	return math.max(career.reputation.min, math.min(career.reputation.max, (current or 0) + delta))
end
