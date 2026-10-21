-- Guia "Como funciona" (shared/guide.lua): cada emprego de jobs/ ganha passo a passo, pagamento, regras e requisitos.
dofile('shared/rules.lua')
dofile('config.lua')
dofile('shared/guide.lua')
for _, name in ipairs({ 'lumberjack', 'miner', 'fisher', 'farmer', 'delivery', 'garbage', 'taxi', 'trucker' }) do
	dofile('jobs/' .. name .. '.lua')
end

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end
local function has(list, pattern, m)
	for _, item in ipairs(list) do
		if (type(item) == 'table' and (item.label .. ' ' .. item.value) or item):find(pattern) then return end
	end
	error(m .. ': nada com ' .. pattern, 2)
end

local career = JobsConfig.Career
local known = {}
for id in pairs(career.skills) do known[id] = true end
local guides = {}
for _, raw in ipairs(JobsCatalog) do
	local job = assert(JobRules.Validate(raw, known))
	local guide = JobGuide.Build(career, job)
	guides[job.id] = guide
	eq(guide.label, job.label, job.id .. ' com nome')
	eq(#guide.steps >= 4, true, job.id .. ' com passo a passo')
	eq(#guide.pay >= 2, true, job.id .. ' com pagamento')
	eq(#guide.rules >= 1, true, job.id .. ' com regras')
	eq(#guide.skills, #job.skills, job.id .. ' mostra as habilidades')
	eq(#guide.tips >= 1, true, job.id .. ' com dicas')
	for _, step in ipairs(guide.steps) do
		eq(#step <= 240, true, job.id .. ': passo curto')
	end
end

-- coleta: venda é o que paga e encerrar com carga descarta
has(guides.farmer.steps, 'Só a venda paga: %$8 por repolho', 'fazendeiro explica a venda')
has(guides.farmer.steps, 'até 40 repolhos', 'carga do fazendeiro')
has(guides.farmer.steps, 'volta em 3 min', 'cooldown em minutos')
has(guides.farmer.rules, 'descarta', 'aviso do descarte')
has(guides.farmer.pay, 'Por repolho %$8', 'preco por unidade')
eq(guides.farmer.kind, 'Coleta e venda', 'tipo da coleta')
eq(guides.farmer.requires, nil, 'fazendeiro sem requisito')
has(guides.fisher.steps, 'rende 1 peixe', 'rendimento no singular')

-- rotas: modos
eq(guides.taxi.kind, 'Corridas com passageiros', 'tipo do taxi')
has(guides.taxi.steps, 'embarca sozinho', 'embarque explicado')
has(guides.taxi.pay, 'Por corrida %$30 %+ %$70 por km', 'pagamento por km')
eq(guides.taxi.requires, 'carreira nível 2', 'requisito do taxi')
eq(guides.garbage.kind, 'Coleta por áreas', 'tipo do lixeiro')
has(guides.garbage.steps, 'área marcada', 'lixeiro vai até a área')
has(guides.garbage.steps, '"Abrir a caçamba" e depois "Jogar na caçamba"', 'abre a caçamba antes')
has(guides.garbage.steps, 'enche de novo depois de 10 min', 'cooldown da lixeira')
has(guides.garbage.pay, 'Por saco %$28', 'pagamento por saco')
has(guides.delivery.steps, 'depósito de %$300', 'deposito explicado')
has(guides.delivery.pay, 'Bônus ao fim da rota %$120', 'bonus da rota')
eq(guides.trucker.requires, 'Direção nível 2, reputação 0 ou mais', 'requisito do caminhoneiro')
eq(guides.miner.requires, 'Força nível 2', 'requisito do mineiro')
eq(guides.miner.skills[1].perks[1], '+10% de carga por nível', 'bonus da habilidade')

-- textos auxiliares
eq(JobGuide.PerkText('speed', 0.05), '-5% no tempo das ações', 'perk de tempo')
eq(JobGuide.PerkText('desconhecido', 1), 'desconhecido', 'perk sem texto')

print('coe_jobs guide tests passed')
