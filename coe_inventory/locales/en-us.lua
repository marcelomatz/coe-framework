Locales = (type(Locales) == 'table' and Locales) or {}

Locales['en-US'] = {
	error_rate_limited = 'Please wait a moment and try again.',
	error_invalid_target = 'The container is no longer available.',
	error_not_found = 'This container is not registered (unowned old object).',
	error_inventory_full = 'No free space in this inventory.',
	error_persistence_failed = 'Could not save the container.',
	error_world_container_limit = 'World container limit reached.',
	error_world_container_limit_player = 'You left too many containers in the world. Pick one up first.',
	error_too_far = 'You moved too far from the container.',
	error_container_prop_busy = 'Please wait for the current animation to finish.',
	error_container_prop_unavailable = 'Could not create the container object.',
	error_place_failed = 'Could not place the container.',
	error_equip_failed = 'Could not equip the container.',
	error_pickup_failed = 'Could not pick up the container.',
	error_action_failed = 'Could not complete this action.',
	error_interact_failed = 'Could not interact with the container.',
	error_closer_needed = 'Get closer to the container.',
	target_open = 'Open',
	target_pickup = 'Pick up',
	target_approach = 'Container: get closer to use',
	target_place_here = 'Place here',
	container_picked_up = 'Container picked up.'
}
