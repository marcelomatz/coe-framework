// Loja (coe_shops): vitrine com categorias, carrinho, pagamento (espécie, Carteira do celular ou cartão na maquininha)
// e gestão para o dono e a equipe (preços, prateleira e relatório). O servidor decide preço, estoque e cobrança.
(function () {
	'use strict';

	const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'coe_shops';
	const IMAGES = 'nui://coe_inventory/data/images/';
	const METHODS = { cash: 'Dinheiro', wallet: 'Carteira do celular', card: 'Cartão na maquininha' };
	const ERRORS = {
		too_far: 'Chegue mais perto do balcão.', store_closed: 'A loja está fechada.', unknown_product: 'Produto indisponível.',
		invalid_quantity: 'Quantidade inválida.', empty_cart: 'O carrinho está vazio.', cart_too_big: 'Itens demais no carrinho.',
		cart_too_expensive: 'Compra acima do limite do caixa.', out_of_stock: 'Sem estoque suficiente', invalid_method: 'Escolha como pagar.',
		insufficient_cash: 'Você não tem dinheiro suficiente.', payment_failed: 'O pagamento não passou.', payment_expired: 'O pagamento expirou. Tente de novo.',
		cancelled: 'Pagamento cancelado.', phone_unavailable: 'Celular indisponível. Use dinheiro ou cartão.', inventory_full: 'Seus bolsos estão cheios. O valor foi devolvido.',
		no_card: 'Cartão não encontrado.', card_blocked: 'Cartão bloqueado.', card_expired: 'Cartão vencido.', no_credit: 'Esse cartão não tem crédito liberado.',
		credit_late: 'Cartão bloqueado por fatura em atraso.', credit_limit: 'Limite do cartão insuficiente.', card_not_in_hand: 'O cartão precisa estar com você.',
		wrong_pin: 'Senha incorreta.', invalid_pin: 'Digite os 4 dígitos da senha.', busy: 'Aguarde um instante.', forbidden: 'Você não tem permissão para isso.',
		staff_store: 'Loja da staff: estoque e preço automáticos.', invalid_price: 'Preço fora da faixa permitida.', stock_full: 'A prateleira não comporta tanto.',
		missing_items: 'Você não tem esses itens no inventário.', not_enough_stock: 'Não há tanto na prateleira.', database_error: 'Falha ao gravar. Tente de novo.',
		no_inventory: 'Inventário indisponível.', internal_error: 'Erro na loja. Tente de novo.', timeout: 'Sem resposta da loja.', closed: 'Loja fechada.'
	};

	const els = {
		overlay: document.getElementById('shop'),
		eyebrow: document.getElementById('sh-eyebrow'),
		title: document.getElementById('sh-title'),
		badges: document.getElementById('sh-badges'),
		tabs: document.getElementById('sh-tabs'),
		body: document.getElementById('sh-body'),
		status: document.getElementById('sh-status'),
		close: document.getElementById('sh-close')
	};

	let view = null;
	let tab = 'shop';
	let category = 'all';
	let search = '';
	let cart = {};
	let method = null;
	let cardId = null;
	let busy = false;
	let report = null;

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
	function money(value) { return '$ ' + Math.floor(value || 0).toLocaleString('pt-BR'); }
	function post(name, body) {
		return fetch('https://' + resource + '/' + name, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json; charset=UTF-8' },
			body: JSON.stringify(body || {})
		}).then(function (response) { return response.json(); }).catch(function () { return { ok: false, error: 'closed' }; });
	}
	function status(text, kind) {
		els.status.textContent = text || '';
		els.status.className = 'sh-status' + (kind ? ' is-' + kind : '');
	}
	function errorText(result) {
		const code = result && result.error;
		let text = ERRORS[code] || 'Não foi possível concluir.';
		if (code === 'out_of_stock' && result.product) { text += ' de ' + result.product + '.'; }
		if (code === 'wrong_pin' && result.left !== undefined && result.left !== null) { text += ' Restam ' + result.left + ' tentativas.'; }
		return text;
	}
	function productById(id) { return view.products.find(function (p) { return p.id === id; }); }
	function image(product) { const img = el('img'); img.src = IMAGES + product.image; img.alt = ''; return img; }
	function cartList() {
		return Object.keys(cart).filter(function (id) { return cart[id] > 0; }).map(function (id) { return { id: id, quantity: cart[id] }; });
	}
	function cartTotal() {
		return cartList().reduce(function (sum, line) { const p = productById(line.id); return sum + (p ? p.price * line.quantity : 0); }, 0);
	}

	// Cabeçalho e abas ------------------------------------------------------------------------------------

	function paintHead() {
		els.eyebrow.textContent = view.store.typeLabel;
		els.title.textContent = view.store.label;
		els.badges.replaceChildren();
		els.badges.appendChild(el('span', 'sh-badge' + (view.mode === 'player' ? ' sh-badge--accent' : ''),
			view.mode === 'player' ? 'Dono: ' + (view.owner || 'jogador') : 'Loja da cidade'));
		els.tabs.replaceChildren();
		const access = view.access || {};
		const canManage = access.work || access.prices || access.stock || access.report || access.staffView;
		if (!canManage) { tab = 'shop'; return; }
		[['shop', 'Comprar'], ['manage', 'Gestão']].forEach(function (pair) {
			const node = button(pair[1], 'sh-tab' + (tab === pair[0] ? ' is-active' : ''), function () {
				tab = pair[0];
				if (tab === 'manage') { loadReport(); }
				render();
			});
			els.tabs.appendChild(node);
		});
	}

	// Comprar ---------------------------------------------------------------------------------------------

	function addToCart(product, delta) {
		const current = cart[product.id] || 0;
		let next = Math.max(0, current + delta);
		next = Math.min(next, view.limits.quantity);
		if (product.stock !== undefined && product.stock !== null) { next = Math.min(next, product.stock); }
		cart[product.id] = next;
		if (!next) { delete cart[product.id]; }
		render();
	}

	function catalogPane() {
		const pane = el('section', 'sh-catalog');
		const filters = el('div', 'sh-filters');
		const used = {};
		view.products.forEach(function (p) { used[p.category] = true; });
		[{ id: 'all', label: 'Tudo' }].concat(view.categories.filter(function (c) { return used[c.id]; })).forEach(function (c) {
			filters.appendChild(button(c.label, 'sh-chip' + (category === c.id ? ' is-active' : ''), function () { category = c.id; render(); }));
		});
		const field = el('input', 'coe-field sh-search');
		field.placeholder = 'Buscar';
		field.value = search;
		field.addEventListener('input', function () {
			search = field.value;
			paintGrid();
		});
		filters.appendChild(field);
		const grid = el('div', 'sh-grid');
		function paintGrid() {
			grid.replaceChildren();
			const term = search.trim().toLowerCase();
			view.products.filter(function (p) {
				return (category === 'all' || p.category === category) && (!term || p.label.toLowerCase().indexOf(term) >= 0);
			}).forEach(function (product) {
				const out = product.stock === 0;
				const card = button('', 'sh-product', function () { addToCart(product, 1); });
				card.disabled = out;
				card.append(image(product), el('strong', null, product.label), el('span', 'sh-price', money(product.price)));
				if (product.stock !== undefined && product.stock !== null) {
					card.appendChild(el('span', 'sh-stock' + (out ? ' is-out' : ''), out ? 'Esgotado' : product.stock + ' un.'));
				}
				if (cart[product.id]) { card.appendChild(el('span', 'sh-in-cart', cart[product.id])); }
				grid.appendChild(card);
			});
			if (!grid.childNodes.length) { grid.appendChild(el('p', 'sh-empty', 'Nada encontrado.')); }
		}
		paintGrid();
		pane.append(filters, grid);
		return pane;
	}

	function methodButton(id, detail, disabled) {
		const node = button('', 'sh-method' + (method === id ? ' is-active' : ''), function () { method = id; render(); });
		node.disabled = disabled;
		node.append(el('strong', null, METHODS[id]), el('small', null, detail));
		return node;
	}

	function sidePane() {
		const side = el('section', 'sh-side');
		side.appendChild(el('h2', null, 'Carrinho'));
		const list = el('div', 'sh-cart');
		const lines = cartList();
		if (!lines.length) { list.appendChild(el('p', 'sh-empty', 'Toque nos produtos para adicionar.')); }
		lines.forEach(function (line) {
			const product = productById(line.id);
			if (!product) { return; }
			const row = el('div', 'sh-line');
			const text = el('div', 'sh-line-text');
			text.append(el('strong', null, product.label), el('small', null, money(product.price) + ' · ' + money(product.price * line.quantity)));
			const qty = el('div', 'sh-qty');
			qty.append(button('−', null, function () { addToCart(product, -1); }), el('span', null, line.quantity), button('+', null, function () { addToCart(product, 1); }));
			row.append(image(product), text, qty);
			list.appendChild(row);
		});
		side.appendChild(list);

		const checkout = el('div', 'sh-checkout');
		const total = cartTotal();
		const totalRow = el('div', 'sh-total');
		totalRow.append(el('span', null, 'Total'), el('strong', null, money(total)));
		checkout.appendChild(totalRow);
		const methods = el('div', 'sh-methods');
		if (view.payments.cash) { methods.appendChild(methodButton('cash', 'Você tem ' + money(view.cash) + ' em espécie', view.cash < total)); }
		if (view.payments.wallet) { methods.appendChild(methodButton('wallet', 'Paga pelo celular com um cartão da Carteira', false)); }
		if (view.payments.card) {
			methods.appendChild(methodButton('card', view.cards.length ? 'Cartão do banco que está com você, com a senha' : 'Nenhum cartão do banco com você', !view.cards.length));
		}
		checkout.appendChild(methods);
		if (method === 'card' && view.cards.length) {
			const cards = el('div', 'sh-cards');
			if (!view.cards.some(function (c) { return c.id === cardId; })) { cardId = view.cards[0].id; }
			view.cards.forEach(function (card) {
				cards.appendChild(button((card.business ? 'Empresa ' : '') + '•••• ' + card.last4, 'sh-card' + (card.id === cardId ? ' is-active' : ''), function () { cardId = card.id; render(); }));
			});
			checkout.appendChild(cards);
		}
		const pay = button(busy ? 'Processando…' : 'Pagar ' + money(total), 'coe-button coe-button--primary sh-pay', confirm);
		pay.disabled = busy || !lines.length || !method;
		checkout.appendChild(pay);
		side.appendChild(checkout);
		return side;
	}

	function finish(result) {
		busy = false;
		if (result && result.ok) {
			cart = {};
			if (result.view) { view = result.view; }
			status('Compra de ' + money(result.total) + ' concluída. Os itens estão no seu inventário.', 'success');
		} else {
			if (result && result.view) { view = result.view; }
			status(errorText(result), 'error');
		}
		render();
	}

	function confirm() {
		if (busy || !method) { return; }
		if (method === 'card') { askPin(); return; }
		busy = true;
		status(method === 'wallet' ? 'Confirme o pagamento no celular…' : 'Processando…');
		render();
		post('buy', { cart: cartList(), method: method }).then(finish);
	}

	function askPin() {
		const card = view.cards.find(function (c) { return c.id === cardId; });
		if (!card) { return; }
		let pin = '';
		const layer = el('div', 'sh-pin');
		const box = el('div', 'sh-pin-box coe-panel coe-panel--compact');
		const dots = el('div', 'sh-pin-dots');
		const msg = el('p', 'sh-pin-msg');
		function paintDots() {
			dots.replaceChildren();
			for (let i = 0; i < 4; i += 1) { dots.appendChild(el('i', i < pin.length ? 'is-on' : null)); }
		}
		function close() { layer.remove(); document.removeEventListener('keydown', onKey, true); }
		function submit() {
			if (pin.length !== 4) { msg.textContent = ERRORS.invalid_pin; return; }
			close();
			busy = true;
			status('Processando na maquininha…');
			render();
			post('buy', { cart: cartList(), method: 'card', cardId: card.id, pin: pin }).then(finish);
		}
		function press(key) {
			if (key === 'back') { pin = pin.slice(0, -1); } else if (key === 'ok') { submit(); return; } else if (pin.length < 4) { pin += key; }
			msg.textContent = '';
			paintDots();
			if (pin.length === 4) { setTimeout(submit, 150); }
		}
		function onKey(event) {
			if (/^\d$/.test(event.key)) { press(event.key); } else if (event.key === 'Backspace') { press('back'); } else if (event.key === 'Enter') { press('ok'); } else if (event.key === 'Escape') { close(); } else { return; }
			event.preventDefault();
			event.stopPropagation();
		}
		document.addEventListener('keydown', onKey, true);
		const keys = el('div', 'sh-keys');
		['1', '2', '3', '4', '5', '6', '7', '8', '9', 'back', '0', 'ok'].forEach(function (key) {
			keys.appendChild(button(key === 'back' ? '⌫' : key === 'ok' ? 'OK' : key, null, function () { press(key); }));
		});
		box.append(el('h3', null, 'Senha do cartão •••• ' + card.last4), el('small', 'sh-hint', 'Total: ' + money(cartTotal())), dots, msg, keys,
			button('Cancelar', 'coe-button', close));
		paintDots();
		layer.appendChild(box);
		document.body.appendChild(layer);
	}

	function shopTab() {
		const wrap = el('div', 'sh-shop');
		wrap.append(catalogPane(), sidePane());
		return wrap;
	}

	// Gestão ----------------------------------------------------------------------------------------------

	function loadReport() {
		const access = view.access || {};
		if (!access.report) { report = null; return; }
		post('manage', { op: 'report' }).then(function (result) {
			report = result && result.ok ? result.report : null;
			if (tab === 'manage') { render(); }
		});
	}

	function manageAction(op, args, success) {
		if (busy) { return; }
		busy = true;
		post('manage', { op: op, args: args }).then(function (result) {
			busy = false;
			if (result && result.ok) {
				if (result.view) { view = result.view; }
				status(success, 'success');
				loadReport();
			} else {
				status(errorText(result), 'error');
			}
			render();
		});
	}

	function qtyInput(placeholder) {
		const field = el('input', 'coe-field');
		field.type = 'number';
		field.min = '1';
		field.placeholder = placeholder;
		return field;
	}

	function manageTable() {
		const wrap = el('div', 'sh-table-wrap');
		const access = view.access || {};
		if (view.mode === 'staff') {
			wrap.appendChild(el('p', 'sh-notice', 'Loja da cidade (staff): o estoque fica sempre cheio e os preços são os de tabela. '
				+ 'Quando a staff definir um dono no painel (Negócios), o dono e a equipe passam a abastecer a prateleira e definir os preços aqui. '
				+ 'A receita das vendas entra no caixa do negócio.'));
		} else {
			wrap.appendChild(el('p', 'sh-notice', 'Abasteça com itens do seu inventário (feitos na bancada, comprados ou trazidos de carregamentos). '
				+ 'O cliente só vê o que está na prateleira. Preço entre o mínimo e o máximo de cada produto.'));
		}
		const table = el('table', 'sh-table');
		const head = el('tr');
		['Produto', 'Prateleira', 'Preço', 'Abastecer', 'Retirar'].forEach(function (t) { head.appendChild(el('th', null, t)); });
		const thead = el('thead');
		thead.appendChild(head);
		table.appendChild(thead);
		const body = el('tbody');
		view.products.forEach(function (product) {
			const row = el('tr');
			const name = el('td');
			const prod = el('div', 'sh-prod');
			prod.append(image(product), el('span', null, product.label));
			name.appendChild(prod);
			row.appendChild(name);
			row.appendChild(el('td', 'sh-num', view.mode === 'staff' ? '∞' : (product.stock || 0) + ' / ' + view.limits.maxStock));
			const priceCell = el('td');
			if (view.mode === 'player' && access.prices) {
				const box = el('div', 'sh-inline');
				const field = qtyInput(String(product.price));
				field.value = product.price;
				field.min = String(product.min);
				field.max = String(product.max);
				box.append(field, button('Salvar', 'coe-button', function () {
					manageAction('price', { productId: product.id, price: Number(field.value) }, 'Preço de ' + product.label + ' salvo.');
				}));
				priceCell.append(box, el('div', 'sh-hint', 'tabela ' + money(product.base) + ' · ' + money(product.min) + '–' + money(product.max)));
			} else {
				priceCell.appendChild(el('span', 'sh-num', money(product.price)));
			}
			row.appendChild(priceCell);
			const restockCell = el('td');
			if (view.mode === 'player' && access.work) {
				const box = el('div', 'sh-inline');
				const field = qtyInput('qtd.');
				box.append(field, button('Pôr', 'coe-button', function () {
					manageAction('restock', { productId: product.id, quantity: Number(field.value) }, product.label + ' na prateleira.');
				}));
				restockCell.appendChild(box);
			} else {
				restockCell.appendChild(el('span', 'sh-hint', '—'));
			}
			row.appendChild(restockCell);
			const withdrawCell = el('td');
			if (view.mode === 'player' && access.stock) {
				const box = el('div', 'sh-inline');
				const field = qtyInput('qtd.');
				box.append(field, button('Tirar', 'coe-button', function () {
					manageAction('withdraw', { productId: product.id, quantity: Number(field.value) }, product.label + ' retirado da prateleira.');
				}));
				withdrawCell.appendChild(box);
			} else {
				withdrawCell.appendChild(el('span', 'sh-hint', '—'));
			}
			row.appendChild(withdrawCell);
			body.appendChild(row);
		});
		table.appendChild(body);
		wrap.appendChild(table);
		return wrap;
	}

	function reportPane() {
		const pane = el('section', 'sh-report');
		pane.appendChild(el('h2', null, 'Vendas'));
		if (!(view.access || {}).report) {
			pane.appendChild(el('p', 'sh-empty', 'O relatório é do dono e de quem gerencia preços ou estoque.'));
			return pane;
		}
		if (!report) {
			pane.appendChild(el('p', 'sh-empty', 'Carregando…'));
			return pane;
		}
		const kpis = el('div', 'sh-kpis');
		[[money(report.today), 'hoje'], [money(report.week), '7 dias (' + report.weekSales + ' vendas)'],
			[typeof report.balance === 'number' ? money(report.balance) : '—', 'caixa do negócio']].forEach(function (pair) {
			const kpi = el('div', 'sh-kpi');
			kpi.append(el('strong', null, pair[0]), el('small', null, pair[1]));
			kpis.appendChild(kpi);
		});
		pane.appendChild(kpis);
		pane.appendChild(el('h2', null, 'Últimas vendas'));
		if (!report.sales.length) { pane.appendChild(el('p', 'sh-empty', 'Nenhuma venda ainda.')); }
		report.sales.forEach(function (sale) {
			const row = el('div', 'sh-sale');
			const when = new Date(sale.at * 1000).toLocaleString('pt-BR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' });
			row.append(el('span', null, sale.units + (sale.units === 1 ? ' item' : ' itens') + ' · ' + (METHODS[sale.method] || sale.method)),
				el('strong', null, money(sale.total)), el('small', null, when));
			pane.appendChild(row);
		});
		return pane;
	}

	function manageTab() {
		const wrap = el('div', 'sh-manage');
		wrap.append(manageTable(), reportPane());
		return wrap;
	}

	// Ciclo -----------------------------------------------------------------------------------------------

	function render() {
		if (!view) { return; }
		paintHead();
		const scroll = els.body.querySelector('.sh-grid, .sh-table-wrap');
		const top = scroll ? scroll.scrollTop : 0;
		els.body.replaceChildren(tab === 'manage' ? manageTab() : shopTab());
		const next = els.body.querySelector('.sh-grid, .sh-table-wrap');
		if (next) { next.scrollTop = top; }
	}

	function open(data) {
		view = data;
		tab = 'shop';
		category = 'all';
		search = '';
		cart = {};
		method = null;
		report = null;
		busy = false;
		status('');
		els.overlay.classList.remove('is-hidden', 'is-suspended');
		els.overlay.setAttribute('aria-hidden', 'false');
		render();
	}

	function hide(notify) {
		els.overlay.classList.add('is-hidden');
		els.overlay.setAttribute('aria-hidden', 'true');
		const pin = document.querySelector('.sh-pin');
		if (pin) { pin.remove(); }
		view = null;
		if (notify) { post('close'); }
	}

	els.close.addEventListener('click', function () { hide(true); });
	window.addEventListener('keydown', function (event) {
		if (view && event.key === 'Escape' && !document.querySelector('.sh-pin') && document.activeElement.tagName !== 'INPUT') {
			event.preventDefault();
			hide(true);
		}
	});
	window.addEventListener('message', function (event) {
		const data = event.data || {};
		if (data.action === 'open' && data.view) { open(data.view); }
		if (data.action === 'close') { hide(false); }
		if (data.action === 'suspend') { els.overlay.classList.toggle('is-suspended', data.value === true); }
	});
})();
