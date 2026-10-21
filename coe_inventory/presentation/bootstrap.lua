-- Inicialização do cliente do inventário: registros que dependem de todos os outros módulos
-- (comandos, teclas, threads, ciclo de vida do personagem e do resource).
local C = Inventory.Client
local state = C.state

local HOTBAR_SLOTS = Config.Client.hotbarSlots
local DISABLED_CONTROLS = { 14, 15, 16, 17, 37, 157, 158, 159, 160, 161 } -- roda de armas e atalhos 1-5

--- Remove props de containers, placement e fecha a UI (descarregar personagem / parar resource).
local function resetPresentation()
	state.placement = nil
	C.destroyAllContainerProps()
end

Core.Events.OnNet('player.characterUnloaded', function()
	if source ~= 65535 then
		return
	end
	C.closeInventory()
	resetPresentation()
end)

-- A roda de armas e os atalhos numéricos nativos ficam desligados; o inventário controla a hotbar.
CreateThread(function()
	while true do
		for _, control in ipairs(DISABLED_CONTROLS) do
			DisableControlAction(0, control, true)
		end
		Wait(0)
	end
end)

RegisterCommand('+coe_core_inventory', function()
	if not IsPauseMenuActive() then
		C.toggleInventory()
	end
end, false)
RegisterCommand('-coe_core_inventory', function() end, false)
RegisterKeyMapping('+coe_core_inventory', 'Abrir/fechar inventário', 'keyboard', Config.Client.openKey)

for slot = 1, HOTBAR_SLOTS do
	local command = ('+coe_core_hotbar_%d'):format(slot)
	RegisterCommand(command, function()
		if state.inventoryOpen or state.requestPending or state.placement or IsPauseMenuActive() then
			return
		end

		state.hotbarRequestSequence = state.hotbarRequestSequence + 1
		Core.Events.ToServer('inventory.use', state.hotbarRequestSequence, slot)
	end, false)
	RegisterCommand(('-coe_core_hotbar_%d'):format(slot), function() end, false)
	RegisterKeyMapping(command, ('Usar item da hotbar %d'):format(slot), 'keyboard', tostring(slot))
end

exports('GetInventoryObject', function()
	return Inventory
end)

-- Se o coetarget reiniciar, ele perde os registros e avisa para registrarmos de novo.
C.registerWorldContainerModels()
C.registerPlacementSurface()
AddEventHandler('coetarget:ready', function()
	C.registerWorldContainerModels()
	C.registerPlacementSurface()
end)

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		return
	end
	resetPresentation()
	C.endOpenCamera()
	for netId in pairs(state.worldTargets) do
		C.removeWorldContainer(netId)
	end
	SetNuiFocus(false, false)
end)

CreateThread(function()
	Wait(1000)
	Core.Events.ToServer('inventory.containerWorldSync')
end)
