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

function RentalsRules.CanRent(characterId, activeRentals)
	if not characterId or characterId == '' then
		return false, 'no_character'
	end
	if type(activeRentals) == 'table' and activeRentals[characterId] ~= nil then
		return false, 'already_rented'
	end
	return true
end
