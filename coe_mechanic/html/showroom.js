(function () {
	'use strict';

	const Labels = window.CoeMechanicLabels;
	const ERRORS = {
		not_ready: 'Serviço ainda iniciando.', invalid_request: 'Pedido inválido.', vehicle_not_found: 'Veículo não registrado.',
		no_key: 'Você precisa ter a chave deste veículo.', not_in_showroom: 'Fique com o veículo dentro da área.',
		order_already_open: 'Este veículo já tem um pedido aberto.', shop_busy: 'A oficina está lotada, tente mais tarde.',
		nothing_to_change: 'Escolha ao menos uma modificação.', invalid_status: 'Esse pedido mudou de estado.',
		order_not_found: 'Pedido não encontrado.', invalid_appearance: 'Modificação inválida.', invalid_mod: 'Modificação inválida.',
		rate_limited: 'Calma, muitas ações seguidas.'
	};
	const PRESETS = [
		['front', 'Frente'], ['side', 'Lateral'], ['rear', 'Traseira'], ['top', 'Topo'], ['wheels', 'Rodas'], ['engine', 'Motor'], ['cabin', 'Cabine'], ['interior', 'Interior']
	];
	const PALETTE = [
		['Preto', '#0d0f11'], ['Grafite', '#2a2d31'], ['Chumbo', '#4a4f55'], ['Prata', '#a7adb3'], ['Branco', '#f1f1ee'],
		['Vermelho', '#c8151b'], ['Bordô', '#5a1119'], ['Laranja', '#e8741a'], ['Amarelo', '#f1c40f'], ['Verde', '#2e8b3d'],
		['Verde escuro', '#17372a'], ['Oliva', '#5b6b3a'], ['Azul', '#1f4fa8'], ['Azul claro', '#4aa3df'], ['Marinho', '#0e1f3d'],
		['Roxo', '#6a3aa3'], ['Rosa', '#e0679f'], ['Marrom', '#5c3b22'], ['Bege', '#c9b79c'], ['Dourado', '#b8923a']
	];
	const WHEEL_TYPES = [
		[0, 'Sport'], [1, 'Muscle'], [2, 'Lowrider'], [3, 'SUV'], [4, 'Off-road'], [5, 'Tuner'], [7, 'High-end'],
		[8, 'Benny\'s Original'], [9, 'Benny\'s Bespoke'], [10, 'Fórmula'], [11, 'Street'], [12, 'Pista']
	];
	const TINTS = [[0, 'Nenhuma'], [1, 'Preto total'], [2, 'Fumê escuro'], [3, 'Fumê claro'], [4, 'De fábrica'], [5, 'Limousine'], [6, 'Verde']];
	const NEON_SIDES = ['Esquerda', 'Direita', 'Frente', 'Traseira'];

	const els = {
		root: document.getElementById('showroom'), stage: document.getElementById('sr-stage'), shop: document.getElementById('sr-shop'),
		vehicle: document.getElementById('sr-vehicle'), tabs: document.getElementById('sr-tabs'), options: document.getElementById('sr-options'),
		lines: document.getElementById('sr-lines'), total: document.getElementById('sr-total'), order: document.getElementById('sr-order'),
		status: document.getElementById('sr-status'), request: document.getElementById('sr-request'), reset: document.getElementById('sr-reset'),
		close: document.getElementById('sr-close'), presets: document.getElementById('sr-presets'), auto: document.getElementById('sr-auto'),
		free: document.getElementById('sr-free')
	};

	let ctx = null;
	let patch = {};
	let order = null;
	let tab = 'colors';
	let previewTimer = null;
	let estimateTimer = null;
	let autoOn = false;

	function post(name, body) {
		return fetch('https://' + GetParentResourceName() + '/' + name, {
			method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(body || {})
		}).then(function (response) { return response.json(); }).catch(function () { return {}; });
	}

	function el(tag, className, text) {
		const node = document.createElement(tag);
		if (className) { node.className = className; }
		if (text !== undefined) { node.textContent = text; }
		return node;
	}

	function money(value) { return '$ ' + Number(value || 0).toLocaleString('pt-BR'); }
	function setStatus(message, error) { els.status.textContent = message || ''; els.status.className = 'sr-status' + (error ? ' is-error' : ''); }
	function isEmpty(object) { return !object || Object.keys(object).length === 0; }
	function same(a, b) { return JSON.stringify(a) === JSON.stringify(b); }
	function hexToRgb(hex) { return [parseInt(hex.slice(1, 3), 16), parseInt(hex.slice(3, 5), 16), parseInt(hex.slice(5, 7), 16)]; }
	function rgbToHex(rgb) { return '#' + rgb.map(function (v) { return ('0' + Math.max(0, Math.min(255, v | 0)).toString(16)).slice(-2); }).join(''); }

	function base() { return (ctx && ctx.current) || {}; }
	function currentMod(key) { const value = (base().mods || {})[key]; return value === undefined ? -1 : value; }
	function currentOf(group, key) { return (base()[group] || {})[key]; }
	function valueOf(group, key) { const own = patch[group] || {}; return own[key] !== undefined ? own[key] : currentOf(group, key); }

	function setIn(group, key, value) {
		patch[group] = patch[group] || {};
		patch[group][key] = value;
		refresh();
	}

	// Remove do pedido o que é igual ao estado atual do veículo.
	function changed() {
		const current = base();
		const out = {};
		['mods', 'colors', 'toggles', 'extras'].forEach(function (group) {
			Object.keys(patch[group] || {}).forEach(function (key) {
				const before = group === 'mods' ? currentMod(key) : (current[group] || {})[key];
				if (!same(patch[group][key], before)) {
					out[group] = out[group] || {};
					out[group][key] = patch[group][key];
				}
			});
		});
		['livery', 'tint', 'wheelType'].forEach(function (key) {
			if (patch[key] !== undefined && patch[key] !== current[key]) { out[key] = patch[key]; }
		});
		if (patch.neon && !same(patch.neon, current.neon)) { out.neon = patch.neon; }
		return out;
	}

	function categoriesChanged(out) {
		const found = {};
		Object.keys(out.mods || {}).forEach(function (key) { found[Labels.categoryOf(Number(key))] = true; });
		if (out.colors) { found.colors = true; }
		if (out.toggles) {
			if (out.toggles.turbo !== undefined) { found.performance = true; }
			if (out.toggles.tyreSmoke !== undefined) { found.wheels = true; }
			if (out.toggles.xenon !== undefined) { found.lights = true; }
		}
		if (out.wheelType !== undefined) { found.wheels = true; }
		if (out.tint !== undefined || out.neon) { found.lights = true; }
		if (out.livery !== undefined || out.extras) { found.livery = true; }
		return found;
	}

	function refresh() {
		const out = changed();
		els.request.disabled = isEmpty(out) || !!(order && order.status !== 'done');
		renderTabs(out);
		clearTimeout(previewTimer);
		previewTimer = setTimeout(function () {
			post('resetPreview').then(function () { return post('preview', { patch: out }); }).then(function (result) {
				const count = result && result.wheels;
				if (count !== undefined && ctx && ctx.options.mods && count !== ctx.options.mods['23'] && count > 0) {
					ctx.options.mods['23'] = count;
					if (tab === 'wheels') { buildOptions(); }
				}
			});
		}, 50);
		clearTimeout(estimateTimer);
		if (isEmpty(out)) { renderEstimate(null); return; }
		estimateTimer = setTimeout(function () { post('estimate', { patch: out }); }, 300);
	}

	function renderEstimate(quote) {
		els.lines.replaceChildren();
		els.total.textContent = '';
		if (!quote) { return; }
		quote.lines.forEach(function (line) {
			const row = el('div', 'sr-line');
			row.appendChild(el('span', '', Labels.lineLabel(line)));
			row.appendChild(el('span', '', money(line.price)));
			els.lines.appendChild(row);
		});
		els.total.textContent = money(quote.total);
	}

	function renderTabs(out) {
		const marks = categoriesChanged(out || changed());
		els.tabs.replaceChildren();
		Labels.CATEGORIES.forEach(function (category) {
			const button = el('button', 'sr-tab' + (tab === category.id ? ' is-active' : ''), category.label);
			button.type = 'button';
			if (marks[category.id]) { button.appendChild(el('span', 'sr-dot')); }
			button.addEventListener('click', function () { tab = category.id; renderTabs(); buildOptions(); els.options.scrollTop = 0; });
			els.tabs.appendChild(button);
		});
	}

	function item(name, changedFlag) {
		const box = el('div', 'sr-item' + (changedFlag ? ' is-changed' : ''));
		const head = el('div', 'sr-item-head');
		head.appendChild(el('span', 'sr-item-name', name));
		box.appendChild(head);
		return { box: box, head: head };
	}

	function stepper(name, count, current, onChange, zeroLabel) {
		let value = current;
		const parts = item(name, false);
		const text = el('span', 'sr-item-value');
		const slider = document.createElement('input');
		slider.type = 'range'; slider.className = 'sr-slider'; slider.min = '-1'; slider.max = String(count - 1); slider.step = '1';
		const prev = el('button', 'sr-step', '‹'); prev.type = 'button';
		const next = el('button', 'sr-step', '›'); next.type = 'button';

		function show() {
			slider.value = String(value);
			text.textContent = value < 0 ? (zeroLabel || 'Original') : ('Opção ' + (value + 1) + ' de ' + count);
			parts.box.classList.toggle('is-changed', value !== current);
		}
		function set(next) {
			value = Math.max(-1, Math.min(count - 1, next));
			show();
			onChange(value);
		}
		prev.addEventListener('click', function () { set(value - 1); });
		next.addEventListener('click', function () { set(value + 1); });
		slider.addEventListener('input', function () { set(Number(slider.value)); });
		parts.head.appendChild(text);
		const row = el('div', 'sr-stepper');
		row.appendChild(prev); row.appendChild(slider); row.appendChild(next);
		parts.box.appendChild(row);
		show();
		return parts.box;
	}

	function toggle(name, value, onChange) {
		const row = el('div', 'sr-toggle' + (value ? ' is-on' : ''));
		row.setAttribute('role', 'switch');
		row.setAttribute('aria-checked', String(!!value));
		row.tabIndex = 0;
		row.appendChild(el('span', '', name));
		row.appendChild(el('span', 'sr-switch'));
		function flip() {
			value = !value;
			row.classList.toggle('is-on', value);
			row.setAttribute('aria-checked', String(value));
			onChange(value);
		}
		row.addEventListener('click', flip);
		row.addEventListener('keydown', function (event) { if (event.key === ' ' || event.key === 'Enter') { event.preventDefault(); flip(); } });
		return row;
	}

	function chips(values, current, onChange) {
		const wrap = el('div', 'sr-chips');
		values.forEach(function (entry) {
			const chip = el('button', 'sr-chip' + (entry[0] === current ? ' is-active' : ''), entry[1]);
			chip.type = 'button';
			chip.addEventListener('click', function () {
				Array.prototype.forEach.call(wrap.children, function (node) { node.classList.remove('is-active'); });
				chip.classList.add('is-active');
				onChange(entry[0]);
			});
			wrap.appendChild(chip);
		});
		return wrap;
	}

	// Grade de cores nomeadas + seletor livre. `get` devolve o RGB atual; `set` recebe o novo.
	function colorPicker(name, get, set) {
		const parts = item(name, false);
		const grid = el('div', 'sr-swatches');
		const custom = document.createElement('input');
		custom.type = 'color';
		function mark() {
			const rgb = get();
			Array.prototype.forEach.call(grid.children, function (node) { node.classList.toggle('is-active', !!rgb && same(hexToRgb(node.dataset.hex), rgb)); });
			custom.value = rgb ? rgbToHex(rgb) : '#808080';
		}
		PALETTE.forEach(function (entry) {
			const swatch = el('button', 'sr-swatch');
			swatch.type = 'button'; swatch.title = entry[0]; swatch.dataset.hex = entry[1];
			swatch.style.background = entry[1];
			swatch.addEventListener('click', function () { set(hexToRgb(entry[1])); mark(); });
			grid.appendChild(swatch);
		});
		custom.addEventListener('change', function () { set(hexToRgb(custom.value)); mark(); });
		const row = el('div', 'sr-custom');
		row.appendChild(el('span', '', 'Personalizada'));
		row.appendChild(custom);
		parts.box.appendChild(grid);
		parts.box.appendChild(row);
		mark();
		return parts.box;
	}

	function modsOf(category) {
		return Object.keys((ctx.options || {}).mods || {}).map(Number).filter(function (type) {
			return Labels.categoryOf(type) === category && type !== 48;
		}).sort(function (a, b) { return a - b; });
	}

	function modControl(type) {
		const count = ctx.options.mods[String(type)];
		const key = String(type);
		const value = patch.mods && patch.mods[key] !== undefined ? patch.mods[key] : currentMod(key);
		return stepper(Labels.MOD_NAMES[type] || ('Modificação ' + type), count, value, function (next) {
			setIn('mods', key, next);
		});
	}

	function section(text) { return el('div', 'sr-section', text); }

	function toggleControl(name, key) {
		return toggle(name, valueOf('toggles', key) === true, function (on) { setIn('toggles', key, on); });
	}

	function buildColors(root) {
		root.appendChild(section('Pintura'));
		[['primaryRgb', 'Cor primária'], ['secondaryRgb', 'Cor secundária']].forEach(function (entry) {
			root.appendChild(colorPicker(entry[1], function () { return valueOf('colors', entry[0]) || null; }, function (rgb) { setIn('colors', entry[0], rgb); }));
		});
	}

	function buildCategory(root, category) {
		const mods = modsOf(category);
		if (mods.length === 0) { root.appendChild(el('p', 'sr-empty', 'Este veículo não oferece opções nesta categoria.')); return; }
		mods.forEach(function (type) { root.appendChild(modControl(type)); });
	}

	function buildPerformance(root) {
		root.appendChild(section('Peças'));
		buildCategory(root, 'performance');
		root.appendChild(section('Extras'));
		root.appendChild(toggleControl('Turbo', 'turbo'));
	}

	function buildWheels(root) {
		root.appendChild(section('Tipo de roda'));
		const typeItem = item('Estilo', false);
		typeItem.box.appendChild(chips(WHEEL_TYPES, valueOfScalar('wheelType'), function (type) { patch.wheelType = type; refresh(); }));
		root.appendChild(typeItem.box);
		root.appendChild(section('Modelo'));
		const wheels = modsOf('wheels');
		if (wheels.length === 0) { root.appendChild(el('p', 'sr-empty', 'Este veículo não oferece rodas alternativas.')); }
		wheels.forEach(function (type) { root.appendChild(modControl(type)); });
		root.appendChild(section('Extras'));
		root.appendChild(toggleControl('Fumaça dos pneus', 'tyreSmoke'));
	}

	function valueOfScalar(key) { return patch[key] !== undefined ? patch[key] : base()[key]; }

	function neonState() {
		const current = base().neon || { sides: [false, false, false, false], rgb: [255, 0, 255] };
		return patch.neon || { sides: (current.sides || [false, false, false, false]).slice(), rgb: (current.rgb || [255, 0, 255]).slice() };
	}

	function buildLights(root) {
		root.appendChild(section('Vidros'));
		const tint = item('Película', false);
		tint.box.appendChild(chips(TINTS, valueOfScalar('tint') || 0, function (value) { patch.tint = value; refresh(); }));
		root.appendChild(tint.box);
		root.appendChild(section('Faróis'));
		root.appendChild(toggleControl('Faróis xenon', 'xenon'));
		root.appendChild(section('Neon'));
		NEON_SIDES.forEach(function (name, index) {
			root.appendChild(toggle(name, neonState().sides[index] === true, function (on) {
				const state = neonState();
				state.sides[index] = on;
				patch.neon = state;
				refresh();
			}));
		});
		root.appendChild(colorPicker('Cor do neon', function () { return neonState().rgb; }, function (rgb) {
			const state = neonState();
			state.rgb = rgb;
			patch.neon = state;
			refresh();
		}));
	}

	function buildLivery(root) {
		const options = ctx.options || {};
		const count = Math.max(options.liveryCount || 0, options.liveryModCount || 0);
		root.appendChild(section('Livery'));
		if (count > 0) {
			const value = patch.livery !== undefined ? patch.livery : (base().livery === undefined ? -1 : base().livery);
			root.appendChild(stepper('Livery', count, value, function (next) { patch.livery = next; refresh(); }, 'Nenhuma'));
		} else {
			root.appendChild(el('p', 'sr-empty', 'Este modelo não tem livery.'));
		}
		root.appendChild(section('Extras do modelo'));
		const extras = options.extras || [];
		if (extras.length === 0) { root.appendChild(el('p', 'sr-empty', 'Este modelo não tem extras.')); }
		extras.forEach(function (id) {
			const key = String(id);
			const on = patch.extras && patch.extras[key] !== undefined ? patch.extras[key] : (base().extras || {})[key] === true;
			root.appendChild(toggle('Extra ' + id, on, function (value) { setIn('extras', key, value); }));
		});
	}

	function buildOptions() {
		els.options.replaceChildren();
		if (!ctx) { return; }
		const builders = {
			colors: buildColors,
			body: function (root) { buildCategory(root, 'body'); },
			performance: buildPerformance,
			wheels: buildWheels,
			interior: function (root) { buildCategory(root, 'interior'); },
			lights: buildLights,
			livery: buildLivery
		};
		builders[tab](els.options);
	}

	function renderOrder() {
		els.order.replaceChildren();
		if (!order) { els.request.disabled = isEmpty(changed()); return; }
		const names = { requested: 'Aguardando o mecânico', quoted: 'Orçamento recebido', approved: 'Aprovado, aguardando execução', done: 'Serviço concluído' };
		els.order.appendChild(el('strong', '', names[order.status] || order.status));
		if (order.status === 'quoted' || order.status === 'approved' || order.status === 'done') {
			els.order.appendChild(el('div', '', 'Valor final: ' + money(order.total)));
			if (order.note) { els.order.appendChild(el('div', 'sr-muted', order.note)); }
		}
		const actions = el('div', 'sr-actions');
		function action(label, className, handler) {
			const button = el('button', 'coe-button ' + className, label);
			button.type = 'button';
			button.addEventListener('click', handler);
			actions.appendChild(button);
		}
		if (order.status === 'quoted') {
			action('Aprovar', 'coe-button--primary', function () { post('respond', { id: order.id, approve: true }); });
			action('Recusar', '', function () { post('respond', { id: order.id, approve: false }); });
		}
		if (order.status === 'requested' || order.status === 'quoted' || order.status === 'approved') {
			action('Cancelar pedido', 'coe-button--danger', function () { post('cancel', { id: order.id }); });
		}
		els.order.appendChild(actions);
		els.request.disabled = true;
	}

	function buildCamera() {
		els.presets.replaceChildren();
		PRESETS.forEach(function (preset) {
			const button = el('button', 'coe-button', preset[1]);
			button.type = 'button';
			button.addEventListener('click', function () {
				Array.prototype.forEach.call(els.presets.children, function (node) { node.classList.remove('is-active'); });
				button.classList.add('is-active');
				post('camPreset', { name: preset[0] });
			});
			els.presets.appendChild(button);
		});
		els.presets.firstChild.classList.add('is-active');
	}

	function open(data) {
		ctx = data; ctx.options = ctx.options || {}; ctx.options.mods = ctx.options.mods || {};
		patch = {}; order = null; tab = 'colors'; autoOn = false;
		els.auto.classList.remove('is-active'); els.auto.setAttribute('aria-pressed', 'false');
		els.root.classList.remove('is-free');
		els.shop.textContent = data.label || '';
		els.vehicle.textContent = [data.model, data.plate].filter(Boolean).join(' · ');
		buildCamera(); renderTabs({}); buildOptions(); renderEstimate(null); renderOrder(); setStatus('');
		els.root.classList.add('is-open'); els.root.setAttribute('aria-hidden', 'false');
	}

	function close() {
		els.root.classList.remove('is-open', 'is-free'); els.root.setAttribute('aria-hidden', 'true');
		ctx = null; order = null;
	}

	els.request.addEventListener('click', function () {
		const out = changed();
		if (!isEmpty(out)) { post('request', { patch: out }); setStatus('Pedido enviado à oficina.'); }
	});
	els.reset.addEventListener('click', function () { patch = {}; buildOptions(); refresh(); });
	els.close.addEventListener('click', function () { post('closeShowroom'); });
	els.auto.addEventListener('click', function () {
		autoOn = !autoOn;
		els.auto.classList.toggle('is-active', autoOn);
		els.auto.setAttribute('aria-pressed', String(autoOn));
		post('camAuto', { enabled: autoOn });
	});
	els.free.addEventListener('click', function () { post('camFree'); });

	// Arrastar no espaço livre gira a câmera; a roda aproxima e afasta.
	let drag = null;
	let pending = { dx: 0, dy: 0 };
	let flushing = false;
	function flush() {
		flushing = false;
		if (pending.dx !== 0 || pending.dy !== 0) { post('camOrbit', pending); pending = { dx: 0, dy: 0 }; }
	}
	els.stage.addEventListener('pointerdown', function (event) {
		drag = { x: event.clientX, y: event.clientY };
		els.stage.classList.add('is-dragging');
		els.stage.setPointerCapture(event.pointerId);
	});
	els.stage.addEventListener('pointermove', function (event) {
		if (!drag) { return; }
		pending.dx += event.clientX - drag.x;
		pending.dy += event.clientY - drag.y;
		drag = { x: event.clientX, y: event.clientY };
		if (!flushing) { flushing = true; requestAnimationFrame(flush); }
	});
	function endDrag() { drag = null; els.stage.classList.remove('is-dragging'); }
	els.stage.addEventListener('pointerup', endDrag);
	els.stage.addEventListener('pointercancel', endDrag);
	els.root.addEventListener('wheel', function (event) {
		if (event.target.closest && event.target.closest('.sr-options, .sr-lines')) { return; }
		post('camZoom', { direction: event.deltaY > 0 ? 1 : -1 });
	}, { passive: true });
	document.addEventListener('keydown', function (event) {
		if (event.key === 'Escape' && ctx && !els.root.classList.contains('is-free')) { post('closeShowroom'); }
	});

	function applyDone() {
		const out = changed();
		const current = ctx.current;
		['mods', 'colors', 'toggles', 'extras'].forEach(function (group) {
			if (out[group]) { current[group] = Object.assign({}, current[group] || {}, out[group]); }
		});
		['livery', 'tint', 'wheelType', 'neon'].forEach(function (key) { if (out[key] !== undefined) { current[key] = out[key]; } });
		patch = {};
		buildOptions();
	}

	window.addEventListener('message', function (event) {
		const message = event.data || {};
		if (message.action === 'open') { open(message.data || {}); }
		else if (message.action === 'close') { close(); }
		else if (message.action === 'freecam') { els.root.classList.toggle('is-free', message.data === true); }
		else if (message.action === 'estimate') { renderEstimate(message.data); }
		else if (message.action === 'error') { setStatus(ERRORS[message.data] || ('Falha: ' + message.data), true); }
		else if (message.action === 'order') {
			order = message.data && ['declined', 'cancelled', 'expired'].indexOf(message.data.status) === -1 ? message.data : null;
			if (message.data && message.data.status === 'done' && ctx) { applyDone(); renderEstimate(null); renderTabs({}); setStatus('Serviço concluído. Boa estrada!'); }
			if (message.data && message.data.status === 'declined') { setStatus('Orçamento recusado.'); }
			renderOrder();
		}
	});
})();
