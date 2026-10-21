Locales = (type(Locales) == 'table' and Locales) or {}

Locales['en-US'] = {
	-- Ponto (Clock)
	not_staff = 'You are not a staff member of this business.',
	too_far = 'Get closer to the time clock.',
	outside_area = 'Clock in inside the business perimeter.',
	on_duty_elsewhere = 'You are already clocked in at another business.',
	already_on_duty = 'You are already on duty.',
	not_on_duty = 'You are not on duty.',
	use_station = 'Clock in at one of the business clock stations.',
	no_business = 'There is no business here.',
	clock_failed = 'Could not toggle time clock.',

	-- Textos de serviço / turno
	clock_in = 'Clocked in: entered %{business}.',
	clock_out = 'Clocked out: left %{business}.',
	left_area = 'You left %{business} area and your shift has ended.',
	business_closed = '%{business} was closed and your shift has ended.',
	duty_not_staff = 'You are no longer part of %{business} staff and your shift has ended.',

	-- Baús (Stash)
	stash_not_staff = 'Only the owner and staff of this business can open this stash.',
	stash_too_far = 'Get closer to the stash.',
	stash_no_business = 'Stash unavailable.',
	stash_container_limit = 'Close a stash before opening another.',
	stash_failed = 'Could not open stash.',

	-- Propostas (Offers)
	no_offer = 'Offer not found.',
	offer_expired = 'The offer has expired.',
	offer_no_business = 'The business is no longer available.',
	is_owner = 'You are the owner of this business.',
	already_staff = 'You are already on the staff team.',
	invalid_grade = 'The offered role no longer exists.',
	multiple_jobs = 'You already have a job and this business requires exclusive dedication.',
	already_partner = 'You are already a partner in this business.',
	partner_limit = 'The business has reached the maximum partner limit.',
	database_error = 'Database error. Please try again.',
	offer_failed = 'Could not accept offer.',

	-- Notificações de resposta a propostas
	offer_declined = 'Offer declined.',
	offer_declined_employer = '%{name} declined the offer.',
	offer_partner_accepted = 'You are now a partner of %{business} and liable for business debts.',
	offer_staff_accepted = 'You are now part of %{business}.',
	offer_partner_accepted_employer = '%{name} accepted and is now a partner.',
	offer_staff_accepted_employer = '%{name} accepted and joined the team.',
	offer_not_completed_partner = 'Partnership of %{name} was not completed: %{error}',
	offer_not_completed_staff = 'Hiring of %{name} was not completed: %{error}'
}
