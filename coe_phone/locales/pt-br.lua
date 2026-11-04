Locales = (type(Locales) == 'table' and Locales) or {}

Locales['pt-BR'] = {
	missed_call = 'Chamada perdida de %{caller}.',
	new_message = 'Nova mensagem de %{sender}.',
	no_phone = 'Você não tem um celular.',
	no_device = 'Este celular não funciona.',
	inventory_unavailable = 'O inventário não respondeu. Tente de novo.',
	number_unavailable = 'Não foi possível gerar um número agora.',
	no_character = 'Selecione um personagem primeiro.',
	not_ready = 'O celular ainda está iniciando.',
	phone_unavailable = 'O celular não está disponível agora.',
	invalid_sim = 'Este chip não funciona.',
	in_call = 'Encerre a ligação antes de trocar o chip.',
	no_free_sim_slot = 'Não há espaço para outro chip neste celular. Retire o atual em Ajustes.',
	slot_changed = 'O chip não está mais nesse lugar do inventário.',
	sim_place_failed = 'Não foi possível colocar o chip.',
	sim_placed = 'Chip %{number} colocado no celular.'
}
