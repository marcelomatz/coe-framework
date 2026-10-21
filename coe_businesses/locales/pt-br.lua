Locales = (type(Locales) == 'table' and Locales) or {}

Locales['pt-BR'] = {
	-- Ponto (Clock)
	not_staff = 'Você não faz parte da equipe deste negócio.',
	too_far = 'Chegue mais perto do ponto.',
	outside_area = 'Bata o ponto dentro da área do negócio.',
	on_duty_elsewhere = 'Você já está de ponto em outro negócio.',
	already_on_duty = 'Você já está de ponto.',
	not_on_duty = 'Você não está de ponto.',
	use_station = 'Bata o ponto em um dos pontos do negócio.',
	no_business = 'Não há um negócio aqui.',
	clock_failed = 'Não foi possível bater o ponto.',

	-- Textos de serviço / turno
	clock_in = 'Ponto batido: entrada em %{business}.',
	clock_out = 'Ponto batido: saída de %{business}.',
	left_area = 'Você saiu da área de %{business} e o ponto foi encerrado.',
	business_closed = '%{business} foi fechado e o ponto foi encerrado.',
	duty_not_staff = 'Você não faz mais parte da equipe de %{business} e o ponto foi encerrado.',

	-- Baús (Stash)
	stash_not_staff = 'Só o dono e a equipe deste negócio abrem este baú.',
	stash_too_far = 'Chegue mais perto do baú.',
	stash_no_business = 'Baú indisponível.',
	stash_container_limit = 'Feche um baú antes de abrir outro.',
	stash_failed = 'Não foi possível abrir o baú.',

	-- Propostas (Offers)
	no_offer = 'Proposta não encontrada.',
	offer_expired = 'A proposta expirou.',
	offer_no_business = 'O negócio não está mais disponível.',
	is_owner = 'Você é o dono deste negócio.',
	already_staff = 'Você já faz parte da equipe.',
	invalid_grade = 'O cargo oferecido não existe mais.',
	multiple_jobs = 'Você já tem um emprego e este negócio exige dedicação exclusiva (ou o seu emprego atual exige).',
	already_partner = 'Você já é sócio deste negócio.',
	partner_limit = 'O negócio atingiu o limite de sócios.',
	database_error = 'Erro ao gravar. Tente novamente.',
	offer_failed = 'Não foi possível aceitar a proposta.',

	-- Notificações de resposta a propostas
	offer_declined = 'Proposta recusada.',
	offer_declined_employer = '%{name} recusou a proposta.',
	offer_partner_accepted = 'Você agora é sócio de %{business} e responde pelas dívidas do negócio.',
	offer_staff_accepted = 'Você agora faz parte de %{business}.',
	offer_partner_accepted_employer = '%{name} aceitou e agora é sócio.',
	offer_staff_accepted_employer = '%{name} aceitou e entrou para a equipe.',
	offer_not_completed_partner = 'A sociedade de %{name} não foi concluída: %{error}',
	offer_not_completed_staff = 'A contratação de %{name} não foi concluída: %{error}'
}
