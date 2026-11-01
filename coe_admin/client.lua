local panelOpen = false
local capturing = false
local requestSequence = 0

local function nextRequestId()
	requestSequence = requestSequence + 1
	return requestSequence
end

local function closePanel()
	panelOpen = false
	capturing = false
	pcall(function() exports.coe_notify:Prompt(nil) end)
	Tablet.Stop()
	SetNuiFocusKeepInput(false)
	SetNuiFocus(false, false)
	SendNUIMessage({ action = 'close' })
end

RegisterCommand(Config.Command, function()
	if panelOpen then
		closePanel()
		return
	end

	TriggerServerEvent('coe_admin:requestOpen')
end, false)

if Config.OpenKey then
	RegisterCommand('+coe_admin_toggle', function()
		if panelOpen then
			closePanel()
			return
		end
		TriggerServerEvent('coe_admin:requestOpen', true)
	end, false)
	RegisterCommand('-coe_admin_toggle', function() end, false)
	RegisterKeyMapping('+coe_admin_toggle', 'Abrir painel administrativo', 'keyboard', Config.OpenKey)
end

RegisterNetEvent('coe_admin:openResult', function(success, data)
	if not success then
		closePanel()
		if data then
			exports.coe_notify:Show('error', data)
		end
		return
	end

	panelOpen = true
	Tablet.Start()
	SetNuiFocusKeepInput(false)
	SetNuiFocus(true, true)
	SendNUIMessage({ action = 'open', data = data })
end)

-- Botão "Ferramentas" do painel: fecha o painel e abre as ferramentas da staff (tools/client.lua).
RegisterNUICallback('openTools', function(_, cb)
	closePanel()
	AdminToolsOpen()
	cb({ ok = true })
end)

RegisterNetEvent('coe_admin:panelData', function(data)
	if panelOpen and type(data) == 'table' then
		SendNUIMessage({ action = 'refresh', data = data })
	end
end)

RegisterNetEvent('coe_admin:result', function(action, requestId, success, message)
	SendNUIMessage({
		action = 'result',
		requestId = requestId,
		operation = action,
		success = success == true,
		message = message
	})
end)

RegisterNUICallback('close', function(_, callback)
	closePanel()
	callback({ ok = true })
end)

RegisterNUICallback('refresh', function(_, callback)
	TriggerServerEvent('coe_admin:refresh')
	callback({ ok = true })
end)

RegisterNUICallback('giveItem', function(data, callback)
	if type(data) ~= 'table' then
		callback({ ok = false })
		return
	end

	local requestId = nextRequestId()
	TriggerServerEvent(
		'coe_admin:giveItem',
		requestId,
		tonumber(data.playerId),
		data.itemName,
		tonumber(data.count),
		data.metadata
	)
	callback({ ok = true, requestId = requestId })
end)

RegisterNUICallback('giveItems', function(data, callback)
	if type(data) ~= 'table'
		or type(data.items) ~= 'table'
		or #data.items < 1
		or #data.items > 64 then
		callback({ ok = false })
		return
	end

	local targetId = tonumber(data.playerId)
	if not targetId or targetId % 1 ~= 0 then
		callback({ ok = false })
		return
	end

	local requestIds = {}
	for index, item in ipairs(data.items) do
		if type(item) ~= 'table'
			or type(item.name) ~= 'string'
			or type(item.count) ~= 'number'
			or item.count % 1 ~= 0
			or item.count < 1
			or item.count > 999 then
			callback({ ok = false })
			return
		end
		requestIds[index] = nextRequestId()
	end

	callback({ ok = true, requestIds = requestIds })
	CreateThread(function()
		Wait(100)
		for index, item in ipairs(data.items) do
			TriggerServerEvent('coe_admin:giveItem', requestIds[index], targetId, item.name, item.count, data.metadata)
			if index < #data.items then Wait(250) end
		end
	end)
end)

RegisterNUICallback('setStaffRole', function(data, callback)
	if type(data) ~= 'table'
		or not Core.Functions.IsInteger(data.targetId)
		or type(data.role) ~= 'string' then
		callback({ ok = false })
		return
	end

	local requestId = nextRequestId()
	TriggerServerEvent('coe_admin:setStaffRole', requestId, data.targetId, data.role)
	callback({ ok = true, requestId = requestId })
end)

RegisterNUICallback('removeStaff', function(data, callback)
	if type(data) ~= 'table' then
		callback({ ok = false })
		return
	end

	local requestId = nextRequestId()
	TriggerServerEvent('coe_admin:removeStaff', requestId, data.license)
	callback({ ok = true, requestId = requestId })
end)

local function simpleCallback(name, event, check)
	RegisterNUICallback(name, function(data, callback)
		local args = type(data) == 'table' and check(data) or nil
		if not args then
			callback({ ok = false })
			return
		end
		local requestId = nextRequestId()
		TriggerServerEvent(event, requestId, table.unpack(args))
		callback({ ok = true, requestId = requestId })
	end)
end

simpleCallback('saveFaction', 'coe_admin:saveFaction', function(data)
	return type(data.faction) == 'table' and { data.faction } or nil
end)
simpleCallback('deleteFaction', 'coe_admin:deleteFaction', function(data)
	return type(data.id) == 'string' and { data.id } or nil
end)
simpleCallback('getFactionMembers', 'coe_admin:getFactionMembers', function(data)
	return type(data.id) == 'string' and { data.id } or nil
end)
simpleCallback('setFactionMember', 'coe_admin:setFactionMember', function(data)
	if type(data.id) == 'string' and type(data.characterId) == 'string' and Core.Functions.IsInteger(data.grade) then
		return { data.id, data.characterId:sub(1, 20), data.grade }
	end
end)
simpleCallback('removeFactionMember', 'coe_admin:removeFactionMember', function(data)
	if type(data.id) == 'string' and type(data.characterId) == 'string' then
		return { data.id, data.characterId:sub(1, 20) }
	end
end)

RegisterNetEvent('coe_admin:factionMembersResult', function(requestId, factionId, members, errorCode)
	SendNUIMessage({ action = 'factionMembersResult', requestId = requestId, factionId = factionId, members = members, error = errorCode })
end)
RegisterNUICallback('restartResource', function(data, callback)
	if type(data) ~= 'table' or type(data.name) ~= 'string' then
		callback({ ok = false })
		return
	end

	local requestId = nextRequestId()
	TriggerServerEvent('coe_admin:restartResource', requestId, data.name)
	callback({ ok = true, requestId = requestId })
end)

RegisterNUICallback('setTheme', function(data, callback)
	if type(data) ~= 'table' or type(data.name) ~= 'string' then
		callback({ ok = false })
		return
	end

	local requestId = nextRequestId()
	TriggerServerEvent('coe_admin:setTheme', requestId, data.name)
	callback({ ok = true, requestId = requestId })
end)

RegisterNetEvent('coe_admin:characterResults', function(requestId, results, errorCode)
	SendNUIMessage({ action = 'characterResults', requestId = requestId, results = results, error = errorCode })
end)

RegisterNetEvent('coe_admin:profileResult', function(requestId, profile, errorCode)
	SendNUIMessage({ action = 'profileResult', requestId = requestId, profile = profile, error = errorCode })
end)

RegisterNetEvent('coe_admin:bankingAccountResult', function(requestId, account, errorCode)
	SendNUIMessage({ action = 'bankingAccountResult', requestId = requestId, account = account, error = errorCode })
end)

RegisterNUICallback('bankingAccount', function(data, callback)
	if type(data) ~= 'table' or type(data.characterId) ~= 'string' then
		callback({ ok = false })
		return
	end
	local requestId = nextRequestId()
	TriggerServerEvent('coe_admin:bankingAccount', requestId, data.characterId:sub(1, 20))
	callback({ ok = true, requestId = requestId })
end)

RegisterNetEvent('coe_admin:bankingRequestsResult', function(requestId, requests, errorCode)
	SendNUIMessage({ action = 'bankingRequestsResult', requestId = requestId, requests = requests, error = errorCode })
end)

RegisterNUICallback('bankingRequests', function(_, callback)
	local requestId = nextRequestId()
	TriggerServerEvent('coe_admin:bankingRequests', requestId)
	callback({ ok = true, requestId = requestId })
end)

-- Contas empresariais (aba Banco > Empresas): lista ou uma conta com o extrato filtrado.
RegisterNetEvent('coe_admin:bankingBusinessResult', function(requestId, result, errorCode)
	SendNUIMessage({ action = 'bankingBusinessResult', requestId = requestId, result = result, error = errorCode })
end)

RegisterNUICallback('bankingBusiness', function(data, callback)
	if type(data) ~= 'table' or (data.op ~= 'list' and data.op ~= 'account') then
		callback({ ok = false })
		return
	end
	local requestId = nextRequestId()
	TriggerServerEvent('coe_admin:bankingBusiness', requestId, data.op, type(data.businessId) == 'string' and data.businessId:sub(1, 32) or nil,
		type(data.filter) == 'table' and data.filter or {})
	callback({ ok = true, requestId = requestId })
end)

RegisterNUICallback('bankingAction', function(data, callback)
	if type(data) ~= 'table' or type(data.action) ~= 'string' or type(data.payload) ~= 'table' then
		callback({ ok = false })
		return
	end
	local requestId = nextRequestId()
	TriggerServerEvent('coe_admin:bankingAction', requestId, data.action, data.payload)
	callback({ ok = true, requestId = requestId })
end)

RegisterNUICallback('cryptoAction', function(data, callback)
	if type(data) ~= 'table' or type(data.action) ~= 'string' or type(data.payload) ~= 'table' then
		callback({ ok = false })
		return
	end
	local requestId = nextRequestId()
	TriggerServerEvent('coe_admin:cryptoAction', requestId, data.action, data.payload)
	callback({ ok = true, requestId = requestId })
end)

RegisterNUICallback('cryptoInspect', function(data, callback)
	if type(data) ~= 'table' or type(data.address) ~= 'string' then
		callback({ ok = false })
		return
	end
	local requestId = nextRequestId()
	TriggerServerEvent('coe_admin:cryptoInspect', requestId, data.address:sub(1, 64))
	callback({ ok = true, requestId = requestId })
end)

RegisterNetEvent('coe_admin:cryptoInspectResult', function(requestId, result, errorCode)
	SendNUIMessage({ action = 'cryptoInspectResult', requestId = requestId, result = result, error = errorCode })
end)

RegisterNUICallback('getProfile', function(data, callback)
	if type(data) ~= 'table' or type(data.characterId) ~= 'string' then
		callback({ ok = false })
		return
	end
	local requestId = nextRequestId()
	TriggerServerEvent('coe_admin:getProfile', requestId, data.characterId:sub(1, 20))
	callback({ ok = true, requestId = requestId })
end)

RegisterNUICallback('searchCharacters', function(data, callback)
	if type(data) ~= 'table' or type(data.term) ~= 'string' then
		callback({ ok = false })
		return
	end
	local requestId = nextRequestId()
	TriggerServerEvent('coe_admin:searchCharacters', requestId, data.term:sub(1, 64))
	callback({ ok = true, requestId = requestId })
end)

RegisterNUICallback('saveBusiness', function(data, callback)
	if type(data) ~= 'table' or type(data.business) ~= 'table' then
		callback({ ok = false })
		return
	end

	local requestId = nextRequestId()
	TriggerServerEvent('coe_admin:saveBusiness', requestId, data.business)
	callback({ ok = true, requestId = requestId })
end)

RegisterNUICallback('deleteBusiness', function(data, callback)
	if type(data) ~= 'table' or type(data.id) ~= 'string' then
		callback({ ok = false })
		return
	end

	local requestId = nextRequestId()
	TriggerServerEvent('coe_admin:deleteBusiness', requestId, data.id)
	callback({ ok = true, requestId = requestId })
end)

RegisterNUICallback('saveGarage', function(data, callback)
	if type(data) ~= 'table' or type(data.garage) ~= 'table' then
		callback({ ok = false })
		return
	end

	local requestId = nextRequestId()
	TriggerServerEvent('coe_admin:saveGarage', requestId, data.garage)
	callback({ ok = true, requestId = requestId })
end)

RegisterNUICallback('deleteGarage', function(data, callback)
	if type(data) ~= 'table' or type(data.id) ~= 'string' then
		callback({ ok = false })
		return
	end

	local requestId = nextRequestId()
	TriggerServerEvent('coe_admin:deleteGarage', requestId, data.id)
	callback({ ok = true, requestId = requestId })
end)

RegisterNUICallback('saveRental', function(data, callback)
	if type(data) ~= 'table' or type(data.station) ~= 'table' then
		callback({ ok = false })
		return
	end
	local requestId = nextRequestId()
	TriggerServerEvent('coe_admin:saveRental', requestId, data.station)
	callback({ ok = true, requestId = requestId })
end)

RegisterNUICallback('deleteRental', function(data, callback)
	if type(data) ~= 'table' or type(data.id) ~= 'string' then
		callback({ ok = false })
		return
	end
	local requestId = nextRequestId()
	TriggerServerEvent('coe_admin:deleteRental', requestId, data.id)
	callback({ ok = true, requestId = requestId })
end)

RegisterNUICallback('craftCatalog', function(data, callback)
	if type(data) ~= 'table' or type(data.op) ~= 'string' then
		callback({ ok = false })
		return
	end

	local requestId = nextRequestId()
	TriggerServerEvent('coe_admin:craftCatalog', requestId, data.op, data.payload)
	callback({ ok = true, requestId = requestId })
end)

RegisterNUICallback('amzgCatalog', function(data, callback)
	if type(data) ~= 'table' or type(data.op) ~= 'string' then
		callback({ ok = false })
		return
	end

	local requestId = nextRequestId()
	TriggerServerEvent('coe_admin:amzgCatalog', requestId, data.op, data.payload)
	callback({ ok = true, requestId = requestId })
end)

RegisterNUICallback('deepweb', function(data, callback)
	if type(data) ~= 'table' or type(data.op) ~= 'string' then
		callback({ ok = false })
		return
	end

	local requestId = nextRequestId()
	TriggerServerEvent('coe_admin:deepweb', requestId, data.op, data.payload)
	callback({ ok = true, requestId = requestId })
end)

-- Imprensa: consultas sob demanda (anúncios, matérias, estoque) e ações.
RegisterNetEvent('coe_admin:newsData', function(requestId, kind, result, errorCode)
	SendNUIMessage({ action = 'newsData', requestId = requestId, kind = kind, result = result, error = errorCode })
end)

RegisterNUICallback('newsQuery', function(data, callback)
	if type(data) ~= 'table' or type(data.kind) ~= 'string' or type(data.payload) ~= 'table' then
		callback({ ok = false })
		return
	end
	local requestId = nextRequestId()
	TriggerServerEvent('coe_admin:newsQuery', requestId, data.kind, data.payload)
	callback({ ok = true, requestId = requestId })
end)

RegisterNUICallback('newsAction', function(data, callback)
	if type(data) ~= 'table' or type(data.op) ~= 'string' or type(data.payload) ~= 'table' then
		callback({ ok = false })
		return
	end
	local requestId = nextRequestId()
	TriggerServerEvent('coe_admin:newsAction', requestId, data.op, data.payload)
	callback({ ok = true, requestId = requestId })
end)

RegisterNUICallback('saveDoor', function(data, callback)
	if type(data) ~= 'table' or type(data.door) ~= 'table' then
		callback({ ok = false })
		return
	end

	local requestId = nextRequestId()
	TriggerServerEvent('coe_admin:saveDoor', requestId, data.door)
	callback({ ok = true, requestId = requestId })
end)

RegisterNUICallback('deleteDoor', function(data, callback)
	if type(data) ~= 'table' or type(data.id) ~= 'string' then
		callback({ ok = false })
		return
	end

	local requestId = nextRequestId()
	TriggerServerEvent('coe_admin:deleteDoor', requestId, data.id)
	callback({ ok = true, requestId = requestId })
end)

RegisterNUICallback('saveProperty', function(data, callback)
	if type(data) ~= 'table' or type(data.property) ~= 'table' then
		callback({ ok = false })
		return
	end

	local requestId = nextRequestId()
	TriggerServerEvent('coe_admin:saveProperty', requestId, data.property)
	callback({ ok = true, requestId = requestId })
end)

RegisterNUICallback('deleteProperty', function(data, callback)
	if type(data) ~= 'table' or type(data.id) ~= 'string' then
		callback({ ok = false })
		return
	end

	local requestId = nextRequestId()
	TriggerServerEvent('coe_admin:deleteProperty', requestId, data.id)
	callback({ ok = true, requestId = requestId })
end)

RegisterNUICallback('housingContracts', function(data, callback)
	if type(data) ~= 'table' or type(data.propertyId) ~= 'string' then
		callback({ ok = false })
		return
	end
	local requestId = nextRequestId()
	TriggerServerEvent('coe_admin:housingContracts', requestId, data.propertyId)
	callback({ ok = true, requestId = requestId })
end)

RegisterNetEvent('coe_admin:housingContractsResult', function(requestId, propertyId, contracts, errorCode)
	SendNUIMessage({ action = 'housingContractsResult', requestId = requestId, propertyId = propertyId, contracts = contracts, error = errorCode })
end)

RegisterNUICallback('housingEndContract', function(data, callback)
	if type(data) ~= 'table' or (data.kind ~= 'tenancy' and data.kind ~= 'lease') or type(data.id) ~= 'number' then
		callback({ ok = false })
		return
	end
	local requestId = nextRequestId()
	TriggerServerEvent('coe_admin:housingEndContract', requestId, data.kind, data.id)
	callback({ ok = true, requestId = requestId })
end)

RegisterNUICallback('fleetAdd', function(data, callback)
	if type(data) ~= 'table' or type(data.garageId) ~= 'string' or type(data.model) ~= 'string' then
		callback({ ok = false })
		return
	end

	local requestId = nextRequestId()
	TriggerServerEvent('coe_admin:fleetAdd', requestId, data.garageId, data.model)
	callback({ ok = true, requestId = requestId })
end)

RegisterNUICallback('fleetRemove', function(data, callback)
	if type(data) ~= 'table' or type(data.garageId) ~= 'string' or type(data.vehicleId) ~= 'string' then
		callback({ ok = false })
		return
	end

	local requestId = nextRequestId()
	TriggerServerEvent('coe_admin:fleetRemove', requestId, data.garageId, data.vehicleId)
	callback({ ok = true, requestId = requestId })
end)

-- Marcação no mundo: o painel some, o admin anda até o local e confirma com E (Enter conclui listas, Backspace cancela).
local CAPTURE_PICKUP, CAPTURE_DONE, CAPTURE_CANCEL = 38, 191, 177

local function round2(value)
	return math.floor(value * 100 + 0.5) / 100
end

-- Instruções da marcação no aviso de interação padrão (exports.coe_notify:Prompt). Só reenvia quando muda.
local capturePromptKey = nil

local function capturePrompt(key, data)
	if key == capturePromptKey then
		return
	end
	capturePromptKey = key
	pcall(function()
		exports.coe_notify:Prompt(key and data or nil)
	end)
end

local function finishCapture(result)
	capturing = false
	capturePrompt(nil)
	if not panelOpen then
		return
	end
	Tablet.Start()
	SetNuiFocus(true, true)
	SendNUIMessage({ action = 'captureDone', data = result })
end

RegisterNUICallback('capture', function(data, callback)
	if not panelOpen or capturing or type(data) ~= 'table' then
		callback({ ok = false })
		return
	end

	local multi = data.multi == true
	local minimum = multi and math.min(math.max(math.floor(tonumber(data.min) or 1), 1), 16) or 1
	local maximum = multi and 16 or 1
	local label = tostring(data.label or 'ponto'):gsub('[~<>%c]', ''):sub(1, 40)
	local shown = {}
	if type(data.preview) == 'table' then
		for index, entry in ipairs(data.preview) do
			if index > 64 then break end
			if type(entry) == 'table' and tonumber(entry.x) and tonumber(entry.y) and tonumber(entry.z) then
				shown[#shown + 1] = { x = entry.x + 0.0, y = entry.y + 0.0, z = entry.z + 0.0 }
			end
		end
	end

	capturing = true
	Tablet.Stop()
	SetNuiFocus(false, false)
	SendNUIMessage({ action = 'captureStart' })
	callback({ ok = true })

	CreateThread(function()
		local points = {}
		while capturing do
			Wait(0)
			if multi then
				capturePrompt('points:' .. #points, {
					title = ('Marcando %s'):format(label),
					subtitle = ('%d/%d pontos · mínimo %d'):format(#points, maximum, minimum),
					options = { { key = 'E', label = 'Adicionar ponto' }, { key = 'Enter', label = 'Concluir' }, { key = 'Backspace', label = 'Cancelar' } }
				})
			else
				capturePrompt('point', {
					title = ('Marcando %s'):format(label),
					subtitle = 'Posição atual',
					options = { { key = 'E', label = 'Confirmar posição' }, { key = 'Backspace', label = 'Cancelar' } }
				})
			end
			for _, entry in ipairs(shown) do
				DrawMarker(28, entry.x, entry.y, entry.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.35, 0.35, 0.35, 196, 223, 155, 140, false, false, 2, false, nil, nil, false)
			end
			for _, entry in ipairs(points) do
				DrawMarker(28, entry.x, entry.y, entry.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.35, 0.35, 0.35, 255, 200, 80, 180, false, false, 2, false, nil, nil, false)
			end

			if IsControlJustReleased(0, CAPTURE_PICKUP) then
				local at = GetEntityCoords(PlayerPedId())
				local entry = { x = round2(at.x), y = round2(at.y), z = round2(at.z), heading = round2(GetEntityHeading(PlayerPedId())) }
				if not multi then
					finishCapture({ point = entry })
					return
				end
				if #points < maximum then
					points[#points + 1] = entry
				end
			elseif IsControlJustReleased(0, CAPTURE_DONE) and multi and #points >= minimum then
				finishCapture({ points = points })
				return
			elseif IsControlJustReleased(0, CAPTURE_CANCEL) then
				finishCapture({ cancelled = true })
				return
			end
		end
		capturePrompt(nil)
	end)
end)

-- Mira em portas (coe_doors): raio da câmera até um objeto; E marca a folha (até 2), Enter conclui, Backspace cancela.
local function round3(value)
	return math.floor(value * 1000 + 0.5) / 1000
end

local function aimedObject(ped)
	local origin = GetGameplayCamCoord()
	local rotation = GetGameplayCamRot(2)
	local pitch, yaw = math.rad(rotation.x), math.rad(rotation.z)
	local direction = vector3(-math.sin(yaw) * math.abs(math.cos(pitch)), math.cos(yaw) * math.abs(math.cos(pitch)), math.sin(pitch))
	local target = origin + direction * 12.0
	local probe = StartExpensiveSynchronousShapeTestLosProbe(origin.x, origin.y, origin.z, target.x, target.y, target.z, 16, ped, 4)
	local _, hit, _, _, entity = GetShapeTestResult(probe)
	if hit == 1 and entity and entity ~= 0 and DoesEntityExist(entity) and GetEntityType(entity) == 3 then
		return entity
	end
	return nil
end

RegisterNUICallback('doorAim', function(data, callback)
	if not panelOpen or capturing then
		callback({ ok = false })
		return
	end

	capturing = true
	Tablet.Stop()
	SetNuiFocus(false, false)
	SendNUIMessage({ action = 'captureStart' })
	callback({ ok = true })

	CreateThread(function()
		local leaves, picked = {}, {}
		local outlined = nil
		local function clearOutline()
			if outlined and DoesEntityExist(outlined) then
				SetEntityDrawOutline(outlined, false)
			end
			outlined = nil
		end
		while capturing do
			Wait(0)
			local entity = aimedObject(PlayerPedId())
			if entity ~= outlined then
				clearOutline()
				if entity then
					SetEntityDrawOutlineColor(255, 200, 80, 255)
					SetEntityDrawOutline(entity, true)
					outlined = entity
				end
			end
			capturePrompt('doors:' .. #leaves, {
				title = 'Mire na porta',
				subtitle = ('%d/2 folhas marcadas'):format(#leaves),
				options = { { key = 'E', label = 'Marcar folha' }, { key = 'Enter', label = 'Concluir' }, { key = 'Backspace', label = 'Cancelar' } }
			})
			for _, leaf in ipairs(leaves) do
				DrawMarker(28, leaf.x, leaf.y, leaf.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.2, 0.2, 0.2, 196, 223, 155, 180, false, false, 2, false, nil, nil, false)
			end

			if IsControlJustReleased(0, CAPTURE_PICKUP) and entity and not picked[entity] and #leaves < 2 then
				local at = GetEntityCoords(entity)
				picked[entity] = true
				leaves[#leaves + 1] = { model = GetEntityModel(entity), x = round3(at.x), y = round3(at.y), z = round3(at.z) }
			elseif IsControlJustReleased(0, CAPTURE_DONE) and #leaves > 0 then
				clearOutline()
				finishCapture({ doors = leaves })
				return
			elseif IsControlJustReleased(0, CAPTURE_CANCEL) then
				clearOutline()
				finishCapture({ cancelled = true })
				return
			end
		end
		clearOutline()
		capturePrompt(nil)
	end)
end)

-- Catálogo de interiores (coe_housing): visitar para conferir/ajustar o ponto e gerar miniaturas com screenshot-basic.
-- Durante a visita o admin fica num mundo só dele (BeginPreview/EndPreview no coe_housing).
local previewWaiter, thumbReadyWaiter, thumbSavedWaiter
local shooting = false

local function awaitWithTimeout(assign, timeoutMs, fallback)
	local waiter = promise.new()
	local settled = false
	local function settle(value)
		if not settled then
			settled = true
			waiter:resolve(value)
		end
	end
	assign(settle)
	SetTimeout(timeoutMs, function()
		settle(fallback)
	end)
	return Citizen.Await(waiter)
end

RegisterNetEvent('coe_admin:housingPreviewResult', function(ok, errorCode)
	if previewWaiter then
		previewWaiter({ ok = ok == true, error = errorCode })
	end
end)

local function setPreview(active)
	local result = awaitWithTimeout(function(settle)
		previewWaiter = settle
		TriggerServerEvent('coe_admin:housingPreview', active)
	end, 5000, { ok = false, error = 'timeout' })
	previewWaiter = nil
	return result
end

RegisterNetEvent('coe_admin:housingThumbsResult', function(requestId, thumbs, errorCode)
	SendNUIMessage({ action = 'housingThumbsResult', requestId = requestId, thumbs = thumbs, error = errorCode })
end)

RegisterNetEvent('coe_admin:housingThumbSaved', function(interiorId, errorCode)
	if thumbSavedWaiter then
		thumbSavedWaiter(errorCode or false)
	end
end)

RegisterNUICallback('housingThumbs', function(_, callback)
	local requestId = nextRequestId()
	TriggerServerEvent('coe_admin:housingThumbs', requestId)
	callback({ ok = true, requestId = requestId })
end)

-- A NUI devolve a miniatura já reduzida (canvas) para enviar ao servidor.
RegisterNUICallback('housingThumbReady', function(data, callback)
	callback({ ok = true })
	if thumbReadyWaiter then
		thumbReadyWaiter(type(data) == 'table' and type(data.data) == 'string' and data.data or false)
	end
end)

local function hidePanelForTrip()
	capturing = true
	Tablet.Stop()
	SetNuiFocus(false, false)
	SendNUIMessage({ action = 'captureStart' })
end

-- Origem da visita em andamento, para restaurar o admin se o resource parar no meio.
local tripOrigin = nil

local function originOf(ped)
	local at = GetEntityCoords(ped)
	tripOrigin = { x = at.x, y = at.y, z = at.z, heading = GetEntityHeading(ped) }
	return tripOrigin
end

local function tripPoint(entry, raw)
	if type(raw) == 'table' and tonumber(raw.x) and tonumber(raw.y) and tonumber(raw.z) then
		return { x = tonumber(raw.x) + 0.0, y = tonumber(raw.y) + 0.0, z = tonumber(raw.z) + 0.0, heading = (tonumber(raw.heading) or 0.0) + 0.0 }
	end
	if not entry then
		return nil
	end
	return { x = entry.x + 0.0, y = entry.y + 0.0, z = entry.z + 0.0, heading = (entry.heading or 0.0) + 0.0 }
end

local VISIT_MARKS = {
	interior = 'Marcar ponto do interior',
	stash = 'Marcar o baú',
	none = 'Voltar'
}

-- Visita um interior do catálogo (id) ou um ponto qualquer (point, ex.: interior personalizado de um imóvel).
-- mark diz o que o E captura: o ponto do interior, o ponto do baú ou nada (só olhar).
RegisterNUICallback('housingVisit', function(data, callback)
	data = type(data) == 'table' and data or {}
	local entry = type(data.id) == 'string' and HousingInteriors.byId[data.id] or nil
	local destination = tripPoint(entry, data.point)
	local mark = VISIT_MARKS[data.mark] and data.mark or 'interior'
	if not panelOpen or capturing or not destination or (data.id ~= nil and not entry) then
		callback({ ok = false })
		return
	end
	callback({ ok = true })
	hidePanelForTrip()

	CreateThread(function()
		local ped = PlayerPedId()
		local origin = originOf(ped)
		local started = setPreview(true)
		if not started.ok then
			tripOrigin = nil
			finishCapture({ cancelled = true, error = started.error })
			return
		end
		HousingInteriorLoader.Teleport(destination, entry and entry.id or data.interiorId, true)
		local result = { cancelled = true }
		local title = entry and entry.label or (type(data.label) == 'string' and data.label:sub(1, 48) or 'interior')
		local visitOptions = mark == 'none'
			and { { key = 'E', label = 'Voltar' }, { key = 'Backspace', label = 'Voltar' } }
			or { { key = 'E', label = VISIT_MARKS[mark] }, { key = 'Backspace', label = 'Voltar sem marcar' } }
		capturePrompt('visit', { title = ('Visitando %s'):format(title), subtitle = 'Interior', options = visitOptions })
		while capturing do
			Wait(0)
			if IsControlJustReleased(0, CAPTURE_PICKUP) then
				if mark == 'none' then
					break
				end
				local at = GetEntityCoords(ped)
				result = { interiorId = entry and entry.id or nil, mark = mark, point = { x = round2(at.x), y = round2(at.y), z = round2(at.z), heading = round2(GetEntityHeading(ped)) } }
				break
			elseif IsControlJustReleased(0, CAPTURE_CANCEL) then
				break
			end
		end
		capturePrompt(nil)
		HousingInteriorLoader.Teleport(origin, nil, true)
		tripOrigin = nil
		setPreview(false)
		finishCapture(result)
	end)
end)

-- Distância livre a partir de (x, y, z) na direção do heading (0 = norte, anti-horário), até 25 m.
local function clearance(x, y, z, heading, ped)
	local rad = math.rad(heading)
	local tx, ty = x - math.sin(rad) * 25.0, y + math.cos(rad) * 25.0
	local handle = StartExpensiveSynchronousShapeTestLosProbe(x, y, z, tx, ty, z, 1, ped, 0)
	local _, hit, endCoords = GetShapeTestResult(handle)
	if hit == 1 then
		return #(vector3(x, y, z) - endCoords)
	end
	return 25.0
end

-- Escolhe a direção com mais espaço livre (média de três raios) e recua a câmera para enquadrar melhor.
local function bestView(x, y, z, ped)
	local distances = {}
	for step = 0, 23 do
		distances[step] = clearance(x, y, z, step * 15.0, ped)
	end
	local best, bestScore = 0, -1.0
	for step = 0, 23 do
		local score = distances[(step + 23) % 24] + distances[step] * 2 + distances[(step + 1) % 24]
		if score > bestScore then
			best, bestScore = step, score
		end
	end
	local heading = best * 15.0
	local back = math.max(0.0, math.min(1.5, distances[(best + 12) % 24] - 0.4))
	local rad = math.rad(heading)
	return heading, x + math.sin(rad) * back, y - math.cos(rad) * back
end

local function captureThumb(entry)
	local ped = PlayerPedId()
	HousingInteriorLoader.Teleport({ x = entry.x, y = entry.y, z = entry.z, heading = 0.0 }, entry.id, false)
	FreezeEntityPosition(ped, true)
	SetEntityVisible(ped, false, false)
	Wait(600)
	local x, y, z = entry.x + 0.0, entry.y + 0.0, entry.z + 0.6
	local heading, cx, cy = bestView(x, y, z, ped)
	local cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', cx, cy, z, -6.0, 0.0, heading, 70.0, false, 2)
	SetCamActive(cam, true)
	RenderScriptCams(true, false, 0, true, true)
	shooting = true
	Wait(1800)
	local image = awaitWithTimeout(function(settle)
		exports['screenshot-basic']:requestScreenshot({ encoding = 'jpg', quality = 0.92 }, function(data)
			settle(type(data) == 'string' and data or false)
		end)
	end, 10000, false)
	shooting = false
	RenderScriptCams(false, false, 0, true, true)
	DestroyCam(cam, false)
	return image
end

RegisterNUICallback('housingGenerateThumbs', function(data, callback)
	local ids = type(data) == 'table' and type(data.ids) == 'table' and data.ids or {}
	local queue = {}
	for _, id in ipairs(ids) do
		if type(id) == 'string' and HousingInteriors.byId[id] then
			queue[#queue + 1] = HousingInteriors.byId[id]
		end
		if #queue >= #HousingInteriors.list then
			break
		end
	end
	if not panelOpen or capturing or #queue == 0 then
		callback({ ok = false })
		return
	end
	if GetResourceState('screenshot-basic') ~= 'started' then
		callback({ ok = false, error = 'no_screenshot' })
		return
	end
	callback({ ok = true })
	hidePanelForTrip()

	CreateThread(function()
		local ped = PlayerPedId()
		local origin = originOf(ped)
		local started = setPreview(true)
		if not started.ok then
			tripOrigin = nil
			finishCapture({ cancelled = true, error = started.error })
			return
		end
		CreateThread(function()
			while capturing do
				HideHudAndRadarThisFrame()
				if not shooting then
					capturePrompt('thumbs', {
						title = 'Gerando miniaturas',
						subtitle = 'Interiores do catálogo',
						options = { { key = 'Backspace', label = 'Cancelar' } }
					})
					if IsControlJustReleased(0, CAPTURE_CANCEL) then
						capturing = false
					end
				else
					capturePrompt(nil)
				end
				Wait(0)
			end
			capturePrompt(nil)
		end)
		local done, failed = 0, 0
		for _, entry in ipairs(queue) do
			if not capturing then
				break
			end
			local image = captureThumb(entry)
			local small = image and awaitWithTimeout(function(settle)
				thumbReadyWaiter = settle
				SendNUIMessage({ action = 'housingThumbRaw', id = entry.id, data = image })
			end, 8000, false)
			thumbReadyWaiter = nil
			local saveError = 'capture_failed'
			if small then
				saveError = awaitWithTimeout(function(settle)
					thumbSavedWaiter = settle
					TriggerLatentServerEvent('coe_admin:housingThumb', 100000, entry.id, small)
				end, 15000, 'timeout')
				thumbSavedWaiter = nil
			end
			if saveError then
				failed = failed + 1
			else
				done = done + 1
			end
		end
		local cancelled = not capturing
		capturing = true
		SetEntityVisible(ped, true, false)
		FreezeEntityPosition(ped, false)
		HousingInteriorLoader.Teleport(origin, nil, true)
		tripOrigin = nil
		setPreview(false)
		finishCapture({ thumbs = { done = done, failed = failed, cancelled = cancelled } })
	end)
end)

RegisterNUICallback('requestRefresh', function(_, callback)
	TriggerServerEvent('coe_admin:refresh')
	callback({ ok = true })
end)

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName == GetCurrentResourceName() then
		panelOpen = false
		Tablet.Stop()
		SetNuiFocusKeepInput(false)
		SetNuiFocus(false, false)
		SendNUIMessage({ action = 'close' })
		if tripOrigin then
			local ped = PlayerPedId()
			RenderScriptCams(false, false, 0, true, true)
			SetEntityVisible(ped, true, false)
			FreezeEntityPosition(ped, false)
			SetEntityCoords(ped, tripOrigin.x + 0.0, tripOrigin.y + 0.0, tripOrigin.z + 0.0, false, false, false, false)
			SetEntityHeading(ped, tripOrigin.heading + 0.0)
			DoScreenFadeIn(0)
			tripOrigin = nil
		end
	end
end)
