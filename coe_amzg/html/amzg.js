// Amzg: loja virtual do COE OS (smartphone e tablet). Vitrine por categoria, carrinho, endereço de entrega,
// frete e pagamento no cartão de crédito pela Carteira do smartphone. A entrega chega numa caixa dentro do imóvel.
(function () {
	'use strict';

	const host = window.CoePhone || window.CoeTablet;
	if (!host) { return; }

	if (!document.querySelector('link[data-coe-amzg]')) {
		const link = document.createElement('link');
		link.rel = 'stylesheet';
		link.href = 'nui://coe_amzg/html/amzg.css';
		link.dataset.coeAmzg = '1';
		document.head.appendChild(link);
	}

	const ERRORS = {
		not_ready: 'Loja ainda iniciando.', no_character: 'Personagem não carregado.',
		database_error: 'Falha ao gravar. Tente de novo.', unknown_action: 'Ação desconhecida.',
		not_installed: 'Instale o Amzg pela Loja.', busy: 'Aguarde a operação anterior terminar.',
		empty_cart: 'Seu carrinho está vazio.', cart_too_large: 'Produtos demais no carrinho.',
		invalid_cart: 'Carrinho inválido. Revise os itens.', product_unavailable: 'Um produto saiu do catálogo. Revise o carrinho.',
		invalid_shipping: 'Escolha o frete.', box_full: 'Os itens não cabem numa caixa. Divida em dois pedidos.',
		amount_too_high: 'Valor acima do permitido para uma compra.', invalid_address: 'Escolha um endereço de entrega válido.',
		price_changed: 'Os preços mudaram. Confira o total e pague de novo.', too_many_orders: 'Você já tem pedidos demais a caminho.',
		no_credit: 'Compras são pagas no cartão de crédito. Peça o seu na agência do banco.',
		no_card: 'Você precisa de um cartão de crédito ativo (não bloqueado nem vencido).',
		credit_late: 'Cartão de crédito bloqueado por fatura em atraso.', credit_limit: 'Limite do cartão de crédito insuficiente.',
		bank_unavailable: 'Banco indisponível no momento.',
		card_blocked: 'Cartão bloqueado. Escolha outro cartão na Carteira.', card_expired: 'Cartão vencido. Escolha outro cartão na Carteira.',
		wallet_required: 'Compras são pagas pela Carteira do smartphone.',
		payment_expired: 'O pagamento expirou. Tente de novo.', payment_mismatch: 'Pagamento não confere. Tente de novo.'
	};

	const STATUS = {
		pending: { label: 'A caminho', badge: '' },
		delivered: { label: 'Entregue', badge: ' coe-badge--success' },
		collected: { label: 'Retirado', badge: '' },
		refunded: { label: 'Estornado', badge: ' coe-badge--danger' }
	};

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
		return '$ ' + Number(value || 0).toLocaleString('pt-BR');
	}

	function eta(seconds, now) {
		const diff = Math.max(0, Number(seconds || 0) - Number(now || Math.floor(Date.now() / 1000)));
		if (diff < 60) { return 'chega em instantes'; }
		return 'chega em ' + Math.ceil(diff / 60) + ' min';
	}

	// Tempo restante da oferta: "2d 4h", "3h 12min" ou "12:05".
	function remaining(seconds) {
		if (seconds >= 86400) { return Math.floor(seconds / 86400) + 'd ' + Math.floor(seconds % 86400 / 3600) + 'h'; }
		if (seconds >= 3600) { return Math.floor(seconds / 3600) + 'h ' + Math.floor(seconds % 3600 / 60) + 'min'; }
		const minutes = Math.floor(seconds / 60);
		const rest = seconds % 60;
		return minutes + ':' + (rest < 10 ? '0' : '') + rest;
	}

	function image(product) {
		const img = el('img');
		img.alt = '';
		img.loading = 'lazy';
		img.src = 'nui://coe_inventory/data/images/' + encodeURIComponent(product.image || (product.item + '.png'));
		img.addEventListener('error', function () { img.remove(); });
		return img;
	}

	// O aparelho aceita uma ação a cada 250 ms: as chamadas passam por esta fila.
	const queue = [];
	let running = false;
	let lastSent = 0;
	const GAP = 300;

	function pump() {
		if (running || queue.length === 0) { return; }
		running = true;
		const job = queue.shift();
		const wait = Math.max(0, lastSent + GAP - Date.now());
		setTimeout(function () {
			lastSent = Date.now();
			job.api.call('amzg', job.action, job.payload).then(function (result) {
				if (result && result.error === 'rate_limited' && job.retries < 3) {
					job.retries += 1;
					queue.unshift(job);
				} else {
					job.resolve(result || { ok: false, error: 'app_error' });
				}
			}, function () {
				job.resolve({ ok: false, error: 'app_error' });
			}).then(function () {
				running = false;
				pump();
			});
		}, wait);
	}

	// O carrinho continua entre aberturas do app (enquanto o aparelho não reinicia).
	const cart = { lines: {}, address: null, shipping: null };

	host.register('amzg', function (root, api) {
		let catalog = null;
		let addresses = null;
		let tab = 'shop';
		let category = '';
		let search = '';
		let busy = false;
		let clockOffset = 0; // relógio do servidor - relógio da tela
		let ticker = null;
		let slide = 0;
		let reloading = false;

		function errorText(code) { return ERRORS[code] || api.errorText(code); }
		function fail(result) { api.status(errorText(result && result.error), 'error'); }
		function call(action, payload) {
			return new Promise(function (resolve) {
				queue.push({ api: api, action: action, payload: payload || {}, resolve: resolve, retries: 0 });
				pump();
			});
		}

		function product(id) {
			return (catalog && catalog.products || []).find(function (p) { return p.id === Number(id); });
		}

		// Remove do carrinho o que saiu do catálogo.
		function entries() {
			const list = [];
			Object.keys(cart.lines).forEach(function (id) {
				const p = product(id);
				if (p) { list.push({ product: p, qty: cart.lines[id] }); } else { delete cart.lines[id]; }
			});
			return list;
		}

		function count() {
			return entries().reduce(function (sum, line) { return sum + line.qty; }, 0);
		}

		function slots() {
			return entries().reduce(function (sum, line) { return sum + Math.ceil(line.qty / Math.max(1, line.product.maxStack || 1)); }, 0);
		}

		function shippingOption() {
			const list = catalog.shipping || [];
			return list.find(function (s) { return s.id === cart.shipping; }) || list[0];
		}

		function setQty(p, qty) {
			const limits = catalog.limits || {};
			if (qty <= 0) { delete cart.lines[p.id]; render(); return; }
			if (!cart.lines[p.id] && Object.keys(cart.lines).length >= (limits.MaxLines || 10)) {
				api.status('Limite de ' + limits.MaxLines + ' produtos diferentes por pedido.', 'error');
				return;
			}
			cart.lines[p.id] = Math.min(qty, limits.MaxQuantity || 50);
			render();
		}

		function stepper(p) {
			const qty = cart.lines[p.id] || 0;
			const box = el('div', 'az-step');
			box.append(
				button('−', '', function () { setQty(p, qty - 1); }),
				el('span', null, qty),
				button('+', '', function () { setQty(p, qty + 1); })
			);
			return box;
		}

		function header() {
			const head = el('div', 'tb-toolbar');
			const title = el('div', 'tb-title az-brand');
			title.append(el('strong', null, 'amzg'), el('span', 'tb-muted', 'Entrega dentro do seu imóvel'));
			head.appendChild(title);
			const tabs = el('div', 'az-tabs');
			const items = count();
			[
				{ id: 'shop', label: 'Loja' },
				{ id: 'cart', label: items ? 'Carrinho (' + items + ')' : 'Carrinho' },
				{ id: 'orders', label: 'Pedidos' }
			].forEach(function (t) {
				tabs.appendChild(button(t.label, 'tb-tab' + (t.id === tab ? ' is-active' : ''), function () {
					tab = t.id;
					if (tab === 'orders') { loadOrders(); return; }
					if (tab === 'cart' && !addresses) { loadAddresses(); }
					render();
				}));
			});
			return [head, tabs];
		}

		function shop(page) {
			const field = el('input', 'coe-field az-search');
			field.type = 'search';
			field.placeholder = 'Buscar produtos';
			field.value = search;
			field.addEventListener('input', function () {
				search = field.value;
				const position = field.selectionStart;
				render();
				const next = root.querySelector('.az-search');
				if (next) { next.focus(); next.setSelectionRange(position, position); }
			});
			page.appendChild(field);

			const chips = el('div', 'az-chips');
			const used = {};
			(catalog.products || []).forEach(function (p) { used[p.category] = true; });
			[{ id: '', label: 'Tudo' }].concat((catalog.categories || []).filter(function (c) { return used[c.id]; })).forEach(function (c) {
				const chip = el('button', 'az-chip' + (c.id === category ? ' is-active' : ''), c.label);
				chip.type = 'button';
				chip.addEventListener('click', function () { category = c.id; slide = 0; render(); });
				chips.appendChild(chip);
			});
			page.appendChild(chips);

			const term = search.trim().toLowerCase();
			const list = (catalog.products || []).filter(function (p) {
				return (!category || p.category === category) && (!term || p.label.toLowerCase().indexOf(term) >= 0);
			});
			if (list.length === 0) {
				page.appendChild(el('p', 'tb-empty', (catalog.products || []).length ? 'Nenhum produto encontrado.' : 'A loja ainda não tem produtos à venda.'));
				return;
			}

			// Banners só na vitrine (sem busca): o carrossel no topo e faixas menores no meio da grade.
			const promos = term ? [] : list.filter(function (p) { return p.listPrice; });
			let heroList = [];
			if (promos.length) {
				const featured = promos.filter(function (p) { return p.featured; });
				heroList = featured.length ? featured : promos;
				page.appendChild(hero(heroList));
			}
			const inline = promos.length > 1 ? promos.filter(function (p) { return heroList.indexOf(p) < 0; }) : [];
			const pool = inline.length ? inline : (promos.length > 1 ? promos : []);
			const every = Math.max(2, Number(catalog.promo && catalog.promo.inlineEvery) || 6);

			const grid = el('div', 'az-grid');
			let placed = 0;
			list.forEach(function (p, index) {
				grid.appendChild(card(p));
				if (pool.length && (index + 1) % every === 0 && index + 1 < list.length) {
					grid.appendChild(banner(pool[placed % pool.length], 'az-banner--inline'));
					placed += 1;
				}
			});
			page.appendChild(grid);
		}

		function priceBlock(p) {
			const box = el('div', 'az-prices');
			if (p.listPrice) { box.appendChild(el('s', 'az-was', money(p.listPrice))); }
			box.appendChild(el('span', 'az-price', money(p.price)));
			return box;
		}

		function card(p) {
			const node = el('div', 'coe-panel coe-panel--compact az-product' + (p.listPrice ? ' is-promo' : ''));
			const thumb = el('div', 'az-thumb');
			thumb.appendChild(image(p));
			if (p.discount) { thumb.appendChild(el('span', 'az-off', '-' + p.discount + '%')); }
			node.append(thumb, el('div', 'az-name', p.label), priceBlock(p));
			node.appendChild(cart.lines[p.id] ? stepper(p) : button('Adicionar', 'coe-button--primary', function () { setQty(p, 1); }));
			return node;
		}

		function countdown(p) {
			if (!p.promoUntil) { return null; }
			const node = el('span', 'az-countdown');
			node.dataset.until = String(p.promoUntil);
			paintCountdown(node);
			return node;
		}

		function paintCountdown(node) {
			const left = Number(node.dataset.until) - Math.floor(Date.now() / 1000 + clockOffset);
			if (left > 0) {
				node.textContent = 'Termina em ' + remaining(left);
				return true;
			}
			node.textContent = 'Oferta encerrada';
			return false;
		}

		// Banner montado com a imagem do produto: selo, nome, "De $X por $Y", prazo e botão de compra.
		function banner(p, variant) {
			const node = el('div', 'az-banner ' + (variant || ''));
			const text = el('div', 'az-banner-text');
			text.appendChild(el('span', 'az-banner-tag', p.bannerText || ('-' + p.discount + '% OFF')));
			text.appendChild(el('strong', 'az-banner-name', p.label));
			const deal = el('div', 'az-deal');
			deal.append(el('span', 'az-deal-label', 'De'), el('s', 'az-was', money(p.listPrice)), el('span', 'az-deal-label', 'por'), el('span', 'az-deal-price', money(p.price)));
			text.appendChild(deal);
			const foot = el('div', 'az-banner-foot');
			const qty = cart.lines[p.id] || 0;
			foot.appendChild(button(qty ? 'No carrinho (' + qty + ')' : 'Aproveitar', 'coe-button--primary az-banner-buy', function () { setQty(p, qty + 1); }));
			const clock = countdown(p);
			if (clock) { foot.appendChild(clock); }
			text.appendChild(foot);
			const art = el('div', 'az-banner-art');
			art.appendChild(image(p));
			if (p.discount && p.bannerText) { art.appendChild(el('span', 'az-off', '-' + p.discount + '%')); }
			node.append(text, art);
			return node;
		}

		// Carrossel do topo: troca sozinho a cada promo.rotateSeconds; os pontos escolhem o banner.
		function hero(list) {
			const box = el('div', 'az-hero');
			const stage = el('div', 'az-hero-stage');
			const dots = el('div', 'az-dots');
			box.append(stage, dots);
			slide = slide % list.length;
			function show(index) {
				slide = (index + list.length) % list.length;
				stage.replaceChildren(banner(list[slide], 'az-banner--hero'));
				Array.prototype.forEach.call(dots.children, function (dot, i) { dot.classList.toggle('is-active', i === slide); });
			}
			if (list.length > 1) {
				list.forEach(function (_, i) {
					const dot = el('button', 'az-dot');
					dot.type = 'button';
					dot.setAttribute('aria-label', 'Banner ' + (i + 1));
					dot.addEventListener('click', function () { show(i); box.dataset.paused = '1'; });
					dots.appendChild(dot);
				});
				box.dataset.rotate = '1';
				box.addEventListener('mouseenter', function () { box.dataset.hover = '1'; });
				box.addEventListener('mouseleave', function () { delete box.dataset.hover; });
				box.next = function () { show(slide + 1); };
			}
			show(slide);
			return box;
		}

		// Um relógio só para o app: atualiza os prazos e gira o carrossel. Para quando o app fecha.
		function startTicker() {
			if (ticker) { return; }
			let seconds = 0;
			ticker = setInterval(function () {
				if (!root.isConnected) { clearInterval(ticker); ticker = null; return; }
				seconds += 1;
				let expired = false;
				root.querySelectorAll('.az-countdown').forEach(function (node) {
					if (!paintCountdown(node)) { expired = true; }
				});
				// Oferta vencida: o servidor já cobra o preço cheio, então a vitrine é recarregada.
				if (expired && !reloading) {
					reloading = true;
					setTimeout(function () { loadCatalog(); }, 1500);
				}
				const rotate = Math.max(3, Number(catalog && catalog.promo && catalog.promo.rotateSeconds) || 6);
				const heroBox = root.querySelector('.az-hero[data-rotate]');
				if (heroBox && seconds % rotate === 0 && !heroBox.dataset.paused && !heroBox.dataset.hover && heroBox.next) { heroBox.next(); }
			}, 1000);
		}

		function option(active, title, detail, side, onClick) {
			const node = el('button', 'az-option' + (active ? ' is-active' : ''));
			node.type = 'button';
			const text = el('span', 'az-grow');
			text.appendChild(el('strong', null, title));
			if (detail) { text.appendChild(el('small', null, detail)); }
			node.appendChild(text);
			if (side) { node.appendChild(el('span', 'az-price', side)); }
			node.addEventListener('click', onClick);
			return node;
		}

		function addressKey(a) { return a.property + '|' + a.owner; }

		function cartView(page) {
			const lines = entries();
			if (lines.length === 0) {
				page.appendChild(el('p', 'tb-empty', 'Seu carrinho está vazio.'));
				page.appendChild(button('Ver produtos', 'coe-button--primary', function () { tab = 'shop'; render(); }));
				return;
			}
			lines.forEach(function (line) {
				const row = el('div', 'coe-panel coe-panel--compact az-line');
				const thumb = el('div', 'az-thumb');
				thumb.appendChild(image(line.product));
				const info = el('div');
				const each = el('div', 'tb-muted az-each');
				if (line.product.listPrice) { each.appendChild(el('s', 'az-was', money(line.product.listPrice))); }
				each.appendChild(document.createTextNode(money(line.product.price) + ' × ' + line.qty));
				info.append(el('div', 'az-name', line.product.label), each);
				row.append(thumb, info, stepper(line.product));
				page.appendChild(row);
			});

			const limits = catalog.limits || {};
			const used = slots();
			const meter = el('div', 'az-meter');
			const fill = el('i');
			fill.style.width = Math.min(100, Math.round(used / Math.max(1, limits.MaxSlots || 20) * 100)) + '%';
			meter.appendChild(fill);
			page.append(el('div', 'tb-muted', 'Espaço na caixa: ' + used + ' de ' + (limits.MaxSlots || 20)), meter);

			page.appendChild(el('div', 'tb-section', 'Entregar em'));
			const places = el('div', 'az-options');
			if (!addresses) {
				places.appendChild(el('p', 'tb-muted', 'Carregando endereços…'));
			} else if (addresses.length === 0) {
				places.appendChild(el('p', 'tb-empty', 'Você não tem imóvel para receber entregas. Alugue uma moradia ou trabalhe num negócio com imóvel comercial.'));
			} else {
				if (!addresses.some(function (a) { return addressKey(a) === cart.address; })) { cart.address = addressKey(addresses[0]); }
				addresses.forEach(function (a) {
					places.appendChild(option(addressKey(a) === cart.address, a.label, a.detail ? a.kind + ' · ' + a.detail : a.kind, null, function () {
						cart.address = addressKey(a);
						render();
					}));
				});
			}
			page.appendChild(places);

			page.appendChild(el('div', 'tb-section', 'Frete'));
			const shipping = shippingOption();
			const ships = el('div', 'az-options');
			(catalog.shipping || []).forEach(function (s) {
				ships.appendChild(option(shipping && s.id === shipping.id, s.label, 'Entrega em ~' + s.minutes + ' min', s.fee ? money(s.fee) : 'Grátis', function () {
					cart.shipping = s.id;
					render();
				}));
			});
			page.appendChild(ships);

			const subtotal = lines.reduce(function (sum, line) { return sum + line.product.price * line.qty; }, 0);
			const fee = shipping ? shipping.fee : 0;
			const total = subtotal + fee;
			const sum = el('div', 'coe-panel coe-panel--compact az-sum');
			const row = function (label, value, className) {
				const line = el('div', className);
				line.append(el('span', null, label), el('span', null, value));
				return line;
			};
			sum.append(row('Produtos', money(subtotal)), row('Frete', fee ? money(fee) : 'Grátis'), row('Total', money(total), 'az-total'));
			page.appendChild(sum);

			const actions = el('div', 'tb-actions');
			actions.append(
				button('Esvaziar', 'coe-button--danger', function () { cart.lines = {}; render(); }),
				button('Pagar ' + money(total), 'coe-button--primary', function () { checkout(lines, total); })
			);
			page.appendChild(actions);
		}

		function checkout(lines, total) {
			if (busy) { return; }
			const address = (addresses || []).find(function (a) { return addressKey(a) === cart.address; });
			if (!address) { api.status(errorText('invalid_address'), 'error'); return; }
			if (typeof api.pay !== 'function') { api.status(errorText('wallet_required'), 'error'); return; }
			const shipping = shippingOption();
			busy = true;
			api.pay({ amount: total, label: 'Compra Amzg', note: 'Entrega em ' + address.label + ' (' + shipping.label + ').' }).then(function (payment) {
				if (!payment) { busy = false; return; }
				call('checkout', {
					cart: lines.map(function (line) { return { id: line.product.id, qty: line.qty }; }),
					property: address.property, owner: address.owner, shipping: shipping.id, total: total, payment: payment.token
				}).then(function (result) {
					busy = false;
					if (!result.ok) {
						fail(result);
						if (result.error === 'price_changed' || result.error === 'product_unavailable') { loadCatalog(); }
						return;
					}
					cart.lines = {};
					api.status('Pedido #' + result.order + ' confirmado: ' + eta(result.deliverAt, result.now) + '.', 'ok');
					loadOrders();
				});
			});
		}

		function ordersView(page, data) {
			const list = data.orders || [];
			if (list.length === 0) { page.appendChild(el('p', 'tb-empty', 'Você ainda não fez pedidos.')); return; }
			list.forEach(function (order) {
				const card = el('div', 'coe-panel coe-panel--compact az-order');
				const head = el('div', 'az-order-head');
				const status = STATUS[order.status] || { label: order.status, badge: '' };
				head.append(el('strong', null, 'Pedido #' + order.id), el('span', 'coe-badge' + status.badge, status.label));
				card.appendChild(head);
				let note = order.address + ' · ' + order.shipping;
				if (order.status === 'pending') { note += ' · ' + eta(order.deliverAt, data.now); }
				if (order.status === 'delivered') { note += ' · retire a caixa no imóvel'; }
				if (order.status === 'refunded') { note += ' · valor devolvido ao cartão'; }
				card.appendChild(el('span', 'tb-muted', note));
				const items = el('ul');
				(order.items || []).forEach(function (item) { items.appendChild(el('li', null, item.qty + '× ' + item.label)); });
				card.appendChild(items);
				card.appendChild(el('div', 'az-price', money(order.total)));
				page.appendChild(card);
			});
		}

		let orders = null;

		function render() {
			root.replaceChildren();
			const page = el('div', 'az-page');
			header().forEach(function (node) { page.appendChild(node); });
			if (!catalog) {
				page.appendChild(el('p', 'tb-muted', 'Carregando…'));
			} else if (tab === 'shop') {
				shop(page);
			} else if (tab === 'cart') {
				cartView(page);
			} else if (orders) {
				const refresh = el('div', 'tb-actions');
				refresh.appendChild(button('Atualizar', '', loadOrders));
				page.appendChild(refresh);
				ordersView(page, orders);
			} else {
				page.appendChild(el('p', 'tb-muted', 'Carregando pedidos…'));
			}
			root.appendChild(page);
		}

		function loadCatalog() {
			call('catalog').then(function (result) {
				if (!result.ok) { fail(result); return; }
				catalog = result;
				reloading = false;
				if (result.now) { clockOffset = Number(result.now) - Date.now() / 1000; }
				render();
				startTicker();
			});
		}

		function loadAddresses() {
			call('addresses').then(function (result) {
				if (!result.ok) { fail(result); return; }
				addresses = result.addresses || [];
				render();
			});
		}

		function loadOrders() {
			tab = 'orders';
			orders = null;
			render();
			call('orders').then(function (result) {
				if (!result.ok) { fail(result); return; }
				orders = result;
				render();
			});
		}

		render();
		loadCatalog();
		loadAddresses();
	});
})();
