-- Todos os empregos de jobs/ passam no contrato e o salário fica na faixa planejada.
dofile('shared/rules.lua')
dofile('config.lua')
local FILES = { 'lumberjack', 'miner', 'fisher', 'farmer', 'delivery', 'garbage', 'taxi', 'trucker' }
for _, name in ipairs(FILES) do
	dofile('jobs/' .. name .. '.lua')
end

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end

local known = {}
for id in pairs(JobsConfig.Career.skills) do known[id] = true end

-- Distância média entre duas paradas distintas (rotas sorteiam as paradas).
local function averageDistance(stops)
	local sum, count = 0, 0
	for a = 1, #stops do
		for b = 1, #stops do
			if a ~= b then
				sum, count = sum + JobRules.Distance(stops[a], stops[b]), count + 1
			end
		end
	end
	return sum / count
end

-- Estimativa por hora no nível 1, sem carreira (mesma conta da tabela do README).
--   coleta: ação + ~15 s até o próximo ponto; ~2,5 min de ida e volta ao comprador a cada carga cheia.
--   rota: dirigir a ~18 m/s pela distância média + ~75 s parando e entregando (passageiro: ida até o embarque e
--   corrida, + ~60 s); bônus no fim da rota. Zona: ~45 s por saco mais a viagem entre áreas.
local function hourly(job)
	if job.gather then
		local g = job.gather
		local units = 3600 / (g.seconds + 15) * (g.yield[1] + g.yield[2]) / 2
		local selling = units / g.capacity * 150
		return math.floor((3600 - selling) / 3600 * units * g.sell.price)
	end
	local r = job.route
	local distance = averageDistance(r.stops)
	if r.mode == 'zone' then
		-- ~45 s por saco (achar a lixeira, levar, jogar) e a viagem entre áreas.
		local zoneSeconds = r.perZone * 45 + distance / 18
		local zonesPerHour = 3600 / zoneSeconds
		return math.floor(zonesPerHour * r.perZone * r.pay + zonesPerHour / r.perRoute * r.bonus)
	end
	local seconds = r.mode == 'passenger' and (2 * distance / 18 + 60) or (distance / 18 + 75)
	local perStop = r.pay + math.floor(r.payPerKm * distance / 1000)
	local stops = 3600 / seconds
	return math.floor(stops * perStop + stops / r.perRoute * r.bonus)
end

local seen, hours = {}, {}
local entryMax = 0
for _, raw in ipairs(JobsCatalog) do
	local job, err = JobRules.Validate(raw, known)
	eq(err, nil, tostring(raw.id) .. ' passa no contrato')
	eq(seen[job.id], nil, 'ids distintos')
	seen[job.id] = true
	eq(JobsConfig.Enabled[job.id] ~= nil, true, job.id .. ' tem chave em Enabled')
	eq(#job.levels, 5, job.id .. ' com 5 niveis')
	eq(#job.skills >= 1, true, job.id .. ' treina alguma habilidade')
	local hour = hourly(job)
	hours[#hours + 1] = ('%s ~$%d/h'):format(job.id, hour)
	if job.requires then
		-- Empregos com requisito pagam mais: o histórico vale a pena.
		assert(hour >= 2200 and hour <= 3800, ('%s (com requisito) fora da faixa: %d/h'):format(job.id, hour))
	else
		assert(hour >= 1500 and hour <= 3000, ('%s fora da faixa: %d/h'):format(job.id, hour))
		entryMax = math.max(entryMax, hour)
	end
end
eq(#JobsCatalog, #FILES, 'todos os arquivos de jobs/ carregados')
for id in pairs(JobsConfig.Enabled) do
	eq(seen[id], true, id .. ' de Enabled tem arquivo')
end

-- Cada habilidade é treinada por pelo menos dois empregos (o histórico em um vale no outro).
local trainers = {}
for _, raw in ipairs(JobsCatalog) do
	for _, skill in ipairs(raw.skills) do trainers[skill] = (trainers[skill] or 0) + 1 end
end
for id in pairs(JobsConfig.Career.skills) do
	assert((trainers[id] or 0) >= 2, id .. ' treinada por menos de dois empregos')
end

-- Todo requisito de habilidade pode ser treinado num emprego sem requisito.
for _, raw in ipairs(JobsCatalog) do
	for skill in pairs(raw.requires and raw.requires.skills or {}) do
		local open = false
		for _, other in ipairs(JobsCatalog) do
			if not other.requires then
				for _, s in ipairs(other.skills) do if s == skill then open = true end end
			end
		end
		eq(open, true, raw.id .. ': ' .. skill .. ' se treina num emprego livre')
	end
end

print(('coe_jobs catalog tests passed (%s; nivel 1)'):format(table.concat(hours, ', ')))
