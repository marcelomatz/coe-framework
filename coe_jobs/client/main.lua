-- coe_jobs (client): runtime genérico dos empregos registrados pelos pacotes. Mostra centros, pontos e paradas,
-- anima as ações e pede ao servidor; nenhum pagamento sai daqui. Sem loops por quadro: tudo em intervalos.
local config = JobsConfig

local catalog = {}      -- id -> definição pública
local centerBlips = {}
local centerPeds = {}   -- id -> ped
local session = nil     -- visão do servidor
local work = { props = {}, peds = {}, blips = {}, routeBlip = nil, zoneBlip = nil, binModels = nil, carrying = nil, busy = false, vehicleTarget = nil, passenger = nil, asked = 0 }

local function show(kind, message)
	pcall(function() exports.coe_notify:Show(kind, message, 4000) end)
end

local rawLocales = (type(Locales) == 'table' and Locales) or {}
local _t_inst = (Core and Core.Locale and Core.Locale.New) and Core.Locale.New({
	default = (config and config.Locale) or (Core and Core.Locale and Core.Locale.GetDefaultLang()) or 'pt-BR',
	locales = rawLocales
})
local _t = function(k, params)
	if type(_t_inst) == 'table' then
		if _t_inst.T then
			return _t_inst:T(k, params)
		end
		local lang = _t_inst.lang or 'pt-BR'
		local dict = (_t_inst.locales and _t_inst.locales[lang]) or rawLocales[lang] or rawLocales['pt-BR']
		if dict and dict[k] then
			local text = dict[k]
			if params then
				for pk, pv in pairs(params) do
					text = text:gsub('%%{' .. pk .. '}', tostring(pv))
				end
			end
			return text
		end
	elseif type(_t_inst) == 'function' then
		return _t_inst(k, params)
	end
	return (rawLocales['pt-BR'] and rawLocales['pt-BR'][k]) or k
end

local function loadModel(name)
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
	if entity and DoesEntityExist(entity) then
		untarget(entity)
		DeleteEntity(entity)
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

local function spawnProp(model, spot)
	local hash = loadModel(model) or loadModel('prop_cs_cardbox_01')
	if not hash then
		return nil
	end
	local found, groundZ = GetGroundZFor_3dCoord(spot.x, spot.y, spot.z + 2.0, false)
	local object = CreateObject(hash, spot.x, spot.y, found and groundZ or spot.z, false, false, false)
	SetModelAsNoLongerNeeded(hash)
	if not object or object == 0 then
		return nil
	end
	SetEntityHeading(object, spot.h or 0.0)
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
	local coords = GetEntityCoords(ped)
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

-- Ação com duração: animação + ferramenta; cancela se o jogador se afastar, entrar em veículo ou morrer.
local function timedAction(seconds, animation, tool)
	local ped = PlayerPedId()
	local origin = GetEntityCoords(ped)
	local held = attachProp(tool)
	playAnimation(animation)
	local deadline = GetGameTimer() + math.floor(seconds * 1000)
	local ok = true
	while GetGameTimer() < deadline do
		Wait(100)
		ped = PlayerPedId()
		if #(GetEntityCoords(ped) - origin) > 1.5 or IsPedInAnyVehicle(ped, true) or IsPedDeadOrDying(ped, true) then
			ok = false
			break
		end
	end
	stopAnimation(animation)
	deleteEntity(held)
	return ok
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
	end
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

local function gatherNode(job, index)
	if work.busy then
		return
	end
	work.busy = true
	CreateThread(function()
		-- Tempo já com o bônus de habilidade (Campo) vindo do servidor.
		local ok = timedAction(session and session.seconds or job.gather.seconds, job.gather.animation, job.tool)
		work.busy = false
		if ok then
			TriggerServerEvent('coe_jobs:gather', job.id, index)
		else
			show('warning', _t('action_cancelled'))
		end
	end)
end

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
	return vehicle ~= 0 and DoesEntityExist(vehicle) and vehicle or nil
end

-- Jogador atrás do veículo (traseira, onde fica a caçamba do caminhão de lixo).
local function behind(vehicle)
	local offset = GetOffsetFromEntityGivenWorldCoords(vehicle, GetEntityCoords(PlayerPedId()))
	local minimum = GetModelDimensions(GetEntityModel(vehicle))
	return offset.y < minimum.y + 1.5
end

local function rearOpen(vehicle, door)
	return GetVehicleDoorAngleRatio(vehicle, door) > 0.1
end

local function paintVehicleTarget(job)
	if work.vehicleTarget or not session.vehicle or not job.route or not job.route.carry or job.route.mode == 'passenger' then
		return
	end
	if not NetworkDoesNetworkIdExist(session.vehicle) then
		return
	end
	local vehicle = NetToVeh(session.vehicle)
	if vehicle == 0 or not DoesEntityExist(vehicle) then
		return
	end
	if job.route.mode == 'zone' then
		-- Traseira do caminhão: abrir/fechar a caçamba (só visual) e jogar o saco com ela aberta.
		local door = job.route.rearDoor or 5
		target(vehicle, {
			{
				label = job.route.openLabel,
				distance = 4.0,
				canInteract = function(entity) return not IsPedInAnyVehicle(PlayerPedId(), false) and behind(entity) and not rearOpen(entity, door) end,
				onSelect = function(entity) SetVehicleDoorOpen(entity, door, false, false) end
			},
			{
				label = job.route.dropLabel,
				distance = 4.0,
				canInteract = function(entity)
					return work.carrying ~= nil and session and session.route and session.route.picked and behind(entity) and rearOpen(entity, door)
				end,
				onSelect = function() TriggerServerEvent('coe_jobs:deliver', job.id) end
			},
			{
				label = job.route.closeLabel,
				distance = 4.0,
				canInteract = function(entity) return work.carrying == nil and behind(entity) and rearOpen(entity, door) end,
				onSelect = function(entity) SetVehicleDoorShut(entity, door, false) end
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
				local here = GetEntityCoords(PlayerPedId())
				return #(vector2(here.x, here.y) - vector2(zone.x, zone.y)) <= zone.radius
			end,
			onSelect = function(entity)
				local spot = GetEntityCoords(entity)
				TriggerServerEvent('coe_jobs:pickup', job.id, { x = spot.x, y = spot.y, z = spot.z })
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
	if not ped or not DoesEntityExist(ped) then
		return
	end
	TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 0)
	CreateThread(function()
		Wait(2500)
		if DoesEntityExist(ped) then
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
	return GetEntitySpeed(vehicle) < 1.5 and #(GetEntityCoords(vehicle) - vector3(stop.x, stop.y, stop.z)) <= radius
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
			for index, spot in ipairs(job.gather.sell.points) do
				pointBlip('sell' .. index, spot, 500, 2, job.gather.sell.label)
			end
			for index, spot in ipairs(job.gather.nodes) do
				pointBlip('node' .. index, spot, 1, 25, job.gather.actionLabel)
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
	clearWork()
	ClearGpsPlayerWaypoint()
end)

-- Guia "Como funciona" (NUI): abre com o foco do mouse e fecha pelo botão ou Esc.
local guideOpen = false

RegisterNetEvent('coe_jobs:guide', function(guide)
	if type(guide) ~= 'table' then
		return
	end
	guideOpen = true
	SendNUIMessage({ action = 'guide:open', guide = guide })
	SetNuiFocus(true, true)
end)

RegisterNUICallback('close', function(_, cb)
	guideOpen = false
	SetNuiFocus(false, false)
	cb({ ok = true })
end)

RegisterNetEvent('coe_jobs:result', function()
	work.busy = false
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

-- Laço de proximidade (1 s): cria e remove NPCs e objetos perto do jogador.
CreateThread(function()
	while not NetworkIsPlayerActive(PlayerId()) do
		Wait(500)
	end
	TriggerServerEvent('coe_jobs:catalog')
	while true do
		local coords = GetEntityCoords(PlayerPedId())
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
		local job = currentJob()
		if job and job.gather then
			for index, spot in ipairs(job.gather.nodes) do
				local key = 'node' .. index
				local distance = #(coords - vector3(spot.x, spot.y, spot.z))
				if distance < range and not work.props[key] and not onCooldown(index) then
					local object = spawnProp(job.gather.nodeProp or 'prop_cs_cardbox_01', spot)
					if object then
						target(object, {
							{
								label = job.gather.actionLabel,
								distance = 2.5,
								canInteract = function() return not work.busy and session ~= nil and (session.cargo or 0) < (session.capacity or job.gather.capacity) end,
								onSelect = function() gatherNode(job, index) end
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
						target(ped, {
							{
								label = ('%s ($%d por %s)'):format(job.gather.sell.label, job.gather.sell.price, job.gather.unit),
								distance = 2.5,
								canInteract = function() return session ~= nil and (session.cargo or 0) > 0 end,
								onSelect = function() TriggerServerEvent('coe_jobs:sell', job.id, index) end
							}
						})
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
		if guideOpen then
			SetNuiFocus(false, false)
		end
		clearCenters()
		clearWork()
	end
end)
