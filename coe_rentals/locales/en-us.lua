Locales = (type(Locales) == 'table' and Locales) or {}

Locales['en-US'] = {
	press_to_rent = 'Press ~INPUT_CONTEXT~ to rent a vehicle',
	press_to_return = 'Press ~INPUT_CONTEXT~ to return the rented vehicle',
	return_prompt = 'Return rented vehicle (Receive $ %{deposit} deposit back)',
	rent_title = 'Rental Station',
	already_rented = 'You already have an active rented vehicle in use.',
	not_enough_money = 'You do not have enough money to rent (price + deposit).',
	rent_success = 'Vehicle %{model} rented! Return to any station to receive $ %{deposit} deposit back.',
	return_success = 'Vehicle returned successfully! You received $ %{deposit} back.',
	not_your_rental = 'This is not the vehicle you rented.',
	not_in_vehicle = 'You must be driving your rented vehicle to return it.',
	station_not_found = 'Rental station not found.',
	vehicle_not_available = 'Vehicle model unavailable for rent.',
	vehicle_spawn_failed = 'Could not spawn the vehicle at this time. Please try again.',
	too_far = 'You need to be at the rental point.',
	busy = 'Wait a moment and try again.',
	economy_unavailable = 'The financial system is unavailable. Try again shortly.',
	refund_failed = 'The deposit could not be refunded right now. Staff has been notified.'
}
