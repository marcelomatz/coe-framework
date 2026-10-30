-- Estações de aluguel (cadastro no banco, editadas pelo painel). Regras puras, testáveis offline.
--   id, label, enabled
--   ped        = { x, y, z, h, model? }  atendente (NPC) e balcão: alugar, devolver e encerrar acontecem aqui
--   spawns     = { { x, y, z, h }, ... } pontos de retirada (1 a MaxSpawns); o veículo sai no primeiro livre
--   returnZone = { x, y, z, radius }     dentro do carro alugado, E devolve
--   blip       = { enabled, sprite, color, scale }
--   vehicles   = { 'modelo', ... }       vazio: todo o catálogo de RentalsConfig.Vehicles
RentalsStations = {}

local MAX_COORD = 20000.0

local function coord(value, min, max)
	value = tonumber(value)
	if not value or value ~= value or value < min or value > max then
		return nil
	end
	return math.floor(value * 100 + 0.5) / 100
end

local function heading(value)
	value = tonumber(value) or 0.0
	if value ~= value then
		return nil
	end
	return math.floor((value % 360.0) * 10 + 0.5) / 10
end

local function text(value, max)
	if type(value) ~= 'string' then
		return nil
	end
	value = value:gsub('^%s+', ''):gsub('%s+$', '')
	if value == '' or #value > max or value:find('[%c<>]') then
		return nil
	end
	return value
end

local function point(raw, withHeading)
	if type(raw) ~= 'table' then
		return nil
	end
	local x, y, z = coord(raw.x, -MAX_COORD, MAX_COORD), coord(raw.y, -MAX_COORD, MAX_COORD), coord(raw.z, -1000.0, 3000.0)
	if not (x and y and z) then
		return nil
	end
	local result = { x = x, y = y, z = z }
	if withHeading then
		result.h = heading(raw.h or raw.heading)
		if not result.h then
			return nil
		end
	end
	return result
end

---Valida uma estação vinda do painel. Retorna a estação normalizada ou nil, código de erro.
function RentalsStations.Normalize(raw, limits)
	limits = limits or {}
	local maxSpawns = limits.MaxSpawns or 8
	if type(raw) ~= 'table' then
		return nil, 'invalid_station'
	end
	if type(raw.id) ~= 'string' or not raw.id:match('^[a-z0-9_]+$') or #raw.id < 2 or #raw.id > 32 then
		return nil, 'invalid_id'
	end
	local label = text(raw.label, 48)
	if not label then
		return nil, 'invalid_label'
	end

	local ped = point(raw.ped, true)
	if not ped then
		return nil, 'invalid_ped'
	end
	if type(raw.ped.model) == 'string' and raw.ped.model ~= '' then
		if not raw.ped.model:match('^[%w_]+$') or #raw.ped.model > 48 then
			return nil, 'invalid_ped'
		end
		ped.model = raw.ped.model:lower()
	end

	if type(raw.spawns) ~= 'table' or #raw.spawns < 1 or #raw.spawns > maxSpawns then
		return nil, 'invalid_spawns'
	end
	local spawns = {}
	for _, rawSpawn in ipairs(raw.spawns) do
		local spawn = point(rawSpawn, true)
		if not spawn then
			return nil, 'invalid_spawns'
		end
		spawns[#spawns + 1] = spawn
	end

	local returnZone = point(raw.returnZone, false)
	local radius = raw.returnZone and coord(raw.returnZone.radius or 5.0, 1.0, 30.0)
	if not returnZone or not radius then
		return nil, 'invalid_return'
	end
	returnZone.radius = radius

	local vehicles = {}
	if raw.vehicles ~= nil then
		if type(raw.vehicles) ~= 'table' or #raw.vehicles > 32 then
			return nil, 'invalid_vehicles'
		end
		local seen = {}
		for _, model in ipairs(raw.vehicles) do
			if type(model) ~= 'string' or not model:match('^[%w_]+$') or #model > 48 then
				return nil, 'invalid_vehicles'
			end
			model = model:lower()
			if not seen[model] then
				seen[model] = true
				vehicles[#vehicles + 1] = model
			end
		end
	end

	local rawBlip = type(raw.blip) == 'table' and raw.blip or {}
	local sprite = math.tointeger(tonumber(rawBlip.sprite or 226))
	local color = math.tointeger(tonumber(rawBlip.color or 3))
	local scale = tonumber(rawBlip.scale or 0.7)
	if not sprite or sprite < 1 or sprite > 900 or not color or color < 0 or color > 85 or not scale or scale < 0.3 or scale > 2.0 then
		return nil, 'invalid_blip'
	end

	return {
		id = raw.id,
		label = label,
		enabled = raw.enabled ~= false,
		ped = ped,
		spawns = spawns,
		returnZone = returnZone,
		vehicles = vehicles,
		blip = { enabled = rawBlip.enabled ~= false, sprite = sprite, color = color, scale = math.floor(scale * 100 + 0.5) / 100 }
	}
end

---Converte uma estação do formato antigo do config.lua (coords/spawn) para o cadastro.
function RentalsStations.FromConfig(entry)
	if type(entry) ~= 'table' then
		return nil
	end
	local counter = entry.ped or entry.coords
	local spawns = entry.spawns or (entry.spawn and { entry.spawn }) or nil
	local zone = entry.returnZone or entry.spawn or counter
	return RentalsStations.Normalize({
		id = entry.id,
		label = entry.label,
		enabled = entry.enabled,
		ped = counter and { x = counter.x, y = counter.y, z = counter.z, h = counter.h or counter.heading or 0.0, model = type(entry.ped) == 'table' and entry.ped.model or nil } or nil,
		spawns = spawns,
		returnZone = zone and { x = zone.x, y = zone.y, z = zone.z, radius = zone.radius or 5.0 } or nil,
		vehicles = entry.vehicles,
		blip = entry.blip
	})
end

---Primeiro ponto de retirada livre. `occupied(point)` diz se há veículo em cima do ponto.
function RentalsStations.FreeSpawn(station, occupied)
	for _, spawn in ipairs(type(station) == 'table' and station.spawns or {}) do
		if not occupied or not occupied(spawn) then
			return spawn
		end
	end
	return nil
end
