// App "Banco" do COE OS (coe_tablet): saldo, extrato, transferência, cartões, fatura e empréstimos.
(function () {
	'use strict';

	const REASONS = {
		starting_balance: 'Saldo inicial', bank_withdraw: 'Saque', bank_deposit: 'Depósito', bank_transfer: 'Transferência',
		bank_refund: 'Estorno', card_fee: 'Tarifa de cartão', payroll: 'Salário', society_deposit: 'Depósito no negócio',
		society_withdraw: 'Saque do negócio', admin_adjustment: 'Ajuste administrativo', rent: 'Aluguel', fine: 'Multa',
		card_invoice: 'Fatura do cartão', atm_fee: 'Tarifa de saque', bank_loan: 'Empréstimo', loan_payment: 'Parcela de empréstimo',
		telecom: 'Operadora de celular', telecom_refund: 'Estorno da operadora'
	};
	const CARD_STATUS = { active: 'Ativo', expired: 'Vencido', blocked: 'Bloqueado' };

	function el(tag, className, text) {
		const node = document.createElement(tag);
		if (className) { node.className = className; }
		if (text !== undefined && text !== null) { node.textContent = String(text); }
		return node;
	}

	function button(label, className, onClick) {
		const node = el('button', 'coe-button ' + (className || ''), label);
		node.type = 'button';
		node.addEventListener('click', onClick);
		return node;
	}

	function money(value) {
		return '$ ' + Math.floor(Math.abs(Number(value) || 0)).toLocaleString('pt-BR');
	}

	function when(text) {
		const match = /^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})/.exec(String(text || ''));
		return match ? match[3] + '/' + match[2] + ' ' + match[4] + ':' + match[5] : '';
	}

	function day(epoch) {
		if (!epoch) { return '—'; }
		const d = new Date(epoch * 1000);
		return String(d.getDate()).padStart(2, '0') + '/' + String(d.getMonth() + 1).padStart(2, '0');
	}

	window.CoeTablet.register('bank', function (root, tablet) {
		let busy = false;
		let data = null;
		let tab = 'account';

		function call(action, payload, success) {
			if (busy) { return; }
			busy = true;
			tablet.call('bank', action, payload || {}).then(function (result) {
				busy = false;
				if (result && result.bank) { data = result.bank; }
				if (!result || !result.ok) {
					tablet.status((result && result.message) || tablet.errorText(result && result.error), 'error');
				} else if (success) {
					tablet.status(success, 'ok');
				}
				view();
			});
		}

		function tabs() {
			const bar = el('div', 'tb-tabs');
			[['account', 'Conta'], ['transfer', 'Transferir'], ['cards', 'Cartões'], ['credit', 'Crédito']].forEach(function (entry) {
				const node = button(entry[1], 'tb-tab' + (tab === entry[0] ? ' is-active' : ''), function () { tab = entry[0]; tablet.status(''); view(); });
				node.className = 'tb-tab' + (tab === entry[0] ? ' is-active' : '');
				bar.appendChild(node);
			});
			return bar;
		}

		function account() {
			const box = el('div', 'coe-panel coe-panel--compact tb-card');
			const head = el('div', 'tb-total');
			head.appendChild(el('span', '', data.holder || 'Conta corrente'));
			head.appendChild(el('strong', '', data.balance == null ? '—' : money(data.balance)));
			box.appendChild(head);
			box.appendChild(el('div', 'tb-section', 'Extrato'));
			const lines = el('div', 'tb-lines');
			if (!(data.statement || []).length) { lines.appendChild(el('p', 'tb-muted', 'Sem movimentações.')); }
			(data.statement || []).forEach(function (row) {
				const line = el('div', 'tb-line');
				line.appendChild(el('span', '', (REASONS[row.reason] || String(row.reason || '').replace(/_/g, ' ')) + '  ' + when(row.at)));
				line.appendChild(el('span', row.delta < 0 ? 'tb-out' : 'tb-in', (row.delta < 0 ? '-' : '+') + money(row.delta)));
				lines.appendChild(line);
			});
			box.appendChild(lines);
			return box;
		}

		function transfer() {
			const box = el('div', 'coe-panel coe-panel--compact tb-card');
			box.appendChild(el('div', 'tb-section', 'Transferência para outro cidadão'));
			const target = el('input', 'coe-field');
			target.placeholder = 'ID do cidadão (state ID)';
			const amount = el('input', 'coe-field');
			amount.type = 'number';
			amount.min = '1';
			amount.placeholder = 'Valor';
			box.append(target, amount);
			box.appendChild(el('span', 'tb-muted', 'Saldo: ' + money(data.balance) + (data.maxAmount ? ' · máximo por operação ' + money(data.maxAmount) : '')));
			box.appendChild(button('Transferir', 'coe-button--primary', function () {
				const value = Math.floor(Number(amount.value));
				if (!target.value.trim() || !value) { tablet.status('Informe o ID e o valor.', 'error'); return; }
				call('transfer', { stateId: target.value.trim(), amount: value }, 'Transferência enviada.');
			}));
			return box;
		}

		function cards() {
			const box = el('div', 'coe-panel coe-panel--compact tb-card');
			box.appendChild(el('div', 'tb-section', 'Cartões'));
			box.appendChild(el('span', 'tb-muted', 'Perdeu ou foi roubado? Bloqueie aqui. Um novo cartão físico é emitido na agência; o virtual, aqui.'));
			const lines = el('div', 'tb-lines');
			if (!(data.cards || []).length) { lines.appendChild(el('p', 'tb-muted', 'Nenhum cartão emitido.')); }
			(data.cards || []).forEach(function (card) {
				const line = el('div', 'tb-line');
				line.appendChild(el('span', '', '•••• ' + card.last4 + (card.kind === 'virtual' ? ' (virtual)' : '') + ' · ' + (CARD_STATUS[card.status] || card.status) + (card.blockedReason ? ' (' + card.blockedReason + ')' : '') + ' · vence ' + day(card.expiresAt)));
				if (card.status === 'active') {
					line.appendChild(button('Bloquear', 'coe-button--danger', function () { call('blockCard', { cardId: card.id }); }));
				}
				lines.appendChild(line);
			});
			box.appendChild(lines);
			const hasVirtual = (data.cards || []).some(function (card) { return card.kind === 'virtual' && card.status === 'active'; });
			const fee = data.virtualCardFee > 0 ? ' (' + money(data.virtualCardFee) + ')' : '';
			box.appendChild(button((hasVirtual ? 'Trocar cartão virtual' : 'Pedir cartão virtual') + fee, '', function () {
				call('issueVirtual', {}, 'Cartão virtual emitido. Adicione na Carteira do smartphone.');
			}));
			return box;
		}

		function creditTab() {
			const wrap = el('div', 'tb-lines');
			const credit = data.credit;
			const box = el('div', 'coe-panel coe-panel--compact tb-card');
			box.appendChild(el('div', 'tb-section', 'Cartão de crédito'));
			if (!credit) {
				box.appendChild(el('p', 'tb-muted', 'Você não tem cartão de crédito. Peça na agência.'));
			} else {
				const lines = el('div', 'tb-lines');
				[['Limite', money(credit.limit)], ['Disponível', money(credit.available)], ['Fatura', money(credit.invoice)],
					['Mínimo a pagar', money(credit.minLeft)], ['Vencimento', day(credit.dueAt)], ['Pontos', credit.points || 0]].forEach(function (pair) {
					const line = el('div', 'tb-line');
					line.append(el('span', '', pair[0]), el('span', '', pair[1]));
					lines.appendChild(line);
				});
				box.appendChild(lines);
				if (credit.late) { box.appendChild(el('span', 'coe-badge tb-badge--warn', 'Fatura em atraso')); }
				const actions = el('div', 'tb-toolbar');
				actions.appendChild(button('Pagar mínimo', '', function () { call('creditPay', { mode: 'min' }, 'Pagamento feito.'); }));
				actions.appendChild(button('Pagar total', 'coe-button--primary', function () { call('creditPay', { mode: 'total' }, 'Fatura paga.'); }));
				box.appendChild(actions);
			}
			wrap.appendChild(box);
			const loans = (data.loans || []).filter(function (loan) { return loan.status === 'active'; });
			if (loans.length) {
				const loanBox = el('div', 'coe-panel coe-panel--compact tb-card');
				loanBox.appendChild(el('div', 'tb-section', 'Empréstimos'));
				loans.forEach(function (loan) {
					const line = el('div', 'tb-line');
					line.appendChild(el('span', '', (loan.businessLabel ? 'Negócio ' + loan.businessLabel : 'Empréstimo #' + loan.id) + ' · ' + (loan.paidCount || 0) + '/' + loan.installments + (loan.remaining != null ? ' · parcela ' + money(loan.remaining) : '') + (loan.late ? ' · em atraso' : '')));
					const actions = el('div', 'tb-toolbar');
					actions.appendChild(button('Parcela', '', function () { call('loanPay', { loanId: loan.id, mode: 'installment' }, 'Parcela paga.'); }));
					actions.appendChild(button('Quitar', 'coe-button--primary', function () { call('loanPay', { loanId: loan.id, mode: 'total' }, 'Empréstimo quitado.'); }));
					line.appendChild(actions);
					loanBox.appendChild(line);
				});
				wrap.appendChild(loanBox);
			}
			return wrap;
		}

		function view() {
			root.replaceChildren();
			if (!data) { root.appendChild(el('p', 'tb-empty', 'Banco indisponível.')); return; }
			root.appendChild(tabs());
			const render = { account: account, transfer: transfer, cards: cards, credit: creditTab }[tab];
			root.appendChild(render());
		}

		root.appendChild(el('p', 'tb-empty', 'Carregando…'));
		call('overview');
	});
})();