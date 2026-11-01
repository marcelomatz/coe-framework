dofile('../coe_tablet/config.lua')
dofile('../coe_tablet/shared/profile.lua')
dofile('../coe_mechanic/server/tablet.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end

local full = CoeTabletConfig

-- Banco e Veículos (everyone): todo personagem vê, na seção Pessoal, mesmo sem emprego.
local citizen = TabletProfile.Resolve(full, nil, false)
eq(citizen.apps[1].id, 'bank', 'banco primeiro')
eq(citizen.apps[2].id, 'vehicles', 'veiculos')
eq(citizen.apps[1].group, 'personal', 'secao pessoal')
eq(citizen.groups, full.Groups, 'secoes vao ao perfil')
eq(nil ~= TabletProfile.CanUse(full, nil, false, 'bank'), true, 'CanUse banco')

-- Demais regras, sem os apps de todo personagem.
local config = { Groups = full.Groups, Profiles = full.Profiles, CategoryLabels = full.CategoryLabels, Shortcuts = full.Shortcuts, Apps = {} }
for id, app in pairs(full.Apps) do
	if not app.everyone then config.Apps[id] = app end
end

-- Perfil por emprego.
local profile = TabletProfile.Resolve(config, { job = { name = 'mechanic', grade = 0 } }, false)
eq(profile.job, 'mechanic', 'job')
eq(profile.label, 'Oficina', 'label')
eq(#profile.apps, 1, 'apps do mecânico')
eq(profile.apps[1].id, 'workshop', 'app workshop')

local none, code = TabletProfile.Resolve(config, { job = { name = 'police', grade = 3 } }, false)
eq(none, nil, 'policial sem apps')
eq(code, 'no_apps', 'código')
eq(select(2, TabletProfile.Resolve(config, nil, false)), 'no_apps', 'sem grupos')
eq(TabletProfile.Resolve(config, nil, true).job, 'admin', 'admin vê tudo')

-- Grau mínimo e script inválido.
local strict = { Apps = { a = { label = 'A', jobs = { mechanic = true }, minGrade = 2, script = 'nui://x/html/a.js' },
	b = { label = 'B', jobs = { mechanic = true }, script = 'https://evil.com/a.js' } }, Profiles = {} }
eq(TabletProfile.Resolve(strict, { job = { name = 'mechanic', grade = 1 } }, false), nil, 'grau insuficiente')
eq(#TabletProfile.Resolve(strict, { job = { name = 'mechanic', grade = 2 } }, false).apps, 1, 'script externo rejeitado')
eq(nil ~= TabletProfile.CanUse(config, { job = { name = 'mechanic', grade = 0 } }, false, 'workshop'), true, 'CanUse')
eq(nil ~= TabletProfile.CanUse(config, { job = { name = 'police', grade = 0 } }, false, 'workshop'), false, 'CanUse negado')
eq(nil ~= TabletProfile.CanUse(config, { job = { name = 'mechanic', grade = 0 } }, false, 'outro'), false, 'app desconhecido')
eq(TabletProfile.IsValidScript('nui://coe_mechanic/html/tablet_app.js'), true, 'script válido')
eq(TabletProfile.IsValidScript('nui://a/../b.js'), false, 'script inválido')

-- Ações do app de oficina.
local replaced = {}
local deps
deps = {
	radius = 8,
	byPlate = function(plate) return plate == 'ABC123' and { id = 1, plate = 'ABC123', model = 'adder', mileage = 5000 } or nil end,
	inspect = function() return { { part = 'engine_oil', wear = 0.5, condition = 'ok' } } end,
	mileage = function() return 6000 end,
	distance = function(_, id) return id == 1 and deps.near or nil end,
	replacePart = function(id, part) replaced[#replaced + 1] = part; return part == 'engine_oil' or 'unknown_part' end,
	serviceAll = function() replaced[#replaced + 1] = 'all'; return true end,
	near = 3
}
local scan = MechanicTablet.Handle(deps, 7, 'scan', { plate = 'ABC123' })
eq(scan.ok, true, 'scan')
eq(scan.vehicle.mileage, 6000, 'mileage')
eq(#scan.vehicle.parts, 1, 'peças')
eq(MechanicTablet.Handle(deps, 7, 'scan', { plate = "A'; DROP" }).error, 'invalid_plate', 'placa inválida')
eq(MechanicTablet.Handle(deps, 7, 'scan', {}).error, 'invalid_plate', 'sem placa')
eq(MechanicTablet.Handle(deps, 7, 'scan', { plate = 'ZZZ999' }).error, 'vehicle_not_found', 'inexistente')
deps.near = 20
eq(MechanicTablet.Handle(deps, 7, 'scan', { plate = 'ABC123' }).error, 'vehicle_too_far', 'longe')
deps.near = 3
eq(MechanicTablet.Handle(deps, 7, 'replace', { plate = 'ABC123', part = 'engine_oil' }).ok, true, 'troca')
eq(MechanicTablet.Handle(deps, 7, 'replace', { plate = 'ABC123', part = 'xx' }).error, 'unknown_part', 'peça inválida')
eq(MechanicTablet.Handle(deps, 7, 'replace', { plate = 'ABC123', part = 'all' }).ok, true, 'revisão')
eq(replaced[#replaced], 'all', 'serviceAll chamado')
eq(MechanicTablet.Handle(deps, 7, 'replace', { plate = 'ABC123' }).error, 'invalid_part', 'sem peça')
eq(MechanicTablet.Handle(deps, 7, 'explode', { plate = 'ABC123' }).error, 'unknown_action', 'ação desconhecida')

-- MDT: liberado pela categoria do negócio em que está de ponto, não pelo emprego.
local copProfile = TabletProfile.Resolve(config, nil, false, 'police')
eq(copProfile.apps[1].id, 'mdt', 'MDT para policial de ponto')
eq(copProfile.label, 'Polícia', 'rótulo da categoria')
eq(TabletProfile.Resolve(config, nil, false, 'ems'), nil, 'EMS não vê MDT')
eq(TabletProfile.Resolve(config, nil, false, nil), nil, 'fora de ponto não vê MDT')
eq(nil ~= TabletProfile.CanUse(config, nil, false, 'mdt', 'police'), true, 'CanUse mdt')
eq(nil ~= TabletProfile.CanUse(config, nil, false, 'mdt', nil), false, 'CanUse mdt sem ponto')
eq(nil ~= TabletProfile.CanUse(config, { job = { name = 'mechanic', grade = 0 } }, false, 'mdt', nil), false, 'mecânico sem MDT')

-- Negócios: um app por negócio do jogador (instances), sem item nem ponto para aparecer.
local function hasApp(profile, id)
	for _, app in ipairs(profile and profile.apps or {}) do
		if app.id == id then return true end
	end
	return false
end
local myBusinesses = function(app)
	if app.resource ~= 'coe_businesses' then return nil end
	return { { id = 'rest_a', label = 'Pizzaria' }, { id = 'mec_b', label = 'Oficina Sul' }, { id = 'bad id!', label = 'X' } }
end
local bizProfile = TabletProfile.Resolve(config, nil, false, nil, nil, nil, myBusinesses)
eq(hasApp(bizProfile, 'business:rest_a'), true, 'app do negócio 1')
eq(hasApp(bizProfile, 'business:mec_b'), true, 'app do negócio 2')
eq(hasApp(bizProfile, 'business:bad id!'), false, 'id inválido descartado')
eq(hasApp(bizProfile, 'business'), false, 'sem app genérico')
eq(bizProfile.apps[1].label, 'Pizzaria', 'nome do negócio no ícone')
eq(bizProfile.apps[1].group, 'business', 'seção Negócios')
eq(bizProfile.apps[1].base, 'business', 'app base')
local used = TabletProfile.CanUse(config, nil, false, 'business:mec_b', nil, nil, nil, myBusinesses)
eq(used and used.instance, 'mec_b', 'CanUse devolve a instância')
eq(TabletProfile.CanUse(config, nil, false, 'business:outro', nil, nil, nil, myBusinesses), nil, 'negócio alheio')
eq(TabletProfile.CanUse(config, nil, false, 'business', nil, nil, nil, myBusinesses), nil, 'app base não é chamável')
eq(TabletProfile.Resolve(config, nil, false, nil, nil, nil, function() return {} end), nil, 'sem negócios')
-- App "Casa" (ownerCheck): só aparece quando o resource confirma que o jogador é dono.
local owner = function(app) return app.resource == 'coe_doors' end
local notOwner = function() return false end
local homeProfile = TabletProfile.Resolve(config, nil, false, nil, nil, owner)
eq(hasApp(homeProfile, 'home'), true, 'dono vê o app Casa')
eq(homeProfile.label, 'Pessoal', 'perfil pessoal')
eq(TabletProfile.Resolve(config, nil, false, nil, nil, notOwner), nil, 'quem não é dono não vê Casa')
eq(TabletProfile.Resolve(config, nil, false, nil, nil, nil), nil, 'sem função de dono')
eq(hasApp(TabletProfile.Resolve(config, { job = { name = 'mechanic', grade = 0 } }, false, nil, nil, owner), 'workshop'), true, 'Casa junto com app de trabalho')
eq(nil ~= TabletProfile.CanUse(config, nil, false, 'home', nil, nil, owner), true, 'CanUse Casa')
eq(nil ~= TabletProfile.CanUse(config, nil, false, 'home', nil, nil, notOwner), false, 'CanUse Casa negado')
-- ownerCheck recebe o id do app (a chave em config.Apps): o resource responde pelo app certo (ex.: Elos, E-mail).
local asked = {}
local byId = function(app, id) asked[id] = true; return id == 'elos' end
local elosProfile = TabletProfile.Resolve(config, nil, false, nil, nil, byId)
eq(hasApp(elosProfile, 'elos'), true, 'Elos aparece quando o resource confirma pelo id')
eq(asked.elos and asked.mail, true, 'cada app com ownerCheck é perguntado pelo próprio id')
-- Atalho /casa: o mesmo tablet (todos os apps do jogador), aberto direto no primeiro app do atalho que ele vê.
local hideoutOwner = function(app) return app.resource == 'coe_housing' end
local both = function() return true end
local mechanic = { job = { name = 'mechanic', grade = 0 } }
local scoped = TabletProfile.Scope(config, TabletProfile.Resolve(config, mechanic, false, nil, nil, hideoutOwner), 'casa')
eq(scoped.launch, 'hideout', 'abre no esconderijo')
eq(hasApp(scoped, 'workshop'), true, 'apps do trabalho continuam no mesmo tablet')
eq(scoped.label, 'Oficina', 'contexto do jogador')
local all = TabletProfile.Scope(config, TabletProfile.Resolve(config, mechanic, true, nil, nil, both), 'casa')
eq(all.launch, 'home', 'Casa primeiro')
eq(all.apps[1].icon, 'home', 'icone vai ao perfil')
local none, denied = TabletProfile.Scope(config, TabletProfile.Resolve(config, mechanic, false, nil, nil, notOwner), 'casa')
eq(none, nil, 'mecanico sem imovel')
eq(denied, config.Shortcuts.casa.deniedMessage, 'mensagem do atalho')
eq(select(2, TabletProfile.Scope(config, nil, 'casa')), config.Shortcuts.casa.deniedMessage, 'sem perfil')
eq(TabletProfile.Scope(config, homeProfile, 'nope'), nil, 'atalho desconhecido')

print('tablet tests passed')
