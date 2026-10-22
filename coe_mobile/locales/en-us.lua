Locales = (type(Locales) == 'table' and Locales) or {}

Locales['en-US'] = {
	not_ready = 'The phone is still starting up.',
	unavailable = 'Service unavailable.',
	busy = 'Please wait a moment.',
	no_character = 'Character not loaded.',
	no_phone = 'You do not have your phone.',
	invalid_number = 'Invalid number.',
	number_not_found = 'This number does not exist.',
	number_exhausted = 'No free numbers left. Tell the staff.',
	unreachable = 'Out of coverage or switched off.',
	line_busy = 'Line busy.',
	already_in_call = 'You are already on a call.',
	not_in_call = 'The call has already ended.',
	invalid_name = 'Invalid name.',
	invalid_message = 'Message is empty or too long.',
	contacts_full = 'Your contact list is full.',
	duplicate_contact = 'This number is already in your contacts.',
	contact_not_found = 'Contact not found.',
	database_error = 'Lookup failed. Try again.',
	generic_error = 'Could not complete.',
	incoming_call = 'Call from %{name}.',
	missed_call = 'Missed call from %{name}.'
}
