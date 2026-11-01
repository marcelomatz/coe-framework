-- Isolamento: um negócio não acessa o de outro e um craft não se mistura com outro.
dofile('../coe_crafting/config.lua')
dofile('../coe_crafting/server/rules.lua')
dofile('../coe_crafting/server/registry.lua')
dofile('../coe_crafting/server/service.lua')
dofile('../coe_crafting/server/business.lua')
-- O acesso por negócio é testado em coe_businesses\test\access_test.lua.

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end

local c = CraftingConfig
local registry = CraftingRegistry.New(c)

-- Registro: dono de receitas, bancadas e categorias
local mech = { id = 'brake_pads', label = 'Pastilhas', category = 'mechanic', timeMs = 1000,
	inputs = { { item = 'scrapmetal', count = 1 } }, outputs = { { item = 'part_brake_pads', count = 1 } } }
eq(registry.AddRecipe(mech, 'coe_mechanic') ~= nil, true, 'mecânica registra a sua categoria')
eq(select(2, registry.AddRecipe({ id = 'sneaky', label = 'x', category = 'mechanic', timeMs = 1000,
	inputs = { { item = 'a1', count = 1 } }, outputs = { { item = 'b1', count = 1 } } }, 'coe_businesses')), 'category_forbidden', 'categoria de outro dono')
eq(select(2, registry.AddRecipe({ id = 'brake_pads', label = 'Roubada', category = 'kitchen', timeMs = 1000,
	inputs = { { item = 'a1', count = 1 } }, outputs = { { item = 'b1', count = 1 } } }, 'coe_crafting')), 'id_conflict', 'id de outro dono')
eq(registry.Recipe('brake_pads').label, 'Pastilhas', 'receita original intacta')
eq(registry.RemoveRecipe('brake_pads', 'coe_businesses'), false, 'outro resource não remove')
eq(registry.AddRecipe({ id = 'brake_pads', label = 'v2', category = 'mechanic', timeMs = 1000,
	inputs = { { item = 'scrapmetal', count = 2 } }, outputs = { { item = 'part_brake_pads', count = 1 } } }, 'coe_mechanic') ~= nil, true, 'dono atualiza')
eq(registry.AddRecipe({ id = 'brake_pads', label = 'override', category = 'mechanic', timeMs = 1000,
	inputs = { { item = 'scrapmetal', count = 3 } }, outputs = { { item = 'part_brake_pads', count = 1 } } }, 'coe_admin') ~= nil, true, 'admin sobrescreve')
eq(select(2, registry.AddBench('business_hack', { label = 'x', categories = { 'mechanic' } }, 'coe_mechanic')), 'reserved_bench', 'prefixo reservado')
eq(select(2, registry.AddBench('faction', { label = 'x', categories = { 'illegal' } }, 'coe_factions')), 'reserved_bench', 'faction reservada ao coe_crafting')
eq(select(2, registry.AddBench('illegal', { label = 'x', categories = { 'illegal' } }, 'coe_factions')), 'reserved_bench', 'illegal reservada ao coe_crafting')

for category, def in pairs(c.BusinessBenches) do
	eq(registry.AddBench('business_' .. category, def, 'coe_crafting') ~= nil, true, 'bancada ' .. category)
end
eq(registry.AddBench('faction', c.FactionBench, 'coe_crafting') ~= nil, true, 'bancada faction')
eq(registry.AddBench('illegal', c.IllegalBench, 'coe_crafting') ~= nil, true, 'bancada illegal')
registry.AddBench('mechanic', { label = 'Bancada', categories = { 'mechanic' } }, 'coe_mechanic')
eq(select(2, registry.AddBench('mechanic', { label = 'x', categories = { 'kitchen' } }, 'coe_businesses')), 'id_conflict', 'bancada de outro dono')
for _, recipe in ipairs(c.Recipes) do
	eq(registry.AddRecipe(recipe, 'coe_crafting') ~= nil, true, 'receita ' .. recipe.id)
end

-- Categorias distintas por tipo de negócio
local function ids(benchType)
	local out = {}
	for _, recipe in ipairs(registry.RecipesOf(benchType)) do out[recipe.id] = true end
	return out
end
local kitchen, shop, other, mechanic, illegal = ids('business_restaurant'), ids('business_shop'), ids('business_other'), ids('mechanic'), ids('illegal')
eq(kitchen.kitchen_burger, true, 'restaurante vê cozinha')
eq(kitchen.retail_bandage, nil, 'restaurante não vê loja')
eq(kitchen.brake_pads, nil, 'restaurante não vê mecânica')
eq(kitchen.illegal_lockpick, nil, 'restaurante não vê ilegal')
eq(shop.retail_bandage, true, 'loja vê varejo')
eq(shop.kitchen_burger, nil, 'loja não vê cozinha')
eq(next(other), nil, 'outros não herda receitas de loja')
eq(mechanic.kitchen_burger, nil, 'mecânica não vê cozinha')
eq(mechanic.retail_bandage, nil, 'mecânica não vê loja')
eq(illegal.illegal_lockpick, true, 'bancada ilegal vê receita ilegal')
eq(illegal.kitchen_burger, nil, 'bancada ilegal não vê cozinha')

-- Serviço com inventário falso
local bags = { p1 = {}, p2 = {}, stashA = {}, stashB = {}, facStashA = {}, facStashB = {} }
local service = CraftingService.New({
	registry = registry,
	inventory = {
		count = function(id, item) return bags[id][item] or 0 end,
		remove = function(id, item, n) bags[id][item] = (bags[id][item] or 0) - n return true end,
		add = function(id, item, n) bags[id][item] = (bags[id][item] or 0) + n return true end
	}
})
local function stock(id) bags[id].bread, bags[id].ingredient_meat, bags[id].ingredient_cheese, bags[id].ingredient_potato = 5, 5, 5, 5 end
stock('stashA'); stock('stashB')

local allow = true
local ctxA = { inventoryId = 'p1', stashId = 'stashA', recipes = { kitchen_burger = true }, access = function() return allow end }
local ctxB = { inventoryId = 'p2', stashId = 'stashB', recipes = { kitchen_fries = true }, access = function() return true end }

-- Menu por negócio
local listA = service.List(1, 'business_restaurant', ctxA)
eq(#listA, 1, 'menu A só tem o hambúrguer')
eq(listA[1].id, 'kitchen_burger', 'menu A')
eq(select(2, service.Begin(1, 'business_restaurant', 'kitchen_fries', ctxA)), 'recipe_not_found', 'A não faz o prato de B')
eq(select(2, service.Begin(1, 'business_restaurant', 'retail_bandage', ctxA)), 'recipe_not_found', 'cozinha não faz receita de loja')
eq(select(2, service.Begin(1, 'business_restaurant', 'brake_pads', ctxA)), 'recipe_not_found', 'cozinha não faz mecânica')
eq(select(2, service.Begin(1, 'mechanic', 'kitchen_burger', ctxA)), 'recipe_not_found', 'mecânica não faz cozinha')
eq(#service.List(2, 'business_restaurant', ctxB), 1, 'menu B')

-- Baú: o craft de A consome o baú de A e nunca o de B
eq(service.Begin(1, 'business_restaurant', 'kitchen_burger', ctxA) ~= nil, true, 'A inicia')
eq(service.Complete(1) ~= nil, true, 'A conclui')
eq(bags.stashA.bread, 4, 'baú A consumido')
eq(bags.stashB.bread, 5, 'baú B intacto')
eq(bags.p1.burger, 1, 'produto vai para quem produziu')
eq(bags.p2.burger, nil, 'outro jogador não recebe')

-- Acesso perdido: bloqueia no início e no fim
allow = false
eq(select(2, service.Begin(1, 'business_restaurant', 'kitchen_burger', ctxA)), 'forbidden', 'sem acesso não inicia')
allow = true
service.Begin(1, 'business_restaurant', 'kitchen_burger', ctxA)
allow = false
eq(select(2, service.Complete(1)), 'forbidden', 'perdeu o acesso durante o craft')
eq(bags.stashA.bread, 4, 'nada consumido sem acesso')
allow = true

-- Bancada de facção (#169): receitas dinâmicas por grau e revalidação por receita em Begin e Complete
local memberGrade = 0
local factionCrafts = { illegal_lockpick = 0, illegal_armour = 2 }
bags.facStashA = { cloth = 4, scrapmetal = 4, rubber = 2, plastic = 2 }
bags.facStashB = { cloth = 10, scrapmetal = 10, rubber = 10, plastic = 10 }
local facCtx = {
	inventoryId = 'p1',
	stashId = 'facStashA',
	recipes = function()
		local unlocked = {}
		for recipeId, minGrade in pairs(factionCrafts) do
			if memberGrade >= minGrade then
				unlocked[#unlocked + 1] = recipeId
			end
		end
		return unlocked
	end,
	access = function(_, recipeId)
		if memberGrade < 0 then
			return false, 'not_member'
		end
		if recipeId ~= nil then
			local minGrade = factionCrafts[recipeId]
			if not minGrade or memberGrade < minGrade then
				return false, 'grade_too_low'
			end
		end
		return true
	end
}
eq(#service.List(1, 'faction', facCtx), 1, 'grau 0 só vê receita de grau 0')
eq(select(2, service.Begin(1, 'faction', 'illegal_armour', facCtx)), 'grade_too_low', 'grau 0 bloqueado em receita de grau 2')
memberGrade = 2
eq(#service.List(1, 'faction', facCtx), 2, 'grau 2 vê as duas receitas')
eq(service.Begin(1, 'faction', 'illegal_armour', facCtx) ~= nil, true, 'grau 2 inicia colete')
memberGrade = 0 -- rebaixado durante a produção
eq(select(2, service.Complete(1)), 'grade_too_low', 'rebaixamento durante o craft bloqueia a entrega')
eq(bags.facStashA.cloth, 4, 'baú da facção intacto após bloqueio')
memberGrade = 2
eq(service.Begin(1, 'faction', 'illegal_armour', facCtx) ~= nil, true, 'inicia colete novamente')
eq(service.Complete(1).id, 'illegal_armour', 'conclui colete')
eq(bags.facStashA.cloth, 0, 'consumiu do baú da facção A')
eq(bags.facStashB.cloth, 10, 'baú da facção B intacto')
eq(bags.p1.armour, 1, 'colete entregue ao membro')

-- Bancada ilegal livre (#161): aberta a qualquer jogador, consome apenas do jogador (sem baú)
bags.p2 = { plastic = 2 }
local illegalCtx = { inventoryId = 'p2', stashId = 'facStashB', recipes = { illegal_ziptie = true } }
eq(#service.List(2, 'illegal', illegalCtx), 1, 'bancada ilegal lista receitas permitidas')
eq(select(2, service.Begin(2, 'illegal', 'illegal_lockpick', illegalCtx)), 'recipe_not_found', 'bancada ilegal respeita filtro de receitas')
eq(select(2, service.Begin(2, 'illegal', 'illegal_lockpick', { inventoryId = 'p2', stashId = 'facStashB' })), 'missing_items', 'bancada ilegal não usa baú nem para checar')
eq(service.Begin(2, 'illegal', 'illegal_ziptie', illegalCtx) ~= nil, true, 'qualquer jogador inicia na bancada ilegal')
eq(service.Complete(2).id, 'illegal_ziptie', 'conclui na bancada ilegal')
eq(bags.p2.plastic, 0, 'consumiu plástico da mochila do jogador')
eq(bags.p2.ziptie, 2, 'abraçadeiras entregues na mochila')

-- Estações e baú carregam o id do negócio
local sa = CraftingBusiness.Stations({ id = 'rest_a', enabled = true, category = 'restaurant',
	stations = { crafts = { { id = 'c1', x = 1, y = 1, z = 1, radius = 1 } } } }, c.BusinessBenches)
eq(sa[1].businessId, 'rest_a', 'estação aponta para o negócio')
eq(CraftingBusiness.StashId('rest_a', 'c1') ~= CraftingBusiness.StashId('rest_b', 'c1'), true, 'baús distintos por negócio')

print('isolation_test ok')
