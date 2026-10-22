// Banco básico (coe_bank): saldo, saque, depósito, transferência por ID de cidadão e extrato. O servidor decide tudo;
// a tela só mostra a conta e envia os pedidos.
(function () {
	'use strict';

	const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'coe_bank';
	const ERRORS = {
		too_far: 'Você se afastou do atendimento.', busy: 'Aguarde um instante.', no_character: 'Personagem não carregado.',
		invalid_amount: 'Valor inválido.', invalid_state_id: 'ID de cidadão inválido (8 caracteres).',
		character_not_found: 'Nenhum cidadão com esse ID.', same_account: 'Esse ID é o seu.',
		insufficient_funds: 'Saldo insuficiente.', insufficient_cash: 'Você não tem esse valor em espécie.',
		inventory_full: 'Seus bolsos estão cheios. O valor voltou para a conta.',
		balance_limit: 'A conta de destino não pode receber esse valor.', economy_unavailable: 'Sistema bancário fora do ar.',
		database_error: 'Falha ao consultar. Tente de novo.', unavailable: 'Atendimento indisponível.',
		timeout: 'Sem resposta do banco.', closed: 'Atendimento encerrado.'
	};
	const REASONS = {
		bank_withdraw: 'Saque', bank_deposit: 'Depósito', bank_transfer: 'Transferência', bank_refund: 'Estorno',
		payroll: 'Salário', society_deposit: 'Depósito na empresa', society_withdraw: 'Saque da empresa',
		business_payment: 'Pagamento de empresa', business_bonus: 'Bônus', admin_adjustment: 'Ajuste da staff',
		job_payment: 'Pagamento de trabalho', shop_purchase: 'Compra em loja'
	};
	const TABS = {
		agency: [
			{ id: 'statement', label: 'Extrato' },
			{ id: 'withdraw', label: 'Sacar' },
			{ id: 'deposit', label: 'Depositar' },
			{ id: 'transfer', label: 'Transferir' }
		],
		atm: [
			{ id: 'withdraw', label: 'Sacar' },
			{ id: 'deposit', label: 'Depositar' },
			{ id: 'statement', label: 'Últimas movimentações' }
		]
	};

	const els = {
		panel: document.getElementById('bank'),
		eyebrow: document.getElementById('bk-eyebrow'),
		title: document.getElementById('bk-title'),
		summary: document.getElementById('bk-summary'),
		tabs: document.getElementById('bk-tabs'),
		body: document.getElementById('bk-body'),
		status: document.getElementById('bk-status'),
		close: document.getElementById('bk-close')
	};

	let view = null;
	let tab = null;
	let busy = false;

	function el(tag, className, text) {
		const node = document.createElement(tag);
		if (className) { node.className = className; }
		if (text !== undefined && text !== null) { node.textContent = String(text); }
		return node;
	}
	function button(label, className, onClick) {
		const node = el('button', className, label);
		node.type = 'button';
		node.addEventListener('click', onClick);
		return node;
	}
	function money(value) {
		const amount = Math.floor(Number(value) || 0);
		return (amount < 0 ? '-$ ' : '$ ') + Math.abs(amount).toLocaleString('pt-BR');
	}
	function post(name, body) {
		return fetch('https://' + resource + '/' + name, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json; charset=UTF-8' },
			body: JSON.stringify(body || {})
		}).then(function (response) { return response.json(); }).catch(function () { return { ok: false, error: 'closed' }; });
	}
	function status(text, kind) {
		els.status.textContent = text || '';
		els.status.className = 'bk-status' + (kind ? ' is-' + kind : '');
	}
	function errorText(result) {
		return (result && (ERRORS[result.error] || result.message)) || 'Não foi possível concluir.';
	}
	function when(value) {
		if (value === undefined || value === null || value === '') { return ''; }
		let date = typeof value === 'number' ? new Date(value < 1e12 ? value * 1000 : value) : new Date(String(value).replace(' ', 'T'));
		if (isNaN(date.getTime())) { return ''; }
		const pad = function (n) { return String(n).padStart(2, '0'); };
		return pad(date.getDate()) + '/' + pad(date.getMonth() + 1) + ' ' + pad(date.getHours()) + ':' + pad(date.getMinutes());
	}
	function reasonLabel(entry) {
		const label = REASONS[entry.reason] || (entry.reason ? entry.reason.replace(/_/g, ' ') : 'Movimentação');
		const match = /^state:([A-Z0-9]+)$/.exec(entry.reference || '');
		if (match && entry.reason === 'bank_transfer') {
			return label + (entry.delta < 0 ? ' para ' : ' de ') + match[1];
		}
		return label.charAt(0).toUpperCase() + label.slice(1);
	}

	// Pedido ao servidor: trava a tela, atualiza a conta e mostra o resultado.
	function act(action, data) {
		if (busy) { return Promise.resolve({ ok: false, error: 'busy' }); }
		busy = true;
		els.panel.classList.add('is-busy');
		return post('action', { action: action, data: data || {} }).then(function (result) {
			busy = false;
			els.panel.classList.remove('is-busy');
			if (result && result.view) { view = result.view; renderSummary(); }
			if (result && result.ok) {
				status(result.message || '', result.message ? 'success' : null);
			} else {
				status(errorText(result), 'error');
			}
			return result || { ok: false };
		});
	}

	// Resumo e abas ------------------------------------------------------------------------------------------

	function stat(label, value, className) {
		const box = el('div', 'bk-stat' + (className ? ' ' + className : ''));
		box.append(el('span', 'bk-stat-label', label), el('strong', 'bk-stat-value', value));
		return box;
	}

	function renderSummary() {
		els.summary.replaceChildren(
			stat('Saldo em conta', view.balance === null || view.balance === undefined ? 'Indisponível' : money(view.balance), 'is-main'),
			stat('Em espécie', money(view.cash)),
			stat('Titular', view.holder || '-'),
			stat('ID de cidadão', view.stateId || '-', 'is-mono')
		);
	}

	function renderTabs() {
		els.tabs.replaceChildren();
		(TABS[view.mode] || []).forEach(function (item) {
			const node = button(item.label, 'bk-tab' + (item.id === tab ? ' is-active' : ''), function () {
				if (tab === item.id) { return; }
				tab = item.id;
				status('');
				renderTabs();
				renderBody();
			});
			node.setAttribute('aria-current', item.id === tab ? 'page' : 'false');
			els.tabs.append(node);
		});
	}

	// Seções -------------------------------------------------------------------------------------------------

	function section(title, hint) {
		const head = el('div', 'bk-section');
		head.append(el('h2', 'bk-section-title', title));
		if (hint) { head.append(el('p', 'bk-hint', hint)); }
		return head;
	}

	function amountForm(kind) {
		const withdraw = kind === 'withdraw';
		const limit = withdraw ? Math.min(view.max, Math.max(0, view.balance || 0)) : Math.min(view.max, view.cash || 0);
		const form = el('form', 'bk-form');
		const field = el('label', 'bk-field');
		field.append(el('span', null, 'Valor'));
		const input = el('input', 'coe-field bk-amount');
		input.type = 'number';
		input.min = '1';
		input.max = String(view.max);
		input.step = '1';
		input.inputMode = 'numeric';
		input.placeholder = '0';
		field.append(input);

		const chips = el('div', 'bk-chips');
		(view.quick || []).forEach(function (value) {
			chips.append(button(money(value), 'coe-button bk-chip', function () { input.value = String(value); input.focus(); }));
		});
		chips.append(button(withdraw ? 'Máximo' : 'Tudo em espécie', 'coe-button bk-chip', function () {
			input.value = limit > 0 ? String(limit) : '';
			input.focus();
		}));

		const submit = el('button', 'coe-button coe-button--primary bk-submit', withdraw ? 'Sacar' : 'Depositar');
		submit.type = 'submit';
		form.append(field, chips, el('p', 'bk-hint', 'Até ' + money(view.max) + ' por operação.'), submit);
		form.addEventListener('submit', function (event) {
			event.preventDefault();
			const amount = Math.floor(Number(input.value));
			if (!amount || amount < 1 || amount > view.max) { status(ERRORS.invalid_amount, 'error'); return; }
			act(kind, { amount: amount }).then(function (result) {
				if (result.ok) { input.value = ''; renderBody(); }
			});
		});
		setTimeout(function () { input.focus(); }, 30);
		return form;
	}

	function transferForm() {
		const form = el('form', 'bk-form');
		const idField = el('label', 'bk-field');
		idField.append(el('span', null, 'ID de cidadão do destinatário'));
		const idInput = el('input', 'coe-field bk-id');
		idInput.maxLength = 9;
		idInput.placeholder = 'Ex.: K7M2Q9XA';
		idInput.autocomplete = 'off';
		idInput.addEventListener('input', function () { idInput.value = idInput.value.toUpperCase(); });
		idField.append(idInput);

		const amountField = el('label', 'bk-field');
		amountField.append(el('span', null, 'Valor'));
		const amountInput = el('input', 'coe-field bk-amount');
		amountInput.type = 'number';
		amountInput.min = '1';
		amountInput.max = String(view.max);
		amountInput.step = '1';
		amountInput.placeholder = '0';
		amountField.append(amountInput);

		const submit = el('button', 'coe-button coe-button--primary bk-submit', 'Continuar');
		submit.type = 'submit';
		form.append(idField, amountField,
			el('p', 'bk-hint', 'O valor sai do seu saldo e cai na hora na conta do destinatário, mesmo que ele esteja fora da cidade.'),
			submit);
		form.addEventListener('submit', function (event) {
			event.preventDefault();
			const stateId = idInput.value.replace(/[\s-]/g, '').toUpperCase();
			const amount = Math.floor(Number(amountInput.value));
			if (stateId.length !== 8) { status(ERRORS.invalid_state_id, 'error'); return; }
			if (!amount || amount < 1 || amount > view.max) { status(ERRORS.invalid_amount, 'error'); return; }
			act('lookup', { stateId: stateId }).then(function (result) {
				if (!result.ok || !result.data) { return null; }
				status('');
				const ask = window.CoeUI && window.CoeUI.confirm
					? window.CoeUI.confirm({
						title: 'Confirmar transferência',
						message: 'Transferir ' + money(amount) + ' para ' + result.data.name + ' (' + result.data.stateId + ')?',
						confirmLabel: 'Transferir', cancelLabel: 'Voltar'
					})
					: Promise.resolve(true);
				return ask.then(function (confirmed) {
					if (!confirmed) { return null; }
					return act('transfer', { stateId: stateId, amount: amount }).then(function (done) {
						if (done.ok) { idInput.value = ''; amountInput.value = ''; }
					});
				});
			});
		});
		setTimeout(function () { idInput.focus(); }, 30);
		return form;
	}

	function statementList() {
		const list = el('ol', 'bk-statement');
		const entries = view.statement || [];
		if (entries.length === 0) {
			const empty = el('li', 'bk-empty', 'Nenhuma movimentação ainda.');
			list.append(empty);
			return list;
		}
		entries.forEach(function (entry) {
			const row = el('li', 'bk-entry');
			const info = el('div', 'bk-entry-info');
			info.append(el('span', 'bk-entry-label', reasonLabel(entry)), el('small', 'bk-entry-date', when(entry.at)));
			row.append(info, el('strong', 'bk-entry-amount ' + (entry.delta < 0 ? 'is-out' : 'is-in'),
				(entry.delta < 0 ? '- ' : '+ ') + money(Math.abs(entry.delta))));
			list.append(row);
		});
		return list;
	}

	function renderBody() {
		els.body.replaceChildren();
		if (tab === 'statement') {
			els.body.append(section(view.mode === 'atm' ? 'Últimas movimentações' : 'Extrato', 'Mais recentes primeiro.'), statementList());
		} else if (tab === 'withdraw') {
			els.body.append(section('Sacar', 'Retira da conta e entrega em espécie.'), amountForm('withdraw'));
		} else if (tab === 'deposit') {
			els.body.append(section('Depositar', 'Guarda o dinheiro em espécie na conta.'), amountForm('deposit'));
		} else if (tab === 'transfer') {
			els.body.append(section('Transferir', 'Para qualquer cidadão pelo ID (comando /id).'), transferForm());
		}
	}

	// Abrir e fechar -----------------------------------------------------------------------------------------

	function open(next) {
		view = next;
		tab = (TABS[view.mode] || [])[0].id;
		els.panel.classList.toggle('bk--atm', view.mode === 'atm');
		els.eyebrow.textContent = view.mode === 'atm' ? 'Autoatendimento' : 'Atendimento';
		els.title.textContent = view.title || 'Banco';
		status('');
		renderSummary();
		renderTabs();
		renderBody();
		els.panel.hidden = false;
	}

	function close() {
		els.panel.hidden = true;
		view = null;
		busy = false;
		els.panel.classList.remove('is-busy');
	}

	function requestClose() {
		if (els.panel.hidden) { return; }
		close();
		post('close');
	}

	els.close.addEventListener('click', requestClose);
	document.addEventListener('keydown', function (event) {
		if (event.key === 'Escape' && !els.panel.hidden && !document.querySelector('.coe-modal-overlay')) {
			requestClose();
		}
	});

	window.addEventListener('message', function (event) {
		const message = event.data || {};
		if (message.type === 'open' && message.view) { open(message.view); }
		if (message.type === 'close') { close(); }
	});
})();
