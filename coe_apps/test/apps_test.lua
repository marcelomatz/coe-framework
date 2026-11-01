dofile('config.lua')
dofile('shared/rules.lua')

local config = CoeAppsConfig
local failures = 0

local function eq(actual, expected, message)
	if actual ~= expected then
		failures = failures + 1
		print(('FAIL %s: esperado %s, obtido %s'):format(message, tostring(expected), tostring(actual)))
	end
end

-- Texto
eq(AppsRules.Text('  Olá   mundo  ', 60), 'Olá mundo', 'texto apara e junta espaços')
eq(AppsRules.Text('a\0b\27c', 60), 'a b c', 'texto troca controle por espaço')
eq(AppsRules.Text('linha 1\r\n\n\n\nlinha 2', 60, true), 'linha 1\n\nlinha 2', 'multilinha limita quebras')
eq(AppsRules.Text('   ', 60), nil, 'texto vazio')
eq(AppsRules.Text(42, 60), nil, 'texto não string')
eq(AppsRules.Text('ááááá', 3), 'ááá', 'corta por caractere UTF-8')
eq(AppsRules.Text('\255\254', 10), nil, 'rejeita UTF-8 inválido')

-- Catálogo
local catalog = AppsRules.Catalog(config, 'tablet', { insta = { installed = true }, jobs = { installed = false } })
eq(#catalog, 10, 'catálogo do tablet')
eq(catalog[1].id, 'elos', 'Social vem primeiro (por nome: Elos, Insta)')
eq(catalog[2].id, 'insta', 'Insta depois do Elos')
eq(catalog[#catalog].id, 'store', 'Sistema por último')
local byId = {}
for _, app in ipairs(catalog) do
	byId[app.id] = app
end
eq(byId.insta.installed, true, 'insta instalado')
eq(byId.jobs.installed, false, 'jobs removido')
eq(byId.jobs.owned, true, 'jobs já comprado')
eq(byId.classifieds.owned, false, 'classificados nunca instalado')
eq(byId.store.installed, true, 'loja é nativa')
eq(byId.elos.installed, true, 'Elos vem instalado')
eq(byId.crypto ~= nil, true, 'carteira cripto na loja do tablet')
eq(#AppsRules.Catalog(config, 'watch', {}), 0, 'aparelho desconhecido')
local phoneCatalog = AppsRules.Catalog(config, 'phone', {})
eq(#phoneCatalog, 11, 'catálogo do smartphone tem o Estúdio')
eq(phoneCatalog[3].id, 'editor', 'Foto e vídeo depois de Social')
local now = 1000000
eq(AppsRules.Install(config, 'editor', 'phone', nil, now), config.Store.editor.price, 'Estúdio é pago')
eq(config.Store.editor.price > 0, true, 'Estúdio tem preço')
eq(select(2, AppsRules.Install(config, 'editor', 'tablet', nil, now)), 'unknown_app', 'Estúdio só no smartphone')
local subscribed = AppsRules.Catalog(config, 'phone', { editor = { installed = true, paidUntil = now + 10, autoRenew = true } }, now)[3]
eq(subscribed.installed, true, 'assinatura em dia')
eq(subscribed.renews, true, 'renovação automática')
eq(subscribed.paidUntil, now + 10, 'pago até')
local lapsed = AppsRules.Catalog(config, 'phone', { editor = { installed = true, paidUntil = now, autoRenew = true } }, now)[3]
eq(lapsed.installed, false, 'assinatura vencida some do aparelho')
eq(lapsed.owned, false, 'vencida precisa assinar de novo')
eq(AppsRules.Active(config, 'editor', { installed = true, paidUntil = now + 1 }, now), true, 'ativo com semana paga')
eq(AppsRules.Active(config, 'editor', { installed = true, paidUntil = now - 1 }, now), false, 'inativo sem pagamento')
eq(AppsRules.Active(config, 'jobs', { installed = true, paidUntil = 0 }, now), true, 'grátis não vence')

-- Instalação
local paid = { Store = { pro = { label = 'Pro', price = 250, devices = { tablet = true } } } }
eq(AppsRules.Install(paid, 'pro', 'tablet', nil, now), 250, 'cobra a primeira semana')
eq(AppsRules.Install(paid, 'pro', 'tablet', { installed = false, paidUntil = now + 60 }, now), 0, 'reinstalar na semana paga é grátis')
eq(AppsRules.Install(paid, 'pro', 'tablet', { installed = false, paidUntil = now - 60 }, now), 250, 'semana vencida cobra de novo')
eq(AppsRules.Install(paid, 'pro', 'tablet', { installed = true, paidUntil = now - 60 }, now), 250, 'instalado mas vencido cobra')
eq(select(2, AppsRules.Install(paid, 'pro', 'tablet', { installed = true, paidUntil = now + 60 }, now)), 'already_installed', 'já instalado')
eq(AppsRules.Install(config, 'jobs', 'tablet', { installed = false }, now), 0, 'grátis reinstala')
eq(select(2, AppsRules.Install(paid, 'pro', 'phone', nil, now)), 'unknown_app', 'aparelho sem suporte')
eq(select(2, AppsRules.Install(config, 'store', 'tablet', nil, now)), 'unknown_app', 'loja não se instala')
eq(select(2, AppsRules.Install(config, 'nada', 'tablet', nil, now)), 'unknown_app', 'app inexistente')
local week = 7 * 86400
eq(AppsRules.NextPeriod(now + 100, now, week), now + 100 + week, 'renovação antecipada soma ao período atual')
eq(AppsRules.NextPeriod(now - 100, now, week), now + week, 'vencida conta a partir de agora')
eq(select(2, AppsRules.Install(config, {}, 'tablet', nil)), 'unknown_app', 'id inválido')

-- Anúncios
local ad = AppsRules.Ad(config, { category = 'vehicles', title = '  Sultan RS  ', body = 'Único dono', price = 45000 })
eq(ad.title, 'Sultan RS', 'título do anúncio')
eq(ad.price, 45000, 'preço do anúncio')
eq(AppsRules.Ad(config, { category = 'items', title = 'Rádio' }).price, nil, 'preço a combinar')
eq(AppsRules.Ad(config, { category = 'items', title = 'Rádio', price = '' }).price, nil, 'preço vazio a combinar')
eq(select(2, AppsRules.Ad(config, { category = 'drugs', title = 'Teste' })), 'invalid_category', 'categoria inválida')
eq(select(2, AppsRules.Ad(config, { category = 'items', title = 'ab' })), 'invalid_title', 'título curto')
eq(select(2, AppsRules.Ad(config, { category = 'items', title = 'Rádio', price = -1 })), 'invalid_price', 'preço negativo')
eq(select(2, AppsRules.Ad(config, { category = 'items', title = 'Rádio', price = 1.5 })), 'invalid_price', 'preço fracionado')
eq(select(2, AppsRules.Ad(config, { category = 'items', title = 'Rádio', price = config.Classifieds.PriceMax + 1 })), 'invalid_price', 'preço acima do teto')
eq(select(2, AppsRules.Ad(config, 'x')), 'invalid_ad', 'payload inválido')
eq(utf8.len(AppsRules.Ad(config, { category = 'other', title = string.rep('x', 200) }).title), config.Classifieds.TitleMax, 'título cortado')
eq(AppsRules.CategoryLabel(config, 'properties'), 'Imóveis', 'rótulo da categoria')

-- Insta
eq(AppsRules.Caption(config, nil), '', 'sem legenda')
eq(utf8.len(AppsRules.Caption(config, string.rep('é', 400))), config.Insta.CaptionMax, 'legenda cortada')
eq(AppsRules.Handle('João da Silva'), '@joao.da.silva', 'handle sem acento')
eq(AppsRules.Handle('ÁLVARO Ícaro'), '@alvaro.icaro', 'handle com maiúsculas acentuadas')
eq(AppsRules.Handle('  '), '@cidadao', 'handle vazio')

-- Fotos
local body = string.rep('A', 100)
eq(AppsRules.Photo(config, 'data:image/jpeg;base64,' .. body), body, 'foto JPEG aceita')
eq(AppsRules.Photo(config, 'data:image/jpeg;base64,' .. body .. '=='), body .. '==', 'foto com padding')
eq(select(2, AppsRules.Photo(config, 'data:image/png;base64,' .. body)), 'invalid_photo', 'só JPEG')
eq(select(2, AppsRules.Photo(config, 'data:image/jpeg;base64,abc')), 'invalid_photo', 'foto curta')
eq(select(2, AppsRules.Photo(config, 'data:image/jpeg;base64,' .. body .. '"<')), 'invalid_photo', 'base64 inválido')
eq(select(2, AppsRules.Photo(config, 'data:image/jpeg;base64,' .. string.rep('A', config.Photos.MaxBytes))), 'invalid_photo', 'foto grande')
eq(AppsRules.PhotoUrl('https://cdn.example.org/i/abc.jpg'), 'https://cdn.example.org/i/abc.jpg', 'URL https')
eq(AppsRules.PhotoUrl('http://cdn.example.org/a.jpg'), nil, 'rejeita http')
eq(AppsRules.PhotoUrl('https://x.org/a" onerror="b'), nil, 'rejeita aspas')
eq(AppsRules.PhotoUrl('javascript:alert(1)'), nil, 'rejeita esquema')

-- Utilidades
eq(AppsRules.Path({ data = { url = 'u' } }, 'data.url'), 'u', 'caminho no JSON')
eq(AppsRules.Path({ data = { 'a', 'b' } }, 'data.2'), 'b', 'caminho com índice')
eq(AppsRules.Path({ data = 'x' }, 'data.url'), nil, 'caminho inexistente')
eq(AppsRules.UrlEncode('a+b/c=='), 'a%2Bb%2Fc%3D%3D', 'url encode')

if failures > 0 then
	error(('%d falha(s)'):format(failures))
end
print('apps_test: ok')
