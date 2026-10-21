-- Camada de apresentação (client) do inventário.
--
-- Todos os arquivos desta pasta compartilham o namespace `Inventory.Client` (alias local `C`),
-- da mesma forma que `application/*` compartilha `Inventory.Service` no servidor.
-- Este arquivo guarda o estado compartilhado, as constantes e os helpers genéricos
-- (espera com timeout, carga de modelo/animação e feedback ao jogador).
Inventory.Client = {}
local C = Inventory.Client

-- Tempo máximo (ms) para streamar um modelo ou dicionário de animação.
C.STREAM_TIMEOUT_MS = Config.Client.streamTimeoutMs
-- Tempo máximo (ms) para obter controle de rede sobre uma entidade.
C.NETWORK_CONTROL_TIMEOUT_MS = Config.Client.networkControlTimeoutMs

-- Estado mutável. Qualquer módulo lê/escreve aqui em vez de usar variáveis locais soltas.
C.state = {
	-- Janela do inventário
	inventoryOpen = false,
	requestPending = false,
	requestSequence = 0,
	activeRequestId = nil,
	hotbarRequestSequence = 0,
	openedContainerPanels = {}, -- índice do painel (1 ou 2) -> true

	-- Containers carregados/posicionados pelo jogador
	containerProps = {}, -- containerId -> registro { containerId, itemName, profile, entity, ... }
	carriedContainerId = nil, -- container atualmente na mão
	equippedWeapon = nil, -- registro cujo container é uma arma nativa equipada
	placement = nil, -- { containerId, record } enquanto o jogador escolhe onde soltar
	pendingDrops = {}, -- requestId -> { record, entity } aguardando resposta do servidor

	-- Ações sobre containers do mundo (Abrir/Pegar pelo target)
	worldActionSequence = 0,
	pendingWorldActions = {}, -- requestId -> nome do evento enviado
	worldTargets = {} -- netId -> true (containers do mundo conhecidos)
}

-- Perfis de carga e modelos dos containers (vêm de Config.Containers.items).
-- Maletas e saco de lixo são armas nativas: o jogo cuida da animação e do prop na mão, e o
-- perfil vale só para posicionar o prop no chão. `bone` é o osso do ped; `position`/`rotation`
-- são offsets (relevantes para itens que não são armas, como o `paperbag`).
C.CONTAINER_PROFILES = Config.Containers.items

-- Modelos de container que recebem as opções Abrir/Pegar no target.
C.WORLD_CONTAINER_MODELS = {}
for itemName, profile in pairs(Config.Containers.items) do
	C.WORLD_CONTAINER_MODELS[itemName] = profile.model
end
local DEFAULTS = {
	error_rate_limited = 'Aguarde um instante e tente novamente.',
	error_invalid_target = 'A maleta não está mais disponível.',
	error_not_found = 'Esta maleta não está registrada (objeto antigo sem dono).',
	error_inventory_full = 'Não há espaço livre neste inventário.',
	error_persistence_failed = 'Não foi possível salvar a maleta.',
	error_world_container_limit = 'O limite de maletas no mundo foi atingido.',
	error_world_container_limit_player = 'Você já deixou maletas demais no mundo. Recolha alguma antes.',
	error_too_far = 'Você se afastou demais da maleta.',
	error_container_prop_busy = 'Aguarde terminar o movimento atual.',
	error_container_prop_unavailable = 'Não foi possível criar o objeto da maleta.',
	error_place_failed = 'Não foi possível colocar a maleta.',
	error_equip_failed = 'Não foi possível equipar a maleta.',
	error_pickup_failed = 'Não foi possível pegar a maleta na mão.',
	error_action_failed = 'Não foi possível concluir essa ação.',
	error_interact_failed = 'Não foi possível interagir com a maleta.',
	error_closer_needed = 'Chegue mais perto da maleta.',
	target_open = 'Abrir',
	target_pickup = 'Pegar',
	target_approach = 'Maleta: aproxime-se para usar',
	target_place_here = 'Colocar aqui',
	container_picked_up = 'Maleta recolhida.'
}

local rawLocales = (type(Locales) == 'table' and Locales) or {}
if not rawLocales['pt-BR'] then
	rawLocales['pt-BR'] = DEFAULTS
end

local _t_inst = (Core and Core.Locale and Core.Locale.New) and Core.Locale.New({
	default = (Config and Config.Locale) or (Core and Core.Locale and Core.Locale.GetDefaultLang()) or 'pt-BR',
	locales = rawLocales
})
local _t = function(k)
	if type(_t_inst) == 'table' then
		if _t_inst.T then
			return _t_inst:T(k)
		end
		local lang = (Config and Config.Locale) or _t_inst.lang or 'pt-BR'
		local dict = (_t_inst.locales and _t_inst.locales[lang]) or rawLocales[lang] or rawLocales['pt-BR'] or DEFAULTS
		if dict and dict[k] then
			return dict[k]
		end
	elseif type(_t_inst) == 'function' then
		return _t_inst(k)
	end
	local lang = (Config and Config.Locale) or 'pt-BR'
	return (rawLocales[lang] and rawLocales[lang][k]) or (rawLocales['pt-BR'] and rawLocales['pt-BR'][k]) or DEFAULTS[k] or k
end

C.t = _t

-- Códigos de erro (cliente ou servidor) -> mensagem exibida ao jogador.
C.ERROR_MESSAGES = {
	rate_limited = _t('error_rate_limited'),
	invalid_target = _t('error_invalid_target'),
	not_found = _t('error_not_found'),
	inventory_full = _t('error_inventory_full'),
	persistence_failed = _t('error_persistence_failed'),
	world_container_limit = _t('error_world_container_limit'),
	world_container_limit_player = _t('error_world_container_limit_player'),
	too_far = _t('error_too_far'),
	container_prop_busy = _t('error_container_prop_busy'),
	container_prop_unavailable = _t('error_container_prop_unavailable')
}

--- Indica se o item é uma arma nativa do GTA (nomes `WEAPON_*`).
function C.isWeaponItem(itemName)
	return type(itemName) == 'string' and itemName:sub(1, 7) == 'WEAPON_'
end

--- Espera (a cada frame) até `predicate()` ser verdadeiro ou o tempo esgotar.
--- Deve rodar dentro de uma thread. Retorna o resultado final de `predicate()`.
function C.waitUntil(predicate, timeoutMs)
	local startedAt = GetGameTimer()
	while not predicate() and GetGameTimer() - startedAt < timeoutMs do
		Wait(0)
	end
	return predicate()
end

--- Converte o nome de um modelo em hash, ou nil se o modelo não existir no jogo.
function C.resolveModelHash(modelName)
	local modelHash = GetHashKey(modelName)
	if not modelHash or modelHash == 0 or not IsModelInCdimage(modelHash) or not IsModelValid(modelHash) then
		return nil
	end
	return modelHash
end

--- Faz o stream do modelo. Em caso de falha libera o modelo e retorna false.
function C.loadModel(modelHash)
	RequestModel(modelHash)
	if C.waitUntil(function() return HasModelLoaded(modelHash) end, C.STREAM_TIMEOUT_MS) then
		return true
	end
	SetModelAsNoLongerNeeded(modelHash)
	return false
end

--- Faz o stream do dicionário de animação. Retorna false se não carregar a tempo.
function C.loadAnimDict(dictionary)
	RequestAnimDict(dictionary)
	return C.waitUntil(function() return HasAnimDictLoaded(dictionary) end, C.STREAM_TIMEOUT_MS)
end

--- Cria um objeto local (não networked) na posição de `coords`, já marcado como mission entity.
--- Libera o modelo logo após a criação. Retorna a entidade ou nil.
function C.createLocalObject(modelHash, coords)
	local entity = CreateObject(modelHash, coords.x, coords.y, coords.z, false, false, false)
	SetModelAsNoLongerNeeded(modelHash)
	if entity == 0 or not DoesEntityExist(entity) then
		return nil
	end
	SetEntityAsMissionEntity(entity, true, true)
	return entity
end

--- Mensagem de feedback pelo coe_notify (padrão de notificações do framework).
function C.feedback(message, isError)
	pcall(function()
		exports.coe_notify:Show(isError == true and 'error' or 'success', message)
	end)
end

--- Traduz um código de erro em mensagem; usa `fallback` para códigos desconhecidos.
function C.errorMessage(code, fallback)
	local key = 'error_' .. tostring(code)
	local localized = _t(key)
	if localized ~= key then
		return localized
	end
	return C.ERROR_MESSAGES[code] or fallback
end

--- Informa a UI qual container está na mão (ou nil), para habilitar Soltar/Guardar.
function C.syncCarriedState()
	SendNUIMessage({ action = 'containerPropState', containerId = C.state.carriedContainerId })
end

--- Gera o próximo requestId das ações sobre containers do mundo (pegar, abrir, soltar).
--- O servidor devolve o mesmo id na resposta, que é casada com `pendingWorldActions`/`pendingDrops`.
function C.nextWorldActionId()
	C.state.worldActionSequence = C.state.worldActionSequence + 1
	return C.state.worldActionSequence
end
