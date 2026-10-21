// Proposta de emprego ou convite de sociedade: o convidado aceita ou recusa no diálogo padrão do coe_ui.
(function () {
	const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'coe_businesses';
	function answer(id, accept) {
		fetch(`https://${resource}/answerOffer`, { method: 'POST', body: JSON.stringify({ id, accept }) }).catch(() => {});
	}
	window.addEventListener('message', (event) => {
		const message = event.data;
		if (!message || message.action !== 'offer' || !message.data) return;
		const offer = message.data;
		const grade = offer.grade ? ` no cargo ${offer.grade}` : '';
		const partner = offer.kind === 'partner';
		window.CoeUI.confirm({
			title: partner ? 'Convite de sociedade' : 'Proposta de emprego',
			message: partner
				? `O proprietário de ${offer.business} convida você para ser sócio.\nSócios respondem pelas dívidas do negócio (empréstimos empresariais): se o caixa não cobrir uma parcela, o atraso pesa no seu relacionamento com o banco.\nO convite vale por ${offer.seconds} segundos.`
				: `${offer.business} quer contratar você${grade}.\nA proposta vale por ${offer.seconds} segundos.`,
			confirmLabel: 'Aceitar',
			cancelLabel: 'Recusar'
		}).then((accepted) => answer(offer.id, accepted));
	});
})();
