Locales = (type(Locales) == 'table' and Locales) or {}

Locales['pt-BR'] = {
	voice_max_range = 'Voz já está no alcance máximo (Gritar)',
	voice_min_range = 'Voz já está no alcance mínimo (Sussurrar)',
	voice_increased = 'Voz aumentada: %{mode} (%{dist}m)',
	voice_decreased = 'Voz diminuída: %{mode} (%{dist}m)',
	voice_activation_on = 'Ativação contínua por voz ligada',
	voice_activation_off = 'Push-to-Talk ativado (tecla N)',
	radio_volume = 'Volume do rádio ajustado para %{vol}%',
	radio_off = 'Rádio desligado',
	radio_invalid_freq = 'Frequência de rádio inválida',
	radio_restricted = 'Frequência restrita: acesso negado',
	radio_connected = 'Conectado à frequência %{freq} MHz'
}
