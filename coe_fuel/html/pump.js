// Bomba de combustível (coe_fuel): frente de bomba na cor da bandeira, visor com total, litros e preço por litro,
// botões de produto e pagamento (espécie, Carteira do celular ou cartão na maquininha). O servidor decide
// compatibilidade, estoque, preço e cobrança. Durante o abastecimento, um mostrador conta os litros.
(function () {
	'use strict';

	const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'coe_fuel';
	const ERRORS = {
		too_far: 'Fique perto da bomba.', station_closed: 'Posto fechado.', unknown_fuel: 'Escolha o combustível.',
		invalid_liters: 'Quantidade inválida.', no_vehicle: 'Nenhum veículo perto da bomba.', no_tank: 'Este veículo não usa combustível.',
		wrong_fuel: 'Combustível errado para este motor.', tank_full: 'O tanque já está cheio.', no_inventory: 'Inventário indisponível.',
		no_can: 'Galão não encontrado.', can_other_fuel: 'O galão tem outro combustível. Esvazie antes.', can_full: 'O galão já está cheio.',
		out_of_stock: 'O posto não tem esse combustível no tanque.', invalid_method: 'Escolha como pagar.', insufficient_cash: 'Você não tem dinheiro suficiente.',
		payment_failed: 'O pagamento não passou.', payment_expired: 'O pagamento expirou. Tente de novo.', cancelled: 'Pagamento cancelado.',
		phone_unavailable: 'Celular indisponível. Use dinheiro ou cartão.', inventory_full: 'Sem espaço para o galão. O valor foi devolvido.',
		no_card: 'Cartão não encontrado.', card_blocked: 'Cartão bloqueado.', card_expired: 'Cartão vencido.', no_credit: 'Esse cartão não tem crédito liberado.',
		credit_late: 'Cartão bloqueado por fatura em atraso.', credit_limit: 'Limite do cartão insuficiente.', card_not_in_hand: 'O cartão precisa estar com você.',
		wrong_pin: 'Senha incorreta.', invalid_pin: 'Digite os 4 dígitos da senha.', busy: 'Aguarde um instante.', not_ready: 'Posto ainda abrindo.',
		internal_error: 'Erro na bomba. Tente de novo.', timeout: 'Sem resposta do posto.', closed: 'Bomba fechada.'
	};

	const els = {
		overlay: document.getElementById('pump'),
		brand: document.getElementById('fp-brand'),
		station: document.getElementById('fp-station'),
		mode: document.getElementById('fp-mode'),
		body: document.getElementById('fp-body'),
		status: document.getElementById('fp-status'),
		close: document.getElementById('fp-close'),
		meter: document.getElementById('meter')
	};

	let view = null;
	let target = 'vehicle';
	let canSlot = null;    // null = galão novo
	let fuelId = null;
	let liters = 0;
	let method = null;
	let cardId = null;
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
	function number(value, digits) { return Number(value || 0).toLocaleString('pt-BR', { minimumFractionDigits: digits, maximumFractionDigits: digits }); }
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
		els.status.className = 'fp-status' + (kind ? ' is-' + kind : '');
	}
	function errorText(result) {
		const code = result && result.error;
		let text = ERRORS[code] || 'Não foi possível concluir.';
		if (code === 'wrong_pin' && result.left !== undefined && result.left !== null) { text += ' Restam ' + result.left + ' tentativas.'; }
		return text;
	}
	function applyTheme(node, theme) {
		const t = theme || {};
		node.style.setProperty('--brand', t.primary || '#4a5360');
		node.style.setProperty('--brand-accent', t.accent || '#c9ced6');
		node.style.setProperty('--brand-text', t.text || '#ffffff');
	}

	function fuelById(id) { return view.fuels.find(function (f) { return f.id === id; }); }
	function canBySlot(slot) { return view.cans.find(function (c) { return c.slot === slot; }); }

	// Por que um produto não pode ser escolhido agora (ou null).
	function fuelBlock(fuel) {
		if (target === 'vehicle') {
			if (!view.vehicle) { return 'Sem veículo'; }
			if (view.vehicle.engine !== fuel.engine) { return view.vehicle.engine === 'none' ? 'Sem tanque' : (fuel.engine === 'diesel' ? 'Motor flex' : 'Motor diesel'); }
		} else if (canSlot !== null) {
			const can = canBySlot(canSlot);
			if (can && can.liters > 0 && can.fuel !== fuel.id) { return 'Galão com outro'; }
		}
		if (fuel.stock !== undefined && fuel.stock !== null && fuel.stock < 0.5) { return 'Sem estoque'; }
		return null;
	}

	function maxLiters() {
		let max = view.maxLiters;
		if (target === 'vehicle') {
			max = view.vehicle ? Math.floor(view.vehicle.space * 10) / 10 : 0;
		} else if (canSlot !== null) {
			const can = canBySlot(canSlot);
			max = can ? Math.floor((view.can.capacity - can.liters) * 10) / 10 : 0;
		} else {
			max = view.can.capacity;
		}
		const fuel = fuelId && fuelById(fuelId);
		if (fuel && fuel.stock !== undefined && fuel.stock !== null) { max = Math.min(max, Math.floor(fuel.stock * 10) / 10); }
		return Math.max(0, Math.min(max, view.maxLiters));
	}

	function canPrice() { return target === 'can' && canSlot === null ? view.can.price : 0; }

	function total() {
		const fuel = fuelId && fuelById(fuelId);
		if (!fuel || liters < 0.5) { return 0; }
		return Math.ceil(fuel.price * liters - 1e-9) + canPrice();
	}

	function fixSelection() {
		const fuel = fuelId && fuelById(fuelId);
		if (!fuel || fuelBlock(fuel)) {
			const first = view.fuels.find(function (f) { return !fuelBlock(f); });
			fuelId = first ? first.id : null;
		}
		const max = maxLiters();
		if (liters > max || liters <= 0) { liters = max; }
		if (!method) { method = view.payments.cash ? 'cash' : (view.payments.wallet ? 'wallet' : 'card'); }
		if (method === 'card' && !cardId && view.cards.length) { cardId = view.cards[0].id; }
	}

	function setLiters(value) {
		liters = Math.max(0, Math.min(maxLiters(), Math.round(value * 10) / 10));
		render();
	}

	function display() {
		const fuel = fuelId && fuelById(fuelId);
		const lcd = el('div', 'fp-lcd');
		[['TOTAL $', number(total(), 2), ''], ['LITROS', number(liters, 2), 'fp-lcd-row--main'], ['PREÇO/L', fuel ? number(fuel.price, 2) : '-,--', 'fp-lcd-row--small']].forEach(function (row) {
			const line = el('div', 'fp-lcd-row ' + row[2]);
			line.append(el('span', null, row[0]), el('b', null, row[1]));
			lcd.appendChild(line);
		});
		return lcd;
	}

	function targets() {
		const wrap = el('div', 'fp-targets');
		const vehicle = view.vehicle;
		const car = button('', 'fp-target' + (target === 'vehicle' ? ' is-active' : ''), function () { target = 'vehicle'; liters = 0; render(); });
		car.disabled = !vehicle || vehicle.engine === 'none';
		car.appendChild(el('strong', null, 'Veículo'));
		if (vehicle) {
			car.appendChild(el('small', null, number(vehicle.liters, 1) + ' / ' + vehicle.capacity + ' L'));
			const gauge = el('div', 'fp-gauge');
			const fill = el('i');
			fill.style.width = Math.round(Math.min(1, vehicle.liters / Math.max(1, vehicle.capacity)) * 100) + '%';
			gauge.appendChild(fill);
			car.appendChild(gauge);
		} else {
			car.appendChild(el('small', null, 'Estacione perto da bomba'));
		}
		wrap.appendChild(car);
		view.cans.forEach(function (can) {
			const fuel = can.fuel && fuelById(can.fuel);
			const node = button('', 'fp-target' + (target === 'can' && canSlot === can.slot ? ' is-active' : ''), function () { target = 'can'; canSlot = can.slot; liters = 0; render(); });
			node.append(el('strong', null, 'Seu galão'), el('small', null, can.liters > 0 && fuel ? fuel.short + ' · ' + number(can.liters, 1) + ' / ' + view.can.capacity + ' L' : 'Vazio'));
			node.disabled = can.liters >= view.can.capacity;
			wrap.appendChild(node);
		});
		const fresh = button('', 'fp-target' + (target === 'can' && canSlot === null ? ' is-active' : ''), function () { target = 'can'; canSlot = null; liters = 0; render(); });
		fresh.append(el('strong', null, 'Galão novo'), el('small', null, view.can.capacity + ' L · ' + money(view.can.price)));
		wrap.appendChild(fresh);
		return wrap;
	}

	function grades() {
		const wrap = el('div', 'fp-grades');
		view.fuels.forEach(function (fuel) {
			const block = fuelBlock(fuel);
			const node = button('', 'fp-grade' + (fuelId === fuel.id ? ' is-active' : ''), function () { fuelId = fuel.id; liters = 0; render(); });
			node.style.setProperty('--fuel', fuel.color || '#888');
			node.disabled = Boolean(block);
			const price = el('div', 'fp-lcd');
			const row = el('div', 'fp-lcd-row');
			row.append(el('span', null, '$/L'), el('b', null, number(fuel.price, 2)));
			price.appendChild(row);
			node.append(el('span', 'fp-grade-name', fuel.label), price,
				el('small', null, block || (fuel.stock !== undefined && fuel.stock !== null ? number(fuel.stock, 0) + ' L no posto' : '')));
			wrap.appendChild(node);
		});
		return wrap;
	}

	function litersBox() {
		const box = el('div', 'fp-box');
		const max = maxLiters();
		const stepper = el('div', 'fp-stepper');
		const out = el('output', null, number(liters, 1) + ' L');
		stepper.append(button('−', null, function () { setLiters(liters - 1); }), out, button('+', null, function () { setLiters(liters + 1); }));
		const presets = el('div', 'fp-presets');
		[10, 20, 50].forEach(function (amount) {
			presets.appendChild(button(amount + ' L', null, function () { setLiters(Math.min(amount, max)); }));
		});
		presets.appendChild(button('Encher', null, function () { setLiters(max); }));
		box.append(el('p', 'fp-label', 'Litros'), stepper, presets);
		if (canPrice() > 0) { box.appendChild(el('p', 'fp-label', 'Inclui o galão (' + money(canPrice()) + ')')); }
		return box;
	}

	function paymentBox() {
		const box = el('div', 'fp-box');
		const wrap = el('div', 'fp-methods');
		[
			['cash', 'Dinheiro', money(view.cash), view.payments.cash],
			['wallet', 'Carteira', 'Celular', view.payments.wallet],
			['card', 'Cartão', view.cards.length ? 'Maquininha' : 'Sem cartão', view.payments.card && view.cards.length > 0]
		].forEach(function (option) {
			if (!view.payments[option[0]]) { return; }
			const node = button('', 'fp-method' + (method === option[0] ? ' is-active' : ''), function () { method = option[0]; render(); });
			node.disabled = !option[3];
			node.append(el('strong', null, option[1]), el('small', null, option[2]));
			wrap.appendChild(node);
		});
		box.append(el('p', 'fp-label', 'Pagamento'), wrap);
		if (method === 'card' && view.cards.length) {
			const cards = el('div', 'fp-cards');
			view.cards.forEach(function (card) {
				cards.appendChild(button('•••• ' + card.last4 + (card.business ? ' · ' + card.business : ''), 'fp-card' + (cardId === card.id ? ' is-active' : ''), function () { cardId = card.id; render(); }));
			});
			box.appendChild(cards);
		}
		return box;
	}

	function render() {
		if (!view) { return; }
		fixSelection();
		els.body.replaceChildren();
		const controls = el('div', 'fp-controls');
		controls.append(litersBox(), paymentBox());
		const start = button(busy ? 'Processando…' : 'Abastecer', 'fp-start', submit);
		start.disabled = busy || !fuelId || liters < 0.5 || !method || (method === 'card' && !cardId);
		els.body.append(display(), targets(), grades(), controls, start);
	}

	function finish(result) {
		busy = false;
		if (result && result.ok) { status(''); return; }
		status(errorText(result), 'error');
		render();
	}

	function payload(extra) {
		return Object.assign({ fuel: fuelId, liters: liters, target: target, slot: target === 'can' ? canSlot : null, method: method }, extra || {});
	}

	function submit() {
		if (busy || !fuelId || !method) { return; }
		if (method === 'card') { askPin(); return; }
		busy = true;
		status(method === 'wallet' ? 'Confirme o pagamento no celular…' : 'Processando…');
		render();
		post('buy', payload()).then(finish);
	}

	function askPin() {
		const card = view.cards.find(function (c) { return c.id === cardId; });
		if (!card) { return; }
		let pin = '';
		const layer = el('div', 'fp-pin');
		applyTheme(layer, view.station.theme);
		const box = el('div', 'fp-pin-box');
		const dots = el('div', 'fp-pin-dots');
		const msg = el('p', 'fp-pin-msg');
		function paintDots() {
			dots.replaceChildren();
			for (let i = 0; i < 4; i += 1) { dots.appendChild(el('i', i < pin.length ? 'is-on' : null)); }
		}
		function close() { layer.remove(); document.removeEventListener('keydown', onKey, true); }
		function send() {
			if (pin.length !== 4) { msg.textContent = ERRORS.invalid_pin; return; }
			close();
			busy = true;
			status('Processando na maquininha…');
			render();
			post('buy', payload({ method: 'card', cardId: card.id, pin: pin })).then(finish);
		}
		function press(key) {
			if (key === 'back') { pin = pin.slice(0, -1); } else if (key === 'ok') { send(); return; } else if (pin.length < 4) { pin += key; }
			msg.textContent = '';
			paintDots();
			if (pin.length === 4) { setTimeout(send, 150); }
		}
		function onKey(event) {
			if (/^\d$/.test(event.key)) { press(event.key); } else if (event.key === 'Backspace') { press('back'); } else if (event.key === 'Enter') { press('ok'); } else if (event.key === 'Escape') { close(); } else { return; }
			event.preventDefault();
			event.stopPropagation();
		}
		document.addEventListener('keydown', onKey, true);
		const keys = el('div', 'fp-keys');
		['1', '2', '3', '4', '5', '6', '7', '8', '9', 'back', '0', 'ok'].forEach(function (key) {
			keys.appendChild(button(key === 'back' ? '⌫' : key === 'ok' ? 'OK' : key, null, function () { press(key); }));
		});
		box.append(el('h3', null, 'Senha do cartão •••• ' + card.last4), el('small', null, 'Total: ' + money(total())), dots, msg, keys,
			button('Cancelar', 'fp-pin-cancel', close));
		paintDots();
		layer.appendChild(box);
		document.body.appendChild(layer);
	}

	function open(data) {
		view = data;
		target = view.vehicle && view.vehicle.engine !== 'none' && view.vehicle.space >= 0.5 ? 'vehicle' : 'can';
		canSlot = null;
		fuelId = null;
		liters = 0;
		method = null;
		cardId = null;
		busy = false;
		applyTheme(document.documentElement, view.station.theme);
		els.brand.textContent = view.station.brand === 'none' ? 'Posto' : view.station.brandLabel;
		els.station.textContent = view.station.label;
		els.mode.textContent = view.mode === 'staff' ? 'Abastecimento automático' : 'Posto de ' + (view.owner || 'jogador');
		status('');
		render();
		els.overlay.classList.remove('is-hidden', 'is-suspended');
		els.overlay.setAttribute('aria-hidden', 'false');
	}

	function hide() {
		els.overlay.classList.add('is-hidden');
		els.overlay.setAttribute('aria-hidden', 'true');
		view = null;
		const pin = document.querySelector('.fp-pin');
		if (pin) { pin.remove(); }
	}

	// Mostrador: conta litros e total do zero até o valor final no tempo do abastecimento.
	let meterFrame = null;
	function meterStart(data) {
		const meter = els.meter;
		applyTheme(meter, data.theme);
		meter.style.setProperty('--fuel', data.color || '');
		document.getElementById('mt-brand').textContent = data.brand === 'none' ? 'Posto' : (data.brandLabel || '');
		document.getElementById('mt-title').textContent = data.title || 'Abastecendo';
		document.getElementById('mt-fuel').textContent = data.fuel || '';
		const hasPrice = typeof data.price === 'number';
		document.getElementById('mt-total-row').classList.toggle('is-hidden-row', !hasPrice);
		document.getElementById('mt-price-row').classList.toggle('is-hidden-row', !hasPrice);
		document.getElementById('mt-price').textContent = hasPrice ? number(data.price, 2) : '';
		const litersEl = document.getElementById('mt-liters');
		const totalEl = document.getElementById('mt-total');
		const bar = document.getElementById('mt-bar');
		const duration = Math.max(1, Number(data.seconds) || 1) * 1000;
		const goal = Number(data.liters) || 0;
		const finalTotal = Number(data.total) || 0;
		const started = performance.now();
		if (meterFrame) { cancelAnimationFrame(meterFrame); }
		meter.classList.remove('is-hidden');
		function step(now) {
			const progress = Math.min(1, (now - started) / duration);
			const current = goal * progress;
			litersEl.textContent = number(current, 2);
			// O total da bomba acompanha os litros; no fim mostra o cobrado (arredondado).
			totalEl.textContent = number(progress >= 1 ? finalTotal : (hasPrice ? data.price * current : 0), 2);
			bar.style.width = (progress * 100).toFixed(1) + '%';
			meterFrame = progress < 1 ? requestAnimationFrame(step) : null;
		}
		meterFrame = requestAnimationFrame(step);
	}
	function meterEnd() {
		if (meterFrame) { cancelAnimationFrame(meterFrame); meterFrame = null; }
		els.meter.classList.add('is-hidden');
	}

	els.close.addEventListener('click', function () { post('close'); });
	window.addEventListener('keydown', function (event) {
		if (event.key === 'Escape' && view && !document.querySelector('.fp-pin')) { post('close'); }
	});
	window.addEventListener('message', function (event) {
		const data = event.data || {};
		if (data.action === 'open') { open(data.view); }
		if (data.action === 'close') { hide(); }
		if (data.action === 'suspend') { els.overlay.classList.toggle('is-suspended', data.value === true); }
		if (data.action === 'meter') { meterStart(data.data || {}); }
		if (data.action === 'meterEnd') { meterEnd(); }
	});
})();
