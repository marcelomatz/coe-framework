-- coe_bank (client): blips e balcões das agências, caixas eletrônicos (alvo de superfície no coetarget) e a tela.
-- Saldo e movimentações ficam no servidor; o client só mostra e pede.
local config = BankConfig

local active = false
local menuOpen = false
local mode = nil
local openedAt = nil
local busy = false
local promptKey = nil
local blips = {}
local pending = {}
local nextRequest = 0

local function send(message)
	SendNUIMessage(message)
end

local function show(kind, message)
	if type(message) == 'string' and message ~= '' then
		pcall(function() exports.coe_notify:Show(kind, message, 4000) end)
	end
end

local function request(kind, payload)
	nextRequest = nextRequest + 1
	local requestId = nextRequest
	local p = promise.new()
	pending[requestId] = p
	SetTimeout(15000, function()
		if pending[requestId] then
			pending[requestId] = nil
			p:resolve({ ok = false, error = 'timeout' })
		end
	end)
	TriggerServerEvent('coe_bank:request', requestId, kind, payload)
	return Citizen.Await(p)
end

RegisterNetEvent('coe_bank:response', function(requestId, result)
	local p = pending[requestId]
	if p then
		pending[requestId] = nil
		p:resolve(type(result) == 'table' and result or { ok = false })
	end
end)

local function setPrompt(prompt)
	local key = prompt and prompt.title or nil
	if key ~= promptKey then
		send({ action = 'prompt', data = prompt })
		promptKey = key
	end
end

local function closeMenu(notifyServer)
	if not menuOpen then
		return
	end
	if mode == 'atm' then
		ClearPedTasks(PlayerPedId())
	end
	menuOpen = false
	mode = nil
	openedAt = nil
	SetNuiFocus(false, false)
	send({ type = 'close' })
	if notifyServer ~= false then
		TriggerServerEvent('coe_bank:closed')
	end
end

local function open(payload)
	if busy or menuOpen then
		return
	end
	busy = true
	setPrompt(nil)
	local result = request('open', payload)
	busy = false
	if not result.ok then
		show('error', result.message)
		return
	end
	if payload.mode == 'atm' then
		TaskStartScenarioInPlace(PlayerPedId(), 'PROP_HUMAN_ATM', 0, true)
	end
	menuOpen = true
	mode = payload.mode
	openedAt = GetEntityCoords(PlayerPedId())
	SetNuiFocus(true, true)
	send({ type = 'open', view = result.view })
end

RegisterNetEvent('coe_bank:close', function()
	closeMenu(false)
end)

-- Blips e caixas eletrônicos (somem quando um pacote assume o banco) -------------------------------------

local function clearBlips()
	for _, blip in ipairs(blips) do
		if DoesBlipExist(blip) then
			RemoveBlip(blip)
		end
	end
	blips = {}
end

local function createBlips()
	clearBlips()
	for _, agency in ipairs(config.Agencies) do
		local blip = AddBlipForCoord(agency.x + 0.0, agency.y + 0.0, agency.z + 0.0)
		SetBlipSprite(blip, config.Blip.sprite)
		SetBlipColour(blip, config.Blip.color)
		SetBlipScale(blip, config.Blip.scale + 0.0)
		SetBlipAsShortRange(blip, true)
		BeginTextCommandSetBlipName('STRING')
		AddTextComponentSubstringPlayerName(config.Blip.label)
		EndTextCommandSetBlipName(blip)
		blips[#blips + 1] = blip
	end
end

-- Muitos caixas fazem parte do mapa e o raycast não devolve o prop (modelo 0): o alvo é de superfície e vale
-- quando há um prop de caixa eletrônico perto do ponto mirado.
local atmHashes = {}
for _, model in ipairs(config.AtmModels) do
	atmHashes[#atmHashes + 1] = type(model) == 'string' and joaat(model) or model
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

local atmOption = {
	label = 'Usar caixa eletrônico',
	distance = config.AtmReach,
	canInteract = function(_, _, hit)
		return active and not menuOpen and not busy and GetVehiclePedIsIn(PlayerPedId(), false) == 0 and atmNear(hit)
	end,
	onSelect = function()
		CreateThread(function()
			open({ mode = 'atm' })
		end)
	end
}

local function registerAtms()
	if not active or GetResourceState('coetarget') ~= 'started' then
		return
	end
	if not exports.coetarget:AddTargetSurface({ atmOption }) then
		print('[coe_bank] coetarget recusou o alvo dos caixas eletrônicos')
	end
end

local function unregisterAtms()
	if GetResourceState('coetarget') == 'started' then
		pcall(function() exports.coetarget:RemoveTargetSurface() end)
	end
end

local function setActive(on)
	if on == active then
		return
	end
	active = on
	if on then
		createBlips()
		registerAtms()
	else
		closeMenu(false)
		setPrompt(nil)
		clearBlips()
		unregisterAtms()
	end
end

AddStateBagChangeHandler('coeBankYielded', 'global', function(_, _, value)
	setActive(not value)
end)

-- Um restart do coetarget apaga os registros: registra de novo.
AddEventHandler('coetarget:ready', registerAtms)

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		return
	end
	clearBlips()
	if menuOpen then
		if mode == 'atm' then
			ClearPedTasks(PlayerPedId())
		end
		SetNuiFocus(false, false)
	end
end)

-- Agências: prompt "E" no balcão ------------------------------------------------------------------------------

local function nearestAgency()
	local at = GetEntityCoords(PlayerPedId())
	for _, agency in ipairs(config.Agencies) do
		if #(at - vector3(agency.x, agency.y, agency.z)) <= agency.radius then
			return agency
		end
	end
	return nil
end

CreateThread(function()
	while GetResourceState('coetarget') ~= 'started' do
		Wait(500)
	end
	setActive(not GlobalState.coeBankYielded)
	while true do
		local wait = 500
		if not active then
			setPrompt(nil)
		elseif menuOpen then
			setPrompt(nil)
			if openedAt and #(GetEntityCoords(PlayerPedId()) - openedAt) > config.SessionRadius then
				closeMenu()
			end
		elseif not busy and GetVehiclePedIsIn(PlayerPedId(), false) == 0 then
			local agency = nearestAgency()
			if agency then
				wait = 0
				setPrompt({ title = agency.label, subtitle = config.Blip.label, options = { { key = 'E', label = 'Atendimento' } } })
				if IsControlJustReleased(0, 38) then
					CreateThread(function()
						open({ mode = 'agency', agencyId = agency.id })
					end)
				end
			else
				setPrompt(nil)
			end
		else
			setPrompt(nil)
		end
		Wait(wait)
	end
end)

-- NUI ---------------------------------------------------------------------------------------------------------

RegisterNUICallback('close', function(_, cb)
	closeMenu()
	cb({})
end)

RegisterNUICallback('action', function(data, cb)
	if not menuOpen or type(data) ~= 'table' or type(data.action) ~= 'string' then
		return cb({ ok = false, error = 'unavailable' })
	end
	local result = request('action', { action = data.action, data = type(data.data) == 'table' and data.data or {} })
	if result.ok and result.message then
		show('success', result.message)
	end
	if result.error == 'too_far' or result.error == 'unavailable' then
		closeMenu()
	end
	cb(result)
end)
