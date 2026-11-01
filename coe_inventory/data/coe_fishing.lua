-- Equipamento de pesca (coe_jobs, emprego de pescador): vendido na loja de pesca. Usar a vara de frente para a
-- água dentro de uma área de pesca lança a linha; usar uma isca escolhe qual vai no anzol. Nenhum dos dois é
-- consumido ao usar: a isca sai do inventário no lance (o coe_jobs remove). Bônus e níveis em coe_jobs/jobs/fisher.lua.
local registered, errorMessage = Inventory.Items.RegisterImageGroup('misc', 'fishing_rod fishing_rod_fiber fishing_rod_carbon', {
	items = {
		fishing_rod = { label = 'Vara de bambu', weight = 900, stack = false, maxStack = 1, usable = true, consume = 0, close = true },
		fishing_rod_fiber = { label = 'Vara de fibra', weight = 800, stack = false, maxStack = 1, usable = true, consume = 0, close = true },
		fishing_rod_carbon = { label = 'Vara de carbono', weight = 650, stack = false, maxStack = 1, usable = true, consume = 0, close = true }
	}
})
assert(registered, ('failed to register fishing rods: %s'):format(errorMessage))

registered, errorMessage = Inventory.Items.RegisterImageGroup('misc', 'bait_bread bait_worm bait_shrimp bait_lure', {
	items = {
		bait_bread = { label = 'Isca de pão', weight = 10, maxStack = 100, usable = true, consume = 0, close = true },
		bait_worm = { label = 'Minhoca', weight = 10, maxStack = 100, usable = true, consume = 0, close = true },
		bait_shrimp = { label = 'Camarão (isca)', weight = 20, maxStack = 100, usable = true, consume = 0, close = true },
		bait_lure = { label = 'Isca artificial', weight = 40, maxStack = 10, usable = true, consume = 0, close = true }
	}
})
assert(registered, ('failed to register fishing baits: %s'):format(errorMessage))
