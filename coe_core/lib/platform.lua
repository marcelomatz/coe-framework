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
	colshapes = {}, -- id -> shapeData
	globalState = {},
	nextHandle = 1000,
	nextNetId = 500,
	nextColshapeId = 1
}

function MockBackend.Reset()
	MockBackend.entities = {}
	MockBackend.players = {}
	MockBackend.buckets = {}
	MockBackend.colshapes = {}
	MockBackend.globalState = {}
	MockBackend.nextHandle = 1000
	MockBackend.nextNetId = 500
	MockBackend.nextColshapeId = 1
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

-- Runtime real do FiveM: só lá `Citizen.InvokeNative` existe (os testes offline não o simulam).
local function isFivemRuntime()
	return type(Citizen) == 'table' and type(Citizen.InvokeNative) == 'function'
end

local function entityValid(entity)
	if type(entity) ~= 'number' or entity <= 0 then
		return false
	end
	if not activeMock and (not isFivemRuntime() or type(DoesEntityExist) ~= 'function') then
		return true
	end
	return Entities.Exists(entity)
end

---Obtém as coordenadas tridimensionais da entidade
---@param entity integer
---@return vector3|nil
function Entities.GetCoords(entity)
	if not activeMock and type(GetEntityCoords) == 'function' then
		if not entityValid(entity) then return nil end
		local ok, coords = pcall(GetEntityCoords, entity, false)
		return ok and coords or nil
	end
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
	if not activeMock and type(SetEntityCoords) == 'function' then
		if not entityValid(entity) then return false end
		local v = safeVector3(x, y, z)
		local ok = pcall(function()
			SetEntityCoords(entity, v.x, v.y, v.z, false, false, false, clearArea == true)
		end)
		return ok
	end
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
	if not activeMock and type(GetEntityHeading) == 'function' then
		if not entityValid(entity) then return 0.0 end
		local ok, heading = pcall(GetEntityHeading, entity)
		return (ok and type(heading) == 'number') and heading or 0.0
	end
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
	if not activeMock and type(SetEntityHeading) == 'function' then
		if not entityValid(entity) then return false end
		local h = tonumber(heading) or 0.0
		local ok = pcall(SetEntityHeading, entity, h)
		return ok
	end
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
	if not activeMock and type(GetEntityModel) == 'function' then
		if not entityValid(entity) then return 0 end
		local ok, model = pcall(GetEntityModel, entity)
		return (ok and type(model) == 'number') and model or 0
	end
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
	if not activeMock and type(DeleteEntity) == 'function' then
		if not entityValid(entity) then return false end
		local ok = pcall(function()
			if not isServer and type(SetEntityAsMissionEntity) == 'function' then
				SetEntityAsMissionEntity(entity, true, true)
			end
			DeleteEntity(entity)
		end)
		return ok
	end
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
	if not activeMock and type(NetworkGetNetworkIdFromEntity) == 'function' then
		if not entityValid(entity) then return nil end
		local ok, netId = pcall(NetworkGetNetworkIdFromEntity, entity)
		return (ok and type(netId) == 'number' and netId > 0) and netId or nil
	end
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
	if not activeMock and type(NetworkGetEntityFromNetworkId) == 'function' then
		local ok, entity = pcall(NetworkGetEntityFromNetworkId, netId)
		if ok and type(entity) == 'number' and entity > 0 and entityValid(entity) then
			return entity
		end
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
---Obtém o dono de rede (source do jogador) da entidade, ou nil se pertencer ao servidor/ninguém.
---@param entity integer
---@return integer|nil
function Entities.GetOwner(entity)
	if type(entity) ~= 'number' or entity <= 0 then
		return nil
	end
	if not activeMock and type(NetworkGetEntityOwner) == 'function' then
		if not entityValid(entity) then return nil end
		local ok, owner = pcall(NetworkGetEntityOwner, entity)
		return (ok and type(owner) == 'number' and owner > 0) and owner or nil
	end
	local mock = useMock()
	if mock then
		local data = mock.entities[entity]
		return (data and type(data.owner) == 'number' and data.owner > 0) and data.owner or nil
	end
	if type(NetworkGetEntityOwner) ~= 'function' then
		return nil
	end
	local ok, owner = pcall(NetworkGetEntityOwner, entity)
	return (ok and type(owner) == 'number' and owner > 0) and owner or nil
end

---Obtém o tipo da entidade (1 = Ped, 2 = Vehicle, 3 = Object, 0 = desconhecido).
---@param entity integer
---@return integer
function Entities.GetType(entity)
	if type(entity) ~= 'number' or entity <= 0 then
		return 0
	end
	if not activeMock and type(GetEntityType) == 'function' then
		if not entityValid(entity) then return 0 end
		local ok, entType = pcall(GetEntityType, entity)
		return (ok and type(entType) == 'number') and entType or 0
	end
	local mock = useMock()
	if mock then
		local data = mock.entities[entity]
		return (data and type(data.entityType) == 'number') and data.entityType or 0
	end
	if type(GetEntityType) ~= 'function' then
		return 0
	end
	local ok, entType = pcall(GetEntityType, entity)
	return (ok and type(entType) == 'number') and entType or 0
end

---Obtém o populationType da entidade (ex.: 7 = script entity).
---@param entity integer
---@return integer
function Entities.GetPopulationType(entity)
	if type(entity) ~= 'number' or entity <= 0 then
		return 0
	end
	if not activeMock and type(GetEntityPopulationType) == 'function' then
		if not entityValid(entity) then return 0 end
		local ok, popType = pcall(GetEntityPopulationType, entity)
		return (ok and type(popType) == 'number') and popType or 0
	end
	local mock = useMock()
	if mock then
		local data = mock.entities[entity]
		return (data and type(data.populationType) == 'number') and data.populationType or 0
	end
	if type(GetEntityPopulationType) ~= 'function' then
		return 0
	end
	local ok, popType = pcall(GetEntityPopulationType, entity)
	return (ok and type(popType) == 'number') and popType or 0
end

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
function EntityWrapper:GetOwner() return Entities.GetOwner(self.handle) end
function EntityWrapper:GetType() return Entities.GetType(self.handle) end
function EntityWrapper:GetPopulationType() return Entities.GetPopulationType(self.handle) end
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
	if not activeMock and type(GetVehicleNumberPlateText) == 'function' then
		if not entityValid(vehicle) then return '' end
		local ok, rawPlate = pcall(GetVehicleNumberPlateText, vehicle)
		return (ok and type(rawPlate) == 'string') and trimString(rawPlate):upper() or ''
	end
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
	local cleanPlate = trimString(plate):upper():sub(1, 8)
	if not activeMock and type(SetVehicleNumberPlateText) == 'function' then
		if not entityValid(vehicle) then return false end
		local ok = pcall(SetVehicleNumberPlateText, vehicle, cleanPlate)
		if ok then
			Entities.SetState(vehicle, 'plate', cleanPlate, true)
			return true
		end
		return false
	end
	if not Entities.Exists(vehicle) then
		return false
	end
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
	if not activeMock and type(GetVehicleDoorLockStatus) == 'function' then
		if not entityValid(vehicle) then return false end
		local ok, status = pcall(GetVehicleDoorLockStatus, vehicle)
		return ok and type(status) == 'number' and status >= 2
	end
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
	local isLock = locked == true
	local lockStatus = isLock and 2 or 1
	if not activeMock and type(SetVehicleDoorsLocked) == 'function' then
		if not entityValid(vehicle) then return false end
		local ok = pcall(SetVehicleDoorsLocked, vehicle, lockStatus)
		if ok then
			Entities.SetState(vehicle, 'locked', isLock, true)
			return true
		end
		return false
	end
	if not Entities.Exists(vehicle) then
		return false
	end

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
	if not activeMock and type(GetVehicleEngineHealth) == 'function' then
		if not entityValid(vehicle) then return 0.0 end
		local ok, health = pcall(GetVehicleEngineHealth, vehicle)
		if ok and type(health) == 'number' then
			return math.max(0.0, math.min(1000.0, health))
		end
		return 1000.0
	end
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
	local val = math.max(0.0, math.min(1000.0, tonumber(health) or 1000.0))
	if not activeMock and type(SetVehicleEngineHealth) == 'function' then
		if not entityValid(vehicle) then return false end
		local ok = pcall(SetVehicleEngineHealth, vehicle, val)
		return ok
	end
	if not Entities.Exists(vehicle) then
		return false
	end
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
	if not activeMock and type(GetIsVehicleEngineRunning) == 'function' then
		if not entityValid(vehicle) then return false end
		local ok, running = pcall(GetIsVehicleEngineRunning, vehicle)
		return ok and (running == 1 or running == true)
	end
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
	local ok = pcall(SetEntityHealth, ped, math.floor(h))
	return ok
end

---Obtém a vida máxima do ped (padrão 200 no GTA V, extensível até 250+ em condicionamento físico)
---@param ped integer
---@return integer
function Peds.GetMaxHealth(ped)
	if not Peds.Exists(ped) then
		return 0
	end
	local mock = useMock()
	if mock then
		local data = mock.entities[ped]
		return data and (data.maxHealth or 200) or 0
	end
	if type(GetEntityMaxHealth) == 'function' then
		local ok, maxH = pcall(GetEntityMaxHealth, ped)
		if ok and type(maxH) == 'number' and maxH > 0 then
			return math.floor(maxH)
		end
	end
	if type(GetPedMaxHealth) == 'function' then
		local ok, maxH = pcall(GetPedMaxHealth, ped)
		if ok and type(maxH) == 'number' and maxH > 0 then
			return math.floor(maxH)
		end
	end
	return 200
end

---Define a vida máxima do ped (SetEntityMaxHealth e SetPedMaxHealth encapsulados na HAL)
---@param ped integer
---@param maxHealth number
---@return boolean
function Peds.SetMaxHealth(ped, maxHealth)
	if not Peds.Exists(ped) then
		return false
	end
	local mh = math.max(100, math.min(500, math.floor(tonumber(maxHealth) or 200)))
	local mock = useMock()
	if mock then
		local data = mock.entities[ped]
		if data then
			data.maxHealth = mh
			if data.health and data.health > mh then
				data.health = mh
			end
		end
		return true
	end
	if isServer then
		return false
	end
	local okAny = false
	if type(SetEntityMaxHealth) == 'function' then
		local ok1 = pcall(SetEntityMaxHealth, ped, mh)
		okAny = okAny or ok1
	end
	if type(SetPedMaxHealth) == 'function' then
		local ok2 = pcall(SetPedMaxHealth, ped, mh)
		okAny = okAny or ok2
	end
	return okAny
end

---Configura estatísticas fisiológicas do ped (MP0_STAMINA, MP0_STRENGTH e tempo submerso)
---@param ped integer
---@param staminaInt number
---@param strengthInt number
---@param maxWaterTimeSeconds number|nil
---@return boolean
function Peds.SetFitnessStats(ped, staminaInt, strengthInt, maxWaterTimeSeconds)
	if not Peds.Exists(ped) then
		return false
	end
	local stam = math.max(0, math.min(100, math.floor(tonumber(staminaInt) or 0)))
	local str = math.max(0, math.min(100, math.floor(tonumber(strengthInt) or 0)))
	local waterSec = maxWaterTimeSeconds and math.max(5.0, math.min(120.0, tonumber(maxWaterTimeSeconds) or 15.0)) or nil

	local mock = useMock()
	if mock then
		local data = mock.entities[ped]
		if data then
			data.fitnessStats = {
				stamina = stam,
				strength = str,
				maxWaterTimeSeconds = waterSec or 15.0
			}
		end
		return true
	end
	if isServer then
		return false
	end
	if type(StatSetInt) == 'function' and type(GetHashKey) == 'function' then
		pcall(StatSetInt, GetHashKey('MP0_STAMINA'), stam, true)
		pcall(StatSetInt, GetHashKey('MP0_STRENGTH'), str, true)
	end
	if waterSec and type(SetPedMaxTimeInWater) == 'function' then
		pcall(SetPedMaxTimeInWater, ped, waterSec + 0.0)
	end
	return true
end

---Obtém as estatísticas fisiológicas registradas no ped
---@param ped integer
---@return table|nil
function Peds.GetFitnessStats(ped)
	if not Peds.Exists(ped) then
		return nil
	end
	local mock = useMock()
	if mock then
		local data = mock.entities[ped]
		return data and data.fitnessStats or { stamina = 0, strength = 0, maxWaterTimeSeconds = 15.0 }
	end
	return { stamina = 0, strength = 0, maxWaterTimeSeconds = 15.0 }
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

---Verifica se o ped é controlado por um jogador humano (IsPedAPlayer)
---@param ped integer
---@return boolean
function Peds.IsPlayer(ped)
	if type(ped) ~= 'number' or ped <= 0 then
		return false
	end
	if not activeMock and type(IsPedAPlayer) == 'function' then
		if not entityValid(ped) then return false end
		local ok, isPl = pcall(IsPedAPlayer, ped)
		return ok and (isPl == 1 or isPl == true)
	end
	local mock = useMock()
	if mock then
		local data = mock.entities[ped]
		return data ~= nil and data.exists == true and data.isPlayer == true
	end
	if type(IsPedAPlayer) ~= 'function' then
		return false
	end
	local ok, isPl = pcall(IsPedAPlayer, ped)
	return ok and (isPl == 1 or isPl == true)
end

-- Metatable do wrapper CoePlatformPed (herda de EntityWrapper)
local PedWrapper = setmetatable({}, { __index = EntityWrapper })
PedWrapper.__index = PedWrapper

function PedWrapper:GetHealth() return Peds.GetHealth(self.handle) end
function PedWrapper:SetHealth(h) return Peds.SetHealth(self.handle, h) end
function PedWrapper:GetMaxHealth() return Peds.GetMaxHealth(self.handle) end
function PedWrapper:SetMaxHealth(mh) return Peds.SetMaxHealth(self.handle, mh) end
function PedWrapper:SetFitnessStats(stam, str, waterSec) return Peds.SetFitnessStats(self.handle, stam, str, waterSec) end
function PedWrapper:GetFitnessStats() return Peds.GetFitnessStats(self.handle) end
function PedWrapper:GetArmour() return Peds.GetArmour(self.handle) end
function PedWrapper:SetArmour(a) return Peds.SetArmour(self.handle, a) end
function PedWrapper:IsDead() return Peds.IsDead(self.handle) end
function PedWrapper:GetVehicle() return Peds.GetVehicle(self.handle) end
function PedWrapper:SetIntoVehicle(v, seat) return Peds.SetIntoVehicle(self.handle, v, seat) end
function PedWrapper:ClearTasks() return Peds.ClearTasks(self.handle) end
function PedWrapper:IsPlayer() return Peds.IsPlayer(self.handle) end

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
	if not activeMock and type(GetPlayerRoutingBucket) == 'function' then
		local ok, bucket = pcall(GetPlayerRoutingBucket, pId)
		return (ok and type(bucket) == 'number') and bucket or 0
	end
	local mock = useMock()
	if mock then
		local data = mock.players[pId]
		return data and data.bucket or 0
	end
	if type(GetPlayerRoutingBucket) ~= 'function' then
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
	if not activeMock and type(SetPlayerRoutingBucket) == 'function' then
		local ok = pcall(SetPlayerRoutingBucket, pId, b)
		return ok
	end
	local mock = useMock()
	if mock then
		local data = mock.players[pId]
		if data then data.bucket = b end
		return true
	end
	if type(SetPlayerRoutingBucket) ~= 'function' then
		return false
	end
	local ok = pcall(SetPlayerRoutingBucket, pId, b)
	return ok
end

---Obtém a dimensão (routing bucket) de uma entidade
---@param entity integer
---@return integer
function Routing.GetEntityBucket(entity)
	if not activeMock and type(GetEntityRoutingBucket) == 'function' then
		if not entityValid(entity) then return 0 end
		local ok, bucket = pcall(GetEntityRoutingBucket, entity)
		return (ok and type(bucket) == 'number') and bucket or 0
	end
	if not Entities.Exists(entity) then
		return 0
	end
	local mock = useMock()
	if mock then
		local data = mock.entities[entity]
		return data and data.bucket or 0
	end
	if type(GetEntityRoutingBucket) ~= 'function' then
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
	local b = math.floor(tonumber(bucket) or 0)
	if b < 0 then return false end
	if not activeMock and type(SetEntityRoutingBucket) == 'function' then
		if not entityValid(entity) then return false end
		local ok = pcall(SetEntityRoutingBucket, entity, b)
		return ok
	end
	if not Entities.Exists(entity) then
		return false
	end
	local mock = useMock()
	if mock then
		local data = mock.entities[entity]
		if data then data.bucket = b end
		return true
	end
	if type(SetEntityRoutingBucket) ~= 'function' then
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
	if not activeMock and type(SetRoutingBucketPopulationEnabled) == 'function' then
		local ok = pcall(SetRoutingBucketPopulationEnabled, b, isEn)
		return ok
	end
	local mock = useMock()
	if mock then
		mock.buckets[b] = mock.buckets[b] or {}
		mock.buckets[b].population = isEn
		return true
	end
	if type(SetRoutingBucketPopulationEnabled) ~= 'function' then
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
	if not activeMock and type(SetRoutingBucketEntityLockdownMode) == 'function' then
		local ok = pcall(SetRoutingBucketEntityLockdownMode, b, m)
		return ok
	end
	local mock = useMock()
	if mock then
		mock.buckets[b] = mock.buckets[b] or {}
		mock.buckets[b].lockdown = m
		return true
	end
	if type(SetRoutingBucketEntityLockdownMode) ~= 'function' then
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

---Obtém a lista de hardware tokens do jogador (GetNumPlayerTokens / GetPlayerToken) no servidor
---@param playerId integer
---@return string[]
function Players.GetTokens(playerId)
	local pId = tonumber(playerId)
	if not pId or pId <= 0 then
		return {}
	end
	local mock = useMock()
	if mock then
		local data = mock.players[pId]
		if data and type(data.tokens) == 'table' then
			local copy = {}
			for i = 1, math.min(#data.tokens, 32) do
				if type(data.tokens[i]) == 'string' and data.tokens[i] ~= '' then
					copy[#copy + 1] = data.tokens[i]
				end
			end
			return copy
		end
		return {}
	end
	if not isServer or type(GetNumPlayerTokens) ~= 'function' or type(GetPlayerToken) ~= 'function' then
		return {}
	end
	local okCount, count = pcall(GetNumPlayerTokens, pId)
	if not okCount or type(count) ~= 'number' or count < 1 then
		return {}
	end
	local tokens = {}
	for i = 0, math.min(count, 32) - 1 do
		local okTok, token = pcall(GetPlayerToken, pId, i)
		if okTok and type(token) == 'string' and token ~= '' then
			tokens[#tokens + 1] = token
		end
	end
	return tokens
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

---Restaura proporcionalmente a estamina do jogador local (client-side)
---@param multiplier number
---@return boolean
function Players.RestoreStamina(multiplier)
	local mult = math.max(0.0, math.min(2.0, tonumber(multiplier) or 1.0))
	local mock = useMock()
	if mock then
		mock.lastStaminaMultiplier = mult
		return true
	end
	if isServer then
		return false
	end
	if type(RestorePlayerStamina) == 'function' and type(PlayerId) == 'function' then
		local ok = pcall(RestorePlayerStamina, PlayerId(), mult + 0.0)
		return ok
	end
	return false
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
function PlayerWrapper:GetTokens() return Players.GetTokens(self.playerId) end
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

-- ============================================================================
-- 8. MÓDULO DE COLSHAPES (Core.Platform.Colshapes)
-- Zonas espaciais de ultra-baixa latência (C++ nativo Gen9 / geometria pura)
-- ============================================================================
Platform.Colshapes = {}
local Colshapes = Platform.Colshapes

local activeColshapes = {}
local nextColshapeLocalId = 1

local ColshapeWrapper = {}
ColshapeWrapper.__index = ColshapeWrapper

function ColshapeWrapper:GetId() return self.id end
function ColshapeWrapper:GetType() return self.shapeType end
function ColshapeWrapper:GetData(key) return self.data and self.data[key] end
function ColshapeWrapper:SetData(key, value)
	if not self.data then self.data = {} end
	self.data[key] = value
end
function ColshapeWrapper:Destroy()
	return Colshapes.Destroy(self.id)
end

local function isInsidePolygon(points, px, py)
	local inside = false
	local count = #points
	if count < 3 then return false end
	local j = count
	for i = 1, count do
		local p1 = points[i]
		local p2 = points[j]
		local x1, y1 = p1.x or p1[1], p1.y or p1[2]
		local x2, y2 = p2.x or p2[1], p2.y or p2[2]
		if ((y1 > py) ~= (y2 > py)) and (px < (x2 - x1) * (py - y1) / (y2 - y1) + x1) then
			inside = not inside
		end
		j = i
	end
	return inside
end

function ColshapeWrapper:IsPointInside(coords)
	local p = safeVector3(coords)
	if self.shapeType == 'sphere' then
		local dx = p.x - self.center.x
		local dy = p.y - self.center.y
		local dz = p.z - self.center.z
		return (dx * dx + dy * dy + dz * dz) <= (self.radius * self.radius)
	elseif self.shapeType == 'cylinder' then
		local dx = p.x - self.center.x
		local dy = p.y - self.center.y
		local dist2D = dx * dx + dy * dy
		if dist2D > (self.radius * self.radius) then return false end
		local minZ = self.minZ or (self.center.z - (self.height / 2))
		local maxZ = self.maxZ or (self.center.z + (self.height / 2))
		return p.z >= minZ and p.z <= maxZ
	elseif self.shapeType == 'box' then
		local dx = p.x - self.center.x
		local dy = p.y - self.center.y
		local dz = p.z - self.center.z
		local rad = math.rad(-(self.heading or 0.0))
		local cosA = math.cos(rad)
		local sinA = math.sin(rad)
		local localX = math.abs(dx * cosA - dy * sinA)
		local localY = math.abs(dx * sinA + dy * cosA)
		local localZ = math.abs(dz)
		return localX <= (self.width / 2) and localY <= (self.length / 2) and localZ <= (self.height / 2)
	elseif self.shapeType == 'polygon' then
		if p.z < self.minZ or p.z > self.maxZ then return false end
		return isInsidePolygon(self.points, p.x, p.y)
	end
	return false
end

---Cria uma colshape esférica
---@param coords vector3|table
---@param radius number
---@param data table|nil
---@return table
function Colshapes.CreateSphere(coords, radius, data)
	local center = safeVector3(coords)
	local r = tonumber(radius) or 1.0
	local id = 'sphere_' .. nextColshapeLocalId
	nextColshapeLocalId = nextColshapeLocalId + 1
	local obj = setmetatable({
		id = id,
		shapeType = 'sphere',
		center = center,
		radius = r,
		data = data or {}
	}, ColshapeWrapper)
	activeColshapes[id] = obj
	return obj
end

---Cria uma colshape cilíndrica
---@param coords vector3|table
---@param radius number
---@param height number
---@param data table|nil
---@return table
function Colshapes.CreateCylinder(coords, radius, height, data)
	local center = safeVector3(coords)
	local r = tonumber(radius) or 1.0
	local h = tonumber(height) or 2.0
	local id = 'cylinder_' .. nextColshapeLocalId
	nextColshapeLocalId = nextColshapeLocalId + 1
	local obj = setmetatable({
		id = id,
		shapeType = 'cylinder',
		center = center,
		radius = r,
		height = h,
		minZ = center.z - (h / 2),
		maxZ = center.z + (h / 2),
		data = data or {}
	}, ColshapeWrapper)
	activeColshapes[id] = obj
	return obj
end

---Cria uma colshape em formato de caixa rotacionada (Box)
---@param coords vector3|table
---@param length number
---@param width number
---@param height number
---@param heading number
---@param data table|nil
---@return table
function Colshapes.CreateBox(coords, length, width, height, heading, data)
	local center = safeVector3(coords)
	local l = tonumber(length) or 1.0
	local w = tonumber(width) or 1.0
	local h = tonumber(height) or 1.0
	local hd = tonumber(heading) or 0.0
	local id = 'box_' .. nextColshapeLocalId
	nextColshapeLocalId = nextColshapeLocalId + 1
	local obj = setmetatable({
		id = id,
		shapeType = 'box',
		center = center,
		length = l,
		width = w,
		height = h,
		heading = hd,
		data = data or {}
	}, ColshapeWrapper)
	activeColshapes[id] = obj
	return obj
end

---Cria uma colshape poligonal delimitada por altura mínima e máxima
---@param points table Array de {x, y} ou vector3
---@param minZ number
---@param maxZ number
---@param data table|nil
---@return table
function Colshapes.CreatePolygon(points, minZ, maxZ, data)
	local pts = {}
	for _, p in ipairs(points or {}) do
		pts[#pts + 1] = { x = tonumber(p.x or p[1]) or 0.0, y = tonumber(p.y or p[2]) or 0.0 }
	end
	local id = 'polygon_' .. nextColshapeLocalId
	nextColshapeLocalId = nextColshapeLocalId + 1
	local obj = setmetatable({
		id = id,
		shapeType = 'polygon',
		points = pts,
		minZ = tonumber(minZ) or -100.0,
		maxZ = tonumber(maxZ) or 1000.0,
		data = data or {}
	}, ColshapeWrapper)
	activeColshapes[id] = obj
	return obj
end

---Verifica se um ponto está dentro de uma colshape por ID ou objeto
---@param shapeOrId string|table
---@param coords vector3|table
---@return boolean
function Colshapes.IsPointInside(shapeOrId, coords)
	local shape = type(shapeOrId) == 'table' and shapeOrId or activeColshapes[shapeOrId]
	if not shape or not shape.IsPointInside then return false end
	return shape:IsPointInside(coords)
end

---Remove e destrói uma colshape
---@param shapeOrId string|table
---@return boolean
function Colshapes.Destroy(shapeOrId)
	local id = type(shapeOrId) == 'table' and shapeOrId.id or shapeOrId
	if activeColshapes[id] then
		activeColshapes[id] = nil
		return true
	end
	return false
end

---Obtém uma colshape pelo ID
---@param id string
---@return table|nil
function Colshapes.Get(id)
	return activeColshapes[id]
end

---Lista todas as colshapes ativas
---@return table<string, table>
function Colshapes.GetAll()
	local copy = {}
	for k, v in pairs(activeColshapes) do copy[k] = v end
	return copy
end

-- ============================================================================
-- 10. ATALHOS DE CONVENIÊNCIA E FISIOLOGIA NA RAIZ DE Core.Platform
-- ============================================================================
function Platform.GetEntityCoords(entity)
	return Entities.GetCoords(entity)
end

function Platform.GetEntityHealth(ped)
	return Peds.GetHealth(ped)
end

function Platform.SetEntityHealth(ped, health)
	return Peds.SetHealth(ped, health)
end

function Platform.GetPedMaxHealth(ped)
	return Peds.GetMaxHealth(ped)
end

function Platform.SetPedMaxHealth(ped, maxHealth)
	return Peds.SetMaxHealth(ped, maxHealth)
end

function Platform.RestorePlayerStamina(multiplier)
	return Players.RestoreStamina(multiplier)
end

function Platform.SetPlayerFitnessStats(ped, staminaInt, strengthInt, maxWaterTimeSeconds)
	return Peds.SetFitnessStats(ped, staminaInt, strengthInt, maxWaterTimeSeconds)
end

Core = Core or {}
Core.Platform = Core.Platform or Platform

return Platform
