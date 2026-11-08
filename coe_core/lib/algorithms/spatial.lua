-- Indexação espacial por Bit-Packed 64-bit Spatial Hash Grid 2D/3D (com isolamento nativo de Routing Bucket)
-- e geometria computacional 2.5D (AABB + Ray-Casting) em Lua 5.4 puro.
local math_floor = math.floor
local table_wipe = table.wipe or function(t)
	for k in pairs(t) do
		t[k] = nil
	end
end

local Spatial = {}
Spatial.__index = Spatial

local BIAS = 32768

local function packCellKey(cx, cy, cz, bucket)
	local b = (bucket or 0) & 0x7FFF
	return (b << 48) | ((cx & 0xFFFF) << 32) | ((cy & 0xFFFF) << 16) | (cz & 0xFFFF)
end

Spatial.PackCellKey = packCellKey

---@param cellSize? number Tamanho da célula em metros (padrão: 50.0)
---@return CoeSpatialGrid
function Spatial.newGrid(cellSize)
	local size = (cellSize and cellSize > 0) and cellSize or 50.0
	return setmetatable({
		cellSize = size,
		invCellSize = 1.0 / size,
		cells = {},     -- table<integer, CoeSpatialEntity[]>
		entities = {},  -- table<string|integer, CoeSpatialEntity>
	}, Spatial)
end

function Spatial:_coordToCell(x, y, z, bucket)
	local inv = self.invCellSize
	local cx = math_floor(x * inv) + BIAS
	local cy = math_floor(y * inv) + BIAS
	local cz = math_floor(z * inv) + BIAS
	return packCellKey(cx, cy, cz, bucket), cx, cy, cz
end

function Spatial:_removeFromCell(ent)
	local cell = self.cells[ent.cellKey]
	if not cell then
		return
	end
	local n = #cell
	local idx = ent.cellIndex
	local last = cell[n]
	cell[n] = nil
	if idx < n and last then
		cell[idx] = last
		last.cellIndex = idx
	end
	if n == 1 then
		self.cells[ent.cellKey] = nil
	end
end

function Spatial:insert(id, x, y, z, bucket, payload)
	if self.entities[id] then
		return self:update(id, x, y, z, bucket)
	end
	local b = bucket or 0
	local key = self:_coordToCell(x, y, z, b)
	local cell = self.cells[key]
	if not cell then
		cell = {}
		self.cells[key] = cell
	end
	local idx = #cell + 1
	local ent = {
		id = id,
		x = x,
		y = y,
		z = z,
		bucket = b,
		cellKey = key,
		cellIndex = idx,
		payload = payload
	}
	cell[idx] = ent
	self.entities[id] = ent
	return true
end

function Spatial:update(id, x, y, z, bucket)
	local ent = self.entities[id]
	if not ent then
		return false
	end
	local b = bucket or ent.bucket
	local newKey = self:_coordToCell(x, y, z, b)
	ent.x, ent.y, ent.z, ent.bucket = x, y, z, b
	if newKey ~= ent.cellKey then
		self:_removeFromCell(ent)
		local cell = self.cells[newKey]
		if not cell then
			cell = {}
			self.cells[newKey] = cell
		end
		local idx = #cell + 1
		cell[idx] = ent
		ent.cellKey = newKey
		ent.cellIndex = idx
	end
	return true
end

function Spatial:remove(id)
	local ent = self.entities[id]
	if not ent then
		return false
	end
	self:_removeFromCell(ent)
	self.entities[id] = nil
	return true
end

function Spatial:queryRadius(x, y, z, radius, bucket, outBuffer)
	local results = outBuffer or {}
	if outBuffer then
		table_wipe(results)
	end
	local count = 0
	local rSq = radius * radius
	local inv = self.invCellSize
	local b = (bucket or 0) & 0x7FFF
	local bShift = b << 48

	local minCx = math_floor((x - radius) * inv) + BIAS
	local maxCx = math_floor((x + radius) * inv) + BIAS
	local minCy = math_floor((y - radius) * inv) + BIAS
	local maxCy = math_floor((y + radius) * inv) + BIAS
	local minCz = math_floor((z - radius) * inv) + BIAS
	local maxCz = math_floor((z + radius) * inv) + BIAS

	local cells = self.cells
	for cx = minCx, maxCx do
		local cxBits = bShift | ((cx & 0xFFFF) << 32)
		for cy = minCy, maxCy do
			local cyBits = cxBits | ((cy & 0xFFFF) << 16)
			for cz = minCz, maxCz do
				local cell = cells[cyBits | (cz & 0xFFFF)]
				if cell then
					for i = 1, #cell do
						local ent = cell[i]
						local dx = ent.x - x
						local dy = ent.y - y
						local dz = ent.z - z
						if (dx * dx + dy * dy + dz * dz) <= rSq then
							count = count + 1
							results[count] = ent
						end
					end
				end
			end
		end
	end
	return results, count
end

function Spatial:queryRadius2D(x, y, radius, bucket, outBuffer)
	return self:queryRadius(x, y, 0.0, radius, bucket, outBuffer)
end

function Spatial:clear()
	table_wipe(self.cells)
	table_wipe(self.entities)
end

--- Cria um polígono 2.5D otimizado com pré-filtro AABB e arestas pré-calculadas.
---@param minZ number
---@param maxZ number
---@param points number[] Array intercalado {x1, y1, x2, y2, ...} compatível com CreateColshapePolygon
---@return CoePolygonZone
function Spatial.newPolygon(minZ, maxZ, points)
	local nCoords = #points
	assert(nCoords >= 6 and nCoords % 2 == 0, 'Poligono exige pelo menos 3 pares (x, y)')
	local minX, maxX = math.huge, -math.huge
	local minY, maxY = math.huge, -math.huge
	local vx, vy = {}, {}
	local nVerts = 0
	for i = 1, nCoords, 2 do
		nVerts = nVerts + 1
		local px, py = points[i], points[i + 1]
		vx[nVerts], vy[nVerts] = px, py
		if px < minX then minX = px end
		if px > maxX then maxX = px end
		if py < minY then minY = py end
		if py > maxY then maxY = py end
	end

	return {
		minZ = minZ,
		maxZ = maxZ,
		minX = minX,
		maxX = maxX,
		minY = minY,
		maxY = maxY,
		vx = vx,
		vy = vy,
		n = nVerts,
		contains = function(zone, x, y, z)
			if z < zone.minZ or z > zone.maxZ or x < zone.minX or x > zone.maxX or y < zone.minY or y > zone.maxY then
				return false
			end
			local inside = false
			local zvx, zvy, zn = zone.vx, zone.vy, zone.n
			local j = zn
			for i = 1, zn do
				local xi, yi = zvx[i], zvy[i]
				local xj, yj = zvx[j], zvy[j]
				if ((yi > y) ~= (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi) then
					inside = not inside
				end
				j = i
			end
			return inside
		end
	}
end

return Spatial
