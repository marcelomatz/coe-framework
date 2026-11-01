-- Interface única de craft: abre quando o servidor manda, nunca por iniciativa do cliente.
local open, animation, animating = false, nil, false

local function stopAnimation()
	if animating and animation then
		animating = false
		StopAnimTask(PlayerPedId(), animation.dict, animation.name, 2.0)
	end
end

local function startAnimation()
	if not animation then
		return
	end
	RequestAnimDict(animation.dict)
	local deadline = GetGameTimer() + 2000
	while not HasAnimDictLoaded(animation.dict) and GetGameTimer() < deadline do
		Wait(0)
	end
	if HasAnimDictLoaded(animation.dict) then
		TaskPlayAnim(PlayerPedId(), animation.dict, animation.name, 4.0, -4.0, -1, 1, 0.0, false, false, false)
		animating = true
	end
end

local function closePanel()
	if not open then
		return
	end
	open = false
	stopAnimation()
	animation = nil
	SetNuiFocus(false, false)
	SendNUIMessage({ action = 'close' })
end

RegisterNetEvent('coe_crafting:open', function(data)
	if type(data) ~= 'table' then
		return
	end
	open, animation = true, data.animation
	SetNuiFocus(true, true)
	SendNUIMessage({ action = 'open', data = { label = data.label, recipes = data.recipes } })
end)

RegisterNetEvent('coe_crafting:recipes', function(recipes)
	SendNUIMessage({ action = 'recipes', data = recipes })
end)

RegisterNetEvent('coe_crafting:started', function(label, timeMs)
	SendNUIMessage({ action = 'started', data = { label = label, timeMs = timeMs } })
	CreateThread(startAnimation)
end)

RegisterNetEvent('coe_crafting:done', function(recipes)
	stopAnimation()
	if recipes then
		SendNUIMessage({ action = 'recipes', data = recipes })
	end
	SendNUIMessage({ action = 'done' })
end)

RegisterNetEvent('coe_crafting:failed', function(errorCode)
	stopAnimation()
	SendNUIMessage({ action = 'error', data = tostring(errorCode) })
end)

RegisterNetEvent('coe_crafting:close', closePanel)

RegisterNUICallback('craft', function(data, cb)
	if open and type(data) == 'table' and type(data.recipe) == 'string' then
		TriggerServerEvent('coe_crafting:craft', data.recipe)
	end
	cb({ ok = true })
end)

RegisterNUICallback('refresh', function(_, cb)
	if open then
		TriggerServerEvent('coe_crafting:refresh')
	end
	cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
	if open then
		closePanel()
		TriggerServerEvent('coe_crafting:close')
	end
	cb({ ok = true })
end)

AddEventHandler('onResourceStop', function(resource)
	if resource == GetCurrentResourceName() then
		stopAnimation()
		if open then
			SetNuiFocus(false, false)
		end
	end
end)
