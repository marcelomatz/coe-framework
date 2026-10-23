// Tablet de trabalho (coe_workpad): tela inicial, abertura dos apps e a API window.CoeTablet usada por eles
// (a mesma dos apps de tablet do framework: Carreira do coe_jobs e Negócio do coe_businesses).
(function () {
	'use strict';

	const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'coe_workpad';
	const RUNNING_MAX = 6;
	const ERRORS = {
		forbidden: 'Você não tem acesso a esse app agora.', rate_limited: 'Aguarde um instante.', closed: 'Tablet guardado.',
		timeout: 'Sem resposta do servidor.', app_error: 'O app falhou. Tente de novo.', app_unavailable: 'App indisponível no momento.',
		invalid_request: 'Pedido inválido.', invalid_payload: 'Dados inválidos.', invalid_action: 'Ação desconhecida.',
		no_tablet: 'Você não está com o tablet de trabalho.', no_character: 'Personagem não carregado.',
		not_ready: 'Serviço ainda iniciando.', not_on_duty: 'Você não está de ponto.', database_error: 'Falha no banco de dados.'
	};
	const ICONS = {
		clock: '<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>',
		jobs: '<rect x="3.5" y="7.5" width="17" height="12" rx="1"/><path d="M9 7.5V5h6v2.5M3.5 12.5h17"/>',
		career: '<path d="M4 19h16M6 16l4-5 3 3 5-7"/><path d="M15 7h3v3"/>',
		business: '<path d="M4 20V9l8-5 8 5v11"/><path d="M9 20v-6h6v6"/>'
	};
	const CATEGORY_ICONS = { mechanic: 'M', shop: 'L', gas_station: 'P', restaurant: 'R', police: 'D', ems: 'H', media: 'N' };

	const $ = function (id) { return document.getElementById(id); };
	const els = {
		root: $('workpad'), home: $('wp-home'), view: $('wp-view'), groups: $('wp-groups'), apps: $('wp-apps'),
		status: $('wp-status'), clock: $('wp-clock'), bigclock: $('wp-bigclock'), date: $('wp-date'), duty: $('wp-duty'),
		dutyWidget: $('wp-duty-widget'), dutyOpen: $('wp-duty-open'), businessCount: $('wp-business-count'),
		back: $('wp-back'), close: $('wp-close'), title: $('wp-view-title'), kind: $('wp-view-kind'), icon: $('wp-view-icon')
	};

	const registry = {};
	const loaded = {};
	let profile = { apps: [], groups: [] };
	let containers = {};
	let running = [];
	let current = null;
	let statusTimer = null;

	function el(tag, className, text) {
		const node = document.createElement(tag);
		if (className) { node.className = className; }
		if (text !== undefined && text !== null) { node.textContent = String(text); }
		return node;
	}
	function post(name, body) {
		return fetch('https://' + resource + '/' + name, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json; charset=UTF-8' },
			body: JSON.stringify(body || {})
		}).then(function (response) { return response.json(); }).catch(function () { return { ok: false, error: 'closed' }; });
	}
	function pad(value) { return String(value).padStart(2, '0'); }

	function setStatus(message, kind) {
		els.status.textContent = message || '';
		els.status.className = 'wp-status' + (kind ? ' is-' + kind : '');
		clearTimeout(statusTimer);
		if (message && kind !== 'error') { statusTimer = setTimeout(function () { setStatus(''); }, 6000); }
	}
	function errorText(code) {
		const fallback = ERRORS[code] || 'Não foi possível concluir.';
		return (window.CoeUI && typeof window.CoeUI.t === 'function') ? window.CoeUI.t('tablet.error.' + code, null, fallback) : fallback;
	}

	// API dos apps (window.CoeTablet) ------------------------------------------------------------------------------
	const api = {
		register: function (id, render) { registry[id] = render; },
		call: function (app, action, payload) { return post('call', { app: app, action: action, payload: payload || {} }); },
		waypoint: function (x, y) { return post('waypoint', { x: x, y: y }); },
		refresh: function () { return post('refresh'); },
		icon: function (node, app) { paintIcon(node, app); },
		status: setStatus,
		errorText: errorText,
		device: 'workpad'
	};
	window.CoeTablet = api;

	// Apps com instância (ex.: um por negócio) chamam pelo id base; o tablet encaminha para o id da instância.
	function appApi(app) {
		if (!app.base || app.base === app.id) { return api; }
		return Object.assign({}, api, {
			call: function (target, action, payload) { return api.call(target === app.base ? app.id : target, action, payload); }
		});
	}

	function paintIcon(node, app) {
		node.replaceChildren();
		node.dataset.icon = app.icon || '';
		const glyph = ICONS[app.icon];
		if (app.base === 'business' && app.instance) {
			node.textContent = (app.label || '?').trim().charAt(0).toUpperCase();
			return;
		}
		if (glyph) {
			const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
			svg.setAttribute('viewBox', '0 0 24 24');
			svg.innerHTML = glyph;
			node.append(svg);
		} else {
			node.textContent = (app.label || '?').charAt(0).toUpperCase();
		}
	}

	// Scripts dos apps (só nui://, conferido também no servidor).
	function loadScript(src) {
		return new Promise(function (resolve) {
			if (loaded[src]) { resolve(); return; }
			const script = document.createElement('script');
			script.src = src;
			script.onload = function () { loaded[src] = true; resolve(); };
			script.onerror = function () { resolve(); };
			document.head.appendChild(script);
		});
	}
	function loadScripts() {
		const unique = [];
		profile.apps.forEach(function (app) {
			if (/^nui:\/\/[a-z0-9_]+\/html\/[a-z0-9_]+\.js$/.test(app.script) && unique.indexOf(app.script) === -1) { unique.push(app.script); }
		});
		return Promise.all(unique.map(loadScript));
	}

	// Tela inicial -------------------------------------------------------------------------------------------------

	function findApp(id) { return profile.apps.find(function (app) { return app.id === id; }) || null; }

	function paintHome() {
		els.groups.replaceChildren();
		(profile.groups || []).forEach(function (group) {
			const list = profile.apps.filter(function (app) { return app.group === group.id; });
			const section = el('section', 'wp-group');
			section.append(el('h2', 'wp-group-title', group.label));
			const grid = el('div', 'wp-grid');
			if (!list.length) {
				grid.append(el('p', 'wp-group-empty', group.id === 'business'
					? 'Você não é dono nem faz parte da equipe de nenhum negócio.'
					: 'Nenhum app disponível.'));
			}
			list.forEach(function (app) {
				const tile = el('button', 'wp-tile' + (running.indexOf(app.id) !== -1 ? ' is-running' : ''));
				tile.type = 'button';
				const icon = el('span', 'wp-app-icon');
				icon.dataset.app = app.base;
				paintIcon(icon, app);
				const text = el('span', 'wp-tile-text');
				text.append(el('strong', null, app.label));
				if (app.kind && app.kind !== app.label) { text.append(el('small', null, app.kind)); }
				tile.append(icon, text);
				tile.addEventListener('click', function () { openApp(app.id); });
				grid.append(tile);
			});
			section.append(grid);
			els.groups.append(section);
		});
		els.businessCount.textContent = String(profile.apps.filter(function (app) { return app.base === 'business'; }).length);
		els.dutyOpen.hidden = !findApp('duty');
	}

	function setDuty(businessId) {
		const app = businessId ? findApp('business:' + businessId) : null;
		const label = businessId ? (app ? app.label : businessId) : null;
		els.duty.textContent = label ? 'De ponto · ' + label : 'Fora de serviço';
		els.duty.classList.toggle('is-on', Boolean(label));
		els.dutyWidget.textContent = label || 'Fora de serviço';
	}

	function tick() {
		const now = new Date();
		const text = pad(now.getHours()) + ':' + pad(now.getMinutes());
		els.clock.textContent = text;
		els.bigclock.textContent = text;
		const date = now.toLocaleDateString('pt-BR', { weekday: 'long', day: 'numeric', month: 'long' });
		els.date.textContent = date.charAt(0).toUpperCase() + date.slice(1);
	}

	// Apps abertos -------------------------------------------------------------------------------------------------

	function killApp(id) {
		if (containers[id]) { containers[id].node.remove(); }
		delete containers[id];
		running = running.filter(function (other) { return other !== id; });
		if (current === id) { current = null; }
	}

	function openApp(id) {
		const app = findApp(id);
		if (!app) { return; }
		setStatus('');
		Object.keys(containers).forEach(function (other) { containers[other].node.hidden = other !== id; });
		current = id;
		els.title.textContent = app.label;
		els.kind.textContent = app.kind && app.kind !== app.label ? app.kind : '';
		paintIcon(els.icon, app);
		els.icon.dataset.app = app.base;
		els.home.hidden = true;
		els.view.hidden = false;
		if (!containers[id]) {
			while (running.length >= RUNNING_MAX) { killApp(running[0]); }
			const node = el('div', 'wp-app');
			node.dataset.app = id;
			els.apps.appendChild(node);
			containers[id] = { app: app, node: node };
			const render = registry[app.base];
			if (render) {
				try { render(node, appApi(app)); } catch (error) { setStatus(errorText('app_error'), 'error'); }
			} else {
				setStatus(errorText('app_unavailable'), 'error');
			}
		}
		running = running.filter(function (other) { return other !== id; }).concat([id]);
	}

	function showHome() {
		current = null;
		Object.keys(containers).forEach(function (id) { containers[id].node.hidden = true; });
		setStatus('');
		els.view.hidden = true;
		els.home.hidden = false;
		paintHome();
	}

	// Lista de apps nova: os que o jogador perdeu fecham.
	function applyProfile(next) {
		profile = { apps: Array.isArray(next.apps) ? next.apps : [], groups: next.groups || [] };
		Object.keys(containers).forEach(function (id) { if (!findApp(id)) { killApp(id); } });
		return loadScripts().then(function () {
			if (current && !findApp(current)) { showHome(); } else if (!current) { paintHome(); }
		});
	}

	function open(data) {
		els.root.hidden = false;
		tick();
		applyProfile(data).then(function () {
			setDuty(data.duty || null);
			if (current && findApp(current)) { openApp(current); } else { showHome(); }
		});
	}

	function close() {
		els.root.hidden = true;
		setStatus('');
	}

	function requestClose() { post('close'); }

	els.back.addEventListener('click', showHome);
	els.close.addEventListener('click', requestClose);
	els.dutyOpen.addEventListener('click', function () { openApp('duty'); });

	document.addEventListener('keydown', function (event) {
		if (event.key !== 'Escape' || els.root.hidden || document.querySelector('.coe-modal-overlay')) { return; }
		if (current) { showHome(); } else { requestClose(); }
	});

	window.addEventListener('message', function (event) {
		const message = event.data || {};
		if (message.action === 'open' && message.data) { open(message.data); }
		if (message.action === 'profile' && message.data) { applyProfile(message.data); }
		if (message.action === 'close') { close(); }
		if (message.action === 'duty') {
			setDuty(message.data || null);
			window.dispatchEvent(new CustomEvent('coe:workpadDuty', { detail: message.data || null }));
		}
	});

	// Os apps do próprio tablet avisam a barra de status quando o ponto muda.
	window.addEventListener('coe:workpadDutyState', function (event) { setDuty(event.detail || null); });

	setInterval(tick, 15000);
	setDuty(null);
})();
