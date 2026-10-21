--[[
	Testes unitários da Camada de Plataforma (Platform / HAL) do Coe Framework
	Valida o isolamento de natives, comportamento defensivo e suporte a mock.
]]

-- Helper básico de assertions
if type(vector3) ~= 'function' then
	vector3 = function(x, y, z)
		return { x = tonumber(x) or 0.0, y = tonumber(y) or 0.0, z = tonumber(z) or 0.0 }
	end
end

local function assertEqual(actual, expected, message)
	if actual ~= expected then
		error(string.format('%s: esperado %s, recebido %s', message or 'Falha na asserção', tostring(expected), tostring(actual)), 2)
	end
end

local function assertTrue(condition, message)
	if condition ~= true then
		error(message or 'Esperava true', 2)
	end
end

local function assertFalse(condition, message)
	if condition ~= false then
		error(message or 'Esperava false', 2)
	end
end

-- Simulação de ambiente e carregamento do módulo
local Platform = dofile('lib/platform.lua')
assertTrue(type(Platform) == 'table', 'Platform deve ser uma tabela')
assertTrue(type(Platform.Entities) == 'table', 'Platform.Entities deve existir')
assertTrue(type(Platform.Vehicles) == 'table', 'Platform.Vehicles deve existir')

-- ============================================================================
-- 1. TESTES DE ENTIDADES (Core.Platform.Entities)
-- ============================================================================
local Entities = Platform.Entities

-- 1.1 Exists defensivo
assertFalse(Entities.Exists(nil), 'nil não deve existir')
assertFalse(Entities.Exists(0), 'handle 0 não deve existir')
assertFalse(Entities.Exists(-1), 'handle negativo não deve existir')
assertFalse(Entities.Exists(9999), 'handle inexistente não deve existir')

-- 1.2 Criação e manipulação de veículo via Vehicles.Create (popula mock)
local veh = Platform.Vehicles.Create('adder', vector3(100.0, 200.0, 30.0), 90.0)
assertTrue(veh ~= nil, 'Veículo criado deve retornar um wrapper válido')
assertTrue(veh:Exists(), 'Veículo criado deve existir')
assertTrue(Entities.Exists(veh:GetHandle()), 'Entities.Exists com handle deve retornar true')

-- 1.3 Coordenadas e Heading
local coords = veh:GetCoords()
assertTrue(coords ~= nil, 'Coordenadas devem ser retornadas')
assertEqual(coords.x, 100.0, 'Coord X deve bater')
assertEqual(coords.y, 200.0, 'Coord Y deve bater')
assertEqual(coords.z, 30.0, 'Coord Z deve bater')

local heading = veh:GetHeading()
assertEqual(heading, 90.0, 'Heading inicial deve bater')

veh:SetCoords(vector3(500.0, 600.0, 10.0))
local newCoords = veh:GetCoords()
assertEqual(newCoords.x, 500.0, 'Nova coord X deve bater')
assertEqual(newCoords.y, 600.0, 'Nova coord Y deve bater')

veh:SetHeading(180.0)
assertEqual(veh:GetHeading(), 180.0, 'Novo heading deve bater')

-- 1.4 Network ID e resolução reversa
local netId = veh:GetNetworkId()
assertTrue(type(netId) == 'number' and netId > 0, 'NetworkId deve ser um número positivo')

local resolvedHandle = Entities.FromNetworkId(netId)
assertEqual(resolvedHandle, veh:GetHandle(), 'FromNetworkId deve resolver para o handle correto')

local resolvedVeh = Platform.Vehicles.FromNetworkId(netId)
assertTrue(resolvedVeh ~= nil, 'Vehicles.FromNetworkId deve retornar o wrapper do veículo')
assertEqual(resolvedVeh:GetHandle(), veh:GetHandle(), 'Vehicles.FromNetworkId deve ter o mesmo handle')

-- 1.5 StateBag
assertFalse(Entities.SetState(9999, 'test', 123), 'SetState em entidade inexistente deve falhar')
assertTrue(veh:SetState('fuel', 85.5, true), 'SetState em veículo deve funcionar')
assertEqual(veh:GetState('fuel'), 85.5, 'GetState deve retornar o valor gravado')

-- ============================================================================
-- 2. TESTES DE VEÍCULOS (Core.Platform.Vehicles)
-- ============================================================================
local Vehicles = Platform.Vehicles

-- 2.1 Placa
local initialPlate = veh:GetPlate()
assertTrue(type(initialPlate) == 'string' and #initialPlate > 0, 'Placa inicial deve existir')

assertTrue(veh:SetPlate(' coe 1234 '), 'SetPlate deve aceitar string com espaços')
assertEqual(veh:GetPlate(), 'COE 1234', 'GetPlate deve normalizar e converter para uppercase')
assertEqual(veh:GetState('plate'), 'COE 1234', 'SetPlate deve sincronizar com o statebag')

-- Truncamento em 8 caracteres
assertTrue(veh:SetPlate('MUITOLONGA123'), 'SetPlate deve aceitar string longa')
assertEqual(#veh:GetPlate(), 8, 'Placa deve ser truncada em 8 caracteres')

-- 2.2 Trava de portas
assertFalse(veh:IsLocked(), 'Veículo recém-criado deve estar destravado')

assertTrue(veh:SetLocked(true), 'SetLocked(true) deve ter sucesso')
assertTrue(veh:IsLocked(), 'IsLocked() deve retornar true após trancar')
assertEqual(veh:GetState('locked'), true, 'Statebag locked deve ser sincronizado')

assertTrue(veh:SetLocked(false), 'SetLocked(false) deve ter sucesso')
assertFalse(veh:IsLocked(), 'IsLocked() deve retornar false após destravar')

-- 2.3 Saúde do motor
assertEqual(veh:GetEngineHealth(), 1000.0, 'Saúde inicial do motor deve ser 1000.0')

assertTrue(veh:SetEngineHealth(650.0), 'SetEngineHealth deve funcionar')
assertEqual(veh:GetEngineHealth(), 650.0, 'GetEngineHealth deve retornar 650.0')

-- Clamp de saúde do motor (0 a 1000)
veh:SetEngineHealth(-50.0)
assertEqual(veh:GetEngineHealth(), 0.0, 'Saúde negativa deve ser limitada a 0.0')

veh:SetEngineHealth(1500.0)
assertEqual(veh:GetEngineHealth(), 1000.0, 'Saúde acima de 1000 deve ser limitada a 1000.0')

-- 2.4 Remoção / Deleção
local handleToDelete = veh:GetHandle()
assertTrue(veh:Delete(), 'Delete deve retornar true')
assertFalse(veh:Exists(), 'Após Delete, veh:Exists deve retornar false')
assertFalse(Entities.Exists(handleToDelete), 'Após Delete, Entities.Exists deve retornar false')
assertEqual(Entities.FromNetworkId(netId), nil, 'Após Delete, FromNetworkId deve retornar nil')

-- ============================================================================
-- 3. TESTES DE INTEGRAÇÃO COM LIB/INIT.LUA
-- ============================================================================
-- Simula export coe_core retornando o Core
exports = {
	coe_core = {
		GetCoreObject = function()
			return {
				Prefix = 'coe_core',
				Classes = { Registry = {} },
				Events = {},
				Platform = Platform
			}
		end
	}
}

-- Requer dofile em lib/init.lua
dofile('lib/init.lua')
assertTrue(Core ~= nil, 'Core global deve existir após init.lua')
assertTrue(Core.Platform ~= nil, 'Core.Platform deve estar presente no Core')
assertTrue(type(Core.Platform.Entities.Exists) == 'function', 'Core.Platform.Entities.Exists deve ser função')
assertTrue(type(Core.Platform.Vehicles.Create) == 'function', 'Core.Platform.Vehicles.Create deve ser função')
assertTrue(type(Core.Platform.Peds.Exists) == 'function', 'Core.Platform.Peds.Exists deve ser função')
assertTrue(type(Core.Platform.Players.GetPed) == 'function', 'Core.Platform.Players.GetPed deve ser função')
assertTrue(type(Core.Platform.Routing.GetPlayerBucket) == 'function', 'Core.Platform.Routing.GetPlayerBucket deve ser função')
assertTrue(type(Core.Platform.StateBags.GetGlobal) == 'function', 'Core.Platform.StateBags.GetGlobal deve ser função')

-- ============================================================================
-- 4. TESTES DE PEDS (Core.Platform.Peds)
-- ============================================================================
local Peds = Platform.Peds

-- 4.1 Criação indireta via mock e validações defensivas
assertFalse(Peds.Exists(nil), 'nil ped não existe')
assertFalse(Peds.Exists(0), 'ped handle 0 não existe')
assertFalse(Peds.Exists(-5), 'ped handle negativo não existe')

local playerPed = Platform.Players.GetPed(1)
assertTrue(playerPed ~= nil and playerPed > 0, 'Players.GetPed deve gerar/retornar ped válido')
assertTrue(Peds.Exists(playerPed), 'Peds.Exists deve ser true para ped válido')

local pedWrap = Peds.Wrap(playerPed)
assertTrue(pedWrap ~= nil, 'Peds.Wrap deve retornar wrapper')
assertEqual(pedWrap:GetHandle(), playerPed, 'Handle do wrapper de ped deve bater')

-- 4.2 Vida e Morte
assertEqual(pedWrap:GetHealth(), 200, 'Vida padrão deve ser 200')
assertFalse(pedWrap:IsDead(), 'Ped com vida 200 não está morto')

pedWrap:SetHealth(100)
assertEqual(pedWrap:GetHealth(), 100, 'Vida deve ser 100 após SetHealth')
assertTrue(pedWrap:IsDead(), 'Ped com vida <= 100 é considerado morto')

pedWrap:SetHealth(180)
assertEqual(pedWrap:GetHealth(), 180, 'Vida atualizada')

-- 4.3 Armadura
assertEqual(pedWrap:GetArmour(), 0, 'Armadura inicial deve ser 0')
assertTrue(pedWrap:SetArmour(50), 'SetArmour deve ter sucesso')
assertEqual(pedWrap:GetArmour(), 50, 'Armadura deve ser 50')

pedWrap:SetArmour(150)
assertEqual(pedWrap:GetArmour(), 100, 'Armadura deve sofrer clamp em 100')

pedWrap:SetArmour(-20)
assertEqual(pedWrap:GetArmour(), 0, 'Armadura deve sofrer clamp em 0')

-- 4.4 Coordenadas e Heading
pedWrap:SetCoords(vector3(15.0, 25.0, 35.0))
local pCoords = pedWrap:GetCoords()
assertEqual(pCoords.x, 15.0, 'Coord X do ped deve bater')
assertEqual(pCoords.y, 25.0, 'Coord Y do ped deve bater')
assertEqual(pCoords.z, 35.0, 'Coord Z do ped deve bater')

pedWrap:SetHeading(270.0)
assertEqual(pedWrap:GetHeading(), 270.0, 'Heading do ped deve bater')

-- 4.5 Veículo e Tarefas
assertEqual(pedWrap:GetVehicle(), 0, 'Ped sem veículo retorna 0')
local testCar = Platform.Vehicles.Create('blista', vector3(0.0, 0.0, 0.0))
assertTrue(testCar ~= nil, 'Veículo de teste criado')

assertTrue(pedWrap:SetIntoVehicle(testCar:GetHandle(), -1), 'SetIntoVehicle no motorista')
assertEqual(pedWrap:GetVehicle(), testCar:GetHandle(), 'GetVehicle deve retornar handle do veículo')

assertTrue(pedWrap:ClearTasks(), 'ClearTasks deve retornar true')

-- ============================================================================
-- 5. TESTES DE JOGADORES (Core.Platform.Players)
-- ============================================================================
local Players = Platform.Players

local pObj = Players.Wrap(1)
assertTrue(pObj ~= nil, 'Players.Wrap(1) deve retornar wrapper')
assertEqual(pObj:GetId(), 1, 'Id do player deve ser 1')
assertEqual(pObj:GetPed(), playerPed, 'Ped do player deve ser o mesmo criado')
assertEqual(pObj:GetPing(), 25, 'Ping mock padrão deve ser 25')
assertEqual(pObj:GetEndpoint(), '127.0.0.1', 'Endpoint padrão deve ser 127.0.0.1')
assertTrue(pObj:GetName() ~= '', 'Nome não deve ser vazio')

local idents = pObj:GetIdentifiers()
assertTrue(type(idents) == 'table', 'Identifiers deve ser tabela')
assertTrue(idents.license ~= nil, 'License deve existir no mock')

local allPlayers = Players.GetAll()
assertTrue(type(allPlayers) == 'table' and #allPlayers >= 1, 'GetAll deve retornar lista de jogadores')

-- ============================================================================
-- 6. TESTES DE ROUTING BUCKETS (Core.Platform.Routing)
-- ============================================================================
local Routing = Platform.Routing

assertEqual(Routing.GetPlayerBucket(1), 0, 'Bucket inicial do jogador deve ser 0 (mundo principal)')
assertTrue(Routing.SetPlayerBucket(1, 42), 'SetPlayerBucket deve ter sucesso')
assertEqual(Routing.GetPlayerBucket(1), 42, 'Bucket do jogador deve ser 42')
assertEqual(pObj:GetBucket(), 42, 'Wrapper deve refletir bucket 42')

assertEqual(Routing.GetEntityBucket(testCar:GetHandle()), 0, 'Bucket inicial da entidade deve ser 0')
assertTrue(Routing.SetEntityBucket(testCar:GetHandle(), 42), 'SetEntityBucket deve ter sucesso')
assertEqual(Routing.GetEntityBucket(testCar:GetHandle()), 42, 'Bucket da entidade deve ser 42')

assertTrue(Routing.SetPopulationEnabled(42, false), 'SetPopulationEnabled deve ter sucesso')
assertTrue(Routing.SetLockdownMode(42, 'strict'), 'SetLockdownMode deve ter sucesso')

-- ============================================================================
-- 7. TESTES DE STATEBAGS (Core.Platform.StateBags)
-- ============================================================================
local StateBags = Platform.StateBags

-- 7.1 GlobalState
assertEqual(StateBags.GetGlobal('weather'), nil, 'Weather inicial deve ser nil')
assertTrue(StateBags.SetGlobal('weather', 'CLEAR'), 'SetGlobal weather deve ter sucesso')
assertEqual(StateBags.GetGlobal('weather'), 'CLEAR', 'GetGlobal weather deve retornar CLEAR')

-- 7.2 Player StateBag
assertEqual(StateBags.GetPlayer(1, 'roleplay_status'), nil, 'Status inicial nil')
assertTrue(StateBags.SetPlayer(1, 'roleplay_status', 'in_coma'), 'SetPlayer statebag')
assertEqual(StateBags.GetPlayer(1, 'roleplay_status'), 'in_coma', 'GetPlayer statebag conferido')
assertEqual(pObj:GetState('roleplay_status'), 'in_coma', 'Wrapper GetState conferido')

-- 7.3 Entity StateBag
assertTrue(StateBags.SetEntity(testCar:GetHandle(), 'trunk_locked', true), 'SetEntity statebag')
assertEqual(StateBags.GetEntity(testCar:GetHandle(), 'trunk_locked'), true, 'GetEntity statebag')

-- 7.4 Change Handler
local handlerId = StateBags.AddChangeHandler('roleplay_status', nil, function() end)
assertTrue(handlerId ~= nil, 'AddChangeHandler deve retornar identificador/cookie')

-- Limpeza
testCar:Delete()

print('✅ Todos os testes de Core.Platform (Fases 1, 2 e 3: Entities, Vehicles, Peds, Players, Routing e StateBags) passaram com sucesso!')
