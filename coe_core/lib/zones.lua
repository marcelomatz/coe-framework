-- Subsistema de zonas espaciais (Core.Zones / CoeZones) com grade espacial empacotada em inteiros de 64 bits
-- (Bit-Packed Spatial Hash Grid), suporte a esferas, caixas orientadas (OBB) e polígonos 2.5D (AABB + Ray-Casting),
-- e integração orientada a eventos com o keymapping unificado '+coe_interact' (E), eliminando loops Wait(0).
CoeZones = CoeZones or {}

local DEFAULT_CELL_SIZE = 50.0
local BIAS = 32768

local function cellCoord(value, invCellSize)
	return math.floor(value * invCellSize) + BIAS
end

local function cellKey(cx, cy, bucket)
	local b = (bucket or 0) & 0x7FFF
	return (b << 48) | ((cx & 0xFFFF) << 32) | ((cy & 0xFFFF) << 16)
end

local function pointInSphere(zone, x, y, z)
	local dx = x - zone.x
	local dy = y - zone.y
	local dz = z - zone.z
	local distSq = dx * dx + dy * dy + dz * dz
	if distSq <= zone.radius * zone.radius then
		return true, math.sqrt(distSq)
	end
	return false, math.sqrt(distSq)
end

local function pointInBox(zone, x, y, z)
	if zone.minZ and z < zone.minZ then
		return false, math.huge
	end
	if zone.maxZ and z > zone.maxZ then
		return false, math.huge
	end
	local dx = x - zone.x
	local dy = y - zone.y
	local dz = z - zone.z
	local cosH = zone._cosH or 1.0
	local sinH = zone._sinH or 0.0
	local localX = dx * cosH - dy * sinH
	local localY = dx * sinH + dy * cosH
	if math.abs(localX) <= zone.halfWidth and math.abs(localY) <= zone.halfLength and math.abs(dz) <= zone.halfHeight then
		return true, math.sqrt(dx * dx + dy * dy + dz * dz)
	end
	return false, math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function pointInPolygon(zone, x, y, z)
	local dx = x - zone.x
	local dy = y - zone.y
	local dz = z - zone.z
	local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
	if z < zone.minZ or z > zone.maxZ or x < zone.minX or x > zone.maxX or y < zone.minY or y > zone.maxY then
		return false, dist
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
	return inside, dist
end

---Cria uma instância isolada de registro espacial de zonas.
---@param opts table|nil `{ cellSize?: number }`
---@return table registry
function CoeZones.New(opts)
	local cellSize = (type(opts) == 'table' and tonumber(opts.cellSize) and opts.cellSize > 0) and opts.cellSize or DEFAULT_CELL_SIZE
	local invCellSize = 1.0 / cellSize
	local zones = {}
	local grid = {}
	local zoneCells = {}
	local count = 0

	local self = {}

	local function unindex(id)
		local keys = zoneCells[id]
		if not keys then
			return
		end
		for i = 1, #keys do
			local key = keys[i]
			local bucket = grid[key]
			if bucket then
				bucket[id] = nil
				if next(bucket) == nil then
					grid[key] = nil
				end
			end
		end
		zoneCells[id] = nil
	end

	local function indexZone(zone)
		unindex(zone.id)
		local extent = zone.boundingRadius or zone.radius or 0.0
		local minCx = cellCoord(zone.x - extent, invCellSize)
		local maxCx = cellCoord(zone.x + extent, invCellSize)
		local minCy = cellCoord(zone.y - extent, invCellSize)
		local maxCy = cellCoord(zone.y + extent, invCellSize)
		local keys = {}
		local b = zone.bucket or 0
		for cx = minCx, maxCx do
			for cy = minCy, maxCy do
				local key = cellKey(cx, cy, b)
				local bucket = grid[key]
				if not bucket then
					bucket = {}
					grid[key] = bucket
				end
				bucket[zone.id] = zone
				keys[#keys + 1] = key
			end
		end
		zoneCells[zone.id] = keys
	end

	---Registra ou substitui uma zona esférica.
	---@param id string
	---@param spec table `{ x: number, y: number, z: number, radius: number, bucket?: integer, prompt?: table|function, canInteract?: function, onEnter?: function, onExit?: function, onSelect?: function, data?: any }`
	---@return table|nil zone
	function self.AddSphere(id, spec)
		if type(id) ~= 'string' or id == '' or type(spec) ~= 'table' then
			return nil
		end
		local x, y, z = tonumber(spec.x), tonumber(spec.y), tonumber(spec.z)
		local radius = tonumber(spec.radius) or 2.0
		if not x or not y or not z or radius <= 0 then
			return nil
		end
		if not zones[id] then
			count = count + 1
		end
		local zone = {
			id = id,
			kind = 'sphere',
			x = x,
			y = y,
			z = z,
			bucket = tonumber(spec.bucket) or 0,
			radius = radius,
			boundingRadius = radius,
			prompt = spec.prompt,
			canInteract = spec.canInteract,
			onEnter = spec.onEnter,
			onExit = spec.onExit,
			onSelect = spec.onSelect,
			data = spec.data
		}
		zones[id] = zone
		indexZone(zone)
		return zone
	end

	---Registra ou substitui uma zona retangular orientada (OBB 2.5D).
	---@param id string
	---@param spec table `{ x: number, y: number, z: number, length: number, width: number, height?: number, heading?: number, minZ?: number, maxZ?: number, bucket?: integer, prompt?: table|function, canInteract?: function, onEnter?: function, onExit?: function, onSelect?: function, data?: any }`
	---@return table|nil zone
	function self.AddBox(id, spec)
		if type(id) ~= 'string' or id == '' or type(spec) ~= 'table' then
			return nil
		end
		local x, y, z = tonumber(spec.x), tonumber(spec.y), tonumber(spec.z)
		local length = tonumber(spec.length) or 2.0
		local width = tonumber(spec.width) or 2.0
		local height = tonumber(spec.height) or 4.0
		if not x or not y or not z or length <= 0 or width <= 0 or height <= 0 then
			return nil
		end
		local headingRad = math.rad(-(tonumber(spec.heading) or 0.0))
		local halfW = width * 0.5
		local halfL = length * 0.5
		local halfH = height * 0.5
		local boundingRadius = math.sqrt(halfW * halfW + halfL * halfL)
		if not zones[id] then
			count = count + 1
		end
		local zone = {
			id = id,
			kind = 'box',
			x = x,
			y = y,
			z = z,
			bucket = tonumber(spec.bucket) or 0,
			length = length,
			width = width,
			height = height,
			halfLength = halfL,
			halfWidth = halfW,
			halfHeight = halfH,
			heading = tonumber(spec.heading) or 0.0,
			minZ = tonumber(spec.minZ),
			maxZ = tonumber(spec.maxZ),
			_cosH = math.cos(headingRad),
			_sinH = math.sin(headingRad),
			radius = boundingRadius,
			boundingRadius = boundingRadius,
			prompt = spec.prompt,
			canInteract = spec.canInteract,
			onEnter = spec.onEnter,
			onExit = spec.onExit,
			onSelect = spec.onSelect,
			data = spec.data
		}
		zones[id] = zone
		indexZone(zone)
		return zone
	end

	---Registra ou substitui uma zona poligonal 2.5D (AABB + Ray-Casting).
	---@param id string
	---@param spec table `{ points: number[]|table[], minZ?: number, maxZ?: number, bucket?: integer, prompt?: table|function, canInteract?: function, onEnter?: function, onExit?: function, onSelect?: function, data?: any }`
	---@return table|nil zone
	function self.AddPolygon(id, spec)
		if type(id) ~= 'string' or id == '' or type(spec) ~= 'table' or type(spec.points) ~= 'table' then
			return nil
		end
		local vx, vy = {}, {}
		local nVerts = 0
		local minX, maxX = math.huge, -math.huge
		local minY, maxY = math.huge, -math.huge
		local sumX, sumY = 0.0, 0.0

		if type(spec.points[1]) == 'table' then
			for i = 1, #spec.points do
				local pt = spec.points[i]
				local px, py = tonumber(pt.x or pt[1]), tonumber(pt.y or pt[2])
				if not px or not py then
					return nil
				end
				nVerts = nVerts + 1
				vx[nVerts], vy[nVerts] = px, py
				sumX, sumY = sumX + px, sumY + py
				if px < minX then minX = px end
				if px > maxX then maxX = px end
				if py < minY then minY = py end
				if py > maxY then maxY = py end
			end
		else
			if #spec.points < 6 or #spec.points % 2 ~= 0 then
				return nil
			end
			for i = 1, #spec.points, 2 do
				local px, py = tonumber(spec.points[i]), tonumber(spec.points[i + 1])
				if not px or not py then
					return nil
				end
				nVerts = nVerts + 1
				vx[nVerts], vy[nVerts] = px, py
				sumX, sumY = sumX + px, sumY + py
				if px < minX then minX = px end
				if px > maxX then maxX = px end
				if py < minY then minY = py end
				if py > maxY then maxY = py end
			end
		end

		if nVerts < 3 then
			return nil
		end

		local cx, cy = sumX / nVerts, sumY / nVerts
		local minZ = tonumber(spec.minZ) or -500.0
		local maxZ = tonumber(spec.maxZ) or 2500.0
		local cz = (minZ + maxZ) * 0.5
		local maxDistSq = 0.0
		for i = 1, nVerts do
			local dx, dy = vx[i] - cx, vy[i] - cy
			local dSq = dx * dx + dy * dy
			if dSq > maxDistSq then
				maxDistSq = dSq
			end
		end
		local boundingRadius = math.sqrt(maxDistSq)

		if not zones[id] then
			count = count + 1
		end
		local zone = {
			id = id,
			kind = 'polygon',
			x = cx,
			y = cy,
			z = cz,
			bucket = tonumber(spec.bucket) or 0,
			minZ = minZ,
			maxZ = maxZ,
			minX = minX,
			maxX = maxX,
			minY = minY,
			maxY = maxY,
			vx = vx,
			vy = vy,
			n = nVerts,
			radius = boundingRadius,
			boundingRadius = boundingRadius,
			prompt = spec.prompt,
			canInteract = spec.canInteract,
			onEnter = spec.onEnter,
			onExit = spec.onExit,
			onSelect = spec.onSelect,
			data = spec.data
		}
		zones[id] = zone
		indexZone(zone)
		return zone
	end

	---Remove uma zona pelo ID.
	---@param id string
	---@return boolean removed
	function self.Remove(id)
		if not zones[id] then
			return false
		end
		unindex(id)
		zones[id] = nil
		count = count - 1
		return true
	end

	---Remove todas as zonas registradas.
	function self.Clear()
		zones = {}
		grid = {}
		zoneCells = {}
		count = 0
	end

	---Obtém uma zona pelo ID.
	---@param id string
	---@return table|nil
	function self.Get(id)
		return zones[id]
	end

	---Total de zonas registradas.
	---@return integer
	function self.Count()
		return count
	end

	---Verifica se um ponto está dentro de uma zona específica.
	---@param zone table
	---@param x number
	---@param y number
	---@param z number
	---@return boolean inside, number distance
	function self.Contains(zone, x, y, z)
		if type(zone) ~= 'table' then
			return false, math.huge
		end
		if zone.kind == 'box' then
			return pointInBox(zone, x, y, z)
		elseif zone.kind == 'polygon' then
			return pointInPolygon(zone, x, y, z)
		end
		return pointInSphere(zone, x, y, z)
	end

	---Consulta as zonas candidatas na vizinhança 3x3 de células da grade espacial ao redor de (x, y).
	---@param x number
	---@param y number
	---@param z number
	---@param bucket? integer
	---@return table[] candidates
	function self.Query(x, y, z, bucket)
		if count == 0 then
			return {}
		end
		local cx = cellCoord(x, invCellSize)
		local cy = cellCoord(y, invCellSize)
		local b = bucket or 0
		local seen = {}
		local candidates = {}
		for dx = -1, 1 do
			for dy = -1, 1 do
				local cellBucket = grid[cellKey(cx + dx, cy + dy, b)]
				if cellBucket then
					for id, zone in pairs(cellBucket) do
						if not seen[id] then
							seen[id] = true
							candidates[#candidates + 1] = zone
						end
					end
				end
			end
		end
		return candidates
	end

	---Retorna a zona ativa mais próxima que contém (x, y, z) e passa em `canInteract` (se definido),
	---além de indicar se há alguma zona candidata na vizinhança (para ajustar o intervalo de tick).
	---@param x number
	---@param y number
	---@param z number
	---@param bucket? integer
	---@return table|nil bestZone, number|nil bestDistance, boolean hasNearbyCandidate
	function self.Nearest(x, y, z, bucket)
		local candidates = self.Query(x, y, z, bucket)
		if #candidates == 0 then
			return nil, nil, false
		end
		local bestZone, bestDist = nil, nil
		local nearAny = false
		for i = 1, #candidates do
			local zone = candidates[i]
			local inside, dist = self.Contains(zone, x, y, z)
			if dist <= (zone.boundingRadius or zone.radius) + 15.0 then
				nearAny = true
			end
			if inside and (not bestDist or dist < bestDist) then
				if type(zone.canInteract) ~= 'function' or zone.canInteract(zone) == true then
					bestZone, bestDist = zone, dist
				end
			end
		end
		return bestZone, bestDist, nearAny
	end

	return self
end

local defaultRegistry = CoeZones.New()

CoeZones.AddSphere = defaultRegistry.AddSphere
CoeZones.AddBox = defaultRegistry.AddBox
CoeZones.AddPolygon = defaultRegistry.AddPolygon
CoeZones.Remove = defaultRegistry.Remove
CoeZones.Clear = defaultRegistry.Clear
CoeZones.Get = defaultRegistry.Get
CoeZones.Count = defaultRegistry.Count
CoeZones.Contains = defaultRegistry.Contains
CoeZones.Query = defaultRegistry.Query
CoeZones.Nearest = defaultRegistry.Nearest

local interactListeners = {}
local interactHooked = false

---Registra um callback disparado quando o jogador pressiona a tecla de interação ('+coe_interact' / E).
---Não utiliza polling Wait(0); responde ao evento local `coe_core:interact`.
---@param fn fun()
---@return integer listenerId
function CoeZones.OnInteract(fn)
	if type(fn) ~= 'function' then
		return 0
	end
	if not interactHooked and type(AddEventHandler) == 'function' then
		interactHooked = true
		AddEventHandler('coe_core:interact', function()
			for _, cb in pairs(interactListeners) do
				cb()
			end
		end)
	end
	local id = #interactListeners + 1
	interactListeners[id] = fn
	return id
end

local lastPromptKey = nil

---Atualiza o prompt NUI do resource local apenas quando o conteúdo muda (zero tráfego NUI redundante).
---@param prompt table|nil
---@param customKey string|nil
function CoeZones.SetPrompt(prompt, customKey)
	local key = customKey
	if key == nil and type(prompt) == 'table' then
		local firstOpt = type(prompt.options) == 'table' and prompt.options[1] and prompt.options[1].label or ''
		key = (tostring(prompt.title or '') .. '|' .. tostring(prompt.subtitle or '') .. '|' .. tostring(firstOpt))
	end
	if key ~= lastPromptKey then
		lastPromptKey = key
		if type(SendNUIMessage) == 'function' then
			SendNUIMessage({ action = 'prompt', data = prompt })
		end
	end
end

return CoeZones
