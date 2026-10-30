/* Menu do aluguel. Textos e valores já chegam traduzidos e formatados do client (Lua). */
(function () {
	'use strict';

	const modal = document.getElementById('rental-modal');
	const titleEl = document.getElementById('rental-title');
	const subtitleEl = document.getElementById('rental-subtitle');
	const listEl = document.getElementById('rental-list');
	const closeBtn = document.getElementById('rental-close');
	const confirmBtn = document.getElementById('rental-confirm');
	const summaryLabel = document.getElementById('rental-summary-label');
	const summaryTotal = document.getElementById('rental-summary-total');
	const summaryHint = document.getElementById('rental-summary-hint');
	const currentBox = document.getElementById('rental-current');
	const currentTitle = document.getElementById('rental-current-title');
	const currentStatus = document.getElementById('rental-current-status');
	const returnBtn = document.getElementById('rental-return');
	const endBtn = document.getElementById('rental-end');
	const docModal = document.getElementById('rental-document');
	const docKicker = document.getElementById('doc-kicker');
	const docTitle = document.getElementById('doc-title');
	const docStatus = document.getElementById('doc-status');
	const docFields = document.getElementById('doc-fields');
	const docClose = document.getElementById('doc-close');

	let stationId = null;
	let vehicles = [];
	let selected = -1;
	let texts = {};
	let sending = false;
	let hasRental = false;

	function post(action, data) {
		if (typeof GetParentResourceName !== 'function') {
			return Promise.resolve({});
		}
		return fetch(`https://${GetParentResourceName()}/${action}`, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json; charset=UTF-8' },
			body: JSON.stringify(data || {})
		}).then((res) => res.json()).catch(() => ({}));
	}

	function text(key, fallback) {
		return typeof texts[key] === 'string' ? texts[key] : fallback;
	}

	function element(tag, className, content) {
		const node = document.createElement(tag);
		if (className) node.className = className;
		if (content !== undefined) node.textContent = content;
		return node;
	}

	function updateSummary() {
		const vehicle = vehicles[selected];
		summaryLabel.textContent = text('total', 'Total a pagar');
		summaryTotal.textContent = vehicle ? vehicle.totalText : '—';
		summaryHint.textContent = hasRental
			? text('hasRental', 'Devolva ou encerre o aluguel atual para alugar outro.')
			: vehicle
				? text('depositHint', 'A caução volta ao devolver em qualquer estação.').replace('%{deposit}', vehicle.depositText)
				: text('chooseHint', 'Escolha um veículo.');
		confirmBtn.disabled = !vehicle || sending || hasRental;
	}

	function select(index) {
		selected = index;
		Array.from(listEl.children).forEach((node, position) => {
			node.setAttribute('aria-selected', position === index ? 'true' : 'false');
		});
		updateSummary();
	}

	function render() {
		listEl.replaceChildren();
		if (vehicles.length === 0) {
			listEl.append(element('p', 'rental-empty', text('empty', 'Nenhum veículo disponível nesta estação.')));
			return;
		}
		vehicles.forEach((vehicle, index) => {
			const item = element('button', 'rental-item');
			item.type = 'button';
			item.setAttribute('role', 'option');
			item.setAttribute('aria-selected', 'false');

			const info = element('div', 'rental-info');
			info.append(
				element('span', 'rental-name', vehicle.label),
				element('span', 'rental-detail', `${text('price', 'Aluguel')} ${vehicle.priceText} · ${text('deposit', 'Caução')} ${vehicle.depositText}`)
			);

			item.append(
				element('span', 'rental-badge', vehicle.categoryLabel || ''),
				info,
				element('span', 'rental-price', vehicle.totalText)
			);
			item.addEventListener('click', () => select(index));
			item.addEventListener('dblclick', () => {
				select(index);
				confirm();
			});
			listEl.append(item);
		});
	}

	function open(data) {
		stationId = data.stationId;
		texts = data.texts && typeof data.texts === 'object' ? data.texts : {};
		vehicles = Array.isArray(data.vehicles) ? data.vehicles : [];
		sending = false;
		titleEl.textContent = data.title || '';
		subtitleEl.textContent = data.subtitle || '';
		closeBtn.setAttribute('aria-label', text('close', 'Fechar'));
		confirmBtn.textContent = text('confirm', 'Alugar');
		hasRental = Boolean(data.rental);
		renderCurrent(data.rental);
		render();
		select(vehicles.length > 0 ? 0 : -1);
		modal.hidden = false;
		const first = listEl.querySelector('.rental-item');
		if (first) first.focus();
	}

	// Aluguel em andamento: devolver (veículo estacionado perto) ou encerrar (veículo sumiu, caução retida).
	function renderCurrent(rental) {
		currentBox.hidden = !rental;
		if (!rental) return;
		currentTitle.textContent = rental.title || '';
		currentStatus.textContent = rental.statusText || '';
		returnBtn.textContent = text('returnLabel', 'Devolver');
		endBtn.textContent = text('endLabel', 'Encerrar aluguel');
		returnBtn.hidden = rental.status === 'lost';
		returnBtn.disabled = rental.status !== 'near';
		endBtn.hidden = rental.status !== 'lost';
	}

	function counterAction(action) {
		if (!stationId || sending) return;
		sending = true;
		const request = { stationId };
		hide();
		post(action, request);
	}

	function showDocument(doc, labels) {
		const t = labels && typeof labels === 'object' ? labels : {};
		docKicker.textContent = doc.station || '';
		docTitle.textContent = t.title || 'Contrato de locação';
		docStatus.textContent = doc.active ? (t.active || 'Em vigor') : (t.closed || 'Encerrado');
		docStatus.classList.toggle('is-active', doc.active === true);
		docClose.textContent = t.close || 'Fechar';
		docFields.replaceChildren();
		const rows = [
			[t.vehicle || 'Veículo', doc.vehicle, true],
			[t.plate || 'Placa', doc.plate],
			[t.date || 'Data', doc.rentedAt],
			[t.renter || 'Locatário', doc.renter, !doc.stateId],
			[t.stateId || 'ID', doc.stateId],
			[t.price || 'Aluguel', doc.price],
			[t.deposit || 'Caução', doc.deposit]
		];
		rows.forEach(([label, value, wide]) => {
			if (value === undefined || value === null || value === '') return;
			const item = element('div', wide ? 'is-wide' : '');
			item.append(element('dt', '', label), element('dd', '', String(value)));
			docFields.append(item);
		});
		docModal.hidden = false;
		docClose.focus();
	}

	function closeDocument() {
		if (docModal.hidden) return;
		docModal.hidden = true;
		post('close');
	}

	function hide() {
		modal.hidden = true;
		listEl.replaceChildren();
		vehicles = [];
		selected = -1;
		stationId = null;
	}

	function close() {
		if (modal.hidden) return;
		hide();
		post('close');
	}

	function confirm() {
		const vehicle = vehicles[selected];
		if (!vehicle || sending || hasRental || !stationId) return;
		sending = true;
		updateSummary();
		const request = { stationId, model: vehicle.model };
		hide();
		post('rent', request);
	}

	closeBtn.addEventListener('click', close);
	confirmBtn.addEventListener('click', confirm);
	returnBtn.addEventListener('click', () => counterAction('returnRental'));
	endBtn.addEventListener('click', () => counterAction('endRental'));
	docClose.addEventListener('click', closeDocument);

	window.addEventListener('keydown', (event) => {
		if (!docModal.hidden) {
			if (event.key === 'Escape' || event.key === 'Enter') closeDocument();
			return;
		}
		if (modal.hidden) return;
		if (event.key === 'Enter' && (event.target === returnBtn || event.target === endBtn)) return;
		if (event.key === 'Enter' && event.target === closeBtn) return;
		if (event.key === 'Escape') {
			close();
		} else if (event.key === 'Enter') {
			confirm();
		} else if (event.key === 'ArrowDown' && vehicles.length > 0) {
			event.preventDefault();
			select((selected + 1) % vehicles.length);
			listEl.children[selected].focus();
		} else if (event.key === 'ArrowUp' && vehicles.length > 0) {
			event.preventDefault();
			select((selected - 1 + vehicles.length) % vehicles.length);
			listEl.children[selected].focus();
		}
	});

	window.addEventListener('message', (event) => {
		const message = event.data || {};
		if (message.action === 'open') {
			open(message);
		} else if (message.action === 'document' && message.doc) {
			showDocument(message.doc, message.texts);
		} else if (message.action === 'close') {
			hide();
			docModal.hidden = true;
		}
	});
})();
