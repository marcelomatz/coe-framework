-- Regras puras do combustível (sem natives): catálogo, motor de cada veículo, tanque com mistura, consumo,
-- efeitos da mistura, preço e postos. Testáveis fora do jogo (test/rules_test.lua).
FuelRules = {}

local function isId(value, max)
	return type(value) == 'string' and #value >= 2 and #value <= (max or 32) and value:match('^[a-z][a-z0-9_]*$') ~= nil
end

local function num(value)
	local n = tonumber(value)
	return n and n == n and n ~= math.huge and n ~= -math.huge and n or nil
end

local function round2(value)
	return math.floor(value * 100 + 0.5) / 100
end

-- Valida o config. hash(modelName) -> número (GetHashKey no jogo). Devolve o catálogo ou nil + erro.
function FuelRules.Catalog(config, hash)
	local fuels = {}
	for _, id in ipairs(config.FuelOrder or {}) do
		local fuel = config.Fuels[id]
		if not isId(id) or type(fuel) ~= 'table' or not num(fuel.price) or fuel.price <= 0 or not num(fuel.consumption)
			or not num(fuel.power) or not num(fuel.wear) or (fuel.engine ~= 'flex' and fuel.engine ~= 'diesel') then
			return nil, 'invalid_fuel:' .. tostring(id)
		end
		fuels[id] = { id = id, label = fuel.label, short = fuel.short, price = fuel.price, consumption = fuel.consumption,
			power = fuel.power, wear = fuel.wear, engine = fuel.engine, color = fuel.color }
	end
	local stations, byId = {}, {}
	for index, station in ipairs(config.Stations or {}) do
		local c = type(station) == 'table' and station.center
		local x, y, z = c and num(c[1]), c and num(c[2]), c and num(c[3])
		if not isId(station and station.id, 24) or byId[station.id] or not config.Brands[station.brand or ''] or not x or not y or not z
			or type(station.label) ~= 'string' or (station.business ~= nil and not isId(station.business, 24)) then
			return nil, 'invalid_station:' .. tostring(index)
		end
		local entry = {
			id = station.id, label = station.label, brand = station.brand, x = x, y = y, z = z,
			radius = num(station.radius) or config.StationRadius, business = station.business or ('posto_' .. station.id)
		}
		if #entry.business > 24 then
			return nil, 'invalid_station:' .. tostring(index)
		end
		stations[#stations + 1] = entry
		byId[station.id] = entry
	end
	local diesel, flex = {}, {}
	if hash then
		for _, model in ipairs(config.DieselModels or {}) do
			diesel[hash(model)] = true
		end
		for _, model in ipairs(config.FlexModels or {}) do
			flex[hash(model)] = true
		end
	end
	return { fuels = fuels, stations = stations, byId = byId, dieselModels = diesel, flexModels = flex }
end

-- Motor do veículo: `flex` (gasolina e etanol), `diesel` ou `none` (não consome).
function FuelRules.Engine(config, catalog, classId, modelHash)
	classId = math.tointeger(tonumber(classId)) or -1
	if config.NoFuelClasses[classId] then
		return 'none'
	end
	if modelHash and catalog.flexModels[modelHash] then
		return 'flex'
	end
	if modelHash and catalog.dieselModels[modelHash] then
		return 'diesel'
	end
	if config.DieselClasses[classId] then
		return 'diesel'
	end
	return 'flex'
end

-- Tanque e consumo da classe.
function FuelRules.ClassSpec(config, classId)
	classId = math.tointeger(tonumber(classId)) or -1
	return config.Classes[classId] or config.DefaultClass
end

function FuelRules.Compatible(catalog, engine, fuelId)
	local fuel = catalog.fuels[fuelId or '']
	return fuel ~= nil and fuel.engine == engine
end

function FuelRules.Empty(config)
	local tank = {}
	for _, id in ipairs(config.FuelOrder) do
		tank[id] = 0
	end
	return tank
end

function FuelRules.Total(tank)
	local total = 0
	for _, liters in pairs(tank or {}) do
		total = total + (tonumber(liters) or 0)
	end
	return round2(total)
end

-- Cópia limpa (só combustíveis conhecidos, nunca negativos).
function FuelRules.Clean(config, tank)
	local out = FuelRules.Empty(config)
	for id in pairs(out) do
		local liters = type(tank) == 'table' and num(tank[id]) or 0
		out[id] = round2(math.max(0, liters or 0))
	end
	return out
end

-- Põe combustível (respeita o espaço). Devolve o tanque novo e quanto entrou.
function FuelRules.Add(config, tank, fuelId, liters, capacity)
	local out = FuelRules.Clean(config, tank)
	local space = math.max(0, capacity - FuelRules.Total(out))
	local added = round2(math.max(0, math.min(num(liters) or 0, space)))
	out[fuelId] = round2((out[fuelId] or 0) + added)
	return out, added
end

-- Gasta combustível na proporção da mistura. Devolve o tanque novo e quanto foi gasto.
function FuelRules.Consume(config, tank, liters)
	local out = FuelRules.Clean(config, tank)
	local total = FuelRules.Total(out)
	liters = math.max(0, num(liters) or 0)
	if total <= 0 or liters <= 0 then
		return out, 0
	end
	local used = math.min(total, liters)
	local factor = (total - used) / total
	for id, value in pairs(out) do
		out[id] = math.floor(value * factor * 10000 + 0.5) / 10000
	end
	return out, used
end

-- Efeitos da mistura (média ponderada pelos litros). Tanque vazio: neutro.
function FuelRules.Effects(config, catalog, tank)
	local total = FuelRules.Total(tank)
	local effects = { consumption = 1, power = 1, wear = 0, shares = {} }
	if total <= 0 then
		return effects
	end
	local consumption, power, wear = 0, 0, 0
	for _, id in ipairs(config.FuelOrder) do
		local share = (tonumber(tank[id]) or 0) / total
		local fuel = catalog.fuels[id]
		effects.shares[id] = share
		consumption = consumption + share * fuel.consumption
		power = power + share * fuel.power
		wear = wear + share * fuel.wear
	end
	effects.consumption = math.floor(consumption * 1000 + 0.5) / 1000
	effects.power = math.floor(power * 1000 + 0.5) / 1000
	effects.wear = math.floor(wear * 1000 + 0.5) / 1000
	return effects
end

-- Chave estável dos efeitos (passos de 1%): só republica o handling quando muda.
function FuelRules.EffectsKey(effects)
	return ('p%d'):format(math.floor((effects.power - 1) * 100 + 0.5))
end

-- Litros gastos num trecho. load = média de rotação (0..1). seconds = tempo com o motor ligado.
function FuelRules.Usage(config, spec, effects, meters, seconds, load)
	meters = math.max(0, num(meters) or 0)
	seconds = math.max(0, num(seconds) or 0)
	load = math.max(0, math.min(1, num(load) or 0))
	local moving = spec.per100 * config.ConsumptionScale * meters / 100000 * (0.6 + 0.8 * load)
	local idle = config.IdlePerHour * seconds / 3600
	return (moving + idle) * (effects and effects.consumption or 1)
end

-- Relatório do motorista dentro dos limites (tempo e velocidade). Devolve metros e segundos aceitos.
function FuelRules.ClampReport(config, meters, seconds)
	seconds = math.max(0, math.min(config.MaxReportSeconds, num(seconds) or 0))
	meters = math.max(0, math.min(seconds * config.MaxSpeed, num(meters) or 0))
	return meters, seconds
end

-- Litros pedidos na bomba: 0,1 L de precisão, mínimo 0,5 L.
function FuelRules.CleanLiters(value, max)
	local liters = num(value)
	if not liters then
		return nil
	end
	liters = math.floor(liters * 10) / 10
	if liters < 0.5 or liters > max then
		return nil
	end
	return liters
end

function FuelRules.Price(price, liters)
	return math.ceil(price * liters - 1e-9)
end

-- Posto que contém o ponto (o mais perto, dentro do raio).
function FuelRules.StationAt(catalog, x, y, z)
	local best, bestDistance = nil, math.huge
	for _, station in ipairs(catalog.stations) do
		local dx, dy, dz = x - station.x, y - station.y, (z or station.z) - station.z
		local distance = math.sqrt(dx * dx + dy * dy)
		if distance <= station.radius and math.abs(dz) < 20 and distance < bestDistance then
			best, bestDistance = station, distance
		end
	end
	return best
end

function FuelRules.Mode(business)
	return type(business) == 'table' and business.owner and business.owner.characterId and 'player' or 'staff'
end

-- Negócio criado na primeira vez para o posto (sem dono = da staff).
function FuelRules.BusinessSeed(station)
	return {
		id = station.business, category = 'gas_station', label = 'Posto ' .. station.label, enabled = true,
		area = { kind = 'circle', x = station.x, y = station.y, z = station.z, radius = station.radius },
		stations = { clocks = { { id = 'ponto', label = 'Ponto', x = station.x, y = station.y, z = station.z, radius = 3.0 } } }
	}
end

-- Desgaste extra das peças por metro rodado (positivo com a comum, negativo com a aditivada).
function FuelRules.WearMeters(effects, meters)
	return (effects and effects.wear or 0) * math.max(0, meters or 0)
end

-- Resumo para o state bag do veículo.
function FuelRules.Summary(config, catalog, tank, capacity, engine)
	local total = FuelRules.Total(tank)
	local main, mainLiters = nil, 0
	for _, id in ipairs(config.FuelOrder) do
		if (tank[id] or 0) > mainLiters then
			main, mainLiters = id, tank[id]
		end
	end
	return {
		liters = total, capacity = capacity, level = capacity > 0 and math.min(1, total / capacity) or 0,
		engine = engine, main = main, tank = FuelRules.Clean(config, tank)
	}
end

-- Postos de jogador: preço, tanques, frota e refinaria -----------------------------------------------------------

-- Preço por litro que o dono pode definir (inteiro, dentro da faixa do preço de tabela). nil se inválido.
function FuelRules.PriceBounds(config, base)
	return math.max(1, math.floor(base * config.PriceBand.Min + 0.5)), math.floor(base * config.PriceBand.Max + 0.5)
end

function FuelRules.ValidPrice(config, base, price)
	local value = tonumber(price)
	if not value or value ~= value or math.floor(value) ~= value then
		return nil
	end
	local low, high = FuelRules.PriceBounds(config, base)
	return value >= low and value <= high and math.tointeger(value) or nil
end

-- Nível do tanque (1..#TankLevels) e a capacidade dele.
function FuelRules.TankLevel(config, level)
	level = math.tointeger(tonumber(level)) or 1
	return math.max(1, math.min(#config.TankLevels, level))
end

function FuelRules.TankCapacity(config, level)
	return config.TankLevels[FuelRules.TankLevel(config, level)].capacity
end

-- Upgrade possível com o caixa e os litros vendidos? Devolve o próximo nível ou nil + erro.
local function nextStep(list, current, balance, sold)
	local spec = list[current + 1]
	if not spec then
		return nil, 'max_level'
	end
	if (tonumber(sold) or 0) < spec.sold then
		return nil, 'not_enough_sales', spec
	end
	if (tonumber(balance) or 0) < spec.price then
		return nil, 'insufficient_funds', spec
	end
	return spec
end

function FuelRules.NextTank(config, level, balance, sold)
	return nextStep(config.TankLevels, FuelRules.TankLevel(config, level), balance, sold)
end

-- Frota: nível atual = maior nível comprado (0 = nenhum). Compra sempre o próximo.
function FuelRules.NextFleet(config, tier, balance, sold)
	tier = math.max(0, math.min(#config.FleetTiers, math.tointeger(tonumber(tier)) or 0))
	return nextStep(config.FleetTiers, tier, balance, sold)
end

function FuelRules.FleetTier(config, tier)
	return config.FleetTiers[math.tointeger(tonumber(tier)) or 0]
end

-- Carga pedida na refinaria: { [combustível] = litros inteiros }. Devolve { liters, add, cost } ou nil + erro.
-- Respeita a capacidade do veículo somando o que já está carregado.
function FuelRules.LoadOrder(config, cargo, capacity, request)
	if type(request) ~= 'table' then
		return nil, 'invalid_load'
	end
	local add, liters, cost = {}, 0, 0
	for _, id in ipairs(config.FuelOrder) do
		local value = request[id]
		if value ~= nil then
			local amount = tonumber(value)
			if not amount or amount ~= amount or amount < 0 or math.floor(amount) ~= amount or amount > 100000 then
				return nil, 'invalid_load'
			end
			if amount > 0 then
				add[id] = math.tointeger(amount)
				liters = liters + amount
				cost = cost + amount * config.Refinery.prices[id]
			end
		end
	end
	if liters <= 0 then
		return nil, 'empty_load'
	end
	if FuelRules.Total(cargo) + liters > capacity + 1e-6 then
		return nil, 'over_capacity'
	end
	return { add = add, liters = math.tointeger(liters), cost = math.ceil(cost - 1e-9) }
end

-- Descarga no posto: passa o que couber em cada tanque. tanks/capacities: { [combustível] = litros }.
-- Devolve carga e tanques novos e o que passou ({ [combustível] = litros }, total).
function FuelRules.Unload(config, cargo, tanks, capacities)
	local newCargo, newTanks, moved, total = FuelRules.Clean(config, cargo), {}, {}, 0
	for _, id in ipairs(config.FuelOrder) do
		local inTank = tonumber(tanks[id]) or 0
		local space = math.max(0, (capacities[id] or 0) - inTank)
		local amount = math.floor(math.min(newCargo[id], space) * 100) / 100
		newTanks[id] = inTank + amount
		if amount > 0 then
			newCargo[id] = math.floor((newCargo[id] - amount) * 100 + 0.5) / 100
			moved[id] = amount
			total = total + amount
		end
	end
	return newCargo, newTanks, moved, math.floor(total * 100 + 0.5) / 100
end

-- Orquestrador Saga (cobrança -> entrega com estorno compensatório determinístico)
function FuelRules.ExecuteSaga(steps, context)
	local alg = (type(Core) == 'table' and Core.Algorithms) or CoeAlgorithms
	local Concurrency = (type(alg) == 'table' and alg.Concurrency) or nil
	if Concurrency and Concurrency.executeSaga then
		return Concurrency.executeSaga(steps, context)
	end
	local completed = {}
	for i = 1, #steps do
		local step = steps[i]
		local ok, resultOrErr, errCode = pcall(step.action, context)
		if not ok or resultOrErr == false then
			local reason = tostring((not ok and resultOrErr) or errCode or 'step_failed')
			for j = #completed, 1, -1 do
				local compStep = completed[j]
				if compStep.compensate then
					pcall(compStep.compensate, context, compStep.output)
				end
			end
			return false, step.name or ('step_' .. i), reason
		end
		completed[#completed + 1] = { name = step.name, compensate = step.compensate, output = resultOrErr }
	end
	return true, nil, nil
end

-- Rate Limiter GCRA O(1) para chamadas de postos e relatórios
function FuelRules.NewCallLimiter(cooldownMs)
	local alg = (type(Core) == 'table' and Core.Algorithms) or CoeAlgorithms
	local RateLimit = (type(alg) == 'table' and alg.RateLimit) or nil
	if RateLimit and RateLimit.newGCRA then
		return RateLimit.newGCRA(cooldownMs or 300, 0)
	end
	local lastSeen = {}
	return {
		allow = function(_, key, nowMs)
			local prev = lastSeen[key]
			if prev and (nowMs - prev) < (cooldownMs or 300) then
				return false, (cooldownMs or 300) - (nowMs - prev)
			end
			lastSeen[key] = nowMs
			return true, 0
		end,
		forget = function(_, key)
			lastSeen[key] = nil
		end
	}
end
