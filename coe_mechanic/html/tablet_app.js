(function () {
	'use strict';

	const CONDITIONS = { ok: 'Bom', warn: 'Desgastada', critical: 'Crítica' };
	const LABELS = {
		engine_oil: 'Óleo do motor', air_filter: 'Filtro de ar', spark_plugs: 'Velas', brake_pads: 'Pastilhas de freio',
		brake_discs: 'Discos de freio', clutch: 'Embreagem', suspension: 'Suspensão'
	};
	const STATUS = {
		requested: ['Aguardando orçamento', 'tb-badge--warn'], quoted: ['Aguardando o cliente', ''], approved: ['Aprovado', 'tb-badge--accent']
	};

	function el(tag, className, text) {
		const node = document.createElement(tag);
		if (className) { node.className = className; }
		if (text !== undefined) { node.textContent = text; }
		return node;
	}

	function button(label, className, onClick) {
		const node = el('button', 'coe-button ' + (className || ''), label);
		node.type = 'button';
		node.addEventListener('click', onClick);
		return node;
	}

	function money(value) { return '$ ' + Number(value || 0).toLocaleString('pt-BR'); }

	// Os rótulos de serviço ficam no mesmo arquivo do showroom; carrega uma vez, sem bloquear o app.
	function withLabels(callback) {
		if (window.CoeMechanicLabels) { callback(); return; }
		const script = document.createElement('script');
		script.src = 'nui://coe_mechanic/html/labels.js';
		script.onload = callback;
		document.head.appendChild(script);
	}

	function lineLabel(line) {
		return window.CoeMechanicLabels ? window.CoeMechanicLabels.lineLabel(line) : line.kind + ': ' + line.key;
	}

	window.CoeTablet.register('workshop', function (root, tablet) {
		let vehicle = null;
		let tab = 'diagnostic';
		let orders = [];
		let alive = true;

		withLabels(function () { if (alive && tab === 'orders') { view(); } });

		function panel(className) { return el('div', 'coe-panel coe-panel--compact ' + (className || '')); }

		function tabs() {
			const bar = el('div', 'tb-tabs');
			const diagnostic = button('Diagnóstico', 'tb-tab' + (tab === 'diagnostic' ? ' is-active' : ''), function () { tab = 'diagnostic'; view(); });
			const list = button('Orçamentos', 'tb-tab' + (tab === 'orders' ? ' is-active' : ''), function () { tab = 'orders'; loadOrders(); });
			if (orders.length > 0) { list.appendChild(el('span', 'tb-count', String(orders.length))); }
			bar.appendChild(diagnostic);
			bar.appendChild(list);
			return bar;
		}

		function loadOrders() {
			tablet.call('workshop', 'orders', {}).then(function (result) {
				if (!result || !result.ok) { tablet.status(tablet.errorText(result && result.error), 'error'); orders = []; }
				else { orders = result.orders || []; }
				view();
			});
		}

		function orderAction(action, order, extra) {
			tablet.call('workshop', action, Object.assign({ id: order.id }, extra || {})).then(function (result) {
				if (!result || !result.ok) { tablet.status(tablet.errorText(result && result.error), 'error'); return; }
				tablet.status(action === 'complete' ? 'Serviço executado.' : 'Orçamento enviado.', 'ok');
				// o tablet limita chamadas a 1 por 250 ms
				setTimeout(loadOrders, 350);
			});
		}

		function orderCard(order) {
			const card = panel('tb-card');
			const head = el('div', 'tb-card-head');
			const title = el('div', 'tb-vehicle');
			title.appendChild(el('strong', '', order.plate));
			title.appendChild(el('span', 'tb-muted', order.model));
			head.appendChild(title);
			const status = STATUS[order.status] || [order.status, ''];
			head.appendChild(el('span', 'coe-badge ' + status[1], status[0]));
			card.appendChild(head);

			const lines = el('div', 'tb-lines');
			((order.estimate && order.estimate.lines) || []).forEach(function (line) {
				const row = el('div', 'tb-line');
				row.appendChild(el('span', '', lineLabel(line)));
				row.appendChild(el('span', 'tb-muted', money(line.price)));
				lines.appendChild(row);
			});
			card.appendChild(lines);

			const total = el('div', 'tb-total');
			total.appendChild(el('span', '', 'Estimativa ' + money(order.estimate && order.estimate.total)));
			const current = el('strong', '', money(order.total));
			total.appendChild(current);
			card.appendChild(total);

			if (order.status === 'requested' || order.status === 'quoted') {
				const value = el('input', 'coe-field');
				value.type = 'number'; value.min = '0'; value.value = String(order.total);
				const note = el('input', 'coe-field');
				note.type = 'text'; note.maxLength = 120; note.placeholder = 'Observação ao cliente';
				const form = el('div', 'tb-quote');
				form.appendChild(value);
				form.appendChild(note);
				form.appendChild(button('Enviar orçamento', 'coe-button--primary', function () {
					orderAction('price', order, { total: Math.floor(Number(value.value)), note: note.value });
				}));
				card.appendChild(form);
			}
			if (order.status === 'approved') {
				const row = el('div', 'tb-toolbar');
				row.appendChild(el('span', 'tb-muted', 'Fique perto do veículo para executar.'));
				row.appendChild(button('Executar serviço', 'coe-button--primary', function () { orderAction('complete', order); }));
				card.appendChild(row);
			}
			return card;
		}

		function ordersView() {
			const bar = el('div', 'tb-toolbar');
			bar.appendChild(el('span', 'tb-section', 'Pedidos da oficina'));
			bar.appendChild(button('Atualizar', '', loadOrders));
			root.appendChild(bar);
			if (orders.length === 0) {
				root.appendChild(el('p', 'tb-empty', 'Nenhum pedido aberto nesta oficina.'));
				return;
			}
			orders.forEach(function (order) { root.appendChild(orderCard(order)); });
		}

		function partRow(part) {
			const wear = Math.max(0, Math.min(1, Number(part.wear) || 0));
			const row = panel('tb-part');
			row.appendChild(el('span', '', LABELS[part.part] || part.part));
			const meter = el('div', 'tb-meter' + (wear >= 0.85 ? ' bad' : wear >= 0.6 ? ' warn' : ''));
			const fill = document.createElement('i');
			fill.style.width = Math.round((1 - wear) * 100) + '%';
			meter.appendChild(fill);
			row.appendChild(meter);
			row.appendChild(el('span', 'tb-muted', CONDITIONS[part.condition] || String(part.condition || '')));
			row.appendChild(button('Trocar', '', function () { replace(part.part); }));
			return row;
		}

		function diagnosticView() {
			const bar = el('div', 'tb-toolbar');
			if (vehicle) {
				const head = el('div', 'tb-vehicle');
				head.appendChild(el('strong', '', vehicle.plate));
				head.appendChild(el('span', 'tb-muted', vehicle.model));
				head.appendChild(el('span', 'tb-muted', (vehicle.mileage / 1000).toFixed(1) + ' km'));
				bar.appendChild(head);
			} else {
				bar.appendChild(el('span', 'tb-section', 'Diagnóstico'));
			}
			bar.appendChild(button('Escanear veículo próximo', 'coe-button--primary', scan));
			root.appendChild(bar);
			if (!vehicle) {
				root.appendChild(el('p', 'tb-empty', 'Aproxime-se de um veículo e escaneie para iniciar o diagnóstico.'));
				return;
			}
			root.appendChild(el('div', 'tb-section', 'Peças e desgaste'));
			(vehicle.parts || []).forEach(function (part) { root.appendChild(partRow(part)); });
			const footer = el('div', 'tb-toolbar');
			footer.appendChild(el('span', 'tb-muted', 'Revisão troca todas as peças de uma vez.'));
			footer.appendChild(button('Revisão completa', 'coe-button--primary', function () { replace('all'); }));
			root.appendChild(footer);
		}

		function view() {
			root.replaceChildren();
			root.appendChild(tabs());
			if (tab === 'orders') { ordersView(); } else { diagnosticView(); }
		}

		function handle(result, success) {
			if (!result || !result.ok) {
				tablet.status(tablet.errorText(result && result.error), 'error');
				return;
			}
			vehicle = result.vehicle;
			tablet.status(success, 'ok');
			view();
		}

		function scan() {
			tablet.nearestVehicle().then(function (near) {
				if (!near.ok) { tablet.status(tablet.errorText(near.error), 'error'); return; }
				tablet.call('workshop', 'scan', { plate: near.plate }).then(function (result) {
					handle(result, 'Diagnóstico atualizado.');
				});
			});
		}

		function replace(part) {
			tablet.call('workshop', 'replace', { plate: vehicle.plate, part: part }).then(function (result) {
				handle(result, 'Serviço concluído.');
			});
		}

		view();
	});
})();
