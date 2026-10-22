Locales = (type(Locales) == 'table' and Locales) or {}

Locales['en-US'] = {
	not_ready = 'The bank is still opening.',
	unavailable = 'Service unavailable.',
	too_far = 'Move closer to the counter.',
	busy = 'Please wait a moment.',
	no_character = 'Character not loaded.',
	invalid_amount = 'Invalid amount.',
	invalid_state_id = 'Invalid citizen ID.',
	character_not_found = 'No citizen with that ID.',
	same_account = 'You cannot transfer to your own account.',
	insufficient_funds = 'Insufficient balance.',
	insufficient_cash = 'You do not have that much cash.',
	inventory_full = 'Your pockets are full. The amount went back to the account.',
	balance_limit = 'The receiving account cannot take that amount.',
	economy_unavailable = 'Banking system offline.',
	database_error = 'Lookup failed. Try again.',
	generic_error = 'Could not complete.',
	withdraw_success = 'Withdrew %{amount}.',
	deposit_success = 'Deposited %{amount}.',
	transfer_success = 'Transferred %{amount} to %{target}.',
	transfer_received = 'You received %{amount} from %{sender}.'
}
