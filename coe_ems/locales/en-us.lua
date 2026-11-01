Locales = (type(Locales) == 'table' and Locales) or {}

Locales['en-US'] = {
	unconscious_notify = 'You are unconscious. Wait for emergency services.',
	dead_notify = 'You died. Use /respawn to return to the hospital.',
	revived = 'You have been revived.',
	treated = 'You have been treated.',
	respawn_only_dead = 'You can only return to the hospital after dying.',
	generic_error = 'Could not complete the action.',
	err_no_character = 'No active character.',
	err_not_on_duty = 'Clock in at a hospital first.',
	err_not_ems = 'You are not on duty at a healthcare business.',
	err_forbidden = 'Your grade does not allow this.',
	err_unknown_patient = 'Patient not found.',
	err_same_character = 'You cannot treat yourself.',
	err_invalid_state = 'The patient does not need this right now.',
	err_too_far = 'Move closer to the patient.',
	err_not_ready = 'Service still initializing.',
	err_database_error = 'Failed to save medical record.'
}
