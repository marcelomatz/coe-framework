-- Regras puras do coe_apps (sem natives), usadas pelo servidor e pelos testes.
AppsRules = {}

local function trim(value)
	return (tostring(value):gsub('^%s+', ''):gsub('%s+$', ''))
end

-- Texto livre do jogador: sem controle, espaços repetidos reduzidos e limite em caracteres UTF-8.
function AppsRules.Text(value, max, multiline)
	if type(value) ~= 'string' then
		return nil
	end
	local text = value:gsub('\r\n?', '\n')
	if multiline then
		text = text:gsub('[\0-\8\11-\31\127]', ''):gsub('\n\n\n+', '\n\n')
	else
		text = text:gsub('[\0-\31\127]', ' ')
	end
	text = trim(text:gsub('[ \t]+', ' '))
	if text == '' or not utf8.len(text) then
		return nil
	end
	if utf8.len(text) > max then
		text = text:sub(1, utf8.offset(text, max + 1) - 1)
	end
	return text
end

-- Preço semanal da assinatura (0 = grátis).
function AppsRules.Price(app)
	return math.max(0, math.floor(tonumber(app and app.price) or 0))
end

-- Assinatura paga até depois de `now`?
function AppsRules.Paid(record, now)
	return record ~= nil and (tonumber(record.paidUntil) or 0) > now
end

-- O app funciona para o personagem: nativo, ou instalado e (grátis ou com a assinatura em dia).
function AppsRules.Active(config, appId, record, now)
	local app = config.Store[appId]
	if not app then
		return false
	end
	if app.builtin then
		return true
	end
	if not record or not record.installed then
		return false
	end
	return AppsRules.Price(app) == 0 or AppsRules.Paid(record, now)
end

-- Apps da loja para um aparelho, na ordem das categorias e depois pelo nome.
-- installed: [appId] = { installed, paidUntil, autoRenew }.
function AppsRules.Catalog(config, device, installed, now)
	now = now or os.time()
	local order = {}
	for index, category in ipairs(config.StoreCategories or {}) do
		order[category] = index
	end
	local list = {}
	for id, app in pairs(config.Store) do
		if type(app.devices) == 'table' and app.devices[device] == true then
			local record = installed and installed[id]
			local price = AppsRules.Price(app)
			local paid = price > 0 and AppsRules.Paid(record, now)
			list[#list + 1] = {
				id = id, label = app.label, description = app.description, icon = app.icon, color = app.color,
				category = app.category or 'Outros', price = price, builtin = app.builtin == true,
				installed = AppsRules.Active(config, id, record, now),
				owned = app.builtin == true or (price == 0 and record ~= nil) or paid,
				paidUntil = paid and record.paidUntil or nil,
				renews = paid and record.installed == true and record.autoRenew == true or nil
			}
		end
	end
	table.sort(list, function(a, b)
		local oa, ob = order[a.category] or 99, order[b.category] or 99
		if oa ~= ob then
			return oa < ob
		end
		return a.label < b.label
	end)
	return list
end

-- Pode instalar? Devolve o valor a cobrar agora (0 se grátis ou com a semana já paga) ou nil + código.
function AppsRules.Install(config, appId, device, record, now)
	local app = type(appId) == 'string' and config.Store[appId]
	if not app or app.builtin then
		return nil, 'unknown_app'
	end
	if type(app.devices) ~= 'table' or app.devices[device] ~= true then
		return nil, 'unknown_app'
	end
	if AppsRules.Active(config, appId, record, now) then
		return nil, 'already_installed'
	end
	local price = AppsRules.Price(app)
	if price == 0 or AppsRules.Paid(record, now) then
		return 0
	end
	return price
end

-- Fim do novo período pago: a partir do fim do atual (renovação antecipada) ou de agora, se já venceu.
function AppsRules.NextPeriod(paidUntil, now, periodSeconds)
	return math.max(tonumber(paidUntil) or 0, now) + periodSeconds
end
function AppsRules.CategoryLabel(config, id)
	for _, category in ipairs(config.Classifieds.Categories) do
		if category.id == id then
			return category.label
		end
	end
	return nil
end

-- Anúncio dos Classificados. price é opcional (nil = "a combinar").
function AppsRules.Ad(config, payload)
	local rules = config.Classifieds
	if type(payload) ~= 'table' then
		return nil, 'invalid_ad'
	end
	if not AppsRules.CategoryLabel(config, payload.category) then
		return nil, 'invalid_category'
	end
	local title = AppsRules.Text(payload.title, rules.TitleMax, false)
	if not title or utf8.len(title) < 3 then
		return nil, 'invalid_title'
	end
	local body = AppsRules.Text(payload.body or '', rules.BodyMax, true)
	local price = nil
	if payload.price ~= nil and payload.price ~= '' then
		price = tonumber(payload.price)
		if not price or price < 0 or price % 1 ~= 0 or price > rules.PriceMax then
			return nil, 'invalid_price'
		end
	end
	return { category = payload.category, title = title, body = body or '', price = price }
end

-- Legenda do Insta (opcional).
function AppsRules.Caption(config, value)
	if value == nil or value == '' then
		return ''
	end
	return AppsRules.Text(value, config.Insta.CaptionMax, true) or ''
end

-- @nome.sobrenome sem acentos, a partir do nome do personagem.
local ACCENTS = {
	['á'] = 'a', ['à'] = 'a', ['â'] = 'a', ['ã'] = 'a', ['ä'] = 'a', ['é'] = 'e', ['ê'] = 'e', ['è'] = 'e', ['ë'] = 'e',
	['í'] = 'i', ['ì'] = 'i', ['î'] = 'i', ['ï'] = 'i', ['ó'] = 'o', ['ò'] = 'o', ['ô'] = 'o', ['õ'] = 'o', ['ö'] = 'o',
	['ú'] = 'u', ['ù'] = 'u', ['û'] = 'u', ['ü'] = 'u', ['ç'] = 'c', ['ñ'] = 'n'
}
function AppsRules.Handle(name)
	local text = tostring(name or ''):lower()
	for from, to in pairs(ACCENTS) do
		text = text:gsub(from, to)
	end
	for upper, lower in pairs({ ['Á'] = 'a', ['É'] = 'e', ['Í'] = 'i', ['Ó'] = 'o', ['Ú'] = 'u', ['Ç'] = 'c', ['Ã'] = 'a', ['Õ'] = 'o', ['Â'] = 'a', ['Ê'] = 'e', ['Ô'] = 'o' }) do
		text = text:gsub(upper, lower)
	end
	text = text:gsub('[^a-z0-9]+', '.'):gsub('^%.+', ''):gsub('%.+$', '')
	if text == '' then
		text = 'cidadao'
	end
	return '@' .. text:sub(1, 30)
end

-- Foto enviada pelo tablet: só JPEG em base64, dentro do limite.
function AppsRules.Photo(config, data)
	if type(data) ~= 'string' or #data > config.Photos.MaxBytes then
		return nil, 'invalid_photo'
	end
	local body = data:match('^data:image/jpeg;base64,([A-Za-z0-9+/]+=?=?)$')
	if not body or #body < 64 then
		return nil, 'invalid_photo'
	end
	return body
end

-- URL pública devolvida pelo host de fotos: só https, sem aspas nem espaços.
function AppsRules.PhotoUrl(value)
	if type(value) ~= 'string' or #value > 500 then
		return nil
	end
	if not value:match('^https://[%w%.%-]+/[%w%-%._~:/%?#%[%]@!%$&%(%)%*%+,;=%%]*$') then
		return nil
	end
	return value
end

-- Lê `a.b.c` de uma tabela decodificada do JSON.
function AppsRules.Path(data, path)
	local node = data
	for key in tostring(path):gmatch('[^%.]+') do
		if type(node) ~= 'table' then
			return nil
		end
		node = node[tonumber(key) or key]
	end
	return node
end

function AppsRules.UrlEncode(value)
	return (tostring(value):gsub('[^%w%-%._~]', function(char)
		return ('%%%02X'):format(char:byte())
	end))
end
