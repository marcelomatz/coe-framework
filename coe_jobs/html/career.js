// App Carreira (COE OS no tablet): histórico do jogador nos empregos livres do coe_jobs.
// Nível de carreira, reputação, habilidades compartilhadas entre empregos e cada emprego com nível, bônus e GPS.
(function () {
	'use strict';

	const PERKS = {
		pay: function (v) { return '+' + pct(v) + ' de pagamento'; },
		speed: function (v) { return '-' + pct(v) + ' no tempo das ações'; },
		capacity: function (v) { return '+' + pct(v) + ' de carga'; },
		deposit: function (v) { return '-' + pct(v) + ' no depósito do veículo'; }
	};
	const KINDS = { gather: 'Coleta', route: 'Rota' };

	function pct(value) { return Math.round((value || 0) * 100) + '%'; }
	function money(value) { return '$ ' + Math.floor(value || 0).toLocaleString('pt-BR'); }
	function el(tag, className, text) {
		const node = document.createElement(tag);
		if (className) { node.className = className; }
		if (text !== undefined && text !== null) { node.textContent = text; }
		return node;
	}
	function line(label, value) {
		const row = el('div', 'tb-line');
		row.append(el('span', null, label), el('strong', null, value));
		return row;
	}
	// Barra de progresso até o próximo nível (tb-meter do coe_ui).
	function meter(xp, floor, next) {
		const bar = el('div', 'tb-meter');
		const fill = el('i');
		const ratio = next ? Math.max(0, Math.min(1, (xp - floor) / Math.max(1, next - floor))) : 1;
		fill.style.width = Math.round(ratio * 100) + '%';
		fill.style.display = 'block';
		fill.style.height = '100%';
		fill.style.background = 'var(--coe-accent)';
		bar.appendChild(fill);
		return bar;
	}
	function levelText(level, max, xp, next) {
		return 'Nível ' + level + '/' + max + ' · ' + xp + ' XP' + (next ? ' (próximo: ' + next + ')' : ' · máximo');
	}

	function card(title, badge) {
		const box = el('section', 'tb-card coe-panel');
		const head = el('div', 'tb-card-head');
		head.appendChild(el('strong', null, title));
		if (badge) { head.appendChild(el('span', 'tb-badge tb-badge--accent', badge)); }
		box.appendChild(head);
		return box;
	}

	// Renderizador do guia "Como funciona" (o mesmo da tela do NPC), carregado uma vez do coe_jobs.
	let guideLoader = null;
	function loadGuideView() {
		if (window.CoeJobGuide) { return Promise.resolve(window.CoeJobGuide); }
		if (!guideLoader) {
			guideLoader = new Promise(function (resolve, reject) {
				const script = document.createElement('script');
				script.src = 'nui://coe_jobs/html/guide-view.js';
				script.onload = function () { resolve(window.CoeJobGuide); };
				script.onerror = reject;
				document.head.appendChild(script);
			}).catch(function () { guideLoader = null; return null; });
		}
		return guideLoader;
	}

	function showGuide(container, api, jobId) {
		container.replaceChildren(el('p', 'tb-empty', 'Carregando o guia...'));
		Promise.all([loadGuideView(), api.call('career', 'guide', { jobId: jobId })]).then(function (results) {
			const view = results[0];
			const result = results[1];
			container.replaceChildren();
			const actions = el('div', 'tb-actions');
			const back = el('button', 'coe-button', '‹ Voltar à carreira');
			back.type = 'button';
			back.addEventListener('click', function () { render(container, api); });
			actions.appendChild(back);
			container.appendChild(actions);
			if (!view || !result || !result.ok) {
				container.appendChild(el('p', 'tb-empty', api.errorText((result && result.error) || 'app_error')));
				return;
			}
			const holder = el('div');
			view.render(holder, result.data);
			container.appendChild(holder);
		});
	}

	function render(container, api) {
		container.replaceChildren(el('p', 'tb-empty', 'Carregando seu histórico...'));
		Promise.all([api.call('career', 'profile'), loadGuideView()]).then(function (results) {
			const result = results[0];
			container.replaceChildren();
			if (!result || !result.ok) {
				container.appendChild(el('p', 'tb-empty', api.errorText((result && result.error) || 'app_error')));
				return;
			}
			const data = result.data;

			const top = el('div', 'tb-grid');
			const careerCard = card('Carreira', 'Nível ' + data.level);
			careerCard.appendChild(meter(data.xp, 0, data.nextXp));
			const careerLines = el('div', 'tb-lines');
			careerLines.append(
				line('Experiência total', levelText(data.level, data.maxLevel, data.xp, data.nextXp)),
				line('Bônus em todos os empregos', '+' + pct(data.payBonus) + ' pagamento · +' + pct(data.xpBonus) + ' XP'),
				line('Tarefas feitas', String(data.tasks)),
				line('Ganhos', money(data.earned))
			);
			careerCard.appendChild(careerLines);

			const repCard = card('Reputação', data.tier);
			const repLines = el('div', 'tb-lines');
			repLines.append(
				line('Pontos', String(data.reputation)),
				line('Concluídos / abandonados', data.completed + ' / ' + data.abandoned),
				line('Efeito', data.depositWaived ? 'Sem depósito de veículo' + (data.tierPay ? ' · +' + pct(data.tierPay) + ' pagamento' : '')
					: (data.tierPay ? '+' + pct(data.tierPay) + ' de pagamento' : (data.reputation < -19 ? 'Depósito dobrado' : 'Nenhum')))
			);
			repCard.append(repLines, el('p', 'tb-muted', 'Concluir vendas e rotas sobe a reputação; sair com o veículo da empresa ou não devolvê-lo derruba.'));
			top.append(careerCard, repCard);
			container.appendChild(top);

			container.appendChild(el('div', 'tb-section', 'Últimos trabalhos'));
			const recent = card('Seus últimos trabalhos', data.sessions && data.sessions.length ? String(data.sessions.length) : null);
			if (window.CoeJobGuide) {
				window.CoeJobGuide.injectStyle();
				recent.appendChild(window.CoeJobGuide.history(data.sessions, true));
			} else {
				recent.appendChild(el('p', 'tb-muted', (data.sessions || []).length + ' trabalhos recentes.'));
			}
			recent.appendChild(el('p', 'tb-muted', 'Na coleta, só a venda paga: encerrar com carga descarta o que você carrega.'));
			container.appendChild(recent);

			container.appendChild(el('div', 'tb-section', 'Habilidades — valem em todos os empregos que as usam'));
			const skills = el('div', 'tb-grid');
			data.skills.forEach(function (skill) {
				const box = card(skill.label, 'Nível ' + skill.level);
				box.appendChild(meter(skill.xp, 0, skill.nextXp));
				const lines = el('div', 'tb-lines');
				lines.appendChild(line('XP', skill.xp + (skill.nextXp ? ' / ' + skill.nextXp : ' · máximo')));
				skill.perks.forEach(function (perk) {
					const text = PERKS[perk.perk] ? PERKS[perk.perk](perk.value) : perk.perk;
					lines.appendChild(line('Agora', text));
					lines.appendChild(line('Por nível', PERKS[perk.perk] ? PERKS[perk.perk](perk.perLevel) : String(perk.perLevel)));
				});
				box.appendChild(lines);
				skills.appendChild(box);
			});
			container.appendChild(skills);

			container.appendChild(el('div', 'tb-section', 'Empregos'));
			const list = el('div', 'tb-grid');
			data.jobs.forEach(function (job) {
				const badge = data.working === job.id ? 'Trabalhando' : (job.allowed ? 'Nível ' + job.level : 'Bloqueado');
				const box = card(job.label, badge);
				if (job.description) { box.appendChild(el('p', 'tb-muted', job.description)); }
				box.appendChild(meter(job.xp, 0, job.nextXp));
				const lines = el('div', 'tb-lines');
				lines.append(
					line('Tipo', KINDS[job.kind] || job.kind),
					line('Progresso', levelText(job.level, job.maxLevel, job.xp, job.nextXp)),
					line('Tarefas feitas', String(job.tasks || 0)),
					line('Treina', job.skills.join(', ') || '—'),
					line('Seu bônus aqui', '+' + pct(job.payBonus) + ' pagamento · ×' + job.xpMultiplier.toFixed(2) + ' XP')
				);
				if (job.capacity) { lines.appendChild(line('Carga / tempo da ação', job.capacity + ' · ' + job.seconds.toFixed(1) + ' s')); }
				if (job.deposit !== undefined && job.deposit !== null) { lines.appendChild(line('Depósito do veículo', job.deposit > 0 ? money(job.deposit) : 'Dispensado')); }
				lines.appendChild(line('Ganhos', money(job.earned)));
				box.appendChild(lines);
				if (!job.allowed) { box.appendChild(el('div', 'tb-alert', 'Precisa de ' + job.lockedReason + '.')); }
				const actions = el('div', 'tb-actions');
				const gps = el('button', 'coe-button', 'Marcar no GPS');
				gps.type = 'button';
				gps.addEventListener('click', function () {
					api.waypoint(job.center.x, job.center.y).then(function () { api.status('Ponto do emprego marcado no GPS.', 'success'); });
				});
				const how = el('button', 'coe-button coe-button--primary', 'Como funciona');
				how.type = 'button';
				how.addEventListener('click', function () { showGuide(container, api, job.id); });
				actions.append(how, gps);
				box.appendChild(actions);
				list.appendChild(box);
			});
			container.appendChild(list);
		});
	}

	if (window.CoeTablet) { window.CoeTablet.register('career', render); }
})();
