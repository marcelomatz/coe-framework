// Painel da staff (coe_staff): cada aba é um módulo liberado pela ACE. O servidor autoriza e valida tudo;
// a tela só monta os formulários e mostra o resultado.
(function () {
	'use strict';

	const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'coe_staff';
	const TABS = [
		{ id: 'self', label: 'Pessoal' },
		{ id: 'players', label: 'Jogadores' },
		{ id: 'vehicles', label: 'Veículos' },
		{ id: 'world', label: 'Mundo' },
		{ id: 'businesses', label: 'Negócios' }
	];
	const ERRORS = {
		forbidden: 'Sem permissão.', busy: 'Aguarde um instante.', timeout: 'Sem resposta do servidor.', closed: 'Painel fechado.',
		no_waypoint: 'Marque um ponto no mapa primeiro.', no_vehicle: 'Nenhum veículo por perto.', invalid_model: 'Modelo inválido.'
	};
	const WEATHERS = {
		EXTRASUNNY: 'Sol forte', CLEAR: 'Limpo', CLOUDS: 'Nuvens', OVERCAST: 'Encoberto', SMOG: 'Poluição', FOGGY: 'Neblina',
		RAIN: 'Chuva', THUNDER: 'Tempestade', CLEARING: 'Abrindo', SNOW: 'Neve', XMAS: 'Natal', HALLOWEEN: 'Halloween'
	};
	const STATIONS = { clocks: 'Relógios de ponto', stashes: 'Baús', crafts: 'Bancadas', showroom: 'Showroom' };
	const RULE_LABELS = {
		ownerAccess: 'Dono tem acesso total', clockRequired: 'Ponto obrigatório para operar', clockOffsite: 'Ponto continua fora da área',
		multiJob: 'Permite outros empregos', priceMultiplier: 'Multiplicador de preço'
	};

	const els = {
		panel: document.getElementById('staff'), tabs: document.getElementById('sf-tabs'), body: document.getElementById('sf-body'),
		status: document.getElementById('sf-status'), close: document.getElementById('sf-close')
	};
	const state = {
		modules: {}, toggles: {}, noclip: false, tab: null,
		players: null, selected: null, groups: null, itemSearch: '', items: null,
		vehicles: null, vehicleSearch: '', world: null,
		businesses: null, business: null
	};
	let statusTimer = null;
	let busy = false;

	// Utilidades ---------------------------------------------------------------------------------------------------

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
	function input(placeholder, type, value) {
		const node = el('input', 'coe-field');
		node.type = type || 'text';
		node.placeholder = placeholder || '';
		if (value !== undefined && value !== null) { node.value = String(value); }
		return node;
	}
	function select(options, value) {
		const node = el('select', 'coe-field');
		options.forEach(function (option) {
			const item = el('option', null, option[1]);
			item.value = option[0];
			if (String(option[0]) === String(value)) { item.selected = true; }
			node.append(item);
		});
		return node;
	}
	function field(label, control) {
		const wrap = el('label', 'sf-field');
		wrap.append(el('span', 'sf-field-label', label), control);
		return wrap;
	}
	function card(title, hint) {
		const box = el('section', 'sf-card');
		const head = el('header', 'sf-card-head');
		head.append(el('h2', null, title));
		if (hint) { head.append(el('p', 'sf-hint', hint)); }
		box.append(head);
		return box;
	}
	function row() { return el('div', 'sf-row'); }
	function empty(text) { return el('p', 'sf-empty', text); }
	function money(value) { return '$ ' + Math.floor(Number(value) || 0).toLocaleString('pt-BR'); }

	function post(name, body) {
		return fetch('https://' + resource + '/' + name, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json; charset=UTF-8' },
			body: JSON.stringify(body || {})
		}).then(function (response) { return response.json(); }).catch(function () { return { ok: false, error: 'closed' }; });
	}
	function status(text, kind) {
		clearTimeout(statusTimer);
		els.status.textContent = text || '';
		els.status.className = 'sf-status' + (kind ? ' is-' + kind : '');
		if (text && kind !== 'error') { statusTimer = setTimeout(function () { status(''); }, 5000); }
	}
	function errorText(result) {
		return (result && (result.message || ERRORS[result.error])) || 'Não foi possível concluir.';
	}
	// Ação no servidor; done(data) roda só no sucesso. okText aparece no rodapé.
	function act(action, data, okText, done) {
		if (busy) { return Promise.resolve(null); }
		busy = true;
		els.panel.classList.add('is-busy');
		return post('action', { action: action, data: data || {} }).then(function (result) {
			busy = false;
			els.panel.classList.remove('is-busy');
			if (!result || !result.ok) { status(errorText(result), 'error'); return null; }
			if (okText) { status(okText, 'success'); }
			if (done) { done(result.data || {}); }
			return result.data || {};
		});
	}
	function confirmBox(title, message, label) {
		return window.CoeUI && window.CoeUI.confirm
			? window.CoeUI.confirm({ title: title, message: message, confirmLabel: label, danger: true })
			: Promise.resolve(true);
	}
	function copyText(text) {
		const area = el('textarea');
		area.value = text;
		area.style.position = 'fixed';
		area.style.opacity = '0';
		document.body.append(area);
		area.select();
		let ok = false;
		try { ok = document.execCommand('copy'); } catch (error) { ok = false; }
		area.remove();
		status(ok ? 'Copiado: ' + text : 'Não foi possível copiar.', ok ? 'success' : 'error');
	}

	// Abas -----------------------------------------------------------------------------------------------------

	function paintTabs() {
		els.tabs.replaceChildren();
		TABS.filter(function (tab) { return state.modules[tab.id]; }).forEach(function (tab) {
			const node = el('button', 'sf-tab' + (state.tab === tab.id ? ' is-active' : ''), tab.label);
			node.type = 'button';
			node.addEventListener('click', function () { go(tab.id); });
			els.tabs.append(node);
		});
	}
	function go(tab) {
		state.tab = tab;
		status('');
		paintTabs();
		render();
		if (tab === 'players' && !state.players) { loadPlayers(); }
		if (tab === 'vehicles' && !state.vehicles) { searchVehicles(''); }
		if (tab === 'world' && !state.world) { act('world', {}, null, function (data) { state.world = data; render(); }); }
		if (tab === 'businesses' && !state.businesses) { loadBusinesses(); }
	}
	function render() {
		els.body.replaceChildren();
		const views = { self: renderSelf, players: renderPlayers, vehicles: renderVehicles, world: renderWorld, businesses: renderBusinesses };
		(views[state.tab] || function () {})();
	}

	// Pessoal --------------------------------------------------------------------------------------------------

	function toggle(label, key, action) {
		const on = key === 'noclip' ? state.noclip : state.toggles[key] === true;
		const node = button(label + (on ? ': ligado' : ': desligado'), on ? 'coe-button--primary sf-toggle' : 'sf-toggle', function () {
			if (key === 'coords') {
				state.toggles.coords = !on;
				post('showCoords', { on: !on });
				render();
				return;
			}
			act(action, { on: !on }, label + (on ? ' desligado.' : ' ligado.'), function () {
				if (key === 'noclip') { state.noclip = !on; } else { state.toggles[key] = !on; }
				render();
			});
		});
		node.setAttribute('aria-pressed', on ? 'true' : 'false');
		return node;
	}

	function renderSelf() {
		const tools = card('Ferramentas', 'O noclip fecha o painel: W/A/S/D, Q/E desce e sobe, Shift acelera, roda do mouse muda a velocidade. Atalho: /noclip.');
		const toggles = el('div', 'sf-grid2');
		toggles.append(toggle('Noclip', 'noclip', 'noclip'), toggle('Invisível', 'invisible', 'invisible'),
			toggle('Invencível', 'godmode', 'godmode'), toggle('Coordenadas na tela', 'coords'));
		const actions = row();
		actions.append(
			button('Curar', '', function () { act('heal', {}, 'Vida e colete restaurados.'); }),
			button('Reviver', '', function () { act('revive', {}, 'Revivido.'); }),
			button('Ir ao marcador do mapa', '', function () { act('tpWaypoint', {}, 'Teleportado.'); })
		);
		tools.append(toggles, actions);

		const tp = card('Teleporte por coordenadas', 'Cole "x, y, z" ou "vector3(x, y, z)". Sem z, procura o chão.');
		const coords = input('x, y, z');
		const go = button('Teleportar', 'coe-button--primary', function () {
			const numbers = (coords.value.match(/-?\d+(?:\.\d+)?/g) || []).map(Number);
			if (numbers.length < 2) { status('Informe pelo menos x e y.', 'error'); return; }
			act('tpCoords', { x: numbers[0], y: numbers[1], z: numbers.length > 2 ? numbers[2] : 0 }, 'Teleportado.');
		});
		const line = row();
		line.append(coords, go);
		tp.append(line);

		const here = card('Minha posição', 'Para colar em configs e scripts.');
		const out = el('p', 'sf-coords', '—');
		const refresh = function () {
			post('coords').then(function (result) {
				if (!result || !result.ok) { out.textContent = '—'; return; }
				const x = result.x.toFixed(2), y = result.y.toFixed(2), z = result.z.toFixed(2), h = result.h.toFixed(1);
				out.textContent = 'x ' + x + '   y ' + y + '   z ' + z + '   h ' + h;
				out.dataset.v3 = 'vector3(' + x + ', ' + y + ', ' + z + ')';
				out.dataset.v4 = 'vector4(' + x + ', ' + y + ', ' + z + ', ' + h + ')';
				out.dataset.table = '{ x = ' + x + ', y = ' + y + ', z = ' + z + ' }';
			});
		};
		const copies = row();
		copies.append(
			button('Atualizar', '', refresh),
			button('Copiar vector3', '', function () { if (out.dataset.v3) { copyText(out.dataset.v3); } }),
			button('Copiar vector4', '', function () { if (out.dataset.v4) { copyText(out.dataset.v4); } }),
			button('Copiar { x, y, z }', '', function () { if (out.dataset.table) { copyText(out.dataset.table); } })
		);
		here.append(out, copies);
		refresh();
		els.body.append(tools, tp, here);
	}

	// Jogadores ------------------------------------------------------------------------------------------------

	function loadPlayers() {
		return act('players', {}, null, function (data) {
			state.players = data.players || [];
			if (state.selected && !state.players.some(function (p) { return p.id === state.selected; })) { state.selected = null; }
			render();
		});
	}
	function selectedPlayer() {
		return (state.players || []).find(function (p) { return p.id === state.selected; }) || null;
	}

	function renderPlayers() {
		const wrap = el('div', 'sf-split');
		const side = el('div', 'sf-list-pane');
		const search = input('Buscar por ID, nome ou ID de cidadão', 'search', state.playerFilter || '');
		const refresh = button('Atualizar', '', loadPlayers);
		const head = row();
		head.append(search, refresh);
		const list = el('ul', 'sf-list');
		function fill() {
			list.replaceChildren();
			if (!state.players) { list.append(empty('Carregando...')); return; }
			const needle = (state.playerFilter || '').toLowerCase();
			const shown = state.players.filter(function (p) {
				return !needle || String(p.id) === needle || (p.name || '').toLowerCase().includes(needle)
					|| (p.character || '').toLowerCase().includes(needle) || (p.stateId || '').toLowerCase().includes(needle);
			});
			if (!shown.length) { list.append(empty('Ninguém encontrado.')); return; }
			shown.forEach(function (p) {
				const item = el('li');
				const node = el('button', 'sf-item' + (p.id === state.selected ? ' is-active' : ''));
				node.type = 'button';
				node.append(el('span', 'sf-badge', p.id));
				const text = el('span', 'sf-item-text');
				text.append(el('strong', null, p.character || 'Sem personagem'), el('small', null, p.name + (p.stateId ? ' · ' + p.stateId : '') + ' · ' + p.ping + ' ms'));
				node.append(text);
				if (p.frozen) { node.append(el('span', 'sf-tag', 'Congelado')); }
				node.addEventListener('click', function () { state.selected = p.id; state.groups = null; render(); loadGroups(); });
				item.append(node);
				list.append(item);
			});
		}
		search.addEventListener('input', function () { state.playerFilter = search.value; fill(); });
		fill();
		side.append(head, list);
		const detail = el('div', 'sf-detail-pane');
		const player = selectedPlayer();
		if (!player) {
			detail.append(empty('Escolha um jogador na lista.'));
		} else {
			detail.append(playerActions(player), playerItem(player), playerMoney(player), playerGroups(player));
		}
		wrap.append(side, detail);
		els.body.append(wrap);
	}

	function playerActions(p) {
		const box = card((p.character || p.name) + ' · ID ' + p.id, p.stateId ? 'ID de cidadão ' + p.stateId : 'Sem personagem carregado');
		const line = el('div', 'sf-grid3');
		line.append(
			button('Ir até', '', function () { act('gotoPlayer', { target: p.id }, 'Teleportado até ' + p.name + '.'); }),
			button('Trazer', '', function () { act('bringPlayer', { target: p.id }, p.name + ' trazido.'); }),
			button(p.frozen ? 'Descongelar' : 'Congelar', '', function () {
				act('freezePlayer', { target: p.id, on: !p.frozen }, p.frozen ? 'Descongelado.' : 'Congelado.', function () { loadPlayers(); });
			}),
			button('Curar', '', function () { act('healPlayer', { target: p.id }, 'Curado.'); }),
			button('Reviver', '', function () { act('revivePlayer', { target: p.id }, 'Revivido.'); })
		);
		const reason = input('Motivo (opcional)');
		const kick = button('Expulsar', 'coe-button--danger', function () {
			confirmBox('Expulsar jogador', 'Expulsar ' + p.name + ' do servidor?', 'Expulsar').then(function (ok) {
				if (ok) { act('kickPlayer', { target: p.id, reason: reason.value }, 'Jogador expulso.', function () { state.selected = null; loadPlayers(); }); }
			});
		});
		const kickRow = row();
		kickRow.append(reason, kick);
		box.append(line, kickRow);
		return box;
	}

	function playerItem(p) {
		const box = card('Dar item');
		const search = input('Buscar item', 'search', state.itemSearch);
		const count = input('Qtd.', 'number', 1);
		count.min = '1';
		count.className += ' sf-narrow';
		const results = el('div', 'sf-items');
		let timer = null;
		function paint() {
			results.replaceChildren();
			if (!state.items) { results.append(empty('Digite para buscar.')); return; }
			if (!state.items.length) { results.append(empty('Nenhum item.')); return; }
			state.items.forEach(function (item) {
				const node = el('button', 'sf-itemcard');
				node.type = 'button';
				const img = el('img');
				img.alt = '';
				const rawImg = (typeof item.image === 'string' && item.image.trim()) ? item.image.trim() : (item.name + '.webp');
				const baseImg = rawImg.replace(/\.(webp|png|svg)$/i, '');
				const sources = [
					'nui://coe_inventory/data/images/' + baseImg + '.webp',
					'nui://coe_inventory/data/images/' + rawImg,
					'nui://coe_inventory/data/images/' + item.name + '.webp',
					'nui://coe_inventory/data/images/' + item.name + '.png'
				];
				let index = 0;
				img.addEventListener('error', function () { index += 1; if (index < sources.length) { img.src = sources[index]; } else { img.remove(); } });
				img.src = sources[0];
				node.append(img, el('span', null, item.label), el('small', null, item.name));
				node.title = 'Dar ' + item.label;
				node.addEventListener('click', function () {
					act('giveItem', { target: p.id, item: item.name, count: Number(count.value) || 1 }, (Number(count.value) || 1) + 'x ' + item.label + ' entregue.');
				});
				results.append(node);
			});
		}
		function find() {
			act('items', { search: search.value.trim() }, null, function (data) { state.items = data.items || []; paint(); });
		}
		search.addEventListener('input', function () {
			state.itemSearch = search.value;
			clearTimeout(timer);
			timer = setTimeout(find, 300);
		});
		const line = row();
		line.append(search, count);
		box.append(line, results);
		paint();
		if (!state.items) { find(); }
		return box;
	}

	function playerMoney(p) {
		const box = card('Dinheiro', 'Espécie é o item dinheiro no inventário; conta é o saldo no coe_economy (extrato: ajuste da staff).');
		const kind = select([['cash', 'Espécie'], ['bank', 'Conta']], 'cash');
		const amount = input('Valor', 'number');
		amount.min = '1';
		const line = row();
		line.append(kind, amount,
			button('Dar', 'coe-button--primary', function () {
				act('money', { target: p.id, kind: kind.value, amount: Number(amount.value), op: 'give' }, money(amount.value) + ' entregue.');
			}),
			button('Retirar', '', function () {
				act('money', { target: p.id, kind: kind.value, amount: Number(amount.value), op: 'take' }, money(amount.value) + ' retirado.');
			}));
		box.append(line);
		return box;
	}

	function loadGroups() {
		const p = selectedPlayer();
		if (!p) { return; }
		post('action', { action: 'groups', data: { target: p.id } }).then(function (result) {
			if (result && result.ok && state.selected === p.id) { state.groups = result.data; render(); }
		});
	}

	function playerGroups(p) {
		const box = card('Grupos', 'Empregos e gangues do coe_core (config/groups.lua).');
		if (!state.groups) { box.append(empty('Carregando...')); return box; }
		const current = state.groups.current || {};
		const lines = el('div', 'sf-lines');
		Object.keys(current).forEach(function (type) {
			const g = current[type];
			const line = el('div', 'sf-line');
			line.append(el('span', null, type + ': ' + (g.label || g.name) + ' · grau ' + g.grade));
			line.append(button('Remover', 'sf-small', function () {
				act('removeGroup', { target: p.id, name: g.name }, 'Grupo removido.', loadGroups);
			}));
			lines.append(line);
		});
		if (!lines.childNodes.length) { lines.append(empty('Sem grupos.')); }
		const defs = state.groups.definitions || [];
		const group = select(defs.map(function (d) { return [d.name, (d.label || d.name) + ' (' + d.type + ')']; }), defs[0] && defs[0].name);
		const grade = el('select', 'coe-field sf-narrow');
		function grades() {
			grade.replaceChildren();
			const def = defs.find(function (d) { return d.name === group.value; });
			(def && def.grades || []).forEach(function (entry) {
				const value = entry.grade !== undefined ? entry.grade : entry.level;
				const option = el('option', null, value + ' · ' + (entry.label || ''));
				option.value = value;
				grade.append(option);
			});
		}
		group.addEventListener('change', grades);
		grades();
		const line = row();
		line.append(group, grade, button('Definir', 'coe-button--primary', function () {
			act('setGroup', { target: p.id, name: group.value, grade: Number(grade.value) || 0 }, 'Grupo definido.', loadGroups);
		}));
		box.append(lines);
		if (defs.length) { box.append(line); }
		return box;
	}

	// Veículos -------------------------------------------------------------------------------------------------

	function searchVehicles(text) {
		return act('catalog', { search: text }, null, function (data) { state.vehicles = data; render(); });
	}

	function renderVehicles() {
		const tools = card('Veículo atual ou mais próximo');
		const line = el('div', 'sf-grid3');
		line.append(
			button('Consertar', '', function () { act('vehicleFix', { op: 'repair' }, 'Veículo consertado.'); }),
			button('Abastecer', '', function () { act('vehicleFix', { op: 'refuel' }, 'Tanque cheio.'); }),
			button('Limpar', '', function () { act('vehicleFix', { op: 'clean' }, 'Veículo limpo.'); }),
			button('Desvirar', '', function () { act('vehicleFix', { op: 'flip' }, 'Veículo desvirado.'); }),
			button('Apagar / guardar', 'coe-button--danger', function () {
				act('deleteVehicle', {}, 'Veículo removido (os registrados vão para a garagem).');
			})
		);
		tools.append(line);

		const box = card('Criar veículo', 'Temporário: não fica registrado (remova com "Apagar / guardar"). Registrado: fica no coe_vehicles em seu nome, com chave.');
		const search = input('Buscar modelo, nome ou marca', 'search', state.vehicleSearch);
		const model = input('ou digite o modelo (ex.: adder)');
		const direct = row();
		direct.append(model,
			button('Temporário', 'coe-button--primary', function () { spawn(model.value.trim(), 'temp'); }),
			button('Registrado', '', function () { spawn(model.value.trim(), 'owned'); }));
		let timer = null;
		search.addEventListener('input', function () {
			state.vehicleSearch = search.value;
			clearTimeout(timer);
			timer = setTimeout(function () { searchVehicles(search.value.trim()); }, 300);
		});
		const list = el('ul', 'sf-list sf-vehicles');
		const data = state.vehicles;
		if (!data) {
			list.append(empty('Carregando...'));
		} else if (!data.catalog) {
			list.append(empty('Catálogo indisponível (coe_vehicle_catalog parado). Use o campo do modelo.'));
		} else if (!data.vehicles.length) {
			list.append(empty('Nenhum veículo.'));
		} else {
			data.vehicles.forEach(function (v) {
				const item = el('li', 'sf-line');
				const text = el('span', 'sf-item-text');
				text.append(el('strong', null, v.name || v.model), el('small', null, v.model + (v.brand ? ' · ' + v.brand : '') + (v.class ? ' · ' + v.class : '')));
				const actions = el('span', 'sf-inline');
				actions.append(
					button('Temporário', 'sf-small coe-button--primary', function () { spawn(v.model, 'temp'); }),
					button('Registrado', 'sf-small', function () { spawn(v.model, 'owned'); }));
				item.append(text, actions);
				list.append(item);
			});
		}
		box.append(search, list, direct);
		els.body.append(tools, box);
	}

	function spawn(model, mode) {
		if (!model) { status('Escolha um modelo.', 'error'); return; }
		act('spawnVehicle', { model: model, mode: mode }, mode === 'owned' ? 'Veículo registrado em seu nome.' : 'Veículo criado.');
	}

	// Mundo ----------------------------------------------------------------------------------------------------

	function renderWorld() {
		const world = state.world || {};
		const time = world.time || {};
		const clock = card('Horário', world.time ? 'Definido pela staff' + (time.freeze ? ' (parado).' : '.') : 'Ciclo natural do jogo.');
		const hour = input('Hora', 'number', time.hour !== undefined ? time.hour : 12);
		hour.min = '0'; hour.max = '23'; hour.className += ' sf-narrow';
		const minute = input('Min', 'number', time.minute !== undefined ? time.minute : 0);
		minute.min = '0'; minute.max = '59'; minute.className += ' sf-narrow';
		const freeze = el('input');
		freeze.type = 'checkbox';
		freeze.checked = time.freeze === true;
		const freezeLabel = el('label', 'sf-check');
		freezeLabel.append(freeze, el('span', null, 'Parar o relógio'));
		const timeRow = row();
		timeRow.append(hour, minute, freezeLabel, button('Aplicar', 'coe-button--primary', function () {
			act('setTime', { hour: Number(hour.value), minute: Number(minute.value), freeze: freeze.checked }, 'Horário aplicado para todos.', function (data) { state.world = data; render(); });
		}));
		const presets = row();
		[[6, 'Amanhecer'], [12, 'Meio-dia'], [18, 'Entardecer'], [23, 'Noite']].forEach(function (preset) {
			presets.append(button(preset[1], 'sf-small', function () {
				act('setTime', { hour: preset[0], minute: 0, freeze: freeze.checked }, 'Horário aplicado para todos.', function (data) { state.world = data; render(); });
			}));
		});
		clock.append(timeRow, presets);

		const weather = card('Clima', world.weather ? 'Atual: ' + (WEATHERS[world.weather] || world.weather) : 'Clima natural do jogo.');
		const chips = el('div', 'sf-chips');
		(world.weathers || Object.keys(WEATHERS)).forEach(function (id) {
			chips.append(button(WEATHERS[id] || id, 'sf-small' + (world.weather === id ? ' coe-button--primary' : ''), function () {
				act('setWeather', { weather: id }, 'Clima aplicado para todos.', function (data) { state.world = data; render(); });
			}));
		});
		weather.append(chips);
		const reset = row();
		reset.append(button('Voltar ao horário e clima naturais', '', function () {
			act('resetWorld', {}, 'Mundo de volta ao natural.', function (data) { state.world = data; render(); });
		}));
		weather.append(reset);

		const notice = card('Aviso para todos', 'Aparece como notificação para quem está online.');
		const text = input('Ex.: Reinício do servidor em 5 minutos');
		text.maxLength = 200;
		const noticeRow = row();
		noticeRow.append(text, button('Enviar', 'coe-button--primary', function () {
			act('announce', { text: text.value }, 'Aviso enviado.', function () { text.value = ''; });
		}));
		notice.append(noticeRow);
		els.body.append(clock, weather, notice);
	}

	// Negócios -------------------------------------------------------------------------------------------------

	function loadBusinesses() {
		return act('businesses', {}, null, function (data) { state.businesses = data; render(); });
	}
	function openBusiness(id) {
		return act('business', { id: id }, null, function (data) { state.business = data.business; render(); });
	}
	function edit(action, data, okText) {
		return act(action, Object.assign({ id: state.business.id }, data), okText, function (result) {
			state.business = result.business;
			const summary = (state.businesses.businesses || []).find(function (b) { return b.id === result.business.id; });
			if (summary) {
				summary.label = result.business.label;
				summary.enabled = result.business.enabled !== false;
				summary.owner = result.business.owner ? result.business.owner.name : null;
				summary.staff = (result.business.staff || []).length;
			}
			render();
		});
	}
	function categoryOf(id) {
		return ((state.businesses && state.businesses.categories) || []).find(function (c) { return c.id === id; }) || null;
	}

	function renderBusinesses() {
		const data = state.businesses;
		if (!data) { els.body.append(empty('Carregando...')); return; }
		const wrap = el('div', 'sf-split');
		const side = el('div', 'sf-list-pane');
		const list = el('ul', 'sf-list');
		const top = row();
		top.append(button('Novo negócio', 'coe-button--primary', function () { state.business = { creating: true }; render(); }),
			button('Atualizar', '', loadBusinesses));
		if (!data.businesses.length) { list.append(empty('Nenhum negócio cadastrado.')); }
		data.businesses.slice().sort(function (a, b) { return a.label.localeCompare(b.label); }).forEach(function (b) {
			const item = el('li');
			const node = el('button', 'sf-item' + (state.business && state.business.id === b.id ? ' is-active' : ''));
			node.type = 'button';
			const text = el('span', 'sf-item-text');
			const category = categoryOf(b.category);
			text.append(el('strong', null, b.label), el('small', null, (category ? category.label : b.category) + ' · ' + b.id + ' · equipe ' + b.staff));
			node.append(text);
			if (!b.enabled) { node.append(el('span', 'sf-tag', 'Desativado')); }
			node.addEventListener('click', function () { openBusiness(b.id); });
			item.append(node);
			list.append(item);
		});
		side.append(top, list);
		const detail = el('div', 'sf-detail-pane');
		if (!state.business) {
			detail.append(empty('Escolha um negócio ou crie um novo.'));
		} else if (state.business.creating) {
			detail.append(businessCreate());
		} else {
			detail.append(businessInfo(), businessArea(), businessStations(), businessOwner(), businessGrades(), businessStaff(), businessDanger());
		}
		wrap.append(side, detail);
		els.body.append(wrap);
	}

	function businessCreate() {
		const box = card('Novo negócio', 'A área nasce como um círculo em volta de onde você está agora. Depois, marque relógio, baús e bancadas no próprio local.');
		const categories = state.businesses.categories;
		const id = input('id (ex.: burger_shot)');
		const label = input('Nome (ex.: Burger Shot)');
		const category = select(categories.map(function (c) { return [c.id, c.label]; }), categories[0] && categories[0].id);
		const radius = input('Raio da área (m)', 'number', 25);
		label.addEventListener('input', function () {
			if (!id.dataset.touched) {
				id.value = label.value.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '').slice(0, 32);
			}
		});
		id.addEventListener('input', function () { id.dataset.touched = '1'; });
		const grid = el('div', 'sf-grid2');
		grid.append(field('Nome', label), field('Id', id), field('Categoria', category), field('Raio (m)', radius));
		const actions = row();
		actions.append(button('Criar aqui', 'coe-button--primary', function () {
			act('businessCreate', { id: id.value.trim(), label: label.value, category: category.value, radius: Number(radius.value) }, 'Negócio criado.', function (result) {
				state.business = result.business;
				loadBusinesses();
			});
		}), button('Cancelar', '', function () { state.business = null; render(); }));
		box.append(grid, actions);
		return box;
	}

	function businessInfo() {
		const b = state.business;
		const category = categoryOf(b.category);
		const box = card(b.label, (category ? category.label : b.category) + ' · id ' + b.id);
		const label = input('Nome', 'text', b.label);
		const enabled = el('input');
		enabled.type = 'checkbox';
		enabled.checked = b.enabled !== false;
		const enabledLabel = el('label', 'sf-check');
		enabledLabel.append(enabled, el('span', null, 'Ativo'));
		const rules = {};
		const rulesBox = el('div', 'sf-grid2');
		((category && category.rules) || []).forEach(function (name) {
			const schema = (state.businesses.rules || {})[name] || {};
			const value = (b.rules || {})[name];
			if (schema.type === 'boolean') {
				const check = el('input');
				check.type = 'checkbox';
				check.checked = value === true;
				const wrap = el('label', 'sf-check');
				wrap.append(check, el('span', null, RULE_LABELS[name] || name));
				rules[name] = function () { return check.checked; };
				rulesBox.append(wrap);
			} else if (schema.type === 'number') {
				const number = input(String(schema.min) + ' a ' + String(schema.max), 'number', value);
				number.step = '0.05';
				rules[name] = function () { return Number(number.value); };
				rulesBox.append(field(RULE_LABELS[name] || name, number));
			}
		});
		const actions = row();
		actions.append(label, enabledLabel, button('Salvar', 'coe-button--primary', function () {
			const values = {};
			Object.keys(rules).forEach(function (name) { values[name] = rules[name](); });
			edit('businessInfo', { label: label.value, enabled: enabled.checked, rules: values }, 'Negócio salvo.');
		}), button('Ir até', '', function () { act('businessGoto', { id: b.id }, 'Teleportado até ' + b.label + '.'); }));
		box.append(actions, rulesBox);
		return box;
	}

	function businessArea() {
		const b = state.business;
		const area = b.area || {};
		const box = card('Área', area.kind === 'circle'
			? 'Círculo de ' + area.radius + ' m em ' + Number(area.x).toFixed(1) + ', ' + Number(area.y).toFixed(1)
			: 'Polígono de ' + ((area.points || []).length) + ' pontos (redefinir troca por um círculo).');
		const radius = input('Raio (m)', 'number', area.radius || 25);
		radius.className += ' sf-narrow';
		const line = row();
		line.append(radius, button('Redefinir em volta de mim', '', function () {
			edit('businessArea', { radius: Number(radius.value) }, 'Área redefinida.');
		}));
		box.append(line);
		return box;
	}

	function businessStations() {
		const b = state.business;
		const category = categoryOf(b.category);
		const box = card('Pontos no local', 'Vá até o lugar e use "Adicionar aqui": o ponto fica na sua posição.');
		((category && category.stations) || []).forEach(function (kind) {
			const section = el('div', 'sf-sub');
			section.append(el('h3', null, STATIONS[kind] || kind));
			const stations = b.stations || {};
			const list = kind === 'showroom' ? (stations.showroom ? [Object.assign({ id: 'showroom', label: 'Showroom' }, stations.showroom)] : []) : (stations[kind] || []);
			list.forEach(function (station) {
				const line = el('div', 'sf-line');
				line.append(el('span', null, (station.label || station.id) + ' · ' + Number(station.x).toFixed(1) + ', ' + Number(station.y).toFixed(1) + ', ' + Number(station.z).toFixed(1)));
				line.append(button('Remover', 'sf-small', function () {
					edit('stationRemove', { kind: kind, stationId: station.id }, 'Ponto removido.');
				}));
				section.append(line);
			});
			if (!list.length) { section.append(el('p', 'sf-hint', 'Nenhum.')); }
			const label = input(kind === 'showroom' ? 'Raio (m)' : 'Nome (opcional)', kind === 'showroom' ? 'number' : 'text');
			const add = row();
			add.append(label, button(kind === 'showroom' ? 'Definir aqui' : 'Adicionar aqui', '', function () {
				const data = { kind: kind };
				if (kind === 'showroom') { data.radius = Number(label.value) || 6; } else { data.label = label.value; }
				edit('stationAdd', data, 'Ponto adicionado.');
			}));
			section.append(add);
			box.append(section);
		});
		return box;
	}

	function businessOwner() {
		const b = state.business;
		const box = card('Dono', b.owner ? b.owner.name + ' (personagem ' + b.owner.characterId + ')' : 'Sem dono.');
		const stateId = input('ID de cidadão (8 caracteres)');
		const line = row();
		line.append(stateId, button('Definir dono', 'coe-button--primary', function () {
			edit('businessOwner', { stateId: stateId.value }, 'Dono definido.');
		}));
		if (b.owner) {
			line.append(button('Remover dono', '', function () { edit('businessOwner', { stateId: '' }, 'Dono removido.'); }));
		}
		box.append(line);
		return box;
	}

	function businessGrades() {
		const b = state.business;
		const box = card('Cargos', 'Do menor ao maior nível. Sem cargos, a equipe entra sem cargo.');
		(b.grades || []).forEach(function (grade) {
			const line = el('div', 'sf-line');
			line.append(el('span', null, grade.level + ' · ' + grade.label + ' · ' + money(grade.salary) + ((grade.permissions || []).length ? ' · ' + grade.permissions.length + ' permissões' : '')));
			line.append(button('Remover', 'sf-small', function () { edit('gradeRemove', { gradeId: grade.id }, 'Cargo removido.'); }));
			box.append(line);
		});
		const label = input('Nome do cargo');
		const level = input('Nível', 'number', (b.grades || []).length);
		level.className += ' sf-narrow';
		const salary = input('Salário', 'number', 0);
		salary.className += ' sf-narrow';
		const perms = el('div', 'sf-perms');
		const checks = [];
		const rawPerms = state.businesses.permissions;
		const permList = Array.isArray(rawPerms)
			? rawPerms
			: (rawPerms && typeof rawPerms === 'object'
				? Object.keys(rawPerms).sort().map(function (k) { return { name: k, label: rawPerms[k] }; })
				: []);
		permList.forEach(function (permission) {
			const check = el('input');
			check.type = 'checkbox';
			check.value = permission.name;
			const wrap = el('label', 'sf-check');
			wrap.append(check, el('span', null, permission.label || permission.name));
			wrap.title = permission.name;
			checks.push(check);
			perms.append(wrap);
		});
		const line = row();
		line.append(label, level, salary, button('Adicionar cargo', '', function () {
			const permissions = checks.filter(function (c) { return c.checked; }).map(function (c) { return c.value; });
			edit('gradeAdd', { label: label.value, level: Number(level.value), salary: Number(salary.value), permissions: permissions }, 'Cargo adicionado.');
		}));
		box.append(line);
		if (checks.length) {
			const details = el('details', 'sf-details');
			details.append(el('summary', null, 'Permissões do novo cargo'), perms);
			box.append(details);
		}
		return box;
	}

	function businessStaff() {
		const b = state.business;
		const grades = (b.grades || []).map(function (g) { return [g.id, g.label]; });
		const box = card('Equipe', (b.staff || []).length + ' pessoa(s).');
		(b.staff || []).forEach(function (member) {
			const line = el('div', 'sf-line');
			line.append(el('span', null, member.name || member.characterId));
			const actions = el('span', 'sf-inline');
			if (grades.length) {
				const grade = select(grades, member.grade);
				grade.className += ' sf-narrow';
				grade.addEventListener('change', function () {
					edit('staffGrade', { characterId: member.characterId, grade: grade.value }, 'Cargo atualizado.');
				});
				actions.append(grade);
			}
			actions.append(button('Remover', 'sf-small', function () {
				edit('staffRemove', { characterId: member.characterId }, 'Removido da equipe.');
			}));
			line.append(actions);
			box.append(line);
		});
		const stateId = input('ID de cidadão');
		const line = row();
		line.append(stateId);
		let grade = null;
		if (grades.length) {
			grade = select(grades, grades[0][0]);
			grade.className += ' sf-narrow';
			line.append(grade);
		}
		line.append(button('Contratar', 'coe-button--primary', function () {
			edit('staffAdd', { stateId: stateId.value, grade: grade ? grade.value : '' }, 'Contratado.');
		}));
		box.append(line);
		return box;
	}

	function businessDanger() {
		const b = state.business;
		const box = card('Apagar negócio', 'Remove o cadastro, a equipe e os pontos. Não dá para desfazer.');
		box.classList.add('is-danger');
		const line = row();
		line.append(button('Apagar ' + b.label, 'coe-button--danger', function () {
			confirmBox('Apagar negócio', 'Apagar ' + b.label + ' (' + b.id + ')? Não dá para desfazer.', 'Apagar').then(function (ok) {
				if (ok) {
					act('businessDelete', { id: b.id }, 'Negócio apagado.', function (data) { state.businesses = data; state.business = null; render(); });
				}
			});
		}));
		box.append(line);
		return box;
	}

	// Abrir e fechar -------------------------------------------------------------------------------------------

	function open(data) {
		state.modules = data.modules || {};
		state.toggles = data.toggles || {};
		state.noclip = data.noclip === true;
		state.players = null;
		state.businesses = null;
		state.business = null;
		state.world = null;
		state.vehicles = null;
		state.items = null;
		els.panel.hidden = false;
		const first = TABS.find(function (tab) { return state.modules[tab.id]; });
		go(state.tab && state.modules[state.tab] ? state.tab : (first ? first.id : null));
	}
	function close() {
		els.panel.hidden = true;
		status('');
	}

	els.close.addEventListener('click', function () { post('close'); });
	document.addEventListener('keydown', function (event) {
		if (event.key === 'Escape' && !els.panel.hidden && !document.querySelector('.coe-modal-overlay')) { post('close'); }
	});
	window.addEventListener('message', function (event) {
		const message = event.data || {};
		if (message.action === 'open' && message.data) { open(message.data); }
		if (message.action === 'close') { close(); }
	});
})();
