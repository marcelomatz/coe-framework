-- Equipamentos de imprensa (câmera de TV, microfone, boom). Usar o item no inventário segura o equipamento com a
-- animação; usar de novo, apertar a tecla de cancelar (X) ou entrar num veículo guarda. É só visual: o item continua
-- no inventário e nada aqui é autoridade do servidor.
local settings = NewsConfig.Equipment
local _t = function(key, params)
	if Core and Core.Locale and Core.Locale.New then
		return Core.Locale.New({ default = Core.Locale.GetDefaultLang(), locales = Locales or {} })(key, params)
	end
	if Locales and Locales['pt-BR'] and Locales['pt-BR'][key] then
		return Locales['pt-BR'][key]
	end
	return key
end

local byName = {}
for _, item in ipairs(settings.Items) do
	byName[item.name] = item
end

local held = nil

local function request(load, loaded, name)
	load(name)
	local deadline = GetGameTimer() + 5000
	while not loaded(name) do
		if GetGameTimer() > deadline then
			return false
		end
		Wait(10)
	end
	return true
end

local function stop()
	local current = held
	held = nil
	if not current then
		return
	end
	local ped = PlayerPedId()
	if current.object and Core.Platform.Entities.Exists(current.object) then
		DetachEntity(current.object, true, false)
		Core.Platform.Entities.Delete(current.object)
	end
	StopAnimTask(ped, current.item.dict, current.item.anim, 1.0)
	ClearPedSecondaryTask(ped)
	RemoveAnimDict(current.item.dict)
end

local function playAnimation(ped, item)
	TaskPlayAnim(ped, item.dict, item.anim, 2.0, 2.0, -1, item.flag or 49, 0, false, false, false)
end

local function start(item)
	local ped = PlayerPedId()
	if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) then
		return
	end
	local model = GetHashKey(item.prop)
	if not request(RequestModel, HasModelLoaded, model) or not request(RequestAnimDict, HasAnimDictLoaded, item.dict) then
		pcall(function()
			exports.coe_notify:Show('error', _t('equipment_load_failed'))
		end)
		return
	end
	local coords = Core.Platform.Entities.GetCoords(ped)
	local object = CreateObject(model, coords.x, coords.y, coords.z + 0.2, false, false, false)
	SetModelAsNoLongerNeeded(model)
	local offset, rotation = item.offset, item.rotation
	AttachEntityToEntity(object, ped, GetPedBoneIndex(ped, item.bone), offset[1], offset[2], offset[3],
		rotation[1], rotation[2], rotation[3], true, true, false, true, 1, true)
	playAnimation(ped, item)
	held = { item = item, object = object }

	CreateThread(function()
		local current = held
		while held == current do
			local playerPed = PlayerPedId()
			if IsControlJustPressed(0, settings.CancelKey) or IsPedInAnyVehicle(playerPed, true) or IsEntityDead(playerPed) then
				stop()
				return
			end
			if not IsEntityPlayingAnim(playerPed, item.dict, item.anim, 3) then
				playAnimation(playerPed, item)
			end
			Wait(0)
		end
	end)
end

Core.Events.On('inventory.itemUsed', function(item)
	local name = type(item) == 'table' and item.name or nil
	local definition = name and byName[name]
	if not definition then
		return
	end
	local same = held and held.item.name == name
	stop()
	if not same then
		start(definition)
	end
end)

AddEventHandler('onResourceStop', function(resource)
	if resource == GetCurrentResourceName() then
		stop()
	end
end)
