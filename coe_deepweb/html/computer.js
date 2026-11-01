// Computador do coe_deepweb (notebook, desktop e servidor doméstico): tela de bloqueio, área de trabalho e uma
// janela por vez. Os apps se registram como no COE OS (`register(id, render(container, api))`).
(function () {
	'use strict';

	const ERRORS = {
		closed: 'Computador desligado.', timeout: 'Sem resposta do servidor.', rate_limited: 'Calma, muitas ações seguidas.',
		app_unavailable: 'Aplicativo indisponível.', app_error: 'Falha no aplicativo.', locked: 'Computador bloqueado.',
		device_gone: 'Você se afastou do computador.', wrong_password: 'Senha incorreta.', face_not_recognized: 'Rosto não reconhecido. Use a senha.', login_locked: 'Muitas tentativas. Aguarde.',
		invalid_request: 'Pedido inválido.', invalid_payload: 'Dados demais.', not_ready: 'Serviço ainda iniciando.'
	};

	const ICONS = {
		onion: '<circle cx="12" cy="13" r="7"/><path d="M12 6c-2.5 2-3.5 4.5-3.5 7s1 5 3.5 7"/><path d="M12 6c2.5 2 3.5 4.5 3.5 7s-1 5-3.5 7"/><path d="M12 6V3"/><path d="M12 3c1.5 0 2.5-.7 3-1.5"/>',
		crypto: '<circle cx="12" cy="12" r="9"/><path d="M9 7.5h4.5a2.25 2.25 0 0 1 0 4.5H9h5a2.25 2.25 0 0 1 0 4.5H9z"/><path d="M10.5 6v1.5M10.5 16.5V18M13 6v1.5M13 16.5V18"/>'
	};

	const els = {
		root: document.getElementById('pc'),
		lock: document.getElementById('pc-lock'),
		lockTitle: document.getElementById('pc-lock-title'),
		lockInput: document.getElementById('pc-lock-input'),
		lockGo: document.getElementById('pc-lock-go'),
		lockOff: document.getElementById('pc-lock-off'),
		lockFace: document.getElementById('pc-lock-face'),
		lockError: document.getElementById('pc-lock-error'),
		desktop: document.getElementById('pc-desktop'),
		icons: document.getElementById('pc-icons'),
		window: document.getElementById('pc-window'),
		windowIcon: document.getElementById('pc-window-icon'),
		windowTitle: document.getElementById('pc-window-title'),
		windowClose: document.getElementById('pc-window-close'),
		app: document.getElementById('pc-app'),
		model: document.getElementById('pc-model'),
		level: document.getElementById('pc-level'),
		tasks: document.getElementById('pc-tasks'),
		status: document.getElementById('pc-status'),
		clock: document.getElementById('pc-clock'),
		power: document.getElementById('pc-power')
	};

	const registry = {};
	const loaded = {};
	let profile = null;
	let current = null;
	let isOpen = false;
	let clockTimer = null;
	let statusTimer = null;

	function post(name, body) {
		return fetch('https://' + GetParentResourceName() + '/' + name, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json; charset=UTF-8' },
			body: JSON.stringify(body || {})
		}).then(function (response) { return response.json(); }).catch(function () { return { ok: false, error: 'closed' }; });
	}

	function setStatus(message, kind) {
		els.status.textContent = message || '';
		els.status.className = 'pc-status' + (kind ? ' is-' + kind : '');
		clearTimeout(statusTimer);
		if (message) { statusTimer = setTimeout(function () { setStatus(''); }, 6000); }
	}

	function errorText(code) {
		return ERRORS[code] || ('Falha: ' + code);
	}

	function paintIcon(node, app) {
		const svg = ICONS[app.icon || app.id];
		if (svg) {
			node.innerHTML = '<svg viewBox="0 0 24 24">' + svg + '</svg>';
		} else {
			node.textContent = (app.label || app.id || '?').charAt(0).toUpperCase();
		}
	}

	const api = {
		register: function (id, render) { registry[id] = render; },
		call: function (app, action, payload) {
			return post('call', { app: app, action: action, payload: payload || {} }).then(function (result) {
				if (result && (result.error === 'device_gone' || result.error === 'closed')) { setStatus(errorText(result.error), 'error'); }
				return result;
			});
		},
		waypoint: function (x, y) { return post('waypoint', { x: x, y: y }); },
		refresh: function () { return Promise.resolve({ ok: true }); },
		icon: function (node, app) { paintIcon(node, app); },
		status: setStatus,
		errorText: errorText,
		device: 'computer',
		profile: function () { return profile; },
		close: function () { closeComputer(true); }
	};
	window.CoeComputer = api;

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

	function tick() {
		const now = new Date();
		els.clock.textContent = String(now.getHours()).padStart(2, '0') + ':' + String(now.getMinutes()).padStart(2, '0');
	}

	function openApp(id) {
		const app = (profile.apps || []).find(function (entry) { return entry.id === id; });
		if (!app) { return; }
		current = id;
		els.app.replaceChildren();
		els.windowTitle.textContent = app.label;
		paintIcon(els.windowIcon, app);
		els.window.hidden = false;
		paintTasks();
		const render = registry[id];
		if (render) {
			render(els.app, api);
		} else {
			els.app.appendChild(Object.assign(document.createElement('p'), { className: 'tb-empty', textContent: errorText('app_unavailable') }));
		}
	}

	function closeApp() {
		current = null;
		els.app.replaceChildren();
		els.window.hidden = true;
		paintTasks();
	}

	function paintTasks() {
		els.tasks.replaceChildren();
		(profile.apps || []).forEach(function (app) {
			const button = document.createElement('button');
			button.type = 'button';
			button.className = 'pc-task' + (current === app.id ? ' is-active' : '');
			const tile = document.createElement('i');
			tile.className = 'pc-icon-tile';
			paintIcon(tile, app);
			button.append(tile, document.createTextNode(app.label));
			button.addEventListener('click', function () { if (current === app.id) { closeApp(); } else { openApp(app.id); } });
			els.tasks.appendChild(button);
		});
	}

	function buildDesktop() {
		els.icons.replaceChildren();
		(profile.apps || []).forEach(function (app) {
			const button = document.createElement('button');
			button.type = 'button';
			button.className = 'pc-icon';
			const tile = document.createElement('i');
			tile.className = 'pc-icon-tile';
			paintIcon(tile, app);
			const label = document.createElement('span');
			label.textContent = app.label;
			button.append(tile, label);
			button.addEventListener('click', function () { openApp(app.id); });
			els.icons.appendChild(button);
		});
		paintTasks();
	}

	function showDesktop() {
		els.lock.hidden = true;
		els.desktop.hidden = false;
		Promise.all((profile.apps || []).map(function (app) { return loadScript(app.script); })).then(buildDesktop);
	}

	function showLock() {
		els.desktop.hidden = true;
		els.lock.hidden = false;
		els.lockTitle.textContent = profile.label + ' · ' + profile.serial;
		els.lockInput.value = '';
		els.lockError.textContent = '';
		els.lockFace.hidden = !profile.face;
		setTimeout(function () { els.lockInput.focus(); }, 50);
	}

	function tryFace() {
		els.lockFace.classList.add('is-scanning');
		setTimeout(function () {
			api.call('system', 'unlock', { face: true }).then(function (result) {
				els.lockFace.classList.remove('is-scanning');
				if (result && result.ok) {
					profile.locked = false;
					showDesktop();
					setStatus('Desbloqueado pelo reconhecimento facial.', 'success');
					return;
				}
				els.lockError.textContent = errorText(result && result.error);
			});
		}, 900);
	}

	function tryUnlock() {
		api.call('system', 'unlock', { password: els.lockInput.value }).then(function (result) {
			if (result && result.ok) {
				profile.locked = false;
				showDesktop();
				return;
			}
			els.lockError.textContent = errorText(result && result.error);
			els.lockInput.select();
		});
	}

	function openComputer(data) {
		profile = data;
		isOpen = true;
		current = null;
		els.root.dataset.kind = data.kind;
		els.root.setAttribute('aria-hidden', 'false');
		els.root.classList.add('is-open');
		els.model.textContent = data.label;
		els.level.textContent = 'Nível ' + data.level;
		els.window.hidden = true;
		setStatus('');
		tick();
		clearInterval(clockTimer);
		clockTimer = setInterval(tick, 15000);
		if (data.locked) {
			showLock();
		} else {
			showDesktop();
			if (data.faceUnlocked) { setStatus('Desbloqueado pelo reconhecimento facial.', 'success'); }
		}
	}

	function closeComputer(notify) {
		if (!isOpen) { return; }
		isOpen = false;
		closeApp();
		clearInterval(clockTimer);
		els.root.classList.remove('is-open');
		els.root.setAttribute('aria-hidden', 'true');
		if (notify) { post('close'); }
	}

	els.lockGo.addEventListener('click', tryUnlock);
	els.lockInput.addEventListener('keydown', function (event) { if (event.key === 'Enter') { tryUnlock(); } });
	els.lockOff.addEventListener('click', function () { closeComputer(true); });
	els.lockFace.addEventListener('click', tryFace);
	els.power.addEventListener('click', function () { closeComputer(true); });
	els.windowClose.addEventListener('click', closeApp);

	document.addEventListener('keydown', function (event) {
		if (!isOpen || event.key !== 'Escape') { return; }
		if (current) { closeApp(); } else { closeComputer(true); }
	});

	window.addEventListener('message', function (event) {
		const message = event.data || {};
		if (message.action === 'open') { openComputer(message.data || {}); }
		if (message.action === 'close') { closeComputer(false); }
	});
})();
