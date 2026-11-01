Locales = (type(Locales) == 'table' and Locales) or {}

Locales['en-US'] = {
	order_undelivered_refund = 'Amzg: order #%{id} could not be delivered to %{address} and was refunded to your card.',
	order_delivered = 'Amzg: order #%{id} was delivered to %{address}.',
	box_not_found = 'This box is no longer here.',
	box_too_far = 'Move closer to the box.',
	box_open_failed = 'Could not open the box.',
	box_label = 'Amzg Box #%{id}',
	open_box = 'Open Amzg box',
	refund_desc = 'Amzg Refund #%{id}'
}
