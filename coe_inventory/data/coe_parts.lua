-- Materiais e peças de oficina usados na bancada de craft do coe_mechanic.
-- Arte própria dedicada no formato WebP e PNG do COE Framework.
local items = [=[
rubber plastic repair_kit part_engine_oil part_air_filter part_spark_plugs part_brake_pads
part_brake_discs part_clutch part_suspension
]=]

local registered, errorMessage = Inventory.Items.RegisterImageGroup('misc', items, {
	items = {
		rubber = { label = 'Borracha', weight = 300 },
		plastic = { label = 'Plástico', weight = 200 },
		repair_kit = { label = 'Kit de reparo', weight = 1500 },
		part_engine_oil = { label = 'Óleo de motor', weight = 900 },
		part_air_filter = { label = 'Filtro de ar', weight = 400 },
		part_spark_plugs = { label = 'Velas de ignição', weight = 300 },
		part_brake_pads = { label = 'Pastilhas de freio', weight = 800 },
		part_brake_discs = { label = 'Discos de freio', weight = 3000 },
		part_clutch = { label = 'Kit de embreagem', weight = 4000 },
		part_suspension = { label = 'Kit de suspensão', weight = 6000 }
	}
})
assert(registered, ('failed to register workshop items: %s'):format(errorMessage))
