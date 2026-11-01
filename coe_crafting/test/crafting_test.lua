dofile('../coe_crafting/config.lua')
dofile('../coe_crafting/server/rules.lua')
dofile('../coe_crafting/server/registry.lua')
dofile('../coe_crafting/server/service.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end

local c = CraftingConfig
local function recipe(extra)
	local r = {
		id = 'brake_pads', label = 'Pastilhas', category = 'mechanic', timeMs = 7000,
		inputs = { { item = 'scrapmetal', count = 3 }, { item = 'rubber', count = 1 } },
		outputs = { { item = 'part_brake_pads', count = 1 } }
	}
	for k, v in pairs(extra or {}) do r[k] = v end
	return r
end

-- Regras
eq(CraftingRules.Recipe(recipe(), c).id, 'brake_pads', 'receita valida')
eq(select(2, CraftingRules.Recipe(recipe({ id = 'x y' }), c)), 'invalid_recipe_id', 'id invalido')
eq(select(2, CraftingRules.Recipe(recipe({ timeMs = 10 }), c)), 'invalid_recipe_time', 'tempo curto')
eq(select(2, CraftingRules.Recipe(recipe({ inputs = {} }), c)), 'invalid_recipe_inputs', 'sem insumos')
eq(select(2, CraftingRules.Recipe(recipe({ outputs = { { item = 'a1', count = 0 } } }), c)), 'invalid_recipe_outputs', 'saida zero')
eq(select(2, CraftingRules.Recipe(recipe({ inputs = { { item = 'ab', count = 1 }, { item = 'ab', count = 2 } } }), c)), 'invalid_recipe_inputs', 'insumo repetido')
eq(select(2, CraftingRules.Recipe(recipe({ inputs = { { item = 'ab', count = 1.5 } } }), c)), 'invalid_recipe_inputs', 'fracao')
eq(select(2, CraftingRules.Bench({ label = 'B', categories = { 'mechanic' }, source = 'x' }, c)), 'invalid_bench_source', 'origem invalida')
eq(select(2, CraftingRules.Bench({ label = 'B', categories = {} }, c)), 'invalid_bench_categories', 'sem categorias')
eq(CraftingRules.Bench({ label = 'B', categories = { 'mechanic' } }, c).source, 'player', 'origem padrao')
eq(select(2, CraftingRules.Bench({ label = 'B', categories = { 'mechanic' }, animation = { dict = 1 } }, c)), 'invalid_bench_animation', 'animacao invalida')
eq(CraftingRules.Bench({ label = 'B', categories = { 'mechanic' }, animation = { dict = 'd', name = 'n' } }, c).animation.name, 'n', 'animacao valida')

-- Registro
-- Aqui as categorias são livres; as travas de dono ficam em isolation_test.lua.
local free = {}
for k, v in pairs(c) do free[k] = v end
free.CategoryOwners = {}
local registry = CraftingRegistry.New(free)
eq(select(2, registry.AddBench('Bad Type', { label = 'x', categories = { 'mechanic' } })), 'invalid_bench_type', 'tipo invalido')
eq(select(2, registry.RecipesOf('nada')), 'bench_not_found', 'bancada inexistente')
registry.AddBench('mechanic', { label = 'Bancada', categories = { 'mechanic' } })
registry.AddBench('kitchen', { label = 'Cozinha', categories = { 'kitchen' }, source = 'stash', output = 'stash' })
registry.AddRecipe(recipe())
registry.AddRecipe(recipe({ id = 'burger', label = 'Hamburguer', category = 'kitchen', timeMs = 3000,
	inputs = { { item = 'bread', count = 1 }, { item = 'meat', count = 1 } }, outputs = { { item = 'burger', count = 2 } } }))
eq(#registry.RecipesOf('mechanic'), 1, 'filtra por categoria')
eq(registry.RecipesOf('kitchen')[1].id, 'burger', 'receita da cozinha')
registry.AddRecipe(recipe({ label = 'Pastilhas v2' }))
eq(registry.Recipe('brake_pads').label, 'Pastilhas v2', 'override')
eq(#registry.RecipesOf('mechanic'), 1, 'override nao duplica')

-- Servico
local bags = { inv = { scrapmetal = 10, rubber = 5 }, stash = { bread = 3, meat = 1 } }
local failAdd, audits = nil, {}
local function bag(id) bags[id] = bags[id] or {}; return bags[id] end
local service = CraftingService.New({
	registry = registry,
	audit = function(event, ctx) audits[#audits + 1] = event end,
	inventory = {
		count = function(id, item) return bag(id)[item] or 0 end,
		remove = function(id, item, n)
			if (bag(id)[item] or 0) < n then return false, 'insufficient_items' end
			bag(id)[item] = bag(id)[item] - n
			return true
		end,
		add = function(id, item, n)
			if failAdd and failAdd.item == item then return false, failAdd.error end
			bag(id)[item] = (bag(id)[item] or 0) + n
			return true
		end
	}
})
local ctx = { inventoryId = 'inv', stashId = 'stash' }

eq(select(2, service.Begin(1, 'nada', 'brake_pads', ctx)), 'bench_not_found', 'bancada desconhecida')
eq(select(2, service.Begin(1, 'mechanic', 'burger', ctx)), 'recipe_not_found', 'receita de outra categoria')
eq(select(2, service.Begin(1, 'mechanic', 'brake_pads', nil)), 'invalid_context', 'sem contexto')
eq(select(2, service.Begin(1, 'mechanic', 'brake_pads', { inventoryId = 'inv', access = function() return false end })), 'forbidden', 'sem acesso')
eq(select(2, service.Begin(1, 'kitchen', 'burger', { inventoryId = 'inv' })), 'no_container', 'cozinha sem bau')

local list = service.List(1, 'mechanic', ctx)
eq(list[1].inputs[1].have, 10, 'mostra o que tem')
eq(list[1].inputs[2].need, 1, 'mostra o que precisa')

eq(service.Begin(1, 'mechanic', 'brake_pads', ctx).id, 'brake_pads', 'comeca')
eq(service.Busy(1), true, 'ocupado')
eq(select(2, service.Begin(1, 'mechanic', 'brake_pads', ctx)), 'craft_busy', 'uma por vez')
eq(service.Complete(1).id, 'brake_pads', 'conclui')
eq(bags.inv.scrapmetal, 7, 'consome sucata')
eq(bags.inv.part_brake_pads, 1, 'entrega')
eq(audits[1], 'craft_completed', 'audita')
eq(select(2, service.Complete(1)), 'no_craft_in_progress', 'nao conclui sem comecar')

-- Itens sumiram na espera
service.Begin(2, 'mechanic', 'brake_pads', ctx)
bags.inv.rubber = 0
eq(select(2, service.Complete(2)), 'missing_items', 'faltou na conclusao')
eq(bags.inv.scrapmetal, 7, 'nada consumido')
bags.inv.rubber = 4

-- Sem espaco: devolve
service.Begin(3, 'mechanic', 'brake_pads', ctx)
failAdd = { item = 'part_brake_pads', error = 'inventory_full' }
eq(select(2, service.Complete(3)), 'inventory_full', 'inventario cheio')
eq(bags.inv.scrapmetal, 7, 'sucata devolvida')
eq(bags.inv.rubber, 4, 'borracha devolvida')
failAdd = nil

-- Origem so no bau, saida no bau, varias saidas
eq(select(2, service.Begin(4, 'kitchen', 'burger', ctx)), nil, 'cozinha comeca')
eq(service.Complete(4).id, 'burger', 'cozinha conclui')
eq(bags.stash.bread, 2, 'consome do bau')
eq(bags.stash.burger, 2, 'entrega no bau')
eq(bags.inv.burger, nil, 'nada no jogador')

-- Origem "both": completa o que falta com o bau
registry.AddBench('both', { label = 'Mista', categories = { 'kitchen' }, source = 'both' })
bags.inv.bread = 1
bags.stash.bread = 2
bags.stash.meat = 0
bags.inv.meat = 1
service.Begin(5, 'both', 'burger', ctx)
service.Complete(5)
eq(bags.inv.bread, 0, 'usa jogador primeiro')
eq(bags.stash.bread, 2, 'bau intacto')
eq(bags.inv.burger, 2, 'saida padrao no jogador')

-- Falha na segunda saida desfaz a primeira
registry.AddRecipe({ id = 'combo', label = 'Combo', category = 'kitchen', timeMs = 1000,
	inputs = { { item = 'bread', count = 1 } }, outputs = { { item = 'bun', count = 1 }, { item = 'sauce', count = 1 } } })
service.Begin(6, 'both', 'combo', ctx)
failAdd = { item = 'sauce', error = 'inventory_full' }
eq(select(2, service.Complete(6)), 'inventory_full', 'segunda saida falha')
eq(bags.inv.bun or 0, 0, 'primeira saida desfeita')
eq(bags.stash.bread, 2, 'insumo devolvido ao mesmo container')
failAdd = nil

bags.inv.rubber = 0
eq(select(2, service.Begin(7, 'mechanic', 'brake_pads', { inventoryId = 'inv', stashId = 'stash' })), 'missing_items', 'sem materiais')
bags.inv.rubber = 4
service.Begin(8, 'mechanic', 'brake_pads', ctx)
service.Drop(8)
eq(service.Busy(8), false, 'saida libera')

print('crafting_test ok')
