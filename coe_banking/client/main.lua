local config = BankingConfig
local menuOpen = false
local mode = nil
local busy = false
local promptShown = false
local openedAt = nil
local blips = {}
-- Modos da agência (escolha da conta, conta pessoal e conta empresarial): mesmo balcão, mesmas regras de distância.
local AGENCY_MODES = { agency = true, choose = true, business = true }

local function send(message)
	SendNUIMessage(message)
end

local function setPrompt(prompt)
	local key = prompt and (prompt.title .. '|' .. prompt.options[1].label) or nil
	if key ~= promptShown then
		send({ action = 'prompt', data = prompt })
		promptShown = key
	end
end

local function stopAtmAnimation()
	if mode == 'atm' then
		ClearPedTasks(PlayerPedId())
	end
end

local function closeMenu(notifyServer)
	if not menuOpen then
		return
	end
	stopAtmAnimation()
	menuOpen = false
	mode = nil
	openedAt = nil
	SetNuiFocus(false, false)
	send({ type = 'close' })
	if notifyServer ~= false then
		TriggerServerEvent('coe_banking:closed')
	end
end

local function createBlips()
	for _, agency in ipairs(config.Agencies) do
		local blip = AddBlipForCoord(agency.x + 0.0, agency.y + 0.0, agency.z + 0.0)
		SetBlipSprite(blip, config.Blip.sprite)
		SetBlipColour(blip, config.Blip.color)
		SetBlipScale(blip, config.Blip.scale + 0.0)
		SetBlipAsShortRange(blip, true)
		BeginTextCommandSetBlipName('STRING')
		AddTextComponentSubstringPlayerName('Banco')
		EndTextCommandSetBlipName(blip)
		blips[#blips + 1] = blip
	end
end

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		return
	end
	for _, blip in ipairs(blips) do
		if DoesBlipExist(blip) then
			RemoveBlip(blip)
		end
	end
	if menuOpen then
		stopAtmAnimation()
		SetNuiFocus(false, false)
	end
end)

RegisterNetEvent('coe_banking:open', function(view)
	busy = false
	if type(view) ~= 'table' then
		return
	end
	if view.mode == 'atm' and mode ~= 'atm' then
		TaskStartScenarioInPlace(PlayerPedId(), 'PROP_HUMAN_ATM', 0, true)
	end
	menuOpen = true
	mode = view.mode
	openedAt = GetEntityCoords(PlayerPedId())
	SetNuiFocus(true, true)
	send({ type = 'open', view = view })
end)

RegisterNetEvent('coe_banking:update', function(view)
	busy = false
	if menuOpen and type(view) == 'table' then
		if type(view.mode) == 'string' and (AGENCY_MODES[view.mode] or view.mode == 'atm') then
			mode = view.mode
		end
		send({ type = 'update', view = view })
	end
end)

RegisterNetEvent('coe_banking:pinError', function(remaining)
	busy = false
	send({ type = 'pinError', remaining = remaining })
end)

RegisterNetEvent('coe_banking:failed', function()
	busy = false
	send({ type = 'idle' })
end)

RegisterNetEvent('coe_banking:close', function()
	busy = false
	closeMenu(false)
end)

local function nearestAgency()
	local at = GetEntityCoords(PlayerPedId())
	for _, agency in ipairs(config.Agencies) do
		if #(at - vector3(agency.x, agency.y, agency.z)) <= agency.radius then
			return agency
		end
	end
	return nil
end

local activeAgency = nil

local function registerAgencyZones()
	if not (Core and Core.Zones) then
		return
	end
	Core.Zones.Clear()
	for _, agency in ipairs(config.Agencies) do
		Core.Zones.AddSphere('agency:' .. tostring(agency.id), {
			x = agency.x,
			y = agency.y,
			z = agency.z,
			radius = agency.radius,
			data = agency
		})
	end
end

if Core and Core.Zones then
	Core.Zones.OnInteract(function()
		if menuOpen or busy or not activeAgency then
			return
		end
		if GetVehiclePedIsIn(PlayerPedId(), false) ~= 0 then
			return
		end
		busy = true
		setPrompt(nil)
		TriggerServerEvent('coe_banking:openAgency', activeAgency.id)
		SetTimeout(3000, function()
			busy = false
		end)
	end)
end

CreateThread(function()
	createBlips()
	registerAgencyZones()
	while true do
		local wait = 600
		if menuOpen then
			wait = 250
			activeAgency = nil
			setPrompt(nil)
			-- Afastou-se do balcão ou do caixa: encerra.
			if openedAt and #(GetEntityCoords(PlayerPedId()) - openedAt) > 3.0 then
				closeMenu()
			end
		elseif not busy and GetVehiclePedIsIn(PlayerPedId(), false) == 0 then
			local at = GetEntityCoords(PlayerPedId())
			local zone, _, nearAny = Core and Core.Zones and Core.Zones.Nearest(at.x, at.y, at.z)
			local agency = zone and zone.data or nearestAgency()
			if nearAny or agency then
				wait = 200
			end
			activeAgency = agency
			if agency then
				setPrompt({ title = agency.label, subtitle = 'Banco', options = { { key = 'E', label = 'Atendimento' } } })
			else
				setPrompt(nil)
			end
		else
			activeAgency = nil
			setPrompt(nil)
		end
		Wait(wait)
	end
end)

-- Caixas eletrônicos: muitos são parte do mapa e o raycast não devolve o prop (modelo 0), então o alvo
-- é de superfície: vale quando há um prop de caixa eletrônico perto do ponto mirado.
local atmHashes = {}
for _, model in ipairs(config.AtmModels) do
	atmHashes[#atmHashes + 1] = type(model) == 'string' and GetHashKey(model) or model
end

local function atmNear(hit)
	if not hit then
		return false
	end
	local player = GetEntityCoords(PlayerPedId())
	for _, hash in ipairs(atmHashes) do
		local object = GetClosestObjectOfType(hit.x, hit.y, hit.z, config.AtmSearchRadius + 0.0, hash, false, false, false)
		if object ~= 0 and #(player - GetEntityCoords(object)) <= config.AtmDistance then
			return true
		end
	end
	return false
end

local atmOpenAt = 0
local atmOption = {
	label = 'Usar caixa eletrônico',
	distance = config.AtmReach,
	canInteract = function(_, _, hit)
		return not menuOpen and GetVehiclePedIsIn(PlayerPedId(), false) == 0 and atmNear(hit)
	end,
	onSelect = function()
		-- O servidor tem trava própria; aqui só evita cliques repetidos.
		local now = GetGameTimer()
		if now < atmOpenAt then
			return
		end
		atmOpenAt = now + 1500
		TriggerServerEvent('coe_banking:atmOpen')
	end
}

local function registerAtms()
	if GetResourceState('coetarget') ~= 'started' then
		return
	end
	if not exports.coetarget:AddTargetSurface({ atmOption }) then
		print('[coe_banking] coetarget recusou o alvo dos caixas eletrônicos')
	end
end

-- Um restart do coetarget apaga os registros: registra de novo.
AddEventHandler('coetarget:ready', registerAtms)

CreateThread(function()
	while GetResourceState('coetarget') ~= 'started' do
		Wait(500)
	end
	registerAtms()
end)

RegisterNUICallback('close', function(_, cb)
	closeMenu()
	cb({})
end)

RegisterNUICallback('agency', function(data, cb)
	if menuOpen and AGENCY_MODES[mode] and type(data) == 'table' and type(data.action) == 'string' then
		busy = true
		TriggerServerEvent('coe_banking:agency', data.action, type(data.data) == 'table' and data.data or {})
	end
	cb({})
end)

-- Escolha ou troca da conta na agência (pessoal, uma empresa ou voltar à escolha).
RegisterNUICallback('agencyAccount', function(data, cb)
	if menuOpen and AGENCY_MODES[mode] and type(data) == 'table' and type(data.kind) == 'string' then
		busy = true
		TriggerServerEvent('coe_banking:agencyAccount', data.kind, type(data.id) == 'string' and data.id or nil)
	end
	cb({})
end)

-- Operações da conta empresarial aberta na agência.
RegisterNUICallback('business', function(data, cb)
	if menuOpen and AGENCY_MODES[mode] and type(data) == 'table' and type(data.action) == 'string' then
		busy = true
		TriggerServerEvent('coe_banking:business', data.action, type(data.data) == 'table' and data.data or {})
	end
	cb({})
end)

RegisterNUICallback('atmAuth', function(data, cb)
	if menuOpen and mode == 'atm' and type(data) == 'table' then
		busy = true
		TriggerServerEvent('coe_banking:atmAuth', tonumber(data.cardId), tostring(data.pin or ''))
	end
	cb({})
end)

RegisterNUICallback('atm', function(data, cb)
	if menuOpen and mode == 'atm' and type(data) == 'table' and type(data.action) == 'string' then
		busy = true
		TriggerServerEvent('coe_banking:atm', data.action, type(data.data) == 'table' and data.data or {})
	end
	cb({})
end)
