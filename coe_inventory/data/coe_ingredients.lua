-- Ingredientes e materiais usados nas bancadas de restaurante e lojinha do coe_crafting.
-- Sem arte própria ainda: reaproveitam imagens existentes.
local items = [=[
ingredient_meat ingredient_potato ingredient_dough ingredient_cheese cloth
]=]

local registered, errorMessage = Inventory.Items.RegisterImageGroup('misc', items, {
	images = {
		ingredient_meat = 'burger.png', ingredient_potato = 'fries.png', ingredient_dough = 'donut.png',
		ingredient_cheese = 'donut.png', cloth = 'bandage.png'
	},
	items = {
		ingredient_meat = { label = 'Carne', weight = 300 },
		ingredient_potato = { label = 'Batata', weight = 200 },
		ingredient_dough = { label = 'Massa', weight = 250 },
		ingredient_cheese = { label = 'Queijo', weight = 150 },
		cloth = { label = 'Tecido', weight = 100 }
	}
})
assert(registered, ('failed to register ingredient items: %s'):format(errorMessage))
