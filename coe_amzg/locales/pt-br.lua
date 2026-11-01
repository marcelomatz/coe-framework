Locales = (type(Locales) == 'table' and Locales) or {}

Locales['pt-BR'] = {
	order_undelivered_refund = 'Amzg: o pedido #%{id} não pôde ser entregue em %{address} e foi estornado no cartão.',
	order_delivered = 'Amzg: o pedido #%{id} foi entregue em %{address}.',
	box_not_found = 'Essa caixa não está mais aqui.',
	box_too_far = 'Chegue mais perto da caixa.',
	box_open_failed = 'Não foi possível abrir a caixa.',
	box_label = 'Caixa Amzg #%{id}',
	open_box = 'Abrir caixa Amzg',
	refund_desc = 'Estorno Amzg #%{id}'
}
