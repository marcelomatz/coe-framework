Locales = (type(Locales) == 'table' and Locales) or {}

Locales['pt-BR'] = {
	service_starting = 'Serviço ainda iniciando.',
	no_active_character = 'Nenhum personagem ativo.',
	balance_query_failed = 'Não foi possível consultar o saldo.',
	balance_display = 'Saldo: %{balance}',
	credit_usage = 'Uso: coe_economy_credit <characterId> <valor> (%{error})',
	credit_failed = 'Não foi possível creditar.',
	credit_error = 'Falha ao creditar (%{error}).',
	credited_to_character = '%{amount} creditado ao personagem %{id}.'
}
