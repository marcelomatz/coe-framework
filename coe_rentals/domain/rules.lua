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

---O jogador está a até `radius` metros do ponto? `coords` e `point` com x, y, z.
function RentalsRules.IsNear(coords, point, radius)
	if type(coords) ~= 'table' and type(coords) ~= 'userdata' then
		return false
	end
	if type(point) ~= 'table' then
		return false
	end
	local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
	local px, py, pz = tonumber(point.x), tonumber(point.y), tonumber(point.z)
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
