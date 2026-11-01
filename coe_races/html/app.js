// App de corridas ilegais (coe_races): corridas abertas, organizar, pistas com recordes, gravação de pista, ranking e
// histórico. Roda no tablet de corridas (aparelho próprio) e no COE OS (coe_tablet), com o mesmo contrato de host.
(function () {
	'use strict';

	const host = window.CoeRacepad || window.CoeTablet;
	if (!host) { return; }

	if (!document.querySelector('link[data-coe-races]')) {
		const link = document.createElement('link');
		link.rel = 'stylesheet';
		link.href = 'nui://coe_races/html/app.css';
		link.dataset.coeRaces = '1';
		document.head.appendChild(link);
	}

	const UNIT = 10000;
	const ERRORS = {
		not_ready: 'A rede de corridas ainda está subindo.', no_character: 'Personagem não carregado.',
		no_tablet: 'Você precisa do tablet de corridas.', rate_limited: 'Calma, muitas ações seguidas.',
		database_error: 'Falha ao gravar. Tente de novo.', internal_error: 'Falha interna. Tente de novo.', timeout: 'Sem resposta.',
		invalid_payload: 'Pedido inválido.', unknown_action: 'Ação desconhecida.', forbidden: 'Sem permissão.',
		no_nickname: 'Escolha seu vulgo primeiro.', invalid_nickname: 'Vulgo: 3 a 16 letras, números, _ ou -.',
		nickname_taken: 'Esse vulgo já tem dono.', in_race: 'Você está inscrito numa corrida.',
		unknown_track: 'Pista não encontrada.', unknown_race: 'Essa corrida não existe mais.',
		invalid_options: 'Opções inválidas.', invalid_laps: 'Número de voltas inválido.', invalid_buy_in: 'Entrada inválida.',
		invalid_class: 'Classe inválida.', invalid_max_racers: 'Número de corredores inválido.', invalid_start_time: 'Horário de largada inválido.',
		too_many_races: 'Já tem corrida demais rolando na cidade. Espere uma acabar.', already_organizing: 'Você já organiza uma corrida.',
		crypto_unavailable: 'Rede cripto fora do ar.', invalid_wallet: 'Escolha a carteira que paga a entrada.',
		invalid_payout: 'Endereço de recebimento inválido.', not_holder: 'A chave dessa carteira não está com você.',
		insufficient_funds: 'Saldo insuficiente (entrada + taxa da rede).', no_key: 'A chave dessa carteira não está à mão.',
		race_started: 'A corrida já largou.', already_racing: 'Você já está numa corrida.', race_full: 'Grid lotado.',
		not_in_race: 'Você não está nessa corrida.', not_organizer: 'Só o organizador pode fazer isso.',
		not_enough_racers: 'Corredores insuficientes para largar.', not_enough_races: 'Corra mais antes de criar pistas.',
		too_many_tracks: 'Você já tem pistas demais.', invalid_name: 'Nome: 3 a 32 caracteres.', invalid_description: 'Descrição inválida.',
		invalid_kind: 'Escolha sprint ou circuito.', invalid_status: 'Status inválido.', too_few_checkpoints: 'Poucos checkpoints.',
		checkpoints_too_close: 'Checkpoints muito próximos.', too_many_checkpoints: 'Checkpoints demais.'
	};
	const KIND = { sprint: 'Sprint', circuit: 'Circuito' };
	const SOURCES = { device: 'Celular', paper: 'Papel', usb: 'Pen drive' };
	const TABS = [
		{ id: 'races', label: 'Corridas' },
		{ id: 'organize', label: 'Organizar' },
		{ id: 'tracks', label: 'Pistas' },
		{ id: 'ranking', label: 'Ranking' },
		{ id: 'history', label: 'Histórico' }
	];

	function el(tag, className, text) {
		const node = document.createElement(tag);
		if (className) { node.className = className; }
		if (text !== undefined && text !== null) { node.textContent = String(text); }
		return node;
	}

	function button(label, kind, onClick) {
		const node = el('button', 'rx-btn' + (kind ? ' rx-btn--' + kind.split(' ').join(' rx-btn--') : ''));
		node.type = 'button';
		node.appendChild(el('span', null, label));
		node.addEventListener('click', onClick);
		return node;
	}

	function field(label, control, wide) {
		const wrap = el('label', 'rx-label' + (wide ? ' is-wide' : ''));
		wrap.appendChild(document.createTextNode(label));
		wrap.appendChild(control);
		return wrap;
	}

	function input(type, value, attrs) {
		const node = el('input', 'rx-input');
		node.type = type || 'text';
		if (value !== undefined && value !== null) { node.value = value; }
		Object.keys(attrs || {}).forEach(function (key) { node.setAttribute(key, attrs[key]); });
		node.spellcheck = false;
		return node;
	}

	function select(options, value) {
		const node = el('select', 'rx-select');
		options.forEach(function (option) {
			const item = el('option', null, option.label);
			item.value = option.value;
			if (String(option.value) === String(value)) { item.selected = true; }
			node.appendChild(item);
		});
		return node;
	}

	function stat(label, value, kind) {
		const node = el('div', 'rx-stat' + (kind ? ' is-' + kind : ''));
		node.appendChild(el('span', null, label));
		node.appendChild(el('strong', null, value));
		return node;
	}

	function badge(text, kind) { return el('span', 'rx-badge' + (kind ? ' rx-badge--' + kind : ''), text); }

	function formatTime(ms) {
		if (ms === null || ms === undefined) { return '—'; }
		const total = Math.max(0, Math.floor(ms));
		const minutes = Math.floor(total / 60000);
		const seconds = Math.floor((total % 60000) / 1000);
		return minutes + ':' + String(seconds).padStart(2, '0') + '.' + String(total % 1000).padStart(3, '0');
	}

	function formatNox(units) {
		const value = (Number(units) || 0) / UNIT;
		return value.toLocaleString('pt-BR', { minimumFractionDigits: 0, maximumFractionDigits: 4 }) + ' NOX';
	}

	function formatKm(meters) { return ((Number(meters) || 0) / 1000).toLocaleString('pt-BR', { maximumFractionDigits: 1 }) + ' km'; }

	function shortAddress(address) { return address && address.length > 14 ? address.slice(0, 8) + '…' + address.slice(-4) : (address || ''); }

	function walletOptions(wallets) {
		return wallets.map(function (wallet) {
			return { value: wallet.address, label: (wallet.label || SOURCES[wallet.source] || 'Carteira') + ' · ' + shortAddress(wallet.address) + ' · ' + (wallet.balanceText || formatNox(wallet.balance)) };
		});
	}

	// Mapa da pista em SVG: largada e checkpoints em escala, Y invertido (norte para cima).
	function trackMap(start, points, big) {
		const ns = 'http://www.w3.org/2000/svg';
		const svg = document.createElementNS(ns, 'svg');
		svg.setAttribute('viewBox', '0 0 100 100');
		svg.setAttribute('class', 'rx-map' + (big ? ' rx-map-big' : ''));
		const all = [start].concat(points || []);
		let minX = Infinity; let maxX = -Infinity; let minY = Infinity; let maxY = -Infinity;
		all.forEach(function (p) { minX = Math.min(minX, p.x); maxX = Math.max(maxX, p.x); minY = Math.min(minY, p.y); maxY = Math.max(maxY, p.y); });
		const span = Math.max(maxX - minX, maxY - minY, 1);
		const offX = (span - (maxX - minX)) / 2;
		const offY = (span - (maxY - minY)) / 2;
		function px(p) { return [8 + ((p.x - minX + offX) / span) * 84, 92 - ((p.y - minY + offY) / span) * 84]; }
		const line = document.createElementNS(ns, 'polyline');
		line.setAttribute('points', all.map(function (p) { return px(p).join(','); }).join(' '));
		svg.appendChild(line);
		(points || []).forEach(function (p) {
			const c = document.createElementNS(ns, 'circle');
			const xy = px(p);
			c.setAttribute('cx', xy[0]); c.setAttribute('cy', xy[1]); c.setAttribute('r', big ? 2.2 : 2.8);
			c.setAttribute('class', 'cp');
			svg.appendChild(c);
		});
		const s = document.createElementNS(ns, 'circle');
		const sxy = px(start);
		s.setAttribute('cx', sxy[0]); s.setAttribute('cy', sxy[1]); s.setAttribute('r', 3.6);
		s.setAttribute('class', 'start');
		svg.appendChild(s);
		return svg;
	}

	host.register('races', function (root, api) {
		const ui = {
			tab: 'races', state: null, offset: 0, tracks: null, detail: null, preselect: null, timers: [], busy: false
		};
		root.innerHTML = '';
		const app = el('div', 'rx');
		root.appendChild(app);

		function errorText(code) { return ERRORS[code] || (api.errorText ? api.errorText(code) : ('Falha: ' + code)); }

		function request(action, payload) {
			return api.call('races', action, payload || {}).then(function (result) {
				if (!result || !result.ok) {
					api.status(errorText(result && result.error), 'error');
					return null;
				}
				return result.data || {};
			});
		}

		function serverNow() { return Date.now() / 1000 + ui.offset; }

		function clearTimers() {
			ui.timers.forEach(function (id) { clearInterval(id); });
			ui.timers = [];
		}

		function every(ms, fn) {
			const id = setInterval(function () {
				if (!app.isConnected) { clearTimers(); return; }
				fn();
			}, ms);
			ui.timers.push(id);
		}

		function countdownText(startAt) {
			const left = Math.max(0, Math.round(startAt - serverNow()));
			return Math.floor(left / 60) + ':' + String(left % 60).padStart(2, '0');
		}

		function loadState() {
			return request('state').then(function (data) {
				if (data) {
					ui.state = data;
					ui.offset = (data.now || Date.now() / 1000) - Date.now() / 1000;
				}
				return data;
			});
		}

		// Moldura: logo, piloto e abas -----------------------------------------------------------------------------

		function frame() {
			clearTimers();
			app.innerHTML = '';
			const top = el('div', 'rx-top');
			const logo = el('div', 'rx-logo');
			logo.innerHTML = '<b>RACHA</b><i>//</i>NET';
			top.appendChild(logo);
			const state = ui.state;
			if (state && state.profile) {
				const me = el('div', 'rx-me');
				if (state.admin) { me.appendChild(el('span', 'rx-tag-staff', 'STAFF')); }
				me.appendChild(el('strong', null, state.profile.nickname));
				me.appendChild(el('span', 'rx-rating', state.profile.rating));
				top.appendChild(me);
			}
			app.appendChild(top);
			if (state && state.profile) {
				const tabs = el('div', 'rx-tabs');
				TABS.forEach(function (tab) {
					const node = el('button', 'rx-tab' + (ui.tab === tab.id ? ' is-active' : ''), tab.label);
					node.type = 'button';
					node.addEventListener('click', function () { go(tab.id); });
					tabs.appendChild(node);
				});
				app.appendChild(tabs);
			}
			const body = el('div', 'rx-body');
			app.appendChild(body);
			return body;
		}

		function go(tab) {
			ui.tab = tab;
			ui.detail = null;
			render();
		}

		function modal(build) {
			const overlay = el('div', 'rx-modal');
			const card = el('div', 'rx-card');
			overlay.appendChild(card);
			function close() { overlay.remove(); }
			overlay.addEventListener('click', function (event) { if (event.target === overlay) { close(); } });
			build(card, close);
			app.appendChild(overlay);
			return close;
		}

		// Vulgo (apelido) -------------------------------------------------------------------------------------------

		function renderGate(body) {
			const gate = el('div', 'rx-gate');
			const h = el('h2');
			h.innerHTML = 'Qual é o seu <b>vulgo</b>?';
			gate.appendChild(h);
			gate.appendChild(el('p', 'rx-hint', 'É assim que a rua vai te conhecer: no grid, no ranking e nos recordes das pistas. Escolha bem — trocar depois só fora das corridas.'));
			const limits = ui.state.limits;
			const name = input('text', '', { maxlength: limits.nicknameMax, placeholder: 'ex.: Toretto_99' });
			gate.appendChild(name);
			const save = button('Entrar na rua', 'go', function () {
				request('setNickname', { nickname: name.value.trim() }).then(function (data) {
					if (data) { ui.state = data; render(); }
				});
			});
			name.addEventListener('keydown', function (event) { if (event.key === 'Enter') { save.click(); } });
			gate.appendChild(save);
			body.appendChild(gate);
			setTimeout(function () { name.focus(); }, 50);
		}

		// Corridas ---------------------------------------------------------------------------------------------------

		function raceCard(race, options) {
			const card = el('div', 'rx-card' + (race.joined ? ' is-mine' : '') + (race.buyIn > 0 ? ' is-hot' : ''));
			const head = el('div', 'rx-card-head');
			const title = el('div');
			title.appendChild(el('div', 'rx-card-title', race.track.name));
			title.appendChild(el('div', 'rx-card-sub', 'Organizada por ' + race.organizer + ' · ' + formatKm(race.track.length * race.laps)));
			head.appendChild(title);
			const right = el('div', 'rx-card-right');
			if (race.status === 'lobby') {
				const when = el('div', 'rx-countdown', countdownText(race.startAt));
				when.dataset.startAt = race.startAt;
				right.appendChild(when);
				right.appendChild(el('div', 'rx-card-sub', 'para a largada'));
			} else {
				right.appendChild(el('span', 'rx-live', race.status === 'running' ? 'AO VIVO' : 'NO GRID'));
			}
			head.appendChild(right);
			card.appendChild(head);

			const badges = el('div', 'rx-actions');
			badges.style.marginTop = '8px';
			badges.appendChild(badge(KIND[race.track.kind] || race.track.kind, race.track.kind === 'circuit' ? 'cyan' : null));
			if (race.track.kind === 'circuit') { badges.appendChild(badge(race.laps + (race.laps === 1 ? ' volta' : ' voltas'))); }
			badges.appendChild(badge(race.classLabel, race.class === 'any' ? null : 'pink'));
			if (race.buyIn > 0) { badges.appendChild(badge('Aposta', 'yellow')); } else { badges.appendChild(badge('Só pela honra')); }
			card.appendChild(badges);

			const stats = el('div', 'rx-stats');
			stats.appendChild(stat('Entrada', race.buyIn > 0 ? race.buyInText : '—', 'money'));
			stats.appendChild(stat('Pote', race.buyIn > 0 ? race.potText : '—', 'money'));
			stats.appendChild(stat('Grid', race.racers.length + '/' + race.maxRacers));
			stats.appendChild(stat('Checkpoints', race.track.checkpoints));
			card.appendChild(stats);

			const racers = el('div', 'rx-racers');
			race.racers.forEach(function (racer) {
				const node = el('span', 'rx-racer', racer.nickname);
				node.appendChild(el('em', null, racer.rating));
				racers.appendChild(node);
			});
			for (let i = race.racers.length; i < Math.min(race.maxRacers, race.racers.length + 3); i += 1) {
				racers.appendChild(el('span', 'rx-racer is-empty', 'vaga'));
			}
			card.appendChild(racers);

			const actions = el('div', 'rx-actions');
			actions.appendChild(button('GPS da largada', 'ghost small', function () {
				const start = race.track.start;
				if (api.waypoint) { api.waypoint(start.x, start.y).then(function () { api.status('Largada marcada no GPS.', 'success'); }); }
			}));
			if (race.status === 'lobby') {
				if (race.joined) {
					actions.appendChild(button('Sair', 'danger small', function () {
						request('leave', { raceId: race.id }).then(function (data) {
							if (data) { ui.state = data; api.status(race.buyIn > 0 ? 'Você saiu. A entrada voltou para a carteira.' : 'Você saiu.', 'success'); render(); }
						});
					}));
				} else if (!ui.state.myRace && race.racers.length < race.maxRacers) {
					actions.appendChild(button('Entrar', 'go', function () { joinRace(race); }));
				}
				if (race.mine) {
					actions.appendChild(button('Largar agora', 'pink small', function () {
						request('startNow', { raceId: race.id }).then(function (data) {
							if (data) { ui.state = data; api.status('Todos para o grid! Largada em instantes.', 'success'); render(); }
						});
					}));
				}
			}
			if ((race.mine && race.status === 'lobby') || (options && options.staff)) {
				actions.appendChild(button('Cancelar', 'danger small', function () {
					request('cancelRace', { raceId: race.id }).then(function (data) {
						if (data) { ui.state = data; api.status('Corrida cancelada. Entradas devolvidas.', 'success'); render(); }
					});
				}));
			}
			card.appendChild(actions);
			return card;
		}

		function joinRace(race) {
			if (race.buyIn <= 0) {
				request('join', { raceId: race.id }).then(function (data) {
					if (data) { ui.state = data; api.status('Inscrito! Vá para a largada.', 'success'); render(); }
				});
				return;
			}
			request('wallets').then(function (data) {
				if (!data) { return; }
				modal(function (card, close) {
					card.appendChild(el('div', 'rx-card-title', 'Entrar: ' + race.track.name));
					card.appendChild(el('p', 'rx-hint', 'A entrada de ' + race.buyInText + ' fica travada até o fim da corrida. Se a corrida for cancelada, ela volta inteira (a taxa da rede não volta).'));
					if (!data.wallets.length) {
						card.appendChild(el('p', 'rx-hint rx-warn', 'Nenhuma carteira à mão. Tenha a carteira no celular, num papel ou pen drive no inventário.'));
						card.appendChild(button('Fechar', 'ghost', close));
						return;
					}
					const form = el('div', 'rx-form');
					const from = select(walletOptions(data.wallets), data.wallets[0].address);
					form.appendChild(field('Pagar com', from, true));
					const payoutOptions = [{ value: '', label: 'A mesma carteira' }].concat(walletOptions(data.wallets)).concat([{ value: '__other', label: 'Outro endereço…' }]);
					const payout = select(payoutOptions, '');
					form.appendChild(field('Receber prêmio em', payout, true));
					const other = input('text', '', { placeholder: 'Endereço da carteira' });
					const otherField = field('Endereço', other, true);
					otherField.hidden = true;
					form.appendChild(otherField);
					payout.addEventListener('change', function () { otherField.hidden = payout.value !== '__other'; });
					card.appendChild(form);
					const actions = el('div', 'rx-actions');
					actions.appendChild(button('Pagar e entrar', 'go', function () {
						const target = payout.value === '__other' ? other.value.trim() : payout.value;
						request('join', { raceId: race.id, from: from.value, payout: target }).then(function (result) {
							if (result) { ui.state = result; close(); api.status('Inscrito! Vá para a largada.', 'success'); render(); }
						});
					}));
					actions.appendChild(button('Voltar', 'ghost', close));
					card.appendChild(actions);
				});
			});
		}

		function renderRaces(body) {
			const state = ui.state;
			if (state.myRace) {
				body.appendChild(el('div', 'rx-h', 'Sua corrida'));
				body.appendChild(raceCard(state.myRace));
				body.appendChild(el('p', 'rx-hint', 'Na largada, esteja no grid, dentro do carro e no banco do motorista. Quem não estiver sai e recebe a entrada de volta. Para desistir correndo: /' + (state.quitCommand || 'sairdacorrida') + '.'));
			} else if (state.organizing) {
				body.appendChild(el('div', 'rx-h', 'Você organiza'));
				body.appendChild(raceCard(state.organizing));
			}
			const others = state.races.filter(function (race) { return !race.joined && !(state.organizing && state.organizing.id === race.id); });
			body.appendChild(el('div', 'rx-h', 'Rolando na cidade'));
			if (!others.length) {
				const empty = el('div', 'rx-empty');
				empty.appendChild(el('strong', null, 'Rua parada'));
				empty.appendChild(document.createTextNode('Nenhuma corrida aberta. Organize uma e chame a galera.'));
				body.appendChild(empty);
			}
			others.forEach(function (race) { body.appendChild(raceCard(race)); });
			if (state.admin) {
				const staff = el('div', 'rx-actions');
				staff.appendChild(button('Staff: todas as corridas', 'ghost small', function () {
					request('adminRaces').then(function (data) {
						if (!data) { return; }
						modal(function (card, close) {
							card.appendChild(el('div', 'rx-card-title', 'Corridas ativas'));
							if (!data.races.length) { card.appendChild(el('p', 'rx-hint', 'Nenhuma corrida ativa.')); }
							data.races.forEach(function (race) {
								const row = el('div', 'rx-actions');
								row.appendChild(el('span', null, '#' + race.id + ' ' + race.track.name + ' · ' + race.status + ' · ' + race.racers.length + ' pilotos'));
								row.appendChild(button('Cancelar', 'danger small', function () {
									request('cancelRace', { raceId: race.id }).then(function (result) {
										if (result) { ui.state = result; close(); api.status('Corrida cancelada pela staff.', 'success'); render(); }
									});
								}));
								card.appendChild(row);
							});
							card.appendChild(button('Fechar', 'ghost', close));
						});
					});
				}));
				body.appendChild(staff);
			}
			every(1000, function () {
				app.querySelectorAll('[data-start-at]').forEach(function (node) { node.textContent = countdownText(Number(node.dataset.startAt)); });
			});
			every(6000, function () {
				if (app.querySelector('.rx-modal')) { return; }
				loadState().then(function (data) { if (data && ui.tab === 'races') { render(); } });
			});
		}

		// Organizar ----------------------------------------------------------------------------------------------------

		function renderOrganize(body) {
			const state = ui.state;
			if (state.organizing) {
				body.appendChild(el('div', 'rx-h', 'Você já organiza'));
				body.appendChild(raceCard(state.organizing));
				return;
			}
			const limits = state.limits;
			body.appendChild(el('div', 'rx-h', 'Nova corrida'));
			const loading = el('p', 'rx-hint', 'Carregando pistas…');
			body.appendChild(loading);
			request('tracks').then(function (data) {
				loading.remove();
				if (!data) { return; }
				const list = data.tracks.filter(function (track) { return track.status !== 'hidden'; });
				if (!list.length) {
					const empty = el('div', 'rx-empty');
					empty.appendChild(el('strong', null, 'Sem pistas'));
					empty.appendChild(document.createTextNode('Ninguém gravou uma pista ainda. Veja a aba Pistas.'));
					body.appendChild(empty);
					return;
				}
				const form = el('div', 'rx-form');
				const trackSelect = select(list.map(function (track) {
					return { value: track.id, label: (track.status === 'featured' ? '★ ' : '') + track.name + ' · ' + (KIND[track.kind] || track.kind) + ' · ' + formatKm(track.length) };
				}), ui.preselect || list[0].id);
				ui.preselect = null;
				form.appendChild(field('Pista', trackSelect, true));
				const laps = input('number', 3, { min: 1, max: limits.maxLaps, step: 1 });
				const lapsField = field('Voltas', laps);
				form.appendChild(lapsField);
				const classSelect = select(state.classes.map(function (c) { return { value: c.id, label: c.label }; }), 'any');
				form.appendChild(field('Classe', classSelect));
				const buyIn = input('number', 0, { min: 0, max: limits.buyInMax / UNIT, step: 0.1 });
				form.appendChild(field('Entrada (NOX)', buyIn));
				const maxRacers = input('number', limits.maxRacers, { min: limits.minRacers, max: limits.maxRacers, step: 1 });
				form.appendChild(field('Máx. corredores', maxRacers));
				const startIn = input('number', 5, { min: limits.minStart, max: limits.maxStart, step: 1 });
				form.appendChild(field('Largada em (min)', startIn));
				const joinBox = input('checkbox');
				joinBox.checked = true;
				const joinLabel = el('label', 'rx-label rx-check');
				joinLabel.appendChild(joinBox);
				joinLabel.appendChild(document.createTextNode('Eu também corro'));
				form.appendChild(joinLabel);

				const money = el('div', 'rx-form is-wide');
				money.style.gridColumn = '1 / -1';
				form.appendChild(money);
				body.appendChild(form);

				let wallets = null;
				function syncTrack() {
					const track = list.find(function (t) { return String(t.id) === trackSelect.value; });
					lapsField.hidden = !track || track.kind !== 'circuit';
				}
				function syncMoney() {
					money.innerHTML = '';
					const units = Math.round((Number(buyIn.value) || 0) * UNIT);
					if (units <= 0) {
						money.appendChild(el('p', 'rx-hint is-wide', 'Sem aposta: corrida pela honra (e pelo ranking).'));
						return;
					}
					const fee = (limits.feeBps / 100).toLocaleString('pt-BR');
					money.appendChild(el('p', 'rx-hint is-wide', 'Cada corredor trava ' + formatNox(units) + ' na entrada. Você fica com ' + fee + '% do pote; o resto vai para os primeiros colocados.'));
					if (!wallets) {
						money.appendChild(el('p', 'rx-hint is-wide', 'Carregando carteiras…'));
						request('wallets').then(function (data) { wallets = data ? data.wallets : []; syncMoney(); });
						return;
					}
					if (!wallets.length) {
						money.appendChild(el('p', 'rx-hint rx-warn is-wide', 'Nenhuma carteira à mão para pagar ou receber.'));
						return;
					}
					money._from = select(walletOptions(wallets), wallets[0].address);
					money._fee = select(walletOptions(wallets), wallets[0].address);
					if (joinBox.checked) { money.appendChild(field('Pagar entrada com', money._from)); }
					money.appendChild(field('Taxa do organizador em', money._fee));
				}
				trackSelect.addEventListener('change', syncTrack);
				buyIn.addEventListener('change', syncMoney);
				joinBox.addEventListener('change', syncMoney);
				syncTrack();
				syncMoney();

				const actions = el('div', 'rx-actions');
				actions.appendChild(button('Abrir corrida', 'go', function () {
					const units = Math.round((Number(buyIn.value) || 0) * UNIT);
					const payload = {
						trackId: Number(trackSelect.value), laps: Number(laps.value) || 1, class: classSelect.value, buyIn: units,
						maxRacers: Number(maxRacers.value), startIn: Number(startIn.value), join: joinBox.checked
					};
					if (units > 0) {
						if (!money._fee) { api.status('Escolha uma carteira para a aposta.', 'error'); return; }
						payload.feeAddress = money._fee.value;
						if (joinBox.checked) { payload.from = money._from.value; }
					}
					request('createRace', payload).then(function (data) {
						if (data) { ui.state = data; api.status('Corrida aberta! Chame a galera.', 'success'); go('races'); }
					});
				}));
				body.appendChild(actions);
			});
		}

		// Pistas -------------------------------------------------------------------------------------------------------

		function trackBadges(track) {
			const row = el('div', 'rx-actions');
			row.style.marginTop = '6px';
			row.appendChild(badge(KIND[track.kind] || track.kind, track.kind === 'circuit' ? 'cyan' : null));
			if (track.status === 'featured') { row.appendChild(badge('★ Destaque', 'yellow')); }
			if (track.status === 'hidden') { row.appendChild(badge('Oculta', 'red')); }
			if (track.mine) { row.appendChild(badge('Sua', 'pink')); }
			return row;
		}

		function renderTracks(body) {
			if (ui.detail) { renderTrackDetail(body, ui.detail); return; }
			const head = el('div', 'rx-actions');
			head.style.margin = '0 0 12px';
			head.appendChild(button('Gravar nova pista', 'go', function () { recordForm(); }));
			body.appendChild(head);
			const loading = el('p', 'rx-hint', 'Carregando pistas…');
			body.appendChild(loading);
			request('tracks').then(function (data) {
				loading.remove();
				if (!data) { return; }
				if (!data.tracks.length) {
					const empty = el('div', 'rx-empty');
					empty.appendChild(el('strong', null, 'Nenhuma pista'));
					empty.appendChild(document.createTextNode('Seja o primeiro a riscar um traçado pela cidade.'));
					body.appendChild(empty);
				}
				data.tracks.forEach(function (track) {
					const card = el('div', 'rx-card rx-track' + (track.mine ? ' is-mine' : ''));
					const thumb = el('div', 'rx-map');
					thumb.style.display = 'flex';
					thumb.style.alignItems = 'center';
					thumb.style.justifyContent = 'center';
					thumb.appendChild(el('span', 'rx-pos p1', track.checkpoints + ' CP'));
					card.appendChild(thumb);
					const info = el('div');
					info.appendChild(el('div', 'rx-card-title', track.name));
					info.appendChild(el('div', 'rx-card-sub', formatKm(track.length) + ' por volta · ' + track.races + ' corridas · por ' + (track.creator || '—')));
					if (track.description) { info.appendChild(el('div', 'rx-card-sub', track.description)); }
					info.appendChild(trackBadges(track));
					card.appendChild(info);
					card.addEventListener('click', function () { openTrack(track.id, 3); });
					body.appendChild(card);
				});
			});
		}

		function openTrack(id, laps) {
			request('track', { id: id, laps: laps }).then(function (data) {
				if (data) { ui.detail = data; render(); }
			});
		}

		function recordsTable(list, label) {
			const wrap = el('div');
			wrap.appendChild(el('div', 'rx-h', label));
			if (!list.length) { wrap.appendChild(el('p', 'rx-hint', 'Sem tempos ainda.')); return wrap; }
			const table = el('table', 'rx-table');
			table.innerHTML = '<thead><tr><th>#</th><th>Piloto</th><th>Carro</th><th class="num">Tempo</th></tr></thead>';
			const tbody = el('tbody');
			list.forEach(function (row, index) {
				const tr = el('tr');
				const pos = el('td');
				pos.appendChild(el('span', 'rx-pos p' + (index + 1), index + 1));
				tr.appendChild(pos);
				tr.appendChild(el('td', null, row.nickname));
				tr.appendChild(el('td', null, row.vehicle || '—'));
				tr.appendChild(el('td', 'num', formatTime(row.ms)));
				tbody.appendChild(tr);
			});
			table.appendChild(tbody);
			wrap.appendChild(table);
			return wrap;
		}

		function renderTrackDetail(body, data) {
			const track = data.track;
			const back = el('div', 'rx-actions');
			back.style.margin = '0 0 12px';
			back.appendChild(button('← Pistas', 'ghost small', function () { ui.detail = null; render(); }));
			body.appendChild(back);
			const card = el('div', 'rx-card');
			const grid = el('div', 'rx-detail');
			grid.appendChild(trackMap(track.startFull || track.start, track.points, true));
			const info = el('div');
			info.appendChild(el('div', 'rx-card-title', track.name));
			info.appendChild(el('div', 'rx-card-sub', 'Criada por ' + (track.creator || '—')));
			if (track.description) { info.appendChild(el('p', 'rx-hint', track.description)); }
			info.appendChild(trackBadges(track));
			const stats = el('div', 'rx-stats');
			stats.appendChild(stat('Volta', formatKm(track.length)));
			stats.appendChild(stat('Checkpoints', track.checkpoints));
			stats.appendChild(stat('Corridas', track.races));
			info.appendChild(stats);
			const actions = el('div', 'rx-actions');
			actions.appendChild(button('GPS da largada', 'ghost small', function () {
				if (api.waypoint) { api.waypoint(track.start.x, track.start.y).then(function () { api.status('Largada marcada no GPS.', 'success'); }); }
			}));
			if (track.status !== 'hidden' && !ui.state.organizing) {
				actions.appendChild(button('Organizar aqui', 'go small', function () { ui.preselect = track.id; go('organize'); }));
			}
			function setStatus(status, message) {
				request('trackStatus', { id: track.id, status: status }).then(function (result) {
					if (result) { api.status(message, 'success'); openTrack(track.id, data.recordLaps); }
				});
			}
			if (ui.state.admin) {
				if (track.status !== 'featured') { actions.appendChild(button('★ Destacar', 'small', function () { setStatus('featured', 'Pista em destaque.'); })); }
				if (track.status === 'featured') { actions.appendChild(button('Tirar destaque', 'small', function () { setStatus('active', 'Destaque removido.'); })); }
			}
			if (ui.state.admin || track.mine) {
				if (track.status === 'hidden') {
					actions.appendChild(button('Reativar', 'small', function () { setStatus('active', 'Pista reativada.'); }));
				} else {
					actions.appendChild(button('Ocultar', 'danger small', function () { setStatus('hidden', 'Pista oculta.'); }));
				}
			}
			info.appendChild(actions);
			grid.appendChild(info);
			card.appendChild(grid);
			body.appendChild(card);
			body.appendChild(recordsTable(data.records.laps || [], 'Melhores voltas'));
			const total = recordsTable(data.records.total || [], track.kind === 'circuit' ? 'Melhores tempos (' + data.recordLaps + ' voltas)' : 'Melhores tempos');
			if (track.kind === 'circuit') {
				const lapPick = select([1, 2, 3, 5, 10].map(function (n) { return { value: n, label: n + (n === 1 ? ' volta' : ' voltas') }; }), data.recordLaps);
				lapPick.style.width = 'auto';
				lapPick.addEventListener('change', function () { openTrack(track.id, Number(lapPick.value)); });
				total.querySelector('.rx-h').appendChild(lapPick);
			}
			body.appendChild(total);
		}

		function recordForm() {
			const state = ui.state;
			const limits = state.limits;
			modal(function (card, close) {
				card.appendChild(el('div', 'rx-card-title', 'Gravar pista'));
				if (!state.admin && state.profile.races < limits.minRacesToCreate) {
					card.appendChild(el('p', 'rx-hint rx-warn', 'Só quem já correu ' + limits.minRacesToCreate + ' corridas risca traçado novo. Você tem ' + state.profile.races + '.'));
					card.appendChild(button('Fechar', 'ghost', close));
					return;
				}
				const form = el('div', 'rx-form');
				const name = input('text', '', { maxlength: 32, placeholder: 'ex.: Descida do Vinewood' });
				form.appendChild(field('Nome', name, true));
				const description = input('text', '', { maxlength: 160, placeholder: 'Opcional: o que esperar do traçado' });
				form.appendChild(field('Descrição', description, true));
				const kind = select([{ value: 'sprint', label: 'Sprint (A → B)' }, { value: 'circuit', label: 'Circuito (com voltas)' }], 'sprint');
				form.appendChild(field('Tipo', kind, true));
				let featured = null;
				if (state.admin) {
					featured = input('checkbox');
					const label = el('label', 'rx-label rx-check is-wide');
					label.appendChild(featured);
					label.appendChild(document.createTextNode('Publicar em destaque (staff)'));
					form.appendChild(label);
				}
				card.appendChild(form);
				const how = el('p', 'rx-hint');
				how.innerHTML = 'Feche o tablet e dirija: pare na largada e aperte <b>Y</b> (marca a largada e a direção do grid). '
					+ 'Siga o traçado apertando <b>Y</b> em cada checkpoint (mínimo ' + limits.minSpacing + ' m entre eles, de '
					+ limits.minCheckpoints + ' a ' + limits.maxCheckpoints + '). <b>U</b> desfaz, <b>Enter</b> salva, <b>Delete</b> cancela. '
					+ 'No circuito, a chegada é na própria largada.';
				card.appendChild(how);
				const actions = el('div', 'rx-actions');
				actions.appendChild(button('Começar a gravar', 'go', function () {
					request('startRecording', {
						name: name.value.trim(), description: description.value.trim(), kind: kind.value, featured: featured ? featured.checked : false
					}).then(function (data) {
						if (data) { close(); api.status('Gravando! Feche o tablet e vá até a largada.', 'success'); }
					});
				}));
				actions.appendChild(button('Voltar', 'ghost', close));
				card.appendChild(actions);
			});
		}

		// Ranking e histórico ---------------------------------------------------------------------------------------------

		function renderRanking(body) {
			const me = ui.state.profile;
			const card = el('div', 'rx-card is-mine');
			card.appendChild(el('div', 'rx-card-title', me.nickname));
			const stats = el('div', 'rx-stats');
			stats.appendChild(stat('Rating', me.rating, 'time'));
			stats.appendChild(stat('Corridas', me.races));
			stats.appendChild(stat('Vitórias', me.wins));
			stats.appendChild(stat('Pódios', me.podiums));
			stats.appendChild(stat('Abandonos', me.dnfs));
			stats.appendChild(stat('Prêmios', formatNox(me.prize), 'money'));
			card.appendChild(stats);
			body.appendChild(card);
			body.appendChild(el('div', 'rx-h', 'Os mais brabos da cidade'));
			request('leaderboard').then(function (data) {
				if (!data) { return; }
				if (!data.leaders.length) { body.appendChild(el('p', 'rx-hint', 'Ninguém correu ainda.')); return; }
				const table = el('table', 'rx-table');
				table.innerHTML = '<thead><tr><th>#</th><th>Piloto</th><th class="num">Rating</th><th class="num">Vitórias</th><th class="num">Pódios</th><th class="num">Corridas</th></tr></thead>';
				const tbody = el('tbody');
				data.leaders.forEach(function (row, index) {
					const tr = el('tr', row.nickname === me.nickname ? 'is-me' : null);
					const pos = el('td');
					pos.appendChild(el('span', 'rx-pos p' + (index + 1), index + 1));
					tr.appendChild(pos);
					tr.appendChild(el('td', null, row.nickname));
					tr.appendChild(el('td', 'num', row.rating));
					tr.appendChild(el('td', 'num', row.wins));
					tr.appendChild(el('td', 'num', row.podiums));
					tr.appendChild(el('td', 'num', row.races));
					tbody.appendChild(tr);
				});
				table.appendChild(tbody);
				body.appendChild(table);
			});
		}

		function renderHistory(body) {
			body.appendChild(el('div', 'rx-h', 'Suas últimas corridas'));
			request('history').then(function (data) {
				if (!data) { return; }
				if (!data.history.length) {
					const empty = el('div', 'rx-empty');
					empty.appendChild(el('strong', null, 'Ficha limpa'));
					empty.appendChild(document.createTextNode('Você ainda não correu.'));
					body.appendChild(empty);
					return;
				}
				const table = el('table', 'rx-table');
				table.innerHTML = '<thead><tr><th>Pos.</th><th>Pista</th><th class="num">Tempo</th><th class="num">Melhor volta</th><th class="num">Rating</th><th class="num">Prêmio</th></tr></thead>';
				const tbody = el('tbody');
				data.history.forEach(function (row) {
					const tr = el('tr');
					const pos = el('td');
					pos.appendChild(el('span', 'rx-pos' + (row.dnf ? '' : ' p' + row.position), row.dnf ? 'DNF' : row.position + 'º/' + row.racers));
					tr.appendChild(pos);
					tr.appendChild(el('td', null, row.track + (row.laps > 1 ? ' (' + row.laps + 'v)' : '')));
					tr.appendChild(el('td', 'num', row.dnf ? '—' : formatTime(row.timeMs)));
					tr.appendChild(el('td', 'num', formatTime(row.bestLapMs)));
					tr.appendChild(el('td', 'num ' + (row.ratingDelta >= 0 ? 'rx-up' : 'rx-down'), (row.ratingDelta >= 0 ? '+' : '') + row.ratingDelta));
					tr.appendChild(el('td', 'num', row.prize > 0 ? formatNox(row.prize) : '—'));
					tbody.appendChild(tr);
				});
				table.appendChild(tbody);
				body.appendChild(table);
			});
		}

		// Render ---------------------------------------------------------------------------------------------------------

		function render() {
			const body = frame();
			if (!ui.state) { body.appendChild(el('p', 'rx-hint', 'Conectando na rede…')); return; }
			if (!ui.state.profile) { renderGate(body); return; }
			if (ui.tab === 'races') { renderRaces(body); }
			else if (ui.tab === 'organize') { renderOrganize(body); }
			else if (ui.tab === 'tracks') { renderTracks(body); }
			else if (ui.tab === 'ranking') { renderRanking(body); }
			else if (ui.tab === 'history') { renderHistory(body); }
		}

		render();
		loadState().then(function () { render(); });
	});
})();
