Locales = (type(Locales) == 'table' and Locales) or {}

Locales['pt-BR'] = {
	press_to_rent = 'Pressione ~INPUT_CONTEXT~ para alugar um veículo',
	press_to_return = 'Pressione ~INPUT_CONTEXT~ para devolver o veículo alugado',
	return_prompt = 'Devolver veículo alugado (Receba R$ %{deposit} de caução)',
	rent_title = 'Ponto de Aluguel',
	already_rented = 'Você já possui um veículo alugado em uso.',
	not_enough_money = 'Você não possui dinheiro suficiente para alugar (custo + caução).',
	rent_success = 'Veículo %{model} alugado! Devolva em qualquer estação para receber R$ %{deposit} de caução.',
	return_success = 'Veículo devolvido com sucesso! Você recebeu R$ %{deposit} de volta.',
	not_your_rental = 'Este não é o veículo que você alugou.',
	not_in_vehicle = 'Você precisa estar conduzindo o veículo alugado para devolver.',
	station_not_found = 'Estação de aluguel não encontrada.',
	vehicle_not_available = 'Modelo de veículo indisponível para aluguel.',
	vehicle_spawn_failed = 'Não foi possível disponibilizar o veículo no momento. Tente novamente.'
}
