-- Fishing & Job Shop Activities
local JobsServer = JobsServer
local config = JobsServer.config
local jobs = JobsServer.jobs
local sessions = JobsServer.sessions
local records = JobsServer.records
local function characterOf(...) return JobsServer.characterOf(...) end
local function coordsOf(...) return JobsServer.coordsOf(...) end
local function throttled(...) return JobsServer.throttled(...) end
local function failure(...) return JobsServer.failure(...) end
local function sessionFor(...) return JobsServer.sessionFor(...) end
local function unitName(...) return JobsServer.unitName(...) end
local function grant(...) return JobsServer.grant(...) end
local function recordOf(...) return JobsServer.recordOf(...) end
local function profileOf(...) return JobsServer.profileOf(...) end
local function progressOf(...) return JobsServer.progressOf(...) end
local function modifiersOf(...) return JobsServer.modifiersOf(...) end
local function saveProfile(...) return JobsServer.saveProfile(...) end
local function reputationEvent(...) return JobsServer.reputationEvent(...) end
local function log(...) return JobsServer.log(...) end
local function notify(...) return JobsServer.notify(...) end
local function reply(...) return JobsServer.reply(...) end
local function money(...) return JobsServer.money(...) end
local function isReady() return JobsServer.isReady() end
local function startSession(...) return JobsServer.startSession(...) end
local function refreshCargo(...) return JobsServer.refreshCargo(...) end
local function goodsTotal(...) return JobsServer.goodsTotal(...) end
local function sessionView(...) return JobsServer.sessionView(...) end
local _t = (Core and Core.Locale and Core.Locale.Bind) and Core.Locale.Bind(Locales) or function(k) return (Locales and Locales["pt-BR"] and Locales["pt-BR"][k]) or k end


local function inventory(method, ...)
	local args = table.pack(...)
	local ok, a, b = pcall(function()
		return exports.coe_inventory[method](exports.coe_inventory, table.unpack(args, 1, args.n))
	end)
	if not ok then
		return nil, 'no_inventory'
	end
	return a, b
end

local function inventoryOf(playerId)
	local id = inventory('GetPlayerInventory', playerId)
	return type(id) == 'string' and id or nil
end

local function countOf(inventoryId, item)
	return tonumber((inventory('GetItemCount', inventoryId, item))) or 0
end

local function playerOfCharacter(characterId)
	for _, id in ipairs(GetPlayers()) do
		local playerId = tonumber(id)
		if playerId and characterOf(playerId) == tostring(characterId) then
			return playerId
		end
	end
	return nil
end

local function jobLevelOf(job, record)
	local progress = record.progress[job.id]
	return JobRules.Level(job.levels, progress and progress.xp or 0)
end

-- Loja do emprego --------------------------------------------------------------------------------------------

local function shopView(job, record, pointIndex)
	local level = jobLevelOf(job, record)
	local items = {}
	for _, entry in ipairs(job.shop.items) do
		items[#items + 1] = {
			item = entry.item, label = entry.label, description = entry.description, price = entry.price, level = entry.level,
			max = entry.max, kind = entry.kind, stats = entry.stats, locked = level < entry.level
		}
	end
	return { jobId = job.id, point = pointIndex, label = job.shop.label, job = job.label, level = level, maxLevel = #job.levels, items = items }
end

local function nearShop(playerId, job, pointIndex)
	local spot = job.shop and job.shop.points[math.tointeger(pointIndex) or -1]
	local coords = coordsOf(playerId)
	return spot and coords and JobRules.Near(coords, spot, config.PointRadius, config.PointHeight)
end

local function openShop(playerId, jobId, pointIndex)
	local job = jobs[jobId]
	local character = characterOf(playerId)
	if not job or not job.shop or not character then
		return failure(playerId, 'unknown_job')
	end
	if not nearShop(playerId, job, pointIndex) then
		return failure(playerId, 'too_far')
	end
	local record = recordOf(character)
	if not record then
		return failure(playerId, 'database_error')
	end
	reply(playerId, 'shop', shopView(job, record, pointIndex))
end

-- Cobra em dinheiro vivo (item `money`) se der; senão no banco (coe_economy). Devolve o meio ou nil.
local function charge(character, inventoryId, amount, jobId)
	if countOf(inventoryId, 'money') >= amount then
		local ok = inventory('RemoveItemByName', inventoryId, 'money', amount)
		if ok == true then
			return 'cash'
		end
	end
	if exports.coe_economy:Debit(character, amount, config.LedgerPrefix .. 'shop', jobId) then
		return 'bank'
	end
	return nil
end

local function refund(character, inventoryId, amount, method, jobId)
	if method == 'cash' then
		inventory('AddItem', inventoryId, 'money', amount)
	else
		exports.coe_economy:Credit(character, amount, config.LedgerPrefix .. 'shop', jobId)
	end
end

local function buy(playerId, jobId, pointIndex, itemName, quantity)
	local job = jobs[jobId]
	local character = characterOf(playerId)
	if not job or not job.shop or not character then
		return failure(playerId, 'unknown_job')
	end
	if not nearShop(playerId, job, pointIndex) then
		return failure(playerId, 'too_far')
	end
	local entry
	for _, candidate in ipairs(job.shop.items) do
		if candidate.item == itemName then
			entry = candidate
		end
	end
	local count = math.tointeger(tonumber(quantity))
	if not entry or not count or count < 1 or count > entry.max then
		return failure(playerId, 'wrong_step')
	end
	local record = recordOf(character)
	if not record then
		return failure(playerId, 'database_error')
	end
	if jobLevelOf(job, record) < entry.level then
		return failure(playerId, 'shop_locked', ('%s nível %d'):format(job.label:lower(), entry.level))
	end
	local inventoryId = inventoryOf(playerId)
	if not inventoryId then
		return failure(playerId, 'no_inventory')
	end
	local total = entry.price * count
	local method = charge(character, inventoryId, total, job.id)
	if not method then
		return failure(playerId, 'no_money')
	end
	local added = inventory('AddItem', inventoryId, entry.item, count)
	if added ~= true then
		refund(character, inventoryId, total, method, job.id)
		return failure(playerId, 'inventory_full')
	end
	log('info', 'gameplay', 'jobs_shop_bought', { character_id = character, target = job.id, item = entry.item, count = count, amount = total })
	notify(playerId, 'success', ('Comprou %dx %s por %s (%s).'):format(count, entry.label, money(total), method == 'cash' and 'dinheiro' or 'banco'))
	reply(playerId, 'shop', shopView(job, record, pointIndex))
end

-- Pesca livre ---------------------------------------------------------------------------------------------

local baitChoice = {}   -- characterId -> item da isca escolhida (usar a isca no inventário)

-- Emprego e tipo (vara/isca) de um item de pesca.
local function gearOf(itemName)
	for _, job in pairs(jobs) do
		local fishing = job.gather and job.gather.fishing
		if fishing then
			if fishing.rods[itemName] then
				return job, fishing.rods[itemName]
			elseif fishing.baits[itemName] then
				return job, fishing.baits[itemName]
			end
		end
	end
	return nil
end

-- Isca do lance: a escolhida (se ainda tiver e estiver liberada) ou a primeira da lista que tiver.
local function pickBait(job, character, inventoryId, level)
	local fishing = job.gather.fishing
	local chosen = baitChoice[character]
	if chosen and fishing.baits[chosen] and fishing.baits[chosen].level <= level and countOf(inventoryId, chosen) > 0 then
		return fishing.baits[chosen]
	end
	for _, id in ipairs(fishing.baitOrder) do
		local bait = fishing.baits[id]
		if bait.level <= level and countOf(inventoryId, id) > 0 then
			return bait
		end
	end
	return nil
end

local function gearUsed(playerId, job, gear)
	local character = characterOf(playerId)
	local record = character and recordOf(character)
	if not record then
		return failure(playerId, 'database_error')
	end
	if jobLevelOf(job, record) < gear.level then
		return failure(playerId, 'gear_locked', ('%s nível %d'):format(job.label:lower(), gear.level))
	end
	if gear.kind == 'bait' then
		baitChoice[character] = gear.item
		return notify(playerId, 'info', ('%s no anzol. Use a vara de frente para a água.'):format(gear.label))
	end
	-- Usar a vara pega (ou guarda) a vara na mão; o arremesso é no client e a área é conferida no lance.
	reply(playerId, 'fishUse', { jobId = job.id, rod = gear.item })
end

Core.Events.On('inventory.itemUsed', function(inventoryId, _slot, item)
	local characterId = type(inventoryId) == 'string' and inventoryId:match('^character:(.+)$')
	if not isReady() or not characterId or type(item) ~= 'table' or type(item.name) ~= 'string' then
		return
	end
	local job, gear = gearOf(item.name)
	local playerId = job and playerOfCharacter(characterId)
	if playerId then
		gearUsed(playerId, job, gear)
	end
end)

-- power (0-1): força do arremesso. Mais longe = água mais funda: mordida um pouco antes e mais chance de raros.
local function cast(playerId, jobId, rodName, power)
	local job = jobs[jobId]
	local fishing = job and job.gather and job.gather.fishing
	local character = characterOf(playerId)
	if not fishing or not character or type(rodName) ~= 'string' then
		return failure(playerId, 'not_working')
	end
	local coords = coordsOf(playerId)
	local areaIndex, zone = JobRules.FishingArea(fishing, coords or { x = 0, y = 0, z = -9999 })
	if not coords or not areaIndex then
		return failure(playerId, 'no_fishing_area')
	end
	local rod = fishing.rods[rodName]
	local record = recordOf(character)
	if not rod or not record then
		return failure(playerId, rod and 'database_error' or 'no_rod')
	end
	local level = jobLevelOf(job, record)
	if level < rod.level then
		return failure(playerId, 'gear_locked', ('%s nível %d'):format(job.label:lower(), rod.level))
	end
	local inventoryId = inventoryOf(playerId)
	if not inventoryId then
		return failure(playerId, 'no_inventory')
	end
	if countOf(inventoryId, rod.item) < 1 then
		return failure(playerId, 'no_rod')
	end
	-- Pesca livre: o trabalho começa no primeiro lance, onde o jogador estiver.
	local session = sessions[playerId]
	if session and session.jobId ~= jobId then
		return failure(playerId, 'already_working')
	end
	if not session then
		local opened, errorCode, detail = startSession(playerId, jobId, true)
		if not opened then
			return failure(playerId, errorCode, detail)
		end
		session = opened
		log('info', 'gameplay', 'jobs_started', { character_id = character, target = jobId })
		notify(playerId, 'success', ('%s: trabalho iniciado. Venda os peixes num comprador do mapa; para encerrar, fale com ele ou com a loja.'):format(job.label))
	end
	if session.cast then
		return failure(playerId, 'casting')
	end
	local mods = modifiersOf(job, record)
	if goodsTotal(session) >= mods.capacity then
		return failure(playerId, 'full')
	end
	local bait = pickBait(job, character, inventoryId, level)
	if not bait then
		return failure(playerId, 'no_bait')
	end
	-- Isca artificial pode sobrar (keep); as outras se gastam no lance, fisgando ou não.
	if math.random() >= bait.keep then
		if inventory('RemoveItemByName', inventoryId, bait.item, 1) ~= true then
			return failure(playerId, 'no_bait')
		end
	end
	power = math.max(0, math.min(1, tonumber(power) or 0))
	if power ~= power then
		power = 0
	end
	local species = JobRules.RollSpecies(zone, job.gather.products, rod.rarity + bait.rarity + power * 0.15)
	local item = job.gather.products[species]
	-- Espera pela mordida com os bônus da vara, da isca, do arremesso e de Campo (mesma proporção da coleta).
	local speed = rod.speed * bait.speed * (1 - power * 0.15) * (mods.seconds / job.gather.seconds)
	local biteMs = math.floor(math.random(fishing.biteSeconds[1] * 1000, fishing.biteSeconds[2] * 1000) * speed)
	local castMs = math.floor(fishing.castSeconds * 1000)
	local fight = JobRules.FightParams(fishing, rod, item)
	session.cast = { rod = rod.item, bait = bait.item, area = areaIndex, species = species, at = GetGameTimer(), bite = castMs + biteMs, fight = fight }
	session.lastTaskAt = GetGameTimer()
	reply(playerId, 'fishCast', {
		jobId = jobId, cast = castMs, bite = biteMs, fight = fight, tier = item.tier, bait = bait.label, area = zone.label
	})
	reply(playerId, 'session', sessionView(session))
end

local function reel(playerId, jobId, caught)
	local session, job = sessionFor(playerId, jobId, 'gather')
	local hook = session and session.cast
	if not hook then
		return failure(playerId, 'wrong_step')
	end
	session.cast = nil
	local elapsed = GetGameTimer() - hook.at
	local item = job.gather.products[hook.species]
	local fight = hook.fight
	if caught ~= true or elapsed > hook.bite + fight.hookMs + fight.maxMs + 3000 then
		notify(playerId, 'warning', _t('fish_escaped'))
		return reply(playerId, 'fishResult', { ok = false })
	end
	-- Fisgada válida só depois da mordida e de uma briga com o tempo mínimo (peixe sempre dentro da faixa).
	if elapsed < (hook.bite + fight.minMs) * 0.9 then
		log('warn', 'gameplay', 'jobs_too_fast', { player_id = playerId, target = job.id })
		reply(playerId, 'fishResult', { ok = false })
		return failure(playerId, 'too_fast')
	end
	local mods = modifiersOf(job, session.record)
	if goodsTotal(session) >= mods.capacity then
		reply(playerId, 'fishResult', { ok = false })
		return failure(playerId, 'full')
	end
	session.goods[item.id] = (session.goods[item.id] or 0) + 1
	refreshCargo(session)
	grant(playerId, session, item.xp, 0)
	local tier = item.tier == 'rare' and ' (raro!)' or item.tier == 'uncommon' and ' (incomum)' or ''
	notify(playerId, 'success', ('Fisgou: %s%s. %d/%d peixes.'):format(item.label, tier, goodsTotal(session), mods.capacity))
	reply(playerId, 'fishResult', { ok = true, species = item.id, label = item.label, tier = item.tier })
	reply(playerId, 'session', sessionView(session))
end

local function cancelCast(playerId, jobId)
	local session = sessionFor(playerId, jobId, 'gather')
	if session then
		session.cast = nil
	end
end



RegisterNetEvent('coe_jobs:shop', function(jobId, pointIndex)
	local playerId = source
	if isReady() and type(jobId) == 'string' and not throttled(playerId) then
		openShop(playerId, jobId, pointIndex)
	end
end)

RegisterNetEvent('coe_jobs:buy', function(jobId, pointIndex, itemName, quantity)
	local playerId = source
	if isReady() and type(jobId) == 'string' and type(itemName) == 'string' and not throttled(playerId) then
		buy(playerId, jobId, pointIndex, itemName, quantity)
	end
end)

RegisterNetEvent('coe_jobs:cast', function(jobId, rodName, power)
	local playerId = source
	if isReady() and type(jobId) == 'string' and not throttled(playerId) then
		cast(playerId, jobId, rodName, power)
	end
end)

-- O reel não passa pelo throttle: chega logo depois do minigame e o tempo já é conferido pelo lance.
RegisterNetEvent('coe_jobs:reel', function(jobId, caught)
	local playerId = source
	if isReady() and type(jobId) == 'string' then
		reel(playerId, jobId, caught)
	end
end)

RegisterNetEvent('coe_jobs:castCancel', function(jobId)
	local playerId = source
	if isReady() and type(jobId) == 'string' then
		cancelCast(playerId, jobId)
	end
end)