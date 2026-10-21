BusinessArea = {}

-- Área circular { kind='circle', x, y, z, radius } ou poligonal { kind='polygon', points={{x,y}...}, z, height }.
local function inPolygon(points, x, y)
	local inside = false
	local j = #points
	for i = 1, #points do
		local a, b = points[i], points[j]
		if (a.y > y) ~= (b.y > y) and x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x then
			inside = not inside
		end
		j = i
	end
	return inside
end

function BusinessArea.Contains(area, x, y, z)
	if type(area) ~= 'table' then
		return false
	end
	if area.kind == 'circle' then
		local dx, dy = x - area.x, y - area.y
		return dx * dx + dy * dy <= area.radius * area.radius and math.abs(z - area.z) <= area.radius
	end
	if area.kind == 'polygon' then
		return z >= area.z - 5.0 and z <= area.z + area.height and inPolygon(area.points, x, y)
	end
	return false
end

function BusinessArea.Center(area)
	if area.kind == 'circle' then
		return { x = area.x, y = area.y, z = area.z }
	end
	local sx, sy = 0.0, 0.0
	for _, p in ipairs(area.points) do
		sx, sy = sx + p.x, sy + p.y
	end
	return { x = sx / #area.points, y = sy / #area.points, z = area.z }
end

-- Maior distância do centro até a borda; usada para filtros baratos de proximidade.
function BusinessArea.Extent(area)
	if area.kind == 'circle' then
		return area.radius
	end
	local c = BusinessArea.Center(area)
	local best = 0.0
	for _, p in ipairs(area.points) do
		local dx, dy = p.x - c.x, p.y - c.y
		best = math.max(best, math.sqrt(dx * dx + dy * dy))
	end
	return best
end
