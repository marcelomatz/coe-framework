local isOpen = false
local requestSequence = 0
local MAX_REQUEST_ID = 2147483647
local lastCharacters = {}
local nuiLoaded = false
-- Pedidos que vieram do criador de personagem (coe_appearance): requestId -> { kind, characterId }.
local creatorRequests = {}
-- Personagem recém-criado: a câmera vai para ele quando a lista atualizada chegar.
local pendingFocus = nil

local function nextRequestId()
	requestSequence = requestSequence + 1
	if requestSequence > MAX_REQUEST_ID then
		requestSequence = 1
	end
	return requestSequence
end

local function debugPrint(text)
	if CoeCharactersConfig.Debug then
		print(('[coe_characters] %s'):format(text))
	end
end

local function acceptServerEvent()
	if source == 65535 then
		return true
	end
	debugPrint(('evento rejeitado, source=%s (%s)'):format(tostring(source), type(source)))
	return false
end

local function creatorAvailable()
	return GetResourceState('coe_appearance') == 'started'
end

-- HUD (coe_hud) fica escondido da seleção até o personagem nascer com a tela já clara.
local hudHidden, hudToken = false, 0

local function hideHud(hidden)
	hudHidden = hidden
	hudToken = hudToken + 1
	if not hidden and DisplayRadar then
		DisplayRadar(true)
	end
	TriggerEvent('coe_hud:setHidden', GetCurrentResourceName(), hidden)
end

local function showHudAfterFade()
	local token = hudToken
	CreateThread(function()
		local deadline = GetGameTimer() + 20000
		while (IsScreenFadedOut() or IsScreenFadingOut() or IsScreenFadingIn()) and GetGameTimer() < deadline do
			Wait(100)
		end
		if token == hudToken and hudHidden then
			hideHud(false)
		end
	end)
end

AddEventHandler('onClientResourceStart', function(resource)
	if resource == 'coe_hud' and hudHidden then
		TriggerEvent('coe_hud:setHidden', GetCurrentResourceName(), true)
	end
end)

-- A tela de carregamento usa loadscreen_manual_shutdown: só fecha quando a cena da seleção está pronta,
-- para não aparecer o jogo cru nem a interface sem cena entre ela e a seleção.
local loadingClosed = false

local function closeLoadingScreen()
	if loadingClosed then
		return
	end
	loadingClosed = true
	debugPrint('tela de carregamento fechada')
	if ShutdownLoadingScreen then
		ShutdownLoadingScreen()
	end
	if ShutdownLoadingScreenNui then
		ShutdownLoadingScreenNui()
	end
end

-- A interface da seleção só aparece junto com a cena (revealed); cada abertura tem seu token.
local revealToken, revealed = 0, true

local function reveal(token)
	if token ~= revealToken or not isOpen or revealed then
		return
	end
	revealed = true
	closeLoadingScreen()
	SendNUIMessage({ action = 'reveal' })
end

local function setOpen(open)
	isOpen = open
	if open and not hudHidden then
		hideHud(true)
	end
	SetNuiFocus(open, open)
	SendNUIMessage({
		action = open and 'open' or 'close',
		genders = CoeCharactersConfig.Genders,
		creator = creatorAvailable(),
		waitScene = open and not revealed or nil
	})
end

local function sendRequest(eventName, ...)
	local sent, errorMessage = Core.Events.ToServer(eventName, ...)
	if not sent then
		SendNUIMessage({
			action = 'error',
			message = errorMessage or 'request_failed'
		})
	end
	return sent
end

local function findCharacter(characterId)
	for _, character in ipairs(lastCharacters) do
		if character.characterId == characterId then
			return character
		end
	end
	return nil
end

-- Cena 3D (client/scene.lua). Opcional: sem ela a seleção continua funcionando só com a NUI.
-- Com token, revela a interface (e fecha a tela de carregamento) quando a cena termina de montar.
local function showScene(focusId, token)
	if CharacterScene and CoeCharactersConfig.Scene.Enabled then
		CreateThread(function()
			local ok, err = pcall(CharacterScene.Show, lastCharacters, focusId)
			if not ok then
				debugPrint(('falha ao montar a cena: %s'):format(tostring(err)))
			end
			if token then
				reveal(token)
			end
		end)
	elseif token then
		reveal(token)
	end
end

local function destroyScene(keepFaded)
	if CharacterScene then
		CharacterScene.Destroy(keepFaded)
	end
end

local function openSelection(characters, focusId)
	lastCharacters = characters
	revealToken = revealToken + 1
	revealed = false
	setOpen(true)
	SendNUIMessage({
		action = 'selectionRequired',
		characters = characters,
		focus = focusId
	})
	showScene(focusId, revealToken)
end

Core.Events.OnNet('character.selectionRequired', function(characters)
	debugPrint(('selectionRequired na entrada, tipo=%s'):format(type(characters)))
	if not acceptServerEvent() or type(characters) ~= 'table' then
		return
	end
	debugPrint(('selectionRequired recebido, personagens=%d'):format(#characters))
	openSelection(characters)
end)

Core.Events.OnNet('character.listUpdated', function(characters)
	if acceptServerEvent() and type(characters) == 'table' then
		lastCharacters = characters
		SendNUIMessage({
			action = 'characters',
			characters = characters
		})
		local focus = pendingFocus
		pendingFocus = nil
		SendNUIMessage({ action = 'focus', characterId = focus })
		if CharacterScene and CharacterScene.IsActive() then
			showScene(focus)
		end
	end
end)

Core.Events.OnNet('player.characterUnloaded', function()
	if not acceptServerEvent() then
		return
	end
	openSelection(lastCharacters)
end)

Core.Events.OnNet('character.listResult', function(requestId, success, result)
	if acceptServerEvent() then
		if success and type(result) == 'table' then
			lastCharacters = result
		end
		SendNUIMessage({
			action = 'listResult',
			requestId = requestId,
			success = success,
			result = result
		})
	end
end)

-- Mensagens dos erros do servidor mostradas dentro do criador.
local CREATOR_ERRORS = {
	character_limit_reached = 'Você atingiu o limite de personagens.',
	invalid_character_name = 'Nome ou sobrenome inválido.',
	invalid_birth_date = 'Data de nascimento inválida.',
	birth_date_out_of_range = 'A idade está fora do permitido.',
	invalid_gender = 'Gênero inválido.',
	invalid_appearance = 'A aparência não pôde ser validada.',
	appearance_locked = 'Este personagem já tem aparência definida.',
	operation_in_progress = 'Aguarde a operação atual terminar.',
	rate_limited = 'Aguarde um momento e tente de novo.'
}

local function creatorFailed(result)
	pcall(function()
		exports.coe_appearance:CreatorError(CREATOR_ERRORS[result] or 'Não foi possível registrar. Tente de novo.')
	end)
end

local function closeCreator()
	pcall(function()
		exports.coe_appearance:CloseCreator()
	end)
end

Core.Events.OnNet('character.createResult', function(requestId, success, result)
	if not acceptServerEvent() then
		return
	end
	local pending = creatorRequests[requestId]
	creatorRequests[requestId] = nil
	if pending then
		if not success then
			creatorFailed(result)
			return
		end
		-- Personagem criado: volta para a seleção com a câmera nele.
		closeCreator()
		local createdId = type(result) == 'table' and result.characterId or nil
		if not findCharacter(createdId) then
			pendingFocus = createdId
		end
		openSelection(lastCharacters, createdId)
		return
	end
	SendNUIMessage({
		action = 'createResult',
		requestId = requestId,
		success = success,
		result = result
	})
end)

Core.Events.OnNet('character.appearanceResult', function(requestId, success, result)
	if not acceptServerEvent() then
		return
	end
	local pending = creatorRequests[requestId]
	creatorRequests[requestId] = nil
	if not pending then
		return
	end
	if not success then
		creatorFailed(result)
		return
	end
	-- Aparência salva: fecha o criador (a tela segue escura) e já entra com o personagem.
	closeCreator()
	sendRequest('character.selectRequest', nextRequestId(), pending.characterId)
end)

Core.Events.OnNet('character.selectResult', function(requestId, success, result)
	if not acceptServerEvent() then
		return
	end

	SendNUIMessage({
		action = 'selectResult',
		requestId = requestId,
		success = success,
		result = result
	})
	if success then
		setOpen(false)
		-- Escurece e desmonta a cena; o coe_spawn faz o fade in quando o personagem nascer.
		CreateThread(function()
			destroyScene(true)
			showHudAfterFade()
		end)
	elseif not isOpen then
		-- Falhou logo depois do criador: volta para a seleção.
		openSelection(lastCharacters)
	end
end)

Core.Events.OnNet('character.changeResult', function(requestId, success, result)
	if not acceptServerEvent() then
		return
	end

	SendNUIMessage({
		action = 'changeResult',
		requestId = requestId,
		success = success,
		result = result
	})
	if success then
		openSelection(result)
		SendNUIMessage({
			action = 'characters',
			characters = result
		})
	end
end)

Core.Events.OnNet('character.archiveResult', function(requestId, success, result)
	if acceptServerEvent() then
		SendNUIMessage({
			action = 'archiveResult',
			requestId = requestId,
			success = success,
			result = result
		})
	end
end)

-- Criador de personagem (coe_appearance) --------------------------------------------------------------------

local function openCreator(options)
	if not creatorAvailable() then
		return false
	end
	setOpen(false)
	CreateThread(function()
		destroyScene(true)
		local ok, opened = pcall(function()
			return exports.coe_appearance:OpenCreator(options)
		end)
		if not ok or not opened then
			debugPrint('criador indisponível; voltando para a seleção')
			openSelection(lastCharacters)
		end
	end)
	return true
end

AddEventHandler('coe_appearance:creatorSubmit', function(payload)
	if type(payload) ~= 'table' or type(payload.appearance) ~= 'table' then
		return
	end
	local requestId = nextRequestId()
	if payload.mode == 'appearance' then
		if type(payload.characterId) ~= 'string' then
			return
		end
		creatorRequests[requestId] = { kind = 'appearance', characterId = payload.characterId }
		if not sendRequest('character.appearanceRequest', requestId, payload.characterId, payload.appearance, payload.version) then
			creatorRequests[requestId] = nil
			creatorFailed('request_failed')
		end
		return
	end
	local identity = type(payload.identity) == 'table' and payload.identity or {}
	creatorRequests[requestId] = { kind = 'create' }
	local profile = {
		birthDate = identity.birthDate,
		gender = identity.gender,
		appearance = payload.appearance,
		appearanceVersion = payload.version
	}
	if not sendRequest('character.createRequest', requestId, identity.firstName, identity.lastName, profile) then
		creatorRequests[requestId] = nil
		creatorFailed('request_failed')
	end
end)

AddEventHandler('coe_appearance:creatorCancelled', function()
	openSelection(lastCharacters)
end)

-- NUI ---------------------------------------------------------------------------------------------------------

RegisterNUICallback('nuiReady', function(_, callback)
	debugPrint('página NUI carregada')
	nuiLoaded = true
	-- Mensagens enviadas antes da página carregar se perdem; reenvia o estado se a seleção já estava aberta.
	if isOpen then
		SendNUIMessage({ action = 'open', genders = CoeCharactersConfig.Genders, creator = creatorAvailable(), waitScene = not revealed or nil })
		SendNUIMessage({ action = 'selectionRequired', characters = lastCharacters })
		if revealed then
			SendNUIMessage({ action = 'reveal' })
		end
	end
	callback({ success = true })
end)

RegisterNUICallback('nuiError', function(data, callback)
	if type(data) == 'table' and type(data.message) == 'string' then
		debugPrint(('erro na NUI: %s'):format(data.message:sub(1, 200)))
	end
	callback({ success = true })
end)

-- Formulário simples (sem o coe_appearance): só nome, nascimento e gênero; a NUI não envia aparência.
RegisterNUICallback('createCharacter', function(data, callback)
	if type(data) ~= 'table' or type(data.firstName) ~= 'string' or type(data.lastName) ~= 'string' then
		callback({ success = false, error = 'invalid_request' })
		return
	end

	local profile = {}
	if data.birthDate ~= nil then
		if type(data.birthDate) ~= 'string' then
			callback({ success = false, error = 'invalid_request' })
			return
		end
		profile.birthDate = data.birthDate
	end
	if data.gender ~= nil then
		if type(data.gender) ~= 'string' then
			callback({ success = false, error = 'invalid_request' })
			return
		end
		profile.gender = data.gender
	end

	sendRequest('character.createRequest', nextRequestId(), data.firstName, data.lastName, profile)
	callback({ success = true })
end)

RegisterNUICallback('newCharacter', function(_, callback)
	callback({ success = openCreator({ mode = 'create' }) })
end)

RegisterNUICallback('focusCharacter', function(data, callback)
	if type(data) == 'table' and type(data.characterId) == 'string' and CharacterScene then
		CharacterScene.Focus(data.characterId, true)
	end
	callback({ success = true })
end)

RegisterNUICallback('selectCharacter', function(data, callback)
	if type(data) ~= 'table' or type(data.characterId) ~= 'string' then
		callback({ success = false, error = 'invalid_request' })
		return
	end

	-- Personagem antigo, sem aparência: passa pelo criador uma vez antes de entrar.
	local character = findCharacter(data.characterId)
	if character and not character.appearance and creatorAvailable() then
		local opened = openCreator({
			mode = 'appearance', characterId = character.characterId, gender = character.gender,
			firstName = character.firstName, lastName = character.lastName, birthDate = character.birthDate
		})
		callback({ success = opened })
		return
	end

	sendRequest('character.selectRequest', nextRequestId(), data.characterId)
	callback({ success = true })
end)

RegisterNUICallback('archiveCharacter', function(data, callback)
	if type(data) ~= 'table' or type(data.characterId) ~= 'string' then
		callback({ success = false, error = 'invalid_request' })
		return
	end

	sendRequest('character.archiveRequest', nextRequestId(), data.characterId)
	callback({ success = true })
end)

RegisterNUICallback('requestCharacters', function(_, callback)
	sendRequest('character.listRequest', nextRequestId())
	callback({ success = true })
end)

RegisterNUICallback('changeCharacter', function(_, callback)
	sendRequest('character.changeRequest', nextRequestId())
	callback({ success = true })
end)

RegisterCommand(CoeCharactersConfig.Command, function()
	if not isOpen then
		sendRequest('character.changeRequest', nextRequestId())
	end
end, false)

RegisterKeyMapping(
	CoeCharactersConfig.Command,
	CoeCharactersConfig.KeyDescription,
	'keyboard',
	CoeCharactersConfig.OpenKey
)

-- Ajuda para reposicionar a cena: fique onde os personagens devem ficar, olhando para a paisagem do fundo,
-- e rode o comando. Imprime no F8 a posição e a direção no formato de CoeCharactersConfig.Scene.
RegisterCommand('coe_scene_anchor', function()
	local ped = PlayerPedId()
	local coords = GetEntityCoords(ped)
	print(('Anchor = { x = %.2f, y = %.2f, z = %.2f },\nFacing = %.1f,'):format(coords.x, coords.y, coords.z, (GetEntityHeading(ped) + 180.0) % 360.0))
end, false)

-- Informa ao servidor que os handlers estão registrados; ele reenvia a seleção caso o envio inicial tenha se perdido.
CreateThread(function()
	while not NetworkIsPlayerActive(PlayerId()) do
		Wait(100)
	end
	-- Espera a NUI carregar (até 15 s) para o reenvio da seleção não chegar a uma página ainda vazia.
	local waited = 0
	while not nuiLoaded and waited < 15000 do
		Wait(100)
		waited = waited + 100
	end
	debugPrint('player.clientReady enviado')
	sendRequest('player.clientReady')
	-- Rede de segurança: se a seleção não abrir (servidor sem resposta, erro), a tela de carregamento fecha mesmo assim.
	local timeout = CoeCharactersConfig.LoadingScreenTimeoutMs or 30000
	local elapsed = 0
	while not loadingClosed and elapsed < timeout do
		Wait(250)
		elapsed = elapsed + 250
	end
	if not loadingClosed then
		debugPrint('seleção não abriu a tempo; fechando a tela de carregamento')
		closeLoadingScreen()
	end
end)

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName == GetCurrentResourceName() and isOpen then
		SetNuiFocus(false, false)
	end
end)
