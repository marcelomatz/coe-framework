-- Fotos do Insta: o tablet reduz a foto, o cliente envia por evento latente e o servidor guarda até a publicação.
-- Na publicação a foto vai para o host: banco (padrão, `media:<id>`) ou HTTP configurado por convar (URL pública).
AppsPhotos = {}

local config = CoeAppsConfig.Photos
local pending = {}
local lastUpload = {}

local function token()
	local chars = {}
	for index = 1, 24 do
		local value = math.random(0, 35)
		chars[index] = string.char(value < 10 and 48 + value or 87 + value)
	end
	return table.concat(chars)
end

function AppsPhotos.Accept(playerId, characterId, data)
	local now = os.time()
	if lastUpload[playerId] and now - lastUpload[playerId] < config.UploadCooldownSeconds then
		return nil, 'upload_cooldown'
	end
	local body, errorCode = AppsRules.Photo(CoeAppsConfig, data)
	if not body then
		return nil, errorCode
	end
	lastUpload[playerId] = now
	local key = token()
	pending[playerId] = { token = key, characterId = characterId, body = body, expires = now + config.PendingSeconds }
	return key
end

-- Devolve a foto pendente (base64) se o token e o personagem conferem; ela é consumida.
function AppsPhotos.Take(playerId, characterId, key)
	local entry = pending[playerId]
	if not entry or type(key) ~= 'string' or entry.token ~= key or entry.characterId ~= characterId or entry.expires < os.time() then
		return nil
	end
	pending[playerId] = nil
	return entry.body
end

function AppsPhotos.Restore(playerId, characterId, key, body)
	pending[playerId] = { token = key, characterId = characterId, body = body, expires = os.time() + config.PendingSeconds }
end

function AppsPhotos.Forget(playerId)
	pending[playerId] = nil
	lastUpload[playerId] = nil
end

local function uploadUrl()
	return (GetConvar(config.UrlConvar, ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

function AppsPhotos.Provider()
	return uploadUrl() ~= '' and 'http' or 'database'
end

local function uploadHttp(url, body)
	local form = config.Field .. '=' .. AppsRules.UrlEncode(body)
	local key = GetConvar(config.KeyConvar, '')
	if key ~= '' then
		form = form .. '&' .. config.KeyField .. '=' .. AppsRules.UrlEncode(key)
	end
	local response = promise.new()
	PerformHttpRequest(url, function(status, text)
		response:resolve({ status = status, text = text })
	end, 'POST', form, { ['Content-Type'] = 'application/x-www-form-urlencoded' })
	local result = Citizen.Await(response)
	if type(result.status) ~= 'number' or result.status < 200 or result.status >= 300 or type(result.text) ~= 'string' then
		return nil, 'upload_failed'
	end
	local ok, decoded = pcall(json.decode, result.text)
	local link = ok and AppsRules.PhotoUrl(AppsRules.Path(decoded, config.ResponsePath)) or nil
	if not link then
		return nil, 'upload_failed'
	end
	return link
end

-- Guarda a foto no host e devolve a referência gravada no post.
function AppsPhotos.Store(characterId, body)
	local url = uploadUrl()
	if url ~= '' then
		return uploadHttp(url, body)
	end
	local id, errorCode = AppsPersistence.InsertMedia(characterId, 'data:image/jpeg;base64,' .. body)
	if not id then
		return nil, errorCode
	end
	return 'media:' .. id
end

-- Apaga a foto guardada no banco (fotos em host externo ficam lá).
function AppsPhotos.Delete(image)
	local id = type(image) == 'string' and tonumber(image:match('^media:(%d+)$'))
	if id then
		AppsPersistence.DeleteMedia(id)
	end
end
