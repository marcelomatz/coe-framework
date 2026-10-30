local notificationTypes = {
	error = true,
	info = true,
	success = true,
	warning = true
}

local function validNotification(kind, message, duration)
	return notificationTypes[kind]
		and type(message) == 'string'
		and #message > 0
		and #message <= 240
		and (duration == nil or (type(duration) == 'number'
			and duration == duration
			and duration >= 1500
			and duration <= 10000))
end

local function show(kind, message, duration)
	if not validNotification(kind, message, duration) then
		return false, 'invalid_notification'
	end

	SendNUIMessage({
		action = 'show',
		type = kind,
		message = message,
		duration = duration or 4000
	})
	return true
end

exports('Show', show)

-- Aviso de interação padrão (coe_ui/prompt.js) para qualquer resource, sem precisar de NUI própria.
-- Cada resource tem no máximo um aviso; o mais recente aparece e, ao ser limpo, volta o anterior.
local prompts = {}
local promptOrder = {}
local promptShown = nil

local function cleanText(value, limit)
	if type(value) ~= 'string' then
		return nil
	end
	value = value:gsub('~%a~', ''):gsub('%c', ' ')
	if #value == 0 then
		return nil
	end
	return value:sub(1, limit)
end

local function sanitizePrompt(data)
	if type(data) ~= 'table' then
		return nil
	end
	local title = cleanText(data.title, 64)
	if not title then
		return nil
	end
	local options = {}
	if type(data.options) == 'table' then
		for index, option in ipairs(data.options) do
			if index > 6 then break end
			local key = type(option) == 'table' and cleanText(option.key, 12)
			local label = type(option) == 'table' and cleanText(option.label, 80)
			if key and label then
				options[#options + 1] = { key = key, label = label }
			end
		end
	end
	return {
		title = title,
		subtitle = cleanText(data.subtitle, 64) or '',
		badge = cleanText(data.badge, 3) or (options[1] and #options[1].key <= 3 and options[1].key) or 'E',
		options = options
	}
end

local function renderPrompt()
	local owner = promptOrder[#promptOrder]
	local data = owner and prompts[owner] or nil
	if data == promptShown then
		return
	end
	promptShown = data
	SendNUIMessage({ action = 'prompt', data = data })
end

local function setPrompt(owner, data)
	for index = #promptOrder, 1, -1 do
		if promptOrder[index] == owner then
			table.remove(promptOrder, index)
		end
	end
	prompts[owner] = data
	if data then
		promptOrder[#promptOrder + 1] = owner
	end
	renderPrompt()
end

exports('Prompt', function(data)
	local owner = (type(GetInvokingResource) == 'function' and GetInvokingResource()) or 'local'
	if data == nil or data == false then
		setPrompt(owner, nil)
		return true
	end
	local clean = sanitizePrompt(data)
	if not clean then
		return false, 'invalid_prompt'
	end
	setPrompt(owner, clean)
	return true
end)

RegisterNetEvent('coe_notify:display', function(kind, message, duration)
	if source ~= 65535 then
		return
	end
	show(kind, message, duration)
end)

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName == GetCurrentResourceName() then
		SendNUIMessage({ action = 'clear' })
	elseif prompts[resourceName] then
		setPrompt(resourceName, nil)
	end
end)
