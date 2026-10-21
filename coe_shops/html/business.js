// Aba Loja do app do negócio no tablet (coe_businesses carrega nui://coe_shops/html/business.js).
// Mostra prateleira, preços e vendas da loja; abastecer e retirar ficam no balcão (aba Gestão da vitrine).
(function () {
	'use strict';

	const IMAGES = 'nui://coe_inventory/data/images/';
	const METHODS = { cash: 'Dinheiro', wallet: 'Carteira', card: 'Cartão' };

	function el(tag, className, text) {
		const node = document.createElement(tag);
		if (className) { node.className = className; }
		if (text !== undefined && text !== null) { node.textContent = String(text); }
		return node;
	}

	function money(value) { return '$ ' + Number(value || 0).toLocaleString('pt-BR'); }

	function button(label, className, onClick) {
		const node = el('button', 'coe-button ' + (className || ''), label);
		node.type = 'button';
		node.addEventListener('click', onClick);
		return node;
	}

	function kpis(report) {
		const box = el('div', 'shb-kpis');
		[[money(report.today), 'vendas hoje'], [money(report.week), '7 dias (' + report.weekSales + ' vendas)'],
			[typeof report.balance === 'number' ? money(report.balance) : '—', 'caixa do negócio']].forEach(function (pair) {
			const kpi = el('div', 'shb-kpi');
			kpi.append(el('strong', null, pair[0]), el('small', null, pair[1]));
			box.appendChild(kpi);
		});
		return box;
	}

	function productRow(product, info, act) {
		const row = el('div', 'shb-row');
		const image = el('img');
		image.src = IMAGES + product.image;
		image.alt = '';
		image.onerror = function () { image.style.visibility = 'hidden'; };
		const name = el('div', 'shb-name');
		name.append(el('span', null, product.label), el('small', null, 'Tabela ' + money(product.base)));
		const stock = product.stock === null || product.stock === undefined ? '∞' : String(product.stock);
		const stockCell = el('span', 'shb-stock' + (product.stock === 0 ? ' is-empty' : ''), stock);
		const price = el('span', 'shb-price' + (product.custom ? ' is-custom' : ''), money(product.price));
		const edit = el('div', 'shb-edit');
		if (info.access.prices) {
			const input = el('input', 'coe-field');
			input.type = 'number';
			input.min = String(product.min);
			input.max = String(product.max);
			input.step = '1';
			input.value = String(product.price);
			input.title = 'Entre ' + money(product.min) + ' e ' + money(product.max);
			edit.append(input, button('Salvar', 'coe-button--primary', function () {
				act('price', { productId: product.id, price: Number(input.value) });
			}));
			if (product.custom) {
				edit.appendChild(button('Tabela', '', function () { act('price', { productId: product.id, price: false }); }));
			}
		}
		row.append(image, name, stockCell, price, edit);
		return row;
	}

	function render(root, info, ctx) {
		const wrap = el('div', 'shb');
		const card = el('div', 'coe-panel coe-panel--compact tb-card');
		const head = el('div', 'tb-card-head');
		head.append(el('strong', null, info.store.label), el('span', 'coe-badge', info.store.typeLabel));
		card.appendChild(head);
		card.appendChild(el('p', 'shb-note', info.mode === 'staff'
			? 'Loja da staff: estoque sempre cheio e preço de tabela. Passa a ter prateleira e preços próprios quando ganhar um dono.'
			: 'Abastecer e retirar estoque: no balcão da loja (aba Gestão da vitrine), com os itens no inventário.'));
		wrap.appendChild(card);
		if (info.report) { wrap.appendChild(kpis(info.report)); }

		wrap.appendChild(el('div', 'tb-section', 'Prateleira e preços'));
		const table = el('div', 'shb-table');
		const header = el('div', 'shb-row shb-row--head');
		header.append(el('span'), el('span', null, 'Produto'), el('span', null, 'Estoque'), el('span', null, 'Preço'), el('span'));
		table.appendChild(header);
		info.products.forEach(function (product) { table.appendChild(productRow(product, info, ctx.act)); });
		wrap.appendChild(table);

		if (info.report) {
			wrap.appendChild(el('div', 'tb-section', 'Últimas vendas'));
			if (!info.report.sales.length) { wrap.appendChild(el('p', 'shb-note', 'Nenhuma venda ainda.')); }
			info.report.sales.forEach(function (sale) {
				const row = el('div', 'shb-sale');
				const when = new Date(sale.at * 1000).toLocaleString('pt-BR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' });
				row.append(el('span', null, sale.units + (sale.units === 1 ? ' item' : ' itens') + ' · ' + (METHODS[sale.method] || sale.method)),
					el('strong', null, money(sale.total)), el('small', null, when));
				wrap.appendChild(row);
			});
		}
		root.appendChild(wrap);
	}

	window.CoeBusinessShop = { render: render };
})();
