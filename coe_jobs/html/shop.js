// Loja dos empregos (ex.: loja de pesca): vitrine com preço, nível do emprego para desbloquear e quantidade.
// O servidor decide preço, nível e pagamento (dinheiro em mãos ou banco); aqui só se escolhe e pede.
(function () {
	'use strict';

	const overlay = document.getElementById('shop');
	const body = document.getElementById('shop-body');
	const brand = document.getElementById('shop-brand');
	const closeButton = document.getElementById('shop-close');
	const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'coe_jobs';
	let open = false;
	let shop = null;

	function post(name, payload) {
		return fetch('https://' + resource + '/' + name, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json; charset=UTF-8' },
			body: JSON.stringify(payload || {})
		}).catch(function () { return null; });
	}

	function money(value) {
		return '$' + Math.floor(value).toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.');
	}

	function el(tag, className, text) {
		const node = document.createElement(tag);
		if (className) { node.className = className; }
		if (text !== undefined) { node.textContent = text; }
		return node;
	}

	function icon(item) {
		const img = el('img', 'shop-icon');
		img.alt = '';
		const sources = [
			'nui://coe_inventory/data/images/' + encodeURIComponent(item) + '.webp',
			'nui://coe_inventory/data/images/' + encodeURIComponent(item) + '.png'
		];
		let index = 0;
		img.onerror = function () {
			index += 1;
			if (index < sources.length) { img.src = sources[index]; } else { img.style.visibility = 'hidden'; }
		};
		img.src = sources[0];
		return img;
	}

	function card(entry) {
		const node = el('article', 'shop-card' + (entry.locked ? ' is-locked' : ''));
		const head = el('div', 'shop-head');
		head.appendChild(icon(entry.item));
		const title = el('div', 'shop-title');
		title.appendChild(el('strong', null, entry.label));
		title.appendChild(el('span', 'shop-kind', entry.kind === 'rod' ? 'Vara' : entry.kind === 'bait' ? 'Isca' : 'Item'));
		head.appendChild(title);
		head.appendChild(el('b', 'shop-price', money(entry.price)));
		node.appendChild(head);
		if (entry.description) { node.appendChild(el('p', 'shop-desc', entry.description)); }
		if (Array.isArray(entry.stats) && entry.stats.length) {
			const list = el('ul', 'shop-stats');
			entry.stats.forEach(function (line) { list.appendChild(el('li', null, line)); });
			node.appendChild(list);
		}
		const foot = el('div', 'shop-foot');
		if (entry.locked) {
			foot.appendChild(el('span', 'shop-lock', 'Bloqueado · nível ' + entry.level + ' no emprego'));
		} else {
			let quantity = null;
			if (entry.max > 1) {
				quantity = el('input', 'coe-field shop-qty');
				quantity.type = 'number';
				quantity.min = '1';
				quantity.max = String(entry.max);
				quantity.value = String(Math.min(10, entry.max));
				foot.appendChild(quantity);
			} else {
				foot.appendChild(el('span', 'shop-note', entry.level > 1 ? 'Liberado no nível ' + entry.level : 'Uma por compra'));
			}
			const button = el('button', 'coe-button coe-button--primary shop-buy', 'Comprar');
			button.type = 'button';
			button.addEventListener('click', function () {
				let count = 1;
				if (quantity) {
					count = Math.max(1, Math.min(entry.max, parseInt(quantity.value, 10) || 1));
					quantity.value = String(count);
				}
				button.disabled = true;
				setTimeout(function () { button.disabled = false; }, 800);
				post('shopBuy', { jobId: shop.jobId, point: shop.point, item: entry.item, quantity: count });
			});
			foot.appendChild(button);
		}
		node.appendChild(foot);
		return node;
	}

	function render() {
		body.textContent = '';
		brand.textContent = 'COE · ' + (shop.label || 'LOJA').toUpperCase();
		const head = el('div', 'shop-top');
		head.appendChild(el('h2', 'shop-heading', shop.label));
		head.appendChild(el('p', 'shop-sub', shop.job + ': você está no nível ' + shop.level + ' de ' + shop.maxLevel +
			'. Paga em dinheiro vivo; sem ele, no banco. Os itens vão para o inventário.'));
		body.appendChild(head);
		const grid = el('div', 'shop-grid');
		shop.items.forEach(function (entry) { grid.appendChild(card(entry)); });
		body.appendChild(grid);
	}

	function show(data) {
		shop = data;
		render();
		body.scrollTop = 0;
		overlay.classList.remove('is-hidden');
		overlay.setAttribute('aria-hidden', 'false');
		open = true;
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
		if (open && event.key === 'Escape') {
			event.preventDefault();
			hide(true);
		}
	});
	window.addEventListener('message', function (event) {
		const data = event.data || {};
		if (data.action === 'shop:open' && data.shop) {
			show(data.shop);
		} else if (data.action === 'shop:update' && data.shop && open) {
			const scroll = body.scrollTop;
			shop = data.shop;
			render();
			body.scrollTop = scroll;
		} else if (data.action === 'shop:close') {
			hide(false);
		}
	});
})();
