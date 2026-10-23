local notificationTypes = {
	error = true,
	info = true,
	success = true,
	warning = true
}

-- Quem envia notificações. Padrões do framework; pacotes e scripts de terceiros recebem a ACE no server.cfg:
--   add_ace resource.<nome> coe.notify allow
local NOTIFY_ACE = 'coe.notify'
local allowedResources = {
	coe_businesses = true,
	coe_characters = true,
	coe_core = true,
	coe_economy = true,
	coe_inventory = true,
	coe_vehicles = true,
	coe_jobs = true,
	coe_shops = true,
	coe_bank = true,
	coe_mobile = true,
	coe_workpad = true,
	coe_staff = true
}

exports('Notify', function(playerId, kind, message, duration)
	local caller = GetInvokingResource()
	if not CoeAccess.Allowed(caller, NOTIFY_ACE, allowedResources) then
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
