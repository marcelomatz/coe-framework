local registeredExports = {}
local registeredEvents = {}
local messages = {}
source = 65535

exports = function(name, callback)
	registeredExports[name] = callback
end
RegisterNetEvent = function(name, callback)
	registeredEvents[name] = callback
end
SendNUIMessage = function(message)
	messages[#messages + 1] = message
end
AddEventHandler = function() end
GetCurrentResourceName = function()
	return 'coe_notify'
end

dofile('client.lua')

local function assertEqual(actual, expected, message)
	if actual ~= expected then
		error(('%s: expected %s, got %s'):format(message, tostring(expected), tostring(actual)))
	end
end

local shown, showError = registeredExports.Show('success', 'Salvo.', 2500)
assertEqual(shown, true, 'valid local notification is shown')
assertEqual(showError, nil, 'successful local notification has no error')
assertEqual(messages[1].type, 'success', 'notification type reaches NUI')
assertEqual(messages[1].message, 'Salvo.', 'notification text reaches NUI')

local invalid, invalidError = registeredExports.Show('custom', 'texto')
assertEqual(invalid, false, 'unknown notification type is rejected')
assertEqual(invalidError, 'invalid_notification', 'invalid request has explicit error')
assertEqual(#messages, 1, 'invalid request is not displayed')

source = 42
registeredEvents['coe_notify:display']('error', 'falsificada', 3000)
assertEqual(#messages, 1, 'client cannot dispatch a server notification event')

source = 65535
registeredEvents['coe_notify:display']('warning', 'Servidor atualizado.', 3000)
assertEqual(#messages, 2, 'server notification is displayed')
assertEqual(messages[2].type, 'warning', 'server notification keeps its type')

-- Aviso de interação padrão (Prompt)
local invoking = 'coe_rentals'
GetInvokingResource = function() return invoking end
local before = #messages
local ok = registeredExports.Prompt({ title = 'Aluguel', subtitle = 'Locadora', options = { { key = 'E', label = 'Alugar ~r~veículo' } } })
assertEqual(ok, true, 'valid prompt is accepted')
local last = messages[#messages]
assertEqual(last.action, 'prompt', 'prompt reaches NUI')
assertEqual(last.data.title, 'Aluguel', 'prompt title reaches NUI')
assertEqual(last.data.badge, 'E', 'badge defaults to first key')
assertEqual(last.data.options[1].label, 'Alugar veículo', 'GTA color codes are stripped')

invoking = 'coe_admin'
registeredExports.Prompt({ title = 'Noclip', badge = 'NC', options = {} })
assertEqual(messages[#messages].data.title, 'Noclip', 'newest prompt wins')
registeredExports.Prompt(nil)
assertEqual(messages[#messages].data.title, 'Aluguel', 'clearing restores previous owner prompt')

local bad, badError = registeredExports.Prompt({ subtitle = 'sem título' })
assertEqual(bad, false, 'prompt without title is rejected')
assertEqual(badError, 'invalid_prompt', 'invalid prompt has explicit error')

invoking = 'coe_rentals'
registeredExports.Prompt(nil)
assertEqual(messages[#messages].data, nil, 'clearing last prompt hides it')
assert(#messages > before)

print('client notification tests passed')
