-- Câmera ao abrir uma maleta do mundo: enquadra a maleta enquanto o inventário está aberto.
-- Não mexe em ped, animação nem na entidade (que é compartilhada com outros jogadores);
-- qualquer falha ou ausência da entidade apenas dispensa a câmera.
local C = Inventory.Client
local state = C.state

local CAMERA_EASE_MS = 600
local WATCH_MS = 500
local FOV = 45.0

local function cameraPosition(pedCoords, caseCoords)
	local dx, dy = caseCoords.x - pedCoords.x, caseCoords.y - pedCoords.y
	local length = math.sqrt(dx * dx + dy * dy)
	if length < 0.01 then dx, dy, length = 0.0, 1.0, 1.0 end
	dx, dy = dx / length, dy / length
	return pedCoords.x + dy * 1.1 - dx * 0.5, pedCoords.y - dx * 1.1 - dy * 0.5, pedCoords.z + 0.8
end

--- Devolve a câmera ao jogo. Seguro de chamar sem câmera ativa.
function C.endOpenCamera()
	local camera = state.openCamera
	if not camera then return end
	state.openCamera = nil
	RenderScriptCams(false, true, CAMERA_EASE_MS, true, false)
	DestroyCam(camera.cam, false)
end

local function start(entity)
	local ped = PlayerPedId()
	local caseCoords = GetEntityCoords(entity)
	local cx, cy, cz = cameraPosition(GetEntityCoords(ped), caseCoords)
	local cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', cx, cy, cz, 0.0, 0.0, 0.0, FOV, true, 2)
	PointCamAtCoord(cam, caseCoords.x, caseCoords.y, caseCoords.z + 0.1)
	SetCamActive(cam, true)
	RenderScriptCams(true, true, CAMERA_EASE_MS, true, false)

	local camera = { cam = cam, entity = entity }
	state.openCamera = camera

	-- A maleta pode sumir (outro jogador pegou) enquanto o inventário está aberto.
	CreateThread(function()
		while state.openCamera == camera do
			if not DoesEntityExist(entity) then
				C.endOpenCamera()
				return
			end
			Wait(WATCH_MS)
		end
	end)
end

--- Enquadra a maleta do mundo ``netId``. Sem entidade local ou em caso de erro, não faz nada.
function C.startOpenCamera(netId)
	C.endOpenCamera()
	local entity = netId and NetworkGetEntityFromNetworkId(netId) or 0
	if entity == 0 or not DoesEntityExist(entity) then return end
	local ok, err = pcall(start, entity)
	if not ok then
		print(('[coe_inventory] erro na câmera da maleta: %s'):format(tostring(err)))
		C.endOpenCamera()
	end
end
