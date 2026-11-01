// Tablet de corridas (aparelho próprio): hospeda o app "races" com o mesmo contrato do COE OS (register, call,
// waypoint, status, errorText). O app em si fica em app.js.
(function () {
	'use strict';

	const els = {
		pad: document.getElementById('pad'),
		app: document.getElementById('pad-app'),
		status: document.getElementById('pad-status'),
		clock: document.getElementById('pad-clock'),
		close: document.getElementById('pad-close')
	};
	const registry = {};
	let isOpen = false;
	let statusTimer = null;
	let clockTimer = null;

	function resourceName() {
		return typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'coe_races';
	}

	function post(name, body) {
		return fetch('https://' + resourceName() + '/' + name, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json; charset=UTF-8' },
			body: JSON.stringify(body || {})
		}).then(function (response) { return response.json(); }).catch(function () { return { ok: false, error: 'closed' }; });
	}

	function setStatus(message, kind) {
		els.status.textContent = message || '';
		els.status.className = 'pad-status' + (kind ? ' is-' + kind : '');
		clearTimeout(statusTimer);
		if (message) { statusTimer = setTimeout(function () { setStatus(''); }, 6000); }
	}

	function tick() {
		const now = new Date();
		els.clock.textContent = String(now.getHours()).padStart(2, '0') + ':' + String(now.getMinutes()).padStart(2, '0');
	}

	const api = {
		register: function (id, render) { registry[id] = render; },
		call: function (_app, action, payload) { return post('call', { action: action, payload: payload || {} }); },
		waypoint: function (x, y) { return post('waypoint', { x: x, y: y }); },
		refresh: function () { return Promise.resolve({ ok: true }); },
		status: setStatus,
		errorText: function (code) { return 'Falha: ' + code; },
		device: 'racepad',
		close: function () { close(true); }
	};
	window.CoeRacepad = api;

	function open() {
		if (isOpen) { return; }
		isOpen = true;
		els.pad.classList.add('is-open');
		els.pad.setAttribute('aria-hidden', 'false');
		tick();
		clockTimer = setInterval(tick, 10000);
		els.app.innerHTML = '';
		const render = registry.races;
		if (render) { render(els.app, api); }
	}

	function close(notify) {
		if (!isOpen) { return; }
		isOpen = false;
		els.pad.classList.remove('is-open');
		els.pad.setAttribute('aria-hidden', 'true');
		clearInterval(clockTimer);
		setStatus('');
		setTimeout(function () { if (!isOpen) { els.app.innerHTML = ''; } }, 250);
		if (notify) { post('close'); }
	}

	els.close.addEventListener('click', function () { close(true); });
	document.addEventListener('keydown', function (event) {
		if (isOpen && event.key === 'Escape') {
			const modal = els.app.querySelector('.rx-modal');
			if (modal) { modal.remove(); return; }
			close(true);
		}
	});

	window.addEventListener('message', function (event) {
		const data = event.data || {};
		if (data.action === 'open') { open(); }
		else if (data.action === 'close') { close(false); }
	});
})();
