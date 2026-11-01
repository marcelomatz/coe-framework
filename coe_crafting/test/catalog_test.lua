dofile('../coe_crafting/config.lua')
dofile('../coe_crafting/server/rules.lua')
dofile('../coe_crafting/server/registry.lua')
dofile('../coe_crafting/server/catalog.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end

local config = CraftingConfig
local registry = CraftingRegistry.New(config)
for category, def in pairs(config.BusinessBenches) do
	registry.AddBench('business_' .. category, def, 'coe_crafting')
end
for _, recipe in ipairs(config.Recipes) do
	registry.AddRecipe(recipe, 'coe_crafting')
end
registry.AddBench('mechanic', { label = 'Oficina', categories = { 'mechanic' } }, 'coe_mechanic')
registry.AddRecipe({ id = 'brake_pads', label = 'Pastilhas', category = 'mechanic', timeMs = 7000,
	inputs = { { item = 'scrapmetal', count = 1 } }, outputs = { { item = 'part', count = 1 } } }, 'coe_mechanic')

local stored, failSave = {}, false
local store = {
	save = function(kind, id, data)
		if failSave then return nil, 'database_error' end
		stored[kind .. ':' .. id] = data
		return true
	end,
	delete = function(kind, id)
		stored[kind .. ':' .. id] = nil
		return true
	end
}
local known = { bread = true, ingredient_cheese = true, ingredient_dough = true, pizza_cheese = true, burger = true }
local catalog = CraftingCatalog.New({
	config = config, registry = registry, owner = 'coe_crafting', store = store,
	itemExists = function(name) return known[name] == true end
})

local function recipe(extra)
	local r = { id = 'pizza_cheese', label = 'Pizza de queijo', category = 'kitchen', timeMs = 6000,
		inputs = { { item = 'ingredient_dough', count = 1 }, { item = 'ingredient_cheese', count = 2 } },
		outputs = { { item = 'pizza_cheese', count = 1 } } }
	for k, v in pairs(extra or {}) do r[k] = v end
	return r
end

-- Receitas próprias
eq(catalog.SaveRecipe(recipe()).id, 'pizza_cheese', 'cria receita')
eq(registry.Recipe('pizza_cheese').label, 'Pizza de queijo', 'registrada')
eq(stored['recipe:pizza_cheese'] ~= nil, true, 'persistida')
eq(select(2, catalog.SaveRecipe(recipe({ id = 'kitchen_burger' }))), 'reserved_recipe', 'receita do config não é editável')
eq(select(2, catalog.SaveRecipe(recipe({ id = 'brake_pads' }))), 'id_conflict', 'receita de outro resource')
eq(select(2, catalog.SaveRecipe(recipe({ id = 'x2', category = 'mechanic' }))), 'invalid_recipe_category', 'categoria fora do painel')
eq(select(2, catalog.SaveRecipe(recipe({ id = 'x3', outputs = { { item = 'nada', count = 1 } } }))), 'unknown_item', 'item inexistente')
eq(select(2, catalog.SaveRecipe(recipe({ id = 'x4', label = '<b>' }))), 'invalid_recipe_label', 'nome com HTML')
failSave = true
eq(select(2, catalog.SaveRecipe(recipe({ id = 'x5' }))), 'database_error', 'falha no banco')
eq(registry.Recipe('x5'), nil, 'falha não registra')
failSave = false

-- Tipos de cardápio
local pizzaria = { id = 'pizzaria', label = 'Pizzaria', category = 'restaurant', recipes = { 'pizza_cheese', 'kitchen_pizza', 'pizza_cheese' } }
local menu = catalog.SaveMenu(pizzaria)
eq(#menu.recipes, 2, 'sem repetição')
eq(select(2, catalog.SaveMenu({ id = 'p2', label = 'X', category = 'restaurant', recipes = { 'retail_bandage' } })), 'invalid_menu_recipes', 'receita de outra bancada')
eq(select(2, catalog.SaveMenu({ id = 'p3', label = 'X', category = 'mechanic', recipes = {} })), 'invalid_menu_category', 'categoria sem bancada')
eq(select(2, catalog.SaveMenu({ id = 'p4', label = 'X', category = 'restaurant', recipes = { 'nao_existe' } })), 'invalid_menu_recipes', 'receita inexistente')

-- Cardápio do negócio
local biz = { id = 'pizza_place', category = 'restaurant' }
eq(catalog.RecipesFor(biz), nil, 'sem cardápio: todas da bancada')
eq(catalog.SetBusinessMenu(biz, { menu = 'pizzaria' }), true, 'escolhe o tipo')
eq(#catalog.RecipesFor(biz), 2, 'usa o cardápio do tipo')
eq(catalog.SetBusinessMenu(biz, { menu = 'pizzaria', recipes = { 'kitchen_fries' } }), true, 'ajusta o cardápio')
eq(catalog.RecipesFor(biz)[1], 'kitchen_fries', 'lista ajustada vale no lugar do tipo')
eq(select(2, catalog.SetBusinessMenu({ id = 'shop1', category = 'shop' }, { menu = 'pizzaria' })), 'unknown_menu', 'tipo de outra categoria')
eq(select(2, catalog.SetBusinessMenu({ id = 'm1', category = 'mechanic' }, { menu = 'pizzaria' })), 'unknown_business', 'negócio sem bancada')
eq(catalog.RecipesFor({ id = 'pizza_place', category = 'shop' }), nil, 'negócio que mudou de categoria ignora o cardápio')
eq(catalog.SetBusinessMenu(biz, {}), true, 'limpa o cardápio')
eq(stored['business:pizza_place'], nil, 'remove do banco')
eq(catalog.RecipesFor(biz), nil, 'volta a todas')

-- Remoções
eq(select(2, catalog.DeleteRecipe('kitchen_burger')), 'unknown_recipe', 'não remove receita do config')
eq(catalog.DeleteRecipe('pizza_cheese'), true, 'remove receita própria')
eq(registry.Recipe('pizza_cheese'), nil, 'sai do registro')
eq(catalog.DeleteMenu('pizzaria'), true, 'remove tipo')

-- Bancadas ilegais livres
local savedBench = catalog.SaveBench({
	id = 'beco_sul', label = 'Bancada do beco', enabled = true,
	x = 120.5, y = -1400.0, z = 29.2, radius = 2.0,
	recipes = { 'illegal_lockpick', 'illegal_lockpick' }
})
eq(savedBench.id, 'beco_sul', 'salva bancada ilegal')
eq(#savedBench.recipes, 1, 'deduplica receitas da bancada ilegal')
eq(catalog.Bench('beco_sul').label, 'Bancada do beco', 'busca bancada ilegal')
eq(#catalog.Benches(), 1, 'lista bancadas ilegais')
eq(select(2, catalog.SaveBench({ id = 'bad id', label = 'X', x = 1, y = 2, z = 3 })), 'invalid_bench_id', 'id inválido de bancada')
eq(select(2, catalog.SaveBench({ id = 'b2', label = '<x>', x = 1, y = 2, z = 3 })), 'invalid_bench_label', 'label inválido de bancada')
eq(select(2, catalog.SaveBench({ id = 'b2', label = 'B2', x = 99999, y = 2, z = 3 })), 'invalid_bench_coords', 'coordenada fora do limite')
eq(select(2, catalog.SaveBench({ id = 'b2', label = 'B2', x = 1, y = 2, z = 3, radius = 20 })), 'invalid_bench_coords', 'raio fora do limite')
eq(select(2, catalog.SaveBench({ id = 'b2', label = 'B2', x = 1, y = 2, z = 3, recipes = { 'kitchen_burger' } })), 'invalid_bench_recipes', 'bancada ilegal rejeita receita de cozinha')
eq(catalog.DeleteBench('beco_sul'), true, 'remove bancada ilegal')
eq(catalog.Bench('beco_sul'), nil, 'bancada removida')
eq(select(2, catalog.DeleteBench('beco_sul')), 'unknown_bench', 'bancada inexistente')

-- Carga do banco
local registry2 = CraftingRegistry.New(config)
for category, def in pairs(config.BusinessBenches) do
	registry2.AddBench('business_' .. category, def, 'coe_crafting')
end
for _, r in ipairs(config.Recipes) do
	registry2.AddRecipe(r, 'coe_crafting')
end
local loaded = CraftingCatalog.New({ config = config, registry = registry2, owner = 'coe_crafting', store = store,
	itemExists = function() return true end })
local skipped = loaded.Load({
	{ kind = 'recipe', id = 'pizza_cheese', data = recipe() },
	{ kind = 'recipe', id = 'kitchen_burger', data = recipe({ id = 'kitchen_burger' }) },
	{ kind = 'menu', id = 'pizzaria', data = { label = 'Pizzaria', category = 'restaurant', recipes = { 'pizza_cheese' } } },
	{ kind = 'business', id = 'pizza_place', data = { menu = 'pizzaria', category = 'restaurant' } },
	{ kind = 'bench', id = 'doca', data = { label = 'Bancada da doca', enabled = true, x = 10, y = 20, z = 30, radius = 1.5, recipes = { 'illegal_lockpick' } } },
	{ kind = 'bench', id = 'invalida', data = { label = 'Invalida', x = 10, y = 20, z = 30, recipes = { 'kitchen_burger' } } }
})
eq(#skipped, 2, 'receita reservada e bancada inválida ignoradas na carga')
eq(registry2.Recipe('pizza_cheese') ~= nil, true, 'receita carregada')
eq(loaded.RecipesFor(biz)[1], 'pizza_cheese', 'cardápio carregado')
eq(loaded.Bench('doca').label, 'Bancada da doca', 'bancada ilegal carregada')
local admin = loaded.Admin()
eq(#admin.menus, 1, 'admin lista tipos')
eq(#admin.illegalBenches, 1, 'admin lista bancadas ilegais')
local custom = 0
for _, entry in ipairs(admin.recipes) do
	if entry.custom then custom = custom + 1 end
end
eq(custom, 1, 'admin marca receitas próprias')
print('ok catalog')
