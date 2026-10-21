-- Integracao com o minimapa nativo: posicao, localizacao (rua, regiao, bussola, hora)
-- e remocao dos elementos nativos que o HUD passa a exibir.
Location = { hideNative = true, scale = 1.0, minimap = nil, aspect = 'full' }

-- O coe_map avisa quando o minimapa muda de tamanho (modo estendido).
AddEventHandler('coe_map:changed', function(_, scale)
	Location.scale = tonumber(scale) or 1.0
end)

local DIRECTIONS = { 'N', 'NE', 'L', 'SE', 'S', 'SO', 'O', 'NO' }
local READ_INTERVAL_MS = 500
local cache, cachedAt = nil, -READ_INTERVAL_MS

-- Heading do GTA: 0 = norte e cresce no sentido anti-horario.
function Location.Direction(heading)
	local degrees = (360 - (heading or 0)) % 360
	return DIRECTIONS[math.floor((degrees + 22.5) / 45) % 8 + 1]
end

local function label(text)
	if not text or text == '' or text == 'NULL' then
		return ''
	end
	return text
end

function Location.Read(ped)
	local now = GetGameTimer()
	local coords = GetEntityCoords(ped)
	if cache and now - cachedAt < READ_INTERVAL_MS then
		cache.dir = Location.Direction(GetEntityHeading(ped))
		return cache
	end
	cachedAt = now
	local streetHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
	cache = {
		dir = Location.Direction(GetEntityHeading(ped)),
		street = label(GetStreetNameFromHashKey(streetHash)),
		zone = label(GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))),
		clock = ('%02d:%02d'):format(GetClockHours(), GetClockMinutes())
	}
	return cache
end

local function streetAt(x, y, z)
	local hash = GetStreetNameAtCoord(x, y, z)
	return label(GetStreetNameFromHashKey(hash))
end

local ROUTE_INTERVAL_MS = 1000
local routeCache, routeSignature, routeAt = {}, '', -ROUTE_INTERVAL_MS

-- Proximas ruas a frente (cache de 1 s; devolve a mesma tabela enquanto nada mudar).
function Location.Route(ped)
	local now = GetGameTimer()
	if now - routeAt < ROUTE_INTERVAL_MS then
		return routeCache
	end
	routeAt = now
	local vehicle = GetVehiclePedIsIn(ped, false)
	local speed = GetEntitySpeed(vehicle ~= 0 and vehicle or ped)
	local found = Route.Next(GetEntityCoords(ped), GetEntityHeading(ped), speed, streetAt)
	local parts = {}
	for i, step in ipairs(found) do
		parts[i] = step.name .. step.side .. step.dist
	end
	local signature = table.concat(parts, '|')
	if signature ~= routeSignature then
		routeSignature, routeCache = signature, found
	end
	return routeCache
end

local function round(value)
	return math.floor(value * 10000 + 0.5) / 10000
end

-- Retangulo padrao do minimapa na tela (fracoes 0-1), pela formula do GTA (safezone + aspecto).
function Location.Base()
	local ok, base = pcall(function()
		local safezone = GetSafeZoneSize()
		local margin = math.abs(safezone - 1.0) * 10 / 20.0
		local aspect = GetAspectRatio(false)
		local width = 1.0 / (4 * aspect)
		local height = 1.0 / 5.674
		local left = margin
		local bottom = 1.0 - margin
		return { l = round(left), r = round(left + width), t = round(bottom - height), b = round(bottom), safezone = round(safezone), aspect = aspect }
	end)
	if not ok then
		return nil
	end
	return base
end

-- Posicao atual do minimapa: padrao + layout do jogador (Location.minimap) + modo estendido do coe_map.
function Location.Anchor()
	local base = Location.Base()
	if not base then
		return nil
	end
	local area = MinimapLayout.Area(Location.aspect, base.aspect)
	return MinimapLayout.Rect(MinimapLayout.AreaBase(base, area), Location.minimap, Location.scale, area)
end
function Location.AnchorEquals(a, b)
	if not a or not b then
		return a == b
	end
	return a.l == b.l and a.r == b.r and a.t == b.t and a.b == b.b
end

-- Esconde vida/colete desenhados no proprio minimapa (o HUD tem os icones). O GTA redesenha
-- esses arcos, entao a chamada precisa ser feita a cada frame, depois de alternar o bigmap
-- uma vez para o radar inicializar por completo.
CreateThread(function()
	Wait(2000)
	local scaleform = RequestScaleformMovie('minimap')
	local tries = 0
	while not HasScaleformMovieLoaded(scaleform) and tries < 50 do
		tries = tries + 1
		Wait(100)
	end
	SetMinimapClipType(0)
	SetRadarBigmapEnabled(true, false)
	Wait(0)
	SetRadarBigmapEnabled(false, false)
	while true do
		if BeginScaleformMovieMethod(scaleform, 'SETUP_HEALTH_ARMOUR') then
			ScaleformMovieMethodAddParamInt(3)
			EndScaleformMovieMethod()
		end
		Wait(0)
	end
end)

-- Nomes de veiculo, regiao, classe e rua nativos (componentes 6 a 9).
CreateThread(function()
	while true do
		if Location.hideNative then
			HideHudComponentThisFrame(6)
			HideHudComponentThisFrame(7)
			HideHudComponentThisFrame(8)
			HideHudComponentThisFrame(9)
			Wait(0)
		else
			Wait(500)
		end
	end
end)
