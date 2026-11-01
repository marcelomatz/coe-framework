// Refinaria (coe_fuel): carga do veículo da frota do posto. Escolhe os litros de cada combustível, vê o custo no
// atacado (pago pelo caixa do posto) e a capacidade do veículo. O servidor confere permissão, capacidade e saldo.
(function () {
	'use strict';

	const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'coe_fuel';
	const ERRORS = {
		over_capacity: 'A carga passa da capacidade do veículo.', empty_load: 'Escolha quanto carregar.', invalid_load: 'Quantidade inválida.',
		insufficient_funds: 'O caixa do posto não tem saldo para essa carga.', economy_unavailable: 'Economia indisponível.',
		not_at_refinery: 'Leve o veículo até a refinaria.', no_vehicle: 'Fique perto do veículo da frota.', not_fleet: 'Este veículo não é da frota de um posto.',
		forbidden: 'Seu cargo não faz carregamentos deste posto.', busy: 'Aguarde um instante.', internal_error: 'Erro na refinaria. Tente de novo.',
		timeout: 'Sem resposta da refinaria.', closed: 'Refinaria fechada.'
	};

	const els = {
		overlay: document.getElementById('refinery'),
		title: document.getElementById('rf-title'),
		sub: document.getElementById('rf-sub'),
		body: document.getElementById('rf-body'),
		status: document.getElementById('rf-status'),
		close: document.getElementById('rf-close')
	};

	let view = null;
	let order = {};
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
	function money(value) { return '$ ' + Math.ceil(value || 0).toLocaleString('pt-BR'); }
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

	function ordered() { return view.fuels.reduce(function (sum, fuel) { return sum + (order[fuel.id] || 0); }, 0); }
	function cost() { return Math.ceil(view.fuels.reduce(function (sum, fuel) { return sum + (order[fuel.id] || 0) * fuel.wholesale; }, 0) - 1e-9); }
	function free() { return Math.max(0, Math.floor(view.vehicle.capacity - view.vehicle.liters - ordered())); }

	function setAmount(id, value) {
		const others = ordered() - (order[id] || 0);
		const max = Math.max(0, Math.floor(view.vehicle.capacity - view.vehicle.liters - others));
		order[id] = Math.max(0, Math.min(max, Math.floor(Number(value) || 0)));
		render();
	}

	function truck() {
		const box = el('div', 'rf-truck');
		const head = el('div', 'rf-truck-head');
		head.append(el('strong', null, view.vehicle.label), el('span', null, number(view.vehicle.liters + ordered(), 0) + ' / ' + number(view.vehicle.capacity, 0) + ' L'));
		const bar = el('div', 'rf-bar');
		view.fuels.forEach(function (fuel) {
			const loaded = view.vehicle.cargo[fuel.id] || 0;
			if (loaded > 0) {
				const part = el('i');
				part.style.width = (loaded / view.vehicle.capacity * 100) + '%';
				part.style.background = fuel.color;
				bar.appendChild(part);
			}
		});
		view.fuels.forEach(function (fuel) {
			const adding = order[fuel.id] || 0;
			if (adding > 0) {
				const part = el('i', 'is-new');
				part.style.width = (adding / view.vehicle.capacity * 100) + '%';
				part.style.backgroundColor = fuel.color;
				bar.appendChild(part);
			}
		});
		box.append(head, bar);
		return box;
	}

	function rows() {
		const wrap = el('div', 'rf-rows');
		view.fuels.forEach(function (fuel) {
			const row = el('div', 'rf-row');
			row.style.setProperty('--fuel', fuel.color);
			const name = el('div', 'rf-name');
			name.append(el('strong', null, fuel.label),
				el('small', null, 'No posto: ' + number(fuel.tank, 0) + ' / ' + number(fuel.tankCapacity, 0) + ' L' + ((view.vehicle.cargo[fuel.id] || 0) > 0 ? ' · na carga: ' + number(view.vehicle.cargo[fuel.id], 0) + ' L' : '')));
			const qty = el('div', 'rf-qty');
			const input = el('input');
			input.type = 'number';
			input.min = '0';
			input.step = '50';
			input.value = String(order[fuel.id] || 0);
			input.addEventListener('change', function () { setAmount(fuel.id, input.value); });
			qty.append(button('−', null, function () { setAmount(fuel.id, (order[fuel.id] || 0) - 100); }), input,
				button('+', null, function () { setAmount(fuel.id, (order[fuel.id] || 0) + 100); }));
			row.append(el('span', 'rf-swatch'), name, el('span', 'rf-price', '$ ' + number(fuel.wholesale, 2) + '/L'), qty);
			wrap.appendChild(row);
		});
		return wrap;
	}

	function summary() {
		const wrap = el('div', 'rf-summary');
		const balance = view.business.balance;
		const total = cost();
		[['Carga', number(ordered(), 0) + ' L', false], ['Custo (atacado)', money(total), false],
			['Caixa do posto', typeof balance === 'number' ? money(balance) : '—', typeof balance === 'number' && balance < total]].forEach(function (item) {
			const kpi = el('div', 'rf-kpi' + (item[2] ? ' is-warn' : ''));
			kpi.append(el('small', null, item[0]), el('strong', null, item[1]));
			wrap.appendChild(kpi);
		});
		return wrap;
	}

	function render() {
		if (!view) { return; }
		els.body.replaceChildren();
		const fill = button('Completar com o combustível que mais falta no posto', 'rf-fill', function () {
			let best = null;
			view.fuels.forEach(function (fuel) {
				const missing = fuel.tankCapacity - fuel.tank - (view.vehicle.cargo[fuel.id] || 0);
				if (!best || missing > best.missing) { best = { id: fuel.id, missing: missing }; }
			});
			if (best) { setAmount(best.id, (order[best.id] || 0) + Math.min(free(), Math.max(0, Math.floor(best.missing)))); }
		});
		const start = button(busy ? 'Carregando…' : 'Carregar', 'rf-start', submit);
		start.disabled = busy || ordered() <= 0;
		els.body.append(truck(), rows(), fill, summary(), start);
	}

	function submit() {
		if (busy || ordered() <= 0) { return; }
		busy = true;
		status('Processando…');
		render();
		const load = {};
		view.fuels.forEach(function (fuel) { if (order[fuel.id] > 0) { load[fuel.id] = order[fuel.id]; } });
		post('load', { load: load }).then(function (result) {
			busy = false;
			if (result && result.ok) { status(''); return; }
			status(ERRORS[result && result.error] || 'Não foi possível carregar.', 'error');
			render();
		});
	}

	function open(data) {
		view = data;
		order = {};
		busy = false;
		els.title.textContent = view.refinery;
		els.sub.textContent = view.business.label + ' · ' + view.vehicle.label;
		status('');
		render();
		els.overlay.classList.remove('is-hidden');
		els.overlay.setAttribute('aria-hidden', 'false');
	}

	function hide() {
		els.overlay.classList.add('is-hidden');
		els.overlay.setAttribute('aria-hidden', 'true');
		view = null;
	}

	els.close.addEventListener('click', function () { post('refineryClose'); });
	window.addEventListener('keydown', function (event) {
		if (event.key === 'Escape' && view) { post('refineryClose'); }
	});
	window.addEventListener('message', function (event) {
		const data = event.data || {};
		if (data.action === 'refinery') { open(data.view); }
		if (data.action === 'refineryClose') { hide(); }
	});
})();
