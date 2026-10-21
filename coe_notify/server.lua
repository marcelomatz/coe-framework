local notificationTypes = {
	error = true,
	info = true,
	success = true,
	warning = true
}

local allowedResources = {
	coe_admin = true,
	coe_amzg = true,
	coe_mail = true,
	coe_news = true,
	coe_crypto = true,
	coe_deepweb = true,
	coe_loot = true,
	coe_banking = true,
	coe_businesses = true,
	coe_characters = true,
	coe_core = true,
	coe_garages = true,
	coe_economy = true,
	coe_housing = true,
	coe_doors = true,
	coe_inventory = true,
	coe_mechanic = true,
	coe_phone = true,
	coe_telecom = true,
	coe_vehicles = true,
	coe_jobs = true,
	coe_elos = true,
	coe_shops = true,
	coe_fuel = true
}

exports('Notify', function(playerId, kind, message, duration)
	local caller = GetInvokingResource()
	if type(caller) ~= 'string' or not allowedResources[caller] then
		return false, 'caller_not_allowed'
	end
	if type(playerId) ~= 'number' or playerId < 1 or playerId % 1 ~= 0
		or not GetPlayerName(playerId) then
		return false, 'invalid_target'
	end
	if not notificationTypes[kind]
		or type(message) ~= 'string'
		or #message == 0
		or #message > 240
		or (duration ~= nil and (type(duration) ~= 'number'
			or duration ~= duration
			or duration < 1500
			or duration > 10000)) then
		return false, 'invalid_notification'
	end

	TriggerClientEvent('coe_notify:display', playerId, kind, message, duration or 4000)
	return true
end)
