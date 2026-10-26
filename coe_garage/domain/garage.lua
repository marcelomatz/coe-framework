GarageDomain = {}

local function trim(s)
	return tostring(s or ''):match('^%s*(.-)%s*$') or ''
end

---Valida os dados de cadastro de uma garagem pública.
---@param raw table Dados brutos da garagem
---@return table|nil clean Dados sanitizados ou nil
---@return string|nil errorCode Código do erro
function GarageDomain.ValidateGarage(raw)
	if type(raw) ~= 'table' then
		return nil, 'invalid_payload'
	end

	local id = trim(raw.id):lower()
	if id == '' or not id:match('^[a-z0-9_]+$') or #id > 32 then
		return nil, 'invalid_id'
	end

	local label = trim(raw.label)
	if label == '' or #label > 64 then
		return nil, 'invalid_label'
	end

	local kind = raw.kind or 'public'
	if kind ~= 'public' then
		kind = 'public'
	end

	local enabled = raw.enabled ~= false

	local spotsRaw = raw.spots
	if type(spotsRaw) ~= 'table' or #spotsRaw == 0 then
		return nil, 'invalid_spots'
	end

	if #spotsRaw > (GarageConfig and GarageConfig.Limits and GarageConfig.Limits.MaxSpotsPerGarage or 8) then
		return nil, 'too_many_spots'
	end

	local cleanSpots = {}
	for i, spot in ipairs(spotsRaw) do
		if type(spot) ~= 'table' then
			return nil, 'invalid_spot_data'
		end
		local spotId = trim(spot.id)
		if spotId == '' then
			spotId = 'vaga_' .. i
		end
		local spotLabel = trim(spot.label)
		if spotLabel == '' then
			spotLabel = 'Vaga ' .. i
		end
		local x = tonumber(spot.x)
		local y = tonumber(spot.y)
		local z = tonumber(spot.z)
		if not x or not y or not z then
			return nil, 'invalid_spot_coords'
		end
		local heading = tonumber(spot.heading) or 0.0
		local radius = tonumber(spot.radius) or 3.5

		cleanSpots[#cleanSpots + 1] = {
			id = spotId,
			label = spotLabel,
			x = x,
			y = y,
			z = z,
			heading = heading,
			radius = radius
		}
	end

	local blipRaw = raw.blip
	local cleanBlip = {
		enabled = true,
		sprite = 357,
		color = 3,
		scale = 0.8
	}
	if type(blipRaw) == 'table' then
		cleanBlip.enabled = blipRaw.enabled ~= false
		cleanBlip.sprite = tonumber(blipRaw.sprite) or 357
		cleanBlip.color = tonumber(blipRaw.color) or 3
		cleanBlip.scale = tonumber(blipRaw.scale) or 0.8
	end

	return {
		id = id,
		label = label,
		kind = kind,
		enabled = enabled,
		spots = cleanSpots,
		blip = cleanBlip
	}
end

---Verifica se as coordenadas estão dentro do raio da vaga.
---@param coords table {x, y, z}
---@param spot table {x, y, z, radius}
---@param fallbackDistance number Distância padrão caso spot.radius seja nulo
---@return boolean inside
function GarageDomain.ValidateDistance(coords, spot, fallbackDistance)
	if not coords or not spot then
		return false
	end
	local dx = (coords.x or 0) - (spot.x or 0)
	local dy = (coords.y or 0) - (spot.y or 0)
	local dz = (coords.z or 0) - (spot.z or 0)
	local distSq = dx * dx + dy * dy + dz * dz
	local radius = tonumber(spot.radius) or fallbackDistance or 3.5
	return distSq <= (radius * radius)
end

---Constrói a lista de estações ativas para o client a partir das garagens cadastradas.
---@param garages table Mapa ou lista de garagens
---@return table stations Lista de estações com coordenadas por vaga
function GarageDomain.BuildStationList(garages)
	local stations = {}
	if type(garages) ~= 'table' then
		return stations
	end

	for _, garage in pairs(garages) do
		if garage.enabled then
			for _, spot in ipairs(garage.spots or {}) do
				stations[#stations + 1] = {
					garageId = garage.id,
					spotId = spot.id,
					title = garage.label,
					label = spot.label,
					kind = garage.kind or 'public',
					x = spot.x,
					y = spot.y,
					z = spot.z,
					radius = spot.radius or 3.5,
					heading = spot.heading or 0.0,
					blip = garage.blip and garage.blip.enabled and garage.blip or nil
				}
			end
		end
	end

	return stations
end
