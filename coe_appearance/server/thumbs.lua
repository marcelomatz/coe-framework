-- Gerador das fotos de roupa (lado servidor): o comando abre uma sessão para quem tem a ACE, o cliente fotografa cada
-- peça (screenshot-basic), recorta na NUI e manda o webp aqui; o servidor confere nome e conteúdo e salva em thumbs/.
-- Os jogadores recebem as fotos novas depois de reiniciar o recurso (arquivos listados no fxmanifest).
local S = AppearanceSchema
local cfg = AppearanceConfig.Thumbnails
local resource = GetCurrentResourceName()
local sessions = {} -- [source] = { saved, rejected, startedAt }

local B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local decodeMap = {}
for index = 1, #B64 do
	decodeMap[B64:byte(index)] = index - 1
end

-- Base64 -> bytes. Devolve nil se houver caractere inválido.
local function decodeBase64(text)
	text = text:gsub('%s', '')
	if #text % 4 ~= 0 then
		return nil
	end
	local out, count = {}, 0
	for index = 1, #text, 4 do
		local a, b, c, d = text:byte(index, index + 3)
		local va, vb = decodeMap[a], decodeMap[b]
		local vc = c == 61 and 0 or decodeMap[c]
		local vd = d == 61 and 0 or decodeMap[d]
		if not va or not vb or not vc or not vd then
			return nil
		end
		local n = va * 262144 + vb * 4096 + vc * 64 + vd
		count = count + 1
		if c == 61 then
			out[count] = string.char(n >> 16)
		elseif d == 61 then
			out[count] = string.char(n >> 16, (n >> 8) & 255)
		else
			out[count] = string.char(n >> 16, (n >> 8) & 255, n & 255)
		end
	end
	return table.concat(out)
end

ThumbsServer = { decodeBase64 = decodeBase64, sessions = sessions }

local function reply(source, text, kind)
	if source == 0 then
		print(('[coe_appearance] %s'):format(text))
	else
		local message = 'Aparência: ' .. text
		pcall(function()
			exports.coe_notify:Notify(source, kind or 'info', message:sub(1, 240), 8000)
		end)
	end
end

RegisterCommand(cfg.Command, function(source, args)
	if source == 0 then
		reply(0, 'use o comando dentro do jogo.')
		return
	end
	if not IsPlayerAceAllowed(tostring(source), cfg.Ace) then
		reply(source, 'sem permissão para gerar as fotos de roupa.', 'error')
		return
	end
	if GetResourceState('screenshot-basic') ~= 'started' then
		reply(source, 'o recurso screenshot-basic precisa estar iniciado.', 'error')
		return
	end
	if sessions[source] then
		-- Repetir o comando cancela a sessão em andamento.
		TriggerClientEvent('coe_appearance:thumbsStop', source)
		return
	end
	local genders = { 'male', 'female' }
	local redo = false
	for _, arg in ipairs(args) do
		if arg == 'male' or arg == 'female' then
			genders = { arg }
		elseif arg == 'refazer' then
			redo = true
		end
	end
	sessions[source] = { saved = 0, rejected = 0, startedAt = os.time() }
	TriggerClientEvent('coe_appearance:thumbsStart', source, { genders = genders, redo = redo })
end, false)

-- Conferência pura (testada): nome válido e data URL webp dentro do limite. Devolve os bytes ou nil, motivo.
function ThumbsServer.validate(name, data)
	if not S.ParseThumbName(name, cfg.Extension) then
		return nil, 'invalid_name'
	end
	local prefix = ('data:image/%s;base64,'):format(cfg.Extension)
	if type(data) ~= 'string' or data:sub(1, #prefix) ~= prefix or #data > cfg.MaxBytes * 4 / 3 + #prefix + 4 then
		return nil, 'invalid_data'
	end
	local bytes = decodeBase64(data:sub(#prefix + 1))
	if not bytes or #bytes == 0 or #bytes > cfg.MaxBytes then
		return nil, 'invalid_data'
	end
	-- Assinatura RIFF....WEBP
	if cfg.Extension == 'webp' and (bytes:sub(1, 4) ~= 'RIFF' or bytes:sub(9, 12) ~= 'WEBP') then
		return nil, 'invalid_data'
	end
	return bytes
end

RegisterNetEvent('coe_appearance:thumbSave', function(name, data)
	local source = source
	local session = sessions[source]
	if not session then
		return
	end
	local bytes = ThumbsServer.validate(name, data)
	if not bytes or not SaveResourceFile(resource, 'thumbs/' .. name, bytes, #bytes) then
		session.rejected = session.rejected + 1
		return
	end
	session.saved = session.saved + 1
end)

RegisterNetEvent('coe_appearance:thumbsDone', function(cancelled)
	local source = source
	local session = sessions[source]
	if not session or session.closing then
		return
	end
	-- Fotos ainda em trânsito (eventos latentes) chegam nos próximos instantes.
	session.closing = true
	Wait(3000)
	sessions[source] = nil
	local text = ('fotos de roupa %s: %d salvas, %d recusadas em %d s. Reinicie o coe_appearance para os jogadores receberem.')
		:format(cancelled and 'interrompidas' or 'concluídas', session.saved, session.rejected, os.time() - session.startedAt)
	reply(source, text, cancelled and 'warning' or 'success')
	print(('[coe_appearance] %s (%s)'):format(text, GetPlayerName(source) or source))
end)

AddEventHandler('playerDropped', function()
	sessions[source] = nil
end)
