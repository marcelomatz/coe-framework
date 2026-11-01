dofile('config.lua')
dofile('shared/rules.lua')

local config = NewsConfig
local failures = 0

local function eq(actual, expected, message)
	if actual ~= expected then
		failures = failures + 1
		print(('FAIL %s: esperado %s, obtido %s'):format(message, tostring(expected), tostring(actual)))
	end
end

-- Texto
eq(NewsRules.Text('  olá   mundo  ', 20), 'olá mundo', 'espaços reduzidos')
eq(NewsRules.Text('a\nb', 20), 'a b', 'quebra vira espaço em linha única')
eq(NewsRules.Text('a\n\n\n\nb', 20, true), 'a\n\nb', 'parágrafos limitados')
eq(NewsRules.Text('   ', 20), nil, 'vazio')
eq(NewsRules.Text(12, 20), nil, 'não é texto')
eq(NewsRules.Text('ãããããã', 3), 'ããã', 'corte em caracteres UTF-8')
eq(NewsRules.Id('7'), 7, 'id numérico')
eq(NewsRules.Id(0), nil, 'id zero')
eq(NewsRules.Id(1.5), nil, 'id fracionado')

-- Editorias
local sections = NewsRules.Sections(config, { 'gossip', 'news', 'gossip', 'nope' })
eq(#sections, 2, 'editorias sem repetição nem inválidas')
eq(sections[1], 'news', 'ordem do config')
eq(NewsRules.Sections(config, {}), nil, 'precisa de uma editoria')
eq(#NewsRules.ParseSections(config, 'police,sports'), 2, 'csv lido')
eq(#NewsRules.ParseSections(config, 'nada'), #config.DefaultSections, 'csv inválido volta ao padrão')

-- Linha editorial
local editorial = NewsRules.Editorial(config, { tagline = ' Slogan ', editorial = 'Texto', sections = { 'news' }, adPrice = 300 })
eq(editorial.tagline, 'Slogan', 'slogan limpo')
eq(editorial.adPrice, 300, 'preço')
eq(select(2, NewsRules.Editorial(config, { sections = { 'news' }, adPrice = 1 })), 'invalid_price', 'preço abaixo do mínimo')
eq(select(2, NewsRules.Editorial(config, { sections = {}, adPrice = 300 })), 'invalid_sections', 'sem editorias')

-- Matéria
local article = NewsRules.Article(config, { section = 'news', title = 'Título', summary = 'Resumo', body = 'Texto', anonymous = true }, { 'news' })
eq(article.title, 'Título', 'título')
eq(article.summary, 'Resumo', 'linha fina')
eq(article.anonymous, true, 'anônima')
eq(select(2, NewsRules.Article(config, { section = 'sports', title = 'a', body = 'b' }, { 'news' })), 'invalid_section', 'editoria desativada')
eq(select(2, NewsRules.Article(config, { section = 'news', title = ' ', body = 'b' }, { 'news' })), 'missing_title', 'sem título')
eq(select(2, NewsRules.Article(config, { section = 'news', title = 'a' }, { 'news' })), 'missing_body', 'sem texto')

-- Fluxo da matéria
local author, editor, outsider = { author = true }, { publisher = true }, {}
eq(NewsRules.Transition('draft', 'edit', author), 'draft', 'autor edita rascunho')
eq(select(2, NewsRules.Transition('draft', 'edit', editor)), 'forbidden', 'editor não mexe em rascunho alheio')
eq(NewsRules.Transition('review', 'edit', editor), 'review', 'editor edita em revisão')
eq(select(2, NewsRules.Transition('published', 'edit', author)), 'forbidden', 'autor não edita publicada')
eq(NewsRules.Transition('draft', 'submit', author), 'review', 'enviar para revisão')
eq(select(2, NewsRules.Transition('review', 'submit', author)), 'forbidden', 'enviar duas vezes')
eq(NewsRules.Transition('review', 'reject', editor), 'draft', 'devolver ao autor')
eq(NewsRules.Transition('review', 'publish', editor), 'published', 'publicar')
eq(NewsRules.Transition('unpublished', 'publish', editor), 'published', 'republicar')
eq(select(2, NewsRules.Transition('review', 'publish', author)), 'forbidden', 'autor não publica')
eq(NewsRules.Transition('published', 'unpublish', editor), 'unpublished', 'tirar do ar')
eq(NewsRules.Transition('review', 'remove', author), 'removed', 'autor apaga a própria em revisão')
eq(select(2, NewsRules.Transition('published', 'remove', author)), 'forbidden', 'autor não apaga publicada')
eq(NewsRules.Transition('published', 'remove', editor), 'removed', 'editor apaga publicada')
eq(select(2, NewsRules.Transition('draft', 'submit', outsider)), 'forbidden', 'sem papel')
eq(select(2, NewsRules.Transition('draft', 'fly', author)), 'invalid_action', 'ação desconhecida')
eq(select(2, NewsRules.Transition('removed', 'edit', editor)), 'invalid_action', 'status desconhecido')

-- Assinatura
eq(NewsRules.Byline({ anonymous = true, authorName = 'Ana' }), 'Redação', 'anônima assina Redação')
eq(NewsRules.Byline({ anonymous = false, authorName = 'Ana' }), 'Ana', 'assinada')
eq(NewsRules.Byline({ anonymous = false, authorName = '' }), 'Redação', 'sem nome')

-- Anúncio
local ad = NewsRules.Ad(config, { advertiser = 'Loja', title = 'Promo', body = 'Tudo pela metade', days = 3 }, 200)
eq(ad.price, 600, 'preço = dias x diária')
eq(select(2, NewsRules.Ad(config, { advertiser = 'Loja', title = 'a', body = 'b', days = 2 }, 200)), 'invalid_days', 'duração fora da lista')
eq(select(2, NewsRules.Ad(config, { title = 'a', body = 'b', days = 1 }, 200)), 'missing_advertiser', 'sem anunciante')

-- Quem paga
eq(NewsRules.Payer('personal').kind, 'personal', 'conta pessoal')
eq(NewsRules.Payer('business:weazel_news').ref, 'weazel_news', 'caixa do negócio')
eq(NewsRules.Payer('business:Weazel'), nil, 'id inválido')
eq(NewsRules.Payer('bank'), nil, 'origem desconhecida')

-- Busca
eq(NewsRules.Search(' 100% _real_ ', 40), '100 real', 'curingas removidos')
eq(NewsRules.Search('%%', 40), nil, 'só curingas')

-- Config
for id, outlet in pairs(config.Outlets) do
	eq(type(outlet.business) == 'string' and outlet.business:match('^[a-z][a-z0-9_]*$') ~= nil, true, 'negócio de ' .. id)
	eq(outlet.color:match('^#%x%x%x%x%x%x$') ~= nil, true, 'cor de ' .. id)
end
for _, permission in ipairs(config.Permissions) do
	eq(permission.name:sub(1, 5), 'news.', 'prefixo da permissão ' .. permission.name)
end

-- Painel admin: equipamentos
eq(NewsRules.EquipmentItem(config, 'news_camera').prop, 'prop_v_cam_01', 'câmera no config')
eq(NewsRules.EquipmentItem(config, 'water'), nil, 'item fora do equipamento')
local stock = NewsRules.StockChange(config, { item = 'news_mic', count = '3', op = 'add' })
eq(stock.count, 3, 'quantidade numérica')
eq(stock.op, 'add', 'operação')
eq(select(2, NewsRules.StockChange(config, { item = 'water', count = 1, op = 'add' })), 'unknown_equipment', 'só itens de imprensa')
eq(select(2, NewsRules.StockChange(config, { item = 'news_mic', count = 0, op = 'add' })), 'invalid_count', 'quantidade zero')
eq(select(2, NewsRules.StockChange(config, { item = 'news_mic', count = config.Equipment.MaxPerOperation + 1, op = 'add' })), 'invalid_count', 'acima do limite')
eq(select(2, NewsRules.StockChange(config, { item = 'news_mic', count = 1.5, op = 'add' })), 'invalid_count', 'fracionada')
eq(select(2, NewsRules.StockChange(config, { item = 'news_mic', count = 1, op = 'steal' })), 'invalid_stock', 'operação inválida')
eq(select(2, NewsRules.StockChange(config, nil)), 'invalid_stock', 'sem dados')
local names = {}
for _, item in ipairs(config.Equipment.Items) do
	eq(names[item.name], nil, 'equipamento sem repetição: ' .. item.name)
	names[item.name] = true
	eq(type(item.prop) == 'string' and type(item.dict) == 'string' and type(item.anim) == 'string', true, 'prop e animação de ' .. item.name)
	eq(#item.offset == 3 and #item.rotation == 3, true, 'offset e rotação de ' .. item.name)
end

-- Painel admin: estorno ao tirar anúncio do ar
local live = { price = 700, days = 7, endsAt = 1000 + 7 * 86400 }
eq(NewsRules.TakedownRefund(live, 1000, 'full'), 700, 'estorno total')
eq(NewsRules.TakedownRefund(live, 1000, 'none'), 0, 'sem estorno')
eq(NewsRules.TakedownRefund(live, 1000, nil), 0, 'modo ausente não estorna')
eq(NewsRules.TakedownRefund(live, 1000, 'remaining'), 700, 'nada consumido: tudo')
eq(NewsRules.TakedownRefund(live, 1000 + 86400 * 3.5, 'remaining'), 350, 'metade consumida')
eq(NewsRules.TakedownRefund(live, live.endsAt + 10, 'remaining'), 0, 'já vencido')
eq(NewsRules.TakedownRefund(live, 1000 + 1, 'remaining'), 699, 'arredonda para baixo')

-- Painel admin: filtro de matérias e grupos de anúncios
eq(NewsRules.ArticleFilter({ status = 'review', search = ' furo ' }, 40).search, 'furo', 'busca limpa')
eq(NewsRules.ArticleFilter({ status = 'review' }, 40).status, 'review', 'status válido')
eq(NewsRules.ArticleFilter({ status = 'removed' }, 40).status, nil, 'status desconhecido vira todos')
eq(NewsRules.ArticleFilter(nil, 40).status, nil, 'sem filtro')
eq(#NewsRules.AdGroups.history, 4, 'histórico: expirados, recusados, cancelados e retirados')
eq(config.AdminResources.coe_admin, true, 'coe_admin chama os exports de admin')

if failures > 0 then
	error(('news_test: %d falha(s)'):format(failures))
end
print('news_test: ok')
