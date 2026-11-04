exports('GetCoreObject', function()
	return Core
end)

-- Keymapping unificado de interação contextual ('E' por padrão).
-- Dispara o evento local 'coe_core:interact' sem necessidade de loops Wait(0) com IsControlJustReleased.
if type(RegisterCommand) == 'function' and type(RegisterKeyMapping) == 'function' then
	RegisterCommand('+coe_interact', function()
		if type(IsPauseMenuActive) == 'function' and IsPauseMenuActive() then
			return
		end
		TriggerEvent('coe_core:interact')
	end, false)
	RegisterCommand('-coe_interact', function() end, false)
	RegisterKeyMapping('+coe_interact', 'Interagir', 'keyboard', 'E')
end

Core.Events.Emit('client.ready', Core)
