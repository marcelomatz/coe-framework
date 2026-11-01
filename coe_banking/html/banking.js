(() => {
	const $ = (id) => document.getElementById(id);
	const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'coe_banking';

	const post = (name, body) => fetch(`https://${resource}/${name}`, {
		method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body || {})
	}).catch(() => {});

	const el = (tag, props = {}, children = []) => {
		const node = document.createElement(tag);
		Object.assign(node, props);
		for (const child of [].concat(children)) if (child != null && child !== false) node.append(child);
		return node;
	};

	const money = (value) => `$ ${Math.floor(Math.abs(value || 0)).toLocaleString('pt-BR')}`;
	const signed = (value) => `${value < 0 ? '−' : '+'} ${money(value)}`;
	const when = (text) => {
		const match = /^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})/.exec(String(text || ''));
		return match ? `${match[3]}/${match[2]} ${match[4]}:${match[5]}` : '';
	};
	const two = (n) => String(n).padStart(2, '0');
	const day = (epoch) => {
		if (!epoch) return '—';
		const d = new Date(epoch * 1000);
		return `${two(d.getDate())}/${two(d.getMonth() + 1)}/${d.getFullYear()}`;
	};
	const date = (epoch) => {
		if (!epoch) return '—';
		const d = new Date(epoch * 1000);
		return `${two(d.getDate())}/${two(d.getMonth() + 1)} ${two(d.getHours())}:${two(d.getMinutes())}`;
	};

	const REASONS = {
		starting_balance: 'Saldo inicial', bank_withdraw: 'Saque', bank_deposit: 'Depósito', bank_transfer: 'Transferência',
		bank_refund: 'Estorno', card_fee: 'Tarifa de cartão', payroll: 'Salário', society_deposit: 'Depósito no negócio',
		society_withdraw: 'Saque do negócio', admin_adjustment: 'Ajuste administrativo', rent: 'Aluguel', fine: 'Multa',
		card_invoice: 'Fatura do cartão', atm_fee: 'Tarifa de saque', bank_loan: 'Empréstimo', loan_payment: 'Parcela de empréstimo',
		telecom: 'Operadora de celular', telecom_refund: 'Estorno da operadora',
		business_deposit: 'Depósito na empresa', business_withdraw: 'Saque da empresa', business_payment: 'Pagamento de empresa',
		business_bonus: 'Bônus da empresa'
	};
	const reasonLabel = (reason) => REASONS[reason] || String(reason || '').replace(/_/g, ' ');

	const CREDIT_KINDS = {
		tier: 'Nível liberado', downgrade: 'Nível rebaixado', closed: 'Fatura fechada', payment: 'Pagamento',
		auto_debit: 'Débito automático', late_fee: 'Multa por atraso', late_interest: 'Juros de atraso',
		revolving_interest: 'Juros do rotativo', annuity: 'Anuidade', purchase: 'Compra no crédito', refund: 'Estorno no crédito', points: 'Pontos',
		staff_tier: 'Ajuste do banco', staff_points: 'Pontos (ajuste do banco)', loan_granted: 'Empréstimo concedido',
		loan_payment: 'Parcela de empréstimo paga', loan_late: 'Parcela em atraso', loan_paid: 'Empréstimo quitado', loan_forgiven: 'Saldo perdoado pelo banco',
		loan_interest: 'Juros de atraso do empréstimo'
	};
	const CREDIT_OUT = new Set(['payment', 'auto_debit', 'loan_payment', 'refund']);
	const CREDIT_NEUTRAL = new Set(['tier', 'downgrade', 'closed', 'staff_tier', 'staff_points', 'loan_granted', 'loan_paid', 'loan_forgiven']);
	const CARD_STATUS = { active: ['is-ok', 'Ativo'], expired: ['is-bad', 'Vencido'], blocked: ['is-bad', 'Bloqueado'] };

	// Progresso de relacionamento. O nível que o cliente já tem (inclusive por upgrade do banco, acima da pontuação
	// atual) e os abaixo dele nunca aparecem como meta: a meta é o primeiro nível acima do maior entre o nível atual
	// e o nível liberado pela pontuação.
	function creditProgress(tiers, score, currentId, eligibleId) {
		const currentIndex = currentId ? tiers.findIndex((tier) => tier.id === currentId) : -1;
		const eligibleIndex = eligibleId ? tiers.findIndex((tier) => tier.id === eligibleId) : -1;
		const reached = Math.max(currentIndex, eligibleIndex);
		const upgrade = eligibleIndex > currentIndex ? tiers[eligibleIndex] : null;
		const target = tiers[reached + 1] || null;
		const states = tiers.map((tier, index) => {
			if (index === currentIndex) return { state: 'current', label: 'Seu nível' };
			if (index < currentIndex) return { state: 'included', label: 'Abaixo do seu nível' };
			if (index <= eligibleIndex) return { state: 'open', label: currentIndex >= 0 ? 'Upgrade liberado' : 'Liberado' };
			return { state: 'locked', label: `Faltam ${Math.max(0, tier.minScore - score)} pts` };
		});
		return {
			currentIndex, eligibleIndex, upgrade, target,
			missing: target ? Math.max(0, target.minScore - score) : 0,
			states
		};
	}

	let view = null;
	let tab = 'account';
	let pending = false;
	let pin = '';
	let pinCard = null;
	let pinWarning = '';

	const setPending = (value) => {
		pending = value;
		for (const button of $('panel').querySelectorAll('.bank-body button, .bank-body input, .bank-body select')) {
			button.disabled = value || button.dataset.locked === '1';
		}
	};

	const act = (endpoint, action, data) => {
		if (pending) return;
		setPending(true);
		post(endpoint, { action, data });
	};

	const lock = (node) => { node.disabled = true; node.dataset.locked = '1'; return node; };
	const button = (label, kind, onClick) => {
		const node = el('button', { type: 'button', className: `coe-button${kind ? ' coe-button--' + kind : ''}`, textContent: label });
		if (onClick) node.onclick = onClick;
		return node;
	};
	const field = (props) => el('input', Object.assign({ className: 'coe-field' }, props));
	const amountInput = (placeholder, max) => field({ type: 'number', min: 1, max, step: 1, placeholder: placeholder || 'Valor' });
	const readAmount = (input) => {
		const value = Number(input.value);
		return Number.isInteger(value) && value > 0 ? value : null;
	};
	const pinInput = (placeholder) => field({ type: 'password', inputMode: 'numeric', maxLength: 4, placeholder });

	const kpi = (label, value, note, main) => el('div', { className: `kpi${main ? ' is-main' : ''}` }, [
		el('span', { textContent: label }), el('strong', { textContent: value }), note ? el('small', { textContent: note }) : null
	]);
	const cell = (label, value) => el('div', { className: 'cell' }, [el('span', { textContent: label }), el('strong', { textContent: value })]);
	const badge = (text, kind) => el('span', { className: `coe-badge${kind ? ' ' + kind : ''}`, textContent: text });
	const hint = (text) => el('p', { className: 'hint', textContent: text });
	const empty = (text) => el('p', { className: 'empty', textContent: text });
	const title = (text, extra) => el('div', { className: 'section-title' }, [el('div', { className: 'tb-section', textContent: text }), extra || null]);
	const box = (children, alert) => el('div', { className: `box${alert ? ' is-alert' : ''}` }, children);
	const boxHead = (left, right) => el('div', { className: 'box-head' }, [el('div', { className: 'box-title' }, left), right || null]);
	const labeled = (text, control) => el('label', { className: 'field-label' }, [text, control]);
	const row = (children, extra) => el('div', { className: `row${extra ? ' ' + extra : ''}` }, children);

	// Cartão visual; `tier` define o acabamento (sem crédito: débito, na cor do tema).
	function cardFace(last4, holder, tier, tierLabel, status, small) {
		return el('div', { className: `bank-card${tier ? ' tier-' + tier : ''}${status && status !== 'active' ? ' off' : ''}${small ? ' sm' : ''}` }, [
			el('div', { className: 'bank-card-top' }, [el('span', { textContent: 'COE BANK' }), el('span', { textContent: tierLabel || 'Débito' })]),
			el('div', { className: 'bank-card-chip' }),
			el('div', { className: 'bank-card-number', textContent: `•••• ${small ? '' : '•••• •••• '}${last4 || '0000'}` }),
			el('div', { className: 'bank-card-holder', textContent: (holder || '').toUpperCase() })
		]);
	}

	const creditTier = () => {
		const credit = view && view.credit;
		if (!credit || !credit.account) return null;
		return (credit.tiers || []).find((tier) => tier.id === credit.account.tier) || null;
	};

	function ledger(rows, emptyText) {
		if (!rows || rows.length === 0) return empty(emptyText || 'Sem movimentações.');
		return el('div', { className: 'ledger' }, rows.map((entry) => {
			const reference = entry.reference && entry.reference.startsWith('state:') ? `Identidade ${entry.reference.slice(6)}` : '';
			return el('div', { className: `ledger-row ${entry.delta < 0 ? 'is-out' : 'is-in'}` }, [
				el('span', { className: 'ledger-icon', textContent: entry.delta < 0 ? '↑' : '↓' }),
				el('div', { className: 'ledger-text' }, [el('div', { textContent: reasonLabel(entry.reason) }), el('small', { textContent: [when(entry.at), reference].filter(Boolean).join(' · ') })]),
				el('span', { className: 'ledger-value', textContent: signed(entry.delta) })
			]);
		}));
	}

	// Agência: Conta ---------------------------------------------------------------------------------------
	function accountTab(body) {
		const withdrawAmount = amountInput('Valor', view.maxAmount);
		const depositAmount = amountInput('Valor', view.maxAmount);
		const stateId = field({ type: 'text', className: 'coe-field upper', maxLength: 16, placeholder: 'Identidade (state ID)' });
		const transferAmount = amountInput('Valor', view.maxAmount);

		const withdraw = button('Sacar', 'primary', () => { const amount = readAmount(withdrawAmount); if (amount) act('agency', 'withdraw', { amount }); });
		const deposit = button('Depositar', 'primary', () => { const amount = readAmount(depositAmount); if (amount) act('agency', 'deposit', { amount }); });
		const transfer = button('Transferir', 'primary', async () => {
			const amount = readAmount(transferAmount);
			const target = stateId.value.trim().toUpperCase();
			if (!amount || !target) return;
			const ok = await CoeUI.confirm({ title: 'Confirmar transferência', message: `Transferir ${money(amount)} para a identidade ${target}?`, confirmLabel: 'Transferir' });
			if (ok) act('agency', 'transfer', { stateId: target, amount });
		});

		body.append(
			title('Operações'),
			el('div', { className: 'grid-2' }, [
				box([boxHead([el('strong', { textContent: 'Saque em espécie' })]), row([withdrawAmount, withdraw]), hint(`Em espécie agora: ${money(view.cash)}.`)]),
				box([boxHead([el('strong', { textContent: 'Depósito em espécie' })]), row([depositAmount, deposit]), hint('O dinheiro sai do inventário e cai na conta.')]),
				el('div', { className: 'box span-all' }, [
					boxHead([el('strong', { textContent: 'Transferência' })]),
					row([stateId, transferAmount, transfer]),
					hint('Informe a identidade (state ID) de quem vai receber. A transferência é imediata.')
				])
			]),
			title('Extrato'),
			ledger(view.statement)
		);
	}

	// Agência: Cartões --------------------------------------------------------------------------------------
	function cardsTab(body) {
		const cards = view.cards || [];
		const physical = cards.filter((card) => card.kind !== 'virtual');
		const active = physical.find((card) => card.status === 'active');
		const activeVirtual = cards.find((card) => card.kind === 'virtual' && card.status === 'active');
		const expired = !active && physical.some((card) => card.status === 'expired');
		const tier = creditTier();

		const pin1 = pinInput('Senha (4 dígitos)');
		const pin2 = pinInput('Repita a senha');
		pin2.oninput = () => pin2.setCustomValidity('');
		const price = expired ? view.cardRenewFee : view.cardFee;
		const issue = button((active ? 'Emitir 2ª via' : expired ? 'Renovar cartão' : 'Emitir cartão') + (price > 0 ? ` · ${money(price)}` : ''), 'primary', async () => {
			if (!/^\d{4}$/.test(pin1.value) || pin1.value !== pin2.value) {
				pin2.setCustomValidity('As senhas devem ter 4 dígitos e ser iguais.');
				pin2.reportValidity();
				return;
			}
			if (active) {
				const ok = await CoeUI.confirm({ title: 'Emitir 2ª via', message: `O cartão •••• ${active.last4} será bloqueado definitivamente.`, confirmLabel: 'Emitir', danger: true });
				if (!ok) return;
			}
			act('agency', 'issueCard', { pin: pin1.value });
		});
		const issueVirtual = button((activeVirtual ? 'Trocar cartão virtual' : 'Pedir cartão virtual') + (view.virtualCardFee > 0 ? ` · ${money(view.virtualCardFee)}` : ''), null, async () => {
			if (activeVirtual) {
				const ok = await CoeUI.confirm({ title: 'Novo cartão virtual', message: `O cartão virtual •••• ${activeVirtual.last4} será bloqueado e sai das carteiras onde estiver.`, confirmLabel: 'Trocar', danger: true });
				if (!ok) return;
			}
			act('agency', 'issueVirtual', {});
		});

		let showcase;
		if (active) {
			showcase = box([el('div', { className: 'card-row' }, [
				cardFace(active.last4, active.holder, tier && tier.id, tier && tier.label, 'active'),
				el('div', { className: 'card-item-info' }, [
					el('div', { className: 'box-title' }, [el('strong', { textContent: tier ? `Cartão múltiplo ${tier.label}` : 'Cartão de débito' }), badge('Ativo', 'is-ok')]),
					hint(tier ? 'Débito na conta e crédito no mesmo plástico.' : 'Só débito. Peça o crédito na seção Crédito.'),
					active.expiresAt ? hint(`Válido até ${day(active.expiresAt)}.`) : null
				])
			])]);
		} else if (expired) {
			showcase = box([boxHead([el('strong', { textContent: 'Seu cartão venceu' }), badge('Vencido', 'is-bad')]),
				hint(`A validade é de ${view.cardValidityDays} dias. Emita um novo: nível, limite e pontos continuam.`)], true);
		} else {
			showcase = box([boxHead([el('strong', { textContent: 'Você ainda não tem cartão' })]), hint('Emita o cartão para usar caixas eletrônicos e pagar com débito.')]);
		}

		body.append(
			title('Cartão atual'), showcase,
			el('div', { className: 'grid-2' }, [
				box([boxHead([el('strong', { textContent: active ? 'Segunda via' : 'Novo cartão físico' })]), row([pin1, pin2]), row([issue], 'end'),
					hint(active ? 'Use em caso de perda ou roubo; o cartão atual é bloqueado.' : 'Escolha uma senha de 4 dígitos para os caixas eletrônicos.')]),
				box([boxHead([el('strong', { textContent: 'Cartão virtual' }), activeVirtual ? badge(`•••• ${activeVirtual.last4}`, 'is-accent') : null]),
					hint(activeVirtual ? 'Ativo na Carteira do smartphone: pague com o rosto ou a senha do aparelho.' : 'Sem plástico nem senha: fica só na Carteira do smartphone.'),
					row([issueVirtual], 'end')])
			]),
			title('Todos os cartões', badge(String(cards.length))),
			cards.length === 0 ? empty('Nenhum cartão emitido.') : el('div', { className: 'card-list' }, cards.map((card) => {
				const status = CARD_STATUS[card.status] || CARD_STATUS.blocked;
				const actions = [];
				if (card.canResetPin) {
					const newPin = pinInput('Nova senha');
					actions.push(row([newPin,
						button(card.status === 'blocked' ? 'Desbloquear' : 'Trocar senha', null, () => { if (/^\d{4}$/.test(newPin.value)) act('agency', 'changePin', { cardId: card.id, pin: newPin.value }); }),
						button('Bloquear', 'danger', async () => {
							const ok = await CoeUI.confirm({ title: 'Bloquear cartão', message: `Bloquear definitivamente o cartão •••• ${card.last4}? Use em caso de perda ou roubo.`, confirmLabel: 'Bloquear', danger: true });
							if (ok) act('agency', 'blockCard', { cardId: card.id });
						})]));
				}
				return el('div', { className: 'card-item' }, [
					cardFace(card.last4, card.holder, card.kind === 'virtual' ? null : card.tier, card.kind === 'virtual' ? 'Virtual' : card.tierLabel, card.status, true),
					el('div', { className: 'card-item-info' }, [
						el('div', { className: 'box-title' }, [el('strong', { textContent: `•••• ${card.last4}` }), card.kind === 'virtual' ? badge('Virtual') : null,
							badge(status[1] + (card.status === 'blocked' && card.blockedReason ? ` · ${card.blockedReason}` : ''), status[0])]),
						hint([card.holder, card.createdAt ? `emitido em ${when(card.createdAt)}` : '', card.expiresAt ? `válido até ${day(card.expiresAt)}` : ''].filter(Boolean).join(' · ')),
						...actions
					])
				]);
			}))
		);
	}

	// Empréstimos (pessoais e do negócio) ---------------------------------------------------------------------
	const loanDetail = (loan) => [`Juros de atraso: ${loan.lateRate}% ao dia sobre a parcela vencida`, loan.interest > 0 ? `já acumulados ${money(loan.interest)}` : ''].filter(Boolean).join(' · ');

	function loanBox(loan, label, actions, note) {
		return box([
			boxHead([el('strong', { textContent: label }), loan.late ? badge('Em atraso', 'is-bad') : badge('Em dia', 'is-ok')], el('span', { className: 'amount', textContent: money(loan.payable) })),
			el('div', { className: 'grid-4' }, [
				cell('Parcela', `${Math.min(loan.paidCount + 1, loan.installments)} de ${loan.installments}`),
				cell('Valor da parcela', money(loan.remaining)),
				cell('Vencimento', date(loan.dueAt)),
				cell('Total contratado', money(loan.total))
			]),
			el('div', { className: 'meter' }, [el('i', { style: `width:${loan.installments > 0 ? Math.min(100, loan.paidCount / loan.installments * 100) : 0}%` })]),
			actions ? row(actions, 'wrap') : null,
			hint(note)
		], loan.late);
	}

	// Agência: Crédito --------------------------------------------------------------------------------------
	function creditTab(body) {
		const credit = view.credit;
		if (!credit) {
			body.append(empty('Crédito indisponível no momento.'));
			return;
		}
		const account = credit.account;
		const tiers = credit.tiers || [];
		const progress = creditProgress(tiers, credit.score, account && account.tier, credit.eligible);
		const late = account && account.late;

		// Relacionamento
		const goal = progress.upgrade && !late
			? el('div', { className: 'goal is-ready', textContent: `${account ? 'Upgrade' : 'Cartão'} ${progress.upgrade.label} liberado pela sua pontuação. Peça abaixo, em Níveis.` })
			: progress.target
				? el('div', { className: 'goal', textContent: `Faltam ${progress.missing} pontos para ${progress.target.label}. Movimente a conta, mantenha saldo e pague as faturas em dia.` })
				: el('div', { className: 'goal is-ready', textContent: progress.currentIndex >= 0 ? 'Você está no maior nível do banco.' : 'Você atingiu a maior pontuação de relacionamento.' });
		body.append(
			title('Relacionamento'),
			box([
				boxHead([el('div', { className: 'score-value' }, [String(credit.score), el('small', { textContent: ' / 1000' })])],
					progress.currentIndex >= 0 ? badge(tiers[progress.currentIndex].label, 'is-accent') : badge('Sem crédito')),
				el('div', { className: 'score-track' }, [
					el('i', { style: `width:${Math.min(100, credit.score / 10)}%` }),
					...tiers.map((tier, index) => el('b', { className: index <= Math.max(progress.currentIndex, progress.eligibleIndex) ? 'is-reached' : '', style: `left:${tier.minScore / 10}%`, title: `${tier.label}: ${tier.minScore}` }))
				]),
				el('div', { className: 'score-legend' }, tiers.map((tier) => el('span', { style: `left:${tier.minScore / 10}%`, textContent: tier.label }))),
				goal
			])
		);

		// Conta de crédito e fatura
		if (account) {
			const tier = tiers[progress.currentIndex];
			const used = account.limit - account.available;
			const usage = account.limit > 0 ? Math.min(100, used / account.limit * 100) : 0;
			body.append(
				title('Cartão de crédito'),
				box([el('div', { className: 'card-row' }, [
					cardFace((view.cards || []).find((card) => card.status === 'active' && card.kind !== 'virtual')?.last4, view.holder, account.tier, tier && tier.label),
					el('div', { className: 'card-item-info', style: 'flex:1' }, [
						el('div', { className: 'grid-3' }, [cell('Limite', money(account.limit)), cell('Disponível', money(account.available)), cell('Pontos', String(account.points))]),
						el('div', { className: `meter is-usage${usage >= 90 ? ' is-full' : ''}` }, [el('i', { style: `width:${usage}%` })]),
						hint(`Usado ${money(used)} · a fatura fecha em ${date(account.closesAt)}`)
					])
				])])
			);

			const payAmount = amountInput('Valor', account.payable);
			const payTotal = button(`Pagar tudo · ${money(account.payable)}`, 'primary', async () => {
				const ok = await CoeUI.confirm({ title: 'Pagar cartão', message: `Debitar ${money(account.payable)} da conta (fatura + compras em aberto)?`, confirmLabel: 'Pagar' });
				if (ok) act('agency', 'creditPay', { mode: 'total' });
			});
			const payMin = button(`Pagar mínimo · ${money(account.minLeft)}`, null, () => act('agency', 'creditPay', { mode: 'min' }));
			const payCustom = button('Pagar valor', null, () => { const amount = readAmount(payAmount); if (amount) act('agency', 'creditPay', { mode: 'amount', amount }); });
			if (account.payable <= 0) { lock(payTotal); lock(payCustom); }
			if (account.minLeft <= 0) lock(payMin);
			const invoiceBadge = late ? badge('Em atraso', 'is-bad') : account.invoice > 0 && account.minLeft === 0 ? badge('Mínimo pago', 'is-ok') : account.invoice > 0 ? badge('Aberta') : badge('Sem fatura');
			body.append(box([
				boxHead([el('strong', { textContent: 'Fatura fechada' }), invoiceBadge], el('span', { className: 'amount', textContent: money(account.invoice) })),
				el('div', { className: 'grid-4' }, [
					cell('Mínimo', money(account.invoiceMin)),
					cell('Pago', money(account.invoicePaid)),
					cell('Vencimento', account.dueAt ? date(account.dueAt) : late ? 'Vencida' : '—'),
					cell('Compras em aberto', money(account.open))
				]),
				row([payTotal, payMin], 'wrap'),
				row([payAmount, payCustom]),
				hint(`Fatura semanal; vence ${credit.dueDays} dias após o fechamento. O que não for pago entra no rotativo com juros. Atraso gera multa, juros diários, bloqueio do crédito e débito automático.`)
			], late));
		}

		// Empréstimos pessoais e de negócios em que é devedor
		const loans = (credit.loans || []).filter((loan) => loan.status === 'active');
		if (loans.length > 0) {
			body.append(title('Empréstimos'), ...loans.map((loan) => loanBox(loan,
				loan.businessLabel ? `Empréstimo empresarial #${loan.id} · ${loan.businessLabel}` : `Empréstimo #${loan.id}`,
				[
					button(`Pagar parcela · ${money(loan.remaining)}`, 'primary', () => act('agency', 'loanPay', { loanId: loan.id, mode: 'installment' })),
					button(`Quitar · ${money(loan.payable)}`, null, async () => {
						const ok = await CoeUI.confirm({ title: 'Quitar empréstimo', message: `Debitar ${money(loan.payable)} da conta e quitar o empréstimo #${loan.id}?`, confirmLabel: 'Quitar' });
						if (ok) act('agency', 'loanPay', { loanId: loan.id, mode: 'total' });
					})
				],
				[loan.businessLabel ? `Débito automático no caixa de ${loan.businessLabel}; pagar por aqui debita da sua conta.` : 'Débito automático no vencimento.',
					'Atraso derruba a pontuação de relacionamento.', loanDetail(loan), loan.note].filter(Boolean).join(' · '))));
		}

		// Níveis
		const canRequest = Boolean(progress.upgrade) && !late;
		const request = button(canRequest ? (account ? `Fazer upgrade para ${progress.upgrade.label}` : `Solicitar cartão ${progress.upgrade.label}`)
			: late ? 'Regularize a fatura para pedir upgrade' : account ? 'Nenhum upgrade disponível' : 'Crédito ainda não liberado', 'primary', () => act('agency', 'creditRequest', {}));
		if (!canRequest) lock(request);
		body.append(title('Níveis'), el('div', { className: 'tiers' }, tiers.map((tier, index) => {
			const status = progress.states[index];
			const perks = [`Limite de ${money(tier.limit)}`, `${tier.pointsPer100} ponto(s) a cada $ 100 no crédito`,
				tier.fee > 0 ? `Anuidade de ${money(tier.fee)} por fatura` : 'Sem anuidade', tier.freeAtm ? 'Saques grátis no caixa eletrônico' : `Saque no caixa: ${money(credit.atmFee)}`];
			const kind = status.state === 'current' ? 'is-accent' : status.state === 'open' ? 'is-ok' : null;
			return el('div', { className: `tier tier-${tier.id} is-${status.state}` }, [
				el('div', { className: 'tier-head' }, [el('strong', { textContent: tier.label }), badge(status.label, kind)]),
				el('ul', {}, perks.map((perk) => el('li', { textContent: perk })))
			]);
		})), row([request], 'end'));

		// Movimentações do cartão
		const entries = credit.entries || [];
		if (account || entries.length > 0) {
			body.append(title('Movimentações do cartão'), entries.length === 0 ? empty('Sem movimentações.')
				: el('div', { className: 'ledger' }, entries.map((entry) => {
					const kind = CREDIT_OUT.has(entry.kind) ? 'is-in' : CREDIT_NEUTRAL.has(entry.kind) ? 'is-neutral' : 'is-out';
					return el('div', { className: `ledger-row ${kind}` }, [
						el('span', { className: 'ledger-icon', textContent: kind === 'is-in' ? '↓' : kind === 'is-out' ? '↑' : '•' }),
						el('div', { className: 'ledger-text' }, [el('div', { textContent: CREDIT_KINDS[entry.kind] || entry.kind }), el('small', { textContent: [date(entry.at), entry.description].filter(Boolean).join(' · ') })]),
						el('span', { className: 'ledger-value', textContent: entry.kind === 'staff_points' ? `${entry.amount > 0 ? '+' : '−'}${Math.abs(entry.amount)} pts` : money(entry.amount) })
					]);
				})));
		}
	}

	const TABS = [['account', 'Conta', accountTab], ['cards', 'Cartões', cardsTab], ['credit', 'Crédito', creditTab]];

	// Ponto vermelho na aba quando há algo atrasado.
	function tabAlert(id) {
		if (id === 'credit') {
			const credit = view.credit || {};
			return (credit.account && credit.account.late) || (credit.loans || []).some((loan) => loan.status === 'active' && loan.late);
		}
		if (id === 'cards') return !(view.cards || []).some((card) => card.status === 'active' && card.kind !== 'virtual');
		return false;
	}

	function renderAgency() {
		$('panel').classList.remove('atm');
		$('switch').hidden = !view.switchable;
		$('eyebrow').textContent = 'Conta pessoal';
		$('title').textContent = view.title || 'Banco';
		$('subtitle').textContent = view.holder ? `Cliente: ${view.holder}` : '';
		const credit = view.credit;
		const account = credit && credit.account;
		const tier = creditTier();
		$('summary').replaceChildren(
			kpi('Saldo em conta', view.balance != null ? money(view.balance) : '—', null, true),
			kpi('Em espécie', money(view.cash)),
			account ? kpi('Crédito disponível', money(account.available), tier ? `Cartão ${tier.label}` : null) : null,
			credit ? kpi('Relacionamento', `${credit.score} / 1000`) : null
		);
		$('tabs').replaceChildren(...TABS.map(([id, label]) => {
			const node = el('button', { type: 'button', className: `bank-tab${id === tab ? ' is-active' : ''}` }, [el('span', { textContent: label }), tabAlert(id) ? el('i', { className: 'dot', title: 'Requer atenção' }) : null]);
			node.onclick = () => { tab = id; render(); $('body').scrollTop = 0; };
			return node;
		}));
		const body = $('body');
		const scroll = body.scrollTop;
		body.replaceChildren();
		(TABS.find(([id]) => id === tab) || TABS[0])[2](body);
		body.scrollTop = scroll;
	}

	// Escolha da conta e conta empresarial ---------------------------------------------------------------------
	let businessTab = 'summary';
	const actBusiness = (action, data) => {
		if (pending) return;
		setPending(true);
		post('business', { action, data });
	};

	function renderChoose() {
		$('panel').classList.remove('atm');
		$('switch').hidden = true;
		$('eyebrow').textContent = 'Atendimento';
		$('title').textContent = view.title || 'Banco';
		$('subtitle').textContent = view.holder ? `Cliente: ${view.holder}` : '';
		$('summary').replaceChildren(kpi('Contas disponíveis', String(1 + (view.accounts || []).length), 'Pessoal e empresas'));
		$('tabs').replaceChildren();
		$('body').replaceChildren(window.CoeBusinessBank.chooser(view, (kind, id) => {
			if (pending) return;
			setPending(true);
			businessTab = 'summary';
			post('agencyAccount', { kind, id });
		}));
	}

	function renderBusiness() {
		const bank = window.CoeBusinessBank;
		$('panel').classList.remove('atm');
		$('switch').hidden = false;
		$('eyebrow').textContent = 'Conta empresarial';
		$('title').textContent = view.business ? view.business.label : 'Empresa';
		$('subtitle').textContent = [view.title, view.holder ? `Operador: ${view.holder}` : null].filter(Boolean).join(' · ');
		$('summary').replaceChildren(...bank.summary(view).filter(Boolean));
		const list = bank.sections(view);
		if (!list.some(([id]) => id === businessTab)) businessTab = list[0][0];
		$('tabs').replaceChildren(...list.map(([id, label, alert]) => {
			const node = el('button', { type: 'button', className: `bank-tab${id === businessTab ? ' is-active' : ''}` }, [el('span', { textContent: label }), alert ? el('i', { className: 'dot', title: 'Requer atenção' }) : null]);
			node.onclick = () => { businessTab = id; render(); $('body').scrollTop = 0; };
			return node;
		}));
		const body = $('body');
		const scroll = body.scrollTop;
		body.replaceChildren();
		businessTab = bank.renderSection(body, businessTab, view, { act: actBusiness, channel: 'agency' });
		body.scrollTop = scroll;
	}

	// Caixa eletrônico ---------------------------------------------------------------------------------------
	function renderAtm() {
		$('panel').classList.add('atm');
		$('switch').hidden = true;
		$('eyebrow').textContent = view.business ? 'Caixa eletrônico 24h · Empresarial' : 'Caixa eletrônico 24h';
		$('title').textContent = view.business || 'COE Bank';
		$('tabs').replaceChildren();
		const body = $('body');
		body.replaceChildren();

		if (view.step === 'cards' && pinCard == null) {
			$('subtitle').textContent = 'Escolha o cartão';
			$('summary').replaceChildren();
			$('summary').parentElement.hidden = true;
			body.append(title('Cartões no inventário'), el('div', { className: 'atm-cards' }, (view.cards || []).map((card) => {
				const node = el('button', { type: 'button', className: 'atm-card' }, [
					cardFace(card.last4, card.holder, null, null, card.status, true),
					el('div', {}, [el('strong', { textContent: `•••• ${card.last4}${card.business ? ' · ' + card.business : ''}` }), el('small', { textContent: card.status === 'active' ? (card.business ? `Empresarial · ${card.holder || ''}` : card.holder || '') : card.status === 'expired' ? 'Vencido' : 'Bloqueado' })])
				]);
				if (card.status !== 'active') lock(node);
				node.onclick = () => { pinCard = card; pin = ''; pinWarning = ''; render(); };
				return node;
			})));
			return;
		}

		if (view.step === 'cards') {
			$('subtitle').textContent = `Cartão •••• ${pinCard.last4}`;
			$('summary').replaceChildren();
			$('summary').parentElement.hidden = true;
			const dots = el('div', { className: 'pin-dots' }, [0, 1, 2, 3].map(() => el('i')));
			const paint = () => dots.querySelectorAll('i').forEach((dot, index) => dot.classList.toggle('is-on', index < pin.length));
			const submit = () => {
				if (pin.length === 4 && !pending) { setPending(true); post('atmAuth', { cardId: pinCard.id, pin }); pin = ''; paint(); }
			};
			const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'C', '0', 'OK'].map((key) => button(key, key === 'OK' ? 'primary' : null, () => {
				if (key === 'C') pin = '';
				else if (key === 'OK') submit();
				else if (pin.length < 4) pin += key;
				paint();
			}));
			pinKeys = (event) => {
				if (/^\d$/.test(event.key) && pin.length < 4) { pin += event.key; paint(); }
				else if (event.key === 'Backspace') { pin = pin.slice(0, -1); paint(); }
				else if (event.key === 'Enter') submit();
			};
			body.append(el('div', { className: 'pin' }, [
				el('span', { className: 'pin-label', textContent: 'Digite a senha' }), dots,
				el('p', { className: 'pin-warn', textContent: pinWarning }),
				el('div', { className: 'keypad' }, keys),
				button('Outro cartão', null, () => { pinCard = null; render(); })
			]));
			return;
		}

		pinKeys = null;
		$('summary').parentElement.hidden = false;
		$('subtitle').textContent = `Cartão •••• ${view.last4}${view.holder ? ' · ' + view.holder : ''}`;
		$('summary').replaceChildren(kpi(view.business ? 'Caixa da empresa' : 'Saldo', view.balance != null ? money(view.balance) : '—', null, true), kpi('Em espécie', money(view.cash)));
		const withdrawAmount = amountInput(`Até ${money(view.maxAmount)}`, view.maxAmount);
		const depositAmount = amountInput(`Até ${money(view.maxAmount)}`, view.maxAmount);
		body.append(
			el('div', { className: 'card-row' }, [cardFace(view.last4, view.holder, view.tier, view.business ? 'Empresarial' : view.tierLabel, 'active', true),
				hint([view.fee > 0 ? `Tarifa por saque: ${money(view.fee)}.` : (view.business ? 'Saques sem tarifa.' : 'Saques sem tarifa no seu nível.'),
					view.business ? (view.dailyLimit ? `Limite do cartão hoje: resta ${money(view.remaining)} de ${money(view.dailyLimit)}.` : 'Cartão sem limite diário.') : null].filter(Boolean).join(' '))]),
			title('Saque rápido'),
			el('div', { className: 'quick' }, (view.quick || []).map((amount) => button(money(amount), null, () => act('atm', 'withdraw', { amount })))),
			el('div', { className: 'grid-2' }, [
				box([el('strong', { textContent: 'Outro valor' }), row([withdrawAmount, button('Sacar', 'primary', () => { const amount = readAmount(withdrawAmount); if (amount) act('atm', 'withdraw', { amount }); })])]),
				box([el('strong', { textContent: 'Depósito' }), row([depositAmount, button('Depositar', 'primary', () => { const amount = readAmount(depositAmount); if (amount) act('atm', 'deposit', { amount }); })])])
			]),
			title('Últimas movimentações'),
			ledger(view.statement)
		);
	}

	let pinKeys = null;

	function render() {
		if (!view) return;
		if (view.mode === 'atm') renderAtm();
		else {
			pinKeys = null;
			$('summary').parentElement.hidden = false;
			if (view.mode === 'choose') renderChoose();
			else if (view.mode === 'business') renderBusiness();
			else renderAgency();
		}
		setPending(pending);
	}

	window.addEventListener('message', ({ data }) => {
		if (!data) return;
		if (data.type === 'open') {
			view = data.view;
			tab = 'account';
			businessTab = 'summary';
			pinCard = null;
			pin = '';
			pinWarning = '';
			pending = false;
			// Garante o tema do servidor e a cor do jogador (/hud) atualizados a cada abertura.
			post('coe_theme_ready');
			render();
			$('panel').hidden = false;
			$('body').scrollTop = 0;
		} else if (data.type === 'update') {
			view = data.view;
			pending = false;
			render();
		} else if (data.type === 'pinError') {
			pinWarning = `Senha incorreta. Tentativas restantes: ${data.remaining}`;
			pending = false;
			render();
		} else if (data.type === 'idle') {
			setPending(false);
		} else if (data.type === 'close') {
			$('panel').hidden = true;
			view = null;
			pinKeys = null;
		}
	});

	$('close').onclick = () => post('close');
	$('switch').onclick = () => { if (!pending) { setPending(true); post('agencyAccount', { kind: 'choose' }); } };
	document.addEventListener('keydown', (event) => {
		if ($('panel').hidden || document.querySelector('.coe-modal')) return;
		if (event.key === 'Escape') { post('close'); return; }
		if (pinKeys && !(event.target instanceof HTMLInputElement)) pinKeys(event);
	});

	// Para os testes de DOM (sem efeito no jogo).
	window.CoeBankProgress = creditProgress;
})();
