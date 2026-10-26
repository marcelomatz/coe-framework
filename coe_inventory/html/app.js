const inventory = document.getElementById('inventory');
const inventoryLayout = document.querySelector('.inventory-layout');
const slotGrid = document.getElementById('slot-grid');
const hotbarGrid = document.getElementById('hotbar-grid');
const occupiedSlots = document.getElementById('occupied-slots');
const totalSlots = document.getElementById('total-slots');
const freeSlots = document.getElementById('free-slots');
const openKey = document.getElementById('open-key');
const hotbarFeedback = document.getElementById('hotbar-feedback');
const closeButton = document.getElementById('close-button');
const hotbarPeek = document.getElementById('hotbar-peek');
const hotbarPeekGrid = document.getElementById('hotbar-peek-grid');
const consumeBar = document.getElementById('consume-bar');
const consumeItemLabel = document.getElementById('consume-item-label');
const consumeCancelKey = document.getElementById('consume-cancel-key');
const consumeBarFill = document.getElementById('consume-bar-fill');
let hotbarPeekTimer = null;
let consumeTimer = null;
let configuredOpenKey = 'I';
const containerPanels = [
	null,
	{
		panel: document.getElementById('container-panel'),
		grid: document.getElementById('container-grid'),
		label: document.getElementById('container-label'),
		occupied: document.getElementById('container-occupied-slots'),
		total: document.getElementById('container-total-slots'),
		free: document.getElementById('container-free-slots'),
		currentWeight: document.getElementById('container-current-weight'),
		maxWeight: document.getElementById('container-max-weight'),
		closeButton: document.getElementById('container-close-button')
	},
	{
		panel: document.getElementById('container-panel-2'),
		grid: document.getElementById('container-grid-2'),
		label: document.getElementById('container-label-2'),
		occupied: document.getElementById('container-occupied-slots-2'),
		total: document.getElementById('container-total-slots-2'),
		free: document.getElementById('container-free-slots-2'),
		currentWeight: document.getElementById('container-current-weight-2'),
		maxWeight: document.getElementById('container-max-weight-2'),
		closeButton: document.getElementById('container-close-button-2')
	}
];
let pointerDrag = null;
let contextMenu = null;
let contextSelection = null;
let actionRequestSequence = 0;
let pendingActionRequest = null;
let pendingActionKind = null;

const actionErrorMessages = {
	too_far: 'O jogador está longe demais.',
	invalid_target: 'Esse alvo não está disponível.',
	inventory_full: 'Não há espaço livre neste inventário.',
	stack_limit: 'A pilha atingiu o limite.',
	insufficient_items: 'Você não tem essa quantidade.',
	empty_slot: 'Esse slot está vazio.',
	invalid_split_count: 'Escolha uma quantidade menor que a pilha.',
	item_not_stackable: 'Esse item não pode ser dividido.',
	persistence_failed: 'Não foi possível salvar a alteração.',
	persistence_rollback_failed: 'Falha ao restaurar inventários; contate a administração.',
	rate_limited: 'Aguarde um instante e tente novamente.',
	too_heavy: 'O container não suporta esse peso.',
	slot_occupied: 'O slot de destino está ocupado.',
	container_not_open: 'Abra uma bag antes de transferir itens.',
	container_moved: 'A bag saiu do inventário e foi fechada.',
	nested_container_not_supported: 'Não é possível guardar bags dentro de containers.',
	container_limit: 'Você já está com duas maletas abertas.',
	container_prop_busy: 'Você já está carregando outra maleta.',
	container_id_missing: 'Abra a maleta uma vez antes de pegá-la.',
	container_prop_unavailable: 'Não foi possível criar o prop desta maleta.',
	container_drop_failed: 'Não foi possível colocar a maleta no mundo.',
	container_not_carried: 'Esta maleta não está na sua mão.',
	container_placement_active: 'Conclua ou cancele o posicionamento atual.'
};

let carriedContainerId = null;

function closeInventory() {
	fetch(`https://${GetParentResourceName()}/close`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json; charset=UTF-8' },
		body: JSON.stringify({})
	}).catch(() => {});
}

function swapSlots(fromSlot, toSlot) {
	fetch(`https://${GetParentResourceName()}/swapSlots`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json; charset=UTF-8' },
		body: JSON.stringify({ fromSlot, toSlot })
	}).catch(() => {});
}

function moveContainerItem(sourceSide, targetSide, fromSlot, toSlot) {
	if (pendingActionRequest) return;
	const requestId = ++actionRequestSequence;
	pendingActionRequest = requestId;
	pendingActionKind = 'containerMove';
	setHotbarFeedback('Movendo item...');
	fetch(`https://${GetParentResourceName()}/moveContainerItem`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json; charset=UTF-8' },
		body: JSON.stringify({ requestId, sourceSide, targetSide, fromSlot, toSlot })
	}).then((response) => response.json()).then((result) => {
		if (pendingActionRequest !== requestId || result.ok) return;
		pendingActionRequest = null;
		pendingActionKind = null;
		setHotbarFeedback(actionErrorMessages[result.error] || 'Não foi possível mover o item.', true);
	}).catch(() => {
		if (pendingActionRequest === requestId) {
			pendingActionRequest = null;
			pendingActionKind = null;
			setHotbarFeedback('Não foi possível mover o item.', true);
		}
	});
}

function updateContainerLayout() {
	const visibleCount = containerPanels.slice(1).filter(({ panel }) => panel.classList.contains('is-visible')).length;
	inventoryLayout.classList.toggle('has-container', visibleCount > 0);
	inventoryLayout.classList.toggle('has-two-containers', visibleCount > 1);
}

function hideContainerPanel(index) {
	const indices = index === 1 || index === 2 ? [index] : [1, 2];
	for (const containerIndex of indices) {
		const container = containerPanels[containerIndex];
		container.panel.classList.remove('is-visible');
		container.panel.setAttribute('aria-hidden', 'true');
		container.grid.replaceChildren();
	}
	updateContainerLayout();
}

function closeContainer(index) {
	fetch(`https://${GetParentResourceName()}/closeContainer`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json; charset=UTF-8' },
		body: JSON.stringify({ index })
	}).catch(() => {});
	hideContainerPanel(index);
}

function setHotbarFeedback(message, isError = false) {
	hotbarFeedback.textContent = message;
	hotbarFeedback.classList.toggle('is-error', isError);
}

function requestItemUse(slot) {
	if (pendingActionRequest) return;
	const requestId = ++actionRequestSequence;
	pendingActionRequest = requestId;
	pendingActionKind = 'hotbar';
	setHotbarFeedback(`Usando slot ${slot}...`);

	fetch(`https://${GetParentResourceName()}/useItem`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json; charset=UTF-8' },
		body: JSON.stringify({ requestId, slot })
	}).then((response) => response.json()).then((result) => {
		if (pendingActionRequest !== requestId || result.ok) return;
		pendingActionRequest = null;
		pendingActionKind = null;
		setHotbarFeedback('Não foi possível usar este item.', true);
	}).catch(() => {
		if (pendingActionRequest === requestId) {
			pendingActionRequest = null;
			pendingActionKind = null;
			setHotbarFeedback('Não foi possível usar este item.', true);
		}
	});
}

function closeContextMenu() {
	contextMenu?.remove();
	contextMenu = null;
	contextSelection = null;
	pendingActionRequest = null;
	pendingActionKind = null;
}

function setContextMenuContent(title, subtitle) {
	contextMenu.replaceChildren();
	const heading = document.createElement('div');
	heading.className = 'context-menu-heading';
	const titleElement = document.createElement('strong');
	titleElement.textContent = title;
	heading.append(titleElement);
	if (subtitle) {
		const subtitleElement = document.createElement('span');
		subtitleElement.textContent = subtitle;
		heading.append(subtitleElement);
	}
	contextMenu.append(heading);
}

function addContextMenuButton(label, onClick, className = '') {
	const button = document.createElement('button');
	button.type = 'button';
	button.className = `context-menu-button ${className}`.trim();
	button.textContent = label;
	button.addEventListener('click', onClick);
	contextMenu.append(button);
	return button;
}

function showContextMenuError(error) {
	const status = contextMenu?.querySelector('.context-menu-status');
	if (status) status.textContent = actionErrorMessages[error] || 'Não foi possível concluir a ação.';
}

function submitContextAction(endpoint, payload, button) {
	const requestId = ++actionRequestSequence;
	pendingActionRequest = requestId;
	pendingActionKind = 'context';
	contextMenu.dataset.requestId = String(requestId);
	let status = contextMenu.querySelector('.context-menu-status');
	if (!status) {
		status = document.createElement('p');
		status.className = 'context-menu-status';
		status.setAttribute('aria-live', 'polite');
		contextMenu.append(status);
	}
	status.textContent = 'Enviando...';
	button.disabled = true;

	fetch(`https://${GetParentResourceName()}/${endpoint}`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json; charset=UTF-8' },
		body: JSON.stringify({ ...payload, requestId })
	}).then((response) => response.json()).then((result) => {
		if (pendingActionRequest === requestId && !result.ok) {
			pendingActionRequest = null;
			button.disabled = false;
			showContextMenuError(result.error);
		}
	}).catch(() => {
		if (pendingActionRequest === requestId) {
			pendingActionRequest = null;
			button.disabled = false;
			showContextMenuError('request_failed');
		}
	});
}

function showQuantityPrompt(action, target) {
	const { slot, item } = contextSelection;
	const maximum = action === 'split' ? item.count - 1 : item.count;
	const initial = action === 'split' ? Math.max(1, Math.floor(item.count / 2)) : item.count;
	setContextMenuContent(action === 'split' ? 'Dividir quantidade' : `Entregar para ${target.name}`, `${item.label || item.name} · máximo ${maximum}`);

	const form = document.createElement('form');
	form.className = 'context-menu-form';
	const input = document.createElement('input');
	input.className = 'coe-field';
	input.type = 'number';
	input.min = '1';
	input.max = String(maximum);
	input.step = '1';
	input.value = String(initial);
	input.required = true;
	input.setAttribute('aria-label', 'Quantidade');
	form.append(input);

	const status = document.createElement('p');
	status.className = 'context-menu-status';
	status.setAttribute('aria-live', 'polite');
	form.append(status);

	const actions = document.createElement('div');
	actions.className = 'context-menu-actions';
	const cancel = document.createElement('button');
	cancel.type = 'button';
	cancel.className = 'coe-button';
	cancel.textContent = 'Cancelar';
	cancel.addEventListener('click', closeContextMenu);
	const submit = document.createElement('button');
	submit.type = 'submit';
	submit.className = 'coe-button coe-button--primary';
	submit.textContent = action === 'split' ? 'Dividir' : 'Entregar';
	actions.append(cancel, submit);
	form.append(actions);
	form.addEventListener('submit', (event) => {
		event.preventDefault();
		const count = Number(input.value);
		if (!Number.isInteger(count) || count < 1 || count > maximum) {
			input.setCustomValidity(`Informe um valor entre 1 e ${maximum}.`);
			input.reportValidity();
			return;
		}
		input.setCustomValidity('');
		const payload = action === 'split'
			? { slot, count }
			: { slot, count, targetId: target.serverId };
		submitContextAction(action === 'split' ? 'splitItem' : 'giveItem', payload, submit);
	});
	contextMenu.append(form);
	input.focus();
	input.select();
}

async function showNearbyPlayers() {
	const selection = contextSelection;
	setContextMenuContent('Escolher jogador', 'Buscando jogadores próximos...');
	try {
		const response = await fetch(`https://${GetParentResourceName()}/nearbyPlayers`, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json; charset=UTF-8' },
			body: JSON.stringify({})
		});
		const result = await response.json();
		if (contextSelection !== selection || !contextMenu) return;
		setContextMenuContent('Escolher jogador', 'Apenas jogadores próximos');
		if (!Array.isArray(result.players) || result.players.length === 0) {
			const empty = document.createElement('p');
			empty.className = 'context-menu-status';
			empty.textContent = 'Nenhum jogador próximo.';
			contextMenu.append(empty);
			return;
		}

		for (const player of result.players) {
			const button = addContextMenuButton(`[${player.serverId}] ${player.name}`,
				() => showQuantityPrompt('give', player));
			button.title = `Entregar para ${player.name}`;
		}
		addContextMenuButton('Voltar', () => showItemContextMenu(), 'is-secondary');
	} catch {
		if (contextSelection === selection && contextMenu) {
			setContextMenuContent('Escolher jogador');
			const error = document.createElement('p');
			error.className = 'context-menu-status';
			error.textContent = 'Não foi possível listar os jogadores.';
			contextMenu.append(error);
		}
	}
}

function requestContainerPropAction(endpoint) {
	const selection = contextSelection;
	if (!selection) return;
	fetch(`https://${GetParentResourceName()}/${endpoint}`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json; charset=UTF-8' },
		body: JSON.stringify({
			itemName: selection.item.name,
			containerId: selection.item.metadata?.containerId
		})
	}).then((response) => response.json()).then((result) => {
		if (contextSelection !== selection || !contextMenu) return;
		if (!result.ok) {
			showContextMenuError(result.error);
			return;
		}
		closeContextMenu();
		if (endpoint === 'placeContainerProp') {
			fetch(`https://${GetParentResourceName()}/close`, {
				method: 'POST',
				headers: { 'Content-Type': 'application/json; charset=UTF-8' },
				body: JSON.stringify({})
			}).catch(() => {});
		}
	}).catch(() => {
		if (contextSelection === selection && contextMenu) showContextMenuError('request_failed');
	});
}

function showItemContextMenu() {
	if (!contextSelection || !contextMenu) return;
	const { slot, item, side } = contextSelection;
	const containerId = item.metadata?.containerId;
	const isContainer = item.container && typeof item.container === 'object';
	const isCarriedContainer = typeof containerId === 'string' && containerId === carriedContainerId;
	setContextMenuContent(item.metadata?.label || item.label || item.name, `Slot ${slot} · x${item.count}`);
	if (side.startsWith('container-')) {
		addContextMenuButton('Fechar', closeContextMenu, 'is-secondary');
		return;
	}
	if (item.usable !== false) {
		const actionLabel = isContainer ? (isCarriedContainer ? 'Guardar' : 'Equipar') : 'Usar';
		addContextMenuButton(actionLabel, () => {
			closeContextMenu();
			requestItemUse(slot);
		});
	}
	if (isContainer) {
		const openButton = addContextMenuButton('Abrir', () => {
			submitContextAction('openContainer', { slot }, openButton);
		});
		if (isCarriedContainer) {
			addContextMenuButton('Colocar no chão', () => requestContainerPropAction('placeContainerProp'));
		} else if (!item.name.startsWith('WEAPON_')) {
			addContextMenuButton('Pegar', () => requestContainerPropAction('pickupContainerProp'));
		}
	}
	addContextMenuButton('Entregar para jogador', showNearbyPlayers);
	if (item.count >= 2) {
		addContextMenuButton('Dividir quantidade', () => showQuantityPrompt('split'));
	}
	addContextMenuButton('Fechar', closeContextMenu, 'is-secondary');
}

function openItemContextMenu(event, slot, item, side) {
	event.preventDefault();
	closeContextMenu();
	contextSelection = { slot, item, side };
	contextMenu = document.createElement('div');
	contextMenu.className = 'inventory-context-menu';
	contextMenu.setAttribute('role', 'menu');
	document.body.append(contextMenu);
	showItemContextMenu();

	const bounds = contextMenu.getBoundingClientRect();
	contextMenu.style.left = `${Math.max(8, Math.min(event.clientX, window.innerWidth - bounds.width - 8))}px`;
	contextMenu.style.top = `${Math.max(8, Math.min(event.clientY, window.innerHeight - bounds.height - 8))}px`;
}

function getSlotAtPoint(x, y) {
	const element = document.elementFromPoint(x, y);
	if (!(element instanceof Element)) return null;

	const slot = element.closest('.inventory-slot');
	return slot && inventory.contains(slot) ? slot : null;
}

function clearPointerDrag() {
	const activeDrag = pointerDrag;
	pointerDrag = null;
	activeDrag?.ghost?.remove();
	inventory.querySelectorAll('.is-dragging, .is-drop-target').forEach((slot) => {
		slot.classList.remove('is-dragging', 'is-drop-target');
	});
}

document.addEventListener('pointermove', (event) => {
	if (!pointerDrag || event.pointerId !== pointerDrag.pointerId) return;
	if (!pointerDrag.active) {
		const distance = Math.hypot(event.clientX - pointerDrag.startX, event.clientY - pointerDrag.startY);
		if (distance < 5) return;
		pointerDrag.active = true;
		const source = inventory.querySelector(`[data-side="${pointerDrag.fromSide}"][data-slot="${pointerDrag.fromSlot}"]`);
		if (source) {
			source.classList.add('is-dragging');
			const bounds = source.getBoundingClientRect();
			const ghost = source.cloneNode(true);
			ghost.classList.add('inventory-drag-ghost');
			ghost.classList.remove('is-dragging', 'is-drop-target', 'is-drop-committing');
			ghost.style.width = `${bounds.width}px`;
			ghost.style.height = `${bounds.height}px`;
			document.body.append(ghost);
			pointerDrag.ghost = ghost;
		}
	}

	event.preventDefault();
	if (pointerDrag.ghost) {
		pointerDrag.ghost.style.left = `${event.clientX}px`;
		pointerDrag.ghost.style.top = `${event.clientY}px`;
	}
	inventory.querySelectorAll('.is-drop-target').forEach((slot) => {
		slot.classList.remove('is-drop-target');
	});
	const target = getSlotAtPoint(event.clientX, event.clientY);
	if (target && (target.dataset.side !== pointerDrag.fromSide || Number(target.dataset.slot) !== pointerDrag.fromSlot)) {
		target.classList.add('is-drop-target');
	}
});

document.addEventListener('pointerup', (event) => {
	if (!pointerDrag || event.pointerId !== pointerDrag.pointerId) return;

	const fromSlot = pointerDrag.fromSlot;
	const fromSide = pointerDrag.fromSide;
	const target = pointerDrag.active ? getSlotAtPoint(event.clientX, event.clientY) : null;
	const toSlot = target ? Number(target.dataset.slot) : null;
	if (toSlot && (fromSide !== target.dataset.side || fromSlot !== toSlot)) {
		target.classList.add('is-drop-committing');
		window.setTimeout(() => target.classList.remove('is-drop-committing'), 260);
		if (fromSide === 'player' && target.dataset.side === 'player') {
			swapSlots(fromSlot, toSlot);
		} else {
			moveContainerItem(fromSide, target.dataset.side, fromSlot, toSlot);
		}
	}
	clearPointerDrag();
});

document.addEventListener('pointercancel', clearPointerDrag);

function createSlot(slotNumber, item, side) {
	const slot = document.createElement('div');
	slot.className = item ? 'coe-slot inventory-slot is-filled' : 'coe-slot inventory-slot';
	if (side === 'player' && slotNumber <= 5) slot.classList.add('is-hotbar');
	slot.setAttribute('role', 'listitem');
	slot.dataset.slot = String(slotNumber);
	slot.dataset.side = side;
	slot.addEventListener('contextmenu', (event) => {
		event.preventDefault();
		if (item && typeof item === 'object') {
			openItemContextMenu(event, slotNumber, item, side);
		} else {
			closeContextMenu();
		}
	});
	if (item && typeof item === 'object') {
		slot.addEventListener('dblclick', (event) => {
			event.preventDefault();
			if (side === 'player' && item.usable !== false) requestItemUse(slotNumber);
		});
		slot.addEventListener('pointerdown', (event) => {
			if (event.button !== 0) return;
			event.preventDefault();
			pointerDrag = {
				fromSlot: slotNumber,
				fromSide: side,
				pointerId: event.pointerId,
				startX: event.clientX,
				startY: event.clientY,
				active: false
			};
		});
	}

	if (side === 'player' && slotNumber <= 5) {
		const hotbarKey = document.createElement('span');
		hotbarKey.className = 'hotbar-key';
		hotbarKey.textContent = String(slotNumber);
		slot.append(hotbarKey);
	}

	if (item && typeof item === 'object') {
		const itemName = typeof item.name === 'string' ? item.name : 'Item';
		const displayName = typeof item.metadata?.label === 'string'
			? item.metadata.label
			: typeof item.label === 'string'
				? item.label
				: itemName.replaceAll('_', ' ');

		const itemContent = document.createElement('div');
		itemContent.className = 'item-content';

		const itemIcon = document.createElement('img');
		itemIcon.className = 'item-icon';
		itemIcon.alt = '';
		itemIcon.draggable = false;

		const rawImage = typeof item.image === 'string' && item.image.trim().length > 0
			? item.image.trim()
			: `${itemName}.webp`;
		const baseName = rawImage.replace(/\.(webp|png|svg)$/i, '');
		const requestedExt = (rawImage.match(/\.(webp|png|svg)$/i)?.[1] || 'webp').toLowerCase();
		const candidates = [
			`${baseName}.${requestedExt}`,
			...(requestedExt !== 'webp' ? [`${baseName}.webp`] : []),
			...(requestedExt !== 'png' ? [`${baseName}.png`] : [])
		];

		let candidateIndex = 0;
		function tryNextSource() {
			if (candidateIndex >= candidates.length) {
				itemIcon.remove();
				return;
			}
			const nextCandidate = candidates[candidateIndex++];
			itemIcon.src = `../data/images/${encodeURIComponent(nextCandidate)}`;
		}

		itemIcon.addEventListener('error', tryNextSource);
		tryNextSource();

		const itemLabel = document.createElement('span');
		itemLabel.className = 'item-label';
		itemLabel.textContent = displayName;
		itemLabel.title = displayName;

		const itemCode = document.createElement('span');
		itemCode.className = 'item-code';
		itemCode.textContent = itemName;

		const quantity = document.createElement('span');
		quantity.className = 'item-quantity';
		quantity.textContent = String(Number(item.count) || 0);
		quantity.setAttribute('aria-label', `Quantidade: ${quantity.textContent}`);

		itemContent.append(itemIcon, itemLabel, itemCode);
		slot.append(itemContent, quantity);
	}

	return slot;
}

function renderHotbarPeekSlots(payload, hotbarSlots = 5) {
	if (!hotbarPeekGrid) return;
	const count = Math.max(1, Math.min(Number(hotbarSlots) || 5, 9));
	const items = Array.isArray(payload?.items) ? payload.items : [];
	hotbarPeekGrid.replaceChildren();
	for (let slot = 1; slot <= count; slot += 1) {
		const item = items[slot - 1];
		hotbarPeekGrid.append(createSlot(slot, item, 'player'));
	}
}

function hideHotbarPeek() {
	if (hotbarPeekTimer) {
		window.clearTimeout(hotbarPeekTimer);
		hotbarPeekTimer = null;
	}
	if (hotbarPeek) {
		hotbarPeek.classList.remove('is-visible');
		hotbarPeek.setAttribute('aria-hidden', 'true');
	}
}

function showHotbarPeek(payload, hotbarSlots = 5, durationMs = 3000) {
	if (!hotbarPeek || inventory.classList.contains('is-open')) return;
	renderHotbarPeekSlots(payload, hotbarSlots);
	hotbarPeek.classList.add('is-visible');
	hotbarPeek.setAttribute('aria-hidden', 'false');
	if (hotbarPeekTimer) window.clearTimeout(hotbarPeekTimer);
	hotbarPeekTimer = window.setTimeout(() => {
		hotbarPeek.classList.remove('is-visible');
		hotbarPeek.setAttribute('aria-hidden', 'true');
		hotbarPeekTimer = null;
	}, Math.max(500, Number(durationMs) || 3000));
}

function startConsumeBar(label, durationMs = 3000, cancelKey = 'X') {
	if (!consumeBar || !consumeBarFill) return;
	if (consumeTimer) {
		window.clearTimeout(consumeTimer);
		consumeTimer = null;
	}
	const duration = Math.max(200, Number(durationMs) || 3000);
	if (consumeItemLabel) consumeItemLabel.textContent = label || 'Item';
	if (consumeCancelKey) consumeCancelKey.textContent = String(cancelKey || 'X').toUpperCase();
	consumeBarFill.style.transition = 'none';
	consumeBarFill.style.transform = 'scaleX(0)';
	consumeBar.classList.add('is-visible');
	consumeBar.setAttribute('aria-hidden', 'false');
	void consumeBarFill.offsetWidth;
	consumeBarFill.style.transition = `transform ${duration}ms linear`;
	consumeBarFill.style.transform = 'scaleX(1)';
	consumeTimer = window.setTimeout(() => {
		stopConsumeBar();
	}, duration + 100);
}

function stopConsumeBar() {
	if (consumeTimer) {
		window.clearTimeout(consumeTimer);
		consumeTimer = null;
	}
	if (!consumeBar) return;
	consumeBar.classList.remove('is-visible');
	consumeBar.setAttribute('aria-hidden', 'true');
}

function renderInventory(data) {
	closeContextMenu();
	const payload = data.inventory;
	const capacity = Math.max(0, Math.min(Number(payload?.slots) || 0, 200));
	const items = Array.isArray(payload?.items) ? payload.items : [];
	let occupied = 0;

	slotGrid.replaceChildren();
	hotbarGrid.replaceChildren();
	for (let slot = 1; slot <= capacity; slot += 1) {
		const item = items[slot - 1];
		if (item && typeof item === 'object') occupied += 1;
		const slotElement = createSlot(slot, item, 'player');
		(slot <= 5 ? hotbarGrid : slotGrid).append(slotElement);
	}

	renderHotbarPeekSlots(payload, data.hotbarSlots || 5);

	occupiedSlots.textContent = String(occupied).padStart(2, '0');
	totalSlots.textContent = String(capacity).padStart(2, '0');
	freeSlots.textContent = `${capacity - occupied} espaços livres`;
	const key = typeof data.openKey === 'string' && data.openKey.trim() !== '' ? data.openKey.toUpperCase() : 'I';
	configuredOpenKey = key;
	openKey.textContent = key;
}

function renderContainer(data, index) {
	const container = containerPanels[index];
	if (!container) return;
	const capacity = Math.max(0, Math.min(Number(data?.slots) || 0, 200));
	const items = Array.isArray(data?.items) ? data.items : [];
	let occupied = 0;
	container.grid.replaceChildren();
	for (let slot = 1; slot <= capacity; slot += 1) {
		const item = items[slot - 1];
		if (item && typeof item === 'object') occupied += 1;
		container.grid.append(createSlot(slot, item, `container-${index}`));
	}

	container.label.textContent = data.container?.label || 'Conteúdo';
	container.occupied.textContent = String(occupied).padStart(2, '0');
	container.total.textContent = String(capacity).padStart(2, '0');
	container.free.textContent = `${capacity - occupied} espaços livres`;
	container.currentWeight.textContent = (Number(data.weight) || 0).toLocaleString('pt-BR');
	container.maxWeight.textContent = (Number(data.maxWeight) || 0).toLocaleString('pt-BR');
}

window.addEventListener('message', (event) => {
	const data = event.data;
	if (!data || typeof data !== 'object') return;

	if (data.action === 'open') {
		hideHotbarPeek();
		hideContainerPanel();
		renderInventory(data);
		inventory.classList.add('is-open');
		inventory.setAttribute('aria-hidden', 'false');
	} else if (data.action === 'update') {
		renderInventory({ inventory: data.inventory, openKey: data.openKey, hotbarSlots: data.hotbarSlots });
	} else if (data.action === 'hotbarData') {
		renderHotbarPeekSlots(data.inventory, data.hotbarSlots);
	} else if (data.action === 'hotbarPeek') {
		showHotbarPeek(data.inventory, data.hotbarSlots, data.durationMs);
	} else if (data.action === 'consumeStart') {
		startConsumeBar(data.label, data.durationMs, data.cancelKey);
	} else if (data.action === 'consumeEnd') {
		stopConsumeBar();
	} else if (data.action === 'containerOpen') {
		renderContainer(data.inventory, data.index);
		const container = containerPanels[data.index];
		if (container) {
			container.panel.classList.add('is-visible');
			container.panel.setAttribute('aria-hidden', 'false');
		}
		updateContainerLayout();
	} else if (data.action === 'containerUpdate') {
		renderContainer(data.inventory, data.index);
	} else if (data.action === 'containerClose') {
		hideContainerPanel(data.index);
	} else if (data.action === 'actionResult') {
		if (data.requestId !== pendingActionRequest) return;
		const actionKind = pendingActionKind;
		pendingActionRequest = null;
		pendingActionKind = null;
		if (data.success === true && actionKind === 'context') {
			closeContextMenu();
		} else if (data.success === true && actionKind === 'containerMove') {
			setHotbarFeedback('Item transferido.');
		} else if (data.success === true) {
			setHotbarFeedback('Item usado.');
		} else if (actionKind === 'context') {
			showContextMenuError(data.error);
		} else if (actionKind === 'containerMove') {
			setHotbarFeedback(actionErrorMessages[data.error] || 'Não foi possível mover o item.', true);
		} else {
			setHotbarFeedback('Não foi possível usar este item.', true);
		}
	} else if (data.action === 'propFeedback') {
		setHotbarFeedback(data.message || '', data.isError === true);
	} else if (data.action === 'containerPropState') {
		carriedContainerId = typeof data.containerId === 'string' ? data.containerId : null;
	} else if (data.action === 'close') {
		closeContextMenu();
		hideContainerPanel();
		inventory.classList.remove('is-open');
		inventory.setAttribute('aria-hidden', 'true');
	}
});

closeButton.addEventListener('click', closeInventory);
containerPanels.slice(1).forEach((container, index) => {
	container.closeButton.addEventListener('click', () => closeContainer(index + 1));
});

document.addEventListener('pointerdown', (event) => {
	if (event.button === 0 && contextMenu && !contextMenu.contains(event.target)) {
		closeContextMenu();
	}
});

window.addEventListener('keydown', (event) => {
	if (event.key === 'Escape' && contextMenu) {
		event.preventDefault();
		closeContextMenu();
		return;
	}
	if (/^[1-5]$/.test(event.key)
		&& inventory.classList.contains('is-open')
		&& !contextMenu
		&& !(event.target instanceof HTMLInputElement)) {
		event.preventDefault();
		const hotbarSlot = hotbarGrid.querySelector(`[data-slot="${event.key}"]`);
		if (hotbarSlot?.classList.contains('is-filled')) {
			requestItemUse(Number(event.key));
		}
		return;
	}
	const pressedKey = typeof event.key === 'string' ? event.key.toUpperCase() : '';
	const isOpenKey = !(event.target instanceof HTMLInputElement)
		&& (event.key === 'F2' || pressedKey === configuredOpenKey);
	if (event.key === 'Escape' || isOpenKey) {
		event.preventDefault();
		const openContainerIndex = [2, 1].find((index) => containerPanels[index].panel.classList.contains('is-visible'));
		if (event.key === 'Escape' && openContainerIndex) {
			closeContainer(openContainerIndex);
			return;
		}
		closeInventory();
	}
});
