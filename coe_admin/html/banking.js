// Aba "Banco": níveis de cartão, crédito, pontos, cartões, empréstimos por cliente e criptomoeda. Usa os helpers de app.js.
// Só aparece para manageBanking (root ou ACE explícita); o servidor confere de novo em cada ação.
const BANK_TABS = [['clients', 'Clientes'], ['business', 'Empresas'], ['requests', 'Pedidos'], ['tiers', 'Níveis'], ['crypto', 'Cripto']];
const BANK_REQUEST_STATUS = { pending: 'Pendente', approved: 'Aprovado', rejected: 'Recusado', cancelled: 'Cancelado' };
const BANK_CARD_STATUS = { active: 'Ativo', expired: 'Vencido', blocked: 'Bloqueado' };
// Rótulos de bloqueio que vêm do coe_banking; só senha e staff podem ser desfeitos.
const BANK_UNBLOCKABLE = ['senha', 'bloqueado pela staff'];
const BANK_LOAN_STATUS = { active: 'Ativo', paid: 'Quitado', forgiven: 'Perdoado' };
const BANK_ENTRY = {
	tier: 'Nível liberado', downgrade: 'Nível rebaixado', closed: 'Fatura fechada', payment: 'Pagamento de fatura', auto_debit: 'Débito automático',
	late_fee: 'Multa por atraso', late_interest: 'Juros de atraso', revolving_interest: 'Juros do rotativo', annuity: 'Anuidade',
	purchase: 'Compra no crédito', refund: 'Estorno no crédito', points: 'Pontos', staff_tier: 'Ajuste da staff', staff_points: 'Pontos (staff)',
	loan_granted: 'Empréstimo concedido', loan_payment: 'Parcela paga', loan_late: 'Parcela em atraso', loan_paid: 'Empréstimo quitado',
	loan_forgiven: 'Saldo perdoado', loan_interest: 'Juros de atraso do empréstimo'
};

state.bank = {
	tab: 'clients', character: null, account: null, error: null, requestId: null, loading: false, tiers: null, tiersDirty: false,
	requests: null, requestsId: null, requestsLoading: false, requestsError: null,
	// Contas empresariais: lista, conta aberta e filtro do extrato.
	biz: { list: null, listId: null, account: null, accountId: null, selected: null, filter: { days: 30 }, loading: false, error: null }
};

const bankMoney = (value) => `$ ${Math.floor(Number(value) || 0).toLocaleString('pt-BR')}`;
const bankDate = (epoch) => {
	if (!epoch) return '—';
	const d = new Date(epoch * 1000);
	const two = (n) => String(n).padStart(2, '0');
	return `${two(d.getDate())}/${two(d.getMonth() + 1)}/${d.getFullYear()} ${two(d.getHours())}:${two(d.getMinutes())}`;
};

function bankMessage(text, success) {
	const message = document.getElementById('bank-message');
	if (!message) return;
	message.textContent = text || '';
	message.classList.toggle('is-success', success === true);
}

function bankButton(text, onClick, extra = '') {
	const button = bizEl('button', `biz-small-button ${extra}`.trim(), text);
	button.type = 'button';
	button.addEventListener('click', onClick);
	return button;
}

function bankStat(label, value) {
	const box = bizEl('div', 'bank-stat');
	box.append(bizEl('span', '', label), bizEl('strong', '', value));
	return box;
}

async function bankAction(action, payload, confirmOptions) {
	if (confirmOptions && !(await CoeUI.confirm(confirmOptions))) return;
	bankMessage('Enviando...');
	const result = await postNui('bankingAction', { action, payload });
	if (!result.ok) bankMessage('Não foi possível enviar a ação.', false);
}

function bankLoadAccount() {
	const character = state.bank.character;
	if (!character) return;
	state.bank.loading = true;
	state.bank.error = null;
	postNui('bankingAccount', { characterId: String(character.characterId) }).then((result) => {
		if (result.ok) state.bank.requestId = result.requestId;
		else state.bank.loading = false;
	});
	renderBankingBody();
}

const BANK_ERRORS = {
	forbidden: 'Sem permissão para o banco.', not_ready: 'O banco ainda está iniciando.', busy: 'Aguarde um instante.',
	character_not_found: 'Personagem sem conta bancária.'
};

function onBankingAccountResult(data) {
	if (data.requestId !== state.bank.requestId) return;
	state.bank.loading = false;
	state.bank.account = data.account || null;
	state.bank.error = data.account ? null : (BANK_ERRORS[data.error] || 'Não foi possível carregar a conta.');
	renderBankingBody();
}

function bankLoadRequests() {
	state.bank.requestsLoading = true;
	state.bank.requestsError = null;
	postNui('bankingRequests', {}).then((result) => {
		if (result.ok) state.bank.requestsId = result.requestId;
		else state.bank.requestsLoading = false;
	});
	renderBankingBody();
}

function onBankingRequestsResult(data) {
	if (data.requestId !== state.bank.requestsId) return;
	state.bank.requestsLoading = false;
	state.bank.requests = data.requests || null;
	state.bank.requestsError = data.requests ? null : (BANK_ERRORS[data.error] || 'Não foi possível carregar os pedidos.');
	if (state.bank.tab === 'requests') renderBankingBody();
}

function onBankingResult(data) {
	bankMessage(data.message, data.success === true);
	if (data.success !== true) return;
	if (state.bank.tab === 'tiers') state.bank.tiersDirty = false;
	if (state.bank.tab === 'requests') setTimeout(bankLoadRequests, 400);
	else if (state.bank.tab === 'business') setTimeout(bankBusinessReload, 400);
	else if (state.bank.character) setTimeout(bankLoadAccount, 400);
}

function renderBanking() {
	const tabs = document.getElementById('bank-tabs');
	if (!tabs) return;
	tabs.replaceChildren();
	for (const [key, text] of BANK_TABS) {
		const button = bizEl('button', `biz-tab${key === state.bank.tab ? ' is-active' : ''}`, text);
		button.type = 'button';
		button.addEventListener('click', () => {
			state.bank.tab = key;
			renderBanking();
			if (key === 'requests') bankLoadRequests();
			if (key === 'business') bankBusinessReload();
		});
		tabs.append(button);
	}
	if (!state.bank.tiersDirty) {
		state.bank.tiers = (state.data?.banking?.tiers || []).map((tier) => ({ ...tier }));
	}
	renderBankingBody();
}

function renderBankingBody() {
	const body = document.getElementById('bank-body');
	if (!body) return;
	body.replaceChildren();
	if (state.bank.tab === 'crypto') {
		if (typeof renderCryptoBody === 'function') {
			const subTabs = bizEl('div', 'biz-sections');
			subTabs.setAttribute('role', 'tablist');
			for (const [key, label] of (window.CRYPTO_TABS || [])) {
				const btn = bizEl('button', `biz-tab${key === state.crypto?.tab ? ' is-active' : ''}`, label);
				btn.type = 'button';
				btn.addEventListener('click', () => {
					state.crypto.tab = key;
					renderBankingBody();
				});
				subTabs.append(btn);
			}
			const subBody = bizEl('div', '');
			body.append(subTabs, subBody);
			renderCryptoBody(subBody);
		}
		return;
	}
	if (!state.data?.banking?.available) {
		appendEmpty(body, 'O resource coe_banking não está iniciado.');
		return;
	}
	if (state.bank.tab === 'tiers') renderBankTiers(body);
	else if (state.bank.tab === 'requests') renderBankRequests(body);
	else if (state.bank.tab === 'business') renderBankBusiness(body);
	else renderBankClients(body);
}

// Contas empresariais --------------------------------------------------------------------------------
// Caixa de cada negócio no coe_banking: saldo, extrato com quem fez cada operação, cartões empresariais e ajuste da staff.

const BANK_BIZ_REASONS = {
	society_deposit: 'Depósito', business_deposit: 'Depósito', society_withdraw: 'Saque', business_withdraw: 'Saque',
	business_payment: 'Pagamento', business_transfer: 'Transferência entre empresas', business_bonus: 'Bônus', payroll: 'Salário',
	business_card: 'Compra com cartão', business_card_refund: 'Estorno de compra', card_fee: 'Tarifa de cartão', atm_fee: 'Tarifa de saque',
	bank_loan: 'Empréstimo recebido', loan_payment: 'Parcela de empréstimo', bank_refund: 'Estorno', admin_adjustment: 'Ajuste da staff'
};

function bankBusinessLoad(op) {
	const biz = state.bank.biz;
	biz.loading = true;
	biz.error = null;
	postNui('bankingBusiness', { op, businessId: biz.selected, filter: biz.filter }).then((result) => {
		if (!result.ok) {
			biz.loading = false;
			return;
		}
		if (op === 'account') biz.accountId = result.requestId;
		else biz.listId = result.requestId;
	});
	renderBankingBody();
}

function bankBusinessReload() {
	bankBusinessLoad(state.bank.biz.selected ? 'account' : 'list');
}

function onBankingBusinessResult(data) {
	const biz = state.bank.biz;
	if (data.requestId !== biz.accountId && data.requestId !== biz.listId) return;
	biz.loading = false;
	if (data.requestId === biz.accountId) biz.account = data.result || null;
	else biz.list = data.result && data.result.accounts || null;
	biz.error = data.result ? null : (BANK_ERRORS[data.error] || 'Não foi possível carregar.');
	if (state.bank.tab === 'business') renderBankingBody();
}

function renderBankBusiness(body) {
	const biz = state.bank.biz;
	if (biz.selected) {
		renderBankBusinessAccount(body);
		return;
	}
	const box = bizEl('div', 'biz-block');
	const head = bizEl('div', 'biz-block-head');
	head.append(bizEl('h3', '', 'Contas empresariais'), bankButton('Atualizar', () => bankBusinessLoad('list')));
	box.append(head, bizEl('p', 'biz-hint', 'O caixa de cada negócio. Abra uma conta para ver o extrato com quem fez cada operação, os cartões empresariais e ajustar o saldo.'));
	body.append(box);
	if (biz.loading && !biz.list) {
		box.append(bizEl('p', 'biz-hint', 'Carregando...'));
		return;
	}
	if (biz.error) box.append(bizEl('p', 'biz-hint', biz.error));
	const list = bizEl('div', 'bank-list');
	for (const account of biz.list || []) {
		const row = bizEl('div', 'bank-row');
		const info = bizEl('div', 'bank-row-info');
		info.append(
			bizEl('strong', '', `${account.label}${account.enabled ? '' : ' (desativado)'}`),
			bizEl('span', 'biz-hint', [account.owner ? `Dono: ${account.owner}` : 'Sem dono', `${account.cards} cartão(ões) ativo(s)`, account.loans ? `${account.loans} empréstimo(s)` : null].filter(Boolean).join(' · '))
		);
		const actions = bizEl('div', 'bank-row-actions');
		actions.append(bizEl('span', 'bank-amount', account.balance != null ? bankMoney(account.balance) : '—'), bankButton('Abrir', () => {
			biz.selected = account.id;
			biz.account = null;
			biz.filter = { days: 30 };
			bankBusinessLoad('account');
		}));
		row.append(info, actions);
		list.append(row);
	}
	if ((biz.list || []).length) box.append(list);
	else if (!biz.loading) box.append(bizEl('p', 'biz-hint', 'Nenhum negócio cadastrado.'));
}

function renderBankBusinessAccount(body) {
	const biz = state.bank.biz;
	const account = biz.account;
	const top = bizEl('div', 'biz-block');
	const head = bizEl('div', 'biz-block-head');
	head.append(bizEl('h3', '', account?.business?.label || biz.selected), bankButton('Voltar à lista', () => {
		biz.selected = null;
		biz.account = null;
		bankBusinessLoad('list');
	}));
	top.append(head);
	body.append(top);
	if (biz.loading && !account) {
		top.append(bizEl('p', 'biz-hint', 'Carregando...'));
		return;
	}
	if (!account) {
		top.append(bizEl('p', 'biz-hint', biz.error || 'Conta indisponível.'));
		return;
	}
	const report = account.report || {};
	const stats = bizEl('div', 'bank-stats');
	stats.append(bankStat('Saldo do caixa', bankMoney(account.balance)), bankStat(`Entradas · ${report.days || 0} dias`, bankMoney(report.inflow)),
		bankStat(`Saídas · ${report.days || 0} dias`, bankMoney(report.outflow)), bankStat('Lançamentos', String(report.count || 0)),
		bankStat('Dono', account.business?.owner || '—'));
	top.append(stats);

	// Ajuste da staff no caixa.
	const draft = { delta: '', note: '' };
	const adjust = bizEl('div', 'bank-form');
	adjust.append(
		bizField('Ajuste (+ credita, − debita)', bizInput('number', '', (value) => { draft.delta = value; }, { step: 1 })),
		bizField('Observação', bizInput('text', '', (value) => { draft.note = value; }, { maxLength: 48 }))
	);
	const actions = bizEl('div', 'bank-actions');
	actions.append(bankButton('Ajustar caixa', () => {
		const delta = Number(draft.delta);
		if (!Number.isInteger(delta) || delta === 0) { bankMessage('Informe um valor inteiro diferente de zero.', false); return; }
		bankAction('businessAdjust', { businessId: biz.selected, delta, note: draft.note.trim() }, {
			title: 'Ajustar caixa da empresa', message: `${delta > 0 ? 'Creditar' : 'Debitar'} ${bankMoney(Math.abs(delta))} no caixa de ${account.business?.label}? Fica no extrato como ajuste da staff.`,
			confirmLabel: 'Ajustar', danger: delta < 0
		});
	}, 'bank-primary'));
	top.append(bizEl('h3', 'bank-subtitle', 'Ajuste do caixa'), adjust, actions);

	// Extrato com filtro de período.
	const ledgerBox = bizEl('div', 'biz-block');
	const ledgerHead = bizEl('div', 'biz-block-head');
	const periods = bizEl('div', 'bank-row-actions');
	for (const days of account.periods || [1, 7, 30, 90]) {
		periods.append(bankButton(days === 1 ? 'Hoje' : `${days} dias`, () => {
			biz.filter = { days };
			bankBusinessLoad('account');
		}, account.filter?.days === days ? 'bank-primary' : ''));
	}
	ledgerHead.append(bizEl('h3', '', 'Extrato'), periods);
	ledgerBox.append(ledgerHead);
	const rows = account.statement || [];
	if (!rows.length) ledgerBox.append(bizEl('p', 'biz-hint', 'Sem lançamentos no período.'));
	const list = bizEl('div', 'bank-list');
	for (const entry of rows) {
		const row = bizEl('div', 'bank-row');
		const info = bizEl('div', 'bank-row-info');
		info.append(
			bizEl('strong', '', BANK_BIZ_REASONS[entry.reason] || String(entry.reason || '').replace(/_/g, ' ')),
			bizEl('span', 'biz-hint', [bankDate(entry.at), entry.counterparty, entry.actor ? `por ${entry.actor}` : null, entry.memo ? `"${entry.memo}"` : null].filter(Boolean).join(' · '))
		);
		row.append(info, bizEl('span', 'bank-amount', `${entry.delta < 0 ? '−' : '+'} ${bankMoney(Math.abs(entry.delta))}`));
		list.append(row);
	}
	if (rows.length) ledgerBox.append(list);
	body.append(ledgerBox);

	// Cartões empresariais.
	const cardsBox = bizEl('div', 'biz-block');
	cardsBox.append(bizEl('h3', '', 'Cartões empresariais'), bizEl('p', 'biz-hint', 'Débito no caixa da empresa com limite diário. Limite 0 = sem limite.'));
	const cards = account.cards || [];
	if (!cards.length) cardsBox.append(bizEl('p', 'biz-hint', 'Nenhum cartão emitido.'));
	const cardList = bizEl('div', 'bank-list');
	for (const card of cards) {
		const row = bizEl('div', 'bank-row');
		const info = bizEl('div', 'bank-row-info');
		info.append(
			bizEl('strong', '', `•••• ${card.last4} · ${card.holder} · ${BANK_CARD_STATUS[card.status] || card.status}${card.blockedReason ? ' (' + card.blockedReason + ')' : ''}${card.holderActive === false ? ' · titular saiu' : ''}`),
			bizEl('span', 'biz-hint', `${card.dailyLimit ? `Limite ${bankMoney(card.dailyLimit)}/dia · hoje ${bankMoney(card.spentToday)}` : `Sem limite · hoje ${bankMoney(card.spentToday)}`} · válido até ${bankDate(card.expiresAt)}`)
		);
		const cardActions = bizEl('div', 'bank-row-actions');
		let limit = String(card.dailyLimit || 0);
		cardActions.append(bizInput('number', limit, (value) => { limit = value; }, { min: 0, step: 1 }),
			bankButton('Salvar limite', () => bankAction('businessCardLimit', { cardId: card.id, dailyLimit: Number(limit) })));
		if (card.status !== 'blocked') {
			cardActions.append(bankButton('Bloquear', () => bankAction('card', { cardId: card.id, op: 'block' }, {
				title: 'Bloquear cartão empresarial', message: `Bloquear o cartão •••• ${card.last4} de ${card.holder}?`, confirmLabel: 'Bloquear', danger: true
			}), 'biz-danger'));
		} else if (BANK_UNBLOCKABLE.includes(card.blockedReason)) {
			cardActions.append(bankButton('Desbloquear', () => bankAction('card', { cardId: card.id, op: 'unblock' })));
		}
		if (card.status !== 'blocked' || BANK_UNBLOCKABLE.includes(card.blockedReason)) {
			cardActions.append(bankButton('Renovar validade', () => bankAction('card', { cardId: card.id, op: 'extend' })));
		}
		row.append(info, cardActions);
		cardList.append(row);
	}
	if (cards.length) cardsBox.append(cardList);
	body.append(cardsBox);

	const loans = account.loans || [];
	if (loans.length) {
		const loansBox = bizEl('div', 'biz-block');
		loansBox.append(bizEl('h3', '', 'Empréstimos ativos'));
		for (const loan of loans) {
			loansBox.append(bizEl('p', 'biz-hint', `#${loan.id} · ${bankMoney(loan.payable)} a pagar · parcela ${Math.min(loan.paidCount + 1, loan.installments)} de ${loan.installments}${loan.late ? ' · em atraso' : ''}`));
		}
		body.append(loansBox);
	}
}

// Pedidos de empréstimo empresarial ---------------------------------------------------------------

function renderBankRequests(body) {
	const box = bizEl('div', 'biz-block');
	const head = bizEl('div', 'biz-block-head');
	head.append(bizEl('h3', '', 'Pedidos de empréstimo empresarial'), bankButton('Atualizar', bankLoadRequests));
	box.append(head, bizEl('p', 'biz-hint', 'Aprovado, o valor cai no caixa do negócio e a dívida fica com o proprietário e os sócios atuais. As parcelas saem do caixa; se faltar, a parcela atrasa, corre juros diários e o relacionamento de todos cai. Juros sugeridos pela pontuação média dos devedores; os juros diários de atraso seguem a mesma pontuação.'));
	body.append(box);
	if (state.bank.requestsLoading) {
		box.append(bizEl('p', 'biz-hint', 'Carregando pedidos...'));
		return;
	}
	if (state.bank.requestsError) {
		box.append(bizEl('p', 'biz-hint', state.bank.requestsError));
		return;
	}
	const data = state.bank.requests;
	if (!data) return;
	const limits = data.limits || {};
	const pending = data.pending || [];
	if (!pending.length) box.append(bizEl('p', 'biz-hint', 'Nenhum pedido pendente.'));
	const list = bizEl('div', 'bank-list');
	for (const request of pending) {
		const suggested = request.suggested || {};
		const draft = { rate: String(suggested.rate ?? request.rate), installments: String(request.installments), reason: '' };
		const item = bizEl('div', 'bank-request');
		item.append(
			bizEl('strong', '', `#${request.id} · ${request.businessLabel || request.businessId} · ${bankMoney(request.principal)} em ${request.installments}x`),
			bizEl('span', 'biz-hint', [
				`Pedido em ${bankDate(request.createdAt)} pelo proprietário (personagem ${request.characterId})`,
				`${request.debtors} devedor(es)`, `pontuação média ${request.currentScore} / 1000`,
				`juros sugeridos ${suggested.rate}% · atraso ${suggested.lateDailyRate}% ao dia`
			].join(' · ') + (request.note ? ` · "${request.note}"` : ''))
		);
		const grid = bizEl('div', 'bank-form');
		grid.append(
			bizField(`Juros totais % (até ${limits.maxRate || 100})`, bizInput('number', draft.rate, (value) => { draft.rate = value; }, { min: 0, max: limits.maxRate || 100, step: 0.01 })),
			bizField(`Parcelas (até ${limits.maxInstallments || 52})`, bizInput('number', draft.installments, (value) => { draft.installments = value; }, { min: 1, max: limits.maxInstallments || 52, step: 1 })),
			bizField('Motivo (obrigatório para recusar)', bizInput('text', draft.reason, (value) => { draft.reason = value; }, { maxlength: 64 }))
		);
		const actions = bizEl('div', 'bank-actions');
		actions.append(
			bankButton('Recusar', () => {
				const reason = draft.reason.trim();
				if (!reason) {
					bankMessage('Informe o motivo da recusa.', false);
					return;
				}
				bankAction('decideRequest', { requestId: request.id, approve: false, reason }, {
					title: 'Recusar pedido', message: `Recusar o pedido de ${request.businessLabel}? Motivo: ${reason}`, confirmLabel: 'Recusar', danger: true
				});
			}, 'biz-danger'),
			bankButton('Aprovar', () => {
				const rate = Number(draft.rate);
				const installments = Number(draft.installments);
				if (!(rate >= 0) || !Number.isInteger(installments) || installments <= 0) {
					bankMessage('Confira juros e parcelas.', false);
					return;
				}
				const total = request.principal + Math.ceil(request.principal * rate / 100 - 1e-9);
				bankAction('decideRequest', { requestId: request.id, approve: true, rate, installments, reason: draft.reason.trim() }, {
					title: 'Aprovar empréstimo empresarial',
					message: `Creditar ${bankMoney(request.principal)} no caixa de ${request.businessLabel}? Total ${bankMoney(total)} em ${installments} parcela(s), atraso a ${suggested.lateDailyRate}% ao dia. A dívida fica com o proprietário e os sócios.`,
					confirmLabel: 'Aprovar'
				});
			}, 'bank-primary')
		);
		item.append(grid, actions);
		list.append(item);
	}
	box.append(list);

	const history = data.history || [];
	const past = bizEl('div', 'biz-block');
	past.append(bizEl('h3', '', 'Decididos recentemente'));
	if (!history.length) past.append(bizEl('p', 'biz-hint', 'Nenhum pedido decidido.'));
	const pastList = bizEl('div', 'bank-list');
	for (const request of history) {
		const row = bizEl('div', 'bank-row');
		const info = bizEl('div', 'bank-row-info');
		info.append(
			bizEl('strong', '', `#${request.id} · ${request.businessLabel || request.businessId} · ${BANK_REQUEST_STATUS[request.status] || request.status}`),
			bizEl('span', 'biz-hint', [`${bankMoney(request.principal)} em ${request.installments}x`, `${request.rate}% · atraso ${request.lateRate}% ao dia`,
				bankDate(request.decidedAt), request.loanId ? `empréstimo #${request.loanId}` : '', request.reason].filter(Boolean).join(' · '))
		);
		row.append(info);
		pastList.append(row);
	}
	past.append(pastList);
	body.append(past);
}

// Níveis ------------------------------------------------------------------------------------------

function renderBankTiers(body) {
	const tiers = state.bank.tiers || [];
	const limits = state.data.banking.limits || {};
	const box = bizEl('div', 'biz-block');
	box.append(
		bizEl('h3', '', 'Níveis do cartão de crédito'),
		bizEl('p', 'biz-hint', 'Os ids são fixos. A pontuação mínima (0 a 1000) deve crescer e o limite não pode diminuir de um nível para o próximo. Vale na hora para todos os clientes, exceto quem tem limite personalizado.')
	);
	const table = bizEl('div', 'bank-tiers');
	const head = bizEl('div', 'bank-tier-row bank-tier-head');
	for (const text of ['Nível', 'Nome', 'Pontuação mín.', 'Limite', 'Pontos / $100', 'Anuidade', 'Saque grátis']) head.append(bizEl('span', '', text));
	table.append(head);
	const dirty = () => { state.bank.tiersDirty = true; };
	for (const tier of tiers) {
		const row = bizEl('div', 'bank-tier-row');
		const free = bizEl('input');
		free.type = 'checkbox';
		free.checked = tier.freeAtm === true;
		free.addEventListener('change', () => { tier.freeAtm = free.checked; dirty(); });
		row.append(
			bizEl('code', '', tier.id),
			bizInput('text', tier.label, (value) => { tier.label = value; dirty(); }, { maxlength: 24 }),
			bizInput('number', tier.minScore, (value) => { tier.minScore = bizNumber(value, 0); dirty(); }, { min: 0, max: 1000, step: 1 }),
			bizInput('number', tier.limit, (value) => { tier.limit = bizNumber(value, 0); dirty(); }, { min: 0, max: limits.maxLimit || 10000000, step: 1 }),
			bizInput('number', tier.pointsPer100, (value) => { tier.pointsPer100 = bizNumber(value, 0); dirty(); }, { min: 0, max: 100, step: 0.01 }),
			bizInput('number', tier.fee, (value) => { tier.fee = bizNumber(value, 0); dirty(); }, { min: 0, step: 1 }),
			free
		);
		table.append(row);
	}
	box.append(table);
	const actions = bizEl('div', 'bank-actions');
	actions.append(
		bankButton('Descartar alterações', () => { state.bank.tiersDirty = false; renderBanking(); }),
		bankButton('Salvar níveis', () => bankAction('saveTiers', { tiers }, {
			title: 'Salvar níveis', message: 'Os novos valores valem imediatamente para todos os clientes.', confirmLabel: 'Salvar'
		}), 'bank-primary')
	);
	box.append(actions);
	body.append(box);
}

// Clientes ----------------------------------------------------------------------------------------

function renderBankClients(body) {
	const search = bizEl('div', 'biz-block');
	search.append(bizEl('h3', '', 'Cliente'), bizField('Buscar pelo nome do personagem ou ID', bizCharacterPicker((character) => {
		state.bank.character = character;
		state.bank.account = null;
		bankLoadAccount();
	})));
	body.append(search);
	const character = state.bank.character;
	if (!character) {
		body.append(bizEl('p', 'biz-hint', 'Escolha um personagem para ver cartões, crédito e empréstimos.'));
		return;
	}
	if (state.bank.loading) {
		body.append(bizEl('p', 'biz-hint', `Carregando ${character.name}...`));
		return;
	}
	if (state.bank.error) {
		body.append(bizEl('p', 'biz-hint', state.bank.error));
		return;
	}
	const account = state.bank.account;
	if (!account) return;

	const summary = bizEl('div', 'biz-block');
	const head = bizEl('div', 'biz-block-head');
	head.append(bizEl('h3', '', `${character.name} · ${character.stateId || ''}`), bankButton('Atualizar', bankLoadAccount));
	const stats = bizEl('div', 'bank-stats');
	const eligible = (account.tiers || []).find((tier) => tier.id === account.eligible);
	stats.append(
		bankStat('Saldo', bankMoney(account.balance)),
		bankStat('Relacionamento', `${account.score} / 1000`),
		bankStat('Nível pela pontuação', eligible ? eligible.label : 'Nenhum')
	);
	summary.append(head, stats);
	body.append(summary, renderBankCredit(account), renderBankCards(account), renderBankLoans(account), renderBankEntries(account));
}

function renderBankCredit(account) {
	const credit = account.credit || null;
	const tiers = account.tiers || [];
	const limits = account.limits || {};
	const box = bizEl('div', 'biz-block');
	box.append(bizEl('h3', '', 'Cartão de crédito'));
	if (credit) {
		const tier = tiers.find((entry) => entry.id === credit.tier);
		const stats = bizEl('div', 'bank-stats');
		stats.append(
			bankStat('Nível', (tier ? tier.label : credit.tier) + (credit.tierLocked ? ' (travado)' : '')),
			bankStat('Limite', bankMoney(credit.limit) + (credit.customLimit != null ? ' (personalizado)' : '')),
			bankStat('Disponível', bankMoney(credit.available)),
			bankStat('Fatura', bankMoney(credit.invoice) + (credit.late ? ' · em atraso' : '')),
			bankStat('Pontos', String(credit.points))
		);
		box.append(stats);
	} else {
		box.append(bizEl('p', 'biz-hint', 'Sem conta de crédito. Escolher um nível abaixo libera o cartão de crédito para o cliente, mesmo sem pontuação.'));
	}

	const draft = { tier: credit ? credit.tier : (tiers[0] && tiers[0].id), custom: credit && credit.customLimit != null ? credit.customLimit : '', locked: credit ? credit.tierLocked === true : true };
	const select = bizEl('select', 'coe-field field-control');
	for (const tier of tiers) select.append(new Option(`${tier.label} (limite ${bankMoney(tier.limit)})`, tier.id));
	select.value = draft.tier;
	select.addEventListener('change', () => { draft.tier = select.value; });
	const grid = bizEl('div', 'bank-form');
	grid.append(
		bizField('Nível', select),
		bizField(`Limite personalizado (vazio = do nível; até ${bankMoney(limits.maxLimit)})`, bizInput('number', draft.custom, (value) => { draft.custom = value; }, { min: 0, max: limits.maxLimit || 10000000, step: 1 }))
	);
	box.append(grid, garCheck('Travar nível (não rebaixa por pontuação baixa)', draft.locked, (checked) => { draft.locked = checked; }));
	const actions = bizEl('div', 'bank-actions');
	actions.append(bankButton(credit ? 'Salvar crédito' : 'Liberar crédito', () => {
		const custom = String(draft.custom).trim();
		const customLimit = custom === '' ? false : Number(custom);
		if (customLimit !== false && (!Number.isInteger(customLimit) || customLimit < 0)) {
			bankMessage('Limite personalizado inválido.', false);
			return;
		}
		const tier = tiers.find((entry) => entry.id === draft.tier);
		bankAction('setCredit', { characterId: account.characterId, tier: draft.tier, customLimit, tierLocked: draft.locked }, {
			title: credit ? 'Ajustar crédito' : 'Liberar crédito',
			message: `${tier ? tier.label : draft.tier} com limite de ${bankMoney(customLimit === false ? (tier ? tier.limit : 0) : customLimit)}${draft.locked ? ', nível travado' : ''}.`,
			confirmLabel: 'Confirmar'
		});
	}, 'bank-primary'));
	box.append(actions);

	if (credit) {
		let delta = '';
		const points = bizEl('div', 'bank-inline');
		points.append(
			bizField('Ajustar pontos (negativo remove)', bizInput('number', '', (value) => { delta = value; }, { step: 1 })),
			bankButton('Aplicar', () => {
				const value = Number(delta);
				if (!Number.isInteger(value) || value === 0) {
					bankMessage('Informe um número inteiro diferente de zero.', false);
					return;
				}
				bankAction('points', { characterId: account.characterId, delta: value });
			})
		);
		box.append(points);
	}
	return box;
}

function renderBankCards(account) {
	const box = bizEl('div', 'biz-block');
	box.append(bizEl('h3', '', 'Cartões'), bizEl('p', 'biz-hint', `Validade de ${account.limits?.cardValidityDays || 60} dias. Renovar estende a partir de hoje; desbloquear só desfaz bloqueio por senha ou da staff.`));
	const cards = account.cards || [];
	if (!cards.length) {
		box.append(bizEl('p', 'biz-hint', 'Nenhum cartão emitido.'));
		return box;
	}
	const list = bizEl('div', 'bank-list');
	for (const card of cards) {
		const row = bizEl('div', 'bank-row');
		const info = bizEl('div', 'bank-row-info');
		info.append(
			bizEl('strong', '', `•••• ${card.last4}${card.kind === 'virtual' ? ' (virtual)' : ''} · ${BANK_CARD_STATUS[card.status] || card.status}${card.blockedReason ? ' (' + card.blockedReason + ')' : ''}`),
			bizEl('span', 'biz-hint', `Válido até ${bankDate(card.expiresAt)}`)
		);
		const actions = bizEl('div', 'bank-row-actions');
		if (card.status !== 'blocked') {
			actions.append(bankButton('Bloquear', () => bankAction('card', { cardId: card.id, op: 'block' }, {
				title: 'Bloquear cartão', message: `Bloquear o cartão •••• ${card.last4}? O cliente não consegue desbloquear sozinho.`, confirmLabel: 'Bloquear', danger: true
			}), 'biz-danger'));
		} else if (BANK_UNBLOCKABLE.includes(card.blockedReason)) {
			actions.append(bankButton('Desbloquear', () => bankAction('card', { cardId: card.id, op: 'unblock' })));
		}
		if (card.status !== 'blocked' || BANK_UNBLOCKABLE.includes(card.blockedReason)) {
			actions.append(bankButton('Renovar validade', () => bankAction('card', { cardId: card.id, op: 'extend' })));
		}
		row.append(info, actions);
		list.append(row);
	}
	box.append(list);
	return box;
}

function renderBankLoans(account) {
	const limits = account.limits || {};
	const box = bizEl('div', 'biz-block');
	box.append(bizEl('h3', '', 'Empréstimos'));
	const loans = account.loans || [];
	if (!loans.length) box.append(bizEl('p', 'biz-hint', 'Nenhum empréstimo.'));
	const list = bizEl('div', 'bank-list');
	for (const loan of loans) {
		const row = bizEl('div', 'bank-row');
		const info = bizEl('div', 'bank-row-info');
		const parts = [`${bankMoney(loan.principal)} a ${loan.rate}% = ${bankMoney(loan.total)}`, `${loan.paidCount}/${loan.installments} parcelas`, `atraso ${loan.lateRate}% ao dia`];
		if (loan.interest > 0) parts.push(`juros de atraso ${bankMoney(loan.interest)}`);
		if (loan.status === 'active') parts.push(`falta ${bankMoney(loan.payable)}`, `vence ${bankDate(loan.dueAt)}`);
		const business = loan.businessLabel ? ` · Empresarial: ${loan.businessLabel}` : '';
		info.append(
			bizEl('strong', '', `#${loan.id}${business} · ${BANK_LOAN_STATUS[loan.status] || loan.status}${loan.late ? ' · em atraso' : ''}${loan.lateCount ? ` · ${loan.lateCount} atraso(s)` : ''}`),
			bizEl('span', 'biz-hint', parts.join(' · ') + (loan.note ? ` · ${loan.note}` : ''))
		);
		const actions = bizEl('div', 'bank-row-actions');
		if (loan.status === 'active') {
			actions.append(bankButton('Perdoar saldo', () => bankAction('forgiveLoan', { loanId: loan.id }, {
				title: 'Perdoar empréstimo', message: `Encerrar o empréstimo #${loan.id} perdoando ${bankMoney(loan.payable)}?`, confirmLabel: 'Perdoar', danger: true
			}), 'biz-danger'));
		}
		row.append(info, actions);
		list.append(row);
	}
	box.append(list);

	const pricing = account.pricing || {};
	const draft = { principal: '', rate: String(pricing.rate ?? 10), installments: '4', note: '' };
	const preview = bizEl('p', 'biz-hint');
	const update = () => {
		const principal = Number(draft.principal);
		const rate = Number(draft.rate);
		const count = Number(draft.installments);
		if (!(principal > 0) || !(rate >= 0) || !(count >= 1)) {
			preview.textContent = 'Informe valor, juros e parcelas.';
			return;
		}
		const total = principal + Math.ceil(principal * rate / 100 - 1e-9);
		preview.textContent = `Total ${bankMoney(total)} em ${count} parcela(s) de ~${bankMoney(Math.ceil(total / count))}, uma a cada ${limits.intervalDays || 7} dias, com débito automático. Atraso: ${pricing.lateDailyRate ?? '-'}% ao dia (pela pontuação ${account.score}).`;
	};
	const grid = bizEl('div', 'bank-form');
	grid.append(
		bizField(`Valor (até ${bankMoney(limits.maxPrincipal)})`, bizInput('number', draft.principal, (value) => { draft.principal = value; update(); }, { min: 1, max: limits.maxPrincipal || 1000000, step: 1 })),
		bizField(`Juros totais % (até ${limits.maxRate || 100})`, bizInput('number', draft.rate, (value) => { draft.rate = value; update(); }, { min: 0, max: limits.maxRate || 100, step: 0.01 })),
		bizField(`Parcelas (até ${limits.maxInstallments || 52})`, bizInput('number', draft.installments, (value) => { draft.installments = value; update(); }, { min: 1, max: limits.maxInstallments || 52, step: 1 })),
		bizField('Observação (opcional)', bizInput('text', draft.note, (value) => { draft.note = value; }, { maxlength: 64 }))
	);
	update();
	const actions = bizEl('div', 'bank-actions');
	actions.append(bankButton('Conceder empréstimo', () => {
		const principal = Number(draft.principal);
		const installments = Number(draft.installments);
		const rate = Number(draft.rate);
		if (!Number.isInteger(principal) || principal <= 0 || !Number.isInteger(installments) || installments <= 0 || !(rate >= 0)) {
			bankMessage('Confira valor, juros e parcelas.', false);
			return;
		}
		bankAction('grantLoan', { characterId: account.characterId, principal, rate, installments, note: draft.note }, {
			title: 'Conceder empréstimo', message: `Creditar ${bankMoney(principal)} na conta de ${state.bank.character.name}? ${preview.textContent}`, confirmLabel: 'Conceder'
		});
	}, 'bank-primary'));
	box.append(bizEl('h3', 'bank-subtitle', 'Novo empréstimo'), bizEl('p', 'biz-hint', `Juros sugeridos pela pontuação: ${pricing.rate ?? '-'}%.`), grid, preview, actions);
	return box;
}

function renderBankEntries(account) {
	const box = bizEl('div', 'biz-block');
	box.append(bizEl('h3', '', 'Movimentações de crédito e empréstimos'));
	const entries = account.entries || [];
	if (!entries.length) {
		box.append(bizEl('p', 'biz-hint', 'Sem movimentações.'));
		return box;
	}
	const list = bizEl('div', 'bank-list');
	for (const entry of entries) {
		const row = bizEl('div', 'bank-row');
		const info = bizEl('div', 'bank-row-info');
		info.append(bizEl('strong', '', BANK_ENTRY[entry.kind] || entry.kind), bizEl('span', 'biz-hint', [bankDate(entry.at), entry.description].filter(Boolean).join(' · ')));
		row.append(info, bizEl('span', 'bank-amount', entry.kind === 'staff_points' ? `${entry.amount} pts` : bankMoney(entry.amount)));
		list.append(row);
	}
	box.append(list);
	return box;
}

// Módulo Criptomoeda embutido em banking.js para garantir carregamento imediato mesmo em restart sem refresh do fxmanifest.
if (typeof window.CRYPTO_TABS === 'undefined') {
	window.CRYPTO_TABS = [
		['exchange', 'Mercado e Corretora'],
		['explorer', 'Explorador e Auditoria'],
		['coin', 'Moeda e Rede'],
		['wallets', 'Carteiras e Envios'],
		['mining', 'Mineração']
	];
}

if (typeof window.CRYPTO_TX_KIND === 'undefined') {
	window.CRYPTO_TX_KIND = {
		buy: 'Compra na corretora',
		sell: 'Venda na corretora',
		transfer: 'Transferência',
		mine: 'Mineração',
		refund: 'Estorno'
	};
}

if (!state.crypto) {
	state.crypto = {
		tab: 'exchange',
		draft: null,
		dirty: false,
		priceInput: '',
		inspectAddress: '',
		inspectLoading: false,
		inspectError: null,
		inspectResult: null,
		inspectRequestId: null
	};
}

function cryptoData() {
	return state.data?.crypto || { available: false };
}

function cryptoScale() {
	const decimals = Number(state.crypto.draft?.coin?.decimals ?? cryptoData().settings?.coin?.decimals ?? 4);
	return Math.pow(10, decimals);
}

function cryptoSymbol() {
	return state.crypto.draft?.coin?.symbol || cryptoData().settings?.coin?.symbol || 'NOX';
}

function cryptoFormatUnits(units) {
	const decimals = Number(state.crypto.draft?.coin?.decimals ?? cryptoData().settings?.coin?.decimals ?? 4);
	const scale = Math.pow(10, decimals);
	const num = Math.max(0, Math.floor(Number(units) || 0));
	const whole = Math.floor(num / scale);
	const frac = String(num % scale).padStart(decimals, '0');
	return `${whole.toLocaleString('pt-BR')},${frac} ${cryptoSymbol()}`;
}

function cryptoMoney(value) {
	const num = Math.floor(Number(value) || 0);
	return `${num < 0 ? '-$ ' : '$ '}${Math.abs(num).toLocaleString('pt-BR')}`;
}

function cryptoDate(epoch) {
	if (!epoch) return '—';
	const d = new Date(Number(epoch) * 1000);
	if (Number.isNaN(d.getTime())) return String(epoch);
	const two = (n) => String(n).padStart(2, '0');
	return `${two(d.getDate())}/${two(d.getMonth() + 1)}/${d.getFullYear()} ${two(d.getHours())}:${two(d.getMinutes())}`;
}

function cryptoMessage(text, success) {
	for (const id of ['crypto-message', 'bank-message']) {
		const message = document.getElementById(id);
		if (message) {
			message.textContent = text || '';
			message.classList.toggle('is-success', success === true);
		}
	}
}

function cryptoButton(text, onClick, extra = '') {
	const button = bizEl('button', `biz-small-button ${extra}`.trim(), text);
	button.type = 'button';
	button.addEventListener('click', onClick);
	return button;
}

function cryptoStat(label, value) {
	const box = bizEl('div', 'bank-stat');
	box.append(bizEl('span', '', label), bizEl('strong', '', value));
	return box;
}

function cryptoCloneSettings(source) {
	if (!source) return null;
	return JSON.parse(JSON.stringify(source));
}

async function cryptoAction(action, payload, confirmOptions) {
	if (confirmOptions && !(await CoeUI.confirm(confirmOptions))) return;
	cryptoMessage('Enviando...');
	const result = await postNui('cryptoAction', { action, payload });
	if (!result.ok) cryptoMessage('Não foi possível enviar a ação.', false);
}

function cryptoInspect(address) {
	const clean = String(address || state.crypto.inspectAddress || '').trim();
	if (!clean) {
		cryptoMessage('Informe um endereço de carteira para inspecionar.', false);
		return;
	}
	state.crypto.inspectAddress = clean;
	state.crypto.inspectLoading = true;
	state.crypto.inspectError = null;
	state.crypto.tab = 'explorer';
	postNui('cryptoInspect', { address: clean }).then((res) => {
		if (res.ok) state.crypto.inspectRequestId = res.requestId;
		else {
			state.crypto.inspectLoading = false;
			state.crypto.inspectError = 'Não foi possível consultar o endereço.';
		}
		renderCrypto();
		if (state.view === 'banking' && state.bank?.tab === 'crypto') renderBankingBody();
	});
	renderCrypto();
	if (state.view === 'banking' && state.bank?.tab === 'crypto') renderBankingBody();
}

const CRYPTO_INSPECT_ERRORS = {
	forbidden: 'Sem permissão para auditar a criptomoeda.',
	not_ready: 'O coe_crypto ainda está iniciando.',
	invalid_address: 'Formato de endereço inválido.',
	unknown_address: 'Carteira não encontrada no banco de dados.',
	database_error: 'Erro ao consultar o banco de dados.',
	busy: 'Aguarde um instante antes de consultar novamente.'
};

function onCryptoInspectResult(data) {
	if (data.requestId !== state.crypto.inspectRequestId) return;
	state.crypto.inspectLoading = false;
	state.crypto.inspectResult = data.result || null;
	state.crypto.inspectError = data.result ? null : (CRYPTO_INSPECT_ERRORS[data.error] || 'Não foi possível inspecionar a carteira.');
	renderCrypto();
	if (state.view === 'banking' && state.bank?.tab === 'crypto') renderBankingBody();
}

function onCryptoResult(data) {
	cryptoMessage(data.message, data.success === true);
	if (data.success === true) {
		state.crypto.dirty = false;
	}
}

function renderCrypto() {
	const tabs = document.getElementById('crypto-tabs');
	if (!tabs) return;
	tabs.replaceChildren();
	for (const [key, label] of window.CRYPTO_TABS) {
		const button = bizEl('button', `biz-tab${key === state.crypto.tab ? ' is-active' : ''}`, label);
		button.type = 'button';
		button.addEventListener('click', () => {
			state.crypto.tab = key;
			renderCrypto();
		});
		tabs.append(button);
	}
	const data = cryptoData();
	if (data.available && data.settings && (!state.crypto.dirty || !state.crypto.draft)) {
		state.crypto.draft = cryptoCloneSettings(data.settings);
		state.crypto.priceInput = String(data.market?.price || data.settings.exchange?.anchorPrice || '');
	}
	renderCryptoBody();
}

function renderCryptoBody(targetContainer) {
	const body = targetContainer || document.getElementById('crypto-body');
	if (!body) return;
	body.replaceChildren();
	const data = cryptoData();
	if (!data.available) {
		appendEmpty(body, 'O resource coe_crypto não está iniciado ou você não possui permissão.');
		return;
	}
	if (!state.crypto.draft && data.settings) {
		state.crypto.draft = cryptoCloneSettings(data.settings);
		state.crypto.priceInput = String(data.market?.price || data.settings.exchange?.anchorPrice || '');
	}
	if (!state.crypto.draft) {
		appendEmpty(body, 'Carregando configurações do coe_crypto...');
		return;
	}
	const tab = state.crypto.tab;
	if (tab === 'exchange') renderCryptoExchange(body, data);
	else if (tab === 'explorer') renderCryptoExplorer(body, data);
	else if (tab === 'coin') renderCryptoCoin(body);
	else if (tab === 'wallets') renderCryptoWallets(body);
	else if (tab === 'mining') renderCryptoMining(body, data);
	if (tab !== 'explorer') {
		body.append(renderCryptoActions(targetContainer));
	}
}

function renderCryptoActions(targetContainer) {
	const box = bizEl('div', 'biz-block');
	const actions = bizEl('div', 'bank-actions');
	actions.append(
		cryptoButton('Descartar alterações', () => {
			state.crypto.dirty = false;
			state.crypto.draft = cryptoCloneSettings(cryptoData().settings);
			cryptoMessage('Alterações locais descartadas.', true);
			renderCryptoBody(targetContainer);
		}),
		cryptoButton('Restaurar padrão (config.lua)', () => cryptoAction('reset', {}, {
			title: 'Restaurar padrão da criptomoeda',
			message: 'Voltar todas as configurações para os valores originais do config.lua? Os saldos e carteiras continuam intactos.',
			confirmLabel: 'Restaurar',
			danger: true
		}), 'biz-danger'),
		cryptoButton('Salvar configurações', () => cryptoAction('save', { settings: state.crypto.draft }, {
			title: 'Salvar configurações de cripto',
			message: 'Aplicar as novas configurações imediatamente em toda a rede e corretora?',
			confirmLabel: 'Salvar'
		}), 'bank-primary')
	);
	box.append(actions);
	return box;
}

function renderCryptoExchange(body, data) {
	const market = data.market || {};
	const summary = data.summary || {};
	const draft = state.crypto.draft;
	const ex = draft.exchange;
	const markDirty = () => { state.crypto.dirty = true; };

	const live = bizEl('div', 'biz-block');
	const head = bizEl('div', 'biz-block-head');
	head.append(
		bizEl('h3', '', 'Panorama ao vivo da corretora e da rede'),
		cryptoButton('Atualizar', () => postNui('requestRefresh'))
	);
	const changeNum = Number(market.change) || 0;
	const changeText = `${changeNum > 0 ? '+' : ''}${changeNum.toFixed(1)}%`;
	const stats = bizEl('div', 'bank-stats');
	stats.append(
		cryptoStat('Cotação atual', cryptoMoney(market.price)),
		cryptoStat('Compra / Venda', `${cryptoMoney(market.buy)} / ${cryptoMoney(market.sell)}`),
		cryptoStat('Variação (janela)', changeText),
		cryptoStat('Fluxo líquido na rodada', cryptoMoney(market.netFlow)),
		cryptoStat('Carteiras de jogadores', String(summary.wallets ?? 0)),
		cryptoStat('Em circulação', cryptoFormatUnits(summary.circulating)),
		cryptoStat('Reserva da corretora', cryptoFormatUnits(market.reserveBalance)),
		cryptoStat('Total minerado', cryptoFormatUnits(market.minted))
	);
	live.append(head, stats);

	const priceRow = bizEl('div', 'bank-inline');
	priceRow.append(
		bizField(`Fixar cotação agora ($ entre ${cryptoMoney(ex.minPrice)} e ${cryptoMoney(ex.maxPrice)})`, bizInput('number', state.crypto.priceInput, (value) => {
			state.crypto.priceInput = value;
		}, { min: ex.minPrice, max: ex.maxPrice, step: 1 })),
		cryptoButton('Fixar cotação', () => {
			const price = Math.floor(Number(state.crypto.priceInput));
			if (!Number.isInteger(price) || price < ex.minPrice || price > ex.maxPrice) {
				cryptoMessage(`Informe um valor inteiro entre ${cryptoMoney(ex.minPrice)} e ${cryptoMoney(ex.maxPrice)}.`, false);
				return;
			}
			cryptoAction('setPrice', { price }, {
				title: 'Fixar cotação da criptomoeda',
				message: `Alterar imediatamente a cotação para ${cryptoMoney(price)} por ${cryptoSymbol()}?`,
				confirmLabel: 'Fixar'
			});
		})
	);
	live.append(priceRow);
	body.append(live);

	const configBox = bizEl('div', 'biz-block');
	configBox.append(
		bizEl('h3', '', 'Corretora e formação de preço'),
		bizEl('p', 'biz-hint', `A corretora negocia contra a carteira de reserva (${ex.reserveAddress}, reserva inicial de ${cryptoFormatUnits(ex.reserve)}). A cada rodada, a cotação caminha em direção à âncora com ruído e impacto do fluxo líquido de compras e vendas.`),
		garCheck('Corretora aberta (permite compra e venda nos aparelhos)', ex.enabled === true, (checked) => {
			ex.enabled = checked;
			markDirty();
		})
	);

	const spreadHint = bizEl('span', 'biz-hint');
	const updateSpreadHint = () => {
		const pct = ((Number(ex.spreadBps) || 0) / 100).toFixed(2).replace('.', ',');
		spreadHint.textContent = `Spread atual: ${ex.spreadBps} bps (${pct}% de cada lado sobre a cotação).`;
	};
	updateSpreadHint();

	const grid = bizEl('div', 'bank-form');
	grid.append(
		bizField('Nome da corretora (1 a 24 caracteres)', bizInput('text', ex.name, (value) => { ex.name = value; markDirty(); }, { maxlength: 24 })),
		bizField('Cotação inicial ($)', bizInput('number', ex.startPrice, (value) => { ex.startPrice = bizNumber(value, 1); markDirty(); }, { min: 1, max: 100000000, step: 1 })),
		bizField('Preço-âncora ($)', bizInput('number', ex.anchorPrice, (value) => { ex.anchorPrice = bizNumber(value, 1); markDirty(); }, { min: 1, max: 100000000, step: 1 })),
		bizField('Cotação mínima / piso ($)', bizInput('number', ex.minPrice, (value) => { ex.minPrice = bizNumber(value, 1); markDirty(); }, { min: 1, max: 100000000, step: 1 })),
		bizField('Cotação máxima / teto ($)', bizInput('number', ex.maxPrice, (value) => { ex.maxPrice = bizNumber(value, 1); markDirty(); }, { min: 1, max: 100000000, step: 1 })),
		bizField('Intervalo da cotação (minutos, 1 a 1440)', bizInput('number', ex.tickMinutes, (value) => { ex.tickMinutes = bizNumber(value, 1); markDirty(); }, { min: 1, max: 1440, step: 1 })),
		bizField('Volatilidade por rodada (0 a 1)', bizInput('number', ex.volatility, (value) => { ex.volatility = bizNumber(value, 0); markDirty(); }, { min: 0, max: 1, step: 0.001 })),
		bizField('Força de reversão à âncora (0 a 1)', bizInput('number', ex.meanReversion, (value) => { ex.meanReversion = bizNumber(value, 0); markDirty(); }, { min: 0, max: 1, step: 0.005 })),
		bizField('Impacto por $ 1.000.000 de fluxo líquido (0 a 5)', bizInput('number', ex.impactPerMillion, (value) => { ex.impactPerMillion = bizNumber(value, 0); markDirty(); }, { min: 0, max: 5, step: 0.01 })),
		bizField('Spread em pontos-base (0 a 5000, 300 = 3%)', bizInput('number', ex.spreadBps, (value) => { ex.spreadBps = bizNumber(value, 0); markDirty(); updateSpreadHint(); }, { min: 0, max: 5000, step: 10 })),
		bizField('Ordem mínima ($)', bizInput('number', ex.minOrder, (value) => { ex.minOrder = bizNumber(value, 1); markDirty(); }, { min: 1, max: 100000000, step: 1 })),
		bizField('Ordem máxima ($)', bizInput('number', ex.maxOrder, (value) => { ex.maxOrder = bizNumber(value, 1); markDirty(); }, { min: 1, max: 100000000, step: 1 })),
		bizField('Limite diário de compra por personagem ($)', bizInput('number', ex.dailyBuyLimit, (value) => { ex.dailyBuyLimit = bizNumber(value, 1); markDirty(); }, { min: 1, max: 1000000000, step: 100 })),
		bizField('Limite diário de venda por personagem ($)', bizInput('number', ex.dailySellLimit, (value) => { ex.dailySellLimit = bizNumber(value, 1); markDirty(); }, { min: 1, max: 1000000000, step: 100 })),
		bizField('Pontos mantidos no gráfico (12 a 2880)', bizInput('number', ex.historyPoints, (value) => { ex.historyPoints = bizNumber(value, 12); markDirty(); }, { min: 12, max: 2880, step: 1 })),
		bizField('Intervalo entre ordens (segundos, 0 a 3600)', bizInput('number', ex.orderCooldownSeconds, (value) => { ex.orderCooldownSeconds = bizNumber(value, 0); markDirty(); }, { min: 0, max: 3600, step: 1 }))
	);
	configBox.append(grid, spreadHint);
	body.append(configBox);
}

function renderCryptoExplorer(body, data) {
	const summary = data.summary || {};
	const market = data.market || {};
	const topWallets = data.topWallets || [];
	const recentTx = data.recentTx || [];

	const netBox = bizEl('div', 'biz-block');
	const netHead = bizEl('div', 'biz-block-head');
	netHead.append(bizEl('h3', '', 'Panorama da rede e auditoria'), cryptoButton('Atualizar rede', () => postNui('requestRefresh')));
	const stats = bizEl('div', 'bank-stats');
	stats.append(
		cryptoStat('Carteiras de jogadores', String(summary.wallets ?? 0)),
		cryptoStat('Em circulação', cryptoFormatUnits(summary.circulating)),
		cryptoStat('Reserva da corretora', cryptoFormatUnits(market.reserveBalance)),
		cryptoStat('Total minerado', cryptoFormatUnits(market.minted)),
		cryptoStat('Transações registradas', String(summary.txCount ?? 0))
	);
	netBox.append(netHead, stats);

	const searchRow = bizEl('div', 'bank-inline');
	searchRow.append(
		bizField('Inspecionar endereço de carteira (saldo, criador, aparelhos com chave e extrato)', bizInput('text', state.crypto.inspectAddress, (value) => {
			state.crypto.inspectAddress = value;
		}, { maxlength: 48, placeholder: 'Ex.: nx...' })),
		cryptoButton('Inspecionar', () => cryptoInspect(state.crypto.inspectAddress), 'bank-primary')
	);
	netBox.append(searchRow);

	if (state.crypto.inspectLoading) {
		netBox.append(bizEl('p', 'biz-hint', 'Consultando carteira...'));
	} else if (state.crypto.inspectError) {
		netBox.append(bizEl('p', 'biz-hint', state.crypto.inspectError));
	} else if (state.crypto.inspectResult?.wallet) {
		const w = state.crypto.inspectResult.wallet;
		const devices = state.crypto.inspectResult.devices || [];
		const history = state.crypto.inspectResult.history || [];
		const inspectCard = bizEl('div', 'biz-block');
		const inspectHead = bizEl('div', 'biz-block-head');
		inspectHead.append(
			bizEl('h3', '', `Carteira ${w.address}`),
			cryptoButton('Fechar inspeção', () => {
				state.crypto.inspectResult = null;
				renderCrypto();
				if (state.view === 'banking' && state.bank?.tab === 'crypto') renderBankingBody();
			})
		);
		const wStats = bizEl('div', 'bank-stats');
		const creatorText = w.characterName
			? `${w.characterName}${w.stateId ? ' · ' + w.stateId : ''} (#${w.createdBy})`
			: (w.createdBy ? `Personagem #${w.createdBy}` : 'Sistema / Reserva');
		wStats.append(
			cryptoStat('Saldo atual', cryptoFormatUnits(w.balance)),
			cryptoStat('Valor em $ (cotação atual)', cryptoMoney(Math.floor((Number(w.balance) || 0) / cryptoScale() * (Number(market.price) || 0)))),
			cryptoStat('Criada por', creatorText),
			cryptoStat('Criada em', cryptoDate(w.createdAt)),
			cryptoStat('Aparelhos com chave', String(devices.length))
		);
		inspectCard.append(inspectHead, wStats);
		if (w.createdBy && state.data?.permissions?.viewPlayers) {
			const actions = bizEl('div', 'bank-actions');
			actions.append(cryptoButton('Abrir perfil do criador', () => openProfile(String(w.createdBy))));
			inspectCard.append(actions);
		}
		if (devices.length) {
			const devList = bizEl('div', 'bank-list');
			for (const dev of devices) {
				const row = bizEl('div', 'bank-row');
				const info = bizEl('div', 'bank-row-info');
				info.append(
					bizEl('strong', '', `${dev.deviceKey}${dev.label ? ' · "' + dev.label + '"' : ''}`),
					bizEl('span', 'biz-hint', `Adicionada em ${cryptoDate(dev.addedAt)}`)
				);
				row.append(info);
				devList.append(row);
			}
			inspectCard.append(bizEl('h3', 'bank-subtitle', 'Aparelhos com a chave salva'), devList);
		}
		if (history.length) {
			const txList = bizEl('div', 'bank-list');
			for (const tx of history) {
				txList.append(renderCryptoTxRow(tx));
			}
			inspectCard.append(bizEl('h3', 'bank-subtitle', `Movimentações da carteira (${history.length})`), txList);
		} else {
			inspectCard.append(bizEl('p', 'biz-hint', 'Nenhuma movimentação registrada para este endereço.'));
		}
		netBox.append(inspectCard);
	}
	body.append(netBox);

	const topBox = bizEl('div', 'biz-block');
	topBox.append(
		bizEl('h3', '', `Maiores carteiras da rede (${topWallets.length})`),
		bizEl('p', 'biz-hint', 'Carteiras de jogadores ordenadas por saldo (exclui a carteira de reserva da corretora).')
	);
	if (!topWallets.length) {
		topBox.append(bizEl('p', 'biz-hint', 'Nenhuma carteira de jogador criada ainda.'));
	} else {
		const list = bizEl('div', 'bank-list');
		for (const w of topWallets) {
			const row = bizEl('div', 'bank-row');
			const info = bizEl('div', 'bank-row-info');
			const owner = w.characterName
				? `Criada por ${w.characterName}${w.stateId ? ' (' + w.stateId + ')' : ''}`
				: (w.createdBy ? `Criada pelo personagem #${w.createdBy}` : 'Sem criador registrado');
			info.append(
				bizEl('strong', '', `${w.address} · ${cryptoFormatUnits(w.balance)}`),
				bizEl('span', 'biz-hint', `${owner} · em ${cryptoDate(w.createdAt)}`)
			);
			const actions = bizEl('div', 'bank-row-actions');
			actions.append(cryptoButton('Inspecionar', () => cryptoInspect(w.address)));
			if (w.createdBy && state.data?.permissions?.viewPlayers) {
				actions.append(cryptoButton('Perfil', () => openProfile(String(w.createdBy))));
			}
			row.append(info, actions);
			list.append(row);
		}
		topBox.append(list);
	}
	body.append(topBox);

	const txBox = bizEl('div', 'biz-block');
	txBox.append(
		bizEl('h3', '', `Últimas movimentações da rede (${recentTx.length})`),
		bizEl('p', 'biz-hint', 'Compras, vendas, envios e rodadas de mineração mais recentes em todo o servidor.')
	);
	if (!recentTx.length) {
		txBox.append(bizEl('p', 'biz-hint', 'Nenhuma movimentação registrada ainda.'));
	} else {
		const list = bizEl('div', 'bank-list');
		for (const tx of recentTx) {
			list.append(renderCryptoTxRow(tx));
		}
		txBox.append(list);
	}
	body.append(txBox);
}

function renderCryptoTxRow(tx) {
	const row = bizEl('div', 'bank-row');
	const info = bizEl('div', 'bank-row-info');
	const kindLabel = window.CRYPTO_TX_KIND[tx.kind] || tx.kind;
	const fiatText = tx.fiat ? ` · ${cryptoMoney(tx.fiat)}` : '';
	const feeText = tx.fee > 0 ? ` (taxa ${cryptoFormatUnits(tx.fee)})` : '';
	const actor = tx.characterName
		? `${tx.characterName}${tx.stateId ? ' (' + tx.stateId + ')' : ''}`
		: (tx.characterId ? `Personagem #${tx.characterId}` : '');
	const details = [
		cryptoDate(tx.at),
		tx.from ? `De: ${tx.from}` : 'Emissão',
		`Para: ${tx.to}`,
		actor,
		tx.deviceKey ? `Aparelho: ${tx.deviceKey}` : '',
		tx.memo ? `Memo: "${tx.memo}"` : ''
	].filter(Boolean).join(' · ');
	info.append(
		bizEl('strong', '', `#${tx.id} · ${kindLabel} · ${cryptoFormatUnits(tx.amount)}${feeText}${fiatText}`),
		bizEl('span', 'biz-hint', details)
	);
	const actions = bizEl('div', 'bank-row-actions');
	if (tx.to) actions.append(cryptoButton('Destino', () => cryptoInspect(tx.to)));
	if (tx.from) actions.append(cryptoButton('Origem', () => cryptoInspect(tx.from)));
	if (tx.characterId && state.data?.permissions?.viewPlayers) {
		actions.append(cryptoButton('Perfil', () => openProfile(String(tx.characterId))));
	}
	row.append(info, actions);
	return row;
}

function renderCryptoCoin(body) {
	const draft = state.crypto.draft;
	const coin = draft.coin;
	const address = draft.address || {};
	const net = draft.network;
	const markDirty = () => { state.crypto.dirty = true; };

	const box = bizEl('div', 'biz-block');
	box.append(
		bizEl('h3', '', 'Identidade da moeda e parâmetros de rede'),
		bizEl('p', 'biz-hint', 'O nome e o símbolo aparecem no smartphone, no tablet e nos computadores da DeepWeb. Casas decimais e formato de endereço são estruturais (somente leitura) para preservar os saldos e carteiras já existentes.')
	);

	const stats = bizEl('div', 'bank-stats');
	stats.append(
		cryptoStat('Casas decimais', `${coin.decimals} (1 ${coin.symbol} = ${cryptoScale().toLocaleString('pt-BR')} un.)`),
		cryptoStat('Prefixo de endereço', address.prefix || 'nx'),
		cryptoStat('Tamanho do endereço', `${address.length || 30} caracteres`)
	);
	box.append(stats);

	const grid = bizEl('div', 'bank-form');
	grid.append(
		bizField('Nome da moeda (1 a 24 caracteres)', bizInput('text', coin.name, (value) => { coin.name = value; markDirty(); }, { maxlength: 24 })),
		bizField('Símbolo / Ticker (2 a 6 letras/números)', bizInput('text', coin.symbol, (value) => { coin.symbol = value.toUpperCase(); markDirty(); }, { maxlength: 6 })),
		bizField('Movimentações por página no Explorador (5 a 100)', bizInput('number', net.historyPageSize, (value) => { net.historyPageSize = bizNumber(value, 30); markDirty(); }, { min: 5, max: 100, step: 1 })),
		bizField('Intervalo mínimo entre chamadas do app (50 a 5000 ms)', bizInput('number', net.callCooldownMs, (value) => { net.callCooldownMs = bizNumber(value, 250); markDirty(); }, { min: 50, max: 5000, step: 10 }))
	);
	box.append(grid);
	body.append(box);
}

function renderCryptoWallets(body) {
	const draft = state.crypto.draft;
	const wallets = draft.wallets;
	const transfer = draft.transfer;
	const markDirty = () => { state.crypto.dirty = true; };

	const walletBox = bizEl('div', 'biz-block');
	walletBox.append(
		bizEl('h3', '', 'Carteiras e proteção de importação'),
		bizEl('p', 'biz-hint', 'Controla quantas chaves cabem em cada aparelho (celular, tablet ou computador), quantas carteiras novas cada personagem pode gerar por dia e o bloqueio contra força bruta na importação de chave privada.')
	);
	const walletGrid = bizEl('div', 'bank-form');
	walletGrid.append(
		bizField('Máx. de carteiras por aparelho (1 a 32)', bizInput('number', wallets.maxPerDevice, (value) => { wallets.maxPerDevice = bizNumber(value, 8); markDirty(); }, { min: 1, max: 32, step: 1 })),
		bizField('Máx. de carteiras criadas por dia por personagem (1 a 100)', bizInput('number', wallets.maxCreatedPerDay, (value) => { wallets.maxCreatedPerDay = bizNumber(value, 5); markDirty(); }, { min: 1, max: 100, step: 1 })),
		bizField('Tamanho máximo do rótulo (4 a 48 caracteres)', bizInput('number', wallets.labelMax, (value) => { wallets.labelMax = bizNumber(value, 24); markDirty(); }, { min: 4, max: 48, step: 1 })),
		bizField('Erros seguidos de chave antes do bloqueio (1 a 50)', bizInput('number', wallets.importFailures, (value) => { wallets.importFailures = bizNumber(value, 5); markDirty(); }, { min: 1, max: 50, step: 1 })),
		bizField('Tempo de bloqueio na importação (segundos, 10 a 86400)', bizInput('number', wallets.importLockSeconds, (value) => { wallets.importLockSeconds = bizNumber(value, 120); markDirty(); }, { min: 10, max: 86400, step: 10 }))
	);
	walletBox.append(walletGrid);
	body.append(walletBox);

	const transferBox = bizEl('div', 'biz-block');
	const preview = bizEl('p', 'biz-hint');
	const updatePreview = () => {
		preview.textContent = `Conversão atual: taxa = ${cryptoFormatUnits(transfer.fee)} · mínimo = ${cryptoFormatUnits(transfer.minAmount)} · máximo = ${cryptoFormatUnits(transfer.maxAmount)}.`;
	};
	updatePreview();
	transferBox.append(
		bizEl('h3', '', 'Transferências na rede'),
		bizEl('p', 'biz-hint', `Valores de moeda em unidades inteiras (1 ${cryptoSymbol()} = ${cryptoScale().toLocaleString('pt-BR')} unidades). A taxa de envio é queimada a cada transferência.`)
	);
	const transferGrid = bizEl('div', 'bank-form');
	transferGrid.append(
		bizField('Taxa da rede por envio (em unidades)', bizInput('number', transfer.fee, (value) => { transfer.fee = bizNumber(value, 0); markDirty(); updatePreview(); }, { min: 0, max: 1000000000, step: 1 })),
		bizField('Quantia mínima por envio (em unidades)', bizInput('number', transfer.minAmount, (value) => { transfer.minAmount = bizNumber(value, 1); markDirty(); updatePreview(); }, { min: 1, max: 100000000000000, step: 1 })),
		bizField('Quantia máxima por envio (em unidades)', bizInput('number', transfer.maxAmount, (value) => { transfer.maxAmount = bizNumber(value, 1); markDirty(); updatePreview(); }, { min: 1, max: 100000000000000, step: 10000 })),
		bizField('Tamanho máximo do memo público (0 a 120 caracteres)', bizInput('number', transfer.memoMax, (value) => { transfer.memoMax = bizNumber(value, 60); markDirty(); }, { min: 0, max: 120, step: 1 })),
		bizField('Intervalo entre envios da mesma carteira (segundos, 0 a 3600)', bizInput('number', transfer.cooldownSeconds, (value) => { transfer.cooldownSeconds = bizNumber(value, 3); markDirty(); }, { min: 0, max: 3600, step: 1 }))
	);
	transferBox.append(transferGrid, preview);
	body.append(transferBox);
}

function renderCryptoMining(body, data) {
	const draft = state.crypto.draft;
	const mining = draft.mining;
	const minted = Number(data.market?.minted) || 0;
	const markDirty = () => { state.crypto.dirty = true; };

	const box = bizEl('div', 'biz-block');
	const preview = bizEl('p', 'biz-hint');
	const updatePreview = () => {
		const remaining = Math.max(0, (Number(mining.maxMined) || 0) - minted);
		preview.textContent = `Emissão por rodada: até ${cryptoFormatUnits(mining.emissionPerTick)} a cada ${mining.tickMinutes} min · Teto: ${cryptoFormatUnits(mining.maxMined)} (restam ${cryptoFormatUnits(remaining)}).`;
	};
	updatePreview();

	box.append(
		bizEl('h3', '', 'Emissão por mineração'),
		bizEl('p', 'biz-hint', `Cada rodada divide a emissão pelo poder de hash das máquinas ativas (coe_deepweb). Quando o hash total da rede é menor que o hash de referência, a emissão é proporcionalmente menor. Valores em unidades inteiras (1 ${cryptoSymbol()} = ${cryptoScale().toLocaleString('pt-BR')} unidades).`)
	);

	const grid = bizEl('div', 'bank-form');
	grid.append(
		bizField('Intervalo entre rodadas (minutos, 1 a 1440)', bizInput('number', mining.tickMinutes, (value) => { mining.tickMinutes = bizNumber(value, 10); markDirty(); updatePreview(); }, { min: 1, max: 1440, step: 1 })),
		bizField('Emissão máxima por rodada (em unidades)', bizInput('number', mining.emissionPerTick, (value) => { mining.emissionPerTick = bizNumber(value, 0); markDirty(); updatePreview(); }, { min: 0, max: 100000000000, step: 1000 })),
		bizField('Poder de hash de referência da rede (1 a 1.000.000)', bizInput('number', mining.referenceHash, (value) => { mining.referenceHash = bizNumber(value, 200); markDirty(); }, { min: 1, max: 1000000, step: 10 })),
		bizField('Teto total de mineração (em unidades)', bizInput('number', mining.maxMined, (value) => { mining.maxMined = bizNumber(value, 0); markDirty(); updatePreview(); }, { min: 0, max: 1000000000000000, step: 10000 }))
	);
	box.append(grid, preview);
	body.append(box);
}
