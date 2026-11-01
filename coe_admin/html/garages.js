// Aba "Garagens": cadastro de garagens públicas, de negócios e de corporações. Usa os helpers de app.js.
const GAR_SECTIONS = [['general', 'Geral'], ['spots', 'Vagas'], ['access', 'Acesso'], ['fleet', 'Frota']];
const GAR_KINDS = { public: 'Públicas', business: 'Negócios', job: 'Corporações' };
const GAR_KIND_HINT = {
	public: 'Garagem pública: cada jogador guarda os próprios veículos, conforme a capacidade da garagem dele.',
	business: 'Frota de um negócio: o dono do negócio escolhe quem usa cada veículo.',
	job: 'Frota de corporação (polícia, hospital, bombeiros...): todos com o emprego informado usam.'
};

function garNewDraft(kind) {
	return {
		id: '', kind, label: '', enabled: true, spots: [], businessId: '', jobsText: '',
		blip: { enabled: kind === 'public', sprite: 357, color: 3, scale: 0.8 }
	};
}

function garFromEntry(entry) {
	const draft = JSON.parse(JSON.stringify(entry));
	draft.spots = draft.spots || [];
	draft.blip = draft.blip || { enabled: false, sprite: 357, color: 3, scale: 0.8 };
	draft.businessId = draft.businessId || '';
	draft.jobsText = (draft.jobs || []).join(', ');
	delete draft.jobs;
	return draft;
}

function garPayload(draft) {
	const payload = JSON.parse(JSON.stringify(draft));
	delete payload.jobsText;
	if (draft.kind === 'job') {
		payload.jobs = draft.jobsText.split(',').map((job) => job.trim().toLowerCase()).filter(Boolean);
	}
	if (draft.kind !== 'business') delete payload.businessId;
	return payload;
}

function garPreview(draft) {
	return draft.spots.filter((spot) => Number.isFinite(spot.x) && Number.isFinite(spot.y) && Number.isFinite(spot.z));
}

function garCheck(text, checked, onChange) {
	const input = bizEl('input');
	input.type = 'checkbox';
	input.checked = checked;
	input.addEventListener('change', () => onChange(input.checked));
	const label = bizEl('label', 'biz-check');
	label.append(input, bizEl('span', '', text));
	return label;
}

function renderGarageGeneral(draft) {
	const box = bizEl('div', 'biz-block');
	const idInput = bizInput('text', draft.id, (value) => { draft.id = value.toLowerCase(); }, { maxlength: 32 });
	idInput.disabled = !state.gar.isNew;
	box.append(
		bizEl('h3', '', 'Identificação'),
		bizEl('p', 'biz-hint', GAR_KIND_HINT[draft.kind]),
		bizField('ID (letras minúsculas, números e _)', idInput),
		bizField('Nome', bizInput('text', draft.label, (value) => { draft.label = value; }, { maxlength: 48 })),
		garCheck('Ativa', draft.enabled !== false, (checked) => { draft.enabled = checked; })
	);

	const blip = bizEl('div', 'biz-block');
	blip.append(
		bizEl('h3', '', 'Blip no mapa'),
		garCheck('Mostrar no mapa', draft.blip.enabled === true, (checked) => { draft.blip.enabled = checked; })
	);
	const fields = bizEl('div', 'biz-station-fields');
	fields.append(
		bizField('Ícone (1 a 900)', bizInput('number', draft.blip.sprite, (value) => { draft.blip.sprite = bizNumber(value, 357); }, { min: 1, max: 900 })),
		bizField('Cor (0 a 85)', bizInput('number', draft.blip.color, (value) => { draft.blip.color = bizNumber(value, 3); }, { min: 0, max: 85 })),
		bizField('Tamanho (0.5 a 1.5)', bizInput('number', draft.blip.scale, (value) => { draft.blip.scale = bizNumber(value, 0.8); }, { min: 0.5, max: 1.5, step: '0.1' }))
	);
	blip.append(fields);
	const wrapper = bizEl('div');
	wrapper.append(box, blip);
	return wrapper;
}

function renderGarageSpots(draft) {
	const box = bizEl('div', 'biz-block');
	const head = bizEl('div', 'biz-block-head');
	head.append(bizEl('h3', '', `Vagas (${draft.spots.length}/8)`));
	const add = bizEl('button', 'coe-button biz-small-button', '+ Marcar nova');
	add.type = 'button';
	add.disabled = draft.spots.length >= 8;
	add.addEventListener('click', () => bizCapture({ label: 'vaga (de frente para onde o veículo sai)', preview: garPreview(draft) }, (data) => {
		if (!data.point) return;
		let index = draft.spots.length + 1;
		while (draft.spots.some((spot) => spot.id === `vaga${index}`)) index += 1;
		draft.spots.push({ id: `vaga${index}`, label: `Vaga ${index}`, ...data.point, radius: 3 });
	}));
	head.append(add);
	box.append(head);
	if (!draft.spots.length) box.append(bizEl('p', 'biz-hint', 'Marque ao menos uma vaga: é onde o jogador abre a garagem e onde o veículo sai e é guardado.'));

	draft.spots.forEach((spot, index) => {
		const row = bizEl('div', 'biz-station');
		const fields = bizEl('div', 'biz-station-fields');
		fields.append(
			bizField('ID', bizInput('text', spot.id, (value) => { spot.id = value.toLowerCase(); }, { maxlength: 24 })),
			bizField('Nome', bizInput('text', spot.label, (value) => { spot.label = value; }, { maxlength: 32 })),
			bizField('Raio', bizInput('number', spot.radius, (value) => { spot.radius = bizNumber(value, 3); }, { min: 1, max: 8, step: '0.5' }))
		);
		row.append(fields);
		const foot = bizEl('div', 'biz-station-foot');
		foot.append(bizEl('p', 'biz-hint', `${bizPointText(spot)} · direção ${Number(spot.heading || 0).toFixed(0)}°`));
		const actions = bizEl('div', 'biz-station-actions');
		const remark = bizEl('button', 'coe-button biz-small-button', 'Remarcar');
		remark.type = 'button';
		remark.addEventListener('click', () => bizCapture({ label: spot.label, preview: garPreview(draft) }, (data) => {
			if (data.point) Object.assign(spot, data.point);
		}));
		const remove = bizEl('button', 'coe-button biz-small-button biz-danger', 'Remover');
		remove.type = 'button';
		remove.addEventListener('click', () => {
			draft.spots.splice(index, 1);
			renderGarageEditor();
		});
		actions.append(remark, remove);
		foot.append(actions);
		row.append(foot);
		box.append(row);
	});
	return box;
}

function renderGarageAccess(draft) {
	const box = bizEl('div', 'biz-block');
	box.append(bizEl('h3', '', 'Acesso'));
	if (draft.kind === 'business') {
		const select = bizEl('select', 'coe-field field-control');
		select.append(new Option('Selecione o negócio', ''));
		for (const business of state.data?.businesses?.list || []) {
			select.append(new Option(`${business.label} (${business.id})`, business.id));
		}
		select.value = draft.businessId;
		select.addEventListener('change', () => { draft.businessId = select.value; });
		box.append(
			bizField('Negócio dono da frota', select),
			bizEl('p', 'biz-hint', 'O dono definido no negócio escolhe quem usa cada veículo. A equipe segue o emprego e o ponto do negócio.')
		);
	} else {
		box.append(
			bizField('Empregos (IDs separados por vírgula, até 5)', bizInput('text', draft.jobsText, (value) => { draft.jobsText = value; }, { maxlength: 200 })),
			bizEl('p', 'biz-hint', 'Quem tem um desses empregos usa todos os veículos da frota.')
		);
	}
	return box;
}

function renderGarageEditor() {
	const host = document.getElementById('gar-editor');
	if (!host) return;
	const draft = state.gar.draft;
	host.replaceChildren();
	if (!draft) {
		host.append(bizEl('div', 'empty-state', 'Selecione uma garagem ou crie uma nova.'));
		return;
	}
	const heading = bizEl('div', 'panel-heading');
	heading.append(bizEl('h2', '', state.gar.isNew ? 'Nova garagem' : `Editar: ${draft.label || draft.id}`));
	host.append(heading);

	const sections = GAR_SECTIONS.filter(([key]) => (key !== 'access' || draft.kind !== 'public') && (key !== 'fleet' || (draft.kind !== 'public' && !state.gar.isNew)));
	if (!sections.some(([key]) => key === state.gar.section)) state.gar.section = 'general';
	const tabs = bizEl('div', 'biz-sections');
	tabs.setAttribute('role', 'tablist');
	for (const [key, text] of sections) {
		const tab = bizEl('button', `biz-tab${key === state.gar.section ? ' is-active' : ''}`, text);
		tab.type = 'button';
		tab.addEventListener('click', () => {
			state.gar.section = key;
			renderGarageEditor();
		});
		tabs.append(tab);
	}
	host.append(tabs);

	const body = bizEl('div', 'biz-section-body');
	if (state.gar.section === 'general') body.append(renderGarageGeneral(draft));
	else if (state.gar.section === 'spots') body.append(renderGarageSpots(draft));
	else if (state.gar.section === 'access') body.append(renderGarageAccess(draft));
	else if (state.gar.section === 'fleet') body.append(renderGarageFleet(draft));
	host.append(body);

	const actions = bizEl('div', 'biz-actions');
	const save = bizEl('button', 'coe-button coe-button--primary primary-button', 'Salvar garagem');
	save.type = 'button';
	save.addEventListener('click', () => {
		postNui('saveGarage', { garage: garPayload(draft) }).then((result) => {
			if (!result.ok) showToast('Não foi possível enviar a garagem.', false);
		});
	});
	actions.append(save);
	if (!state.gar.isNew) {
		const remove = bizEl('button', 'coe-button biz-danger', 'Remover');
		remove.type = 'button';
		remove.addEventListener('click', () => {
			if (remove.dataset.confirm !== '1') {
				remove.dataset.confirm = '1';
				remove.textContent = 'Confirmar remoção';
				return;
			}
			postNui('deleteGarage', { id: draft.id });
		});
		actions.append(remove);
	}
	host.append(actions);
}

function renderGarages() {
	const data = state.data?.garages;
	const tabs = document.getElementById('gar-kinds');
	const list = document.getElementById('gar-list');
	if (!tabs || !list) return;
	tabs.replaceChildren();
	list.replaceChildren();
	if (!data?.available) {
		appendEmpty(list, 'Nenhum resource de garagens (coe_garages ou coe_garage) está iniciado.');
		return;
	}
	// Tipos que o resource de garagens ativo aceita (o básico coe_garage só tem garagens públicas).
	const kinds = Object.keys(GAR_KINDS).filter((key) => !data.kinds || data.kinds[key] !== undefined);
	if (!kinds.includes(state.gar.kind)) state.gar.kind = kinds[0] || 'public';
	for (const key of kinds) {
		const button = bizEl('button', `biz-tab${key === state.gar.kind ? ' is-active' : ''}`, GAR_KINDS[key]);
		button.type = 'button';
		button.addEventListener('click', () => {
			state.gar.kind = key;
			state.gar.draft = null;
			renderGarages();
			renderGarageEditor();
		});
		tabs.append(button);
	}
	document.getElementById('gar-list-title').textContent = GAR_KINDS[state.gar.kind];
	const items = (data.list || []).filter((entry) => entry.kind === state.gar.kind);
	if (!items.length) appendEmpty(list, 'Nenhuma garagem neste tipo.');
	for (const entry of items) {
		const row = bizEl('button', `biz-item${state.gar.draft?.id === entry.id ? ' is-active' : ''}`);
		row.type = 'button';
		row.append(bizEl('strong', '', entry.label), bizEl('small', '', `${entry.id} · ${entry.spots?.length || 0} vaga(s)${entry.enabled === false ? ' · inativa' : ''}`));
		row.addEventListener('click', () => {
			state.gar.draft = garFromEntry(entry);
			state.gar.isNew = false;
			renderGarages();
			renderGarageEditor();
		});
		list.append(row);
	}
	const fleetBox = document.getElementById('gar-fleet');
	if (fleetBox && state.gar.draft) fillGarageFleet(fleetBox, state.gar.draft);
	if (!state.gar.draft) renderGarageEditor();
}

function onGarageResult(data) {
	const message = document.getElementById('gar-message');
	message.textContent = data.message || '';
	message.classList.toggle('is-success', data.success === true);
	if (data.success !== true) return;
	if (data.operation === 'garageDelete') state.gar.draft = null;
	else state.gar.isNew = false;
	renderGarages();
	renderGarageEditor();
}

document.getElementById('gar-new').addEventListener('click', () => {
	state.gar.draft = garNewDraft(state.gar.kind);
	state.gar.isNew = true;
	state.gar.section = 'general';
	renderGarages();
	renderGarageEditor();
});
