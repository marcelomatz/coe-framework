Locales = (type(Locales) == 'table' and Locales) or {}

Locales['en-US'] = {
	passenger_boarded = 'Passenger on board. Follow the GPS to the destination.',
	action_cancelled = 'Action cancelled.',
	err_not_ready = 'Service still initializing.',
	err_already_working = 'End your current job first.',
	err_no_character = 'Character not loaded.',
	err_unknown_job = 'Job unavailable.',
	err_too_far = 'Move closer.',
	err_database_error = 'Failed to load your history. Try again.',
	err_no_deposit = 'Insufficient funds for the vehicle deposit.',
	err_vehicle_failed = 'Could not spawn the vehicle right now.',
	err_not_working = 'You are not working on this.',
	err_cooldown = 'This point is not ready yet.',
	err_too_fast = 'Finish the previous action first.',
	err_full = 'Inventory full. Sell your cargo first.',
	err_empty = 'Nothing to sell.',
	err_vehicle_far = 'Bring the work vehicle closer.',
	err_payment_failed = 'Payment unavailable right now. Try again.',
	err_wrong_step = 'Complete the previous step first.',
	err_outside_zone = 'Collect inside the marked map area, with the truck nearby.',
	err_bin_empty = 'This bin was recently collected. Look for another.',
	err_locked = 'You do not have enough experience for this job yet.',
	generic_error = 'Could not complete right now.',
	needs_detail = '%{message} Requires %{detail}.'
}
