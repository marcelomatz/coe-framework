local items = [=[
advancedkit black_money bandage card_bank card_id carkey garbage key lockpick money
oldkey panties parachute phone radio scrapmetal trash trash_bread trash_burger trash_can
trash_chips usb_black water ziptie
]=]

local registered, errorMessage = Inventory.Items.RegisterImageGroup('misc', items, {
	items = {
		advancedkit = { usable = true, animation = 'repair' },
		black_money = { weight = 0, maxStack = 1000000000 },
		card_bank = { stack = false, maxStack = 1 },
		card_id = { stack = false, maxStack = 1 },
		carkey = { stack = false, maxStack = 1 },
		key = { stack = false, maxStack = 1 },
		-- Espécie: cada unidade é $1; sem peso e em pilha grande para saques do banco e ajustes caberem.
		money = { weight = 0, maxStack = 1000000000 },
		oldkey = { stack = false, maxStack = 1 },
		parachute = { stack = false, maxStack = 1 },
		phone = { stack = false, maxStack = 1 },
		radio = { stack = false, maxStack = 1 },
		usb_black = { stack = false, maxStack = 1 },
		-- Água: bebível (sede no coe_needs), vendida nas lojas do coe_shops.
		water = { label = 'Água', usable = true, consume = 1, animation = 'drink', weight = 500 },
		ziptie = { stack = false, maxStack = 1 }
	}
})
assert(registered, ('failed to register miscellaneous items: %s'):format(errorMessage))
