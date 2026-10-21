-- Retangulo do minimapa na tela (fracoes 0-1) pela formula padrao do GTA (safezone + aspecto).
MapAnchor = {}

local function round(value)
	return math.floor(value * 10000 + 0.5) / 10000
end

function MapAnchor.Compute(scale, safezone, aspect)
	scale = scale or 1.0
	local margin = math.abs(safezone - 1.0) * 10 / 20.0
	local bottom = 1.0 - margin
	local width = scale / (4 * aspect)
	local height = scale / 5.674
	return { l = round(margin), r = round(margin + width), t = round(bottom - height), b = round(bottom) }
end

-- Distancia 2D, em metros, entre dois pontos do mundo.
function MapAnchor.Distance(from, to)
	local dx, dy = to.x - from.x, to.y - from.y
	return math.sqrt(dx * dx + dy * dy)
end
