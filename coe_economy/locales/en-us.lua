Locales = (type(Locales) == 'table' and Locales) or {}

Locales['en-US'] = {
	service_starting = 'Service is still starting.',
	no_active_character = 'No active character.',
	balance_query_failed = 'Could not query balance.',
	balance_display = 'Balance: %{balance}',
	credit_usage = 'Usage: coe_economy_credit <characterId> <amount> (%{error})',
	credit_failed = 'Could not credit amount.',
	credit_error = 'Failed to credit (%{error}).',
	credited_to_character = '%{amount} credited to character %{id}.'
}
