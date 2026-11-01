-- Exports de administração (server/admin.lua) com persistência, economia e inventário falsos.
dofile('config.lua')
dofile('shared/rules.lua')

local failures = 0
local function eq(actual, expected, message)
	if actual ~= expected then
		failures = failures + 1
		print(('FAIL %s: esperado %s, obtido %s'):format(message, tostring(expected), tostring(actual)))
	end
end

local registered = {}
function exports(name, handler)
	registered[name] = handler
end
local caller = 'coe_admin'
function GetInvokingResource()
	return caller
end

-- Mundo falso -------------------------------------------------------------------------------------------------
local now = 1000000
local calls, audits, notices = {}, {}, {}
local inventories = { ['character:7'] = { news_mic = 1 } }
local balances = { weazel_news = 5000 }
local business = {
	id = 'weazel_news', category = 'media', owner = { characterId = '7', name = 'Dona' },
	staff = { { characterId = '8', name = 'Repórter' } },
	stations = { stashes = { { id = 'arquivo', label = 'Arquivo', slots = 30 } } }
}

local remotes = {
	coe_businesses = { Get = function(id) return id == 'weazel_news' and business or nil end },
	coe_economy = {
		SocietyBalance = function(id) return balances[id] end,
		SocietyCharge = function(id, amount)
			calls[#calls + 1] = 'charge:' .. id .. ':' .. amount
			if (balances[id] or 0) < amount then return { error = 'insufficient_funds' } end
			balances[id] = balances[id] - amount
			return true
		end,
		SocietyCollect = function(id, amount)
			calls[#calls + 1] = 'collect:' .. id .. ':' .. amount
			balances[id] = (balances[id] or 0) + amount
			return true
		end,
		Credit = function(characterId, amount)
			calls[#calls + 1] = 'credit:' .. characterId .. ':' .. amount
			return true
		end
	},
	coe_inventory = {
		GetInventory = function(id) return inventories[id] and {} or nil end,
		CreateInventory = function(id) inventories[id] = {}; return true end,
		GetItemCount = function(id, name) return inventories[id] and inventories[id][name] or 0 end,
		AddItem = function(id, name, amount)
			inventories[id][name] = (inventories[id][name] or 0) + amount
			return true
		end,
		RemoveItemByName = function(id, name, amount)
			if (inventories[id][name] or 0) < amount then return false end
			inventories[id][name] = inventories[id][name] - amount
			return true
		end
	}
}

local ads = {
	[1] = { id = 1, outlet = 'weazel', status = 'pending', price = 300, days = 3, buyerId = '9', payerKind = 'personal', title = 'A' },
	[2] = { id = 2, outlet = 'weazel', status = 'active', price = 700, days = 7, endsAt = now + 7 * 86400 / 2, buyerId = '9', payerKind = 'business', payerRef = 'bar', title = 'B' }
}
local articles = {
	[5] = { id = 5, outlet = 'weazel', status = 'published', image = 'media:1', title = 'T' }
}

NewsPersistence = {
	Stats = function() return { articles = { published = 1 }, ads = {}, views = 3 } end,
	SaveOutlet = function() return true end,
	TakedownAd = function(id)
		if ads[id].status ~= 'active' then return false end
		ads[id].status = 'removed'
		return true
	end,
	RestoreAd = function(id) ads[id].status = 'active'; return true end,
	SetStatus = function(id, from, to)
		if articles[id].status ~= from then return false end
		articles[id].status = to
		return true
	end,
	DeleteArticle = function(id) articles[id] = nil; return true end,
	AdminAds = function() return {} end,
	AdminArticles = function() return {} end
}

local deleted = {}
NewsServer = {
	config = NewsConfig,
	outlets = { weazel = { tagline = 'x', editorial = 'y', sections = { 'news' }, adPrice = 500 }, rebel = { sections = { 'news' }, adPrice = 500 } },
	isReady = function() return true end,
	remote = function(resource, name, ...)
		local fn = remotes[resource] and remotes[resource][name]
		if not fn then return nil end
		return fn(...)
	end,
	log = function() end,
	audit = function(event, context) audits[#audits + 1] = { event = event, context = context } end,
	notifyCharacter = function(id, kind, message) notices[#notices + 1] = message end,
	withLock = function(_, run) return run() end,
	loadAd = function(outlet, id)
		local ad = ads[tonumber(id)]
		if not ad or ad.outlet ~= outlet then return nil, 'not_found' end
		return ad
	end,
	loadArticle = function(outlet, id)
		local article = articles[tonumber(id)]
		if not article or article.outlet ~= outlet then return nil, 'not_found' end
		return article
	end,
	decideAd = function(ad, approve)
		ad.status = approve and 'active' or 'rejected'
		return { ok = true }
	end,
	deletePhoto = function(image) deleted[#deleted + 1] = image end,
	adView = function(ad) return { id = ad.id } end
}

local realTime = os.time
os.time = function() return now end
dofile('server/admin.lua')

-- Só o coe_admin chama
caller = 'coe_phone'
eq(registered.AdminOverview().error, 'forbidden', 'outro resource não lê')
eq(registered.AdminAction('stock', { outlet = 'weazel' }).error, 'forbidden', 'outro resource não age')
caller = 'coe_admin'

-- Visão geral
local overview = registered.AdminOverview()
eq(overview.available, true, 'visão geral disponível')
eq(#overview.outlets, 2, 'dois veículos')
eq(overview.outlets[2].label, 'Weazel News', 'ordenados por nome')
eq(overview.outlets[2].balance, 5000, 'caixa da sociedade')
eq(#overview.equipment, #NewsConfig.Equipment.Items, 'catálogo de equipamento')

-- Ações e consultas inválidas
eq(registered.AdminAction('hack', { outlet = 'weazel' }).error, 'invalid_action', 'ação desconhecida')
eq(registered.AdminAction('stock', { outlet = 'cnn' }).error, 'invalid_action', 'veículo desconhecido')
eq(registered.AdminQuery('nope', { outlet = 'weazel' }).error, 'invalid_query', 'consulta desconhecida')

-- Linha editorial
eq(registered.AdminAction('editorial', { outlet = 'weazel', tagline = 'Novo', sections = { 'news', 'gossip' }, adPrice = 900, admin = 3 }).ok, true, 'editorial salvo')
eq(NewsServer.outlets.weazel.adPrice, 900, 'preço em memória')
eq(audits[#audits].context.source, 'admin:3', 'auditoria com o admin')
eq(registered.AdminAction('editorial', { outlet = 'weazel', sections = {}, adPrice = 900 }).error, 'invalid_sections', 'editorial inválido')

-- Anúncios: aprovar e recusar só pendentes
eq(registered.AdminAction('adApprove', { outlet = 'weazel', id = 1 }).ok, true, 'aprovado')
eq(ads[1].status, 'active', 'no ar')
eq(registered.AdminAction('adReject', { outlet = 'weazel', id = 1 }).error, 'ad_decided', 'já decidido')
eq(registered.AdminAction('adApprove', { outlet = 'rebel', id = 2 }).error, 'not_found', 'anúncio de outro veículo')

-- Tirar do ar com estorno dos dias restantes (metade): sai do caixa do veículo e volta ao caixa do negócio pagador
local result = registered.AdminAction('adTakedown', { outlet = 'weazel', id = 2, refund = 'remaining' })
eq(result.ok, true, 'retirado')
eq(result.refunded, 350, 'estorno proporcional')
eq(ads[2].status, 'removed', 'status retirado')
eq(calls[1], 'charge:weazel_news:350', 'debita o veículo')
eq(calls[2], 'collect:bar:350', 'devolve ao negócio que pagou')
eq(balances.weazel_news, 4650, 'caixa do veículo menor')
eq(registered.AdminAction('adTakedown', { outlet = 'weazel', id = 2 }).error, 'ad_not_active', 'só anúncio no ar')

-- Sem saldo para o estorno total: nada muda
ads[2].status = 'active'
balances.weazel_news = 100
eq(registered.AdminAction('adTakedown', { outlet = 'weazel', id = 2, refund = 'full' }).error, 'outlet_insufficient_funds', 'sem saldo')
eq(ads[2].status, 'active', 'anúncio volta ao ar')

-- Matérias
eq(registered.AdminAction('articleRepublish', { outlet = 'weazel', id = 5 }).error, 'invalid_status', 'republicar exige fora do ar')
eq(registered.AdminAction('articleUnpublish', { outlet = 'weazel', id = 5 }).ok, true, 'tirada do ar')
eq(articles[5].status, 'unpublished', 'status fora do ar')
eq(registered.AdminAction('articleRepublish', { outlet = 'weazel', id = 5 }).ok, true, 'publicada de novo')
eq(registered.AdminAction('articleDelete', { outlet = 'weazel', id = 5 }).ok, true, 'apagada')
eq(articles[5], nil, 'removida')
eq(deleted[1], 'media:1', 'foto apagada')

-- Estoque: cria o baú na primeira vez, abastece, retira e recusa além do saldo
local stash = 'stash:business:weazel_news:arquivo'
eq(registered.AdminAction('stock', { outlet = 'weazel', item = 'news_camera', count = 2, op = 'add' }).ok, true, 'abastecido')
eq(inventories[stash].news_camera, 2, 'baú criado e abastecido')
eq(registered.AdminAction('stock', { outlet = 'weazel', item = 'news_camera', count = 3, op = 'remove' }).error, 'insufficient_items', 'retirar além do estoque')
eq(registered.AdminAction('stock', { outlet = 'weazel', item = 'news_camera', count = 1, op = 'remove' }).ok, true, 'retirado')
eq(registered.AdminAction('stock', { outlet = 'weazel', item = 'water', count = 1, op = 'add' }).error, 'unknown_equipment', 'item comum recusado')
eq(registered.AdminAction('stock', { outlet = 'rebel', item = 'news_camera', count = 1, op = 'add' }).error, 'no_stash', 'negócio sem baú')

-- Consulta de equipamento: estoque e quem está com cada item
local equipment = registered.AdminQuery('equipment', { outlet = 'weazel' })
eq(equipment.stash.id, stash, 'baú do estoque')
eq(equipment.items[1].stock, 1, 'câmeras no baú')
eq(equipment.items[2].holders[1].name, 'Dona', 'a dona está com o microfone')
eq(equipment.items[2].holders[1].owner, true, 'marcada como dona')

os.time = realTime
if failures > 0 then
	error(('admin_test: %d falha(s)'):format(failures))
end
print('admin_test: ok')
