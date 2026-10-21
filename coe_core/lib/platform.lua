--[[
	Coe Framework — Camada de Abstração da Plataforma CFX (Platform / HAL)
	Isola o framework das natives do FiveM / CFX, oferecendo interfaces
	defensivas, tipadas e com suporte a mock para testes automatizados.
]]

CoePlatform = {}
local Platform = CoePlatform

local isServer = false
if type(IsDuplicityVersion) == 'function' then
	isServer = IsDuplicityVersion()
end

-- ============================================================================
-- 1. BACKEND DE MOCK EM MEMÓRIA (Ativo quando fora do FXServer ou via SetMock)
-- ============================================================================
local MockBackend = {
	active = false,
	entities = {}, -- netId / handle -> { coords, heading, model, state, plate, locked, engineHealth, exists, isPed, health, armour, dead, vehicle, seat, bucket }
	players = {},  -- playerId -> { ped, name, ping, endpoint, bucket, state, identifiers = {}, ace = {} }
	buckets = {},  -- bucketId -> { population = true, lockdown = 'inactive' }
	globalState = {},
	nextHandle = 1000,
	nextNetId = 500
}

function MockBackend.Reset()
	MockBackend.entities = {}
	MockBackend.players = {}
	MockBackend.buckets = {}
	MockBackend.globalState = {}
	MockBackend.nextHandle = 1000
	MockBackend.nextNetId = 500
end

local activeMock = nil

function Platform.SetMock(mock)
	activeMock = mock
end

function Platform.GetMock()
	return activeMock
end

local function useMock()
	if activeMock then return activeMock end
	if type(DoesEntityExist) ~= 'function' then
		return MockBackend
	end
	return nil
end

-- ============================================================================
-- 2. UTILITÁRIOS INTERNOS
-- ============================================================================
local function trimString(s)
	if type(s) ~= 'string' then return '' end
	return s:match('^%s*(.-)%s*$') or ''
end

local function safeVector3(x, y, z)
	if type(vector3) == 'function' then
		if type(x) == 'table' or type(x) == 'vector3' then
			return vector3(x.x or 0.0, x.y or 0.0, x.z or 0.0)
		end
		return vector3(tonumber(x) or 0.0, tonumber(y) or 0.0, tonumber(z) or 0.0)
	end
	if type(x) == 'table' then
		return { x = tonumber(x.x) or 0.0, y = tonumber(x.y) or 0.0, z = tonumber(x.z) or 0.0 }
	end
	return { x = tonumber(x) or 0.0, y = tonumber(y) or 0.0, z = tonumber(z) or 0.0 }
end

-- ============================================================================
-- 3. MÓDULO DE ENTIDADES (Core.Platform.Entities)
-- ============================================================================
Platform.Entities = {}
local Entities = Platform.Entities

---Verifica se a entidade existe de forma defensiva
---@param entity integer
---@return boolean
function Entities.Exists(entity)
	if type(entity) ~= 'number' or entity <= 0 then
		return false
	end
	local mock = useMock()
	if mock then
		local data = mock.entities[entity]
		return data ~= nil and data.exists == true
	end
	return DoesEntityExist(entity) == 1 or DoesEntityExist(entity) == true
end

---Obtém as coordenadas tridimensionais da entidade
---@param entity integer
---@return vector3|nil
function Entities.GetCoords(entity)
	if not Entities.Exists(entity) then
		return nil
	end
	local mock = useMock()
	if mock then
		local data = mock.entities[entity]
		return data and data.coords or vector3(0.0, 0.0, 0.0)
	end
	local ok, coords = pcall(GetEntityCoords, entity, false)
	if ok and coords then
		return coords
	end
	return nil
end

---Define as coordenadas da entidade com validação de tipo
---@param entity integer
---@param x number|vector3
---@param y number|nil
---@param z number|nil
---@param clearArea boolean|nil
---@return boolean
function Entities.SetCoords(entity, x, y, z, clearArea)
	if not Entities.Exists(entity) then
		return false
	end
	local v = safeVector3(x, y, z)
	local mock = useMock()
	if mock then
		local data = mock.entities[entity]
		if data then data.coords = v end
		return true
	end
	local ok = pcall(function()
		SetEntityCoords(entity, v.x, v.y, v.z, false, false, false, clearArea == true)
	end)
	return ok
end

---Obtém a orientação (heading) da entidade em graus (0.0 a 360.0)
---@param entity integer
---@return number
function Entities.GetHeading(entity)
	if not Entities.Exists(entity) then
		return 0.0
	end
	local mock = useMock()
	if mock then
		local data = mock.entities[entity]
		return data and data.heading or 0.0
	end
	local ok, heading = pcall(GetEntityHeading, entity)
	return (ok and type(heading) == 'number') and heading or 0.0
end

---Define o heading da entidade
---@param entity integer
---@param heading number
---@return boolean
function Entities.SetHeading(entity, heading)
	if not Entities.Exists(entity) then
		return false
	end
	local h = tonumber(heading) or 0.0
	local mock = useMock()
	if mock then
		local data = mock.entities[entity]
		if data then data.heading = h end
		return true
	end
	local ok = pcall(SetEntityHeading, entity, h)
	return ok
end

---Obtém o hash do modelo da entidade
---@param entity integer
---@return integer
function Entities.GetModel(entity)
	if not Entities.Exists(entity) then
		return 0
	end
	local mock = useMock()
	if mock then
		local data = mock.entities[entity]
		return data and data.model or 0
	end
	local ok, model = pcall(GetEntityModel, entity)
	return (ok and type(model) == 'number') and model or 0
end

---Remove e deleta a entidade do mundo com segurança
---@param entity integer
---@return boolean
function Entities.Delete(entity)
	if not Entities.Exists(entity) then
		return false
	end
	local mock = useMock()
	if mock then
		local data = mock.entities[entity]
		if data then
			data.exists = false
			mock.entities[entity] = nil
		end
		return true
	end
	local ok = pcall(function()
		if not isServer and type(SetEntityAsMissionEntity) == 'function' then
			SetEntityAsMissionEntity(entity, true, true)
		end
		DeleteEntity(entity)
	end)
	return ok
end

---Obtém o Network ID de uma entidade
---@param entity integer
---@return integer|nil
function Entities.GetNetworkId(entity)
	if not Entities.Exists(entity) then
		return nil
	end
	local mock = useMock()
	if mock then
		local data = mock.entities[entity]
		return data and data.netId or nil
	end
	if type(NetworkGetNetworkIdFromEntity) ~= 'function' then
		return nil
	end
	local ok, netId = pcall(NetworkGetNetworkIdFromEntity, entity)
	return (ok and type(netId) == 'number' and netId > 0) and netId or nil
end

---Resolve uma entidade a partir de um Network ID
---@param netId integer
---@return integer|nil
function Entities.FromNetworkId(netId)
	if type(netId) ~= 'number' or netId <= 0 then
		return nil
	end
	local mock = useMock()
	if mock then
		for handle, data in pairs(mock.entities) do
			if data.netId == netId and data.exists then
				return handle
			end
		end
		return nil
	end
	if type(NetworkGetEntityFromNetworkId) ~= 'function' then
		return nil
	end
	local ok, entity = pcall(NetworkGetEntityFromNetworkId, netId)
	if ok and type(entity) == 'number' and entity > 0 and Entities.Exists(entity) then
		return entity
	end
	return nil
end

---Lê um valor do StateBag da entidade
---@param entity integer
---@param key string
---@return any
function Entities.GetState(entity, key)
	if not Entities.Exists(entity) or type(key) ~= 'string' then
		return nil
	end
	local mock = useMock()
	if mock then
		local data = mock.entities[entity]
		return data and data.state and data.state[key] or nil
	end
	if type(Entity) ~= 'function' then
		return nil
	end
	local ok, entObj = pcall(Entity, entity)
	if ok and entObj and entObj.state then
		return entObj.state[key]
	end
	return nil
end

---Grava um valor no StateBag da entidade
---@param entity integer
---@param key string
---@param value any
---@param replicated boolean|nil
---@return boolean
function Entities.SetState(entity, key, value, replicated)
	if not Entities.Exists(entity) or type(key) ~= 'string' then
		return false
	end
	local mock = useMock()
	if mock then
		local data = mock.entities[entity]
		if data then
			if not data.state then data.state = {} end
			data.state[key] = value
		end
		return true
	end
	if type(Entity) ~= 'function' then
		return false
	end
	local ok, entObj = pcall(Entity, entity)
	if ok and entObj and entObj.state and type(entObj.state.set) == 'function' then
		entObj.state:set(key, value, replicated == true)
		return true
	end
	return false
end

-- Metatable da classe CoePlatformEntity
local EntityWrapper = {}
EntityWrapper.__index = EntityWrapper

function EntityWrapper:GetHandle() return self.handle end
function EntityWrapper:Exists() return Entities.Exists(self.handle) end
function EntityWrapper:GetCoords() return Entities.GetCoords(self.handle) end
function EntityWrapper:SetCoords(x, y, z, clearArea) return Entities.SetCoords(self.handle, x, y, z, clearArea) end
function EntityWrapper:GetHeading() return Entities.GetHeading(self.handle) end
function EntityWrapper:SetHeading(h) return Entities.SetHeading(self.handle, h) end
function EntityWrapper:GetModel() return Entities.GetModel(self.handle) end
function EntityWrapper:GetNetworkId() return Entities.GetNetworkId(self.handle) end
function EntityWrapper:GetState(k) return Entities.GetState(self.handle, k) end
function EntityWrapper:SetState(k, v, rep) return Entities.SetState(self.handle, k, v, rep) end
function EntityWrapper:Delete() return Entities.Delete(self.handle) end

---Encapsula uma entidade nativa em um objeto orientado a métodos
---@param entity integer
---@return table|nil
function Entities.Wrap(entity)
	if not Entities.Exists(entity) then
		return nil
	end
	return setmetatable({ handle = entity }, EntityWrapper)
end

-- ============================================================================
-- 4. MÓDULO DE VEÍCULOS (Core.Platform.Vehicles)
-- ============================================================================
Platform.Vehicles = {}
local Vehicles = Platform.Vehicles

---Cria um veículo defensivamente tanto no cliente quanto no servidor
---@param model string|integer
---@param coords vector3|table
---@param heading number|nil
---@param isNetworked boolean|nil
---@return table|nil CoePlatformVehicle
function Vehicles.Create(model, coords, heading, isNetworked)
	local modelHash = type(model) == 'string' and (type(GetHashKey) == 'function' and GetHashKey(model) or 123456) or model
	local pos = safeVector3(coords)
	local h = tonumber(heading) or 0.0
	local net = isNetworked ~= false

	local mock = useMock()
	if mock then
		local handle = mock.nextHandle
		mock.nextHandle = mock.nextHandle + 1
		local netId = mock.nextNetId
		mock.nextNetId = mock.nextNetId + 1

		mock.entities[handle] = {
			exists = true,
			model = modelHash,
			coords = pos,
			heading = h,
			netId = netId,
			plate = 'COE' .. tostring(handle % 10000),
			locked = false,
			engineHealth = 1000.0,
			engineRunning = false,
			state = {}
		}
		return Vehicles.Wrap(handle)
	end

	local handle = 0
	if isServer then
		if type(CreateVehicleServerSetter) == 'function' then
			handle = CreateVehicleServerSetter(modelHash, 'automobile', pos.x, pos.y, pos.z, h)
		elseif type(CreateVehicle) == 'function' then
			handle = CreateVehicle(modelHash, pos.x, pos.y, pos.z, h, net, false)
		end
	else
		if type(CreateVehicle) == 'function' then
			handle = CreateVehicle(modelHash, pos.x, pos.y, pos.z, h, net, false)
		end
	end

	if handle and handle > 0 and Entities.Exists(handle) then
		return Vehicles.Wrap(handle)
	end
	return nil
end

---Obtém a placa normalizada (sem espaços adicionais)
---@param vehicle integer
---@return string
function Vehicles.GetPlate(vehicle)
	if not Entities.Exists(vehicle) then
		return ''
	end
	local mock = useMock()
	if mock then
		local data = mock.entities[vehicle]
		return data and data.plate or ''
	end
	if type(GetVehicleNumberPlateText) ~= 'function' then
		return ''
	end
	local ok, rawPlate = pcall(GetVehicleNumberPlateText, vehicle)
	if ok and type(rawPlate) == 'string' then
		return trimString(rawPlate):upper()
	end
	return ''
end

---Define a placa de um veículo (máximo de 8 caracteres normalizados)
---@param vehicle integer
---@param plate string
---@return boolean
function Vehicles.SetPlate(vehicle, plate)
	if not Entities.Exists(vehicle) then
		return false
	end
	local cleanPlate = trimString(plate):upper():sub(1, 8)
	local mock = useMock()
	if mock then
		local data = mock.entities[vehicle]
		if data then
			data.plate = cleanPlate
			Entities.SetState(vehicle, 'plate', cleanPlate, true)
		end
		return true
	end
	if type(SetVehicleNumberPlateText) ~= 'function' then
		return false
	end
	local ok = pcall(SetVehicleNumberPlateText, vehicle, cleanPlate)
	if ok then
		Entities.SetState(vehicle, 'plate', cleanPlate, true)
		return true
	end
	return false
end

---Verifica se as portas do veículo estão travadas
---@param vehicle integer
---@return boolean
function Vehicles.IsLocked(vehicle)
	if not Entities.Exists(vehicle) then
		return false
	end
	local mock = useMock()
	if mock then
		local data = mock.entities[vehicle]
		return data and data.locked == true
	end
	if type(GetVehicleDoorLockStatus) ~= 'function' then
		return false
	end
	local ok, status = pcall(GetVehicleDoorLockStatus, vehicle)
	return ok and type(status) == 'number' and status >= 2
end

---Trava ou destrava as portas do veículo
---@param vehicle integer
---@param locked boolean
---@return boolean
function Vehicles.SetLocked(vehicle, locked)
	if not Entities.Exists(vehicle) then
		return false
	end
	local isLock = locked == true
	local lockStatus = isLock and 2 or 1

	local mock = useMock()
	if mock then
		local data = mock.entities[vehicle]
		if data then
			data.locked = isLock
			Entities.SetState(vehicle, 'locked', isLock, true)
		end
		return true
	end
	if type(SetVehicleDoorsLocked) ~= 'function' then
		return false
	end
	local ok = pcall(SetVehicleDoorsLocked, vehicle, lockStatus)
	if ok then
		Entities.SetState(vehicle, 'locked', isLock, true)
		return true
	end
	return false
end

---Obtém a integridade do motor (0.0 a 1000.0)
---@param vehicle integer
---@return number
function Vehicles.GetEngineHealth(vehicle)
	if not Entities.Exists(vehicle) then
		return 0.0
	end
	local mock = useMock()
	if mock then
		local data = mock.entities[vehicle]
		return data and data.engineHealth or 1000.0
	end
	if type(GetVehicleEngineHealth) ~= 'function' then
		return 1000.0
	end
	local ok, health = pcall(GetVehicleEngineHealth, vehicle)
	if ok and type(health) == 'number' then
		return math.max(0.0, math.min(1000.0, health))
	end
	return 1000.0
end

---Define a integridade do motor com clamp
---@param vehicle integer
---@param health number
---@return boolean
function Vehicles.SetEngineHealth(vehicle, health)
	if not Entities.Exists(vehicle) then
		return false
	end
	local val = math.max(0.0, math.min(1000.0, tonumber(health) or 1000.0))
	local mock = useMock()
	if mock then
		local data = mock.entities[vehicle]
		if data then data.engineHealth = val end
		return true
	end
	if type(SetVehicleEngineHealth) ~= 'function' then
		return false
	end
	local ok = pcall(SetVehicleEngineHealth, vehicle, val)
	return ok
end

---Verifica se o motor está ligado
---@param vehicle integer
---@return boolean
function Vehicles.IsEngineRunning(vehicle)
	if not Entities.Exists(vehicle) then
		return false
	end
	local mock = useMock()
	if mock then
		local data = mock.entities[vehicle]
		return data and data.engineRunning == true
	end
	if type(GetIsVehicleEngineRunning) ~= 'function' then
		return false
	end
	local ok, running = pcall(GetIsVehicleEngineRunning, vehicle)
	return ok and (running == 1 or running == true)
end

---Encontra ou encapsula um veículo a partir de um Network ID
---@param netId integer
---@return table|nil CoePlatformVehicle
function Vehicles.FromNetworkId(netId)
	local handle = Entities.FromNetworkId(netId)
	if handle then
		return Vehicles.Wrap(handle)
	end
	return nil
end

-- Metatable para o wrapper de veículo (herda métodos de entidade)
local VehicleWrapper = setmetatable({}, { __index = EntityWrapper })
VehicleWrapper.__index = VehicleWrapper

function VehicleWrapper:GetPlate() return Vehicles.GetPlate(self.handle) end
function VehicleWrapper:SetPlate(plate) return Vehicles.SetPlate(self.handle, plate) end
function VehicleWrapper:IsLocked() return Vehicles.IsLocked(self.handle) end
function VehicleWrapper:SetLocked(locked) return Vehicles.SetLocked(self.handle, locked) end
function VehicleWrapper:GetEngineHealth() return Vehicles.GetEngineHealth(self.handle) end
function VehicleWrapper:SetEngineHealth(h) return Vehicles.SetEngineHealth(self.handle, h) end
function VehicleWrapper:IsEngineRunning() return Vehicles.IsEngineRunning(self.handle) end

---Encapsula um veículo nativo em um objeto CoePlatformVehicle
---@param vehicle integer
---@return table|nil
function Vehicles.Wrap(vehicle)
	if not Entities.Exists(vehicle) then
		return nil
	end
	return setmetatable({ handle = vehicle }, VehicleWrapper)
end

-- ============================================================================
-- 5. MÓDULO DE PEDS (Core.Platform.Peds)
-- ============================================================================
Platform.Peds = {}
local Peds = Platform.Peds

---Verifica se o ped existe defensivamente
---@param ped integer
---@return boolean
function Peds.Exists(ped)
	if type(ped) ~= 'number' or ped <= 0 then
		return false
	end
	local mock = useMock()
	if mock then
		local data = mock.entities[ped]
		return data ~= nil and data.exists == true and data.isPed ~= false
	end
	if not Entities.Exists(ped) then
		return false
	end
	if type(IsEntityAPed) == 'function' then
		local ok, isPed = pcall(IsEntityAPed, ped)
		return ok and (isPed == 1 or isPed == true)
	end
	return true
end

---Obtém as coordenadas do ped
---@param ped integer
---@return vector3|nil
function Peds.GetCoords(ped)
	return Entities.GetCoords(ped)
end

---Define as coordenadas do ped
---@param ped integer
---@param x number|vector3
---@param y number|nil
---@param z number|nil
---@param clearArea boolean|nil
---@return boolean
function Peds.SetCoords(ped, x, y, z, clearArea)
	return Entities.SetCoords(ped, x, y, z, clearArea)
end

---Obtém a orientação (heading) do ped
---@param ped integer
---@return number
function Peds.GetHeading(ped)
	return Entities.GetHeading(ped)
end

---Define a orientação do ped
---@param ped integer
---@param heading number
---@return boolean
function Peds.SetHeading(ped, heading)
	return Entities.SetHeading(ped, heading)
end

---Obtém a vida atual do ped (0 a maxHealth, tipicamente 100-200 no GTA V)
---@param ped integer
---@return number
function Peds.GetHealth(ped)
	if not Peds.Exists(ped) then
		return 0
	end
	local mock = useMock()
	if mock then
		local data = mock.entities[ped]
		return data and (data.health or 200) or 0
	end
	if type(GetEntityHealth) ~= 'function' then
		return 200
	end
	local ok, health = pcall(GetEntityHealth, ped)
	return (ok and type(health) == 'number') and health or 0
end

---Define a vida do ped
---@param ped integer
---@param health number
---@return boolean
function Peds.SetHealth(ped, health)
	if not Peds.Exists(ped) then
		return false
	end
	local h = math.max(0, tonumber(health) or 0)
	local mock = useMock()
	if mock then
		local data = mock.entities[ped]
		if data then
			data.health = h
			if h <= 100 then data.dead = true end
		end
		return true
	end
	if type(SetEntityHealth) ~= 'function' then
		return false
	end
	local ok = pcall(SetEntityHealth, ped, h)
	return ok
end

---Obtém a armadura do ped (0 a 100)
---@param ped integer
---@return integer
function Peds.GetArmour(ped)
	if not Peds.Exists(ped) then
		return 0
	end
	local mock = useMock()
	if mock then
		local data = mock.entities[ped]
		return data and (data.armour or 0) or 0
	end
	if type(GetPedArmour) ~= 'function' then
		return 0
	end
	local ok, armour = pcall(GetPedArmour, ped)
	return (ok and type(armour) == 'number') and armour or 0
end

---Define a armadura do ped (clamp 0 a 100)
---@param ped integer
---@param armour number
---@return boolean
function Peds.SetArmour(ped, armour)
	if not Peds.Exists(ped) then
		return false
	end
	local a = math.max(0, math.min(100, math.floor(tonumber(armour) or 0)))
	local mock = useMock()
	if mock then
		local data = mock.entities[ped]
		if data then data.armour = a end
		return true
	end
	if type(SetPedArmour) ~= 'function' then
		return false
	end
	local ok = pcall(SetPedArmour, ped, a)
	return ok
end

---Verifica se o ped está morto ou agonizando
---@param ped integer
---@return boolean
function Peds.IsDead(ped)
	if not Peds.Exists(ped) then
		return true
	end
	local mock = useMock()
	if mock then
		local data = mock.entities[ped]
		if not data then return true end
		return data.dead == true or (data.health ~= nil and data.health <= 100)
	end
	if type(IsPedDeadOrDying) == 'function' then
		local ok, dead = pcall(IsPedDeadOrDying, ped, true)
		if ok and (dead == 1 or dead == true) then
			return true
		end
	end
	if type(IsEntityDead) == 'function' then
		local ok, dead = pcall(IsEntityDead, ped)
		if ok and (dead == 1 or dead == true) then
			return true
		end
	end
	return Peds.GetHealth(ped) <= 100
end

---Obtém o veículo em que o ped está (ou 0 se nenhum)
---@param ped integer
---@return integer
function Peds.GetVehicle(ped)
	if not Peds.Exists(ped) then
		return 0
	end
	local mock = useMock()
	if mock then
		local data = mock.entities[ped]
		return data and data.vehicle or 0
	end
	if type(GetVehiclePedIsIn) ~= 'function' then
		return 0
	end
	local ok, veh = pcall(GetVehiclePedIsIn, ped, false)
	return (ok and type(veh) == 'number' and veh > 0) and veh or 0
end

---Coloca o ped em um assento de veículo
---@param ped integer
---@param vehicle integer
---@param seat integer|nil
---@return boolean
function Peds.SetIntoVehicle(ped, vehicle, seat)
	if not Peds.Exists(ped) or not Entities.Exists(vehicle) then
		return false
	end
	local s = math.floor(tonumber(seat) or -1)
	local mock = useMock()
	if mock then
		local data = mock.entities[ped]
		if data then
			data.vehicle = vehicle
			data.seat = s
		end
		return true
	end
	if type(SetPedIntoVehicle) ~= 'function' then
		return false
	end
	local ok = pcall(SetPedIntoVehicle, ped, vehicle, s)
	return ok
end

---Limpa todas as tarefas e animações do ped
---@param ped integer
---@return boolean
function Peds.ClearTasks(ped)
	if not Peds.Exists(ped) then
		return false
	end
	local mock = useMock()
	if mock then return true end
	if type(ClearPedTasks) ~= 'function' then
		return false
	end
	local ok = pcall(ClearPedTasks, ped)
	return ok
end

-- Metatable do wrapper CoePlatformPed (herda de EntityWrapper)
local PedWrapper = setmetatable({}, { __index = EntityWrapper })
PedWrapper.__index = PedWrapper

function PedWrapper:GetHealth() return Peds.GetHealth(self.handle) end
function PedWrapper:SetHealth(h) return Peds.SetHealth(self.handle, h) end
function PedWrapper:GetArmour() return Peds.GetArmour(self.handle) end
function PedWrapper:SetArmour(a) return Peds.SetArmour(self.handle, a) end
function PedWrapper:IsDead() return Peds.IsDead(self.handle) end
function PedWrapper:GetVehicle() return Peds.GetVehicle(self.handle) end
function PedWrapper:SetIntoVehicle(v, seat) return Peds.SetIntoVehicle(self.handle, v, seat) end
function PedWrapper:ClearTasks() return Peds.ClearTasks(self.handle) end

---Encapsula um ped nativo em um objeto CoePlatformPed
---@param ped integer
---@return table|nil
function Peds.Wrap(ped)
	if not Peds.Exists(ped) then
		return nil
	end
	return setmetatable({ handle = ped }, PedWrapper)
end

-- ============================================================================
-- 6. MÓDULO DE ROUTING BUCKETS / DIMENSÕES (Core.Platform.Routing)
-- ============================================================================
Platform.Routing = {}
local Routing = Platform.Routing

---Obtém a dimensão (routing bucket) do jogador (0 = mundo principal)
---@param playerId integer
---@return integer
function Routing.GetPlayerBucket(playerId)
	local pId = tonumber(playerId)
	if not pId or pId <= 0 then
		return 0
	end
	local mock = useMock()
	if mock then
		local data = mock.players[pId]
		return data and data.bucket or 0
	end
	if not isServer or type(GetPlayerRoutingBucket) ~= 'function' then
		return 0
	end
	local ok, bucket = pcall(GetPlayerRoutingBucket, pId)
	return (ok and type(bucket) == 'number') and bucket or 0
end

---Define a dimensão (routing bucket) do jogador
---@param playerId integer
---@param bucket integer
---@return boolean
function Routing.SetPlayerBucket(playerId, bucket)
	local pId = tonumber(playerId)
	local b = math.floor(tonumber(bucket) or 0)
	if not pId or pId <= 0 or b < 0 then
		return false
	end
	local mock = useMock()
	if mock then
		local data = mock.players[pId]
		if data then data.bucket = b end
		return true
	end
	if not isServer or type(SetPlayerRoutingBucket) ~= 'function' then
		return false
	end
	local ok = pcall(SetPlayerRoutingBucket, pId, b)
	return ok
end

---Obtém a dimensão (routing bucket) de uma entidade
---@param entity integer
---@return integer
function Routing.GetEntityBucket(entity)
	if not Entities.Exists(entity) then
		return 0
	end
	local mock = useMock()
	if mock then
		local data = mock.entities[entity]
		return data and data.bucket or 0
	end
	if not isServer or type(GetEntityRoutingBucket) ~= 'function' then
		return 0
	end
	local ok, bucket = pcall(GetEntityRoutingBucket, entity)
	return (ok and type(bucket) == 'number') and bucket or 0
end

---Define a dimensão (routing bucket) de uma entidade
---@param entity integer
---@param bucket integer
---@return boolean
function Routing.SetEntityBucket(entity, bucket)
	if not Entities.Exists(entity) then
		return false
	end
	local b = math.floor(tonumber(bucket) or 0)
	if b < 0 then return false end
	local mock = useMock()
	if mock then
		local data = mock.entities[entity]
		if data then data.bucket = b end
		return true
	end
	if not isServer or type(SetEntityRoutingBucket) ~= 'function' then
		return false
	end
	local ok = pcall(SetEntityRoutingBucket, entity, b)
	return ok
end

---Habilita ou desabilita população de NPCs na dimensão especificada
---@param bucket integer
---@param enabled boolean
---@return boolean
function Routing.SetPopulationEnabled(bucket, enabled)
	local b = math.floor(tonumber(bucket) or 0)
	if b < 0 then return false end
	local isEn = enabled == true
	local mock = useMock()
	if mock then
		mock.buckets[b] = mock.buckets[b] or {}
		mock.buckets[b].population = isEn
		return true
	end
	if not isServer or type(SetRoutingBucketPopulationEnabled) ~= 'function' then
		return false
	end
	local ok = pcall(SetRoutingBucketPopulationEnabled, b, isEn)
	return ok
end

---Define o modo de bloqueio de entidades na dimensão ('strict', 'relaxed', 'inactive')
---@param bucket integer
---@param mode string|nil
---@return boolean
function Routing.SetLockdownMode(bucket, mode)
	local b = math.floor(tonumber(bucket) or 0)
	local m = mode or 'strict'
	if b < 0 then return false end
	local mock = useMock()
	if mock then
		mock.buckets[b] = mock.buckets[b] or {}
		mock.buckets[b].lockdown = m
		return true
	end
	if not isServer or type(SetRoutingBucketEntityLockdownMode) ~= 'function' then
		return false
	end
	local ok = pcall(SetRoutingBucketEntityLockdownMode, b, m)
	return ok
end

-- ============================================================================
-- 7. MÓDULO DE STATEBAGS (Core.Platform.StateBags)
-- ============================================================================
Platform.StateBags = {}
local StateBags = Platform.StateBags

---Lê um valor do StateBag Global (GlobalState)
---@param key string
---@return any
function StateBags.GetGlobal(key)
	if type(key) ~= 'string' then return nil end
	local mock = useMock()
	if mock then
		return mock.globalState and mock.globalState[key]
	end
	if type(GlobalState) == 'table' or type(GlobalState) == 'userdata' then
		local ok, val = pcall(function() return GlobalState[key] end)
		return ok and val or nil
	end
	return nil
end

---Grava um valor no StateBag Global (GlobalState)
---@param key string
---@param value any
---@param replicated boolean|nil
---@return boolean
function StateBags.SetGlobal(key, value, replicated)
	if type(key) ~= 'string' then return false end
	local mock = useMock()
	if mock then
		mock.globalState[key] = value
		return true
	end
	if not isServer then
		return false
	end
	if type(GlobalState) == 'table' or type(GlobalState) == 'userdata' then
		local ok = pcall(function()
			GlobalState:set(key, value, replicated ~= false)
		end)
		return ok
	end
	return false
end

---Lê um valor do StateBag de um Jogador (Player(id).state)
---@param playerId integer
---@param key string
---@return any
function StateBags.GetPlayer(playerId, key)
	local pId = tonumber(playerId)
	if not pId or pId <= 0 or type(key) ~= 'string' then
		return nil
	end
	local mock = useMock()
	if mock then
		local data = mock.players[pId]
		return data and data.state and data.state[key] or nil
	end
	if type(Player) ~= 'function' then
		return nil
	end
	local ok, playerObj = pcall(Player, pId)
	if ok and playerObj and playerObj.state then
		return playerObj.state[key]
	end
	return nil
end

---Grava um valor no StateBag de um Jogador (Player(id).state)
---@param playerId integer
---@param key string
---@param value any
---@param replicated boolean|nil
---@return boolean
function StateBags.SetPlayer(playerId, key, value, replicated)
	local pId = tonumber(playerId)
	if not pId or pId <= 0 or type(key) ~= 'string' then
		return false
	end
	local mock = useMock()
	if mock then
		local data = mock.players[pId]
		if not data then
			data = { state = {} }
			mock.players[pId] = data
		end
		data.state[key] = value
		return true
	end
	if type(Player) ~= 'function' then
		return false
	end
	local ok, playerObj = pcall(Player, pId)
	if ok and playerObj and playerObj.state and type(playerObj.state.set) == 'function' then
		local okSet = pcall(playerObj.state.set, playerObj.state, key, value, replicated ~= false)
		return okSet
	end
	return false
end

---Lê um valor do StateBag de uma Entidade
---@param entity integer
---@param key string
---@return any
function StateBags.GetEntity(entity, key)
	return Entities.GetState(entity, key)
end

---Grava um valor no StateBag de uma Entidade
---@param entity integer
---@param key string
---@param value any
---@param replicated boolean|nil
---@return boolean
function StateBags.SetEntity(entity, key, value, replicated)
	return Entities.SetState(entity, key, value, replicated)
end

---Registra um escutador de alterações de StateBag
---@param key string
---@param filter string|nil
---@param callback fun(bagName: string, key: string, value: any, reserved: integer, replicated: boolean)
---@return integer|nil
function StateBags.AddChangeHandler(key, filter, callback)
	if type(key) ~= 'string' or type(callback) ~= 'function' then
		return nil
	end
	local mock = useMock()
	if mock then
		return 1234
	end
	if type(AddStateBagChangeHandler) ~= 'function' then
		return nil
	end
	local ok, cookie = pcall(AddStateBagChangeHandler, key, filter or '', callback)
	return ok and cookie or nil
end

-- ============================================================================
-- 8. MÓDULO DE JOGADORES (Core.Platform.Players)
-- ============================================================================
Platform.Players = {}
local Players = Platform.Players

---Obtém o ped associado ao jogador
---@param playerId integer
---@return integer|nil
function Players.GetPed(playerId)
	local pId = tonumber(playerId)
	if not pId or pId <= 0 then
		return nil
	end
	local mock = useMock()
	if mock then
		local data = mock.players[pId]
		if not data then
			local handle = mock.nextHandle
			mock.nextHandle = mock.nextHandle + 1
			data = {
				ped = handle,
				name = 'Player_' .. tostring(pId),
				ping = 25,
				endpoint = '127.0.0.1',
				bucket = 0,
				state = {},
				identifiers = { license = 'license:mock' .. tostring(pId) },
				ace = {}
			}
			mock.players[pId] = data
			mock.entities[handle] = {
				exists = true,
				isPed = true,
				health = 200,
				coords = vector3(0.0, 0.0, 0.0),
				heading = 0.0,
				state = {}
			}
		end
		return data.ped
	end
	if isServer then
		if type(GetPlayerPed) ~= 'function' then
			return nil
		end
		local ok, ped = pcall(GetPlayerPed, pId)
		return (ok and type(ped) == 'number' and ped > 0) and ped or nil
	else
		if type(PlayerId) == 'function' and pId == PlayerId() then
			return type(PlayerPedId) == 'function' and PlayerPedId() or nil
		end
		if type(GetPlayerFromServerId) == 'function' and type(GetPlayerPed) == 'function' then
			local okLocal, localId = pcall(GetPlayerFromServerId, pId)
			if okLocal and localId and localId > 0 then
				local okPed, ped = pcall(GetPlayerPed, localId)
				return (okPed and type(ped) == 'number' and ped > 0) and ped or nil
			end
		end
		return type(PlayerPedId) == 'function' and PlayerPedId() or nil
	end
end

---Obtém o nome do jogador no FiveM (sanitizado)
---@param playerId integer
---@return string
function Players.GetName(playerId)
	local pId = tonumber(playerId)
	if not pId or pId <= 0 then
		return ''
	end
	local mock = useMock()
	if mock then
		local data = mock.players[pId]
		return data and data.name or ('Player_' .. tostring(pId))
	end
	if type(GetPlayerName) ~= 'function' then
		return ''
	end
	local ok, name = pcall(GetPlayerName, pId)
	return (ok and type(name) == 'string') and trimString(name) or ''
end

---Obtém o ping do jogador em milissegundos
---@param playerId integer
---@return integer
function Players.GetPing(playerId)
	local pId = tonumber(playerId)
	if not pId or pId <= 0 then
		return 0
	end
	local mock = useMock()
	if mock then
		local data = mock.players[pId]
		return data and data.ping or 0
	end
	if not isServer or type(GetPlayerPing) ~= 'function' then
		return 0
	end
	local ok, ping = pcall(GetPlayerPing, pId)
	return (ok and type(ping) == 'number' and ping >= 0) and ping or 0
end

---Obtém o IP/endpoint do jogador
---@param playerId integer
---@return string
function Players.GetEndpoint(playerId)
	local pId = tonumber(playerId)
	if not pId or pId <= 0 then
		return ''
	end
	local mock = useMock()
	if mock then
		local data = mock.players[pId]
		return data and data.endpoint or '127.0.0.1'
	end
	if not isServer or type(GetPlayerEndpoint) ~= 'function' then
		return ''
	end
	local ok, endpoint = pcall(GetPlayerEndpoint, pId)
	return (ok and type(endpoint) == 'string') and endpoint or ''
end

---Obtém os identificadores (license, steam, discord, etc.) do jogador de forma estruturada
---@param playerId integer
---@return table { license: string|nil, steam: string|nil, discord: string|nil, fivem: string|nil, ip: string|nil, list: string[] }
function Players.GetIdentifiers(playerId)
	local pId = tonumber(playerId)
	if not pId or pId <= 0 then
		return { list = {} }
	end
	local mock = useMock()
	if mock then
		local data = mock.players[pId]
		local idMap = data and data.identifiers or { license = 'license:mock' .. tostring(pId) }
		local list = {}
		for k, v in pairs(idMap) do
			if k ~= 'list' then
				list[#list + 1] = tostring(v)
			end
		end
		idMap.list = list
		return idMap
	end
	local result = { list = {} }
	if not isServer or type(GetNumPlayerIdentifiers) ~= 'function' or type(GetPlayerIdentifier) ~= 'function' then
		return result
	end
	local okCount, count = pcall(GetNumPlayerIdentifiers, pId)
	if not okCount or type(count) ~= 'number' then
		return result
	end
	for i = 0, count - 1 do
		local okId, id = pcall(GetPlayerIdentifier, pId, i)
		if okId and type(id) == 'string' then
			result.list[#result.list + 1] = id
			local prefix, val = id:match('^([^:]+):(.+)$')
			if prefix and val then
				result[prefix] = id
			end
		end
	end
	return result
end

---Desconecta o jogador do servidor com mensagem amigável
---@param playerId integer
---@param reason string|nil
---@return boolean
function Players.Drop(playerId, reason)
	local pId = tonumber(playerId)
	if not pId or pId <= 0 then
		return false
	end
	local msg = reason or 'Desconectado do servidor.'
	local mock = useMock()
	if mock then
		mock.players[pId] = nil
		return true
	end
	if not isServer or type(DropPlayer) ~= 'function' then
		return false
	end
	local ok = pcall(DropPlayer, pId, msg)
	return ok
end

---Verifica se o jogador possui permissão ACE
---@param playerId integer
---@param ace string
---@return boolean
function Players.IsAceAllowed(playerId, ace)
	local pId = tonumber(playerId)
	if not pId or type(ace) ~= 'string' then
		return false
	end
	local mock = useMock()
	if mock then
		local data = mock.players[pId]
		return data and data.ace and data.ace[ace] == true or false
	end
	if type(IsPlayerAceAllowed) ~= 'function' then
		return false
	end
	local ok, allowed = pcall(IsPlayerAceAllowed, pId, ace)
	return ok and (allowed == 1 or allowed == true)
end

---Obtém a lista de IDs de todos os jogadores online como números
---@return integer[]
function Players.GetAll()
	local mock = useMock()
	if mock then
		local list = {}
		for id, _ in pairs(mock.players) do
			list[#list + 1] = id
		end
		table.sort(list)
		if #list == 0 then list = { 1 } end
		return list
	end
	local list = {}
	if isServer and type(GetPlayers) == 'function' then
		local ok, rawPlayers = pcall(GetPlayers)
		if ok and type(rawPlayers) == 'table' then
			for _, idStr in ipairs(rawPlayers) do
				local num = tonumber(idStr)
				if num and num > 0 then
					list[#list + 1] = num
				end
			end
			table.sort(list)
			return list
		end
	elseif not isServer and type(GetActivePlayers) == 'function' then
		local ok, rawPlayers = pcall(GetActivePlayers)
		if ok and type(rawPlayers) == 'table' then
			for _, pId in ipairs(rawPlayers) do
				local num = tonumber(pId)
				if num and num >= 0 then
					list[#list + 1] = num
				end
			end
			table.sort(list)
			return list
		end
	end
	return list
end

---Obtém a dimensão / routing bucket do jogador
---@param playerId integer
---@return integer
function Players.GetRoutingBucket(playerId)
	return Routing.GetPlayerBucket(playerId)
end

---Define a dimensão / routing bucket do jogador
---@param playerId integer
---@param bucket integer
---@return boolean
function Players.SetRoutingBucket(playerId, bucket)
	return Routing.SetPlayerBucket(playerId, bucket)
end

---Obtém um valor do state bag do jogador
---@param playerId integer
---@param key string
---@return any
function Players.GetState(playerId, key)
	return StateBags.GetPlayer(playerId, key)
end

---Grava um valor no state bag do jogador
---@param playerId integer
---@param key string
---@param value any
---@param replicated boolean|nil
---@return boolean
function Players.SetState(playerId, key, value, replicated)
	return StateBags.SetPlayer(playerId, key, value, replicated)
end

-- Wrapper CoePlatformPlayer
local PlayerWrapper = {}
PlayerWrapper.__index = PlayerWrapper

function PlayerWrapper:GetId() return self.playerId end
function PlayerWrapper:GetPed() return Players.GetPed(self.playerId) end
function PlayerWrapper:GetName() return Players.GetName(self.playerId) end
function PlayerWrapper:GetPing() return Players.GetPing(self.playerId) end
function PlayerWrapper:GetEndpoint() return Players.GetEndpoint(self.playerId) end
function PlayerWrapper:GetIdentifiers() return Players.GetIdentifiers(self.playerId) end
function PlayerWrapper:GetBucket() return Players.GetRoutingBucket(self.playerId) end
function PlayerWrapper:SetBucket(b) return Players.SetRoutingBucket(self.playerId, b) end
function PlayerWrapper:GetState(k) return Players.GetState(self.playerId, k) end
function PlayerWrapper:SetState(k, v, rep) return Players.SetState(self.playerId, k, v, rep) end
function PlayerWrapper:IsAceAllowed(ace) return Players.IsAceAllowed(self.playerId, ace) end
function PlayerWrapper:Drop(reason) return Players.Drop(self.playerId, reason) end

---Encapsula um jogador em um objeto CoePlatformPlayer
---@param playerId integer
---@return table|nil
function Players.Wrap(playerId)
	local pId = tonumber(playerId)
	if not pId or pId <= 0 then
		return nil
	end
	return setmetatable({ playerId = pId }, PlayerWrapper)
end

return Platform
