(() => {
	const $ = (id) => document.getElementById(id);
	const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'coe_garages';
	let menu = null;

	const post = (name, body) => fetch(`https://${resource}/${name}`, {
		method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body || {})
	}).catch(() => {});

	const el = (tag, props = {}, children = []) => {
		const node = document.createElement(tag);
		Object.assign(node, props);
		for (const child of [].concat(children)) node.append(child);
		return node;
	};

	function accessPanel(vehicle) {
		const staff = el('input', { type: 'checkbox', checked: vehicle.staff === true });
		staff.onchange = () => post('access', { vehicleId: vehicle.id, action: 'staff', value: staff.checked });
		const people = (vehicle.access || []).map((person) => {
			const remove = el('button', { type: 'button', textContent: 'Remover' });
			remove.onclick = () => post('access', { vehicleId: vehicle.id, action: 'remove', value: person.characterId });
			return el('div', { className: 'person' }, [el('span', { textContent: person.name || `#${person.characterId}` }), remove]);
		});
		const input = el('input', { type: 'text', placeholder: 'stateId', maxLength: 16 });
		const add = el('button', { type: 'button', textContent: 'Liberar' });
		add.onclick = () => {
			if (input.value.trim()) post('access', { vehicleId: vehicle.id, action: 'add', value: input.value.trim() });
		};
		return el('div', { className: 'access' }, [
			el('label', {}, [staff, 'Toda a equipe de ponto batido']),
			...people,
			el('div', { className: 'add' }, [input, add])
		]);
	}

	function render() {
		$('title').textContent = menu.title || 'Garagem';
		$('subtitle').textContent = menu.subtitle || '';
		const capacity = menu.capacity;
		$('capacity').textContent = capacity
			? `Carros ${capacity.car.used}/${capacity.car.max} · Motos ${capacity.bike.used}/${capacity.bike.max}`
			: (menu.kind === 'public' ? 'Veículos' : 'Frota');
		const list = $('list');
		list.replaceChildren();
		if (!menu.vehicles.length) {
			list.append(el('li', { className: 'empty', textContent: 'Nenhum veículo disponível.' }));
			return;
		}
		for (const vehicle of menu.vehicles) {
			const stored = vehicle.state === 'stored';
			const take = el('button', { type: 'button', className: 'primary', textContent: 'Retirar', disabled: !stored });
			take.onclick = () => post('take', { vehicleId: vehicle.id });
			const row = el('div', { className: 'row' }, [
				el('div', {}, [
					el('div', { textContent: vehicle.name }),
					el('div', { className: 'meta', textContent: `${vehicle.plate} · ${stored ? 'Guardado' : 'Na rua'}` })
				]),
				take
			]);
			const item = el('li', { className: stored ? '' : 'out' }, [row]);
			if (menu.canManage) item.append(accessPanel(vehicle));
			list.append(item);
		}
	}

	function notice(text) {
		const node = $('notice');
		node.textContent = text || '';
		node.hidden = !text;
	}

	window.addEventListener('message', ({ data }) => {
		if (data.type === 'open') {
			menu = data.menu;
			notice('');
			render();
			$('menu').hidden = false;
		} else if (data.type === 'close') {
			$('menu').hidden = true;
		} else if (data.type === 'notice') {
			notice(data.text);
		}
	});

	$('close').onclick = () => post('close');
	document.addEventListener('keydown', (event) => {
		if (event.key === 'Escape') post('close');
	});
})();
