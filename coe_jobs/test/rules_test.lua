-- Contrato do coe_jobs: validação das definições, níveis, pagamento e checagens anti-trapaça.
dofile('shared/rules.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end

local function gatherJob(patch)
	local job = {
		id = 'lumberjack', label = 'Lenhador', kind = 'gather',
		center = { x = 1.0, y = 2.0, z = 3.0, h = 90.0 },
		levels = { 0, 100, 300 },
		vehicle = { model = 'bison', spawn = { 5, 6, 7, 180 }, deposit = 250, plate = 'lenh-1' },
		tool = { model = 'prop_w_me_hatchet', bone = 57005, offset = { 0.1, 0, 0 }, rotation = { 0, 0, 90 } },
		gather = {
			nodes = { { 10, 10, 10 }, { 20, 20, 20 } }, seconds = 8, yield = { 2, 3 }, capacity = 24, xp = 4,
			animation = { dict = 'melee@large_wpn@streamed_core', name = 'ground_attack_on_spot', flag = 1 },
			sell = { points = { { 30, 30, 30 } }, price = 15, label = 'Vender toras' }
		}
	}
	for k, v in pairs(patch or {}) do job[k] = v end
	return job
end

local function routeJob(patch)
	local job = {
		id = 'delivery', label = 'Entregador', kind = 'route', center = { 0, 0, 0 },
		vehicle = { model = 'boxville2', spawn = { 1, 1, 1 } },
		route = { stops = { { 100, 0, 0 }, { 200, 0, 0 }, { 300, 0, 0 } }, perRoute = 2, pay = 80, bonus = 150,
			carry = { model = 'prop_cs_cardbox_01', bone = 28422 }, carryAnimation = { dict = 'anim@heists@box_carry@', name = 'idle', flag = 49 } }
	}
	for k, v in pairs(patch or {}) do job[k] = v end
	return job
end

-- definição válida (coleta)
local job, err = JobRules.Validate(gatherJob())
eq(err, nil, 'coleta valida')
eq(job.center.h, 90.0, 'heading do centro')
eq(job.vehicle.plate, 'LENH', 'placa normalizada em 4 letras')
eq(job.vehicle.deposit, 250, 'deposito')
eq(job.vehicle.spawn.h, 180, 'spawn com heading em lista')
eq(job.gather.nodes[2].x, 20, 'pontos em lista viram x/y/z')
eq(job.gather.animation.flag, 1, 'animacao')
eq(job.tool.rotation[3], 90, 'ferramenta')
eq(job.levelBonus, 0.05, 'bonus padrao de 5% por nivel')

-- erros de contrato
local function code(def) local _, e = JobRules.Validate(def); return e end
eq(code(nil), 'invalid_definition', 'definicao nil')
eq(code(gatherJob({ id = 'Lumber Jack' })), 'invalid_id', 'id invalido')
eq(code(gatherJob({ id = 'deposit' })), 'invalid_id', 'id reservado')
eq(code(gatherJob({ kind = 'mining' })), 'invalid_kind', 'tipo desconhecido')
eq(code(gatherJob({ center = { 'a' } })), 'invalid_center', 'centro invalido')
eq(code(gatherJob({ levels = { 10, 20 } })), 'invalid_levels', 'niveis comecam em 0')
eq(code(gatherJob({ levels = { 0, 50, 40 } })), 'invalid_levels', 'niveis crescentes')
eq(code(gatherJob({ vehicle = { model = 'bison' } })), 'invalid_vehicle', 'veiculo sem spawn')
eq(code(gatherJob({ tool = { model = 'a b' } })), 'invalid_tool', 'ferramenta invalida')
local bad = gatherJob(); bad.gather.nodes[2] = { 'x', 1, 1 }
eq(code(bad), 'invalid_nodes:2', 'ponto invalido indica o indice')
bad = gatherJob(); bad.gather.yield = { 3, 2 }
eq(code(bad), 'invalid_yield', 'rendimento invertido')
bad = gatherJob(); bad.gather.sell.price = 0
eq(code(bad), 'invalid_price', 'preco zero')
bad = gatherJob(); bad.gather.sell = nil
eq(code(bad), 'invalid_sell_points', 'sem ponto de venda')
bad = gatherJob(); bad.gather.animation = { dict = 'x' }
eq(code(bad), 'invalid_animation', 'animacao sem nome')

-- rota
job, err = JobRules.Validate(routeJob())
eq(err, nil, 'rota valida')
eq(job.route.vehicleRange, 40.0, 'alcance padrao do veiculo')
eq(#job.route.recipients, 3, 'destinatarios padrao')
eq(code(routeJob({ route = { stops = { { 1, 1, 1 } }, pay = 10 } })), 'invalid_stops', 'rota com uma parada')
eq(code(routeJob({ route = { stops = { { 1, 1, 1 }, { 2, 2, 2 } }, perRoute = 3, pay = 10 } })), 'invalid_per_route', 'mais paradas por rota que o total')
eq(code(routeJob({ route = { stops = { { 1, 1, 1 }, { 2, 2, 2 } }, perRoute = 2, pay = 0 } })), 'invalid_pay', 'pagamento zero')

-- niveis e pagamento
local levels = { 0, 100, 300 }
eq(JobRules.Level(levels, 0), 1, 'nivel 1')
eq(JobRules.Level(levels, 99), 1, 'ainda nivel 1')
eq(JobRules.Level(levels, 100), 2, 'nivel 2')
eq(JobRules.Level(levels, 5000), 3, 'nivel maximo')
eq(JobRules.NextLevelXp(levels, 120), 300, 'proximo nivel')
eq(JobRules.NextLevelXp(levels, 400), nil, 'sem proximo no maximo')
eq(JobRules.Pay(100, 1, 0.05), 100, 'nivel 1 sem bonus')
eq(JobRules.Pay(100, 3, 0.05), 110, 'nivel 3 com +10%')
eq(JobRules.Pay(15, 2, 0.05), 15, 'arredonda para baixo')

-- posicao e tempo
eq(JobRules.Near({ x = 0, y = 0, z = 0 }, { x = 3, y = 4, z = 5 }, 5, 6), true, 'perto na horizontal com altura tolerada')
eq(JobRules.Near({ x = 0, y = 0, z = 0 }, { x = 3, y = 4, z = 9 }, 5, 6), false, 'altura demais')
eq(JobRules.Near({ x = 0, y = 0, z = 0 }, { x = 6, y = 0, z = 0 }, 5, 6), false, 'longe')
eq(JobRules.MinTravelSeconds({ x = 0, y = 0, z = 0 }, { x = 600, y = 0, z = 0 }, 60), 10, 'tempo minimo de viagem')

-- sorteio de paradas: distintas e no tamanho pedido
local seq = { 3, 1, 2, 1 }
local i = 0
local picked = JobRules.PickStops(5, 3, function(n) i = i + 1; return math.min(n, seq[i] or 1) end)
eq(#picked, 3, 'tres paradas')
local seen = {}
for _, v in ipairs(picked) do
	eq(seen[v], nil, 'paradas distintas')
	seen[v] = true
end

-- parte publica nao leva o que so o servidor usa
local public = JobRules.Public(JobRules.Validate(routeJob()))
eq(public.route.stops, nil, 'paradas da rota nao vao ao client antes da hora')
eq(public.vehicle.spawn, nil, 'spawn do veiculo fica no servidor')
eq(public.route.pay, 80, 'pagamento visivel')

-- modos de rota: coleta exige carga; passageiro usa duas paradas por corrida; pagamento por km
local function routeWith(fields)
	local raw = routeJob()
	for k, v in pairs(fields) do raw.route[k] = v end
	return JobRules.Validate(raw)
end
eq(JobRules.Validate(routeJob()).route.mode, 'deliver', 'modo padrao')
_, err = routeWith({ mode = 'voar' })
eq(err, 'invalid_mode', 'modo desconhecido')
local noCarry = routeJob()
noCarry.route.mode, noCarry.route.carry = 'collect', nil
_, err = JobRules.Validate(noCarry)
eq(err, 'invalid_carry', 'coleta sem carga')
job = routeWith({ mode = 'collect', stopProp = 'prop_dumpster_01a' })
eq(job.route.stopProp, 'prop_dumpster_01a', 'prop da parada')
eq(job.route.dropLabel, 'Guardar no veículo', 'rotulo padrao de guardar')
_, err = routeWith({ mode = 'passenger', perRoute = 2 })
eq(err, 'invalid_per_route', 'duas corridas precisam de quatro paradas')
job = routeWith({ mode = 'passenger', perRoute = 1, payPerKm = 50, stopRadius = 12 })
eq(JobRules.RouteStops(job.route), 2, 'corrida usa embarque e destino')
eq(job.route.stopRadius, 12, 'raio da parada')
eq(JobRules.StopPay(job.route, { x = 0, y = 0, z = 0 }, { x = 2500, y = 0, z = 0 }), 80 + 125, 'fixo + 2,5 km x $50')
eq(JobRules.StopPay(JobRules.Validate(routeJob()).route, { x = 0, y = 0, z = 0 }, { x = 9000, y = 0, z = 0 }), 80, 'sem payPerKm paga so o fixo')
eq(JobRules.Public(job).route.mode, 'passenger', 'modo vai ao client')

-- dicas do guia
local tipped = routeJob()
tipped.tips = { 'Pare perto da porta.' }
eq(JobRules.Validate(tipped).tips[1], 'Pare perto da porta.', 'dica aceita')
eq(#JobRules.Validate(routeJob()).tips, 0, 'sem dicas')
tipped.tips = { 1 }
_, err = JobRules.Validate(tipped)
eq(err, 'invalid_tips', 'dica precisa ser texto')
tipped.tips = { 'a', 'b', 'c', 'd', 'e', 'f', 'g' }
_, err = JobRules.Validate(tipped)
eq(err, 'invalid_tips', 'no maximo 6 dicas')

-- modo zona: áreas com raio, lixeiras do mapa e sacos por área
local zoneRaw = routeJob()
zoneRaw.route = { mode = 'zone', pay = 30, perRoute = 2, perZone = 4, carry = { model = 'prop_cs_rub_binbag_01', fallback = 'hei_prop_heist_binbag' },
	binModels = { 'prop_bin_01a', 'prop_dumpster_01a' },
	zones = { { 100, 0, 0, radius = 80, label = 'Centro' }, { 500, 0, 0, radius = 60 } } }
local zoned = JobRules.Validate(zoneRaw)
eq(zoned.route.mode, 'zone', 'modo zona')
eq(#zoned.route.stops, 2, 'zonas viram paradas sorteaveis')
eq(zoned.route.zones[1].radius, 80, 'raio da zona')
eq(zoned.route.zones[2].label, 'Zona 2', 'nome padrao da zona')
eq(zoned.route.perZone, 4, 'sacos por zona')
eq(zoned.route.binCooldown, 600, 'cooldown padrao da lixeira')
eq(zoned.route.rearDoor, 5, 'porta traseira padrao')
eq(zoned.route.carry.fallback, 'hei_prop_heist_binbag', 'modelo reserva do saco')
eq(JobRules.Public(zoned).route.binModels[2], 'prop_dumpster_01a', 'lixeiras vao ao client')
eq(JobRules.Public(zoned).route.zones, nil, 'zonas so pela sessao')
zoneRaw.route.binModels = {}
_, err = JobRules.Validate(zoneRaw)
eq(err, 'invalid_bins', 'precisa de lixeiras')
zoneRaw.route.binModels = { 'prop_bin_01a' }
zoneRaw.route.zones = { { 100, 0, 0, radius = 80 }, { 500, 0, 0 } }
_, err = JobRules.Validate(zoneRaw)
eq(err, 'invalid_zones:2', 'zona sem raio')
zoneRaw.route.zones = { { 100, 0, 0, radius = 80 } }
_, err = JobRules.Validate(zoneRaw)
eq(err, 'invalid_zones', 'pelo menos duas zonas')
eq(JobRules.BinKey({ x = 10.4, y = -3.6, z = 29.5 }), '10:-4:30', 'chave da lixeira arredondada')

print('coe_jobs rules tests passed')
