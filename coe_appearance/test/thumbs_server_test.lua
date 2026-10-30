-- Gerador de fotos (servidor): base64, conferência de nome/conteúdo, permissão e sessão.
local commands, events, saved, clientEvents, notices = {}, {}, {}, {}, {}
local aces = { ['7'] = true }
RegisterCommand = function(name, fn) commands[name] = fn end
RegisterNetEvent = function(name, fn) events[name] = fn end
AddEventHandler = function(name, fn) events[name] = fn end
GetCurrentResourceName = function() return 'coe_appearance' end
GetResourceState = function() return 'started' end
IsPlayerAceAllowed = function(player, ace) return ace == 'coe_appearance.thumbs' and aces[player] == true end
TriggerClientEvent = function(name, target, payload) clientEvents[#clientEvents + 1] = { name = name, target = target, payload = payload } end
SaveResourceFile = function(_, path, data, length) saved[path] = { data = data, length = length }; return true end
GetPlayerName = function() return 'Admin' end
Wait = function() end
exports = setmetatable({}, { __index = function(_, res)
	if res == 'coe_notify' then
		return { Notify = function(_, target, kind, message) notices[#notices + 1] = { target = target, kind = kind, message = message } end }
	end
end })

dofile('config.lua')
dofile('shared/schema.lua')
dofile('server/thumbs.lua')

local failures = 0
local function eq(actual, expected, message)
	if actual ~= expected then
		failures = failures + 1
		print(('FAIL %s: esperado %s, obtido %s'):format(message, tostring(expected), tostring(actual)))
	end
end

local decode = ThumbsServer.decodeBase64
eq(decode('TWFu'), 'Man', 'base64 sem padding')
eq(decode('TWE='), 'Ma', 'base64 com um =')
eq(decode('TQ=='), 'M', 'base64 com dois =')
eq(decode('TW*u'), nil, 'caractere inválido')
eq(decode('TWF'), nil, 'tamanho inválido')

-- webp mínimo: RIFF....WEBP
local webp = 'RIFF\0\0\0\0WEBPVP8 '
local B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function encode(data)
	return ((data:gsub('.', function(x)
		local r, b = '', x:byte()
		for i = 8, 1, -1 do r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and '1' or '0') end
		return r
	end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
		if #x < 6 then return '' end
		local c = 0
		for i = 1, 6 do c = c + (x:sub(i, i) == '1' and 2 ^ (6 - i) or 0) end
		return B64:sub(c + 1, c + 1)
	end) .. ({ '', '==', '=' })[#data % 3 + 1])
end
local url = 'data:image/webp;base64,' .. encode(webp)
eq(ThumbsServer.validate('male_c11_3.webp', url), webp, 'foto válida')
eq(select(2, ThumbsServer.validate('../x.webp', url)), 'invalid_name', 'nome inválido')
eq(select(2, ThumbsServer.validate('male_c11_3.webp', 'data:image/png;base64,' .. encode(webp))), 'invalid_data', 'tipo errado')
eq(select(2, ThumbsServer.validate('male_c11_3.webp', 'data:image/webp;base64,' .. encode('nada aqui'))), 'invalid_data', 'sem assinatura webp')

-- Sem sessão, o envio é ignorado
events['coe_appearance:thumbSave']('male_c11_3.webp', url)
eq(saved['thumbs/male_c11_3.webp'], nil, 'sem sessão não salva')

-- Sem permissão não abre sessão
commands.coe_fotos_roupas(8, {})
eq(#clientEvents, 0, 'recusa não abre sessão')
eq(#notices, 1, 'só a mensagem de recusa')
eq(notices[1].kind, 'error', 'recusa avisada pelo coe_notify')

-- Com permissão: abre a sessão, salva e encerra
commands.coe_fotos_roupas(7, { 'female', 'refazer' })
local start = clientEvents[#clientEvents]
eq(start.name, 'coe_appearance:thumbsStart', 'sessão iniciada')
eq(start.payload.genders[1], 'female', 'gênero escolhido')
eq(start.payload.redo, true, 'refazer')
source = 7
events['coe_appearance:thumbSave']('female_p0_1.webp', url)
eq(saved['thumbs/female_p0_1.webp'].length, #webp, 'foto salva')
events['coe_appearance:thumbSave']('female_c2_1.webp', url)
eq(saved['thumbs/female_c2_1.webp'], nil, 'peça fora do catálogo recusada')
events['coe_appearance:thumbsDone'](false)
eq(ThumbsServer.sessions[7], nil, 'sessão encerrada')
eq(notices[#notices].message:match('1 salvas, 1 recusadas') ~= nil, true, 'resumo enviado pelo coe_notify')

if failures > 0 then
	error(('thumbs_server_test: %d falha(s)'):format(failures))
end
print('thumbs_server_test: ok')
