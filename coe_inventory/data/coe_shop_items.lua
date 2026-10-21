-- Produtos das lojas de conveniência (coe_shops): comida, bebidas, bebidas alcoólicas e saúde.
-- Efeitos de fome, sede e estresse ficam no coe_needs (Config.Needs.ItemEffects).
local food = [=[
sandwich chips chocolate cereal_bar ecola coffee energy_drink beer whiskey vodka
]=]

local registered, errorMessage = Inventory.Items.RegisterImageGroup('food', food, {
	items = {
		sandwich = { label = 'Sanduíche', weight = 300 },
		chips = { label = 'Salgadinho', weight = 150 },
		chocolate = { label = 'Barra de chocolate', weight = 100 },
		cereal_bar = { label = 'Barra de cereal', weight = 80 },
		ecola = { label = 'eCola', weight = 350, animation = 'drink' },
		coffee = { label = 'Café', weight = 300, animation = 'drink' },
		energy_drink = { label = 'Energético', weight = 350, animation = 'drink' },
		beer = { label = 'Cerveja', weight = 500, animation = 'drink' },
		whiskey = { label = 'Uísque', weight = 900, animation = 'drink' },
		vodka = { label = 'Vodca', weight = 900, animation = 'drink' }
	}
})
assert(registered, ('failed to register shop food: %s'):format(errorMessage))

registered, errorMessage = Inventory.Items.RegisterImageGroup('consumables', 'painkillers', {
	items = {
		painkillers = { label = 'Analgésico', weight = 50, animation = 'drink' }
	}
})
assert(registered, ('failed to register shop consumables: %s'):format(errorMessage))

-- Galão de combustível (coe_fuel): metadata { fuel, liters }. Comprado cheio na bomba; usar despeja no veículo
-- mais perto. Não é consumido ao usar (o coe_fuel baixa os litros).
registered, errorMessage = Inventory.Items.RegisterImageGroup('misc', 'fuel_can', {
	items = {
		fuel_can = { label = 'Galão de combustível', weight = 3000, stack = false, usable = true, consume = 0, maxStack = 1, metadata = { fuel = 'empty', liters = 0 } }
	}
})
assert(registered, ('failed to register fuel can: %s'):format(errorMessage))
