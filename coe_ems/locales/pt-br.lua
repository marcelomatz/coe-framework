Locales = (type(Locales) == 'table' and Locales) or {}

Locales['pt-BR'] = {
	unconscious_notify = 'Você está inconsciente. Aguarde socorro.',
	dead_notify = 'Você morreu. Use /respawn para voltar ao hospital.',
	revived = 'Você foi reanimado.',
	treated = 'Você foi tratado.',
	respawn_only_dead = 'Você só pode voltar ao hospital depois de morrer.',
	generic_error = 'Não foi possível concluir.',
	err_no_character = 'Nenhum personagem ativo.',
	err_not_on_duty = 'Bata o ponto em um hospital primeiro.',
	err_not_ems = 'Você não está de ponto em um negócio de saúde.',
	err_forbidden = 'Seu cargo não permite isso.',
	err_unknown_patient = 'Paciente não encontrado.',
	err_same_character = 'Você não pode tratar a si mesmo.',
	err_invalid_state = 'O paciente não precisa disso agora.',
	err_too_far = 'Chegue mais perto do paciente.',
	err_not_ready = 'Serviço ainda iniciando.',
	err_database_error = 'Falha ao gravar o prontuário.'
}
