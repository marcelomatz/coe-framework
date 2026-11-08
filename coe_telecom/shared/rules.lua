TelecomRules = {}

local function resolveAlgorithms()
	if type(Core) == 'table' and type(Core.Algorithms) == 'table' then
		return Core.Algorithms
	end
	if type(CoeAlgorithms) == 'table' then
		return CoeAlgorithms
	end
	if type(LoadResourceFile) == 'function' and type(load) == 'function' then
		local src = LoadResourceFile('coe_core', 'lib/algorithms/init.lua')
		if type(src) == 'string' and src ~= '' then
			local fn = load(src, '@@coe_core/lib/algorithms/init.lua', 't', _G)
			if fn then
				local ok, mod = pcall(fn)
				if ok and type(mod) == 'table' then
					return mod
				end
			end
		end
		return CoeAlgorithms
	end
	if type(loadfile) == 'function' then
		local candidates = {
			'../coe_core/lib/algorithms/init.lua',
			'coe-framework/coe_core/lib/algorithms/init.lua',
			'dev/coe_core/lib/algorithms/init.lua',
		}
		for i = 1, #candidates do
			local chunk = loadfile(candidates[i])
			if chunk then
				local ok, mod = pcall(chunk)
				if ok and type(mod) == 'table' then
					return mod
				end
			end
		end
	end
	return nil
end

local Algorithms = resolveAlgorithms()
local Containers = Algorithms and Algorithms.Containers or nil
local Concurrency = Algorithms and Algorithms.Concurrency or nil

function TelecomRules.NewTimingWheel(tickResolutionMs)
	if Containers and type(Containers.newTimingWheel) == 'function' then
		return Containers.newTimingWheel(tickResolutionMs or 1000)
	end
	return nil
end

function TelecomRules.ExecuteSaga(steps)
	if Concurrency and type(Concurrency.executeSaga) == 'function' then
		return Concurrency.executeSaga(steps)
	end
	return false, nil, 'saga_unavailable'
end

local DAY = 86400
local KINDS = { voice = 'minute', video = 'minute', sms = 'unit', data = 'megabyte' }
local BAND_RANK = { NONE = 0, ['3G'] = 1, ['4G'] = 2, ['5G'] = 3, SAT = 4, WIFI6 = 5 }

function TelecomRules.NewTowerGrid(cellSize)
	local alg = Algorithms or resolveAlgorithms()
	if alg and alg.Spatial and alg.Spatial.newGrid then
		return alg.Spatial.newGrid(cellSize or 256.0)
	end
	return nil
end

function TelecomRules.IsKind(kind)
	return type(kind) == 'string' and KINDS[kind] ~= nil
end

function TelecomRules.Plan(config, id)
	local plan = type(id) == 'string' and config.Plans[id] or nil
	return plan
end

function TelecomRules.IsPostpaid(config, id)
	local plan = TelecomRules.Plan(config, id)
	return plan ~= nil and plan.kind == 'postpaid'
end

-- Minutos cobrados: cada minuto iniciado conta, depois da tolerância.
function TelecomRules.Minutes(config, seconds)
	local value = math.floor(tonumber(seconds) or 0) - (config.GraceSeconds or 0)
	if value <= 0 then
		return 0
	end
	return math.ceil(value / 60)
end

-- Preço de uma unidade (minuto ou mensagem); nil quando o plano é ilimitado nesse tipo.
local function rate(plan, kind)
	return plan.rates and plan.rates[kind] or nil
end

-- Pode usar a linha? Retorna true, maxSeconds (nil = sem limite) ou nil, código.
function TelecomRules.Authorize(config, line, kind)
	if not TelecomRules.IsKind(kind) then
		return nil, 'invalid_kind'
	end
	local plan = TelecomRules.Plan(config, line.plan)
	if not plan then
		return nil, 'unknown_plan'
	end
	if line.status ~= 'active' then
		return nil, 'line_suspended'
	end
	if plan.kind ~= 'prepaid' then
		return true, nil
	end
	local price = rate(plan, kind) or 0
	if price <= 0 then
		return true, nil
	end
	local balance = math.max(0, math.floor(tonumber(line.balance) or 0))
	if balance < price then
		return nil, 'no_credit'
	end
	if KINDS[kind] == 'unit' or KINDS[kind] == 'megabyte' then
		return true, nil
	end
	-- Minutos que o crédito paga, mais a tolerância (que não é cobrada).
	return true, math.floor(balance / price) * 60 + (config.GraceSeconds or 0)
end

-- O que um uso custa agora. Retorna { cost, units, field } onde:
-- cost  = valor a descontar do crédito (só pré-pago),
-- units = minutos (ou mensagens / megabytes) usados,
-- field = 'voice_used'/'video_used'/'data_used' quando o uso soma na franquia do pós-pago.
function TelecomRules.Charge(config, line, kind, amountOrSeconds, isFreeWifi)
	local plan = TelecomRules.Plan(config, line.plan)
	if not plan or not TelecomRules.IsKind(kind) then
		return { cost = 0, units = 0 }
	end
	if kind == 'data' and isFreeWifi == true then
		return { cost = 0, units = 0 }
	end
	local units
	if KINDS[kind] == 'unit' then
		units = 1
	elseif KINDS[kind] == 'megabyte' then
		units = math.max(0, math.ceil(tonumber(amountOrSeconds) or 0))
	else
		units = TelecomRules.Minutes(config, amountOrSeconds)
	end
	if units == 0 then
		return { cost = 0, units = 0 }
	end
	if plan.kind == 'prepaid' then
		local price = rate(plan, kind) or 0
		local balance = math.max(0, math.floor(tonumber(line.balance) or 0))
		return { cost = math.min(balance, units * price), units = units }
	end
	if kind == 'sms' then
		return { cost = 0, units = units }
	end
	return { cost = 0, units = units, field = kind .. '_used' }
end

function TelecomRules.CycleSeconds(config)
	return config.CycleDays * DAY
end

function TelecomRules.CycleEnd(config, line)
	return (tonumber(line.cycleStart) or 0) + TelecomRules.CycleSeconds(config)
end

function TelecomRules.CycleDue(config, line, now)
	return TelecomRules.IsPostpaid(config, line.plan) and now >= TelecomRules.CycleEnd(config, line)
end

-- Fatura do ciclo do pós-pago. prorate: cobra a mensalidade proporcional ao tempo usado (troca de plano).
-- Retorna { amount, base, extra, voice, video } (voice/video = minutos excedentes).
function TelecomRules.Invoice(config, line, now, prorate)
	local plan = TelecomRules.Plan(config, line.plan)
	if not plan or plan.kind ~= 'postpaid' then
		return { amount = 0, base = 0, extra = 0, voice = 0, video = 0 }
	end
	local monthly = plan.monthly or 0
	local base = monthly
	if prorate then
		local elapsed = math.max(0, now - (tonumber(line.cycleStart) or now))
		local fraction = math.min(1, elapsed / TelecomRules.CycleSeconds(config))
		base = math.ceil(monthly * fraction)
	end
	local allowance = plan.allowance or {}
	local voice, video, extra = 0, 0, 0
	if plan.rates then
		voice = math.max(0, (tonumber(line.voiceUsed) or 0) - (allowance.voice or 0))
		video = math.max(0, (tonumber(line.videoUsed) or 0) - (allowance.video or 0))
		extra = voice * (plan.rates.voice or 0) + video * (plan.rates.video or 0)
	end
	return { amount = base + extra, base = base, extra = extra, voice = voice, video = video }
end

function TelecomRules.DueAt(config, now)
	return now + config.GraceDays * DAY
end

function TelecomRules.Recharge(config, line, amount)
	local plan = TelecomRules.Plan(config, line.plan)
	if not plan or plan.kind ~= 'prepaid' then
		return nil, 'not_prepaid'
	end
	local valid = false
	for _, value in ipairs(config.Recharges) do
		if value == amount then
			valid = true
			break
		end
	end
	if not valid then
		return nil, 'invalid_amount'
	end
	if (tonumber(line.balance) or 0) + amount > config.MaxBalance then
		return nil, 'balance_full'
	end
	return amount
end

-- Troca de plano. openInvoices: quantas faturas em aberto a linha tem.
function TelecomRules.ChangePlan(config, line, target, openInvoices, now)
	local plan = TelecomRules.Plan(config, target)
	if not plan then
		return nil, 'unknown_plan'
	end
	if target == line.plan then
		return nil, 'same_plan'
	end
	local changedAt = tonumber(line.planChangedAt) or 0
	if changedAt > 0 and now - changedAt < config.PlanChangeHours * 3600 then
		return nil, 'plan_cooldown'
	end
	-- Pós-pago é fatura no nome de alguém: linha sem titular (chip anônimo) fica no pré.
	if plan.kind == 'postpaid' and line.holder == nil then
		return nil, 'holder_required'
	end
	if plan.kind == 'postpaid' and (line.status ~= 'active' or (openInvoices or 0) > 0) then
		return nil, 'open_invoice'
	end
	return plan
end

-- Planos para a tela do app, na ordem do config.
function TelecomRules.PlanList(config)
	local list = {}
	for id, plan in pairs(config.Plans) do
		list[#list + 1] = {
			id = id, label = plan.label, kind = plan.kind, order = plan.order or 99, description = plan.description,
			monthly = plan.monthly or 0, allowance = plan.allowance, rates = plan.rates
		}
	end
	table.sort(list, function(a, b)
		if a.order ~= b.order then
			return a.order < b.order
		end
		return a.id < b.id
	end)
	return list
end

-- 4.1 / 4.2 / 4.3: Avaliação de Cobertura (5G, 4G, 3G, Zonas de Sombra, Fibra Wi-Fi 6 e Satélite OrbitLink)
function TelecomRules.EvaluateSignal(config, coords, towerStates, context)
	context = type(context) == 'table' and context or {}
	if context.wifiActive == true then
		return { band = 'WIFI6', bars = 4, speedMbps = 1000, freeData = true }
	end
	if context.orbitlinkBubble == true or context.carrier == 'orbitlink' then
		local storm = context.weather == 'THUNDER' or context.weather == 'RAIN'
		return {
			band = 'SAT',
			bars = storm and 3 or 4,
			speedMbps = storm and 85 or 250,
			freeData = context.orbitlinkBubble == true
		}
	end
	if type(coords) ~= 'table' and type(coords) ~= 'vector3' then
		return { band = 'NONE', bars = 0, speedMbps = 0, freeData = false }
	end
	local x, y, z = tonumber(coords.x) or 0.0, tonumber(coords.y) or 0.0, tonumber(coords.z) or 0.0

	-- Verifica Zonas de Sombra (DeadZones)
	for _, dz in ipairs((config and config.DeadZones) or {}) do
		local dx, dy, dzZ = x - dz.x, y - dz.y, z - dz.z
		if (dx * dx + dy * dy + dzZ * dzZ) <= (dz.radius * dz.radius) then
			return { band = 'NONE', bars = 0, speedMbps = 0, freeData = false, deadZone = dz.id }
		end
	end

	local bestTower = nil
	local bestRank = 0
	for _, tower in ipairs((config and config.Towers) or {}) do
		local st = towerStates and towerStates[tower.id]
		local sabotaged = type(st) == 'table' and st.sabotaged == true
		if not sabotaged then
			local dx, dy = x - tower.x, y - tower.y
			local dist = math.sqrt(dx * dx + dy * dy)
			if dist <= tower.radius then
				local r = BAND_RANK[tower.band] or 0
				if r > bestRank then
					bestRank = r
					bestTower = tower
				end
			end
		end
	end

	if not bestTower then
		return { band = 'NONE', bars = 0, speedMbps = 0, freeData = false }
	end

	local bars = bestTower.band == '5G' and 4 or (bestTower.band == '4G' and 3 or 2)
	return {
		band = bestTower.band,
		bars = bars,
		speedMbps = bestTower.speedMbps or 50,
		freeData = false,
		towerId = bestTower.id
	}
end

-- Verifica se a banda atual suporta o aplicativo requisitado (ex.: DeepWeb e streaming exigem >= 4G/WIFI6/SAT)
function TelecomRules.CanAccessBandFeature(band, feature)
	local rank = BAND_RANK[tostring(band or 'NONE')] or 0
	if rank <= 0 then
		return false, 'no_signal'
	end
	if (feature == 'deepweb' or feature == 'hd_stream' or feature == 'crypto_hft') and rank < BAND_RANK['4G'] then
		return false, 'band_too_slow'
	end
	return true, nil
end

