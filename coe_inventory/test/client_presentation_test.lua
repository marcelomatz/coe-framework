-- Smoke test do cliente (presentation): carrega os módulos na ordem do manifest com natives
-- stubadas e dispara eventos do servidor para pegar globais nil e erros de ordem de carga.
local calls = {}
local lastModelOptions
local function record(name, ...) calls[#calls + 1] = { name = name, args = { ... } } end
local function count(name)
	local n = 0
	for _, call in ipairs(calls) do if call.name == name then n = n + 1 end end
	return n
end

local netHandlers, nuiCallbacks, commands, eventHandlers, exportsRegistered = {}, {}, {}, {}, {}

-- Qualquer native não stubada vira função inofensiva que retorna 0; só nomes em CamelCase.
setmetatable(_G, {
	__index = function(_, key)
		if type(key) == 'string' and key:match('^[A-Z]') then
			return function(...) record(key, ...); return 0 end
		end
		return nil
	end
})

local timer = 0
function GetGameTimer() timer = timer + 1000; return timer end
function Wait() end
function CreateThread() end
function PlayerPedId() return 1 end
function PlayerId() return 1 end
function DoesEntityExist() return false end
function IsPauseMenuActive() return false end
function GetHashKey(name) return #name end
function GetCurrentResourceName() return 'coe_inventory' end
function GetActivePlayers() return {} end
function GetEntityCoords() return vector3(0, 0, 0) end
function SetNuiFocus(...) record('SetNuiFocus', ...) end
function SendNUIMessage(message) record('SendNUIMessage', message) end
function RegisterNUICallback(name, fn) nuiCallbacks[name] = fn end
function RegisterCommand(name, fn) commands[name] = fn end
function AddEventHandler(name, fn) eventHandlers[name] = fn end
function exports(name, fn) exportsRegistered[name] = fn end
function vector3(x, y, z) return { x = x, y = y, z = z } end
source = 65535

Inventory = {}
dofile('config.lua')
dofile('domain/config_schema.lua')
assert(#Inventory.Settings.issues == 0, 'config.lua padrão deve ser válido: ' .. table.concat(Inventory.Settings.issues, '; '))

exports = setmetatable({
	coe_notify = { Show = function(...) record('notify', ...) end },
	coetarget = {
		AddTargetModel = function(_, model, options) record('AddModel', model); lastModelOptions = options; return true end,
		AddTargetSurface = function(options) record('AddSurface', options); return true end
	}
}, {
	__call = function(_, name, fn) exportsRegistered[name] = fn end
})
Inventory.Items = { Animations = {} }
Core = {
	Functions = { IsInteger = function(v) return math.type(v) == 'integer' end },
	Events = {
		OnNet = function(name, fn) netHandlers[name] = fn end,
		ToServer = function(name, ...) record('ToServer', name, ...); return true end,
		Emit = function(name, ...) record('Emit', name, ...) end
	}
}

-- Descobre a ordem de carga no próprio manifest para o teste nunca divergir dele.
local manifest = assert(io.open('fxmanifest.lua', 'r')):read('*a')
local clientBlock = manifest:match('client_scripts%s*(%b{})')
local files = {}
for path in clientBlock:gmatch("'([^']+)'") do
	if path:sub(1, 1) ~= '@' then files[#files + 1] = path end
end
assert(#files >= 10, 'manifest client_scripts incompleto')
for _, path in ipairs(files) do dofile(path) end
for _, path in ipairs({ 'presentation/client.lua' }) do
	assert(not io.open(path, 'r'), 'client.lua monolítico deveria ter sido removido')
end

local C = Inventory.Client
assert(C and C.state, 'namespace Inventory.Client ausente')

-- Registros de bootstrap
assert(exportsRegistered.GetInventoryObject() == Inventory)
for _, name in ipairs({ '+coe_core_inventory', '+coe_core_hotbar_peek', '+coe_core_cancel_use', '+coe_core_hotbar_1', '+coe_core_hotbar_5' }) do
	assert(commands[name], 'comando ausente: ' .. name)
end
assert(eventHandlers['coetarget:ready'] and eventHandlers['onResourceStop'])

-- Alcance do target: Abrir/Pegar só dentro de targetDistance; fora dele aparece o aviso para se aproximar
local worldOptions = {}
for _, option in ipairs(lastModelOptions) do worldOptions[option.label] = option end
local near, far = Config.Client.targetDistance - 0.5, Config.Client.targetDistance + 1.0
NetworkGetEntityIsNetworked = function() return true end
NetworkGetNetworkIdFromEntity = function() return 7 end
assert(worldOptions['Abrir'].distance == Config.Client.targetDistance, 'Abrir usa targetDistance')
assert(Config.Client.targetDistance <= Config.Server.worldInteractDistance, 'cliente não oferece além do que o servidor aceita')
local tooFar = worldOptions['Maleta: aproxime-se para usar']
assert(tooFar and tooFar.canInteract(1, far) and not tooFar.canInteract(1, near), 'aviso só fora do alcance')
assert(worldOptions['Abrir'].canInteract(1, near), 'Abrir disponível perto')
assert(count('AddModel') > 0, 'modelos de container não registrados no target')

-- Callbacks NUI esperados
for _, name in ipairs({ 'nearbyPlayers', 'openContainer', 'swapSlots', 'splitItem', 'giveItem', 'useItem',
	'moveContainerItem', 'closeContainer', 'pickupContainerProp', 'placeContainerProp', 'storeContainerProp', 'close' }) do
	assert(nuiCallbacks[name], 'callback NUI ausente: ' .. name)
end

-- Validação NUI
local result
nuiCallbacks.swapSlots({ fromSlot = 1, toSlot = 'x' }, function(r) result = r end)
assert(result.ok == false, 'payload inválido deveria ser recusado')
nuiCallbacks.swapSlots({ fromSlot = 1, toSlot = 2 }, function(r) result = r end)
assert(result.ok == true)
local sent = calls[#calls]
assert(sent.args[1] == 'inventory.swap' and sent.args[2] == 1 and sent.args[3] == 2)
nuiCallbacks.moveContainerItem({ requestId = 1, sourceSide = 'bad', targetSide = 'player', fromSlot = 1, toSlot = 1 },
	function(r) result = r end)
assert(result.ok == false)
nuiCallbacks.pickupContainerProp({}, function(r) result = r end)
assert(result.ok == false and result.error == 'container_id_missing')
nuiCallbacks.giveItem({ requestId = 1, targetId = 2, slot = 3, count = 4 }, function(r) result = r end)
assert(result.ok == true)

-- Fluxo do inventário: request -> response -> abre UI -> close
C.toggleInventory()
local requestId = C.state.activeRequestId
assert(requestId and C.state.requestPending)
netHandlers['inventory.response'](requestId, { slots = {} })
assert(C.state.inventoryOpen and not C.state.requestPending)
netHandlers['inventory.containerOpened']({ slots = {} }, 1)
assert(C.state.openedContainerPanels[1])
nuiCallbacks.close({}, function() end)
assert(not C.state.inventoryOpen and next(C.state.openedContainerPanels) == nil)

-- Abrir maleta do mundo: sem entidade local abre direto; com entidade enquadra a câmera até fechar
netHandlers['inventory.worldContainerOpened']({ slots = {} }, { slots = {} }, 1)
assert(C.state.inventoryOpen and not C.state.openCamera, 'sem entidade abre direto')
C.closeInventory()
local realExists, realFromNet = DoesEntityExist, NetworkGetEntityFromNetworkId
DoesEntityExist = function() return true end
NetworkGetEntityFromNetworkId = function() return 5 end
C.state.lastOpenNetId = 99
netHandlers['inventory.worldContainerOpened']({ slots = {} }, { slots = {} }, 1)
assert(C.state.inventoryOpen and C.state.openCamera, 'câmera ativa com o inventário aberto')
assert(count('RenderScriptCams') >= 1, 'câmera da cinemática')
C.closeInventory()
assert(not C.state.openCamera and not C.state.inventoryOpen, 'fechar encerra a câmera')
DoesEntityExist, NetworkGetEntityFromNetworkId = realExists, realFromNet

-- Resposta de ação do mundo
C.state.pendingWorldActions[7] = 'inventory.containerWorldPickup'
netHandlers['inventory.actionResult'](7, false, 'container_not_found')
assert(C.state.pendingWorldActions[7] == nil)

-- Uso de item genérico, consumível com cancelamento no X, hotbar peek no TAB e arma não devem estourar
commands['+coe_core_hotbar_peek']()
netHandlers['inventory.useItem']({ name = 'water', slot = 1, consume = 1, consumeTime = 2500 })
assert(C.state.consuming ~= nil, 'consumo ativo iniciado')
commands['+coe_core_cancel_use']()
assert(C.state.consuming == nil, 'consumo cancelado no X')
netHandlers['inventory.useItem']({ name = 'WEAPON_PISTOL', slot = 2 })
netHandlers['inventory.useItem']('lixo')

-- Resultado de drop desconhecido é ignorado
netHandlers['inventory.containerDropResult'](999, true)

-- Limpeza
netHandlers['player.characterUnloaded']()
eventHandlers.onResourceStop('coe_inventory')

print('client_presentation_test: ok')
