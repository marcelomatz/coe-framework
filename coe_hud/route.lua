-- Proximas ruas a frente do jogador, com o lado em que cada uma aparece (como uma rota).
-- Amostra pontos ao longo do heading e ao lado dele; a rua de cada ponto vem de nameAt(x, y, z).
Route = {}

local STEP = 30.0
local LATERAL = 28.0
local MAX_RESULTS = 3

-- Alcance em metros: maior em velocidade, para dar tempo de decidir a curva.
function Route.Reach(speed)
	return math.max(180.0, math.min(600.0, 150.0 + (speed or 0) * 12.0))
end

function Route.Next(origin, heading, speed, nameAt)
	local angle = math.rad(heading or 0)
	-- Heading do GTA: 0 = norte, cresce no sentido anti-horario.
	local fx, fy = -math.sin(angle), math.cos(angle)
	local rx, ry = fy, -fx
	local seen = { [nameAt(origin.x, origin.y, origin.z)] = true }
	local found = {}
	local reach = Route.Reach(speed)
	local distance = STEP
	while distance <= reach and #found < MAX_RESULTS do
		local px, py = origin.x + fx * distance, origin.y + fy * distance
		local candidates = {
			{ side = 'frente', name = nameAt(px, py, origin.z) },
			{ side = 'esquerda', name = nameAt(px - rx * LATERAL, py - ry * LATERAL, origin.z) },
			{ side = 'direita', name = nameAt(px + rx * LATERAL, py + ry * LATERAL, origin.z) }
		}
		for _, candidate in ipairs(candidates) do
			if candidate.name ~= '' and not seen[candidate.name] and #found < MAX_RESULTS then
				seen[candidate.name] = true
				found[#found + 1] = { name = candidate.name, side = candidate.side, dist = math.floor(distance + 0.5) }
			end
		end
		distance = distance + STEP
	end
	return found
end
