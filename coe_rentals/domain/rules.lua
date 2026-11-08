-- Regras de negócio puras do sistema de aluguel (testáveis offline).
RentalsRules = {}

local function resolveAlgorithms()
	if type(Core) == 'table' and type(Core.Algorithms) == 'table' then
		return Core.Algorithms
	end
	if type(CoeAlgorithms) == 'table' then
		return CoeAlgorithms
	end
	if type(LoadResourceFile) == 'function' and type(load) == 'function' then
		local src = LoadResourceFile('coe_core', 'lib/algorithms/init.lua')
		if type(src) == 'string' and src ~= '' then
			local fn = load(src, '@@coe_core/lib/algorithms/init.lua', 't', _G)
			if fn then
				local ok, mod = pcall(fn)
				if ok and type(mod) == 'table' then
					return mod
				end
			end
		end
		return CoeAlgorithms
	end
	if type(loadfile) == 'function' then
		local candidates = {
			'../coe_core/lib/algorithms/init.lua',
			'coe-framework/coe_core/lib/algorithms/init.lua',
			'dev/coe_core/lib/algorithms/init.lua',
		}
		for i = 1, #candidates do
			local chunk = loadfile(candidates[i])
			if chunk then
				local ok, mod = pcall(chunk)
				if ok and type(mod) == 'table' then
					return mod
				end
			end
		end
	end
	return nil
end

local Algorithms = resolveAlgorithms()
local Concurrency = Algorithms and Algorithms.Concurrency or nil
local RateLimit = Algorithms and Algorithms.RateLimit or nil

function RentalsRules.NewRateLimiter(emissionIntervalMs, burstTolerance)
	if RateLimit and type(RateLimit.newGCRA) == 'function' then
		return RateLimit.newGCRA(emissionIntervalMs or 2000, burstTolerance or 0)
	end
	return nil
end

function RentalsRules.ExecuteSaga(steps)
	if Concurrency and type(Concurrency.executeSaga) == 'function' then
		return Concurrency.executeSaga(steps)
	end
	return false, nil, 'saga_unavailable'
end

function RentalsRules.FindVehicle(config, model)
	if type(config) ~= 'table' or type(config.Vehicles) ~= 'table' or type(model) ~= 'string' then
		return nil
	end
	for _, v in ipairs(config.Vehicles) do
		if v.model:lower() == model:lower() then
			return v
		end
	end
	return nil
end

function RentalsRules.FindStation(config, stationId)
	if type(config) ~= 'table' or type(config.Stations) ~= 'table' or type(stationId) ~= 'string' then
		return nil
	end
	for _, s in ipairs(config.Stations) do
		if s.id == stationId then
			return s
		end
	end
	return nil
end

---Veículos oferecidos numa estação: `station.vehicles` (lista de modelos) restringe o catálogo; vazia ou sem ela, todos.
function RentalsRules.VehiclesFor(config, station)
	local list = {}
	if type(config) ~= 'table' or type(config.Vehicles) ~= 'table' then
		return list
	end
	local allowed = nil
	if type(station) == 'table' and type(station.vehicles) == 'table' and #station.vehicles > 0 then
		allowed = {}
		for _, model in ipairs(station.vehicles) do
			if type(model) == 'string' then
				allowed[model:lower()] = true
			end
		end
	end
	for _, vehicle in ipairs(config.Vehicles) do
		if type(vehicle.model) == 'string' and (not allowed or allowed[vehicle.model:lower()]) then
			list[#list + 1] = vehicle
		end
	end
	return list
end

---O modelo é oferecido nesta estação? Retorna a definição do veículo ou nil.
function RentalsRules.FindVehicleAt(config, station, model)
	if type(model) ~= 'string' then
		return nil
	end
	for _, vehicle in ipairs(RentalsRules.VehiclesFor(config, station)) do
		if vehicle.model:lower() == model:lower() then
			return vehicle
		end
	end
	return nil
end

function RentalsRules.CalculateTotal(vehicleDef)
	if type(vehicleDef) ~= 'table' then
		return 0, 0, 0
	end
	local price = math.max(0, tonumber(vehicleDef.price) or 0)
	local deposit = math.max(0, tonumber(vehicleDef.deposit) or 0)
	return price, deposit, price + deposit
end

function RentalsRules.GenerateRentalPlate()
	local chars = '0123456789'
	local num = ''
	for _ = 1, 4 do
		local r = math.random(1, #chars)
		num = num .. chars:sub(r, r)
	end
	return 'RENT' .. num
end

-- x, y, z de uma tabela ou de um vetor do FiveM. No CfxLua, type(vector3(...)) é 'vector3' (não 'userdata'):
-- por isso a leitura é feita sem checar o tipo, protegida por pcall.
local function xyz(value)
	if value == nil then
		return nil
	end
	local ok, x, y, z = pcall(function()
		return tonumber(value.x), tonumber(value.y), tonumber(value.z)
	end)
	if not ok then
		return nil
	end
	return x, y, z
end

---O jogador está a até `radius` metros do ponto? `coords` e `point` com x, y, z (tabela ou vector3).
function RentalsRules.IsNear(coords, point, radius)
	local x, y, z = xyz(coords)
	local px, py, pz = xyz(point)
	local limit = tonumber(radius)
	if not (x and y and z and px and py and pz and limit) then
		return false
	end
	local dx, dy, dz = x - px, y - py, z - pz
	return (dx * dx + dy * dy + dz * dz) <= limit * limit
end

function RentalsRules.CanRent(characterId, activeRentals)
	if not characterId or characterId == '' then
		return false, 'no_character'
	end
	if type(activeRentals) == 'table' and activeRentals[characterId] ~= nil then
		return false, 'already_rented'
	end
	return true
end
