/*
 * Aviso de interação padrão. Cria o próprio elemento e responde à mensagem NUI
 * { action = 'prompt', data = { title, subtitle, badge?, options = { { key, label } } } | nil }.
 */
(function () {
	'use strict';

	let root = null;
	let title = null;
	let sub = null;
	let badgeEl = null;
	let list = null;

	function build() {
		root = document.createElement('div');
		root.className = 'coe-persp coe-persp-tl it-prompt';
		root.hidden = true;
		const panel = document.createElement('div');
		panel.className = 'coe-persp-panel coe-persp-in it-panel';
		const head = document.createElement('div');
		head.className = 'it-head';
		const badge = document.createElement('div');
		badge.className = 'it-badge';
		badge.setAttribute('aria-hidden', 'true');
		badge.textContent = 'E';
		badgeEl = badge;
		const text = document.createElement('div');
		text.className = 'it-text';
		title = document.createElement('b');
		sub = document.createElement('small');
		text.append(title, sub);
		head.append(badge, text);
		list = document.createElement('ul');
		list.className = 'it-options';
		panel.append(head, list);
		root.append(panel);
		document.body.append(root);
	}

	function show(data) {
		if (!root) { build(); }
		if (!data) { root.hidden = true; return; }
		badgeEl.textContent = data.badge || 'E';
		title.textContent = data.title || '';
		sub.textContent = data.subtitle || '';
		list.replaceChildren();
		(data.options || []).forEach(function (option) {
			const li = document.createElement('li');
			const key = document.createElement('span');
			key.className = 'it-key';
			key.textContent = option.key;
			const label = document.createElement('span');
			label.textContent = option.label;
			li.append(key, label);
			list.append(li);
		});
		root.hidden = false;
	}

	window.addEventListener('message', function (event) {
		const message = event.data || {};
		if (message.action === 'prompt') { show(message.data); }
	});
})();
