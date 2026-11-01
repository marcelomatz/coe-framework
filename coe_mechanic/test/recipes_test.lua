dofile('../coe_mechanic/config.lua')
dofile('../coe_crafting/config.lua')
dofile('../coe_crafting/server/rules.lua')

local function eq(a, b, m)
	if a ~= b then error(('%s: esperado %s, veio %s'):format(m, tostring(b), tostring(a)), 2) end
end

-- As receitas da mecânica precisam ser aceitas pelo coe_crafting.
local seen = {}
for _, recipe in ipairs(CoeMechanicConfig.Recipes.mechanic) do
	local clean, errorCode = CraftingRules.Recipe(recipe, CraftingConfig)
	eq(errorCode, nil, 'receita ' .. tostring(recipe.id))
	eq(clean.category, 'mechanic', 'categoria ' .. recipe.id)
	eq(seen[recipe.id], nil, 'id repetido ' .. recipe.id)
	seen[recipe.id] = true
end
eq(seen.brake_pads, true, 'pastilhas existem')

print('recipes_test ok')
