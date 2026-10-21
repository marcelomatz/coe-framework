Locales = (type(Locales) == 'table' and Locales) or {}

Locales['en-US'] = {
	voice_max_range = 'Voice is already at maximum range (Shout)',
	voice_min_range = 'Voice is already at minimum range (Whisper)',
	voice_increased = 'Voice range increased: %{mode} (%{dist}m)',
	voice_decreased = 'Voice range decreased: %{mode} (%{dist}m)',
	voice_activation_on = 'Continuous voice activation enabled',
	voice_activation_off = 'Push-to-Talk enabled (N key)',
	radio_volume = 'Radio volume set to %{vol}%',
	radio_off = 'Radio turned off',
	radio_invalid_freq = 'Invalid radio frequency',
	radio_restricted = 'Restricted frequency: access denied',
	radio_connected = 'Connected to frequency %{freq} MHz'
}
