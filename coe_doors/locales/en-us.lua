Locales = (type(Locales) == 'table' and Locales) or {}

Locales['en-US'] = {
	not_ready = 'Locks still starting.',
	no_door = 'Door unavailable.',
	too_far = 'Get closer to the door.',
	no_access = 'You do not have access to this door.',
	wrong_pin = 'Incorrect PIN.',
	no_pin = 'This door does not have a PIN.',
	pin_locked = 'Too many attempts. Wait before trying again.',
	busy = 'Please wait a moment.',
	action_failed = 'Could not complete action.',
	closed = 'Closed',
	opened = 'Open',
	locked = 'Locked',
	unlocked = 'Unlocked',
	action_open = 'Open',
	action_close = 'Close',
	action_lock = 'Lock',
	action_unlock = 'Unlock'
}
