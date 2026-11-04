-- Subsistema de zonas espaciais (Core.Zones / CoeZones) com grade espacial 2D (Spatial Hash Grid)
-- e integração orientada a eventos com o keymapping unificado '+coe_interact' (E), eliminando loops Wait(0).
CoeZones = CoeZones or {}

local DEFAULT_CELL_SIZE = 50.0

local function cellCoord(value, cellSize)
	return math.floor(value / cellSize)
end

local function cellKey(cx, cy)
	return cx .. ':' .. cy
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

---Cria uma instância isolada de registro espacial de zonas.
---@param opts table|nil `{ cellSize?: number }`
---@return table registry
function CoeZones.New(opts)
	local cellSize = (type(opts) == 'table' and tonumber(opts.cellSize) and opts.cellSize > 0) and opts.cellSize or DEFAULT_CELL_SIZE
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
		for _, key in ipairs(keys) do
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
		local minCx = cellCoord(zone.x - extent, cellSize)
		local maxCx = cellCoord(zone.x + extent, cellSize)
		local minCy = cellCoord(zone.y - extent, cellSize)
		local maxCy = cellCoord(zone.y + extent, cellSize)
		local keys = {}
		for cx = minCx, maxCx do
			for cy = minCy, maxCy do
				local key = cellKey(cx, cy)
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
	---@param spec table `{ x: number, y: number, z: number, radius: number, prompt?: table|function, canInteract?: function, onEnter?: function, onExit?: function, onSelect?: function, data?: any }`
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
	---@param spec table `{ x: number, y: number, z: number, length: number, width: number, height?: number, heading?: number, minZ?: number, maxZ?: number, prompt?: table|function, canInteract?: function, onEnter?: function, onExit?: function, onSelect?: function, data?: any }`
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
		end
		return pointInSphere(zone, x, y, z)
	end

	---Consulta as zonas candidatas na vizinhança 3x3 de células da grade espacial ao redor de (x, y).
	---@param x number
	---@param y number
	---@param z number
	---@return table[] candidates
	function self.Query(x, y, z)
		if count == 0 then
			return {}
		end
		local cx = cellCoord(x, cellSize)
		local cy = cellCoord(y, cellSize)
		local seen = {}
		local candidates = {}
		for dx = -1, 1 do
			for dy = -1, 1 do
				local bucket = grid[cellKey(cx + dx, cy + dy)]
				if bucket then
					for id, zone in pairs(bucket) do
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
	---@return table|nil bestZone, number|nil bestDistance, boolean hasNearbyCandidate
	function self.Nearest(x, y, z)
		local candidates = self.Query(x, y, z)
		if #candidates == 0 then
			return nil, nil, false
		end
		local bestZone, bestDist = nil, nil
		local nearAny = false
		for _, zone in ipairs(candidates) do
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
