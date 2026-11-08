BusinessArea = {}

local function resolveSpatial()
	if type(Core) == 'table' and type(Core.Algorithms) == 'table' and type(Core.Algorithms.Spatial) == 'table' then
		return Core.Algorithms.Spatial
	end
	if type(CoeAlgorithms) == 'table' and type(CoeAlgorithms.Spatial) == 'table' then
		return CoeAlgorithms.Spatial
	end
	if type(LoadResourceFile) == 'function' and type(load) == 'function' then
		local src = LoadResourceFile('coe_core', 'lib/algorithms/spatial.lua')
		if type(src) == 'string' and src ~= '' then
			local fn = load(src, '@@coe_core/lib/algorithms/spatial.lua', 't', _G)
			if fn then
				local ok, mod = pcall(fn)
				if ok and type(mod) == 'table' then
					return mod
				end
			end
		end
		return nil
	end
	if type(loadfile) == 'function' then
		local candidates = {
			'../coe_core/lib/algorithms/spatial.lua',
			'coe-framework/coe_core/lib/algorithms/spatial.lua',
			'dev/coe_core/lib/algorithms/spatial.lua',
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

local Spatial = resolveSpatial()

-- Constrói (e memoriza) o polígono 2.5D otimizado com pré-filtro AABB O(1) + Ray-Casting.
function BusinessArea.BuildPolygon(area)
	if type(area) ~= 'table' or area.kind ~= 'polygon' or type(area.points) ~= 'table' or #area.points < 3 or not Spatial then
		return nil
	end
	local cached = rawget(area, '_polyZone')
	if cached and rawget(area, '_polyCount') == #area.points and rawget(area, '_polyZ') == area.z and rawget(area, '_polyH') == area.height then
		return cached
	end
	local flat = {}
	for i = 1, #area.points do
		local p = area.points[i]
		flat[#flat + 1] = tonumber(p.x) or 0.0
		flat[#flat + 1] = tonumber(p.y) or 0.0
	end
	local ok, zone = pcall(Spatial.newPolygon, (tonumber(area.z) or 0.0) - 5.0, (tonumber(area.z) or 0.0) + (tonumber(area.height) or 0.0), flat)
	if not ok or not zone then
		return nil
	end
	rawset(area, '_polyZone', zone)
	rawset(area, '_polyCount', #area.points)
	rawset(area, '_polyZ', area.z)
	rawset(area, '_polyH', area.height)
	return zone
end

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
		local poly = BusinessArea.BuildPolygon(area)
		if poly then
			return poly:contains(x, y, z)
		end
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
