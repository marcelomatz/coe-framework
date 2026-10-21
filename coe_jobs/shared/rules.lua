-- Regras puras do coe_jobs (sem natives): validação das definições de emprego, níveis, pagamento e checagens de
-- posição/tempo usadas pelo servidor. Testáveis fora do jogo (test/rules_test.lua).
JobRules = {}

local KINDS = { gather = true, route = true }
-- deliver: leva do veículo até o destinatário; collect: recolhe na parada e guarda no veículo;
-- passenger: embarca na parada e desembarca na seguinte (táxi).
-- zone: vai até uma área e recolhe em qualquer lixeira/objeto do mapa (`binModels`) até completar a zona.
local ROUTE_MODES = { deliver = true, collect = true, passenger = true, zone = true }
local MAX_POINTS = 200
local MAX_LEVELS = 20

local function isId(value)
	return type(value) == 'string' and #value >= 2 and #value <= 24 and value:match('^[a-z][a-z0-9_]*$') ~= nil
end

local function text(value, max)
	return type(value) == 'string' and #value > 0 and #value <= (max or 64)
end

local function num(value, min, max)
	local n = tonumber(value)
	if not n or n ~= n or n == math.huge or n == -math.huge then
		return nil
	end
	if (min and n < min) or (max and n > max) then
		return nil
	end
	return n
end

local function int(value, min, max)
	local n = num(value, min, max)
	return n and math.floor(n) == n and n or nil
end

local function model(value)
	return type(value) == 'string' and #value >= 2 and #value <= 48 and value:match('^[%w_]+$') ~= nil
end

-- Ponto {x, y, z, h?}; devolve uma cópia limpa.
local function point(raw)
	if type(raw) ~= 'table' then
		return nil
	end
	local x, y, z = num(raw.x or raw[1], -10000, 10000), num(raw.y or raw[2], -10000, 10000), num(raw.z or raw[3], -500, 3000)
	if not x or not y or not z then
		return nil
	end
	local heading = num(raw.h or raw.heading or raw[4], -360, 360) or 0.0
	return { x = x, y = y, z = z, h = heading }
end

local function points(raw, min)
	if type(raw) ~= 'table' or #raw < (min or 1) or #raw > MAX_POINTS then
		return nil
	end
	local out = {}
	for index, entry in ipairs(raw) do
		local clean = point(entry)
		if not clean then
			return nil, index
		end
		out[index] = clean
	end
	return out
end

-- Animação: { dict, name, flag? } ou { scenario }.
local function anim(raw)
	if raw == nil then
		return nil, true
	end
	if type(raw) ~= 'table' then
		return nil, false
	end
	if raw.scenario then
		return model(raw.scenario) and { scenario = raw.scenario } or nil, model(raw.scenario)
	end
	if not text(raw.dict, 96) or not text(raw.name, 96) then
		return nil, false
	end
	return { dict = raw.dict, name = raw.name, flag = int(raw.flag, 0, 1023) or 1 }, true
end

-- Prop segurado na mão: { model, bone?, offset?, rotation? }.
local function prop(raw)
	if raw == nil then
		return nil, true
	end
	if type(raw) ~= 'table' or not model(raw.model) then
		return nil, false
	end
	local function vec(v)
		if type(v) ~= 'table' then
			return { 0.0, 0.0, 0.0 }
		end
		return { num(v[1], -10, 10) or 0.0, num(v[2], -10, 10) or 0.0, num(v[3], -360, 360) or 0.0 }
	end
	return {
		model = raw.model,
		-- Modelo reserva se o principal não existir no jogo (o client tenta na ordem).
		fallback = model(raw.fallback) and raw.fallback or nil,
		bone = int(raw.bone, 0, 65535) or 57005,
		offset = vec(raw.offset),
		rotation = (function()
			if type(raw.rotation) ~= 'table' then return { 0.0, 0.0, 0.0 } end
			return { num(raw.rotation[1], -360, 360) or 0.0, num(raw.rotation[2], -360, 360) or 0.0, num(raw.rotation[3], -360, 360) or 0.0 }
		end)()
	}, true
end

local function fail(code, detail)
	return nil, detail and (code .. ':' .. detail) or code
end

function JobRules.IsId(value)
	return isId(value)
end

-- Valida e normaliza a definição de um emprego. Devolve a definição limpa ou nil + código.
-- knownSkills (opcional): id -> true das habilidades da carreira; habilidade desconhecida é erro.
function JobRules.Validate(raw, knownSkills)
	if type(raw) ~= 'table' then
		return fail('invalid_definition')
	end
	-- `deposit` é o motivo do extrato do depósito de veículo (job_deposit).
	if not isId(raw.id) or raw.id == 'deposit' then
		return fail('invalid_id')
	end
	if not text(raw.label, 40) then
		return fail('invalid_label')
	end
	if not KINDS[raw.kind] then
		return fail('invalid_kind')
	end
	local center = point(raw.center)
	if not center then
		return fail('invalid_center')
	end
	local job = {
		id = raw.id, label = raw.label, kind = raw.kind,
		description = text(raw.description, 240) and raw.description or '',
		center = center,
		centerPed = model(raw.centerPed) and raw.centerPed or 's_m_m_gentransport',
		blip = {
			sprite = int(type(raw.blip) == 'table' and raw.blip.sprite, 1, 900) or 408,
			color = int(type(raw.blip) == 'table' and raw.blip.color, 0, 85) or 2
		},
		-- Limites de XP por nível (crescentes, começando em 0).
		levels = {},
		levelBonus = num(raw.levelBonus, 0, 1) or 0.05,
		tool = nil, vehicle = nil
	}
	local levels = raw.levels or { 0 }
	if type(levels) ~= 'table' or #levels < 1 or #levels > MAX_LEVELS or levels[1] ~= 0 then
		return fail('invalid_levels')
	end
	for index, value in ipairs(levels) do
		local xp = int(value, 0, 10000000)
		if not xp or (index > 1 and xp <= job.levels[index - 1]) then
			return fail('invalid_levels')
		end
		job.levels[index] = xp
	end
	-- Habilidades que o emprego treina (o XP dele soma nelas) e requisitos de carreira para começar.
	job.skills = {}
	for _, skill in ipairs(type(raw.skills) == 'table' and raw.skills or {}) do
		if not isId(skill) or (knownSkills and not knownSkills[skill]) then
			return fail('invalid_skill', tostring(skill))
		end
		job.skills[#job.skills + 1] = skill
	end
	if raw.requires ~= nil then
		local r = raw.requires
		if type(r) ~= 'table' then
			return fail('invalid_requires')
		end
		job.requires = { career = int(r.career, 1, 100), reputation = int(r.reputation, -1000, 1000), skills = {} }
		for skill, level in pairs(type(r.skills) == 'table' and r.skills or {}) do
			if not isId(skill) or (knownSkills and not knownSkills[skill]) or not int(level, 1, 100) then
				return fail('invalid_requires')
			end
			job.requires.skills[skill] = level
		end
	end
	-- Dicas extras do guia "Como funciona" (até 6 frases).
	job.tips = {}
	if raw.tips ~= nil then
		if type(raw.tips) ~= 'table' or #raw.tips > 6 then
			return fail('invalid_tips')
		end
		for _, tip in ipairs(raw.tips) do
			if not text(tip, 160) then
				return fail('invalid_tips')
			end
			job.tips[#job.tips + 1] = tip
		end
	end
	local tool, toolOk = prop(raw.tool)
	if not toolOk then
		return fail('invalid_tool')
	end
	job.tool = tool
	if raw.vehicle ~= nil then
		local v = raw.vehicle
		local spawn = type(v) == 'table' and point(v.spawn)
		if type(v) ~= 'table' or not model(v.model) or not spawn then
			return fail('invalid_vehicle')
		end
		local plate = type(v.plate) == 'string' and v.plate:upper():gsub('[^A-Z0-9]', ''):sub(1, 4) or 'JOB'
		job.vehicle = {
			model = v.model, spawn = spawn, plate = plate ~= '' and plate or 'JOB',
			deposit = int(v.deposit, 0, 100000) or 0,
			-- Distância do centro para devolver o veículo e reaver o depósito.
			returnRadius = num(v.returnRadius, 5, 200) or 35.0
		}
	end
	if raw.kind == 'gather' then
		local g = raw.gather
		if type(g) ~= 'table' then
			return fail('invalid_gather')
		end
		local nodes, badNode = points(g.nodes)
		if not nodes then
			return fail('invalid_nodes', badNode and tostring(badNode) or nil)
		end
		local sell, badSell = points(g.sell and g.sell.points)
		if not sell then
			return fail('invalid_sell_points', badSell and tostring(badSell) or nil)
		end
		local animation, animOk = anim(g.animation)
		if not animOk then
			return fail('invalid_animation')
		end
		local yield = type(g.yield) == 'table' and g.yield or { 1, 1 }
		local minYield, maxYield = int(yield[1], 1, 100), int(yield[2], 1, 100)
		if not minYield or not maxYield or maxYield < minYield then
			return fail('invalid_yield')
		end
		local price = int(g.sell.price, 1, 100000)
		if not price then
			return fail('invalid_price')
		end
		job.gather = {
			nodes = nodes,
			nodeProp = model(g.nodeProp) and g.nodeProp or nil,
			actionLabel = text(g.actionLabel, 40) and g.actionLabel or 'Coletar',
			seconds = num(g.seconds, 1, 120) or 6,
			yield = { minYield, maxYield },
			capacity = int(g.capacity, 1, 1000) or 20,
			nodeCooldown = int(g.nodeCooldown, 0, 3600) or 60,
			xp = int(g.xp, 0, 10000) or 1,
			unit = text(g.unit, 24) and g.unit or 'unidade',
			units = text(g.units, 24) and g.units or 'unidades',
			animation = animation,
			sell = {
				points = sell, price = price,
				ped = model(g.sell.ped) and g.sell.ped or 's_m_m_gentransport',
				label = text(g.sell.label, 40) and g.sell.label or 'Vender'
			}
		}
	else
		local r = raw.route
		if type(r) ~= 'table' then
			return fail('invalid_route')
		end
		local mode = r.mode or 'deliver'
		if not ROUTE_MODES[mode] then
			return fail('invalid_mode')
		end
		-- Zonas: cada uma é um centro com raio; as rotas sorteiam zonas como sorteiam paradas.
		local zones
		if mode == 'zone' then
			if type(r.zones) ~= 'table' or #r.zones < 2 or #r.zones > MAX_POINTS then
				return fail('invalid_zones')
			end
			zones = {}
			for index, raw_zone in ipairs(r.zones) do
				local center = point(raw_zone)
				local radius = type(raw_zone) == 'table' and num(raw_zone.radius, 10, 400)
				if not center or not radius then
					return fail('invalid_zones', tostring(index))
				end
				zones[index] = {
					x = center.x, y = center.y, z = center.z, radius = radius,
					label = text(raw_zone.label, 40) and raw_zone.label or ('Zona ' .. index)
				}
			end
		end
		local stops, badStop
		if zones then
			stops = {}
			for index, zone in ipairs(zones) do
				stops[index] = { x = zone.x, y = zone.y, z = zone.z, h = 0.0 }
			end
		else
			stops, badStop = points(r.stops, 2)
			if not stops then
				return fail('invalid_stops', badStop and tostring(badStop) or nil)
			end
		end
		local perRoute = int(r.perRoute, 1, 50) or 5
		-- Passageiro: cada corrida usa duas paradas (embarque e destino).
		if perRoute * (mode == 'passenger' and 2 or 1) > #stops then
			return fail('invalid_per_route')
		end
		local pay = int(r.pay, 1, 100000)
		if not pay then
			return fail('invalid_pay')
		end
		local carry, carryOk = prop(r.carry)
		if not carryOk then
			return fail('invalid_carry')
		end
		local carryAnim, carryAnimOk = anim(r.carryAnimation)
		if not carryAnimOk then
			return fail('invalid_animation')
		end
		local peds = {}
		for _, ped in ipairs(type(r.recipients) == 'table' and r.recipients or {}) do
			if model(ped) then
				peds[#peds + 1] = ped
			end
		end
		if (mode == 'collect' or mode == 'zone') and not carry then
			return fail('invalid_carry')
		end
		local bins = {}
		if mode == 'zone' then
			for _, name in ipairs(type(r.binModels) == 'table' and r.binModels or {}) do
				if not model(name) then
					return fail('invalid_bins')
				end
				bins[#bins + 1] = name
			end
			if #bins == 0 or #bins > 64 then
				return fail('invalid_bins')
			end
		end
		job.route = {
			mode = mode, stops = stops, perRoute = perRoute, pay = pay,
			-- Valor extra por km entre a parada anterior (ou o embarque) e esta.
			payPerKm = int(r.payPerKm, 0, 100000) or 0,
			-- Distância do jogador até a parada (passageiro: do táxi até o ponto).
			stopRadius = num(r.stopRadius, 2, 30) or nil,
			stopProp = model(r.stopProp) and r.stopProp or nil,
			dropLabel = text(r.dropLabel, 40) and r.dropLabel or 'Guardar no veículo',
			bonus = int(r.bonus, 0, 1000000) or 0,
			xp = int(r.xp, 0, 10000) or 5,
			actionLabel = text(r.actionLabel, 40) and r.actionLabel or 'Entregar',
			pickupLabel = text(r.pickupLabel, 40) and r.pickupLabel or 'Pegar a carga',
			-- O veículo do emprego precisa estar a esta distância da parada (0 = não exige).
			vehicleRange = num(r.vehicleRange, 0, 500) or 40.0,
			carry = carry, carryAnimation = carryAnim,
			recipients = #peds > 0 and peds or { 'a_m_y_business_01', 'a_f_y_business_02', 'a_m_m_bevhills_01' }
		}
		if zones then
			local route = job.route
			route.zones = zones
			-- Sacos a recolher em cada zona antes de seguir para a próxima.
			route.perZone = int(r.perZone, 1, 50) or 5
			-- Objetos do mapa onde dá para recolher (lixeiras, caçambas, sacos) e o tempo até a mesma lixeira encher de novo.
			route.binModels = bins
			route.binCooldown = int(r.binCooldown, 0, 86400) or 600
			-- Porta da caçamba do veículo (traseira) que precisa estar aberta para guardar.
			route.rearDoor = int(r.rearDoor, 0, 7) or 5
			route.openLabel = text(r.openLabel, 40) and r.openLabel or 'Abrir a caçamba'
			route.closeLabel = text(r.closeLabel, 40) and r.closeLabel or 'Fechar a caçamba'
		end
	end
	return job
end

-- Nível (1..#levels) para um total de XP.
function JobRules.Level(levels, xp)
	local level = 1
	for index, threshold in ipairs(levels) do
		if (xp or 0) >= threshold then
			level = index
		end
	end
	return level
end

-- XP que falta para o próximo nível (nil no último).
function JobRules.NextLevelXp(levels, xp)
	local level = JobRules.Level(levels, xp)
	return levels[level + 1]
end

-- Valor com o bônus de nível: +levelBonus por nível acima do 1, arredondado para baixo.
function JobRules.Pay(base, level, levelBonus)
	local multiplier = 1 + math.max(0, (level or 1) - 1) * (levelBonus or 0)
	return math.floor(base * multiplier)
end

function JobRules.Distance(a, b)
	local dx, dy, dz = a.x - b.x, a.y - b.y, (a.z or 0) - (b.z or 0)
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Horizontal com tolerância de altura (pontos de config têm z aproximado).
function JobRules.Near(a, b, radius, height)
	local dx, dy = a.x - b.x, a.y - b.y
	return math.sqrt(dx * dx + dy * dy) <= radius and math.abs((a.z or 0) - (b.z or 0)) <= (height or 5.0)
end

-- Tempo mínimo plausível entre dois pontos (anti-teleporte) a uma velocidade máxima em m/s.
function JobRules.MinTravelSeconds(from, to, maxSpeed)
	return JobRules.Distance(from, to) / (maxSpeed or 60.0)
end

-- Sorteia `count` paradas distintas (índices) com o gerador `random(n)` (math.random por padrão).
function JobRules.PickStops(total, count, random)
	random = random or math.random
	local pool = {}
	for index = 1, total do
		pool[index] = index
	end
	for index = total, 2, -1 do
		local swap = random(index)
		pool[index], pool[swap] = pool[swap], pool[index]
	end
	local picked = {}
	for index = 1, math.min(count, total) do
		picked[index] = pool[index]
	end
	return picked
end

-- Chave de uma lixeira do mapa pela posição (arredondada a 1 m), para o cooldown entre recolhas.
function JobRules.BinKey(spot)
	return ('%d:%d:%d'):format(math.floor(spot.x + 0.5), math.floor(spot.y + 0.5), math.floor(spot.z + 0.5))
end

-- Paradas sorteadas por rota (passageiro usa duas por corrida).
function JobRules.RouteStops(route)
	return route.perRoute * (route.mode == 'passenger' and 2 or 1)
end

-- Valor base de uma parada: fixo + km percorridos desde o ponto anterior (embarque, parada ou centro).
function JobRules.StopPay(route, from, to)
	local km = (from and to) and JobRules.Distance(from, to) / 1000 or 0
	return route.pay + math.floor((route.payPerKm or 0) * km)
end

-- Parte pública da definição, enviada aos clients (sem nada que o servidor precise esconder).
function JobRules.Public(job)
	return {
		id = job.id, label = job.label, kind = job.kind, description = job.description,
		center = job.center, centerPed = job.centerPed, blip = job.blip, levels = job.levels, skills = job.skills, requires = job.requires,
		tool = job.tool, vehicle = job.vehicle and { model = job.vehicle.model, deposit = job.vehicle.deposit } or nil,
		gather = job.gather and {
			nodes = job.gather.nodes, nodeProp = job.gather.nodeProp, actionLabel = job.gather.actionLabel,
			seconds = job.gather.seconds, capacity = job.gather.capacity, unit = job.gather.unit, units = job.gather.units,
			animation = job.gather.animation,
			sell = { points = job.gather.sell.points, price = job.gather.sell.price, ped = job.gather.sell.ped, label = job.gather.sell.label }
		} or nil,
		route = job.route and {
			mode = job.route.mode, perRoute = job.route.perRoute, pay = job.route.pay, payPerKm = job.route.payPerKm,
			bonus = job.route.bonus, stopRadius = job.route.stopRadius, stopProp = job.route.stopProp, dropLabel = job.route.dropLabel,
			perZone = job.route.perZone, binModels = job.route.binModels, binCooldown = job.route.binCooldown,
			rearDoor = job.route.rearDoor, openLabel = job.route.openLabel, closeLabel = job.route.closeLabel,
			actionLabel = job.route.actionLabel, pickupLabel = job.route.pickupLabel,
			carry = job.route.carry, carryAnimation = job.route.carryAnimation, recipients = job.route.recipients
		} or nil
	}
end
