Locales = (type(Locales) == 'table' and Locales) or {}

Locales['en-US'] = {
	call_sent = 'Call dispatched.',
	call_accepted = 'Call accepted. Waypoint set on map.',
	call_closed = 'Call closed.',
	calls_none = 'No active calls.',
	calls_prefix = 'Calls: %{list}',
	generic_error = 'Could not complete the action.',
	err_invalid_code = 'Invalid call code.',
	err_invalid_coords = 'Invalid position coordinates.',
	err_too_many_calls = 'Dispatch center overloaded.',
	err_not_on_duty = 'Clock in at a police station or hospital first.',
	err_unknown_call = 'Call not found.',
	err_invalid_call = 'Invalid call number.',
	err_cooldown = 'Please wait before placing another call.',
	err_no_character = 'No active character.',
	err_forbidden = 'Forbidden.'
}
