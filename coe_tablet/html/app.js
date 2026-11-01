(function () {
	'use strict';

	const ERRORS = {
		forbidden: 'Seu trabalho não permite esta ação.',
		rate_limited: 'Calma, muitas ações seguidas.',
		app_unavailable: 'Aplicativo indisponível.',
		app_error: 'Falha no aplicativo.',
		timeout: 'Sem resposta do servidor.',
		closed: 'Tablet fechado.',
		no_vehicle: 'Nenhum veículo por perto.',
		camera_unavailable: 'Câmera indisponível.',
		camera_timeout: 'A câmera não respondeu. Tente de novo (detalhes no F8).',
		camera_empty: 'A câmera não gerou a foto (detalhes no F8).',
		cancelled: 'Foto cancelada.',
		vehicle_not_found: 'Veículo não registrado.',
		vehicle_too_far: 'Chegue mais perto do veículo.',
		invalid_plate: 'Placa inválida.',
		not_ready: 'Serviço ainda iniciando.',
		not_in_shop: 'Você precisa estar dentro da oficina.',
		order_not_found: 'Pedido não encontrado ou expirado.',
		invalid_status: 'Esse pedido mudou de estado. Atualize.',
		total_out_of_range: 'Valor fora da faixa permitida (±50% da estimativa).',
		invalid_total: 'Valor inválido.',
		payment_failed: 'Pagamento do cliente falhou.'
	};

	const ICONS = {
		clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
		home: '<path d="M4 11 12 4l8 7"/><path d="M6 10v10h12V10"/><path d="M10 20v-6h4v6"/>',
		hideout: '<path d="M3 20h18"/><path d="M6 20V9l6-5 6 5v11"/><path d="M10 20v-4a2 2 0 0 1 4 0v4"/>',
		business: '<rect x="3" y="7" width="18" height="13" rx="2"/><path d="M8 7V5a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/><path d="M3 13h18"/>',
		workshop: '<path d="M14 6a4 4 0 0 0-5 5L4 16l4 4 5-5a4 4 0 0 0 5-5l-3 3-3-1-1-3z"/>',
		mdt: '<path d="M12 3 4 6v6c0 5 3.5 8 8 9 4.5-1 8-4 8-9V6z"/><path d="m9 12 2 2 4-4"/>',
		bank: '<path d="M3 10h18L12 4z"/><path d="M5 10v8M9.5 10v8M14.5 10v8M19 10v8"/><path d="M3 20h18"/>',
		car: '<path d="M5 16V11l2-5h10l2 5v5"/><path d="M3 16h18v2H3z"/><circle cx="7.5" cy="13.5" r=".8"/><circle cx="16.5" cy="13.5" r=".8"/>',
		faction: '<path d="M5 21V4"/><path d="M5 4h11l-2 4 2 4H5"/>',
		key: '<circle cx="8" cy="15" r="4"/><path d="m11 12 9-9"/><path d="m17 6 3 3"/><path d="m15 8 2 2"/>',
		store: '<path d="M4 8h16l-1 12H5z"/><path d="M9 8V6a3 3 0 0 1 6 0v2"/><path d="m10 14 2 2 3-4"/>',
		career: '<path d="M12 3l2.6 5.3 5.9.9-4.3 4.1 1 5.8L12 16.4l-5.2 2.7 1-5.8-4.3-4.1 5.9-.9z"/>',
		jobs: '<rect x="3" y="8" width="18" height="12" rx="2"/><path d="M9 8V6h6v2"/><path d="M12 12v3"/><path d="M3 13h18"/>',
		cart: '<circle cx="9" cy="20" r="1.4"/><circle cx="17" cy="20" r="1.4"/><path d="M3 4h2.5l2.2 11h10.6l2-8H6.6"/>',
		mail: '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3.5 7l8.5 6 8.5-6"/>',
		tv: '<rect x="3" y="6" width="18" height="13" rx="2"/><path d="M8 2.5l4 3.5 4-3.5"/><path d="M8 21h8"/>',
		radio: '<circle cx="12" cy="12" r="2"/><path d="M8.5 15.5a5 5 0 0 1 0-7M15.5 8.5a5 5 0 0 1 0 7"/><path d="M5.6 18.4a9 9 0 0 1 0-12.8M18.4 5.6a9 9 0 0 1 0 12.8"/>',
		news: '<path d="M4 5h13v15H6a2 2 0 0 1-2-2z"/><path d="M17 9h3v9a2 2 0 0 1-2 2"/><path d="M7 9h7M7 12h7M7 15h4"/>',
		camera: '<rect x="3" y="3" width="18" height="18" rx="5"/><circle cx="12" cy="12" r="4"/><circle cx="17.2" cy="6.8" r=".6"/>',
		crypto: '<circle cx="12" cy="12" r="9"/><path d="M9 7.5h4.5a2.25 2.25 0 0 1 0 4.5H9h5a2.25 2.25 0 0 1 0 4.5H9z"/><path d="M10.5 6v1.5M10.5 16.5V18M13 6v1.5M13 16.5V18"/>',
		onion: '<circle cx="12" cy="13" r="7"/><path d="M12 6c-2.5 2-3.5 4.5-3.5 7s1 5 3.5 7"/><path d="M12 6c2.5 2 3.5 4.5 3.5 7s-1 5-3.5 7"/><path d="M12 6V3"/><path d="M12 3c1.5 0 2.5-.7 3-1.5"/>'
	};

	const WALLPAPERS = { padrao: 'Padrão', noite: 'Noite', oceano: 'Oceano', brasa: 'Brasa', floresta: 'Floresta', grafite: 'Grafite' };
	const SCALES = [{ value: 90, label: 'P' }, { value: 100, label: 'M' }, { value: 110, label: 'G' }];
	const DOCK_MAX = 6;
	const DOCK_DEFAULT = 5;
	// Apps mantidos em memória (multitarefa); o mais antigo fecha quando passa disso.
	const RUNNING_MAX = 6;
	const RECENT_MAX = 6;

	const $ = function (id) { return document.getElementById(id); };
	const els = {
		root: $('tablet'), screen: $('tablet-screen'), dim: $('tablet-dim'), profile: $('tablet-profile'), clock: $('tablet-clock'),
		heroClock: $('tablet-hero-clock'), heroDate: $('tablet-hero-date'), count: $('tablet-count'), openCount: $('tablet-open-count'),
		recent: $('tablet-recent'), search: $('tablet-search'), home: $('tablet-home'), grid: $('tablet-grid'),
		view: $('tablet-view'), icon: $('tablet-app-icon'), title: $('tablet-app-title'), kind: $('tablet-app-kind'), apps: $('tablet-apps'),
		back: $('tablet-back'), appClose: $('tablet-app-close'), status: $('tablet-status'),
		dock: $('tablet-dock-apps'), switcherButton: $('tablet-switcher-button'), switcherBadge: $('tablet-switcher-badge'),
		switcher: $('tablet-switcher'), cards: $('tablet-cards'), switcherClear: $('tablet-switcher-clear'),
		control: $('tablet-control'), controlToggle: $('tablet-control-toggle'), brightness: $('tablet-brightness'),
		scales: $('tablet-scales'), walls: $('tablet-walls'), homeButton: $('tablet-home-button'),
		keyPower: $('tablet-key-power'), close: $('tablet-close'), keyUp: $('tablet-key-up'), keyDown: $('tablet-key-down')
	};

	const registry = {};
	const loaded = {};
	// id -> { app, node } dos apps abertos; `running` guarda a ordem de uso (último no fim).
	const containers = {};
	let running = [];
	let recent = [];
	let apps = [];
	let groups = [];
	let prefs = { wallpaper: 'padrao', brightness: 100, scale: 100, dock: null };
	let current = null;
	let isOpen = false;
	let clockTimer = null;
	let statusTimer = null;
	let prefsTimer = null;

	function post(name, body) {
		return fetch('https://' + GetParentResourceName() + '/' + name, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json; charset=UTF-8' },
			body: JSON.stringify(body || {})
		}).then(function (response) { return response.json(); }).catch(function () { return { ok: false, error: 'closed' }; });
	}

	function setStatus(message, kind) {
		els.status.textContent = message || '';
		els.status.className = 'tablet-status' + (kind ? ' is-' + kind : '');
		clearTimeout(statusTimer);
		if (message && kind !== 'error') { statusTimer = setTimeout(function () { setStatus(''); }, 6000); }
	}

	function errorText(code) {
		const fallback = ERRORS[code] || ('Falha: ' + code);
		return (window.CoeUI && typeof window.CoeUI.t === 'function')
			? window.CoeUI.t('tablet.error.' + code, null, fallback)
			: fallback;
	}

	const api = {
		register: function (id, render) { registry[id] = render; },
		call: function (app, action, payload) {
			return post('call', { app: app, action: action, payload: payload || {} });
		},
		nearestVehicle: function () { return post('nearestVehicle'); },
		waypoint: function (x, y) { return post('waypoint', { x: x, y: y }); },
		// Câmera do aparelho: o tablet some enquanto o jogador fotografa e volta com { ok, image }.
		camera: function () { return post('camera'); },
		// Envia uma foto (data URI JPEG) ao servidor fora do canal das ações; devolve { ok, token }.
		upload: function (image) { return post('upload', { image: image }); },
		// Recarrega a lista de apps (ex.: depois de instalar pela loja) sem sair do app aberto.
		refresh: function () { return post('refresh'); },
		icon: function (node, app) { paintIcon(node, app); },
		status: setStatus,
		errorText: errorText,
		device: 'tablet'
	};
	window.CoeTablet = api;

	function findApp(id) {
		return apps.find(function (app) { return app.id === id; });
	}

	function el(tag, className, text) {
		const node = document.createElement(tag);
		if (className) { node.className = className; }
		if (text !== undefined) { node.textContent = text; }
		return node;
	}

	function paintIcon(tile, app) {
		tile.style.removeProperty('--app-color');
		if (/^#[0-9a-fA-F]{3,8}$/.test(app.color || '')) { tile.style.setProperty('--app-color', app.color); }
		if (ICONS[app.icon]) {
			tile.innerHTML = '<svg viewBox="0 0 24 24">' + ICONS[app.icon] + '</svg>';
		} else {
			tile.textContent = (app.label || app.id || '?').charAt(0).toUpperCase();
		}
	}

	// Preferências do aparelho ----------------------------------------------------------------------------

	function savePrefs() {
		clearTimeout(prefsTimer);
		prefsTimer = setTimeout(function () { post('prefs', prefs); }, 400);
	}

	function applyPrefs() {
		els.screen.dataset.wallpaper = WALLPAPERS[prefs.wallpaper] ? prefs.wallpaper : 'padrao';
		const brightness = Math.max(30, Math.min(100, Number(prefs.brightness) || 100));
		els.dim.style.opacity = String(((100 - brightness) / 70) * 0.6);
		els.brightness.value = String(brightness);
		const scale = SCALES.some(function (s) { return s.value === prefs.scale; }) ? prefs.scale : 100;
		els.screen.style.setProperty('--tablet-zoom', String(scale / 100));
		els.scales.querySelectorAll('button').forEach(function (button) { button.classList.toggle('is-active', Number(button.dataset.scale) === scale); });
		els.walls.querySelectorAll('button').forEach(function (button) { button.classList.toggle('is-active', button.dataset.wallpaper === els.screen.dataset.wallpaper); });
	}

	function setPref(patch) {
		prefs = Object.assign({}, prefs, patch);
		applyPrefs();
		savePrefs();
	}

	function buildControls() {
		SCALES.forEach(function (scale) {
			const button = el('button', null, scale.label);
			button.type = 'button';
			button.dataset.scale = String(scale.value);
			button.title = scale.value + '%';
			button.addEventListener('click', function () { setPref({ scale: scale.value }); });
			els.scales.appendChild(button);
		});
		Object.keys(WALLPAPERS).forEach(function (id) {
			const button = el('button', 'tablet-wall');
			button.type = 'button';
			button.dataset.wallpaper = id;
			button.title = WALLPAPERS[id];
			button.setAttribute('aria-label', WALLPAPERS[id]);
			button.addEventListener('click', function () { setPref({ wallpaper: id }); });
			els.walls.appendChild(button);
		});
		els.brightness.addEventListener('input', function () { setPref({ brightness: Number(els.brightness.value) }); });
	}

	function nudgeBrightness(delta) {
		setPref({ brightness: Math.max(30, Math.min(100, (Number(prefs.brightness) || 100) + delta)) });
		setStatus('Brilho ' + prefs.brightness + '%');
	}

	// Dock ------------------------------------------------------------------------------------------------

	function dockIds() {
		const ids = Array.isArray(prefs.dock) ? prefs.dock : apps.slice(0, DOCK_DEFAULT).map(function (app) { return app.id; });
		return ids.filter(function (id) { return findApp(id); }).slice(0, DOCK_MAX);
	}

	function togglePin(id) {
		const ids = dockIds();
		const index = ids.indexOf(id);
		if (index >= 0) {
			ids.splice(index, 1);
			setStatus('Removido da dock.');
		} else if (ids.length >= DOCK_MAX) {
			setStatus('A dock já tem ' + DOCK_MAX + ' aplicativos.', 'error');
			return;
		} else {
			ids.push(id);
			setStatus('Fixado na dock.');
		}
		setPref({ dock: ids });
		paintLauncher();
	}

	// Tela inicial ------------------------------------------------------------------------------------------

	function iconFor(app, compact) {
		const button = el('button', 'tablet-icon');
		button.type = 'button';
		button.dataset.app = app.id;
		button.title = app.label;
		const tile = el('i');
		paintIcon(tile, app);
		button.append(tile, el('span', null, app.label));
		if (!compact && app.kind && app.kind !== app.label) { button.appendChild(el('small', null, app.kind)); }
		button.classList.toggle('is-running', Boolean(containers[app.id]));
		button.classList.toggle('is-pinned', dockIds().indexOf(app.id) >= 0);
		button.addEventListener('click', function () { openApp(app.id); });
		button.addEventListener('contextmenu', function (event) { event.preventDefault(); togglePin(app.id); });
		return button;
	}

	function matches(app, query) {
		if (!query) { return true; }
		const text = ((app.label || '') + ' ' + (app.kind || '')).toLowerCase();
		return text.indexOf(query) >= 0;
	}

	function paintGrid() {
		const query = els.search.value.trim().toLowerCase();
		els.grid.replaceChildren();
		const visible = apps.filter(function (app) { return matches(app, query); });
		if (visible.length === 0) {
			els.grid.appendChild(el('p', 'tablet-empty', apps.length ? 'Nenhum aplicativo encontrado.' : 'Nenhum aplicativo disponível.'));
			return;
		}
		const order = groups.map(function (group) { return group.id; });
		const sections = {};
		visible.forEach(function (app) {
			const key = order.indexOf(app.group) >= 0 ? app.group : (order[0] || 'personal');
			if (!sections[key]) {
				const group = groups.find(function (g) { return g.id === key; });
				const section = el('div', 'tablet-section');
				const title = el('h2', null, group ? group.label : '');
				const count = el('b');
				title.appendChild(count);
				const grid = el('div', 'tablet-grid');
				section.append(title, grid);
				sections[key] = { section: section, grid: grid, count: count, total: 0 };
			}
			sections[key].grid.appendChild(iconFor(app));
			sections[key].total += 1;
		});
		(order.length ? order : Object.keys(sections)).forEach(function (key) {
			const entry = sections[key];
			if (!entry) { return; }
			entry.count.textContent = String(entry.total);
			els.grid.appendChild(entry.section);
		});
	}

	function paintDock() {
		els.dock.replaceChildren();
		dockIds().forEach(function (id) { els.dock.appendChild(iconFor(findApp(id), true)); });
		const open = running.length;
		els.switcherBadge.hidden = open === 0;
		els.switcherBadge.textContent = String(open);
		els.openCount.textContent = String(open);
	}

	function paintRecent() {
		els.recent.replaceChildren();
		const list = recent.map(findApp).filter(Boolean);
		if (list.length === 0) {
			els.recent.appendChild(el('p', 'tablet-recent-empty', 'Os apps que você usar aparecem aqui.'));
			return;
		}
		list.forEach(function (app) {
			const item = el('button', 'tablet-recent-item');
			item.type = 'button';
			const tile = el('i');
			paintIcon(tile, app);
			item.append(tile, el('span', null, app.label));
			item.addEventListener('click', function () { openApp(app.id); });
			els.recent.appendChild(item);
		});
	}

	function paintLauncher() {
		els.count.textContent = String(apps.length);
		paintGrid();
		paintDock();
		paintRecent();
		if (!els.switcher.hidden) { paintCards(); }
	}

	// Apps e multitarefa ------------------------------------------------------------------------------------

	// Apps com instância (ex.: um por negócio) chamam pelo id base; o tablet encaminha para o id da instância.
	function appApi(app) {
		if (!app.base || app.base === app.id) { return api; }
		return Object.assign({}, api, {
			call: function (target, action, payload) {
				return api.call(target === app.base ? app.id : target, action, payload);
			}
		});
	}

	function touch(id) {
		running = running.filter(function (other) { return other !== id; });
		running.push(id);
		recent = [id].concat(recent.filter(function (other) { return other !== id; })).slice(0, RECENT_MAX);
	}

	function killApp(id) {
		const entry = containers[id];
		if (entry) { entry.node.remove(); }
		delete containers[id];
		running = running.filter(function (other) { return other !== id; });
		if (current === id) { current = null; }
	}

	function showView(app) {
		els.title.textContent = app.label;
		els.kind.textContent = app.kind && app.kind !== app.label ? app.kind : '';
		paintIcon(els.icon, app);
		els.home.hidden = true;
		els.view.hidden = false;
		els.root.classList.add('is-in-app');
	}

	function openApp(id) {
		const app = findApp(id);
		if (!app) { return; }
		closeOverlays();
		setStatus('');
		Object.keys(containers).forEach(function (other) { containers[other].node.hidden = other !== id; });
		current = id;
		showView(app);
		if (!containers[id]) {
			while (running.length >= RUNNING_MAX) { killApp(running[0]); }
			const node = el('div', 'tablet-app');
			node.dataset.app = id;
			els.apps.appendChild(node);
			containers[id] = { app: app, node: node };
			const renderer = registry[app.base || app.id];
			if (renderer) {
				try {
					renderer(node, appApi(app));
				} catch (error) {
					setStatus(errorText('app_error'), 'error');
				}
			} else {
				setStatus(errorText('app_unavailable'), 'error');
			}
		}
		touch(id);
		paintLauncher();
	}

	function showHome() {
		closeOverlays();
		current = null;
		Object.keys(containers).forEach(function (id) { containers[id].node.hidden = true; });
		setStatus('');
		els.view.hidden = true;
		els.home.hidden = false;
		els.root.classList.remove('is-in-app');
		paintLauncher();
	}

	function closeCurrent() {
		if (!current) { return; }
		killApp(current);
		showHome();
	}

	function paintCards() {
		els.cards.replaceChildren();
		const list = running.slice().reverse().map(function (id) { return containers[id] && containers[id].app; }).filter(Boolean);
		els.switcherClear.disabled = list.length === 0;
		if (list.length === 0) {
			els.cards.appendChild(el('p', 'tablet-empty', 'Nenhum aplicativo aberto.'));
			return;
		}
		list.forEach(function (app) {
			const card = el('div', 'tablet-card' + (app.id === current ? ' is-current' : ''));
			card.tabIndex = 0;
			const head = el('div', 'tablet-card-head');
			const tile = el('i');
			paintIcon(tile, app);
			const close = el('button', 'tablet-card-close', '✕');
			close.type = 'button';
			close.title = 'Fechar';
			close.addEventListener('click', function (event) {
				event.stopPropagation();
				killApp(app.id);
				paintLauncher();
				paintCards();
			});
			head.append(tile, el('strong', null, app.label), close);
			card.append(head, el('div', 'tablet-card-body', app.kind && app.kind !== app.label ? app.kind : 'Aberto'));
			card.addEventListener('click', function () { openApp(app.id); });
			els.cards.appendChild(card);
		});
	}

	function toggleSwitcher(show) {
		const open = show === undefined ? els.switcher.hidden : show;
		els.control.hidden = true;
		els.controlToggle.classList.remove('is-active');
		els.switcher.hidden = !open;
		els.switcherButton.classList.toggle('is-active', open);
		if (open) { paintCards(); }
	}

	function toggleControl(show) {
		const open = show === undefined ? els.control.hidden : show;
		els.switcher.hidden = true;
		els.switcherButton.classList.remove('is-active');
		els.control.hidden = !open;
		els.controlToggle.classList.toggle('is-active', open);
	}

	function closeOverlays() {
		toggleSwitcher(false);
		toggleControl(false);
	}

	// Abrir, fechar e perfil ---------------------------------------------------------------------------------

	function tick() {
		const now = new Date();
		const time = String(now.getHours()).padStart(2, '0') + ':' + String(now.getMinutes()).padStart(2, '0');
		els.clock.textContent = time;
		els.heroClock.textContent = time;
		els.heroDate.textContent = now.toLocaleDateString('pt-BR', { weekday: 'long', day: 'numeric', month: 'long' });
	}

	function loadApp(app) {
		return new Promise(function (resolve) {
			if (loaded[app.script]) { resolve(); return; }
			const script = document.createElement('script');
			script.src = app.script;
			script.onload = function () { loaded[app.script] = true; resolve(); };
			script.onerror = function () { resolve(); };
			document.head.appendChild(script);
		});
	}

	function loadScripts() {
		const scripts = apps.filter(function (app, index) { return app.script && apps.findIndex(function (other) { return other.script === app.script; }) === index; });
		return Promise.all(scripts.map(loadApp));
	}

	function setProfile(profile) {
		apps = profile.apps || [];
		groups = profile.groups || [];
		els.profile.textContent = profile.label || '';
		// Apps que o jogador perdeu (emprego, negócio) fecham.
		Object.keys(containers).forEach(function (id) { if (!findApp(id)) { killApp(id); } });
		recent = recent.filter(function (id) { return findApp(id); });
	}

	function refreshed(profile) {
		if (!isOpen) { return; }
		setProfile(profile);
		loadScripts();
		if (current && !findApp(current)) { showHome(); } else { paintLauncher(); }
	}

	function open(profile) {
		if (profile.prefs) { prefs = Object.assign({}, prefs, profile.prefs); }
		setProfile(profile);
		applyPrefs();
		els.search.value = '';
		isOpen = true;
		tick();
		clearInterval(clockTimer);
		clockTimer = setInterval(tick, 15000);
		els.root.classList.add('is-open');
		els.root.setAttribute('aria-hidden', 'false');
		// Volta ao app que estava aberto (multitarefa), ou à tela inicial.
		if (current && findApp(current)) { openApp(current); } else { showHome(); }
		loadScripts().then(function () {
			if (isOpen && profile.launch && findApp(profile.launch)) { openApp(profile.launch); }
		});
	}

	function close() {
		isOpen = false;
		clearInterval(clockTimer);
		closeOverlays();
		els.root.classList.remove('is-open');
		els.root.setAttribute('aria-hidden', 'true');
	}

	buildControls();
	els.back.addEventListener('click', showHome);
	els.homeButton.addEventListener('click', showHome);
	els.appClose.addEventListener('click', closeCurrent);
	els.search.addEventListener('input', paintGrid);
	els.switcherButton.addEventListener('click', function () { toggleSwitcher(); });
	els.switcherClear.addEventListener('click', function () {
		running.slice().forEach(killApp);
		showHome();
	});
	els.controlToggle.addEventListener('click', function () { toggleControl(); });
	els.keyPower.addEventListener('click', function () { post('close'); });
	els.close.addEventListener('click', function () { post('close'); });
	els.keyUp.addEventListener('click', function () { nudgeBrightness(10); });
	els.keyDown.addEventListener('click', function () { nudgeBrightness(-10); });
	document.addEventListener('keydown', function (event) {
		if (event.key !== 'Escape' || !isOpen) { return; }
		if (!els.control.hidden || !els.switcher.hidden) { closeOverlays(); return; }
		if (current) { showHome(); } else { post('close'); }
	});
	window.addEventListener('message', function (event) {
		const message = event.data || {};
		if (message.action === 'open') { open(message.data || {}); }
		if (message.action === 'close') { close(); }
		if (message.action === 'profile') { refreshed(message.data || {}); }
		if (message.action === 'suspend') { els.root.classList.toggle('is-suspended', message.data === true); }
		if (message.action === 'duty') { window.dispatchEvent(new CustomEvent('coe:tabletDuty', { detail: message.data || null })); }
	});
	window.addEventListener('coe:localeChanged', function () {
		if (window.CoeUI && typeof window.CoeUI.translateDOM === 'function') {
			window.CoeUI.translateDOM(document);
		}
	});

	if (window.CoeUI && typeof window.CoeUI.translateDOM === 'function') {
		window.CoeUI.translateDOM(document);
	}
})();
