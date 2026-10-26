-- Janela do inventário: abrir, fechar, alternar e consulta de jogadores próximos (para "dar item").
local C = Inventory.Client
local state = C.state

--- Fecha a UI, avisa o servidor se havia painéis de container abertos e devolve o foco ao jogo.
function C.closeInventory()
	state.inventoryOpen = false
	if next(state.openedContainerPanels) then
		Core.Events.ToServer('inventory.containerClose')
		state.openedContainerPanels = {}
	end
	state.requestPending = false
	state.activeRequestId = nil
	SetNuiFocus(false, false)
	SendNUIMessage({ action = 'close' })
	C.endOpenCamera()
end

--- Tecla do inventário: fecha se aberto/pendente; senão pede o inventário ao servidor.
--- Ignora enquanto o jogador escolhe onde soltar um container.
function C.toggleInventory()
	if state.placement then
		return
	end
	if state.inventoryOpen or state.requestPending then
		C.closeInventory()
		return
	end

	state.requestSequence = state.requestSequence + 1
	state.activeRequestId = state.requestSequence
	state.requestPending = true
	Core.Events.ToServer('inventory.request', state.activeRequestId)
end

--- Abre a UI com o inventário informado (resposta do servidor ou abertura de container do mundo).
function C.openInventoryUi(inventory)
	state.cachedInventory = inventory
	state.inventoryOpen = true
	SetNuiFocus(true, true)
	SendNUIMessage({
		action = 'open',
		inventory = inventory,
		openKey = Config.Client.openKey,
		hotbarSlots = Config.Client.hotbarSlots
	})
end

--- Exibe a barra rápida (Hotbar 1..N) flutuante na tela ao pressionar TAB.
function C.showHotbarPeek()
	if state.inventoryOpen or state.placement then
		return
	end
	if not state.cachedInventory and not state.requestPending and not state.hotbarSyncRequestId then
		state.requestSequence = state.requestSequence + 1
		state.hotbarSyncRequestId = state.requestSequence
		Core.Events.ToServer('inventory.request', state.hotbarSyncRequestId)
	end
	SendNUIMessage({
		action = 'hotbarPeek',
		inventory = state.cachedInventory,
		hotbarSlots = Config.Client.hotbarSlots,
		durationMs = Config.Client.hotbarPreviewMs
	})
end

--- Jogadores a até `Config.Server.giveDistance` metros, ordenados por nome.
function C.getNearbyPlayers()
	local playerPed = PlayerPedId()
	if playerPed == 0 then
		return {}
	end

	local playerId = PlayerId()
	local playerCoords = GetEntityCoords(playerPed)
	local maxDistance = Config.Server.giveDistance
	local nearbyPlayers = {}
	for _, activePlayer in ipairs(GetActivePlayers()) do
		local targetPed = activePlayer ~= playerId and GetPlayerPed(activePlayer) or 0
		if targetPed ~= 0 and #(GetEntityCoords(targetPed) - playerCoords) <= maxDistance then
			local serverId = GetPlayerServerId(activePlayer)
			if serverId > 0 then
				nearbyPlayers[#nearbyPlayers + 1] = {
					serverId = serverId,
					name = GetPlayerName(activePlayer) or ('Jogador %d'):format(serverId)
				}
			end
		end
	end

	table.sort(nearbyPlayers, function(first, second)
		return first.name:lower() < second.name:lower()
	end)
	return nearbyPlayers
end
