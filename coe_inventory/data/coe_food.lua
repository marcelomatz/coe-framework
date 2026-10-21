local items = [=[
burger burger_chicken donut fries mustard pizza_ham pizza_ham_box pizza_ham_slice sprunk
]=]

local registered, errorMessage = Inventory.Items.RegisterImageGroup('food', items, {
	items = {
		pizza_ham_box = { usable = false, consume = 0, animation = nil },
		sprunk = { animation = 'drink' }
	}
})
assert(registered, ('failed to register food: %s'):format(errorMessage))
