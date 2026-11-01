// App Minha linha (coe_telecom) no smartphone do COE OS: saldo, plano, consumo, recarga, faturas e extrato.
(function () {
	'use strict';

	const ERRORS = {
		not_ready: 'Operadora ainda iniciando.', no_character: 'Personagem não carregado.',
		database_error: 'Falha ao gravar. Tente de novo.', unknown_action: 'Ação desconhecida.',
		insufficient_funds: 'Saldo insuficiente na conta do banco.', economy_unavailable: 'Banco indisponível no momento.',
		invalid_amount: 'Valor de recarga inválido.', balance_full: 'Limite de crédito atingido.',
		not_prepaid: 'Recarga só no pré-pago.', unknown_plan: 'Plano inexistente.', same_plan: 'Você já está nesse plano.',
		plan_cooldown: 'Você trocou de plano há pouco. Aguarde para trocar de novo.',
		open_invoice: 'Pague as faturas em aberto antes de ir para o pós-pago.', already_paid: 'Essa fatura já foi paga.',
		invalid_request: 'Pedido inválido.',
		no_sim: 'Coloque um chip no celular para ver a linha.', no_phone: 'Você não tem um celular.',
		not_holder: 'Só o titular do chip pode trocar o plano.',
		holder_required: 'Chip sem titular não pode ter plano pós-pago.'
	};

	const KINDS = { voice: 'Ligação', video: 'Vídeo', sms: 'Mensagem', recharge: 'Recarga', invoice: 'Fatura paga' };

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

	function money(value) {
		return '$ ' + Number(value || 0).toLocaleString('pt-BR');
	}

	function date(seconds) {
		if (!seconds) { return '-'; }
		const d = new Date(Number(seconds) * 1000);
		return String(d.getDate()).padStart(2, '0') + '/' + String(d.getMonth() + 1).padStart(2, '0') + ' ' +
			String(d.getHours()).padStart(2, '0') + ':' + String(d.getMinutes()).padStart(2, '0');
	}

	function line(label, value) {
		const node = el('div', 'tb-line');
		node.append(el('span', 'tb-muted', label), el('strong', null, value));
		return node;
	}

	function meter(used, total) {
		const ratio = total > 0 ? Math.min(1, used / total) : 0;
		const node = el('div', 'tb-meter' + (ratio >= 1 ? ' bad' : ratio >= 0.8 ? ' warn' : ''));
		const fill = el('i');
		fill.style.width = Math.round(ratio * 100) + '%';
		node.appendChild(fill);
		return node;
	}

	function card(title, badge, badgeClass) {
		const box = el('div', 'coe-panel coe-panel--compact tb-card');
		const head = el('div', 'tb-card-head');
		head.appendChild(el('strong', null, title));
		if (badge) { head.appendChild(el('span', 'coe-badge ' + (badgeClass || ''), badge)); }
		box.appendChild(head);
		return box;
	}

	function rates(plan) {
		if (!plan.rates) { return 'Voz, vídeo e mensagens ilimitados'; }
		const parts = ['voz ' + money(plan.rates.voice) + '/min', 'vídeo ' + money(plan.rates.video) + '/min'];
		if (plan.rates.sms) { parts.push('SMS ' + money(plan.rates.sms)); }
		return (plan.kind === 'postpaid' ? 'Excedente: ' : '') + parts.join(' · ');
	}

	window.CoePhone.register('line', function (root, api) {
		let data = null;
		let tab = 'summary';
		let busy = false;

		function errorText(code) { return ERRORS[code] || api.errorText(code); }

		function act(action, payload, message) {
			if (busy) { return; }
			busy = true;
			api.call('line', action, payload).then(function (result) {
				busy = false;
				if (!result || !result.ok) { api.status(errorText(result && result.error), 'error'); return; }
				data = result;
				if (message) { api.status(message, 'success'); }
				paint();
			});
		}

		function summary(body) {
			const info = data.line;
			const suspended = info.status !== 'active';
			const box = card(info.planLabel, suspended ? 'Suspensa' : 'Ativa', suspended ? 'tb-badge--warn' : 'coe-badge--success');
			box.appendChild(el('span', 'tb-muted', info.carrier + (info.number ? ' · ' + info.number : '')));
			if (suspended) {
				box.appendChild(el('div', 'tb-alert', 'Linha suspensa: você não liga nem manda mensagens até pagar a fatura.'));
			}
			const lines = el('div', 'tb-lines');
			if (info.kind === 'prepaid') {
				const total = el('div', 'tb-total');
				total.append(el('span', null, 'Crédito'), el('strong', null, money(info.balance)));
				box.appendChild(total);
				lines.append(line('Voz', money(info.rates.voice) + '/min'), line('Vídeo', money(info.rates.video) + '/min'));
				box.appendChild(lines);
				box.appendChild(el('div', 'tb-actions')).appendChild(button('Recarregar', 'coe-button--primary', function () { tab = 'recharge'; paint(); }));
			} else {
				lines.append(line('Mensalidade', money(info.monthly)), line('Fecha o ciclo em', date(info.cycleEnd)));
				box.appendChild(lines);
				if (info.allowance) {
					[['voice', 'Voz', info.voiceUsed], ['video', 'Vídeo', info.videoUsed]].forEach(function (entry) {
						const limit = info.allowance[entry[0]] || 0;
						const label = el('div', 'tb-total');
						label.append(el('span', null, entry[1]), el('span', null, entry[2] + ' / ' + limit + ' min'));
						box.append(label, meter(entry[2], limit));
					});
				} else {
					box.appendChild(el('p', 'tb-muted', 'Uso no ciclo: ' + info.voiceUsed + ' min de voz, ' + info.videoUsed + ' min de vídeo.'));
				}
			}
			body.appendChild(box);
			const open = (data.invoices || []).filter(function (invoice) { return invoice.status === 'open'; });
			if (open.length) {
				const alert = el('div', 'tb-alert', open.length + ' fatura(s) em aberto.');
				alert.style.cursor = 'pointer';
				alert.addEventListener('click', function () { tab = 'invoices'; paint(); });
				body.appendChild(alert);
			}
		}

		function recharge(body) {
			const info = data.line;
			if (info.kind !== 'prepaid') {
				body.appendChild(el('p', 'tb-empty', 'Recarga só no pré-pago. No seu plano o uso vem na fatura.'));
				return;
			}
			const box = card('Recarga', 'Crédito ' + money(info.balance), 'tb-badge--accent');
			box.appendChild(el('span', 'tb-muted', 'Debitado da sua conta no banco. Limite de ' + money(data.maxBalance) + '.'));
			const options = el('div', 'tb-actions');
			options.style.justifyContent = 'flex-start';
			(data.recharges || []).forEach(function (value) {
				options.appendChild(button(money(value), 'coe-button--primary', function () {
					act('recharge', { amount: value }, 'Recarga de ' + money(value) + ' feita.');
				}));
			});
			box.appendChild(options);
			body.appendChild(box);
		}

		function plans(body) {
			const info = data.line;
			if (info.planChangeAt && info.planChangeAt > Date.now() / 1000) {
				body.appendChild(el('div', 'tb-alert', 'Próxima troca de plano liberada em ' + date(info.planChangeAt) + '.'));
			}
			(data.plans || []).forEach(function (plan) {
				const mine = plan.id === info.plan;
				const box = card(plan.label, mine ? 'Seu plano' : (plan.kind === 'postpaid' ? money(plan.monthly) + '/ciclo' : 'Sem mensalidade'),
					mine ? 'coe-badge--success' : 'tb-badge--accent');
				if (plan.description) { box.appendChild(el('p', 'tb-muted', plan.description)); }
				box.appendChild(el('span', 'tb-muted', rates(plan)));
				if (!mine) {
					const actions = el('div', 'tb-actions');
					const note = info.kind === 'postpaid' ? 'O ciclo atual fecha agora com fatura proporcional.' : '';
					let armed = false;
					const change = button('Mudar para ' + plan.label, '', function () {
						if (!armed) {
							armed = true;
							change.textContent = 'Confirmar mudança';
							change.classList.add('coe-button--primary');
							if (note) { api.status(note, 'info'); }
							return;
						}
						act('plan', { plan: plan.id }, 'Plano alterado para ' + plan.label + '.');
					});
					actions.appendChild(change);
					box.appendChild(actions);
				}
				body.appendChild(box);
			});
		}

		function invoices(body) {
			const list = data.invoices || [];
			if (!list.length) { body.appendChild(el('p', 'tb-empty', 'Nenhuma fatura ainda.')); return; }
			list.forEach(function (invoice) {
				const open = invoice.status === 'open';
				const overdue = open && invoice.dueAt < Date.now() / 1000;
				const box = card('Fatura #' + invoice.id + ' · ' + money(invoice.amount),
					open ? (overdue ? 'Vencida' : 'Em aberto') : 'Paga', open ? 'tb-badge--warn' : 'coe-badge--success');
				const lines = el('div', 'tb-lines');
				lines.append(line('Período', date(invoice.from) + ' a ' + date(invoice.to)));
				const parts = {};
				String(invoice.details || '').split(';').forEach(function (pair) {
					const kv = pair.split(':');
					if (kv.length === 2) { parts[kv[0]] = Number(kv[1]) || 0; }
				});
				lines.append(line('Mensalidade', money(parts.base)));
				if (parts.extra) {
					lines.append(line('Excedente (' + (parts.voice || 0) + ' min voz, ' + (parts.video || 0) + ' min vídeo)', money(parts.extra)));
				}
				lines.append(line(open ? 'Vence em' : 'Paga em', date(open ? invoice.dueAt : invoice.paidAt)));
				box.appendChild(lines);
				if (open) {
					const actions = el('div', 'tb-actions');
					actions.appendChild(button('Pagar ' + money(invoice.amount), 'coe-button--primary', function () {
						act('pay', { id: invoice.id }, 'Fatura paga.');
					}));
					box.appendChild(actions);
				}
				body.appendChild(box);
			});
		}

		function usage(body) {
			const list = data.usage || [];
			if (!list.length) { body.appendChild(el('p', 'tb-empty', 'Nenhum uso registrado.')); return; }
			const lines = el('div', 'tb-lines');
			list.forEach(function (entry) {
				let label = KINDS[entry.kind] || entry.kind;
				if (entry.peer) { label += ' · ' + api.formatNumber(entry.peer); }
				if (entry.kind === 'voice' || entry.kind === 'video') { label += ' · ' + entry.units + ' min'; }
				const value = entry.kind === 'recharge' ? '+ ' + money(entry.cost) : (entry.cost ? money(entry.cost) : 'franquia');
				const node = line(label, value);
				node.title = date(entry.at);
				lines.appendChild(node);
			});
			body.appendChild(lines);
		}

		const TABS = [['summary', 'Resumo', summary], ['recharge', 'Recarga', recharge], ['plans', 'Planos', plans],
			['invoices', 'Faturas', invoices], ['usage', 'Extrato', usage]];

		function paint() {
			root.replaceChildren();
			const wrap = el('div');
			wrap.style.display = 'grid';
			wrap.style.gap = '10px';
			const tabs = el('div', 'tb-tabs');
			const body = el('div');
			body.style.display = 'grid';
			body.style.gap = '10px';
			TABS.forEach(function (entry) {
				const node = el('button', 'tb-tab' + (entry[0] === tab ? ' is-active' : ''), entry[1]);
				node.type = 'button';
				if (entry[0] === 'invoices') {
					const open = (data.invoices || []).filter(function (invoice) { return invoice.status === 'open'; }).length;
					if (open) { node.appendChild(el('span', 'tb-count', open)); }
				}
				node.addEventListener('click', function () { tab = entry[0]; paint(); });
				tabs.appendChild(node);
			});
			TABS.forEach(function (entry) { if (entry[0] === tab) { entry[2](body); } });
			wrap.append(tabs, body);
			root.appendChild(wrap);
		}

		root.replaceChildren(el('p', 'tb-empty', 'Carregando...'));
		api.call('line', 'overview').then(function (result) {
			if (!result || !result.ok) {
				root.replaceChildren(el('p', 'tb-empty', errorText(result && result.error)));
				return;
			}
			data = result;
			paint();
		});
	});
})();
