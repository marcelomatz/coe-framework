(() => {
	const $ = (id) => document.getElementById(id);
	const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'coe_housing';

	const post = (name, body) => fetch(`https://${resource}/${name}`, {
		method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body || {})
	}).catch(() => {});

	const el = (tag, props = {}, children = []) => {
		const node = document.createElement(tag);
		Object.assign(node, props);
		for (const child of [].concat(children)) node.append(child);
		return node;
	};

	const money = (value) => `$ ${Math.floor(value || 0).toLocaleString('pt-BR')}`;
	const date = (seconds) => new Date(seconds * 1000).toLocaleDateString('pt-BR');
	const cycleName = { 7: 'Semanal', 15: 'Quinzenal', 30: 'Mensal' };

	function render(menu) {
		$('title').textContent = menu.title || 'Moradia';
		$('subtitle').textContent = menu.subtitle || '';
		const balance = menu.balance != null ? money(menu.balance) : null;
		$('info').textContent = menu.payer
			? (balance ? `Caixa de ${menu.payer}: ${balance}` : `Negócio: ${menu.payer}`)
			: (balance ? `Saldo: ${balance}` : '');
		const list = $('list');
		list.replaceChildren();

		if (menu.tenancy) {
			const tenancy = menu.tenancy;
			const enter = el('button', { type: 'button', className: 'primary', textContent: 'Entrar', disabled: tenancy.overdue });
			enter.onclick = () => post('enter');
			const detail = tenancy.starter
				? `Unidade ${tenancy.unit} · ${menu.commercial ? 'Cedido ao negócio' : 'Apartamento inicial'}`
				: `Unidade ${tenancy.unit} · ${cycleName[tenancy.cycleDays] || tenancy.cycleDays + ' dias'} · ${money(tenancy.dailyRate)}/dia · pago até ${date(tenancy.paidUntil)}`;
			const buttons = [enter];
			if (!tenancy.starter && menu.canCancel !== false) {
				const cancel = el('button', { type: 'button', textContent: 'Cancelar contrato' });
				cancel.onclick = () => post('cancel');
				buttons.push(cancel);
			}
			list.append(el('li', {}, [
				el('div', { className: 'row' }, [
					el('div', {}, [
						el('div', { textContent: menu.commercial ? 'Imóvel do negócio' : 'Seu imóvel' }),
						el('div', { className: 'meta', textContent: tenancy.overdue ? `${detail} · VENCIDO` : detail })
					]),
					el('div', { className: 'add' }, buttons)
				])
			]));
			return;
		}

		if (menu.rent) {
			if (menu.rent.vacancies <= 0) {
				list.append(el('li', { className: 'empty', textContent: 'Sem vagas no momento.' }));
				return;
			}
			for (const cycle of menu.rent.cycles) {
				const rent = el('button', { type: 'button', className: 'primary', textContent: 'Alugar' });
				rent.onclick = () => post('rent', { days: cycle.days });
				list.append(el('li', {}, [el('div', { className: 'row' }, [
					el('div', {}, [
						el('div', { textContent: cycleName[cycle.days] || `${cycle.days} dias` }),
						el('div', { className: 'meta', textContent: `${money(menu.rent.daily)}/dia · cobrança de ${money(cycle.total)}` })
					]),
					rent
				])]));
			}
			return;
		}
		list.append(el('li', { className: 'empty', textContent: menu.hint || 'Este imóvel não está disponível.' }));
	}

	window.addEventListener('message', ({ data }) => {
		if (data.type === 'open') {
			render(data.menu);
			$('menu').hidden = false;
		} else if (data.type === 'close') {
			$('menu').hidden = true;
		}
	});

	$('close').onclick = () => post('close');
	document.addEventListener('keydown', (event) => {
		if (event.key === 'Escape') post('close');
	});
})();
