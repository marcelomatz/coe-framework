-- Regras puras da última posição (sem natives). Testadas em test/positions_test.lua.
SpawnPositions = {}

local function finite(value)
	return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

local function round(value, places)
	local factor = 10 ^ places
	return math.floor(value * factor + 0.5) / factor
end

-- Devolve { x, y, z, heading } arredondado, ou nil se a posição for inválida ou fora do mapa.
function SpawnPositions.Normalize(raw, bounds)
	if type(raw) ~= 'table' or not finite(raw.x) or not finite(raw.y) or not finite(raw.z) then
		return nil
	end
	if math.abs(raw.x) > bounds.MaxXY or math.abs(raw.y) > bounds.MaxXY or raw.z < bounds.MinZ or raw.z > bounds.MaxZ then
		return nil
	end
	-- Coordenada zerada é o ped ainda não posicionado (antes do spawn), não uma posição real.
	if math.abs(raw.x) < 1 and math.abs(raw.y) < 1 then
		return nil
	end
	local heading = finite(raw.heading) and raw.heading % 360 or 0.0
	return { x = round(raw.x, 2), y = round(raw.y, 2), z = round(raw.z, 2), heading = round(heading, 1) }
end

-- Só vale gravar de novo quando o personagem andou pelo menos minMove metros.
function SpawnPositions.Moved(previous, current, minMove)
	if not previous then
		return true
	end
	local dx, dy, dz = previous.x - current.x, previous.y - current.y, previous.z - current.z
	return dx * dx + dy * dy + dz * dz >= minMove * minMove
end
