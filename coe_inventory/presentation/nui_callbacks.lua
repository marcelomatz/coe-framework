-- Callbacks NUI (UI -> client). Cada callback valida o payload recebido da UI e o repassa
-- ao servidor ou a um módulo local. A UI nunca é confiável: o servidor valida de novo.
local C = Inventory.Client
local state = C.state
local isInteger = Core.Functions.IsInteger

local function isPanelSide(value)
	return value == 'player' or value == 'container-1' or value == 'container-2'
end

--- Registra um callback que exige que todos os `fields` do payload sejam inteiros e envia
--- esses valores, na ordem, ao evento de servidor `serverEvent`.
local function forwardIntegers(callbackName, serverEvent, fields)
	RegisterNUICallback(callbackName, function(data, callback)
		if type(data) ~= 'table' then
			callback({ ok = false })
			return
		end

		local values = {}
		for index, field in ipairs(fields) do
			if not isInteger(data[field]) then
				callback({ ok = false })
				return
			end
			values[index] = data[field]
		end

		local sent, errorMessage = Core.Events.ToServer(serverEvent, table.unpack(values))
		callback({ ok = sent, error = errorMessage })
	end)
end

--- Registra um callback sobre um container portátil: exige `containerId` string e delega
--- a `action(data)`, que retorna `success, errorCode`.
local function containerPropAction(callbackName, requiredFields, action)
	RegisterNUICallback(callbackName, function(data, callback)
		if type(data) ~= 'table' or type(data.containerId) ~= 'string' then
			callback({ ok = false, error = 'container_id_missing' })
			return
		end
		for _, field in ipairs(requiredFields) do
			if type(data[field]) ~= 'string' then
				callback({ ok = false, error = 'container_id_missing' })
				return
			end
		end

		local success, errorCode = action(data)
		callback({ ok = success, error = errorCode })
	end)
end

RegisterNUICallback('nearbyPlayers', function(_, callback)
	callback({ players = C.getNearbyPlayers() })
end)

forwardIntegers('openContainer', 'inventory.containerOpen', { 'requestId', 'slot' })
forwardIntegers('swapSlots', 'inventory.swap', { 'fromSlot', 'toSlot' })
forwardIntegers('splitItem', 'inventory.split', { 'requestId', 'slot', 'count' })
forwardIntegers('giveItem', 'inventory.give', { 'requestId', 'targetId', 'slot', 'count' })
forwardIntegers('useItem', 'inventory.use', { 'requestId', 'slot' })

containerPropAction('pickupContainerProp', { 'itemName' }, function(data)
	local success, errorCode = C.pickupContainerProp(data.itemName, data.containerId)
	if success then C.feedback('Maleta na mão.') end
	return success, errorCode
end)

containerPropAction('placeContainerProp', {}, function(data)
	return C.placeContainerProp(data.containerId)
end)

containerPropAction('storeContainerProp', {}, function(data)
	local success, errorCode = C.storeContainerProp(data.containerId)
	if success then C.feedback('Maleta guardada.') end
	return success, errorCode
end)

RegisterNUICallback('moveContainerItem', function(data, callback)
	if type(data) ~= 'table'
		or not isInteger(data.requestId)
		or not isPanelSide(data.sourceSide)
		or not isPanelSide(data.targetSide)
		or not isInteger(data.fromSlot)
		or not isInteger(data.toSlot) then
		callback({ ok = false })
		return
	end

	local sent, errorMessage = Core.Events.ToServer(
		'inventory.containerMove',
		data.requestId,
		data.sourceSide,
		data.targetSide,
		data.fromSlot,
		data.toSlot
	)
	callback({ ok = sent, error = errorMessage })
end)

RegisterNUICallback('closeContainer', function(data, callback)
	if type(data) ~= 'table' or (data.index ~= 1 and data.index ~= 2) then
		callback({ ok = false })
		return
	end

	Core.Events.ToServer('inventory.containerClose', data.index)
	state.openedContainerPanels[data.index] = nil
	SendNUIMessage({ action = 'containerClose', index = data.index })
	callback({ ok = true })
end)

RegisterNUICallback('close', function(_, callback)
	C.closeInventory()
	callback({ ok = true })
end)
