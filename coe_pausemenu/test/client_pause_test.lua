local netEvents = {}
local nuiCallbacks = {}
local nuiMessages = {}
local serverEvents = {}
local nuiFocus = false
local exportedFunctions = {}
local lastWaypointCoord = nil
local waypointActive = false

RegisterNetEvent = function(name, fn)
	netEvents[name] = fn
end

RegisterNUICallback = function(name, fn)
	nuiCallbacks[name] = fn
end

SendNUIMessage = function(msg)
	nuiMessages[#nuiMessages + 1] = msg
end

SetNuiFocus = function(hasCursor, hasKeyboard)
	nuiFocus = hasCursor and hasKeyboard
end

PlaySoundFrontend = function() end
TriggerServerEvent = function(name, ...)
	serverEvents[#serverEvents + 1] = { name = name, args = { ... } }
end

SetPauseMenuActive = function() end
DisableControlAction = function() end
IsDisabledControlJustReleased = function() return false end
IsPedDeadOrDying = function() return false end
PlayerPedId = function() return 100 end
GetEntityCoords = function() return { x = 100.0, y = 200.0, z = 30.0 } end
GetEntityHeading = function() return 90.0 end
GetStreetNameAtCoord = function() return 12345, 0 end
GetStreetNameFromHashKey = function() return 'Vinewood Boulevard' end
GetNameOfZone = function() return 'VINE' end
GetLabelText = function() return 'Vinewood' end
GetClockHours = function() return 14 end
GetClockMinutes = function() return 30 end
GetFirstBlipInfoId = function() return 0 end
DoesBlipExist = function() return false end
SetNewWaypoint = function(x, y)
	lastWaypointCoord = { x = x, y = y }
	waypointActive = true
end
SetWaypointOff = function()
	lastWaypointCoord = nil
	waypointActive = false
end
local kvpStore = {}
json = {
	encode = function(t)
		if type(t) ~= 'table' then return tostring(t) end
		local parts = {}
		for k, v in pairs(t) do
			table.insert(parts, string.format('"%s":%s', tostring(k), type(v) == 'table' and json.encode(v) or (type(v) == 'string' and ('"%s"'):format(v) or tostring(v))))
		end
		return '{' .. table.concat(parts, ',') .. '}'
	end,
	decode = function(str)
		-- Simple parser for test payloads
		local res = {}
		for k, v in string.gmatch(str, '"([%w_]+)":([%w_]+)') do
			if tonumber(v) then res[k] = tonumber(v)
			elseif v == 'true' then res[k] = true
			elseif v == 'false' then res[k] = false
			else res[k] = v end
		end
		for k, v in string.gmatch(str, '"([%w_]+)":"([^"]+)"') do
			res[k] = v
		end
		return res
	end
}
SetResourceKvp = function(k, v) kvpStore[k] = v end
GetResourceKvpString = function(k) return kvpStore[k] end
DeleteResourceKvp = function(k) kvpStore[k] = nil end
ExecuteCommand = function() end
CreateThread = function() end
Wait = function() end

exports = setmetatable({}, {
	__call = function(_, name, fn)
		exportedFunctions[name] = fn
	end,
	__index = function(_, res)
		return exportedFunctions
	end
})

dofile('config.lua')
dofile('shared/rules.lua')
dofile('client/main.lua')

local function eq(a, b, msg)
	if a ~= b then
		error(('%s: esperado %s, obtido %s'):format(msg, tostring(b), tostring(a)))
	end
end

-- Teste de estado inicial
eq(exports.coe_pausemenu:IsOpen(), false, 'menu fechado inicialmente')
eq(nuiFocus, false, 'foco desativado inicialmente')

-- Teste de abertura via export
exports.coe_pausemenu:Toggle(true)
eq(exports.coe_pausemenu:IsOpen(), true, 'menu aberto via Toggle')
eq(nuiFocus, true, 'foco NUI ativado ao abrir')
eq(serverEvents[#serverEvents].name, 'coe_pausemenu:server:requestData', 'solicitou dados ao servidor')

-- Teste de recebimento de dados
local mockPayload = Rules.BuildPayload({
	name = 'Marcus Holloway',
	stateId = 'COE9999'
}, {
	onlinePlayers = 10,
	ping = 20
})

netEvents['coe_pausemenu:client:receiveData'](mockPayload)
eq(#nuiMessages, 1, 'mensagem NUI enviada')
local lastMsg = nuiMessages[#nuiMessages]
eq(lastMsg.action, 'open', 'ação NUI é open')
eq(lastMsg.data.character.name, 'Marcus Holloway', 'nome no payload NUI')
eq(lastMsg.data.server.gameTime, '14:30', 'hora do jogo injetada no cliente')
eq(lastMsg.data.character.location, 'Vinewood Boulevard, Vinewood', 'localização injetada')
eq(lastMsg.data.character.coords.x, 100.0, 'coordenada X enviada ao NUI')

-- Teste de callback 'close'
local closedOk = false
nuiCallbacks['close']({}, function(r) closedOk = r.ok end)
eq(closedOk, true, 'callback close executado com sucesso')
eq(exports.coe_pausemenu:IsOpen(), false, 'menu fechado apos callback close')
eq(nuiFocus, false, 'foco NUI desativado')

-- Teste de marcar waypoint no mapa interativo
local wpOk = false
nuiCallbacks['setWaypoint']({ x = 298.0, y = -584.0 }, function(r) wpOk = r.ok end)
eq(wpOk, true, 'callback setWaypoint executado')
eq(waypointActive, true, 'waypoint ativado no jogo')
eq(lastWaypointCoord.x, 298.0, 'coordenada X do waypoint')
eq(lastWaypointCoord.y, -584.0, 'coordenada Y do waypoint')

-- Teste de limpar waypoint
nuiCallbacks['clearWaypoint']({}, function(r) wpOk = r.ok end)
eq(waypointActive, false, 'waypoint desativado no jogo')

-- Teste de callback 'disconnect'
exports.coe_pausemenu:Toggle(true)
local dcOk = false
nuiCallbacks['disconnect']({}, function(r) dcOk = r.ok end)
eq(dcOk, true, 'callback disconnect executado com sucesso')
eq(serverEvents[#serverEvents].name, 'coe_pausemenu:server:disconnect', 'evento de desconexao enviado')

-- Teste de callbacks de configurações e teclados
local setOk = false
nuiCallbacks['saveSettings']({ masterVol = 90, voiceVol = 85 }, function(r) setOk = r.ok end)
eq(setOk, true, 'saveSettings executado')
eq(type(kvpStore['coe_pausemenu_settings']), 'string', 'kvp de settings persistido')

local kbOk = false
nuiCallbacks['updateKeybind']({ id = 'voice_ptt', key = 'MOUSE4' }, function(r) kbOk = r.ok end)
eq(kbOk, true, 'updateKeybind executado')
eq(type(kvpStore['coe_pausemenu_keybinds']), 'string', 'kvp de keybinds persistido')

local getOk = false
local retrievedData = nil
nuiCallbacks['getSettings']({}, function(r) getOk = r.ok; retrievedData = r end)
eq(getOk, true, 'getSettings executado')
eq(retrievedData.settings.masterVol, 90, 'retornou masterVol correto')
eq(retrievedData.keybinds.voice_ptt, 'MOUSE4', 'retornou keybind correto')

local resetOk = false
nuiCallbacks['resetSettings']({}, function(r) resetOk = r.ok end)
eq(resetOk, true, 'resetSettings executado')
eq(kvpStore['coe_pausemenu_settings'], nil, 'settings limpos apos reset')
eq(kvpStore['coe_pausemenu_keybinds'], nil, 'keybinds limpos apos reset')

print('coe_pausemenu client tests passed')
