local messages, callbacks, commands, kvp = {}, {}, {}, {}
local natives = {
	health = 200, armor = 0, vehicle = 0, seatDriver = true, speed = 0
}
local radar = nil
flags, indicators = {}, {}
local focus = nil

json = {
	encode = function(value) return value end,
	decode = function(value) return value end
}
SendNUIMessage = function(m) messages[#messages + 1] = m end
RegisterNUICallback = function(name, fn) callbacks[name] = fn end
RegisterCommand = function(name, fn) commands[name] = fn end
local handlers = {}
AddEventHandler = function(name, fn) handlers[name] = fn end
RegisterKeyMapping = function(name, _, _, key) keymaps = keymaps or {}; keymaps[name] = key end
SetPedConfigFlag = function(_, flag, value) flags[flag] = value end
DoesEntityExist = function() return true end
SetVehicleIndicatorLights = function(_, side, on) indicators[side] = on end
SetVehicleLights = function() end
SetVehicleFullbeam = function() end
DisableControlAction = function() end
GetCurrentResourceName = function() return 'coe_hud' end
SetNuiFocus = function(a) focus = a end
DisplayRadar = function(v) radar = v end
GetResourceKvpString = function(k) return kvp[k] end
SetResourceKvp = function(k, v) kvp[k] = v end
PlayerPedId = function() return 1 end
GetEntityHealth = function() return natives.health end
GetEntityMaxHealth = function() return 200 end
GetPedArmour = function() return natives.armor end
GetVehiclePedIsIn = function() return natives.vehicle end
GetPedInVehicleSeat = function() return natives.seatDriver and 1 or 0 end
GetVehicleClass = function() return 8 end
GetEntitySpeed = function() return natives.speed end
GetVehicleCurrentRpm = function() return 0.5 end
GetVehicleCurrentGear = function() return 3 end
GetVehicleFuelLevel = function() return 40 end
GetVehicleEngineHealth = function() return 900 end
GetIsVehicleEngineRunning = function() return true end
local gameTimer = 0
GetGameTimer = function() gameTimer = gameTimer + 3000; return gameTimer end
GetEntityCoords = function() return { x = 1.0, y = 2.0, z = 3.0 } end
GetEntityHeading = function() return 90.0 end
GetStreetNameAtCoord = function() return 11 end
GetStreetNameFromHashKey = function() return 'Vinewood Blvd' end
GetNameOfZone = function() return 'VINE' end
GetLabelText = function() return 'Vinewood' end
GetClockHours = function() return 9 end
GetClockMinutes = function() return 5 end
GetSafeZoneSize = function() return 0.95 end
local screenAspect = 16 / 9
GetAspectRatio = function() return screenAspect end
RequestScaleformMovie = function() return 1 end
HasScaleformMovieLoaded = function() return true end
BeginScaleformMovieMethod = function() end
ScaleformMovieMethodAddParamInt = function() end
EndScaleformMovieMethod = function() end
HideHudComponentThisFrame = function() end
local components, bigmapToggles = {}, 0
SetMinimapComponentPosition = function(name, alignX, alignY, x, y, w, h)
	components[name] = { alignX = alignX, alignY = alignY, x = x, y = y, w = w, h = h }
end
SetRadarBigmapEnabled = function() bigmapToggles = bigmapToggles + 1 end
SetMinimapClipType = function() end
exports = function() end
local threads = {}
CreateThread = function(fn) threads[#threads + 1] = coroutine.create(fn) end
Wait = function() coroutine.yield() end

dofile('config.lua')
dofile('prefs.lua')
dofile('route.lua')
dofile('minimap.lua')
dofile('location.lua')
dofile('vehicle.lua')
dofile('logo.lua')
dofile('client.lua')

local function eq(a, b, msg)
	if a ~= b then error(('%s: esperado %s, obtido %s'):format(msg, tostring(b), tostring(a))) end
end

-- sanitize
local p = Prefs.sanitize({ accent = 'x', style = 'flat', scale = 500, showMinimap = 'no', icons = 'hex' })
eq(p.accent, 'theme', 'accent invalido volta ao padrao')
eq(p.style, 'flat', 'estilo valido mantido')
eq(p.scale, 130, 'escala limitada')
eq(p.showMinimap, true, 'booleano invalido volta ao padrao')
eq(Prefs.sanitize(nil).unit, 'kmh', 'nil usa padrao')
eq(Prefs.sanitize({ tint = 'x' }).tint, 'status', 'tint invalido volta ao padrao')
eq(Prefs.sanitize(nil).showPercent, false, 'porcentagem oculta por padrao')
eq(Prefs.sanitize(nil).speedo, 'panel', 'velocimetro padrao e o painel')
eq(Prefs.sanitize({ speedo = 'analog' }).speedo, 'analog', 'velocimetro valido e mantido')
eq(Prefs.sanitize({ speedo = 'x' }).speedo, 'panel', 'velocimetro invalido volta ao padrao')

-- a thread principal envia estado e so reenvia quando muda
local mainThread = threads[#threads]
local function tick()
	local ok, err = coroutine.resume(mainThread)
	if not ok then error(err) end
end
tick()
local function states()
	local n = 0
	for _, m in ipairs(messages) do if m.action == 'state' then n = n + 1 end end
	return n
end
eq(states(), 1, 'primeiro estado enviado')
tick()
eq(states(), 1, 'estado igual nao reenvia')
natives.health = 150
tick()
eq(states(), 2, 'mudanca reenvia')
eq(messages[#messages].state.health, 50, 'vida em porcentagem')
eq(messages[#messages].state.dir, 'O', 'bussola: heading 90 e oeste')
eq(messages[#messages].state.street, 'Vinewood Blvd', 'rua no estado')
eq(messages[#messages].state.zone, 'Vinewood', 'regiao no estado')
eq(messages[#messages].state.clock, '09:05', 'hora no estado')
eq(Location.Direction(0), 'N', 'norte')
eq(Location.Direction(270), 'L', 'heading 270 e leste')

local minimap
for _, m in ipairs(messages) do if m.action == 'minimap' then minimap = m.anchor end end
eq(minimap.l, 0.025, 'margem da safezone')
eq(minimap.r > minimap.l and minimap.b > minimap.t, true, 'retangulo do minimapa valido')
eq(Location.hideNative, true, 'nativos ocultos por padrao')

natives.vehicle = 7
natives.speed = 10
tick()
local s = messages[#messages].state
eq(s.vehicle, true, 'motorista em veiculo')
eq(s.kind, 'bike', 'classe moto')
eq(s.speed, 36, 'km/h')

-- cinto, farol e setas
eq(keymaps.coe_hud_belt, 'B', 'cinto em B')
eq(keymaps.coe_hud_lights, 'H', 'farol em H')
eq(keymaps.coe_hud_left, 'LEFT', 'seta esquerda')
commands.coe_hud_belt()
commands.coe_hud_lights()
commands.coe_hud_left()
tick()
s = messages[#messages].state
eq(s.belt, true, 'cinto afivelado')
eq(flags[32], false, 'ejecao pelo parabrisa desligada')
eq(s.lights, 1, 'farol baixo')
eq(s.left, true, 'seta esquerda ligada')
commands.coe_hud_right()
tick()
s = messages[#messages].state
eq(s.left, false, 'seta esquerda desliga ao ligar a direita')
eq(s.right, true, 'seta direita ligada')

handlers['coe_needs:changed']({ hunger = 40, thirst = 30, stress = 5 })
tick()
eq(messages[#messages].state.thirst, 30, 'necessidades no estado do HUD')

natives.seatDriver = false
tick()
eq(messages[#messages].state.vehicle, false, 'passageiro nao ve painel')
eq(flags[32], true, 'cinto zerado ao deixar de dirigir')

-- /hud abre o modo de edicao; pre-visualizacao nao salva; concluir salva; descartar volta
local function lastOf(action)
	for i = #messages, 1, -1 do
		if messages[i].action == action then return messages[i] end
	end
end
commands.hud()
eq(focus, true, 'foco ao abrir o editor')
local opened = lastOf('editor')
eq(opened.open, true, 'editor aberto no NUI')
eq(opened.defaults.layout.status.size, 100, 'padroes enviados ao editor')
eq(opened.defaults.layout.status.x, nil, 'padrao ancorado')
callbacks.hudSave({ accent = 'cyan', unit = 'mph' }, function() end)
eq(kvp['coe_hud:prefs'].accent, 'cyan', 'preferencia persistida')
eq(radar, true, 'minimapa por padrao')
callbacks.hudSave({ showMinimap = false }, function() end)
eq(radar, false, 'minimapa oculto')

callbacks.hudSave({ showMinimap = true }, function() end)
local saved = kvp['coe_hud:prefs']
local reply
callbacks.hudPreview({ showMinimap = false, layout = { status = { x = 0.5, y = 0.4, size = 140 } } }, function(r) reply = r end)
eq(reply.ok, true, 'pre-visualizacao aceita no editor')
eq(radar, false, 'pre-visualizacao aplica o minimapa')
eq(kvp['coe_hud:prefs'], saved, 'pre-visualizacao nao grava KVP')
eq(lastOf('prefs').prefs.layout.status.size, 140, 'layout em pre-visualizacao no NUI')
callbacks.hudDiscard({}, function() end)
eq(focus, false, 'descartar libera o foco')
eq(radar, true, 'descartar volta ao minimapa salvo')
eq(lastOf('prefs').prefs.layout.status.x, nil, 'descartar volta ao layout salvo')
callbacks.hudPreview({ showMinimap = false }, function(r) reply = r end)
eq(reply.ok, false, 'pre-visualizacao fora do editor e ignorada')
eq(radar, true, 'pre-visualizacao ignorada nao altera o radar')

commands.hud()
callbacks.hudDone({ layout = { location = { x = 0.1, y = 0.2, size = 90 } } }, function() end)
eq(focus, false, 'concluir fecha o editor')
eq(kvp['coe_hud:prefs'].layout.location.x, 0.1, 'concluir grava o layout')
eq(kvp['coe_hud:prefs'].layout.location.size, 90, 'concluir grava o tamanho')
commands.hud()
commands.hud()
eq(focus, false, '/hud de novo fecha o editor (descarta)')

-- minimapa: mover e redimensionar reposiciona o radar nativo e os componentes ancorados
local toggles = bigmapToggles
callbacks.hudSave({ layout = { minimap = { x = 0.4, y = 0.5, size = 150 } } }, function() end)
for _, t in ipairs(threads) do if t ~= mainThread and coroutine.status(t) == 'suspended' then coroutine.resume(t); coroutine.resume(t) end end
eq(components.minimap.alignX, 'L', 'radar alinhado a esquerda')
eq(components.minimap.w, 0.225, 'radar escalado 150%')
eq(bigmapToggles > toggles, true, 'bigmap alternado para o radar reler as posicoes')
local moved = lastOf('minimap')
eq(moved.anchor.l, 0.4, 'ancora segue o minimapa movido')
eq(moved.anchor.t, 0.5, 'topo da ancora segue o minimapa')
eq(moved.base.l, 0.025, 'retangulo padrao enviado para as zonas de ancora')
handlers['coe_map:changed']('extended', 1.9)
local wide = lastOf('minimap')
eq(wide.extended, true, 'estendido avisado')
eq(wide.anchor.l, 0.4, 'estendido abre a partir do canto do minimapa movido')
eq(wide.anchor.b, moved.anchor.b, 'estendido mantem a base')
handlers['coe_map:changed']('mini', 1.0)
callbacks.hudSave({}, function() end)
eq(components.minimap.x, -0.0045, 'restaurar padrao devolve o radar ao lugar do GTA')
eq(lastOf('minimap').anchor.l, 0.025, 'ancora volta ao padrao')

-- ultrawide: area 16:9 numa tela 21:9 leva o radar e a ancora para dentro da area
screenAspect = 21 / 9
callbacks.hudSave({ aspect = '16:9' }, function() end)
for _, t in ipairs(threads) do if t ~= mainThread and coroutine.status(t) == 'suspended' then coroutine.resume(t); coroutine.resume(t) end end
eq(lastOf('minimap').anchor.l, 0.1441, 'ancora do minimapa dentro da area 16:9')
eq(lastOf('minimap').base.l, 0.025, 'retangulo padrao do GTA enviado ao NUI')
eq(components.minimap.x, 0.1518, 'radar nativo deslocado para a area')
callbacks.hudSave({ aspect = 'full' }, function() end)
eq(lastOf('minimap').anchor.l, 0.025, 'tela inteira volta ao canto')
screenAspect = 16 / 9
callbacks.hudSave({}, function() end)

-- outros recursos escondem o HUD por motivo (selecao de personagem, criador)
local function lastVisible()
	for i = #messages, 1, -1 do
		if messages[i].action == 'visible' then return messages[i].visible end
	end
end
callbacks.hudSave({ showMinimap = true }, function() end)
handlers['coe_hud:setHidden']('coe_characters', true)
eq(lastVisible(), false, 'HUD escondido pela selecao')
eq(radar, false, 'minimapa escondido junto')
handlers['coe_hud:setHidden']('coe_appearance', true)
handlers['coe_hud:setHidden']('coe_characters', false)
eq(lastVisible(), false, 'segue escondido enquanto restar um motivo')
callbacks.hudSave({ accent = 'lime' }, function() end)
eq(radar, false, 'salvar preferencias nao reexibe o minimapa escondido')
handlers['onResourceStop']('coe_appearance')
eq(lastVisible(), true, 'motivo liberado quando o recurso para')
eq(radar, true, 'minimapa volta conforme a preferencia')

-- minimapa e bussola so em veiculos
natives.vehicle = 0
callbacks.hudSave({ minimapMode = 'vehicle', locationMode = 'vehicle' }, function() end)
tick()
eq(radar, false, 'a pe o minimapa some no modo veiculo')
eq(messages[#messages].state.dir, nil, 'a pe a bussola some no modo veiculo')
eq(messages[#messages].state.inVehicle, false, 'estado informa que esta a pe')
natives.vehicle = 7
natives.seatDriver = false
tick()
eq(radar, true, 'passageiro ve o minimapa')
eq(messages[#messages].state.dir, 'O', 'passageiro ve a bussola')
eq(messages[#messages].state.inVehicle, true, 'estado informa o veiculo')
natives.vehicle = 0
tick()
eq(radar, false, 'descer do veiculo esconde o minimapa')
commands.hud()
eq(radar, true, 'editor mostra o minimapa a pe para posicionar')
tick()
eq(messages[#messages].state.dir ~= nil, true, 'editor mostra a bussola a pe')
callbacks.hudDiscard({}, function() end)
tick()
eq(radar, false, 'fechar o editor volta ao modo veiculo')
callbacks.hudSave({ minimapMode = 'always', locationMode = 'always' }, function() end)
eq(radar, true, 'modo sempre mostra a pe')

-- Testes do comando e visibilidade do logotipo
eq(Logo.IsVisible(), true, 'logo visivel por padrao no client')
commands.logo()
eq(Logo.IsVisible(), false, 'comando /logo desativa visibilidade')
commands.logo()
eq(Logo.IsVisible(), true, 'comando /logo ativa visibilidade novamente')

print('coe_hud tests passed')
