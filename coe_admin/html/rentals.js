// Aba "Aluguel": estações do coe_rentals (atendente, pontos de retirada, devolução, modelos e blip). Usa os helpers de app.js.
const RENT_SECTIONS = [['general', 'Geral'], ['points', 'Atendente e retirada'], ['return', 'Devolução'], ['vehicles', 'Veículos']];
state.rent = { section: 'general', draft: null, isNew: false };

function rentNewDraft() {
	return {
		id: '', label: '', enabled: true,
		ped: { model: '' }, spawns: [], returnZone: { radius: 5 }, vehicles: [],
		blip: { enabled: true, sprite: 226, color: 3, scale: 0.7 }
	};
}

function rentFromEntry(entry) {
	const draft = JSON.parse(JSON.stringify(entry));
	draft.ped = draft.ped || { model: '' };
	draft.ped.model = draft.ped.model || '';
	draft.spawns = draft.spawns || [];
	draft.returnZone = draft.returnZone || { radius: 5 };
	draft.vehicles = draft.vehicles || [];
	draft.blip = draft.blip || { enabled: true, sprite: 226, color: 3, scale: 0.7 };
	return draft;
}

function rentPayload(draft) {
	const payload = JSON.parse(JSON.stringify(draft));
	if (!payload.ped.model) delete payload.ped.model;
	return payload;
}

function rentPoint(point) {
	return { x: point.x, y: point.y, z: point.z, h: Number(point.heading ?? point.h ?? 0) };
}

function rentPreview(draft) {
	const list = [];
	if (Number.isFinite(draft.ped?.x)) list.push(draft.ped);
	for (const spawn of draft.spawns) list.push(spawn);
	if (Number.isFinite(draft.returnZone?.x)) list.push(draft.returnZone);
	return list;
}

function rentCheck(text, checked, onChange) {
	const input = bizEl('input');
	input.type = 'checkbox';
	input.checked = checked;
	input.addEventListener('change', () => onChange(input.checked));
	const label = bizEl('label', 'biz-check');
	label.append(input, bizEl('span', '', text));
	return label;
}

function renderRentalGeneral(draft) {
	const box = bizEl('div', 'biz-block');
	const idInput = bizInput('text', draft.id, (value) => { draft.id = value.toLowerCase(); }, { maxlength: 32 });
	idInput.disabled = !state.rent.isNew;
	box.append(
		bizEl('h3', '', 'Identificação'),
		bizField('ID (letras minúsculas, números e _)', idInput),
		bizField('Nome', bizInput('text', draft.label, (value) => { draft.label = value; }, { maxlength: 48 })),
		rentCheck('Ativa', draft.enabled !== false, (checked) => { draft.enabled = checked; })
	);
	const blip = bizEl('div', 'biz-block');
	blip.append(bizEl('h3', '', 'Blip no mapa (no atendente)'), rentCheck('Mostrar no mapa', draft.blip.enabled !== false, (checked) => { draft.blip.enabled = checked; }));
	const fields = bizEl('div', 'biz-station-fields');
	fields.append(
		bizField('Ícone (1 a 900)', bizInput('number', draft.blip.sprite, (value) => { draft.blip.sprite = bizNumber(value, 226); }, { min: 1, max: 900 })),
		bizField('Cor (0 a 85)', bizInput('number', draft.blip.color, (value) => { draft.blip.color = bizNumber(value, 3); }, { min: 0, max: 85 })),
		bizField('Tamanho', bizInput('number', draft.blip.scale, (value) => { draft.blip.scale = bizNumber(value, 0.7); }, { min: 0.3, max: 2, step: '0.1' }))
	);
	blip.append(fields);
	const wrapper = bizEl('div');
	wrapper.append(box, blip);
	return wrapper;
}

function renderRentalPoints(draft) {
	const wrapper = bizEl('div');

	const ped = bizEl('div', 'biz-block');
	const pedHead = bizEl('div', 'biz-block-head');
	pedHead.append(bizEl('h3', '', 'Atendente (NPC) e balcão'));
	const markPed = bizEl('button', 'coe-button biz-small-button', Number.isFinite(draft.ped.x) ? 'Remarcar' : 'Marcar');
	markPed.type = 'button';
	markPed.addEventListener('click', () => bizCapture({ label: 'atendente (fique onde o NPC fica, de frente para o cliente)', preview: rentPreview(draft) }, (data) => {
		if (data.point) Object.assign(draft.ped, rentPoint(data.point));
	}));
	pedHead.append(markPed);
	ped.append(
		pedHead,
		bizEl('p', 'biz-hint', `${bizPointText(draft.ped)} · direção ${Number(draft.ped.h || 0).toFixed(0)}°. O jogador fala com o atendente para alugar, devolver ou encerrar.`),
		bizField('Modelo do NPC (vazio = padrão)', bizInput('text', draft.ped.model, (value) => { draft.ped.model = value.trim().toLowerCase(); }, { maxlength: 48 }))
	);
	wrapper.append(ped);

	const spawns = bizEl('div', 'biz-block');
	const head = bizEl('div', 'biz-block-head');
	head.append(bizEl('h3', '', `Pontos de retirada (${draft.spawns.length}/8)`));
	const add = bizEl('button', 'coe-button biz-small-button', '+ Marcar novo');
	add.type = 'button';
	add.disabled = draft.spawns.length >= 8;
	add.addEventListener('click', () => bizCapture({ label: 'ponto de retirada (de frente para onde o veículo sai)', preview: rentPreview(draft) }, (data) => {
		if (data.point) draft.spawns.push(rentPoint(data.point));
	}));
	head.append(add);
	spawns.append(head, bizEl('p', 'biz-hint', 'O veículo sai no primeiro ponto livre, na ordem da lista.'));
	draft.spawns.forEach((spawn, index) => {
		const row = bizEl('div', 'biz-station');
		const foot = bizEl('div', 'biz-station-foot');
		foot.append(bizEl('p', 'biz-hint', `#${index + 1} · ${bizPointText(spawn)} · direção ${Number(spawn.h || 0).toFixed(0)}°`));
		const actions = bizEl('div', 'biz-station-actions');
		const remark = bizEl('button', 'coe-button biz-small-button', 'Remarcar');
		remark.type = 'button';
		remark.addEventListener('click', () => bizCapture({ label: `ponto de retirada #${index + 1}`, preview: rentPreview(draft) }, (data) => {
			if (data.point) Object.assign(spawn, rentPoint(data.point));
		}));
		const remove = bizEl('button', 'coe-button biz-small-button biz-danger', 'Remover');
		remove.type = 'button';
		remove.addEventListener('click', () => {
			draft.spawns.splice(index, 1);
			renderRentalEditor();
		});
		actions.append(remark, remove);
		foot.append(actions);
		row.append(foot);
		spawns.append(row);
	});
	wrapper.append(spawns);
	return wrapper;
}

function renderRentalReturn(draft) {
	const box = bizEl('div', 'biz-block');
	const head = bizEl('div', 'biz-block-head');
	head.append(bizEl('h3', '', 'Zona de devolução'));
	const mark = bizEl('button', 'coe-button biz-small-button', Number.isFinite(draft.returnZone.x) ? 'Remarcar' : 'Marcar');
	mark.type = 'button';
	mark.addEventListener('click', () => bizCapture({ label: 'centro da zona de devolução', preview: rentPreview(draft) }, (data) => {
		if (data.point) Object.assign(draft.returnZone, { x: data.point.x, y: data.point.y, z: data.point.z });
	}));
	head.append(mark);
	box.append(
		head,
		bizEl('p', 'biz-hint', `${bizPointText(draft.returnZone)}. Dentro do carro alugado, E devolve. No balcão também dá para devolver com o carro estacionado perto.`),
		bizField('Raio (m)', bizInput('number', draft.returnZone.radius, (value) => { draft.returnZone.radius = bizNumber(value, 5); }, { min: 1, max: 30, step: '0.5' }))
	);
	return box;
}

function renderRentalVehicles(draft) {
	const box = bizEl('div', 'biz-block');
	const catalog = state.data?.rentals?.catalog || [];
	box.append(bizEl('h3', '', 'Veículos oferecidos'), bizEl('p', 'biz-hint', 'Nenhum marcado: a estação oferece todo o catálogo do aluguel (config.lua do coe_rentals).'));
	for (const vehicle of catalog) {
		const checked = draft.vehicles.includes(vehicle.model);
		box.append(rentCheck(`${vehicle.label || vehicle.model} (${vehicle.model}) · aluguel ${vehicle.price} · caução ${vehicle.deposit}`, checked, (on) => {
			draft.vehicles = draft.vehicles.filter((model) => model !== vehicle.model);
			if (on) draft.vehicles.push(vehicle.model);
		}));
	}
	if (!catalog.length) box.append(bizEl('p', 'biz-hint', 'Catálogo vazio.'));
	return box;
}

function renderRentalEditor() {
	const host = document.getElementById('rent-editor');
	if (!host) return;
	const draft = state.rent.draft;
	host.replaceChildren();
	if (!draft) {
		host.append(bizEl('div', 'empty-state', 'Selecione uma estação ou crie uma nova.'));
		return;
	}
	const heading = bizEl('div', 'panel-heading');
	heading.append(bizEl('h2', '', state.rent.isNew ? 'Nova estação' : `Editar: ${draft.label || draft.id}`));
	host.append(heading);

	const tabs = bizEl('div', 'biz-sections');
	tabs.setAttribute('role', 'tablist');
	for (const [key, text] of RENT_SECTIONS) {
		const tab = bizEl('button', `biz-tab${key === state.rent.section ? ' is-active' : ''}`, text);
		tab.type = 'button';
		tab.addEventListener('click', () => {
			state.rent.section = key;
			renderRentalEditor();
		});
		tabs.append(tab);
	}
	host.append(tabs);

	const body = bizEl('div', 'biz-section-body');
	if (state.rent.section === 'general') body.append(renderRentalGeneral(draft));
	else if (state.rent.section === 'points') body.append(renderRentalPoints(draft));
	else if (state.rent.section === 'return') body.append(renderRentalReturn(draft));
	else body.append(renderRentalVehicles(draft));
	host.append(body);

	const actions = bizEl('div', 'biz-actions');
	const save = bizEl('button', 'coe-button coe-button--primary primary-button', 'Salvar estação');
	save.type = 'button';
	save.addEventListener('click', () => {
		postNui('saveRental', { station: rentPayload(draft) }).then((result) => {
			if (!result.ok) showToast('Não foi possível enviar a estação.', false);
		});
	});
	actions.append(save);
	if (!state.rent.isNew) {
		const remove = bizEl('button', 'coe-button biz-danger', 'Remover');
		remove.type = 'button';
		remove.addEventListener('click', () => {
			if (remove.dataset.confirm !== '1') {
				remove.dataset.confirm = '1';
				remove.textContent = 'Confirmar remoção';
				return;
			}
			postNui('deleteRental', { id: draft.id });
		});
		actions.append(remove);
	}
	host.append(actions);
}

function renderRentals() {
	const data = state.data?.rentals;
	const list = document.getElementById('rent-list');
	if (!list) return;
	list.replaceChildren();
	if (!data?.available) {
		appendEmpty(list, 'O resource coe_rentals não está iniciado.');
		return;
	}
	if (!(data.list || []).length) appendEmpty(list, 'Nenhuma estação cadastrada.');
	for (const entry of data.list || []) {
		const row = bizEl('button', `biz-item${state.rent.draft?.id === entry.id ? ' is-active' : ''}`);
		row.type = 'button';
		row.append(bizEl('strong', '', entry.label), bizEl('small', '', `${entry.id} · ${entry.spawns?.length || 0} ponto(s) de retirada${entry.enabled === false ? ' · inativa' : ''}`));
		row.addEventListener('click', () => {
			state.rent.draft = rentFromEntry(entry);
			state.rent.isNew = false;
			renderRentals();
			renderRentalEditor();
		});
		list.append(row);
	}
	if (!state.rent.draft) renderRentalEditor();
}

function onRentalResult(data) {
	const message = document.getElementById('rent-message');
	message.textContent = data.message || '';
	message.classList.toggle('is-success', data.success === true);
	if (data.success !== true) return;
	if (data.operation === 'rentalDelete') state.rent.draft = null;
	else state.rent.isNew = false;
	renderRentals();
	renderRentalEditor();
}

document.getElementById('rent-new').addEventListener('click', () => {
	state.rent.draft = rentNewDraft();
	state.rent.isNew = true;
	state.rent.section = 'general';
	renderRentals();
	renderRentalEditor();
});
