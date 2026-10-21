// NUI do coe_jobs: abre o guia "Como funciona" pedido no NPC e devolve o foco ao fechar.
(function () {
	'use strict';

	const overlay = document.getElementById('guide');
	const body = document.getElementById('guide-body');
	const closeButton = document.getElementById('guide-close');
	const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'coe_jobs';
	let open = false;

	function post(name, payload) {
		return fetch('https://' + resource + '/' + name, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json; charset=UTF-8' },
			body: JSON.stringify(payload || {})
		}).catch(function () { return null; });
	}

	function show(guide) {
		window.CoeJobGuide.render(body, guide);
		body.scrollTop = 0;
		overlay.classList.remove('is-hidden');
		overlay.setAttribute('aria-hidden', 'false');
		open = true;
		closeButton.focus();
	}

	function hide(notify) {
		if (!open) { return; }
		open = false;
		overlay.classList.add('is-hidden');
		overlay.setAttribute('aria-hidden', 'true');
		if (notify) { post('close'); }
	}

	closeButton.addEventListener('click', function () { hide(true); });
	overlay.addEventListener('click', function (event) {
		if (event.target === overlay) { hide(true); }
	});
	window.addEventListener('keydown', function (event) {
		if (open && (event.key === 'Escape' || event.key === 'Backspace')) {
			event.preventDefault();
			hide(true);
		}
	});
	window.addEventListener('message', function (event) {
		const data = event.data || {};
		if (data.action === 'guide:open' && data.guide) {
			show(data.guide);
		} else if (data.action === 'guide:close') {
			hide(false);
		}
	});
})();
