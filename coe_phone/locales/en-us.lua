Locales = (type(Locales) == 'table' and Locales) or {}

Locales['en-US'] = {
	missed_call = 'Missed call from %{caller}.',
	new_message = 'New message from %{sender}.',
	no_phone = 'You do not have a phone.',
	no_device = 'This phone does not work.',
	inventory_unavailable = 'Inventory did not respond. Please try again.',
	number_unavailable = 'Could not generate a phone number right now.',
	no_character = 'Select a character first.',
	not_ready = 'Phone is still starting.',
	phone_unavailable = 'Phone is not available right now.',
	invalid_sim = 'This SIM card does not work.',
	in_call = 'End your call before switching the SIM card.',
	no_free_sim_slot = 'No free SIM slot in this phone. Remove the current one in Settings.',
	slot_changed = 'The SIM card is no longer in this inventory slot.',
	sim_place_failed = 'Could not insert SIM card.',
	sim_placed = 'SIM card %{number} inserted into phone.'
}
