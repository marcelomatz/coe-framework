// Aba Posto do app do negócio no tablet (registrada com coe_businesses:RegisterTab; o app carrega este arquivo).
// Tanques por nível, preços por litro, frota de abastecimento, refinaria e vendas do posto.
(function () {
	'use strict';

	const STATES = { stored: 'Guardado', out: 'Na rua', spawned: 'Na rua', impounded: 'Apreendido', destroyed: 'Destruído' };

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
	function money(value) { return '$ ' + Math.floor(value || 0).toLocaleString('pt-BR'); }
	function liters(value) { return Math.floor(value || 0).toLocaleString('pt-BR') + ' L'; }

	// Texto do requisito de um upgrade: o que falta (vendas e caixa).
	function requirement(next, info) {
		const parts = [money(next.price)];
		if (next.sold > 0) { parts.push(liters(next.sold) + ' vendidos'); }
		const missing = [];
		if (info.stats.sold < next.sold) { missing.push('faltam ' + liters(next.sold - info.stats.sold) + ' vendidos'); }
		if (typeof info.balance === 'number' && info.balance < next.price) { missing.push('caixa insuficiente'); }
		return { text: parts.join(' + '), missing: missing, ok: missing.length === 0 };
	}

	function kpis(info) {
		const box = el('div', 'fub-kpis');
		[[liters(info.stats.sold), 'vendidos (histórico)'], [money(info.stats.today), 'vendas hoje'], [money(info.stats.week), '7 dias'],
			[typeof info.balance === 'number' ? money(info.balance) : '—', 'caixa do posto']].forEach(function (pair) {
			const kpi = el('div', 'fub-kpi');
			kpi.append(el('strong', null, pair[0]), el('small', null, pair[1]));
			box.appendChild(kpi);
		});
		return box;
	}

	function tankRow(fuel, info, act) {
		const row = el('div', 'fub-tank');
		row.style.setProperty('--fuel', fuel.color);
		const name = el('div', 'fub-tank-name');
		name.append(el('strong', null, fuel.label), el('small', null, 'Nível ' + fuel.level + ' de ' + fuel.maxLevel + ' · atacado $ ' + fuel.wholesale.toLocaleString('pt-BR', { minimumFractionDigits: 2 }) + '/L'));
		const gauge = el('div', 'fub-gauge');
		const fill = el('i');
		fill.style.width = Math.min(100, fuel.liters / Math.max(1, fuel.capacity) * 100) + '%';
		gauge.appendChild(fill);
		const level = el('div', 'fub-tank-level');
		level.append(gauge, el('small', null, liters(fuel.liters) + ' / ' + liters(fuel.capacity)));
		const price = el('div', 'fub-price');
		if (info.canManage) {
			const input = el('input', 'coe-field');
			input.type = 'number';
			input.min = String(fuel.min);
			input.max = String(fuel.max);
			input.value = String(fuel.price);
			input.title = 'Entre ' + money(fuel.min) + ' e ' + money(fuel.max) + ' (tabela ' + money(fuel.base) + ')';
			price.append(el('span', null, '$/L'), input, button('Salvar', 'coe-button--primary', function () { act('price', { fuel: fuel.id, price: Number(input.value) }); }));
			if (fuel.custom) { price.appendChild(button('Tabela', '', function () { act('price', { fuel: fuel.id, price: false }); })); }
		} else {
			price.appendChild(el('strong', null, money(fuel.price) + '/L'));
		}
		row.append(el('span', 'fub-swatch'), name, level, price);
		if (info.canManage) {
			const up = el('div', 'fub-upgrade');
			if (fuel.next) {
				const req = requirement(fuel.next, info);
				const go = button('Ampliar para ' + liters(fuel.next.capacity), req.ok ? 'coe-button--primary' : '', function () { act('upgradeTank', { fuel: fuel.id }); });
				go.disabled = !req.ok;
				up.append(go, el('small', null, req.text + (req.missing.length ? ' · ' + req.missing.join(', ') : '')));
			} else {
				up.appendChild(el('small', null, 'Tanque no nível máximo.'));
			}
			row.appendChild(up);
		}
		return row;
	}

	function fleetPane(info, act) {
		const box = el('div', 'fub-fleet');
		const tiers = el('div', 'fub-tiers');
		info.fleet.tiers.forEach(function (tier) {
			const card = el('div', 'fub-tier' + (tier.owned ? ' is-owned' : ''));
			card.append(el('strong', null, tier.label), el('small', null, liters(tier.capacity) + ' de carga'),
				el('span', 'fub-tier-tag', tier.owned ? 'Na frota' : money(tier.price) + (tier.sold ? ' + ' + liters(tier.sold) + ' vendidos' : '')));
			tiers.appendChild(card);
		});
		box.appendChild(tiers);
		if (info.canManage && info.fleet.next) {
			const req = requirement(info.fleet.next, info);
			const buy = button('Comprar ' + info.fleet.next.label, req.ok ? 'coe-button--primary' : '', function () { act('upgradeFleet', {}); });
			buy.disabled = !req.ok;
			const line = el('div', 'fub-buy');
			line.append(buy, el('small', null, req.text + (req.missing.length ? ' · ' + req.missing.join(', ') : '') + '. O veículo vai para a garagem de frota do posto.'));
			box.appendChild(line);
		}
		if (info.fleet.vehicles.length === 0) {
			box.appendChild(el('p', 'fub-note', 'Nenhum veículo de abastecimento ainda.'));
		}
		info.fleet.vehicles.forEach(function (vehicle) {
			const line = el('div', 'fub-vehicle');
			line.append(el('strong', null, vehicle.label + (vehicle.plate ? ' · ' + vehicle.plate : '')),
				el('span', null, liters(vehicle.liters) + ' / ' + liters(vehicle.capacity) + ' carregados'),
				el('small', null, STATES[vehicle.state] || vehicle.state || ''));
			box.appendChild(line);
		});
		return box;
	}

	const ERRORS = {
		not_a_station: 'Este negócio não é um posto.', staff_station: 'Posto da staff: abastecimento automático.',
		not_enough_sales: 'O posto ainda não vendeu o suficiente para isso.', max_level: 'Já está no nível máximo.',
		no_fleet_garage: 'O posto não tem garagem de frota. Peça à staff para criar uma.', unknown_fuel: 'Combustível desconhecido.',
		station_closed: 'Posto fechado.', invalid_price: 'Preço fora da faixa permitida.', garages_unavailable: 'Garagens indisponíveis no momento.'
	};

	function render(root, info, api) {
		const ctx = {
			act: function (op, payload) {
				api.request(op, payload).then(function (result) {
					if (!result.ok) { api.status(api.errorText(result.error), 'error'); return; }
					api.status(op === 'upgradeFleet' ? 'Veículo comprado' + (result.plate ? ' (placa ' + result.plate + ')' : '') + '. Está na garagem de frota do posto.' : (op === 'upgradeTank' ? 'Tanque ampliado.' : 'Preço atualizado.'), 'ok');
					api.update(result);
				});
			},
			gps: function (x, y) { api.gps(x, y, 'Refinaria marcada no GPS.'); }
		};
		const wrap = el('div', 'fub');
		wrap.style.setProperty('--brand', (info.station.theme && info.station.theme.primary) || '#4a5360');
		const card = el('div', 'coe-panel coe-panel--compact tb-card fub-head');
		const head = el('div', 'tb-card-head');
		head.append(el('strong', null, info.station.label), el('span', 'coe-badge', info.station.brand === 'none' ? 'Sem bandeira' : info.station.brandLabel));
		card.appendChild(head);
		card.appendChild(el('p', 'fub-note', info.mode === 'staff'
			? 'Posto da staff: bombas com abastecimento automático. Tanques, preços e frota passam a valer quando o posto tiver dono.'
			: 'Leve a frota até a refinaria, carregue (o atacado sai do caixa do posto) e descarregue no posto pelo alvo do veículo.'));
		wrap.append(card, kpis(info));
		wrap.appendChild(el('div', 'tb-section', 'Tanques e preços'));
		const tanks = el('div', 'fub-tanks');
		info.fuels.forEach(function (fuel) { tanks.appendChild(tankRow(fuel, info, ctx.act)); });
		wrap.appendChild(tanks);
		wrap.appendChild(el('div', 'tb-section', 'Frota de abastecimento'));
		wrap.appendChild(fleetPane(info, ctx.act));
		const refinery = el('div', 'fub-refinery');
		refinery.append(el('strong', null, info.refinery.label), el('small', null, 'Onde a frota carrega combustível.'));
		if (ctx.gps) { refinery.appendChild(button('GPS', '', function () { ctx.gps(info.refinery.x, info.refinery.y); })); }
		wrap.appendChild(refinery);
		root.appendChild(wrap);
	}

	window.CoeBusinessTabs = window.CoeBusinessTabs || {};
	window.CoeBusinessTabs.fuel = { errors: ERRORS, render: render };
})();
