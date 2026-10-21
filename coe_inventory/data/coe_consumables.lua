local items = [=[
armour cigarette cigarettes_redwood cocaine medikit meth weed
]=]

local registered, errorMessage = Inventory.Items.RegisterImageGroup('consumables', items, {
	items = {
		armour = { animation = 'bandage' },
		cigarette = { animation = 'smoke' },
		cigarettes_redwood = { animation = 'smoke' },
		cocaine = { animation = 'drug' },
		medikit = { animation = 'bandage' },
		meth = { animation = 'drug' },
		weed = { animation = 'smoke' }
	}
})
assert(registered, ('failed to register consumables: %s'):format(errorMessage))
