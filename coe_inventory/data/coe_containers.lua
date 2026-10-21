local items = [=[
paperbag WEAPON_BRIEFCASE WEAPON_BRIEFCASE_02 WEAPON_GARBAGEBAG
]=]

local registered, errorMessage = Inventory.Items.RegisterImageGroup('containers', items, {
	containers = {
		paperbag = { slots = 6, maxWeight = 5000 },
		WEAPON_BRIEFCASE = { slots = 18, maxWeight = 20000 },
		WEAPON_BRIEFCASE_02 = { slots = 30, maxWeight = 40000 },
		WEAPON_GARBAGEBAG = { slots = 10, maxWeight = 10000 }
	}
})
assert(registered, ('failed to register containers: %s'):format(errorMessage))
