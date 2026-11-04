local config = AmzgConfig

local _t = function(key, params)
	if Core and Core.Locale and Core.Locale.New then
		return Core.Locale.New({ default = Core.Locale.GetDefaultLang(), locales = Locales or {} })(key, params)
	end
	if Locales and Locales['pt-BR'] and Locales['pt-BR'][key] then
		return Locales['pt-BR'][key]
	end
	return key
end

local boxes = {}
local entities = {}
local generation = 0

local function clear()
	for id, entity in pairs(entities) do
		if Core.Platform.Entities.Exists(entity) then
			DeleteObject(entity)
		end
		entities[id] = nil
	end
end

local function loadModel(model)
	local hash = joaat(model)
	if not IsModelInCdimage(hash) then
		return nil
	end
	RequestModel(hash)
	local deadline = GetGameTimer() + 5000
	while not HasModelLoaded(hash) and GetGameTimer() < deadline do
		Wait(10)
	end
	return HasModelLoaded(hash) and hash or nil
end

local function spawn()
	clear()
	if #boxes == 0 then
		return
	end
	local hash = loadModel(config.Box.Model)
	if not hash then
		return
	end
	for _, box in ipairs(boxes) do
		local entity = CreateObjectNoOffset(hash, box.x, box.y, box.z, false, false, false)
		if entity and entity ~= 0 then
			PlaceObjectOnGroundProperly(entity)
			FreezeEntityPosition(entity, true)
			SetEntityInvincible(entity, true)
			entities[box.id] = entity
		end
	end
	SetModelAsNoLongerNeeded(hash)
end

local function boxOf(entity)
	for id, candidate in pairs(entities) do
		if candidate == entity then
			return id
		end
	end
	return nil
end

local function registerTarget()
	if GetResourceState('coetarget') ~= 'started' then
		return
	end
	pcall(function()
		exports.coetarget:AddTargetModel(config.Box.Model, {
			{
				label = _t('open_box'),
				distance = config.Box.Reach,
				canInteract = function(entity)
					return boxOf(entity) ~= nil
				end,
				onSelect = function(entity)
					local id = boxOf(entity)
					if id then
						TriggerServerEvent('coe_amzg:openBox', id)
					end
				end
			}
		})
	end)
end

-- O teleporte para o interior acontece depois do evento: espera chegar perto antes de pedir as caixas.
local function requestWhenInside(interior)
	generation = generation + 1
	local current = generation
	CreateThread(function()
		local deadline = GetGameTimer() + 15000
		local target = vector3(interior.x, interior.y, interior.z)
		while current == generation and GetGameTimer() < deadline do
			if #(Core.Platform.Entities.GetCoords(PlayerPedId()) - target) < 30.0 then
				Wait(500)
				TriggerServerEvent('coe_amzg:requestBoxes')
				return
			end
			Wait(250)
		end
	end)
end

RegisterNetEvent('coe_housing:entered', function(info)
	if type(info) == 'table' and type(info.interior) == 'table' then
		requestWhenInside(info.interior)
	end
end)

RegisterNetEvent('coe_housing:left', function()
	generation = generation + 1
	boxes = {}
	clear()
end)

RegisterNetEvent('coe_amzg:boxes', function(list)
	boxes = type(list) == 'table' and list or {}
	spawn()
end)

AddEventHandler('coetarget:ready', registerTarget)

AddEventHandler('onResourceStop', function(resource)
	if resource == GetCurrentResourceName() then
		clear()
	end
end)

CreateThread(function()
	registerTarget()
end)
