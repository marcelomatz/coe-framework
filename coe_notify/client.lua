local notificationTypes = {
	error = true,
	info = true,
	success = true,
	warning = true
}

local function validNotification(kind, message, duration)
	return notificationTypes[kind]
		and type(message) == 'string'
		and #message > 0
		and #message <= 240
		and (duration == nil or (type(duration) == 'number'
			and duration == duration
			and duration >= 1500
			and duration <= 10000))
end

local function show(kind, message, duration)
	if not validNotification(kind, message, duration) then
		return false, 'invalid_notification'
	end

	SendNUIMessage({
		action = 'show',
		type = kind,
		message = message,
		duration = duration or 4000
	})
	return true
end

exports('Show', show)

RegisterNetEvent('coe_notify:display', function(kind, message, duration)
	if source ~= 65535 then
		return
	end
	show(kind, message, duration)
end)

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName == GetCurrentResourceName() then
		SendNUIMessage({ action = 'clear' })
	end
end)
