// App "Veículos" do COE OS (coe_tablet): lista os veículos do personagem e marca no GPS onde estão.
(function () {
	'use strict';

	const STATES = { stored: 'Guardado', out: 'Na rua', impounded: 'Apreendido' };

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

	window.CoeTablet.register('vehicles', function (root, tablet) {
		function view(list) {
			root.replaceChildren();
			if (!list.length) { root.appendChild(el('p', 'tb-empty', 'Você não tem veículos registrados.')); return; }
			const grid = el('div', 'tb-grid');
			root.appendChild(grid);
			list.forEach(function (vehicle) {
				const box = el('div', 'coe-panel coe-panel--compact tb-card');
				const head = el('div', 'tb-card-head');
				head.appendChild(el('strong', '', vehicle.name));
				head.appendChild(el('span', 'coe-badge' + (vehicle.state === 'out' ? ' tb-badge--accent' : vehicle.state === 'impounded' ? ' tb-badge--warn' : ''), STATES[vehicle.state] || vehicle.state));
				box.appendChild(head);
				const lines = el('div', 'tb-lines');
				[['Placa', vehicle.plate], ['Quilometragem', (vehicle.km || 0).toLocaleString('pt-BR') + ' km'], ['Local', vehicle.where || (vehicle.state === 'out' ? 'Na rua' : '—')]].forEach(function (pair) {
					const line = el('div', 'tb-line');
					line.append(el('span', 'tb-muted', pair[0]), el('span', '', pair[1]));
					lines.appendChild(line);
				});
				box.appendChild(lines);
				if (typeof vehicle.x === 'number' && typeof vehicle.y === 'number') {
					const actions = el('div', 'tb-actions');
					actions.appendChild(button('Marcar no GPS', '', function () {
						tablet.waypoint(vehicle.x, vehicle.y).then(function () { tablet.status('Local marcado no GPS.', 'ok'); });
					}));
					box.appendChild(actions);
				}
				grid.appendChild(box);
			});
		}

		root.appendChild(el('p', 'tb-empty', 'Carregando…'));
		tablet.call('vehicles', 'list', {}).then(function (result) {
			if (!result || !result.ok) { root.replaceChildren(); tablet.status(tablet.errorText(result && result.error), 'error'); return; }
			view(result.vehicles || []);
		});
	});
})();