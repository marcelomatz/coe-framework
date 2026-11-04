-- coe_jobs (client): runtime genérico dos empregos registrados pelos pacotes. Mostra centros, pontos e paradas,
-- anima as ações e pede ao servidor; nenhum pagamento sai daqui. Sem loops por quadro: tudo em intervalos.
local config = JobsConfig

local catalog = {}      -- id -> definição pública
local centerBlips = {}
local centerPeds = {}   -- id -> ped
local session = nil     -- visão do servidor
local work = {
	props = {}, peds = {}, blips = {}, routeBlip = nil, zoneBlip = nil, binModels = nil, carrying = nil, busy = false,
	vehicleTarget = nil, passenger = nil, asked = 0, worldModels = nil, ground = {}, groundKey = nil, areaBlips = {},
	offSoil = {}, soilOff = {}
}
local felled = {}       -- chave -> { x, y, z, model, until } (árvores escondidas para todos)
local racks = {}        -- veículo -> props desenhados na caçamba (state bag coe:jobLoad)
local wearing = nil     -- roupa guardada enquanto o uniforme está vestido
local shopPeds = {}     -- "<emprego>:<índice>" -> vendedor da loja do emprego
local fishingState = nil -- lance de pesca em andamento (visão do servidor)
local nuiOpen = nil     -- 'guide' | 'shop' (tela com foco do mouse)
local cancelFishing, putAwayRod -- definidas na seção da pesca (usadas antes, no fim do trabalho)

local function show(kind, message)
	pcall(function() exports.coe_notify:Show(kind, message, 4000) end)
end

local _t = (Core and Core.Locale and Core.Locale.Bind) and Core.Locale.Bind(Locales) or function(k) return (Locales and Locales['pt-BR'] and Locales['pt-BR'][k]) or k end

local function loadModel(name)
	-- Lista de candidatos: o primeiro modelo que existir nesta versão do jogo.
	if type(name) == 'table' then
		for _, candidate in ipairs(name) do
			local found = loadModel(candidate)
			if found then
				return found
			end
		end
		return nil
	end
	if type(name) ~= 'string' then
		return nil
	end
	local hash = joaat(name)
	if not IsModelInCdimage(hash) then
		return nil
	end
	RequestModel(hash)
	local deadline = GetGameTimer() + 5000
	while not HasModelLoaded(hash) and GetGameTimer() < deadline do
		Wait(25)
	end
	return HasModelLoaded(hash) and hash or nil
end

local function loadDict(dict)
	RequestAnimDict(dict)
	local deadline = GetGameTimer() + 3000
	while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do
		Wait(25)
	end
	return HasAnimDictLoaded(dict)
end

local function target(entity, options)
	pcall(function() exports.coetarget:AddTargetEntity(entity, options) end)
end

local function untarget(entity)
	pcall(function() exports.coetarget:RemoveTargetEntity(entity) end)
end

local function deleteEntity(entity)
	if entity and Core.Platform.Entities.Exists(entity) then
		untarget(entity)
		Core.Platform.Entities.Delete(entity)
	end
end

local function spawnPed(model, spot, scenario)
	local hash = loadModel(model) or loadModel('s_m_m_gentransport')
	if not hash then
		return nil
	end
	local ped = CreatePed(4, hash, spot.x, spot.y, spot.z - 1.0, spot.h or 0.0, false, false)
	SetModelAsNoLongerNeeded(hash)
	if not ped or ped == 0 then
		return nil
	end
	SetEntityInvincible(ped, true)
	SetBlockingOfNonTemporaryEvents(ped, true)
	SetPedCanRagdoll(ped, false)
	FreezeEntityPosition(ped, true)
	TaskStartScenarioInPlace(ped, scenario or 'WORLD_HUMAN_CLIPBOARD', 0, true)
	return ped
end

-- Chão de verdade sob o ponto (o z do config é aproximado): sonda de cima para baixo e devolve z e material.
local function probeGround(spot)
	local handle = StartExpensiveSynchronousShapeTestLosProbe(spot.x, spot.y, spot.z + 25.0, spot.x, spot.y, spot.z - 25.0, 1, 0, 7)
	local _, hit, endCoords, _, material = GetShapeTestResultIncludingMaterial(handle)
	if hit == 1 or hit == true then
		return endCoords.z, material
	end
	local found, groundZ = GetGroundZFor_3dCoord(spot.x, spot.y, spot.z + 25.0, false)
	return found and groundZ or nil, nil
end

-- Materiais de chão de plantio (terra, lama, argila): pontos fora deles não ganham prop.
local soilHashes = nil
local function isSoil(material)
	if not soilHashes then
		soilHashes = {}
		for _, name in ipairs(config.SoilMaterials or {}) do
			soilHashes[joaat(name)] = true
		end
	end
	return material == nil or material == 0 or soilHashes[material] == true
end

local function spawnProp(model, spot, ground)
	local hash = loadModel(model) or loadModel('prop_cs_cardbox_01')
	if not hash then
		return nil
	end
	local groundZ = ground or probeGround(spot)
	local object = CreateObject(hash, spot.x, spot.y, groundZ or spot.z, false, false, false)
	SetModelAsNoLongerNeeded(hash)
	if not object or object == 0 then
		return nil
	end
	Core.Platform.Entities.SetHeading(object, spot.h or 0.0)
	PlaceObjectOnGroundProperly(object)
	FreezeEntityPosition(object, true)
	SetEntityInvincible(object, true)
	return object
end

local function attachProp(spec)
	if not spec then
		return nil
	end
	-- Modelo principal ou o reserva (`fallback`), se o principal não existir nesta versão do jogo.
	local hash = loadModel(spec.model) or (spec.fallback and loadModel(spec.fallback))
	if not hash then
		return nil
	end
	local ped = PlayerPedId()
	local coords = Core.Platform.Entities.GetCoords(ped)
	local object = CreateObject(hash, coords.x, coords.y, coords.z + 0.2, true, true, false)
	SetModelAsNoLongerNeeded(hash)
	AttachEntityToEntity(object, ped, GetPedBoneIndex(ped, spec.bone), spec.offset[1], spec.offset[2], spec.offset[3],
		spec.rotation[1], spec.rotation[2], spec.rotation[3], true, true, false, true, 1, true)
	return object
end

local function playAnimation(animation)
	local ped = PlayerPedId()
	if not animation then
		return
	end
	if animation.scenario then
		TaskStartScenarioInPlace(ped, animation.scenario, 0, true)
	elseif loadDict(animation.dict) then
		TaskPlayAnim(ped, animation.dict, animation.name, 4.0, -4.0, -1, animation.flag or 1, 0.0, false, false, false)
	end
end

local function stopAnimation(animation)
	local ped = PlayerPedId()
	if animation and animation.dict then
		StopAnimTask(ped, animation.dict, animation.name, 2.0)
	else
		ClearPedTasks(ped)
	end
end

-- Animação curta (pegar, jogar): toca uma vez e espera `ms`, sem prender o jogador.
local function playOnce(animation)
	if not animation or not loadDict(animation.dict) then
		return
	end
	local ped = PlayerPedId()
	TaskPlayAnim(ped, animation.dict, animation.name, 8.0, -8.0, animation.ms, animation.flag or 48, 0.0, false, false, false)
	Wait(animation.ms)
	StopAnimTask(ped, animation.dict, animation.name, 2.0)
end

-- Controle de rede do veículo antes de mexer em porta (o caminhão nasce no servidor e pode ser de outro client).
local function control(entity)
	if NetworkHasControlOfEntity(entity) then
		return true
	end
	NetworkRequestControlOfEntity(entity)
	local deadline = GetGameTimer() + 1500
	while not NetworkHasControlOfEntity(entity) and GetGameTimer() < deadline do
		Wait(50)
		NetworkRequestControlOfEntity(entity)
	end
	return NetworkHasControlOfEntity(entity)
end

-- Ação com duração: animação + ferramenta; cancela se o jogador se afastar, entrar em veículo ou morrer.
local function timedAction(seconds, animation, tool, face)
	local ped = PlayerPedId()
	if face then
		TaskTurnPedToFaceCoord(ped, face.x, face.y, face.z, 600)
		Wait(600)
	end
	local origin = Core.Platform.Entities.GetCoords(ped)
	local held = attachProp(tool)
	playAnimation(animation)
	local deadline = GetGameTimer() + math.floor(seconds * 1000)
	local ok = true
	while GetGameTimer() < deadline do
		Wait(100)
		ped = PlayerPedId()
		if #(Core.Platform.Entities.GetCoords(ped) - origin) > 1.5 or IsPedInAnyVehicle(ped, true) or IsPedDeadOrDying(ped, true) then
			ok = false
			break
		end
	end
	stopAnimation(animation)
	deleteEntity(held)
	return ok
end

-- Uniforme (opcional, só visual) -------------------------------------------------------------------------

-- Roupa do uniforme para o modelo do ped (freemode masculino ou feminino); nil se o emprego não tiver.
local function outfitFor(job)
	local uniform = job and job.uniform
	if not uniform then
		return nil
	end
	local model = Core.Platform.Entities.GetModel(PlayerPedId())
	if model == joaat('mp_m_freemode_01') then
		return uniform.male
	elseif model == joaat('mp_f_freemode_01') then
		return uniform.female
	end
	return nil
end

local function wearUniform(job)
	local outfit = outfitFor(job)
	if not outfit then
		show('warning', _t('uniform_unavailable'))
		return
	end
	local ped = PlayerPedId()
	if not wearing then
		-- Guarda a roupa atual inteira para devolver igual ao tirar.
		wearing = { components = {}, props = {} }
		for slot = 0, 11 do
			wearing.components[#wearing.components + 1] = { slot, GetPedDrawableVariation(ped, slot), GetPedTextureVariation(ped, slot), GetPedPaletteVariation(ped, slot) }
		end
		for slot = 0, 9 do
			wearing.props[#wearing.props + 1] = { slot, GetPedPropIndex(ped, slot), GetPedPropTextureIndex(ped, slot) }
		end
	end
	for _, part in ipairs(outfit.components) do
		SetPedComponentVariation(ped, part[1], part[2], part[3], 0)
	end
	for _, part in ipairs(outfit.props) do
		if part[2] < 0 then
			ClearPedProp(ped, part[1])
		else
			SetPedPropIndex(ped, part[1], part[2], part[3], true)
		end
	end
	wearing.jobId = job.id
	show('success', _t('uniform_on', { label = job.uniform.label }))
end

local function removeUniform(silent)
	if not wearing then
		return
	end
	local ped = PlayerPedId()
	for _, part in ipairs(wearing.components) do
		SetPedComponentVariation(ped, part[1], part[2], part[3], part[4] or 0)
	end
	for _, part in ipairs(wearing.props) do
		if part[2] < 0 then
			ClearPedProp(ped, part[1])
		else
			SetPedPropIndex(ped, part[1], part[2], part[3], true)
		end
	end
	wearing = nil
	if not silent then
		show('info', _t('uniform_off'))
	end
end

-- Centros (NPC de cada emprego) ---------------------------------------------------------------------------

local function clearCenters()
	for id, blip in pairs(centerBlips) do
		RemoveBlip(blip)
		centerBlips[id] = nil
	end
	for id, ped in pairs(centerPeds) do
		deleteEntity(ped)
		centerPeds[id] = nil
	end
	for key, ped in pairs(shopPeds) do
		deleteEntity(ped)
		shopPeds[key] = nil
	end
end

local function paintCenters()
	clearCenters()
	for id, job in pairs(catalog) do
		local blip = AddBlipForCoord(job.center.x, job.center.y, job.center.z)
		SetBlipSprite(blip, job.blip.sprite)
		SetBlipColour(blip, job.blip.color)
		SetBlipScale(blip, 0.8)
		SetBlipAsShortRange(blip, true)
		BeginTextCommandSetBlipName('STRING')
		AddTextComponentSubstringPlayerName(job.label)
		EndTextCommandSetBlipName(blip)
		centerBlips[id] = blip
		-- Loja do emprego e áreas de pesca ficam no mapa sempre (compra-se a vara antes de começar).
		for index, spot in ipairs(job.shop and job.shop.points or {}) do
			local shopBlip = AddBlipForCoord(spot.x, spot.y, spot.z)
			SetBlipSprite(shopBlip, 52)
			SetBlipColour(shopBlip, job.blip.color)
			SetBlipScale(shopBlip, 0.7)
			SetBlipAsShortRange(shopBlip, true)
			BeginTextCommandSetBlipName('STRING')
			AddTextComponentSubstringPlayerName(job.shop.label)
			EndTextCommandSetBlipName(shopBlip)
			centerBlips[id .. ':shop' .. index] = shopBlip
		end
		local fishing = job.gather and job.gather.fishing
		for index, zone in ipairs(fishing and fishing.areas or {}) do
			local radiusBlip = AddBlipForRadius(zone.x, zone.y, zone.z, zone.radius)
			SetBlipColour(radiusBlip, 3)
			SetBlipAlpha(radiusBlip, 70)
			centerBlips[id .. ':area' .. index] = radiusBlip
			local areaBlip = AddBlipForCoord(zone.x, zone.y, zone.z)
			SetBlipSprite(areaBlip, 68)
			SetBlipColour(areaBlip, 3)
			SetBlipScale(areaBlip, 0.6)
			SetBlipAsShortRange(areaBlip, true)
			BeginTextCommandSetBlipName('STRING')
			AddTextComponentSubstringPlayerName(('Pesca: %s'):format(zone.label))
			EndTextCommandSetBlipName(areaBlip)
			centerBlips[id .. ':areac' .. index] = areaBlip
		end
	end
end

-- Encerrar fora do NPC (compradores e loja): só empregos sem veículo da empresa, como a pesca livre.
local function stopOptions(job)
	if job.vehicle then
		return {}
	end
	return {
		{
			label = 'Encerrar o trabalho',
			distance = 2.5,
			canInteract = function() return session ~= nil and session.jobId == job.id end,
			onSelect = function() TriggerServerEvent('coe_jobs:stop') end
		},
		{
			label = 'Descartar a carga e encerrar',
			distance = 2.5,
			canInteract = function() return session ~= nil and session.jobId == job.id and (session.cargo or 0) > 0 end,
			onSelect = function() TriggerServerEvent('coe_jobs:stop', true) end
		}
	}
end

local function centerOptions(job)
	return {
		{
			label = ('Começar: %s'):format(job.label),
			distance = 2.5,
			canInteract = function() return session == nil end,
			onSelect = function() TriggerServerEvent('coe_jobs:start', job.id) end
		},
		{
			label = 'Encerrar o trabalho',
			distance = 2.5,
			canInteract = function() return session ~= nil and session.jobId == job.id end,
			onSelect = function() TriggerServerEvent('coe_jobs:stop') end
		},
		{
			-- Só na coleta com carga: encerrar descarta o que não foi vendido (o servidor avisa antes).
			label = 'Descartar a carga e encerrar',
			distance = 2.5,
			canInteract = function() return session ~= nil and session.jobId == job.id and (session.cargo or 0) > 0 end,
			onSelect = function() TriggerServerEvent('coe_jobs:stop', true) end
		},
		{
			-- Uniforme é opcional: só aparece trabalhando nesse emprego, se ele tiver um para o seu modelo.
			label = ('Vestir %s'):format(job.uniform and job.uniform.label:lower() or 'uniforme'),
			distance = 2.5,
			canInteract = function() return session ~= nil and session.jobId == job.id and wearing == nil and outfitFor(job) ~= nil end,
			onSelect = function() wearUniform(job) end
		},
		{
			label = 'Tirar o uniforme',
			distance = 2.5,
			canInteract = function() return wearing ~= nil and wearing.jobId == job.id end,
			onSelect = function() removeUniform(false) end
		},
		{
			label = 'Como funciona',
			distance = 2.5,
			onSelect = function() TriggerServerEvent('coe_jobs:guide', job.id) end
		}
	}
end

-- Sessão: pontos de coleta, venda e paradas ---------------------------------------------------------------

local function currentJob()
	return session and catalog[session.jobId] or nil
end

local function clearWork()
	for key, entity in pairs(work.props) do
		deleteEntity(entity)
		work.props[key] = nil
	end
	for key, entity in pairs(work.peds) do
		deleteEntity(entity)
		work.peds[key] = nil
	end
	for key, blip in pairs(work.blips) do
		RemoveBlip(blip)
		work.blips[key] = nil
	end
	if work.routeBlip then
		RemoveBlip(work.routeBlip)
		work.routeBlip = nil
	end
	if work.zoneBlip then
		RemoveBlip(work.zoneBlip)
		work.zoneBlip = nil
	end
	for _, name in ipairs(work.binModels or {}) do
		pcall(function() exports.coetarget:RemoveTargetModel(name) end)
	end
	work.binModels = nil
	for _, name in ipairs(work.worldModels or {}) do
		pcall(function() exports.coetarget:RemoveTargetModel(name) end)
	end
	work.worldModels = nil
	for index, object in pairs(work.ground) do
		deleteEntity(object)
		work.ground[index] = nil
	end
	work.groundKey = nil
	work.offSoil = {}
	work.soilOff = {}
	for key, blip in pairs(work.areaBlips) do
		RemoveBlip(blip)
		work.areaBlips[key] = nil
	end
	if work.carrying then
		deleteEntity(work.carrying.prop)
		stopAnimation(work.carrying.animation)
		work.carrying = nil
	end
	if work.vehicleTarget then
		untarget(work.vehicleTarget)
		work.vehicleTarget = nil
	end
	deleteEntity(work.passenger)
	work.passenger = nil
	work.busy = false
end

local function pointBlip(key, spot, sprite, color, label)
	local blip = AddBlipForCoord(spot.x, spot.y, spot.z)
	SetBlipSprite(blip, sprite)
	SetBlipColour(blip, color)
	SetBlipScale(blip, 0.65)
	SetBlipAsShortRange(blip, true)
	BeginTextCommandSetBlipName('STRING')
	AddTextComponentSubstringPlayerName(label)
	EndTextCommandSetBlipName(blip)
	work.blips[key] = blip
end

local function onCooldown(index)
	for _, entry in ipairs(session and session.cooldowns or {}) do
		if entry.node == index and entry.until_ and entry.until_ > GetGameTimer() then
			return true
		end
	end
	return false
end

-- Produto de um ponto (ou da coleta, se não houver produtos) e o tempo da ação com o bônus de Campo.
local function productOf(job, id)
	return job.gather.products and job.gather.products[id or job.gather.defaultProduct] or nil
end

local function actionSeconds(job, item)
	local base = (item and item.seconds) or job.gather.seconds
	return math.max(1, base * ((session and session.speed) or 1))
end

local function gatherNode(job, index)
	if work.busy then
		return
	end
	work.busy = true
	local node = job.gather.nodes[index]
	local item = productOf(job, node.product)
	CreateThread(function()
		local ok = timedAction(actionSeconds(job, item), (item and item.animation) or job.gather.animation, job.tool, node)
		work.busy = false
		if ok then
			TriggerServerEvent('coe_jobs:gather', job.id, index)
		else
			show('warning', _t('action_cancelled'))
		end
	end)
end

-- Haul (lenhador): estado do que está no chão, na mão e na caçamba.
local function haulState()
	return session and session.haul or nil
end

local function insideArea(zone)
	local here = Core.Platform.Entities.GetCoords(PlayerPedId())
	return #(vector2(here.x, here.y) - vector2(zone.x, zone.y)) <= zone.radius
end

-- Árvore tombando: cópia local do modelo no lugar da original (escondida), girando até deitar.
local function fallTree(entry)
	local hash = entry.model
	RequestModel(hash)
	local deadline = GetGameTimer() + 3000
	while not HasModelLoaded(hash) and GetGameTimer() < deadline do
		Wait(25)
	end
	if not HasModelLoaded(hash) then
		return
	end
	local object = CreateObjectNoOffset(hash, entry.x, entry.y, entry.z, false, false, false)
	SetModelAsNoLongerNeeded(hash)
	if not object or object == 0 then
		return
	end
	SetEntityCollision(object, false, false)
	FreezeEntityPosition(object, true)
	local heading = math.random(0, 359) + 0.0
	local started = GetGameTimer()
	-- Cai devagar no começo e acelera (como uma árvore de verdade), em ~2,2 s.
	while GetGameTimer() - started < 2200 do
		local t = (GetGameTimer() - started) / 2200
		SetEntityRotation(object, 88.0 * t * t, 0.0, heading, 2, true)
		Wait(0)
	end
	SetEntityRotation(object, 88.0, 0.0, heading, 2, true)
	Wait(3500)
	Core.Platform.Entities.Delete(object)
end

local function hideTree(entry, animate)
	local key = JobRules.BinKey(entry)
	if felled[key] then
		return
	end
	entry.until_ = GetGameTimer() + (entry.seconds or 600) * 1000
	felled[key] = entry
	CreateModelHide(entry.x, entry.y, entry.z, 2.0, entry.model, true)
	if animate and #(Core.Platform.Entities.GetCoords(PlayerPedId()) - vector3(entry.x, entry.y, entry.z)) < 150.0 then
		CreateThread(function() fallTree(entry) end)
	end
end

RegisterNetEvent('coe_jobs:felled', function(entry)
	if type(entry) == 'table' and type(entry.model) == 'number' then
		hideTree(entry, true)
	end
end)

RegisterNetEvent('coe_jobs:felledList', function(list)
	for _, entry in ipairs(type(list) == 'table' and list or {}) do
		if type(entry.model) == 'number' then
			hideTree(entry, false)
		end
	end
end)

-- Árvores voltam quando o cooldown do servidor passa.
CreateThread(function()
	while true do
		Wait(5000)
		local now = GetGameTimer()
		for key, entry in pairs(felled) do
			if entry.until_ <= now then
				RemoveModelHide(entry.x, entry.y, entry.z, 2.0, entry.model, false)
				felled[key] = nil
			end
		end
	end
end)

-- Objetos do mapa da coleta (árvores): os modelos de cada área ganham a opção enquanto o jogador está nela.
local function paintWorld(job)
	if work.worldModels or not job.gather or not job.gather.world or #job.gather.world == 0 then
		return
	end
	work.worldModels = {}
	for worldIndex, source in ipairs(job.gather.world) do
		local item = productOf(job, source.product)
		local option = {
			{
				label = (item and item.actionLabel) or job.gather.actionLabel,
				distance = 3.0,
				canInteract = function(entity)
					if work.busy or not session or session.jobId ~= job.id or IsPedInAnyVehicle(PlayerPedId(), false) then
						return false
					end
					local haul = haulState()
					if haul and (haul.ground > 0 or haul.carrying or haul.loaded >= haul.capacity) then
						return false
					end
					if felled[JobRules.BinKey(Core.Platform.Entities.GetCoords(entity))] then
						return false
					end
					return insideArea(source.area)
				end,
				onSelect = function(entity)
					if work.busy then
						return
					end
					work.busy = true
					local spot = Core.Platform.Entities.GetCoords(entity)
					local modelHash = Core.Platform.Entities.GetModel(entity)
					CreateThread(function()
						local ok = timedAction(actionSeconds(job, item), (item and item.animation) or job.gather.animation, job.tool, spot)
						work.busy = false
						if ok then
							TriggerServerEvent('coe_jobs:gatherWorld', job.id, worldIndex, { x = spot.x, y = spot.y, z = spot.z }, modelHash)
						else
							show('warning', _t('action_cancelled'))
						end
					end)
				end
			}
		}
		for _, name in ipairs(source.models) do
			work.worldModels[#work.worldModels + 1] = name
			pcall(function() exports.coetarget:AddTargetModel(name, option) end)
		end
	end
end

-- Toras no chão ao lado da árvore cortada: uma prop por unidade, cada uma com "Pegar".
local function paintGround(job)
	local haul = haulState()
	local key = haul and haul.spot and ('%s:%d'):format(JobRules.BinKey(haul.spot), haul.ground) or nil
	if key == work.groundKey then
		return
	end
	work.groundKey = key
	for index, object in pairs(work.ground) do
		deleteEntity(object)
		work.ground[index] = nil
	end
	if not haul or haul.ground <= 0 or not haul.spot then
		return
	end
	local spec = job.gather.haul
	for index = 1, haul.ground do
		-- Espalhadas em leque a 2-3 m do tronco.
		local angle = math.rad(index * (360 / haul.ground) + 20)
		local spot = { x = haul.spot.x + math.cos(angle) * 2.6, y = haul.spot.y + math.sin(angle) * 2.6, z = haul.spot.z, h = math.deg(angle) }
		local object = spawnProp(spec.groundProp, spot)
		if object then
			target(object, {
				{
					label = spec.takeLabel,
					distance = 2.5,
					canInteract = function() local h = haulState() return h ~= nil and not h.carrying and h.ground > 0 and not work.busy end,
					onSelect = function()
						work.busy = true
						CreateThread(function()
							playOnce({ dict = 'anim@mp_snowball', name = 'pickup_snowball', ms = 900, flag = 48 })
							work.busy = false
							TriggerServerEvent('coe_jobs:take', job.id)
						end)
					end
				}
			})
			work.ground[index] = object
		end
	end
end

-- Carga visível na caçamba: qualquer client perto desenha as props pela state bag do veículo.
local function clearRack(vehicle)
	for _, object in ipairs(racks[vehicle] or {}) do
		deleteEntity(object)
	end
	racks[vehicle] = nil
end

local function drawRack(vehicle, count)
	clearRack(vehicle)
	local tag = Entity(vehicle).state['coe:jobVehicle']
	local job = type(tag) == 'string' and catalog[tag:match('^([^:]+)')] or nil
	local rack = job and job.gather and job.gather.haul and job.gather.haul.rack
	if not rack or (count or 0) <= 0 then
		return
	end
	local hash = loadModel(rack.model)
	if not hash then
		return
	end
	local list = {}
	for index = 1, math.min(count, #rack.slots) do
		local slot = rack.slots[index]
		local object = CreateObject(hash, 0.0, 0.0, 0.0, false, false, false)
		SetEntityCollision(object, false, false)
		AttachEntityToEntity(object, vehicle, 0, slot[1], slot[2], slot[3], slot[4], slot[5], slot[6], false, false, false, false, 2, true)
		list[#list + 1] = object
	end
	SetModelAsNoLongerNeeded(hash)
	racks[vehicle] = list
end

AddStateBagChangeHandler('coe:jobLoad', nil, function(bagName, _, value)
	CreateThread(function()
		local deadline = GetGameTimer() + 3000
		local vehicle = GetEntityFromStateBagName(bagName)
		while (vehicle == 0 or not Core.Platform.Entities.Exists(vehicle)) and GetGameTimer() < deadline do
			Wait(100)
			vehicle = GetEntityFromStateBagName(bagName)
		end
		if vehicle ~= 0 and Core.Platform.Entities.Exists(vehicle) then
			drawRack(vehicle, tonumber(value) or 0)
		end
	end)
end)

-- Caçambas que saíram do alcance (veículo apagado) liberam as props.
CreateThread(function()
	while true do
		Wait(3000)
		for vehicle in pairs(racks) do
			if not Core.Platform.Entities.Exists(vehicle) then
				for _, object in ipairs(racks[vehicle]) do
					if Core.Platform.Entities.Exists(object) then
						Core.Platform.Entities.Delete(object)
					end
				end
				racks[vehicle] = nil
			end
		end
	end
end)

local function paintRoute(job)
	if work.routeBlip then
		RemoveBlip(work.routeBlip)
		work.routeBlip = nil
	end
	deleteEntity(work.peds.stop)
	work.peds.stop = nil
	deleteEntity(work.props.stop)
	work.props.stop = nil
	if work.zoneBlip then
		RemoveBlip(work.zoneBlip)
		work.zoneBlip = nil
	end
	local stop = session.route and session.route.stop
	if not stop then
		return
	end
	local zone = session.route.zone
	if zone then
		-- Área da coleta: círculo no mapa e GPS até o centro.
		work.zoneBlip = AddBlipForRadius(zone.x, zone.y, zone.z, zone.radius)
		SetBlipColour(work.zoneBlip, 25)
		SetBlipAlpha(work.zoneBlip, 90)
	end
	work.routeBlip = AddBlipForCoord(stop.x, stop.y, stop.z)
	SetBlipSprite(work.routeBlip, 1)
	SetBlipColour(work.routeBlip, 5)
	SetBlipRoute(work.routeBlip, true)
	SetBlipRouteColour(work.routeBlip, 5)
	BeginTextCommandSetBlipName('STRING')
	local phase = session.route.phase == 'pickup' and ' (embarque)' or session.route.phase == 'dropoff' and ' (destino)' or ''
	if zone then
		AddTextComponentSubstringPlayerName(('%s: %s (%d/%d sacos)'):format(job.label, zone.label, session.route.collected or 0, session.route.perZone or 0))
	else
		AddTextComponentSubstringPlayerName(('%s %d/%d%s'):format(job.label, session.route.index, session.route.total, phase))
	end
	EndTextCommandSetBlipName(work.routeBlip)
end

local function pickUp(job)
	if work.carrying or not job.route.carry then
		return
	end
	local prop = attachProp(job.route.carry)
	playAnimation(job.route.carryAnimation)
	work.carrying = { prop = prop, animation = job.route.carryAnimation }
end

local function jobVehicle()
	if not session or not session.vehicle or not NetworkDoesNetworkIdExist(session.vehicle) then
		return nil
	end
	local vehicle = NetToVeh(session.vehicle)
	return vehicle ~= 0 and Core.Platform.Entities.Exists(vehicle) and vehicle or nil
end

-- Jogador na traseira do veículo (onde fica a caçamba do caminhão de lixo). O coetarget mede a distância até o
-- centro do veículo, e o caminhão tem ~10 m: por isso a opção usa um alcance largo e esta checagem fina na traseira.
local function behind(vehicle)
	local minimum, maximum = GetModelDimensions(Core.Platform.Entities.GetModel(vehicle))
	local rear = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, minimum.y - 0.4, 0.0)
	local offset = GetOffsetFromEntityGivenWorldCoords(vehicle, Core.Platform.Entities.GetCoords(PlayerPedId()))
	return #(Core.Platform.Entities.GetCoords(PlayerPedId()) - rear) <= 2.6 and offset.y < minimum.y + 1.2
		and math.abs(offset.x) <= (maximum.x - minimum.x) / 2 + 0.6
end

-- Alcance da opção no veículo: metade do comprimento + o braço do jogador.
local function vehicleReach(vehicle)
	local minimum, maximum = GetModelDimensions(Core.Platform.Entities.GetModel(vehicle))
	return math.max(maximum.y, -minimum.y) + 2.5
end

local function rearOpen(vehicle, door)
	return GetVehicleDoorAngleRatio(vehicle, door) > 0.1
end

-- Porta da caçamba: o caminhão de lixo usa a porta 5 (traseira); se o modelo não tiver, tenta a 4 e a 6.
local function rearDoor(vehicle, door)
	if GetIsDoorValid(vehicle, door) then
		return door
	end
	for _, other in ipairs({ 5, 4, 6, 2 }) do
		if GetIsDoorValid(vehicle, other) then
			return other
		end
	end
	return door
end

local function setRear(vehicle, door, open)
	CreateThread(function()
		control(vehicle)
		local actual = rearDoor(vehicle, door)
		if open then
			SetVehicleDoorOpen(vehicle, actual, false, false)
		else
			SetVehicleDoorShut(vehicle, actual, false)
		end
	end)
end

-- Lenhador: colocar a tora da mão na caçamba da pickup (lateral ou traseira, perto da caçamba).
local function paintHaulTarget(job)
	local vehicle = jobVehicle()
	if work.vehicleTarget or not vehicle then
		return
	end
	local spec = job.gather.haul
	target(vehicle, {
		{
			label = spec.loadLabel,
			distance = vehicleReach(vehicle),
			canInteract = function(entity)
				local haul = haulState()
				if not haul or not haul.carrying or work.busy or IsPedInAnyVehicle(PlayerPedId(), false) then
					return false
				end
				-- Perto da caçamba (metade de trás do veículo).
				local offset = GetOffsetFromEntityGivenWorldCoords(entity, Core.Platform.Entities.GetCoords(PlayerPedId()))
				return offset.y < 0.5 and #(vector2(offset.x, offset.y)) < 4.5
			end,
			onSelect = function()
				work.busy = true
				CreateThread(function()
					playOnce({ dict = 'anim@heists@narcotics@trash', name = 'throw_b', ms = 1100, flag = 48 })
					work.busy = false
					TriggerServerEvent('coe_jobs:load', job.id)
				end)
			end
		}
	})
	work.vehicleTarget = vehicle
end

local function paintVehicleTarget(job)
	if work.vehicleTarget or not session.vehicle or not job.route or not job.route.carry or job.route.mode == 'passenger' then
		return
	end
	if not NetworkDoesNetworkIdExist(session.vehicle) then
		return
	end
	local vehicle = NetToVeh(session.vehicle)
	if vehicle == 0 or not Core.Platform.Entities.Exists(vehicle) then
		return
	end
	if job.route.mode == 'zone' then
		-- Traseira do caminhão: abrir/fechar a caçamba (só visual) e jogar o saco com ela aberta.
		local door = job.route.rearDoor or 5
		local reach = vehicleReach(vehicle)
		local function isOpen(entity)
			return rearOpen(entity, rearDoor(entity, door))
		end
		target(vehicle, {
			{
				label = job.route.openLabel,
				distance = reach,
				canInteract = function(entity) return not IsPedInAnyVehicle(PlayerPedId(), false) and behind(entity) and not isOpen(entity) end,
				onSelect = function(entity) setRear(entity, door, true) end
			},
			{
				label = job.route.dropLabel,
				distance = reach,
				canInteract = function(entity)
					return work.carrying ~= nil and not work.busy and session and session.route and session.route.picked and behind(entity) and isOpen(entity)
				end,
				onSelect = function(entity)
					-- Vira para a caçamba, arremessa o saco e só então o servidor conta.
					work.busy = true
					CreateThread(function()
						local ped = PlayerPedId()
						local minimum = GetModelDimensions(Core.Platform.Entities.GetModel(entity))
						local rear = GetOffsetFromEntityInWorldCoords(entity, 0.0, minimum.y, 0.5)
						TaskTurnPedToFaceCoord(ped, rear.x, rear.y, rear.z, 500)
						Wait(500)
						if work.carrying then
							stopAnimation(work.carrying.animation)
						end
						playOnce(job.route.dropAnimation)
						work.busy = false
						TriggerServerEvent('coe_jobs:deliver', job.id)
					end)
				end
			},
			{
				label = job.route.closeLabel,
				distance = reach,
				canInteract = function(entity) return work.carrying == nil and behind(entity) and isOpen(entity) end,
				onSelect = function(entity) setRear(entity, door, false) end
			}
		})
	elseif job.route.mode == 'collect' then
		-- Recolhido na parada: guarda no veículo (o servidor confere a distância do veículo e paga).
		target(vehicle, {
			{
				label = job.route.dropLabel,
				distance = 4.0,
				canInteract = function() return work.carrying ~= nil and session and session.route and session.route.picked end,
				onSelect = function() TriggerServerEvent('coe_jobs:deliver', job.id) end
			}
		})
	else
		target(vehicle, {
			{
				label = job.route.pickupLabel,
				distance = 3.0,
				canInteract = function() return work.carrying == nil and not IsPedInAnyVehicle(PlayerPedId(), false) end,
				onSelect = function() pickUp(job) end
			}
		})
	end
	work.vehicleTarget = vehicle
end

-- Zona: as lixeiras do mapa (modelos de `binModels`) ganham a opção de recolher enquanto o jogador está na área.
local function paintBins(job)
	if work.binModels or not job.route or job.route.mode ~= 'zone' then
		return
	end
	work.binModels = job.route.binModels or {}
	local option = {
		{
			label = job.route.actionLabel,
			distance = 2.2,
			canInteract = function()
				local zone = session and session.jobId == job.id and session.route and session.route.zone
				if not zone or session.route.picked or work.carrying or IsPedInAnyVehicle(PlayerPedId(), false) then
					return false
				end
				local here = Core.Platform.Entities.GetCoords(PlayerPedId())
				return #(vector2(here.x, here.y) - vector2(zone.x, zone.y)) <= zone.radius
			end,
			onSelect = function(entity)
				if work.busy then
					return
				end
				local spot = Core.Platform.Entities.GetCoords(entity)
				work.busy = true
				CreateThread(function()
					-- Abaixa e pega o saco antes de ele aparecer na mão.
					TaskTurnPedToFaceCoord(PlayerPedId(), spot.x, spot.y, spot.z, 500)
					Wait(500)
					playOnce(job.route.pickAnimation)
					work.busy = false
					TriggerServerEvent('coe_jobs:pickup', job.id, { x = spot.x, y = spot.y, z = spot.z })
				end)
			end
		}
	}
	for _, name in ipairs(work.binModels) do
		pcall(function() exports.coetarget:AddTargetModel(name, option) end)
	end
end

-- Mesma parada? As visões chegam como tabelas novas a cada evento, então compara as coordenadas.
local function sameSpot(a, b)
	if a == nil or b == nil then
		return a == b
	end
	return a.x == b.x and a.y == b.y and a.z == b.z
end

-- Táxi: o passageiro entra no banco de trás e sai no destino.
local function boardPassenger(ped)
	local vehicle = jobVehicle()
	if not ped or not vehicle then
		deleteEntity(ped)
		return
	end
	untarget(ped)
	FreezeEntityPosition(ped, false)
	ClearPedTasks(ped)
	TaskEnterVehicle(ped, vehicle, 15000, 2, 1.0, 1, 0)
	work.passenger = ped
end

local function dropPassenger()
	local ped = work.passenger
	work.passenger = nil
	if not ped or not Core.Platform.Entities.Exists(ped) then
		return
	end
	TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 0)
	CreateThread(function()
		Wait(2500)
		if Core.Platform.Entities.Exists(ped) then
			TaskWanderStandard(ped, 10.0, 10)
			Wait(12000)
			deleteEntity(ped)
		end
	end)
end

-- Táxi parado perto da parada com o jogador ao volante.
local function stoppedAt(stop, radius)
	local ped = PlayerPedId()
	local vehicle = jobVehicle()
	if not vehicle or GetVehiclePedIsIn(ped, false) ~= vehicle or GetPedInVehicleSeat(vehicle, -1) ~= ped then
		return false
	end
	return GetEntitySpeed(vehicle) < 1.5 and #(Core.Platform.Entities.GetCoords(vehicle) - vector3(stop.x, stop.y, stop.z)) <= radius
end

local function applySession(view)
	local previous = session
	session = view
	-- Cooldowns chegam em segundos; guarda o fim no relógio local.
	for _, entry in ipairs(session.cooldowns or {}) do
		entry.until_ = GetGameTimer() + entry.seconds * 1000
	end
	local job = currentJob()
	if not job then
		return
	end
	if not previous or previous.jobId ~= view.jobId then
		clearWork()
		if job.gather then
			local g = job.gather
			for index, spot in ipairs(g.sell.points) do
				pointBlip('sell' .. index, spot, 500, 2, g.sell.label)
			end
			for index, spot in ipairs(g.process and g.process.points or {}) do
				pointBlip('process' .. index, spot, 566, 47, g.process.label)
			end
			-- Campos em grade: um blip no meio de cada campo (não um por pé); pontos soltos ganham o seu.
			local inField = {}
			for fieldIndex, field in ipairs(g.fields or {}) do
				local sx, sy, sz = 0.0, 0.0, 0.0
				for index = field.first, field.first + field.count - 1 do
					local node = g.nodes[index]
					sx, sy, sz = sx + node.x, sy + node.y, sz + node.z
					inField[index] = true
				end
				local spot = { x = sx / field.count, y = sy / field.count, z = sz / field.count }
				pointBlip('field' .. fieldIndex, spot, 1, 25, field.label)
			end
			for index, spot in ipairs(g.nodes) do
				if not inField[index] then
					pointBlip('node' .. index, spot, 1, 25, g.actionLabel)
				end
			end
			-- Áreas do mapa (floresta): círculo e blip no centro.
			for index, source in ipairs(g.world or {}) do
				local zone = source.area
				local radiusBlip = AddBlipForRadius(zone.x, zone.y, zone.z, zone.radius)
				SetBlipColour(radiusBlip, 25)
				SetBlipAlpha(radiusBlip, 80)
				work.areaBlips['world' .. index] = radiusBlip
				pointBlip('worldc' .. index, zone, 1, 25, source.label)
			end
		end
	end
	if job.gather then
		paintWorld(job)
		local haul = view.haul
		if haul then
			paintGround(job)
			local spec = job.gather.haul
			if haul.carrying and not work.carrying then
				-- Tora no ombro: prop e andar de carga até a pickup.
				local prop = attachProp(spec.carry)
				playAnimation(spec.carryAnimation)
				work.carrying = { prop = prop, animation = spec.carryAnimation }
			elseif not haul.carrying and work.carrying then
				deleteEntity(work.carrying.prop)
				stopAnimation(work.carrying.animation)
				work.carrying = nil
			end
		end
	end
	if job.route then
		local was, now = previous and previous.route, view.route
		local moved = not was or not now or not sameSpot(was.stop, now.stop) or was.index ~= now.index or was.phase ~= now.phase
			or was.collected ~= now.collected
		paintBins(job)
		if job.route.mode == 'passenger' and moved then
			if was and was.phase == 'pickup' and now and now.phase == 'dropoff' then
				boardPassenger(work.peds.stop)
				work.peds.stop = nil
			elseif work.passenger then
				dropPassenger()
			end
		end
		local carries = job.route.mode == 'collect' or job.route.mode == 'zone'
		if carries and now and now.picked and not work.carrying then
			pickUp(job)
		elseif carries and now and not now.picked and work.carrying then
			-- Saco entregue: some da mão.
			deleteEntity(work.carrying.prop)
			stopAnimation(work.carrying.animation)
			work.carrying = nil
		end
		if moved then
			paintRoute(job)
		end
		if work.carrying and not carries and (not previous or (previous.route and view.route and (previous.route.index ~= view.route.index or not sameSpot(previous.route.stop, view.route.stop)))) then
			deleteEntity(work.carrying.prop)
			stopAnimation(work.carrying.animation)
			work.carrying = nil
		end
	end
	-- Ponto de coleta usado: some até o fim do cooldown.
	for _, entry in ipairs(session.cooldowns or {}) do
		local key = 'node' .. entry.node
		if work.props[key] then
			deleteEntity(work.props[key])
			work.props[key] = nil
		end
	end
end

RegisterNetEvent('coe_jobs:session', function(view)
	if type(view) == 'table' and catalog[view.jobId] then
		applySession(view)
	end
end)

RegisterNetEvent('coe_jobs:ended', function()
	session = nil
	if fishingState then
		cancelFishing(false)
	end
	putAwayRod()
	clearWork()
	removeUniform(true)
	ClearGpsPlayerWaypoint()
end)

-- Guia "Como funciona" (NUI): abre com o foco do mouse e fecha pelo botão ou Esc.
RegisterNetEvent('coe_jobs:guide', function(guide)
	if type(guide) ~= 'table' then
		return
	end
	nuiOpen = 'guide'
	SendNUIMessage({ action = 'guide:open', guide = guide })
	SetNuiFocus(true, true)
end)

RegisterNUICallback('close', function(_, cb)
	nuiOpen = nil
	SetNuiFocus(false, false)
	cb({ ok = true })
end)

-- Loja do emprego (NUI): vitrine com nível, preço e itens bloqueados; o servidor cobra e entrega no inventário.
RegisterNetEvent('coe_jobs:shop', function(view)
	if type(view) ~= 'table' then
		return
	end
	SendNUIMessage({ action = nuiOpen == 'shop' and 'shop:update' or 'shop:open', shop = view })
	if nuiOpen ~= 'shop' then
		nuiOpen = 'shop'
		SetNuiFocus(true, true)
	end
end)

RegisterNUICallback('shopBuy', function(data, cb)
	if type(data) == 'table' and type(data.jobId) == 'string' and type(data.item) == 'string' then
		TriggerServerEvent('coe_jobs:buy', data.jobId, tonumber(data.point), data.item, tonumber(data.quantity) or 1)
	end
	cb({ ok = true })
end)

-- Pesca livre ------------------------------------------------------------------------------------------------
-- Usar a vara no inventário põe a vara (prop próprio, não o do cenário) na mão. Com ela: segurar E carrega a força
-- e soltar arremessa; X guarda. Na mordida, E fisga; depois vem a briga: segurar/soltar E move a faixa para manter
-- o peixe dentro até o progresso encher. Laço por quadro só enquanto a vara está na mão.

JobsClient = {
	catalog = catalog,
	work = work,
	show = show,
	loadDict = loadDict,
	attachProp = attachProp,
	playAnimation = playAnimation,
	stopAnimation = stopAnimation,
	deleteEntity = deleteEntity
}

local function cancelFishing(silent)
	if JobsClient.cancelFishing then
		JobsClient.cancelFishing(silent)
	end
end

RegisterNetEvent('coe_jobs:result', function()
	work.busy = false
	-- Lance recusado pelo servidor (sem isca, cheio...): solta o jogador.
	if fishingState then
		cancelFishing(false)
	end
end)

RegisterNetEvent('coe_jobs:catalog', function(list)
	if type(list) ~= 'table' then
		return
	end
	catalog = {}
	for _, job in ipairs(list) do
		catalog[job.id] = job
	end
	paintCenters()
	if session and not catalog[session.jobId] then
		session = nil
		clearWork()
	end
end)

-- Venda: com um produto, o rótulo mostra o preço ("$8 por repolho"); com vários, o guia lista cada preço.
local function sellLabel(job)
	local g = job.gather
	local order = g.productOrder or {}
	local priced = {}
	for _, id in ipairs(order) do
		if g.products[id].price > 0 then
			priced[#priced + 1] = g.products[id]
		end
	end
	if #priced == 1 then
		return ('%s ($%d por %s)'):format(g.sell.label, priced[1].price, priced[1].unit)
	end
	return g.sell.label
end

local function sellable(job)
	for id, amount in pairs(session and session.goods or {}) do
		local item = job.gather.products[id]
		if amount > 0 and item and item.price > 0 then
			return true
		end
	end
	return false
end

-- Laço de proximidade (1 s): cria e remove NPCs e objetos perto do jogador.
CreateThread(function()
	while not NetworkIsPlayerActive(PlayerId()) do
		Wait(500)
	end
	TriggerServerEvent('coe_jobs:catalog')
	while true do
		local coords = Core.Platform.Entities.GetCoords(PlayerPedId())
		local range = config.SpawnDistance
		for id, job in pairs(catalog) do
			local center = vector3(job.center.x, job.center.y, job.center.z)
			local near = #(coords - center) < range
			if near and not centerPeds[id] then
				local ped = spawnPed(job.centerPed, job.center)
				if ped then
					target(ped, centerOptions(job))
					centerPeds[id] = ped
				end
			elseif not near and centerPeds[id] and #(coords - center) > range + 20.0 then
				deleteEntity(centerPeds[id])
				centerPeds[id] = nil
			end
		end
		-- Lojas dos empregos: sempre (sem precisar ter começado o trabalho).
		for id, shopJob in pairs(catalog) do
			for index, spot in ipairs(shopJob.shop and shopJob.shop.points or {}) do
				local key = id .. ':' .. index
				local distance = #(coords - vector3(spot.x, spot.y, spot.z))
				if distance < range and not shopPeds[key] then
					local ped = spawnPed(shopJob.shop.ped, spot, 'WORLD_HUMAN_STAND_IMPATIENT')
					if ped then
						local options = {
							{
								label = shopJob.shop.label,
								distance = 2.5,
								onSelect = function() TriggerServerEvent('coe_jobs:shop', shopJob.id, index) end
							}
						}
						for _, option in ipairs(stopOptions(shopJob)) do
							options[#options + 1] = option
						end
						target(ped, options)
						shopPeds[key] = ped
					end
				elseif distance > range + 20.0 and shopPeds[key] then
					deleteEntity(shopPeds[key])
					shopPeds[key] = nil
				end
			end
		end
		local job = currentJob()
		if job and job.gather then
			if job.gather.haul then
				paintHaulTarget(job)
			end
			for index, spot in ipairs(job.gather.nodes) do
				local key = 'node' .. index
				local distance = #(coords - vector3(spot.x, spot.y, spot.z))
				if distance < range and not work.props[key] and not onCooldown(index) and not work.offSoil[index] then
					local item = productOf(job, spot.product)
					local groundZ, material = probeGround(spot)
					-- Campo de plantio: ponto que cai fora da terra (estrada, grama, cerca) fica sem prop.
					if spot.field and job.gather.fields[spot.field].soil and not work.soilOff[spot.field] and not isSoil(material) then
						work.offSoil[index] = true
						-- Campo inteiro fora da lista de materiais (mapa diferente): desliga o filtro nele em vez de sumir.
						local field = job.gather.fields[spot.field]
						local all = true
						for other = field.first, field.first + field.count - 1 do
							all = all and work.offSoil[other] == true
						end
						if all then
							work.soilOff[spot.field] = true
							for other = field.first, field.first + field.count - 1 do
								work.offSoil[other] = nil
							end
						end
					else
						local object = spawnProp((item and item.prop) or job.gather.nodeProp or 'prop_cs_cardbox_01', spot, groundZ)
						if object then
							target(object, {
								{
									label = (item and item.actionLabel) or job.gather.actionLabel,
									distance = 2.5,
									canInteract = function() return not work.busy and session ~= nil and (session.cargo or 0) < (session.capacity or job.gather.capacity) end,
									onSelect = function() gatherNode(job, index) end
								}
							})
							work.props[key] = object
						end
					end
				elseif distance > range + 20.0 and work.props[key] then
					deleteEntity(work.props[key])
					work.props[key] = nil
				end
			end
			-- Beneficiamento (serra da madeireira): bancada com a opção de desdobrar a carga da caçamba.
			for index, spot in ipairs(job.gather.process and job.gather.process.points or {}) do
				local key = 'process' .. index
				local distance = #(coords - vector3(spot.x, spot.y, spot.z))
				local process = job.gather.process
				if distance < range and not work.props[key] then
					local object = spawnProp(process.prop or 'prop_tool_bench02', spot)
					if object then
						target(object, {
							{
								label = process.label,
								distance = 2.8,
								canInteract = function() local h = haulState() return h ~= nil and h.loaded > 0 and not work.busy and not h.carrying end,
								onSelect = function()
									local h = haulState()
									if work.busy or not h then
										return
									end
									work.busy = true
									CreateThread(function()
										local seconds = math.min(process.maxSeconds, process.seconds * h.loaded)
										local ok = timedAction(seconds, process.animation, nil, spot)
										work.busy = false
										if ok then
											TriggerServerEvent('coe_jobs:process', job.id, index)
										else
											show('warning', _t('action_cancelled'))
										end
									end)
								end
							}
						})
						work.props[key] = object
					end
				elseif distance > range + 20.0 and work.props[key] then
					deleteEntity(work.props[key])
					work.props[key] = nil
				end
			end
			for index, spot in ipairs(job.gather.sell.points) do
				local key = 'sell' .. index
				local distance = #(coords - vector3(spot.x, spot.y, spot.z))
				if distance < range and not work.peds[key] then
					local ped = spawnPed(job.gather.sell.ped, spot)
					if ped then
						local options = {
							{
								label = sellLabel(job),
								distance = 2.5,
								canInteract = function() return session ~= nil and sellable(job) end,
								onSelect = function() TriggerServerEvent('coe_jobs:sell', job.id, index) end
							}
						}
						for _, option in ipairs(stopOptions(job)) do
							options[#options + 1] = option
						end
						target(ped, options)
						work.peds[key] = ped
					end
				elseif distance > range + 20.0 and work.peds[key] then
					deleteEntity(work.peds[key])
					work.peds[key] = nil
				end
			end
		elseif job and job.route and session.route then
			paintVehicleTarget(job)
			local route = session.route
			local stop = route.stop
			local mode = job.route.mode
			local distance = stop and #(coords - vector3(stop.x, stop.y, stop.z)) or math.huge
			local radius = job.route.stopRadius or config.PointRadius
			if mode == 'zone' then
				-- Nada a criar: as lixeiras são as do próprio mapa (paintBins).
			elseif mode == 'passenger' then
				-- Embarque e desembarque automáticos com o táxi parado no ponto (pedido a cada 3 s no máximo).
				if stop and stoppedAt(stop, radius) and GetGameTimer() - work.asked > 3000 then
					work.asked = GetGameTimer()
					TriggerServerEvent(route.phase == 'pickup' and 'coe_jobs:pickup' or 'coe_jobs:deliver', job.id)
				end
				if route.phase == 'pickup' and distance < range and not work.peds.stop then
					local recipients = job.route.recipients
					work.peds.stop = spawnPed(recipients[math.random(#recipients)], stop, 'WORLD_HUMAN_STAND_MOBILE')
				end
			elseif mode == 'collect' then
				if distance < range and not work.props.stop then
					local object = spawnProp(job.route.stopProp or 'prop_cs_cardbox_01', stop)
					if object then
						target(object, {
							{
								label = job.route.actionLabel,
								distance = 2.5,
								canInteract = function() return work.carrying == nil and session and session.route and not session.route.picked end,
								onSelect = function() TriggerServerEvent('coe_jobs:pickup', job.id) end
							}
						})
						work.props.stop = object
					end
				elseif distance > range + 20.0 and work.props.stop then
					deleteEntity(work.props.stop)
					work.props.stop = nil
				end
			elseif distance < range and not work.peds.stop then
				local recipients = job.route.recipients
				local ped = spawnPed(recipients[math.random(#recipients)], stop, 'WORLD_HUMAN_STAND_IMPATIENT')
				if ped then
					target(ped, {
						{
							label = job.route.actionLabel,
							distance = 2.5,
							canInteract = function() return job.route.carry == nil or work.carrying ~= nil end,
							onSelect = function() TriggerServerEvent('coe_jobs:deliver', job.id) end
						}
					})
					work.peds.stop = ped
				end
			elseif distance > range + 20.0 and work.peds.stop then
				deleteEntity(work.peds.stop)
				work.peds.stop = nil
			end
		end
		Wait(1000)
	end
end)

AddEventHandler('onResourceStop', function(resource)
	if resource == GetCurrentResourceName() then
		if nuiOpen then
			SetNuiFocus(false, false)
		end
		if fishingState then
			cancelFishing(false)
		end
		putAwayRod()
		clearCenters()
		clearWork()
		removeUniform(true)
		for key, entry in pairs(felled) do
			RemoveModelHide(entry.x, entry.y, entry.z, 2.0, entry.model, false)
			felled[key] = nil
		end
		for vehicle in pairs(racks) do
			for _, object in ipairs(racks[vehicle]) do
				deleteEntity(object)
			end
			racks[vehicle] = nil
		end
	end
end)
