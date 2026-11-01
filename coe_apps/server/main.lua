local config = CoeAppsConfig
local DAY = 86400

local ready = false
local installedCache = {}
local ads = {}
local lastPost = {}

-- Aparelhos que podem pedir apps (o smartphone entra aqui quando existir).
local HOSTS = { coe_tablet = 'tablet', coe_phone = 'phone' }

local function log(level, category, event, context)
	pcall(function()
		return exports.coe_logging:Log(level, category, event, context)
	end)
end

local function audit(event, context)
	pcall(function()
		return exports.coe_audit:Record('info', 'audit', event, context)
	end)
end

local playerCharacter = {}

local function characterOf(playerId)
	local snapshot = Core.Players.GetActiveCharacter(playerId)
	if type(snapshot) ~= 'table' or not snapshot.characterId then
		return nil
	end
	playerCharacter[playerId] = tostring(snapshot.characterId)
	local name = (((snapshot.firstName or '') .. ' ' .. (snapshot.lastName or '')):gsub('^%s+', ''):gsub('%s+$', ''))
	return { id = tostring(snapshot.characterId), name = name ~= '' and name:sub(1, 64) or 'Cidadão', stateId = tostring(snapshot.stateId or '') }
end

local function isModerator(playerId)
	return IsPlayerAceAllowed(playerId, config.ModerateAce)
end

local function installedOf(characterId)
	local cached = installedCache[characterId]
	if cached then
		return cached
	end
	local map = AppsPersistence.Installed(characterId)
	if not map then
		return nil
	end
	installedCache[characterId] = map
	return map
end

local function notify(playerId, kind, message)
	pcall(function()
		exports.coe_notify:Notify(playerId, kind, message)
	end)
end

local function playerOf(characterId)
	for playerId, id in pairs(playerCharacter) do
		if id == characterId then
			return playerId
		end
	end
	return nil
end

-- device (opcional): o app também precisa rodar nesse aparelho (devices).
local function hasApp(characterId, appId, device)
	local app = config.Store[appId]
	if not app then
		return false
	end
	if device and (type(app.devices) ~= 'table' or app.devices[device] ~= true) then
		return false
	end
	if app.builtin then
		return true
	end
	local map = installedOf(characterId)
	return map ~= nil and AppsRules.Active(config, appId, map[appId], os.time())
end

-- Assinaturas no cartão de crédito ------------------------------------------------------------------

local PERIOD = config.Subscriptions.PeriodDays * DAY
-- Recusas definitivas do banco: a assinatura vencida cai; o resto (banco fora, trava) tenta de novo depois.
local DECLINED = { no_credit = true, no_card = true, credit_late = true, credit_limit = true, card_blocked = true, card_expired = true }
local locks = {}

local function withLock(characterId, run)
	if locks[characterId] then
		return { ok = false, error = 'busy' }
	end
	locks[characterId] = true
	local ok, result = pcall(run)
	locks[characterId] = nil
	if not ok then
		log('error', 'gameplay', 'apps_lock_failed', { error_code = tostring(result) })
		return { ok = false, error = 'database_error' }
	end
	return result
end

-- Cobra no crédito do cartão (coe_banking). Cartão ausente conta como recusa.
local function chargeCard(cardId, amount, description)
	if not cardId then
		return nil, 'no_card'
	end
	if GetResourceState('coe_banking') ~= 'started' then
		return nil, 'bank_unavailable'
	end
	local ok, result = pcall(function()
		return exports.coe_banking:CardPurchase(cardId, amount, description)
	end)
	if not ok or type(result) ~= 'table' then
		return nil, 'bank_unavailable'
	end
	if not result.ok then
		return nil, result.error or 'bank_unavailable'
	end
	return true
end

local function refundCard(cardId, amount, description)
	local ok, result = pcall(function()
		return exports.coe_banking:CardRefund(cardId, amount, description)
	end)
	if not ok or type(result) ~= 'table' or not result.ok then
		log('error', 'gameplay', 'app_refund_failed', { request_id = tostring(cardId), count = amount })
	end
end

local function subscriptionLabel(appId)
	return 'Assinatura ' .. (config.Store[appId] and config.Store[appId].label or appId)
end

-- Loja ----------------------------------------------------------------------------------------------

local Store = {}

function Store.list(_, character, _, device)
	local map = installedOf(character.id)
	if not map then
		return { ok = false, error = 'database_error' }
	end
	return { ok = true, apps = AppsRules.Catalog(config, device, map, os.time()) }
end

function Store.install(playerId, character, payload, device)
	return withLock(character.id, function()
		local map = installedOf(character.id)
		if not map then
			return { ok = false, error = 'database_error' }
		end
		local appId = payload.app
		local now = os.time()
		local record = map[appId]
		local price, errorCode = AppsRules.Install(config, appId, device, record, now)
		if not price then
			return { ok = false, error = errorCode }
		end
		local weekly = AppsRules.Price(config.Store[appId])
		local subscription = weekly > 0
		local paidUntil, cardId = nil, nil
		if subscription then
			-- Assinatura: paga com um cartão da Carteira do smartphone (autorização de uso único).
			if device ~= 'phone' or GetResourceState('coe_phone') ~= 'started' then
				return { ok = false, error = 'wallet_required' }
			end
			local consumed, outcome = pcall(function()
				return table.pack(exports.coe_phone:ConsumePayment(playerId, payload.payment, weekly))
			end)
			if not consumed or type(outcome) ~= 'table' then
				return { ok = false, error = 'wallet_required' }
			end
			cardId = math.tointeger(tonumber(outcome[1]))
			if not cardId then
				return { ok = false, error = outcome[2] or 'payment_expired' }
			end
		end
		if price > 0 then
			local charged, chargeError = chargeCard(cardId, price, subscriptionLabel(appId))
			if not charged then
				return { ok = false, error = chargeError }
			end
			paidUntil = AppsRules.NextPeriod(record and record.paidUntil, now, PERIOD)
		end
		if not AppsPersistence.SetInstalled(character.id, appId, true, price, paidUntil, subscription, cardId) then
			if price > 0 then
				refundCard(cardId, price, 'Estorno ' .. subscriptionLabel(appId))
			end
			return { ok = false, error = 'database_error' }
		end
		map[appId] = { installed = true, paidUntil = paidUntil or (record and record.paidUntil) or 0, autoRenew = subscription, cardId = cardId or (record and record.cardId) }
		if price > 0 then
			audit('app_subscribed', { source = playerId, character_id = character.id, operation = appId, count = price })
		end
		return { ok = true, price = price, paidUntil = subscription and map[appId].paidUntil or nil }
	end)
end

-- Remove o app; nos pagos também cancela a renovação. A semana paga continua valendo para reinstalar.
function Store.uninstall(playerId, character, payload)
	local appId = payload.app
	local app = type(appId) == 'string' and config.Store[appId]
	if not app or app.builtin then
		return { ok = false, error = 'unknown_app' }
	end
	return withLock(character.id, function()
		local map = installedOf(character.id)
		if not map or not map[appId] or not map[appId].installed then
			return { ok = false, error = 'not_installed' }
		end
		if not AppsPersistence.SetInstalled(character.id, appId, false, 0, nil, false) then
			return { ok = false, error = 'database_error' }
		end
		map[appId].installed = false
		map[appId].autoRenew = false
		if AppsRules.Price(app) > 0 then
			audit('app_subscription_cancelled', { source = playerId, character_id = character.id, operation = appId })
		end
		return { ok = true }
	end)
end

-- Renova uma assinatura que vence. Roda sob a trava do personagem.
local function renew(due, now)
	local app = config.Store[due.appId]
	local map = installedCache[due.characterId]
	local function apply(installed)
		if map and map[due.appId] then
			map[due.appId].installed = installed
			map[due.appId].autoRenew = false
		end
	end
	if not app or app.builtin then
		AppsPersistence.Expire(due.characterId, due.appId)
		return apply(false)
	end
	local price = AppsRules.Price(app)
	if price == 0 then
		AppsPersistence.StopRenewal(due.characterId, due.appId)
		return apply(true)
	end
	local label = subscriptionLabel(due.appId)
	local charged, errorCode = chargeCard(due.cardId, price, label)
	local playerId = playerOf(due.characterId)
	if not charged then
		if DECLINED[errorCode] and due.paidUntil <= now then
			if AppsPersistence.Expire(due.characterId, due.appId) then
				apply(false)
				audit('app_subscription_expired', { character_id = due.characterId, operation = due.appId, error_code = errorCode })
				if playerId then
					notify(playerId, 'error', ('%s: cobrança recusada no cartão de crédito. O app foi removido.'):format(app.label))
				end
			end
		end
		return
	end
	local paidUntil = AppsRules.NextPeriod(due.paidUntil, now, PERIOD)
	local renewed = AppsPersistence.Renew(due.characterId, due.appId, due.paidUntil, paidUntil, price)
	if not renewed then
		refundCard(due.cardId, price, 'Estorno ' .. label)
		return
	end
	if map and map[due.appId] then
		map[due.appId].paidUntil = paidUntil
	end
	audit('app_subscription_renewed', { character_id = due.characterId, operation = due.appId, count = price })
	if playerId then
		notify(playerId, 'info', ('%s: assinatura renovada no cartão de crédito.'):format(app.label))
	end
end

local function renewSubscriptions()
	local now = os.time()
	local list = AppsPersistence.DueSubscriptions(now + config.Subscriptions.RenewLeadSeconds, config.Subscriptions.BatchSize)
	for _, due in ipairs(list or {}) do
		if not locks[due.characterId] then
			withLock(due.characterId, function()
				return renew(due, now)
			end)
		end
	end
end
-- Empregos ------------------------------------------------------------------------------------------

local Jobs = {}

function Jobs.list(playerId)
	local ok, definitions = pcall(function()
		return exports.coe_core:GetGroupDefinitions()
	end)
	if not ok or type(definitions) ~= 'table' then
		return { ok = false, error = 'not_ready' }
	end
	local online = {}
	for _, player in ipairs(GetPlayers()) do
		local groupsOk, groups = pcall(function()
			return exports.coe_core:GetPlayerGroups(tonumber(player))
		end)
		local job = groupsOk and type(groups) == 'table' and groups.job
		if job and job.name then
			online[job.name] = (online[job.name] or 0) + 1
		end
	end
	local mineOk, mine = pcall(function()
		return exports.coe_core:GetPlayerGroups(playerId)
	end)
	local myJob = mineOk and type(mine) == 'table' and mine.job and mine.job.name or nil
	local list = {}
	for _, group in ipairs(definitions) do
		if group.type == 'job' then
			local info = config.Jobs[group.name] or {}
			local grades = {}
			for _, grade in ipairs(group.grades or {}) do
				grades[#grades + 1] = grade.label
			end
			list[#list + 1] = {
				id = group.name, label = group.label or group.name, description = info.description, place = info.place,
				x = info.x, y = info.y, grades = grades, online = online[group.name] or 0, mine = group.name == myJob
			}
		end
	end
	return { ok = true, jobs = list }
end

-- Classificados -------------------------------------------------------------------------------------

local Classifieds = {}

local function activeAds()
	local now, list = os.time(), {}
	for _, ad in ipairs(ads) do
		if ad.expiresAt > now then
			list[#list + 1] = ad
		end
	end
	return list
end

function Classifieds.list(playerId, character, payload)
	local category = payload.category
	local moderator = isModerator(playerId)
	local list, mine = {}, 0
	for _, ad in ipairs(activeAds()) do
		if ad.characterId == character.id then
			mine = mine + 1
		end
		if (category == nil or category == '' or ad.category == category) and #list < config.Classifieds.PageSize then
			list[#list + 1] = {
				id = ad.id, category = ad.category, categoryLabel = AppsRules.CategoryLabel(config, ad.category),
				title = ad.title, body = ad.body, price = ad.price, author = ad.author, contact = ad.contact,
				createdAt = ad.createdAt, expiresAt = ad.expiresAt, mine = ad.characterId == character.id,
				canRemove = ad.characterId == character.id or moderator
			}
		end
	end
	return {
		ok = true, ads = list, categories = config.Classifieds.Categories, fee = config.Classifieds.Fee,
		durationHours = config.Classifieds.DurationHours, maxActive = config.Classifieds.MaxActive, mine = mine,
		limits = { title = config.Classifieds.TitleMax, body = config.Classifieds.BodyMax }
	}
end

function Classifieds.post(playerId, character, payload)
	local ad, errorCode = AppsRules.Ad(config, payload)
	if not ad then
		return { ok = false, error = errorCode }
	end
	local count = 0
	for _, existing in ipairs(activeAds()) do
		if existing.characterId == character.id then
			count = count + 1
		end
	end
	if count >= config.Classifieds.MaxActive then
		return { ok = false, error = 'ad_limit' }
	end
	local fee = config.Classifieds.Fee
	if fee > 0 then
		local paid, payError = debit(character.id, fee, 'classified_fee', 'classifieds')
		if not paid then
			return { ok = false, error = payError }
		end
	end
	local now = os.time()
	ad.characterId, ad.author, ad.contact = character.id, character.name, character.stateId
	ad.createdAt, ad.expiresAt = now, now + config.Classifieds.DurationHours * 3600
	local id = AppsPersistence.InsertAd(ad)
	if not id then
		if fee > 0 then
			refund(character.id, fee, 'classified_refund', 'classifieds')
		end
		return { ok = false, error = 'database_error' }
	end
	ad.id = id
	table.insert(ads, 1, ad)
	log('info', 'gameplay', 'classified_posted', { source = playerId, operation = ad.category })
	return { ok = true }
end

function Classifieds.remove(playerId, character, payload)
	local id = tonumber(payload.id)
	for index, ad in ipairs(ads) do
		if ad.id == id then
			local moderator = ad.characterId ~= character.id and isModerator(playerId)
			if ad.characterId ~= character.id and not moderator then
				return { ok = false, error = 'forbidden' }
			end
			if not AppsPersistence.DeleteAd(id) then
				return { ok = false, error = 'database_error' }
			end
			table.remove(ads, index)
			if moderator then
				audit('classified_removed', { source = playerId, operation = tostring(id), target = ad.characterId })
			end
			return { ok = true }
		end
	end
	return { ok = false, error = 'not_found' }
end

-- Insta ---------------------------------------------------------------------------------------------

local Insta = {}

function Insta.feed(playerId, character, payload)
	local before = tonumber(payload.before)
	if not before or before < 1 or before % 1 ~= 0 then
		before = math.maxinteger
	end
	local author = payload.mine == true and character.id or nil
	local list = AppsPersistence.Feed(character.id, before, config.Insta.PageSize, author)
	if not list then
		return { ok = false, error = 'database_error' }
	end
	local moderator = isModerator(playerId)
	for _, post in ipairs(list) do
		post.mine = post.characterId == character.id
		post.canRemove = post.mine or moderator
		post.characterId = nil
	end
	return {
		ok = true, posts = list, more = #list == config.Insta.PageSize,
		photo = { width = config.Photos.Width, quality = config.Photos.Quality, maxBytes = config.Photos.MaxBytes },
		captionMax = config.Insta.CaptionMax, me = AppsRules.Handle(character.name)
	}
end

function Insta.media(_, _, payload)
	local id = tonumber(payload.id)
	if not id or id < 1 or id % 1 ~= 0 then
		return { ok = false, error = 'not_found' }
	end
	local data = AppsPersistence.Media(id)
	if type(data) ~= 'string' then
		return { ok = false, error = 'not_found' }
	end
	return { ok = true, data = data }
end

function Insta.publish(playerId, character, payload)
	local now = os.time()
	if lastPost[character.id] and now - lastPost[character.id] < config.Insta.PostCooldownSeconds then
		return { ok = false, error = 'post_cooldown' }
	end
	local body = AppsPhotos.Take(playerId, character.id, payload.token)
	if not body then
		return { ok = false, error = 'photo_expired' }
	end
	local image, storeError = AppsPhotos.Store(character.id, body)
	if not image then
		AppsPhotos.Restore(playerId, character.id, payload.token, body)
		return { ok = false, error = storeError == 'upload_failed' and 'upload_failed' or 'database_error' }
	end
	local id = AppsPersistence.InsertPost({
		characterId = character.id, author = character.name, handle = AppsRules.Handle(character.name),
		caption = AppsRules.Caption(config, payload.caption), image = image, createdAt = now
	})
	if not id then
		AppsPhotos.Delete(image)
		AppsPhotos.Restore(playerId, character.id, payload.token, body)
		return { ok = false, error = 'database_error' }
	end
	lastPost[character.id] = now
	log('info', 'gameplay', 'insta_posted', { source = playerId, operation = AppsPhotos.Provider() })
	return { ok = true, id = id }
end

function Insta.like(_, character, payload)
	local id = tonumber(payload.id)
	if not id or id < 1 or id % 1 ~= 0 then
		return { ok = false, error = 'not_found' }
	end
	local post = AppsPersistence.Post(id)
	if not post then
		return { ok = false, error = post == false and 'not_found' or 'database_error' }
	end
	local liked, total = AppsPersistence.ToggleLike(id, character.id)
	if liked == nil then
		return { ok = false, error = 'database_error' }
	end
	return { ok = true, liked = liked, likes = total }
end

function Insta.remove(playerId, character, payload)
	local id = tonumber(payload.id)
	local post = id and AppsPersistence.Post(id)
	if not post then
		return { ok = false, error = post == false and 'not_found' or 'database_error' }
	end
	local moderator = post.characterId ~= character.id and isModerator(playerId)
	if post.characterId ~= character.id and not moderator then
		return { ok = false, error = 'forbidden' }
	end
	if not AppsPersistence.DeletePost(id) then
		return { ok = false, error = 'database_error' }
	end
	AppsPhotos.Delete(post.image)
	if moderator then
		audit('insta_post_removed', { source = playerId, operation = tostring(id), target = post.characterId })
	end
	return { ok = true }
end

local HANDLERS = { store = Store, jobs = Jobs, classifieds = Classifieds, insta = Insta }

-- Exports para o tablet (e o smartphone) ------------------------------------------------------------

exports('TabletVisible', function(playerId, appId)
	local device = HOSTS[GetInvokingResource()]
	if not device or not ready then
		return false
	end
	local character = characterOf(playerId)
	return character ~= nil and type(appId) == 'string' and hasApp(character.id, appId, device)
end)

exports('TabletCall', function(playerId, appId, action, payload)
	local device = HOSTS[GetInvokingResource()]
	if not device then
		return { ok = false, error = 'forbidden' }
	end
	if not ready then
		return { ok = false, error = 'not_ready' }
	end
	local character = characterOf(playerId)
	if not character then
		return { ok = false, error = 'no_character' }
	end
	local handlers = HANDLERS[appId]
	local handler = handlers and type(action) == 'string' and rawget(handlers, action)
	if type(handler) ~= 'function' then
		return { ok = false, error = 'unknown_action' }
	end
	if not hasApp(character.id, appId, device) then
		return { ok = false, error = 'not_installed' }
	end
	return handler(playerId, character, type(payload) == 'table' and payload or {}, device)
end)

-- Outros resources com apps na loja (ex.: coe_amzg) conferem se o personagem instalou o app no aparelho.
exports('HasApp', function(playerId, appId, device)
	if not ready or type(appId) ~= 'string' or (device ~= 'tablet' and device ~= 'phone') then
		return false
	end
	local character = characterOf(playerId)
	return character ~= nil and hasApp(character.id, appId, device)
end)

-- Fotos para outros resources (Photos.Callers, ex.: capa de matéria do coe_news). Valor único: tabela com ok/erro.
local function photoCaller()
	return config.Photos.Callers[GetInvokingResource() or ''] == true
end

-- Guarda a foto enviada pelo aparelho (token do upload) e devolve { ok, image } (`media:<id>` ou URL https).
exports('ClaimPhoto', function(playerId, token)
	if not photoCaller() then
		return { ok = false, error = 'forbidden' }
	end
	local character = ready and characterOf(playerId)
	if not character then
		return { ok = false, error = 'not_ready' }
	end
	local body = AppsPhotos.Take(playerId, character.id, token)
	if not body then
		return { ok = false, error = 'photo_expired' }
	end
	local image, storeError = AppsPhotos.Store(character.id, body)
	if not image then
		AppsPhotos.Restore(playerId, character.id, token, body)
		return { ok = false, error = storeError == 'upload_failed' and 'upload_failed' or 'database_error' }
	end
	return { ok = true, image = image }
end)

-- Conteúdo de uma foto guardada no banco (`media:<id>`).
exports('PhotoData', function(id)
	id = math.tointeger(tonumber(id))
	if not photoCaller() or not ready or not id or id < 1 then
		return nil
	end
	local data = AppsPersistence.Media(id)
	return type(data) == 'string' and data or nil
end)

exports('DeletePhoto', function(image)
	if photoCaller() and ready then
		AppsPhotos.Delete(image)
	end
end)

-- Foto tirada no aparelho: chega por evento latente e fica pendente até a publicação.
RegisterNetEvent('coe_apps:photo', function(requestId, data)
	local playerId = source
	if type(requestId) ~= 'number' or requestId % 1 ~= 0 then
		return
	end
	local function reply(result)
		TriggerClientEvent('coe_apps:photoResult', playerId, requestId, result)
	end
	local character = ready and characterOf(playerId)
	if not character then
		return reply({ ok = false, error = 'not_ready' })
	end
	local allowed = false
	for _, appId in ipairs(config.Photos.Apps) do
		if hasApp(character.id, appId) then
			allowed = true
			break
		end
	end
	if not allowed then
		return reply({ ok = false, error = 'not_installed' })
	end
	local key, errorCode = AppsPhotos.Accept(playerId, character.id, data)
	if not key then
		return reply({ ok = false, error = errorCode })
	end
	reply({ ok = true, token = key })
end)

AddEventHandler('playerDropped', function()
	local playerId = source
	AppsPhotos.Forget(playerId)
	if playerCharacter[playerId] then
		installedCache[playerCharacter[playerId]] = nil
		playerCharacter[playerId] = nil
	end
end)

CreateThread(function()
	math.randomseed(os.time() + GetGameTimer())
	local waitingLogged = false
	while true do
		local initialized, errorCode = AppsPersistence.Initialize()
		if initialized then
			break
		end
		if errorCode == 'database_not_ready' or errorCode == 'database_unavailable' then
			if not waitingLogged then
				log('info', 'persistence', 'database_waiting', {})
				waitingLogged = true
			end
			Wait(1000)
		else
			log('error', 'persistence', 'migrations_failed', { error_code = tostring(errorCode) })
			return
		end
	end
	local list = AppsPersistence.ActiveAds(os.time())
	ads = list or {}
	ready = true
	log('info', 'system', 'apps_ready', { operation = AppsPhotos.Provider() })

	CreateThread(function()
		while true do
			renewSubscriptions()
			Wait(config.Subscriptions.TickSeconds * 1000)
		end
	end)

	while true do
		Wait(10 * 60 * 1000)
		local now = os.time()
		for index = #ads, 1, -1 do
			if ads[index].expiresAt <= now then
				table.remove(ads, index)
			end
		end
		AppsPersistence.PurgeAds(now)
		for characterId, at in pairs(lastPost) do
			if now - at > DAY then
				lastPost[characterId] = nil
			end
		end
	end
end)
