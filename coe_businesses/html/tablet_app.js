(function () {
	'use strict';

	const ERRORS = {
		not_on_duty: 'Bata o ponto neste negócio para usar o tablet.', forbidden: 'Seu cargo não permite isso.',
		not_ready: 'Serviço ainda iniciando.', no_character: 'Personagem não carregado.',
		invalid_grade: 'Cargo inválido.', grade_too_high: 'Você só gerencia cargos abaixo do seu.',
		target_not_online: 'Cidadão não está online.', target_not_found: 'Cidadão não encontrado (confira o ID).',
		is_owner: 'O proprietário não entra na equipe.', already_staff: 'Já faz parte da equipe.',
		unknown_member: 'Funcionário não encontrado.', same_character: 'Você não pode fazer isso consigo mesmo.',
		multiple_jobs: 'Este negócio ou o outro emprego do cidadão é de dedicação exclusiva.',
		invalid_amount: 'Valor inválido.', insufficient_funds: 'Saldo insuficiente.', balance_limit: 'Limite de saldo atingido.',
		economy_unavailable: 'Economia indisponível.', database_error: 'Falha no banco de dados.', unknown_action: 'Ação desconhecida.',
		garages_unavailable: 'Garagens indisponíveis.', invalid_vehicle: 'Veículo inválido.', not_in_fleet: 'Este veículo não é da frota deste negócio.',
		properties_unavailable: 'Garagens e imóveis indisponíveis.', offer_pending: 'Este cidadão já tem uma proposta pendente.',
		already_partner: 'Já é sócio deste negócio.', partner_limit: 'Limite de sócios atingido.', unknown_partner: 'Sócio não encontrado.',
		invalid_partners: 'Lista de sócios inválida.', bank_unavailable: 'Banco indisponível no momento.',
		shop_unavailable: 'Lojas indisponíveis no momento.', not_a_store: 'Este negócio não é uma loja.', invalid_price: 'Preço fora da faixa permitida.',
		staff_store: 'Loja da staff: estoque e preço automáticos.', unknown_product: 'Produto não encontrado.', store_closed: 'Loja fechada.'
	};

	// Conta bancária empresarial: telas do coe_banking (business.js + bank-ui.css), carregadas uma vez.
	let bankAssets = null;
	function loadBankAssets() {
		if (window.CoeBusinessBank) { return Promise.resolve(true); }
		if (bankAssets) { return bankAssets; }
		bankAssets = new Promise(function (resolve) {
			if (!document.querySelector('link[data-coe-bank]')) {
				const link = document.createElement('link');
				link.rel = 'stylesheet';
				link.href = 'nui://coe_banking/html/bank-ui.css';
				link.dataset.coeBank = '1';
				document.head.appendChild(link);
			}
			const script = document.createElement('script');
			script.src = 'nui://coe_banking/html/business.js';
			script.onload = function () { resolve(Boolean(window.CoeBusinessBank)); };
			script.onerror = function () { bankAssets = null; resolve(false); };
			document.head.appendChild(script);
		});
		return bankAssets;
	}

	// Aba Loja: tela do coe_shops (business.js + business.css), carregada uma vez.
	let shopAssets = null;
	function loadShopAssets() {
		if (window.CoeBusinessShop) { return Promise.resolve(true); }
		if (shopAssets) { return shopAssets; }
		shopAssets = new Promise(function (resolve) {
			if (!document.querySelector('link[data-coe-shop]')) {
				const link = document.createElement('link');
				link.rel = 'stylesheet';
				link.href = 'nui://coe_shops/html/business.css';
				link.dataset.coeShop = '1';
				document.head.appendChild(link);
			}
			const script = document.createElement('script');
			script.src = 'nui://coe_shops/html/business.js';
			script.onload = function () { resolve(Boolean(window.CoeBusinessShop)); };
			script.onerror = function () { shopAssets = null; resolve(false); };
			document.head.appendChild(script);
		});
		return shopAssets;
	}

	const VEHICLE_STATES = { stored: 'Guardado', out: 'Na rua', spawned: 'Na rua', impounded: 'Apreendido', destroyed: 'Destruído' };

	const CATEGORIES = {
		mechanic: 'Mecânica', shop: 'Loja', gas_station: 'Posto', restaurant: 'Restaurante', other: 'Negócio',
		police: 'Delegacia', ems: 'Hospital', media: 'Mídia'
	};

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

	function field(placeholder, max, type) {
		const node = el('input', 'coe-field');
		node.type = type || 'text';
		node.maxLength = max || 100;
		node.placeholder = placeholder;
		return node;
	}

	function money(value) { return '$ ' + Number(value || 0).toLocaleString('pt-BR'); }

	window.CoeTablet.register('business', function (root, tablet) {
		const TABS = [
			['overview', 'Resumo'], ['shop', 'Loja'], ['bank', 'Banco'], ['finance', 'Financeiro'], ['staff', 'Equipe'], ['partners', 'Sócios'], ['access', 'Acessos'],
			['structure', 'Estrutura'], ['fleet', 'Frota'], ['properties', 'Propriedades']
		];
		let tab = 'overview';
		// Banco: null = ainda não testado; true = conta empresarial do coe_banking; false = sem banco (usa Financeiro).
		let bankOk = null;
		let bankTab = 'summary';
		let busy = false;
		let can = { funds: false, staff: false };
		const data = {};

		function errorText(code) { return ERRORS[code] || tablet.errorText(code); }
		function panel(className) { return el('div', 'coe-panel coe-panel--compact ' + (className || '')); }
		function section(title) { return el('div', 'tb-section', title); }
		function empty(text) { return el('p', 'tb-empty', text); }

		function row(label, value) {
			const line = el('div', 'tb-line');
			line.appendChild(el('span', '', label));
			line.appendChild(el('span', 'tb-muted', value));
			return line;
		}

		function call(action, payload, done) {
			if (busy) { return; }
			busy = true;
			tablet.call('business', action, payload || {}).then(function (result) {
				busy = false;
				if (!result || !result.ok) { tablet.status(errorText(result && result.error), 'error'); return; }
				done(result);
			});
		}

		// Operações da conta empresarial: a resposta sempre traz a conta atualizada (mesmo com erro).
		function bankCall(payload) {
			if (busy) { return; }
			busy = true;
			tablet.call('business', 'bank', payload).then(function (result) {
				busy = false;
				if (result && result.bank) {
					data.bank = result.bank;
					bankOk = true;
				} else if (result && result.error === 'bank_unavailable') {
					bankOk = false;
					tab = 'finance';
					load('finance');
					return;
				}
				if (!result || !result.ok) {
					tablet.status((result && result.message) || errorText(result && result.error), 'error');
				} else if (payload.op !== 'overview' && payload.op !== 'statement') {
					tablet.status('Operação concluída.', 'ok');
				}
				view();
			});
		}

		function load(name) {
			tab = name;
			if (name === 'shop') {
				loadShopAssets().then(function (ok) {
					if (!ok) { tablet.status(errorText('shop_unavailable'), 'error'); return; }
					call('shop', { op: 'overview' }, function (result) { data.shop = result; view(); });
				});
				return;
			}
			if (name === 'bank') {
				loadBankAssets().then(function (ok) {
					if (!ok) { bankOk = false; load('finance'); return; }
					bankCall({ op: 'overview' });
				});
				return;
			}
			call(name, {}, function (result) {
				data[name] = result;
				if (name === 'overview') { can = result.can || can; }
				view();
			});
		}

		function reload() { setTimeout(function () { load(tab); }, 350); }

		function tabs() {
			const bar = el('div', 'tb-tabs');
			TABS.forEach(function (entry) {
				const hidden = (entry[0] === 'bank' && bankOk === false) || (entry[0] === 'finance' && (bankOk !== false || !can.funds))
					|| (data.overview && entry[0] === 'access' && !can.staff)
					|| (entry[0] === 'shop' && !(data.overview && data.overview.business.shop));
				if (hidden) { return; }
				bar.appendChild(button(entry[1], 'tb-tab' + (tab === entry[0] ? ' is-active' : ''), function () { load(entry[0]); }));
			});
			return bar;
		}

		function overviewView() {
			const info = data.overview.business;
			const card = panel('tb-card');
			const head = el('div', 'tb-card-head');
			head.appendChild(el('strong', '', info.label));
			head.appendChild(el('span', 'coe-badge', CATEGORIES[info.category] || 'Negócio'));
			card.appendChild(head);
			card.appendChild(row('Seu cargo', info.grade || '-'));
			card.appendChild(row('Proprietário', info.owner || '-'));
			card.appendChild(row('Equipe', info.staffCount + ' (' + info.onDuty + ' de ponto)'));
			if (info.balance !== undefined) { card.appendChild(row('Caixa', money(info.balance))); }
			card.appendChild(row('Mais de um emprego', info.rules && info.rules.multiJob === false ? 'Não (dedicação exclusiva)' : 'Permitido'));
			root.appendChild(card);
		}

		function amountForm(label, action) {
			const form = el('div', 'tb-toolbar');
			const amount = field(label, 12, 'number');
			amount.min = '1';
			form.appendChild(amount);
			form.appendChild(button(label, 'coe-button--primary', function () {
				call(action, { amount: Number(amount.value) }, function () {
					tablet.status('Operação concluída.', 'ok');
					reload();
				});
			}));
			return form;
		}

		function financeView() {
			const info = data.finance;
			const card = panel('tb-card');
			card.appendChild(row('Saldo da sociedade', money(info.balance)));
			card.appendChild(row('Folha por ciclo', money(info.payroll)));
			root.appendChild(card);
			root.appendChild(section('Movimentar'));
			root.appendChild(amountForm('Depositar', 'deposit'));
			root.appendChild(amountForm('Sacar', 'withdraw'));
			root.appendChild(section('Últimos lançamentos'));
			if (!info.ledger || info.ledger.length === 0) { root.appendChild(empty('Nenhum lançamento.')); }
			(info.ledger || []).forEach(function (entry) {
				root.appendChild(row(entry.reason + (entry.created_at ? ' - ' + entry.created_at : ''), (Number(entry.delta) > 0 ? '+' : '') + money(entry.delta)));
			});
		}

		function gradeSelect(grades, current) {
			const select = el('select', 'coe-field');
			grades.forEach(function (grade) {
				const option = el('option', '', grade.label);
				option.value = grade.id;
				if (grade.id === current) { option.selected = true; }
				select.appendChild(option);
			});
			return select;
		}

		function staffView() {
			const info = data.staff;
			if (info.canManage) {
				root.appendChild(section('Contratar'));
				const form = el('div', 'tb-toolbar');
				const stateId = field('ID do cidadão (online)', 16);
				const grade = gradeSelect(info.grades, info.grades[0] && info.grades[0].id);
				form.appendChild(stateId);
				form.appendChild(grade);
				form.appendChild(button('Contratar', 'coe-button--primary', function () {
					call('hire', { stateId: stateId.value.trim(), grade: grade.value }, function () { tablet.status('Proposta enviada. Aguardando o aceite do cidadão.', 'ok'); reload(); });
				}));
				root.appendChild(form);
			}
			root.appendChild(section('Equipe (' + info.staff.length + ')'));
			if (info.staff.length === 0) { root.appendChild(empty('Ninguém na equipe.')); }
			info.staff.forEach(function (member) {
				const line = row(member.name + (member.onDuty ? ' - de ponto' : ''), (member.gradeLabel || '-') + (member.salary !== undefined ? ' - ' + money(member.salary) : ''));
				if (info.canManage && info.grades.length > 0) {
					const select = gradeSelect(info.grades, member.grade);
					select.addEventListener('change', function () {
						call('setGrade', { characterId: member.characterId, grade: select.value }, function () { tablet.status('Cargo atualizado.', 'ok'); reload(); });
					});
					line.appendChild(select);
				}
				if (info.canManage) {
					line.appendChild(button('Demitir', '', function () {
						call('fire', { characterId: member.characterId }, function () { tablet.status('Funcionário demitido.', 'ok'); reload(); });
					}));
				}
				root.appendChild(line);
			});
		}

		function partnersView() {
			const info = data.partners;
			root.appendChild(el('p', 'tb-muted', 'Sócios respondem pelas dívidas do negócio junto com o proprietário (empréstimos empresariais). Ser sócio não dá acesso de trabalho.'));
			if (info.canManage) {
				root.appendChild(section('Convidar sócio'));
				const form = el('div', 'tb-toolbar');
				const stateId = field('ID do cidadão (online)', 16);
				form.appendChild(stateId);
				form.appendChild(button('Convidar', 'coe-button--primary', function () {
					call('addPartner', { stateId: stateId.value.trim() }, function () { tablet.status('Convite enviado. Aguardando o aceite do cidadão.', 'ok'); reload(); });
				}));
				root.appendChild(form);
			}
			root.appendChild(row('Proprietário', info.owner || '-'));
			root.appendChild(section('Sócios (' + info.partners.length + ')'));
			if (info.partners.length === 0) { root.appendChild(empty('Nenhum sócio.')); }
			info.partners.forEach(function (partner) {
				const line = row(partner.name, 'Sócio');
				if (info.canManage) {
					line.appendChild(button('Remover', '', function () {
						call('removePartner', { characterId: partner.characterId }, function () { tablet.status('Sócio removido. Dívidas já contratadas continuam com ele.', 'ok'); reload(); });
					}));
				}
				root.appendChild(line);
			});
		}

		function accessView() {
			const info = data.access;
			root.appendChild(section('Cargos e permissões'));
			if (info.grades.length === 0) { root.appendChild(empty('Este negócio não tem cargos.')); return; }
			if (info.ownerAccess) { root.appendChild(el('p', 'tb-muted', 'O proprietário tem todas as permissões.')); }
			info.grades.forEach(function (grade) {
				const card = panel('tb-card');
				card.appendChild(el('strong', '', grade.label + ' (nível ' + grade.level + ')'));
				info.permissions.forEach(function (permission) {
					card.appendChild(row(permission.label, grade.granted[permission.name] ? 'Sim' : 'Não'));
				});
				root.appendChild(card);
			});
		}

		function gpsButton(x, y) {
			return button('GPS', '', function () {
				tablet.waypoint(x, y).then(function (result) {
					tablet.status(result && result.ok ? 'Local marcado no GPS.' : 'Não foi possível marcar o GPS.', result && result.ok ? 'ok' : 'error');
				});
			});
		}

		function structureView() {
			const info = data.structure;
			const card = panel('tb-card');
			const head = el('div', 'tb-card-head');
			head.appendChild(el('strong', '', 'Área do negócio'));
			head.appendChild(gpsButton(info.area.x, info.area.y));
			card.appendChild(head);
			card.appendChild(row('Formato', info.area.kind === 'circle' ? 'Círculo (' + Math.round(info.area.radius) + ' m)' : 'Polígono (' + info.area.points + ' pontos)'));
			root.appendChild(card);
			root.appendChild(section('Pontos (' + info.stations.length + ')'));
			if (info.stations.length === 0) { root.appendChild(empty('Nenhum ponto cadastrado.')); }
			info.stations.forEach(function (station) {
				const extra = station.slots ? ' - ' + station.slots + ' espaços, ' + Math.round(station.maxWeight / 1000) + ' kg' : '';
				const line = row(station.label, station.kindLabel + extra);
				line.appendChild(gpsButton(station.x, station.y));
				root.appendChild(line);
			});
		}

		function fleetView() {
			const info = data.fleet;
			if (info.garages.length === 0) { root.appendChild(empty('Este negócio não tem garagem de frota.')); return; }
			info.garages.forEach(function (garage) {
				root.appendChild(section(garage.label + ' (' + garage.vehicles.length + ')'));
				if (garage.vehicles.length === 0) { root.appendChild(empty('Nenhum veículo.')); }
				garage.vehicles.forEach(function (vehicle) {
					const access = vehicle.staff ? 'Equipe' : (vehicle.accessCount > 0 ? vehicle.accessCount + ' pessoa(s)' : 'Só o dono');
					const line = row(vehicle.name + ' - ' + vehicle.plate, (VEHICLE_STATES[vehicle.state] || vehicle.state) + ' - ' + access);
					if (info.canManage) {
						line.appendChild(button(vehicle.staff ? 'Bloquear equipe' : 'Liberar equipe', '', function () {
							call('fleetAccess', { vehicleId: String(vehicle.id), staff: !vehicle.staff }, function () { tablet.status('Acesso atualizado.', 'ok'); reload(); });
						}));
					}
					root.appendChild(line);
				});
			});
		}

		function bankView() {
			const bank = window.CoeBusinessBank;
			const info = data.bank;
			if (!bank || !info) { root.appendChild(empty('Carregando a conta da empresa...')); return; }
			const list = bank.sections(info);
			if (!list.some(function (entry) { return entry[0] === bankTab; })) { bankTab = list[0][0]; }
			const kpis = el('div', 'grid-4');
			bank.summary(info).forEach(function (node) { if (node) { kpis.appendChild(node); } });
			root.appendChild(kpis);
			const bar = el('div', 'tb-tabs');
			list.forEach(function (entry) {
				const node = button(entry[1] + (entry[2] ? ' •' : ''), 'tb-tab' + (bankTab === entry[0] ? ' is-active' : ''), function () { bankTab = entry[0]; tablet.status(''); view(); });
				node.className = 'tb-tab' + (bankTab === entry[0] ? ' is-active' : '');
				bar.appendChild(node);
			});
			root.appendChild(bar);
			const body = el('div', 'bank-ui');
			bankTab = bank.renderSection(body, bankTab, info, {
				channel: 'tablet',
				act: function (action, payload) { bankCall(Object.assign({}, payload || {}, { op: action })); }
			});
			root.appendChild(body);
		}

		function shopView() {
			const shop = window.CoeBusinessShop;
			if (!shop || !data.shop) { root.appendChild(empty('Carregando a loja...')); return; }
			shop.render(root, data.shop, {
				act: function (op, payload) {
					call('shop', Object.assign({}, payload || {}, { op: op }), function (result) {
						data.shop = result;
						tablet.status('Preço atualizado.', 'ok');
						view();
					});
				}
			});
		}

		function propertiesView() {
			const info = data.properties;
			if (info.properties.length === 0) { root.appendChild(empty('Nenhuma propriedade vinculada a este negócio.')); return; }
			info.properties.forEach(function (property) {
				const line = row(property.label + (property.enabled ? '' : ' (desativada)'), property.kindLabel + ' - ' + property.detail + (property.overdue ? ' (aluguel vencido)' : ''));
				if (property.x !== undefined && property.x !== null) { line.appendChild(gpsButton(property.x, property.y)); }
				root.appendChild(line);
			});
		}

		function view() {
			root.replaceChildren();
			root.appendChild(tabs());
			({
				overview: overviewView, shop: shopView, bank: bankView, finance: financeView, staff: staffView, partners: partnersView, access: accessView,
				structure: structureView, fleet: fleetView, properties: propertiesView
			})[tab]();
		}

		load('overview');
	});
})();
