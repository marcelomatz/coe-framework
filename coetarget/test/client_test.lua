local registeredExports = {}
local commands = {}
local keyMappings = {}
local nuiMessages = {}
local stopHandlers = {}
local threads = {}
TriggerEvent = function() end
local invoker = 'res_a'
local pressed = {}
local world = {
	hit = 0,
	player = { x = 0.0, y = 0.0, z = 0.0 },
	entities = {}
}

Config = {
	Command = 'target',
	DefaultKey = 'LMENU',
	MaxDistance = 8.0,
	DefaultOptionDistance = 3.0
}
exports = function(name, callback)
	registeredExports[name] = callback
end
GetInvokingResource = function()
	return invoker
end
AddEventHandler = function(name, callback)
	stopHandlers[name] = callback
end
DoesEntityExist = function(entity)
	return world.entities[entity] ~= nil
end
GetHashKey = function(model)
	return type(model) == 'string' and #model or model
end
RegisterCommand = function(name, callback)
	commands[name] = callback
end
RegisterKeyMapping = function(command, description, device, key)
	keyMappings[command] = { description = description, device = device, key = key }
end
CreateThread = function(callback)
	threads[#threads + 1] = callback
end
SendNUIMessage = function(message)
	nuiMessages[#nuiMessages + 1] = message
end
Wait = function()
	error('stop test thread')
end

local vectorMeta = {}
vectorMeta.__index = vectorMeta
vectorMeta.__sub = function(a, b)
	return setmetatable({ x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }, vectorMeta)
end
vectorMeta.__add = function(a, b)
	return setmetatable({ x = a.x + b.x, y = a.y + b.y, z = a.z + b.z }, vectorMeta)
end
vectorMeta.__mul = function(a, s)
	return setmetatable({ x = a.x * s, y = a.y * s, z = a.z * s }, vectorMeta)
end
vectorMeta.__len = function(a)
	return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
end
vector3 = function(x, y, z)
	return setmetatable({ x = x, y = y, z = z }, vectorMeta)
end

GetGameplayCamRot = function()
	return { x = 0, z = 0 }
end
GetGameplayCamCoord = function()
	return vector3(0, 0, 0)
end
StartShapeTestRay = function()
	return 1
end
GetShapeTestResult = function()
	return 0, (world.hit ~= 0 or world.surface) and 1 or 0, world.surface, nil, world.hit
end
IsEntityAttachedToEntity = function(entity)
	return world.attached == entity
end
PlayerPedId = function()
	return 1
end
GetEntityCoords = function(entity)
	if entity == 1 then
		return vector3(world.player.x, world.player.y, world.player.z)
	end
	local data = world.entities[entity]
	return vector3(data.x, 0.0, 0.0)
end
GetEntityModel = function(entity)
	return world.entities[entity].model
end
GetEntityType = function(entity)
	return world.entities[entity].kind
end
IsPedAPlayer = function(entity)
	return world.entities[entity].player == true
end
DisableControlAction = function() end
IsDisabledControlJustPressed = function(_, control)
	return pressed[control] == true
end
local nuiFocus = false
SetCursorLocation = function() end
SetNuiFocus = function(focus)
	nuiFocus = focus
end
local nuiCallbacks = {}
RegisterNUICallback = function(name, callback)
	nuiCallbacks[name] = callback
end
GetCurrentResourceName = function()
	return 'coetarget'
end

dofile('client.lua')

local function assertEqual(actual, expected, label)
	if actual ~= expected then
		error(('%s: expected %s, got %s'):format(label, tostring(expected), tostring(actual)))
	end
end

local mainThread = threads[2]
local function tick()
	pcall(mainThread)
	return nuiMessages[#nuiMessages]
end
local function option(label, extra)
	local value = { label = label, onSelect = function() end }
	for key, field in pairs(extra or {}) do value[key] = field end
	return value
end

world.entities[10] = { kind = 3, model = 111, x = 1.0 }
world.entities[11] = { kind = 3, model = 222, x = 1.0 }
world.entities[12] = { kind = 2, model = 333, x = 2.0 }
world.entities[13] = { kind = 1, model = 444, x = 2.0, player = true }
world.entities[14] = { kind = 1, model = 555, x = 2.0 }
world.entities[15] = { kind = 3, model = 111, x = 9.0 }

-- Validação de registro
assertEqual(registeredExports.AddTargetEntity(10, { option('a') }), true, 'entidade existente')
assertEqual(registeredExports.AddTargetEntity(99, { option('a') }), false, 'entidade inexistente')
assertEqual(registeredExports.AddTargetEntity(10, 'x'), false, 'opções inválidas')
assertEqual(registeredExports.AddTargetEntity(10, { { label = 'sem callback' } }), false, 'opção sem onSelect')
assertEqual(registeredExports.AddTargetGlobal('banana', { option('a') }), false, 'tipo global inválido')
registeredExports.RemoveTargetEntity(10)

assertEqual(keyMappings['+coetarget'].key, Config.DefaultKey, 'tecla configurada')
commands[Config.Command]()

-- Sem entidade: só o indicador
assertEqual(tick().hasTarget, false, 'raycast vazio')

-- Objeto sem interação: indicador, mas nenhuma opção
world.hit = 11
local message = tick()
assertEqual(message.hasTarget, true, 'objeto atingido')
assertEqual(#message.options, 0, 'objeto sem interação não lista nada')

-- Modelo: todos os objetos do modelo, respeitando distância e canInteract
registeredExports.AddTargetModel('x', { option('Modelo 1 char') })
registeredExports.AddTargetModel(111, {
	option('Abrir'),
	option('Longe', { distance = 0.5 }),
	option('Bloqueada', { canInteract = function() return false end }),
	option('Quebrada', { canInteract = function() error('boom') end }),
	option('Perto', { canInteract = function(entity) return entity == 10 end })
})
world.hit = 10
message = tick()
assertEqual(#message.options, 2, 'filtra por distância e canInteract')
assertEqual(message.options[1], 'Abrir', 'primeira opção')
assertEqual(message.options[2], 'Perto', 'canInteract recebe a entidade')
world.hit = 15
assertEqual(#tick().options, 0, 'fora do alcance da opção padrão')

-- Opções de recursos diferentes coexistem no mesmo modelo
invoker = 'res_b'
registeredExports.AddTargetModel(111, { option('Do B') })
world.hit = 10
assertEqual(#tick().options, 3, 'dois donos no mesmo modelo')

-- Globais por tipo
registeredExports.AddTargetGlobal('vehicle', { option('Abrir porta do carro') })
registeredExports.AddTargetGlobal('player', { option('Revistar') })
registeredExports.AddTargetGlobal('object', { option('Qualquer objeto') })
world.hit = 12
assertEqual(tick().options[1], 'Abrir porta do carro', 'global de veículo')
world.hit = 13
assertEqual(tick().options[1], 'Revistar', 'global de jogador')
world.hit = 14
assertEqual(#tick().options, 0, 'NPC sem global de ped')
world.hit = 11
assertEqual(tick().options[1], 'Qualquer objeto', 'global de objeto')

-- Limpeza ao parar um resource
stopHandlers['onClientResourceStop']('res_b')
world.hit = 10
assertEqual(#tick().options, 2, 'registros do resource parado somem')
stopHandlers['onClientResourceStop']('res_a')
assertEqual(#tick().options, 0, 'todos removidos')

-- Remover só o registro do próprio dono
invoker = 'res_a'
registeredExports.AddTargetModel(111, { option('A') })
invoker = 'res_b'
registeredExports.AddTargetModel(111, { option('B') })
registeredExports.RemoveTargetModel(111)
assertEqual(tick().options[1], 'A', 'remoção afeta só o dono')

-- Modo de escolha por mouse: o clique congela as opções e a seleção vem da NUI.
local selected
invoker = 'res_a'
registeredExports.AddTargetEntity(10, {
	option('Um', { onSelect = function() selected = 'um' end }),
	option('Dois', { onSelect = function() selected = 'dois' end })
})
world.hit = 10
message = tick()
assertEqual(message.interactive, false, 'sem clique a lista não é interativa')
assertEqual(nuiFocus, false, 'sem clique não há foco de mouse')
pressed[38] = true
tick()
pressed[38] = nil
assertEqual(selected, nil, 'E não executa mais a opção')

pressed[24] = true
message = tick()
pressed[24] = nil
assertEqual(message.interactive, true, 'clique ativa o modo de escolha')
assertEqual(nuiFocus, true, 'modo de escolha libera o mouse')
assertEqual(#message.options, 3, 'opções congeladas no clique')

nuiCallbacks.menuSelect({ index = 2 }, function() end)
assertEqual(selected, 'dois', 'escolha pelo mouse executa a opção')
assertEqual(nuiFocus, false, 'foco devolvido após escolher')
assertEqual(nuiMessages[#nuiMessages].visible, false, 'UI some após escolher')

-- Índice inválido ou sem menu aberto não executa nada
selected = nil
nuiCallbacks.menuSelect({ index = 1 }, function() end)
assertEqual(selected, nil, 'sem menu aberto é ignorado')
commands[Config.Command]()
commands[Config.Command]()
tick()
pressed[24] = true
tick()
pressed[24] = nil
for _, bad in ipairs({ 0, 3, 1.5, 'x', false }) do
	nuiCallbacks.menuSelect({ index = bad }, function() end)
	assertEqual(selected, nil, 'índice inválido ' .. tostring(bad))
	pressed[24] = true
	tick()
	pressed[24] = nil
end

-- Cancelar devolve o foco
nuiCallbacks.menuClose({}, function() end)
assertEqual(nuiFocus, false, 'cancelar devolve o foco')

-- Opção que deixou de valer entre o clique e a escolha não executa
local allowed = true
registeredExports.AddTargetEntity(10, { option('Condicional', {
	canInteract = function() return allowed end,
	onSelect = function() selected = 'condicional' end
}) })
commands[Config.Command]()
world.hit = 10
tick()
pressed[24] = true
tick()
pressed[24] = nil
allowed = false
nuiCallbacks.menuSelect({ index = 1 }, function() end)
assertEqual(selected, nil, 'opção invalidada não executa')

-- Entidade destruída com o menu aberto fecha o modo de escolha
allowed = true
registeredExports.AddTargetEntity(10, { option('Outra') })
commands[Config.Command]()
tick()
pressed[24] = true
tick()
pressed[24] = nil
assertEqual(nuiFocus, true, 'menu aberto de novo')
world.entities[10] = nil
tick()
assertEqual(nuiFocus, false, 'entidade destruída fecha o menu')
world.entities[10] = { kind = 3, model = 111, x = 1.0 }
registeredExports.AddTargetEntity(10, { option('Erro', { onSelect = function() error('x') end }) })
commands[Config.Command]()
tick()
pressed[24] = true
tick()
pressed[24] = nil
nuiCallbacks.menuSelect({ index = 1 }, function() end)
assertEqual(nuiFocus, false, 'erro no onSelect não deixa o foco preso')
-- Entidade destruída é limpa pela thread de manutenção
world.entities[10] = nil
pcall(threads[1])
world.entities[10] = { kind = 3, model = 999, x = 1.0 }
world.hit = 10
assertEqual(#tick().options, 0, 'registro de entidade antiga não vaza para o novo handle')

-- Superfície: o mapa (entidade 0) também oferece opções, com o ponto atingido
nuiCallbacks.menuClose({}, function() end)
commands[Config.Command]()
stopHandlers['onClientResourceStop']('res_a')
stopHandlers['onClientResourceStop']('res_b')
invoker = 'res_a'
local placedAt
assertEqual(registeredExports.AddTargetSurface({
	option('Colocar aqui', {
		distance = 4.0,
		canInteract = function(entity, _, hit) return entity == 0 and hit ~= nil end,
		onSelect = function(_, _, hit) placedAt = hit end
	})
}), true, 'registra superfície')
world.hit = 0
world.surface = vector3(1.0, 0.0, 0.0)
message = tick()
assertEqual(message.options[1], 'Colocar aqui', 'mapa lista a opção de superfície')
world.surface = vector3(9.0, 0.0, 0.0)
assertEqual(#tick().options, 0, 'superfície fora do alcance')
world.surface = vector3(1.0, 0.0, 0.0)
tick()
pressed[24] = true
tick()
pressed[24] = nil
nuiCallbacks.menuSelect({ index = 1 }, function() end)
assertEqual(placedAt ~= nil and placedAt.x, 1.0, 'onSelect recebe o ponto atingido')
world.surface = nil

-- Prop preso ao jogador (maleta na mão) é atravessado: o ponto vale como superfície
world.hit = 10
world.attached = 10
world.surface = vector3(1.0, 0.0, 0.0)
message = tick()
assertEqual(message.options[1], 'Colocar aqui', 'entidade presa ao jogador vira superfície')
world.attached = nil
world.surface = nil

-- Prop grande com a origem longe: o menu ancora no ponto clicado e não fecha sozinho
commands[Config.Command]()
stopHandlers['onClientResourceStop']('res_a')
invoker = 'res_a'
registeredExports.AddTargetSurface({ option('Colocar aqui', { distance = 4.0, onSelect = function() placedAt = 'ok' end }) })
world.entities[10] = { kind = 3, model = 555, x = 30.0 }
world.hit = 10
world.surface = vector3(1.0, 0.0, 0.0)
commands[Config.Command]()
tick()
pressed[24] = true
tick()
pressed[24] = nil
assertEqual(nuiFocus, true, 'menu aberto em prop grande')
tick()
assertEqual(nuiFocus, true, 'origem distante da entidade não fecha o menu')
placedAt = nil
nuiCallbacks.menuSelect({ index = 1 }, function() end)
assertEqual(placedAt, 'ok', 'seleção em prop grande executa')
world.surface = nil
print('target client tests passed')
