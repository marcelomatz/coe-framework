// App Ponto (coe_workpad): onde o personagem está de ponto, há quanto tempo, encerrar o ponto e os locais de trabalho
// (dono ou equipe) com cargo, salário, regra de ponto e GPS até o relógio.
(function () {
	'use strict';

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
	function line(label, value) {
		const row = el('div', 'tb-line');
		row.append(el('span', null, label), el('strong', null, value));
		return row;
	}
	function money(value) { return '$ ' + Math.floor(Number(value) || 0).toLocaleString('pt-BR'); }
	function pad(value) { return String(value).padStart(2, '0'); }
	function elapsed(seconds) {
		const total = Math.max(0, Math.floor(seconds));
		return pad(Math.floor(total / 3600)) + ':' + pad(Math.floor((total % 3600) / 60)) + ':' + pad(total % 60);
	}

	function render(root, api) {
		let timer = null;
		let busy = false;

		function load() {
			api.call('duty', 'overview').then(function (result) {
				if (!result || !result.ok) { api.status(api.errorText(result && result.error), 'error'); return; }
				paint(result.data || {});
			});
		}

		function clockOut(duty) {
			const ask = window.CoeUI && window.CoeUI.confirm
				? window.CoeUI.confirm({ title: 'Encerrar ponto', message: 'Encerrar o ponto em ' + duty.label + '?', confirmLabel: 'Encerrar', danger: true })
				: Promise.resolve(true);
			ask.then(function (ok) {
				if (!ok || busy) { return; }
				busy = true;
				api.call('duty', 'clockOut').then(function (result) {
					busy = false;
					if (!result || !result.ok) { api.status(api.errorText(result && result.error), 'error'); return; }
					api.status('Ponto encerrado.', 'ok');
					window.dispatchEvent(new CustomEvent('coe:workpadDutyState', { detail: null }));
					paint(result.data || {});
				});
			});
		}

		function nowCard(duty) {
			const box = el('section', 'tb-card coe-panel wp-now' + (duty ? ' is-on' : ''));
			const head = el('div', 'tb-card-head');
			head.append(el('strong', null, duty ? duty.label : 'Fora de serviço'));
			head.append(el('span', 'tb-badge' + (duty ? ' tb-badge--accent' : ''), duty ? 'De ponto' : 'Livre'));
			box.append(head);
			if (!duty) {
				box.append(el('p', 'tb-muted', 'Bata o ponto no relógio do seu local de trabalho. Os empregos livres não usam ponto.'));
				return box;
			}
			const clock = el('p', 'wp-elapsed', duty.seconds !== null && duty.seconds !== undefined ? elapsed(duty.seconds) : '--:--:--');
			if (duty.seconds !== null && duty.seconds !== undefined) {
				const started = Date.now() - duty.seconds * 1000;
				timer = setInterval(function () {
					if (!root.isConnected) { clearInterval(timer); return; }
					clock.textContent = elapsed((Date.now() - started) / 1000);
				}, 1000);
			}
			box.append(el('span', 'tb-muted', 'Tempo de ponto' + (duty.category ? ' · ' + duty.category : '')), clock);
			const actions = el('div', 'tb-actions');
			actions.append(button('Encerrar ponto', 'coe-button--danger', function () { clockOut(duty); }));
			box.append(actions);
			return box;
		}

		function workplaceCard(place) {
			const box = el('section', 'tb-card coe-panel');
			const head = el('div', 'tb-card-head');
			const title = el('div', 'tb-title');
			title.append(el('strong', null, place.label), el('span', 'tb-muted', place.category + (place.enabled ? '' : ' · desativado')));
			head.append(title, el('span', 'tb-badge' + (place.onDuty ? ' tb-badge--accent' : ''), place.onDuty ? 'De ponto' : place.role));
			box.append(head);
			const lines = el('div', 'tb-lines');
			lines.append(line('Função', place.role));
			if (place.salary) { lines.append(line('Salário', money(place.salary) + ' por ciclo')); }
			lines.append(line('Ponto', place.clockRequired ? 'Obrigatório para operar' : 'Livre (sem ponto)'));
			if (place.clockRequired) { lines.append(line('Fora da área', place.offsite ? 'O ponto continua' : 'O ponto encerra')); }
			box.append(lines);
			if (place.x !== null && place.x !== undefined) {
				const actions = el('div', 'tb-actions');
				actions.append(button('Marcar relógio no GPS', '', function () {
					api.waypoint(place.x, place.y).then(function (result) {
						api.status(result && result.ok ? 'Local marcado no GPS.' : 'Não foi possível marcar o GPS.', result && result.ok ? 'ok' : 'error');
					});
				}));
				box.append(actions);
			}
			return box;
		}

		function paint(data) {
			clearInterval(timer);
			root.replaceChildren();
			root.append(nowCard(data.duty || null));
			root.append(el('div', 'tb-section', 'Meus locais de trabalho'));
			const places = data.workplaces || [];
			if (!places.length) {
				root.append(el('p', 'tb-empty', 'Você ainda não é dono nem faz parte da equipe de nenhum negócio.'));
				return;
			}
			const grid = el('div', 'tb-grid');
			places.forEach(function (place) { grid.append(workplaceCard(place)); });
			root.append(grid);
		}

		// Ponto batido ou encerrado em outro lugar (relógio, saída da área) com o app aberto.
		window.addEventListener('coe:workpadDuty', function () { if (root.isConnected) { load(); } });
		root.append(el('p', 'tb-empty', 'Carregando...'));
		load();
	}

	if (window.CoeTablet) { window.CoeTablet.register('duty', render); }
})();
