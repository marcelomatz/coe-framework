-- Ingredientes e materiais usados nas bancadas de restaurante e lojinha do coe_crafting.
-- Arte própria dedicada no formato WebP e PNG do COE Framework.
local items = [=[
ingredient_meat ingredient_potato ingredient_dough ingredient_cheese cloth
]=]

local registered, errorMessage = Inventory.Items.RegisterImageGroup('misc', items, {
	items = {
		ingredient_meat = { label = 'Carne', weight = 300 },
		ingredient_potato = { label = 'Batata', weight = 200 },
		ingredient_dough = { label = 'Massa', weight = 250 },
		ingredient_cheese = { label = 'Queijo', weight = 150 },
		cloth = { label = 'Tecido', weight = 100 }
	}
})
assert(registered, ('failed to register ingredient items: %s'):format(errorMessage))
