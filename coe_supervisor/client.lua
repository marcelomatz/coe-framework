RegisterNetEvent('coe_supervisor:result', function(success, message)
	if type(message) ~= 'string' then
		return
	end
	pcall(function()
		exports.coe_notify:Show(success == true and 'success' or 'error', message)
	end)
end)
