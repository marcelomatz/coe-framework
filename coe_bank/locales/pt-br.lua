Locales = (type(Locales) == 'table' and Locales) or {}

Locales['pt-BR'] = {
	not_ready = 'O banco ainda está abrindo.',
	unavailable = 'Atendimento indisponível.',
	too_far = 'Chegue mais perto do balcão.',
	busy = 'Aguarde um instante.',
	no_character = 'Personagem não carregado.',
	invalid_amount = 'Valor inválido.',
	invalid_state_id = 'ID de cidadão inválido.',
	character_not_found = 'Nenhum cidadão com esse ID.',
	same_account = 'Você não pode transferir para a própria conta.',
	insufficient_funds = 'Saldo insuficiente.',
	insufficient_cash = 'Você não tem esse valor em espécie.',
	inventory_full = 'Seus bolsos estão cheios. O valor voltou para a conta.',
	balance_limit = 'A conta de destino não pode receber esse valor.',
	economy_unavailable = 'Sistema bancário fora do ar.',
	database_error = 'Falha ao consultar. Tente de novo.',
	generic_error = 'Não foi possível concluir.',
	withdraw_success = 'Saque de %{amount} realizado.',
	deposit_success = 'Depósito de %{amount} realizado.',
	transfer_success = 'Transferência de %{amount} para %{target} realizada.',
	transfer_received = 'Você recebeu %{amount} de %{sender}.'
}
