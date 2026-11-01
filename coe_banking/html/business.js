// Conta bancária empresarial (coe_banking): seções, resumo e telas, usados pela agência (banking.js) e pela aba
// Banco do app do negócio no tablet (registrada com coe_businesses:RegisterTab). Script clássico: expõe
// window.CoeBusinessBank e a aba em window.CoeBusinessTabs.bank.
// api = { act(action, data), channel: 'agency' | 'tablet' }. As ações voltam com a visão atualizada do servidor.
(function () {
	'use strict';

	const el = (tag, props = {}, children = []) => {
		const node = document.createElement(tag);
		Object.assign(node, props);
		for (const child of [].concat(children)) if (child != null && child !== false) node.append(child);
		return node;
	};
	const money = (value) => `$ ${Math.floor(Math.abs(value || 0)).toLocaleString('pt-BR')}`;
	const signed = (value) => `${value < 0 ? '−' : '+'} ${money(value)}`;
	const two = (n) => String(n).padStart(2, '0');
	const date = (epoch) => {
		if (!epoch) return '—';
		const d = new Date(epoch * 1000);
		return `${two(d.getDate())}/${two(d.getMonth() + 1)} ${two(d.getHours())}:${two(d.getMinutes())}`;
	};
	const day = (epoch) => {
		if (!epoch) return '—';
		const d = new Date(epoch * 1000);
		return `${two(d.getDate())}/${two(d.getMonth() + 1)}/${d.getFullYear()}`;
	};
	const confirm = (options) => (window.CoeUI ? window.CoeUI.confirm(options) : Promise.resolve(true));

	const REASONS = {
		society_deposit: 'Depósito', business_deposit: 'Depósito', bank_deposit: 'Depósito',
		society_withdraw: 'Saque', business_withdraw: 'Saque', bank_withdraw: 'Saque',
		business_payment: 'Pagamento', business_transfer: 'Transferência entre empresas', business_bonus: 'Bônus',
		payroll: 'Salário', business_card: 'Compra com cartão', business_card_refund: 'Estorno de compra', card_fee: 'Tarifa de cartão',
		atm_fee: 'Tarifa de saque', bank_loan: 'Empréstimo recebido', loan_payment: 'Parcela de empréstimo', bank_refund: 'Estorno',
		admin_adjustment: 'Ajuste do banco', news_ad: 'Anúncio', news_ad_refund: 'Estorno de anúncio', rent: 'Aluguel',
		commercial_rent: 'Aluguel comercial', fine: 'Multa', fines: 'Multas'
	};
	const reasonLabel = (reason) => REASONS[reason] || String(reason || '').replace(/_/g, ' ');
	const CARD_STATUS = { active: ['is-ok', 'Ativo'], expired: ['is-bad', 'Vencido'], blocked: ['is-bad', 'Bloqueado'] };

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
	const select = (options, value) => {
		const node = el('select', { className: 'coe-field' }, options.map((option) => el('option', { value: option.value, textContent: option.label })));
		if (value != null) node.value = String(value);
		return node;
	};
	const kpi = (label, value, note, main) => el('div', { className: `kpi${main ? ' is-main' : ''}` }, [
		el('span', { textContent: label }), el('strong', { textContent: value }), note ? el('small', { textContent: note }) : null
	]);
	const cell = (label, value, className) => el('div', { className: 'cell' }, [el('span', { textContent: label }), el('strong', { textContent: value, className: className || '' })]);
	const badge = (text, kind) => el('span', { className: `coe-badge${kind ? ' ' + kind : ''}`, textContent: text });
	const hint = (text) => el('p', { className: 'hint', textContent: text });
	const empty = (text) => el('p', { className: 'empty', textContent: text });
	const title = (text, extra) => el('div', { className: 'section-title' }, [el('div', { className: 'tb-section', textContent: text }), extra || null]);
	const box = (children, alert) => el('div', { className: `box${alert ? ' is-alert' : ''}` }, children);
	const boxHead = (left, right) => el('div', { className: 'box-head' }, [el('div', { className: 'box-title' }, left), right || null]);
	const labeled = (text, control) => el('label', { className: 'field-label' }, [text, control]);
	const row = (children, extra) => el('div', { className: `row${extra ? ' ' + extra : ''}` }, children);
	const strong = (text) => el('strong', { textContent: text });

	function cardFace(card, small) {
		return el('div', { className: `bank-card${card.status && card.status !== 'active' ? ' off' : ''}${small ? ' sm' : ''}` }, [
			el('div', { className: 'bank-card-top' }, [el('span', { textContent: 'COE BANK' }), el('span', { textContent: 'Empresarial' })]),
			el('div', { className: 'bank-card-chip' }),
			el('div', { className: 'bank-card-number', textContent: `•••• ${small ? '' : '•••• •••• '}${card.last4 || '0000'}` }),
			el('div', { className: 'bank-card-holder', textContent: (card.holder || '').toUpperCase() })
		]);
	}

	function ledger(rows, emptyText) {
		if (!rows || rows.length === 0) return empty(emptyText || 'Sem movimentações no período.');
		return el('div', { className: 'ledger' }, rows.map((entry) => {
			const who = [entry.counterparty, entry.actor && entry.actor !== entry.counterparty ? `por ${entry.actor}` : null, entry.memo ? `“${entry.memo}”` : null].filter(Boolean).join(' · ');
			return el('div', { className: `ledger-row ${entry.delta < 0 ? 'is-out' : 'is-in'}` }, [
				el('span', { className: 'ledger-icon', textContent: entry.delta < 0 ? '↑' : '↓' }),
				el('div', { className: 'ledger-text' }, [
					el('div', { textContent: reasonLabel(entry.reason) }),
					el('small', { textContent: [date(entry.at), who].filter(Boolean).join(' · ') })
				]),
				el('span', { className: 'ledger-value', textContent: signed(entry.delta) })
			]);
		}));
	}

	const loanDetail = (loan) => [`Juros de atraso: ${loan.lateRate}% ao dia sobre a parcela vencida`, loan.interest > 0 ? `já acumulados ${money(loan.interest)}` : ''].filter(Boolean).join(' · ');

	// Seções -------------------------------------------------------------------------------------------------

	function sections(view) {
		const rights = view.rights || {};
		const late = (view.loans || []).some((loan) => loan.late);
		const list = [];
		if (rights.view) {
			list.push(['summary', 'Resumo'], ['statement', 'Extrato']);
		} else {
			list.push(['summary', 'Depósito']);
		}
		if (rights.transfer) list.push(['transfer', 'Transferir']);
		if (rights.view) list.push(['cards', 'Cartões']);
		if (rights.payroll) list.push(['payroll', 'Folha']);
		if (rights.view) list.push(['loans', 'Empréstimos', late]);
		return list;
	}

	function summary(view) {
		const rights = view.rights || {};
		const report = view.report;
		return [
			rights.view ? kpi('Saldo do caixa', view.balance != null ? money(view.balance) : '—', null, true) : null,
			report ? kpi(`Resultado · ${report.days} dia(s)`, `${report.net < 0 ? '−' : '+'} ${money(report.net)}`, `${money(report.inflow)} entrou · ${money(report.outflow)} saiu`) : null,
			view.cash != null ? kpi('Seu dinheiro em espécie', money(view.cash)) : null,
			kpi('Seu papel', view.business ? view.business.role : '—', view.business && view.business.owner ? `Dono: ${view.business.owner}` : null)
		];
	}

	function periodChips(view, api, extra) {
		const filter = view.filter || {};
		return el('div', { className: 'chips' }, (view.periods || []).map((days) => {
			const chip = el('button', { type: 'button', className: `chip${filter.days === days ? ' is-active' : ''}`, textContent: days === 1 ? 'Hoje' : `${days} dias` });
			chip.onclick = () => api.act('statement', { filter: Object.assign({}, filter, extra || {}, { days, beforeId: null }) });
			return chip;
		}));
	}

	function moneyForms(view, api) {
		const rights = view.rights || {};
		const agency = api.channel === 'agency';
		const forms = [];
		if (rights.deposit) {
			const amount = amountInput('Valor', view.limits.maxAmount);
			const method = select(agency ? [{ value: 'account', label: 'Da minha conta' }, { value: 'cash', label: 'Em espécie' }] : [{ value: 'account', label: 'Da minha conta' }]);
			forms.push(box([strong('Depositar no caixa'), row([amount, method, button('Depositar', 'primary', () => {
				const value = readAmount(amount);
				if (value) api.act('deposit', { amount: value, method: method.value });
			})]), hint('Qualquer pessoa da empresa pode depositar.')]));
		}
		if (rights.withdraw) {
			const amount = amountInput('Valor', view.limits.maxAmount);
			const method = select(agency ? [{ value: 'account', label: 'Para minha conta' }, { value: 'cash', label: 'Em espécie' }] : [{ value: 'account', label: 'Para minha conta' }]);
			forms.push(box([strong('Sacar do caixa'), row([amount, method, button('Sacar', null, async () => {
				const value = readAmount(amount);
				if (!value) return;
				const ok = await confirm({ title: 'Sacar do caixa', message: `Sacar ${money(value)} do caixa de ${view.business.label}${method.value === 'cash' ? ' em espécie' : ' para a sua conta'}?`, confirmLabel: 'Sacar' });
				if (ok) api.act('withdraw', { amount: value, method: method.value });
			})]), hint('Fica registrado no extrato com o seu nome.')]));
		}
		return forms.length ? el('div', { className: 'grid-2' }, forms) : null;
	}

	function summarySection(container, view, api) {
		const rights = view.rights || {};
		if (!rights.view) {
			container.append(title('Depósito'), moneyForms(view, api) || empty('Sem operações disponíveis.'),
				hint('Seu cargo não vê o saldo nem o extrato da empresa. Peça ao dono para ajustar as permissões do cargo (Banco).'));
			return;
		}
		const report = view.report || { inflow: 0, outflow: 0, net: 0, count: 0, days: 0 };
		const cards = (view.cards || []).filter((card) => card.status === 'active');
		const lateLoans = (view.loans || []).filter((loan) => loan.late);
		container.append(
			title('Resultado do período', periodChips(view, api)),
			el('div', { className: 'grid-4' }, [
				cell('Entradas', money(report.inflow), 'net-in'),
				cell('Saídas', money(report.outflow), 'net-out'),
				cell('Resultado', `${report.net < 0 ? '−' : '+'} ${money(report.net)}`, report.net < 0 ? 'net-out' : 'net-in'),
				cell('Lançamentos', String(report.count))
			]),
			lateLoans.length ? box([boxHead([strong('Empréstimo em atraso'), badge('Atenção', 'is-bad')]), hint('A parcela vencida acumula juros diários e pesa no relacionamento do dono e dos sócios. Veja Empréstimos.')], true) : null,
			view.payroll && !view.payroll.covered ? box([boxHead([strong('O caixa não cobre a folha de agora'), badge('Folha', 'is-warn')]), hint(`Quem está de ponto soma ${money(view.payroll.due)} e o caixa tem ${money(view.balance)}.`)], true) : null,
			title('Operações'),
			moneyForms(view, api),
			title('Últimos lançamentos', cards.length ? badge(`${cards.length} cartão(ões) ativo(s)`, 'is-accent') : null),
			ledger((view.statement || []).slice(0, 6))
		);
	}

	function statementSection(container, view, api) {
		const filter = view.filter || {};
		const direction = el('div', { className: 'chips' }, [['', 'Tudo'], ['in', 'Entradas'], ['out', 'Saídas']].map(([value, label]) => {
			const chip = el('button', { type: 'button', className: `chip${(filter.direction || '') === value ? ' is-active' : ''}`, textContent: label });
			chip.onclick = () => api.act('statement', { filter: Object.assign({}, filter, { direction: value || null, beforeId: null }) });
			return chip;
		}));
		const category = select([{ value: '', label: 'Todas as categorias' }, ...(view.categories || []).map((entry) => ({ value: entry.id, label: entry.label }))], filter.category || '');
		category.onchange = () => api.act('statement', { filter: Object.assign({}, filter, { category: category.value || null, beforeId: null }) });
		const report = view.report || {};
		const pager = [];
		if (filter.beforeId) pager.push(button('Mais recentes', null, () => api.act('statement', { filter: Object.assign({}, filter, { beforeId: null }) })));
		if (view.nextBefore) pager.push(button('Mais antigos', null, () => api.act('statement', { filter: Object.assign({}, filter, { beforeId: view.nextBefore }) })));
		container.append(
			title('Filtros'),
			el('div', { className: 'toolbar' }, [periodChips(view, api), direction, category]),
			el('div', { className: 'grid-3' }, [cell('Entradas no filtro', money(report.inflow), 'net-in'), cell('Saídas no filtro', money(report.outflow), 'net-out'), cell('Lançamentos', String(report.count || 0))]),
			title('Lançamentos'),
			ledger(view.statement, 'Nada encontrado com esse filtro.'),
			pager.length ? row(pager, 'end') : null,
			hint('Cada lançamento mostra quem recebeu ou pagou e quem fez a operação pelo banco.')
		);
	}

	function transferSection(container, view, api) {
		let kind = 'person';
		const toggle = el('div', { className: 'chips' });
		const target = field({ type: 'text', className: 'coe-field upper', maxLength: 16, placeholder: 'Identidade (state ID)' });
		const paint = () => {
			toggle.replaceChildren(...[['person', 'Pessoa'], ['business', 'Empresa']].map(([value, label]) => {
				const chip = el('button', { type: 'button', className: `chip${kind === value ? ' is-active' : ''}`, textContent: label });
				chip.onclick = () => { kind = value; target.value = ''; target.placeholder = value === 'person' ? 'Identidade (state ID)' : 'Código da empresa (ex.: bennys)'; target.className = value === 'person' ? 'coe-field upper' : 'coe-field'; paint(); };
				return chip;
			}));
		};
		paint();
		const amount = amountInput('Valor', view.limits.maxTransfer);
		const memo = field({ type: 'text', maxLength: view.limits.memoMax, placeholder: 'Descrição (aparece no extrato)' });
		const send = button('Enviar', 'primary', async () => {
			const value = readAmount(amount);
			const id = target.value.trim();
			if (!value || !id) return;
			const who = kind === 'person' ? `a identidade ${id.toUpperCase()}` : `a empresa ${id.toLowerCase()}`;
			const ok = await confirm({ title: 'Confirmar pagamento', message: `Enviar ${money(value)} do caixa de ${view.business.label} para ${who}?`, confirmLabel: 'Enviar' });
			if (ok) api.act('transfer', { target: kind === 'person' ? { kind, stateId: id } : { kind, id: id.toLowerCase() }, amount: value, memo: memo.value.trim() });
		});
		container.append(
			title('Pagamento ou transferência'),
			box([
				boxHead([strong('Para quem')], toggle),
				el('div', { className: 'grid-3' }, [labeled(kind === 'person' ? 'Destino' : 'Destino', target), labeled('Valor', amount), labeled('Descrição', memo)]),
				row([send], 'end'),
				hint(`Até ${money(view.limits.maxTransfer)} por operação. Para pessoas cai na conta pessoal; para empresas, no caixa da outra empresa.`)
			]),
			title('Últimos pagamentos'),
			ledger((view.statement || []).filter((entry) => entry.category === 'transfers').slice(0, 8), 'Nenhum pagamento no período.')
		);
	}

	function cardsSection(container, view, api) {
		const rights = view.rights || {};
		const cards = view.cards || [];
		const active = cards.filter((card) => card.status === 'active').length;
		if (rights.cards && api.channel === 'agency') {
			const holder = select((view.members || []).map((member) => ({ value: member.characterId, label: `${member.name} · ${member.role}` })));
			const pin1 = field({ type: 'password', inputMode: 'numeric', maxLength: 4, placeholder: 'Senha (4 dígitos)' });
			const pin2 = field({ type: 'password', inputMode: 'numeric', maxLength: 4, placeholder: 'Repita a senha' });
			pin2.oninput = () => pin2.setCustomValidity('');
			const limit = field({ type: 'number', min: 0, max: view.limits.maxDailyLimit, step: 1, value: view.limits.defaultDailyLimit });
			const issue = button(`Emitir cartão${view.limits.cardFee > 0 ? ' · ' + money(view.limits.cardFee) : ''}`, 'primary', async () => {
				if (!/^\d{4}$/.test(pin1.value) || pin1.value !== pin2.value) {
					pin2.setCustomValidity('As senhas devem ter 4 dígitos e ser iguais.');
					pin2.reportValidity();
					return;
				}
				const dailyLimit = Number(limit.value);
				if (!Number.isInteger(dailyLimit) || dailyLimit < 0) return;
				const name = holder.options[holder.selectedIndex] ? holder.options[holder.selectedIndex].textContent : '';
				const ok = await confirm({ title: 'Emitir cartão empresarial', message: `Emitir cartão para ${name} com limite de ${dailyLimit > 0 ? money(dailyLimit) + ' por dia' : 'uso livre'}? A tarifa sai do caixa e o cartão vem para você entregar.`, confirmLabel: 'Emitir' });
				if (ok) api.act('issueCard', { holderId: holder.value, pin: pin1.value, dailyLimit });
			});
			if (active >= view.limits.maxCards || !(view.members || []).length) { issue.disabled = true; issue.dataset.locked = '1'; }
			container.append(title('Novo cartão empresarial'), box([
				el('div', { className: 'grid-2' }, [labeled('Titular', holder), labeled('Limite diário (0 = livre)', limit), labeled('Senha', pin1), labeled('Confirmar senha', pin2)]),
				row([issue], 'end'),
				hint(`Débito no caixa da empresa: saque no caixa eletrônico e compras pela Carteira do celular. ${active}/${view.limits.maxCards} cartões ativos. Para de funcionar se o titular sair da empresa.`)
			]));
		} else if (rights.cards) {
			container.append(hint('Novos cartões e troca de senha são feitos na agência.'));
		}
		container.append(title('Cartões da empresa', badge(`${active} ativo(s)`)));
		if (!cards.length) {
			container.append(empty('Nenhum cartão emitido.'));
			return;
		}
		container.append(el('div', { className: 'card-list' }, cards.map((card) => {
			const status = CARD_STATUS[card.status] || CARD_STATUS.blocked;
			const info = [
				el('div', { className: 'box-title' }, [strong(`•••• ${card.last4}`), badge(status[1] + (card.status === 'blocked' && card.blockedReason ? ` · ${card.blockedReason}` : ''), status[0]),
					card.holderActive === false ? badge('Titular saiu', 'is-warn') : null]),
				hint([card.holder, card.expiresAt ? `válido até ${day(card.expiresAt)}` : ''].filter(Boolean).join(' · '))
			];
			if (card.dailyLimit) {
				const used = Math.min(100, card.spentToday / card.dailyLimit * 100);
				info.push(el('div', { className: `meter is-usage${used >= 90 ? ' is-full' : ''}` }, [el('i', { style: `width:${used}%` })]),
					hint(`Hoje: ${money(card.spentToday)} de ${money(card.dailyLimit)} · resta ${money(card.remaining)}`));
			} else {
				info.push(hint(`Sem limite diário · hoje: ${money(card.spentToday)}`));
			}
			if (rights.cards && card.status !== 'expired' && !(card.status === 'blocked' && card.blockedReason && card.blockedReason !== 'senha')) {
				const limit = field({ type: 'number', min: 0, max: view.limits.maxDailyLimit, step: 1, value: card.dailyLimit || 0 });
				const actions = [limit, button('Salvar limite', null, () => {
					const value = Number(limit.value);
					if (Number.isInteger(value) && value >= 0) api.act('cardLimit', { cardId: card.id, dailyLimit: value });
				})];
				if (api.channel === 'agency') {
					const pin = field({ type: 'password', inputMode: 'numeric', maxLength: 4, placeholder: 'Nova senha' });
					actions.push(pin, button(card.status === 'blocked' ? 'Desbloquear' : 'Trocar senha', null, () => { if (/^\d{4}$/.test(pin.value)) api.act('cardPin', { cardId: card.id, pin: pin.value }); }));
				}
				actions.push(button('Bloquear', 'danger', async () => {
					const ok = await confirm({ title: 'Bloquear cartão empresarial', message: `Bloquear definitivamente o cartão •••• ${card.last4} de ${card.holder}?`, confirmLabel: 'Bloquear', danger: true });
					if (ok) api.act('cardBlock', { cardId: card.id });
				}));
				info.push(row(actions, 'wrap'));
			}
			return el('div', { className: 'card-item' }, [cardFace(card, true), el('div', { className: 'card-item-info' }, info)]);
		})));
	}

	function payrollSection(container, view, api) {
		const payroll = view.payroll;
		if (!payroll) {
			container.append(empty('Folha indisponível.'));
			return;
		}
		const run = button(`Pagar folha agora · ${money(payroll.due)}`, 'primary', async () => {
			const ok = await confirm({ title: 'Pagar folha agora', message: `Pagar o salário de quem está de ponto agora (${money(payroll.due)})? Quem está fora de ponto não recebe, como na folha automática.`, confirmLabel: 'Pagar' });
			if (ok) api.act('payrollRun', {});
		});
		if (payroll.due <= 0) { run.disabled = true; run.dataset.locked = '1'; }
		const memberSelect = select((view.members || []).map((member) => ({ value: member.characterId, label: member.name })));
		const bonusAmount = amountInput('Valor', view.limits.maxTransfer);
		const bonusMemo = field({ type: 'text', maxLength: view.limits.memoMax, placeholder: 'Motivo (opcional)' });
		const bonus = button('Pagar bônus', null, async () => {
			const value = readAmount(bonusAmount);
			if (!value) return;
			const name = memberSelect.options[memberSelect.selectedIndex] ? memberSelect.options[memberSelect.selectedIndex].textContent : '';
			const ok = await confirm({ title: 'Pagar bônus', message: `Pagar ${money(value)} de bônus para ${name}, do caixa da empresa?`, confirmLabel: 'Pagar' });
			if (ok) api.act('bonus', { characterId: memberSelect.value, amount: value, memo: bonusMemo.value.trim() });
		});
		container.append(
			title('Próxima folha'),
			box([
				el('div', { className: 'grid-3' }, [cell('De ponto agora', money(payroll.due)), cell('Folha completa', money(payroll.total)), cell('Pago em 30 dias', money(payroll.paid30 || 0))]),
				!payroll.covered ? hint('O caixa não cobre quem está de ponto agora: a folha paga na ordem até acabar o saldo.') : null,
				payroll.members.length ? el('div', { className: 'people' }, payroll.members.map((member) => el('div', { className: 'person' }, [
					el('div', {}, [member.name || `#${member.characterId}`, el('small', { textContent: member.grade || 'Sem cargo' })]),
					member.onDuty ? badge('De ponto', 'is-ok') : badge('Fora de ponto'),
					el('span', { className: 'amount', textContent: money(member.salary) })
				]))) : empty('Ninguém na equipe.'),
				row([run], 'end'),
				hint('A folha automática paga o salário do cargo a cada ciclo, só para quem está de ponto.')
			]),
			title('Bônus'),
			box([el('div', { className: 'grid-3' }, [labeled('Pessoa', memberSelect), labeled('Valor', bonusAmount), labeled('Motivo', bonusMemo)]), row([bonus], 'end')]),
			title('Pagamentos dos últimos 30 dias'),
			ledger(payroll.history, 'Nenhum salário ou bônus pago.')
		);
	}

	function loanBox(view, loan, api) {
		const rights = view.rights || {};
		const actions = rights.loans ? row([
			button(`Pagar parcela · ${money(loan.remaining)}`, 'primary', () => api.act('loanPay', { loanId: loan.id, mode: 'installment' })),
			button(`Quitar · ${money(loan.payable)}`, null, async () => {
				const ok = await confirm({ title: 'Quitar empréstimo', message: `Debitar ${money(loan.payable)} do caixa de ${view.business.label} e quitar o empréstimo #${loan.id}?`, confirmLabel: 'Quitar' });
				if (ok) api.act('loanPay', { loanId: loan.id, mode: 'total' });
			})
		], 'wrap') : null;
		return box([
			boxHead([strong(`Empréstimo empresarial #${loan.id}`), loan.late ? badge('Em atraso', 'is-bad') : badge('Em dia', 'is-ok')], el('span', { className: 'amount', textContent: money(loan.payable) })),
			el('div', { className: 'grid-4' }, [
				cell('Parcela', `${Math.min(loan.paidCount + 1, loan.installments)} de ${loan.installments}`),
				cell('Valor da parcela', money(loan.remaining)),
				cell('Vencimento', date(loan.dueAt)),
				cell('Total contratado', money(loan.total))
			]),
			el('div', { className: 'meter' }, [el('i', { style: `width:${loan.installments > 0 ? Math.min(100, loan.paidCount / loan.installments * 100) : 0}%` })]),
			actions,
			hint(`Débito automático no caixa. Se o caixa não cobrir, a parcela atrasa e pesa no relacionamento do dono e dos sócios. ${loanDetail(loan)}`)
		], loan.late);
	}

	function loansSection(container, view, api) {
		const loans = view.loans || [];
		container.append(title('Empréstimos ativos'), ...(loans.length ? loans.map((loan) => loanBox(view, loan, api)) : [empty('Nenhum empréstimo ativo.')]));
		const offer = view.loanOffer;
		if (!offer) {
			container.append(hint('Só o proprietário pede empréstimo em nome da empresa.'));
			return;
		}
		const pricing = offer.pricing || {};
		const info = [el('div', { className: 'grid-3' }, [cell('Pontuação média', `${offer.score} / 1000`), cell('Juros totais', `${pricing.rate}%`), cell('Atraso', `${pricing.lateDailyRate}% ao dia`)]),
			hint(`Média sua e de ${Math.max(0, offer.debtors - 1)} sócio(s). Quanto melhor o relacionamento, menores os juros.`)];
		if (offer.last) {
			const decided = offer.last.status === 'approved' ? 'aprovado' : offer.last.status === 'rejected' ? 'recusado' : 'cancelado';
			info.push(hint(`Último pedido (${money(offer.last.principal)}) ${decided} em ${date(offer.last.decidedAt)}${offer.last.reason ? ': ' + offer.last.reason : ''}.`));
		}
		container.append(title('Pedir empréstimo'));
		if (offer.pending) {
			container.append(box([
				boxHead([strong('Pedido em análise'), badge('Pendente', 'is-warn')], el('span', { className: 'amount', textContent: money(offer.pending.principal) })),
				hint(`${offer.pending.installments} parcela(s) · enviado em ${date(offer.pending.createdAt)}${offer.pending.note ? ' · ' + offer.pending.note : ''}`),
				row([button('Cancelar pedido', null, () => api.act('loanRequestCancel', { requestId: offer.pending.id }))], 'end'),
				...info
			]));
			return;
		}
		if (loans.length > 0) {
			container.append(box([...info, hint('Quite o empréstimo atual para pedir outro.')]));
			return;
		}
		if (api.channel !== 'agency') {
			container.append(box([...info, hint('O pedido é feito na agência, na conta da empresa.')]));
			return;
		}
		const principal = amountInput(`Até ${money(offer.maxPrincipal)}`, offer.maxPrincipal);
		const installments = field({ type: 'number', min: 1, max: offer.maxInstallments, step: 1, value: 4 });
		const note = field({ type: 'text', maxLength: 64, placeholder: 'Finalidade (opcional)' });
		const send = button('Pedir empréstimo', 'primary', async () => {
			const amount = readAmount(principal);
			const count = Number(installments.value);
			if (!amount || !Number.isInteger(count) || count < 1 || count > offer.maxInstallments) return;
			const total = amount + Math.ceil(amount * pricing.rate / 100 - 1e-9);
			const ok = await confirm({
				title: 'Pedir empréstimo empresarial',
				message: `Pedir ${money(amount)} para ${view.business.label}: total ${money(total)} em ${count} parcela(s), uma a cada ${offer.intervalDays} dias, debitadas do caixa. A dívida fica em seu nome e dos sócios. O banco vai analisar o pedido.`,
				confirmLabel: 'Enviar pedido'
			});
			if (ok) api.act('loanRequest', { principal: amount, installments: count, note: note.value.trim() });
		});
		container.append(box([...info,
			el('div', { className: 'grid-3' }, [labeled('Valor', principal), labeled(`Parcelas (até ${offer.maxInstallments})`, installments), labeled('Finalidade', note)]),
			row([send], 'end')]));
	}

	const RENDER = { summary: summarySection, statement: statementSection, transfer: transferSection, cards: cardsSection, payroll: payrollSection, loans: loansSection };

	function renderSection(container, id, view, api) {
		const list = sections(view);
		const current = list.some(([key]) => key === id) ? id : list[0][0];
		(RENDER[current] || summarySection)(container, view, api);
		return current;
	}

	// Tela de escolha da conta na agência.
	function chooser(view, onPick) {
		const tiles = [el('button', { type: 'button', className: 'account-tile' }, [
			el('span', { className: 'eyebrow', textContent: 'Pessoa física' }), strong(view.holder || 'Conta pessoal'), el('small', { textContent: 'Conta, cartões, crédito e empréstimos pessoais' })
		])];
		tiles[0].onclick = () => onPick('personal');
		for (const account of view.accounts || []) {
			const tile = el('button', { type: 'button', className: 'account-tile' }, [
				el('span', { className: 'eyebrow', textContent: 'Empresa' }), strong(account.label), el('small', { textContent: account.role })
			]);
			tile.onclick = () => onPick('business', account.id);
			tiles.push(tile);
		}
		return el('div', {}, [title('Qual conta você quer acessar?'), el('div', { className: 'account-tiles' }, tiles),
			hint('A conta da empresa é separada da sua: cada operação fica registrada com o seu nome.')]);
	}

	window.CoeBusinessBank = Object.freeze({ sections, summary, renderSection, chooser, reasonLabel });

	// Aba Banco do app do negócio: o estado é a conta empresarial (result.bank); as respostas trazem a conta
	// atualizada mesmo com erro. Sem conta (bank_unavailable), o app esconde a aba e volta ao Financeiro.
	let tabletSection = 'summary';
	function tabletRender(root, view, api) {
		const list = sections(view);
		if (!list.some(([key]) => key === tabletSection)) tabletSection = list[0][0];
		const kpis = el('div', { className: 'grid-4' });
		summary(view).forEach((node) => { if (node) kpis.append(node); });
		root.append(kpis);
		const bar = el('div', { className: 'tb-tabs' });
		for (const [key, label, flagged] of list) {
			const node = el('button', { type: 'button', className: 'tb-tab' + (tabletSection === key ? ' is-active' : ''), textContent: label + (flagged ? ' •' : '') });
			node.onclick = () => { tabletSection = key; api.status(''); api.render(); };
			bar.append(node);
		}
		root.append(bar);
		const body = el('div', { className: 'bank-ui' });
		tabletSection = renderSection(body, tabletSection, view, {
			channel: 'tablet',
			act: (action, payload) => {
				api.request(action, payload || {}).then((result) => {
					if (!result.ok) api.status(result.message || api.errorText(result.error), 'error');
					else if (action !== 'overview' && action !== 'statement') api.status('Operação concluída.', 'ok');
					if (result.bank) api.update(result.bank); else api.render();
				});
			}
		});
		root.append(body);
	}

	window.CoeBusinessTabs = window.CoeBusinessTabs || {};
	window.CoeBusinessTabs.bank = {
		render: tabletRender,
		state: (result) => result.bank,
		unavailable: ['bank_unavailable'],
		errors: { bank_unavailable: 'Banco indisponível no momento.' }
	};
})();
