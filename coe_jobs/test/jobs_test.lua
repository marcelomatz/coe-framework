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
	if job.gather and job.gather.haul then
		-- transporte: árvores até encher a caçamba (ação + ~15 s até a próxima), ~12 s por tora carregada,
		-- ~150 s de ida e volta à madeireira, o tempo da serra e a venda das tábuas.
		local g = job.gather
		local raw = g.products[g.haul.product]
		local output = g.products[g.process.product]
		local cap = g.haul.capacity
		local trees = cap / ((raw.yield[1] + raw.yield[2]) / 2)
		local seconds = trees * (raw.seconds + 15) + cap * 12 + 150 + math.min(g.process.maxSeconds, g.process.seconds * cap)
		return math.floor(3600 / seconds * cap * g.process.ratio * output.price)
	end
	if job.gather and job.gather.fishing then
		-- pesca com a vara e a isca básicas na primeira área: arremesso (~2 s) + espera média + fisgar (~1 s) + briga
		-- (~1,4x o mínimo da espécie); acerta ~(faixa da briga x 0,6 + 55%); venda a cada carga cheia (~150 s);
		-- desconta a isca de cada lance.
		local g, f = job.gather, job.gather.fishing
		local rod, bait = f.rods[f.rodOrder[1]], f.baits[f.baitOrder[1]]
		local zone = f.areas[1]
		local total, value, fightMs = 0, 0, 0
		for _, entry in ipairs(zone.species) do
			local item = g.products[entry.id]
			total, value = total + entry.weight, value + entry.weight * item.price
			fightMs = fightMs + entry.weight * JobRules.FightParams(f, rod, item).minMs * 1.4
		end
		local bar = JobRules.FightParams(f, rod, g.products[zone.species[1].id]).bar
		local seconds = 2 + f.castSeconds + (f.biteSeconds[1] + f.biteSeconds[2]) / 2 * rod.speed * bait.speed + 1 + fightMs / total / 1000
		local casts = 3600 / seconds
		local fish = casts * math.min(0.95, bar * 0.6 + 0.55)
		local selling = fish / g.capacity * 150
		local baitPrice = 0
		for _, entry in ipairs(job.shop.items) do
			if entry.item == bait.item then baitPrice = entry.price end
		end
		return math.floor((3600 - selling) / 3600 * (fish * value / total - casts * baitPrice))
	end
	if job.gather then
		-- média dos pontos (cada um com o seu produto): ação + ~15 s até o próximo; venda a cada carga cheia.
		local g = job.gather
		local seconds, units, value = 0, 0, 0
		for _, node in ipairs(g.nodes) do
			local item = g.products[node.product]
			local each = (item.yield[1] + item.yield[2]) / 2
			seconds, units, value = seconds + item.seconds + 15, units + each, value + each * item.price
		end
		local perHour = 3600 / (seconds / #g.nodes)
		local unitsHour = perHour * units / #g.nodes
		local selling = unitsHour / g.capacity * 150
		return math.floor((3600 - selling) / 3600 * perHour * value / #g.nodes)
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
