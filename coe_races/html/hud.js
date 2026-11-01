// HUD da corrida (coe_races): recebe { action: 'hud', type, data } do client.
(function () {
	'use strict';

	const root = document.getElementById('hud');
	const DNF = {
		quit: 'Você desistiu.', left_vehicle: 'Ficou fora do carro.', offline: 'Desconectado.', time: 'O tempo acabou.'
	};

	function el(tag, className, text) {
		const node = document.createElement(tag);
		if (className) { node.className = className; }
		if (text !== undefined && text !== null) { node.textContent = String(text); }
		return node;
	}

	function formatTime(ms) {
		if (ms === null || ms === undefined) { return '—'; }
		const total = Math.max(0, Math.floor(ms));
		const minutes = Math.floor(total / 60000);
		const seconds = Math.floor((total % 60000) / 1000);
		return minutes + ':' + String(seconds).padStart(2, '0') + '.' + String(total % 1000).padStart(3, '0');
	}

	function ordinal(n) { return n + 'º'; }

	// Áreas
	const lobby = el('div', 'hud-lobby'); lobby.hidden = true;
	const board = el('div', 'hud-board'); board.hidden = true;
	const center = el('div', 'hud-center');
	const banner = el('div', 'hud-banner'); banner.hidden = true;
	const lapBanner = el('div', 'hud-banner is-lap'); lapBanner.hidden = true;
	const warn = el('div', 'hud-banner is-warn'); warn.hidden = true;
	const record = el('div', 'hud-record'); record.hidden = true;
	const results = el('div', 'hud-results'); results.hidden = true;
	[lobby, board, center, banner, lapBanner, warn, record, results].forEach(function (node) { root.appendChild(node); });

	const pos = el('div', 'hud-pos');
	const rows = el('div', 'hud-rows');
	const list = el('div', 'hud-list');
	board.appendChild(pos);
	board.appendChild(rows);
	board.appendChild(list);

	const race = { laps: 1, lap: 1, checkpoint: 0, total: 0, startedAt: null, finishedMs: null, best: null, position: null, racers: null };
	let lobbyDeadline = 0;
	let leaderDeadline = 0;
	const timers = {};

	function later(name, ms, fn) {
		clearTimeout(timers[name]);
		timers[name] = setTimeout(fn, ms);
	}

	function row(label, value, kind) {
		const node = el('div', 'hud-row' + (kind ? ' is-' + kind : ''));
		node.appendChild(el('span', null, label));
		node.appendChild(el('strong', null, value));
		return node;
	}

	function elapsed() {
		if (race.finishedMs !== null) { return race.finishedMs; }
		return race.startedAt ? performance.now() - race.startedAt : 0;
	}

	function paintBoard() {
		pos.innerHTML = '';
		if (race.position) {
			pos.appendChild(el('b', null, race.position));
			pos.appendChild(el('sup', null, 'º'));
			pos.appendChild(el('span', null, '/' + race.racers));
		}
		rows.innerHTML = '';
		rows.appendChild(row('Tempo', formatTime(elapsed()), 'time'));
		if (race.laps > 1) { rows.appendChild(row('Volta', Math.min(race.lap, race.laps) + '/' + race.laps)); }
		rows.appendChild(row('Checkpoint', race.checkpoint + '/' + race.total));
		if (race.best) { rows.appendChild(row('Melhor volta', formatTime(race.best))); }
	}

	function paintList(entries) {
		list.innerHTML = '';
		(entries || []).slice(0, 8).forEach(function (entry) {
			const line = el('div', (entry.position === race.position ? 'is-me' : '') + (entry.dnf ? ' is-out' : ''));
			const left = el('span');
			left.appendChild(el('b', null, entry.position));
			left.appendChild(document.createTextNode(entry.nickname));
			line.appendChild(left);
			line.appendChild(el('em', null, entry.finished ? formatTime(entry.timeMs) : (entry.dnf ? 'DNF' : 'CP ' + entry.progress)));
			list.appendChild(line);
		});
	}

	function big(text, kind, sub, subKind) {
		center.innerHTML = '';
		const node = el('div', 'hud-big' + (kind ? ' is-' + kind : ''), text);
		center.appendChild(node);
		if (sub) { center.appendChild(el('div', 'hud-sub' + (subKind ? ' is-' + subKind : ''), sub)); }
	}

	function clearCenter() { center.innerHTML = ''; }

	function showBanner(node, html, ms) {
		node.innerHTML = '';
		const span = el('span');
		span.innerHTML = html;
		node.appendChild(span);
		node.hidden = false;
		if (ms) { later(node === lapBanner ? 'lap' : (node === warn ? 'warn' : 'banner'), ms, function () { node.hidden = true; }); }
	}

	function escape(text) { return String(text).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); }

	function resetRace() {
		race.lap = 1; race.checkpoint = 0; race.startedAt = null; race.finishedMs = null; race.best = null; race.position = null; race.racers = null;
		board.hidden = true;
		banner.hidden = true;
		lapBanner.hidden = true;
		warn.hidden = true;
		leaderDeadline = 0;
		list.innerHTML = '';
	}

	function countdown(goIn) {
		const at = performance.now() + (goIn || 0);
		let last = null;
		function step() {
			const left = Math.ceil((at - performance.now()) / 1000);
			if (left <= 0) { return; }
			if (left !== last) { last = left; big(left, null); }
			timers.count = setTimeout(step, 50);
		}
		clearTimeout(timers.count);
		step();
	}

	const handlers = {
		clear: function () {
			resetRace();
			lobby.hidden = true;
			clearCenter();
			clearTimeout(timers.count);
		},
		lobby: function (data) {
			resetRace();
			lobbyDeadline = performance.now() + (data.startsIn || 0) * 1000;
			lobby.innerHTML = '';
			lobby.appendChild(el('small', null, 'INSCRITO'));
			lobby.appendChild(el('strong', null, data.name));
			const p = el('p');
			p.innerHTML = 'Largada em <b data-lobby>--:--</b> · vá ao grid e espere no carro';
			lobby.appendChild(p);
			lobby.hidden = false;
		},
		prepare: function () {
			lobby.hidden = true;
			big('GRID', 'hold', 'Alinhe e fique no carro');
		},
		countdown: function (data) {
			lobby.hidden = true;
			resetRace();
			race.laps = data.laps || 1;
			race.racers = data.racers;
			board.hidden = false;
			paintBoard();
			countdown(data.goIn);
		},
		go: function (data) {
			clearTimeout(timers.count);
			race.startedAt = performance.now();
			big('VAI!', 'go', data && data.ghostSeconds ? 'Fantasma por ' + data.ghostSeconds + ' s' : null, 'ghost');
			later('go', 1600, clearCenter);
		},
		progress: function (data) {
			race.checkpoint = data.checkpoint;
			race.total = data.total;
			race.lap = data.lap;
			race.laps = data.laps;
			paintBoard();
		},
		standings: function (data) {
			race.position = data.position;
			race.racers = data.racers;
			if (race.startedAt && race.finishedMs === null && typeof data.elapsed === 'number') {
				race.startedAt = performance.now() - data.elapsed;
			}
			board.hidden = false;
			paintBoard();
			paintList(data.list);
		},
		lap: function (data) {
			race.best = data.bestMs;
			const record = data.lapMs === data.bestMs ? ' <b>MELHOR</b>' : '';
			showBanner(lapBanner, 'Volta ' + data.lap + ' · <b>' + formatTime(data.lapMs) + '</b>' + record, 4000);
			paintBoard();
		},
		leader: function (data) {
			leaderDeadline = performance.now() + (data.seconds || 0) * 1000;
			showBanner(banner, escape(data.nickname) + ' cruzou a chegada! Termine em <b data-leader>' + data.seconds + '</b> s');
		},
		finished: function (data) {
			race.finishedMs = data.timeMs;
			banner.hidden = true;
			big('CHEGADA', 'finish', formatTime(data.timeMs) + ' · aguardando os demais');
			center.firstChild.classList.add('is-hold');
			paintBoard();
		},
		dnf: function (data) {
			banner.hidden = true;
			big('ABANDONO', 'dnf', DNF[data.reason] || '');
			center.firstChild.classList.add('is-hold');
			later('dnf', 6000, clearCenter);
		},
		warning: function (data) {
			showBanner(warn, escape(data.text), 1200);
		},
		results: function (data) {
			resetRace();
			lobby.hidden = true;
			clearCenter();
			results.innerHTML = '';
			results.appendChild(el('h3', null, data.track));
			results.appendChild(el('p', null, 'Resultado final' + (data.potText && data.results.some(function (r) { return r.prize > 0; }) ? ' · pote ' + data.potText : '')));
			const table = el('table');
			data.results.forEach(function (r) {
				const tr = el('tr');
				tr.appendChild(el('td', r.dnf ? 'dnf' : 'p' + r.position, r.dnf ? 'DNF' : ordinal(r.position)));
				tr.appendChild(el('td', null, r.nickname));
				tr.appendChild(el('td', null, r.vehicle || ''));
				tr.appendChild(el('td', 'num', r.dnf ? '—' : formatTime(r.timeMs)));
				tr.appendChild(el('td', 'num ' + (r.ratingDelta >= 0 ? 'up' : 'down'), (r.ratingDelta >= 0 ? '+' : '') + r.ratingDelta));
				tr.appendChild(el('td', 'num prize', r.prize > 0 ? r.prizeText : ''));
				table.appendChild(tr);
			});
			results.appendChild(table);
			results.hidden = false;
			later('results', 20000, function () { results.hidden = true; });
		},
		record: function (data) {
			if (!data) { record.hidden = true; return; }
			record.innerHTML = '';
			record.appendChild(el('small', null, 'GRAVANDO PISTA'));
			record.appendChild(el('strong', null, data.name));
			const count = el('div');
			if (!data.started) {
				count.appendChild(el('span', null, 'Pare na largada e marque.'));
			} else {
				count.appendChild(el('span', 'hud-count', data.count));
				count.appendChild(document.createTextNode(' checkpoints' + (data.kind === 'circuit' ? ' · circuito' : ' · sprint')));
			}
			record.appendChild(count);
			const keys = el('ul');
			[[data.keys.mark, data.started ? 'Marcar checkpoint' : 'Marcar largada'], [data.keys.undo, 'Desfazer'], [data.keys.save, 'Salvar pista'], [data.keys.cancel, 'Cancelar']].forEach(function (pair) {
				const li = el('li');
				li.appendChild(el('kbd', null, pair[0] === 'RETURN' ? 'Enter' : (pair[0] === 'DELETE' ? 'Del' : pair[0])));
				li.appendChild(document.createTextNode(pair[1]));
				keys.appendChild(li);
			});
			record.appendChild(keys);
			record.hidden = false;
		}
	};

	// Relógio do HUD
	setInterval(function () {
		if (!board.hidden && race.startedAt) {
			const time = rows.querySelector('.is-time strong');
			if (time) { time.textContent = formatTime(elapsed()); }
		}
		if (!lobby.hidden) {
			const node = lobby.querySelector('[data-lobby]');
			const left = Math.max(0, Math.round((lobbyDeadline - performance.now()) / 1000));
			if (node) { node.textContent = Math.floor(left / 60) + ':' + String(left % 60).padStart(2, '0'); }
		}
		if (!banner.hidden && leaderDeadline) {
			const node = banner.querySelector('[data-leader]');
			if (node) { node.textContent = Math.max(0, Math.ceil((leaderDeadline - performance.now()) / 1000)); }
		}
	}, 100);

	window.addEventListener('message', function (event) {
		const data = event.data || {};
		if (data.action !== 'hud') { return; }
		const handler = handlers[data.type];
		if (handler) { handler(data.data); }
	});

	window.CoeRacesHud = { handle: function (type, data) { if (handlers[type]) { handlers[type](data); } } };
})();
