function Core.Events.Name(name)
	if not Core.Functions.IsValidName(name) then
		return nil, 'invalid_event_name'
	end

	return Core.Prefix .. ':' .. name
end

function Core.Events.On(name, callback)
	local eventName, errorMessage = Core.Events.Name(name)
	if not eventName then
		return nil, errorMessage
	end
	if type(callback) ~= 'function' then
		return nil, 'invalid_callback'
	end

	return AddEventHandler(eventName, callback)
end

function Core.Events.OnNet(name, callback)
	local eventName, errorMessage = Core.Events.Name(name)
	if not eventName then
		return nil, errorMessage
	end
	if type(callback) ~= 'function' then
		return nil, 'invalid_callback'
	end

	RegisterNetEvent(eventName)
	return AddEventHandler(eventName, callback)
end

function Core.Events.Emit(name, ...)
	local eventName, errorMessage = Core.Events.Name(name)
	if not eventName then
		return false, errorMessage
	end

	TriggerEvent(eventName, ...)
	return true
end

function Core.Events.ToServer(name, ...)
	if IsDuplicityVersion() then
		return false, 'client_only'
	end

	local eventName, errorMessage = Core.Events.Name(name)
	if not eventName then
		return false, errorMessage
	end

	TriggerServerEvent(eventName, ...)
	return true
end

function Core.Events.ToClient(target, name, ...)
	if not IsDuplicityVersion() then
		return false, 'server_only'
	end
	if not Core.Functions.IsInteger(target) or target < 1 then
		return false, 'invalid_target'
	end

	local eventName, errorMessage = Core.Events.Name(name)
	if not eventName then
		return false, errorMessage
	end

	TriggerClientEvent(eventName, target, ...)
	return true
end

function Core.Events.ToAll(name, ...)
	if not IsDuplicityVersion() then
		return false, 'server_only'
	end

	local eventName, errorMessage = Core.Events.Name(name)
	if not eventName then
		return false, errorMessage
	end

	TriggerClientEvent(eventName, -1, ...)
	return true
end

function Core.Events.Remove(handlerId)
	if type(handlerId) ~= 'number' then
		return false
	end

	RemoveEventHandler(handlerId)
	return true
end
