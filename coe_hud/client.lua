local prefs = Prefs.sanitize(nil)
-- Preferencias em uso: as salvas ou, durante o modo de edicao, o rascunho em pre-visualizacao.
local live = prefs
local editing = false
-- Dentro de qualquer veiculo (motorista ou passageiro): libera minimapa/bussola no modo 'vehicle'.
local inVehicle = false
local radarShown = nil
local last = nil
local needs = nil
local anchor, anchorAt = nil, 0
-- Motivos que escondem o HUD (seleção de personagem, criador...). Vazio = visível.
local hiddenBy = {}

local function isHidden()
	return next(hiddenBy) ~= nil
end

local CLASS_MOTORCYCLE = 8
local CLASS_CYCLE = 13
local AIR_CLASSES = { [15] = true, [16] = true }

-- motorcycle: moto (sem cinto). bicycle: bicicleta (sem motor: sem combustível, rotação, marcha nem cinto).
local function vehicleKind(vehicle)
	local class = GetVehicleClass(vehicle)
	if class == CLASS_MOTORCYCLE then
		return 'motorcycle'
	end
	if class == CLASS_CYCLE then
		return 'bicycle'
	end
	if class == 14 then
		return 'boat'
	end
	if AIR_CLASSES[class] then
		return 'air'
	end
	return 'car'
end

local function percent(value, max)
	if max <= 0 then
		return 0
	end
	return math.max(0, math.min(100, math.floor(value / max * 100 + 0.5)))
end

-- Tabela reaproveitada a cada leitura; só vira cópia nova quando algo mudou.
local scratch = {}

local function buildSnapshot(ped)
	local health = GetEntityHealth(ped) - 100
	local snapshot = scratch
	for key in pairs(snapshot) do
		snapshot[key] = nil
	end
	snapshot.health = percent(health, GetEntityMaxHealth(ped) - 100)
	snapshot.armor = percent(GetPedArmour(ped), 100)
	snapshot.vehicle = false
	local vehicle = GetVehiclePedIsIn(ped, false)
	inVehicle = vehicle ~= 0
	snapshot.inVehicle = inVehicle
	if live.showLocation and (live.locationMode ~= 'vehicle' or inVehicle or editing) then
		local place = Location.Read(ped)
		snapshot.dir, snapshot.street, snapshot.zone, snapshot.clock = place.dir, place.street, place.zone, place.clock
		if live.showRoute then
			snapshot.route = Location.Route(ped)
		end
	end
	if needs then
		snapshot.hunger = needs.hunger
		snapshot.thirst = needs.thirst
		snapshot.stress = needs.stress
		snapshot.alcohol = needs.alcohol or 0
		snapshot.drugs = needs.drugs or 0
	end

	pcall(function()
		if exports.coe_talk and exports.coe_talk.GetVoiceRange then
			local dist = exports.coe_talk:GetVoiceRange()
			if dist then
				snapshot.voiceRange = dist
				snapshot.talking = exports.coe_talk:IsTalking()
				snapshot.radioTransmitting = exports.coe_talk:IsRadioTransmitting()
			end
		end
	end)

	local driving = vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped
	VehicleControls.Track(ped, driving and vehicle or 0)
	if driving then
		local factor = live.unit == 'mph' and 2.236936 or 3.6
		local kind = vehicleKind(vehicle)
		snapshot.vehicle = true
		snapshot.kind = kind
		snapshot.speed = math.floor(GetEntitySpeed(vehicle) * factor + 0.5)
		snapshot.motor = kind ~= 'bicycle'
		snapshot.hasBelt = VehicleControls.HasBelt(kind)
		if snapshot.motor then
			snapshot.rpm = percent(GetVehicleCurrentRpm(vehicle), 1)
			snapshot.gear = GetVehicleCurrentGear(vehicle)
			snapshot.fuel = percent(GetVehicleFuelLevel(vehicle), 100)
			snapshot.engine = percent(GetVehicleEngineHealth(vehicle), 1000)
			snapshot.engineOn = GetIsVehicleEngineRunning(vehicle) and true or false
		end
		snapshot.belt = snapshot.hasBelt and VehicleControls.belt or false
		snapshot.lights = VehicleControls.lights
		snapshot.left = VehicleControls.left
		snapshot.right = VehicleControls.right
	end
	return snapshot
end

local function changed(a, b)
	if not a then
		return true
	end
	for key, value in pairs(b) do
		if a[key] ~= value then
			return true
		end
	end
	for key in pairs(a) do
		if b[key] == nil then
			return true
		end
	end
	return false
end

-- base e o retangulo padrao do GTA (tela inteira); o NUI calcula a area util pela proporcao escolhida.
local function sendMinimap()
	SendNUIMessage({ action = 'minimap', anchor = anchor, base = Location.Base(), extended = Location.scale > 1 })
end

-- Recalcula o retangulo do minimapa pelo layout em uso e reposiciona o radar nativo.
local function applyMinimap()
	Location.minimap = live.layout.minimap
	Location.aspect = live.aspect
	local base = Location.Base()
	if base then
		local area = MinimapLayout.Area(live.aspect, base.aspect)
		local rect = MinimapLayout.Rect(MinimapLayout.AreaBase(base, area), live.layout.minimap, 1.0, area)
		MinimapLayout.Apply(MinimapLayout.Components(base, rect, base.aspect), Location.scale)
	end
	anchor = Location.Anchor()
	anchorAt = GetGameTimer()
end

-- Radar nativo: preferencia, modo (sempre/so em veiculo) e motivos de ocultar. So chama o native ao mudar.
local function applyRadar(force)
	local shown = live.showMinimap and not isHidden()
		and (live.minimapMode ~= 'vehicle' or inVehicle or editing)
	if force or shown ~= radarShown then
		radarShown = shown
		DisplayRadar(shown)
	end
end

local function applyPrefs()
	pcall(function()
		exports.coe_ui:SetAccent(live.accent)
	end)
	applyMinimap()
	applyRadar(true)
	Location.hideNative = live.showLocation
	SendNUIMessage({ action = 'prefs', prefs = live })
	SendNUIMessage({ action = 'visible', visible = not isHidden() })
	sendMinimap()
end

local function loadPrefs()
	local raw = GetResourceKvpString(Config.KvpKey)
	local decoded = raw and json.decode(raw) or nil
	prefs = Prefs.sanitize(decoded)
	live = prefs
end

local function savePrefs(next)
	prefs = Prefs.sanitize(next)
	live = prefs
	SetResourceKvp(Config.KvpKey, json.encode(prefs))
	applyPrefs()
	last = nil
end

if Logo and Logo.Init then
	Logo.Init(function() return live end, savePrefs)
end

-- Modo de edicao: o NUI trabalha num rascunho; hudPreview aplica sem salvar,
-- hudDone salva e hudDiscard volta as preferencias salvas.
local function setEditor(open)
	editing = open
	SetNuiFocus(open, open)
	-- No editor minimapa e bussola aparecem mesmo a pe, para poderem ser posicionados.
	applyRadar(false)
	last = nil
	SendNUIMessage({
		action = 'editor',
		open = open,
		prefs = prefs,
		defaults = Prefs.sanitize(nil),
		options = Config.Options
	})
end

local function discardEditor()
	if live ~= prefs then
		live = prefs
		applyPrefs()
		last = nil
	end
	setEditor(false)
end

-- Esconde/mostra o HUD por motivo; use o nome do recurso como motivo. Só volta quando nenhum motivo restar.
-- Se o recurso que escondeu parar, o motivo dele é liberado.
local function setHidden(reason, hidden)
	if type(reason) ~= 'string' or reason == '' then
		return false
	end
	local before = isHidden()
	hiddenBy[reason] = hidden and true or nil
	if before ~= isHidden() then
		applyPrefs()
	end
	return true
end

AddEventHandler('coe_hud:setHidden', setHidden)
exports('SetHidden', setHidden)
exports('IsHidden', isHidden)
exports('SetLogoVisible', function(visible)
	return Logo.SetVisible(visible)
end)
exports('IsLogoVisible', function()
	return Logo.IsVisible()
end)
exports('ToggleLogo', function()
	return Logo.Toggle()
end)

AddEventHandler('coe_talk:client:talking', function(talking)
	SendNUIMessage({ action = 'talking', talking = talking })
end)

AddEventHandler('coe_talk:client:mode', function(mode)
	if type(mode) == 'table' and mode.distance then
		SendNUIMessage({ action = 'mode', distance = mode.distance })
	elseif type(mode) == 'number' then
		SendNUIMessage({ action = 'mode', distance = mode })
	end
end)

-- Reposiciona o HUD no mesmo instante da troca do minimapa, sem esperar o ciclo de 500 ms.
AddEventHandler('coe_map:changed', function(_, scale)
	Location.scale = tonumber(scale) or 1.0
	local before = anchor
	-- Com o estendido aberto o radar nativo nao e movido; a posicao adiada e aplicada ao voltar.
	applyMinimap()
	if not Location.AnchorEquals(before, anchor) then
		sendMinimap()
	end
end)

AddEventHandler('coe_needs:changed', function(snapshot)
	needs = snapshot
end)

RegisterCommand(Config.Command, function()
	if editing then
		discardEditor()
	else
		setEditor(true)
	end
end, false)

RegisterNUICallback('hudSave', function(data, callback)
	savePrefs(data)
	callback({ ok = true, prefs = prefs })
end)

RegisterNUICallback('hudPreview', function(data, callback)
	if not editing then
		callback({ ok = false })
		return
	end
	live = Prefs.sanitize(data)
	applyPrefs()
	last = nil
	callback({ ok = true, prefs = live })
end)

RegisterNUICallback('hudDone', function(data, callback)
	savePrefs(data)
	setEditor(false)
	callback({ ok = true, prefs = prefs })
end)

RegisterNUICallback('hudDiscard', function(_, callback)
	discardEditor()
	callback({ ok = true, prefs = prefs })
end)

RegisterNUICallback('hudReady', function(_, callback)
	applyPrefs()
	last = nil
	callback({ ok = true })
end)

CreateThread(function()
	loadPrefs()
	applyPrefs()
	local ok, current = pcall(function()
		return exports.coe_needs:GetNeeds()
	end)
	if ok and type(current) == 'table' then
		needs = current
	end
	while true do
		local now = GetGameTimer()
		if now - anchorAt >= 500 then
			anchorAt = now
			local current = Location.Anchor()
			if not Location.AnchorEquals(anchor, current) then
				anchor = current
				sendMinimap()
			end
		end
		local ped = PlayerPedId()
		local snapshot = buildSnapshot(ped)
		applyRadar(false)
		if changed(last, snapshot) then
			last = {}
			for key, value in pairs(snapshot) do
				last[key] = value
			end
			SendNUIMessage({ action = 'state', state = last })
		end
		Wait(snapshot.vehicle and Config.VehicleIntervalMs or Config.FootIntervalMs)
	end
end)

AddEventHandler('onResourceStop', function(resourceName)
	if hiddenBy[resourceName] then
		setHidden(resourceName, false)
	end
	if resourceName == GetCurrentResourceName() then
		if editing then
			SetNuiFocus(false, false)
		end
		-- Devolve o radar ao lugar padrao do GTA.
		for name, item in pairs(MinimapLayout.DEFAULTS) do
			SetMinimapComponentPosition(name, 'L', 'B', item.x, item.y, item.w, item.h)
		end
		DisplayRadar(true)
	end
end)
