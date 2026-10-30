-- Regras de negócio puras do sistema de aluguel (testáveis offline).
RentalsRules = {}

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
