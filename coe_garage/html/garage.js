(function () {
	'use strict';

	const modal = document.getElementById('garage-modal');
	const listEl = document.getElementById('vehicle-list');
	const closeBtn = document.getElementById('garage-close');
	const titleEl = document.getElementById('garage-title');
	const subtitleEl = document.getElementById('garage-subtitle');

	let currentGarageId = null;
	let currentSpotId = null;

	function post(action, data) {
		return fetch(`https://${GetParentResourceName()}/${action}`, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json; charset=UTF-8' },
			body: JSON.stringify(data || {})
		}).then(res => res.json()).catch(() => ({}));
	}

	function close() {
		modal.hidden = true;
		listEl.innerHTML = '';
		currentGarageId = null;
		currentSpotId = null;
		post('close');
	}

	function open(data) {
		currentGarageId = data.garageId;
		currentSpotId = data.spotId;
		listEl.innerHTML = '';
		titleEl.textContent = data.title || 'Garagem Pública';
		subtitleEl.textContent = data.spotLabel ? (data.spotLabel + ' · selecione o veículo para retirar') : 'Selecione o veículo que deseja retirar';

		const vehicles = Array.isArray(data.vehicles) ? data.vehicles : [];
		if (vehicles.length === 0) {
			const emptyMsg = document.createElement('p');
			emptyMsg.className = 'garage-empty';
			emptyMsg.textContent = 'Nenhum veículo disponível nesta garagem.';
			listEl.appendChild(emptyMsg);
		} else {
			vehicles.forEach(function (v) {
				const item = document.createElement('div');
				item.className = 'garage-item';

				const details = document.createElement('div');
				details.className = 'garage-item-info';

				const model = document.createElement('div');
				model.className = 'garage-item-name';
				model.textContent = v.label || v.model || 'Veículo';

				const plate = document.createElement('div');
				plate.className = 'garage-item-plate';
				plate.textContent = v.plate || '------';

				details.appendChild(model);
				details.appendChild(plate);

				const retrieveBtn = document.createElement('button');
				retrieveBtn.type = 'button';
				retrieveBtn.className = 'coe-button coe-button--primary';
				retrieveBtn.textContent = 'Retirar';
				retrieveBtn.addEventListener('click', function () {
					post('retrieve', {
						garageId: currentGarageId,
						spotId: currentSpotId,
						vehicleId: v.id
					});
				});

				item.appendChild(details);
				item.appendChild(retrieveBtn);
				listEl.appendChild(item);
			});
		}

		modal.hidden = false;
	}

	closeBtn.addEventListener('click', close);

	window.addEventListener('keydown', function (e) {
		if (e.key === 'Escape' && !modal.hidden) {
			close();
		}
	});

	window.addEventListener('message', function (e) {
		const msg = e.data || {};
		if (msg.action === 'open') {
			open(msg);
		} else if (msg.action === 'close') {
			modal.hidden = true;
		}
	});
})();
