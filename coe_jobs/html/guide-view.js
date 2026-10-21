// Guia "Como funciona" de um emprego do coe_jobs: usado pela tela do NPC (guide.html) e pelo app Carreira do tablet.
// Expõe window.CoeJobGuide.render(container, guide, options). Estilo próprio (prefixo cjg-) sobre os tokens do coe_ui.
(function () {
	'use strict';

	const REASONS = {
		stop: 'Encerrado',
		dropped: 'Saiu do jogo',
		character: 'Trocou de personagem',
		unavailable: 'Emprego indisponível'
	};

	const STYLE = `
.cjg { display: grid; gap: var(--coe-space-4, 16px); color: var(--coe-text); font-family: var(--coe-font); font-size: var(--coe-text-md, 14px); }
.cjg-head { display: grid; gap: 6px; }
.cjg-eyebrow { margin: 0; color: var(--coe-accent); font-size: var(--coe-text-xs, 11px); letter-spacing: 0.14em; text-transform: uppercase; }
.cjg-title { margin: 0; font-size: 24px; font-weight: 600; letter-spacing: 0.01em; }
.cjg-desc { margin: 0; color: var(--coe-muted); line-height: 1.45; }
.cjg-badges { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 4px; }
.cjg-badge { padding: 3px 8px; border: 1px solid var(--coe-line-strong); color: var(--coe-muted); font-size: var(--coe-text-xs, 11px); letter-spacing: 0.06em; text-transform: uppercase; }
.cjg-badge--ok { border-color: rgba(var(--coe-success-rgb), 0.5); color: var(--coe-success); }
.cjg-badge--lock { border-color: rgba(var(--coe-danger-rgb), 0.5); color: var(--coe-danger); }
.cjg-badge--accent { border-color: rgba(var(--coe-accent-rgb), 0.55); color: var(--coe-accent); background: var(--coe-accent-soft); }
.cjg-cols { display: grid; grid-template-columns: minmax(0, 1.25fr) minmax(0, 1fr); gap: var(--coe-space-4, 16px); align-items: start; }
@media (max-width: 720px) { .cjg-cols { grid-template-columns: minmax(0, 1fr); } }
.cjg-block { display: grid; gap: 10px; padding: 14px 16px; border: 1px solid var(--coe-line); background: rgba(var(--coe-ink-rgb), 0.025); }
.cjg-block h3 { margin: 0; color: var(--coe-muted); font-size: var(--coe-text-xs, 11px); font-weight: 600; letter-spacing: 0.14em; text-transform: uppercase; }
.cjg-steps { display: grid; gap: 10px; margin: 0; padding: 0; list-style: none; counter-reset: cjg-step; }
.cjg-steps li { position: relative; padding-left: 34px; line-height: 1.45; counter-increment: cjg-step; }
.cjg-steps li::before { position: absolute; top: -1px; left: 0; display: grid; place-items: center; width: 22px; height: 22px; border: 1px solid rgba(var(--coe-accent-rgb), 0.6); color: var(--coe-accent); font-size: 12px; font-weight: 600; content: counter(cjg-step); }
.cjg-list { display: grid; gap: 6px; margin: 0; padding-left: 18px; color: var(--coe-text); line-height: 1.45; }
.cjg-list--muted { color: var(--coe-muted); }
.cjg-rows { display: grid; gap: 6px; }
.cjg-row { display: flex; justify-content: space-between; gap: 12px; padding-bottom: 6px; border-bottom: 1px solid var(--coe-line); }
.cjg-row:last-child { padding-bottom: 0; border-bottom: 0; }
.cjg-row span { color: var(--coe-muted); }
.cjg-row strong { font-weight: 600; text-align: right; }
.cjg-meter { height: 6px; background: rgba(var(--coe-ink-rgb), 0.08); }
.cjg-meter i { display: block; height: 100%; background: var(--coe-accent); }
.cjg-skills { display: grid; gap: 8px; }
.cjg-skill { display: grid; gap: 2px; }
.cjg-skill strong { color: var(--coe-accent); }
.cjg-skill span { color: var(--coe-muted); font-size: var(--coe-text-sm, 12px); }
.cjg-alert { padding: 10px 12px; border: 1px solid rgba(var(--coe-danger-rgb), 0.45); background: var(--coe-danger-soft); color: var(--coe-danger); line-height: 1.4; }
.cjg-history { display: grid; gap: 6px; }
.cjg-entry { display: grid; grid-template-columns: auto minmax(0, 1fr) auto; gap: 4px 12px; padding: 8px 0; border-bottom: 1px solid var(--coe-line); }
.cjg-entry:last-child { border-bottom: 0; }
.cjg-entry time { color: var(--coe-muted); font-size: var(--coe-text-sm, 12px); white-space: nowrap; }
.cjg-entry b { font-weight: 600; }
.cjg-entry em { color: var(--coe-muted); font-size: var(--coe-text-sm, 12px); font-style: normal; grid-column: 2 / 4; }
.cjg-empty { margin: 0; color: var(--coe-muted); }
`;

	function injectStyle() {
		if (document.getElementById('cjg-style')) { return; }
		const style = document.createElement('style');
		style.id = 'cjg-style';
		style.textContent = STYLE;
		document.head.appendChild(style);
	}

	function el(tag, className, text) {
		const node = document.createElement(tag);
		if (className) { node.className = className; }
		if (text !== undefined && text !== null) { node.textContent = text; }
		return node;
	}
	function pct(value) { return Math.round((value || 0) * 100) + '%'; }
	function money(value) { return '$ ' + Math.floor(value || 0).toLocaleString('pt-BR'); }
	function row(label, value) {
		const node = el('div', 'cjg-row');
		node.append(el('span', null, label), el('strong', null, value));
		return node;
	}
	function block(title) {
		const node = el('section', 'cjg-block');
		node.appendChild(el('h3', null, title));
		return node;
	}
	function list(items, muted) {
		const node = el('ul', 'cjg-list' + (muted ? ' cjg-list--muted' : ''));
		items.forEach(function (item) { node.appendChild(el('li', null, item)); });
		return node;
	}
	function when(seconds) {
		if (!seconds) { return '—'; }
		return new Date(seconds * 1000).toLocaleString('pt-BR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' });
	}
	function minutes(entry) {
		const total = Math.max(0, Math.round(((entry.endedAt || 0) - (entry.startedAt || 0)) / 60));
		return total < 1 ? 'menos de 1 min' : total + ' min';
	}

	// Lista de últimos trabalhos (também usada no app Carreira, com o nome do emprego).
	function history(entries, withLabel) {
		const box = el('div', 'cjg-history');
		if (!entries || entries.length === 0) {
			box.appendChild(el('p', 'cjg-empty', 'Nenhum trabalho registrado ainda.'));
			return box;
		}
		entries.forEach(function (entry) {
			const item = el('div', 'cjg-entry');
			const what = (withLabel ? entry.label + ' · ' : '') + entry.tasks + (entry.tasks === 1 ? ' tarefa' : ' tarefas') + ' · +' + entry.xp + ' XP';
			item.append(el('time', null, when(entry.endedAt)), el('b', null, what), el('strong', null, money(entry.earned)));
			const notes = [minutes(entry), REASONS[entry.reason] || entry.reason];
			if (entry.discarded > 0) {
				notes.push(entry.discarded + ' ' + (entry.unit || 'unidades') + ' descartados sem vender');
			}
			item.appendChild(el('em', null, notes.join(' · ')));
			box.appendChild(item);
		});
		return box;
	}

	function render(container, guide) {
		injectStyle();
		const player = guide.player || {};
		const root = el('div', 'cjg');

		const head = el('header', 'cjg-head');
		head.append(el('p', 'cjg-eyebrow', 'Como funciona · ' + guide.kind), el('h2', 'cjg-title', guide.label));
		if (guide.description) { head.appendChild(el('p', 'cjg-desc', guide.description)); }
		const badges = el('div', 'cjg-badges');
		if (player.working) { badges.appendChild(el('span', 'cjg-badge cjg-badge--accent', 'Trabalhando agora')); }
		if (player.allowed === false) {
			badges.appendChild(el('span', 'cjg-badge cjg-badge--lock', 'Bloqueado'));
		} else {
			badges.appendChild(el('span', 'cjg-badge cjg-badge--ok', 'Liberado'));
		}
		if (guide.requires) { badges.appendChild(el('span', 'cjg-badge', 'Requisito: ' + guide.requires)); }
		head.appendChild(badges);
		root.appendChild(head);

		if (player.allowed === false) {
			root.appendChild(el('div', 'cjg-alert', 'Você ainda não pode começar: precisa de ' + player.lockedReason
				+ '. Ganhe experiência nos empregos que treinam isso (veja no app Carreira).'));
		}

		const cols = el('div', 'cjg-cols');
		const left = el('div', 'cjg');
		const steps = block('Passo a passo');
		const ol = el('ol', 'cjg-steps');
		guide.steps.forEach(function (step) { ol.appendChild(el('li', null, step)); });
		steps.appendChild(ol);
		left.appendChild(steps);
		if (guide.tips && guide.tips.length) {
			const tips = block('Dicas');
			tips.appendChild(list(guide.tips));
			left.appendChild(tips);
		}
		const rules = block('Bom saber');
		rules.appendChild(list(guide.rules, true));
		left.appendChild(rules);

		const right = el('div', 'cjg');
		const pay = block('Pagamento');
		const payRows = el('div', 'cjg-rows');
		guide.pay.forEach(function (line) { payRows.appendChild(row(line.label, line.value)); });
		pay.appendChild(payRows);
		right.appendChild(pay);

		const mine = block('Seu histórico aqui');
		const meter = el('div', 'cjg-meter');
		const fill = el('i');
		const ratio = player.nextXp ? Math.max(0, Math.min(1, (player.xp || 0) / player.nextXp)) : 1;
		fill.style.width = Math.round(ratio * 100) + '%';
		meter.appendChild(fill);
		const mineRows = el('div', 'cjg-rows');
		mineRows.append(
			row('Nível no emprego', (player.level || 1) + '/' + (player.maxLevel || 1)),
			row('Experiência', (player.xp || 0) + ' XP' + (player.nextXp ? ' de ' + player.nextXp : ' · máximo')),
			row('Tarefas feitas', String(player.tasks || 0)),
			row('Ganhos aqui', money(player.earned)),
			row('Seu bônus aqui', '+' + pct(player.payBonus) + ' pagamento · ×' + (player.xpMultiplier || 1).toFixed(2) + ' XP')
		);
		if (player.capacity) { mineRows.appendChild(row('Sua carga / tempo da ação', player.capacity + ' · ' + (player.seconds || 0).toFixed(1) + ' s')); }
		if (player.deposit !== undefined && player.deposit !== null) { mineRows.appendChild(row('Seu depósito', player.deposit > 0 ? money(player.deposit) : 'Dispensado')); }
		mine.append(meter, mineRows);
		right.appendChild(mine);

		if (guide.skills && guide.skills.length) {
			const skills = block('Treina — vale em outros empregos');
			const box = el('div', 'cjg-skills');
			guide.skills.forEach(function (skill) {
				const item = el('div', 'cjg-skill');
				item.append(el('strong', null, skill.label), el('span', null, skill.perks.join(' · ')));
				box.appendChild(item);
			});
			skills.appendChild(box);
			right.appendChild(skills);
		}
		cols.append(left, right);
		root.appendChild(cols);

		const recent = block('Suas últimas vezes aqui');
		recent.appendChild(history(player.sessions, false));
		root.appendChild(recent);

		container.replaceChildren(root);
	}

	window.CoeJobGuide = { render: render, history: history, injectStyle: injectStyle };
})();
