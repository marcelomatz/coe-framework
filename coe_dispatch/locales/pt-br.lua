Locales = (type(Locales) == 'table' and Locales) or {}

Locales['pt-BR'] = {
	call_sent = 'Chamado enviado.',
	call_accepted = 'Chamado aceito. Rota marcada no mapa.',
	call_closed = 'Chamado encerrado.',
	calls_none = 'Nenhum chamado ativo.',
	calls_prefix = 'Chamados: %{list}',
	generic_error = 'Não foi possível concluir.',
	err_invalid_code = 'Código de chamado inválido.',
	err_invalid_coords = 'Posição inválida.',
	err_too_many_calls = 'Central sobrecarregada.',
	err_not_on_duty = 'Bata o ponto em uma delegacia ou hospital primeiro.',
	err_unknown_call = 'Chamado não encontrado.',
	err_invalid_call = 'Número de chamado inválido.',
	err_cooldown = 'Aguarde antes de abrir outro chamado.',
	err_no_character = 'Nenhum personagem ativo.',
	err_forbidden = 'Sem permissão.'
}
