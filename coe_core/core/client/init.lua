exports('GetCoreObject', function()
	return Core
end)

Core.Events.Emit('client.ready', Core)
